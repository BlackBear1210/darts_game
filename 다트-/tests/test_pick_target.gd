extends SceneTree
## Tab 으로 대상을 직접 고르는 카드(PICK — 이속 감소·키 변화·목소리 변조·강제 음소거·소매치기·왕머리):
## 고른 사람에게만 걸려야 하고, 고를 사람이 한 명뿐이면 "(Tab 바꾸기)" 안내를 붙이지 않는다.
## [2026-11-27 사용자 "Tab 으로 대상 바꾸는 카드가 제대로 작동하지 않는다"]
const Catalog = preload("res://game/card_round/rules/card_catalog.gd")
## 대상을 Tab 으로 고르는 카드 전부(card_catalog.gd 의 Target.PICK).
const PICK_CARDS: Array[String] = ["speed_down", "body_size", "voice_warp", "voice_mute", "pickpocket", "big_head"]

var main: Node
var game: GameView
var controller: MatchController
var hud: CanvasLayer


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# 2인: 고를 사람이 한 명뿐이라 Tab 은 플레이어 목록이다 → 안내에 Tab 을 쓰지 않는다.
	await _start(1, 17931)
	var me: MatchPlayer = await _lift("speed_down", true)
	assert(hud._pick_targets(controller.state, me).size() == 1, "2인 방은 고를 사람이 한 명이다")
	assert(not hud.tab_picks_target(), "2인 방에서 Tab 은 대상 바꾸기가 아니다")
	assert(not "Tab" in hud._target_name(controller.state, me),
		"바꿀 수 없으면 Tab 안내를 붙이지 않는다: %s" % hud._target_name(controller.state, me))
	await _stop()

	# 4인: 내 차례든 아니든, Tab 으로 고른 사람에게만 걸린다.
	await _start(3, 17932)
	for id: String in PICK_CARDS:
		for mine: bool in [true, false]:
			await _check(id, mine)
	me = await _lift("speed_down", true)
	assert(hud.tab_picks_target(), "고를 사람이 둘 이상이면 Tab 이 대상 바꾸기다")
	assert("Tab" in hud._target_name(controller.state, me), "바꿀 수 있으면 Tab 안내를 붙인다")
	await _stop()
	print("PASS: Tab picks the PICK-card target, effect lands only on that player, hint only when it can change")
	quit()


## 고른 사람에게만 효과가 걸리는지 한 장으로 확인한다. mine = 내 차례인가.
func _check(id: String, mine: bool) -> void:
	var state: MatchState = controller.state
	var me: MatchPlayer = await _lift(id, mine)
	assert(me.pending_card == Catalog.type_of(id), "%s 를 꺼내 들지 못했다" % id)
	# 소매치기는 손패가 있는 사람만 고를 수 있다 → 봇 손패를 채워 둔다.
	for player in state.players:
		if player.peer_id != 1 and player.hand.is_empty(): player.hand.append(Catalog.type_of("plus_10"))
	# Tab 한 번 = 기본 대상(지금 던지는 사람) 다음 후보 → 기본값과 다른 사람이 고른 대상이 된다.
	var picks: Array[int] = hud._pick_targets(state, me)
	var default_target: int = hud._pick_target(state, me)
	hud._pick = picks[(picks.find(default_target) + 1) % picks.size()]
	var chosen: int = hud._pick
	assert(chosen != default_target, "%s: Tab 으로 기본 대상과 다른 사람을 골라야 검사가 뜻이 있다" % id)
	assert(hud._blocked_card_reason(me).is_empty(), "%s: 지금 쓸 수 있어야 한다 — %s" % [id, hud._blocked_card_reason(me)])
	var mod: String = str(Catalog.card(me.pending_card).get("mod", ""))
	var before: Dictionary = {}
	var hands: Dictionary = {}
	for player in state.players:
		before[player.peer_id] = str(player.card_effects.get(mod, "-"))
		hands[player.peer_id] = player.hand.size()
	hud.use_lifted_card()
	await create_timer(0.4).timeout
	var landed: Array[int] = []
	for player in state.players:
		var changed: bool = str(player.card_effects.get(mod, "-")) != before[player.peer_id]
		# 소매치기는 효과가 아니라 손패가 줄어든다.
		if id == "pickpocket": changed = player.hand.size() < int(hands[player.peer_id])
		if changed: landed.append(player.peer_id)
	assert(landed == [chosen], "%s (내 차례 %s): %d 에게 걸려야 하는데 %s" % [id, mine, chosen, landed])


## 내 손패 첫 칸에 카드를 놓고 꺼내 든다. mine = 내 차례로 둘 것인가.
func _lift(id: String, mine: bool) -> MatchPlayer:
	var cards: RefCounted = controller.cards
	var seat: int = cards.peers.find(1)
	controller.state.turn_index = 0 if mine else 1
	cards.rules.lower(seat)
	cards.rules.seats[seat].slots[0] = null
	cards.rules.place(seat, 0, cards.rules.new_card(Catalog.type_of(id)))
	cards.rules.lift(seat, 0, controller._now())
	cards._sync()
	controller._publish()
	await create_timer(0.35).timeout
	return controller.state.find_player(1)


func _start(bots: int, port: int) -> void:
	main = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	var options := RoomSettings.new()
	options.social_lobby = true
	options.solo = true
	options.bot_count = bots
	options.special_cards = true
	# 검사 중에 라운드가 끝나 손패가 다시 깔리지 않도록 넉넉히 둔다.
	options.rounds = 9
	main.session.host_room("테스터", port, options)
	var until: float = Time.get_ticks_msec() / 1000.0 + 10.0
	while Time.get_ticks_msec() / 1000.0 < until and main._game == null:
		await process_frame
	game = main._game
	assert(game != null, "경기 화면이 열리지 않았다")
	game.force_seat(1)
	await create_timer(0.3).timeout
	main.session.set_ready(true)
	until = Time.get_ticks_msec() / 1000.0 + 10.0
	while Time.get_ticks_msec() / 1000.0 < until and game.controller.state.phase != MatchState.Phase.AIMING:
		await process_frame
	controller = game.controller
	hud = game.lounge_hud
	assert(controller.state.phase == MatchState.Phase.AIMING, "조준 단계까지 가지 못했다")
	assert(controller.state.players.size() == bots + 1)
	# 후보 선택만 재현한다. 무효 카드를 쓰는 봇과 자동 턴 만료가 시험 손패를 바꾸지 않게 한다.
	controller.set_process(false)


func _stop() -> void:
	main.queue_free()
	await process_frame
	await process_frame
