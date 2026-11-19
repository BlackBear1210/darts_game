extends SceneTree
## 가져온 실제 게임 메시/스킨과 모션·게임 보정 결과를 삼각형 검사용으로 기록한다.
## 수정 전후 동일한 정점·면·바인드 데이터인지도 별도로 비교한다.

const FPS: float = 24.0
const EMOTES = preload("res://art/characters/motion_emotes.gd")
var _out: String
var _model: Node3D
var _motion: CharacterMotion
var _skeleton: Skeleton3D
var _player: AnimationPlayer
var _layer: CharacterPoseLayer
var _poses: FileAccess
var _records: Array = []
var _asset: PackedScene

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var tag: String = args[0] if not args.is_empty() else "before"
	_out = ProjectSettings.globalize_path("res://../output/character_nude_base_20261116/motion_review_20261119/" + tag)
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()

func _matrix(t: Transform3D) -> Array:
	return [t.basis.x.x, t.basis.y.x, t.basis.z.x, t.origin.x, t.basis.x.y, t.basis.y.y, t.basis.z.y, t.origin.y, t.basis.x.z, t.basis.y.z, t.basis.z.z, t.origin.z]

func _attach() -> void:
	_model = PlayerLook.character(0)
	root.add_child(_model)
	_motion = CharacterMotion.new(_model)
	_player = _model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	_skeleton = _model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_layer = _motion.get("_layer") as CharacterPoseLayer
	if OS.get_cmdline_user_args().has("physics_probe"):
		_layer.pose_safety=preload("res://art/characters/character_pose_safety.gd").new(_skeleton,_model,true)
	_layer.active = false
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL

func _record(name: String, time: float, mode: String) -> void:
	var values := PackedFloat32Array()
	for i in range(_skeleton.get_bone_count()):
		values.append_array(PackedFloat32Array(_matrix(_skeleton.get_bone_global_pose(i))))
	_poses.store_buffer(values.to_byte_array())
	_records.append({"case": name, "time": time, "mode": mode, "clip": _motion.clip})

func _geometry() -> void:
	var file := FileAccess.open(_out.path_join("geometry.bin"), FileAccess.WRITE)
	var meshes: Array = []
	for node: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		if not node.visible: continue
		var binds: Array = []
		var names: Array = []
		for i in range(node.skin.get_bind_count()):
			binds.append(_matrix(node.skin.get_bind_pose(i)))
			names.append(_skeleton.find_bone(node.skin.get_bind_name(i)))
		for surface in range(node.mesh.get_surface_count()):
			var a: Array = node.mesh.surface_get_arrays(surface)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var points := PackedFloat32Array()
			for p in v: points.append_array(PackedFloat32Array([p.x,p.y,p.z]))
			var sections: Array = []
			for data: PackedFloat32Array in [points, PackedFloat32Array(Array(a[Mesh.ARRAY_BONES])), a[Mesh.ARRAY_WEIGHTS] as PackedFloat32Array, PackedFloat32Array(Array(a[Mesh.ARRAY_INDEX]))]:
				sections.append([file.get_position(),data.size()])
				file.store_buffer(data.to_byte_array())
			meshes.append({"part":str(node.name),"surface":surface,"vertices":v.size(),"sections":sections,"binds":binds,"bone_indices":names})
	file.close()
	var bones: Array = []
	for i in range(_skeleton.get_bone_count()): bones.append({"name":_skeleton.get_bone_name(i),"parent":_skeleton.get_bone_parent(i),"rest":_matrix(_skeleton.get_bone_global_rest(i))})
	var header := FileAccess.open(_out.path_join("geometry.json"), FileAccess.WRITE)
	header.store_string(JSON.stringify({"meshes":meshes,"bones":bones}))
	header.close()

func _step(speed: float, posture: int, air: bool, aim: bool, pitch: float = 0.0) -> void:
	# AnimationPlayer이 매 프레임 기본 자세를 쓰고 같은 CharacterPoseLayer가 보정을 얹는다.
	_motion.animate(1.0/FPS,speed,posture,air,pitch,aim)
	_player.advance(1.0/FPS)
	_layer._process_modification()

func _reset() -> void:
	_model.free()
	_attach()

func _run() -> void:
	_asset = load(PlayerLook.CHARACTER_SCENE) as PackedScene
	_attach()
	_geometry()
	if OS.get_cmdline_user_args().has("geometry_only"):
		_model.free()
		print("PASS: imported geometry recorded")
		quit()
		return
	_poses = FileAccess.open(_out.path_join("poses.bin"), FileAccess.WRITE)
	if OS.get_cmdline_user_args().has("probe") or OS.get_cmdline_user_args().has("physics_probe") or OS.get_cmdline_user_args().has("bake_original"):
		var base_tag:String="ragdoll_verified" if OS.get_cmdline_user_args().has("physics_probe") else "before"
		var args := OS.get_cmdline_user_args()
		var source_arg := args.find("physics_probe") + 1
		if source_arg > 0 and source_arg < args.size():
			base_tag = args[source_arg]
		var base:String=ProjectSettings.globalize_path("res://../output/character_nude_base_20261116/motion_review_20261119/"+base_tag)
		var original:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(base.path_join("poses.json")))
		var audit:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(base.path_join("collision_audit.json")))
		var f:=FileAccess.open(base.path_join("poses.bin"),FileAccess.READ)
		var probes:Array=audit.worst_by_case.values()
		if OS.get_cmdline_user_args().has("probe"):
			var second_path:String=ProjectSettings.globalize_path("res://../output/character_nude_base_20261116/motion_review_20261119/verified/collision_audit.json")
			var second:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(second_path))
			probes.append_array(second.worst_by_case.values())
		if OS.get_cmdline_user_args().has("physics_probe"):
			probes=[]
			for i in range(original.samples.size()):
				var row:Dictionary=original.samples[i].duplicate()
				row.index=i
				row.total=1
				probes.append(row)
		if OS.get_cmdline_user_args().has("bake_original"):
			probes=[]
			for i in range(original.samples.size()):
				if original.samples[i].mode!="clip":continue
				var row:Dictionary=original.samples[i].duplicate()
				row.index=i
				row.total=1
				probes.append(row)
		for row:Dictionary in probes:
			if row.total==0:continue
			f.seek(int(row.index)*_skeleton.get_bone_count()*12*4)
			var values:PackedFloat32Array=f.get_buffer(_skeleton.get_bone_count()*12*4).to_float32_array()
			for b in range(_skeleton.get_bone_count()):
				var o:int=b*12
				_skeleton.set_bone_global_pose(b,Transform3D(Basis(Vector3(values[o],values[o+4],values[o+8]),Vector3(values[o+1],values[o+5],values[o+9]),Vector3(values[o+2],values[o+6],values[o+10])),Vector3(values[o+3],values[o+7],values[o+11])))
			if str(row.case).to_lower().ends_with("crouch_walk"):
				var thighs:Array=[_skeleton.find_bone("thigh.L"),_skeleton.find_bone("thigh.R")]
				var turns:Array=[]
				for thigh:int in thighs:turns.append(_skeleton.get_bone_global_pose(thigh).basis.get_rotation_quaternion())
				_layer._turn(_skeleton,_skeleton.find_bone("hips"),Vector3.RIGHT,0.18)
				for ti in range(thighs.size()):
					var parent:int=_skeleton.get_bone_parent(thighs[ti])
					_skeleton.set_bone_pose_rotation(thighs[ti],_skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion().inverse()*turns[ti])
			_layer.pose_safety.apply()
			_record(row.case,row.time,row.mode)
		f.close()
		_poses.close()
		var output:=FileAccess.open(_out.path_join("poses.json"),FileAccess.WRITE)
		output.store_string(JSON.stringify({"fps":FPS,"samples":_records,"bones":_skeleton.get_bone_count()}))
		_model.free()
		print("PASS: problem poses ",_records.size())
		quit()
		return
	for clip: String in _player.get_animation_list():
		if clip == "RESET": continue
		var length: float = _player.get_animation(clip).length
		var steps: int = maxi(1,ceili(length*FPS))
		_player.play(clip,0.0)
		for i in range(steps+1):
			var t: float = minf(i/FPS,length)
			_player.seek(t,true)
			_player.advance(0.0)
			if OS.get_cmdline_user_args().has("bake_safety"):
				_layer.pose_safety.apply()
			_record(clip,t,"clip")
		print("SAMPLED_CLIP ",clip," ",steps+1)
	# 실제 팔/머리 레이어, 앉은 감정표현 및 상태 전환을 포함한다.
	var cases: Array = ["aim", "throw", "cards", "cheer", "point", "drink", "look_up", "look_down", "peek_left", "peek_right", "crouch_walk", "jump", "sit_stand"]
	for e in range(EMOTES.CLIPS.size()): cases.append("emote_"+str(e))
	if OS.get_cmdline_user_args().has("clips_only"): cases.clear()
	for seated: bool in [false,true]:
		for name: String in cases:
			_reset()
			var posture: int = CharacterMotion.Posture.SEAT if seated else CharacterMotion.Posture.STAND
			# 2초 앉기를 끝낸 안정 상태에서 팔 동작/감정표현을 시작한다.
			for i in range(60): _step(0.0,posture,false,false)
			var duration: float = 3.0
			if name.begins_with("emote_"):
				var e: int = name.trim_prefix("emote_").to_int()
				_motion.play_emote(e)
				duration = _player.get_animation(EMOTES.CLIPS[e]).length+0.4
			var steps: int = ceili(duration*FPS)
			for i in range(steps+1):
				var t: float = i/FPS
				_motion.holding_cards = name == "cards"
				_motion.cheering = name == "cheer"
				_motion.pointing = name == "point"
				_motion.drinking = clampf(t/3.0,0.0,1.0) if name == "drink" else 0.0
				_motion.lean = sin(t/3.0*PI)*(-0.42 if name == "peek_left" else 0.42) if name.begins_with("peek_") else 0.0
				_motion.head_tilt = _motion.lean*0.2/0.42
				var pitch: float = (0.9 if name == "look_up" else -0.9) if name.begins_with("look_") else 0.0
				if name == "throw" and i == 24: _motion.play_throw()
				var p: int = CharacterMotion.Posture.CROUCH if name == "crouch_walk" else posture
				if name == "sit_stand": p = CharacterMotion.Posture.SEAT if t < 1.0 else CharacterMotion.Posture.STAND
				_step(0.5 if name == "crouch_walk" else 0.0,p,name == "jump" and t < 1.2,name == "aim" or (name == "throw" and t<1.0),pitch)
				_record(("seat_" if seated else "stand_")+name,t,"runtime")
			print("SAMPLED_RUNTIME ",seated," ",name)
	_poses.close()
	var records := FileAccess.open(_out.path_join("poses.json"), FileAccess.WRITE)
	records.store_string(JSON.stringify({"fps":FPS,"samples":_records,"bones":_skeleton.get_bone_count()}))
	records.close()
	_model.free()
	print("PASS: motion geometry sampled ",_records.size())
	quit()
