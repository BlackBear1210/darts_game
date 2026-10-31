extends Node3D
## 네온 오락실(테마 1)의 "보이는 것". 펍의 바·NPC 자리·당구대·럼주통·창문 묶음을 빼고(TableView.rebuild_pub)
## 같은 자리(같은 충돌 상자)에 오락실 물건을 코드 + RG Poly 모델로 세운다. 규칙은 arcade_rules.gd, 이 파일은 그림과 움직임만.
##
## [2026-10-31 늦은 밤 개편 — 사용자 요청 "네온 사인과 인형뽑기 가게 느낌 · 바텐더 대신 주스·음료를 파는 느낌 · 간판 글자가 창문과 겹쳐 잘림"]
##   바 카운터 자리   → 주스 가게(밝은 카운터 · 주스 디스펜서 · 과일 · 다이너 의자 · 줄무늬 차양 · 메뉴판 · 주스 가게 직원)
##   바 끝 냉장고 자리 → 음료 냉장고(색색 캔)
##   NPC 테이블 자리  → 가챠 기계 2대(규칙 그대로)
##   당구대 자리      → 농구 오락기(규칙 그대로)
##   라운지 오른쪽 뒤  → 인형뽑기 가게: 진짜 기계 1대(규칙) + 장식 기계 4대 + 인형 진열 벽
##   럼주통 자리      → LED 드럼 의자
##   벽 · 천장       → 창문 없음. 글자 크기로 판 크기를 계산한 네온 간판, 천장 보 아래 네온 관, 벽 위 네온 레일
##   다트 홀 옆벽 · 라운지 뒷벽 → 오락기 줄(이 테마에서만 충돌)
## 규칙 좌표(TableView · arcade_rules.gd)는 하나도 바꾸지 않았다 — 게임 흐름·방해 공작·오락실 규칙은 그대로다.
## 움직이지 않는 물건은 _static 아래에 모아 화면이 있을 때 한 번에 묶는다(StaticBatch, 그리기 호출 줄이기).

const Kit = preload("res://art/mesh_kit.gd")
const PubParts = preload("res://art/pub/pub_parts.gd")
const Rules = preload("res://game/lounge/arcade/arcade_rules.gd")
const StaticBatch = preload("res://art/static_batch.gd")
const VENDOR_SCENE := "res://art/characters/chr_bartender.tscn"

const CYAN := Color("3be5db")
const MAGENTA := Color("ef65cb")
const YELLOW := Color("ffd34d")
const ORANGE := Color("ff8a3c")
const VIOLET := Color("8f6bff")
const PINK := Color("ff5aa8")
## 오락기: [놓는 자리(바닥), 정면이 보는 방향 yaw, 화면 위 글자]. 정면 = 로컬 -Z.
## 뒷벽 6대는 펍 소파 자리 양옆, 다트 홀 옆벽 4대는 넓어진 홀(2026-10-31 늦은 밤)의 투척 구역 밖 벽쪽이다.
const CABINETS: Array = [
	[Vector3(-4.4, 0, 8.51), 0.0, "DART\nRUSH"], [Vector3(-3.5, 0, 8.51), 0.0, "NEON\nRACER"], [Vector3(-2.5, 0, 8.51), 0.0, "PUNCH!"],
	[Vector3(2.5, 0, 8.51), 0.0, "SPACE\nDUCK"], [Vector3(3.5, 0, 8.51), 0.0, "RHYTHM\n★"], [Vector3(4.5, 0, 8.51), 0.0, "BLOCK\nDROP"],
	[Vector3(-6.11, 0, -0.65), -PI / 2, "ZOMBIE\nPARTY"], [Vector3(-6.11, 0, -1.55), -PI / 2, "KART\nGP"],
	[Vector3(6.11, 0, -0.65), PI / 2, "PIXEL\nQUEST"], [Vector3(6.11, 0, -1.55), PI / 2, "BEAT\nBOX"]]
## 장식 인형뽑기(진짜 기계 Rules.CLAW_AT 옆). [자리, yaw, 몸통 색]. 뒷벽 3대 + 오른쪽 벽 1대 = ㄱ자 코너.
const CLAW_DECOS: Array = [[Vector3(10.0, 0, 8.3), 0.0, "ff5aa8"], [Vector3(11.2, 0, 8.3), 0.0, "3bc8e5"], [Vector3(12.4, 0, 8.3), 0.0, "ffcf3d"],
	[Vector3(12.9, 0, 7.0), PI / 2, "8f6bff"]]
## 인형 색(곰). 오리는 모델 색 그대로.
const PLUSH_COLORS: Array[Color] = [Color("ff6fae"), Color("49d6e6"), Color("ffd34d"), Color("a98bff"), Color("ff9a52"), Color("7be86a")]

var _static: Node3D
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
## 같은 이름 재질은 하나만 만든다 → 정적 묶기가 같은 재질끼리 합칠 수 있다.
var _materials: Dictionary = {}
var _time: float = 0.0
## 장식 인형(곰) 재질 모음. 손에 드는 인형 소품(prop_looks.gd)은 이 모음을 쓰지 않는다(색을 따로 바꿀 수 있게).
static var _plush_materials: Dictionary = {}


func build() -> void:
	_static = Node3D.new()
	_static.name = "Static"
	add_child(_static)
	_carpet()
	_ceiling_neon()
	_wall_signs()
	_juice_bar()
	_drink_fridge()
	_drums()
	_cabinets()
	_claw_corner()
	_claw_machine()
	_gacha_machines()
	_hoop_machine()
	_small_props()
	_lights()
	# 화면 없는 시험(--headless)에서는 그리지 않으므로 묶지 않는다(펍 _prepare_pub 와 같은 규칙).
	if DisplayServer.get_name() != "headless":
		StaticBatch.optimize(_static)


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


## 이름으로 한 번만 만드는 단색 재질.
func _mat(key: String, color: Color, metal: float = 0.1, rough: float = 0.32) -> StandardMaterial3D:
	if not _materials.has(key):
		var material := _gloss(color, metal, rough)
		material.resource_name = key
		_materials[key] = material
	return _materials[key]


func _glass_mat(key: String, color: Color, alpha: float = 0.16) -> StandardMaterial3D:
	if not _materials.has(key):
		_materials[key] = _glass(color, alpha)
	return _materials[key]


## 네온 재질(숨 쉬듯 밝기가 살짝 변한다 — show_state). 기본 밝기는 메타 "energy" 에 둔다.
func _neon_mat(color: Color, energy: float = 2.4) -> StandardMaterial3D:
	var key := "neon_%s_%.2f" % [color.to_html(false), energy]
	if not _materials.has(key):
		var material := _glow(key, color, energy)
		material.set_meta("energy", energy)
		_materials[key] = material
		_neon.append(material)
	return _materials[key]


## 빛나는 글자(1보다 큰 색). 정면 방향은 yaw(라디안)로 돌린다. 글자는 로컬 +Z 쪽에서 읽힌다.
func _sign(text: String, at: Vector3, yaw: float, size: int, color: Color, pixel: float = 0.006, parent: Node = null) -> Label3D:
	var label := Kit.label(parent if parent != null else _static, "Sign", text, at, size, Color(color.r * 2.2, color.g * 2.2, color.b * 2.2), pixel)
	label.shaded = false
	label.outline_size = 10
	label.outline_modulate = Color(color.darkened(0.6), 0.9)
	label.rotation.y = yaw
	return label


## 글자 묶음의 크기(m). 판 크기를 글자에 맞추려고 쓴다(대략값 — 기본 글꼴로 잰다).
static func text_size(text: String, size: int, pixel: float) -> Vector2:
	var font: Font = ThemeDB.fallback_font
	var measured: Vector2 = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size)
	return measured * pixel


## 벽에 거는 네온 간판: 어두운 아크릴 판 + 빛나는 테두리 관 + 빛나는 글자.
## at = 벽 안쪽 면 위 판 가운데, yaw = 글자가 보는 방향(벽에서 방 안쪽).
## 판 크기를 글자 크기로 계산해 둔다 → 예전처럼 글자가 창문·과녁 판넬 뒤로 들어가 잘리지 않는다(2026-10-31 늦은 밤).
func _neon_sign(text: String, at: Vector3, yaw: float, size: int, color: Color, pixel: float, pad: float = 0.16) -> Vector2:
	var root := Node3D.new()
	root.name = "NeonSign"
	_static.add_child(root)
	root.position = at
	root.rotation.y = yaw
	var extent: Vector2 = text_size(text, size, pixel) + Vector2(pad, pad) * 2.0
	Kit.box(root, "SignBoard", Vector3(extent.x, extent.y, 0.04), Vector3(0, 0, 0.02), _mat("sign_board", Color("0d0a1c"), 0.0, 0.6))
	var tube := _neon_mat(color, 2.0)
	for y: float in [-1.0, 1.0]:
		Kit.box(root, "SignTube", Vector3(extent.x + 0.03, 0.03, 0.03), Vector3(0, y * extent.y / 2.0, 0.05), tube)
	for x: float in [-1.0, 1.0]:
		Kit.box(root, "SignTube", Vector3(0.03, extent.y, 0.03), Vector3(x * extent.x / 2.0, 0, 0.05), tube)
	_sign(text, Vector3(0, 0, 0.06), 0.0, size, color, pixel, root)
	return extent


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


## 벽 안쪽 면 좌표(펍 생성기 _faces 와 같은 값).
static func _faces() -> Dictionary:
	var half: float = TableView.WALL_THICKNESS / 2.0
	return {"hall_x0": TableView.DART_HALL.position.x + half, "hall_x1": TableView.DART_HALL.end.x - half,
		"board_z": TableView.DART_HALL.position.y + half, "step_z": TableView.LOUNGE.position.y + half,
		"lounge_x0": TableView.LOUNGE.position.x + half, "lounge_x1": TableView.LOUNGE.end.x - half,
		"back_z": TableView.LOUNGE.end.y - half}


# ─────────────────────────────── 바닥·천장·벽 ───────────────────────────────

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


## 천장: 벽 위 네온 레일 + 천장 보 아래 네온 관(청록·분홍 번갈아) + 과녁 둘레 고리 · 레인 LED · 빛나는 투척선.
func _ceiling_neon() -> void:
	var hall: Rect2 = TableView.DART_HALL
	var lounge: Rect2 = TableView.LOUNGE
	var f := _faces()
	var ceiling: float = TableView.CEILING_HEIGHT
	var top: float = ceiling - 0.25
	Kit.box(_static, "NeonRail", Vector3(0.05, 0.05, hall.size.y), Vector3(f.hall_x0 + 0.03, top, hall.get_center().y), _neon_mat(CYAN))
	Kit.box(_static, "NeonRail", Vector3(0.05, 0.05, hall.size.y), Vector3(f.hall_x1 - 0.03, top, hall.get_center().y), _neon_mat(MAGENTA))
	Kit.box(_static, "NeonRail", Vector3(f.hall_x1 - f.hall_x0, 0.05, 0.05), Vector3(0, top, f.board_z + 0.03), _neon_mat(YELLOW))
	Kit.box(_static, "NeonRail", Vector3(f.lounge_x1 - f.lounge_x0, 0.05, 0.05), Vector3(lounge.get_center().x, top, f.back_z - 0.03), _neon_mat(VIOLET))
	Kit.box(_static, "NeonRail", Vector3(0.05, 0.05, lounge.size.y), Vector3(f.lounge_x0 + 0.03, top, lounge.get_center().y), _neon_mat(CYAN))
	Kit.box(_static, "NeonRail", Vector3(0.05, 0.05, lounge.size.y), Vector3(f.lounge_x1 - 0.03, top, lounge.get_center().y), _neon_mat(MAGENTA))
	# 천장 보(펍 생성기 _shell 과 같은 자리) 바로 아래 네온 관.
	var beams := [[hall, [-5.4, -2.1]], [lounge, [lounge.position.y + lounge.size.y * 0.22, lounge.get_center().y, lounge.position.y + lounge.size.y * 0.8]]]
	var index := 0
	for entry: Array in beams:
		var room: Rect2 = entry[0]
		for z: float in entry[1]:
			Kit.box(_static, "BeamNeon", Vector3(room.size.x - 0.8, 0.035, 0.05), Vector3(room.get_center().x, ceiling - 0.19, z), _neon_mat(CYAN if index % 2 == 0 else PINK, 2.0))
			index += 1
	var ring := TorusMesh.new()
	ring.inner_radius = 0.86
	ring.outer_radius = 0.92
	ring.rings = 48
	var halo := Kit.mesh_node(_static, "BoardHalo", ring, TableView.BOARD_CENTER + Vector3(0, 0, 0.06), _neon_mat(MAGENTA, 3.0))
	halo.rotation.x = PI / 2
	for side: float in [-1.0, 1.0]:
		var depth: float = TableView.NO_ENTRY_Z - hall.position.y
		Kit.box(_static, "LaneLed", Vector3(0.04, 0.012, depth), Vector3(side * TableView.LANE_HALF, 0.016, (TableView.NO_ENTRY_Z + hall.position.y) / 2.0), _neon_mat(CYAN, 2.0))
	Kit.box(_static, "ThrowLine", Vector3(TableView.LANE_HALF * 2.0, 0.014, 0.06), Vector3(0, 0.017, TableView.THROW_LINE_Z), _neon_mat(YELLOW, 3.0))


## 벽 간판. 창문이 없는 벽 · 과녁 판넬(x ±2.7) 밖 · 오락기·선반 위 높이에만 건다. 판 크기는 글자로 계산.
func _wall_signs() -> void:
	var f := _faces()
	_neon_sign("ARCADE", Vector3(f.hall_x0 + 0.02, 3.2, -3.6), PI / 2, 110, CYAN, 0.008)
	_neon_sign("DARTY", Vector3(f.hall_x1 - 0.02, 3.2, -3.6), -PI / 2, 110, MAGENTA, 0.008)
	_neon_sign("GAME OVER?\nINSERT DART", Vector3(-4.55, 3.1, f.board_z + 0.02), 0.0, 60, VIOLET, 0.006)
	_neon_sign("HI-SCORE\n180", Vector3(4.55, 3.1, f.board_z + 0.02), 0.0, 60, YELLOW, 0.006)
	_neon_sign("★ NEON ARCADE ★", Vector3(0.5, 3.55, f.back_z - 0.02), PI, 90, YELLOW, 0.007)
	_neon_sign("CLAW · 인형뽑기", Vector3(11.2, 3.95, f.back_z - 0.02), PI, 72, PINK, 0.006)
	_neon_sign("PRIZE ZONE", Vector3(f.lounge_x1 - 0.02, 3.3, 7.0), -PI / 2, 64, CYAN, 0.006)


# ─────────────────────────────── 주스 가게(바 자리) ───────────────────────────────

## 바 카운터 자리(TableView.BAR_BOX)를 주스 가게로. 카운터 윗면 = TableView.BAR_TOP_Y(1.1m) — 음료병 소품이 그 위에 선다.
## 카운터 방 쪽 절반(x ≈ -5.15)은 음료병 소품 줄(BAR_BOTTLES_Z)이라 비워 두고, 벽 쪽 절반에 디스펜서·과일을 둔다.
func _juice_bar() -> void:
	var f := _faces()
	var box: AABB = TableView.BAR_BOX
	var center: Vector3 = box.get_center()
	var top_y: float = TableView.BAR_TOP_Y
	var front: float = box.end.x
	var back: float = box.position.x + 0.3
	# 카운터: 보라 몸통 · 하얀 대리석 윗면 · 앞면 네온 타일(분홍·청록) · 윗선·바닥선 LED.
	Kit.box(_static, "JuiceCounter", Vector3(box.size.x, top_y - 0.04, box.size.z), Vector3(center.x, (top_y - 0.04) / 2.0, center.z), _mat("juice_counter", Color("2b1d4d")))
	Kit.box(_static, "JuiceTop", Vector3(box.size.x + 0.1, 0.04, box.size.z + 0.06), Vector3(center.x + 0.05, top_y - 0.02, center.z), _mat("juice_top", Color("ece6f2"), 0.05, 0.25))
	var tiles: int = int(box.size.z / 0.9)
	for i in range(tiles):
		var z: float = box.position.z + box.size.z * (i + 0.5) / tiles
		Kit.box(_static, "JuiceTile", Vector3(0.02, 0.72, box.size.z / tiles - 0.12), Vector3(front + 0.011, 0.5, z), _neon_mat(PINK if i % 2 == 0 else CYAN, 0.55))
	Kit.box(_static, "JuiceLed", Vector3(0.03, 0.03, box.size.z), Vector3(front + 0.04, top_y - 0.07, center.z), _neon_mat(CYAN, 2.2))
	Kit.box(_static, "JuiceLedLow", Vector3(0.03, 0.03, box.size.z), Vector3(front + 0.015, 0.06, center.z), _neon_mat(MAGENTA, 2.0))
	# 주스 디스펜서 3대(오렌지 · 딸기 · 키위): 받침 + 유리 통 + 빛나는 주스 + 뚜껑 + 꼭지.
	var juices: Array[Color] = [Color("ff9a2e"), Color("ff4f8b"), Color("7be86a")]
	for i in range(3):
		var at := Vector3(back, top_y, 0.55 + i * 0.6)
		Kit.box(_static, "DispenserBase", Vector3(0.32, 0.1, 0.3), at + Vector3(0, 0.05, 0), _mat("dispenser_base", Color("d8d8e4"), 0.7, 0.25))
		Kit.cylinder(_static, "DispenserJuice", 0.115, 0.32, at + Vector3(0, 0.27, 0), _neon_mat(juices[i], 0.9), 14)
		Kit.cylinder(_static, "DispenserTank", 0.13, 0.42, at + Vector3(0, 0.31, 0), _glass_mat("dispenser_glass", Color("e6f7ff"), 0.2), 14)
		Kit.cylinder(_static, "DispenserLid", 0.135, 0.04, at + Vector3(0, 0.54, 0), _mat("dispenser_lid", Color("d8d8e4"), 0.7, 0.25), 14)
		Kit.box(_static, "DispenserTap", Vector3(0.08, 0.04, 0.04), at + Vector3(0.17, 0.14, 0), _mat("dispenser_tap", Color("120c12"), 0.0, 0.5))
	# 컵 줄 · 믹서(분홍 스무디).
	for k in range(3):
		PubParts.asset(_static, "juice_cup", Vector3(back + 0.05, top_y + k * 0.085, 2.45), k * 0.4, Vector3.ONE)
	Kit.box(_static, "BlenderBase", Vector3(0.18, 0.12, 0.18), Vector3(back, top_y + 0.06, 2.95), _mat("blender_base", Color("1c1733")))
	Kit.cylinder(_static, "BlenderJar", 0.08, 0.26, Vector3(back, top_y + 0.25, 2.95), _neon_mat(Color("ff7ab8"), 0.7), 10, 0.1)
	# 과일 진열(카운터 끝): 과일 그릇 · 바나나 · 레몬 · 딸기 그릇 · 블루베리 상자 · 와플.
	PubParts.asset(_static, "fruit_bowl", Vector3(back + 0.05, top_y, 5.6), 0.3, Vector3.ONE * 0.9)
	PubParts.asset(_static, "juice_bowl", Vector3(back + 0.02, top_y, 6.2), 0.0, Vector3.ONE * 0.75)
	for k in range(5):
		PubParts.asset(_static, "strawberry", Vector3(back + 0.02 + cos(k * 1.3) * 0.07, top_y + 0.07, 6.2 + sin(k * 1.3) * 0.07), k * 0.7, Vector3.ONE * 1.1)
	for k in range(2):
		PubParts.asset(_static, "banana", Vector3(back + 0.05, top_y + k * 0.05, 6.65 + k * 0.05), 0.4 + k * 0.6, Vector3.ONE * 1.1)
	for k in range(3):
		PubParts.asset(_static, "lemon", Vector3(back - 0.08 + k * 0.1, top_y, 6.95), k * 1.1, Vector3.ONE)
	PubParts.asset(_static, "blueberries", Vector3(back + 0.04, top_y, 7.2), 0.2, Vector3.ONE * 1.2)
	PubParts.asset(_static, "waffle", Vector3(front - 0.2, top_y, 0.45), 0.0, Vector3.ONE * 0.9)
	# 다이너 의자 3개(펍 바 스툴 자리). 모델 0.59m → 1.35배 = 0.8m(카운터 1.1m 에 맞는 높이).
	var z0: float = box.position.z + 0.1
	var length: float = box.size.z - 0.2
	for i in range(3):
		PubParts.asset(_static, "diner_stool", Vector3(front + 0.45, 0, z0 + length * (i + 0.5) / 3.0), i * 0.5, Vector3.ONE * 1.35)
	# 가게 안쪽(왼쪽 벽): 금속 선반(캔·우유) · 싱크대 2개(준비대) · 메뉴판 · 줄무늬 차양 · 간판.
	var shelf := PubParts.asset(_static, "metal_shelf", Vector3(f.lounge_x0 + 0.28, 0, 0.75), PI / 2, Vector3.ONE)
	if shelf != null:
		var shelf_top: float = shelf.mesh.get_aabb().size.y
		for k in range(4):
			PubParts.asset(_static, "soda_can_%d" % k, Vector3(f.lounge_x0 + 0.28, shelf_top, 0.42 + k * 0.2), k * 0.8, Vector3.ONE * 1.3)
		PubParts.asset(_static, "milk", Vector3(f.lounge_x0 + 0.3, shelf_top, 1.18), 0.3, Vector3.ONE)
	for z: float in [5.6, 6.55]:
		PubParts.asset(_static, "prep_sink", Vector3(f.lounge_x0 + 0.46, 0, z), PI / 2, Vector3.ONE)
	_menu_board(Vector3(f.lounge_x0 + 0.02, 1.85, 1.9))
	# 차양: 벽에서 방 쪽으로 내려오는 줄무늬 지붕(2.25~3.1m). 노랑 둘 + 빨강 하나.
	for spec: Array in [["juice_awning", 1.6], ["juice_awning", 4.4], ["juice_awning_red", 7.1]]:
		PubParts.asset(_static, str(spec[0]), Vector3(f.lounge_x0 + 0.62, 2.25, float(spec[1])), 0.0, Vector3.ONE)
	_neon_sign("FRESH JUICE\n생과일 주스 · 음료", Vector3(f.lounge_x0 + 0.02, 3.8, 3.7), PI / 2, 80, ORANGE, 0.006)
	_juice_vendor(Vector3(-6.6, 0, 4.0))


## 메뉴판(왼쪽 벽, 방 쪽 +X 를 본다). 값은 장식(실제 사고파는 규칙은 없다 — 음료병은 예전처럼 공짜로 집는다).
func _menu_board(at: Vector3) -> void:
	var root := Node3D.new()
	root.name = "MenuBoard"
	_static.add_child(root)
	root.position = at
	root.rotation.y = PI / 2
	Kit.box(root, "MenuPanel", Vector3(1.6, 0.74, 0.04), Vector3(0, 0, 0.02), _mat("menu_panel", Color("120c22"), 0.0, 0.7))
	for y: float in [-1.0, 1.0]:
		Kit.box(root, "MenuTube", Vector3(1.63, 0.025, 0.025), Vector3(0, y * 0.37, 0.05), _neon_mat(PINK, 1.8))
	_sign("MENU", Vector3(0, 0.25, 0.05), 0.0, 44, PINK, 0.004, root)
	var items := Kit.label(root, "MenuItems", "딸기 바나나 ····· 3 COIN\n레몬 에이드 ····· 2 COIN\n블루베리 스무디 ··· 3 COIN\n오늘의 탄산 ····· 1 COIN",
		Vector3(0, -0.08, 0.05), 24, Color("f6efe0"), 0.0028)
	items.shaded = false


## 주스 가게 직원: 펍 바텐더 모델을 옷만 바꿔 쓴다(조끼·나비넥타이·콧수염 숨김 → 청록 후드 · 분홍 앞치마 · 분홍 모자).
## 서 있기만 한다(펍 바텐더와 같다). 재질은 모델에서 장면마다 따로라(resource_local_to_scene) 펍 바텐더 색은 안 바뀐다.
func _juice_vendor(at: Vector3) -> void:
	var vendor := (load(VENDOR_SCENE) as PackedScene).instantiate() as Node3D
	vendor.name = "JuiceVendor"
	add_child(vendor)
	vendor.position = at
	vendor.rotation.y = PI / 2
	for path in ["Body/Vest", "Body/BowTieR", "Body/BowTieL", "Body/Neck/MoustacheR", "Body/Neck/MoustacheL"]:
		var node := vendor.get_node_or_null(path) as Node3D
		if node != null: node.visible = false
	var top := _mat("vendor_top", Color("2fc6b6"), 0.0, 0.8)
	for path in ["Body/Hoodie", "Body/Hood", "Body/Pocket", "Body/ArmR/Sleeve", "Body/ArmL/Sleeve"]:
		var mesh := vendor.get_node_or_null(path) as MeshInstance3D
		if mesh != null: mesh.material_override = top
	var body := vendor.get_node_or_null("Body") as Node3D
	if body != null:
		var apron := _mat("vendor_apron", PINK, 0.0, 0.8)
		Kit.box(body, "Apron", Vector3(0.3, 0.4, 0.02), Vector3(0, 0.08, 0.2), apron)
		Kit.box(body, "ApronStrap", Vector3(0.2, 0.18, 0.015), Vector3(0, 0.36, 0.19), apron)
	var neck := vendor.get_node_or_null("Body/Neck") as Node3D
	if neck != null:
		var cap := _mat("vendor_cap", PINK, 0.0, 0.6)
		Kit.cylinder(neck, "Cap", 0.19, 0.1, Vector3(0, 0.56, 0.01), cap, 16)
		Kit.box(neck, "CapBrim", Vector3(0.26, 0.02, 0.16), Vector3(0, 0.52, 0.2), cap)


## 바 끝 냉장고 자리(TableView.BAR_FRIDGE_AT): 하얀 음료 냉장고 + 빛나는 유리문 + 색색 캔 4칸 + "COLD DRINKS".
func _drink_fridge() -> void:
	var at: Vector3 = TableView.BAR_FRIDGE_AT
	var size: Vector3 = TableView.BAR_FRIDGE_SIZE
	var front: float = at.x + size.x / 2.0
	# 몸통은 속이 빈 틀(뒤판·옆판·아래·위) — 유리문 안의 캔이 보이게.
	var shell := _mat("soda_fridge", Color("f3eef8"), 0.1, 0.3)
	var depth: float = size.x - 0.02
	Kit.box(_static, "SodaFridgeBack", Vector3(0.06, size.y, size.z), Vector3(at.x - size.x / 2.0 + 0.03, size.y / 2.0, at.z), shell)
	for dz: float in [-1.0, 1.0]:
		Kit.box(_static, "SodaFridgeSide", Vector3(depth, size.y, 0.06), Vector3(at.x - 0.01, size.y / 2.0, at.z + dz * (size.z / 2.0 - 0.03)), shell)
	Kit.box(_static, "SodaFridgeBase", Vector3(depth, 0.16, size.z), Vector3(at.x - 0.01, 0.08, at.z), shell)
	Kit.box(_static, "SodaFridgeCrown", Vector3(depth, 0.34, size.z), Vector3(at.x - 0.01, size.y - 0.17, at.z), shell)
	Kit.box(_static, "SodaFridgeStripe", Vector3(size.x + 0.01, 0.08, size.z + 0.01), at + Vector3(0, size.y - 0.3, 0), _neon_mat(PINK, 1.6))
	Kit.box(_static, "SodaFridgeGlow", Vector3(0.02, size.y - 0.55, size.z - 0.22), Vector3(front - 0.42, size.y / 2.0 - 0.05, at.z), _neon_mat(Color("dff8ff"), 1.1))
	for shelf in range(4):
		var y: float = 0.32 + shelf * 0.31
		Kit.box(_static, "SodaShelf", Vector3(0.4, 0.02, size.z - 0.2), Vector3(front - 0.22, y, at.z), _mat("soda_shelf", Color("c9c9d6"), 0.6, 0.3))
		for slot in range(6):
			var z: float = at.z - size.z / 2.0 + 0.24 + slot * (size.z - 0.48) / 5.0
			PubParts.asset(_static, "soda_can_%d" % ((shelf + slot) % 4), Vector3(front - 0.2, y + 0.01, z), slot * 0.6, Vector3.ONE * 1.4)
	Kit.box(_static, "SodaDoorGlass", Vector3(0.02, size.y - 0.45, size.z - 0.12), Vector3(front + 0.005, size.y / 2.0 - 0.05, at.z), _glass_mat("soda_glass", Color("bfe9ff"), 0.14))
	_sign("COLD DRINKS", Vector3(front + 0.03, size.y - 0.14, at.z), PI / 2, 40, CYAN, 0.004)


# ─────────────────────────────── 드럼 의자 · 오락기 ───────────────────────────────

func _drums() -> void:
	for at in TableView.BARRELS:
		_drum(at, TableView.BARREL_RADIUS, TableView.BARREL_HEIGHT, MAGENTA)
	for at in TableView.SMALL_BARRELS:
		_drum(at, TableView.SMALL_BARREL_RADIUS, TableView.SMALL_BARREL_HEIGHT, CYAN)
	for at in TableView.NPC_STOOLS:
		_drum(at, TableView.STOOL_RADIUS, TableView.STOOL_HEIGHT, YELLOW)


## LED 드럼(앉을 수 있을 것 같은 둥근 통 + 빛나는 띠 두 줄).
func _drum(at: Vector3, radius: float, height: float, color: Color) -> void:
	Kit.cylinder(_static, "Drum", radius, height, at + Vector3(0, height / 2.0, 0), _mat("drum", Color("1c1733")), 16)
	for y in [0.12, height - 0.06]:
		Kit.cylinder(_static, "DrumLed", radius + 0.01, 0.035, at + Vector3(0, y, 0), _neon_mat(color, 2.0), 16)
	Kit.cylinder(_static, "DrumTop", radius - 0.02, 0.02, at + Vector3(0, height + 0.01, 0), _mat("drum_top_" + color.to_html(false), color.darkened(0.5), 0.0, 0.6), 16)


## 오락기 줄. 이 테마에서만 몸이 부딪힌다. 화면 색은 show_state 가 돌린다(묶지 않는다 — 화면 재질이 오락기마다 따로다).
func _cabinets() -> void:
	var colors: Array[Color] = [CYAN, MAGENTA, YELLOW, VIOLET, ORANGE]
	for index in range(CABINETS.size()):
		var at: Vector3 = CABINETS[index][0]
		var yaw: float = CABINETS[index][1]
		var color: Color = colors[index % colors.size()]
		var root := Node3D.new()
		root.name = "Cabinet"
		_static.add_child(root)
		root.position = at
		root.rotation.y = yaw
		Kit.box(root, "Cabinet", Vector3(0.82, 1.82, 0.6), Vector3(0, 0.91, 0), _mat("cabinet", Color("181330")))
		Kit.box(root, "CabinetSide", Vector3(0.84, 1.84, 0.04), Vector3(0, 0.92, -0.3), _neon_mat(color, 1.4))
		var screen := Kit.box(root, "CabinetScreen", Vector3(0.62, 0.5, 0.02), Vector3(0, 1.3, -0.315), _glow("screen_%d" % index, color.darkened(0.2), 1.6))
		_screens.append(screen)
		Kit.box(root, "CabinetPanel", Vector3(0.8, 0.06, 0.3), Vector3(0, 0.98, -0.42), _mat("cabinet_panel", Color("2a2148")))
		Kit.cylinder(root, "Stick", 0.012, 0.12, Vector3(-0.18, 1.06, -0.45), _mat("ink", Color("120c12")), 6)
		Kit.sphere(root, "StickBall", 0.035, Vector3(-0.18, 1.13, -0.45), _mat("stick_ball", MAGENTA))
		for button in range(3):
			Kit.cylinder(root, "Button", 0.028, 0.03, Vector3(0.04 + button * 0.09, 1.02, -0.45), _neon_mat(colors[(index + button + 1) % colors.size()], 1.6), 10)
		_sign(str(CABINETS[index][2]), Vector3(0, 1.68, -0.33), PI, 40, color, 0.004, root)
		var turned: bool = absf(sin(yaw)) > 0.5
		_body(at + Vector3(0, 0.91, 0), Vector3(0.6, 1.82, 0.82) if turned else Vector3(0.82, 1.82, 0.6))


# ─────────────────────────────── 인형뽑기 가게 ───────────────────────────────

## 곰 인형 한 마리(인형 진열·인형뽑기 안·손에 드는 인형 소품). 머리 앞이 yaw 방향.
## shared = true 면 색별 재질을 같이 쓴다(장식 인형 — 정적 묶기용). 소품(prop_looks.gd)은 false(따로 색을 바꿀 수 있게).
static func _bear(parent: Node3D, at: Vector3, color: Color, yaw: float, size: float = 1.0, shared: bool = false) -> Node3D:
	var bear := Node3D.new()
	parent.add_child(bear)
	bear.position = at
	bear.rotation.y = yaw
	bear.scale = Vector3.ONE * size
	var fur := _plush_mat("fur_" + color.to_html(false), color, 0.9) if shared else _gloss(color, 0.0, 0.9)
	var face := _plush_mat("face_" + color.to_html(false), color.lightened(0.45), 0.9) if shared else _gloss(color.lightened(0.45), 0.0, 0.9)
	var ink := _plush_mat("ink", Color("120c12"), 0.4) if shared else _gloss(Color("120c12"), 0.0, 0.4)
	Kit.sphere(bear, "Body", 0.085, Vector3(0, -0.04, 0), fur, Vector3(1, 1.05, 0.9))
	Kit.sphere(bear, "Head", 0.075, Vector3(0, 0.08, 0.01), fur)
	for side in [-1.0, 1.0]:
		Kit.sphere(bear, "Ear", 0.03, Vector3(side * 0.055, 0.14, 0), fur)
		Kit.sphere(bear, "Eye", 0.011, Vector3(side * 0.027, 0.095, 0.07), ink)
		Kit.sphere(bear, "Arm", 0.03, Vector3(side * 0.085, -0.02, 0.02), fur)
	Kit.sphere(bear, "Snout", 0.032, Vector3(0, 0.065, 0.065), face, Vector3(1, 0.8, 0.6))
	return bear


static func _plush_mat(key: String, color: Color, rough: float) -> StandardMaterial3D:
	if not _plush_materials.has(key):
		_plush_materials[key] = _gloss(color, 0.0, rough)
	return _plush_materials[key]


## 인형 하나: 곰(코드) 또는 오리(RG Poly 모델). 진열·장식 기계 안에 쓴다.
func _plush(parent: Node3D, at: Vector3, yaw: float, pick: int) -> void:
	if pick % 3 == 2 and PubParts.asset(parent, "plush_duck", at - Vector3(0, 0.12, 0), yaw, Vector3.ONE * 0.3) != null:
		return
	_bear(parent, at, PLUSH_COLORS[pick % PLUSH_COLORS.size()], yaw, 0.95, true)


## 인형뽑기 코너: 장식 기계 4대(ㄱ자) + 뒷벽 인형 진열 선반 2단. 진짜 기계(_claw_machine)는 그 앞 Rules.CLAW_AT.
func _claw_corner() -> void:
	var f := _faces()
	for index in range(CLAW_DECOS.size()):
		_claw_deco(CLAW_DECOS[index][0], CLAW_DECOS[index][1], Color(str(CLAW_DECOS[index][2])), index)
	# 진열 선반: 장식 기계 위(2.75m · 3.3m), 뒷벽 x 9.45~12.95.
	var from: float = 9.45
	var to: float = 12.95
	for row in range(2):
		var y: float = 2.75 + row * 0.55
		Kit.box(_static, "PlushShelf", Vector3(to - from, 0.04, 0.28), Vector3((from + to) / 2.0, y, f.back_z - 0.14), _mat("plush_shelf", Color("2a2148")))
		Kit.box(_static, "PlushShelfLed", Vector3(to - from, 0.02, 0.02), Vector3((from + to) / 2.0, y - 0.03, f.back_z - 0.28), _neon_mat([CYAN, PINK][row], 2.0))
		for slot in range(8):
			_plush(_static, Vector3(from + 0.22 + slot * 0.44, y + 0.14, f.back_z - 0.15), PI, slot + row * 3)


## 장식 인형뽑기 한 대(움직이지 않음, 이 테마에서만 충돌). 진짜 기계와 같은 크기(Rules.CLAW_SIZE). 정면 = 로컬 -Z.
func _claw_deco(at: Vector3, yaw: float, shell_color: Color, index: int) -> void:
	var size: Vector3 = Rules.CLAW_SIZE
	var root := Node3D.new()
	root.name = "ClawDeco"
	_static.add_child(root)
	root.position = at
	root.rotation.y = yaw
	var shell := _mat("claw_shell_" + shell_color.to_html(false), shell_color, 0.15, 0.28)
	Kit.box(root, "ClawBase", Vector3(size.x, 0.95, size.z), Vector3(0, 0.475, 0), shell)
	Kit.box(root, "ClawStripe", Vector3(size.x + 0.01, 0.06, size.z + 0.01), Vector3(0, 0.8, 0), _neon_mat(YELLOW, 2.0))
	Kit.box(root, "ClawFloor", Vector3(size.x - 0.08, 0.04, size.z - 0.08), Vector3(0, 0.98, 0), _mat("claw_floor", Color("4b2a6b"), 0.0, 0.8))
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		Kit.box(root, "ClawPost", Vector3(0.05, 1.12, 0.05), Vector3(corner.x * (size.x / 2 - 0.025), 1.5, corner.y * (size.z / 2 - 0.025)), shell)
	Kit.box(root, "ClawHeader", Vector3(size.x + 0.04, 0.36, size.z + 0.04), Vector3(0, 2.23, 0), shell)
	Kit.box(root, "ClawLamp", Vector3(size.x - 0.12, 0.02, size.z - 0.12), Vector3(0, 2.04, 0), _neon_mat(Color("fff3e0"), 1.2))
	Kit.box(root, "ClawHeaderLed", Vector3(size.x + 0.05, 0.04, 0.02), Vector3(0, 2.08, -size.z / 2 - 0.02), _neon_mat(CYAN, 2.4))
	Kit.box(root, "ClawPanel", Vector3(size.x, 0.1, 0.22), Vector3(0, 0.98, -size.z / 2 - 0.08), _mat("cabinet_panel", Color("2a2148")))
	Kit.sphere(root, "ClawKnob", 0.04, Vector3(-0.2, 1.1, -size.z / 2 - 0.08), _mat("claw_knob", Color("ff3b3b")))
	Kit.cylinder(root, "ClawButton", 0.06, 0.05, Vector3(0.18, 1.05, -size.z / 2 - 0.08), _neon_mat(Color("ff3b3b"), 1.8), 14)
	# 멈춰 있는 집게(레일 위 한쪽 구석).
	var rng := RandomNumberGenerator.new()
	rng.seed = 2031 + index
	var head := Vector3(rng.randf_range(-0.3, 0.3), 1.98, rng.randf_range(-0.25, 0.25))
	var metal := _mat("claw_metal", Color("d8d8e4"), 0.9, 0.25)
	Kit.box(root, "Carriage", Vector3(0.14, 0.06, 0.14), head, metal)
	Kit.cylinder(root, "Cable", 0.006, 0.26, head + Vector3(0, -0.15, 0), _mat("ink", Color("120c12")), 5)
	Kit.sphere(root, "HubBall", 0.045, head + Vector3(0, -0.3, 0), metal)
	for finger in range(3):
		var angle: float = TAU * finger / 3.0
		Kit.box(root, "Finger", Vector3(0.018, 0.12, 0.018), head + Vector3(sin(angle) * 0.05, -0.38, cos(angle) * 0.05), metal)
	# 안에 쌓인 인형 7개(두 층).
	for k in range(7):
		var layer: int = 0 if k < 5 else 1
		var spot := Vector3(rng.randf_range(-0.36, 0.36), 1.09 + layer * 0.13, rng.randf_range(-0.3, 0.3))
		_plush(root, spot, rng.randf_range(-0.8, 0.8) + PI, k + index * 2)
	# 유리는 맨 나중에(투명 — 안이 보인다).
	Kit.box(root, "ClawGlass", Vector3(size.x - 0.04, 1.1, size.z - 0.04), Vector3(0, 1.5, 0), _glass_mat("claw_glass", Color("d8f4ff"), 0.12))
	_sign("CLAW", Vector3(0, 2.25, -size.z / 2 - 0.04), PI, 60, shell_color.lightened(0.2), 0.005, root)
	var turned: bool = absf(sin(yaw)) > 0.5
	_body(at + Vector3(0, size.y / 2.0, 0), Vector3(size.z, size.y, size.x) if turned else size)


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
	Kit.box(_claw_body, "ClawLamp", Vector3(size.x - 0.12, 0.02, size.z - 0.12), Vector3(0, 2.04, 0), _neon_mat(Color("fff3e0"), 1.2))
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
	_claw_marquee = _sign("CLAW", at + Vector3(0, 2.25, -size.z / 2 - 0.04), PI, 72, YELLOW, 0.005, self)
	_body(at + Vector3(0, size.y / 2.0, 0), size)
	# 기계 위 큰 오리 인형(가게 마스코트).
	PubParts.asset(_static, "plush_duck", at + Vector3(0.2, size.y + 0.02, 0.1), PI + 0.5, Vector3.ONE * 0.75)


# ─────────────────────────────── 가챠 ───────────────────────────────

func _gacha_machines() -> void:
	var box: AABB = TableView.NPC_TABLE_BOX
	Kit.box(_static, "GachaBase", box.size, box.get_center(), _mat("gacha_base", Color("2b1d4d")))
	Kit.box(_static, "GachaBaseLed", Vector3(0.02, 0.04, box.size.z), Vector3(box.position.x - 0.01, box.end.y - 0.08, box.get_center().z), _neon_mat(YELLOW))
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
		_sign("GACHA", at + Vector3(-0.29, 0.47, 0), -PI / 2, 30, colors[machine].lightened(0.3), 0.0035, self)
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
	_hoop_led = _sign("HOOP\nFEVER", Vector3(center.x, Rules.HOOP_RING.y + 1.02, box.end.z - 0.16), PI, 54, ORANGE, 0.0045, self)
	_hoop_score = _sign("", Vector3(center.x, Rules.HOOP_RING.y + 0.7, box.end.z - 0.17), PI, 26, YELLOW, 0.0035, self)
	Kit.cylinder(self, "HoopButton", 0.07, 0.05, Rules.HOOP_BUTTON + Vector3(0, -0.04, 0), _neon_mat(Color("49ff7a"), 2.0), 14)


## 작은 소품(충돌 없음 — 사람이 다니지 않는 가장자리에만): 가챠 뒤 사탕 병 · 냉장고 위 화분 · 다트 홀 오락기 옆 휴지통.
func _small_props() -> void:
	var gacha: AABB = TableView.NPC_TABLE_BOX
	for z: float in [gacha.position.z + 0.18, gacha.end.z - 0.18]:
		PubParts.asset(_static, "candy_jar", Vector3(gacha.end.x - 0.2, gacha.end.y, z), z, Vector3.ONE * 1.2)
	var fridge: Vector3 = TableView.BAR_FRIDGE_AT
	for dz: float in [-0.4, 0.4]:
		PubParts.asset(_static, "plant_pot", fridge + Vector3(-0.1, TableView.BAR_FRIDGE_SIZE.y, dz), dz, Vector3.ONE * 1.2)
	PubParts.asset(_static, "trash_bin", Vector3(6.15, 0, 0.45), 0.3, Vector3.ONE)
	PubParts.asset(_static, "trash_bin", Vector3(-6.15, 0, 0.45), 1.2, Vector3.ONE)


## 색 조명(그림자 없음). 오락실 분위기는 대부분 빛나는 재질이 내고, 여기 빛은 바닥·사람에 색을 묻히는 정도.
func _lights() -> void:
	for spec in [[Rules.CLAW_AT + Vector3(0, 2.0, -0.2), MAGENTA, 2.6, 3.2], [Vector3(11.2, 2.9, 7.4), Color("ff7ad9"), 2.2, 5.0],
			[Rules.GACHA_AT[0] + Vector3(-0.4, 1.1, 0.37), YELLOW, 1.8, 3.0], [Rules.HOOP_RING + Vector3(0, 0.4, -0.8), ORANGE, 2.2, 3.5],
			[Vector3(-3.5, 3.6, -3.0), CYAN, 1.6, 7.5], [Vector3(3.5, 3.6, -3.0), MAGENTA, 1.6, 7.5],
			[Vector3(-6.4, 3.0, 3.7), Color("ffb347"), 1.8, 6.0], [Vector3(0.5, 3.4, 7.6), VIOLET, 1.4, 6.0]]:
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
	# 오락기 화면 색 순환 + 네온이 아주 살짝 숨 쉰다(기본 밝기의 ±11%).
	for index in range(_screens.size()):
		var material := _screens[index].material_override as StandardMaterial3D
		var hue: float = fmod(_time * 0.07 + index * 0.21, 1.0)
		material.emission = Color.from_hsv(hue, 0.7, 1.0)
		material.albedo_color = material.emission
	var pulse: float = 1.0 + sin(_time * 1.7) * 0.11
	for material in _neon:
		material.emission_energy_multiplier = float(material.get_meta("energy", 2.2)) * pulse
