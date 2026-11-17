extends "res://art/pub/room/room_kit.gd"
## 과녁 벽 양옆 꾸밈(2026-11-17). 디자인 담당 소유. 장면 안 묶음 = PubOnly/BoardSideDecor.
## 사용자 지적 "다트판 양 옆이 너무 횅한 것 같다": 머신 판넬(x ±2.7) 바로 바깥 칸(안 칸, x ±3.64)이 통째로 비어 있었고
## 끝 칸(x ±5.51)도 꽃 선반 위가 비어 있었다. 다트 펍답게 채운다.
##
##   왼쪽 안 칸  = 네온 과녁 간판(위) + 하우스 다트 꽂이(아래)
##   오른쪽 안 칸 = 벽시계(위) + 트로피 선반(아래)
##   끝 칸 둘    = 꽃 선반 위에 펍 거울 간판(금 글씨)
##   벽 위쪽     = 삼각 깃발 줄(벽 모서리 → 칸 기둥 → 머신 아치 옆, 고리에서 고리로 처진다)
##
## [자리 규칙]
##   - 칸 가운데·기둥 x 는 벽 칸 나누기(room_kit.gd _bays)와 같은 계산으로 구한다: 판넬 끝 ~ 벽 끝을 4등분.
##     (판넬 폭 FEATURE_HALF 나 홀 폭이 바뀌어도 칸을 따라간다.)
##   - 바닥 앞의 연습 과녁(높이 ~1.5m)·럼주통을 가리지 않게 모두 1.8m 위에 단다.
##   - 벽에서 0.12m 안쪽까지만 나온다(빗나간 다트가 꽂히는 벽면 근처). 충돌은 없다(보이기만).
##   - 펍 전용(PubOnly) — 네온 오락실은 그 벽에 제 간판이 있다.

## 안 칸 위 간판·시계 높이(가운데) · 아래 꽂이·선반 높이(윗면) · 끝 칸 거울 높이.
## 간판·시계·거울은 처음 만든 치수(네온 0.86m · 시계 지름 0.6m · 거울 0.84m)에 아래 배율을 곱한다 —
## 투척선(벽에서 8.7m)에서 봐도 작아 보이지 않게(2026-11-17 화면 확인 뒤 키움).
const SIGN_Y: float = 2.8
const NEON_SCALE: float = 1.15
const CLOCK_SCALE: float = 1.2
const MIRROR_SCALE: float = 1.18
const RACK_Y: float = 1.95
const TROPHY_Y: float = 1.85
const MIRROR_Y: float = 2.72
## 깃발 줄: 고리 높이(칸 기둥 머리 바로 아래) · 가운데가 처지는 깊이 · 벽에서 떨어진 거리 · 깃발 간격.
const BUNTING_Y: float = 3.92
const BUNTING_SAG: float = 0.26
const BUNTING_OUT: float = 0.1
const PENNANT_STEP: float = 0.34
## 깃발 색(과녁 빨강 · 크림 · 과녁 초록 · 금) — 차례로 돌린다.
const PENNANT_COLORS: Array[String] = ["e0453a", "f3ead2", "1f9d68", "ffc845"]
## 다트 꽂이의 다트 배율(실제 다트 16cm × 1.6 — 방 건너 투척선에서도 다트로 읽히게).
const RACK_DART_SCALE: float = 1.6


## 과녁 벽 양옆을 꾸민다. p = PubOnly 아래 "BoardSideDecor" 묶음.
static func build_board_sides(p: Node3D) -> void:
	var f := _faces()
	var step: float = (f.hall_x1 - FEATURE_HALF) / 4.0
	var inner: float = FEATURE_HALF + step
	var post: float = FEATURE_HALF + step * 2.0
	var outer: float = FEATURE_HALF + step * 3.0
	var inward := Vector2(0, 1)
	_neon_target(_scaled(_wall_mount(p, Vector2(-inner, f.board_z), inward, SIGN_Y, "NeonTarget"), NEON_SCALE))
	_dart_rack(_wall_mount(p, Vector2(-inner, f.board_z), inward, RACK_Y, "DartRack"))
	_wall_clock(_scaled(_wall_mount(p, Vector2(inner, f.board_z), inward, SIGN_Y, "WallClock"), CLOCK_SCALE))
	_trophy_shelf(_wall_mount(p, Vector2(inner, f.board_z), inward, TROPHY_Y, "TrophyShelf"))
	# 이름이 같은 형제 노드는 엔진이 "@Node3D@468" 처럼 바꿔 버린다 → 왼쪽·오른쪽 이름을 따로 준다.
	_pub_mirror(_scaled(_wall_mount(p, Vector2(-outer, f.board_z), inward, MIRROR_Y, "PubMirrorLeft"), MIRROR_SCALE), "DARTY ALE", 48, "since 2026 · 밤 9시 리그")
	_pub_mirror(_scaled(_wall_mount(p, Vector2(outer, f.board_z), inward, MIRROR_Y, "PubMirrorRight"), MIRROR_SCALE), "180!", 72, "ONE HUNDRED AND EIGHTY")
	# 깃발 줄: 양쪽마다 [벽 모서리 → 칸 기둥 → 머신 아치 옆] 두 구간. 아치 굵은 틀(판넬 끝 + 0.13m) 바깥에 고리를 단다.
	var spans: Array = []
	for side: float in [-1.0, 1.0]:
		var hooks: Array[float] = [side * (f.hall_x1 - 0.07), side * post, side * (FEATURE_HALF + 0.22)]
		spans.append([hooks[0], hooks[1]])
		spans.append([hooks[1], hooks[2]])
	_bunting(p, f.board_z + BUNTING_OUT, spans)


## 벽 묶음 안에 같은 배율로 키운 그림 묶음("Art")을 만들어 돌려준다(벽 묶음 자리·방향은 그대로).
static func _scaled(mount: Node3D, size: float) -> Node3D:
	var art := Node3D.new()
	art.name = "Art"
	art.scale = Vector3.ONE * size
	mount.add_child(art, true)
	return art


# ─────────────────────────────── 왼쪽 안 칸 ───────────────────────────────

## 네온 과녁 간판: 검은 받침판 위에 빨강·초록 네온 고리(과녁 링) + 가운데로 날아드는 크림색 네온 다트 + 붉은 빛.
static func _neon_target(root: Node3D) -> void:
	var backer := MeshKit.rounded_box(root, "NeonBacker", Vector3(0.86, 0.86, 0.025), Vector3(0, 0, WALL_LAYER_GAP + 0.0125),
		MeshKit.material("NeonBacker", "17131b"), 0.08, 2)
	backer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		MeshKit.mesh_node(root, "NeonStandoff", RoundKit.sphere_mesh(0.016, 10), Vector3(corner.x * 0.36, corner.y * 0.36, WALL_LAYER_GAP + 0.03), _brass())
	var tube := RoundKit.circle_profile(0.011, 6)
	var ring_z: float = WALL_LAYER_GAP + 0.025 + 0.035
	var red := MeshKit.material("NeonRed", "ff4a5a", 0.0, 3.2)
	var green := MeshKit.material("NeonGreen", "4dffb0", 0.0, 2.6)
	var cream := MeshKit.material("NeonCream", "ffe7a3", 0.0, 2.6)
	for ring: Array in [[0.34, red], [0.24, green], [0.13, red], [0.045, green]]:
		var node := MeshKit.mesh_node(root, "NeonRing", RoundKit.ring_mesh("neon_ring", float(ring[0]), tube, 36), Vector3(0, 0, ring_z), ring[1])
		node.rotation.x = PI / 2.0
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 다트(왼쪽 위 → 가운데): 고리보다 3cm 앞에 둬서 고리와 겹치지 않는다. 촉 · 몸통(굵게) · 대 · 깃 테두리(V 두 개).
	var dart_z: float = ring_z + 0.03
	var lines: Array = [
		[Vector2(0.0, 0.0), Vector2(-0.06, 0.06), 0.006],
		[Vector2(-0.06, 0.06), Vector2(-0.2, 0.2), 0.016],
		[Vector2(-0.2, 0.2), Vector2(-0.36, 0.36), 0.009],
		[Vector2(-0.3, 0.3), Vector2(-0.47, 0.37), 0.008],
		[Vector2(-0.47, 0.37), Vector2(-0.36, 0.36), 0.008],
		[Vector2(-0.3, 0.3), Vector2(-0.37, 0.47), 0.008],
		[Vector2(-0.37, 0.47), Vector2(-0.36, 0.36), 0.008],
	]
	for line: Array in lines:
		var a: Vector2 = line[0]
		var b: Vector2 = line[1]
		var rod := RoundKit.rod(root, "NeonDart", Vector3(a.x, a.y, dart_z), Vector3(b.x, b.y, dart_z), float(line[2]), cream, -1.0, 6)
		rod.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var glow := OmniLight3D.new()
	glow.name = "NeonGlowLight"
	glow.position = Vector3(0, 0, 0.3)
	glow.light_color = Color("ff7a86")
	glow.light_energy = 0.35
	glow.omni_range = 1.8
	glow.shadow_enabled = false
	root.add_child(glow, true)


## 하우스 다트 꽂이: 벽 받침판 + 앞 나무 토막 + 토막에 꽂아 세운 다트 3벌(깃 색 빨강·초록·금) + "하우스 다트" 글씨.
## 다트 9개는 재질별로 한 메시로 합친다(촉·몸통·대·깃 색 셋 = 메시 6개).
static func _dart_rack(root: Node3D) -> void:
	MeshKit.rounded_box(root, "DartRackBack", Vector3(0.78, 0.26, 0.02), Vector3(0, 0.04, WALL_LAYER_GAP + 0.01), _walnut_dark(), 0.03, 2)
	var block_depth := 0.11
	var block_z: float = WALL_LAYER_GAP + 0.02 + block_depth / 2.0
	MeshKit.rounded_box(root, "DartRackBlock", Vector3(0.7, 0.07, block_depth), Vector3(0, -0.035, block_z), _walnut(), 0.015, 2)
	var plate_z: float = block_z + block_depth / 2.0
	MeshKit.rounded_box(root, "DartRackPlate", Vector3(0.24, 0.04, 0.006), Vector3(0, -0.035, plate_z + 0.003 + WALL_LAYER_GAP), _brass(), 0.004, 1)
	MeshKit.label(root, "DartRackText", "하우스 다트", Vector3(0, -0.035, plate_z + 0.006 + WALL_LAYER_GAP * 2.0), 22, Color("3b2a1d"), 0.0012)
	# 다트 한 개(원점 = 촉 끝, 위 = +Y): 촉 · 몸통 · 대 · 깃 4장(X 자).
	var tip := RoundKit.lathe_mesh(PackedVector2Array([Vector2(0, 0), Vector2(0.0035, 0.03), Vector2(0, 0.03)]), 8)
	var barrel := RoundKit.lathe_mesh(PackedVector2Array([Vector2(0, 0.03), Vector2(0.007, 0.03), Vector2(0.0095, 0.04),
		Vector2(0.0095, 0.07), Vector2(0.007, 0.08), Vector2(0, 0.08)]), 12)
	var shaft := RoundKit.lathe_mesh(PackedVector2Array([Vector2(0, 0.08), Vector2(0.0045, 0.08), Vector2(0.0045, 0.125), Vector2(0, 0.125)]), 8)
	var fin := RoundKit.panel_mesh("rack_dart_fin", PackedVector2Array([Vector2(0, 0.1), Vector2(0.028, 0.13), Vector2(0.026, 0.16), Vector2(0, 0.155)]), 0.0015)
	var parts := {"tip": [], "barrel": [], "shaft": [], 0: [], 1: [], 2: []}
	for group in range(3):
		for k in range(3):
			# 촉 0.025m 를 토막에 묻는다. 다트마다 살짝씩 기울이고 돌려 손으로 꽂은 느낌을 낸다.
			var u: float = (group - 1) * 0.22 + (k - 1) * 0.05
			var lean: float = 0.07 * (k - 1) + 0.03 * (group - 1)
			var basis := Basis(Vector3.BACK, -lean) * Basis(Vector3.UP, PI / 4.0 + 0.3 * k) * Basis.from_scale(Vector3.ONE * RACK_DART_SCALE)
			var at := Transform3D(basis, Vector3(u, -0.025, block_z))
			parts.tip.append([tip, at])
			parts.barrel.append([barrel, at])
			parts.shaft.append([shaft, at])
			for turn in range(4):
				parts[group].append([fin, at * Transform3D(Basis(Vector3.UP, turn * PI / 2.0), Vector3(0, 0, -0.00075))])
	MeshKit.mesh_node(root, "RackDartTips", RoundKit.merge("rack_dart_tips", parts.tip), Vector3.ZERO, MeshKit.material("DartSteel", "c9ccd2", 0.9))
	MeshKit.mesh_node(root, "RackDartBarrels", RoundKit.merge("rack_dart_barrels", parts.barrel), Vector3.ZERO, _brass())
	MeshKit.mesh_node(root, "RackDartShafts", RoundKit.merge("rack_dart_shafts", parts.shaft), Vector3.ZERO, _walnut_dark())
	var flight_colors: Array[String] = ["e0453a", "1f9d68", "ffc845"]
	for group in range(3):
		MeshKit.mesh_node(root, "RackDartFlights", RoundKit.merge("rack_dart_flights_%d" % group, parts[group]), Vector3.ZERO,
			RoundKit.clay("rack_flight_%s" % flight_colors[group], flight_colors[group], 0.7))


# ─────────────────────────────── 오른쪽 안 칸 ───────────────────────────────

## 벽시계: 월넛 뒤판 + 놋쇠 테 + 크림 문자판 + 눈금 12 + 시침·분침(10시 10분) · 빨간 초침 + 가운데 마개 + DARTY 글씨. 움직이지 않는다.
static func _wall_clock(root: Node3D) -> void:
	var radius := 0.3
	var back := MeshKit.mesh_node(root, "ClockBack", RoundKit.lathe_mesh(PackedVector2Array([Vector2(0, 0), Vector2(radius, 0),
		Vector2(radius, 0.03), Vector2(0, 0.03)]), 32), Vector3(0, 0, WALL_LAYER_GAP), _walnut_dark())
	back.rotation.x = PI / 2.0
	var face_z: float = WALL_LAYER_GAP + 0.03
	var face := MeshKit.mesh_node(root, "ClockFace", RoundKit.lathe_mesh(PackedVector2Array([Vector2(0, 0), Vector2(radius - 0.025, 0),
		Vector2(radius - 0.025, 0.004), Vector2(0, 0.004)]), 32), Vector3(0, 0, face_z), RoundKit.clay("clock_face", "f3ead2", 0.6))
	face.rotation.x = PI / 2.0
	var rim := MeshKit.mesh_node(root, "ClockRim", RoundKit.ring_mesh("clock_rim", radius - 0.012, RoundKit.rounded_rect_profile(Vector2(0.04, 0.06), 0.012, 1), 36),
		Vector3(0, 0, face_z + 0.008), _brass())
	rim.rotation.x = PI / 2.0
	var ink := RoundKit.clay("clock_ink", "1d1a1e", 0.5)
	var front: float = face_z + 0.004
	var ticks: Array = []
	for i in range(12):
		var big: bool = i % 3 == 0
		var size := Vector3(0.014 if big else 0.008, 0.05 if big else 0.03, 0.004)
		var angle: float = TAU * i / 12.0
		var spot := Vector3(sin(angle), cos(angle), 0.0) * (radius - 0.07)
		ticks.append([MeshKit.rounded_box_mesh(size, 0.002, 1), Transform3D(Basis(Vector3.BACK, -angle), spot + Vector3(0, 0, front + 0.002))])
	MeshKit.mesh_node(root, "ClockTicks", RoundKit.merge("clock_ticks", ticks), Vector3.ZERO, ink)
	# 바늘: 가운데 축에서 바깥으로 뻗는다(뒤로 2cm 꼬리). 시침 10시 · 분침 2시 · 초침 7시 쪽.
	for hand: Array in [["ClockHourHand", 10.0 / 12.0, 0.15, 0.018, 0.006, ink], ["ClockMinuteHand", 2.0 / 12.0, 0.22, 0.012, 0.012, ink],
			["ClockSecondHand", 7.0 / 12.0, 0.24, 0.004, 0.018, RoundKit.clay("clock_red", "c8343a", 0.5)]]:
		var angle: float = TAU * float(hand[1])
		var length: float = hand[2]
		var node := MeshKit.rounded_box(root, str(hand[0]), Vector3(float(hand[3]), length + 0.02, 0.004),
			Vector3(sin(angle), cos(angle), 0.0) * (length / 2.0 - 0.01) + Vector3(0, 0, front + float(hand[4])), hand[5], 0.002, 1)
		node.rotation.z = -angle
	MeshKit.mesh_node(root, "ClockCap", RoundKit.sphere_mesh(0.018, 12), Vector3(0, 0, front + 0.024), _brass())
	MeshKit.label(root, "ClockBrand", "DARTY", Vector3(0, -0.12, front + 0.003), 26, Color("6b4128"), 0.0016)


## 트로피 선반: 월넛 판 + 놋쇠 받침 + 금 트로피 셋(가운데가 크다) — 받침 나무 토막 · 앞 놋쇠 이름판.
static func _trophy_shelf(root: Node3D) -> void:
	_plank_shelf(root, 1.2, [])
	var gold := RoundKit.clay("TrophyGold", "e9b949", 0.28, 0.9)
	var cup := RoundKit.lathe_mesh(RoundKit.rounded_profile(PackedVector2Array([Vector2(0, 0), Vector2(0.036, 0), Vector2(0.036, 0.012),
		Vector2(0.014, 0.03), Vector2(0.011, 0.075), Vector2(0.03, 0.09), Vector2(0.058, 0.115), Vector2(0.07, 0.17), Vector2(0.075, 0.2),
		Vector2(0.066, 0.2), Vector2(0.061, 0.17), Vector2(0.05, 0.12), Vector2(0, 0.11)]), 0.005, 1), 20)
	var handle := RoundKit.ring_mesh("trophy_handle", 0.035, RoundKit.circle_profile(0.0065, 5), 14)
	var shelf_mid: float = WALL_LAYER_GAP + 0.1
	for spec: Array in [[-0.38, 1.0], [0.0, 1.35], [0.38, 1.0]]:
		var u: float = spec[0]
		var s: float = spec[1]
		var trophy := Node3D.new()
		trophy.name = "Trophy"
		trophy.position = Vector3(u, 0, shelf_mid)
		trophy.scale = Vector3.ONE * s
		root.add_child(trophy, true)
		MeshKit.rounded_box(trophy, "TrophyBase", Vector3(0.13, 0.07, 0.13), Vector3(0, 0.035, 0), _walnut_dark(), 0.01, 1)
		MeshKit.rounded_box(trophy, "TrophyPlate", Vector3(0.09, 0.025, 0.004), Vector3(0, 0.035, 0.065 + 0.002 + WALL_LAYER_GAP / s), _brass(), 0.002, 1)
		MeshKit.mesh_node(trophy, "TrophyCup", cup, Vector3(0, 0.07, 0), gold)
		for side: float in [-1.0, 1.0]:
			var ear := MeshKit.mesh_node(trophy, "TrophyHandle", handle, Vector3(side * 0.075, 0.07 + 0.15, 0), gold)
			ear.rotation.x = PI / 2.0


# ─────────────────────────────── 끝 칸 · 벽 위 ───────────────────────────────

## 펍 거울 간판: 월넛 틀 + 놋쇠 띠 + 연기 낀 거울 + 금 글씨 두 줄(제목 · 작은 글씨). title_size = 제목 글자 크기(거울 폭 0.7m 안에 들게).
static func _pub_mirror(root: Node3D, title: String, title_size: int, subtitle: String) -> void:
	MeshKit.rounded_box(root, "MirrorFrame", Vector3(0.84, 0.62, 0.04), Vector3(0, 0, WALL_LAYER_GAP + 0.02), _walnut(), 0.03, 2)
	MeshKit.rounded_box(root, "MirrorBead", Vector3(0.76, 0.54, 0.012), Vector3(0, 0, WALL_LAYER_GAP + 0.046), _brass(), 0.01, 1)
	var glass := StandardMaterial3D.new()
	glass.resource_name = "PubMirrorGlass"
	glass.albedo_color = Color("2c3a44")
	glass.metallic = 0.85
	glass.roughness = 0.28
	MeshKit.rounded_box(root, "MirrorGlass", Vector3(0.7, 0.48, 0.01), Vector3(0, 0, WALL_LAYER_GAP + 0.05), glass, 0.008, 1)
	var text_z: float = WALL_LAYER_GAP + 0.055 + WALL_LAYER_GAP
	var big := MeshKit.label(root, "MirrorTitle", title, Vector3(0, 0.05, text_z), title_size, Color("e8c36a"), 0.0024)
	big.outline_size = 10
	big.outline_modulate = Color("3b2414")
	var small := MeshKit.label(root, "MirrorSubtitle", subtitle, Vector3(0, -0.14, text_z), 22, Color("e8c36a"), 0.0016)
	small.outline_size = 6
	small.outline_modulate = Color("3b2414")


## 삼각 깃발 줄: spans = [[시작 x, 끝 x], ...](벽에서 z 만큼 떨어진 줄). 줄은 고리에서 고리로 포물선처럼 처지고,
## 깃발은 줄을 따라 PENNANT_STEP 간격으로 색을 돌려 매단다. 깃발은 색마다 한 메시, 줄·고리도 한 메시씩(메시 6개).
static func _bunting(p: Node3D, z: float, spans: Array) -> void:
	var root := Node3D.new()
	root.name = "Bunting"
	p.add_child(root, true)
	var rope_unit := RoundKit.lathe_mesh(PackedVector2Array([Vector2(0, 0), Vector2(0.008, 0), Vector2(0.008, 1.0), Vector2(0, 1.0)]), 6)
	var pennant := RoundKit.panel_mesh("bunting_pennant", PackedVector2Array([Vector2(-0.11, 0), Vector2(0, -0.26), Vector2(0.11, 0)]), 0.003)
	var hook := RoundKit.sphere_mesh(0.02, 10)
	var rope: Array = []
	var hooks: Array = []
	var flags: Array = [[], [], [], []]
	var count := 0
	for span: Array in spans:
		var x0: float = span[0]
		var x1: float = span[1]
		var point := func(t: float) -> Vector3:
			return Vector3(lerpf(x0, x1, t), BUNTING_Y - 4.0 * BUNTING_SAG * t * (1.0 - t), z)
		for x: float in [x0, x1]:
			hooks.append([hook, Transform3D(Basis.IDENTITY, Vector3(x, BUNTING_Y, z))])
		var pieces := 14
		for i in range(pieces):
			var a: Vector3 = point.call(float(i) / pieces)
			var b: Vector3 = point.call(float(i + 1) / pieces)
			var direction := (b - a).normalized()
			var basis := Basis(Quaternion(Vector3.UP, direction)) * Basis.from_scale(Vector3(1, a.distance_to(b), 1))
			rope.append([rope_unit, Transform3D(basis, a)])
		var flag_count: int = maxi(roundi(absf(x1 - x0) / PENNANT_STEP) - 1, 1)
		for i in range(flag_count):
			var t: float = float(i + 1) / (flag_count + 1)
			var at: Vector3 = point.call(t)
			var ahead: Vector3 = point.call(t + 0.01)
			var slope: float = atan2(ahead.y - at.y, ahead.x - at.x)
			flags[count % PENNANT_COLORS.size()].append([pennant, Transform3D(Basis(Vector3.BACK, slope), at + Vector3(0, -0.004, -0.0015))])
			count += 1
	var tag: String = "%.2f|%d" % [z, spans.size()]
	var rope_node := MeshKit.mesh_node(root, "BuntingRope", RoundKit.merge("bunting_rope|" + tag, rope), Vector3.ZERO, RoundKit.clay("bunting_rope", "d9c9a3", 0.9))
	rope_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	MeshKit.mesh_node(root, "BuntingHooks", RoundKit.merge("bunting_hooks|" + tag, hooks), Vector3.ZERO, _brass())
	for k in range(PENNANT_COLORS.size()):
		var color: String = PENNANT_COLORS[k]
		var node := MeshKit.mesh_node(root, "BuntingFlags", RoundKit.merge("bunting_flags_%d|%s" % [k, tag], flags[k]), Vector3.ZERO,
			RoundKit.clay("bunting_" + color, color, 0.85))
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
