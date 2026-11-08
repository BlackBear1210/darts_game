extends RefCounted
## NPC 의상 부품(바텐더 · 주스 가게 직원 · 손님 모자/안경). 2026-11-08, 디자인 담당 소유.
##
## 사용자 지적 "바텐더는 의상과 디테일이 살아 있어야 해. 다른 캐릭터들과 구분이 가능해야 하거든":
##   다른 작업자가 캐릭터를 Tripo 리깅 캐릭터(art/characters/rigged/tripo_character.glb, 텍스처 입힌 모델)로 바꾸면서
##   예전 "셔츠 재질 색 바꾸기"(Ref_Shirt_Plum)와 안경 부품(Accessory_Glasses)이 없어졌다 → NPC 가 선수와 똑같이 보였다.
##   → 캐릭터 GLB 는 건드리지 않고, 뼈(BoneAttachment3D)에 점토 부품을 붙여 옷을 입힌다.
##     바텐더 = 중절모(볼러) · 콧수염 · 나비넥타이 · 조끼(단추) · 소매 고정 밴드 · 어깨 수건 · 긴 앞치마.
##     주스 직원 = 야구 모자 + 가슴 앞치마(가게 색). 손님 = 비니·야구 모자·안경 중 골라 쓴다.
##
## 치수는 Tripo 캐릭터를 잰 값이다(2026-11-08, 뼈대 공간 m · 정면 = −Z):
##   몸통 앞면 z ≈ −0.05(허리)~+0.01(가슴 위) · 뒷면 z ≈ 0.21 · 몸통 반폭 0.16~0.20 · 어깨 위 y 1.30
##   얼굴 앞면 z ≈ −0.23(y 1.41 코) · 머리 꼭대기 y 1.78 · 머리 가운데 x ≈ −0.025
##   캐릭터 모델을 바꾸면 이 숫자들을 다시 재야 한다(재는 법: 몸통 메시 꼭짓점을 높이 띠별로 x·z 최소/최대).
## 부품은 실행 중에만 만든다(NpcIdle._ready). 펍 생성물(pub_game.tscn)에는 저장되지 않는다(캐릭터 인스턴스 안이라).

const MeshKit = preload("res://art/mesh_kit.gd")
const RoundKit = preload("res://art/pub/round_kit.gd")

enum Outfit { GUEST, BARTENDER, JUICE_VENDOR, GUEST_BEANIE, GUEST_CAP }

## 머리 가운데(뼈대 공간) — 모자를 씌우는 축.
const HEAD_AXIS := Vector3(-0.025, 0.0, 0.0)
## 모자 밑면 높이(머리 꼭대기 1.78 보다 조금 아래 → 머리에 얹혀 보인다).
const HAT_BASE_Y: float = 1.70
## 머리가 앞뒤로 길다(앞뒤 0.40m · 좌우 0.36m) → 모자를 앞뒤로 이만큼 늘려 머리카락이 뚫고 나오지 않게.
const HAT_DEPTH_SCALE: float = 1.12


## model(캐릭터 씬)에 outfit 의상을 입힌다. accent = 손님 모자색·주스 직원 가게 색. glasses = 안경.
static func dress(model: Node3D, outfit: int, accent: Color, glasses: bool) -> void:
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return
	match outfit:
		Outfit.BARTENDER:
			_bartender(skeleton)
		Outfit.JUICE_VENDOR:
			_juice_vendor(skeleton, accent)
		Outfit.GUEST_BEANIE:
			_beanie(_on_bone(skeleton, "head"), accent)
		Outfit.GUEST_CAP:
			_cap(_on_bone(skeleton, "head"), accent)
	if glasses:
		_glasses(_on_bone(skeleton, "head"))


## 뼈 하나에 붙는 "의상 받침" 노드. 이 노드 아래 좌표 = 뼈대 공간(쉬는 자세 기준)이라 위 치수표 숫자를 그대로 쓴다.
## 뼈가 움직이면(몸짓) 받침째 따라 움직인다.
static func _on_bone(skeleton: Skeleton3D, bone: String) -> Node3D:
	var index: int = skeleton.find_bone(bone)
	if index < 0:
		return skeleton
	var holder_name := "Outfit_" + bone.replace(".", "_")
	var existing := skeleton.get_node_or_null(holder_name) as BoneAttachment3D
	if existing != null:
		return existing.get_child(0) as Node3D
	var attach := BoneAttachment3D.new()
	attach.name = holder_name
	attach.bone_name = bone
	skeleton.add_child(attach)
	var rest := Node3D.new()
	rest.name = "Rest"
	rest.transform = skeleton.get_bone_global_rest(index).affine_inverse()
	attach.add_child(rest)
	return rest


static func _clay(key: String, color: String, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	return RoundKit.clay("outfit_" + key, color, rough, metal)


# ─────────────────────────────── 바텐더 ───────────────────────────────

static func _bartender(skeleton: Skeleton3D) -> void:
	var chest := _on_bone(skeleton, "chest")
	var head := _on_bone(skeleton, "head")
	var vest := _clay("vest", "2e1f26", 0.62)
	vest.cull_mode = BaseMaterial3D.CULL_DISABLED
	MeshKit.mesh_node(chest, "Vest", _vest_mesh(), Vector3.ZERO, vest)
	# V 목선 안: 흰 셔츠 앞판(선수 티셔츠가 비쳐 보이지 않게) + V 가장자리 새틴 단(조끼 칸 계단을 덮는다).
	var shirt := _clay("shirt_front", "efe9dc", 0.85)
	shirt.cull_mode = BaseMaterial3D.CULL_DISABLED
	MeshKit.mesh_node(chest, "ShirtFront", _shirt_front_mesh(), Vector3.ZERO, shirt)
	var satin := _clay("vest_lapel", "4a2c38", 0.45)
	for side: float in [-1.0, 1.0]:
		var previous := _v_edge(side, VEST_V_FROM)
		for k in range(1, 7):
			var here := _v_edge(side, lerpf(VEST_V_FROM, VEST_TOP, k / 6.0))
			RoundKit.rod(chest, "VestLapel", previous, here, 0.0095, satin, -1.0, 8)
			previous = here
	# 조끼 단추 3개(V 아래 앞 가운데) — 놋쇠.
	var brass := _clay("brass", "c9a24f", 0.35, 0.8)
	for y: float in [0.96, 0.9, 0.84]:
		MeshKit.mesh_node(chest, "VestButton", RoundKit.sphere_mesh(0.011, 10), Vector3(0, y, _front_z(y) - 0.008), brass)
	# 조끼 주머니 덮개 두 개 + 주머니 시계 금줄.
	for side: float in [-1.0, 1.0]:
		var pocket := MeshKit.rounded_box(chest, "VestPocket", Vector3(0.07, 0.012, 0.012), Vector3(side * 0.085, 0.88, _front_z(0.88) - 0.006), _clay("vest_trim", "1d1418", 0.6), 0.004)
		pocket.rotation.y = side * 0.35
	RoundKit.rod(chest, "WatchChain", Vector3(-0.09, 0.9, _front_z(0.9) - 0.012), Vector3(-0.012, 0.93, _front_z(0.93) - 0.012), 0.003, brass, -1.0, 6)
	# 나비넥타이(흰 셔츠 앞판 위, 턱 바로 아래): 매듭 + 양 날개.
	var tie := _clay("bowtie", "8c1f2a", 0.55)
	var knot := Vector3(-0.005, 1.2, -0.032)
	MeshKit.mesh_node(chest, "BowTieKnot", RoundKit.sphere_mesh(0.017, 12), knot, tie)
	for side: float in [-1.0, 1.0]:
		var wing := MeshKit.rounded_box(chest, "BowTieWing", Vector3(0.055, 0.042, 0.016), knot + Vector3(side * 0.032, 0, 0.004), tie, 0.008)
		wing.rotation.z = side * 0.18
	# 소매 고정 밴드(위팔, 빨강) — 옛날 바텐더의 상징.
	var garter := _clay("garter", "a3272f", 0.5)
	for bone: String in ["upper_arm.L", "upper_arm.R"]:
		var arm := skeleton.find_bone(bone)
		var below := skeleton.find_bone(bone.replace("upper_arm", "forearm"))
		if arm < 0 or below < 0:
			continue
		var a: Vector3 = skeleton.get_bone_global_rest(arm).origin
		var b: Vector3 = skeleton.get_bone_global_rest(below).origin
		var band := MeshKit.mesh_node(_on_bone(skeleton, bone), "SleeveGarter", RoundKit.ring_mesh("outfit_garter", 0.062, RoundKit.rounded_rect_profile(Vector2(0.014, 0.03), 0.006, 3), 20), a.lerp(b, 0.55), garter)
		band.basis = _basis_along((b - a).normalized())
	# 어깨 수건(왼쪽 어깨에 걸쳐 앞뒤로 늘어진 줄무늬 행주): 어깨를 넘는 길을 따라 얇은 천 띠를 민다.
	var towel_path := PackedVector2Array([Vector2(-0.07, 1.09), Vector2(-0.058, 1.17), Vector2(-0.04, 1.25), Vector2(-0.005, 1.305), Vector2(0.05, 1.325),
		Vector2(0.12, 1.322), Vector2(0.185, 1.295), Vector2(0.225, 1.235), Vector2(0.238, 1.15)])
	MeshKit.mesh_node(chest, "Towel", RoundKit.sweep_mesh("outfit_towel", RoundKit.rounded_rect_profile(Vector2(0.115, 0.012), 0.005, 3),
		_drape_rails(towel_path, TOWEL_X, Vector2(0.09, 1.2))), Vector3.ZERO, _clay("towel", "e6dcc6", 0.95))
	var stripe := _clay("towel_stripe", "b23a3a", 0.9)
	for k in range(2):
		var y0: float = 1.115 + k * 0.03
		var piece := PackedVector2Array([Vector2(lerpf(-0.07, -0.058, (y0 - 1.09) / 0.08), y0), Vector2(lerpf(-0.07, -0.058, (y0 + 0.012 - 1.09) / 0.08), y0 + 0.012)])
		MeshKit.mesh_node(chest, "TowelStripe", RoundKit.sweep_mesh("outfit_towel_stripe_%d" % k, RoundKit.rounded_rect_profile(Vector2(0.118, 0.015), 0.005, 3),
			_drape_rails(piece, TOWEL_X, Vector2(0.09, 1.2))), Vector3.ZERO, stripe)
	# 중절모(볼러): 둥근 머리 + 말린 챙 + 빨간 띠. 살짝 기울여 쓴다.
	var hat_root := Node3D.new()
	hat_root.name = "BowlerHat"
	hat_root.position = HEAD_AXIS + Vector3(0, HAT_BASE_Y, 0.0)
	hat_root.rotation = Vector3(-0.08, 0, 0.06)
	hat_root.scale = Vector3(1, 1, HAT_DEPTH_SCALE)
	head.add_child(hat_root)
	var felt := _clay("bowler", "1e1b20", 0.55)
	var bowler := RoundKit.rounded_profile(PackedVector2Array([Vector2(0, -0.012), Vector2(0.17, -0.012), Vector2(0.235, -0.004), Vector2(0.25, 0.012),
		Vector2(0.215, 0.016), Vector2(0.178, 0.026), Vector2(0.182, 0.09), Vector2(0.162, 0.15), Vector2(0.1, 0.185), Vector2(0, 0.192)]), 0.02, 3)
	RoundKit.lathe(hat_root, "Bowler", bowler, Vector3.ZERO, felt, 36)
	MeshKit.mesh_node(hat_root, "BowlerBand", RoundKit.ring_mesh("outfit_bowler_band", 0.18, RoundKit.rounded_rect_profile(Vector2(0.01, 0.032), 0.004, 3), 36),
		Vector3(0, 0.046, 0), _clay("bowler_band", "7d1d26", 0.5))
	# 콧수염(끝이 말려 올라간 손잡이 모양): 코끝 바로 아래 윗입술 앞 → 양옆 → 볼 쪽으로 말려 올라감.
	# 코가 길게 아래로 내려온 얼굴이라 코끝(z −0.23)보다 안쪽(윗입술 z ≈ −0.2)에 붙인다.
	var hair := _clay("mustache", "3a2418", 0.7)
	var middle := Vector3(-0.012, 1.372, -0.205)
	for side: float in [-1.0, 1.0]:
		var mid := middle + Vector3(side * 0.045, -0.01, 0.012)
		var tip := middle + Vector3(side * 0.08, 0.012, 0.04)
		RoundKit.rod(head, "Mustache", middle + Vector3(side * 0.006, 0, 0), mid, 0.016, hair, 0.012, 10)
		RoundKit.rod(head, "MustacheCurl", mid, tip, 0.012, hair, 0.006, 8)
	# 긴 앞치마(허리 → 무릎, 검정, 다리를 따라 살짝 둥글게) — 바 앞에서 보면 대부분 카운터에 가린다. 엉덩이 뼈에 붙인다.
	_curved_apron(_on_bone(skeleton, "hips"), "Apron", 0.4, 0.86, _clay("apron", "1c1a20", 0.85))


## 수건 x 자리(왼쪽 어깨 위).
const TOWEL_X: float = -0.155
## 조끼 맨 위 높이.
const VEST_TOP: float = 1.25


## 어깨를 넘는 천 띠의 틀: path = (z, y) 점들(x = at_x 세로면 위), 단면 x = 몸 옆(+X), 단면 y = 길에 수직 바깥쪽(center 반대).
static func _drape_rails(path: PackedVector2Array, at_x: float, center: Vector2) -> Array:
	var rails: Array = []
	for k in range(path.size()):
		var ahead: Vector2 = path[mini(k + 1, path.size() - 1)] - path[maxi(k - 1, 0)]
		var normal := Vector2(-ahead.y, ahead.x).normalized()
		if normal.dot(path[k] - center) < 0.0:
			normal = -normal
		rails.append([Vector3(at_x, path[k].y, path[k].x), Vector3.RIGHT, Vector3(0, normal.y, normal.x)])
	return rails


## 다리 앞을 둥글게 감싸는 앞치마(아래 y0 → 위 y1). 몸 앞면(z −0.085)을 지나는 큰 원호(반지름 0.35m, ±25°)라
## 옆 가장자리도 다리 앞에 남는다(작은 원호면 다리가 앞치마 옆을 뚫고 나왔다).
static func _curved_apron(parent: Node3D, name_: String, y0: float, y1: float, cloth: Material) -> MeshInstance3D:
	var radius: float = 0.35
	var center_z: float = -0.085 + radius
	var rails: Array = []
	for k in range(9):
		var angle: float = deg_to_rad(lerpf(-25.0, 25.0, k / 8.0))
		var out := Vector3(sin(angle), 0, -cos(angle))
		rails.append([Vector3(0, (y0 + y1) / 2.0, center_z) + out * radius, out, Vector3.UP])
	var profile := RoundKit.rounded_rect_profile(Vector2(0.012, y1 - y0), 0.005, 3)
	return MeshKit.mesh_node(parent, name_, RoundKit.sweep_mesh("outfit_apron_%.2f_%.2f" % [y0, y1], profile, rails), Vector3.ZERO, cloth)


## V 가장자리 한 점(side −1 왼쪽 / +1 오른쪽, 높이 y): 조끼 겉면보다 4mm 앞.
static func _v_edge(side: float, y: float) -> Vector3:
	var ring := _vest_ring_at(y)
	var x: float = side * _v_open(y)
	var angle: float = asin(clampf(x / ring.z, -1.0, 1.0))
	return Vector3(x, y, ring.y - ring.w * cos(angle) - 0.004)


static func _v_open(y: float) -> float:
	return maxf(0.0, (y - VEST_V_FROM) / (VEST_TOP - VEST_V_FROM)) * VEST_V_WIDTH


## 흰 셔츠 앞판: V 안쪽을 채우는 다섯 점 판. 몸통 앞면이 볼록해서 1.11m 에서 한 번 꺾는다(평판이면 몸통이 뚫고 나왔다).
static func _shirt_front_mesh() -> ArrayMesh:
	var top_left := Vector3(-0.095, 1.25, 0.0)
	var top_right := Vector3(0.095, 1.25, 0.0)
	var mid_left := Vector3(-0.047, 1.11, -0.043)
	var mid_right := Vector3(0.047, 1.11, -0.043)
	var bottom := Vector3(0.0, 0.985, -0.056)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tri: Array in [[top_left, top_right, mid_right], [top_left, mid_right, mid_left], [mid_left, mid_right, bottom]]:
		var a: Vector3 = tri[0]
		var b: Vector3 = tri[1]
		var c: Vector3 = tri[2]
		# 앞(−Z)이 앞면이 되게(Godot 앞면 = 시계 방향 → (b−a)×(c−a) 가 +Z 쪽).
		if (b - a).cross(c - a).z < 0.0:
			var swap := b
			b = c
			c = swap
		for v: Vector3 in [a, b, c]:
			surface.set_normal(Vector3(0, 0.25, -1).normalized())
			surface.add_vertex(v)
	return surface.commit()


## 조끼: 몸통을 감싸는 타원 고리를 높이마다 쌓은 껍데기(앞 가운데는 V 로 열림). 뼈대 공간 좌표.
## [높이, 앞뒤 가운데 z, 좌우 반지름, 앞뒤 반지름] — 몸통 잰 값 + 1.5cm 여유. 사이 높이는 2cm 마다 섞어 촘촘히 쌓는다.
const VEST_RINGS: Array[Vector4] = [
	Vector4(0.80, 0.090, 0.192, 0.158), Vector4(0.88, 0.087, 0.187, 0.150), Vector4(0.96, 0.078, 0.177, 0.140),
	Vector4(1.04, 0.080, 0.180, 0.140), Vector4(1.12, 0.090, 0.207, 0.137), Vector4(1.18, 0.100, 0.207, 0.122),
	Vector4(1.25, 0.112, 0.196, 0.104)]
## V 목선: 이 높이에서 시작해 맨 위에서 반폭 VEST_V_WIDTH 까지 벌어진다.
const VEST_V_FROM: float = 0.99
const VEST_V_WIDTH: float = 0.1
## 둘레 칸 수 · 세로 칸 높이(m). 촘촘할수록 V 가장자리 계단이 작아진다(가장자리는 새틴 단이 덮는다).
const VEST_SEGMENTS: int = 96
const VEST_STEP: float = 0.02


static func _vest_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bottom: float = VEST_RINGS[0].x
	var rows: int = ceili((VEST_TOP - bottom) / VEST_STEP)
	for row in range(rows):
		var y0: float = bottom + (VEST_TOP - bottom) * row / rows
		var y1: float = bottom + (VEST_TOP - bottom) * (row + 1) / rows
		var ring0 := _vest_ring_at(y0)
		var ring1 := _vest_ring_at(y1)
		for j in range(VEST_SEGMENTS):
			var corners: Array[Vector3] = [_ring_point(ring0, j), _ring_point(ring0, j + 1), _ring_point(ring1, j + 1), _ring_point(ring1, j)]
			var center := (corners[0] + corners[1] + corners[2] + corners[3]) / 4.0
			# V 목선 안쪽 칸은 비운다(앞쪽 반만).
			if center.y > VEST_V_FROM and center.z < ring0.y and absf(center.x) < _v_open(center.y):
				continue
			var outward := Vector3(center.x, 0, center.z - ring0.y).normalized()
			for tri: Array in [[0, 1, 2], [0, 2, 3]]:
				var a: Vector3 = corners[tri[0]]
				var b: Vector3 = corners[tri[1]]
				var c: Vector3 = corners[tri[2]]
				# Godot 앞면 = 시계 방향 → (b−a)×(c−a) 가 안쪽을 보면 바깥이 앞면이다. 반대면 순서를 뒤집는다.
				if (b - a).cross(c - a).dot(outward) > 0.0:
					var swap := b
					b = c
					c = swap
				for v: Vector3 in [a, b, c]:
					var ring := _vest_ring_at(v.y)
					surface.set_normal(Vector3(v.x / (ring.z * ring.z), 0.0, (v.z - ring.y) / (ring.w * ring.w)).normalized())
					surface.add_vertex(v)
	surface.index()
	return surface.commit()


## 높이 y 의 조끼 고리(VEST_RINGS 사이를 섞는다). 값 = [y, 가운데 z, 좌우 반지름, 앞뒤 반지름].
static func _vest_ring_at(y: float) -> Vector4:
	if y <= VEST_RINGS[0].x:
		return VEST_RINGS[0]
	for i in range(VEST_RINGS.size() - 1):
		var a: Vector4 = VEST_RINGS[i]
		var b: Vector4 = VEST_RINGS[i + 1]
		if y <= b.x:
			var mixed: Vector4 = a.lerp(b, (y - a.x) / (b.x - a.x))
			mixed.x = y
			return mixed
	return VEST_RINGS[VEST_RINGS.size() - 1]


static func _ring_point(ring: Vector4, j: int) -> Vector3:
	var angle: float = TAU * float(j % VEST_SEGMENTS) / VEST_SEGMENTS
	# angle 0 = 앞(−Z).
	return Vector3(ring.z * sin(angle), ring.x, ring.y - ring.w * cos(angle))


## 그 높이에서 조끼 앞 가운데 z(단추·주머니를 붙일 자리).
static func _front_z(y: float) -> float:
	var ring := _vest_ring_at(y)
	return ring.y - ring.w


## +Y 축이 direction 을 보게 돌리는 회전(고리를 팔 방향에 맞춘다).
static func _basis_along(direction: Vector3) -> Basis:
	var up := direction.normalized()
	var side := up.cross(Vector3.FORWARD)
	if side.length() < 0.01:
		side = up.cross(Vector3.RIGHT)
	side = side.normalized()
	return Basis(side, up, side.cross(up).normalized())


# ─────────────────────────────── 주스 가게 직원 ───────────────────────────────

static func _juice_vendor(skeleton: Skeleton3D, accent: Color) -> void:
	_cap(_on_bone(skeleton, "head"), accent)
	var chest := _on_bone(skeleton, "chest")
	var cloth := RoundKit.clay("outfit_juice_apron_" + accent.to_html(false), accent.to_html(false), 0.85)
	# 가슴 앞치마: 아래 치마(허리 앞) + 가슴판(위로 갈수록 몸에 붙게 뒤로 기운다) + 목끈 두 줄 + 앞주머니.
	_curved_apron(_on_bone(skeleton, "hips"), "ApronSkirt", 0.47, 0.9, cloth)
	# 가슴판: 위가 몸 쪽(+Z)으로 눕게 기울인다(rotation.x 양수 = 위쪽이 뒤로). 몸통 앞면(1.0m −0.045 → 1.18m −0.005)보다 1.5cm 앞.
	var bib := MeshKit.rounded_box(chest, "ApronBib", Vector3(0.22, 0.25, 0.012), Vector3(0, 1.06, -0.062), cloth, 0.012)
	bib.rotation.x = 0.25
	var pocket := _clay("juice_pocket", "f3efe2", 0.9)
	MeshKit.rounded_box(_on_bone(skeleton, "hips"), "ApronPocket", Vector3(0.16, 0.08, 0.008), Vector3(0, 0.74, -0.097), pocket, 0.006)
	for side: float in [-1.0, 1.0]:
		RoundKit.rod(chest, "ApronStrap", Vector3(side * 0.1, 1.17, -0.012), Vector3(side * 0.07, 1.29, 0.07), 0.009, cloth, -1.0, 6)


# ─────────────────────────────── 모자 · 안경 ───────────────────────────────

## 야구 모자: 둥근 머리 + 앞(−Z) 챙 + 꼭대기 단추.
static func _cap(head: Node3D, accent: Color) -> void:
	var root := Node3D.new()
	root.name = "Cap"
	root.position = HEAD_AXIS + Vector3(0, HAT_BASE_Y - 0.01, 0.0)
	root.scale = Vector3(1, 1, HAT_DEPTH_SCALE)
	head.add_child(root)
	var cloth := RoundKit.clay("outfit_cap_" + accent.to_html(false), accent.to_html(false), 0.75)
	var dome := RoundKit.rounded_profile(PackedVector2Array([Vector2(0, 0), Vector2(0.19, 0), Vector2(0.185, 0.07), Vector2(0.14, 0.135), Vector2(0, 0.155)]), 0.03, 3)
	RoundKit.lathe(root, "CapDome", dome, Vector3.ZERO, cloth, 32)
	# 챙: 앞(−Z)으로 길게 + 앞 끝이 아래로 숙인다(rotation.x 음수 = 앞 끝이 내려감). 짧으면 앞에서 베레모처럼 보였다.
	var visor := MeshKit.mesh_node(root, "CapVisor", RoundKit.rounded_slab_mesh(Vector2(0.26, 0.2), 0.012, 0.07), Vector3(0, 0.0, -0.25), cloth)
	visor.rotation.x = -0.22
	MeshKit.mesh_node(root, "CapButton", RoundKit.sphere_mesh(0.016, 10), Vector3(0, 0.155, 0), cloth)


## 비니(털모자): 둥근 머리 + 접은 단 + 방울.
static func _beanie(head: Node3D, accent: Color) -> void:
	var root := Node3D.new()
	root.name = "Beanie"
	root.position = HEAD_AXIS + Vector3(0, HAT_BASE_Y - 0.05, 0.0)
	root.scale = Vector3(1.03, 1, HAT_DEPTH_SCALE)
	head.add_child(root)
	var knit := RoundKit.clay("outfit_beanie_" + accent.to_html(false), accent.to_html(false), 0.97)
	var dome := RoundKit.rounded_profile(PackedVector2Array([Vector2(0, 0), Vector2(0.195, 0), Vector2(0.19, 0.08), Vector2(0.15, 0.16), Vector2(0, 0.19)]), 0.04, 3)
	RoundKit.lathe(root, "BeanieDome", dome, Vector3.ZERO, knit, 32)
	MeshKit.mesh_node(root, "BeanieCuff", RoundKit.ring_mesh("outfit_beanie_cuff", 0.197, RoundKit.rounded_rect_profile(Vector2(0.03, 0.06), 0.012, 3), 32), Vector3(0, 0.03, 0), knit)
	MeshKit.mesh_node(root, "BeaniePom", RoundKit.sphere_mesh(0.045, 12), Vector3(0, 0.2, 0), _clay("beanie_pom", "f1ece0", 0.98))


## 둥근 안경: 테 두 개 + 코다리 + 다리(귀 쪽으로).
static func _glasses(head: Node3D) -> void:
	var frame := _clay("glasses", "2a2420", 0.4, 0.3)
	# 눈 가운데 y 1.57 · 머리 가운데에서 좌우 ±0.1 · 큰 눈알(반지름 ≈0.045)이 앞으로 튀어나와 테를 그 앞(z −0.245)에 둔다(2026-11-08 미리보기에서 잼).
	var eye_y: float = 1.57
	var eye_x: float = 0.1
	var front_z: float = -0.245
	var lens: float = 0.056
	for side: float in [-1.0, 1.0]:
		var center := Vector3(HEAD_AXIS.x + side * eye_x, eye_y, front_z)
		var rim := MeshKit.mesh_node(head, "GlassesRim", RoundKit.ring_mesh("outfit_glasses_rim", lens, RoundKit.circle_profile(0.006, 6), 24), center, frame)
		rim.rotation.x = PI / 2
		RoundKit.rod(head, "GlassesTemple", center + Vector3(side * lens, 0.0, 0.0), Vector3(HEAD_AXIS.x + side * 0.19, eye_y - 0.01, -0.03), 0.005, frame, -1.0, 6)
	var inner: float = eye_x - lens
	RoundKit.rod(head, "GlassesBridge", Vector3(HEAD_AXIS.x - inner, eye_y + 0.01, front_z), Vector3(HEAD_AXIS.x + inner, eye_y + 0.01, front_z), 0.005, frame, -1.0, 6)
