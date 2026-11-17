extends RefCounted
## 펍 방 생성기 공용 부품함(2026-11-17 모듈 나누기). 디자인 담당 소유. 게임 실행 중에는 안 쓰인다(생성기 전용).
## 방 생성기 모듈(art/pub/room/room_*.gd)과 조립표(art/pub/game_room_builder.gd)가 모두 이 파일을 extends 한다
## → 아래 상수·재질·벽 계산 함수를 앞에 아무것도 안 붙이고 그대로 부를 수 있다.
##
## [여기 있는 것]
##   - 방 치수 상수: 벽 높이(걸레받이·징두리·허리 난간·코브) · 창 높이 · 겹침 틈(WALL_LAYER_GAP) · 바 자리 · 전등 높이
##   - 재질(_walnut·_brass·_teal …): 이름이 오락실 색 바꾸기 표(lounge_world._recolor)와 이어져 있으니 이름을 바꾸지 않는다.
##   - 벽 계획(_faces·_walls·_bays·_all_fixtures): 벽 8면 · 칸 나누기 · 창/문/주크박스 자리
##   - 여러 모듈이 같이 쓰는 손 부품: _wall_mount(벽 위 한 점) · _on_shelf/_plank_shelf(선반 소품) · _model(GLB) · _sconce(벽등) · _pendant(펜던트)
## [고칠 때] 새 모듈만 쓰는 함수는 그 모듈에 둔다. 둘 이상이 쓰게 되면 여기로 옮긴다.
## 모듈 지도 = art/pub/room/README.md

const MeshKit = preload("res://art/mesh_kit.gd")
const PubParts = preload("res://art/pub/pub_parts.gd")
const RoundKit = preload("res://art/pub/round_kit.gd")
## 인디 펍 소품 선반이 물건 크기를 미리 잴 때 쓴다(_plank_shelf).
const RgPoly = preload("res://art/vendor/rg_poly/rg_poly_catalog.gd")
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
## 자리 깔개(SeatRug) 아랫면 높이·두께(m). 윗면 = 0.0325m — 펍 러그(0.012m)·오락실 러그(0.026m)보다 높다.
const SEAT_RUG_BASE := 0.0125
const SEAT_RUG_THICKNESS := 0.02
## 창(아치) 아래 끝·위 끝 높이.
const WINDOW_BOTTOM := 1.45
const WINDOW_TOP := 3.55
## [겹침 깜빡임(z-파이팅) 규칙 — 2026-11-15 사용자 지적 "벽에 붙은 그림·바닥이 치지직 깜빡인다"]
## 같은 쪽을 보는 두 면이 거의 같은 평면에 겹치면 깊이 버퍼(24비트)가 둘을 가르지 못해 멀리서 깜빡인다.
## 방 끝에서 끝(약 25m)까지 보면 구분할 수 있는 틈이 1mm 가까이로 커진다 → 겹쳐 놓는 얇은 판은 아래 값만큼 띄운다.
## 벽 그림·유리처럼 벽에 붙는 판 = WALL_LAYER_GAP, 러그 줄무늬처럼 바닥에 까는 판 = FLOOR_LAYER_GAP.
const WALL_LAYER_GAP := 0.008
const FLOOR_LAYER_GAP := 0.004

static var _floor_shader_material: ShaderMaterial
## [2026-11-16 창 밖 = 진짜 3D — 사용자 "밖의 풍경이 고도 엔진 안에서 안 보인다 · 건물들이 전부 누워 있다 · 하늘이 2D"]
## 예전(11-08~11-15) 창은 유리판에 밤거리 그림(window_view.gdshader + SVG/PNG)을 그렸다. 그래서 편집기 장면에는
## 바깥이 없었고, 그림 속 건물 일부는 누운 모델을 찍은 것이었다. 이제:
##   - 벽 판을 창 자리에서 잘라 진짜 구멍을 낸다(_wall_run · _window_hole). 유리는 거의 투명한 판(WindowGlass).
##   - 바깥 거리·건물·하늘·달은 art/pub/street_outside.gd 가 "Outside" 묶음으로 세운다(편집기에서도 보인다).
##   - 네온 오락실은 창 없는 방이라 Windows·Outside 를 빼고 구멍 메우는 회벽(WindowPlugs)을 켠다(lounge_world._trim_arcade).
## 창 유리 구멍 반폭(m). 창 틀(WindowFrame)은 이보다 0.025m 바깥을 돈다.
const GLASS_HALF := 0.75
const StreetOutside = preload("res://art/pub/street_outside.gd")
## 벽 액자 포스터 3장(_art_spots 의 그림 번호 순서): 놀란 과녁 친구 180! · 건배 맥주잔 CHEERS! · 윙크 하트 에이스 LUCKY!
const POSTER_PICTURES: Array[String] = [
	"res://art/pub/pictures/poster_bullseye.svg",
	"res://art/pub/pictures/poster_cheers.svg",
	"res://art/pub/pictures/poster_lucky.svg",
]
## 라운드하우스 펍 가구 GLB(Codex 묶음 1 v2, 2026-11-08 사용자 승인): <key>/<key>.glb.
## 모델마다 원점(바닥 가운데 · 커튼은 봉 가운데 · 옷걸이는 벽에 닿는 판 뒷면)·정면(-Z)·미터 크기가 이미 맞춰져 있다 →
## 배율 1 그대로 놓는다. 옛 RG Poly 의 바닥 자동 보정·배율(낮은 탁자 0.45, 축음기 0.75 …)은 다시 쓰지 않는다.
const ROUNDHOUSE_PUB := "res://art/environments/roundhouse/pub/%s/%s.glb"
## 커튼 봉 높이(창 위 끝 + 0.33m = 예전 놋쇠 봉 자리). 커튼 모델은 봉에서 2.347m 아래까지 내려와 아래 끝이 창턱(1.43m) 위 1.53m 다.
const CURTAIN_ROD_Y := WINDOW_TOP + 0.33
## 벽걸이 옷걸이(벽걸이 판 가운데) 높이. 걸린 코트 아래 끝(판 가운데 − 0.62m)이 허리 난간 윗면(RAIL_TOP) 위에 오게 했다.
## 2026-11-16: 뒷벽 문 옆(x 9.62) → 꾸미기 방 상자 오른쪽 옆벽(room_fitting.gd)으로 옮겼다.
const COAT_RACK_Y := RAIL_TOP + 0.63
## 축음기 방향(yaw). 나팔이 방 안 (−0.67, +0.75) 쪽을 본다.
## 2026-11-08: 사용자가 고른 RG Poly 축음기(Gramophone — 나팔 = 모델 +Z, 4면 렌더로 확인)로 바꿨다.
## 예전 라운드하우스 축음기(나팔 = -Z)의 2.41 에서 반 바퀴 뺀 값이다.
const GRAMOPHONE_YAW := 2.41 - PI
## [2026-11-08 바텐더 서빙 — art/pub/pub_service.gd] 바텐더가 걷는 바 뒤 통로 x · 손님 앞에 잔을 놓을 때 다가서는 x ·
## 뒤 조리대(주방 기구) 앞에 다가서는 x · 걸을 수 있는 z. 통로는 바 뒤판(x −5.85)과 생맥주 통(x −7.0)·조리대(x −7.35) 사이다.
const BAR_LANE_X := -6.45
const BAR_SERVE_X := -6.12
const BACK_COUNTER_REACH_X := -6.95
const BAR_LANE_Z := Vector2(0.7, 7.0)
## 뒤 조리대(z 5.67~6.93) 위 주방 기구 z: 전자레인지(음식을 꺼낸다) · 토스터 · 커피 머신(커피를 내린다).
const MICROWAVE_Z := 5.98
const TOASTER_Z := 6.4
const COFFEE_Z := 6.74
## 바 끝에 서서 시가를 피우는 손님 앞 재떨이(바 윗면, 둥근 끝 안쪽).
const BAR_ASHTRAY := Vector3(-5.12, 1.1, 7.08)
## 등 높이 규칙(2026-11-08 사용자 "전등이 너무 무규칙적으로 설치된 느낌"): 라운지 펜던트는 모두 갓 아래 끝 3.2m,
## 다트 홀은 투척선 뒤 한 줄(z −2.2, 높이 3.3m).
const LOUNGE_PENDANT_Y := 3.2
const HALL_PENDANT_Y := 3.3
const HALL_PENDANT_Z := -2.2
const TABLE_FOOD_SCRIPT := "res://art/pub/npc_table_food.gd"
const PubService = preload("res://art/pub/pub_service.gd")

## 에디터 장면 목록에서 찾기 쉽도록 부위별 묶음 노드를 만든다.
static func _group(parent: Node3D, group_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = group_name
	parent.add_child(node, true)
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


## 창 유리(2026-11-16): 거의 투명한 판. 방 등불이 비치는 반짝임만 살짝 남아 "유리가 있다"는 느낌을 준다.
## 투명 재질은 정적 묶기에서 빠진다(이름 "WindowGlass" — art/static_batch.gd NO_BATCH_NAMES).
static func _window_glass() -> StandardMaterial3D:
	if MeshKit.materials.has("WindowGlass"):
		return MeshKit.materials["WindowGlass"]
	var glass := StandardMaterial3D.new()
	glass.resource_name = "WindowGlass"
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.78, 0.86, 1.0, 0.07)
	glass.roughness = 0.06
	glass.metallic_specular = 0.7
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	MeshKit.materials["WindowGlass"] = glass
	return glass


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


## 바 스툴 i 번 자리 z. 2026-11-08: 바 길이 3등분 → 바 위 맥주잔·병 줄 사이 빈 곳 앞(TableView.BAR_STOOLS_Z) —
## 앉은 손님 앞 바 윗면에 바텐더가 잔·접시를 놓을 자리가 있어야 한다.
static func _bar_stool_z(i: int) -> float:
	return TableView.BAR_STOOLS_Z[i]


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

## 창 자리: [바닥 위 점(x, z), 방 안쪽 방향]. room_decor.gd build_decor 가 창을 걸고, 벽 칸 나누기가 창 둘레에 칸을 맞춘다.
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
		# "window" = 벽 판에 구멍을 내는 고정물(_wall_run).
		var window := _fixture(spot[0], WINDOW_HALF)
		window["window"] = true
		list.append(window)
	for art: Array in _art_spots():
		list.append(_fixture(art[0], 0.42))
	list.append(_fixture(Vector2(0, f.board_z), FEATURE_HALF, false, true, 0.0))
	# 다트 홀 입구 쪽 벽 선반(펍)·오락기 위 자리: 기둥이 선반을 뚫지 않게 칸을 비운다.
	for x: float in [f.hall_x0, f.hall_x1]:
		list.append(_fixture(Vector2(x, -1.5), 0.45, false))
	list.append(_fixture(Vector2(JUKEBOX_X, f.step_z), 0.75))
	# 입구 문 자리 = 2026-11-16 꾸미기 방 상자(TableView.FITTING_ROOM_BOX) 폭만큼 비운다 — 칸 기둥이 상자 바로 바깥에 선다.
	list.append(_fixture(Vector2(DOOR_X, f.back_z), TableView.FITTING_ROOM_BOX.size.x / 2.0, false, true, 0.12))
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


## 창 유리 자리 테두리(아래 네모 + 위 반원, x 오른쪽·y 위). 유리·구멍 메우개가 같이 쓴다.
static func _window_outline(segments := 16) -> PackedVector2Array:
	var spring: float = WINDOW_TOP - GLASS_HALF
	var outline := PackedVector2Array([Vector2(-GLASS_HALF, WINDOW_BOTTOM), Vector2(GLASS_HALF, WINDOW_BOTTOM)])
	for s in range(segments + 1):
		var angle := PI * s / segments
		outline.append(Vector2(cos(angle) * GLASS_HALF, spring + sin(angle) * GLASS_HALF))
	return outline


## 라운드하우스 GLB 하나를 장면 그대로 세운다 — 여러 재질·텍스처·부품 노드(커튼 좌우·화분 잎 …)를 그대로 둔다.
## 저장할 때 MeshKit.own_tree 가 이 노드까지만 주인을 정해 pub_game.tscn 에는 "GLB 인스턴스 한 줄"로 들어간다(속 메시를 복사하지 않는다).
## 오락실 색 바꾸기는 LoungeWorld._recolor 가 면마다 복제 재질로 덮는다. 정적 묶기에서는 빠진다(art/static_batch.gd ROUNDHOUSE_DIR).
static func _model(parent: Node3D, key: String, pos: Vector3, yaw: float, node_name: String) -> Node3D:
	var node := (load(ROUNDHOUSE_PUB % [key, key]) as PackedScene).instantiate() as Node3D
	node.name = node_name
	node.position = pos
	node.rotation.y = yaw
	parent.add_child(node, true)
	return node


## 벽 위 한 점(바닥 x, z)·높이 y 에 붙는 묶음 노드. 로컬 +Z = 방 안쪽, 로컬 z = 0 이 벽면이다.
static func _wall_mount(parent: Node3D, at: Vector2, inward: Vector2, y: float, node_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	root.position = Vector3(at.x, y, at.y)
	root.rotation.y = _yaw(inward)
	parent.add_child(root, true)
	return root


## 앞이 있는 RG Poly 소품의 "얼굴 돌림각": 이만큼 더 돌리면 얼굴이 로컬 +Z(벽 묶음에서는 방 안쪽)를 본다.
## [2026-11-17 사용자 지적 "창문 화분의 꽃들이 전부 밖의 풍경을 보고 있다"]
## 꽃(flowers_a~c)은 꽃송이가 모델 −Z 쪽으로 기울어 있다(4면 렌더로 확인). 그래서 창턱 꽃 상자에서는 꽃이 창 밖을 봤고,
## 벽 선반에서는 깊이(0.26m)가 판(0.2m)보다 길다고 90도 눕혀져 옆을 봤다.
## 표에 없는 소품은 둥글거나(물약·병조림·허브 화분) 앞뒤 구분이 없다. 새 소품을 놓을 때 4면 렌더로 앞을 보고 여기에 적는다.
const FACE_YAW := {"flowers_a": PI, "flowers_b": PI, "flowers_c": PI}


## 소품 하나를 (로컬) 자리 at 에 세운다: 바닥면 = at.y, 모델 상자의 가로·깊이 가운데 = at.x·at.z (모델마다 원점이 달라서).
## yaw 0 = 얼굴이 로컬 +Z 를 본다(FACE_YAW 를 여기서 더한다).
static func _on_shelf(root: Node3D, key: String, at: Vector3, yaw := 0.0, size := 1.0) -> MeshInstance3D:
	var node := PubParts.asset(root, key, at, yaw + float(FACE_YAW.get(key, 0.0)), Vector3.ONE * size, key.to_pascal_case())
	if node == null:
		return null
	var box: AABB = node.mesh.get_aabb()
	var center := node.basis * (box.get_center() * Vector3(1, 0, 1))
	node.position -= Vector3(center.x, 0, center.z)
	return node


## 벽 선반: 월넛 판(깊이 0.2m) + 놋쇠 받침 둘 + 판 위 소품을 같은 간격으로. root = _wall_mount 묶음(판 윗면 = 묶음 높이).
static func _plank_shelf(root: Node3D, length: float, keys: Array) -> void:
	var depth := 0.2
	var front: float = WALL_LAYER_GAP + depth / 2.0
	MeshKit.rounded_box(root, "ShelfBoard", Vector3(length, 0.04, depth), Vector3(0, -0.02, front), _walnut(), 0.012)
	for u: float in [-length / 2.0 + 0.09, length / 2.0 - 0.09]:
		# 받침은 판 아래에 1cm 겹쳐 묻는다(면이 맞닿아 깜빡이지 않게) · 벽에서도 WALL_LAYER_GAP 띄운다.
		MeshKit.rounded_box(root, "ShelfBracket", Vector3(0.03, 0.15, 0.15), Vector3(u, -0.105, WALL_LAYER_GAP + 0.075), _brass(), 0.008)
	# 물건마다 돌림각과 (돌린 뒤) 폭·깊이를 먼저 잰다. 깊이가 판보다 긴 것(빵·밀대·오리)은 90도 돌려 벽을 따라 눕힌다.
	# 단 얼굴이 있는 것(FACE_YAW — 꽃)은 눕히지 않고 방을 보게 둔다(꽃송이가 판 앞으로 조금 나온다).
	# 살짝씩 다른 각도(±0.2)로 손으로 놓은 느낌을 낸다.
	var yaws: Array[float] = []
	var widths: Array[float] = []
	var depths: Array[float] = []
	var total := 0.0
	for i in range(keys.size()):
		var mesh: Mesh = RgPoly.mesh(str(keys[i]))
		var size: Vector3 = mesh.get_aabb().size if mesh != null else Vector3.ZERO
		var yaw: float = 0.2 if i % 2 == 0 else -0.2
		if size.z > depth + 0.04 and not FACE_YAW.has(str(keys[i])):
			yaw += PI / 2.0
		var turned := Basis(Vector3.UP, yaw)
		var extent := Vector2(absf(turned.x.x) * size.x + absf(turned.z.x) * size.z, absf(turned.x.z) * size.x + absf(turned.z.z) * size.z)
		yaws.append(yaw)
		widths.append(extent.x)
		depths.append(extent.y)
		total += extent.x
	# 남는 길이를 물건 사이·양 끝에 고르게 나눈다(물건이 서로 닿지 않는다). 모자라면 맞닿게 붙인다.
	var gap: float = maxf(0.0, (length - total) / (keys.size() + 1))
	var cursor: float = -length / 2.0 + gap
	for i in range(keys.size()):
		var u: float = cursor + widths[i] / 2.0
		cursor += widths[i] + gap
		# 깊은 물건은 뒤쪽이 벽을 뚫지 않게 앞으로 뺀다(뒷면 ≥ 벽에서 2 × WALL_LAYER_GAP).
		var z: float = maxf(front, WALL_LAYER_GAP * 2.0 + depths[i] / 2.0)
		_on_shelf(root, str(keys[i]), Vector3(u, 0, z), yaws[i])


# ─────────────────────────────── 조명 ───────────────────────────────

## 천장 펜던트: 물레로 깎은 놋쇠 돔 갓 + 안쪽 따뜻한 빛 + 천장 받침. pos = 갓 아래 테두리 가운데.
## 노드 이름은 모두 "Pendant" 로 시작한다(오락실이 이름으로 찾아 뺀다).
## prefix = 부품 노드 이름 앞머리. 오락실은 "Pendant" 로 시작하는 펜던트를 모두 빼고(LoungeWorld._trim_arcade) 카드 테이블 등("TablePendant")만 남긴다.
static func _pendant(parent: Node3D, pos: Vector3, ceiling: float, energy := 0.65, light_range := 6.5, shadow := false, size := 1.0, prefix := "Pendant") -> OmniLight3D:
	# 등 하나 = 묶음 노드 하나("Pendant_7" …). 부품 이름이 등마다 같으면 엔진이 둘째부터 "@MeshInstance3D@12" 같은 이름을 붙여
	# 오락실이 이름으로 펜던트를 못 찾았다(2026-11-08 발견 — 첫 등만 빠지고 나머지는 남았다). 묶음 이름은 부모 자식 수로 겹치지 않게 한다.
	var p := Node3D.new()
	p.name = "%s_%d" % [prefix, parent.get_child_count()]
	parent.add_child(p, true)
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
	p.add_child(light, true)
	return light


## 벽등(요청서 콘셉트의 놋쇠 반쪽 그릇 업라이트): 벽판 + 위로 열린 반원 그릇 + 안쪽 빛 + 실제 빛. facing = 벽에서 방 쪽.
static func _sconce(p: Node3D, pos: Vector3, facing: Vector3, energy := 0.35) -> void:
	var root := Node3D.new()
	root.name = "Sconce"
	root.position = pos
	root.rotation.y = atan2(facing.x, facing.z)
	p.add_child(root, true)
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
	root.add_child(light, true)
