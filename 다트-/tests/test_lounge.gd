extends SceneTree
## 새 F5 경로를 실제로 생성해 로비→착석→참여→카드→다트→재참여를 검증한다.
var main: Node
var game: GameView
var _shots: bool = false
var _output: String = "res://.godot/lounge_render"

func _initialize() -> void:
	_shots = OS.get_cmdline_user_args().has("--render")
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		printerr("FAIL: ", message)
		quit(1)
		assert(value, message)

func capture(name: String) -> void:
	if not _shots: return
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	root.get_texture().get_image().save_png(_output.path_join(name + ".png"))

func _run() -> void:
	main = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	check(main.get_node_or_null("Game") == null, "F5 starts at lobby, no automatic prototype")
	check(main.front.visible, "front door visible")
	await capture("01_lobby")
	main.front._create(false)
	await capture("02_create_room")
	main.open_settings()
	await capture("03_personal_settings")
	main.settings_panel._close()
	await process_frame
	var options := RoomSettings.new()
	options.social_lobby = true
	options.solo = true
	options.capacity = 1
	options.bot_count = 0
	options.win_mode = 1
	options.target_score = 50
	options.theme_id = 1
	main.session.host_room("테스터", 17629, options)
	await process_frame
	game = main._game
	check(game != null and game.actors.size() == 1, "solo no bots enters 3D waiting room")
	main.session.set_ready(true)
	check(main.session.room.phase == RoomState.Phase.LOBBY, "standing ready rejected")
	main.open_settings("room")
	await capture("04_host_settings")
	main.settings_panel._close()
	await process_frame
	# 매칭 중 공유 설정과 개발자 값을 조작하는 우회 시도를 검사한다.
	var proposed: Dictionary = options.to_snapshot()
	proposed.rounds = 8
	proposed.hit_stun = 3.0
	main.session._accept_settings(987, proposed)
	check(main.session.room.settings.rounds == 5, "non-host settings rejected")
	main.session.change_settings(proposed)
	check(main.session.room.settings.rounds == 8 and main.session.room.settings.hit_stun == 1.0, "normal host cannot change developer fields")
	game.force_seat(1)
	await physics_frame
	await capture("05_waiting_room")
	main.session.set_ready(true)
	await create_timer(0.25).timeout
	game = main._game
	check(game.controller.state.phase == MatchState.Phase.CARDS, "seated Enter auto starts card view after load barrier")
	check(game.is_seated(1), "loading transition keeps participants seated for cards")
	check(game.controller.state.players[0].hand.size() == 7, "seven cards dealt")
	await capture("06_card_view")
	# 2026-10-31: 카드 턴은 없다. 카드 확인 동안은 못 쓰고, 확인이 끝나면 바로 다트다.
	var me: MatchPlayer = game.controller.state.players[0]
	game.controller.request_card("select", 0)
	check(me.pending_card == -1, "cards locked while viewing")
	game.controller._phase_end = game.controller._now()
	await process_frame
	await process_frame
	me = game.controller.state.players[0]
	check(game.controller.state.phase == MatchState.Phase.AIMING, "card view leads straight to darts")
	# 다트 턴 중 카드: 미등록 발신자 거부 → 꺼내 들고 1.2초 전 사용 거부 → 사용하면 던지는 사람에게 바로 걸린다.
	var cards: RefCounted = game.controller.cards
	var catalog = cards.Catalog
	cards.rules.seats[0].slots[0] = cards.rules.new_card(catalog.type_of("number_shuffle"))
	cards.rules.seats[0].slots[1] = cards.rules.new_card(catalog.type_of("heavy_dart"))
	cards._sync()
	game.controller.cards.action(999, "select", 0)
	check(me.pending_card == -1, "unregistered card sender rejected")
	game.controller.request_card("select", 0)
	game.controller.request_card("use", 1)
	check(me.hand.size() == 7, "card needs the ready wait")
	await create_timer(1.3).timeout
	game.controller.request_card("use", 1)
	check(me.hand.size() == 6 and me.layout.numbers != BoardLayout.DEFAULT_NUMBERS, "shuffle card applies to the thrower at once")
	game.actors[1].seated = false
	game.actors[1].position = Vector3(0, 0, TableView.THROW_LINE_Z + 0.6)
	await physics_frame
	# 날아가는 다트에 쓴 궤적 카드(무거운 다트)는 꽂히는 자리를 바꾼다.
	game.controller.request_card("select", 0)
	await create_timer(1.3).timeout
	game.controller.submit_throw(Vector2.ZERO, 1.0)
	var aimed_y: float = float(game.controller._pending_hit.y)
	game.controller.request_card("use", 1)
	check(game.controller.state.phase == MatchState.Phase.FLIGHT and float(game.controller._pending_hit.y) < aimed_y - 0.3, "trajectory card redirects the flying dart")
	await create_timer(0.8).timeout
	var first: int = game.controller.state.players[0].score
	check(first < 50 and game.controller.state.phase == MatchState.Phase.AIMING, "redirected dart scores where it lands")
	game.controller.submit_throw(Vector2.ZERO, 1.0)
	await create_timer(0.8).timeout
	check(game.controller.state.phase == MatchState.Phase.FINISHED, "target score win ends game")
	check(game.controller.state.players[0].score == first + 50, "bull score")
	await capture("07_result")
	game.controller.restart()
	await create_timer(0.1).timeout
	game = main._game
	check(main.session.room.phase == RoomState.Phase.LOBBY, "rematch returns to map waiting")
	check(not main.session.room.players[0].is_ready, "rematch resets human readiness")
	check(game.controller.state.phase == MatchState.Phase.WAITING, "waiting controller does not auto start")
	# 소품 소유권·접근 거리 및 숨겨진 취기 상태.
	var lounge: Node = game.lounge
	var actor: PlayerView = game.actors[1]
	lounge._accept(999, "take", 0)
	check(lounge.held(999) == -1, "unregistered prop actor rejected")
	lounge._accept(1, "take", 0)
	check(lounge.held(1) == -1, "distant object grab rejected")
	main.session.leave_room()
	await process_frame
	check(main._game == null and main.front.visible, "leave returns to lobby")
	main.queue_free()
	await process_frame
	print("PASS: lobby, solo, seating authority, settings permissions, cards, target victory, rematch readiness, distance validation")
	quit()
