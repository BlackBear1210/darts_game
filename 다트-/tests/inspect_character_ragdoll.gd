extends SceneTree
## 실제 게임의 물리 쓰러지기/회복에서 최종 모디파이어 자세와 화면을 기록한다.
const Warmup=preload("res://app/asset_warmup.gd")
var _out:String
var _actor:PlayerView
var _skeleton:Skeleton3D
var _file:FileAccess
var _rows:Array=[]
var _case:String=""
var _clock:float=0.0
var _frames:int=0

func _hold_flags() -> void:
	if is_instance_valid(_actor):
		_actor.seated=false
		_actor.ready_pose=false
		_actor.taunting=false
		_actor.aiming=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	var tag:String=args[0] if not args.is_empty() else "ragdoll"
	_out=ProjectSettings.globalize_path("res://../output/character_nude_base_20261116/motion_review_20261119/"+tag)
	DirAccess.make_dir_recursive_absolute(_out.path_join("game_frames"))
	root.position=Vector2i(-20000,-20000)
	root.size=Vector2i(1280,720)
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	_run.call_deferred()

func _record() -> void:
	_frames+=1
	var values:=PackedFloat32Array()
	for i in range(_skeleton.get_bone_count()):
		var t:Transform3D=_skeleton.get_bone_global_pose(i)
		values.append_array(PackedFloat32Array([t.basis.x.x,t.basis.y.x,t.basis.z.x,t.origin.x,t.basis.x.y,t.basis.y.y,t.basis.z.y,t.origin.y,t.basis.x.z,t.basis.y.z,t.basis.z.z,t.origin.z]))
	_file.store_buffer(values.to_byte_array())
	_rows.append({"case":_case,"time":_clock,"mode":"physics","clip":"ragdoll" if _actor.fallen else "recovery"})

func _run() -> void:
	var main:Node=(load("res://app/main.tscn") as PackedScene).instantiate()
	main.developer_mode=true
	root.add_child(main)
	var backdrop:Node=main.get("front").get("_backdrop")
	while backdrop!=null and not backdrop.call("is_built"):await process_frame
	Warmup.start()
	while Warmup.poll():await process_frame
	var session:=main.get_node("NetworkSession") as NetworkSession
	session.host_room("쓰러지기 외형 검수",43849)
	session.enable_bots()
	session.set_ready(true)
	session.start_match()
	while main.get_node_or_null("Game")==null:await process_frame
	var game:=main.get_node("Game") as GameView
	await create_timer(0.5).timeout
	game.set_process(false)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	_actor=game.actors[session.local_peer_id] as PlayerView
	process_frame.connect(_hold_flags)
	_actor.wear({})
	_actor.seated=false
	_actor.position=Vector3(-1.6,0,-0.3)
	_actor.rotation=Vector3.ZERO
	_actor.velocity=Vector3.ZERO
	_actor.update_posture()
	var model:=_actor.get("_model") as Node3D
	_skeleton=model.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	var camera:=Camera3D.new()
	camera.fov=47
	camera.cull_mask=0xfffff
	game.add_child(camera)
	camera.current=true
	main.get_node("GameHUD").visible=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	_file=FileAccess.open(_out.path_join("poses.bin"),FileAccess.WRITE)
	var directions:Array=[Vector3(0,0,-2.0),Vector3(0,0,2.0),Vector3(-2.0,0,0),Vector3(2.0,0,0)]
	for index in range(directions.size()):
		_actor.position=Vector3(-1.6,0,-0.3)
		_actor.rotation=Vector3.ZERO
		await create_timer(1.0).timeout
		_case="fall_"+str(index)
		_actor.fall(directions[index])
		var ragdoll:SkeletonModifier3D=_actor.get("_ragdoll") as SkeletonModifier3D
		if not ragdoll.modification_processed.is_connected(_record):ragdoll.modification_processed.connect(_record)
		var age:float=0.0
		var shots:int=0
		while age<4.3:
			_clock=age
			var target:Vector3=ragdoll.center() if _actor.fallen else _actor.global_position+Vector3.UP*0.8
			camera.global_position=target+Vector3(1.6,1.3,-2.6)
			camera.look_at(target)
			await process_frame
			age+=root.get_process_delta_time()
			if _clock>shots*0.5:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(_out.path_join("game_frames/"+_case+"_"+str(shots)+".png"))
				shots+=1
		print("FALL_DONE ",index," recovered ",not _actor.fallen)
		assert(not _actor.fallen)
	_file.close()
	var f:=FileAccess.open(_out.path_join("poses.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"fps":20,"samples":_rows,"bones":_skeleton.get_bone_count()}))
	session.leave_room()
	main.queue_free()
	await process_frame
	print("PASS: four physical falls and recovery ",_rows.size())
	quit()
