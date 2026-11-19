extends SceneTree
## 실제 F5 앱의 PlayerView/CharacterMotion을 통해 승인 캐릭터를 촬영한다.

const Warmup = preload("res://app/asset_warmup.gd")

var _main: Node
var _game: GameView
var _actor: PlayerView
var _tour: Camera3D
var _out: String
var _states: Dictionary = {}

func _initialize() -> void:
	_out = ProjectSettings.globalize_path("res://../output/character_nude_base_20261116/game_apply_20261119")
	if OS.get_cmdline_user_args().has("motion_review"):
		_out = ProjectSettings.globalize_path("res://../output/character_nude_base_20261116/motion_review_20261119/checked/live")
		DirAccess.make_dir_recursive_absolute(_out)
	root.size = Vector2i(1280, 720)
	root.position = Vector2i(-20000, -20000)
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	process_frame.connect(_keep_input_safe)
	_run.call_deferred()

func _keep_input_safe() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(_actor):
		_actor.ready_pose = false
		_actor.taunting = false
		_actor.pitch = 0.0
		_actor.head_scale = 1.0
		_actor.drink_pose = 0.0
		_actor.seat_lean = 0.0
		var motion: CharacterMotion = _actor.get("_rig") as CharacterMotion
		if motion != null:
			motion.holding_cards = false

func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(_out.path_join(name + ".png")) == OK)
	var motion: CharacterMotion = _actor.get("_rig") as CharacterMotion
	_states[name] = {"clip": motion.clip, "seated": _actor.seated, "position": var_to_str(_actor.position), "model": PlayerLook.CHARACTER_SCENE}
	print("SHOT ", name, " ", motion.clip)

func _look(offset: Vector3, height: float) -> void:
	_tour.global_position = _actor.global_position + offset
	_tour.look_at(_actor.global_position + Vector3.UP * height)
	_tour.current = true
	_main.get_node("GameHUD").visible = false

func _run() -> void:
	_main = (load("res://app/main.tscn") as PackedScene).instantiate()
	_main.developer_mode = true
	root.add_child(_main)
	var backdrop: Node = _main.get("front").get("_backdrop")
	while backdrop != null and not backdrop.call("is_built"):
		await process_frame
	Warmup.start()
	while Warmup.poll():
		await process_frame
	var session: NetworkSession = _main.get_node("NetworkSession") as NetworkSession
	session.host_room("승인 캐릭터 검토", 43829)
	assert(session.is_host())
	session.enable_bots()
	session.set_ready(true)
	session.start_match()
	var until: int = Time.get_ticks_msec() + 15000
	while _main.get_node_or_null("Game") == null and Time.get_ticks_msec() < until:
		await process_frame
	_game = _main.get_node("Game") as GameView
	await create_timer(1.0).timeout
	_game.set_process_unhandled_input(false)
	_game.set_process(false)
	_game.set_physics_process(false)
	_actor = _game.actors[session.local_peer_id] as PlayerView
	_actor.wear({})
	_actor.seated = false
	_actor.crouched = false
	_actor.position = Vector3(-1.6, 0, -0.3)
	_actor.rotation.y = 0.0
	_actor.velocity = Vector3.ZERO
	_actor.update_posture()
	_tour = Camera3D.new()
	_tour.fov = 43
	_tour.cull_mask = 0xfffff
	_game.add_child(_tour)
	await create_timer(2.3).timeout
	_look(Vector3(1.25, 1.20, -2.65), 0.95)
	await _capture("01_game_character_standing")
	# 게임의 실제 이동 함수를 호출해 이동 속도에 따라 Walk로 바뀌는지 확인한다.
	for i in range(40):
		await physics_frame
		_actor.simulate(1.0 / 60.0, {"move": Vector2(0, -0.25), "yaw": 0.0, "pitch": 0.0})
	_look(Vector3(1.25, 1.20, -2.65), 0.95)
	assert((_actor.get("_rig") as CharacterMotion).clip == CharacterMotion.WALK)
	await _capture("02_game_character_walking")
	_actor.velocity = Vector3.ZERO
	_game.force_seat(session.local_peer_id)
	await create_timer(2.3).timeout
	assert((_actor.get("_rig") as CharacterMotion).clip == CharacterMotion.SEATED)
	_look(Vector3(-1.7, 1.30, -1.95), 1.0)
	await _capture("03_game_character_seated")
	_tour.global_position = Vector3(3.4, 2.7, 8.4)
	_tour.look_at(TableView.TABLE_CENTER + Vector3.UP * 1.0)
	await _capture("04_game_table_players")
	# 실제 F5 카메라/손도 새 에셋으로 초기화되는지 확인한다.
	_game._yaw = _actor.rotation.y
	_game._pitch = 0.0
	_game._process(1.0 / 60.0)
	_game.camera.current = true
	_main.get_node("GameHUD").visible = true
	await _capture("05_game_first_person")
	var f := FileAccess.open(_out.path_join("game_capture_states.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(_states, "\t"))
	session.leave_room()
	await create_timer(0.1).timeout
	_main.queue_free()
	await process_frame
	print("PASS: approved character in actual F5 standing, movement Walk, seated, room and first person")
	quit()
