extends SceneTree
## 1인칭 오른팔(art/characters/first_person_arm.gd)만 띄워 찍는다. 디자인 조정용.
##   & $godot --path . --script res://tests/render_fp_arm.gd
## 결과: .godot/fp_arm/*.png (Git 제외)
##
## 경기 전체를 띄우는 render_first_idea 는 한 번 도는 데 오래 걸려 팔 각도를 맞추기 어렵다.
## game/game.tscn의 실제 Camera/Hand/HeldDart를 꺼내 몇 초 만에 찍는다.

const FirstPersonArm = preload("res://art/characters/first_person_arm.gd")
## 게임(GameView._animate_hand)과 같은 던지기 몸짓 곡선 — 여기서는 몇 장면만 멈춰 찍는다.
const FirstPersonThrow = preload("res://art/characters/first_person_throw.gd")
const GAME_SCENE: PackedScene = preload("res://game/game.tscn")

var _output: String = ""
var _hand_at: Vector3


func _initialize() -> void:
	_output = ProjectSettings.globalize_path("res://.godot/fp_arm")
	DirAccess.make_dir_recursive_absolute(_output)
	root.size = Vector2i(1280, 720)
	_run.call_deferred()


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	# 팔이 또렷하게 보이도록 단색 배경 + 정면광(펍 조명과 다르지만 각도 맞추기에는 이게 낫다).
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("2a3340")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("c8c8c8")
	env.environment.ambient_light_energy = 0.9
	world.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -30, 0)
	world.add_child(key)
	# tscn의 Transform3D 숫자를 Basis(Vector3, ...)로 옮겨 적으면 행과 열이 뒤바뀐다.
	# 실제 게임의 Camera/Hand/HeldDart를 꺼내 써서 수동 재현값을 없앤다.
	var game := GAME_SCENE.instantiate()
	var camera := game.get_node("Camera") as Camera3D
	game.remove_child(camera)
	game.free()
	camera.position = Vector3.ZERO
	camera.current = true
	world.add_child(camera)
	var hand := camera.get_node("Hand") as Node3D
	_hand_at = hand.position
	hand.show()
	var dart := hand.get_node("HeldDart") as DartView
	dart.paint(PlayerLook.COLORS[0])
	var arm := FirstPersonArm.new()
	arm.name = "FirstPersonHand"
	arm.seat = 0
	arm.dart_grip = dart.transform
	hand.add_child(arm)
	await process_frame
	await process_frame
	await _shot(camera, "01_from_camera")
	# 완전 충전 자세: 얼굴 쪽으로 당기고 손목을 젖힌다(pull = 1).
	# 이때 어깨·몸통이 화면에 들어오면 안 된다 — 가장 들키기 쉬운 자세라 꼭 같이 찍는다.
	var base := Transform3D(Basis.IDENTITY, _hand_at)
	hand.transform = FirstPersonThrow.pose(base, arm.elbow, 1.0)
	await _shot(camera, "01c_charged")
	# 놓은 뒤 몸짓: 팔을 다 뻗고 손목을 꺾은 순간 → 팔로 스루(떨어지는 중) → 다음 다트를 쥐고 올라오는 중.
	for frame: Array in [["01d_release", 0.8], ["01e_follow_through", 0.55], ["01f_reload", 0.2]]:
		var kick: float = frame[1]
		hand.transform = FirstPersonThrow.pose(base, arm.elbow, 0.0, kick, 1.0)
		arm.animate_grip(FirstPersonThrow.fingers_open(kick), 1.0)
		arm.swing(FirstPersonThrow.forearm(kick), FirstPersonThrow.wrist(kick))
		dart.visible = FirstPersonThrow.dart_in_hand(kick, true)
		await _shot(camera, frame[0])
	hand.transform = base
	arm.animate_grip(false, 1.0)
	arm.swing(0.0, 0.0)
	dart.show()
	# 쥔 모양 확대: 눈과 거의 같은 자리에서 손을 바라본다(손가락이 다트를 감쌌는지 본다).
	await _aside(world, camera, Vector3(0.02, 0.02, 0.0), "01b_grip_closeup", 24.0)
	# 옆·위에서도 찍어 몸통이 카메라 뒤에 있는지, 팔이 어디로 뻗는지 본다.
	await _aside(world, camera, Vector3(1.6, 0.3, 0.6), "02_from_right")
	await _aside(world, camera, Vector3(0.0, 1.8, 0.4), "03_from_above")
	# 참고 그림(다트를 손가락 위에 얹고 엄지로 누름)과 같은 쪽 — 몸 안쪽에서 손 옆모습을 본다.
	await _aside(world, camera, _hand_at + Vector3(-0.3, 0.02, -0.04), "03b_inner_side", 30.0)
	# 크기 카드: 다트만 자루 가운데를 축으로 커지고 손은 그대로(굵은 자루 바깥으로 살짝 비킴).
	var dart_base: Transform3D = dart.transform
	dart.transform = FirstPersonArm.held_dart(dart_base, DartView.LARGE_SIZE)
	arm.hold_large(true)
	await _shot(camera, "05_large_dart")
	await _aside(world, camera, Vector3(0.02, 0.02, 0.0), "05b_large_closeup", 24.0)
	dart.transform = dart_base
	arm.hold_large(false)
	# 힘 카드: 손을 떠난 다트 뒤 바람 줄기(비행 중간에 멈춰 내 화면·옆에서 찍는다).
	hand.hide()
	var flying := (load("res://game/dart/dart.tscn") as PackedScene).instantiate() as DartView
	world.add_child(flying)
	flying.paint(PlayerLook.COLORS[0])
	flying.powered = true
	flying.fly(camera.global_transform * _hand_at, camera.global_transform * Vector3(0.0, 0.05, -2.4), 0.4)
	await create_timer(0.12).timeout
	flying.set_physics_process(false)
	await _shot(camera, "06_power_wind")
	var side := Camera3D.new()
	world.add_child(side)
	side.global_position = flying.global_position + Vector3(1.2, 0.25, 0.3)
	side.look_at(flying.global_position + Vector3(0, 0, 0.4))
	side.current = true
	await _shot(side, "06b_power_wind_side")
	side.queue_free()
	camera.current = true
	flying.queue_free()
	hand.show()
	# 가리키는 손은 투척 손과 별도로 남아 있던 옛 도형 모델의 교체 경로다.
	hand.hide()
	var gestures := preload("res://game/card_round/flow/gestures.gd").new()
	var ctx := preload("res://game/card_round/flow/round_context.gd").new()
	ctx.camera = camera
	gestures._ctx = ctx
	gestures.build()
	gestures._fp_hand.position = gestures.FP_POSITION
	gestures._fp_hand.show()
	await _shot(camera, "04_pointing")
	print("PASS: 1인칭 팔 화면 → ", _output)
	quit()


## 보조 카메라를 원점(= 쥔 다트) 쪽으로 돌려 찍는다. 팔이 어떻게 놓였는지 구조를 본다.
func _aside(world: Node3D, main: Camera3D, at: Vector3, label: String, fov: float = 65.0) -> void:
	var view := Camera3D.new()
	view.fov = fov
	world.add_child(view)
	view.global_position = main.global_position + at
	view.look_at(main.global_position + main.global_basis * _hand_at)
	view.current = true
	await _shot(view, label)
	view.current = false
	main.current = true
	view.queue_free()


func _shot(_camera: Camera3D, label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(_output.path_join(label + ".png")) == OK)
	print("SHOT ", label)
