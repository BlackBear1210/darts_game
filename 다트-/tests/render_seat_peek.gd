extends SceneTree
## 앉은 시점 · 엿보기(A·D) · 마시기 · 유리병 깨짐을 실제 창으로 띄워 확인한다(2026-10-31).
##   godot --path . --script res://tests/render_seat_peek.gd
## 화면은 .godot/seat_peek_render/*.png 에 남는다(Git 제외). 창 모드라 assert 가 실패하면 창이 멈출 수 있다 → 시간 제한을 두고 돌린다.
## 사람 1(나, 1번 자리 ●) + 봇 3. 카드 확인 단계를 길게 붙잡아 두고 찍는다.
var main: Node
var game: GameView
var _output: String = "res://.godot/seat_peek_render"


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


## 실제 키보드처럼 물리 키를 누르거나 뗀다(GameView 는 Input.is_physical_key_pressed 로 A·D 를 읽는다).
func press(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)


func _run() -> void:
	main = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	var options := RoomSettings.new()
	options.social_lobby = true
	options.solo = true
	options.bot_count = 3
	options.theme_id = 0
	main.session.host_room("테스터", 17641, options)
	await create_timer(0.8).timeout
	main._game.force_seat(1)
	await create_timer(0.3).timeout
	main.session.set_ready(true)
	var until: float = Time.get_ticks_msec() / 1000.0 + 10.0
	while Time.get_ticks_msec() / 1000.0 < until and (main._game == null or main._game.controller.state.phase != MatchState.Phase.CARDS):
		await process_frame
	game = main._game
	check(game != null and game.controller.state.phase == MatchState.Phase.CARDS, "경기 카드 단계 진입")
	# 카드 확인 단계를 붙잡아 둔다(찍는 동안 다트로 넘어가지 않게).
	game.controller._phase_end = game.controller._now() + 999.0
	game.force_seat(1)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await create_timer(1.0).timeout
	var me: PlayerView = game.actors[1]
	check(me.seated, "내가 앉았다")
	check(absf(me.eye_position().y - PlayerView.SEATED_EYE_HEIGHT) < 0.01, "앉은 눈높이 = 캐릭터 눈 높이")
	check(game.seat_cards != null, "테이블 매트 카드가 있다")
	await capture("01_seated_view")

	# 왼쪽(A)으로 엿보기 → 왼쪽 자리 카드가 앞면으로 펼쳐진다.
	press(KEY_A, true)
	await create_timer(0.8).timeout
	var left: int = game.seat_cards.peeked_seat(me)
	check(left >= 0, "A 로 기울이면 옆자리를 엿본다")
	await capture("02_peek_left")
	press(KEY_A, false)
	await create_timer(0.6).timeout
	check(game.seat_cards.peeked_seat(me) == -1, "떼면 바로 돌아온다")
	press(KEY_D, true)
	await create_timer(0.8).timeout
	var right: int = game.seat_cards.peeked_seat(me)
	check(right >= 0 and right != left, "D 로 기울이면 반대쪽 옆자리를 엿본다")
	await capture("03_peek_right")
	press(KEY_D, false)
	await create_timer(0.6).timeout

	# 내가 병을 들고 한 모금(1인칭).
	var lounge: Node3D = game.lounge
	var bottle: int = -1
	for index in range(lounge.objects.size()):
		if lounge.objects[index].kind == "bottle" and bottle < 0: bottle = index
	lounge.objects[bottle].holder = 1
	lounge.request("drink")
	await create_timer(0.55).timeout
	check(me.drink_pose > 0.0, "마시는 몸짓 진행 중")
	await capture("04_drink_first_person")
	await create_timer(1.2).timeout
	lounge.objects[bottle].holder = 0

	# 오른쪽 옆 봇이 마시는 모습(3인칭): 그 봇 쪽을 본다.
	var bot: PlayerView = null
	for view: PlayerView in game.actors.values():
		if view.identity.seat == right: bot = view
	var other: int = -1
	for index in range(lounge.objects.size()):
		if lounge.objects[index].kind == "bottle" and index != bottle and other < 0: other = index
	lounge.objects[other].holder = bot.identity.peer_id
	var to_bot: Vector3 = bot.eye_position() - me.eye_position()
	game._yaw = atan2(-to_bot.x, -to_bot.z)
	game._pitch = -0.05
	lounge.objects[other].drank = lounge.now()
	await create_timer(0.6).timeout
	await capture("05_bot_drinking")
	lounge.objects[other].holder = 0

	# 유리병 깨짐: 일어나서 앞 바닥을 내려다보고 그 위 1m 에서 병을 깬다.
	game._accept_seat(1)
	await create_timer(0.4).timeout
	var forward: Vector3 = Basis(Vector3.UP, game._yaw) * Vector3.FORWARD
	var spot: Vector3 = TableView.clamp_floor(me.global_position + forward * 1.6)
	game._pitch = -0.62
	await create_timer(0.2).timeout
	lounge._break(bottle, spot + Vector3.UP * 1.0, forward * 3.0 + Vector3.DOWN * 4.0, 1, null, "시험")
	await create_timer(0.12).timeout
	await capture("06_glass_burst")
	await create_timer(1.6).timeout
	await capture("07_glass_rest")
	await create_timer(0.2).timeout
	print("PASS: seated eye height, A/D peek reveals neighbour cards, drink pose, glass shards — screenshots in ", ProjectSettings.globalize_path(_output))
	quit()
