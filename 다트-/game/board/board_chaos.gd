extends RefCounted

## 아수라장 다트 머신(2026-11-07 디자인 요청서 5장)의 움직임과 판정을 한 곳에서 계산한다.
## 화면(BoardView 회전·조각 · DartMachine 셔터)과 방장 점수(MatchCards.landing_points)가 같은 함수를 쓴다
## → "보이는 과녁 모양 = 점수 판정"이 어긋나지 않는다. 노드·입력·네트워크에 의존하지 않는 순수 계산이다.
##
## [입력은 "효과가 걸린 지 몇 초 지났나"(age)뿐]
## 컴퓨터마다 시계가 달라도 방장이 보낸 age 에서 이어 세면 같은 각도·같은 벌어짐을 재생한다(프레임마다 RPC 를 보내지 않는다).
## age < 0 = 그 효과가 꺼져 있음.
##
## [좌표] 과녁 앞면 정규화 좌표: 반지름 1 = 더블 링 바깥, +X 오른쪽, +Y 위(BoardScorer 와 같다).
## 회전은 과녁 평면 안에서(법선 Z축 기준) 돈다. 분리는 20섹터를 연속 4섹터씩 5조각(72°)으로 묶어 바깥으로 벌린다.
## 숫자는 자기 조각과 함께 움직이고(그림도 같이 붙어 있다), 가운데 불의 각 섹터도 가로·세로 경계에 맞춰 움직인다.
##
## [판정 순서] 셔터(머신에 고정, 회전 안 함) → 회전 되돌리기 → 어느 조각인지 찾아 벌어진 만큼 되돌리기 → 원래 판으로 채점.
## 벌어진 틈·뒤판에 꽂히면 0점(INF 반환).

## 회전: 최고 속도(라디안/초)와 그 속도까지 서서히 올라가는 시간(초). 0.9 rad/s ≈ 52°/s → 약 7초에 한 바퀴.
## 3발 동안 숫자가 눈에 따라갈 수 있는 빠르기로 시작값을 잡았다(시연값 — 직접 던져 보고 조정).
const SPIN_SPEED: float = 0.9
const SPIN_RAMP: float = 0.6
## 분리: 조각 수와 최대 벌어짐(정규화). 요청서 출발값 0.28m ÷ F5 득점 반지름 0.75m(0.30 × 배율 2.5).
const GROUP_COUNT: int = 5
const SECTORS_PER_GROUP: int = 4
const SPLIT_MAX: float = 0.28 / 0.75
## 처음 다 벌어지기까지(초), 그 뒤 좁혀졌다 벌어지는 주기(초)와 가장 좁혀졌을 때 비율.
## 계속 벌어져만 있으면 가운데 불만 노리면 되므로 숨 쉬듯 움직여 "타이밍"을 노리게 한다.
const SPLIT_OPEN: float = 0.8
const SPLIT_PERIOD: float = 2.6
const SPLIT_LOW: float = 0.35
## 축별 분리 거리와 이동 주기.
const HALF_SPLIT_MAX: float = 0.18
const HALF_SPLIT_OPEN: float = 1.5
## 한 칸은 18도. 칸 양옆의 철사 경계까지 반 칸 움직여 정렬한다.
const SEAM_ANGLE := PI / 20.0
const INDEX_SECONDS := 0.34
const ZOOM_SECONDS := 0.70
const INSERT_SECONDS := 0.38
const MOVE_AMPLITUDE: float = 0.25
const MOVE_PERIOD: float = 3.0
const LARGE_RADIUS: float = 0.06
const AREA_SAMPLES: int = 4096
static var _area_points := PackedVector2Array()

## 득점 반지름 단위. 숫자(두 자리 글자 포함)와 모든 이동량의 합이 기계 개구부를 넘지 않는다.
const WINDOW_RADIUS := 2.16
const PRINT_RADIUS := 1.38
const SHUTTER_LEAVES := 12
const SHUTTER_CLOSE: float = 0.72
## 완전히 펼친 가림막의 앞면(m). 전개 중 각 날개의 착탄 깊이는 shutter_depth에서 계산한다.
## 다트 머신 그림(art/dart_machine/dart_machine.gd)의 날개 자리도 이 값을 쓴다.
const SHUTTER_FRONT: float = 0.15
## 가동 보조판의 앞면. 득점판보다 뒤쪽이므로 정상 타일의 점수를 가리지 않는다.
const INFILL_FRONT := -0.097


## 효과가 걸린 시간들로 지금 과녁 모양을 만든다.
## 반환: {angle: 회전(라디안, + = 앞에서 볼 때 반시계), split: 벌어짐(정규화), shutter: 왼쪽 셔터 닫힘 0~1, cover: 판정상 가림 여부}
static func pose(spin_age: float, spin_dir: float, split_age: float, cover_age: float,
		vertical_age: float = -1, horizontal_age: float = -1, move_age: float = -1,
		move_dir: Vector2 = Vector2.RIGHT, cover_side: int = -1, vertical_sign: int = 1, horizontal_sign: int = 1) -> Dictionary:
	var movement: Vector2 = move_dir * MOVE_AMPLITUDE * sin(TAU * maxf(0, move_age) / MOVE_PERIOD) if move_age >= 0 else Vector2.ZERO
	var v_angle := SEAM_ANGLE * signi(vertical_sign)
	var h_angle := SEAM_ANGLE * signi(horizontal_sign)
	var v_index := smoothstep(0, INDEX_SECONDS, vertical_age)
	var h_index := smoothstep(0, INDEX_SECONDS, horizontal_age)
	var index := (v_angle * v_index + h_angle * h_index) / maxf(1.0, v_index + h_index)
	return {"angle": spin_angle(spin_age, spin_dir) - index,
		"v_axis": Vector2.RIGHT.rotated(v_angle), "h_axis": Vector2.UP.rotated(h_angle), "split": split_amount(split_age),
		"shutter": shutter_amount(cover_age), "cover": cover_age >= 0.0, "cover_side": cover_side, "cover_age": cover_age,
		"vertical": half_split_amount(vertical_age - INDEX_SECONDS), "horizontal": half_split_amount(horizontal_age - INDEX_SECONDS), "move": movement}


static func half_split_amount(age: float) -> float:
	if age < 0: return 0.0
	if age < HALF_SPLIT_OPEN: return HALF_SPLIT_MAX * smoothstep(0, HALF_SPLIT_OPEN, age)
	return HALF_SPLIT_MAX * lerpf(SPLIT_LOW, 1.0, 0.5 + 0.5 * cos(TAU * (age - HALF_SPLIT_OPEN) / SPLIT_PERIOD))



## 호스트·손님은 같은 스냅샷을 같은 시각만큼 전진시킨다. 활성 카드의 변환을 합친 뒤 기구의 가동 범위 안으로 맞춘다.
static func from_ages(ages: Dictionary, elapsed: float = 0.0) -> Dictionary:
	var age := func(kind: String) -> float:
		return float(ages[kind]) + elapsed if ages.has(kind) else -1.0
	var shape := pose(age.call("spin"), float(ages.get("dir", 1)), age.call("split"), age.call("cover"),
		age.call("vertical"), age.call("horizontal"), age.call("move"), ages.get("move_dir", Vector2.RIGHT), int(ages.get("cover_side", -1)),
		int(ages.get("vertical_sign", 1)), int(ages.get("horizontal_sign", 1)))
	var target := float(ages.get("scale", 1.0))
	# 과거 스냅샷에 크기 카드의 시각이 없으면 이미 펼쳐진 상태로 복원한다.
	var zoom_age: float = age.call("board_zoom") if ages.has("board_zoom") else ZOOM_SECONDS + INSERT_SECONDS
	var zoom := lerpf(1.0, target, smoothstep(0, ZOOM_SECONDS, zoom_age))
	shape["insert"] = smoothstep(ZOOM_SECONDS, ZOOM_SECONDS + INSERT_SECONDS, zoom_age) * clampf((target - 1.0) / 0.35, 0, 1)
	return fit_window(shape, zoom)


static func fit_window(shape: Dictionary, zoom: float) -> Dictionary:
	var size := clampf(zoom, 0.1, WINDOW_RADIUS / PRINT_RADIUS)
	# 바깥 더블 링은 지정 배율에 닿고, 그 안쪽에서 20개 타일이 서로 떨어진다.
	var petal := 0.092 * clampf((size - 1.0) / 0.35, 0, 1)
	size /= 1.0 + petal
	shape["petal"] = petal
	shape["scale"] = size
	var travel := split_travel(shape)
	var motion := travel * size + Vector2(shape.move).length()
	if motion > 0:
		var factor := clampf((WINDOW_RADIUS - PRINT_RADIUS * size) / motion, 0, 1)
		for key: String in ["split", "vertical", "horizontal", "move", "petal"]:
			shape[key] *= factor
	return shape


## 아무 효과도 없는 모양.
static func rest() -> Dictionary:
	return pose(-1.0, 1.0, -1.0, -1.0)


## 회전각. 속도를 SPIN_RAMP 동안 0 → SPIN_SPEED 로 올린 것의 적분이라 시작할 때 덜컥 튀지 않는다.
static func spin_angle(age: float, direction: float) -> float:
	if age <= 0.0:
		return 0.0
	var turned: float = SPIN_SPEED * age * age / (2.0 * SPIN_RAMP) if age < SPIN_RAMP else SPIN_SPEED * (age - SPIN_RAMP / 2.0)
	return turned * signf(direction if direction != 0.0 else 1.0)


## 조각이 바깥으로 벌어진 거리(정규화).
static func split_amount(age: float) -> float:
	if age <= 0.0:
		return 0.0
	if age < SPLIT_OPEN:
		return SPLIT_MAX * smoothstep(0.0, SPLIT_OPEN, age)
	var wave: float = 0.5 + 0.5 * cos(TAU * (age - SPLIT_OPEN) / SPLIT_PERIOD)
	return SPLIT_MAX * lerpf(SPLIT_LOW, 1.0, wave)


static func shutter_amount(age: float) -> float:
	return 0.0 if age < 0.0 else smoothstep(0.0, SHUTTER_CLOSE, age)


## 섹터 번호(BoardLayout.sector_at, 0 = 12시, 시계 방향) → 조각 번호.
static func group_of(sector: int) -> int:
	return posmod(sector, 20) / SECTORS_PER_GROUP


## 조각이 벌어지는 방향(조각 가운데 각도). 섹터 i 의 가운데는 12시에서 시계 방향 i × 18°.
static func sector_direction(sector: int) -> Vector2:
	var a := TAU * sector / 20.0
	return Vector2(sin(a), cos(a))


static func group_direction(group: int) -> Vector2:
	var angle: float = (group * SECTORS_PER_GROUP + (SECTORS_PER_GROUP - 1) / 2.0) * TAU / 20.0
	return Vector2(sin(angle), cos(angle))


## 과녁 평면에서 다트가 꽂힌 자리 → 원래(움직이기 전) 판 위의 자리. 셔터·틈·뒤판이면 Vector2.INF(0점).
## 득점판 밖(반지름 1 너머)도 INF 다 — BoardScorer 가 어차피 0점으로 본다.
static func covered(point: Vector2, shape: Dictionary) -> bool:
	if not bool(shape.get("cover", false)): return false
	var side_x := point.x * int(shape.get("cover_side", -1))
	var spread := shutter_spread(float(shape.get("shutter", 1.0)))
	var radius := shutter_radius(shape)
	if spread < 0.00001 or side_x <= 0.0: return false
	var unfolded_x := (side_x - radius * (1.0 - spread)) / spread
	return unfolded_x >= 0.0 and Vector2(unfolded_x, point.y).length_squared() <= radius * radius


## 접힌 강판의 앞뒤 깊이(m). 가림 판정과 같은 경첩 각도에서 착탄 위치를 복원한다.
static func shutter_depth(point: Vector2, shape: Dictionary, unit: float) -> float:
	var spread := shutter_spread(float(shape.get("shutter", 1.0)))
	var radius := shutter_radius(shape)
	if spread < 0.00001: return SHUTTER_FRONT
	var x := absf(point.x) / radius
	var leaf := clampf((x - (1.0 - spread)) / spread, 0.0, 1.0) * SHUTTER_LEAVES
	var pleat := 1.0 - absf(fposmod(leaf, 2.0) - 1.0)
	return SHUTTER_FRONT - pleat * sqrt(maxf(0, 1.0 - spread * spread)) * radius * unit / SHUTTER_LEAVES


static func shutter_radius(shape: Dictionary) -> float:
	var center: Vector2 = shape.get("move", Vector2.ZERO)
	return minf(infill_radius(shape) + center.length(), WINDOW_RADIUS)


## 수납문이 충분히 열린 후 차례대로 펼쳐진다. 펼침과 접힘은 같은 경로를 사용한다.
static func shutter_spread(close: float) -> float:
	return smoothstep(0.24, 1.0, close)


static func split_travel(shape: Dictionary) -> float:
	var v: Vector2 = shape.get("v_axis", Vector2.RIGHT) * float(shape.get("vertical", 0))
	var h: Vector2 = shape.get("h_axis", Vector2.UP) * float(shape.get("horizontal", 0))
	return float(shape.get("petal", 0)) + float(shape.get("split", 0)) + maxf((v+h).length(), (v-h).length())


static func infill_radius(shape: Dictionary) -> float:
	return (PRINT_RADIUS + split_travel(shape)) * float(shape.get("scale", 1.0))


static func on_infill(point: Vector2, shape: Dictionary) -> bool:
	var center: Vector2 = shape.get("move", Vector2.ZERO)
	return point.distance_to(center) <= infill_radius(shape)


## 원래 위치에 따른 조각 이동량. 그림과 역변환 판정이 함께 사용한다.
static func offset_at(original: Vector2, shape: Dictionary) -> Vector2:
	var v: Vector2 = shape.get("v_axis", Vector2.RIGHT)
	var h: Vector2 = shape.get("h_axis", Vector2.UP)
	var result := v * float(shape.get("vertical", 0)) * (1.0 if original.dot(v) >= 0 else -1.0)
	result += h * float(shape.get("horizontal", 0)) * (1.0 if original.dot(h) >= 0 else -1.0)
	if original.length() > BoardLayout.OUTER_BULL:
		var sector := BoardLayout.sector_at(original)
		result += group_direction(group_of(sector)) * float(shape.get("split", 0))
		result += sector_direction(sector) * float(shape.get("petal", 0.0))
	return result


## 과녁 크기 변화 카드: shape.scale(기본 1). 그림은 Spin 노드 배율, 판정은 회전을 되돌린 뒤 배율로 나눈다.
static func locate(point: Vector2, shape: Dictionary, outer: float = 1.0) -> Vector2:
	if not point.is_finite() or covered(point, shape): return Vector2.INF
	var local: Vector2 = (point - Vector2(shape.get("move", Vector2.ZERO))).rotated(-float(shape.get("angle", 0))) / maxf(float(shape.get("scale", 1.0)), 0.1)
	var vertical: float = float(shape.get("vertical", 0))
	var horizontal: float = float(shape.get("horizontal", 0))
	var v: Vector2 = shape.get("v_axis", Vector2.RIGHT)
	var h: Vector2 = shape.get("h_axis", Vector2.UP)
	for x: float in [-1.0, 1.0] if vertical > 0 else [0.0]:
		for y: float in [-1.0, 1.0] if horizontal > 0 else [0.0]:
			var shifted: Vector2 = local - v * x * vertical - h * y * horizontal
			var original: Vector2 = _locate_pizza(shifted, float(shape.get("split", 0)), outer, float(shape.get("petal", 0)))
			if not original.is_finite(): continue
			if vertical > 0 and (original.dot(v) >= 0) != (x > 0): continue
			if horizontal > 0 and (original.dot(h) >= 0) != (y > 0): continue
			return original
	return Vector2.INF


static func _locate_pizza(point: Vector2, split: float, outer: float, petal: float) -> Vector2:
	if point.length() <= BoardLayout.OUTER_BULL + BoardScorer.BOUNDARY_EPSILON: return point
	# 확대 시 득점 칸은 원래 좌표로 되돌려 채점한다. 드러난 삽입판은 0점이다.
	if petal > 0.0:
		for group in range(GROUP_COUNT):
			var candidate := point - group_direction(group) * split
			var sector := BoardLayout.sector_at(candidate)
			if split > 0 and group_of(sector) != group: continue
			var original := candidate - sector_direction(sector) * petal
			if original.length() > BoardLayout.OUTER_BULL and original.length() <= outer + BoardScorer.BOUNDARY_EPSILON and BoardLayout.sector_at(original) == sector:
				return original
		return Vector2.INF
	if split <= 0: return point if point.length() <= outer + BoardScorer.BOUNDARY_EPSILON else Vector2.INF
	for group in range(GROUP_COUNT):
		var original: Vector2 = point - group_direction(group) * split
		if original.length() <= BoardLayout.OUTER_BULL or original.length() > outer + BoardScorer.BOUNDARY_EPSILON: continue
		if group_of(BoardLayout.sector_at(original)) == group: return original
	return Vector2.INF



## 지금 모양에서 과녁 평면 위 다트가 "판에 꽂힐 수 있는" 가장 먼 반지름(벌어진 조각 끝까지).
static func reach(shape: Dictionary) -> float:
	return (1.0 + split_travel(shape)) * maxf(float(shape.get("scale", 1.0)), 1.0) + Vector2(shape.get("move", Vector2.ZERO)).length()


## 꽂힌 자리의 점수(움직인 모양 반영). 숫자 섞기는 layout 이 이미 갖고 있다.
static func score(point: Vector2, shape: Dictionary, layout: BoardLayout) -> int:
	var original: Vector2 = locate(point, shape)
	return 0 if not original.is_finite() else BoardScorer.score(original, layout)


## 큰 다트 원 안의 고해상도 면적 점유율. 동률은 방장의 난수로 고른다.
static func area_result(point: Vector2, shape: Dictionary, layout: BoardLayout, random: RandomNumberGenerator) -> Dictionary:
	if _area_points.is_empty():
		for index in range(AREA_SAMPLES):
			_area_points.append(Vector2.from_angle(index * 2.399963229728653) * sqrt((index + 0.5) / AREA_SAMPLES))
	var counts: Dictionary = {}
	for sample in _area_points:
		var region: int = BoardScorer.region_at(locate(point + sample * LARGE_RADIUS, shape), layout.ring_scale)
		counts[region] = int(counts.get(region, 0)) + 1
	var best: int = 0
	var choices: Array[int] = []
	for region: int in counts:
		if counts[region] > best:
			best = counts[region]
			choices.clear()
		if counts[region] == best: choices.append(region)
	var winner: int = choices[random.randi_range(0, choices.size() - 1)]
	return {"points": layout.region_score(winner), "region": winner}
