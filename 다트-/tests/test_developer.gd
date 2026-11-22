extends SceneTree
## 개발자 모드(2026-11-22): 설정에서 켜고, 카드 시험대로 아무 카드나 바로 쓰고, 경기 조작(점수·효과·자리)을 한다.
## 개발자 모드가 꺼져 있으면 같은 길이 전부 거절되는지도 함께 본다.
const Catalog = preload("res://game/card_round/rules/card_catalog.gd")

var main: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	main = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	var options := RoomSettings.new()
	options.social_lobby = true
	options.solo = true
	options.bot_count = 3
	main.session.host_room("테스터", 17680, options)
	await create_timer(0.8).timeout
	var game: GameView = main._game
	assert(not game.can_start_card_test(), "개발자 모드 없이 테스트를 시작할 수 없다")
	main.set_developer_mode(true)
	var test_controller: MatchController = game.controller
	var opponent: int = test_controller.state.players[1].peer_id
	game.card_test_selection = {1: Catalog.type_of("power_up"), opponent: Catalog.type_of("dizzy")}
	game.start_card_test()
	assert(main._game == game and main.session.room.phase == RoomState.Phase.LOBBY, "같은 맵에서 연습 턴을 연다")
	assert(test_controller.card_test_active and test_controller.state.phase == MatchState.Phase.AIMING)
	assert(test_controller.state.active_player().peer_id == 1 and game.can_throw_from(1))
	assert(test_controller.state.find_player(1).hand.is_empty(), "무작위 손패를 배분하지 않는다")
	var effects: Dictionary = test_controller.state.find_player(1).card_effects
	assert(bool(effects.get("power", false)) and float(effects.get("dizzy", 0)) > 0, "나와 방해자의 카드가 함께 걸린다")
	test_controller.submit_throw(Vector2.ZERO, 0.7)
	assert(test_controller.state.phase == MatchState.Phase.FLIGHT, "정상 투척 경로로 던질 수 있다")
	test_controller._phase_end = test_controller._now()
	await process_frame
	await process_frame
	assert(not test_controller.state.last_hit.is_empty(), "착탄 결과가 나온다")
	test_controller.developer_skip()
	test_controller._phase_end = test_controller._now()
	await process_frame
	await process_frame
	assert(test_controller.state.phase == MatchState.Phase.SETTLING and test_controller.state.active_player().peer_id == 1)
	game.card_test_selection.erase(opponent)
	game.start_card_test()
	effects = test_controller.state.find_player(1).card_effects
	assert(bool(effects.get("power", false)) and float(effects.get("dizzy", 0)) == 0, "다시 시작하면 선택한 카드만 남는다")
	game.card_test_selection[opponent] = Catalog.type_of("bind")
	game.start_card_test()
	await create_timer(0.35).timeout
	assert(game._frozen(1), "조준이 필요한 방해 카드도 같은 맵에서 실제로 맞는다")
	main.set_developer_mode(false)
	assert(not test_controller.card_test_active and test_controller.state.phase == MatchState.Phase.WAITING and not game._frozen(1))
	game.force_seat(1)
	await create_timer(0.3).timeout
	main.session.set_ready(true)
	var until: float = Time.get_ticks_msec() / 1000.0 + 12.0
	while Time.get_ticks_msec() / 1000.0 < until and (main._game == null or main._game.controller.state.phase != MatchState.Phase.CARDS):
		await process_frame
	game = main._game
	var controller: MatchController = game.controller
	controller._phase_end = controller._now()
	await create_timer(0.2).timeout
	assert(controller.state.phase == MatchState.Phase.AIMING, "다트 턴")
	var drowsy: int = Catalog.type_of("drowsy")

	# 개발자 모드가 꺼져 있으면 아무것도 안 한다.
	main.set_developer_mode(false)
	assert(not controller.developer_card(1, drowsy, 0).is_empty(), "꺼져 있으면 카드 시험대가 거절한다")
	var before: int = controller.state.find_player(1).score
	controller.developer_set_score(1, 999)
	assert(controller.state.find_player(1).score == before, "꺼져 있으면 점수를 못 바꾼다")
	assert(not game.developer_teleport(1), "꺼져 있으면 자리를 못 옮긴다")

	# 켜면 손패와 상관없이 카드가 바로 걸린다.
	main.set_developer_mode(true)
	assert(main.developer_mode, "개발 빌드에서는 설정으로 켤 수 있다")
	assert(controller.developer_enabled and game.developer_enabled, "경기에도 전해진다")
	var problem: String = controller.developer_card(1, drowsy, 0)
	assert(problem.is_empty(), "카드 시험대로 졸림을 바로 씀: %s" % problem)
	assert(bool(controller.state.find_player(1).card_effects.get("drowsy", false)), "던지는 사람에게 걸렸다")
	# 같은 효과는 한 번만(시너지 제거) — 시험대도 같은 규칙을 탄다.
	assert(not controller.developer_card(1, drowsy, 0).is_empty(), "이미 걸린 효과는 시험대에서도 거절된다")

	# 경기 조작: 점수·효과 지우기·자리.
	controller.developer_set_score(1, 123)
	assert(controller.state.find_player(1).score == 123, "점수를 직접 넣는다")
	controller.developer_clear_effects()
	assert(not bool(controller.state.find_player(1).card_effects.get("drowsy", false)), "효과를 모두 지웠다")
	assert(game.developer_teleport(1), "투척선으로 옮긴다")
	assert(absf((game.actors[1] as PlayerView).position.z - (TableView.THROW_LINE_Z + 0.4)) < 0.01, "투척선 뒤에 선다")
	assert(game.can_throw_from(1), "옮긴 자리에서 던질 수 있다")

	main.queue_free()
	await process_frame
	print("PASS: card combination turn, real throw and result, replay without opponent effect, original developer tools")
	quit()
