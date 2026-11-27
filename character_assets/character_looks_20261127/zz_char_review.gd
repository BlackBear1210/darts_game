extends SceneTree
## 확인용 촬영·측정 도구(저장소에 남기지 않음). 게임 코드 그대로(PlayerLook.character + PlayerOutfit.dress) 캐릭터를 입혀 찍는다.
##   godot --path . --script res://tests/zz_char_review.gd -- <mode> <out_dir> [캐릭터...]  (창 모드 — --headless 면 사진이 안 찍힌다)
## 모드: stats = 만드는 시간·정점·면 수 · shots = 전신·얼굴·모자 · turn = 12방향 전신·얼굴 · hands = 오른손 8방향 · hats = 모자 6종 · glasses = 안경 3종
const PlayerOutfit = preload("res://art/characters/player_outfit.gd")
const CharacterLooks = preload("res://art/characters/character_looks.gd")

var _out: String = ""
var _mode: String = "stats"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0: _mode = args[0]
	_out = args[1] if args.size() > 1 else ProjectSettings.globalize_path("res://.godot/char_game")
	DirAccess.make_dir_recursive_absolute(_out)
	root.size = Vector2i(320, 240)
	_run.call_deferred()


func _run() -> void:
	match _mode:
		"stats": await _stats()
		"shots": await _shots(["base", "jun", "som", "on"], true)
		"som": await _shots(["som", "base"], false)
		"one": await _shots([OS.get_cmdline_user_args()[2]], true)
		"hats": await _hats(["jun", "som", "on"])
		"turn": await _turn(Array(OS.get_cmdline_user_args().slice(2)))
		"hands": await _hands(Array(OS.get_cmdline_user_args().slice(2)))
		"glasses": await _glasses(["jun", "som", "on"])
	print("DONE ", _mode)
	quit()


func _dressed(index: int, extra: Dictionary = {}) -> Node3D:
	var model: Node3D = PlayerLook.character(0)
	var look: Dictionary = {"character": index}
	look.merge(extra, true)
	PlayerOutfit.dress(model, look)
	return model


# ---------- 측정 ----------

func _stats() -> void:
	var base: Node3D = PlayerLook.character(0)
	root.add_child(base)
	await process_frame
	var lines: Array[String] = []
	# 원본 메시: 면·정점·블렌드 셰이프·LOD
	for part_name: String in CharacterLooks.PART_NAMES:
		var mi := base.find_child(part_name, true, false) as MeshInstance3D
		var mesh := mi.mesh as ArrayMesh
		var verts: int = 0
		var lods: Array = []
		for s in range(mesh.get_surface_count()):
			verts += mesh.surface_get_array_len(s)
			var info: Dictionary = RenderingServer.mesh_get_surface(mesh.get_rid(), s)
			lods.append((info.get("lods", []) as Array).size())
		lines.append("BASE %s surfaces=%d verts=%d blend=%d lods=%s shadow_mesh=%s" % [part_name, mesh.get_surface_count(), verts, mesh.get_blend_shape_count(), lods, mesh.shadow_mesh != null])
	var t0: int = Time.get_ticks_usec()
	CharacterLooks._data_resource()
	lines.append("DATA load_ms=%.1f" % ((Time.get_ticks_usec() - t0) / 1000.0))
	for index in range(1, CharacterLooks.IDS.size()):
		var id: String = CharacterLooks.IDS[index]
		var total: float = 0.0
		var per: Array[String] = []
		for part_name: String in CharacterLooks.PART_NAMES:
			var mi := base.find_child(part_name, true, false) as MeshInstance3D
			var t1: int = Time.get_ticks_usec()
			var built: ArrayMesh = CharacterLooks.part_mesh(id, part_name, mi.get_meta(CharacterLooks.BASE_META) if mi.has_meta(CharacterLooks.BASE_META) else mi.mesh)
			var ms: float = (Time.get_ticks_usec() - t1) / 1000.0
			total += ms
			var lods: Array = []
			for s in range(built.get_surface_count()):
				lods.append((RenderingServer.mesh_get_surface(built.get_rid(), s).get("lods", []) as Array).size())
			per.append("%s=%.1fms(lods %s)" % [part_name, ms, lods])
		# 처음 입히기(조각 메시 포함) · 두 번째 입히기(캐시)
		var t2: int = Time.get_ticks_usec()
		var model := _dressed(index)
		var first_ms: float = (Time.get_ticks_usec() - t2) / 1000.0
		root.add_child(model)
		var t3: int = Time.get_ticks_usec()
		var model2 := _dressed(index)
		var second_ms: float = (Time.get_ticks_usec() - t3) / 1000.0
		model2.free()
		var verts: int = 0
		var surfaces: int = 0
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			var m := (mi as MeshInstance3D).mesh
			if m == null or not (mi as MeshInstance3D).visible:
				continue
			surfaces += m.get_surface_count()
			for s in range(m.get_surface_count()):
				verts += (m as ArrayMesh).surface_get_array_len(s) if m is ArrayMesh else 0
		var parts := model.find_child(CharacterLooks.PARTS_NODE, true, false) as MeshInstance3D
		lines.append("CHAR %s build_total=%.1fms [%s] dress_first=%.1fms dress_cached=%.1fms surfaces=%d verts=%d parts_verts=%d parts_layers=%d" % [id, total, ", ".join(per), first_ms, second_ms, surfaces, verts, (parts.mesh as ArrayMesh).surface_get_array_len(0) if parts != null else 0, parts.layers if parts != null else -1])
		model.queue_free()
	# 기본(승인 모델 그대로) 입혔을 때
	var plain := _dressed(0)
	var verts0: int = 0
	var surf0: int = 0
	for mi in plain.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh
		if m == null or not (mi as MeshInstance3D).visible:
			continue
		surf0 += m.get_surface_count()
		for s in range(m.get_surface_count()):
			verts0 += (m as ArrayMesh).surface_get_array_len(s) if m is ArrayMesh else 0
	lines.append("CHAR base surfaces=%d verts=%d" % [surf0, verts0])
	plain.free()
	# 갈아입기: 솜 → 기본 → 온 → 기본 (조각이 남지 않는지)
	var swap := _dressed(2)
	root.add_child(swap)
	PlayerOutfit.undress(swap)
	PlayerOutfit.dress(swap, {"character": 0})
	await process_frame
	var left_after_base: int = swap.find_children(CharacterLooks.PARTS_NODE, "", true, false).size()
	PlayerOutfit.undress(swap)
	PlayerOutfit.dress(swap, {"character": 3, "hat": 2, "shirt": 4})
	await process_frame
	var after_on: int = swap.find_children(CharacterLooks.PARTS_NODE, "", true, false).size()
	PlayerOutfit.undress(swap)
	await process_frame
	var after_undress: int = swap.find_children(CharacterLooks.PARTS_NODE, "", true, false).size()
	var body_back: bool = (swap.find_child("Body", true, false) as MeshInstance3D).mesh == (base.find_child("Body", true, false) as MeshInstance3D).mesh
	lines.append("SWAP parts_after_base=%d parts_after_on=%d parts_after_undress=%d body_back_to_base=%s" % [left_after_base, after_on, after_undress, body_back])
	# 옛 저장(캐릭터 칸 없음) → 기본
	lines.append("SANITIZE old=%s bad=%s" % [PlayerOutfit.sanitize({"hat": 1}).get("character"), PlayerOutfit.sanitize({"character": 99}).get("character")])
	# 미리 만들기 줄: 몇 번 부르면 끝나는가 · 가장 긴 한 번
	CharacterLooks._meshes.clear()
	var steps: int = 0
	var worst: float = 0.0
	var t5: int = Time.get_ticks_usec()
	while true:
		var t4: int = Time.get_ticks_usec()
		var more: bool = CharacterLooks.prewarm_step()
		var took: float = (Time.get_ticks_usec() - t4) / 1000.0
		worst = maxf(worst, took)
		if took > 3.0:
			lines.append("  step %d %.1fms" % [steps, took])
		steps += 1
		if not more or steps > 2000:
			break
		await process_frame
	lines.append("PREWARM frames=%d worst_main_thread_ms=%.1f total_ms=%.0f meshes=%d" % [steps, worst, (Time.get_ticks_usec() - t5) / 1000.0, CharacterLooks._meshes.size()])
	# 미리 만든 메시와 바로 만든 메시가 같은가(스레드 결과 검증): 솜 상의 정점 비교
	var top_base: ArrayMesh = (base.find_child("Top_01", true, false) as MeshInstance3D).get_meta(CharacterLooks.BASE_META, (base.find_child("Top_01", true, false) as MeshInstance3D).mesh)
	var warmed: ArrayMesh = CharacterLooks.part_mesh("som", "Top_01", top_base)
	CharacterLooks._meshes.clear()
	var direct: ArrayMesh = CharacterLooks.part_mesh("som", "Top_01", top_base)
	lines.append("PREWARM_SAME som_top=%s" % [warmed.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == direct.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]])
	for line in lines:
		print(line)
	var f := FileAccess.open(_out.path_join("stats.txt"), FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()


# ---------- 촬영 ----------

func _studio(size: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA
	vp.use_debanding = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.positional_shadow_atlas_size = 4096
	root.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.WHITE
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e9ecf2")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	_light(vp, Vector3(-38, -32, 0), Color("fff4e8"), 1.15, true)
	_light(vp, Vector3(-12, 48, 0), Color("dfe8ff"), 0.42, false)
	_light(vp, Vector3(-30, 165, 0), Color("ffffff"), 0.55, false)
	return vp


func _light(vp: SubViewport, rot: Vector3, color: Color, energy: float, shadow: bool) -> void:
	var l := DirectionalLight3D.new()
	l.rotation_degrees = rot
	l.light_color = color
	l.light_energy = energy
	l.shadow_enabled = shadow
	l.shadow_blur = 1.5
	l.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	l.directional_shadow_max_distance = 6.0
	vp.add_child(l)


func _camera(vp: SubViewport, ortho: bool, eye: Vector3, target: Vector3, size: float) -> Camera3D:
	var cam := Camera3D.new()
	if ortho:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = size
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
	else:
		cam.fov = size
	cam.near = 0.02
	cam.far = 30.0
	vp.add_child(cam)
	cam.position = eye
	cam.look_at(target, Vector3.UP)
	cam.current = true
	return cam


func _save(vp: SubViewport, name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	var path: String = _out.path_join(name + ".png")
	img.save_png(path)
	print("SHOT ", path)


func _rest(model: Node3D) -> void:
	for ap in model.find_children("*", "AnimationPlayer", true, false):
		(ap as AnimationPlayer).stop()
		(ap as AnimationPlayer).active = false
	for sk in model.find_children("*", "Skeleton3D", true, false):
		(sk as Skeleton3D).reset_bone_poses()


func _shots(ids: Array, hats: bool) -> void:
	var vp := _studio(Vector2i(1800, 2400))
	for id: String in ids:
		var index: int = CharacterLooks.IDS.find(id)
		var model := _dressed(index)
		vp.add_child(model)
		_rest(model)
		var cam := _camera(vp, true, Vector3(0, 0.915, -6.0), Vector3(0, 0.915, 0), 1.96)
		for yaw in [0, 30, 90, 150, 180, 270]:
			model.rotation_degrees.y = yaw
			await _save(vp, "%s_body_%03d" % [id, yaw])
		cam.queue_free()
		vp.size = Vector2i(2000, 2000)
		var face := _camera(vp, false, Vector3(0, 1.585, -1.62), Vector3(0, 1.59, 0), 21.5)
		for yaw in [0, 35, 90, 180]:
			model.rotation_degrees.y = yaw
			await _save(vp, "%s_face_%03d" % [id, yaw])
		model.queue_free()
		await process_frame
		if hats:
			# 모자 5종: 얼굴 정면·옆. 모자 쓴 모델은 새로 입힌다(게임도 모자를 바꾸면 다시 입힌다).
			for hat in range(1, 6):
				var capped := _dressed(index, {"hat": hat})
				vp.add_child(capped)
				_rest(capped)
				for yaw in [0, 90, 180]:
					capped.rotation_degrees.y = yaw
					await _save(vp, "%s_hat%d_%03d" % [id, hat, yaw])
				capped.queue_free()
				await process_frame
			# 꾸미기 옷 색(빨강)·안경·시계 같이
			var colored := _dressed(index, {"shirt": 1, "eyes": 1, "watch": 1, "pants": 2})
			vp.add_child(colored)
			_rest(colored)
			face.queue_free()
			vp.size = Vector2i(1800, 2400)
			var cam2 := _camera(vp, true, Vector3(0, 0.915, -6.0), Vector3(0, 0.915, 0), 1.96)
			for yaw in [0, 180]:
				colored.rotation_degrees.y = yaw
				await _save(vp, "%s_red_%03d" % [id, yaw])
			cam2.queue_free()
			colored.queue_free()
		else:
			face.queue_free()
		vp.size = Vector2i(1800, 2400)
		await process_frame


## 모자 5종 × 정면·옆·뒤 — 모자 꼭대기까지 들어오게 얼굴보다 조금 위·넓게 찍는다.
func _hats(ids: Array) -> void:
	var vp := _studio(Vector2i(1400, 1400))
	var cam := _camera(vp, false, Vector3(0, 1.70, -1.9), Vector3(0, 1.70, 0), 22.0)
	for id: String in ids:
		var index: int = CharacterLooks.IDS.find(id)
		for hat in range(0, 6):
			var capped := _dressed(index, {"hat": hat})
			vp.add_child(capped)
			_rest(capped)
			for yaw in [0, 90, 180]:
				capped.rotation_degrees.y = yaw
				await _save(vp, "%s_hat%d_%03d" % [id, hat, yaw])
			capped.queue_free()
			await process_frame
	cam.queue_free()


## 12방향(30°마다): 전신(정사영) + 얼굴(원근). 파일 = <id>_t_body_<각> · <id>_t_face_<각>
func _turn(ids: Array) -> void:
	var vp := _studio(Vector2i(1200, 1600))
	for id: String in ids:
		var model := _dressed(CharacterLooks.IDS.find(id))
		vp.add_child(model)
		_rest(model)
		vp.size = Vector2i(1200, 1600)
		var cam := _camera(vp, true, Vector3(0, 0.915, -6.0), Vector3(0, 0.915, 0), 1.96)
		for k in range(12):
			model.rotation_degrees.y = k * 30
			await _save(vp, "%s_t_body_%03d" % [id, k * 30])
		cam.queue_free()
		vp.size = Vector2i(1000, 1000)
		var face := _camera(vp, false, Vector3(0, 1.57, -1.62), Vector3(0, 1.57, 0), 23.0)
		for k in range(12):
			model.rotation_degrees.y = k * 30
			await _save(vp, "%s_t_face_%03d" % [id, k * 30])
		face.queue_free()
		model.queue_free()
		await process_frame


## 오른손 가까이 8방향(카메라가 손 둘레를 돈다). 파일 = <id>_hand_<각>
func _hands(ids: Array) -> void:
	var vp := _studio(Vector2i(800, 800))
	for id: String in ids:
		var model := _dressed(CharacterLooks.IDS.find(id))
		vp.add_child(model)
		_rest(model)
		var target := Vector3(0.53, 0.70, 0.02)
		for k in range(8):
			var a: float = deg_to_rad(k * 45.0)
			var eye: Vector3 = target + Vector3(sin(a), 0.25, -cos(a)).normalized() * 0.55
			var cam := _camera(vp, false, eye, target, 30.0)
			await _save(vp, "%s_hand_%03d" % [id, k * 45])
			cam.queue_free()
		model.queue_free()
		await process_frame


## 안경 3종 × 정면·옆(얼굴 카메라). 파일 = <id>_eyes<번호>_<각>
func _glasses(ids: Array) -> void:
	var vp := _studio(Vector2i(900, 900))
	var cam := _camera(vp, false, Vector3(0, 1.60, -1.4), Vector3(0, 1.60, 0), 18.0)
	for id: String in ids:
		for eyes in range(1, 4):
			var m := _dressed(CharacterLooks.IDS.find(id), {"eyes": eyes})
			vp.add_child(m)
			_rest(m)
			for yaw in [0, 60]:
				m.rotation_degrees.y = yaw
				await _save(vp, "%s_eyes%d_%03d" % [id, eyes, yaw])
			m.queue_free()
			await process_frame
	cam.queue_free()
