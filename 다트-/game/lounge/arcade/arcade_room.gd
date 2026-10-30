extends Node3D
## 네온 오락실(테마 1)의 "보이는 것". 펍의 바·NPC 자리·당구대·럼주통 묶음을 빼고(TableView.rebuild_pub)
## 같은 자리(같은 충돌 상자)에 오락실 물건을 코드로 세운다. 규칙은 arcade_rules.gd, 이 파일은 그림과 움직임만.
##
##   바 카운터 자리   → 경품 카운터(유리 진열장) + 왼쪽 벽 경품 선반
##   NPC 테이블 자리  → 가챠 기계 2대
##   당구대 자리      → 농구 오락기(경사판 · 그물 · 백보드 · 링 · 점수 전광판)
##   라운지 뒷벽 오른쪽 → 인형뽑기(이 테마에서만 충돌 상자를 더한다)
##   럼주통 자리      → LED 드럼 의자
##   바닥 · 벽       → 블랙라이트 카펫, 네온 레일, 간판, 오락기 줄
## 모양은 디자이너 모델이 오기 전의 임시안이다(디자인 요청서 "오락실 기계" 항목). 위치·크기는 규칙 상수와 맞춘다.

const Kit = preload("res://art/mesh_kit.gd")
const Rules = preload("res://game/lounge/arcade/arcade_rules.gd")

const CYAN := Color("3be5db")
const MAGENTA := Color("ef65cb")
const YELLOW := Color("ffd34d")
const ORANGE := Color("ff8a3c")
const VIOLET := Color("8f6bff")
## 오락기 줄(라운지 뒷벽). 이름은 화면 위 간판 글자.
const CABINETS: Array = [[-3.5, "DART\nRUSH"], [-2.5, "NEON\nRACER"], [2.5, "PUNCH!"], [3.5, "SPACE\nDUCK"], [4.5, "RHYTHM\n★"]]

var _claw_head: Node3D
var _claw_cable: MeshInstance3D
var _claw_fingers: Array[Node3D] = []
var _claw_body: Node3D
var _claw_marquee: Label3D
var _gacha_cranks: Array[Node3D] = []
var _gacha_bodies: Array[Node3D] = []
var _hoop_ring: Node3D
var _hoop_led: Label3D
var _hoop_score: Label3D
var _screens: Array[MeshInstance3D] = []
var _neon: Array[StandardMaterial3D] = []
var _time: float = 0.0


func build() -> void:
	_carpet()
	_neon_dressing()
	_prize_counter()
	_drums()
	_cabinets()
	_claw_machine()
	_gacha_machines()
	_hoop_machine()
	_lights()


# ─────────────────────────────── 재질 ───────────────────────────────

static func _glow(key: String, color: Color, energy: float = 2.2) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = key
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


static func _gloss(color: Color, metal: float = 0.1, rough: float = 0.32) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metal
	material.roughness = rough
	return material


static func _glass(color: Color, alpha: float = 0.16) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, alpha)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.05
	material.metallic_specular = 0.9
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _neon_mat(color: Color, energy: float = 2.4) -> StandardMaterial3D:
	var material := _glow("neon_%s" % color.to_html(false), color, energy)
	_neon.append(material)
	return material


## 전경 간판 글자(빛나 보이도록 1보다 큰 색). 정면 방향은 yaw(라디안)로 돌린다.
func _sign(text: String, at: Vector3, yaw: float, size: int, color: Color, pixel: float = 0.006) -> Label3D:
	var label := Kit.label(self, "Sign", text, at, size, Color(color.r * 2.2, color.g * 2.2, color.b * 2.2), pixel)
	label.shaded = false
	label.outline_size = 10
	label.outline_modulate = Color(color.darkened(0.6), 0.9)
	label.rotation.y = yaw
	return label


func _body(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	body.position = at


# ─────────────────────────────── 바닥·벽 ───────────────────────────────

## 블랙라이트 카펫 그림(이음매 없는 타일, 2.2m 마다 반복). 파일이 있으면 그것을, 없으면 코드 무늬를 쓴다.
const CARPET_ART := "res://art/arcade/carpet_blacklight.png"


func _carpet() -> void:
	var texture: Texture2D = load(CARPET_ART) as Texture2D if ResourceLoader.exists(CARPET_ART) else _carpet_pattern()
	for room: Rect2 in [TableView.DART_HALL, TableView.LOUNGE]:
		var material := StandardMaterial3D.new()
		material.albedo_texture = texture
		material.emission_enabled = true
		material.emission_texture = texture
		material.emission_energy_multiplier = 0.35
		material.roughness = 0.95
		material.uv1_scale = Vector3(room.size.x / 2.2, room.size.y / 2.2, 1)
		var plane := PlaneMesh.new()
		plane.size = room.size
		# 펍 바닥 널빤지 윗면(0.01m)보다 살짝 위.
		Kit.mesh_node(self, "Carpet", plane, Vector3(room.get_center().x, 0.018, room.get_center().y), material)


## 코드 무늬: 남색 바탕에 형광 고리·지그재그·점을 256px 에 찍는다.
func _carpet_pattern() -> Texture2D:
	var image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	image.fill(Color("0e0b20"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1030
	var colors: Array[Color] = [CYAN, MAGENTA, YELLOW, VIOLET, Color("6bff8a")]
	for index in range(46):
		var color: Color = colors[index % colors.size()]
		var center := Vector2(rng.randf_range(0, 256), rng.randf_range(0, 256))
		var shape: int = index % 3
		for step in range(60):
			var angle: float = TAU * step / 60.0
			var point: Vector2
			if shape == 0:
				point = center + Vector2.from_angle(angle) * 9.0
			elif shape == 1:
				point = center + Vector2(step * 0.5 - 15.0, 6.0 if (step / 6) % 2 == 0 else -6.0)
			else:
				point = center + Vector2.from_angle(angle) * 2.5
			for dx in range(2):
				for dy in range(2):
					var px := Vector2i(int(point.x + dx) % 256, int(point.y + dy) % 256)
					if px.x >= 0 and px.y >= 0: image.set_pixelv(px, color)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

func _neon_dressing() -> void:
	var hall: Rect2 = TableView.DART_HALL
	var lounge: Rect2 = TableView.LOUNGE
	var inset: float = TableView.WALL_THICKNESS * 0.5 + 0.03
	var top: float = TableView.CEILING_HEIGHT - 0.25
	# 천장 아래 네온 레일(왼쪽 청록 · 오른쪽 분홍 · 뒤 노랑).
	Kit.box(self, "NeonRail", Vector3(0.05, 0.05, hall.size.y), Vector3(hall.position.x + inset, top, hall.get_center().y), _neon_mat(CYAN))
	Kit.box(self, "NeonRail", Vector3(0.05, 0.05, hall.size.y), Vector3(hall.end.x - inset, top, hall.get_center().y), _neon_mat(MAGENTA))
	Kit.box(self, "NeonRail", Vector3(hall.size.x, 0.05, 0.05), Vector3(0, top, hall.position.y + inset), _neon_mat(YELLOW))
	Kit.box(self, "NeonRail", Vector3(lounge.size.x, 0.05, 0.05), Vector3(lounge.get_center().x, top, lounge.end.y - inset), _neon_mat(VIOLET))
	Kit.box(self, "NeonRail", Vector3(0.05, 0.05, lounge.size.y), Vector3(lounge.position.x + inset, top, lounge.get_center().y), _neon_mat(CYAN))
	Kit.box(self, "NeonRail", Vector3(0.05, 0.05, lounge.size.y), Vector3(lounge.end.x - inset, top, lounge.get_center().y), _neon_mat(MAGENTA))
	# 과녁 둘레 네온 고리 + 레인 바닥 LED 줄 + 빛나는 투척선.
	var ring := TorusMesh.new()
	ring.inner_radius = 0.86
	ring.outer_radius = 0.92
	ring.rings = 48
	var halo := Kit.mesh_node(self, "BoardHalo", ring, TableView.BOARD_CENTER + Vector3(0, 0, 0.06), _neon_mat(MAGENTA, 3.0))
	halo.rotation.x = PI / 2
	for side in [-1.0, 1.0]:
		var depth: float = TableView.NO_ENTRY_Z - hall.position.y
		Kit.box(self, "LaneLed", Vector3(0.04, 0.012, depth), Vector3(side * TableView.LANE_HALF, 0.016, (TableView.NO_ENTRY_Z + hall.position.y) / 2.0), _neon_mat(CYAN, 2.0))
	Kit.box(self, "ThrowLine", Vector3(TableView.LANE_HALF * 2.0, 0.014, 0.06), Vector3(0, 0.017, TableView.THROW_LINE_Z), _neon_mat(YELLOW, 3.0))
	# 간판. 다트 홀 양옆 벽, 라운지 뒷벽.
	_sign("ARCADE", Vector3(hall.position.x + inset + 0.02, 3.1, -3.0), PI / 2, 120, CYAN, 0.008)
	_sign("DARTY", Vector3(hall.end.x - inset - 0.02, 3.1, -3.0), -PI / 2, 120, MAGENTA, 0.008)
	_sign("★ NEON ARCADE ★", Vector3(lounge.get_center().x + 1.0, 3.35, lounge.end.y - inset - 0.02), PI, 96, YELLOW, 0.007)
	_sign("GAME OVER?\nINSERT DART", Vector3(-3.0, 2.9, hall.position.y + inset + 0.02), 0.0, 64, VIOLET, 0.006)


func _prize_counter() -> void:
	var box: AABB = TableView.BAR_BOX
	var center: Vector3 = box.get_center()
	Kit.box(self, "PrizeCounter", box.size - Vector3(0.02, 0.0, 0.02), center, _gloss(Color("1b1430")))
	Kit.box(self, "PrizeTop", Vector3(box.size.x + 0.32, 0.05, box.size.z), Vector3(center.x + 0.16, box.end.y - 0.025, center.z), _gloss(Color("2a2148"), 0.3, 0.2))
	Kit.box(self, "PrizeLed", Vector3(0.03, 0.04, box.size.z), Vector3(box.end.x + 0.32, box.end.y - 0.06, center.z), _neon_mat(CYAN))
	Kit.box(self, "PrizeLedLow", Vector3(0.03, 0.04, box.size.z), Vector3(box.end.x + 0.01, 0.08, center.z), _neon_mat(MAGENTA))
	# 진열장(유리) 안 경품: 작은 인형·상자·별.
	Kit.box(self, "PrizeGlass", Vector3(box.size.x - 0.1, 0.45, box.size.z - 0.6), Vector3(center.x - 0.1, box.end.y + 0.225, center.z), _glass(Color("bfe9ff"), 0.1))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var colors: Array[Color] = [MAGENTA, CYAN, YELLOW, VIOLET, ORANGE]
	for index in range(14):
		var at := Vector3(center.x - 0.25 + rng.randf_range(-0.12, 0.12), box.end.y + 0.08, box.position.z + 0.5 + index * 0.46)
		if index % 2 == 0: Kit.sphere(self, "Prize", 0.07, at, _gloss(colors[index % colors.size()]), Vector3(1, 1.1, 1))
		else: Kit.box(self, "Prize", Vector3(0.12, 0.12, 0.12), at, _gloss(colors[index % colors.size()]))
	# 왼쪽 벽 경품 선반(곰 인형 줄).
	var wall_x: float = TableView.LOUNGE.position.x + TableView.WALL_THICKNESS * 0.5 + 0.2
	for shelf in range(3):
		var y: float = 1.1 + shelf * 0.62
		Kit.box(self, "PrizeShelf", Vector3(0.36, 0.04, 6.4), Vector3(wall_x, y, 3.75), _gloss(Color("2a2148")))
		Kit.box(self, "PrizeShelfLed", Vector3(0.02, 0.02, 6.4), Vector3(wall_x + 0.18, y - 0.02, 3.75), _neon_mat([CYAN, MAGENTA, YELLOW][shelf]))
		for slot in range(9):
			_bear(self, Vector3(wall_x, y + 0.14, 0.95 + slot * 0.7), colors[(slot + shelf) % colors.size()], PI / 2, 0.9)
	_sign("PRIZE", Vector3(wall_x + 0.05, 3.25, 3.75), PI / 2, 110, YELLOW, 0.008)


## 곰 인형 한 마리(경품 선반·인형뽑기 안). 머리 앞이 yaw 방향.
static func _bear(parent: Node3D, at: Vector3, color: Color, yaw: float, size: float = 1.0) -> Node3D:
	var bear := Node3D.new()
	parent.add_child(bear)
	bear.position = at
	bear.rotation.y = yaw
	bear.scale = Vector3.ONE * size
	var fur := _gloss(color, 0.0, 0.9)
	var face := _gloss(color.lightened(0.45), 0.0, 0.9)
	var ink := _gloss(Color("120c12"), 0.0, 0.4)
	Kit.sphere(bear, "Body", 0.085, Vector3(0, -0.04, 0), fur, Vector3(1, 1.05, 0.9))
	Kit.sphere(bear, "Head", 0.075, Vector3(0, 0.08, 0.01), fur)
	for side in [-1.0, 1.0]:
		Kit.sphere(bear, "Ear", 0.03, Vector3(side * 0.055, 0.14, 0), fur)
		Kit.sphere(bear, "Eye", 0.011, Vector3(side * 0.027, 0.095, 0.07), ink)
		Kit.sphere(bear, "Arm", 0.03, Vector3(side * 0.085, -0.02, 0.02), fur)
	Kit.sphere(bear, "Snout", 0.032, Vector3(0, 0.065, 0.065), face, Vector3(1, 0.8, 0.6))
	return bear


func _drums() -> void:
	for at in TableView.BARRELS:
		_drum(at, TableView.BARREL_RADIUS, TableView.BARREL_HEIGHT, MAGENTA)
	for at in TableView.SMALL_BARRELS:
		_drum(at, TableView.SMALL_BARREL_RADIUS, TableView.SMALL_BARREL_HEIGHT, CYAN)
	for at in TableView.NPC_STOOLS:
		_drum(at, TableView.STOOL_RADIUS, TableView.STOOL_HEIGHT, YELLOW)


## LED 드럼(앉을 수 있을 것 같은 둥근 통 + 빛나는 띠 두 줄).
func _drum(at: Vector3, radius: float, height: float, color: Color) -> void:
	Kit.cylinder(self, "Drum", radius, height, at + Vector3(0, height / 2.0, 0), _gloss(Color("1c1733")), 16)
	for y in [0.12, height - 0.06]:
		Kit.cylinder(self, "DrumLed", radius + 0.01, 0.035, at + Vector3(0, y, 0), _neon_mat(color, 2.0), 16)
	Kit.cylinder(self, "DrumTop", radius - 0.02, 0.02, at + Vector3(0, height + 0.01, 0), _gloss(color.darkened(0.5), 0.0, 0.6), 16)


## 라운지 뒷벽 오락기 줄. 이 테마에서만 몸이 부딪힌다.
func _cabinets() -> void:
	var z: float = TableView.LOUNGE.end.y - TableView.WALL_THICKNESS * 0.5 - 0.34
	var colors: Array[Color] = [CYAN, MAGENTA, YELLOW, VIOLET, ORANGE]
	for index in range(CABINETS.size()):
		var x: float = float(CABINETS[index][0])
		var color: Color = colors[index % colors.size()]
		var at := Vector3(x, 0, z)
		Kit.box(self, "Cabinet", Vector3(0.82, 1.82, 0.6), at + Vector3(0, 0.91, 0), _gloss(Color("181330")))
		Kit.box(self, "CabinetSide", Vector3(0.84, 1.84, 0.04), at + Vector3(0, 0.92, -0.3), _neon_mat(color, 1.4))
		var screen := Kit.box(self, "CabinetScreen", Vector3(0.62, 0.5, 0.02), at + Vector3(0, 1.3, -0.315), _glow("screen_%d" % index, color.darkened(0.2), 1.6))
		_screens.append(screen)
		Kit.box(self, "CabinetPanel", Vector3(0.8, 0.06, 0.3), at + Vector3(0, 0.98, -0.42), _gloss(Color("2a2148")))
		Kit.cylinder(self, "Stick", 0.012, 0.12, at + Vector3(-0.18, 1.06, -0.45), _gloss(Color("120c12")), 6)
		Kit.sphere(self, "StickBall", 0.035, at + Vector3(-0.18, 1.13, -0.45), _gloss(MAGENTA))
		for button in range(3):
			Kit.cylinder(self, "Button", 0.028, 0.03, at + Vector3(0.04 + button * 0.09, 1.02, -0.45), _neon_mat(colors[(index + button + 1) % colors.size()], 1.6), 10)
		_sign(str(CABINETS[index][1]), at + Vector3(0, 1.68, -0.33), PI, 40, color, 0.004)
		_body(at + Vector3(0, 0.91, 0), Vector3(0.82, 1.82, 0.6))


# ─────────────────────────────── 인형뽑기 ───────────────────────────────

func _claw_machine() -> void:
	var at: Vector3 = Rules.CLAW_AT
	var size: Vector3 = Rules.CLAW_SIZE
	_claw_body = Node3D.new()
	add_child(_claw_body)
	_claw_body.position = at
	var shell := _gloss(Color("ff5aa8"), 0.15, 0.28)
	Kit.box(_claw_body, "ClawBase", Vector3(size.x, 0.95, size.z), Vector3(0, 0.475, 0), shell)
	Kit.box(_claw_body, "ClawStripe", Vector3(size.x + 0.01, 0.06, size.z + 0.01), Vector3(0, 0.8, 0), _neon_mat(YELLOW, 2.0))
	Kit.box(_claw_body, "ClawGlass", Vector3(size.x - 0.04, 1.1, size.z - 0.04), Vector3(0, 1.5, 0), _glass(Color("d8f4ff"), 0.12))
	Kit.box(_claw_body, "ClawFloor", Vector3(size.x - 0.08, 0.04, size.z - 0.08), Vector3(0, 0.98, 0), _gloss(Color("4b2a6b"), 0.0, 0.8))
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		Kit.box(_claw_body, "ClawPost", Vector3(0.05, 1.12, 0.05), Vector3(corner.x * (size.x / 2 - 0.025), 1.5, corner.y * (size.z / 2 - 0.025)), shell)
	Kit.box(_claw_body, "ClawHeader", Vector3(size.x + 0.04, 0.36, size.z + 0.04), Vector3(0, 2.23, 0), shell)
	Kit.box(_claw_body, "ClawHeaderLed", Vector3(size.x + 0.05, 0.04, 0.02), Vector3(0, 2.08, -size.z / 2 - 0.02), _neon_mat(CYAN, 2.4))
	# 상품 구멍(앞 왼쪽 구석) + 상품 문.
	Kit.box(_claw_body, "ClawChute", Vector3(0.26, 0.16, 0.26), Vector3(Rules.CLAW_CHUTE.x, 1.06, Rules.CLAW_CHUTE.y), _glass(YELLOW, 0.35))
	Kit.box(_claw_body, "ClawDoor", Vector3(0.32, 0.26, 0.02), Rules.CLAW_DOOR - at + Vector3(0, 0.1, -0.03), _gloss(Color("120c12"), 0.0, 0.5))
	# 조작판(조이스틱 + 큰 버튼).
	Kit.box(_claw_body, "ClawPanel", Vector3(size.x, 0.1, 0.22), Vector3(0, 0.98, -size.z / 2 - 0.08), _gloss(Color("2a2148")))
	Kit.cylinder(_claw_body, "ClawStick", 0.014, 0.14, Vector3(-0.2, 1.08, -size.z / 2 - 0.08), _gloss(Color("120c12")), 6)
	Kit.sphere(_claw_body, "ClawKnob", 0.04, Vector3(-0.2, 1.16, -size.z / 2 - 0.08), _gloss(Color("ff3b3b")))
	Kit.cylinder(_claw_body, "ClawButton", 0.06, 0.05, Vector3(0.18, 1.05, -size.z / 2 - 0.08), _neon_mat(Color("ff3b3b"), 1.8), 14)
	# 레일과 집게 머리.
	for side in [-1.0, 1.0]:
		Kit.box(_claw_body, "ClawRail", Vector3(size.x - 0.08, 0.03, 0.03), Vector3(0, 2.03, side * (size.z / 2 - 0.06)), _gloss(Color("c9c9d6"), 0.8, 0.3))
	_claw_head = Node3D.new()
	add_child(_claw_head)
	var metal := _gloss(Color("d8d8e4"), 0.9, 0.25)
	Kit.box(_claw_head, "Carriage", Vector3(0.14, 0.06, 0.14), Vector3.ZERO, metal)
	_claw_cable = Kit.cylinder(_claw_head, "Cable", 0.006, 1.0, Vector3(0, -0.5, 0), _gloss(Color("222222")), 5)
	var hub := Node3D.new()
	hub.name = "Hub"
	_claw_head.add_child(hub)
	Kit.sphere(hub, "HubBall", 0.045, Vector3.ZERO, metal)
	for index in range(3):
		var pivot := Node3D.new()
		hub.add_child(pivot)
		pivot.rotation.y = TAU * index / 3.0
		var finger := Node3D.new()
		pivot.add_child(finger)
		finger.position = Vector3(0, -0.02, 0.04)
		Kit.box(finger, "Finger", Vector3(0.018, 0.12, 0.018), Vector3(0, -0.06, 0.0), metal)
		Kit.box(finger, "Tip", Vector3(0.018, 0.018, 0.05), Vector3(0, -0.12, -0.02), metal)
		_claw_fingers.append(finger)
	_claw_marquee = _sign("CLAW", at + Vector3(0, 2.25, -size.z / 2 - 0.04), PI, 72, YELLOW, 0.005)
	_body(at + Vector3(0, size.y / 2.0, 0), size)


# ─────────────────────────────── 가챠 ───────────────────────────────

func _gacha_machines() -> void:
	var box: AABB = TableView.NPC_TABLE_BOX
	Kit.box(self, "GachaBase", box.size, box.get_center(), _gloss(Color("2b1d4d")))
	Kit.box(self, "GachaBaseLed", Vector3(0.02, 0.04, box.size.z), Vector3(box.position.x - 0.01, box.end.y - 0.08, box.get_center().z), _neon_mat(YELLOW))
	var colors: Array[Color] = [Color("ff4f6d"), Color("2fc6b6")]
	for machine in range(Rules.GACHA_AT.size()):
		var at: Vector3 = Rules.GACHA_AT[machine]
		var body := Node3D.new()
		add_child(body)
		body.position = at
		_gacha_bodies.append(body)
		var shell := _gloss(colors[machine], 0.1, 0.3)
		Kit.box(body, "GachaBody", Vector3(0.5, 0.52, 0.6), Vector3(0, 0.26, 0), shell)
		Kit.box(body, "GachaFace", Vector3(0.02, 0.4, 0.5), Vector3(-0.26, 0.28, 0), _gloss(Color("fff3dc"), 0.0, 0.5))
		Kit.cylinder(body, "GachaNeck", 0.16, 0.06, Vector3(0, 0.55, 0), shell, 16)
		Kit.sphere(body, "GachaGlobe", 0.27, Vector3(0, Rules.GACHA_GLOBE_Y, 0), _glass(Color("e6f7ff"), 0.14))
		Kit.cylinder(body, "GachaCap", 0.13, 0.08, Vector3(0, Rules.GACHA_GLOBE_Y + 0.27, 0), shell, 16)
		Kit.box(body, "GachaTray", Vector3(0.18, 0.1, 0.2), Rules.GACHA_TRAY + Vector3(0.02, -0.03, 0), _gloss(Color("120c12"), 0.0, 0.5))
		Kit.box(body, "GachaCoin", Vector3(0.02, 0.07, 0.03), Vector3(-0.27, 0.42, -0.16), _neon_mat(YELLOW, 1.6))
		var crank := Node3D.new()
		body.add_child(crank)
		crank.position = Rules.GACHA_CRANK
		Kit.cylinder(crank, "CrankHub", 0.07, 0.03, Vector3.ZERO, _gloss(Color("d8d8e4"), 0.8, 0.25), 12).rotation.z = PI / 2
		Kit.box(crank, "CrankBar", Vector3(0.03, 0.2, 0.04), Vector3(-0.03, 0.0, 0.0), _gloss(Color("d8d8e4"), 0.8, 0.25))
		Kit.sphere(crank, "CrankKnob", 0.03, Vector3(-0.06, 0.09, 0.0), _gloss(colors[1 - machine]))
		_gacha_cranks.append(crank)
		_sign("GACHA", at + Vector3(-0.29, 0.47, 0), -PI / 2, 30, colors[machine].lightened(0.3), 0.0035)
	_sign("가챠 · 1 COIN", Vector3(box.get_center().x + 0.3, 2.35, box.get_center().z), -PI / 2, 48, YELLOW, 0.005)


# ─────────────────────────────── 농구 오락기 ───────────────────────────────

func _hoop_machine() -> void:
	var box: AABB = TableView.POOL_TABLE_BOX
	var center: Vector3 = box.get_center()
	var shell := _gloss(Color("1f2d5c"), 0.15, 0.3)
	Kit.box(self, "HoopBase", box.size, center, shell)
	Kit.box(self, "HoopStripe", Vector3(box.size.x + 0.01, 0.08, box.size.z + 0.01), Vector3(center.x, box.end.y - 0.12, center.z), _neon_mat(ORANGE, 2.2))
	var ramp := Kit.box(self, "HoopRamp", Vector3(box.size.x - 0.1, 0.03, box.size.z - 0.1), Vector3(center.x, box.end.y + 0.06, center.z), _gloss(Color("c8763a"), 0.0, 0.7))
	ramp.rotation.x = -0.08
	Kit.box(self, "HoopLip", Vector3(box.size.x - 0.1, 0.08, 0.04), Vector3(center.x, box.end.y + 0.04, box.position.z + 0.06), shell)
	# 그물(양옆) · 뒤판 · 백보드. 공이 튕기도록 이 테마에서만 충돌을 더한다.
	var net := _glass(Color("bfe9ff"), 0.13)
	var net_from: float = box.position.z + 0.8
	var net_depth: float = box.end.z - net_from
	for x in [box.position.x + 0.02, box.end.x - 0.02]:
		Kit.box(self, "HoopNet", Vector3(0.02, 1.9, net_depth), Vector3(x, box.end.y + 0.95, net_from + net_depth / 2.0), net)
		Kit.box(self, "HoopNetFrame", Vector3(0.04, 0.04, net_depth), Vector3(x, box.end.y + 1.9, net_from + net_depth / 2.0), _neon_mat(CYAN, 1.8))
		_body(Vector3(x, box.end.y + 0.95, net_from + net_depth / 2.0), Vector3(0.04, 1.9, net_depth))
	Kit.box(self, "HoopBack", Vector3(box.size.x, 2.5, 0.06), Vector3(center.x, box.end.y + 1.25, box.end.z - 0.03), shell)
	_body(Vector3(center.x, box.end.y + 1.25, box.end.z - 0.03), Vector3(box.size.x, 2.5, 0.06))
	var board_at := Vector3(center.x, Rules.HOOP_RING.y + 0.3, Rules.HOOP_RING.z + 0.28)
	Kit.box(self, "Backboard", Vector3(1.0, 0.68, 0.03), board_at, _glass(Color("ffffff"), 0.35))
	Kit.box(self, "BackboardSquare", Vector3(0.4, 0.3, 0.035), board_at + Vector3(0, -0.12, -0.002), _neon_mat(ORANGE, 1.6))
	_body(board_at, Vector3(1.0, 0.68, 0.06))
	_hoop_ring = Node3D.new()
	add_child(_hoop_ring)
	_hoop_ring.position = Rules.HOOP_RING
	var torus := TorusMesh.new()
	torus.inner_radius = Rules.HOOP_RADIUS
	torus.outer_radius = Rules.HOOP_RADIUS + 0.025
	torus.rings = 24
	Kit.mesh_node(_hoop_ring, "Ring", torus, Vector3.ZERO, _gloss(Color("ff5a1f"), 0.6, 0.3))
	var hoop_net := CylinderMesh.new()
	hoop_net.top_radius = Rules.HOOP_RADIUS
	hoop_net.bottom_radius = Rules.HOOP_RADIUS * 0.6
	hoop_net.height = 0.28
	hoop_net.cap_top = false
	hoop_net.cap_bottom = false
	Kit.mesh_node(_hoop_ring, "Net", hoop_net, Vector3(0, -0.15, 0), _glass(Color("ffffff"), 0.45))
	Kit.box(_hoop_ring, "RingArm", Vector3(0.06, 0.03, 0.26), Vector3(0, 0, 0.24), _gloss(Color("ff5a1f"), 0.6, 0.3))
	# 점수 전광판(백보드 위). 정면 = -Z(사람 쪽).
	Kit.box(self, "HoopLedBox", Vector3(1.3, 0.5, 0.1), Vector3(center.x, Rules.HOOP_RING.y + 1.0, box.end.z - 0.1), _gloss(Color("0b0816")))
	_hoop_led = _sign("HOOP\nFEVER", Vector3(center.x, Rules.HOOP_RING.y + 1.02, box.end.z - 0.16), PI, 54, ORANGE, 0.0045)
	_hoop_score = _sign("", Vector3(center.x, Rules.HOOP_RING.y + 0.7, box.end.z - 0.17), PI, 26, YELLOW, 0.0035)
	Kit.cylinder(self, "HoopButton", 0.07, 0.05, Rules.HOOP_BUTTON + Vector3(0, -0.04, 0), _neon_mat(Color("49ff7a"), 2.0), 14)


func _lights() -> void:
	for spec in [[Rules.CLAW_AT + Vector3(0, 2.0, -0.2), MAGENTA, 2.6, 3.2], [Rules.GACHA_AT[0] + Vector3(-0.4, 1.1, 0.37), YELLOW, 1.8, 3.0],
			[Rules.HOOP_RING + Vector3(0, 0.4, -0.8), ORANGE, 2.2, 3.5], [Vector3(-3.0, 3.2, -3.0), CYAN, 1.6, 7.0],
			[Vector3(3.0, 3.2, -3.0), MAGENTA, 1.6, 7.0], [Vector3(-5.5, 3.0, 3.8), VIOLET, 1.4, 6.0], [Vector3(3.0, 3.0, 6.4), CYAN, 1.2, 5.0]]:
		var light := OmniLight3D.new()
		light.position = spec[0]
		light.light_color = spec[1]
		light.light_energy = spec[2]
		light.omni_range = spec[3]
		add_child(light)


# ─────────────────────────────── 움직임 ───────────────────────────────

## 규칙 상태를 그림에 옮긴다(모든 화면에서 돈다).
func show_state(rules: RefCounted, now: float, delta: float) -> void:
	_time += delta
	var claw: Dictionary = rules.claw
	var head_at: Vector3 = Rules.claw_world(float(claw.x), float(claw.z), float(claw.drop))
	var top := Vector3(head_at.x, Rules.CLAW_TOP + 0.08, head_at.z)
	_claw_head.global_position = _claw_head.global_position.lerp(top, minf(1.0, delta * 14.0)) if _claw_head.is_inside_tree() else top
	var hub: Node3D = _claw_head.get_node("Hub")
	var length: float = maxf(0.05, top.y - head_at.y)
	hub.position.y = lerpf(hub.position.y, -length, minf(1.0, delta * 14.0))
	_claw_cable.scale = Vector3(1, -hub.position.y, 1)
	_claw_cable.position.y = hub.position.y / 2.0
	# 집게: 내려가는 동안 벌리고, 바닥에서 오므린다. 잡았으면 꽉, 놓치면 헐렁.
	var phase: String = claw.phase
	var open: float = 0.55 if phase == "drop" else (0.1 if int(claw.grab) >= 0 else (0.35 if phase in ["lift", "carry"] else 0.2))
	if phase == "release": open = 0.6
	for finger in _claw_fingers:
		finger.rotation.x = lerpf(finger.rotation.x, -open, minf(1.0, delta * 8.0))
	# 누가 흔들면 기계 전체가 덜컹거린다.
	var shaking: bool = now < float(claw.shake)
	_claw_body.rotation.z = sin(_time * 38.0) * 0.012 if shaking else lerpf(_claw_body.rotation.z, 0.0, minf(1.0, delta * 10.0))
	_claw_marquee.text = "CLAW" if phase == "idle" else ("★ GO! ★" if phase in ["x", "z"] else "· · ·")
	# 가챠 손잡이: 돌린 직후 한 바퀴.
	for machine in range(mini(_gacha_cranks.size(), rules.gacha.size())):
		var age: float = now - float(rules.gacha[machine].crank)
		_gacha_cranks[machine].rotation.x = -TAU * clampf(age / 0.8, 0.0, 1.0)
		_gacha_bodies[machine].scale = Vector3.ONE * (1.0 + sin(clampf(age / 0.5, 0.0, 1.0) * PI) * 0.04)
	# 농구: 링 좌우 이동, 전광판 시간·순위.
	var hoop: Dictionary = rules.hoop
	_hoop_ring.position = Rules.HOOP_RING + Vector3(float(hoop.offset), 0, 0)
	if bool(hoop.running):
		_hoop_led.text = "FEVER\n%02d" % ceili(maxf(0.0, float(hoop.until) - now))
		var lines := PackedStringArray()
		var scores: Dictionary = hoop.scores
		var peers: Array = scores.keys()
		peers.sort_custom(func(a, b) -> bool: return int(scores[a]) > int(scores[b]))
		for peer in peers.slice(0, 3):
			var actor: PlayerView = rules.lounge.game.actors.get(int(peer))
			lines.append("%s %d" % [actor.identity.display_name if actor != null else "?", int(scores[peer])])
		_hoop_score.text = "   ".join(lines)
	else:
		_hoop_led.text = "HOOP\nFEVER" if fmod(_time, 2.0) < 1.4 else "PRESS\nSTART"
		_hoop_score.text = ""
	# 오락기 화면 색 순환 + 네온이 아주 살짝 숨 쉰다.
	for index in range(_screens.size()):
		var material := _screens[index].material_override as StandardMaterial3D
		var hue: float = fmod(_time * 0.07 + index * 0.21, 1.0)
		material.emission = Color.from_hsv(hue, 0.7, 1.0)
		material.albedo_color = material.emission
	var pulse: float = 2.2 + sin(_time * 1.7) * 0.25
	for material in _neon:
		material.emission_energy_multiplier = pulse
