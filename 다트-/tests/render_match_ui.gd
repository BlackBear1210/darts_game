extends SceneTree
## 경기 화면 UI 를 실제 창으로 띄워 확인한다(2026-10-31 저녁).
##   위 가운데 라운드 표시(카드 → 다트 → 다음 카드 충전) · 테이블 카드 앞면 · 봇 왼손 카드 부채 · F 로 카드 쓰기 · T 감정표현.
##   godot --path . --script res://tests/render_match_ui.gd
## 화면은 .godot/match_ui_render/*.png 에 남는다(Git 제외). 창 모드라 시간 제한을 두고 돌린다.
var main: Node
var game: GameView
var _output: String = "res://.godot/match_ui_render"


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	if not value:
		printerr("FAIL: ", message)
		quit(1)


func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	root.get_texture().get_image().save_png(_output.path_join(name + ".png"))


func press(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)


## 카메라가 peer 의 캐릭터 가슴 쪽을 보게 한다.
func look_at_actor(peer: int, height: float = 1.0) -> void:
	var me: PlayerView = game.actors[game.controller.local_peer_id]
	var target: PlayerView = game.actors[peer]
	var to: Vector3 = target.global_position + Vector3.UP * height - me.eye_position()
	game._yaw = atan2(-to.x, -to.z)
	game._pitch = atan2(to.y, Vector2(to.x, to.z).length())


func _run() -> void:
	main = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	var options := RoomSettings.new()
	options.social_lobby = true
	options.solo = true
	options.bot_count = 3
	options.theme_id = 0
	main.session.host_room("테스터", 17642, options)
	await create_timer(0.8).timeout
	main._game.force_seat(1)
	await create_timer(0.3).timeout
	main.session.set_ready(true)
	var until: float = Time.get_ticks_msec() / 1000.0 + 10.0
	while Time.get_ticks_msec() / 1000.0 < until and (main._game == null or main._game.controller.state.phase != MatchState.Phase.CARDS):
		await process_frame
	game = main._game
	check(game != null and game.controller.state.phase == MatchState.Phase.CARDS, "카드 단계 진입")
	game.force_seat(1)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# 카드 충전 라운드: 테이블 가운데 덱이 섞이고 한 장씩 나눠 준다(2026-10-31 늦은 밤, deck_show.gd).
	check(game.deck_show != null and game.deck_show.is_playing(), "카드 단계에 덱 섞기 연출이 돈다")
	await create_timer(0.7).timeout
	await capture("00_deck_shuffle")
	await create_timer(0.5).timeout
	var banner: Control = game.lounge_hud.get("_banner")
	check(banner != null and banner.visible, "위 가운데 라운드 표시가 보인다")
	check(game.held_cards != null, "봇 왼손 카드 부채 노드")
	await capture("01_cards_phase")
	# 연출이 카드 확인 시간(5초) 안에 끝나고 매트 카드가 모두 보인다.
	var show_until: float = Time.get_ticks_msec() / 1000.0 + 4.5
	while Time.get_ticks_msec() / 1000.0 < show_until and game.deck_show.is_playing():
		await process_frame
	check(not game.deck_show.is_playing(), "덱 연출이 카드 확인 시간 안에 끝난다")
	await create_timer(0.3).timeout
	var shown: int = 0
	for card in game.seat_cards.get_children():
		if card is Node3D and (card as Node3D).visible: shown += 1
	check(shown == 4 * CardHandRules.HAND_LIMIT, "매트 카드 28장이 모두 보인다(%d)" % shown)
	check(game.deck_show.pile_size() == game.deck_show.DECK_REST, "덱이 가운데 다시 쌓였다")
	await capture("01b_cards_dealt")

	# 다트 라운드까지 넘긴다(카드 확인 시간을 끝낸다).
	game.controller._phase_end = game.controller._now()
	until = Time.get_ticks_msec() / 1000.0 + 8.0
	while Time.get_ticks_msec() / 1000.0 < until and game.controller.state.phase != MatchState.Phase.AIMING:
		await process_frame
	check(game.controller.state.phase == MatchState.Phase.AIMING, "다트 라운드 진입")
	game.controller._phase_end = game.controller._now() + 999.0
	await create_timer(0.6).timeout
	await capture("02_dart_round")

	# 오른쪽 옆 봇이 카드를 꺼내 들면 손 위로 올라온다.
	var bot: MatchPlayer = null
	for player in game.controller.state.players:
		if player.is_bot and bot == null: bot = player
	game.controller.cards._bot_plans.clear()
	game.controller.cards.action(bot.peer_id, "select", 0)
	await create_timer(0.5).timeout
	check(game.controller.state.find_player(bot.peer_id).pending_slot == 0, "봇이 카드를 꺼내 들었다")
	look_at_actor(bot.peer_id, 0.9)
	await create_timer(0.5).timeout
	await capture("03_bot_holding_cards")

	# 내가 카드를 꺼내 들고 F 로 쓴다(준비 1.2초 뒤).
	var me: MatchPlayer = game.controller.state.find_player(game.controller.local_peer_id)
	var before: int = me.hand.size()
	game._yaw += 0.0
	game._pitch = -0.47
	game.controller.request_card("select", 1)
	await create_timer(1.5).timeout
	await capture("04_my_card_lifted")
	press(KEY_F, true)
	await create_timer(0.1).timeout
	press(KEY_F, false)
	await create_timer(0.4).timeout
	me = game.controller.state.find_player(game.controller.local_peer_id)
	check(me.hand.size() == before - 1, "F 로 꺼내 든 카드를 썼다")

	# T 감정표현: 피자판 미리보기 → 봇 머리 위 말풍선.
	game.emotes.wheel.preview(1)
	await create_timer(0.3).timeout
	await capture("05_emote_wheel")
	game.emotes.wheel.close()
	game.emotes._accept(bot.peer_id, 0)
	look_at_actor(bot.peer_id, 1.6)
	await create_timer(0.35).timeout
	await capture("06_bot_emote")
	print("PASS: round banner, face-up mat cards, bot hand fan + lifted card, F card use, T emote wheel + bubble — screenshots in ", ProjectSettings.globalize_path(_output))
	quit()
