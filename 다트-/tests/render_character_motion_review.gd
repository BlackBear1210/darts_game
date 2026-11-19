extends SceneTree
## 실제 F5 펍/PlayerView에서 검사한 최종 스킨 자세를 다각도로 촬영한다.
const Warmup = preload("res://app/asset_warmup.gd")
var _out: String
var _dir: String
var _main: Node
var _actor:PlayerView

func _hold_stage() -> void:
	if is_instance_valid(_actor):
		_actor.position=Vector3(-1.6,0,-0.3)
		_actor.rotation=Vector3.ZERO
		_actor.seated=false
		_actor.velocity=Vector3.ZERO
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var tag: String = args[0] if not args.is_empty() else "before"
	_out = ProjectSettings.globalize_path("res://../output/character_nude_base_20261116/motion_review_20261119/"+tag)
	_dir = _out.path_join("game_frames")
	DirAccess.make_dir_recursive_absolute(_dir)
	root.size=Vector2i(720,720)
	root.position=Vector2i(-20000,-20000)
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	_run.call_deferred()

func _run() -> void:
	_main=(load("res://app/main.tscn") as PackedScene).instantiate()
	_main.developer_mode=true
	root.add_child(_main)
	var backdrop: Node = _main.get("front").get("_backdrop")
	while backdrop != null and not backdrop.call("is_built"): await process_frame
	Warmup.start()
	while Warmup.poll(): await process_frame
	var session:=_main.get_node("NetworkSession") as NetworkSession
	session.host_room("모션 외형 검수",43839)
	session.enable_bots()
	session.set_ready(true)
	session.start_match()
	while _main.get_node_or_null("Game")==null: await process_frame
	var game:=_main.get_node("Game") as GameView
	await create_timer(0.5).timeout
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(1280,720)
	root.position=Vector2i(-20000,-20000)
	game.set_process(false)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	var actor:=game.actors[session.local_peer_id] as PlayerView
	_actor=actor
	process_frame.connect(_hold_stage)
	actor.wear({})
	actor.set_process(false)
	actor.position=Vector3(-1.6,0,-0.3)
	actor.rotation=Vector3.ZERO
	var model:=actor.get("_model") as Node3D
	var motion:=actor.get("_rig") as CharacterMotion
	var player:=model.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer
	var skeleton:=model.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	player.active=false
	(motion.get("_layer") as CharacterPoseLayer).active=false
	for n:Node3D in model.find_children("*", "Node3D",true,false):
		if str(n.name).contains("Card"): n.visible=false
	var camera:=Camera3D.new()
	camera.fov=40
	camera.cull_mask=0xfffff
	game.add_child(camera)
	camera.current=true
	_main.get_node("GameHUD").visible=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var plan: Array=JSON.parse_string(FileAccess.get_file_as_string(_out.path_join("render_plan.json")))
	var f:=FileAccess.open(_out.path_join("poses.bin"),FileAccess.READ)
	var captured: int = 0
	for rec:Dictionary in plan:
		var views:Array=rec.get("views",["front","side","back"])
		if FileAccess.file_exists(_dir.path_join(str(rec.file)+"_"+str(views[-1])+".png")): continue
		f.seek(int(rec.index)*skeleton.get_bone_count()*12*4)
		var values:PackedFloat32Array=f.get_buffer(skeleton.get_bone_count()*12*4).to_float32_array()
		for b in range(skeleton.get_bone_count()):
			var o:int=b*12
			var t:=Transform3D(Basis(Vector3(values[o],values[o+4],values[o+8]),Vector3(values[o+1],values[o+5],values[o+9]),Vector3(values[o+2],values[o+6],values[o+10])),Vector3(values[o+3],values[o+7],values[o+11]))
			skeleton.set_bone_global_pose(b,t)
		for view:String in views:
			var offset:=Vector3(0.75,1.15,-3.2) if view=="front" else Vector3(3.2,1.15,-0.15) if view=="side" else Vector3(-0.5,1.15,3.2)
			camera.global_position=actor.global_position+offset
			camera.look_at(actor.global_position+Vector3.UP*0.91)
			await process_frame
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png(_dir.path_join(str(rec.file)+"_"+view+".png"))==OK)
			captured += 1
		print("SHOT ",rec.file)
	f.close()
	session.leave_room()
	_main.queue_free()
	await process_frame
	print("PASS: actual game multi-view motion capture, new screenshots ",captured)
	quit()
