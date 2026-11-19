extends RefCounted
## 선수 꾸미기(2026-11-15 사용자 요청 "당구대 옆 문을 열고 들어가면 커스터마이징 방 — 배그·덕 어몽어스처럼
## 선글라스·콧수염·시가·옷 색·시계·모자들을 넣어 줘. 게임에는 지장이 생기면 안 돼"). 디자인 담당 소유.
## class_name 을 만들지 않고 preload 로 부른다(열린 편집기가 새 class_name 을 못 읽어 파스 오류가 나는 함정).
##
## [무엇을 바꾸나] 보이기만 한다. 몸 충돌 캡슐·눈높이·판정·자리 색(●▲■◆ 이름표 색)은 그대로다.
##   look(꾸미기 값) = { "hat", "eyes", "mustache", "cigar", "watch", "shirt" } — 칸마다 목록 번호(0 = 없음/기본).
##   이 값은 방 정보(RoomPlayer.look)로 모두에게 같이 간다 → 모든 화면에서 같은 차림으로 보인다.
## [어떻게 입히나] 캐릭터 GLB 는 건드리지 않는다. NPC 옷(art/pub/npc_outfit.gd)처럼 뼈(BoneAttachment3D)에 점토 부품을 붙이고,
##   옷 색만 셰이더(art/characters/shirt_tint.gdshader)로 몸통 그림의 티셔츠 칸을 다시 칠한다.
##   부품은 실행 중에만 만든다(저장되는 장면 없음). 다시 입힐 때는 캐릭터를 새로 만든 뒤 입힌다(PlayerView.wear).

const NpcOutfit = preload("res://art/pub/npc_outfit.gd")
const MeshKit = preload("res://art/mesh_kit.gd")
const RoundKit = preload("res://art/pub/round_kit.gd")
const PubParts = preload("res://art/pub/pub_parts.gd")
const CigarSmoke = preload("res://art/pub/cigar_smoke.gd")
const SHIRT_SHADER := preload("res://art/characters/shirt_tint.gdshader")

## 꾸미기 칸: [키, 화면 이름, 고를 것 이름들]. 순서 = 꾸미기 방 오른쪽 패널의 줄 순서. 번호 0 은 늘 "없음"(또는 기본).
## 새 물건은 목록 맨 뒤에 붙인다(앞에 끼우면 저장된 번호가 다른 물건을 가리킨다).
const SLOTS: Array = [
	["hat", "모자", ["없음", "중절모", "야구 모자", "비니", "실크햇", "밀짚모자"]],
	["eyes", "안경", ["없음", "동그란 안경", "선글라스", "주황 색안경"]],
	["mustache", "콧수염", ["없음", "말린 콧수염", "두툼한 콧수염"]],
	["cigar", "시가", ["없음", "시가 물기"]],
	["watch", "시계", ["없음", "금시계", "은시계", "전자시계"]],
	["shirt", "옷 색", ["기본 자주", "빨강", "주황", "노랑", "초록", "하늘", "남색", "흰색", "검정", "분홍"]],
]
## 옷 색(위 "shirt" 이름과 같은 순서). 0 = 원래 그림 색(다시 칠하지 않음).
const SHIRT_COLORS: Array[Color] = [Color("3d2738"), Color("b8343a"), Color("dd7a2c"), Color("e3c043"), Color("3f9a55"),
	Color("62b4dd"), Color("2c3f7a"), Color("ece6da"), Color("1f1d22"), Color("e48aae")]
## 모자 색(야구 모자·비니). 자리 색과 헷갈리지 않게 차분한 색.
const CAP_COLOR := Color("2f5f8f")
const BEANIE_COLOR := Color("c8643c")
## 시가: 오른쪽 입꼬리(뼈대 공간, 머리뼈 받침 좌표). 콧수염 가운데(−0.012, 1.372, −0.205) 바로 아래 옆.
const CIGAR_MOUTH := Vector3(0.03, 1.343, -0.2)
## 시가 길이(m) — RG Poly 시가(0.21m)를 0.6배.
const CIGAR_SCALE: float = 0.6
const CIGAR_LENGTH: float = 0.21 * CIGAR_SCALE
## 시계: 왼쪽 아래팔에서 손목 쪽으로 이 비율 자리 · 손목 고리 반지름(m).
const WATCH_ALONG: float = 0.86
const WATCH_RADIUS: float = 0.036

static var _shirt_materials: Dictionary = {}
static var _modular_shirt_materials: Dictionary = {}


## 빈 값·옛 값·남이 보낸 이상한 값을 목록 안으로 맞춘다(방장이 받은 값도 이것을 거친다).
static func sanitize(look: Variant) -> Dictionary:
	var clean: Dictionary = {}
	var source: Dictionary = look if look is Dictionary else {}
	for slot: Array in SLOTS:
		var count: int = (slot[2] as Array).size()
		clean[slot[0]] = clampi(int(source.get(slot[0], 0)), 0, count - 1)
	return clean


## 연습 봇용 무작위 차림(방장이 봇을 만들 때 한 번). 너무 요란하지 않게 칸마다 "없음"이 자주 나온다.
static func random_look(rng: RandomNumberGenerator) -> Dictionary:
	var look: Dictionary = {}
	for slot: Array in SLOTS:
		var count: int = (slot[2] as Array).size()
		look[slot[0]] = rng.randi_range(1, count - 1) if rng.randf() < 0.5 else 0
	look["shirt"] = rng.randi_range(0, SHIRT_COLORS.size() - 1)
	return look


## 칸의 지금 고른 물건 이름(꾸미기 방 패널 글자).
static func choice_name(key: String, index: int) -> String:
	for slot: Array in SLOTS:
		if slot[0] == key:
			var names: Array = slot[2]
			return str(names[clampi(index, 0, names.size() - 1)])
	return ""


## model(PlayerLook.character 로 만든 선수 캐릭터)에 look 차림을 입힌다. 이미 입은 부품은 지우지 않는다 → 새 모델에 한 번만.
static func dress(model: Node3D, look: Dictionary) -> void:
	var clean := sanitize(look)
	tint_shirt(model, int(clean.shirt))
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return
	var head: Node3D = NpcOutfit.on_bone(skeleton, "head")
	hat(_fitted_head(model, head, "hat"), int(clean.hat))
	var eyes: Node3D = _fitted_head(model, head, "eyes")
	match int(clean.eyes):
		1: NpcOutfit.glasses(eyes)
		2: _sunglasses(eyes, "15151a", "1b1b1f", 0.12)
		3: _sunglasses(eyes, "e08a2e", "c9a24f", 0.25)
	var mouth: Node3D = _fitted_head(model, head, "mouth")
	match int(clean.mustache):
		1: NpcOutfit.mustache(mouth)
		2: _thick_mustache(mouth)
	if int(clean.cigar) == 1:
		_cigar(_fitted_head(model, head, "cigar"))
	if int(clean.watch) > 0:
		_watch(skeleton, int(clean.watch), 0.75 if model.find_child("Top_01", true, false) != null else 1.0)


## 새 모델의 눈·머리·입 위치로 기존 꾸미기 부품의 받침만 맞춘다. NPC용 원본 치수는 유지한다.
static func _fitted_head(model: Node3D, head: Node3D, kind: String) -> Node3D:
	if model.find_child("Top_01", true, false) == null:
		return head
	var anchors: Dictionary = model.get_meta("face_anchors", {})
	if anchors.has(kind):
		var anchor_target: Vector3 = anchors[kind]
		var anchor_scale: float = float(model.get_meta("hat_fit_scale" if kind == "hat" else "face_fit_scale", 1.0))
		var anchor_origin := Vector3(NpcOutfit.HEAD_AXIS.x, 1.57, -0.245)
		if kind == "hat":
			anchor_origin = Vector3(NpcOutfit.HEAD_AXIS.x, NpcOutfit.HAT_BASE_Y, 0.0)
		elif kind == "mouth":
			anchor_origin = Vector3(-0.012, 1.37, -0.207)
		elif kind == "cigar":
			anchor_origin = CIGAR_MOUTH
		var anchor_node := Node3D.new()
		anchor_node.name = "Approved_" + kind
		head.add_child(anchor_node)
		anchor_node.transform = Transform3D(Basis.from_scale(Vector3.ONE * anchor_scale), anchor_target - anchor_origin * anchor_scale)
		return anchor_node
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	var left := model.find_child("Eye_L", true, false) as MeshInstance3D
	var right := model.find_child("Eye_R", true, false) as MeshInstance3D
	var hair := model.find_child("Hair_01", true, false) as MeshInstance3D
	if skeleton == null or left == null or right == null or hair == null:
		return head
	var to_rig: Transform3D = skeleton.global_transform.affine_inverse()
	var eye_l: Vector3 = to_rig * left.global_transform * left.get_aabb().get_center()
	var eye_r: Vector3 = to_rig * right.global_transform * right.get_aabb().get_center()
	var target: Vector3 = (eye_l + eye_r) * 0.5
	var amount: float = absf(eye_l.x - eye_r.x) / 0.2
	var original := Vector3(NpcOutfit.HEAD_AXIS.x, 1.57, -0.245)
	if kind == "hat":
		var bounds: AABB = hair.get_aabb()
		target = to_rig * hair.global_transform * bounds.get_center()
		target.y += bounds.size.y * 0.5 - 0.06
		amount = bounds.size.x / 0.36
		original = Vector3(NpcOutfit.HEAD_AXIS.x, NpcOutfit.HAT_BASE_Y, 0.0)
	elif kind == "eyes":
		var front: Vector3 = left.get_aabb().get_center() - Vector3(0, 0, left.get_aabb().size.z * 0.5)
		target.z = (to_rig * left.global_transform * front).z - 0.008
	else:
		var socket := model.find_child("Socket_Mouth", true, false) as Node3D
		if socket == null:
			return head
		target = skeleton.get_bone_global_rest(skeleton.find_bone("head")) * socket.position
		original = Vector3(-0.012, 1.37, -0.207)
		if kind == "cigar":
			original = CIGAR_MOUTH
			target += Vector3(0.025, -0.004, -0.008)
	var fit := Node3D.new()
	fit.name = "Modular_" + kind
	head.add_child(fit)
	fit.transform = Transform3D(Basis.from_scale(Vector3.ONE * amount), target - original * amount)
	return fit


## 입힌 부품을 모두 벗긴다(뼈 받침 "Outfit_*" 를 통째로 지운다). 캐릭터를 새로 만들지 않고 차림만 바꿀 때 쓴다
## → 손에 붙은 카드 부채·래그돌·몸짓 상태가 그대로 남는다. 받침은 바로 떼어 낸다(지우는 중인 받침을 다시 쓰지 않게).
static func undress(model: Node3D) -> void:
	tint_shirt(model, 0)
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return
	for child in skeleton.get_children():
		if child is BoneAttachment3D and String(child.name).begins_with("Outfit_"):
			skeleton.remove_child(child)
			child.queue_free()


## 몸통 그림의 티셔츠 칸만 다시 칠한다(index 0 = 원래 그림). 1인칭 팔(art/characters/first_person_arm.gd)도 같은 함수를 쓴다.
static func tint_shirt(model: Node3D, index: int) -> void:
	var top := model.find_child("Top_01", true, false) as MeshInstance3D
	if top != null:
		for surface in range(top.mesh.get_surface_count()):
			if index <= 0 or index >= SHIRT_COLORS.size():
				top.set_surface_override_material(surface, null)
				continue
			if not _modular_shirt_materials.has(index):
				var material := top.mesh.surface_get_material(surface).duplicate() as BaseMaterial3D
				material.albedo_color = SHIRT_COLORS[index]
				_modular_shirt_materials[index] = material
			top.set_surface_override_material(surface, _modular_shirt_materials[index] as Material)
		return
	for node in model.find_children("tripo_part_0", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if index <= 0 or index >= SHIRT_COLORS.size():
			mesh.set_surface_override_material(0, null)
			continue
		var original := mesh.mesh.surface_get_material(0) as BaseMaterial3D
		if original == null:
			continue
		mesh.set_surface_override_material(0, _shirt_material(original, index))


## 고른 색 하나당 재질 하나(모든 선수가 같이 쓴다 → 같은 색끼리 한 번에 그려진다).
static func _shirt_material(original: BaseMaterial3D, index: int) -> ShaderMaterial:
	if _shirt_materials.has(index):
		return _shirt_materials[index]
	var material := ShaderMaterial.new()
	material.resource_name = "ShirtTint_%d" % index
	material.shader = SHIRT_SHADER
	material.set_shader_parameter("albedo_tex", original.albedo_texture)
	material.set_shader_parameter("use_normal", original.normal_enabled and original.normal_texture != null)
	if original.normal_texture != null: material.set_shader_parameter("normal_tex", original.normal_texture)
	material.set_shader_parameter("normal_scale", original.normal_scale)
	material.set_shader_parameter("roughness", original.roughness)
	material.set_shader_parameter("metallic", original.metallic)
	material.set_shader_parameter("specular", original.metallic_specular)
	if original.roughness_texture != null:
		material.set_shader_parameter("roughness_tex", original.roughness_texture)
		material.set_shader_parameter("roughness_channel", _channel(original.roughness_texture_channel))
	if original.metallic_texture != null:
		material.set_shader_parameter("metallic_tex", original.metallic_texture)
		material.set_shader_parameter("metallic_channel", _channel(original.metallic_texture_channel))
	material.set_shader_parameter("shirt_color", SHIRT_COLORS[index])
	material.set_shader_parameter("tint", 1.0)
	_shirt_materials[index] = material
	return material


## StandardMaterial3D 의 그림 칸 번호(R·G·B·A·회색) → 셰이더가 dot 으로 꺼내 쓰는 칸 가리개.
static func _channel(channel: int) -> Vector4:
	match channel:
		BaseMaterial3D.TEXTURE_CHANNEL_RED: return Vector4(1, 0, 0, 0)
		BaseMaterial3D.TEXTURE_CHANNEL_GREEN: return Vector4(0, 1, 0, 0)
		BaseMaterial3D.TEXTURE_CHANNEL_BLUE: return Vector4(0, 0, 1, 0)
		BaseMaterial3D.TEXTURE_CHANNEL_ALPHA: return Vector4(0, 0, 0, 1)
	return Vector4(0.333, 0.333, 0.334, 0)


# ─────────────────────────────── 모자 ───────────────────────────────
# 치수: NPC 옷과 같은 Tripo 캐릭터 측정값(머리 가운데 x −0.025, 머리 꼭대기 y 1.78, 앞 = −Z). 모자 밑면 = NpcOutfit.HAT_BASE_Y.

## 모자 하나를 head(머리뼈 받침, 또는 꾸미기 방 선반 위 받침)에 씌운다. index = "hat" 칸 번호(0 = 없음).
static func hat(head: Node3D, index: int) -> void:
	match index:
		1: NpcOutfit.bowler(head)
		2: NpcOutfit.cap(head, CAP_COLOR)
		3: NpcOutfit.beanie(head, BEANIE_COLOR)
		4: _top_hat(head)
		5: _straw_hat(head)


## 실크햇: 넓은 챙 + 높은 원통 + 자주 띠.
static func _top_hat(head: Node3D) -> void:
	var root := _hat_root(head, "TopHat", 0.0)
	root.rotation = Vector3(-0.05, 0, -0.05)
	var felt := RoundKit.clay("outfit_top_hat", "1b191e", 0.5)
	var shape := RoundKit.rounded_profile(PackedVector2Array([Vector2(0, -0.012), Vector2(0.255, -0.012), Vector2(0.262, 0.012),
		Vector2(0.18, 0.018), Vector2(0.188, 0.27), Vector2(0, 0.275)]), 0.012, 3)
	RoundKit.lathe(root, "TopHat", shape, Vector3.ZERO, felt, 36)
	MeshKit.mesh_node(root, "TopHatBand", RoundKit.ring_mesh("outfit_top_hat_band", 0.183, RoundKit.rounded_rect_profile(Vector2(0.01, 0.045), 0.004, 3), 36),
		Vector3(0, 0.05, 0), RoundKit.clay("outfit_top_hat_band", "6e2a55", 0.5))


## 밀짚모자: 아주 넓고 얇은 챙 + 낮은 둥근 머리 + 빨간 띠.
static func _straw_hat(head: Node3D) -> void:
	var root := _hat_root(head, "StrawHat", -0.01)
	root.rotation = Vector3(-0.1, 0, 0.04)
	var straw := RoundKit.clay("outfit_straw_hat", "d8b56c", 0.95)
	var shape := RoundKit.rounded_profile(PackedVector2Array([Vector2(0, -0.01), Vector2(0.34, -0.01), Vector2(0.36, 0.004),
		Vector2(0.19, 0.022), Vector2(0.192, 0.1), Vector2(0.14, 0.15), Vector2(0, 0.158)]), 0.012, 3)
	RoundKit.lathe(root, "StrawHat", shape, Vector3.ZERO, straw, 40)
	MeshKit.mesh_node(root, "StrawHatBand", RoundKit.ring_mesh("outfit_straw_hat_band", 0.193, RoundKit.rounded_rect_profile(Vector2(0.01, 0.035), 0.004, 3), 40),
		Vector3(0, 0.045, 0), RoundKit.clay("outfit_straw_hat_band", "b8343a", 0.6))


static func _hat_root(head: Node3D, name_: String, lift: float) -> Node3D:
	var root := Node3D.new()
	root.name = name_
	root.position = NpcOutfit.HEAD_AXIS + Vector3(0, NpcOutfit.HAT_BASE_Y + lift, 0)
	root.scale = Vector3(1, 1, NpcOutfit.HAT_DEPTH_SCALE)
	head.add_child(root)
	return root


# ─────────────────────────────── 안경 · 수염 · 시가 ───────────────────────────────

## 선글라스: 둥근 동그란 안경(NpcOutfit 와 같은 자리)에 짙은 알을 끼운다. 알은 납작한 원판(빛을 조금 반사).
static func _sunglasses(head: Node3D, lens_color: String, frame_color: String, lens_rough: float) -> void:
	var frame := RoundKit.clay("outfit_sunglass_frame_" + frame_color, frame_color, 0.35, 0.5)
	var lens := RoundKit.clay("outfit_sunglass_lens_" + lens_color, lens_color, lens_rough, 0.4)
	var eye_y: float = 1.57
	var eye_x: float = 0.1
	var front_z: float = -0.245
	var radius: float = 0.058
	var disc := RoundKit.lathe_mesh(PackedVector2Array([Vector2(0, -0.005), Vector2(radius, -0.005), Vector2(radius, 0.005), Vector2(0, 0.005)]), 24)
	for side: float in [-1.0, 1.0]:
		var center := Vector3(NpcOutfit.HEAD_AXIS.x + side * eye_x, eye_y, front_z)
		var glass := MeshKit.mesh_node(head, "SunglassLens", disc, center, lens)
		glass.rotation.x = PI / 2
		var rim := MeshKit.mesh_node(head, "SunglassRim", RoundKit.ring_mesh("outfit_sunglass_rim", radius, RoundKit.circle_profile(0.007, 6), 24), center, frame)
		rim.rotation.x = PI / 2
		RoundKit.rod(head, "SunglassTemple", center + Vector3(side * radius, 0.0, 0.0), Vector3(NpcOutfit.HEAD_AXIS.x + side * 0.19, eye_y - 0.01, -0.03), 0.006, frame, -1.0, 6)
	var inner: float = eye_x - radius
	RoundKit.rod(head, "SunglassBridge", Vector3(NpcOutfit.HEAD_AXIS.x - inner, eye_y + 0.015, front_z), Vector3(NpcOutfit.HEAD_AXIS.x + inner, eye_y + 0.015, front_z), 0.006, frame, -1.0, 6)


## 두툼한 콧수염: 윗입술 위 넓은 덩어리(가운데가 두껍고 양끝이 아래로 처진다).
static func _thick_mustache(head: Node3D) -> void:
	var hair := RoundKit.clay("outfit_thick_mustache", "2e1d14", 0.8)
	var middle := Vector3(-0.012, 1.37, -0.207)
	for side: float in [-1.0, 1.0]:
		var mid := middle + Vector3(side * 0.04, -0.006, 0.01)
		var tip := middle + Vector3(side * 0.07, -0.03, 0.03)
		RoundKit.rod(head, "ThickMustache", middle, mid, 0.024, hair, 0.02, 10)
		RoundKit.rod(head, "ThickMustacheEnd", mid, tip, 0.02, hair, 0.01, 8)


## 시가: 오른쪽 입꼬리에 물고 앞·아래·바깥으로 내민다. 끝에 불씨 + 가는 연기(art/pub/cigar_smoke.gd 의 wisp).
static func _cigar(head: Node3D) -> void:
	var holder := Node3D.new()
	holder.name = "MouthCigar"
	head.add_child(holder)
	# 홀더의 +Z = 시가가 뻗는 쪽(RG Poly 시가는 원점 = 꽁무니, 불 붙은 끝 = +Z).
	var out := Vector3(0.35, -0.35, -1.0).normalized()
	holder.transform = Transform3D(Basis.looking_at(-out, Vector3.UP), CIGAR_MOUTH)
	var body := PubParts.asset(holder, "cigar", Vector3.ZERO, 0.0, Vector3.ONE * CIGAR_SCALE, "CigarBody", false)
	if body == null:
		var stick := MeshInstance3D.new()
		stick.name = "CigarBody"
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.009
		cylinder.bottom_radius = 0.009
		cylinder.height = CIGAR_LENGTH
		stick.mesh = cylinder
		stick.material_override = RoundKit.clay("outfit_cigar", "6b4128", 0.8)
		stick.rotation.x = PI / 2
		stick.position.z = CIGAR_LENGTH * 0.5
		holder.add_child(stick)
	var ember := MeshInstance3D.new()
	ember.name = "CigarEmber"
	var ember_mesh := SphereMesh.new()
	ember_mesh.radius = 0.009
	ember_mesh.height = 0.014
	ember.mesh = ember_mesh
	var glow := StandardMaterial3D.new()
	glow.resource_name = "MouthCigarEmber"
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.9, 0.6, 0.2)
	ember.material_override = glow
	ember.position = Vector3(0, 0, CIGAR_LENGTH)
	holder.add_child(ember)
	var wisp := CigarSmoke.wisp()
	wisp.amount = 26
	wisp.position = ember.position
	holder.add_child(wisp)


# ─────────────────────────────── 시계 ───────────────────────────────

## 왼쪽 손목 시계: 손목 고리(줄) + 손등 쪽 시계 판. kind 1 금 · 2 은 · 3 전자(검정 줄 + 초록 화면).
static func _watch(skeleton: Skeleton3D, kind: int, size: float = 1.0) -> void:
	var arm: int = skeleton.find_bone("forearm.L")
	var hand: int = skeleton.find_bone("hand.L")
	if arm < 0 or hand < 0:
		return
	var a: Vector3 = skeleton.get_bone_global_rest(arm).origin
	var b: Vector3 = skeleton.get_bone_global_rest(hand).origin
	var along: Vector3 = (b - a).normalized()
	var holder := Node3D.new()
	holder.name = "Watch"
	NpcOutfit.on_bone(skeleton, "forearm.L").add_child(holder)
	# 고리 축(+Y) = 아래팔 방향. 시계 판은 몸 바깥(−X 쪽 = 왼팔 바깥)을 본다.
	var outward: Vector3 = (Vector3.LEFT - along * Vector3.LEFT.dot(along)).normalized()
	var side: Vector3 = along.cross(outward).normalized()
	holder.transform = Transform3D(Basis(side, along, outward), a.lerp(b, WATCH_ALONG))
	holder.scale = Vector3.ONE * size
	var colors: Array = [["c9a24f", "f3ead2", 0.3, 0.85], ["b9bec6", "eef2f5", 0.25, 0.85], ["1d1d22", "4fd27a", 0.6, 0.0]][kind - 1]
	var band := RoundKit.clay("outfit_watch_band_%d" % kind, colors[0], colors[2], colors[3])
	MeshKit.mesh_node(holder, "WatchBand", RoundKit.ring_mesh("outfit_watch_band", WATCH_RADIUS, RoundKit.rounded_rect_profile(Vector2(0.008, 0.024), 0.003, 3), 20),
		Vector3.ZERO, band)
	var face_disc := RoundKit.lathe_mesh(PackedVector2Array([Vector2(0, -0.006), Vector2(0.021, -0.006), Vector2(0.021, 0.006), Vector2(0, 0.006)]), 20)
	var case_node := MeshKit.mesh_node(holder, "WatchCase", face_disc, Vector3(0, 0, WATCH_RADIUS + 0.004), band)
	case_node.rotation.x = PI / 2
	var glass := MeshKit.mesh_node(holder, "WatchFace", RoundKit.sphere_mesh(0.016, 12), Vector3(0, 0, WATCH_RADIUS + 0.008),
		RoundKit.clay("outfit_watch_face_%d" % kind, colors[1], 0.3, 0.0, 0.6 if kind == 3 else 0.0))
	glass.scale = Vector3(1, 1, 0.3)
