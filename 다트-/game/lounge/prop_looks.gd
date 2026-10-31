extends RefCounted
## 집어 던지는 소품의 겉모습(코드로 만든 임시안). 디자이너 모델이 오면 res://art/props/<kind>.tscn 을 먼저 쓴다.
## 소품의 원점 = 바닥에 놓였을 때의 무게중심. REST 만큼 바닥에서 띄워 놓는다(LoungeWorld 가 쓴다).
##   bottle 병 · mug 맥주잔 · ball 당구공 · cue 큐대 · hoop_ball 농구공 · plush 곰 인형 · capsule 가챠 캡슐
## 맥주잔(2026-10-31 밤)은 RG Poly 에셋 구운 메시(art/vendor/rg_poly/meshes/mug.res)를 쓴다. 없으면 도형 잔.

const Kit = preload("res://art/mesh_kit.gd")
const RgPoly = preload("res://art/vendor/rg_poly/rg_poly_catalog.gd")
const ArcadeRoom = preload("res://game/lounge/arcade/arcade_room.gd")
## 바닥(또는 탁자) 면에서 원점까지 높이(m).
const REST := {"bottle": 0.13, "mug": 0.075, "ball": 0.06, "cue": 0.03, "hoop_ball": 0.12, "plush": 0.1, "capsule": 0.07}
const NAMES := {"bottle": "병", "mug": "맥주잔", "ball": "당구공", "cue": "큐대", "hoop_ball": "농구공", "plush": "인형", "capsule": "캡슐"}
const POOL_COLORS: Array[Color] = [Color("f2c230"), Color("c7372f"), Color("2c55b8")]
const PLUSH_COLORS: Array[Color] = [Color("ff8fc6"), Color("7fe3d1"), Color("ffd36b")]
const CAPSULE_COLORS: Array[Color] = [Color("ff5a7a"), Color("3fb7ff"), Color("ffd34d"), Color("9b6bff")]
const BOTTLE_COLORS: Array[Color] = [Color("3f9e5a"), Color("8a5a2b"), Color("4fa3c7")]
## 디자이너 모델에서 이 이름의 재질만 변형 색으로 다시 칠한다(디자인 요청서 5번).
const VARIANT_MATERIAL := "M_Variant"


## kind 의 겉모습 노드. variant 는 같은 종류 안의 색 번호.
static func make(kind: String, variant: int) -> Node3D:
	var path := "res://art/props/%s.tscn" % kind
	if ResourceLoader.exists(path):
		var model := (load(path) as PackedScene).instantiate() as Node3D
		_tint_variant(model, _variant_color(kind, variant))
		return model
	var node := Node3D.new()
	match kind:
		"bottle": _bottle(node, variant)
		"mug": _mug(node)
		"ball": _pool_ball(node, variant)
		"cue": _cue(node)
		"hoop_ball": _basketball(node)
		"plush": ArcadeRoom._bear(node, Vector3(0, 0.02, 0), PLUSH_COLORS[variant % PLUSH_COLORS.size()], 0.0, 1.25)
		"capsule": _capsule(node, variant)
	return node


static func _variant_color(kind: String, variant: int) -> Color:
	match kind:
		"bottle": return BOTTLE_COLORS[variant % BOTTLE_COLORS.size()]
		"ball": return POOL_COLORS[variant % POOL_COLORS.size()]
		"plush": return PLUSH_COLORS[variant % PLUSH_COLORS.size()]
		"capsule": return CAPSULE_COLORS[variant % CAPSULE_COLORS.size()]
	return Color.WHITE


## 모델 안 M_Variant 재질 면을 color 로 칠한다(투명도는 모델 값을 유지). 다른 재질은 그대로 둔다.
static func _tint_variant(model: Node, color: Color) -> void:
	for found in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := found as MeshInstance3D
		if mesh_node.mesh == null: continue
		for surface in range(mesh_node.mesh.get_surface_count()):
			var material := mesh_node.get_active_material(surface) as BaseMaterial3D
			if material == null or material.resource_name != VARIANT_MATERIAL: continue
			var tinted := material.duplicate() as BaseMaterial3D
			tinted.albedo_color = Color(color, material.albedo_color.a)
			mesh_node.set_surface_override_material(surface, tinted)


static func _glassy(color: Color, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, alpha)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.08
	material.metallic_specular = 0.8
	return material


static func _solid(color: Color, rough: float = 0.4, metal: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = rough
	material.metallic = metal
	return material


## 유리병: 몸통 · 어깨 · 목 · 뚜껑 · 라벨 띠. 글자는 따로 Label3D(LoungeWorld 가 SODA/PUB 로 바꾼다).
static func _bottle(node: Node3D, variant: int) -> void:
	var glass := _glassy(BOTTLE_COLORS[variant % BOTTLE_COLORS.size()], 0.72)
	Kit.cylinder(node, "Body", 0.07, 0.2, Vector3(0, -0.03, 0), glass, 12)
	Kit.cylinder(node, "Shoulder", 0.07, 0.06, Vector3(0, 0.1, 0), glass, 12, 0.03)
	Kit.cylinder(node, "Neck", 0.026, 0.09, Vector3(0, 0.175, 0), glass, 10)
	Kit.cylinder(node, "Cap", 0.03, 0.022, Vector3(0, 0.23, 0), _solid(Color("e8c34a"), 0.3, 0.7), 10)
	Kit.cylinder(node, "LabelBand", 0.072, 0.08, Vector3(0, -0.02, 0), _solid(Color("fff3dc"), 0.7), 12)


## 맥주잔: 나무 잔 모델(0.25m → 0.6배 ≈ 높이 0.15m). 원점이 무게중심이 되게 반 높이만큼 내린다.
## 위에 맥주 거품 원판을 얹어 "채운 잔"으로 보이게 한다(쏟으면 잔이 치워졌다가 다시 채워져 나온다).
static func _mug(node: Node3D) -> void:
	var mesh: Mesh = RgPoly.mesh("mug")
	if mesh == null:
		Kit.cylinder(node, "Mug", 0.06, 0.15, Vector3.ZERO, _solid(Color("7d5034"), 0.8), 12)
		return
	var model := MeshInstance3D.new()
	model.name = "Mug"
	model.mesh = mesh
	model.scale = Vector3.ONE * 0.6
	model.position = Vector3(0, -REST.mug - mesh.get_aabb().position.y * 0.6, 0)
	node.add_child(model)
	Kit.cylinder(node, "Foam", 0.055, 0.012, Vector3(0, REST.mug - 0.02, 0), _solid(Color("f4ecd6"), 0.9), 10)


static func _pool_ball(node: Node3D, variant: int) -> void:
	Kit.sphere(node, "Ball", 0.06, Vector3.ZERO, _solid(POOL_COLORS[variant % POOL_COLORS.size()], 0.15))
	Kit.sphere(node, "Spot", 0.025, Vector3(0, 0, 0.05), _solid(Color("fff8ea"), 0.2), Vector3(1, 1, 0.35))


## 큐대: 가는 끝(파란 초크) → 굵은 손잡이(검은 감개). 세운 상태가 기본, 바닥에 떨어지면 눕는다.
static func _cue(node: Node3D) -> void:
	Kit.cylinder(node, "Shaft", 0.016, 1.1, Vector3(0, 0.1, 0), _solid(Color("e3c48f"), 0.5), 8, 0.009)
	Kit.cylinder(node, "Butt", 0.019, 0.32, Vector3(0, -0.6, 0), _solid(Color("4a2a1a"), 0.4), 8, 0.017)
	Kit.cylinder(node, "Wrap", 0.0195, 0.16, Vector3(0, -0.52, 0), _solid(Color("15121a"), 0.8), 8)
	Kit.cylinder(node, "Tip", 0.009, 0.02, Vector3(0, 0.66, 0), _solid(Color("2f6fd6"), 0.9), 8)


static func _basketball(node: Node3D) -> void:
	Kit.sphere(node, "Ball", 0.12, Vector3.ZERO, _solid(Color("f0782e"), 0.75))
	for axis in [Vector3.ZERO, Vector3(PI / 2, 0, 0), Vector3(0, 0, PI / 2)]:
		var seam := TorusMesh.new()
		seam.inner_radius = 0.118
		seam.outer_radius = 0.124
		seam.rings = 20
		seam.ring_segments = 4
		Kit.mesh_node(node, "Seam", seam, Vector3.ZERO, _solid(Color("2a160c"), 0.8)).rotation = axis


## 가챠 캡슐: 위 반구 색 · 아래 반구 흰색 · 가운데 띠.
static func _capsule(node: Node3D, variant: int) -> void:
	var top := SphereMesh.new()
	top.radius = 0.07
	top.height = 0.07
	top.is_hemisphere = true
	top.radial_segments = 14
	top.rings = 5
	Kit.mesh_node(node, "Top", top, Vector3.ZERO, _glassy(CAPSULE_COLORS[variant % CAPSULE_COLORS.size()], 0.85))
	var bottom := top.duplicate() as SphereMesh
	Kit.mesh_node(node, "Bottom", bottom, Vector3.ZERO, _solid(Color("f6f1ea"), 0.3)).rotation.x = PI
	var band := TorusMesh.new()
	band.inner_radius = 0.066
	band.outer_radius = 0.074
	band.rings = 16
	band.ring_segments = 4
	Kit.mesh_node(node, "Band", band, Vector3.ZERO, _solid(Color("120c12"), 0.5))
