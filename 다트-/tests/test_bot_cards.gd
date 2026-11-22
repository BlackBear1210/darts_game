extends SceneTree
## 봇 카드(2026-10-31): 다트 턴 중 봇이 카드를 쓰고, 효과는 늘 지금 던지는 사람에게 걸린다.
## 남의 차례 = 방해 카드, 자기 차례 = 나에게 거는 카드, 자기 차례에 남이 꺼내 든 카드는 무효(×0)로 막는다.
const Rules = preload("res://game/card_round/rules/round_rules.gd")
const MatchCards = preload("res://game/match/match_cards.gd")
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
	options.special_cards = true
	main.session.host_room("테스터", 17638, options)
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
	var cards: RefCounted = controller.cards
	var catalog = cards.Catalog
	controller._phase_end = controller._now()
	await create_timer(0.2).timeout
	assert(controller.state.phase == MatchState.Phase.AIMING and controller.state.active_player().peer_id == 1)
	# 내 차례: 봇마다 서로 다른 방해 카드를 한 장씩 쥐여 주고 곧 쓰게 한다 → 효과는 모두 나(던지는 사람)에게.
	# 2026-11-22 협동 시너지를 없애 같은 효과는 한 번만 걸린다 → 셋에게 같은 카드를 주면 둘은 거절된다. 서로 다른 카드로 준다.
	# 나머지 손패는 비운다 — 무작위 손패의 새 카드(점프·차례 바꾸기 등)가 차례 순서를 바꾸면 시험이 흔들린다.
	var bot_cards: Array[String] = ["drowsy", "wind", "number_shuffle"]
	for seat in range(1, 4):
		cards.rules.seats[seat].slots[0] = cards.rules.new_card(catalog.type_of(bot_cards[seat - 1]))
		for index in range(1, 7): cards.rules.seats[seat].slots[index] = null
	cards._sync()
	for peer in cards._bot_plans.keys(): cards._bot_plans[peer] = controller._now() + 0.1
	await create_timer(Rules.READY_SECONDS + 0.8).timeout
	var on_me: int = controller.state.feed.filter(func(line: String) -> bool: return line.ends_with("	0	테스터")).size()
	assert(on_me == 3, "봇 셋이 던지는 사람에게 서로 다른 방해 카드: %s" % [controller.state.feed])
	# 같은 효과는 두 번 안 걸린다: 이미 졸림이 걸린 나에게 봇이 졸림을 또 내면 거절되고 손패도 그대로다.
	var again: int = catalog.type_of("drowsy")
	assert(not MatchCards.duplicate_reason(again, controller.state.find_player(1).card_effects, -1).is_empty(),
		"같은 효과를 또 걸 수 없다: %s" % [controller.state.find_player(1).card_effects.get("active_kinds", [])])
	cards.rules.seats[1].slots[0] = cards.rules.new_card(again)
	cards._sync()
	var kept: int = controller.state.find_player(-1).hand.size()
	cards.action(-1, "select", 0)
	cards.action(-1, "use", 1)
	assert(controller.state.find_player(-1).hand.size() == kept, "거절된 카드는 손에 남는다")
	# 봇 1 차례: 봇 1은 나에게 거는 카드를 쓰고, 내가 꺼낸 카드는 봇 1의 무효로 막힌다.
	controller._timeout_turn()
	await create_timer(1.3).timeout
	assert(controller.state.active_player().peer_id == -1, "봇 1 차례: %s" % [controller.state.feed])
	cards.rules.seats[1].slots[0] = cards.rules.new_card(catalog.type_of("times_0"))
	cards.rules.seats[1].slots[1] = cards.rules.new_card(catalog.type_of("power_up"))
	for index in range(2, 7): cards.rules.seats[1].slots[index] = null
	cards._sync()
	cards._bot_plans[-1] = controller._now() + 0.1
	controller.request_card("select", 0)
	await create_timer(Rules.READY_SECONDS * 2 + 1.0).timeout
	var me: MatchPlayer = controller.state.find_player(1)
	assert(me.pending_card == -1 and me.hand.size() == 6, "내 카드가 무효로 막힘")
	assert(controller.state.find_player(-1).hand.is_empty(), "봇 1이 무효와 힘 증가를 모두 씀: %s" % [controller.state.feed])
	# 봇 이름은 별명(럭키세븐 등)이라 이름 대신 킬로그 한 줄을 MatchController.feed_entry 로 똑같이 만들어 비교한다.
	var bot: MatchPlayer = controller.state.find_player(-1)
	var line_power: String = MatchController.feed_entry("card", bot, str(catalog.card(catalog.type_of("power_up")).big), bot)
	assert(controller.state.feed.has(line_power), "봇 1 힘 증가 킬로그: %s" % [controller.state.feed])
	main.queue_free()
	await process_frame
	print("PASS: bots use disruption cards on other throwers, own-target cards on their turn, and counter a lifted card with ×0")
	quit()

