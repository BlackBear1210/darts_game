extends SceneTree
## 실제 경기 Scene에서 입력 취소, 비행 종점과 미리보기의 일치를 확인한다.

var _requests: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var config: DartConfig = preload("res://game/dart/default_dart.tres")
	var start: Vector3 = Vector3(0.16, 1.25, 1.2)
	var target: Vector3 = Vector3(0, 1.35, 0)
	for duration: float in [0.05, 0.45, 1.0]:
		var velocity: Vector3 = config.initial_velocity(start, target, duration)
		assert(config.position_at(start, velocity, duration).is_equal_approx(target))
		var halfway: Vector3 = config.position_at(start, velocity, duration * 0.5)
		assert(is_equal_approx(halfway.y, start.lerp(target, 0.5).y + config.gravity * duration * duration / 8.0))
	assert(config.impact_position(Vector2.ZERO, 0.5) == Vector2.ZERO)
	assert(config.impact_position(Vector2.ZERO, 0.0).is_equal_approx(Vector2(-0.07, 0.075)))
	assert(config.impact_position(Vector2.ZERO, 1.0).is_equal_approx(Vector2(0.07, 0.075)))

	var room: RoomState = RoomState.new()
	room.match_id = 1
	room.add_player(1, "방장")
	room.add_player(2, "참가자")
	room.phase = RoomState.Phase.PLAYING
	var game: GameView = (load("res://game/game.tscn") as PackedScene).instantiate() as GameView
	root.add_child(game)
	game.configure(room, 1)
	game.controller.set_process(false)
	game.controller.config.transition_seconds = 0.01
	game.controller.state.phase = MatchState.Phase.AIMING
	assert(not (game.actors[1] as PlayerView).seated)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	game.controller.state.turn_id = 1
	game.controller.changed.emit()
	await create_timer(0.1).timeout
	game.controller.state.phase = MatchState.Phase.AIMING
	await process_frame
	await process_frame
	var input: DartThrowController = game.throw_input
	input.set_process(false)
	input.enabled = true
	# 경기 요청 대신 입력만 관찰하여 시간 기반 경기 진행과 분리한다.
	input.throw_requested.disconnect(game.controller.submit_throw)
	input.throw_requested.connect(func(_aim: Vector2, _timing: float) -> void: _requests += 1)
	var screen: Vector2 = game.camera.unproject_position(game.table.board.global_position)
	assert(input.aim_at(screen).is_equal_approx(Vector2.ZERO))
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = screen
	press.pressed = true
	var release: InputEventMouseButton = press.duplicate() as InputEventMouseButton
	release.pressed = false
	input._unhandled_input(release)
	assert(_requests == 0)
	input._unhandled_input(press)
	input._process(config.charge_seconds * 0.5)
	assert(is_equal_approx(input.timing, 0.5))
	input._unhandled_input(release)
	input._unhandled_input(release)
	assert(_requests == 1)
	input._unhandled_input(press)
	input._process(config.charge_seconds * 4)
	assert(input.timing == 1.0)
	input.enabled = false
	input.enabled = true
	input._unhandled_input(release)
	assert(_requests == 1 and not input.charging and input.timing == 0.0)
	input._unhandled_input(press)
	input.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	input._unhandled_input(release)
	assert(_requests == 1 and not input.charging)
	input._unhandled_input(press)
	input._input(release)
	input._unhandled_input(release)
	assert(_requests == 2 and not input.charging)
	# 충전 중 오른쪽 버튼은 이번 투척을 취소한다. 그 뒤 왼쪽을 놓아도 발사하지 않는다.
	var cancels: Array[int] = [0]
	input.charge_cancelled.connect(func() -> void: cancels[0] += 1)
	var right: InputEventMouseButton = press.duplicate() as InputEventMouseButton
	right.button_index = MOUSE_BUTTON_RIGHT
	input._unhandled_input(press)
	input._process(config.charge_seconds * 0.5)
	input._input(right)
	assert(not input.charging and input.timing == 0.0 and cancels[0] == 1)
	input._unhandled_input(release)
	assert(_requests == 2)
	input._input(right)
	assert(cancels[0] == 1)
	game.camera.look_at(game.camera.global_position + Vector3.UP, Vector3.FORWARD)
	assert(not input.aim_at(root.get_visible_rect().size * 0.5).is_finite())
	game.camera.look_at(game.table.board.global_position)

	var preview: TrajectoryPreview = game.get_node("TrajectoryPreview") as TrajectoryPreview
	preview.show_trajectory(start, target, 0.45, config)
	assert(preview.visible and preview.mesh.get_surface_count() == 1)
	var vertices: PackedVector3Array = preview.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert(preview.to_global(vertices[0]).is_equal_approx(start))
	assert(preview.to_global(vertices[-1]).is_equal_approx(target))
	game.controller.state.phase = MatchState.Phase.FLIGHT
	await process_frame
	await process_frame
	preview.hide()
	assert(not preview.visible)
	var dart: DartView = (load("res://game/dart/dart.tscn") as PackedScene).instantiate() as DartView
	root.add_child(dart)
	dart.fly(start, target, 0.05, true, Vector3(0.16, -0.1, -0.32))
	assert(dart.global_position == start)
	assert((dart.get_node("Visual") as Node3D).global_position.distance_to(start) > 0.1)
	await create_timer(0.12).timeout
	assert(dart.global_position.is_equal_approx(target) and dart.velocity == Vector3.ZERO)
	assert((dart.get_node("Visual") as Node3D).position.is_zero_approx())
	await create_timer(0.05).timeout
	assert(dart.global_position.is_equal_approx(target) and not dart.is_physics_processing())
	dart.fly(start, target, 0.05, false)
	await create_timer(0.12).timeout
	assert(is_instance_valid(dart) and dart.global_position.distance_to(target) > 0.01)
	await create_timer(config.miss_lifetime).timeout
	assert(not is_instance_valid(dart))
	game.queue_free()
	await process_frame
	print("PASS: ballistic endpoints/arc, timing boundaries, mouse release, disable/focus/right-click cancellation, standalone preview endpoints, hit stop and miss cleanup")
	quit()
