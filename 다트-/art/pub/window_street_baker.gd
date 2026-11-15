extends SceneTree
## 창 밖 거리 그림 굽기 도구(2026-11-15). 게임 실행 중에는 쓰이지 않는다.
## 사용자 요청 "창문 밖 이미지들을 고른 에셋들로 다시 재구성해서 건물이랑 거리 등을 만들어 줘 — z축 겹치면 이미지가 깨져 보이니 조심":
##   펍 창은 벽에 붙은 판이고(벽에 구멍이 없다) 그 판에 창 밖 셰이더(art/pub/window_view.gdshader)가 깊이별 그림 층을 그린다.
##   → 진짜 3D 모델을 벽 뒤에 세우는 대신, 고른 Cartoon City 모델(RG Poly, CC0)로 거리를 꾸며 그 층과 같은 크기로
##     정면(직교 카메라)에서 찍어 투명 PNG 로 굽는다. 그림이라 방 안 면과 겹칠(z-파이팅) 일이 아예 없고, 걸어 다니면
##     층마다 다른 깊이로 움직여(시차) 창 밖처럼 보인다.
##   - 길 건너 층(window_street.png): 건물 줄(고른 Building_2_4_J 와 같은 계열 변형) · 차양 · 가로등 · 나무 · 화분 · 벤치 · 상자 · 쓰레기봉투
##   - 앞 층(window_front.png): 창 바로 앞 보도 — 가로등(셰이더 front_lamp_x = 10.5m 의 불빛 웅덩이 자리) · 나무 · 벤치 · 화분 · 덤불
##   먼 층(스카이라인 SVG)과 달은 그대로 둔다.
##
## 실행(창 모드 — 그림을 그려야 한다):
##   godot --path . --script res://art/pub/window_street_baker.gd -- --source=<Cartoon City Massive Pack 폴더>
##   → art/pub/pictures/window_street.png · window_front.png (편집기가 다시 훑으면 .import 가 생긴다)
##   --preview=<폴더> 를 주면 같은 그림을 그 폴더에도 저장한다(확인용).
## 층 크기(폭·높이 m)는 window_view.gdshader 의 street_size · front_size 와 같아야 한다(아래 STREET · FRONT).

## 층 = [그림 폭 m, 그림 높이 m, 1m 당 픽셀]. 셰이더 street_size.yz · front_size.yz 와 맞춘다.
const STREET := [42.0, 16.0, 64]
const FRONT := [14.0, 6.0, 128]
const OUT_STREET := "res://art/pub/pictures/window_street.png"
const OUT_FRONT := "res://art/pub/pictures/window_front.png"
## 건물 줄: 고른 Building_2_4_J 와 같은 계열(모양 1~6 × 색 A~J). 왼쪽부터 폭이 찰 때까지 차례로 세운다.
const BUILDINGS: Array[String] = ["Building_2_4_J", "Building_2_1_C", "Building_2_3_F", "Building_2_5_B", "Building_2_6_H",
	"Building_2_2_E", "Building_2_4_D", "Building_2_1_G"]
## Cartoon City 모델은 정면(창·문·차양 앞쪽)이 +X 를 본다 → y 축으로 -90도 돌리면 정면이 +Z(카메라 쪽)를 본다.
const FACE_YAW := -PI / 2.0
## 건물 사이 골목 폭(m). 골목에는 상자·쓰레기봉투를 둔다.
const ALLEY := 0.9
## 밤 조명: 가로등 불빛(따뜻한 노랑)과 달빛·하늘빛(파랑).
const LAMP_COLOR := Color(1.0, 0.78, 0.48)
const MOON_COLOR := Color(0.62, 0.68, 0.95)

var _source: String = ""
var _preview: String = ""
var _cache: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--source="): _source = arg.trim_prefix("--source=")
		if arg.begins_with("--preview="): _preview = arg.trim_prefix("--preview=")
	if _source.is_empty() or not DirAccess.dir_exists_absolute(_source):
		printerr("Cartoon City Massive Pack 폴더를 --source=<경로> 로 주세요: ", _source)
		quit(1)
		return
	if not _preview.is_empty(): DirAccess.make_dir_recursive_absolute(_preview)
	await _bake(STREET, _build_street, OUT_STREET, "window_street.png")
	await _bake(FRONT, _build_front, OUT_FRONT, "window_front.png")
	print("WINDOW STREET BAKE COMPLETE")
	quit()


## 한 층을 꾸며 직교 카메라로 찍고 PNG 로 저장한다. build(world, width) 가 모델을 세운다.
func _bake(layer: Array, build: Callable, out_path: String, preview_name: String) -> void:
	var width: float = layer[0]
	var height: float = layer[1]
	var viewport := SubViewport.new()
	viewport.size = Vector2i(int(width * layer[2]), int(height * layer[2]))
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	root.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	_lights(world)
	build.call(world, width)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = height
	camera.position = Vector3(width * 0.5, height * 0.5, 40.0)
	camera.far = 120.0
	world.add_child(camera)
	camera.current = true
	for i in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(out_path))
	if not _preview.is_empty(): image.save_png(_preview.path_join(preview_name))
	print("saved ", out_path, " ", image.get_size())
	viewport.queue_free()
	await process_frame


## 밤 조명: 하늘빛(주변광) + 달빛(앞 위에서) — 가로등 불빛은 가로등마다 따로(_lamp).
func _lights(world: Node3D) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.42, 0.45, 0.62)
	environment.ambient_light_energy = 0.75
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var holder := WorldEnvironment.new()
	holder.environment = environment
	world.add_child(holder)
	var moon := DirectionalLight3D.new()
	moon.light_color = MOON_COLOR
	moon.light_energy = 0.55
	moon.rotation = Vector3(deg_to_rad(-35.0), deg_to_rad(20.0), 0.0)
	moon.shadow_enabled = true
	world.add_child(moon)


## 원본 GLB 하나를 장면으로 읽는다(같은 파일은 한 번만 읽고 복제).
func _load(file_name: String) -> Node3D:
	if not _cache.has(file_name):
		var path := _find(_source, file_name + ".glb")
		if path.is_empty():
			printerr("모델을 못 찾음: ", file_name)
			return null
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		# 원본 팩의 텍스처(Textures/city_atlas.png · windows.png)는 GLB 밖 파일이고 옆에 구경판 프로젝트의 .import 가 있어
		# 엔진이 우리 프로젝트의 가져오기 캐시에서 찾다 실패한다(오류 줄이 찍힌다 — 무시해도 된다) → 아래 _fix_textures 가 직접 읽어 붙인다.
		if document.append_from_file(path, state) != OK:
			printerr("읽기 실패: ", path)
			return null
		_fix_textures(path, state)
		_cache[file_name] = document.generate_scene(state)
	return (_cache[file_name] as Node3D).duplicate()


## GLB 재질의 바탕 텍스처를 GLB 가 가리키는 그림 파일(상대 경로)에서 직접 읽어 붙인다.
var _textures: Dictionary = {}
func _fix_textures(path: String, state: GLTFState) -> void:
	var json: Dictionary = state.json
	var images: Array = json.get("images", [])
	var textures: Array = json.get("textures", [])
	var described: Array = json.get("materials", [])
	var materials := state.get_materials()
	for i in range(mini(materials.size(), described.size())):
		var base := materials[i] as BaseMaterial3D
		var info: Dictionary = (described[i] as Dictionary).get("pbrMetallicRoughness", {}).get("baseColorTexture", {})
		if base == null or info.is_empty(): continue
		var texture_index: int = int(info.get("index", -1))
		if texture_index < 0 or texture_index >= textures.size(): continue
		var source: int = int((textures[texture_index] as Dictionary).get("source", -1))
		if source < 0 or source >= images.size() or not (images[source] as Dictionary).has("uri"): continue
		var file: String = path.get_base_dir().path_join(str(images[source].uri)).simplify_path()
		if not _textures.has(file):
			var image := Image.load_from_file(file)
			_textures[file] = ImageTexture.create_from_image(image) if image != null else null
		if _textures[file] != null:
			base.albedo_texture = _textures[file]


func _find(dir: String, file_name: String) -> String:
	var access := DirAccess.open(dir)
	if access == null: return ""
	for file in access.get_files():
		if file == file_name: return dir.path_join(file)
	for sub in access.get_directories():
		var found := _find(dir.path_join(sub), file_name)
		if not found.is_empty(): return found
	return ""


## 노드 아래 모든 메시를 합친 상자(부모 좌표).
static func _bounds(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mesh_node in node.find_children("*", "MeshInstance3D", true, false):
		var instance := mesh_node as MeshInstance3D
		var xform: Transform3D = node.transform * _relative(node, instance)
		var part: AABB = xform * instance.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box


static func _relative(top: Node3D, child: Node3D) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var node: Node = child
	while node != null and node != top:
		if node is Node3D: xform = (node as Node3D).transform * xform
		node = node.get_parent()
	return xform


## 모델을 세운다: yaw 로 돌린 뒤, 바닥(아래 끝)을 y 0 에, 가로 가운데를 x 에, 뒤(또는 앞) 면을 z 에 맞춘다.
## back = true 면 모델 뒷면(z 최소)을 z 에(벽에 붙이는 것), false 면 모델 가운데를 z 에 둔다.
## 같은 모델을 그림 폭(wrap)만큼 양옆에도 하나씩 세워 그림 가장자리가 끊김 없이 이어지게 한다.
func _place(world: Node3D, file_name: String, x: float, z: float, yaw := 0.0, scale := 1.0, back := false, wrap := 0.0, lift := 0.0) -> AABB:
	var model := _load(file_name)
	if model == null: return AABB()
	model.rotation.y = yaw
	model.scale = Vector3.ONE * scale
	var box := _bounds(model)
	var offset := Vector3(x - box.get_center().x, lift - box.position.y, (z - box.position.z) if back else (z - box.get_center().z))
	model.position += offset
	world.add_child(model)
	if wrap > 0.0:
		for side: float in [-1.0, 1.0]:
			var copy := model.duplicate() as Node3D
			copy.position.x += side * wrap
			world.add_child(copy)
	return AABB(box.position + offset, box.size)


## 가로등 + 불빛(따뜻한 점광원). 그림 가장자리를 넘는 불빛도 양옆 복제로 이어진다.
func _lamp(world: Node3D, file_name: String, x: float, z: float, wrap: float) -> void:
	var box := _place(world, file_name, x, z, 0.0, 1.0, false, wrap)
	for side: float in ([-1.0, 0.0, 1.0] if wrap > 0.0 else [0.0]):
		var light := OmniLight3D.new()
		light.light_color = LAMP_COLOR
		light.light_energy = 2.4
		light.omni_range = 7.5
		light.position = Vector3(x + side * wrap, box.end.y - 0.45, z + 0.6)
		world.add_child(light)


## 길 건너 층(유리 뒤 18m): 건물 줄 + 1층 차양 + 보도 소품.
func _build_street(world: Node3D, width: float) -> void:
	# 1) 건물: 왼쪽부터 폭이 찰 때까지. 남는 폭은 골목에 고르게 나눈다(그림 양 끝 = 골목 반쪽씩 → 이어 붙여도 골목 하나).
	var picked: Array = []
	var used: float = 0.0
	for file_name in BUILDINGS:
		var probe := _load(file_name)
		if probe == null: continue
		var w: float = _bounds(probe).size.z  # 원본 정면이 +X 라 정면 폭은 z 길이
		probe.free()
		if used + w + ALLEY > width: break
		picked.append([file_name, w])
		used += w + ALLEY
	var alley: float = (width - (used - ALLEY * picked.size())) / maxf(picked.size(), 1)
	var x: float = alley * 0.5
	var fronts: Array = []
	for entry: Array in picked:
		var w: float = entry[1]
		# 원본 건물 정면(창이 난 쪽)은 +X → FACE_YAW 로 돌려 정면이 카메라(+Z, 길 쪽)를 보게 한다.
		var box := _place(world, entry[0], x + w * 0.5, 0.0, FACE_YAW, 1.0, false, width)
		# 건물 앞면이 z 0 에 오게 다시 맞춘다(모델마다 깊이가 다르다).
		fronts.append([x + w * 0.5, w, box])
		x += w + alley
	# 2) 보도 소품: 건물마다 문 옆 화분 · 1층 차양(셋에 둘) · 골목에 상자·쓰레기봉투 · 사이사이 나무와 가로등.
	var awnings := ["Awning_1_A", "Awning_1_D", "Awning_1_G", "Awning_1_J", "Awning_1_M", "Awning_1_C", "Awning_1_H", "Awning_1_K"]
	for i in range(fronts.size()):
		var center: float = fronts[i][0]
		var w: float = fronts[i][1]
		var box: AABB = fronts[i][2]
		var face: float = box.end.z
		if i % 3 != 2:
			# 차양: 원본은 폭이 z 방향(2.8m)·정면 +X → 건물과 같이 돌린다. 앞면에서 2cm 띄워 벽과 겹치지 않게.
			_place(world, awnings[i % awnings.size()], center - w * 0.18, face + 0.02, FACE_YAW, 1.0, true, width, 2.35)
		_place(world, "FlowerPot_5_2_F" if i % 2 == 0 else "FlowerPot_5_2_G", center + w * 0.3, face + 0.45, FACE_YAW, 1.0, false, width)
		var gap_x: float = center + w * 0.5 + alley * 0.5
		var junk: Array = [["Trashbag_A_1", 0.0], ["Box_1", 0.35], ["Trashbag_B_2", -0.3]] if i % 2 == 0 else [["Box_3", 0.0], ["Trashbag_A_2", 0.3]]
		for j in range(junk.size()):
			_place(world, junk[j][0], gap_x + (j - 0.5) * 0.42, face - 0.6 + float(junk[j][1]), 0.3 * j, 1.0, false, width)
	# 가로등과 나무는 건물과 상관없이 일정한 간격(10.5m)으로 — 앞 층 가로등 박자와 비슷하게.
	var trees := ["Tree_F_2_", "Tree_F_4_", "Tree_F_6_", "Tree_F_7_"]
	for k in range(4):
		var lamp_x: float = 2.6 + k * 10.5
		_lamp(world, "StreetLamp_3_C" if k % 2 == 0 else "StreetLamp_3_D", lamp_x, fronts[0][2].end.z + 2.6, width)
		_place(world, trees[k], lamp_x + 5.2, fronts[0][2].end.z + 3.0, k * 0.7, 0.9, false, width)
	_place(world, "Bench_1_A", 8.4, fronts[0][2].end.z + 1.5, FACE_YAW, 1.0, false, width)
	_place(world, "Bench_1_A", 30.2, fronts[0][2].end.z + 1.5, FACE_YAW, 1.0, false, width)
	_place(world, "Cone_1", 19.6, fronts[0][2].end.z + 2.2, 0.0, 1.0, false, width)


## 앞 층(유리 뒤 6.5m): 창 바로 앞 보도. 길 건너가 가려지지 않게 듬성듬성.
func _build_front(world: Node3D, width: float) -> void:
	# 셰이더 front_lamp_x(10.5m)에 가로등 — 길바닥 불빛 웅덩이와 자리가 맞는다.
	_lamp(world, "StreetLamp_3_D", 10.5, 0.0, width)
	_place(world, "Tree_F_3_", 3.4, -0.4, 0.4, 1.0, false, width)
	_place(world, "Bench_1_A", 6.9, -0.2, FACE_YAW, 1.0, false, width)
	_place(world, "FlowerPot_5_2_F", 0.9, 0.3, FACE_YAW, 1.0, false, width)
	_place(world, "FlowerPot_5_2_G", 12.9, 0.3, FACE_YAW, 1.0, false, width)
	_place(world, "Bush_1_B_1", 9.7, -0.3, FACE_YAW, 1.0, false, width)
	_place(world, "Trashbag_B_1", 11.6, 0.2, 0.5, 1.0, false, width)
	_place(world, "Flowers_1_C", 13.6, 0.5, 0.0, 1.0, false, width)
	_place(world, "Flowers_2_A", 1.7, 0.6, 0.0, 1.0, false, width)
