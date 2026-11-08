extends RefCounted
## F5 실제 경기 방(art/pub/pub_game.tscn)의 "보이는 것"을 만든다. pub_builder.gd 가 부른다(게임 실행 중에는 안 쓰인다).
##
## [방 모양 — 2026-10-28 도면]
## 위쪽 좁은 "다트 홀"(과녁·투척선·럼주통)과 아래쪽 넓은 "라운지"(바·플레이어 테이블·NPC 자리·당구대)가
## 이어진 ㄱ자 한 방이다. 두 칸은 TableView.DART_HALL / LOUNGE 이고 z=0 에서 만난다.
##
## [2026-11-08 "라운드하우스" 다시 짓기 — 사용자 지적 "맵의 지형지물과 벽·창문·테이블 다리 등 전부 이상하다"]
## 기준 = 바탕화면 DARTY_프로젝트/2026-11-07_DARTY_디자인요청_프롬프트.md 2장 + 디자인_2026-11-07/01_pub_concept.png.
##   - 바닥: 판자 상자 수백 개 → 이음매 없는 판 한 장 + 헤링본 오크 셰이더(art/pub/roundhouse_floor.gdshader).
##   - 벽: 크림 회벽 + 아래 청록 누빔 가죽 징두리 + 월넛 걸레받이·허리 난간 + 기둥 사이 "아치 틀" 칸 나누기
##         + 위쪽 코니스(숨은 빛 띠) + 벽과 천장을 곡면으로 잇는 코브. 천장 보는 없앴다(요청서 "갑작스러운 두꺼운 보 금지").
##   - 창: 둥근 머리 아치 창 + 커튼. 문: 둥근 머리 문틀 + 작은 아치 유리.
##   - 가구: 상자 다리 4개 테이블 → 물레로 깎은 받침 하나(트럼펫 모양) + 둥근 난간 테두리 + 원형 러그.
##           의자·바 스툴·NPC 테이블·당구대·전등도 모두 물레 깎기/단면 밀기(art/pub/round_kit.gd)로 둥글게.
##   - 사람: 바텐더·손님은 선수와 같은 리깅 캐릭터(art/pub/npc_idle.gd) — 의자에 실제로 앉는다.
##
## [왜 쇼케이스 펍과 따로 만드나]
## 실제 경기는 프로그래머가 정한 규칙 좌표가 있다: 과녁 중심 높이·크기, 투척선, 테이블·자리 4개 위치.
## 그래서 펍 디자인(벽·바닥·조명·소품 모양)은 그대로 쓰고, 배치만 그 좌표에 맞춘 방을 따로 만든다.
##
## [규칙 좌표는 어디서 오나]
## 전부 game/table/table.gd(TableView) 상수를 읽는다. 여기에 숫자를 따로 적지 않는다.
## 프로그래머가 그 상수를 바꾸면 이 생성기를 다시 돌려야 한다. 안 돌리면 게임 시작 때 경고가 뜨고
## tests/test_game_look.gd 가 실패한다(방에 저장된 layout_signature 와 비교).
##
## [충돌은 여기서 안 만든다]
## 벽·테이블·바·럼주통·NPC 테이블·당구대의 충돌은 TableView 가 만든다. 여기 있는 건 모두 "보이기만" 하는 물체다.
## 그래서 사람이 부딪히는 소품을 옮길 때는 TableView 의 충돌 상수도 같이 옮겨야 한다.
##
## [이름 약속 — 바꾸면 다른 곳도 고쳐야 한다]
## 묶음 이름(Shell·Bar·Guests…)은 오락실 테마가 빼는 목록(lounge_world.ARCADE_SKIP)과 시험이 본다.
## SeatMat_N·SeatRug_N·SeatStool_N·SeatLabel_N = 방 인원수에 따라 TableView.show_seats 가 숨긴다.
## Bell·Keg·PracticeTarget·Gramophone = "건드리기"(LoungeWorld.touch_spots)가 이름으로 찾아 흔든다.
## Pendant* = 오락실이 x 4m 밖 펜던트를 이름으로 뺀다(lounge_world._trim_arcade).

const MeshKit = preload("res://art/mesh_kit.gd")
const PubParts = preload("res://art/pub/pub_parts.gd")
const RoundKit = preload("res://art/pub/round_kit.gd")
const NpcIdle = preload("res://art/pub/npc_idle.gd")
## NPC 옷(바텐더·손님 모자/안경) — Outfit 번호표만 쓴다(2026-11-08).
const NpcOutfit = preload("res://art/pub/npc_outfit.gd")
const FLOOR_SHADER := "res://art/pub/roundhouse_floor.gdshader"
## 과녁 뒤 청록 특징 판넬의 절반 폭(m).
const FEATURE_HALF := 2.7
## 주크박스 자리 x — game/lounge/lounge_world.gd 의 JUKEBOX 와 같아야 한다(그 벽 칸을 주크박스 몫으로 비운다).
const JUKEBOX_X := 8.6
## 입구 문(뒷벽) x · 하우스 룰 간판(오른쪽 벽) z.
const DOOR_X := 8.4
const SIGN_Z := 1.4
## 벽 칸 나누기: 창 반폭 · 고정물 둘레 여유 · 빈 벽 칸의 목표 폭 · 이보다 좁은 틈은 옆 칸에 붙인다.
const WINDOW_HALF := 0.95
const BAY_PAD := 0.35
const BAY_WIDTH := 2.4
const MIN_BAY := 0.7
## 벽 높이 기준(m): 걸레받이 윗면 · 누빔 징두리 윗면 · 허리 난간 아래·윗면 · 코브(벽↔천장 곡면) 반지름.
const BASE_TOP := 0.15
const WAINSCOT_TOP := 1.15
const RAIL_TOP := 1.23
const COVE_R := 0.6
## 바 스툴 방석 윗면(바 윗면 1.1m 에 맞는 높이). 바에 앉은 손님은 이 높이에 앉힌다.
const BAR_STOOL_TOP := 0.8
## 앉는 면에서 앉은 발바닥까지 내려간 높이(m). 앉은 다리 자세(CharacterPoseLayer.SEAT_THIGH·SEAT_SHIN)로 잰 값
## (앉는 면 0.6m 의자 → 발바닥 0.222m). 의자·바 스툴 발 고리 윗면을 여기에 맞춘다(2026-11-08).
const SEATED_SOLE_DROP := 0.378
## 창(아치) 아래 끝·위 끝 높이.
const WINDOW_BOTTOM := 1.45
const WINDOW_TOP := 3.55

static var _floor_shader_material: ShaderMaterial
## 창 밖 풍경 그림 셰이더(2026-11-08) — _window_view_material.
const WINDOW_VIEW_SHADER := "res://art/pub/window_view.gdshader"
static var _window_view_shader_material: ShaderMaterial


## 방 전체를 만든다. 반환한 노드를 pub_builder.gd 가 pub_game.tscn 으로 저장한다.
static func build() -> Node3D:
	var room := Node3D.new()
	room.name = "PubGame"
	room.set_meta("layout_signature", TableView.layout_signature())
	_shell(_group(room, "Shell"))
	_board_wall(_group(room, "BoardWall"))
	_lane(_group(room, "Lane"))
	_barrels(_group(room, "Barrels"))
	_table_and_seats(_group(room, "TableAndSeats"))
	_bar(_group(room, "Bar"))
	_npc_corner(_group(room, "NpcCorner"))
	_guests(_group(room, "Guests"))
	_pool_table(_group(room, "PoolTable"))
	var pub_only := _group(room, "PubOnly")
	_decor(_group(room, "Decor"), _group(room, "Windows"), pub_only)
	_furnish(_group(room, "Furnishings"), pub_only)
	_lighting(_group(room, "Lights"))
	return room


## 에디터 장면 목록에서 찾기 쉽도록 부위별 묶음 노드를 만든다.
static func _group(parent: Node3D, group_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = group_name
	parent.add_child(node)
	return node


# ─────────────────────────────── 재질(요청서 2장 재질표) ───────────────────────────────
# 이름이 예전과 같은 재질(PlasterCream·ForestPanel·WoodWalnut·WoodDark·TableFelt)은 오락실 테마가 이름으로 색을 바꾼다
# (game/lounge/lounge_world.gd _recolor). 새 이름(LeatherTeal·CovePlaster·CoveGlow…)도 그 표에 더했다.

static func _plaster() -> StandardMaterial3D:
	return RoundKit.clay("PlasterCream", "e6d8bf", 0.93)

static func _ceiling_mat() -> StandardMaterial3D:
	return RoundKit.clay("CeilingPlaster", "eadbc2", 0.95)

## 코브(벽 위 곡면): 숨은 빛 띠가 비추는 것처럼 아주 약하게 스스로 빛난다(요청서 "조명은 측벽/코브 중심").
static func _cove_mat() -> StandardMaterial3D:
	var material := RoundKit.clay("CovePlaster", "efdcc0", 0.95)
	material.emission_enabled = true
	material.emission = Color("ffcf96")
	material.emission_energy_multiplier = 0.22
	return material

static func _walnut() -> StandardMaterial3D:
	return RoundKit.clay("WoodWalnut", "5b3d2b", 0.55)

static func _walnut_dark() -> StandardMaterial3D:
	return RoundKit.clay("WoodDark", "3b281d", 0.6)

static func _panel_wood() -> StandardMaterial3D:
	return RoundKit.clay("WoodPanel", "6e4a33", 0.55)

static func _leather() -> StandardMaterial3D:
	return RoundKit.clay("LeatherTeal", "28584f", 0.58)

static func _teal() -> StandardMaterial3D:
	return RoundKit.clay("ForestPanel", "24483f", 0.85)

static func _brass() -> StandardMaterial3D:
	return RoundKit.clay("AgedBrass", "b58a4a", 0.4, 0.75)

static func _felt() -> StandardMaterial3D:
	return RoundKit.clay("TableFelt", "2f5f50", 0.97)

static func _marble() -> StandardMaterial3D:
	return RoundKit.clay("BarMarble", "ddd1bc", 0.32)

## 코니스 위 숨은 빛 띠(밝게 빛나서 빛 번짐이 코브를 물들인다).
static func _glow() -> StandardMaterial3D:
	return MeshKit.material("CoveGlow", "ffc98a", 0.0, 2.4)

static func _warm_glow() -> StandardMaterial3D:
	return MeshKit.material("WarmLight", "ffd9a0", 0.0, 1.6)

static func _floor_material() -> ShaderMaterial:
	if _floor_shader_material == null:
		_floor_shader_material = ShaderMaterial.new()
		_floor_shader_material.resource_name = "RoundhouseFloor"
		_floor_shader_material.shader = load(FLOOR_SHADER)
	return _floor_shader_material


## 창 밖 밤거리 그림 재질(창 7개가 같이 쓴다 — 창마다 다른 배치는 셰이더가 창 위치로 정한다).
static func _window_view_material() -> ShaderMaterial:
	if _window_view_shader_material == null:
		_window_view_shader_material = ShaderMaterial.new()
		_window_view_shader_material.resource_name = "WindowView"
		_window_view_shader_material.shader = load(WINDOW_VIEW_SHADER)
	return _window_view_shader_material


# ─────────────────────────────── 공용 계산 ───────────────────────────────

## 벽 안쪽 면 좌표(벽 상자 두께의 절반만큼 안쪽). 바닥 평면 x·z 다.
static func _faces() -> Dictionary:
	var half: float = TableView.WALL_THICKNESS / 2.0
	return {
		"hall_x0": TableView.DART_HALL.position.x + half,
		"hall_x1": TableView.DART_HALL.end.x - half,
		"board_z": TableView.DART_HALL.position.y + half,
		"step_z": TableView.LOUNGE.position.y + half,
		"lounge_x0": TableView.LOUNGE.position.x + half,
		"lounge_x1": TableView.LOUNGE.end.x - half,
		"back_z": TableView.LOUNGE.end.y - half,
	}


## 2D 방향(x, z) → 노드 Y 회전(로컬 +Z 가 그쪽을 보게).
static func _yaw(direction: Vector2) -> float:
	return atan2(direction.x, direction.y)


## 축에 나란한 널빤지 하나. along 은 (1,0) 또는 (0,1), thickness 는 그 반대 축 두께다.
static func _plank(p: Node3D, node_name: String, mid: Vector2, along: Vector2, length: float,
		thickness: float, y: float, height: float, mat: Material) -> void:
	var size := Vector3(absf(along.x) * length + absf(along.y) * thickness, height,
		absf(along.y) * length + absf(along.x) * thickness)
	MeshKit.box(p, node_name, size, Vector3(mid.x, y, mid.y), mat)


## 바 스툴 i 번 자리 z(바 길이를 셋으로 나눈 가운데).
static func _bar_stool_z(i: int) -> float:
	var box: AABB = TableView.BAR_BOX
	var z0: float = box.position.z + 0.1
	var length: float = box.size.z - 0.2
	return z0 + length * (i + 0.5) / 3.0


# ─────────────────────────────── 벽 단면 모양 ───────────────────────────────
# 점은 (방 쪽으로 나온 깊이, 높이). "벽 쪽 아래 → 방 쪽 → 위 → 벽 쪽" 순서(round_kit.gd 점 적는 규칙).

static func _base_profile() -> PackedVector2Array:
	return RoundKit.rounded_profile(PackedVector2Array([Vector2(0, 0), Vector2(0.03, 0), Vector2(0.03, 0.11), Vector2(0.014, BASE_TOP), Vector2(0, BASE_TOP)]), 0.01, 3)

## 허리 난간: 누빔 징두리 윗면을 덮는 둥근 월넛 손잡이 띠.
static func _rail_profile() -> PackedVector2Array:
	var h := RAIL_TOP - WAINSCOT_TOP
	return RoundKit.rounded_profile(PackedVector2Array([Vector2(0, 0), Vector2(0.055, 0), Vector2(0.078, h * 0.4), Vector2(0.07, h * 0.85), Vector2(0.04, h), Vector2(0, h)]), 0.016, 3)

## 코니스: 아래가 비스듬한 선반 띠. 윗면 뒤쪽에 숨은 빛 띠가 놓인다.
static func _cornice_profile() -> PackedVector2Array:
	return RoundKit.rounded_profile(PackedVector2Array([Vector2(0, 0), Vector2(0.03, 0), Vector2(0.13, 0.07), Vector2(0.135, 0.1), Vector2(0, 0.1)]), 0.02, 3)

## 코브: 벽(아래)에서 천장(위)으로 휘어 드는 오목한 1/4 원. 원점 = 벽과 천장이 만나는 모서리.
static func _cove_profile() -> PackedVector2Array:
	var points := PackedVector2Array()
	for s in range(11):
		var angle := PI - (PI / 2.0) * s / 10.0
		points.append(Vector2(COVE_R, -COVE_R) + Vector2(cos(angle), sin(angle)) * COVE_R)
	return points


## 벽을 따라 미는 띠(로컬 X 로 −길이/2 ~ +길이/2, 단면 x = 로컬 +Z). 같은 길이·모양은 한 번만 만든다.
static func _band_mesh(kind: String, profile: PackedVector2Array, length: float) -> ArrayMesh:
	var half := length / 2.0
	return RoundKit.sweep_mesh("band|%s|%.3f" % [kind, length], profile,
		RoundKit.line_rails(Vector3(-half, 0, 0), Vector3(half, 0, 0), Vector3.BACK, Vector3.UP), false, false)


## 벽 위 u(벽 시작점에서 잰 거리)·높이 y 에 로컬 메시를 붙인다(로컬 +Z = 방 안쪽, 로컬 X = 벽을 따라).
static func _on_wall(p: Node3D, node_name: String, mesh: Mesh, wall: Dictionary, u: float, y: float, mat: Material, depth := 0.0) -> MeshInstance3D:
	var at: Vector2 = wall.from + wall.along * u + wall.inward * depth
	var node := MeshKit.mesh_node(p, node_name, mesh, Vector3(at.x, y, at.y), mat)
	node.rotation.y = _yaw(wall.inward)
	return node


# ─────────────────────────────── 벽 계획(칸 나누기) ───────────────────────────────

## 창 자리: [바닥 위 점(x, z), 방 안쪽 방향]. _decor 가 창을 걸고, 벽 칸 나누기가 창 둘레에 칸을 맞춘다.
static func _window_spots() -> Array:
	var f := _faces()
	var spots: Array = []
	for side: float in [-1.0, 1.0]:
		var x: float = f.hall_x1 if side > 0 else f.hall_x0
		for z: float in [-5.1, -8.7]:
			spots.append([Vector2(x, z), Vector2(-side, 0)])
	for x: float in [-2.4, 1.8, 11.2]:
		spots.append([Vector2(x, f.back_z), Vector2(0, -1)])
	spots.append([Vector2(f.lounge_x1, 4.6), Vector2(-1, 0)])
	return spots


## 벽 그림 액자 자리: [바닥 위 점, 방 안쪽, 그림 번호, 가운데 높이]. 펍 전용(오락실은 그 벽에 간판·기계).
static func _art_spots() -> Array:
	var f := _faces()
	return [[Vector2(-7.35, f.step_z), Vector2(0, 1), 0, 2.45],
		[Vector2(5.0, f.back_z), Vector2(0, -1), 1, 2.35],
		[Vector2(11.4, f.step_z), Vector2(0, 1), 2, 2.35]]


## 벽 고정물 하나. at = 바닥 위 자리(x, z), half = 반폭, frame = 그 칸에 아치 틀을 두는가,
## cut = 그 자리에서 징두리·걸레받이를 끊는가(문·과녁 판넬), pad = 칸 여유.
static func _fixture(at: Vector2, half: float, frame := true, cut := false, pad := BAY_PAD) -> Dictionary:
	return {"at": at, "half": half, "frame": frame, "cut": cut, "pad": pad}


static func _all_fixtures() -> Array:
	var f := _faces()
	var box: AABB = TableView.BAR_BOX
	var list: Array = []
	for spot: Array in _window_spots():
		list.append(_fixture(spot[0], WINDOW_HALF))
	for art: Array in _art_spots():
		list.append(_fixture(art[0], 0.42))
	list.append(_fixture(Vector2(0, f.board_z), FEATURE_HALF, false, true, 0.0))
	# 다트 홀 입구 쪽 벽 선반(펍)·오락기 위 자리: 기둥이 선반을 뚫지 않게 칸을 비운다.
	for x: float in [f.hall_x0, f.hall_x1]:
		list.append(_fixture(Vector2(x, -1.5), 0.45, false))
	list.append(_fixture(Vector2(JUKEBOX_X, f.step_z), 0.75))
	list.append(_fixture(Vector2(DOOR_X, f.back_z), 0.75, false, true, 0.25))
	list.append(_fixture(Vector2(f.lounge_x1, SIGN_Z), 0.9))
	# 바 뒤 병 선반(제 아치 틀이 있다).
	list.append(_fixture(Vector2(f.lounge_x0, box.get_center().z), (box.size.z - 0.6) / 2.0, false))
	return list


## 벽 8면(ㄱ자 둘레). 튀어나온 모서리 = (hall_x0, step_z) · (hall_x1, step_z). sconces = 빈 칸 가운데에 벽등을 다는가.
static func _walls() -> Array:
	var f := _faces()
	var specs: Array = [
		[Vector2(f.hall_x0, f.board_z), Vector2(f.hall_x1, f.board_z), Vector2(0, 1), false, false, false],
		[Vector2(f.hall_x0, f.board_z), Vector2(f.hall_x0, f.step_z), Vector2(1, 0), false, true, true],
		[Vector2(f.hall_x1, f.board_z), Vector2(f.hall_x1, f.step_z), Vector2(-1, 0), false, true, true],
		[Vector2(f.lounge_x0, f.step_z), Vector2(f.hall_x0, f.step_z), Vector2(0, 1), false, true, false],
		[Vector2(f.hall_x1, f.step_z), Vector2(f.lounge_x1, f.step_z), Vector2(0, 1), true, false, false],
		[Vector2(f.lounge_x0, f.step_z), Vector2(f.lounge_x0, f.back_z), Vector2(1, 0), false, false, false],
		[Vector2(f.lounge_x1, f.step_z), Vector2(f.lounge_x1, f.back_z), Vector2(-1, 0), false, false, true],
		[Vector2(f.lounge_x0, f.back_z), Vector2(f.lounge_x1, f.back_z), Vector2(0, -1), false, false, false],
	]
	var fixtures := _all_fixtures()
	var walls: Array = []
	for spec: Array in specs:
		var from: Vector2 = spec[0]
		var to: Vector2 = spec[1]
		var along := (to - from).normalized()
		var length := from.distance_to(to)
		var mine: Array = []
		for fixture: Dictionary in fixtures:
			var offset: Vector2 = fixture.at - from
			var u := offset.dot(along)
			if absf(offset.dot(spec[2])) < 0.05 and u > -0.01 and u < length + 0.01:
				var placed: Dictionary = fixture.duplicate()
				placed["u"] = u
				mine.append(placed)
		mine.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.u) < float(b.u))
		var wall := {"from": from, "to": to, "along": along, "length": length, "inward": spec[2],
			"convex_from": spec[3], "convex_to": spec[4], "sconces": spec[5], "fixtures": mine}
		wall["bays"] = _bays(length, mine)
		walls.append(wall)
	return walls


## 벽 한 면을 칸으로 나눈다. 고정물(창·문·주크박스…)마다 한 칸을 주고, 남은 빈 곳은 BAY_WIDTH 안팎 칸으로 고르게 나눈다.
## 반환 = [{"from": u, "to": u, "fixture": 고정물 또는 {}}, ...]. 칸 사이 경계마다 월넛 기둥이 선다.
static func _bays(length: float, fixtures: Array) -> Array:
	var bays: Array = []
	var cursor := 0.0
	var spans: Array = []
	for fixture: Dictionary in fixtures:
		var reach: float = float(fixture.half) + float(fixture.pad)
		spans.append([maxf(float(fixture.u) - reach, 0.0), minf(float(fixture.u) + reach, length), fixture])
	spans.append([length, length, {}])
	for span: Array in spans:
		var start: float = maxf(span[0], cursor)
		var gap := start - cursor
		if gap >= MIN_BAY:
			var count := maxi(roundi(gap / BAY_WIDTH), 1)
			for k in range(count):
				bays.append({"from": cursor + gap * k / count, "to": cursor + gap * (k + 1) / count, "fixture": {}})
		elif gap > 0.001:
			# 좁은 틈은 칸을 따로 만들지 않고 다음 고정물 칸(끝이면 앞 칸)에 붙인다.
			if (span[2] as Dictionary).is_empty() and not bays.is_empty():
				bays[-1]["to"] = start
			else:
				start = cursor
		if not (span[2] as Dictionary).is_empty():
			bays.append({"from": start, "to": maxf(span[1], start), "fixture": span[2]})
		cursor = maxf(cursor, span[1])
	return bays


## 끊긴 곳(cut 고정물)을 뺀 띠 구간들: [Vector2(u0, u1), ...].
static func _segments(wall: Dictionary) -> Array:
	var segments: Array = []
	var cursor := 0.0
	for fixture: Dictionary in wall.fixtures:
		if not bool(fixture.cut):
			continue
		var a: float = float(fixture.u) - float(fixture.half)
		if a - cursor > 0.02:
			segments.append(Vector2(cursor, a))
		cursor = float(fixture.u) + float(fixture.half)
	if float(wall.length) - cursor > 0.02:
		segments.append(Vector2(cursor, wall.length))
	return segments


# ─────────────────────────────── 바닥·벽·천장 ───────────────────────────────

## 바닥 한 장 · 벽 8면 · 튀어나온 모서리 둥근 기둥 · 천장.
static func _shell(p: Node3D) -> void:
	var f := _faces()
	var ceiling: float = TableView.CEILING_HEIGHT
	var hall: Rect2 = TableView.DART_HALL
	var lounge: Rect2 = TableView.LOUNGE
	var edge: float = TableView.WALL_THICKNESS / 2.0
	# 바닥: 칸마다 판 한 장(윗면 y = 0). 헤링본 무늬는 세계 좌표로 그려서 두 판 사이에서 끊기지 않는다.
	var floor_mat := _floor_material()
	for slab: Rect2 in [Rect2(hall.position.x - edge, hall.position.y - edge, hall.size.x + edge * 2.0, hall.size.y + edge),
			Rect2(lounge.position.x - edge, lounge.position.y, lounge.size.x + edge * 2.0, lounge.size.y + edge)]:
		MeshKit.box(p, "Floor", Vector3(slab.size.x, 0.1, slab.size.y), Vector3(slab.get_center().x, -0.05, slab.get_center().y), floor_mat)
	for wall: Dictionary in _walls():
		_wall_run(p, wall, ceiling)
	# 튀어나온 모서리(다트 홀 입구 양옆): 둥근 월넛 기둥이 두 벽 띠의 끝을 덮고, 그 위 코브는 모서리를 따라 휘돈다.
	var cornice_top: float = ceiling - COVE_R - 0.06
	for corner: Vector2 in [Vector2(f.hall_x0, f.step_z), Vector2(f.hall_x1, f.step_z)]:
		var column := RoundKit.rounded_profile(PackedVector2Array([Vector2(0, 0), Vector2(0.22, 0), Vector2(0.22, 0.17), Vector2(0.17, 0.22),
			Vector2(0.16, 0.3), Vector2(0.16, cornice_top - 0.2), Vector2(0.21, cornice_top - 0.08), Vector2(0.23, cornice_top), Vector2(0, cornice_top)]), 0.025, 3)
		RoundKit.lathe(p, "CornerColumn", column, Vector3(corner.x, 0, corner.y), _walnut(), 28)
		var cove := MeshKit.mesh_node(p, "CoveCorner", RoundKit.lathe_mesh(_cove_profile(), 12, PI / 2.0), Vector3(corner.x, ceiling, corner.y), _cove_mat())
		cove.rotation.y = 0.0 if corner.x < 0.0 else -PI / 2.0
	# 천장(크림 회벽). 칸마다 한 장이고 그림자를 만들지 않는다. 보는 없다 — 벽 위 코브가 천장으로 부드럽게 넘어간다.
	for roof_rect: Rect2 in [Rect2(hall.position.x - 0.2, hall.position.y - 0.2, hall.size.x + 0.4, hall.size.y + 0.2),
			Rect2(lounge.position.x - 0.2, lounge.position.y, lounge.size.x + 0.4, lounge.size.y + 0.2)]:
		var roof := MeshKit.box(p, "Ceiling", Vector3(roof_rect.size.x, 0.08, roof_rect.size.y),
			Vector3(roof_rect.get_center().x, ceiling + 0.04, roof_rect.get_center().y), _ceiling_mat())
		roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## 벽 한 면: 회벽 판 + (끊긴 곳 빼고) 걸레받이·누빔 징두리·허리 난간 + 코니스·숨은 빛·코브 + 칸마다 기둥·아치 틀.
## 띠들은 들어간 모서리에서 서로 엇갈려 맞물리고(같은 단면이라 이음이 깔끔하다), 튀어나온 모서리는 둥근 기둥이 덮는다.
static func _wall_run(p: Node3D, wall: Dictionary, ceiling: float) -> void:
	var from: Vector2 = wall.from
	var to: Vector2 = wall.to
	var along: Vector2 = wall.along
	var inward: Vector2 = wall.inward
	var length: float = wall.length
	# 1) 회벽 판: 들어간 모서리 쪽 끝만 0.18m 늘려 벽 속에 숨긴다(튀어나온 끝을 늘리면 방 안으로 삐져나온다).
	var wall_from := from - along * (0.0 if wall.convex_from else 0.18)
	var wall_to := to + along * (0.0 if wall.convex_to else 0.18)
	_plank(p, "Wall", (wall_from + wall_to) / 2.0 - inward * 0.09, along, (wall_to - wall_from).length(), 0.18, ceiling / 2.0, ceiling, _plaster())
	# 2) 아래 띠 셋(문·과녁 판넬 자리는 끊는다).
	for segment: Vector2 in _segments(wall):
		var mid := (segment.x + segment.y) / 2.0
		var span := segment.y - segment.x
		_on_wall(p, "Baseboard", _band_mesh("base", _base_profile(), span), wall, mid, 0.0, _walnut_dark())
		_on_wall(p, "Wainscot", RoundKit.channel_panel_mesh(span, WAINSCOT_TOP - BASE_TOP, 0.18, 0.04), wall, mid, BASE_TOP, _leather())
		_on_wall(p, "ChairRail", _band_mesh("rail", _rail_profile(), span), wall, mid, WAINSCOT_TOP, _walnut())
	# 3) 위 띠: 코니스 선반 + 그 위 숨은 빛 + 코브(끊김 없이).
	var cornice_y: float = ceiling - COVE_R - 0.16
	_on_wall(p, "Cornice", _band_mesh("cornice", _cornice_profile(), length), wall, length / 2.0, cornice_y, _walnut())
	var strip := _on_wall(p, "CoveGlowStrip", BoxMesh.new(), wall, length / 2.0, cornice_y + 0.115, _glow(), 0.05)
	(strip.mesh as BoxMesh).size = Vector3(length, 0.03, 0.05)
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cove := _on_wall(p, "Cove", _band_mesh("cove", _cove_profile(), length), wall, length / 2.0, ceiling, _cove_mat())
	cove.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 4) 칸: 경계마다 기둥, 칸마다 둥근 머리 아치 틀(고정물 칸은 고정물 가운데에 맞춘다).
	var frame_top: float = cornice_y - 0.22
	var bays: Array = wall.bays
	for i in range(bays.size()):
		var bay: Dictionary = bays[i]
		if i > 0:
			var post_u: float = bay.from
			var post_height: float = cornice_y - RAIL_TOP
			_on_wall(p, "Pilaster", MeshKit.rounded_box_mesh(Vector3(0.14, post_height, 0.05), 0.02, 3), wall, post_u, RAIL_TOP + post_height / 2.0, _walnut(), 0.025)
			_on_wall(p, "PilasterCap", MeshKit.rounded_box_mesh(Vector3(0.2, 0.07, 0.075), 0.025, 3), wall, post_u, cornice_y - 0.035, _walnut(), 0.037)
		var fixture: Dictionary = bay.fixture
		var center: float = (float(bay.from) + float(bay.to)) / 2.0
		var width: float = float(bay.to) - float(bay.from)
		if not fixture.is_empty():
			if not bool(fixture.frame):
				continue
			center = float(fixture.u)
			width = 2.0 * minf(center - float(bay.from), float(bay.to) - center)
		var frame_width := width - 0.34
		if frame_width < 0.6:
			continue
		var path := RoundKit.arch_path(frame_width, RAIL_TOP, frame_top, minf(0.5, frame_width / 2.0), 8)
		var mesh := RoundKit.sweep_mesh("bayframe|%.3f|%.3f" % [frame_width, frame_top], RoundKit.bead_profile(0.055, 0.03),
			RoundKit.wall_path_rails(path, Vector3.ZERO, Vector3.RIGHT, Vector3.BACK), false, false)
		_on_wall(p, "BayFrame", mesh, wall, center, 0.0, _walnut())


## 천장 줄 자리: [[칸, [z...]], ...]. 2026-11-08 부터 펍에는 천장 보가 없다(코브로 바꿈).
## 네온 오락실(game/lounge/arcade/arcade_room.gd)이 이 자리에 천장 네온 관을 단다 — 홀 길이가 바뀌어도 같이 따라가게 여기 둔다.
## 다트 홀은 입구 쪽부터 2.6m 간격, 과녁 스포트라이트(BOARD_CENTER.z + 1.8)부터 과녁 벽까지는 비운다.
static func ceiling_beams() -> Array:
	var hall: Rect2 = TableView.DART_HALL
	var lounge: Rect2 = TableView.LOUNGE
	var spot_z: float = TableView.BOARD_CENTER.z + 1.8
	var hall_rows: Array[float] = []
	var z: float = hall.end.y - 1.9
	while z > spot_z + 1.2:
		hall_rows.append(z)
		z -= 2.6
	return [[hall, hall_rows],
		[lounge, [lounge.position.y + lounge.size.y * 0.22, lounge.get_center().y, lounge.position.y + lounge.size.y * 0.8]]]


# ─────────────────────────────── 과녁 벽·레인·통 ───────────────────────────────

## 과녁 벽: 청록 특징 판넬 + 머신을 감싸는 큰 아치 틀 + 양옆 칠판 두 장(점수·하우스 룰).
## 다트판 자체는 여기 없다 — 다트 머신(art/dart_machine/dart_machine.gd)이 TableView 실행 때 세워진다.
## 칠판(ChalkScores — GameView 가 글자를 바꾼다)은 투척선에서 보면 머신 어깨(x ±1.35) 바깥이다(x ±2.05).
static func _board_wall(p: Node3D) -> void:
	var f := _faces()
	var ceiling: float = TableView.CEILING_HEIGHT
	var center: Vector3 = TableView.BOARD_CENTER
	var face: float = f.board_z
	MeshKit.box(p, "FeaturePanel", Vector3(FEATURE_HALF * 2, ceiling, 0.05), Vector3(center.x, ceiling / 2, face + 0.025), _teal())
	# 머신 뒤 큰 아치(요청서 콘셉트의 둥근 벽감): 판넬 가장자리(x ±FEATURE_HALF)를 따라 서는 굵은 월넛 틀.
	# 틀 다리가 판넬 옆 징두리·허리 난간·걸레받이의 잘린 끝을 덮는다. 칠판(바깥 끝 x ±2.61)과는 닿지 않는다.
	var top: float = ceiling - COVE_R - 0.4
	var outer := RoundKit.arch_path(FEATURE_HALF * 2.0, 0.0, top, 1.3, 12)
	MeshKit.mesh_node(p, "FeatureArch", RoundKit.sweep_mesh("feature_arch", RoundKit.bead_profile(0.13, 0.11),
		RoundKit.wall_path_rails(outer, Vector3.ZERO, Vector3.RIGHT, Vector3.BACK), false, false), Vector3(center.x, 0, face), _walnut())
	# 칠판 두 장: 둥근 나무 틀 + 칠판면. 왼쪽 = 실시간 점수판, 오른쪽 = 하우스 룰.
	var board_size := Vector2(1.0, 1.7)
	var chalk := Color("e6e3d6")
	for side: float in [-1.0, 1.0]:
		var x: float = center.x + side * 2.05
		MeshKit.rounded_box(p, "ChalkFrame", Vector3(board_size.x + 0.12, board_size.y + 0.12, 0.06), Vector3(x, center.y - 0.1, face + 0.08), _walnut(), 0.03)
		MeshKit.rounded_box(p, "ChalkBoard", Vector3(board_size.x - 0.04, board_size.y - 0.04, 0.012), Vector3(x, center.y - 0.1, face + 0.11), PubParts.chalk_board(), 0.005)
		for y: float in [-1.0, 1.0]:
			MeshKit.mesh_node(p, "ChalkPin", RoundKit.sphere_mesh(0.025, 12), Vector3(x, center.y - 0.1 + y * (board_size.y / 2.0 + 0.03), face + 0.115), _brass())
	var scores := MeshKit.label(p, "ChalkScores", "점 수\n\n―", Vector3(center.x - 2.05, center.y - 0.05, face + 0.12), 28, chalk, 0.0036)
	scores.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	MeshKit.label(p, "ChalkRules", "하 우 스  룰\n\n한 차례 3발\n꾹 = 충전\n오른쪽 = 취소\n늦으면 슬로우!", Vector3(center.x + 2.05, center.y - 0.05, face + 0.12), 30, chalk, 0.0036)


## 놋쇠 기둥 하나(물레 깎기 받침·기둥 + 둥근 꼭지). 높이 약 0.95m.
static func _stanchion(p: Node3D, pos: Vector3) -> void:
	var post := RoundKit.rounded_profile(PackedVector2Array([Vector2(0, 0), Vector2(0.14, 0), Vector2(0.14, 0.025), Vector2(0.05, 0.055),
		Vector2(0.024, 0.09), Vector2(0.022, 0.86), Vector2(0.04, 0.885), Vector2(0, 0.885)]), 0.012, 3)
	RoundKit.lathe(p, "Stanchion", post, pos, _brass(), 20)
	MeshKit.mesh_node(p, "Finial", RoundKit.sphere_mesh(0.052, 16), pos + Vector3(0, 0.925, 0), _brass())


## 두 기둥 사이에 처진 벨벳 로프(매끈한 관 한 줄). a·b 는 기둥 바닥 위치. sag = 가운데가 처지는 정도(m).
static func _rope(p: Node3D, a: Vector3, b: Vector3, sag := 0.17) -> void:
	var points := PackedVector3Array()
	for j in range(13):
		var t := float(j) / 12.0
		points.append(a.lerp(b, t) + Vector3(0, 0.89 - sin(t * PI) * sag, 0))
	MeshKit.mesh_node(p, "VelvetRope", RoundKit.tube_mesh("rope|%s|%s" % [a, b], points, 0.022, 10), Vector3.ZERO, PubParts.rope())


## 레인: 과녁 앞 벨벳 매트 + 놋쇠 투척선 + 투척 구역 경계 로프(이 선 앞으로는 못 들어간다 = TableView 투명벽).
## 2026-11-02 "몸으로 막기": 로프와 투명벽을 몸막 구역(TableView.BLOCK_ZONE)만큼 끊어 두고 그 바닥을 붉게 칠한다.
static func _lane(p: Node3D) -> void:
	var f := _faces()
	var line_z: float = TableView.THROW_LINE_Z
	var fence_z: float = TableView.NO_ENTRY_Z - 0.15
	# 레인 매트는 과녁 벽이 아니라 다트 머신 받침 앞(과녁 면 바로 아래)에서 끝난다.
	var lane_end: float = TableView.BOARD_CENTER.z
	var lane_length: float = fence_z - lane_end
	var lane_center: float = (fence_z + lane_end) / 2.0
	var lane_half: float = TableView.LANE_HALF
	MeshKit.mesh_node(p, "LaneMat", RoundKit.rounded_slab_mesh(Vector2(lane_half * 2, lane_length), 0.02, 0.12), Vector3(0, 0.01, lane_center), MeshKit.material("LaneVelvet", "244d43"))
	for side: float in [-1.0, 1.0]:
		MeshKit.box(p, "LanePinstripe", Vector3(0.02, 0.006, lane_length - 0.3), Vector3(side * (lane_half - 0.1), 0.033, lane_center), _brass())
	# 투척선(Oche): 다트 홀 전체 폭. 이 선 뒤에서 던진다.
	MeshKit.rounded_box(p, "Oche", Vector3(f.hall_x1 - f.hall_x0 - 0.1, 0.03, 0.07), Vector3(0, 0.025, line_z), _brass(), 0.012)
	var oche_text := MeshKit.label(p, "OcheText", "투 척 선", Vector3(0, 0.045, line_z + 0.34), 48, Color("dcc68f"), 0.004)
	oche_text.rotation.x = -PI / 2
	# 로프는 가운데 보호 복도만 두른다(TableView 의 레인 벽과 같은 자리). 복도 바깥 양옆은 비워 둔다.
	var zone: Vector2 = TableView.BLOCK_ZONE
	for side: float in [-1.0, 1.0]:
		for run: Vector2 in [Vector2(fence_z, zone.y), Vector2(zone.x, lane_end + 0.45)]:
			var from_post := Vector3(side * lane_half, 0, run.x)
			var to_post := Vector3(side * lane_half, 0, run.y)
			_stanchion(p, from_post)
			_stanchion(p, to_post)
			_rope(p, from_post, to_post, 0.14)
	_rope(p, Vector3(-lane_half, 0, fence_z), Vector3(lane_half, 0, fence_z))
	# 몸막 구역 바닥(붉은 띠 + 글자). 매트 위에 얇게 덧칠한다.
	var zone_mid: float = (zone.x + zone.y) / 2.0
	MeshKit.mesh_node(p, "BlockZoneFloor", RoundKit.rounded_slab_mesh(Vector2(lane_half * 2 - 0.02, zone.y - zone.x), 0.006, 0.05),
		Vector3(0, 0.031, zone_mid), MeshKit.material("BlockZone", "7c3029"))
	var zone_text := MeshKit.label(p, "BlockZoneText", "몸 으 로  막 기", Vector3(0, 0.05, zone_mid), 40, Color("ffb9a6"), 0.0034)
	zone_text.rotation.x = -PI / 2
	# 로프 가운데에 매단 안내판.
	MeshKit.rounded_box(p, "NoEntryPlaque", Vector3(0.62, 0.24, 0.025), Vector3(0, 0.5, fence_z + 0.03), _brass(), 0.03)
	MeshKit.rounded_box(p, "NoEntryPaper", Vector3(0.56, 0.18, 0.01), Vector3(0, 0.5, fence_z + 0.045), PubParts.dark(), 0.02)
	MeshKit.label(p, "NoEntryText", "출입 금지", Vector3(0, 0.5, fence_z + 0.052), 40, Color("e0c58d"), 0.0022)


## 도면의 럼주통. 큰 통 4개와 곁의 작은 통. 충돌은 TableView.BARRELS / SMALL_BARRELS.
static func _barrels(p: Node3D) -> void:
	var sets := [[TableView.BARRELS, TableView.BARREL_RADIUS, TableView.BARREL_HEIGHT, "RumBarrel"],
		[TableView.SMALL_BARRELS, TableView.SMALL_BARREL_RADIUS, TableView.SMALL_BARREL_HEIGHT, "SmallBarrel"]]
	for entry in sets:
		var spots: Array = entry[0]
		var radius: float = entry[1]
		var height: float = entry[2]
		for i in range(spots.size()):
			var at: Vector3 = spots[i]
			var node_name: String = "%s_%d" % [entry[3], i + 1]
			# RG Poly 나무통(테·나뭇결 있는 모델)을 충돌 원기둥 크기에 맞춰 놓는다. 통마다 조금씩 돌려 똑같아 보이지 않게.
			var big: bool = entry[3] == "RumBarrel"
			var source: Vector3 = Vector3(0.864, 0.907, 0.887) if big else Vector3(0.864, 0.878, 0.887)
			var fit := Vector3(radius * 2.0 / source.x, height / source.y, radius * 2.0 / source.z)
			if PubParts.asset(p, "barrel" if big else "barrel_small", at, i * 1.3 + 0.4, fit, node_name) != null:
				continue
			# 모델이 없으면 배가 부른 통을 물레로 깎는다.
			var belly := RoundKit.rounded_profile(PackedVector2Array([Vector2(0, 0), Vector2(radius * 0.86, 0), Vector2(radius, height * 0.5),
				Vector2(radius * 0.86, height), Vector2(0, height)]), radius * 0.2, 4)
			RoundKit.lathe(p, node_name, belly, at, _walnut(), 24)
	# 투척 구역 안 큰 통 둘(3·4번)은 뚜껑을 덮어 "서서 마시는 탁자"로 쓴다: 맥주잔·잔·치즈/빵.
	for i: int in [2, 3]:
		var top: Vector3 = TableView.BARRELS[i] + Vector3(0, TableView.BARREL_HEIGHT, 0)
		var side: float = -1.0 if TableView.BARRELS[i].x < 0 else 1.0
		if PubParts.asset(p, "barrel_lid", top, 0.3, Vector3(1.0, 0.5, 1.0), "BarrelTableLid_%d" % (i + 1)) == null:
			continue
		var surface: Vector3 = top + Vector3(0, 0.06, 0)
		PubParts.asset(p, "mug", surface + Vector3(0.12 * side, 0, -0.1), 2.2 * side, Vector3.ONE * 0.6)
		PubParts.asset(p, "goblet", surface + Vector3(-0.1 * side, 0, 0.14), 0.0, Vector3.ONE * 0.7)
		PubParts.asset(p, "cheese" if i == 2 else "bread", surface + Vector3(-0.12 * side, 0, -0.15), 0.6, Vector3.ONE * 0.6)


# ─────────────────────────────── 카드 테이블·의자 ───────────────────────────────

## 둥근 클럽 의자(요청서 4장: 폭 0.5~0.58m · 낮은 등받이 · 팔걸이 없음). 앉는 면 = TableView.STOOL_HEIGHT
## (선수·NPC 앉기 몸짓 Seated_Stool 이 맞춰진 높이). 로컬 +Z = 등받이 쪽(앉은 사람 등 뒤).
## piping = 방석 테두리 띠(자리 의자 = 자리 색, NPC 의자 = 놋쇠).
static func _club_chair(parent: Node3D, at: Vector3, yaw: float, node_name: String, piping: Material) -> Node3D:
	var chair := Node3D.new()
	chair.name = node_name
	chair.position = at
	chair.rotation.y = yaw
	parent.add_child(chair)
	var top: float = TableView.STOOL_HEIGHT
	# 방석: 물레로 깎은 도톰한 원판(윗면 가운데가 살짝 부푼다).
	var cushion := RoundKit.rounded_profile(PackedVector2Array([Vector2(0, top - 0.1), Vector2(0.26, top - 0.1), Vector2(0.278, top - 0.045),
		Vector2(0.25, top - 0.004), Vector2(0, top + 0.006)]), 0.035, 4)
	RoundKit.lathe(chair, "Cushion", cushion, Vector3.ZERO, _leather(), 32)
	var base := RoundKit.rounded_profile(PackedVector2Array([Vector2(0, top - 0.16), Vector2(0.22, top - 0.16), Vector2(0.25, top - 0.1), Vector2(0, top - 0.1)]), 0.02, 3)
	RoundKit.lathe(chair, "SeatBase", base, Vector3.ZERO, _walnut(), 28)
	MeshKit.mesh_node(chair, "Piping", RoundKit.ring_mesh("piping", 0.262, RoundKit.circle_profile(0.011, 8), 40), Vector3(0, top - 0.1, 0), piping)
	# 낮은 등받이: 둥근 띠 단면을 등 뒤 140° 원호로 민다(양 끝은 막힌다).
	var rails: Array = []
	for k in range(15):
		var angle := PI / 2.0 + deg_to_rad(-70.0 + 140.0 * k / 14.0)
		var out := Vector3(cos(angle), 0, sin(angle))
		rails.append([out * 0.236 + Vector3.UP * (top + 0.115), out, Vector3.UP])
	MeshKit.mesh_node(chair, "Backrest", RoundKit.sweep_mesh("chair_back", RoundKit.rounded_rect_profile(Vector2(0.07, 0.25), 0.033, 4), rails, true, true), Vector3.ZERO, _leather())
	# 다리 4개: 바깥으로 살짝 벌어진 가는 나무 다리 + 놋쇠 발끝.
	var cap := PackedVector2Array([Vector2(0, 0), Vector2(0.021, 0), Vector2(0.021, 0), Vector2(0.021, 0.035), Vector2(0.021, 0.035), Vector2(0, 0.035)])
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var foot := Vector3(sx * 0.2, 0.0, sz * 0.2)
			RoundKit.rod(chair, "Leg", foot, Vector3(sx * 0.15, top - 0.15, sz * 0.15), 0.017, _walnut_dark(), 0.024, 10)
			RoundKit.lathe(chair, "LegCap", cap, foot, _brass(), 10)
	# 발걸이(2026-11-08): 앉는 면이 0.6m 로 높아(테이블에 팔이 닿게) 앉은 발이 바닥에 안 닿는다 → 다리 네 개를 꿰는
	# 놋쇠 고리에 발을 얹는다. 높이는 앉은 다리 자세(CharacterPoseLayer.SEAT_THIGH·SEAT_SHIN)의 발바닥 높이에 맞춘다.
	_foot_ring(chair, "FootRing", top, 0.2, 0.15, top - 0.15)
	return chair


## 앉은 발이 얹힐 놋쇠 발 고리. 다리는 바닥에서 반폭 foot_offset, 높이 leg_top 에서 반폭 top_offset 이다
## (고리 높이에서 다리 위치를 보간한 반지름으로 네 다리를 꿴다). 고리 윗면 = 앉는 면 − SEATED_SOLE_DROP.
static func _foot_ring(parent: Node3D, node_name: String, seat_top: float, foot_offset: float, top_offset: float, leg_top: float) -> void:
	var tube: float = 0.013
	var y: float = seat_top - SEATED_SOLE_DROP - tube
	var offset: float = lerpf(foot_offset, top_offset, y / leg_top)
	MeshKit.mesh_node(parent, node_name, RoundKit.ring_mesh("foot_ring_%d" % roundi(offset * 1000.0), offset * sqrt(2.0), RoundKit.circle_profile(tube, 8), 40),
		Vector3(0, y, 0), _brass())


## 높은 바 스툴(방석 윗면 BAR_STOOL_TOP): 도톰한 청록 가죽 방석 + 놋쇠 테 + 다리 4개 + 놋쇠 발 고리.
static func _bar_stool(parent: Node3D, at: Vector3, node_name: String) -> Node3D:
	var stool := Node3D.new()
	stool.name = node_name
	stool.position = at
	parent.add_child(stool)
	var top := BAR_STOOL_TOP
	var cushion := RoundKit.rounded_profile(PackedVector2Array([Vector2(0, top - 0.09), Vector2(0.2, top - 0.09), Vector2(0.212, top - 0.04),
		Vector2(0.19, top - 0.003), Vector2(0, top + 0.006)]), 0.03, 4)
	RoundKit.lathe(stool, "Cushion", cushion, Vector3.ZERO, _leather(), 28)
	MeshKit.mesh_node(stool, "CushionRing", RoundKit.ring_mesh("stool_ring", 0.203, RoundKit.circle_profile(0.012, 8), 36), Vector3(0, top - 0.09, 0), _brass())
	var plate := RoundKit.rounded_profile(PackedVector2Array([Vector2(0, top - 0.13), Vector2(0.17, top - 0.13), Vector2(0.19, top - 0.09), Vector2(0, top - 0.09)]), 0.015, 3)
	RoundKit.lathe(stool, "SeatPlate", plate, Vector3.ZERO, _walnut(), 24)
	var hip: float = top - 0.13
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			RoundKit.rod(stool, "Leg", Vector3(sx * 0.19, 0, sz * 0.19), Vector3(sx * 0.12, hip, sz * 0.12), 0.018, _walnut_dark(), 0.022, 10)
	# 발 고리: 앉은 NPC 발바닥 높이(앉는 면 − SEATED_SOLE_DROP)에서 다리 네 개를 꿴다(2026-11-08 — 예전 0.3m 는 발보다 낮았다).
	_foot_ring(stool, "FootRing", top, 0.19, 0.12, hip)
	return stool


## 원형 카드 테이블(요청서 4장: 완전 원형 · 가운데 받침 하나 · 손 얹기 편한 둥근 테두리) + 원형 러그
## + 자리 4개(자리 색 띠 의자·모양 깔개·이름 글자) + 테이블 위 자리 매트(예약 2칸 + 카드 7칸 홈).
## 2026-11-08: 예전 상자 다리 4개(사용자 지적 "테이블 다리가 이상하다") → 물레로 깎은 트럼펫 받침 + 놋쇠 발 고리.
static func _table_and_seats(p: Node3D) -> void:
	var table_center: Vector3 = TableView.TABLE_CENTER
	var size: Vector2 = TableView.TABLE_SIZE
	var height: float = TableView.TABLE_HEIGHT
	var radius: float = size.x / 2.0
	var table := Node3D.new()
	table.name = "CardTable"
	table.position = table_center
	p.add_child(table)
	# 큰 원형 러그(청록 + 놋쇠빛 줄 두 겹). 의자가 다 올라가는 크기.
	var rug := RoundKit.rounded_profile(PackedVector2Array([Vector2(0, 0.002), Vector2(2.5, 0.002), Vector2(2.55, 0.008), Vector2(2.5, 0.012), Vector2(0, 0.012)]), 0.01, 2)
	RoundKit.lathe(table, "TableRug", rug, Vector3.ZERO, RoundKit.clay("RugTeal", "1f3d36", 0.98), 64)
	for ring: Vector2 in [Vector2(2.36, 2.3), Vector2(2.2, 2.17)]:
		RoundKit.lathe(table, "RugStripe", PackedVector2Array([Vector2(ring.x, 0.0125), Vector2(ring.y, 0.0125)]), Vector3.ZERO, RoundKit.clay("RugStripe", "a98552", 0.9), 64)
	# 받침: 바닥 원판 → 오목하게 좁아지는 목 → 상판 아래 받침판.
	var pedestal := RoundKit.rounded_profile(PackedVector2Array([Vector2(0, 0), Vector2(0.62, 0), Vector2(0.62, 0.04), Vector2(0.42, 0.1), Vector2(0.2, 0.24),
		Vector2(0.14, 0.42), Vector2(0.13, height - 0.3), Vector2(0.2, height - 0.2), Vector2(0.45, height - 0.165), Vector2(0, height - 0.16)]), 0.05, 5)
	RoundKit.lathe(table, "Pedestal", pedestal, Vector3.ZERO, _walnut(), 40)
	MeshKit.mesh_node(table, "PedestalFootRing", RoundKit.ring_mesh("table_foot", 0.6, RoundKit.circle_profile(0.022, 8), 56), Vector3(0, 0.035, 0), _brass())
	MeshKit.mesh_node(table, "PedestalCollar", RoundKit.ring_mesh("table_collar", 0.14, RoundKit.circle_profile(0.016, 8), 32), Vector3(0, 0.42, 0), _brass())
	# 상판 몸통(아래가 둥글게 말려 들어간 월넛) + 펠트 + 손 얹는 둥근 난간 테두리. 윗면 모서리(4번 점)는 난간이 덮으니 각지게 둔다.
	var top_edge: Array[int] = [4]
	var body := RoundKit.rounded_profile(PackedVector2Array([Vector2(0, height - 0.16), Vector2(radius - 0.3, height - 0.16), Vector2(radius - 0.12, height - 0.085),
		Vector2(radius - 0.1, height - 0.03), Vector2(radius - 0.1, height - 0.002), Vector2(0, height - 0.002)]), 0.03, 4, top_edge)
	RoundKit.lathe(table, "TableTop", body, Vector3.ZERO, _walnut(), 64)
	var felt := PackedVector2Array([Vector2(0, height - 0.01), Vector2(radius - 0.14, height - 0.01), Vector2(radius - 0.14, height - 0.01),
		Vector2(radius - 0.14, height + 0.004), Vector2(radius - 0.14, height + 0.004), Vector2(0, height + 0.004)])
	RoundKit.lathe(table, "TableFelt", felt, Vector3.ZERO, _felt(), 64)
	MeshKit.mesh_node(table, "TableRim", RoundKit.ring_mesh("table_rim", radius - 0.075, RoundKit.rounded_rect_profile(Vector2(0.15, 0.075), 0.035, 4), 72),
		Vector3(0, height - 0.01, 0), _walnut())
	MeshKit.mesh_node(table, "RimInlay", RoundKit.ring_mesh("table_inlay", radius - 0.152, RoundKit.circle_profile(0.006, 6), 72), Vector3(0, height + 0.004, 0), _brass())
	for i in range(TableView.SEATS.size()):
		var seat: Vector3 = TableView.SEATS[i]
		var direction := Vector3(seat.x - table_center.x, 0, seat.z - table_center.z).normalized()
		# angle: 이 각도로 돌리면 로컬 +Z 가 자리 쪽을 본다.
		var angle := atan2(direction.x, direction.z)
		var color := MeshKit.material("PlayerColor_" + str(i), PlayerLook.hex(i))
		# 테이블 위 자리 매트 + 예약 2칸 + 카드 7칸 홈. 카드는 그리지 않는다(2026-10-31):
		# F5 는 game/table/seat_cards.gd, F6 시연은 table_cards.gd 가 실제 손패 장수만큼 진짜 카드를 이 매트 위에 깐다.
		# 자리·높이(카드 칸 x = −0.36 + 0.12c, z 0.66 · 예약 칸 z 0.44)는 그 두 파일과 약속된 값이라 바꾸지 않는다.
		var mat_root := Node3D.new()
		mat_root.name = "SeatMat_%d" % (i + 1)
		mat_root.rotation.y = angle
		table.add_child(mat_root)
		var top := height + 0.012 + i * 0.0006 # 매트끼리 모서리가 겹쳐도 깜빡이지 않게 높이를 조금씩 다르게
		MeshKit.mesh_node(mat_root, "PlayerMat", RoundKit.rounded_slab_mesh(Vector2(0.86, 0.42), 0.006, 0.06), Vector3(0, top - 0.003, 0.55), color)
		var groove := MeshKit.material("PlayerSlot_" + str(i), Color(PlayerLook.hex(i)).darkened(0.35).to_html(false))
		var slot_mesh := RoundKit.rounded_slab_mesh(Vector2(0.104, 0.15), 0.002, 0.014, 3)
		for c in range(7):
			MeshKit.mesh_node(mat_root, "CardSlot", slot_mesh, Vector3(-0.36 + c * 0.12, top + 0.003, 0.66), groove)
		var reserve_mesh := RoundKit.rounded_slab_mesh(Vector2(0.1, 0.15), 0.002, 0.014, 3)
		for c in range(2):
			MeshKit.mesh_node(mat_root, "ReserveSlot", reserve_mesh, Vector3(-0.08 + c * 0.16, top + 0.003, 0.44), groove)
		var symbol := MeshKit.label(mat_root, "SeatSymbol", PlayerLook.SYMBOLS[i], Vector3(0.36, top + 0.012, 0.42), 64, Color("f0e6cf"), 0.0014)
		symbol.rotation.x = -PI / 2
		# 바닥: 자리 표시 깔개(색 + 모양: 원·세모·네모·마름모 — 요청서 "색과 함께 서로 다른 기호") · 자리 의자 · "● 1번 자리" 글자.
		var sides: int = PlayerLook.MAT_SIDES[i]
		var rug_mesh := RoundKit.slab_mesh("seat_rug_%d" % sides, RoundKit.regular_outline(sides, 0.55, 0.08), 0.012)
		var seat_rug := MeshKit.mesh_node(p, "SeatRug_%d" % (i + 1), rug_mesh, seat + Vector3(0, 0.0125, 0), color)
		seat_rug.rotation.y = angle + (PI / 4 if i == 3 else 0.0)
		_club_chair(p, seat, angle, "SeatStool_%d" % (i + 1), color)
		var label := MeshKit.label(p, "SeatLabel_%d" % (i + 1), "%s %d번 자리" % [PlayerLook.SYMBOLS[i], i + 1], seat + direction * 0.85 + Vector3(0, 0.03, 0), 40, Color("f0e6cf"), 0.003)
		label.rotation = Vector3(-PI / 2, angle, 0)


# ─────────────────────────────── 바 ───────────────────────────────

## 라운지 왼쪽 벽 바(요청서 P01 "둥근 끝의 바 카운터·발받침"): 월넛 몸통 + 둥근 끝 대리석 상판 + 놋쇠 발받침 +
## 맥주 꼭지·종·컵받침, 뒤 아치 병 선반, 바 스툴 3개, 바텐더. 충돌은 TableView.BAR_BOX.
static func _bar(p: Node3D) -> void:
	var f := _faces()
	var box: AABB = TableView.BAR_BOX
	var z0: float = box.position.z + 0.1
	var z1: float = box.end.z - 0.1
	var mid: float = (z0 + z1) / 2.0
	var length: float = z1 - z0
	var front: float = box.end.x # 카운터 윗면 앞 끝 x(방 쪽). 스툴은 이 앞에 놓인다.
	var body_x: float = box.get_center().x - 0.08
	var body_front: float = body_x + 0.36
	_back_bar(p, Vector3(f.lounge_x0 + 0.04, 0, mid), length - 0.6)
	# 몸통(둥근 모서리) + 들어간 발치 + 앞면 판넬(조금 밝은 월넛, 칸마다 둥근 상자).
	MeshKit.rounded_box(p, "BarBody", Vector3(0.72, 0.96, length), Vector3(body_x, 0.56, mid), _walnut(), 0.06)
	MeshKit.rounded_box(p, "BarKick", Vector3(0.62, 0.12, length - 0.06), Vector3(body_x - 0.06, 0.06, mid), _walnut_dark(), 0.03)
	var panel_count := maxi(int(length / 1.2), 1)
	for i in range(panel_count):
		var z := z0 + length * (i + 0.5) / panel_count
		MeshKit.rounded_box(p, "BarPanel", Vector3(0.04, 0.66, length / panel_count - 0.22), Vector3(body_front + 0.005, 0.6, z), _panel_wood(), 0.018)
	# 상판: 위에서 보면 끝이 둥근 대리석 판(윗면 = BAR_TOP_Y) + 아래 월넛 테.
	var top_y: float = TableView.BAR_TOP_Y
	MeshKit.mesh_node(p, "BarTop", RoundKit.rounded_slab_mesh(Vector2(box.size.x + 0.04, length + 0.2), 0.06, 0.35), Vector3(box.get_center().x + 0.02, top_y - 0.06, mid), _marble())
	MeshKit.mesh_node(p, "BarTopBand", RoundKit.rounded_slab_mesh(Vector2(box.size.x - 0.02, length + 0.14), 0.05, 0.32), Vector3(box.get_center().x + 0.01, top_y - 0.11, mid), _walnut())
	# 발받침: 앞면을 따라가다 양 끝에서 몸통으로 휘어 드는 놋쇠 관 + 받침 다리.
	var rail_x: float = body_front + 0.14
	var rail := PackedVector3Array([Vector3(body_front, 0.2, z0 + 0.12), Vector3(rail_x - 0.04, 0.2, z0 + 0.2), Vector3(rail_x, 0.2, z0 + 0.32),
		Vector3(rail_x, 0.2, z1 - 0.32), Vector3(rail_x - 0.04, 0.2, z1 - 0.2), Vector3(body_front, 0.2, z1 - 0.12)])
	MeshKit.mesh_node(p, "FootRail", RoundKit.tube_mesh("bar_foot_rail", rail, 0.026, 12), Vector3.ZERO, _brass())
	var bracket_count := maxi(int(length / 1.5), 2)
	for i in range(bracket_count + 1):
		var z := lerpf(z0 + 0.5, z1 - 0.5, float(i) / bracket_count)
		RoundKit.rod(p, "FootRailBracket", Vector3(body_front, 0.12, z), Vector3(rail_x, 0.2, z), 0.012, _brass(), -1.0, 8)
	# 맥주 꼭지 3개(물레 깎은 놋쇠 기둥 + 색 손잡이).
	var tap_post := RoundKit.rounded_profile(PackedVector2Array([Vector2(0, 0), Vector2(0.05, 0), Vector2(0.04, 0.03), Vector2(0.025, 0.06), Vector2(0.025, 0.36), Vector2(0.035, 0.4), Vector2(0, 0.42)]), 0.01, 2)
	for i in range(3):
		var tap := Vector3(body_x - 0.12, top_y, mid - 0.4 + i * 0.4)
		RoundKit.lathe(p, "TapPost", tap_post, tap, _brass(), 16)
		RoundKit.rod(p, "TapHandle", tap + Vector3(0.03, 0.42, 0), tap + Vector3(0.08, 0.6, 0), 0.022, MeshKit.material("TapHandle_" + str(i), ["cf594f", "e4d7ad", "38806a"][i]), 0.03, 10)
	# 종(건드리기 대상 "Bell" — 노드 하나여야 흔들린다) + 받침. 자리는 LoungeWorld.touch_spots 와 같다.
	var bell_at := Vector3(front - 0.25, top_y, z0 + 0.45)
	RoundKit.lathe(p, "BellStand", RoundKit.rounded_profile(PackedVector2Array([Vector2(0, 0), Vector2(0.07, 0), Vector2(0.07, 0.018), Vector2(0.02, 0.03), Vector2(0, 0.032)]), 0.008, 2), bell_at, _walnut_dark(), 20)
	var bell := RoundKit.rounded_profile(PackedVector2Array([Vector2(0, 0.03), Vector2(0.095, 0.03), Vector2(0.088, 0.05), Vector2(0.062, 0.1), Vector2(0.052, 0.15), Vector2(0.03, 0.18), Vector2(0, 0.19)]), 0.02, 3)
	RoundKit.lathe(p, "Bell", bell, bell_at, _brass(), 24)
	# 컵받침: 맥주잔(집어 마시고 던지는 소품, LoungeWorld)이 놓이는 자리. 잔을 들고 가도 받침은 남는다.
	var coaster := PackedVector2Array([Vector2(0, 0), Vector2(0.1, 0), Vector2(0.1, 0), Vector2(0.1, 0.008), Vector2(0.1, 0.008), Vector2(0, 0.008)])
	for at: Vector3 in TableView.BAR_MUGS:
		RoundKit.lathe(p, "Coaster", coaster, at + Vector3(0, 0.001, 0), _brass(), 24)
	# 바 위 안주(빵·치즈) — 맥주잔과 병 소품 줄 사이 빈자리.
	PubParts.asset(p, "bread", Vector3(front - 0.3, top_y, 2.45), 0.5, Vector3.ONE * 0.7)
	PubParts.asset(p, "cheese", Vector3(front - 0.32, top_y, 2.72), 1.2, Vector3.ONE * 0.55)
	for i in range(3):
		_bar_stool(p, Vector3(front + 0.45, 0, _bar_stool_z(i)), "BarStool_%d" % (i + 1))
	_bar_fridge(p)
	# 바텐더: 선수와 같은 리깅 캐릭터(크림 셔츠). 카운터 뒤에 서서 방 쪽(+X)을 보고, 가끔 손님 쪽을 가리킨다.
	var stand := Vector3((f.lounge_x0 + box.position.x) / 2.0, 0, mid + 1.0)
	# 2026-11-08 사용자 지적 "바텐더는 의상과 디테일이 살아 있어야 해 — 다른 캐릭터와 구분이 돼야 한다":
	#   선수와 같은 캐릭터 + 바텐더 옷(중절모·콧수염·나비넥타이·조끼·소매 밴드·어깨 수건·앞치마, art/pub/npc_outfit.gd).
	NpcIdle.spawn(p, "Bartender", stand, stand + Vector3(3.0, 0, 0), Color("e9e2d0"), false, 1, 0.4, NpcIdle.SEAT_TOP, false, NpcOutfit.Outfit.BARTENDER)


## 바 뒤 병 선반(아치 머리 월넛 틀 + 선반 4단 + 선반 아래 빛 + 병). 로컬 +Z = 방 쪽(+X 를 보게 돌린다).
static func _back_bar(p: Node3D, pos: Vector3, width: float) -> void:
	var shelf := Node3D.new()
	shelf.name = "BottleLibrary"
	shelf.position = pos
	shelf.rotation.y = PI / 2
	p.add_child(shelf)
	var top: float = 3.75
	MeshKit.rounded_box(shelf, "ShelfBack", Vector3(width, top - 1.1, 0.06), Vector3(0, (top + 1.1) / 2.0, 0.03), _walnut_dark(), 0.02)
	var arch := RoundKit.arch_path(width, 1.1, top, 0.7, 10)
	MeshKit.mesh_node(shelf, "ShelfArch", RoundKit.sweep_mesh("back_bar_arch|%.3f" % width, RoundKit.bead_profile(0.14, 0.09),
		RoundKit.wall_path_rails(arch, Vector3.ZERO, Vector3.RIGHT, Vector3.BACK), false, false), Vector3(0, 0, 0.06), _walnut())
	var shelf_mesh := RoundKit.rounded_slab_mesh(Vector2(width - 0.2, 0.3), 0.045, 0.03)
	for y: float in [1.25, 1.93, 2.61, 3.29]:
		MeshKit.mesh_node(shelf, "Shelf", shelf_mesh, Vector3(0, y - 0.045, 0.21), _walnut())
		var strip := MeshKit.box(shelf, "ShelfLight", Vector3(width - 0.4, 0.014, 0.02), Vector3(0, y - 0.055, 0.32), _warm_glow())
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var count := int(width / 0.365) - 1
	for row in range(3):
		for j in range(count):
			var x := -0.365 * (count - 1) / 2.0 + j * 0.365
			var y := 1.30 + row * 0.68
			# RG Poly 병(코르크 마개·라벨 모양 2종 × 4색). 몇 칸은 비우거나 병조림 단지를 섞어 "줄 맞춘 도형" 느낌을 줄인다.
			var pick: int = (j * 7 + row * 3) % 11
			if pick == 4:
				continue
			var spot := Vector3(x + (0.04 if pick % 3 == 0 else -0.03), y - 0.005, 0.2)
			if PubParts.asset(shelf, "jar" if pick == 7 else "shelf_bottle_%d" % ((j + row) % 4), spot,
					0.4 * (pick % 5) - 0.8, Vector3.ONE * (0.85 if pick == 7 else 1.5)) != null:
				continue
			var bottle := RoundKit.rounded_profile(PackedVector2Array([Vector2(0, 0), Vector2(0.065, 0), Vector2(0.067, 0.24), Vector2(0.03, 0.3), Vector2(0.026, 0.4), Vector2(0, 0.41)]), 0.02, 3)
			RoundKit.lathe(shelf, "Bottle", bottle, spot, MeshKit.material("Bottle_" + str((j + row) % 4), ["3c695b", "af7948", "516a77", "7b4641"][(j + row) % 4], 0.15), 14)


## 바 끝 유리문 음료 냉장고. 라운지가 뒤로 길어지며 생긴 바 끝 틈을 막는다.
## 충돌은 TableView.decor_blocks()(BAR_FRIDGE_AT · BAR_FRIDGE_SIZE). 문(유리)은 방 쪽 +X, 안쪽은 따뜻한 빛 + 병 선반 4칸.
## 2026-11-08: 모서리를 모두 둥글렸다(요청서 "상자를 쌓은 외형 대신 둥근 실루엣").
static func _bar_fridge(p: Node3D) -> void:
	var at: Vector3 = TableView.BAR_FRIDGE_AT
	var size: Vector3 = TableView.BAR_FRIDGE_SIZE
	var front: float = at.x + size.x / 2.0
	var fridge := Node3D.new()
	fridge.name = "DrinkFridge"
	p.add_child(fridge)
	# 몸통은 속이 빈 틀(뒤판·옆판·아래·위)이다 — 꽉 찬 상자면 유리문 안의 선반·병이 가려져 안 보인다.
	var depth: float = size.x - 0.02
	MeshKit.rounded_box(fridge, "FridgeBack", Vector3(0.06, size.y, size.z), Vector3(at.x - size.x / 2.0 + 0.03, size.y / 2.0, at.z), _teal(), 0.02)
	for dz: float in [-1.0, 1.0]:
		MeshKit.rounded_box(fridge, "FridgeSide", Vector3(depth, size.y, 0.07), Vector3(at.x - 0.01, size.y / 2.0, at.z + dz * (size.z / 2.0 - 0.035)), _teal(), 0.03)
	MeshKit.rounded_box(fridge, "FridgeBase", Vector3(depth, 0.16, size.z), Vector3(at.x - 0.01, 0.08, at.z), _teal(), 0.03)
	MeshKit.rounded_box(fridge, "FridgeCrown", Vector3(depth, 0.22, size.z), Vector3(at.x - 0.01, size.y - 0.11, at.z), _teal(), 0.04)
	MeshKit.rounded_box(fridge, "FridgeTop", Vector3(size.x + 0.04, 0.06, size.z + 0.04), at + Vector3(0, size.y + 0.03, 0), _walnut(), 0.025)
	MeshKit.rounded_box(fridge, "FridgeKick", Vector3(0.04, 0.12, size.z - 0.04), Vector3(front, 0.06, at.z), _walnut_dark(), 0.015)
	# 안쪽: 따뜻한 빛 판(뒤) + 선반 4칸 + 병. 문 유리는 반투명이라 안이 보인다.
	var inside: float = front - 0.4
	MeshKit.box(fridge, "FridgeGlow", Vector3(0.02, size.y - 0.42, size.z - 0.22), Vector3(inside - 0.08, size.y / 2.0 + 0.06, at.z), MeshKit.material("FridgeLight", "f3e2b8", 0.0, 1.4))
	for shelf in range(4):
		var y: float = 0.36 + shelf * 0.38
		MeshKit.rounded_box(fridge, "FridgeShelf", Vector3(0.42, 0.02, size.z - 0.2), Vector3(inside + 0.12, y, at.z), _brass(), 0.008)
		for slot in range(5):
			var z: float = at.z - size.z / 2.0 + 0.28 + slot * (size.z - 0.56) / 4.0
			PubParts.asset(fridge, "shelf_bottle_%d" % ((shelf + slot) % 4), Vector3(inside + 0.14, y + 0.01, z), slot * 0.9, Vector3.ONE * 0.75)
	var glass := StandardMaterial3D.new()
	glass.resource_name = "FridgeGlass"
	glass.albedo_color = Color(0.75, 0.88, 0.92, 0.18)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic_specular = 0.9
	MeshKit.box(fridge, "FridgeDoorGlass", Vector3(0.02, size.y - 0.32, size.z - 0.12), Vector3(front + 0.005, size.y / 2.0 + 0.04, at.z), glass)
	for dz: float in [-1.0, 1.0]:
		MeshKit.rounded_box(fridge, "FridgeDoorFrame", Vector3(0.05, size.y - 0.3, 0.06), Vector3(front + 0.01, size.y / 2.0 + 0.04, at.z + dz * (size.z / 2.0 - 0.05)), _walnut_dark(), 0.02)
	RoundKit.rod(fridge, "FridgeHandle", Vector3(front + 0.06, 0.8, at.z - size.z / 2.0 + 0.16), Vector3(front + 0.06, 1.35, at.z - size.z / 2.0 + 0.16), 0.016, _brass(), -1.0, 10)
	var label := MeshKit.label(fridge, "FridgeSign", "시원한 음료", Vector3(front + 0.035, size.y - 0.09, at.z), 40, Color("e0c58d"), 0.003)
	label.rotation.y = PI / 2


# ─────────────────────────────── NPC 자리·손님·당구대 ───────────────────────────────

## 도면의 "npc 자리": 둥근 비스트로 테이블(물레 받침) + 클럽 의자 2개. 충돌은 TableView.NPC_TABLE_BOX / NPC_STOOLS.
static func _npc_corner(p: Node3D) -> void:
	var box: AABB = TableView.NPC_TABLE_BOX
	var center := box.get_center()
	var height: float = box.size.y
	var table := Node3D.new()
	table.name = "NpcTable"
	table.position = Vector3(center.x, 0, center.z)
	p.add_child(table)
	var top_r: float = minf(box.size.x, box.size.z) / 2.0 - 0.03
	var top := RoundKit.rounded_profile(PackedVector2Array([Vector2(0, height - 0.06), Vector2(top_r - 0.05, height - 0.06), Vector2(top_r, height - 0.03),
		Vector2(top_r - 0.01, height), Vector2(0, height)]), 0.02, 4)
	RoundKit.lathe(table, "NpcTableTop", top, Vector3.ZERO, _walnut(), 48)
	var stem := RoundKit.rounded_profile(PackedVector2Array([Vector2(0, 0), Vector2(0.4, 0), Vector2(0.4, 0.035), Vector2(0.18, 0.1), Vector2(0.07, 0.25),
		Vector2(0.06, height - 0.2), Vector2(0.12, height - 0.1), Vector2(0.3, height - 0.065), Vector2(0, height - 0.06)]), 0.035, 4)
	RoundKit.lathe(table, "NpcTableStem", stem, Vector3.ZERO, _walnut_dark(), 32)
	# 테이블 위: 먹다 만 저녁(피자·버거·감자튀김) + 맥주잔 둘(앉은 NPC 가 쓰는 자리라는 표시).
	var surface := height + 0.006
	if PubParts.asset(table, "pizza", Vector3(0.1, surface, 0.0), 0.4, Vector3.ONE * 0.85) != null:
		PubParts.asset(table, "burger", Vector3(-0.4, surface, -0.3), 1.1, Vector3.ONE * 0.8)
		PubParts.asset(table, "fries", Vector3(0.42, surface, 0.32), -0.5, Vector3.ONE * 0.8)
		for sz: float in [-0.45, 0.45]:
			RoundKit.lathe(table, "NpcCoaster", PackedVector2Array([Vector2(0, 0), Vector2(0.1, 0), Vector2(0.1, 0.008), Vector2(0, 0.008)]), Vector3(-0.3 * sz * 2.0, height + 0.001, sz), _brass(), 20)
			PubParts.asset(table, "mug", Vector3(-0.3 * sz * 2.0, surface + 0.008, sz), PI if sz > 0 else 0.0, Vector3.ONE * 0.6)
	for i in range(TableView.NPC_STOOLS.size()):
		var chair_at: Vector3 = TableView.NPC_STOOLS[i]
		var away := Vector2(chair_at.x - center.x, chair_at.z - center.z).normalized()
		_club_chair(p, chair_at, _yaw(away), "NpcStool_%d" % (i + 1), _brass())


## 펍 손님 NPC 4명: 구석 테이블에 둘(앉아서 마시기), 바 끝에 서서 마시는 하나, 바 스툴에 앉은 하나.
## 2026-11-08 사용자 지적 "바에 사람이 디자인이 다르고 의자에 앉아 있지도 않아" → 선수와 같은 리깅 캐릭터 + 실제 앉기 몸짓.
## 경기에 끼어들지 않는 장식이라 충돌을 주지 않는다(art/pub/npc_idle.gd). 오락실에서는 이 묶음째 빠진다(ARCADE_SKIP).
static func _guests(p: Node3D) -> void:
	var bar: AABB = TableView.BAR_BOX
	var npc_center: Vector3 = TableView.NPC_TABLE_BOX.get_center()
	var npc_look := Vector3(npc_center.x, 0, npc_center.z)
	var stool_z: float = _bar_stool_z(1)
	var stand_z: float = bar.end.z - 0.35
	# [자리, 바라볼 곳, 앉는가, 모자 색, 안경, 앉는 면 높이, 옷(NpcOutfit.Outfit)]
	# 2026-11-08: 캐릭터가 Tripo 모델로 바뀌며 셔츠 색 바꾸기가 없어졌다 → 손님마다 비니·안경·야구 모자로 구분(선수와도 구분).
	var spots: Array = [
		[TableView.NPC_STOOLS[0], npc_look, true, "b8674a", false, TableView.STOOL_HEIGHT, NpcOutfit.Outfit.GUEST_BEANIE],
		[TableView.NPC_STOOLS[1], npc_look, true, "4f6d8f", true, TableView.STOOL_HEIGHT, NpcOutfit.Outfit.GUEST],
		[Vector3(bar.end.x + 0.42, 0, stand_z), Vector3(bar.position.x, 0, stand_z - 0.3), false, "7d8f4f", false, TableView.STOOL_HEIGHT, NpcOutfit.Outfit.GUEST_CAP],
		[Vector3(bar.end.x + 0.45, 0, stool_z), Vector3(bar.position.x, 0, stool_z), true, "a8576b", false, BAR_STOOL_TOP, NpcOutfit.Outfit.GUEST_BEANIE],
	]
	for i in range(spots.size()):
		var spot: Array = spots[i]
		NpcIdle.spawn(p, "Guest_%d" % (i + 1), spot[0], spot[1], Color(spot[3]), spot[2], 0, i * 1.7, spot[5], spot[4], spot[6])


## 도면의 당구대(요청서 P08 "곡면 모서리"). 충돌은 TableView.POOL_TABLE_BOX.
## 높이는 예전과 같다(펠트 윗면 = 높이 − 0.04, 쿠션 윗면 = 높이 + 0.04) — 공·큐대 소품 자리(LoungeWorld)가 이 높이에 맞춰져 있다.
static func _pool_table(p: Node3D) -> void:
	var box: AABB = TableView.POOL_TABLE_BOX
	var height: float = box.size.y
	var table := Node3D.new()
	table.name = "PoolTable"
	table.position = Vector3(box.get_center().x, 0, box.get_center().z)
	p.add_child(table)
	var half := Vector2(box.size.x / 2.0, box.size.z / 2.0)
	var felt := RoundKit.clay("PoolFelt", "1f6b4a", 0.95)
	MeshKit.rounded_box(table, "PoolBody", Vector3(box.size.x - 0.06, 0.3, box.size.z - 0.06), Vector3(0, height - 0.21, 0), _walnut(), 0.08)
	MeshKit.rounded_box(table, "PoolBed", Vector3(box.size.x - 0.2, 0.04, box.size.z - 0.2), Vector3(0, height - 0.06, 0), felt, 0.015)
	# 쿠션(네 변 레일): 둥근 월넛 띠 + 안쪽 펠트 쿠션.
	for sx: float in [-1.0, 1.0]:
		MeshKit.rounded_box(table, "PoolRail", Vector3(0.13, 0.11, box.size.z), Vector3(sx * (half.x - 0.065), height - 0.015, 0), _walnut(), 0.04)
		MeshKit.rounded_box(table, "PoolCushion", Vector3(0.04, 0.05, box.size.z - 0.26), Vector3(sx * (half.x - 0.14), height - 0.025, 0), felt, 0.018)
	for sz: float in [-1.0, 1.0]:
		MeshKit.rounded_box(table, "PoolRail", Vector3(box.size.x, 0.11, 0.13), Vector3(0, height - 0.015, sz * (half.y - 0.065)), _walnut(), 0.04)
		MeshKit.rounded_box(table, "PoolCushion", Vector3(box.size.x - 0.26, 0.05, 0.04), Vector3(0, height - 0.025, sz * (half.y - 0.14)), felt, 0.018)
	var pocket := PackedVector2Array([Vector2(0, 0), Vector2(0.075, 0), Vector2(0.075, 0), Vector2(0.075, 0.012), Vector2(0.075, 0.012), Vector2(0, 0.012)])
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 0.0, 1.0]:
			RoundKit.lathe(table, "PoolPocket", pocket, Vector3(sx * (half.x - 0.08), height + 0.035, sz * (half.y - 0.08)), PubParts.dark(), 20)
	# 다리 넷: 물레로 깎은 굵은 다리(아래가 부풀었다가 좁아짐) + 놋쇠 발.
	var leg := RoundKit.rounded_profile(PackedVector2Array([Vector2(0, 0), Vector2(0.1, 0), Vector2(0.1, 0.05), Vector2(0.075, 0.08), Vector2(0.12, 0.2),
		Vector2(0.085, 0.34), Vector2(0.1, height - 0.32), Vector2(0, height - 0.32)]), 0.03, 4)
	var foot := PackedVector2Array([Vector2(0, 0), Vector2(0.105, 0), Vector2(0.105, 0), Vector2(0.105, 0.05), Vector2(0.105, 0.05), Vector2(0, 0.05)])
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var at := Vector3(sx * (half.x - 0.2), 0, sz * (half.y - 0.25))
			RoundKit.lathe(table, "PoolLeg", leg, at, _walnut_dark(), 24)
			RoundKit.lathe(table, "PoolFoot", foot, at, _brass(), 24)
	# 공 몇 개와 큐대(세워 놓음).
	var balls := [[Vector2(-0.2, -0.5), "f0e6cf"], [Vector2(0.1, 0.4), "cf594f"], [Vector2(0.25, 0.62), "e4c45a"]]
	for i in range(balls.size()):
		var spot: Vector2 = balls[i][0]
		MeshKit.mesh_node(table, "PoolBall_%d" % (i + 1), RoundKit.sphere_mesh(0.055, 18), Vector3(spot.x, height - 0.04 + 0.055, spot.y), RoundKit.clay("PoolBall_" + str(i), balls[i][1], 0.3))
	RoundKit.rod(table, "PoolCue", Vector3(half.x + 0.1, 0.02, -half.y + 0.2), Vector3(half.x + 0.3, 1.45, -half.y + 0.1), 0.017, _walnut(), 0.008, 10)


# ─────────────────────────────── 창·문·간판·화분·그림 ───────────────────────────────

## 둥근 머리 아치 창(요청서 P09: 창 밖은 추상적인 밤 색면). 로컬 +Z = 방 쪽, 원점 = 벽 면 바닥.
static func _window(parent: Node3D, at: Vector2, inward: Vector2) -> Node3D:
	var root := Node3D.new()
	root.name = "Window"
	root.position = Vector3(at.x, 0, at.y)
	root.rotation.y = _yaw(inward)
	parent.add_child(root)
	var half := 0.75
	var spring := WINDOW_TOP - half
	# 유리 자리: 아래 네모 + 위 반원(볼록 도형 하나)에 창 밖 밤거리 그림(art/pub/window_view.gdshader)을 그린다.
	# 2026-11-08 사용자 지적 "창문 모형에 밖의 풍경이 안 나온다 — 그림을 붙여 주는 게 좋겠다":
	#   예전 = 청록 단색 유리(NightGlass) + 갈색 불빛 띠(CityGlow) → 하늘·별·달·빌딩·불 켜진 창·네온·가로등이 보이는 그림으로.
	#   노드 이름 "WindowView" 는 정적 묶기에서 빠진다(art/static_batch.gd NO_BATCH_NAMES — 묶이면 그림 좌표가 깨진다).
	var outline := PackedVector2Array([Vector2(-half, WINDOW_BOTTOM), Vector2(half, WINDOW_BOTTOM)])
	for s in range(13):
		var angle := PI * s / 12.0
		outline.append(Vector2(cos(angle) * half, spring + sin(angle) * half))
	MeshKit.mesh_node(root, "WindowView", RoundKit.flat_shape_mesh("window_glass", outline), Vector3(0, 0, 0.012), _window_view_material())
	# 틀: 둥근 띠를 아치 길 따라 민다 + 창살(세로 1 · 가로 1 · 반원 안 부챗살 2).
	var frame_path := RoundKit.arch_path(half * 2.0 + 0.05, WINDOW_BOTTOM - 0.02, WINDOW_TOP + 0.025, half + 0.025, 14)
	MeshKit.mesh_node(root, "WindowFrame", RoundKit.sweep_mesh("window_frame", RoundKit.bead_profile(0.11, 0.06),
		RoundKit.wall_path_rails(frame_path, Vector3.ZERO, Vector3.RIGHT, Vector3.BACK), false, false), Vector3.ZERO, _walnut())
	MeshKit.rounded_box(root, "Mullion", Vector3(0.035, WINDOW_TOP - WINDOW_BOTTOM, 0.03), Vector3(0, (WINDOW_TOP + WINDOW_BOTTOM) / 2.0, 0.03), _walnut_dark(), 0.012)
	MeshKit.rounded_box(root, "MullionHorizontal", Vector3(half * 2.0, 0.035, 0.03), Vector3(0, spring, 0.03), _walnut_dark(), 0.012)
	for side: float in [-1.0, 1.0]:
		var tip := Vector3(cos(PI / 2.0 - side * PI / 4.0) * half, spring + sin(PI / 2.0 - side * PI / 4.0) * half, 0.03)
		RoundKit.rod(root, "MullionFan", Vector3(0, spring, 0.03), tip, 0.014, _walnut_dark(), -1.0, 8)
	MeshKit.rounded_box(root, "Sill", Vector3(half * 2.0 + 0.3, 0.07, 0.24), Vector3(0, WINDOW_BOTTOM - 0.06, 0.1), _walnut(), 0.03)
	# 커튼 두 폭(주름진 천을 세로로 민다 — 양면) + 놋쇠 커튼봉.
	var fabric := RoundKit.clay("CurtainFabric", "7e4438", 0.92)
	fabric.cull_mode = BaseMaterial3D.CULL_DISABLED
	var folds := PackedVector2Array()
	for k in range(13):
		folds.append(Vector2(0.1 + sin(k * PI / 2.0) * 0.035, -0.17 + 0.34 * k / 12.0))
	var drape := RoundKit.sweep_mesh("curtain", folds, RoundKit.line_rails(Vector3(0, 1.25, 0), Vector3(0, WINDOW_TOP + 0.3, 0), Vector3.BACK, Vector3.RIGHT), false, false)
	for side: float in [-1.0, 1.0]:
		MeshKit.mesh_node(root, "Curtain", drape, Vector3(side * (half + 0.2), 0, 0), fabric)
	RoundKit.rod(root, "CurtainRod", Vector3(-half - 0.42, WINDOW_TOP + 0.33, 0.12), Vector3(half + 0.42, WINDOW_TOP + 0.33, 0.12), 0.016, _brass(), -1.0, 10)
	for side: float in [-1.0, 1.0]:
		MeshKit.mesh_node(root, "CurtainFinial", RoundKit.sphere_mesh(0.035, 12), Vector3(side * (half + 0.44), WINDOW_TOP + 0.33, 0.12), _brass())
	return root


## 벽 그림 액자(요청서 C18 "자체 기하 패턴"): 월넛 틀 + 크림 캔버스 + 해·아치·언덕 같은 단순 도형.
static func _wall_art(parent: Node3D, at: Vector2, inward: Vector2, kind: int, y: float) -> void:
	var root := Node3D.new()
	root.name = "WallArt_%d" % (kind + 1)
	root.position = Vector3(at.x, y, at.y)
	root.rotation.y = _yaw(inward)
	parent.add_child(root)
	MeshKit.rounded_box(root, "ArtFrame", Vector3(0.78, 0.98, 0.05), Vector3(0, 0, 0.03), _walnut(), 0.02)
	MeshKit.rounded_box(root, "ArtCanvas", Vector3(0.64, 0.84, 0.02), Vector3(0, 0, 0.05), RoundKit.clay("ArtCanvas", "e9dcc4", 0.95), 0.006)
	var terracotta := RoundKit.clay("ArtTerracotta", "c0674a", 0.9)
	var mustard := RoundKit.clay("ArtMustard", "d4a24c", 0.9)
	var teal := RoundKit.clay("ArtTeal", "2f6b5e", 0.9)
	var cream := RoundKit.clay("ArtCanvas", "e9dcc4", 0.95)
	# [가운데, 반지름, 재질, 반원인가]. 그리는 순서대로 조금씩 앞에 놓는다.
	var shapes: Array = []
	match kind:
		0:
			shapes = [[Vector2(0.0, 0.18), 0.14, terracotta, false], [Vector2(0, -0.36), 0.26, teal, true], [Vector2(0, -0.36), 0.17, mustard, true], [Vector2(0, -0.36), 0.08, cream, true]]
		1:
			shapes = [[Vector2(0, -0.3), 0.29, terracotta, true], [Vector2(0, -0.3), 0.22, cream, true], [Vector2(0, -0.3), 0.15, mustard, true], [Vector2(0, -0.3), 0.08, cream, true], [Vector2(0.13, 0.22), 0.07, teal, false]]
		_:
			shapes = [[Vector2(0.12, 0.15), 0.12, mustard, false], [Vector2(-0.14, -0.38), 0.3, teal, true], [Vector2(0.18, -0.38), 0.22, terracotta, true]]
	for i in range(shapes.size()):
		var shape: Array = shapes[i]
		var center: Vector2 = shape[0]
		var radius: float = shape[1]
		var outline := PackedVector2Array()
		var arc: float = PI if bool(shape[3]) else TAU
		var steps := 16 if bool(shape[3]) else 28
		for s in range(steps + (1 if bool(shape[3]) else 0)):
			var angle := arc * s / steps
			outline.append(center + Vector2(cos(angle), sin(angle)) * radius)
		MeshKit.mesh_node(root, "ArtShape", RoundKit.flat_shape_mesh("art|%d|%d" % [kind, i], outline), Vector3(0, 0, 0.061 + i * 0.0015), shape[2])


## 구석 화분(요청서 C18): 물레로 깎은 화분 + 줄기 끝에 달린 둥근 잎(크기·기울기는 seed 로 조금씩 다르게).
static func _plant(parent: Node3D, pos: Vector3, variant: int, pot: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "Plant"
	root.position = pos
	parent.add_child(root)
	var shape := RoundKit.rounded_profile(PackedVector2Array([Vector2(0, 0), Vector2(0.2, 0), Vector2(0.27, 0.36), Vector2(0.3, 0.42), Vector2(0.29, 0.46), Vector2(0.26, 0.44)]), 0.025, 3)
	RoundKit.lathe(root, "Planter", shape, Vector3.ZERO, pot, 28)
	RoundKit.lathe(root, "Soil", PackedVector2Array([Vector2(0.265, 0.425), Vector2(0, 0.425)]), Vector3.ZERO, RoundKit.clay("Soil", "3a2a1f", 1.0), 24)
	var leaf_mesh := RoundKit.lathe_mesh(RoundKit.rounded_profile(PackedVector2Array([Vector2(0, 0), Vector2(0.5, 0.32), Vector2(0.4, 0.78), Vector2(0, 1.0)]), 0.25, 4), 10)
	var greens: Array[Material] = [RoundKit.clay("Leaf", "456f4e", 0.7), RoundKit.clay("LeafLight", "5f8d58", 0.7)]
	var stem_mat := RoundKit.clay("LeafStem", "3e5a3b", 0.8)
	var rng := RandomNumberGenerator.new()
	rng.seed = variant
	for i in range(12):
		var angle := TAU * i / 12.0 + rng.randf_range(-0.2, 0.2)
		var reach := rng.randf_range(0.1, 0.28)
		var tip_y := rng.randf_range(0.8, 1.3)
		var out := Vector3(cos(angle), 0, -sin(angle))
		var base := Vector3(0, 0.42, 0)
		var stem_end := out * reach + Vector3(0, tip_y - 0.25, 0)
		RoundKit.rod(root, "PlantStem", base, stem_end, 0.012, stem_mat, 0.008, 6)
		var leaf := MeshKit.mesh_node(root, "PlantLeaf", leaf_mesh, stem_end, greens[i % 2])
		# 잎 폭은 원둘레 방향(로컬 Z), 두께는 바깥·위 방향(로컬 X) — 잎 면이 위·바깥을 본다.
		leaf.scale = Vector3(0.05, rng.randf_range(0.34, 0.46), rng.randf_range(0.2, 0.28))
		leaf.rotation = Vector3(0, angle, -rng.randf_range(0.45, 1.05))
	return root


## 창·간판·화분·입구 문·조명 스위치·벽 그림.
## 창은 windows 묶음(Windows)에 따로 둔다 — 네온 오락실은 창 없는 방이라 통째로 빼고(LoungeWorld.ARCADE_SKIP) 그 벽에 네온 간판을 단다.
static func _decor(p: Node3D, windows: Node3D, pub_only: Node3D) -> void:
	var f := _faces()
	for spot: Array in _window_spots():
		_window(windows, spot[0], spot[1])
	# 오른쪽 벽 하우스 룰 간판(다트판과 헷갈리지 않게 네모 액자).
	var sign := Node3D.new()
	sign.name = "HouseRulesSign"
	sign.position = Vector3(f.lounge_x1 - 0.05, 2.3, SIGN_Z)
	sign.rotation.y = -PI / 2
	p.add_child(sign)
	MeshKit.rounded_box(sign, "Frame", Vector3(1.75, 1.25, 0.08), Vector3.ZERO, _brass(), 0.04)
	MeshKit.rounded_box(sign, "Paper", Vector3(1.62, 1.12, 0.04), Vector3(0, 0, 0.03), PubParts.dark(), 0.02)
	MeshKit.label(sign, "Title", "좋은 한 발,\n좋은 사람들.", Vector3(0, 0.16, 0.06), 55, Color("e0c58d"), 0.0018)
	MeshKit.label(sign, "Caption", "DARTY   /   소 셜   클 럽", Vector3(0, -0.33, 0.06), 21)
	# 벽 그림 액자(펍 전용 — 오락실은 그 벽에 간판·기계).
	for art: Array in _art_spots():
		var at: Vector2 = art[0]
		_wall_art(pub_only, at, art[1], art[2], art[3])
	# 화분: 주크박스 왼쪽(다트 홀 입구 오른쪽 모서리 옆) — 2026-11-08 주크박스와 겹쳐서 둘 다 옮겼다.
	# 오른쪽 뒤 구석 화분은 오락실에서 인형뽑기 코너 자리라 펍 전용(PubOnly)으로 둔다.
	_plant(p, Vector3(f.hall_x1 + 0.55, 0, f.step_z + 0.6), 3, _brass())
	_plant(pub_only, Vector3(f.lounge_x1 - 0.6, 0, f.back_z - 0.6), 7, RoundKit.clay("Terracotta", "a8684a", 0.9))
	# 입구 문(뒷벽, 방 안쪽에서 보이는 면): 둥근 머리 문틀 + 문짝 판넬 둘 + 작은 아치 유리 + 손잡이 + 문 매트.
	var door := Node3D.new()
	door.name = "EntranceDoor"
	door.position = Vector3(DOOR_X, 0, f.back_z)
	door.rotation.y = PI
	p.add_child(door)
	var frame_path := RoundKit.arch_path(1.36, 0.0, 2.52, 0.38, 10)
	MeshKit.mesh_node(door, "DoorFrame", RoundKit.sweep_mesh("door_frame", RoundKit.bead_profile(0.12, 0.07),
		RoundKit.wall_path_rails(frame_path, Vector3.ZERO, Vector3.RIGHT, Vector3.BACK), false, false), Vector3.ZERO, _walnut_dark())
	var leaf_outline := RoundKit.rounded_polygon(PackedVector2Array([Vector2(-0.6, 0), Vector2(0.6, 0), Vector2(0.6, 2.48), Vector2(-0.6, 2.48)]),
		PackedFloat32Array([0.0, 0.0, 0.34, 0.34]), 8)
	MeshKit.mesh_node(door, "Door", RoundKit.panel_mesh("door_leaf", leaf_outline, 0.04), Vector3(0, 0, 0.005), _walnut())
	for y: float in [0.62, 1.42]:
		MeshKit.rounded_box(door, "DoorPanel", Vector3(0.82, 0.62, 0.025), Vector3(0, y, 0.05), _panel_wood(), 0.03)
	var glass := PackedVector2Array()
	for s in range(13):
		var angle := PI * s / 12.0
		glass.append(Vector2(cos(angle) * 0.32, 1.92 + sin(angle) * 0.32))
	MeshKit.mesh_node(door, "DoorGlass", RoundKit.flat_shape_mesh("door_glass", glass), Vector3(0, 0, 0.047), MeshKit.material("DoorGlass", "f2d4a0", 0.0, 0.45))
	MeshKit.mesh_node(door, "DoorKnob", RoundKit.sphere_mesh(0.04, 14), Vector3(-0.44, 1.05, 0.09), _brass())
	MeshKit.rounded_box(door, "DoorKick", Vector3(1.0, 0.16, 0.012), Vector3(0, 0.1, 0.05), _brass(), 0.005)
	var mat := MeshKit.mesh_node(p, "DoorMat", RoundKit.rounded_slab_mesh(Vector2(1.4, 0.7), 0.012, 0.12), Vector3(DOOR_X, 0.002, f.back_z - 0.55), RoundKit.clay("DoorMat", "6b3f33", 1.0))
	mat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var entrance := MeshKit.label(p, "EntranceSign", "입 구", Vector3(DOOR_X, 2.75, f.back_z - 0.05), 48, Color("e0c58d"), 0.003)
	entrance.rotation.y = PI
	# 문 옆 조명 스위치(기획 M11).
	MeshKit.rounded_box(p, "LightSwitchPlate", Vector3(0.13, 0.2, 0.03), Vector3(DOOR_X - 0.95, 1.35, f.back_z - 0.015), _plaster(), 0.015)
	MeshKit.rounded_box(p, "LightSwitchLever", Vector3(0.03, 0.08, 0.05), Vector3(DOOR_X - 0.95, 1.38, f.back_z - 0.05), _brass(), 0.01)


## 도면 v3(2026-10-31 밤) 에셋 가구: 비어 보이던 곳을 RG Poly 모델로 채운다(docs/MAP_PLAN_2026-10-31.md).
## 자리·충돌은 TableView *_AT 상수와 decor_blocks(), 모양·방향·배율은 여기서 정한다.
## p(Furnishings)는 오락실 테마에서도 남는다. pub_only(PubOnly)는 오락실에서 빠진다(LoungeWorld.ARCADE_SKIP).
## 이름이 붙은 노드(Keg·PracticeTarget·Gramophone)는 LoungeWorld 가 "건드리기"(F) 때 찾아 흔든다 — 이름을 바꾸면 거기도 고친다.
## 2026-11-08: 천장 아래 전구 줄(string lights)은 뺐다 — 요청서 P11 "천장 전선 대신 벽면 장식으로 밀도 확보"(빛은 코브 띠가 낸다).
static func _furnish(p: Node3D, pub_only: Node3D) -> void:
	var f := _faces()
	# 바 뒤: 받침대에 누운 생맥주 통(꼭지가 방 쪽) · 뒤 조리대 + 커피 머신 · 병조림 · 구석 화분(오락실에서는 경품 진열대 자리).
	PubParts.asset(pub_only, "keg", TableView.KEG_AT, PI / 2, Vector3.ONE * 0.95, "Keg")
	PubParts.asset(pub_only, "back_counter", TableView.BACK_COUNTER_AT, PI / 2, Vector3.ONE, "BackCounter")
	_plant(pub_only, Vector3(f.lounge_x0 + 0.6, 0, f.back_z - 0.6), 11, _brass())
	# 조리대 윗면 1.0m. 병 선반 판과 겹치지 않게 방 쪽 절반에만 올린다.
	var counter_top: Vector3 = TableView.BACK_COUNTER_AT + Vector3(0.22, 1.0, 0)
	PubParts.asset(pub_only, "coffee_machine", counter_top + Vector3(0, 0, -0.32), PI / 2, Vector3.ONE * 0.8, "CoffeeMachine")
	PubParts.asset(pub_only, "honey_jar", counter_top + Vector3(0.02, 0, 0.22), 0.3, Vector3.ONE * 0.7)
	PubParts.asset(pub_only, "jar", counter_top + Vector3(0.08, 0, 0.48), 0.0, Vector3.ONE * 0.8)
	# 다트 홀: 연습 과녁(장식 — 점수 없음, 건드리면 흔들린다) · 양동이와 벽에 기댄 빗자루.
	PubParts.asset(p, "practice_target", TableView.PRACTICE_TARGET_AT, 1.4, Vector3.ONE, "PracticeTarget")
	PubParts.asset(p, "bucket", TableView.BUCKET_AT, 0.7, Vector3.ONE, "Bucket")
	var broom := PubParts.asset(p, "broom", Vector3(f.hall_x1 - 0.2, 0, TableView.BUCKET_AT.z - 0.55), 0.0, Vector3.ONE, "Broom")
	if broom != null:
		broom.rotation.z = -0.1 # 위쪽이 벽(+X)에 기댄다
	# 다트 홀 옆벽 선반(구경꾼 잔 놓는 곳): 왼쪽·오른쪽 벽, 1.75m. 벽 칸 나누기가 이 자리(z −1.5)를 비워 둔다.
	for side: float in [-1.0, 1.0]:
		var wall_x: float = f.hall_x1 - 0.26 if side > 0 else f.hall_x0 + 0.26
		var shelf := PubParts.asset(pub_only, "hang_shelf", Vector3(wall_x, 1.75, -1.5), 0.0 if side < 0 else PI, Vector3.ONE, "WallShelf", false)
		if shelf == null:
			continue
		var top: float = 1.75 + shelf.mesh.get_aabb().end.y
		PubParts.asset(pub_only, "mug", Vector3(wall_x + side * 0.05, top, -1.85), 1.0, Vector3.ONE * 0.55)
		PubParts.asset(pub_only, "goblet", Vector3(wall_x + side * 0.05, top, -1.45), 0.0, Vector3.ONE * 0.65)
		PubParts.asset(pub_only, "jar", Vector3(wall_x + side * 0.05, top, -1.05), 0.6, Vector3.ONE * 0.7)
	# 라운지 뒷벽: 구경 소파(카드 테이블 쪽을 본다). 오락실에서는 오락기 자리라 뺀다.
	PubParts.asset(pub_only, "sofa", TableView.SOFA_AT, PI / 2, Vector3.ONE, "Sofa")
	# 오른쪽 귀퉁이: 안락의자(창 쪽 벽을 등지고 방 안을 본다) + 낮은 탁자 위 축음기.
	PubParts.asset(p, "armchair", TableView.ARMCHAIR_AT, -PI / 2, Vector3.ONE, "Armchair")
	PubParts.asset(p, "side_table", TableView.SIDE_TABLE_AT, 0.0, Vector3(0.45, 0.5, 0.45), "SideTable")
	PubParts.asset(p, "gramophone", TableView.SIDE_TABLE_AT + Vector3(0, 0.4, 0), -2.3, Vector3.ONE * 0.75, "Gramophone")
	# 문 옆 짐: 나무 상자 둘을 엇갈려 쌓고 곡물 자루를 기대 둔다(배달 온 술·안주).
	PubParts.asset(p, "crate", TableView.CRATES_AT, 0.15, Vector3.ONE, "Crate")
	PubParts.asset(p, "crate", TableView.CRATES_AT + Vector3(0.03, 0.59, -0.02), 0.5, Vector3.ONE * 0.9, "CrateTop")
	PubParts.asset(p, "grain_bag", TableView.GRAIN_BAG_AT, 0.9, Vector3.ONE, "GrainBag")
	# 문 오른쪽 옷걸이 고리 셋(오락실에서는 인형뽑기 기계 자리라 펍 전용). 창 커튼(x 10.1~)보다 왼쪽.
	for k in range(3):
		PubParts.asset(pub_only, "hook", Vector3(9.55 + k * 0.2, 1.75, f.back_z - 0.06), PI, Vector3.ONE, "CoatHook", false)


# ─────────────────────────────── 조명 ───────────────────────────────

## 천장 펜던트: 물레로 깎은 놋쇠 돔 갓 + 안쪽 따뜻한 빛 + 천장 받침. pos = 갓 아래 테두리 가운데.
## 노드 이름은 모두 "Pendant" 로 시작한다(오락실이 이름으로 찾아 뺀다).
static func _pendant(p: Node3D, pos: Vector3, ceiling: float, energy := 0.65, light_range := 6.5, shadow := false, size := 1.0) -> OmniLight3D:
	var r := 0.26 * size
	RoundKit.rod(p, "PendantCable", pos + Vector3(0, 0.29 * size, 0), Vector3(pos.x, ceiling - 0.04, pos.z), 0.007, _walnut_dark(), -1.0, 6)
	var canopy := RoundKit.rounded_profile(PackedVector2Array([Vector2(0, -0.06), Vector2(0.05, -0.06), Vector2(0.09, -0.01), Vector2(0.09, 0.0), Vector2(0, 0.0)]), 0.02, 3)
	RoundKit.lathe(p, "PendantCanopy", canopy, Vector3(pos.x, ceiling, pos.z), _brass(), 20)
	var dome := RoundKit.rounded_profile(PackedVector2Array([Vector2(r, 0), Vector2(r * 0.94, 0.1 * size), Vector2(r * 0.55, 0.21 * size),
		Vector2(0.05 * size, 0.25 * size), Vector2(0.035 * size, 0.3 * size), Vector2(0, 0.3 * size)]), 0.04 * size, 4)
	RoundKit.lathe(p, "PendantShade", dome, pos, _brass(), 28)
	var lining := RoundKit.rounded_profile(PackedVector2Array([Vector2(0, 0.24 * size), Vector2(r * 0.5, 0.18 * size), Vector2(r * 0.88, 0.08 * size), Vector2(r - 0.008, 0.002)]), 0.03 * size, 3)
	RoundKit.lathe(p, "PendantLining", lining, pos, _warm_glow(), 28)
	MeshKit.mesh_node(p, "PendantRim", RoundKit.ring_mesh("pendant_rim|%.2f" % size, r, RoundKit.circle_profile(0.01, 6), 40), pos, _brass())
	MeshKit.mesh_node(p, "PendantBulb", RoundKit.sphere_mesh(0.07 * size, 14), pos + Vector3(0, 0.06 * size, 0), _warm_glow())
	var light := OmniLight3D.new()
	light.name = "PendantLight"
	light.position = pos + Vector3(0, -0.15 * size, 0)
	light.light_color = Color("ffdbad")
	light.light_energy = energy
	light.omni_range = light_range
	light.omni_attenuation = 1.2
	light.shadow_enabled = shadow
	p.add_child(light)
	return light


## 벽등(요청서 콘셉트의 놋쇠 반쪽 그릇 업라이트): 벽판 + 위로 열린 반원 그릇 + 안쪽 빛 + 실제 빛. facing = 벽에서 방 쪽.
static func _sconce(p: Node3D, pos: Vector3, facing: Vector3, energy := 0.35) -> void:
	var root := Node3D.new()
	root.name = "Sconce"
	root.position = pos
	root.rotation.y = atan2(facing.x, facing.z)
	p.add_child(root)
	MeshKit.rounded_box(root, "SconcePlate", Vector3(0.12, 0.24, 0.03), Vector3(0, 0, 0.015), _brass(), 0.012)
	var cup := RoundKit.rounded_profile(PackedVector2Array([Vector2(0, 0), Vector2(0.06, 0), Vector2(0.11, 0.04), Vector2(0.135, 0.1), Vector2(0.14, 0.13)]), 0.02, 3)
	# 반원(π)만 돌린 물레 깎기 = 로컬 +Z(방 쪽) 반쪽 그릇.
	MeshKit.mesh_node(root, "SconceCup", RoundKit.lathe_mesh(cup, 16, PI), Vector3(0, -0.04, 0.03), _brass())
	var lining := RoundKit.rounded_profile(PackedVector2Array([Vector2(0.13, 0.13), Vector2(0.125, 0.1), Vector2(0.1, 0.045), Vector2(0.05, 0.012), Vector2(0, 0.012)]), 0.015, 3)
	MeshKit.mesh_node(root, "SconceGlow", RoundKit.lathe_mesh(lining, 16, PI), Vector3(0, -0.04, 0.03), _warm_glow())
	var light := OmniLight3D.new()
	light.name = "SconceLight"
	light.position = Vector3(0, 0.2, 0.25)
	light.light_color = Color("ffc98c")
	light.light_energy = energy
	light.omni_range = 3.2
	root.add_child(light)


## 환경(배경색·주변광·톤·SSAO)과 조명. 다트판에 가장 밝은 흰 스포트라이트(기획 2-6), 나머지는 주황빛 펜던트·벽등·코브 빛.
## 2026-11-08: 화면 공간 접촉 그림자(SSAO)를 켠다 — 가구가 바닥·벽에 "붙어" 보이게 하는 점토 느낌의 핵심(요청서 2장 "부드러운 접촉 그림자").
static func _lighting(p: Node3D) -> void:
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("182924")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c4b59c")
	env.ambient_light_energy = 0.36
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_hdr_threshold = 1.05
	env.ssao_enabled = true
	env.ssao_radius = 0.9
	env.ssao_intensity = 1.6
	env.ssao_power = 1.4
	env.ssao_detail = 0.4
	world.environment = env
	p.add_child(world)
	var fill := DirectionalLight3D.new()
	fill.name = "SoftFill"
	fill.rotation_degrees = Vector3(-55, -25, 0)
	fill.light_color = Color("ffe2b6")
	fill.light_energy = 0.2
	p.add_child(fill)
	var ceiling: float = TableView.CEILING_HEIGHT
	var table: Vector3 = TableView.TABLE_CENTER
	# 테이블 위 펜던트(요청서: 최하단 3.2m 이상).
	_pendant(p, table + Vector3(0, 3.3, 0), ceiling, 1.05, 7.5, true, 1.3)
	# 다트 홀: 투척 자리 위와 입구 쪽(레인 위에는 달지 않는다).
	_pendant(p, Vector3(0, 3.3, TableView.THROW_LINE_Z + 0.6), ceiling, 0.6, 6.5)
	_pendant(p, Vector3(0, 3.45, -1.4), ceiling, 0.5, 6.0)
	for side: float in [-1.0, 1.0]:
		_pendant(p, Vector3(side * 3.6, 3.35, TableView.THROW_LINE_Z + 1.6), ceiling, 0.4, 5.5, false, 0.85)
	# 바 위 놋쇠 돔 셋(콘셉트처럼 줄지어).
	var bar: AABB = TableView.BAR_BOX
	for i in range(3):
		_pendant(p, Vector3(bar.get_center().x - 0.1, 3.0, _bar_stool_z(i)), ceiling, 0.4, 4.5, false, 0.75)
	_pendant(p, Vector3(TableView.NPC_TABLE_BOX.get_center().x, 3.1, TableView.NPC_TABLE_BOX.get_center().z), ceiling, 0.55, 5.5, false, 0.9)
	_pendant(p, Vector3(TableView.POOL_TABLE_BOX.get_center().x, 3.1, TableView.POOL_TABLE_BOX.get_center().z), ceiling, 0.6, 5.5, false, 1.1)
	# 넓어진 라운지(뒤쪽 소파 · 입구 · 오른쪽 안락의자)도 어둡지 않게.
	for at: Vector3 in [Vector3(-3.1, 3.4, 7.4), Vector3(8.4, 3.4, 7.6), Vector3(12.4, 3.3, 1.6)]:
		_pendant(p, at, ceiling, 0.4, 5.0, false, 0.85)
	# 벽등: 벽 칸 나누기에서 고정물이 없는 칸 가운데(다트 홀 양옆 · 라운지 오른쪽 벽).
	for wall: Dictionary in _walls():
		if not bool(wall.sconces):
			continue
		for bay: Dictionary in wall.bays:
			if not (bay.fixture as Dictionary).is_empty() or float(bay.to) - float(bay.from) < 0.9:
				continue
			var u: float = (float(bay.from) + float(bay.to)) / 2.0
			var at: Vector2 = wall.from + wall.along * u
			var inward: Vector2 = wall.inward
			_sconce(p, Vector3(at.x, 2.55, at.y), Vector3(inward.x, 0, inward.y))
	var spot := SpotLight3D.new()
	spot.name = "BoardSpot"
	spot.position = Vector3(TableView.BOARD_CENTER.x, ceiling - 0.2, TableView.BOARD_CENTER.z + 1.8)
	spot.light_color = Color("ffe6c4")
	spot.light_energy = 2.2
	spot.spot_range = 5.5
	spot.spot_angle = 32
	spot.spot_attenuation = 0.6
	spot.shadow_enabled = true
	# 아직 장면 트리 밖이라 look_at 대신 방향 행렬을 직접 만든다(조명은 -Z 쪽을 비춘다).
	spot.basis = Basis.looking_at(TableView.BOARD_CENTER - spot.position)
	p.add_child(spot)
