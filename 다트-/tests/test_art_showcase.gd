extends SceneTree
## 아트 쇼케이스(art/showcase/showcase.tscn) 자동 검사. 아스트라 원본의 --smoke / --ui-smoke / --capture 를 옮겼다.
##   & $godot --headless --path . --script res://tests/test_art_showcase.gd
##   & $godot --path . --script res://tests/test_art_showcase.gd -- --render     (실제 화면 4장 촬영)
##   & $godot --path . --script res://tests/test_art_showcase.gd -- --benchmark  (시점별 180프레임 측정)
## 촬영·측정 결과는 .godot/art_showcase_render/ 에 저장한다(Git 제외 폴더).

const SHOWCASE_SCENE := "res://art/showcase/showcase.tscn"
const OUTPUT_FOLDER := "res://.godot/art_showcase_render"
const VIEW_NAMES: Array[String] = ["room", "throw", "cast", "table"]
## 비행(최대 충전 약 0.14초, 충전 0 약 0.3초)이 끝날 때까지 기다리는 시간.
const LANDING_WAIT := 0.4
## 왼쪽 버튼을 누르고 있는 시간. 충전 시간(0.8초)보다 길게 → 최대 충전 = 조준점 그대로.
const FULL_CHARGE_HOLD := 0.95

var showcase: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	showcase = load(SHOWCASE_SCENE).instantiate()
	root.add_child(showcase)
	current_scene = showcase
	await process_frame
	var args := OS.get_cmdline_user_args()
	if args.has("--render"):
		await _capture_views()
	elif args.has("--benchmark"):
		await _benchmark_views()
	else:
		await _smoke()
		await _ui_smoke()
		print("PASS: art showcase — double card, bull, T20, miss, weak-charge drop, 3-dart cap, next visit, mid-flight reset, strafe/look aim, four cameras, hold-to-charge, right-click cancel, A/D strafe, GUI click isolation, focused-button shortcut, credits input lock")
	# 효과음 재생 객체(AudioStreamPlaybackWAV)는 오디오 스레드가 다음 믹스 때 놓는다.
	# headless 는 프레임이 매우 빨라 프레임 대기로는 부족하다 → 실제 시간 0.2초를 기다린다.
	showcase.queue_free()
	await create_timer(0.2).timeout
	quit()


## 규칙 검사: 2배 카드+불=100, T20=60, 캐비닛 밖=0, 약한 충전은 아래로 빗나감, 3발 제한, 다음 차례,
## 비행 중 초기화, 좌우 이동·시선에 따른 조준점, 카메라 4개.
func _smoke() -> void:
	var center: Vector3 = showcase.BOARD_CENTER
	showcase.set_view(1, true)
	assert(showcase.aim_point().is_equal_approx(center))
	# A/D 로 옆으로 가면 조준점도 그만큼 옆으로(정면 유지), 마우스 시선을 왼쪽(+yaw)으로 돌리면 조준점이 왼쪽으로.
	showcase.strafe = 0.3
	showcase.camera.transform = showcase.throw_transform()
	var strafed: Vector3 = showcase.aim_point()
	assert(is_equal_approx(strafed.x, 0.3) and is_equal_approx(strafed.y, center.y))
	showcase.look = Vector2(0.1, 0.05)
	showcase.camera.transform = showcase.throw_transform()
	assert(showcase.aim_point().x < 0.3 and showcase.aim_point().y > center.y)
	showcase.look = Vector2.ZERO
	showcase.strafe = 0.0
	showcase.camera.transform = showcase.throw_transform()
	showcase.arm_card()
	showcase.throw_at(center)
	await create_timer(LANDING_WAIT).timeout
	assert(showcase.total == 100 and showcase.hits.size() == 1 and showcase.card_used and not showcase.card_armed)
	# 위로 0.103m = 트리플 링 안쪽(20 구역) → T20.
	showcase.throw_at(center + Vector3(0, 0.103, 0))
	await create_timer(LANDING_WAIT).timeout
	assert(showcase.total == 160 and showcase.hits.size() == 2)
	showcase.throw_at(center + Vector3(0.3, 0, 0))
	await create_timer(LANDING_WAIT).timeout
	assert(showcase.total == 160 and showcase.hits.size() == 3)
	showcase.throw_at(center)
	assert(showcase.hits.size() == 3 and not showcase.busy)
	showcase.next_visit()
	assert(showcase.visit == 2 and showcase.hits.is_empty() and showcase.total == 160 and not showcase.card_used)
	# 충전 0 은 실제 경기 식대로 약 0.25m 아래로 떨어진다 → 점수 링(반지름 0.17m) 밖 = 0점.
	showcase.throw_at(center, 0.0)
	await create_timer(LANDING_WAIT).timeout
	var weak: Node3D = showcase.darts.get_child(showcase.darts.get_child_count() - 1)
	assert(showcase.total == 160 and showcase.hits.size() == 1 and showcase.hits[0] == 0 and weak.global_position.y < center.y - 0.2)
	showcase.throw_at(center)
	showcase.reset_session()
	await create_timer(LANDING_WAIT).timeout
	assert(showcase.total == 0 and showcase.hits.is_empty() and not showcase.busy)
	for i in range(showcase.VIEWS.size()):
		showcase.set_view(i, true)
		assert(showcase.camera.position.distance_to(showcase.VIEWS[i][0]) < 0.001)


## 실제 입력 검사: Viewport 에 마우스·키 이벤트를 넣어 버튼/투척/단축키가 사람 조작처럼 동작하는지 본다.
func _ui_smoke() -> void:
	var hud: CanvasLayer = showcase.hud
	await process_frame
	_click(hud.view_buttons[1].get_global_rect().get_center())
	await create_timer(0.8).timeout
	assert(showcase.current_view == 1)
	var board: Vector2 = showcase.camera.unproject_position(showcase.BOARD_CENTER)
	# 충전 중 오른쪽 버튼 = 취소. 그 뒤 왼쪽을 놓아도 다트가 나가지 않는다.
	_mouse(board, MOUSE_BUTTON_LEFT, true)
	await create_timer(0.3).timeout
	assert(showcase.charging and showcase.charge > 0.2 and hud.charge_bar.visible)
	_mouse(board, MOUSE_BUTTON_RIGHT, true)
	assert(not showcase.charging and showcase.charge == 0.0 and "취소" in hud.result_label.text)
	_mouse(board, MOUSE_BUTTON_LEFT, false)
	await create_timer(LANDING_WAIT).timeout
	assert(showcase.hits.is_empty() and not showcase.busy and not hud.charge_bar.visible)
	_click(hud.card_button.get_global_rect().get_center())
	assert(showcase.card_armed and showcase.hits.is_empty())
	await _hold(board, FULL_CHARGE_HOLD)
	await create_timer(LANDING_WAIT).timeout
	assert(showcase.total == 100 and showcase.hits.size() == 1)
	for remaining in range(2):
		await _hold(board, FULL_CHARGE_HOLD)
		await create_timer(LANDING_WAIT).timeout
	assert(showcase.hits.size() == 3)
	# A/D(물리 키): 투척선 위를 좌우로 움직인다. 카메라와 조준점이 같이 옮겨 간다.
	_physical_key(KEY_D, true)
	await create_timer(0.25).timeout
	_physical_key(KEY_D, false)
	await process_frame
	assert(showcase.strafe > 0.1 and showcase.camera.position.x > 0.1 and showcase.aim_point().x > 0.1)
	_physical_key(KEY_A, true)
	await create_timer(1.2).timeout
	_physical_key(KEY_A, false)
	await process_frame
	assert(is_equal_approx(showcase.strafe, -showcase.STRAFE_LIMIT))
	# 버튼이 키보드 포커스를 잡고 있어도 Space 단축키가 동작해야 한다.
	hud.view_buttons[1].grab_focus()
	_key(KEY_SPACE)
	assert(showcase.visit == 2 and showcase.hits.is_empty())
	# GUI 버튼 클릭은 GUI 가 먹는다 — 시점 버튼을 눌러도 다트가 나가면 안 된다.
	_click(hud.view_buttons[2].get_global_rect().get_center())
	assert(showcase.current_view == 2 and showcase.hits.is_empty())
	_key(KEY_R)
	assert(showcase.total == 0 and showcase.hits.is_empty())
	hud.credits.show()
	_key(KEY_2)
	assert(showcase.current_view == 2)
	_key(KEY_ESCAPE)
	assert(not hud.credits.visible)


func _click(screen_position: Vector2) -> void:
	for pressed: bool in [true, false]:
		_mouse(screen_position, MOUSE_BUTTON_LEFT, pressed)


## 왼쪽 버튼을 seconds 동안 누르고 있다가 놓는다(충전 투척).
func _hold(screen_position: Vector2, seconds: float) -> void:
	_mouse(screen_position, MOUSE_BUTTON_LEFT, true)
	await create_timer(seconds).timeout
	_mouse(screen_position, MOUSE_BUTTON_LEFT, false)


func _mouse(screen_position: Vector2, button: MouseButton, pressed: bool) -> void:
	var viewport := showcase.get_viewport()
	var motion := InputEventMouseMotion.new()
	motion.position = screen_position
	viewport.push_input(motion, true)
	var click := InputEventMouseButton.new()
	click.position = screen_position
	click.button_index = button
	click.pressed = pressed
	viewport.push_input(click, true)


## Input 싱글턴의 물리 키 상태까지 바꾼다(is_physical_key_pressed 로 읽는 A/D 이동용).
func _physical_key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)


func _key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	showcase.get_viewport().push_input(event)


## 네 시점 실제 렌더 화면을 PNG 로 저장한다(사람이 열어서 확인하는 용도).
func _capture_views() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_FOLDER))
	showcase.capture_mode = true
	for i in range(VIEW_NAMES.size()):
		showcase.set_view(i, true)
		showcase.hud.aim_dot.hide()
		await create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		var path := "%s/%02d_%s.png" % [OUTPUT_FOLDER, i + 1, VIEW_NAMES[i]]
		var error := root.get_texture().get_image().save_png(path)
		assert(error == OK)
		print("CAPTURE ", path)


## 시점별 평균 FPS·p95 프레임 시간·그리기 호출 수. 짧은 표본이라 최소 사양 인증값이 아니다.
func _benchmark_views() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_FOLDER))
	var report: Array[Dictionary] = []
	for i in range(VIEW_NAMES.size()):
		showcase.set_view(i, true)
		await create_timer(1.2).timeout
		var samples: Array[float] = []
		var previous := Time.get_ticks_usec()
		for frame in range(180):
			await process_frame
			var now := Time.get_ticks_usec()
			samples.append((now - previous) / 1000.0)
			previous = now
		samples.sort()
		var sum := 0.0
		for sample in samples:
			sum += sample
		var entry := {"view": VIEW_NAMES[i], "average_fps": 1000.0 / (sum / samples.size()), "p95_frame_ms": samples[171],
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
		report.append(entry)
		print("BENCHMARK ", JSON.stringify(entry))
	var file := FileAccess.open(OUTPUT_FOLDER + "/benchmark.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine": Engine.get_version_info().string, "adapter": RenderingServer.get_video_adapter_name(), "results": report}, "  "))
