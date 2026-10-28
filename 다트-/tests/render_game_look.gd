extends SceneTree
## F5 실제 경기 화면을 여러 각도에서 찍는다(디자인 피드백용 · 팀 공유용). 화면이 있는 상태(D3D12)로 실행한다.
##   & $godot --path . --script res://tests/render_game_look.gd
## 결과: 저장소 루트의 output/game_look/*.png (+ 투척 장면 낱장 throw_frames/ — GIF 로 묶을 수 있다)
## 실제 F5 와 같은 장면(app/main.tscn, 개발자 모드 = 사람 1 + 봇 3)을 띄우고, 사람이 3발을 던지는 동안 찍는다.
## 촬영 중에는 전체 화면이 되고 마우스가 잡힌다(약 20초).

var _output: String = ""
var _main: Node
var _game: GameView
var _hud: GameHUD
var _tour: Camera3D


func _initialize() -> void:
	_output = ProjectSettings.globalize_path("res://").path_join("../output/game_look").simplify_path()
	DirAccess.make_dir_recursive_absolute(_output.path_join("throw_frames"))
	root.size = Vector2i(1920, 1080)
	_run.call_deferred()


func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(_output.path_join(label + ".png")) == OK)
	print("SHOT ", label)


## 관찰 카메라로 바꿔 찍는다(HUD 숨김). 몸짓이 자리 잡도록 잠깐 기다린다.
func _look(from: Vector3, at: Vector3, label: String) -> void:
	_tour.global_position = from
	_tour.look_at(at)
	_tour.current = true
	_hud.visible = false
	await create_timer(0.3).timeout
	await _capture(label)


## 플레이어 1인칭 화면으로 돌아온다(HUD 보임).
func _first_person() -> void:
	_game.camera.current = true
	_hud.visible = true


func _aim_at_board(actor: PlayerView) -> void:
	var direction := (TableView.BOARD_CENTER - actor.eye_position()).normalized()
	_game._yaw = atan2(-direction.x, -direction.z)
	_game._pitch = asin(direction.y)


## 사람 차례에 한 발 던지고 꽂힐 때까지 기다린다. aim = 과녁 반지름 1 기준 조준점(최대 충전이라 그대로 꽂힌다).
func _throw(aim: Vector2) -> void:
	assert(_game.controller.state.phase == MatchState.Phase.AIMING)
	_game.controller.submit_throw(aim, 1.0)
	await create_timer(1.2).timeout


func _run() -> void:
	root.mode = Window.MODE_FULLSCREEN
	_main = (load("res://app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await create_timer(1.0).timeout
	_game = _main.get_node("Game") as GameView
	_hud = _main.get_node("GameHUD") as GameHUD
	# 실제 마우스가 시점을 흔들거나 캐릭터를 움직이지 않게 입력을 끈다(촬영용).
	_game.set_process_unhandled_input(false)
	_tour = Camera3D.new()
	_tour.fov = 62
	_game.add_child(_tour)
	var local := _game.actors[1] as PlayerView
	# 2026-10-28: 라운지에서는 못 던진다. 1인칭 투척 장면은 투척선 뒤에서 찍는다.
	local.position = Vector3(0, 0, TableView.THROW_LINE_Z + 0.5)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_aim_at_board(local)
	await create_timer(0.4).timeout
	assert(_game.throw_input.enabled)
	await _capture("01_first_person_standing")
	# 1발: 불(정중앙). 손을 떠난 직후를 1인칭으로 찍는다.
	_game.controller.submit_throw(Vector2.ZERO, 1.0)
	await create_timer(0.07).timeout
	await _capture("02_first_person_dart_flight")
	await create_timer(1.15).timeout
	# 2발: T20. 던지는 사람 오른쪽 앞에서 낱장으로 찍는다(던지기 몸짓 + 다트 비행). GIF 로 묶어 공유한다.
	_tour.global_position = local.global_position + Vector3(1.0, 1.75, -1.9)
	_tour.look_at(local.global_position + Vector3(0, 1.2, 0))
	_tour.current = true
	_hud.visible = false
	await create_timer(0.3).timeout
	_game.controller.submit_throw(Vector2(0, 0.605), 1.0)
	for i in range(30):
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(_output.path_join("throw_frames/%02d.png" % i))
	await create_timer(1.0).timeout
	assert(_game.controller.state.find_player(1).score == 110)
	await _look(Vector3(0.6, 2.75, -5.6), Vector3(0, 2.75, -7.3), "03_board_two_darts")
	_first_person()
	await create_timer(0.1).timeout
	await _throw(Vector2(-0.35, 0.8))
	# 방 둘러보기(HUD 숨김).
	await _look(Vector3(7.4, 3.8, 9.6), Vector3(-1.5, 0.9, -1.2), "04_overview_from_entrance")
	await _look(Vector3(4.4, 1.7, 9.0), Vector3(0, 0.8, 5.1), "05_table_and_seats")
	await _look(Vector3(-2.1, 1.65, 2.1), Vector3(-7.0, 1.15, 6.0), "06_bar_and_bartender")
	await _look(Vector3(7.0, 2.6, -3.5), Vector3(-0.9, 1.6, -7.0), "07_lane_and_fence")
	await _look(Vector3(1.8, 3.6, -6.9), Vector3(0, 0.8, 4.5), "08_room_from_board")
	# 봇 차례: 봇이 오른팔을 들고 조준하는 모습.
	var bot := _game.actors.values().filter(func(actor: PlayerView) -> bool: return actor.identity.is_bot)[0] as PlayerView
	_game.controller.developer_bot_turn(bot.identity.peer_id)
	await _look(bot.global_position + Vector3(1.6, 1.2, -1.6), bot.global_position + Vector3(0, 1.0, 0), "09_bot_aiming")
	# 사람이 자리에 앉아 던지는 1인칭 화면.
	local.position = TableView.SEATS[0] + Vector3(0, 0.01, 0.6)
	_game.controller.state.turn_index = 0
	_game.controller._begin_turn()
	_game._accept_seat(1)
	assert(local.seated)
	_aim_at_board(local)
	_first_person()
	await create_timer(0.4).timeout
	await _capture("10_first_person_seated")
	_main.get_node("NetworkSession").leave_room()
	await create_timer(0.1).timeout
	_main.queue_free()
	await process_frame
	print("PASS: game look screenshots → ", _output)
	quit()
