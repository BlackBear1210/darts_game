extends SceneTree
## 실제 앱을 D3D12로 렌더링한다. 비교 이미지는 같은 World3D의 봇 카메라에서 저장한다.

var _output: String = ""
var _main: Node
var _game: GameView
var _hud: GameHUD

func _initialize() -> void:
	_output = ProjectSettings.globalize_path("res://.godot/prototype_render")
	DirAccess.make_dir_recursive_absolute(_output)
	assert(ProjectSettings.get_setting("display/window/size/viewport_width") == 1920)
	assert(ProjectSettings.get_setting("display/window/size/viewport_height") == 1080)
	root.size = Vector2i(1920, 1080)
	call_deferred("_run")

func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(_output.path_join(label + ".png")) == OK)

func _bot_capture(label: String) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = _hud._viewport.get_texture().get_image()
	assert(picture.save_png(_output.path_join(label + ".png")) == OK)
	return picture

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)

func _run() -> void:
	# Windows의 창 테두리 크기 보정을 피하고 실제 1920×1080 픽셀도 확인한다.
	root.mode = Window.MODE_FULLSCREEN
	_main = (load("res://app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await create_timer(1).timeout
	_game = _main.get_node("Game") as GameView
	_hud = _main.get_node("GameHUD") as GameHUD
	# 실제 Input 이벤트가 WASD/점프/숙이기 폴링으로 이어지는지 확인한다.
	var local := _game.actors[1] as PlayerView
	# 시작 위치와 서 있는 상태를 유지한 채 E 입력 없이 실제 누름·해제로 발사한다.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await process_frame
	await process_frame
	assert(not local.seated and _game.throw_input.enabled and _hud._charge.visible)
	var aim_direction: Vector3 = (TableView.BOARD_CENTER - local.eye_position()).normalized()
	_game._yaw = atan2(-aim_direction.x, -aim_direction.z)
	_game._pitch = asin(aim_direction.y)
	await process_frame
	var standing_press: InputEventMouseButton = InputEventMouseButton.new()
	standing_press.button_index = MOUSE_BUTTON_LEFT
	standing_press.position = root.get_visible_rect().size * 0.5
	standing_press.pressed = true
	root.push_input(standing_press, true)
	await create_timer(0.85).timeout
	assert(_game.throw_input.charging and _game.throw_input.timing == 1)
	await _capture("00_standing_charged")
	var standing_release: InputEventMouseButton = standing_press.duplicate() as InputEventMouseButton
	standing_release.pressed = false
	root.push_input(standing_release, true)
	await create_timer(0.06).timeout
	assert(_game.controller.state.phase == MatchState.Phase.FLIGHT and not local.seated)
	await _capture("00_standing_flight")
	await create_timer(0.9).timeout
	assert(_game.controller.state.players[0].score == 50)
	assert(_game.controller.state.darts_left == 2 and _game.controller.state.turn_id == 1)
	var before: Vector3 = local.position
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var move_key := InputEventKey.new()
	move_key.keycode = KEY_W
	move_key.physical_keycode = KEY_W
	move_key.pressed = true
	Input.parse_input_event(move_key)
	await create_timer(0.25).timeout
	move_key.pressed = false
	Input.parse_input_event(move_key)
	assert(local.position.z < before.z - 0.2)
	assert(_game.camera.global_position.distance_to(local.eye_position()) < 0.1)
	var crouch_key := InputEventKey.new()
	crouch_key.keycode = KEY_CTRL
	crouch_key.physical_keycode = KEY_CTRL
	crouch_key.pressed = true
	Input.parse_input_event(crouch_key)
	_key(KEY_SPACE)
	await create_timer(0.15).timeout
	assert(local.crouched and local.position.y > 0.1)
	crouch_key.pressed = false
	Input.parse_input_event(crouch_key)
	await create_timer(0.8).timeout
	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2(50, -12)
	root.push_input(mouse, true)
	await create_timer(0.05).timeout
	assert(absf(_game.camera.rotation.y) > 0.05 and absf(_game.camera.rotation.x) > 0.01)
	_game._yaw = 0
	_game._pitch = 0
	_game.set_process_unhandled_input(false)
	await _capture("01_f5_room")
	# 사람 캐릭터가 봇 전방에 서고 숙일 때 보조 화면 픽셀이 달라지는지 확인한다.
	local.position = Vector3(1.5, 0, 2.7)
	await create_timer(0.15).timeout
	var standing := await _bot_capture("02_bot_sees_human_standing")
	_game.send_controls(Vector2.ZERO, 0, 0, false, true)
	await create_timer(0.1).timeout
	var crouching := await _bot_capture("03_bot_sees_human_crouching")
	assert(standing.get_data() != crouching.get_data())
	await _capture("04_crouch_in_bot_view")
	_key(KEY_F1)
	await create_timer(0.1).timeout
	assert(not _hud._preview.visible)
	await _capture("05_f1_hidden")
	_key(KEY_F1)
	_key(KEY_F2)
	await create_timer(0.1).timeout
	assert(_hud._bot_label.text.begins_with("봇 2"))
	await _capture("06_f2_next_bot")
	_key(KEY_F4)
	assert(_game.controller.state.active_player().display_name == "봇 2")
	await _capture("07_f4_bot_turn")
	# E 입력으로 자기 자리에 앉고 실제 마우스 입력을 눌렀다가 놓는다.
	local.position = TableView.SEATS[0] + Vector3(0, 0.01, 0.6)
	_game.controller.state.turn_index = 0
	_game.controller._begin_turn()
	_game.set_process_unhandled_input(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_key(KEY_E)
	await create_timer(0.15).timeout
	assert(local.seated and _game.throw_input.enabled)
	aim_direction = (TableView.BOARD_CENTER - local.eye_position()).normalized()
	_game._yaw = atan2(-aim_direction.x, -aim_direction.z)
	_game._pitch = asin(aim_direction.y)
	await process_frame
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = root.get_visible_rect().size * 0.5
	press.pressed = true
	# 다른 창으로 전환했다가 돌아온 뒤에는 첫 클릭으로 시점을 다시 잡아야 한다.
	_game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await process_frame
	await process_frame
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not _game.throw_input.enabled)
	root.push_input(press, true)
	await process_frame
	await process_frame
	assert(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and _game.throw_input.enabled)
	assert(not _game.throw_input.charging)
	# 마우스를 잡은 상태에서는 중앙의 Control이 GUI 이벤트를 소비해도 발사한다.
	var input_blocker: Control = Control.new()
	_hud._root.add_child(input_blocker)
	input_blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	input_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	root.push_input(press, true)
	await create_timer(0.85).timeout
	assert(_game.throw_input.charging and _game.throw_input.timing == 1)
	assert((_game.get_node("Camera/Hand") as Node3D).is_visible_in_tree())
	assert(_hud._cross.get_global_rect().get_center().distance_to(root.get_visible_rect().size * 0.5) < 1.0)
	await _capture("08_seated_charged")
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	root.push_input(release, true)
	input_blocker.queue_free()
	await create_timer(0.06).timeout
	assert(_game.controller.state.phase == MatchState.Phase.FLIGHT)
	assert(not (_game.get_node("Camera/Hand") as Node3D).visible)
	var dart: DartView = _game.get_node("Darts").get_child(0) as DartView
	dart.set_physics_process(false)
	_game.controller.set_process(false)
	await _capture("09_dart_in_flight")
	var with_dart: Image = root.get_texture().get_image()
	var visual: Node3D = dart.get_node("Visual") as Node3D
	var screen: Vector2 = _game.camera.unproject_position(visual.global_position)
	var region: Rect2i = Rect2i(Vector2i(screen) - Vector2i(100, 100), Vector2i(200, 200))
	dart.hide()
	await _capture("09_hidden_dart_comparison")
	var without_dart: Image = root.get_texture().get_image()
	var visible_pixels: int = 0
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			if with_dart.get_pixel(x, y) != without_dart.get_pixel(x, y):
				visible_pixels += 1
	assert(visible_pixels >= 80, "발사한 다트가 화면에서 구분되어야 합니다.")
	print("PASS: flying dart changes ", visible_pixels, " pixels in its screen region")
	dart.show()
	dart.set_physics_process(true)
	_game.controller.set_process(true)
	await create_timer(0.9).timeout
	assert(_game.controller.state.players[0].score == 100)
	await _capture("10_dart_hit")
	_game.controller.state.phase = MatchState.Phase.FINISHED
	_game.controller.state.players[1].score = 100
	_game.controller.changed.emit()
	await create_timer(0.1).timeout
	await _capture("11_shared_rank_results")
	assert(root.get_texture().get_image().get_size() == Vector2i(1920, 1080))
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(960, 540)
	await create_timer(0.1).timeout
	await _capture("12_laptop_layout")
	_main.get_node("NetworkSession").leave_room()
	await create_timer(0.1).timeout
	await _capture("13_normal_menu")
	_main.queue_free()
	await process_frame
	print("PASS: 1920x1080 rendering, focus-loss click recapture, captured click through GUI, shared-world bot view, WASD/Space/Ctrl/mouse/F1/F2/F4/E, charge/release/flight/bull score, results/960x540/menu. Screenshots: ", _output)
	quit()
