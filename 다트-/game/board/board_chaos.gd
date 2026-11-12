extends RefCounted
const Catalog = preload("res://game/card_round/rules/card_catalog.gd")
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
## 숫자는 자기 조각과 함께 움직이고(그림도 같이 붙어 있다), 가운데 불은 제자리다.
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
## 셔터(가림판 카드): 닫히는 데 걸리는 시간(초). 판정은 카드를 쓴 순간부터 가린 쪽 0점이다(기존 cover 규칙 그대로).
const HALF_SPLIT_MAX: float = 0.18
const HALF_SPLIT_OPEN: float = 1.5
const MOVE_AMPLITUDE: float = 0.25
const MOVE_PERIOD: float = 3.0
const LARGE_RADIUS: float = 0.06
const AREA_SAMPLES: int = 4096
static var _area_points := PackedVector2Array()

const SHUTTER_CLOSE: float = 0.45
## 셔터 날개 앞면이 과녁 면보다 앞으로 나온 거리(m). 가린 쪽에 꽂히는 다트는 과녁이 아니라 이 면에 박힌다(보이기만).
## 다트 머신 그림(art/dart_machine/dart_machine.gd)의 날개 자리도 이 값을 쓴다.
const SHUTTER_FRONT: float = 0.15


## 효과가 걸린 시간들로 지금 과녁 모양을 만든다.
## 반환: {angle: 회전(라디안, + = 앞에서 볼 때 반시계), split: 벌어짐(정규화), shutter: 왼쪽 셔터 닫힘 0~1, cover: 판정상 가림 여부}
static func pose(spin_age: float, spin_dir: float, split_age: float, cover_age: float,
		vertical_age: float = -1, horizontal_age: float = -1, move_age: float = -1,
		move_dir: Vector2 = Vector2.RIGHT, cover_side: int = -1) -> Dictionary:
	var movement: Vector2 = move_dir * MOVE_AMPLITUDE * sin(TAU * maxf(0, move_age) / MOVE_PERIOD) if move_age >= 0 else Vector2.ZERO
	return {"angle": spin_angle(spin_age, spin_dir), "split": split_amount(split_age),
		"shutter": shutter_amount(cover_age), "cover": cover_age >= 0.0, "cover_side": cover_side, "cover_age": cover_age,
		"vertical": half_split_amount(vertical_age), "horizontal": half_split_amount(horizontal_age), "move": movement}


static func half_split_amount(age: float) -> float:
	if age < 0: return 0.0
	if age < HALF_SPLIT_OPEN: return HALF_SPLIT_MAX * smoothstep(0, HALF_SPLIT_OPEN, age)
	return HALF_SPLIT_MAX * lerpf(SPLIT_LOW, 1.0, 0.5 + 0.5 * cos(TAU * (age - HALF_SPLIT_OPEN) / SPLIT_PERIOD))


## 같은 강화식을 방장 판정·원격 그림·F6가 함께 쓴다. 셔터는 닫는 면적 대신 교대 속도를 강화한다.
static func boost(shape: Dictionary, levels: Dictionary) -> Dictionary:
	var shown: Dictionary = shape.duplicate()
	for pair: Array in [["spin", "angle"], ["split", "split"], ["vertical", "vertical"], ["horizontal", "horizontal"], ["move", "move"]]:
		shown[pair[1]] *= Catalog.synergy_factor(int(levels.get(pair[0], 1)))
	var cover_players: int = int(levels.get("cover", 1))
	if bool(shown.cover) and cover_players >= 2:
		var interval: float = 1.2 if cover_players == 2 else 0.6
		if int(maxf(0, float(shown.cover_age)) / interval) % 2 == 1: shown.cover_side = -int(shown.cover_side)
	return shown



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
static func group_direction(group: int) -> Vector2:
	var angle: float = (group * SECTORS_PER_GROUP + (SECTORS_PER_GROUP - 1) / 2.0) * TAU / 20.0
	return Vector2(sin(angle), cos(angle))


## 과녁 평면에서 다트가 꽂힌 자리 → 원래(움직이기 전) 판 위의 자리. 셔터·틈·뒤판이면 Vector2.INF(0점).
## 득점판 밖(반지름 1 너머)도 INF 다 — BoardScorer 가 어차피 0점으로 본다.
static func covered(point: Vector2, shape: Dictionary) -> bool:
	return bool(shape.get("cover", false)) and point.x * int(shape.get("cover_side", -1)) > 0


## 원래 위치에 따른 조각 이동량. 그림과 역변환 판정이 함께 사용한다.
static func offset_at(original: Vector2, shape: Dictionary) -> Vector2:
	var result := Vector2(1.0 if original.x >= 0 else -1.0, 1.0 if original.y >= 0 else -1.0)
	result *= Vector2(float(shape.get("vertical", 0)), float(shape.get("horizontal", 0)))
	if original.length() > BoardLayout.OUTER_BULL:
		result += group_direction(group_of(BoardLayout.sector_at(original))) * float(shape.get("split", 0))
	return result


static func locate(point: Vector2, shape: Dictionary) -> Vector2:
	if not point.is_finite() or covered(point, shape): return Vector2.INF
	var local: Vector2 = (point - Vector2(shape.get("move", Vector2.ZERO))).rotated(-float(shape.get("angle", 0)))
	var vertical: float = float(shape.get("vertical", 0))
	var horizontal: float = float(shape.get("horizontal", 0))
	for x: float in [-1.0, 1.0] if vertical > 0 else [0.0]:
		for y: float in [-1.0, 1.0] if horizontal > 0 else [0.0]:
			var shifted: Vector2 = local - Vector2(x * vertical, y * horizontal)
			var original: Vector2 = _locate_pizza(shifted, float(shape.get("split", 0)))
			if not original.is_finite(): continue
			if vertical > 0 and (original.x >= 0) != (x > 0): continue
			if horizontal > 0 and (original.y >= 0) != (y > 0): continue
			return original
	return Vector2.INF


static func _locate_pizza(point: Vector2, split: float) -> Vector2:
	if point.length() <= BoardLayout.OUTER_BULL + BoardScorer.BOUNDARY_EPSILON: return point
	if split <= 0: return point
	for group in range(GROUP_COUNT):
		var original: Vector2 = point - group_direction(group) * split
		if original.length() <= BoardLayout.OUTER_BULL or original.length() > 1.0 + BoardScorer.BOUNDARY_EPSILON: continue
		if group_of(BoardLayout.sector_at(original)) == group: return original
	return Vector2.INF



## 지금 모양에서 과녁 평면 위 다트가 "판에 꽂힐 수 있는" 가장 먼 반지름(벌어진 조각 끝까지).
static func reach(shape: Dictionary) -> float:
	return 1.0 + float(shape.get("split", 0.0)) + float(shape.get("vertical", 0)) + float(shape.get("horizontal", 0)) + Vector2(shape.get("move", Vector2.ZERO)).length()


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
		var region: int = BoardScorer.region_at(locate(point + sample * LARGE_RADIUS, shape))
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
