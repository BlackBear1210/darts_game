extends SceneTree
## 카드 사용 HUD A 보완안(2026-11-28): 이번 라운드에 누가 어떤 카드를 썼는지.
##   방장 기록  MatchCards._used_cards — 쓴 순서·상태(걸려 있음·끝남·무효), 투척자 벌칙은 빼고, 라운드가 바뀌면 비운다.
##   화면       ui/used_cards.gd — 상대는 오른쪽 위 사람별 묶음(그 아래로 킬로그), 나는 손패 위(카드를 꺼내 들면 숨김),
##              상대가 새로 쓴 카드는 과녁 옆까지 날아갔다가 사라진다.
##   godot --headless --path . --script res://tests/test_used_cards.gd
const Catalog = preload("res://game/card_round/rules/card_catalog.gd")
const MatchCards = preload("res://game/match/match_cards.gd")
const Preferences = preload("res://ui/player_preferences.gd")
## 날아갔다 돌아오는 데 걸리는 시간보다 넉넉히(UsedCards.FLY_* 합 1.45초).
const FLIGHT_DONE_SECONDS: float = 2.0

var main: Node
var game: GameView
var controller: MatchController
var cards: RefCounted
var hud: CanvasLayer


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	if not value:
		printerr("FAIL: ", message)
		quit(1)
		assert(value, message)


func _run() -> void:
	Preferences.reduced_motion = false
	await _start(3, 17941)
	var me: int = controller.local_peer_id
	var bots: Array[int] = []
	for player in controller.state.players:
		if player.peer_id != me: bots.append(player.peer_id)
	var power: int = Catalog.type_of("power_up")
	var wind: int = Catalog.type_of("wind")
	var nullify: int = Catalog.type_of("times_0")

	# 내 차례에 투척 힘 증가를 쓴다 → 내 기록에 걸려 있는 카드 한 장, 손패 위 내 줄에 보인다. 상대 묶음은 아직 없다.
	_play(me, power, me)
	await _frames()
	_expect(me, [Vector2i(power, MatchCards.UsedCard.LIVE)])
	var used: Control = hud._used_cards
	check(used.visible, "경기 중에는 보여야 한다")
	check(not used.has_opponent_cards(), "상대가 아직 카드를 안 썼다")
	check(used._mine.visible, "내가 쓴 카드 줄이 보여야 한다")

	# 상대가 바람을 쓴다 → 오른쪽 위에 그 사람 묶음, 새 카드는 빛나고 과녁 쪽으로 날아간다. 킬로그는 묶음 아래.
	var children_before: int = used.get_child_count()
	_play(bots[0], wind, me)
	await _frames()
	_expect(bots[0], [Vector2i(wind, MatchCards.UsedCard.LIVE)])
	check(used.has_opponent_cards() and used._others.get_child_count() == 1, "상대 묶음이 하나 생겨야 한다")
	var name_text: String = (used._others.get_child(0).get_child(1) as Label).text
	check(controller.state.find_player(bots[0]).display_name in name_text, "묶음 아래에 쓴 사람 이름: %s" % name_text)
	check(used._fresh.has("%d:0" % bots[0]), "방금 쓴 카드는 빛나야 한다")
	check(used.get_child_count() == children_before + 1, "방금 쓴 상대 카드 사본이 날아가야 한다")
	check(hud._feed.position.y >= used.opponents_bottom(), "킬로그는 상대 카드 묶음 아래에 있어야 한다")

	# 다른 상대가 무효(×0)로 내 투척 힘 증가를 되돌린다 → 내 카드는 무효, 그 사람의 무효 카드는 바로 끝난 카드.
	_play(bots[1], nullify, me)
	await _frames()
	_expect(me, [Vector2i(power, MatchCards.UsedCard.NULLIFIED)])
	_expect(bots[1], [Vector2i(nullify, MatchCards.UsedCard.SPENT)])
	check(used._others.get_child_count() == 2, "카드를 쓴 상대마다 묶음 하나")

	# 투척자 벌칙(몸 명중)은 카드가 아니다 → 기록에 들어가지 않는다.
	cards.rules.penalize_thrower(cards.peers.find(me))
	cards._sync()
	_expect(me, [Vector2i(power, MatchCards.UsedCard.NULLIFIED)])

	# 카드를 꺼내 들면 내 줄은 숨는다(꺼낸 카드가 그 자리로 올라온다).
	var seat: int = cards.peers.find(me)
	cards.rules.seats[seat].slots[0] = cards.rules.new_card(Catalog.type_of("wind"))
	cards.rules.lift(seat, 0, controller._now())
	cards._sync()
	controller._publish()
	await _frames()
	check(not used._mine.visible, "카드를 꺼내 든 동안 내 줄은 숨는다")
	cards.rules.lower(seat)
	cards._sync()
	controller._publish()
	await _frames()
	check(used._mine.visible, "카드를 내리면 내 줄이 다시 보인다")

	# 날아간 사본은 돌아와서 사라지고, 빛도 꺼진다.
	await create_timer(FLIGHT_DONE_SECONDS).timeout
	check(used.get_child_count() == children_before, "날아간 사본이 사라져야 한다")
	check(used._fresh.is_empty(), "빛나는 시간이 끝나야 한다")

	# 새 라운드: 기록이 비고 화면도 비며, 줄어든 것을 '새로 쓴 카드'로 착각해 날리지 않는다.
	cards.begin_round()
	controller._publish()
	await _frames()
	for player in controller.state.players:
		_expect(player.peer_id, [])
	check(not used.has_opponent_cards() and not used._mine.visible, "새 라운드에는 비어 있어야 한다")
	check(used.get_child_count() == children_before, "라운드가 바뀌었다고 카드를 날리면 안 된다")
	main.queue_free()
	await process_frame
	print("PASS: used cards — host record (order, live/spent/nullified, no penalty, per round) and HUD (groups, mine, flight, feed)")
	quit()


## peer 가 카드 한 장을 진짜 사용 경로(_use → _after_use)로 쓴다. 봇이 끼어들지 않게 봇 계획을 지운다.
func _play(peer: int, type: int, target: int) -> void:
	cards._bot_plans.clear()
	var problem: String = cards.developer_play(peer, type, target)
	check(problem.is_empty(), "%s 를 쓰지 못했다: %s" % [Catalog.card(type).name, problem])


func _expect(peer: int, wanted: Array[Vector2i]) -> void:
	var got: Array = controller.state.find_player(peer).card_effects.get("used_cards", [])
	check(got == wanted, "%d 의 기록이 %s 이어야 하는데 %s" % [peer, wanted, got])


func _frames() -> void:
	for i in range(3):
		await process_frame


func _start(bots: int, port: int) -> void:
	main = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	var options := RoomSettings.new()
	options.social_lobby = true
	options.solo = true
	options.bot_count = bots
	options.special_cards = true
	options.rounds = 9
	main.session.host_room("테스터", port, options)
	var until: float = Time.get_ticks_msec() / 1000.0 + 10.0
	while Time.get_ticks_msec() / 1000.0 < until and main._game == null:
		await process_frame
	game = main._game
	check(game != null, "경기 화면이 열리지 않았다")
	game.force_seat(1)
	await create_timer(0.3).timeout
	main.session.set_ready(true)
	until = Time.get_ticks_msec() / 1000.0 + 10.0
	while Time.get_ticks_msec() / 1000.0 < until and game.controller.state.phase != MatchState.Phase.AIMING:
		await process_frame
	controller = game.controller
	cards = controller.cards
	hud = game.lounge_hud
	check(controller.state.phase == MatchState.Phase.AIMING, "조준 단계까지 가지 못했다")
	# 내 차례로 두고, 시작 전에 봇이 쓴 카드는 지운 채 시작한다.
	controller.state.turn_index = controller.state.players.find(controller.state.find_player(controller.local_peer_id))
	cards.begin_round()
	cards.begin_dart_turn()
	cards._bot_plans.clear()
	controller._publish()
	await _frames()
