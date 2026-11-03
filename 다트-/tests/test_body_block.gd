extends SceneTree
## 몸으로 막기(2026-11-02 F6 이식): 몸막 구역에 선 사람에게 다트가 맞으면
## 그 발은 0점이고 맞은 사람은 스턴 + 방해 성공 보상(점수)을 받는다.
## 구역 밖(레인 안쪽 복도)은 투명 벽으로 막혀 있어 거기서는 막을 수 없다.
const Rules = preload("res://game/card_round/rules/round_rules.gd")

var main: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# 구역 판정은 좌표 계산이라 방 없이 먼저 본다.
	var middle: float = (TableView.BLOCK_ZONE.x + TableView.BLOCK_ZONE.y) / 2.0
	assert(TableView.in_block_zone(Vector3(0, 0, middle)))
	assert(TableView.in_block_zone(TableView.block_spot()), "서서 막는 자리는 구역 안이다")
	assert(not TableView.in_block_zone(Vector3(0, 0, TableView.BLOCK_ZONE.y + 0.3)), "구역 뒤(투척선 쪽)는 막혀 있다")
	assert(not TableView.in_block_zone(Vector3(0, 0, TableView.BLOCK_ZONE.x - 0.3)), "구역 앞(과녁 쪽)은 막혀 있다")
	assert(not TableView.in_block_zone(Vector3(TableView.LANE_HALF + 0.4, 0, middle)), "레인 바깥은 구경 자리다")
	# 구역은 투척선보다 앞(과녁 쪽)이고 다트 홀 안이다.
	assert(TableView.BLOCK_ZONE.x < TableView.BLOCK_ZONE.y and TableView.BLOCK_ZONE.y < TableView.NO_ENTRY_Z)
	assert(TableView.BLOCK_ZONE.x > TableView.DART_HALL.position.y)

	main = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	var options := RoomSettings.new()
	options.social_lobby = true
	options.solo = true
	options.bot_count = 3
	main.session.host_room("테스터", 17646, options)
	await create_timer(0.8).timeout
	var game: GameView = main._game
	game.force_seat(1)
	await create_timer(0.3).timeout
	main.session.set_ready(true)
	var until: float = Time.get_ticks_msec() / 1000.0 + 10.0
	while Time.get_ticks_msec() / 1000.0 < until and (main._game == null or main._game.controller.state.phase != MatchState.Phase.CARDS):
		await process_frame
	game = main._game
	var controller: MatchController = game.controller
	controller._phase_end = controller._now()
	await create_timer(0.2).timeout
	assert(controller.state.phase == MatchState.Phase.AIMING and controller.state.active_player().peer_id == 1)
	var local := game.actors[1] as PlayerView
	local.position = Vector3(0, 0, TableView.THROW_LINE_Z + 0.4)
	await physics_frame
	assert(game.can_throw_from(1))

	# 봇 하나를 몸막 구역 한가운데 세운다. 비행 궤적은 던지는 순간 확정되므로
	# 그 뒤 봇이 자리로 돌아가도 판정은 바뀌지 않는다.
	var blocker := game.actors[-1] as PlayerView
	var cards: RefCounted = controller.cards
	for peer: int in cards._bot_plans.keys():
		cards._bot_plans[peer] = -1.0
	blocker.seated = false
	blocker.position = TableView.block_spot()
	var before: int = controller.state.find_player(-1).score
	controller.submit_throw(Vector2.ZERO, 1)
	assert(controller.state.phase == MatchState.Phase.FLIGHT)
	assert(int(controller.state.find_player(1).score) == 0, "던진 사람은 점수를 못 얻는다")
	until = Time.get_ticks_msec() / 1000.0 + 4.0
	while Time.get_ticks_msec() / 1000.0 < until and int(controller.state.last_hit.get("victim", 0)) == 0:
		await process_frame
	var hit: Dictionary = controller.state.last_hit
	assert(int(hit.get("victim", 0)) == -1, "몸에 맞은 사람이 스냅샷에 실려야 한다: %s" % hit)
	assert(int(hit.points) == 0 and "몸에 맞음" in str(hit.reason), "막힌 발은 0점이다: %s" % hit)
	assert(int(controller.state.find_player(1).score) == 0, "던진 사람 점수는 그대로다")
	# 방해 성공 보상(점수)과 스턴.
	var after: int = controller.state.find_player(-1).score
	assert(after == before + Rules.DISRUPT_SCORE, "막은 사람이 방해 성공 보상을 받는다: %d → %d" % [before, after])
	assert(game._frozen(-1), "막은 사람은 잠깐 못 움직인다")
	assert(controller.state.feed.any(func(line: String) -> bool: return line.begins_with("dizzy\t")), "킬로그에 남는다: %s" % [controller.state.feed])
	# 스턴이 풀리면 다시 움직인다.
	game._stun_until[-1] = controller._now()
	assert(not game._frozen(-1))

	main.queue_free()
	await process_frame
	print("PASS: body block scores zero, stuns the blocker, pays the disruption reward, and only works inside the block zone")
	quit()
