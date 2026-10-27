extends RefCounted
## 펍 소품 조립 도구 + 공용 재질. 쇼케이스 펍(pub.tscn)과 F5 경기 방(pub_game.tscn) 생성기가 같이 쓴다.
## 스툴·테이블·조명 모양을 바꾸려면 여기만 고치고 생성기를 다시 돌린다 → 두 장면이 같이 바뀐다.
## 모든 함수는 parent 기준 로컬 좌표(m)를 받는다. 메시만 만들고 충돌은 만들지 않는다(충돌은 game/table/table.gd 담당).

const MeshKit = preload("res://art/mesh_kit.gd")


# --- 공용 재질(기획 2-6 환경 팔레트를 펍 조명 아래에서 조금 어둡게 맞춘 값) ---
# MeshKit.material 은 같은 이름이면 같은 재질을 돌려준다 → 같은 재질끼리 실행 중 한 번에 그려진다(static_batch.gd).

static func wood() -> StandardMaterial3D:
	return MeshKit.material("WoodWalnut", "68442f")

static func trim() -> StandardMaterial3D:
	return MeshKit.material("WoodDark", "302b24")

static func green() -> StandardMaterial3D:
	return MeshKit.material("ForestPanel", "24483e")

static func inset_green() -> StandardMaterial3D:
	return MeshKit.material("InsetGreen", "1d3b34")

static func brass() -> StandardMaterial3D:
	return MeshKit.material("AgedBrass", "c4a566", 0.65)

static func cream() -> StandardMaterial3D:
	return MeshKit.material("PlasterCream", "c3b496")

static func dark() -> StandardMaterial3D:
	return MeshKit.material("NearBlack", "172523")

## 전구·선반 조명처럼 스스로 빛나는 재질.
static func warm_glow() -> StandardMaterial3D:
	return MeshKit.material("WarmLight", "ffd9a0", 0, 1.2)

static func rope() -> StandardMaterial3D:
	return MeshKit.material("RopeBurgundy", "854c40")

static func felt() -> StandardMaterial3D:
	return MeshKit.material("TableFelt", "326757")

static func chalk_board() -> StandardMaterial3D:
	return MeshKit.material("ChalkBoard", "1f2b27")


## 스툴 한 개(좌석·놋쇠 테·다리 4개). 좌석 윗면 높이 0.57m. accent 는 좌석 색.
static func stool(parent: Node3D, pos: Vector3, accent: Material, node_name := "Stool") -> Node3D:
	var s := Node3D.new()
	s.name = node_name
	parent.add_child(s)
	s.position = pos
	MeshKit.cylinder(s, "Seat", 0.26, 0.10, Vector3(0, 0.52, 0), accent)
	MeshKit.cylinder(s, "SeatTrim", 0.27, 0.045, Vector3(0, 0.455, 0), brass())
	for x: float in [-0.15, 0.15]:
		for z: float in [-0.15, 0.15]:
			MeshKit.rod(s, "Leg", Vector3(x * 1.25, 0.02, z * 1.25), Vector3(x, 0.46, z), 0.034, trim())
	for x: float in [-0.18, 0.18]:
		MeshKit.rod(s, "Brace", Vector3(x, 0.19, -0.18), Vector3(x, 0.19, 0.18), 0.018, brass())
	return s


## 원형 카드 테이블. radius = 상판 반지름, height = 상판 윗면 높이(나무 테두리 기준).
## 쇼케이스는 지름 2.48m·높이 0.765m, F5 경기는 TableView 충돌 크기(지름 2.1m·높이 0.85m)에 맞춘다.
static func round_table(parent: Node3D, pos: Vector3, radius: float, height: float, node_name := "CardTable") -> Node3D:
	var t := Node3D.new()
	t.name = node_name
	t.position = pos
	parent.add_child(t)
	MeshKit.cylinder(t, "PedestalFoot", 0.58, 0.10, Vector3(0, 0.07, 0), trim())
	MeshKit.cylinder(t, "Pedestal", 0.18, height - 0.175, Vector3(0, (height - 0.005) / 2.0, 0), wood(), 10)
	MeshKit.cylinder(t, "TableEdge", radius, 0.13, Vector3(0, height - 0.065, 0), wood(), 48)
	MeshKit.cylinder(t, "BrassEdge", radius + 0.005, 0.025, Vector3(0, height - 0.013, 0), brass(), 48)
	MeshKit.cylinder(t, "Felt", radius - 0.07, 0.012, Vector3(0, height + 0.005, 0), felt(), 48)
	var logo := MeshKit.label(t, "TableBrand", "다 티\n소셜 클럽", Vector3(0, height + 0.014, 0), 55, Color("c8ba82"), 0.0016)
	logo.rotation.x = -PI / 2
	return t


## 천장 펜던트 조명(전선·갓·놋쇠 테·전구 + 실제 빛). ceiling_y = 천장 높이.
## 밝기를 바꿀 때는 energy, 빛이 닿는 거리는 light_range. shadow 를 켜면 그림자가 생기지만 무거워진다.
static func pendant(parent: Node3D, pos: Vector3, ceiling_y: float, energy := 0.65, light_range := 6.5, shadow := false, size := 1.0) -> OmniLight3D:
	MeshKit.cylinder(parent, "PendantCable", 0.009, ceiling_y - pos.y, Vector3(pos.x, (ceiling_y + pos.y) / 2, pos.z), trim(), 6)
	MeshKit.cylinder(parent, "PendantShade", 0.43 * size, 0.25 * size, pos, green(), 12, 0.15 * size)
	MeshKit.cylinder(parent, "PendantRim", 0.434 * size, 0.025, pos + Vector3(0, -0.13 * size, 0), brass(), 12)
	MeshKit.sphere(parent, "PendantBulb", 0.10 * size, pos + Vector3(0, -0.13 * size, 0), warm_glow())
	var light := OmniLight3D.new()
	light.name = "PendantLight"
	light.position = pos + Vector3(0, -0.3 * size, 0)
	light.light_color = Color("ffdbad")
	light.light_energy = energy
	light.omni_range = light_range
	light.omni_attenuation = 1.2
	light.shadow_enabled = shadow
	parent.add_child(light)
	return light


## 벽등(벽에 붙은 작은 등). facing = 벽에서 방 쪽으로 향하는 방향(예: Vector3.BACK).
static func sconce(parent: Node3D, pos: Vector3, facing: Vector3, energy := 0.35) -> void:
	MeshKit.box(parent, "SconcePlate", Vector3(0.14, 0.24, 0.14) * (Vector3.ONE - facing.abs() * 0.8), pos, brass())
	MeshKit.cylinder(parent, "SconceShade", 0.11, 0.16, pos + facing * 0.13 + Vector3(0, 0.05, 0), green(), 8, 0.06)
	MeshKit.sphere(parent, "SconceBulb", 0.05, pos + facing * 0.13 - Vector3(0, 0.02, 0), warm_glow())
	var light := OmniLight3D.new()
	light.name = "SconceLight"
	light.position = pos + facing * 0.3
	light.light_color = Color("ffc98c")
	light.light_energy = energy
	light.omni_range = 3.2
	parent.add_child(light)


## 놋쇠 기둥 하나(받침·기둥·꼭지). 높이 약 0.95m.
static func stanchion(parent: Node3D, pos: Vector3) -> void:
	MeshKit.cylinder(parent, "StanchionBase", 0.14, 0.04, pos + Vector3(0, 0.02, 0), brass())
	MeshKit.cylinder(parent, "Stanchion", 0.025, 0.87, pos + Vector3(0, 0.455, 0), brass())
	MeshKit.sphere(parent, "Finial", 0.055, pos + Vector3(0, 0.92, 0), brass())


## 두 기둥 사이에 처진 빨간 로프. a·b 는 기둥 바닥 위치. sag = 가운데가 처지는 정도(m).
static func rope_between(parent: Node3D, a: Vector3, b: Vector3, sag := 0.17) -> void:
	for j in range(8):
		var t := float(j) / 8
		var u := float(j + 1) / 8
		var p := a.lerp(b, t) + Vector3(0, 0.89 - sin(t * PI) * sag, 0)
		var q := a.lerp(b, u) + Vector3(0, 0.89 - sin(u * PI) * sag, 0)
		MeshKit.rod(parent, "VelvetRope", p, q, 0.022, rope())


## 밤 창문(사진 없이 도형만). 벽에 붙일 때 rot_y 로 방향을 돌린다(뒷벽 = 0).
static func window(parent: Node3D, pos: Vector3, rot_y := 0.0) -> Node3D:
	var w := Node3D.new()
	w.name = "Window"
	w.position = pos
	w.rotation.y = rot_y
	parent.add_child(w)
	MeshKit.box(w, "WindowFrame", Vector3(2.15, 1.9, 0.14), Vector3.ZERO, trim())
	MeshKit.box(w, "NightGlass", Vector3(1.96, 1.7, 0.03), Vector3(0, 0, 0.10), MeshKit.material("BlueNightGlass", "344f5b", 0.15, 0.12))
	for dx: float in [-0.65, 0.0, 0.65]:
		MeshKit.box(w, "Mullion", Vector3(0.04, 1.7, 0.05), Vector3(dx, 0, 0.14), brass())
	MeshKit.box(w, "MullionHorizontal", Vector3(1.96, 0.04, 0.05), Vector3(0, 0, 0.14), brass())
	MeshKit.box(w, "Sill", Vector3(2.26, 0.11, 0.30), Vector3(0, -0.96, 0.14), wood())
	return w


## 구석 화분(각진 가구 사이에 다른 실루엣 하나).
static func plant(parent: Node3D, pos: Vector3) -> void:
	MeshKit.cylinder(parent, "Planter", 0.32, 0.42, pos + Vector3(0, 0.22, 0), MeshKit.material("Terracotta", "986c4c"), 10, 0.4)
	for i in range(9):
		var a := i * TAU / 9.0
		MeshKit.rod(parent, "PlantStem", pos + Vector3(0, 0.4, 0), pos + Vector3(cos(a) * 0.4, 1.1 + (i % 3) * 0.17, sin(a) * 0.4), 0.025, green())
		var leaf := MeshKit.sphere(parent, "PlantLeaf", 0.2, pos + Vector3(cos(a) * 0.38, 1.15 + (i % 3) * 0.17, sin(a) * 0.38), MeshKit.material("Leaf", "456f4e"), Vector3(0.5, 1.7, 0.25))
		leaf.rotation = Vector3(0.3, a, 0.45)


## 병 선반(라벨 없는 병 3단). 벽에 붙일 때 rot_y 로 돌린다. width = 선반 길이(m).
static func bottle_shelf(parent: Node3D, pos: Vector3, rot_y: float, width := 4.2) -> Node3D:
	var shelf := Node3D.new()
	shelf.name = "BottleLibrary"
	parent.add_child(shelf)
	shelf.position = pos
	shelf.rotation.y = rot_y
	MeshKit.box(shelf, "ShelfBack", Vector3(width, 2.2, 0.12), Vector3(0, 2.2, 0), trim())
	for y: float in [1.25, 1.93, 2.61, 3.29]:
		MeshKit.box(shelf, "Shelf", Vector3(width + 0.2, 0.07, 0.34), Vector3(0, y, 0.12), wood())
		MeshKit.box(shelf, "ShelfLight", Vector3(width - 0.2, 0.018, 0.02), Vector3(0, y - 0.045, 0.24), warm_glow())
	var count := int(width / 0.365) - 1
	for row in range(3):
		for j in range(count):
			var x := -0.365 * (count - 1) / 2.0 + j * 0.365
			var y := 1.30 + row * 0.68
			var col: String = ["3c695b", "af7948", "516a77", "7b4641"][(j + row) % 4]
			var mat := MeshKit.material("Bottle_" + str((j + row) % 4), col, 0.15)
			MeshKit.cylinder(shelf, "Bottle", 0.067, 0.26, Vector3(x, y + 0.13, 0.14), mat, 8, 0.052)
			MeshKit.cylinder(shelf, "BottleNeck", 0.028, 0.12, Vector3(x, y + 0.32, 0.14), mat, 8)
			MeshKit.box(shelf, "BlankLabel", Vector3(0.075, 0.09, 0.008), Vector3(x, y + 0.15, 0.202), cream())
	return shelf
