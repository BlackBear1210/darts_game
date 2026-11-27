extends RefCounted
## [부품] 캐릭터 3안(준·솜·온) 조립 — 꾸미기 칸 "캐릭터"(art/characters/player_outfit.gd SLOTS)가 부른다. 디자인 담당 소유.
## class_name 을 만들지 않고 preload 로 부른다(열린 편집기가 새 class_name 을 못 읽어 파스 오류가 나는 함정).
##
## [어떻게] 승인 모델(approved_player.tscn) 하나를 그대로 쓰고 **메시만 갈아 끼운다**. 뼈·관절·키·충돌·눈높이·판정은 그대로다.
##   - Body(피부·머리 그림) → 피부·머리 색 셰이더(character_skin.gdshader) + 옛 곱슬머리를 두피 안으로 눌러 넣은 정점
##     + 캐릭터마다 얼굴형(_morph_face: 턱·볼·코) + 두툼한 손(_morph_hands)
##   - Top_01 · Bottom_01 · Shoes_01 → 옷 색 구역 셰이더(character_cloth.gdshader). 쉬는 자세 좌표를 정점(UV·UV2)에 구워 칠한다.
##   - 체형(_morph): 쉬는 자세 좌표를 조금 밀고 당긴다 — 솜 = 가슴·허리·골반·엉덩이, 온 = 몸통·상완 두툼
##   - 새 머리·입체 눈썹·소맷단·깃 같은 단단한 조각은 한 메시(CharacterParts)로 묶어 뼈대에 붙인다(드로우콜 +1, 조각마다 한 뼈).
##     그림 속 머리카락·눈썹은 셰이더가 살색으로 지운다(2026-11-27 v2 — 그림 눈썹이 튀어나온 눈알 뒤에 박혀 보였다).
##   게임이 찾는 파츠 이름(Body / Top_01 / Bottom_01 / Shoes_01)과 뼈 이름은 바꾸지 않는다.
## [재사용] 같은 캐릭터 메시는 한 번만 만들어 모든 선수·래그돌·꾸미기 방·1인칭 팔이 같이 쓴다(_meshes 캐시, 게임을 끌 때까지).
##   처음 만들 때 시간이 걸리므로(잰 값은 docs/ARCHITECTURE.md) 타이틀 화면에서 prewarm_step()으로 한 조각씩 미리 만든다(app/asset_warmup.gd).
## [되돌리기] apply(model, 0) = 원래 메시로 돌리고 조각을 뗀다(player_outfit.undress 가 부른다).
## 디자인 기준: 바탕화면 darty_캐릭터_디자인/3D_검증_2026-11-26 (12방향 사진). 시안 그림은 참고만 한다(저작권).

const DATA_PATH := "res://art/characters/character_look_data.res"
const LookData = preload("res://art/characters/character_look_data.gd")
const SKIN_SHADER: Shader = preload("res://art/characters/character_skin.gdshader")
const SKIN_SHADER_TWO_SIDED: Shader = preload("res://art/characters/character_skin_two_sided.gdshader")
const CLOTH_SHADER: Shader = preload("res://art/characters/character_cloth.gdshader")
## 경기 선수 몸은 소품 잡기(character_prop_grip.gd)가 손가락 블렌드 셰이프를 붙인 변환본이다 → 캐릭터 몸도 같은 변환을 거친다.
const PropGrip = preload("res://art/characters/character_prop_grip.gd")
## 손바닥 좌표틀(손 두께 변형). 다트 쥐기 자세 파일의 PALM 과 같다.
const PALM: Basis = preload("res://art/characters/approved_dart_grip.gd").PALM

## 꾸미기 "character" 칸 번호 순서(0 = 기본 = 승인 모델 그대로). 새 캐릭터는 맨 뒤에 붙인다(저장된 번호가 바뀌지 않게).
## 이름은 player_outfit.gd SLOTS 의 "character" 줄과 같은 순서다.
const IDS: Array[String] = ["base", "jun", "som", "on"]

## 캐릭터 색표(sRGB 16진). skin = 피부 · hair = 머리 · brow = 눈썹·입술선 · fade = 온의 짧게 민 옆·뒤 머리 · 나머지는 옷 색 구역.
## 피부는 셋이 한눈에 갈리게 밝기를 벌린다(2026-11-27 v2): 준 = 밝은 살구 · 솜 = 따뜻한 황갈 · 온 = 짙은 갈색.
const LOOKS: Dictionary = {
	"jun": {"skin": "eba57a", "hair": "231f22", "brow": "231d20",
		"shirt": "4b2441", "inner": "eadfca", "accent": "d69a3c", "pants": "465068", "shoe": "5c2123", "sole": "cdb88f"},
	"som": {"skin": "c18556", "hair": "232a48", "brow": "1b1d30",
		"shirt": "ebe1cb", "panel": "4f8985", "pocket": "2c5754", "pants": "272b3f", "turnup": "a9c9b4", "shoe": "23242d", "sole": "17171c"},
	"on": {"skin": "6b3f29", "hair": "a4532a", "brow": "3b1d12", "fade": "4a2619",
		"shirt": "a5392b", "yoke": "ebdfc3", "tab": "5f6f8c", "pants": "4c4744", "shoe": "2b325c", "sole": "151518", "pull": "b5452f"},
}
## 옷 색 구역 셰이더 칸: 부위 → [무늬 번호, c_main 키, c_a 키, c_b 키, 밑창 줄 높이]. 신발은 면마다(0 = 몸통, 1 = 밑창).
## 무늬 번호는 character_cloth.gdshader 의 pattern 과 같다(0 한 색 · 1 준 상의 · 2 솜 상의 · 3 온 상의 · 4 밑창 줄).
const CLOTH: Dictionary = {
	"jun": {"Top_01": [1, "shirt", "inner", "accent"], "Bottom_01": [0, "pants"],
		"Shoes_01": [[4, "shoe", "sole", "", 0.018], [0, "sole"]]},
	"som": {"Top_01": [2, "shirt", "panel", "pocket"], "Bottom_01": [0, "pants"],
		"Shoes_01": [[0, "shoe"], [0, "sole"]]},
	"on": {"Top_01": [3, "shirt", "yoke"], "Bottom_01": [0, "pants"],
		"Shoes_01": [[4, "shoe", "sole", "", 0.016], [0, "sole"]]},
}
## 원래 텍스처의 피부·머리 평균색(sRGB, 머리 정점 표본 실측). 새 색 / 이 색 = 바꾸는 비율.
const SKIN_REF := Color("e19461")
const HAIR_REF := Color("3d2216")
## 갈아 끼우는 파츠(게임이 찾는 이름 — 바꾸지 않는다).
const PART_NAMES: Array[String] = ["Body", "Top_01", "Bottom_01", "Shoes_01"]
## 원래 메시를 기억해 두는 메타 키 · 조각 노드 이름(1인칭 팔 first_person_arm.gd ARM_PARTS 도 이 이름을 본다).
const BASE_META := &"character_base_mesh"
const PARTS_NODE := "CharacterParts"
## 모자를 쓰면 이 높이(m) 위의 새 머리를 눌러 모자 속에 넣는다 = 승인 모델 모자 밑면(face_anchors.hat y 1.785).
## 이보다 낮게 누르면 모자와 머리 사이가 떠 보인다(2026-11-27 1.73 → 1.785 로 고침). 옆·뒤 머리와 묶음머리는 그대로 보인다.
const HAT_HAIR_LINE: float = 1.785
const HAT_HAIR_SQUASH: float = 0.35
## 모자 속으로 넣을 때 머리를 이 반지름(m, 머리 가운데 기준) 안으로 모은다.
const HAT_HAIR_RADIUS: float = 0.135
const HEAD_CENTER := Vector2(0.0, -0.055)
## 모자 밑 머리를 부풀리는 띠(m): x 에서 시작해 y 에서 다 부푼다(_under_hat).
const HAT_FIT_BAND := Vector2(1.72, 1.765)
## 승인 모델(옛 곱슬머리 포함) 머리 바깥선 — 높이 → (가로 반지름, 앞뒤 반지름, 앞뒤 가운데 z). mesh 실측(2026-11-27).
const HAT_FIT_OUTLINE: Array[Vector4] = [
	Vector4(1.700, 0.156, 0.170, -0.075),
	Vector4(1.730, 0.140, 0.157, -0.083),
	Vector4(1.760, 0.117, 0.140, -0.085),
	Vector4(1.785, 0.105, 0.118, -0.0925),
]

static var _data: LookData
## 만든 메시(키 "캐릭터/파츠/원본 메시 id" → ArrayMesh). 게임을 끌 때까지 남는다.
static var _meshes: Dictionary = {}
## 재질(키 → Material). 같은 캐릭터·같은 면은 모든 선수가 한 재질을 같이 쓴다(같은 것끼리 한 번에 그려진다).
static var _materials: Dictionary = {}
static var _parts_material: StandardMaterial3D
## 미리 만들기 줄(prewarm_step). [캐릭터, 파츠] 순서.
static var _prewarm_queue: Array = []
static var _prewarm_base: Dictionary = {}
## 0 = 아직 · 1 = 하는 중 · 2 = 끝.
static var _prewarm_state: int = 0
## 파츠별 원본 면 배열(미리 만들기 동안만 들고 있다 — 캐릭터 셋이 같은 원본을 쓰므로 한 번만 꺼낸다).
static var _prewarm_arrays: Dictionary = {}
## 지금 일꾼 스레드가 정점을 계산 중인 일(WorkerThreadPool 번호, 없으면 −1)과 그 일의
## [캐릭터, 파츠, 원본, 결과 면 배열, 손가락 변환 결과(몸만)].
static var _prewarm_task: int = -1
static var _prewarm_job: Array = []
## 다음 프레임에 붙일 손가락 변환본 [원래 메시, PropGrip.grip_surfaces 결과].
static var _prewarm_grip: Array = []
## 손가락 변환에 쓰는 승인 모델 스킨·손 쉬는 자세(PropGrip.hand_rests). 미리 만들기 동안만 들고 있다.
static var _prewarm_skin: Skin
static var _prewarm_rests: Array = []
## 손 두께 변형(_morph_hands)에 쓰는 손바닥 좌표틀 [오른손 → 손바닥, 손바닥 → 오른손, 왼손 → 손바닥, 손바닥 → 왼손].
## 승인 모델 뼈의 쉬는 자세에서 한 번 구한다(_hand_frames, 메인 스레드). 스레드는 읽기만 한다.
static var _palm: Array = []


## 칸 번호 → 캐릭터 키(범위 밖이면 가장 가까운 번호).
static func id_at(index: int) -> String:
	return IDS[clampi(index, 0, IDS.size() - 1)]


## model(PlayerLook.character 로 만든 승인 캐릭터)에 캐릭터 index 를 입힌다. 이미 입은 캐릭터는 바꿔 끼운다.
##   hat_on  모자를 쓰는가(새 머리 윗부분을 모자 속으로 눌러 넣는다)
##   shirt   꾸미기 옷 색 번호(0 = 캐릭터 옷 그대로). 상의 색과 같은 색인 깃 조각도 같이 바꾼다.
static func apply(model: Node3D, index: int, hat_on: bool = false, shirt_color: Variant = null) -> void:
	var id: String = id_at(index)
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	for part_name: String in PART_NAMES:
		var instance := model.find_child(part_name, true, false) as MeshInstance3D
		if instance == null or not (instance.mesh is ArrayMesh):
			continue
		# 경기 선수 몸은 소품 잡기가 손가락 셰이프를 붙인 변환본이다(PlayerView: 모션 → 차림 순서).
		# 원래 메시를 기준으로 캐릭터 몸을 만들고, 다시 같은 변환을 붙인다 — 안 붙이면 손가락 셰이프가 없어
		# 매 프레임 set_blend_shape_value 오류가 쏟아지고(2026-11-27 실측 4천 번+) 프레임이 64 → 42 fps 로 떨어졌다.
		var current := instance.mesh as ArrayMesh
		var gripped: bool = current.has_meta(PropGrip.SOURCE_META)
		if not instance.has_meta(BASE_META):
			instance.set_meta(BASE_META, current.get_meta(PropGrip.SOURCE_META) if gripped else current)
		var base: ArrayMesh = instance.get_meta(BASE_META)
		var chosen: ArrayMesh = base if id == "base" else part_mesh(id, part_name, base)
		if gripped and skeleton != null:
			chosen = PropGrip.grip_mesh(chosen, instance.skin, skeleton)
		instance.mesh = chosen
		if part_name == "Bottom_01":
			# 바지 스타일(player_outfit._fit_pants)은 지금 캐릭터의 바지에서 폭·색을 바꾼다.
			instance.set_meta("wardrobe_base_mesh", instance.mesh)
	if skeleton == null:
		return
	var old := skeleton.get_node_or_null(PARTS_NODE)
	if old != null:
		# 바로 떼어 낸다(지우는 중인 조각을 같은 프레임에 다시 찾지 않게).
		skeleton.remove_child(old)
		old.queue_free()
	model.set_meta("character", id)
	var body := model.find_child("Body", true, false) as MeshInstance3D
	if id == "base" or body == null or body.skin == null:
		return
	var parts := MeshInstance3D.new()
	parts.name = PARTS_NODE
	parts.mesh = _parts_mesh(id, hat_on, shirt_color, body.skin)
	skeleton.add_child(parts)
	parts.skin = body.skin
	parts.skeleton = parts.get_path_to(skeleton)
	parts.layers = body.layers
	parts.cast_shadow = body.cast_shadow


## 캐릭터 상의 재질의 큰 면(c_main)만 color 로 바꾼 재질(꾸미기 옷 색). 같은 재질·같은 색은 하나를 같이 쓴다.
static func tinted(material: Material, color: Color) -> Material:
	var key: String = "tint/%d/%s" % [material.get_instance_id(), color.to_html()]
	if not _materials.has(key):
		var copy := material.duplicate() as ShaderMaterial
		copy.set_shader_parameter("c_main", color)
		_materials[key] = copy
	return _materials[key]


## id 캐릭터의 part_name 메시(원본 base 에서 한 번만 만든다). 미리 만들기 전에 필요해지면 여기서 바로 만든다.
static func part_mesh(id: String, part_name: String, base: ArrayMesh) -> ArrayMesh:
	var key: String = _mesh_key(id, part_name, base)
	if not _meshes.has(key):
		_data_resource()
		_hand_frames()
		var surfaces: Array = _surface_arrays(base)
		_shape(id, part_name, surfaces)
		_meshes[key] = _assemble(id, part_name, base, surfaces)
	return _meshes[key]


static func _mesh_key(id: String, part_name: String, base: ArrayMesh) -> String:
	return "%s/%s/%d" % [id, part_name, base.get_instance_id()]


## 타이틀 화면에서 매 프레임 부른다(app/asset_warmup.gd). 남은 일이 있으면 true.
## 만드는 것: 캐릭터 3안 × 파츠 4개 + 몸의 손가락 변환본(승인 모델 몸 포함 — 경기 시작 때 첫 선수가 만들며 멈추던 것).
## 무거운 정점 계산(체형·색 구역 좌표·손가락 셰이프, 파츠 하나 20~300 ms)은 일꾼 스레드(WorkerThreadPool)가 하고,
## 메인 스레드는 원본 배열 꺼내기와 메시 붙이기(몇 ms)만 한다 → 타이틀 화면이 끊기지 않는다.
## 스레드는 배열과 읽기 전용 자료(_data·스킨)만 만진다(노드·RenderingServer 를 건드리지 않는다 — 스레드에서 안전).
## 한 번 부를 때 메인 스레드의 무거운 일은 하나만 한다(모델 읽기 / 원본 배열 꺼내기 / 메시 붙이기 중 하나).
static func prewarm_step() -> bool:
	if _prewarm_state == 2:
		return false
	if _prewarm_state == 0:
		_prewarm_state = 1
		var model: Node3D = (load(PlayerLook.CHARACTER_SCENE) as PackedScene).instantiate()
		for part_name: String in PART_NAMES:
			var instance := model.find_child(part_name, true, false) as MeshInstance3D
			if instance != null and instance.mesh is ArrayMesh:
				_prewarm_base[part_name] = instance.mesh
		var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
		var body := model.find_child("Body", true, false) as MeshInstance3D
		if skeleton != null and body != null and body.skin != null and _prewarm_base.has("Body"):
			_prewarm_skin = body.skin
			_prewarm_rests = PropGrip.hand_rests(skeleton)
			_prewarm_queue.append(["base", "Body"])
		if skeleton != null and _palm.is_empty():
			_palm = _palm_frames(skeleton)
		model.free()
		for id: String in IDS.slice(1):
			for part_name: String in _prewarm_base:
				_prewarm_queue.append([id, part_name])
		# 자료는 메인 스레드에서 미리 읽어 둔다(스레드는 읽기만 한다).
		_data_resource()
		return true
	if _prewarm_task >= 0:
		if not WorkerThreadPool.is_task_completed(_prewarm_task):
			return true
		WorkerThreadPool.wait_for_task_completion(_prewarm_task)
		_prewarm_task = -1
		var job: Array = _prewarm_job
		_prewarm_job = []
		var source: ArrayMesh = job[2]
		if job[0] != "base":
			var key: String = _mesh_key(job[0], job[1], job[2])
			# 그 사이 경기가 먼저 만들었으면(part_mesh) 그것을 쓴다.
			if not _meshes.has(key):
				_meshes[key] = _assemble(job[0], job[1], job[2], job[3])
			source = _meshes[key]
		if not (job[4] as Array).is_empty():
			# 손가락 변환본은 다음 프레임에 붙인다(한 프레임에 무거운 일 하나).
			_prewarm_grip = [source, job[4]]
		return true
	if not _prewarm_grip.is_empty():
		var plain: ArrayMesh = _prewarm_grip[0]
		if not PropGrip.meshes.has(plain.get_instance_id()):
			PropGrip.meshes[plain.get_instance_id()] = PropGrip.assemble_grip(plain, _prewarm_grip[1])
		_prewarm_grip = []
		return true
	while not _prewarm_queue.is_empty():
		var job: Array = _prewarm_queue.pop_front()
		var base: ArrayMesh = _prewarm_base[job[1]]
		var grip: bool = job[1] == "Body" and _prewarm_skin != null
		if job[0] == "base":
			if PropGrip.meshes.has(base.get_instance_id()):
				continue
		elif _meshes.has(_mesh_key(job[0], job[1], base)) and not (grip and PropGrip.meshes.has((_meshes[_mesh_key(job[0], job[1], base)] as ArrayMesh).get_instance_id())):
			continue
		if not _prewarm_arrays.has(job[1]):
			_prewarm_arrays[job[1]] = _surface_arrays(base)
		_prewarm_job = [job[0], job[1], base, [], []]
		_prewarm_task = WorkerThreadPool.add_task(_prewarm_work.bind(_prewarm_job, _prewarm_arrays[job[1]], grip), false, "캐릭터 메시 미리 만들기")
		return true
	# 다 만들었다 — 원본 배열·스킨은 놓아 준다(메모리).
	_prewarm_state = 2
	_prewarm_arrays.clear()
	_prewarm_base.clear()
	_prewarm_skin = null
	_prewarm_rests = []
	return false


## 일꾼 스레드: 원본 면 배열(source, 읽기만)을 복사해 정점을 계산하고 job[3] 에 담는다.
## 정점 배열은 그 자리에서 고치므로 꼭 새로 복사한다(원본은 다음 캐릭터도 쓴다).
## grip 이면 그 결과(승인 모델이면 원본 그대로)에 손가락 셰이프를 계산해 job[4] 에 담는다.
static func _prewarm_work(job: Array, source: Array, grip: bool) -> void:
	var out: Array = job[3]
	if job[0] == "base":
		out.append_array(source)
	else:
		for surface in range(source.size()):
			var arrays: Array = (source[surface] as Array).duplicate()
			arrays[Mesh.ARRAY_VERTEX] = (source[surface][Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
			out.append(arrays)
		_shape(job[0], job[1], out)
	if grip:
		job[4] = PropGrip.grip_surfaces(out, _prewarm_skin, _prewarm_rests)


# ─────────────────────────────── 몸(피부·머리 그림) ───────────────────────────────

static func _data_resource() -> LookData:
	if _data == null:
		_data = load(DATA_PATH) as LookData
	return _data


## 원본 메시의 면별 정점 배열(메인 스레드에서 꺼낸다).
static func _surface_arrays(base: ArrayMesh) -> Array:
	var surfaces: Array = []
	for surface in range(base.get_surface_count()):
		surfaces.append(base.surface_get_arrays(surface))
	return surfaces


## 정점 계산만 한다(메인 스레드든 일꾼 스레드든 같은 결과). surfaces 를 그 자리에서 바꾼다. _data 는 미리 읽혀 있어야 한다.
static func _shape(id: String, part_name: String, surfaces: Array) -> void:
	for surface in range(surfaces.size()):
		if part_name == "Body":
			_shape_body(id, surface, surfaces[surface])
		else:
			_shape_cloth(id, part_name, surface, surfaces[surface])


## 계산한 배열로 메시를 붙이고 재질을 단다(메인 스레드).
static func _assemble(id: String, part_name: String, base: ArrayMesh, surfaces: Array) -> ArrayMesh:
	var result := ArrayMesh.new()
	for surface in range(surfaces.size()):
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surfaces[surface], [], {}, base.surface_get_format(surface) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		var material: Material
		if part_name == "Body":
			material = _skin_material(id, surface, surface == _data.head_surface, base.surface_get_material(surface))
		else:
			material = _cloth_material(id, part_name, surface)
		result.surface_set_material(surface, material)
	return result


## 몸: 머리 면이면 옛 곱슬머리를 두피 안으로 눌러 넣고(자료의 정점 자리), 체형·얼굴형·손을 밀고, 입술선 좌표를 굽는다.
static func _shape_body(id: String, surface: int, arrays: Array) -> void:
	var data: LookData = _data
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var head: bool = surface == data.head_surface
	if head:
		if verts.size() == data.head_vertex_count:
			var moved_index: PackedInt32Array = data.moved_index
			var moved_position: PackedVector3Array = data.moved_position
			for k in range(moved_index.size()):
				verts[moved_index[k]] = moved_position[k]
		else:
			push_warning("캐릭터 조립: 승인 모델 머리 정점 수가 자료와 달라 옛 머리 눌러 넣기를 건너뜁니다(character_look_data.res 를 다시 만드세요).")
	var rest_y := PackedFloat32Array()
	var rest_z := PackedFloat32Array()
	if head:
		rest_y.resize(verts.size())
		rest_z.resize(verts.size())
		for i in range(verts.size()):
			rest_y[i] = verts[i].y
			rest_z[i] = verts[i].z
	verts = _morph(id, "Body", verts)
	arrays[Mesh.ARRAY_VERTEX] = verts
	if head:
		# 입술선만 남기고 그림 머리카락·눈썹을 살색으로 지우는 데 쓰는 쉬는 자세 좌표(character_skin.gdshaderinc 참고).
		# 얼굴형 변형 전 좌표를 쓴다(턱을 내려도 입술선 고르기는 같게).
		var uv2 := PackedVector2Array()
		uv2.resize(verts.size())
		for i in range(verts.size()):
			uv2[i] = Vector2(rest_y[i], rest_z[i])
		arrays[Mesh.ARRAY_TEX_UV2] = uv2


static func _skin_material(id: String, surface: int, head: bool, original: Material) -> Material:
	var key: String = "skin/%s/%d" % [id, surface]
	if _materials.has(key):
		return _materials[key]
	var look: Dictionary = LOOKS[id]
	var source := original as BaseMaterial3D
	var material := ShaderMaterial.new()
	material.resource_name = "CharacterSkin_%s_%d" % [id, surface]
	material.shader = SKIN_SHADER_TWO_SIDED if source != null and source.cull_mode == BaseMaterial3D.CULL_DISABLED else SKIN_SHADER
	if source != null:
		material.set_shader_parameter("albedo_tex", source.albedo_texture)
	material.set_shader_parameter("skin_mul", _linear(Color(look.skin)) / _linear(SKIN_REF))
	material.set_shader_parameter("skin_new", _linear(Color(look.skin)))
	material.set_shader_parameter("hair_new", _linear(Color(look.hair)))
	material.set_shader_parameter("brow_new", _linear(Color(look.brow)))
	material.set_shader_parameter("hair_ref_lum", _linear(HAIR_REF).dot(Vector3(0.2126, 0.7152, 0.0722)))
	# 면 0 = 얼굴·몸 그림(피부와 머리카락이 섞임), 머리 면 = 머리 그림 — 나머지 면(팔·손·다리)은 그림 전체가 피부.
	material.set_shader_parameter("all_skin", surface != 0 and not head)
	material.set_shader_parameter("is_head", head)
	_materials[key] = material
	return material


# ─────────────────────────────── 옷(쉬는 자세 좌표로 색 구역) ───────────────────────────────

## 옷: 체형을 같이 밀고, 쉬는 자세 좌표를 UV(x, y)·UV2(z, 면 번호)에 굽는다(character_cloth.gdshader 가 읽는다).
static func _shape_cloth(id: String, part_name: String, surface: int, arrays: Array) -> void:
	var verts: PackedVector3Array = _morph(id, part_name, arrays[Mesh.ARRAY_VERTEX])
	arrays[Mesh.ARRAY_VERTEX] = verts
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	uv.resize(verts.size())
	uv2.resize(verts.size())
	for i in range(verts.size()):
		uv[i] = Vector2(verts[i].x, verts[i].y)
		uv2[i] = Vector2(verts[i].z, float(surface))
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2


static func _cloth_material(id: String, part_name: String, surface: int) -> Material:
	var key: String = "cloth/%s/%s/%d" % [id, part_name, surface]
	if _materials.has(key):
		return _materials[key]
	var look: Dictionary = LOOKS[id]
	var spec: Array = CLOTH[id][part_name]
	if spec[0] is Array:
		spec = spec[mini(surface, spec.size() - 1)]
	var material := ShaderMaterial.new()
	material.resource_name = "CharacterCloth_%s_%s_%d" % [id, part_name, surface]
	material.shader = CLOTH_SHADER
	material.set_shader_parameter("pattern", int(spec[0]))
	for slot in range(1, mini(spec.size(), 4)):
		var color_key: String = str(spec[slot])
		if color_key != "":
			material.set_shader_parameter(["", "c_main", "c_a", "c_b"][slot], Color(look[color_key]))
	if spec.size() > 4:
		material.set_shader_parameter("sole_line", float(spec[4]))
	_materials[key] = material
	return material


# ─────────────────────────────── 체형(쉬는 자세 좌표 변형) ───────────────────────────────
# 모든 파츠(몸·상의·바지·신발)에 같은 변형 장(場)을 써서 옷과 살이 같이 움직인다(서로 뚫지 않게).
# 정면 −Z, 캐릭터 오른쪽 +X, 바닥 y = 0. 관절 높이: 어깨 1.208 · 팔꿈치 0.964 · 손목 0.777 · 골반(다리 뿌리) 0.753 · 무릎 0.385.
# 승인 모델은 옷 속에 몸통 살이 없다(상의·바지가 곧 몸통). 상의 = 0.779~1.0 m 곧은 상자(반폭 0.16) · 바지 위끝 0.828 m.

## 솜 상의 밑단·바지 허리 높이(m). 승인 상의 밑단 0.779 → 0.865(허리선에서 끝나는 짧은 상의),
## 승인 바지 위끝 0.828 → 0.92(허리까지 오는 바지). 상의가 바지 위를 5 cm 덮는다(사이로 빈 속이 보이지 않게).
const SOM_TOP_HEM := Vector2(0.779, 0.865)
const SOM_PANTS_TOP := Vector2(0.828, 0.92)
## 위 두 줄의 기준 높이: 상의는 1.0 m 위(소매·가슴)를, 바지는 0.6 m 아래(허벅지 아래)를 그대로 둔다.
const SOM_TOP_KEEP: float = 1.0
const SOM_PANTS_KEEP: float = 0.6


static func _morph(id: String, part_name: String, verts: PackedVector3Array) -> PackedVector3Array:
	if id == "som":
		verts = _morph_som(verts, part_name)
	elif id == "on":
		verts = _morph_on(verts)
	if part_name == "Body":
		verts = _morph_face(id, verts)
		verts = _morph_hands(verts)
	return verts


# ─────────────────────────────── 얼굴형 · 손 (2026-11-27 v2) ───────────────────────────────
# 승인 모델 얼굴: 좁은 턱 · 긴 쐐기 코(끝 y 1.48, z −0.295) · 입술선 y 1.43~1.44 · 턱 밑 1.344 · 눈 1.56~1.62.
# 눈·이마·두개골(1.56 m 위)은 건드리지 않는다 → 모자·안경 자리, 입체 눈썹·새 머리 자리가 그대로 맞는다.
# 얼굴 앞(z < −0.02)만 민다 → 뒤통수·목 뒤는 그대로. 같은 자리 정점(면 경계)은 같은 함수로 움직여 틈이 생기지 않는다.

## 캐릭터별 얼굴형: [턱 폭(+넓게/−좁게), 턱끝 위아래(m, +위), 턱끝 폭, 볼 볼륨, 코 길이 줄임(0~1), 코 폭].
const FACE: Dictionary = {
	"jun": [-0.05, -0.006, -0.03, 0.0, 0.0, -0.06],   # 길고 좁은 얼굴 · 긴 턱 · 곧은 긴 코
	"som": [0.03, 0.012, 0.12, 0.14, 0.80, 0.0],      # 둥근 볼 · 짧고 둥근 턱 · 짧은 코
	"on": [0.16, -0.004, 0.14, 0.0, 0.15, 0.38],      # 넓고 각진 턱 · 넓은 코
}


static func _morph_face(id: String, verts: PackedVector3Array) -> PackedVector3Array:
	if not FACE.has(id):
		return verts
	var f: Array = FACE[id]
	for i in range(verts.size()):
		var p: Vector3 = verts[i]
		# 얼굴 아래쪽(턱 밑 목 1.30 ~ 광대 1.56)·앞쪽만.
		if p.y < 1.30 or p.y > 1.56 or absf(p.x) > 0.2 or p.z > -0.02:
			continue
		var ax: float = absf(p.x)
		var front: float = smoothstep(0.02, 0.12, -p.z)
		# 턱 밑(1.30~1.345)은 목에서 서서히 — 목·깃 쪽은 그대로.
		var under: float = smoothstep(1.30, 1.345, p.y)
		var jaw: float = (1.0 - smoothstep(1.42, 1.54, p.y)) * front * under
		var chin: float = (1.0 - smoothstep(1.36, 1.44, p.y)) * front * under
		var cheek: float = _bump(p.y, 1.38, 1.47, 1.55) * front
		p.x *= 1.0 + float(f[0]) * jaw + float(f[2]) * chin + float(f[3]) * cheek
		p.y += float(f[1]) * chin
		# 코: 가운데 좁은 띠(|x| < 3.5 cm), 콧방울 1.455 ~ 콧등 1.60.
		var nose: float = (1.0 - smoothstep(0.022, 0.036, ax)) * smoothstep(1.455, 1.47, p.y) * (1.0 - smoothstep(1.57, 1.61, p.y))
		if nose > 0.0 and p.z < -0.235:
			p.z = -0.235 + (p.z + 0.235) * (1.0 - float(f[4]) * nose)
		var wide: float = (1.0 - smoothstep(0.03, 0.045, ax)) * _bump(p.y, 1.455, 1.49, 1.56)
		p.x *= 1.0 + float(f[5]) * wide
		verts[i] = p
	return verts


## 손: 승인 손은 손바닥·손가락이 얇아 옆(엄지 쪽·새끼 쪽)에서 보면 납작한 판처럼 보인다(2026-11-27 사용자 피드백).
## 손바닥 좌표(approved_dart_grip.PALM: x = 손가락 가로, y = 손목 → 손끝, z = 손바닥 두께)에서 두께(z)만 키운다.
## 손목(손바닥 y 0 ~ 3.5 cm)은 서서히 — 아래팔과 이어지는 곳은 그대로. 손가락 쥐기 셰이프는 이 모양에서 다시 계산된다.
const HAND_THICKEN: float = 0.35


static func _morph_hands(verts: PackedVector3Array) -> PackedVector3Array:
	if _palm.size() < 4:
		return verts
	for side in [0, 2]:
		var to_palm: Transform3D = _palm[side]
		var from_palm: Transform3D = _palm[side + 1]
		var wrist: Vector3 = from_palm.origin
		for i in range(verts.size()):
			var p: Vector3 = verts[i]
			# 손목에서 25 cm 밖은 바로 건너뛴다(몸 정점 대부분).
			if absf(p.x - wrist.x) > 0.25 or absf(p.y - wrist.y) > 0.25:
				continue
			var q: Vector3 = to_palm * p
			if q.y < 0.0 or q.y > 0.24 or absf(q.x) > 0.13 or absf(q.z) > 0.1:
				continue
			# 두께 가운데: 손바닥은 거의 평평(0.002), 손가락은 안으로 굽어 끝으로 갈수록 손바닥 쪽(0.028).
			var center: float = lerpf(0.002, 0.028, smoothstep(0.12, 0.20, q.y))
			q.z = center + (q.z - center) * (1.0 + HAND_THICKEN * smoothstep(0.0, 0.035, q.y))
			verts[i] = from_palm * q
	return verts


## 손바닥 좌표틀을 한 번 구한다(메인 스레드 — 승인 모델을 잠깐 만든다). 이미 있으면 아무것도 안 한다.
static func _hand_frames() -> void:
	if not _palm.is_empty():
		return
	var model: Node3D = (load(PlayerLook.CHARACTER_SCENE) as PackedScene).instantiate()
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton != null:
		_palm = _palm_frames(skeleton)
	model.free()


## [오른손 → 손바닥, 손바닥 → 오른손, 왼손 → 손바닥, 손바닥 → 왼손] (PropGrip.hand_rests 와 같은 틀).
static func _palm_frames(skeleton: Skeleton3D) -> Array:
	var rests: Array = PropGrip.hand_rests(skeleton)
	var right: Transform3D = (rests[0] as Transform3D) * Transform3D(PALM, Vector3.ZERO)
	var left: Transform3D = (rests[1] as Transform3D) * Transform3D(rests[2], Vector3.ZERO)
	return [right.affine_inverse(), right, left.affine_inverse(), left]


## 솜: 2026-11-27 사용자 "가슴·허리·골반이 너무 남자 같다" → 시안(신규_캐릭터_도안/02_솜)을 다시 보고 고침.
##   시안의 여성 실루엣 = 짧은 상의 + 허리까지 오는 바지 + 잘록한 허리 + 바지 위로 둥근 골반·엉덩이 + 앞으로 나온 가슴.
##   1) 상의 밑단을 허리선으로 올리고 바지 허리를 올린다(파츠마다 높이만 옮김 — 뼈 가중치는 그대로).
##   2) 같은 변형 장으로 허리를 조이고, 골반·엉덩이를 바지 위에서 넓히고, 가슴을 앞으로 낸다.
## 어깨 관절(뼈) 자리는 그대로라 팔 움직임·판정은 같다. 손(A 자세에서 |x| > 0.3)은 건드리지 않는다.
static func _morph_som(verts: PackedVector3Array, part_name: String) -> PackedVector3Array:
	var top_scale: float = (SOM_TOP_KEEP - SOM_TOP_HEM.y) / (SOM_TOP_KEEP - SOM_TOP_HEM.x)
	var pants_scale: float = (SOM_PANTS_TOP.y - SOM_PANTS_KEEP) / (SOM_PANTS_TOP.x - SOM_PANTS_KEEP)
	for i in range(verts.size()):
		var p: Vector3 = verts[i]
		var ax: float = absf(p.x)
		# 변형이 닿는 높이(0.56~1.34 m) 밖 · 손은 바로 건너뛴다(머리 정점 3만 개를 계산하지 않게 — 미리 만들기 시간 절약).
		if ax > 0.3 or p.y <= 0.56 or p.y >= 1.34:
			continue
		# 1) 짧은 상의(몸통 상자만, 소매는 1.0 m 위라 그대로) · 높은 허리 바지.
		if part_name == "Top_01" and p.y < SOM_TOP_KEEP and ax < 0.2:
			p.y = SOM_TOP_KEEP - (SOM_TOP_KEEP - p.y) * top_scale
		elif part_name == "Bottom_01" and p.y > SOM_PANTS_KEEP:
			p.y = SOM_PANTS_KEEP + (p.y - SOM_PANTS_KEEP) * pants_scale
			# 상의 밑단 위(상의 속)로 올라간 바지 허리는 8 % 안으로 — 앞 모서리가 상의를 뚫고 나오지 않게(실측 0.8 mm 뚫림).
			var tuck: float = smoothstep(SOM_TOP_HEM.y - 0.006, SOM_TOP_HEM.y + 0.012, p.y)
			p.x *= 1.0 - 0.08 * tuck
			p.z *= 1.0 - 0.08 * tuck
		# 몸통(팔 제외) 가중치: 가운데 1 → 옆구리 바깥 0.
		var trunk: float = 1.0 - smoothstep(0.17, 0.22, ax)
		# 2) 허리: 갈비 아래부터 상의 밑단·바지 허리띠(0.92 m)까지 점점 잘록하게. 앞뒤도 조금.
		var waist: float = _bump(p.y, 0.80, 0.92, 1.12) * trunk
		p.x *= 1.0 - 0.16 * waist
		p.z *= 1.0 - 0.06 * waist
		# 골반·허벅지 윗부분: 바지 위에서 옆으로 둥글게(가장 넓은 곳 0.75 m).
		var hip: float = _bump(p.y, 0.56, 0.75, 0.88) * (1.0 - smoothstep(0.24, 0.30, ax))
		p.x *= 1.0 + 0.23 * hip
		# 어깨·상완: 어깨 관절(뼈)은 그대로 두고, 상완 둘레(소매와 살 같이)를 팔 축 쪽으로 가늘게 → 어깨선이 좁고 처져 보인다.
		# 몸통 상자(|x| ≤ 0.165)는 건드리지 않는다(팔 축 쪽으로 끌려 나가지 않게). 팔꿈치 쪽(|x| > 0.29)은 이미 0.
		if ax > 0.165:
			var side: float = signf(p.x)
			var joint := Vector3(0.175 * side, 1.208, 0.006)
			var axis: Vector3 = Vector3(0.367 * side, 0.964, 0.028) - joint
			var along: float = (p - joint).dot(axis) / axis.length_squared()
			if along > -0.25 and along < 0.6:
				var on_axis: Vector3 = joint + axis * clampf(along, 0.0, 1.0)
				var radial: Vector3 = p - on_axis
				if radial.length() < 0.09:
					p = on_axis + radial * (1.0 - 0.13 * _bump(along, -0.25, 0.1, 0.55))
		# 엉덩이: 뒤(+Z)로 둥글게(양쪽 두 덩이).
		if p.z > 0.0:
			var seat: float = _bump(p.y, 0.60, 0.76, 0.90) * exp(-pow((ax - 0.075) / 0.085, 2.0))
			p.z += 0.06 * seat * smoothstep(0.0, 0.05, p.z)
		# 가슴: 상의 앞 두 덩어리를 앞(−Z)으로, 아래쪽이 더 나오게.
		if p.z < -0.02 and ax < 0.17:
			var chest: float = _bump(p.y, 0.98, 1.09, 1.19) * exp(-pow((ax - 0.068) / 0.055, 2.0))
			p.z -= 0.036 * chest
		verts[i] = p
	return verts


## 온: 몸통(어깨~골반)과 상완을 두툼하게.
static func _morph_on(verts: PackedVector3Array) -> PackedVector3Array:
	for i in range(verts.size()):
		var p: Vector3 = verts[i]
		# 변형이 닿는 높이(몸통 0.76~1.30 m · 상완 0.89~1.33 m) 밖은 건너뛴다.
		if p.y < 0.76 or p.y > 1.33:
			continue
		var trunk: float = _bump(p.y, 0.76, 1.02, 1.30) * (1.0 - smoothstep(0.15, 0.21, absf(p.x)))
		if trunk > 0.0:
			p.x *= 1.0 + 0.055 * trunk
			p.z = -0.004 + (p.z + 0.004) * (1.0 + 0.07 * trunk)
		for side: float in [1.0, -1.0]:
			if p.x * side <= 0.15:
				continue
			var shoulder := Vector3(0.175 * side, 1.208, 0.006)
			var axis: Vector3 = Vector3(0.367 * side, 0.964, 0.028) - shoulder
			var t: float = (p - shoulder).dot(axis) / axis.length_squared()
			if t > -0.15 and t < 1.0:
				var on_axis: Vector3 = shoulder + axis * clampf(t, 0.0, 1.0)
				var radial: Vector3 = p - on_axis
				if radial.length() < 0.075:
					p = on_axis + radial * (1.0 + 0.16 * _bump(t, -0.1, 0.4, 0.95))
		verts[i] = p
	return verts


## a~b 사이에서 peak 일 때 1 인 부드러운 언덕(밖은 0).
static func _bump(x: float, a: float, peak: float, b: float) -> float:
	if x <= a or x >= b:
		return 0.0
	var t: float = (x - a) / (peak - a) if x < peak else (b - x) / (b - peak)
	return t * t * (3.0 - 2.0 * t)


# ─────────────────────────────── 덧붙이는 단단한 조각 ───────────────────────────────

## 새 머리·소맷단·깃·탭 등을 한 메시로 묶는다. 조각마다 한 뼈에 통째로(가중치 1) 붙는다.
## 면마다 밝기를 조금 흔들어 낮은 다각형 느낌을 살린다. 1인칭 팔이 오른팔 면만 골라내므로 번호(인덱스) 배열을 갖는다.
static func _parts_mesh(id: String, hat_on: bool, shirt_color: Variant, skin: Skin) -> ArrayMesh:
	var shirt_key: String = str(shirt_color) if shirt_color is Color else "-"
	var key: String = "parts/%s/%s/%s/%d" % [id, hat_on, shirt_key, skin.get_instance_id()]
	if _meshes.has(key):
		return _meshes[key]
	var binds: Dictionary = {}
	for bind in range(skin.get_bind_count()):
		binds[str(skin.get_bind_name(bind))] = bind
	var look: Dictionary = LOOKS[id]
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var indices := PackedInt32Array()
	for part: Dictionary in _data_resource().parts:
		if str(part.id) != id or not binds.has(str(part.bone)):
			continue
		var color := Color(look[str(part.color)])
		if str(part.color) == "shirt" and shirt_color is Color:
			color = shirt_color
		var bind: int = binds[str(part.bone)]
		var points: PackedVector3Array = part.v
		if hat_on and str(part.kind) == "hair":
			points = _under_hat(points)
		var triangles: PackedInt32Array = part.t
		var shade: float = float(part.shade)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(part.bone) + str(points.size()))
		for k in range(0, triangles.size(), 3):
			var a: Vector3 = points[triangles[k]]
			var b: Vector3 = points[triangles[k + 1]]
			var c: Vector3 = points[triangles[k + 2]]
			var n: Vector3 = (c - a).cross(b - a)
			if n.length_squared() < 1e-14:
				continue
			n = n.normalized()
			var lit: float = 1.0 + rng.randf_range(-shade, shade)
			var face := Color(color.r * lit, color.g * lit, color.b * lit)
			for point: Vector3 in [a, b, c]:
				indices.append(verts.size())
				verts.append(point)
				normals.append(n)
				colors.append(face)
				bones.append_array([bind, 0, 0, 0])
				weights.append_array([1.0, 0.0, 0.0, 0.0])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	if not verts.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, _parts_shared_material())
	_meshes[key] = mesh
	return mesh


## 모자 밑으로 들어갈 머리:
##   1) 모자 밑면 바로 아래 띠(1.72 ~ 1.785 m)는 승인 모델 옛 곱슬머리 바깥선(HAT_FIT_OUTLINE)까지 부풀린다.
##      모자 5종은 승인 모델 머리에 맞춰져 있어, 그보다 좁은 새 머리 위에서는 모자와 머리 사이가 떠 보였다(2026-11-27 v2).
##   2) HAT_HAIR_LINE 위는 낮게 누르고 머리 가운데로 모은다(모자 꼭대기를 뚫고 나오지 않게).
static func _under_hat(points: PackedVector3Array) -> PackedVector3Array:
	var result := points.duplicate()
	for i in range(result.size()):
		var p: Vector3 = result[i]
		if p.y <= HAT_FIT_BAND.x:
			continue
		var outline: Vector3 = _hat_outline(minf(p.y, HAT_HAIR_LINE))
		var ex: float = p.x / outline.x
		var ez: float = (p.z - outline.z) / outline.y
		var e: float = sqrt(ex * ex + ez * ez)
		if e > 0.05 and e < 1.0:
			var grow: float = lerpf(1.0, 1.0 / e, smoothstep(HAT_FIT_BAND.x, HAT_FIT_BAND.y, p.y))
			p.x *= grow
			p.z = outline.z + (p.z - outline.z) * grow
		var above: float = p.y - HAT_HAIR_LINE
		if above <= 0.0:
			result[i] = p
			continue
		p.y = HAT_HAIR_LINE + above * HAT_HAIR_SQUASH
		var flat := Vector2(p.x, p.z) - HEAD_CENTER
		var reach: float = flat.length()
		var limit: float = lerpf(reach, minf(reach, HAT_HAIR_RADIUS), smoothstep(0.0, 0.02, above))
		if reach > 0.0001:
			flat = flat * (limit / reach)
		p.x = HEAD_CENTER.x + flat.x
		p.z = HEAD_CENTER.y + flat.y
		result[i] = p
	return result


## 높이 y 의 승인 모델 머리 바깥선(HAT_FIT_OUTLINE 사이를 직선으로 잇는다) → (가로 반지름, 앞뒤 반지름, 가운데 z).
static func _hat_outline(y: float) -> Vector3:
	var rows: Array[Vector4] = HAT_FIT_OUTLINE
	if y <= rows[0].x:
		return Vector3(rows[0].y, rows[0].z, rows[0].w)
	for k in range(1, rows.size()):
		if y <= rows[k].x:
			var t: float = (y - rows[k - 1].x) / (rows[k].x - rows[k - 1].x)
			var a: Vector4 = rows[k - 1].lerp(rows[k], t)
			return Vector3(a.y, a.z, a.w)
	return Vector3(rows[-1].y, rows[-1].z, rows[-1].w)


static func _parts_shared_material() -> StandardMaterial3D:
	if _parts_material == null:
		_parts_material = StandardMaterial3D.new()
		_parts_material.resource_name = "CharacterParts"
		_parts_material.vertex_color_use_as_albedo = true
		_parts_material.vertex_color_is_srgb = true
		_parts_material.roughness = 0.9
		_parts_material.metallic_specular = 0.3
		_parts_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _parts_material


static func _linear(color: Color) -> Vector3:
	var value: Color = color.srgb_to_linear()
	return Vector3(value.r, value.g, value.b)
