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
##
## [2026-11-07 디자인 요청서(DARTY ROUNDHOUSE) 반영 — 사용자 "디자인과 상호작용 느낌이 이상해"]
##   색: 기계 몸은 크림 에나멜(CREAM) + 남색(NAVY), 네온(시안·마젠타)은 "얇은 가장자리 줄"에만. 예전처럼 옆판 전체가 빛나지 않는다.
##   모양: 상자 대신 둥근 모서리(Kit.rounded_box — 요청서 2장 "캐비닛 큰 모서리 40~100mm").
##   인형뽑기: 조이스틱이 집게 방향대로 기울고(stick_x/z), 조종 중에는 집게 아래 바닥에 시안 조준 고리 + 가는 빛줄기가 뜬다.
##            간판(마퀴)은 남은 초를 센다.
##   가챠: 진열대 위에서 옆을 보던 2대를 앞(-Z, 통로 쪽)을 보게 돌렸다(요청서 3.3). 손잡이는 앞면에서 Z 축으로 돈다.
##        캡슐은 규칙(arcade_rules._step_gacha)이 배출구 → 받침으로 굴려 보낸다.
##   농구: 골이 들어가면 그물이 출렁이고 전광판이 GOAL!, 림에 맞으면 링이 떨린다. 바닥에 3점 선(3m 호)을 그었다.
##   장식 인형뽑기 4대 → 닫힌 경품 진열장 2대(요청서 6.3 A05 — 조작 기계와 헷갈리지 않게 집게·조이스틱이 없다).
##
## [2026-11-08 Codex 라운드하우스 모델(묶음 2) — art/environments/roundhouse/arcade/]
##   오락기 10대 = A(아치형)/B(경사형) GLB 번갈아(_cabinets) · 경품 진열장 2대 = prize_showcase GLB(_prize_showcase)
##   · 뒷벽 대기 벤치(_bench, 새 자리) · 진열 선반 인형 16개 = 다트·주사위·카드 인형 GLB(_plush).
##   조종하는 인형뽑기(_claw_machine)·가챠·농구 기계와 규칙 영역은 그대로다(손에 드는 인형·캡슐은 prop_looks.gd → art/props/).

const Kit = preload("res://art/mesh_kit.gd")
const PubParts = preload("res://art/pub/pub_parts.gd")
const Rules = preload("res://game/lounge/arcade/arcade_rules.gd")
const StaticBatch = preload("res://art/static_batch.gd")
## 천장 보 자리를 펍 생성기와 같이 쓴다(둘이 어긋나면 네온 관이 보에서 떨어진다).
const RoomBuilder = preload("res://art/pub/game_room_builder.gd")
const NpcIdle = preload("res://art/pub/npc_idle.gd")
## 주스 가게 직원 옷(2026-11-08).
const NpcOutfit = preload("res://art/pub/npc_outfit.gd")
## 물레로 깎는 둥근 메시(오락실 테이블 러그).
const RoundKit = preload("res://art/pub/round_kit.gd")
## 직원 서빙(2026-11-08 — 펍 바텐더와 같은 움직임: 주스·캔을 손님 앞에 놓고, 뒤돌아 전자레인지에서 음식을 꺼낸다).
const PubService = preload("res://art/pub/pub_service.gd")
## 주스 가게 직원 통로 x · 손님 앞에 다가서는 x · 음료 진열대/주방대 앞에 다가서는 x · 걸을 수 있는 z.
const SHOP_LANE_X := -6.6
const SHOP_SERVE_X := -6.12
const RACK_REACH_X := -7.3
const KITCHEN_REACH_X := -7.0
const SHOP_LANE_Z := Vector2(0.6, 6.9)
## 왼쪽 벽 음료 진열대(RG Poly StandShelf — 선반 0.08·0.42·0.73m, 긴 쪽 = z, 앞뒤(±X)가 열려 있다) 자리 z.
const RACK_Z := 2.45
const SMALL_RACK_Z := 3.5
const RACK_SHELVES: Array[float] = [0.08, 0.42, 0.73]
## 주방대(RG Poly StationTable 1.25 × 1.0 × 0.88m, 예전 준비 싱크대 자리) 가운데 z · 그 위 전자레인지 z.
const KITCHEN_Z := 6.0
const SHOP_MICROWAVE_Z := 6.25
## 벽 간판·메뉴판을 벽에서 띄우는 거리(m) — 펍 벽 기둥(0.05)·허리 난간(0.078) 앞.
const SIGN_STANDOFF: float = 0.1

const CYAN := Color("3be5db")
const MAGENTA := Color("ef65cb")
const YELLOW := Color("ffd34d")
const ORANGE := Color("ff8a3c")
const VIOLET := Color("8f6bff")
const PINK := Color("ff5aa8")
## 2026-11-07 요청서 2장 오락실 가구 색: 크림 에나멜 · 남색 몸체 · 자두색(유리 안 바닥).
const CREAM := Color("eee8dc")
const NAVY := Color("20283e")
const PLUM := Color("382743")
## 오락기: [놓는 자리(바닥), 정면이 보는 방향 yaw, 화면 위 글자]. 정면 = 로컬 -Z.
## 뒷벽 6대는 펍 소파 자리 양옆, 다트 홀 옆벽 4대는 넓어진 홀(2026-10-31 늦은 밤)의 투척 구역 밖 벽쪽이다.
## 2026-11-08 Codex 묶음 2: 몸이 상자(깊이 0.6m) → 라운드하우스 오락기 A/B(깊이 0.85m). 뒷면이 예전과 같은 벽 틈(0.04m)에
## 오도록 자리를 벽에서 0.125m 당겼다(뒷벽 z 8.51 → 8.385, 옆벽 x ±6.11 → ±5.985). 앞 조작판 끝은 예전과 거의 같다.
const CABINETS: Array = [
	[Vector3(-4.4, 0, 8.385), 0.0, "DART\nRUSH"], [Vector3(-3.5, 0, 8.385), 0.0, "NEON\nRACER"], [Vector3(-2.5, 0, 8.385), 0.0, "PUNCH!"],
	[Vector3(2.5, 0, 8.385), 0.0, "SPACE\nDUCK"], [Vector3(3.5, 0, 8.385), 0.0, "RHYTHM\n★"], [Vector3(4.5, 0, 8.385), 0.0, "BLOCK\nDROP"],
	[Vector3(-5.985, 0, -0.65), -PI / 2, "ZOMBIE\nPARTY"], [Vector3(-5.985, 0, -1.55), -PI / 2, "KART\nGP"],
	[Vector3(5.985, 0, -0.65), PI / 2, "PIXEL\nQUEST"], [Vector3(5.985, 0, -1.55), PI / 2, "BEAT\nBOX"]]
## 라운드하우스 오락실 모델(Codex 묶음 2, 2026-11-08 사용자 승인): <key>/<key>.glb. 원점 = 바닥 가운데, 정면 -Z, 미터 크기 그대로(배율 1).
const ROUNDHOUSE_ARCADE := "res://art/environments/roundhouse/arcade/%s/%s.glb"
## 오락기 A(아치형)·B(경사형) 몸 크기(폭, 높이, 깊이) = 충돌 상자. 번갈아 세운다.
const CABINET_MODELS: Array[String] = ["arcade_cabinet_a", "arcade_cabinet_b"]
const CABINET_SIZE := Vector3(0.75, 1.85, 0.85)
## 장식 경품 진열장(닫힌 유리장, 진짜 인형뽑기 Rules.CLAW_AT 옆 뒷벽). [자리, yaw, 간판 글자 색].
## 2026-11-07: 예전 장식 인형뽑기 4대(ㄱ자)는 진짜 기계와 똑같이 생겨 "어느 게 되는 기계인지" 헷갈렸다 → 2대 · 집게 없음(요청서 6.3 A05).
## 2026-11-08: 라운드하우스 진열장(0.9 × 1.9 × 0.7m)으로 바꾸며 깊이가 0.1m 줄어 뒷면이 예전 자리(z 8.8)에 오게 z 8.4 → 8.45.
const CLAW_DECOS: Array = [[Vector3(10.35, 0, 8.45), 0.0, "ef65cb"], [Vector3(12.15, 0, 8.45), 0.0, "3be5db"]]
## 인형뽑기 조작판의 조이스틱 자리(기계 기준 x). 기계 앞에 서서 +Z 를 보면 +X 가 왼손 쪽이다 →
## 진짜 오락기처럼 조이스틱은 왼손, 내리기 버튼은 오른손(-STICK_X). 2026-11-07 렌더에서 반대로 놓인 것을 보고 고쳤다.
const STICK_X: float = 0.22
## 진열장 크기(폭, 높이, 깊이) = 라운드하우스 prize_showcase 실측(예전 상자 진열장 1.1 × 2.4 × 0.8m). 충돌 상자도 이 크기.
const SHOWCASE_SIZE := Vector3(0.9, 1.9, 0.7)
## 진열장 위 판(TopCanopy) 앞면 가운데 높이 — "PRIZE" 글자 자리.
const SHOWCASE_SIGN_Y: float = 1.845
## 대기 벤치(라운드하우스 arcade_bench, 1.34 × 0.75 × 0.525m). 펍 코드에는 벤치 자리가 없어 새로 정했다(2026-11-08):
## 뒷벽 가운데 "★ NEON ARCADE ★" 간판 아래 — 양쪽 오락기 줄(x ±2.125 안쪽) 사이 빈 벽이고, 카드 테이블 안쪽 자리(z 5.8)와는 2m 넘게 떨어져
## 다트 투척 구역·기계 조작 자리·문(x 8.4) 동선과 겹치지 않는다. 뒷면(+0.27m)이 벽에서 0.05m 떨어지게 z 를 잡았다.
const BENCH_AT := Vector3(0.5, 0, 8.53)
const BENCH_SIZE := Vector3(1.34, 0.75, 0.525)
## 장식 인형(라운드하우스 묶음 2): 다트·주사위·카드 인형을 번갈아 선반에 앉힌다. 몸통 재질 M_Variant 만 PLUSH_COLORS 로 칠한다.
const DECO_PLUSHES: Array[String] = ["plush_dart", "plush_dice", "plush_card"]
## 인형 색. 손에 드는 인형 소품(art/props/plush.tscn)은 prop_looks.gd 의 색을 쓴다.
const PLUSH_COLORS: Array[Color] = [Color("ff6fae"), Color("49d6e6"), Color("ffd34d"), Color("a98bff"), Color("ff9a52"), Color("7be86a")]

var _static: Node3D
var _claw_head: Node3D
var _claw_cable: MeshInstance3D
var _claw_fingers: Array[Node3D] = []
var _claw_body: Node3D
var _claw_marquee: Label3D
## 조이스틱(규칙 stick_x/z 대로 기운다) · 조준 고리(집게 바로 아래 바닥) · 조준 빛줄기.
var _claw_stick: Node3D
var _claw_aim: Node3D
var _claw_beam: MeshInstance3D
var _gacha_cranks: Array[Node3D] = []
var _gacha_bodies: Array[Node3D] = []
var _hoop_ring: Node3D
var _hoop_net: MeshInstance3D
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
	_bench()
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
	root.rotation.y = yaw
	var extent: Vector2 = text_size(text, size, pixel) + Vector2(pad, pad) * 2.0
	# 2026-11-08: 펍 벽에 월넛 기둥·아치 틀·코니스가 생겨(art/pub/game_room_builder.gd) 벽에 딱 붙이면 판이 기둥에 묻힌다 →
	# 판을 벽에서 SIGN_STANDOFF 만큼 띄우고, 위 끝이 코니스 아래(천장 − 0.82m)에 오도록 필요하면 내린다.
	root.position = at + Basis(Vector3.UP, yaw) * Vector3(0, 0, SIGN_STANDOFF)
	root.position.y = minf(at.y, TableView.CEILING_HEIGHT - 0.82 - extent.y / 2.0)
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


## 라운드하우스 오락실 GLB 하나를 장면 그대로(여러 재질·부품 노드 유지) _static 아래에 세운다. 정면 = 로컬 -Z.
## 정적 묶기(StaticBatch)는 이 GLB 아래를 통째로 건너뛴다(UV·텍스처·대마다 다른 화면 재질 보존 — art/static_batch.gd ROUNDHOUSE_DIR).
func _model(key: String, at: Vector3, yaw: float, node_name: String) -> Node3D:
	var node := (load(ROUNDHOUSE_ARCADE % [key, key]) as PackedScene).instantiate() as Node3D
	node.name = node_name
	node.position = at
	node.rotation.y = yaw
	_static.add_child(node)
	return node


## 부품 메시의 경계 상자를 root 기준 좌표로(트리 밖에서도 되게 부모 변환을 직접 곱한다).
static func _box_in(root: Node3D, part: MeshInstance3D) -> AABB:
	var to_root := Transform3D.IDENTITY
	var node: Node = part
	while node != root and node is Node3D:
		to_root = (node as Node3D).transform * to_root
		node = node.get_parent()
	return to_root * part.get_aabb()


## 판(box, 정면 -Z) 앞면에 글자를 판 크기에 맞춰 붙인다(폭 86% · 높이 70% 안). 빈 간판 판을 가진 모델용.
func _fit_sign(text: String, box: AABB, parent: Node3D, color: Color, size: int = 40) -> Label3D:
	var unit: Vector2 = text_size(text, size, 1.0)
	var pixel: float = minf(box.size.x * 0.86 / unit.x, box.size.y * 0.7 / unit.y)
	var center := box.get_center()
	return _sign(text, Vector3(center.x, center.y, box.position.z - 0.004), PI, size, color, pixel, parent)


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
	_table_rug()


## 2026-11-08 사용자 지적 "오락실 맵에는 테이블 아래에 카펫이 없어":
##   펍의 둥근 러그(TableRug, 윗면 0.012m)가 오락실 블랙라이트 카펫(0.018m) 아래에 묻혀 안 보였다.
##   → 카펫 위(윗면 0.022m)에 오락실 색 둥근 러그를 따로 깐다: 진한 보라 바탕 + 청록·분홍 네온 줄 두 겹.
##   자리 깔개(SeatRug, 윗면 0.0245m)는 이보다 높아 그대로 위에 보인다. 크기는 펍 러그와 같다(반지름 2.55m).
func _table_rug() -> void:
	var center: Vector3 = TableView.TABLE_CENTER
	var base := PackedVector2Array([Vector2(0, 0.019), Vector2(2.5, 0.019), Vector2(2.55, 0.02), Vector2(2.5, 0.022), Vector2(0, 0.022)])
	Kit.mesh_node(_static, "ArcadeTableRug", RoundKit.lathe_mesh(base, 64), Vector3(center.x, 0, center.z), _mat("arcade_rug", Color("221a3f"), 0.0, 0.95))
	# 네온 줄: 위에서 보이는 얇은 고리(바탕 윗면보다 0.5mm 위 → 깜빡임 없음).
	for ring: Array in [[2.38, 2.31, CYAN], [2.2, 2.16, MAGENTA]]:
		var stripe := PackedVector2Array([Vector2(ring[0], 0.0225), Vector2(ring[1], 0.0225)])
		Kit.mesh_node(_static, "ArcadeRugStripe", RoundKit.lathe_mesh(stripe, 64), Vector3(center.x, 0, center.z), _neon_mat(ring[2], 0.9))


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


## 천장: 벽 위 네온 레일 + 천장 보 아래 네온 관(청록·분홍 번갈아) · 레인 LED · 빛나는 투척선.
func _ceiling_neon() -> void:
	var hall: Rect2 = TableView.DART_HALL
	var lounge: Rect2 = TableView.LOUNGE
	var f := _faces()
	var ceiling: float = TableView.CEILING_HEIGHT
	# 2026-11-08: 펍 벽 위가 코니스(선반 띠)+코브(곡면)로 바뀌어 예전 높이(천장 − 0.25)의 레일은 코브 속에 묻힌다 →
	# 코니스 바로 아래, 코니스 앞 끝(벽에서 0.135m)보다 조금 앞에 띄워 "코니스 아랫선 네온"으로 보이게 한다.
	var top: float = ceiling - 0.8
	var off: float = 0.16
	Kit.box(_static, "NeonRail", Vector3(0.05, 0.05, hall.size.y), Vector3(f.hall_x0 + off, top, hall.get_center().y), _neon_mat(CYAN))
	Kit.box(_static, "NeonRail", Vector3(0.05, 0.05, hall.size.y), Vector3(f.hall_x1 - off, top, hall.get_center().y), _neon_mat(MAGENTA))
	Kit.box(_static, "NeonRail", Vector3(f.hall_x1 - f.hall_x0 - off * 2.0, 0.05, 0.05), Vector3(0, top, f.board_z + off), _neon_mat(YELLOW))
	Kit.box(_static, "NeonRail", Vector3(f.lounge_x1 - f.lounge_x0 - off * 2.0, 0.05, 0.05), Vector3(lounge.get_center().x, top, f.back_z - off), _neon_mat(VIOLET))
	Kit.box(_static, "NeonRail", Vector3(0.05, 0.05, lounge.size.y), Vector3(f.lounge_x0 + off, top, lounge.get_center().y), _neon_mat(CYAN))
	Kit.box(_static, "NeonRail", Vector3(0.05, 0.05, lounge.size.y), Vector3(f.lounge_x1 - off, top, lounge.get_center().y), _neon_mat(MAGENTA))
	# 천장 줄 자리(펍 생성기 ceiling_beams())에 천장에 붙인 네온 관. 2026-11-08 펍 천장 보가 없어져 천장 바로 아래(−0.06m)로 올렸다.
	# 2026-11-02: 자리를 여기 또 적어 두면 홀 길이가 바뀔 때 어긋나므로 생성기의 ceiling_beams() 를 같이 쓴다.
	var index := 0
	for entry: Array in RoomBuilder.ceiling_beams():
		var room: Rect2 = entry[0]
		for z: float in entry[1]:
			Kit.box(_static, "BeamNeon", Vector3(room.size.x - 0.8, 0.035, 0.05), Vector3(room.get_center().x, ceiling - 0.06, z), _neon_mat(CYAN if index % 2 == 0 else PINK, 2.0))
			index += 1
	# 2026-11-07: 과녁 둘레 분홍 고리(BoardHalo)는 뺐다 — 다트 머신(art/dart_machine/dart_machine.gd)이
	# 오락실 스킨에서 자기 테두리 조명(시안/마젠타 반쪽씩)을 켠다. 고리가 둘이면 과녁 숫자보다 눈에 띈다(요청서 가독성 위계).
	# 레인 LED 는 과녁 벽이 아니라 머신 받침 앞(과녁 면 아래)에서 끝난다.
	for side: float in [-1.0, 1.0]:
		var lane_end: float = TableView.BOARD_CENTER.z
		var depth: float = TableView.NO_ENTRY_Z - lane_end
		Kit.box(_static, "LaneLed", Vector3(0.04, 0.012, depth), Vector3(side * TableView.LANE_HALF, 0.016, (TableView.NO_ENTRY_Z + lane_end) / 2.0), _neon_mat(CYAN, 2.0))
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
	# 카운터: 2026-11-08 사용자 "음료 판매대가 너무 구려 — 에셋 도구로 간판대·서랍·음료 전시대": 보라 상자 + 네온 타일 대신
	# RG Poly 서랍장 모듈(Furnit_A, 파랑 서랍 · 분홍 옆판 · 크림 윗판) 8개를 줄지어 세운다. 서랍 = 모델 +Z → yaw π/2 로 방 쪽(+X).
	# 깊이 0.935m ≈ 바 깊이(0.95m), 높이 1.02m → 1.078배 = 윗면 1.1m(BAR_TOP_Y — 음료병 소품이 그 위에 선다). 충돌은 그대로 BAR_BOX.
	var modules: int = 8
	var width: float = box.size.z / modules
	var drawers: Array[String] = ["drawer_counter_a", "drawer_counter_b", "drawer_counter_c", "drawer_counter_d"]
	for i in range(modules):
		PubParts.asset(_static, drawers[(i * 3) % 4], Vector3(box.position.x + 0.408, 0, box.position.z + width * (i + 0.5)), PI / 2,
			Vector3(width / 0.9, top_y / 1.019, 1.0), "JuiceDrawer")
	Kit.box(_static, "JuiceLed", Vector3(0.03, 0.03, box.size.z), Vector3(front + 0.04, top_y - 0.07, center.z), _neon_mat(CYAN, 2.2))
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
	# 다이너 의자 3개(펍 바 스툴과 같은 자리 TableView.BAR_STOOLS_Z). 모델 0.59m → 1.35배 = 0.8m(카운터 1.1m 에 맞는 높이).
	for i in range(3):
		PubParts.asset(_static, "diner_stool", Vector3(front + 0.45, 0, TableView.BAR_STOOLS_Z[i]), i * 0.5, Vector3.ONE * 1.35)
	# 가게 안쪽(왼쪽 벽): 금속 선반(캔·우유) · 싱크대 2개(준비대) · 메뉴판 · 줄무늬 차양 · 간판.
	var shelf := PubParts.asset(_static, "metal_shelf", Vector3(f.lounge_x0 + 0.28, 0, 0.75), PI / 2, Vector3.ONE)
	if shelf != null:
		var shelf_top: float = shelf.mesh.get_aabb().size.y
		for k in range(4):
			PubParts.asset(_static, "soda_can_%d" % k, Vector3(f.lounge_x0 + 0.28, shelf_top, 0.42 + k * 0.2), k * 0.8, Vector3.ONE * 1.3)
		PubParts.asset(_static, "milk", Vector3(f.lounge_x0 + 0.3, shelf_top, 1.18), 0.3, Vector3.ONE)
	# 음료 진열대(2026-11-08): 왼쪽 벽에 RG Poly 진열대 큰 것·작은 것 + 선반마다 캔 음료(SodaCan 5종). 메뉴판(1.48m~) 아래에 들어간다.
	for spec: Array in [["drink_rack", RACK_Z, 6], ["drink_rack_small", SMALL_RACK_Z, 3]]:
		var rack_x: float = f.lounge_x0 + 0.28
		PubParts.asset(_static, str(spec[0]), Vector3(rack_x, 0, float(spec[1])), 0.0, Vector3.ONE, "DrinkRack")
		var count: int = int(spec[2])
		for level in range(RACK_SHELVES.size()):
			for k in range(count):
				var z: float = float(spec[1]) + (k - (count - 1) / 2.0) * 0.13
				PubParts.asset(_static, "soda_can_" + "abcde"[(k + level * 2) % 5], Vector3(rack_x + 0.05, RACK_SHELVES[level] + 0.005, z), k * 0.9, Vector3.ONE * 1.15)
	# 주방대(예전 준비 싱크대 자리): RG Poly 스테이션 테이블 위 네온 전자레인지(문 = 모델 -X → 반 바퀴 돌려 +X) · 토스터.
	# 직원이 뒤돌아 여기서 음식을 꺼낸다(_juice_service).
	var kitchen_x: float = f.lounge_x0 + 0.45
	PubParts.asset(_static, "kitchen_station", Vector3(kitchen_x, 0, KITCHEN_Z), PI / 2, Vector3.ONE, "KitchenStation")
	PubParts.asset(_static, "microwave_neon", Vector3(kitchen_x + 0.08, 1.0, SHOP_MICROWAVE_Z), PI, Vector3.ONE * 0.9, "Microwave")
	PubParts.asset(_static, "toaster", Vector3(kitchen_x + 0.12, 1.0, KITCHEN_Z - 0.38), 0.0, Vector3.ONE * 0.85, "Toaster")
	_menu_board(Vector3(f.lounge_x0 + SIGN_STANDOFF, 1.85, 1.9))
	# 차양: 벽에서 방 쪽으로 내려오는 줄무늬 지붕(2.25~3.1m). 노랑 둘 + 빨강 하나.
	for spec: Array in [["juice_awning", 1.6], ["juice_awning", 4.4], ["juice_awning_red", 7.1]]:
		PubParts.asset(_static, str(spec[0]), Vector3(f.lounge_x0 + 0.62, 2.25, float(spec[1])), 0.0, Vector3.ONE)
	# 2026-11-08: 벽 위에 코니스가 생겨 간판 위 끝이 천장 − 0.82m 로 내려왔다 → 두 줄이면 아래 줄이 차양(위 끝 3.1m)에 가려진다.
	# 한 줄로 줄여 차양과 코니스 사이(3.3~3.9m)에 들어가게 한다.
	_neon_sign("FRESH JUICE · 생과일 주스", Vector3(f.lounge_x0 + 0.02, 3.6, 3.7), PI / 2, 64, ORANGE, 0.005, 0.12)
	_cafe_sign(Vector3(front + 0.62, 0, 6.85))
	_juice_service()


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


## 카운터 끝 바닥 간판대(RG Poly CafeBoard — A자 판, 판 = 모델 ±X). 방 가운데 쪽으로 조금 돌려 세우고 앞면에 오늘의 메뉴 글자.
func _cafe_sign(at: Vector3) -> void:
	var board := PubParts.asset(_static, "cafe_board", at, 0.36, Vector3.ONE * 1.25, "CafeBoard")
	if board == null:
		return
	# 판이 위로 갈수록 뒤로 기운다(A자 반쪽 ≈ 12.5°) → 글자도 같이 눕힌다. Label3D 정면 = +Z → 반의 반 바퀴 돌려 +X.
	var menu := Kit.label(board, "CafeBoardText", "SNACK BAR\n핫도그 · 피자\n시원한 캔", Vector3(0.105, 0.43, 0.0), 30, Color("fff4d6"), 0.0021)
	menu.basis = Basis(Vector3.UP, PI / 2) * Basis(Vector3.RIGHT, -0.22)
	menu.shaded = false


## 주스 가게 직원 + 서빙 + 다이너 의자 손님 둘(2026-11-08 사용자 "오락실도 똑같이 음료나 음식을 서빙하는 식으로").
## 직원은 카운터 뒤 통로를 걸으며 디스펜서에서 주스를 · 음료 진열대에서 캔을 꺼내 손님 앞에 놓고,
## 뒤돌아 주방대 전자레인지에서 음식을 꺼낸다(art/pub/pub_service.gd — 펍 바텐더와 같은 코드).
func _juice_service() -> void:
	var box: AABB = TableView.BAR_BOX
	var front: float = box.end.x
	var top_y: float = TableView.BAR_TOP_Y
	var vendor := _juice_vendor(Vector3(SHOP_LANE_X, 0, 4.0))
	var customers: Array = []
	var looks: Array = [["ff5aa8", false, NpcOutfit.Outfit.GUEST_CAP], ["49d6e6", true, NpcOutfit.Outfit.GUEST_BEANIE]]
	for i: int in [1, 2]:
		var z: float = TableView.BAR_STOOLS_Z[i]
		var look: Array = looks[i - 1]
		NpcIdle.spawn(self, "ArcadeGuest_%d" % i, Vector3(front + 0.45, 0, z), Vector3(box.position.x, 0, z), Color(look[0]), true, 0, i * 2.1,
			0.8, look[1], look[2])
		customers.append([z, Vector3(front - 0.22, top_y, z - 0.17), Vector3(front - 0.22, top_y, z + 0.15)])
	var foods := PackedStringArray(["plate+hotdog@0.72", "plate+burger_ready@0.7", "pizza_plate@0.6", "plate+donut@0.95", "plate+cake_slice@0.55",
		"plate+pancakes@0.62", "dish_5@0.52"])
	var kitchen_x: float = _faces().lounge_x0 + 0.45
	PubService.make(self, vendor, SHOP_LANE_X, SHOP_SERVE_X, SHOP_LANE_Z, -PI / 2, [
		["drink", 1.15, -PI / 2, 2.4, PackedStringArray(["juice_cup"]), 1.0, Vector3.ZERO, SHOP_SERVE_X],
		["drink", RACK_Z, PI / 2, 1.6, PackedStringArray(["soda_can_a", "soda_can_b", "soda_can_c", "soda_can_d", "soda_can_e"]), 1.15, Vector3.ZERO, RACK_REACH_X],
		["food", SHOP_MICROWAVE_Z, PI / 2, 3.2, foods, 1.0, Vector3(kitchen_x + 0.35, 1.18, SHOP_MICROWAVE_Z), KITCHEN_REACH_X]],
		customers)


## 주스 가게 직원(2026-11-08): 펍 바텐더·손님과 같은 리깅 캐릭터(art/pub/npc_idle.gd)에 청록 셔츠만 입힌다.
## 예전에는 옛 상자 바텐더 모델(chr_bartender)의 옷을 갈아입혔다 — 선수와 생김새가 달라 보인다는 사용자 지적으로 바꿨다.
## 카운터 뒤에 서서 방 쪽(+X)을 보고, 가끔 손님 쪽을 가리킨다. 충돌 없음(지나갈 수 있다).
func _juice_vendor(at: Vector3) -> Node3D:
	# 2026-11-08: 가게 색 야구 모자 + 가슴 앞치마(art/pub/npc_outfit.gd) — 손님·선수와 구분된다. 몸짓 3 = 서빙(PubService 가 움직인다).
	return NpcIdle.spawn(self, "JuiceVendor", at, at + Vector3(3.0, 0, 0), Color("2fc6b6"), false, 3, 0.9, NpcIdle.SEAT_TOP, false, NpcOutfit.Outfit.JUICE_VENDOR)


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
		# 2026-11-08 Codex 묶음 2: 상자 몸 → 라운드하우스 오락기 A(아치형)/B(경사형) 번갈아. 화면·조이스틱·버튼 3개·동전 투입구가
		# 따로 된 부품 노드이고, 크림 에나멜·남색·얇은 네온 테두리가 모델에 들어 있다(예전 네온 모서리 띠·버튼을 덧붙이지 않는다).
		# B 조작판은 메시에 이미 X −34.7도 기울어 있다 — 여기서 또 돌리지 않는다.
		var cabinet := _model(CABINET_MODELS[index % CABINET_MODELS.size()], at, yaw, "Cabinet")
		# 화면: 모델의 빈 검은 유리(ScreenBlank)를 대마다 복제해 빛나게 덮는다 → show_state 의 색 순환이 대마다 따로 돈다.
		var screen := cabinet.find_child("Screen", true, false) as MeshInstance3D
		var lit := screen.get_active_material(0).duplicate() as StandardMaterial3D
		lit.emission_enabled = true
		lit.emission = color.darkened(0.2)
		lit.emission_energy_multiplier = 1.6
		screen.material_override = lit
		_screens.append(screen)
		# 간판: 빈 남색 판(MarqueeBlank) 앞면에 게임 이름 한 줄(판 크기에 맞춘 글자).
		var marquee := cabinet.find_child("MarqueeBlank", true, false) as MeshInstance3D
		_fit_sign(str(CABINETS[index][2]).replace("\n", " "), _box_in(cabinet, marquee), cabinet, color)
		var turned: bool = absf(sin(yaw)) > 0.5
		var footprint := Vector3(CABINET_SIZE.z, CABINET_SIZE.y, CABINET_SIZE.x) if turned else CABINET_SIZE
		_body(at + Vector3(0, CABINET_SIZE.y / 2.0, 0), footprint)


## 대기 벤치(라운드하우스 arcade_bench, 2026-11-08 Codex 묶음 2). 자리 근거는 BENCH_AT 주석.
## 앉는 기능은 없다(장식 + 이 테마에서만 충돌). 이름이 "Seat" 로 시작하지 않아 자리 숨기기(TableView.show_seats)와 섞이지 않는다.
func _bench() -> void:
	_model("arcade_bench", BENCH_AT, 0.0, "ArcadeBench")
	_body(BENCH_AT + Vector3(0, BENCH_SIZE.y / 2.0, 0), BENCH_SIZE)


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


## 장식 인형 하나(선반용): 라운드하우스 다트·주사위·카드 인형(묶음 2)을 pick 순서로 번갈아 앉힌다. at = 앉는 면, 정면 = yaw 방향의 -Z.
## 2026-11-08: 예전 곰(코드 도형)·오리(RG Poly) → 라운드하우스 인형. 몸통 M_Variant 는 색마다 복제 재질 하나를 같이 쓴다(_plush_body).
func _plush(at: Vector3, yaw: float, pick: int) -> void:
	var doll := _model(DECO_PLUSHES[pick % DECO_PLUSHES.size()], at, yaw, "DecoPlush")
	var color: Color = PLUSH_COLORS[pick % PLUSH_COLORS.size()]
	for found in doll.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := found as MeshInstance3D
		for surface in range(mesh_node.mesh.get_surface_count()):
			var material := mesh_node.mesh.surface_get_material(surface) as StandardMaterial3D
			if material != null and material.resource_name == "M_Variant":
				mesh_node.set_surface_override_material(surface, _plush_body(material, color))


## 인형 몸통 재질(원본 M_Variant + 색)의 복제본. 섬유 텍스처·노멀은 원본 그대로, 색(albedo_color)만 바꾼다.
func _plush_body(source: StandardMaterial3D, color: Color) -> StandardMaterial3D:
	var key := "plush_%d_%s" % [source.get_instance_id(), color.to_html(false)]
	if not _materials.has(key):
		var tinted := source.duplicate() as StandardMaterial3D
		tinted.albedo_color = Color(color, source.albedo_color.a)
		_materials[key] = tinted
	return _materials[key]


## 인형뽑기 코너: 닫힌 경품 진열장 2대 + 뒷벽 인형 진열 선반 2단. 진짜 기계(_claw_machine)는 그 앞 Rules.CLAW_AT.
func _claw_corner() -> void:
	var f := _faces()
	for index in range(CLAW_DECOS.size()):
		_prize_showcase(CLAW_DECOS[index][0], CLAW_DECOS[index][1], Color(str(CLAW_DECOS[index][2])))
	# 진열 선반: 장식 기계 위(2.75m · 3.3m), 뒷벽 x 9.45~12.95.
	var from: float = 9.45
	var to: float = 12.95
	for row in range(2):
		var y: float = 2.75 + row * 0.55
		Kit.box(_static, "PlushShelf", Vector3(to - from, 0.04, 0.28), Vector3((from + to) / 2.0, y, f.back_z - 0.14), _mat("plush_shelf", Color("2a2148")))
		Kit.box(_static, "PlushShelfLed", Vector3(to - from, 0.02, 0.02), Vector3((from + to) / 2.0, y - 0.03, f.back_z - 0.28), _neon_mat([CYAN, PINK][row], 2.0))
		# 인형은 선반 윗면(y + 0.02)에 바닥 원점으로 앉고 정면(-Z)이 방 안을 본다.
		for slot in range(8):
			_plush(Vector3(from + 0.22 + slot * 0.44, y + 0.02, f.back_z - 0.15), 0.0, slot + row * 3)


## 닫힌 경품 진열장 한 대(움직이지 않음, 이 테마에서만 충돌). 정면 = 로컬 -Z.
## 2026-11-07: 조작 인형뽑기와 헷갈리지 않게 집게·레일·조이스틱이 없다.
## 2026-11-08 Codex 묶음 2: 상자 진열장(계단 받침 + 곰·오리 9마리 + 투명 상자 유리) → 라운드하우스 진열장 GLB.
## 모델 안에 선반 3단·앞유리 한 장(Glass)·인형 3개(PrizeDisplayRoot — 다트·주사위·카드)가 이미 있어 그대로 쓴다
## (예전 투명 상자 유리·인형을 덧붙이지 않는다). 위 판 앞면에 "PRIZE" 글자만 더한다.
func _prize_showcase(at: Vector3, yaw: float, accent: Color) -> void:
	var showcase := _model("prize_showcase", at, yaw, "PrizeShowcase")
	_sign("PRIZE", Vector3(0, SHOWCASE_SIGN_Y, -SHOWCASE_SIZE.z / 2.0 - 0.004), PI, 40, accent, 0.0021, showcase)
	var turned: bool = absf(sin(yaw)) > 0.5
	var footprint := Vector3(SHOWCASE_SIZE.z, SHOWCASE_SIZE.y, SHOWCASE_SIZE.x) if turned else SHOWCASE_SIZE
	_body(at + Vector3(0, SHOWCASE_SIZE.y / 2.0, 0), footprint)


func _claw_machine() -> void:
	var at: Vector3 = Rules.CLAW_AT
	var size: Vector3 = Rules.CLAW_SIZE
	_claw_body = Node3D.new()
	_claw_body.name = "ClawMachine"
	add_child(_claw_body)
	_claw_body.position = at
	# 2026-11-07: 분홍 상자 → 크림 에나멜 둥근 몸통 + 남색 머리·기둥 + 얇은 마젠타/시안 줄(요청서 2장 오락실 스킨).
	var cream := _mat("arcade_cream", CREAM, 0.05, 0.38)
	var navy := _mat("arcade_navy", NAVY, 0.1, 0.42)
	var front: float = -size.z / 2.0
	Kit.rounded_box(_claw_body, "ClawKick", Vector3(size.x - 0.06, 0.1, size.z - 0.06), Vector3(0, 0.05, 0), navy, 0.03)
	Kit.rounded_box(_claw_body, "ClawBase", Vector3(size.x, 0.85, size.z), Vector3(0, 0.525, 0), cream, 0.07)
	Kit.box(_claw_body, "ClawEdge", Vector3(size.x - 0.12, 0.014, 0.014), Vector3(0, 0.91, front - 0.002), _neon_mat(MAGENTA, 2.0))
	Kit.box(_claw_body, "ClawFloor", Vector3(size.x - 0.08, 0.04, size.z - 0.08), Vector3(0, 0.98, 0), _mat("arcade_plum", PLUM, 0.0, 0.8))
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		Kit.rounded_box(_claw_body, "ClawPost", Vector3(0.05, 1.12, 0.05), Vector3(corner.x * (size.x / 2 - 0.025), 1.5, corner.y * (size.z / 2 - 0.025)), navy, 0.02)
	Kit.rounded_box(_claw_body, "ClawHeader", Vector3(size.x + 0.04, 0.36, size.z + 0.04), Vector3(0, 2.23, 0), navy, 0.08)
	Kit.rounded_box(_claw_body, "ClawMarqueePlate", Vector3(size.x - 0.16, 0.24, 0.03), Vector3(0, 2.24, front - 0.03), cream, 0.025)
	Kit.box(_claw_body, "ClawHeaderEdge", Vector3(size.x - 0.04, 0.014, 0.014), Vector3(0, 2.05, front - 0.03), _neon_mat(CYAN, 2.2))
	Kit.box(_claw_body, "ClawLamp", Vector3(size.x - 0.12, 0.02, size.z - 0.12), Vector3(0, 2.04, 0), _neon_mat(Color("fff3e0"), 1.2))
	Kit.box(_claw_body, "ClawGlass", Vector3(size.x - 0.04, 1.1, size.z - 0.04), Vector3(0, 1.5, 0), _glass(Color("d8f4ff"), 0.12))
	# 상품 구멍(앞 왼쪽 구석, 크림 테두리 투명 통) + 상품 문(남색).
	Kit.box(_claw_body, "ClawChute", Vector3(0.26, 0.16, 0.26), Vector3(Rules.CLAW_CHUTE.x, 1.06, Rules.CLAW_CHUTE.y), _glass_mat("claw_chute", CREAM, 0.3))
	Kit.box(_claw_body, "ClawChuteRim", Vector3(0.28, 0.02, 0.28), Vector3(Rules.CLAW_CHUTE.x, 1.15, Rules.CLAW_CHUTE.y), _neon_mat(MAGENTA, 1.4))
	Kit.rounded_box(_claw_body, "ClawDoor", Vector3(0.32, 0.26, 0.03), Rules.CLAW_DOOR - at + Vector3(0, 0.1, -0.03), navy, 0.02)
	Kit.box(_claw_body, "ClawDoorLed", Vector3(0.24, 0.012, 0.012), Rules.CLAW_DOOR - at + Vector3(0, 0.25, -0.05), _neon_mat(CYAN, 1.8))
	# 조작판: 크림 둥근 판(사람 쪽으로 살짝 기움) + 기울어지는 조이스틱 + 큰 버튼 + 작은 글자(키 이름은 설정마다 달라 적지 않는다).
	var panel := Kit.rounded_box(_claw_body, "ClawPanel", Vector3(size.x, 0.08, 0.26), Vector3(0, 0.98, front - 0.1), cream, 0.03)
	# 윗면이 사람 쪽(-Z)으로 기울게(rotation.x 가 음수면 위가 -Z 쪽으로 눕는다).
	panel.rotation.x = -0.12
	_claw_stick = Node3D.new()
	_claw_stick.name = "ClawStickPivot"
	_claw_body.add_child(_claw_stick)
	_claw_stick.position = Vector3(STICK_X, 1.02, front - 0.1)
	Kit.cylinder(_claw_stick, "ClawStick", 0.013, 0.13, Vector3(0, 0.065, 0), navy, 8)
	Kit.sphere(_claw_stick, "ClawKnob", 0.042, Vector3(0, 0.14, 0), _mat("claw_knob", MAGENTA, 0.1, 0.25))
	Kit.cylinder(_claw_body, "ClawStickBoot", 0.045, 0.02, Vector3(STICK_X, 1.025, front - 0.1), navy, 12)
	Kit.cylinder(_claw_body, "ClawButton", 0.06, 0.05, Vector3(-STICK_X, 1.04, front - 0.1), _neon_mat(MAGENTA, 1.8), 16)
	Kit.cylinder(_claw_body, "ClawButtonRing", 0.072, 0.02, Vector3(-STICK_X, 1.025, front - 0.1), navy, 16)
	for spec: Array in [["MOVE", STICK_X], ["DROP", -STICK_X]]:
		# 판 위에 눕힌 글자: X 로 눕히고(Y 로 반 바퀴) 앞에 선 사람이 바로 읽는다. 판과 같은 기울기(0.12).
		var tag := Kit.label(_claw_body, "ClawTag", str(spec[0]), Vector3(float(spec[1]), 1.012, front - 0.2), 22, NAVY, 0.0028)
		tag.rotation = Vector3(-PI / 2 + 0.12, PI, 0)
	# 레일과 집게 머리.
	for side in [-1.0, 1.0]:
		Kit.box(_claw_body, "ClawRail", Vector3(size.x - 0.08, 0.03, 0.03), Vector3(0, 2.03, side * (size.z / 2 - 0.06)), _gloss(Color("c9c9d6"), 0.8, 0.3))
	# 조준 고리(시안) + 가는 빛줄기: 조종 중에만 보인다(show_state). 집게가 어디로 떨어질지 유리 너머로도 읽히게.
	_claw_aim = Node3D.new()
	_claw_aim.name = "ClawAim"
	add_child(_claw_aim)
	_claw_aim.visible = false
	var ring := TorusMesh.new()
	ring.inner_radius = 0.05
	ring.outer_radius = 0.066
	ring.rings = 20
	Kit.mesh_node(_claw_aim, "AimRing", ring, Vector3.ZERO, _neon_mat(CYAN, 2.4))
	_claw_beam = Kit.cylinder(_claw_aim, "AimBeam", 0.0035, 1.0, Vector3(0, 0.5, 0), _neon_mat(CYAN, 1.2), 6)
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
	_claw_marquee = _sign("CLAW", Vector3(0, 2.24, -size.z / 2 - 0.05), PI, 72, MAGENTA, 0.005, _claw_body)
	_body(at + Vector3(0, size.y / 2.0, 0), size)
	# 기계 위 큰 오리 인형(가게 마스코트).
	PubParts.asset(_static, "plush_duck", at + Vector3(0.2, size.y + 0.02, 0.1), PI + 0.5, Vector3.ONE * 0.75)


# ─────────────────────────────── 가챠 ───────────────────────────────

## 가챠 2대 + 받침대. 2026-11-07 요청서 3.3 "가챠 2대 + 독립 받침대, 전면 -Z":
##   받침대 = 펍 NPC 식탁 충돌 상자(TableView.NPC_TABLE_BOX, 높이 0.85m) 그대로 — 크림 둥근 섬 + 남색 걸레받이 + 앞 모서리 시안 줄.
##   기계는 그 앞쪽 가장자리에 나란히 서서 통로(-Z)를 본다. 손잡이·배출구·받침 자리는 Rules.GACHA_CRANK/EXIT/TRAY(규칙과 같은 값).
func _gacha_machines() -> void:
	var box: AABB = TableView.NPC_TABLE_BOX
	var center: Vector3 = box.get_center()
	var cream := _mat("arcade_cream", CREAM, 0.05, 0.38)
	var navy := _mat("arcade_navy", NAVY, 0.1, 0.42)
	var metal := _mat("gacha_metal", Color("d8d8e4"), 0.8, 0.25)
	Kit.rounded_box(_static, "GachaStandKick", Vector3(box.size.x - 0.08, 0.09, box.size.z - 0.08), Vector3(center.x, 0.045, center.z), navy, 0.025)
	Kit.rounded_box(_static, "GachaStand", Vector3(box.size.x, box.size.y - 0.12, box.size.z), Vector3(center.x, 0.085 + (box.size.y - 0.12) / 2.0, center.z), cream, 0.06)
	Kit.rounded_box(_static, "GachaStandTop", Vector3(box.size.x + 0.04, 0.04, box.size.z + 0.04), Vector3(center.x, box.end.y - 0.02, center.z), navy, 0.015)
	Kit.box(_static, "GachaStandEdge", Vector3(box.size.x - 0.14, 0.012, 0.012), Vector3(center.x, box.end.y - 0.08, box.position.z - 0.002), _neon_mat(CYAN, 1.8))
	var accents: Array[Color] = [MAGENTA, CYAN]
	for machine in range(Rules.GACHA_AT.size()):
		var at: Vector3 = Rules.GACHA_AT[machine]
		var accent: Color = accents[machine % accents.size()]
		var body := Node3D.new()
		body.name = "Gacha%d" % machine
		add_child(body)
		body.position = at
		_gacha_bodies.append(body)
		# 몸통(크림 둥근 상자, 앞면 z = -0.26) · 앞 남색 판(손잡이·동전 자리) · 배출구(검은 구멍) · 받침(남색 낮은 접시).
		Kit.rounded_box(body, "GachaBody", Vector3(0.46, 0.5, 0.52), Vector3(0, 0.25, 0), cream, 0.06)
		Kit.rounded_box(body, "GachaFace", Vector3(0.24, 0.26, 0.02), Vector3(-0.08, 0.31, -0.262), navy, 0.02)
		Kit.box(body, "GachaCoin", Vector3(0.03, 0.06, 0.01), Vector3(0.12, 0.38, -0.266), _neon_mat(accent, 1.6))
		Kit.rounded_box(body, "GachaExit", Vector3(0.15, 0.12, 0.012), Vector3(Rules.GACHA_EXIT.x, 0.14, -0.264), _mat("ink", Color("120c12"), 0.0, 0.5), 0.02)
		Kit.rounded_box(body, "GachaTray", Vector3(0.2, 0.012, 0.17), Vector3(Rules.GACHA_TRAY.x, 0.006, Rules.GACHA_TRAY.z + 0.02), navy, 0.005)
		Kit.rounded_box(body, "GachaTrayLip", Vector3(0.2, 0.07, 0.02), Vector3(Rules.GACHA_TRAY.x, 0.035, Rules.GACHA_TRAY.z - 0.07), navy, 0.008)
		for side: float in [-1.0, 1.0]:
			Kit.rounded_box(body, "GachaTraySide", Vector3(0.02, 0.07, 0.17), Vector3(Rules.GACHA_TRAY.x + side * 0.1, 0.035, Rules.GACHA_TRAY.z + 0.02), navy, 0.008)
		# 목(남색) + 얇은 색 줄 · 유리구슬 · 뚜껑(남색) + 크림 꼭지.
		Kit.cylinder(body, "GachaNeck", 0.17, 0.06, Vector3(0, 0.53, 0), navy, 20)
		Kit.cylinder(body, "GachaNeckEdge", 0.172, 0.012, Vector3(0, 0.565, 0), _neon_mat(accent, 1.8), 20)
		Kit.sphere(body, "GachaGlobe", 0.27, Vector3(0, Rules.GACHA_GLOBE_Y, 0), _glass(Color("e6f7ff"), 0.14))
		Kit.cylinder(body, "GachaCap", 0.12, 0.07, Vector3(0, Rules.GACHA_GLOBE_Y + 0.27, 0), navy, 20)
		Kit.sphere(body, "GachaCapKnob", 0.04, Vector3(0, Rules.GACHA_GLOBE_Y + 0.32, 0), cream)
		# 손잡이: 앞면에서 바깥(-Z)으로 나온 축 둘레로 돈다(show_state 가 rotation.z). 막대 끝에 색 손잡이 공.
		var crank := Node3D.new()
		crank.name = "Crank"
		body.add_child(crank)
		crank.position = Rules.GACHA_CRANK
		var hub := Kit.cylinder(crank, "CrankHub", 0.065, 0.03, Vector3(0, 0, 0.01), metal, 16)
		hub.rotation.x = PI / 2
		Kit.box(crank, "CrankBar", Vector3(0.03, 0.15, 0.022), Vector3(0, 0.045, -0.015), metal)
		Kit.sphere(crank, "CrankKnob", 0.03, Vector3(0, 0.11, -0.04), _mat("gacha_knob_%d" % machine, accent, 0.1, 0.25))
		_gacha_cranks.append(crank)
		_sign("GACHA", Vector3(0, 0.465, -0.265), PI, 22, accent, 0.0032, body)
	# 받침대 뒤쪽: 작은 간판(남색 판 · 두 기둥 · 아래 얇은 마젠타 줄). 기계 머리 위로 보이는 높이.
	var sign_z: float = box.end.z - 0.18
	for x: float in [center.x - 0.6, center.x + 0.6]:
		Kit.cylinder(_static, "GachaSignPost", 0.018, 1.2, Vector3(x, box.end.y + 0.6, sign_z), navy, 8)
	Kit.rounded_box(_static, "GachaSignBoard", Vector3(1.4, 0.32, 0.04), Vector3(center.x, box.end.y + 1.32, sign_z), navy, 0.03)
	Kit.box(_static, "GachaSignEdge", Vector3(1.32, 0.012, 0.012), Vector3(center.x, box.end.y + 1.15, sign_z - 0.025), _neon_mat(MAGENTA, 1.8))
	_sign("GACHA · 캡슐뽑기", Vector3(center.x, box.end.y + 1.32, sign_z - 0.03), PI, 40, CREAM, 0.0042)


# ─────────────────────────────── 농구 오락기 ───────────────────────────────

func _hoop_machine() -> void:
	var box: AABB = TableView.POOL_TABLE_BOX
	var center: Vector3 = box.get_center()
	# 2026-11-07: 남색 둥근 몸통 + 크림 앞판 + 얇은 마젠타 윗줄(예전 굵은 주황 띠 대신). 경사판은 공 색과 겹치지 않게 크림.
	var shell := _mat("arcade_navy", NAVY, 0.1, 0.42)
	var cream := _mat("arcade_cream", CREAM, 0.05, 0.38)
	Kit.rounded_box(self, "HoopBase", box.size, center, shell, 0.07)
	Kit.rounded_box(self, "HoopFront", Vector3(box.size.x - 0.16, box.size.y - 0.24, 0.03), Vector3(center.x, box.size.y / 2.0 + 0.02, box.position.z - 0.005), cream, 0.03)
	Kit.box(self, "HoopEdge", Vector3(box.size.x - 0.12, 0.014, 0.014), Vector3(center.x, box.end.y - 0.06, box.position.z - 0.004), _neon_mat(MAGENTA, 2.0))
	var ramp := Kit.box(self, "HoopRamp", Vector3(box.size.x - 0.1, 0.03, box.size.z - 0.1), Vector3(center.x, box.end.y + 0.06, center.z), _mat("hoop_ramp", CREAM.darkened(0.12), 0.0, 0.6))
	ramp.rotation.x = -0.08
	Kit.rounded_box(self, "HoopLip", Vector3(box.size.x - 0.1, 0.08, 0.04), Vector3(center.x, box.end.y + 0.04, box.position.z + 0.06), shell, 0.015)
	# 그물(양옆) · 뒤판 · 백보드. 공이 튕기도록 이 테마에서만 충돌을 더한다.
	var net := _glass(Color("bfe9ff"), 0.13)
	var net_from: float = box.position.z + 0.8
	var net_depth: float = box.end.z - net_from
	for x in [box.position.x + 0.02, box.end.x - 0.02]:
		Kit.box(self, "HoopNet", Vector3(0.02, 1.9, net_depth), Vector3(x, box.end.y + 0.95, net_from + net_depth / 2.0), net)
		Kit.rounded_box(self, "HoopNetFrame", Vector3(0.035, 0.035, net_depth), Vector3(x, box.end.y + 1.9, net_from + net_depth / 2.0), shell, 0.012)
		Kit.box(self, "HoopNetEdge", Vector3(0.014, 0.014, net_depth), Vector3(x, box.end.y + 1.875, net_from + net_depth / 2.0), _neon_mat(CYAN, 1.6))
		_body(Vector3(x, box.end.y + 0.95, net_from + net_depth / 2.0), Vector3(0.04, 1.9, net_depth))
	Kit.rounded_box(self, "HoopBack", Vector3(box.size.x, 2.5, 0.06), Vector3(center.x, box.end.y + 1.25, box.end.z - 0.03), shell, 0.025)
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
	# 그물은 골이 들어가면 출렁인다(show_state 가 scale 을 바꾼다 — 원점이 그물 가운데라 위아래로 부푼다).
	_hoop_net = Kit.mesh_node(_hoop_ring, "Net", hoop_net, Vector3(0, -0.15, 0), _glass(Color("ffffff"), 0.45))
	Kit.box(_hoop_ring, "RingArm", Vector3(0.06, 0.03, 0.26), Vector3(0, 0, 0.24), _gloss(Color("ff5a1f"), 0.6, 0.3))
	# 점수 전광판(백보드 위, 남색 둥근 틀 + 크림 테두리). 정면 = -Z(사람 쪽).
	Kit.rounded_box(self, "HoopLedFrame", Vector3(1.36, 0.56, 0.08), Vector3(center.x, Rules.HOOP_RING.y + 1.0, box.end.z - 0.08), cream, 0.04)
	Kit.rounded_box(self, "HoopLedBox", Vector3(1.26, 0.46, 0.1), Vector3(center.x, Rules.HOOP_RING.y + 1.0, box.end.z - 0.1), _mat("hoop_led_box", Color("0b0816"), 0.0, 0.6), 0.03)
	_hoop_led = _sign("HOOP\nFEVER", Vector3(center.x, Rules.HOOP_RING.y + 1.02, box.end.z - 0.16), PI, 54, ORANGE, 0.0045, self)
	_hoop_score = _sign("", Vector3(center.x, Rules.HOOP_RING.y + 0.7, box.end.z - 0.17), PI, 26, YELLOW, 0.0035, self)
	Kit.cylinder(self, "HoopButtonRing", 0.085, 0.03, Rules.HOOP_BUTTON + Vector3(0, -0.06, 0), shell, 16)
	Kit.cylinder(self, "HoopButton", 0.07, 0.05, Rules.HOOP_BUTTON + Vector3(0, -0.04, 0), _neon_mat(Color("49ff7a"), 2.0), 16)
	_three_point_line()


## 바닥 3점 선: 링 가운데(움직이지 않을 때)에서 Rules.THREE_POINT(3m) 반지름 호. 이 선 밖에서 던져 넣으면 3점.
## 2026-11-07: 규칙엔 3점이 있었지만 바닥에 표시가 없어 아무도 몰랐다. 기계 앞(-Z) 쪽 반원만 그린다(벽 안으로 들어가는 끝은 잘린다).
func _three_point_line() -> void:
	var ring: Vector3 = Rules.HOOP_RING
	var arc := Kit.mesh_node(_static, "ThreePointLine", Kit.arc_tube_mesh(Rules.THREE_POINT, 0.012, -PI + 0.35, -0.62, 40, 6), Vector3(ring.x, 0.022, ring.z), _neon_mat(CYAN, 1.4))
	# 원호는 XY 평면에 만들어진다 → X 축으로 90° 눕히면 (cos a, sin a, 0) 이 (cos a, 0, sin a) 바닥 위로 간다.
	arc.rotation.x = PI / 2
	var tag := Kit.label(_static, "ThreePointTag", "3PT", Vector3(ring.x, 0.024, ring.z - Rules.THREE_POINT - 0.18), 64, CYAN.lightened(0.3), 0.004)
	tag.rotation = Vector3(-PI / 2, PI, 0)
	tag.shaded = false


## 작은 소품(충돌 없음 — 사람이 다니지 않는 가장자리에만): 가챠 뒤 사탕 병 · 냉장고 위 화분 · 다트 홀 오락기 옆 휴지통.
func _small_props() -> void:
	var gacha: AABB = TableView.NPC_TABLE_BOX
	# 2026-11-07: 가챠가 앞(-Z)을 보게 돌아서 사탕 병은 받침대 뒤쪽 두 구석으로 옮겼다(기계 뒤, 간판 기둥 옆).
	for x: float in [gacha.position.x + 0.2, gacha.end.x - 0.2]:
		PubParts.asset(_static, "candy_jar", Vector3(x, gacha.end.y, gacha.end.z - 0.42), x, Vector3.ONE * 1.2)
	var fridge: Vector3 = TableView.BAR_FRIDGE_AT
	for dz: float in [-0.4, 0.4]:
		PubParts.asset(_static, "plant_pot", fridge + Vector3(-0.1, TableView.BAR_FRIDGE_SIZE.y, dz), dz, Vector3.ONE * 1.2)
	PubParts.asset(_static, "trash_bin", Vector3(6.15, 0, 0.45), 0.3, Vector3.ONE)
	PubParts.asset(_static, "trash_bin", Vector3(-6.15, 0, 0.45), 1.2, Vector3.ONE)


## 색 조명(그림자 없음). 오락실 분위기는 대부분 빛나는 재질이 내고, 여기 빛은 바닥·사람에 색을 묻히는 정도.
## 2026-11-08 사용자 "펍과 오락실 전부 전등이 안 어울리거나 너무 무규칙적" → 빛 자리 규칙:
##   ① 천장 네온 관 줄(RoomBuilder.ceiling_beams — _ceiling_neon 과 같은 차례·같은 색) 바로 아래, 칸 너비를 똑같이 나눈 간격.
##      다트 홀(폭 13m)은 가운데 하나, 라운지(폭 22m)는 셋.
##   ② 조작하는 기계(인형뽑기·가챠·농구)는 기계 앞에 기계 색 하나씩. ③ 주스 가게 주방대 위 따뜻한 빛 하나.
##   펍 놋쇠 펜던트는 카드 테이블 것만 남긴다(LoungeWorld._trim_arcade).
func _lights() -> void:
	var specs: Array = []
	var ceiling: float = TableView.CEILING_HEIGHT
	var index := 0
	for entry: Array in RoomBuilder.ceiling_beams():
		var room: Rect2 = entry[0]
		var columns: int = 1 if room.size.x < 14.0 else 3
		for z: float in entry[1]:
			for c in range(columns):
				specs.append([Vector3(room.position.x + room.size.x * (c + 0.5) / columns, ceiling - 0.6, z), CYAN if index % 2 == 0 else PINK, 1.2, 6.5])
			index += 1
	specs.append([Rules.CLAW_AT + Vector3(0, 2.0, -0.2), MAGENTA, 2.6, 3.2])
	specs.append([(Rules.GACHA_AT[0] + Rules.GACHA_AT[1]) / 2.0 + Vector3(0, 1.3, -0.7), Color("ffe7c2"), 1.6, 3.0])
	specs.append([Rules.HOOP_RING + Vector3(0, 0.4, -0.8), ORANGE, 2.2, 3.5])
	specs.append([Vector3(_faces().lounge_x0 + 1.2, 2.6, KITCHEN_Z - 1.2), Color("ffb347"), 1.4, 5.0])
	for spec: Array in specs:
		var light := OmniLight3D.new()
		light.name = "ArcadeLight"
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
	# 2026-11-07: 간판은 조종 중 남은 초를 센다(예전 "GO!" 는 옛 타이밍 단계 x/z 에 맞춘 글자라 새 단계 move 에선 안 떴다).
	var moving: bool = phase == "move"
	if phase == "idle": _claw_marquee.text = "CLAW"
	# 숫자만(별을 붙이면 간판 판 폭 0.94m 를 넘는다 — 렌더 확인).
	elif moving: _claw_marquee.text = "%d" % ceili(maxf(0.0, float(claw.until) - now))
	else: _claw_marquee.text = "· · ·"
	# 조이스틱: 규칙의 stick_x/z(세상 방향 -1~1)대로 기운다. rotation.x 양수 = 위가 +Z 로, rotation.z 음수 = 위가 +X 로.
	var tilt := Vector2(float(claw.get("stick_x", 0.0)), float(claw.get("stick_z", 0.0))) if moving else Vector2.ZERO
	_claw_stick.rotation.x = lerpf(_claw_stick.rotation.x, tilt.y * 0.35, minf(1.0, delta * 14.0))
	_claw_stick.rotation.z = lerpf(_claw_stick.rotation.z, -tilt.x * 0.35, minf(1.0, delta * 14.0))
	# 조준 고리: 집게 바로 아래 유리 안 바닥(1.0m) + 집게 손에서 고리까지 가는 빛줄기. 조종할 때만.
	_claw_aim.visible = moving
	if moving:
		var floor_y: float = 1.005
		_claw_aim.position = Vector3(_claw_head.position.x, floor_y, _claw_head.position.z)
		var reach: float = maxf(0.05, _claw_head.position.y + hub.position.y - 0.12 - floor_y)
		_claw_beam.scale = Vector3(1, reach, 1)
		_claw_beam.position.y = reach / 2.0
	# 가챠 손잡이: 돌린 직후 한 바퀴(앞에서 보면 시계 방향 — 앞면이 -Z 라 Z 축 양수 회전이 시계 방향으로 보인다).
	for machine in range(mini(_gacha_cranks.size(), rules.gacha.size())):
		var age: float = now - float(rules.gacha[machine].crank)
		_gacha_cranks[machine].rotation.z = TAU * clampf(age / 0.8, 0.0, 1.0)
		_gacha_bodies[machine].scale = Vector3.ONE * (1.0 + sin(clampf(age / 0.5, 0.0, 1.0) * PI) * 0.04)
	# 농구: 링 좌우 이동 + 림에 맞으면 링이 위아래로 떨림, 골이면 그물이 출렁. 전광판 시간·순위(골 직후 GOAL!).
	var hoop: Dictionary = rules.hoop
	var rim_age: float = now - float(hoop.get("rim", -10.0))
	var goal_age: float = now - float(hoop.get("goal", -10.0))
	var wobble: float = sin(rim_age * 55.0) * 0.018 * (1.0 - rim_age / 0.45) if rim_age < 0.45 else 0.0
	_hoop_ring.position = Rules.HOOP_RING + Vector3(float(hoop.offset), wobble, 0)
	_hoop_ring.rotation.x = wobble * 2.0
	var swell: float = sin(clampf(goal_age / 0.55, 0.0, 1.0) * PI) if goal_age < 0.55 else 0.0
	_hoop_net.scale = Vector3(1.0 + swell * 0.18, 1.0 + swell * 0.45, 1.0 + swell * 0.18)
	if goal_age < 0.9:
		_hoop_led.text = "GOAL!"
		_hoop_score.text = ""
	elif bool(hoop.running):
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
