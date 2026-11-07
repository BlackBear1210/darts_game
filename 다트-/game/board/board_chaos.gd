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
const SHUTTER_CLOSE: float = 0.45
## 셔터 날개 앞면이 과녁 면보다 앞으로 나온 거리(m). 가린 쪽에 꽂히는 다트는 과녁이 아니라 이 면에 박힌다(보이기만).
## 다트 머신 그림(art/dart_machine/dart_machine.gd)의 날개 자리도 이 값을 쓴다.
const SHUTTER_FRONT: float = 0.15


## 효과가 걸린 시간들로 지금 과녁 모양을 만든다.
## 반환: {angle: 회전(라디안, + = 앞에서 볼 때 반시계), split: 벌어짐(정규화), shutter: 왼쪽 셔터 닫힘 0~1, cover: 판정상 가림 여부}
static func pose(spin_age: float, spin_dir: float, split_age: float, cover_age: float) -> Dictionary:
	return {"angle": spin_angle(spin_age, spin_dir), "split": split_amount(split_age),
		"shutter": shutter_amount(cover_age), "cover": cover_age >= 0.0}


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
static func locate(point: Vector2, shape: Dictionary) -> Vector2:
	if not point.is_finite():
		return Vector2.INF
	# 1) 셔터는 머신 몸체에 붙어 있다(판과 같이 돌지 않는다): 기존 가림판 규칙 = 왼쪽 절반 0점.
	if bool(shape.get("cover", false)) and point.x < 0.0:
		return Vector2.INF
	# 2) 회전 되돌리기. 판 위의 점 q 가 화면에서는 q.rotated(angle) 에 보인다.
	var local: Vector2 = point.rotated(-float(shape.get("angle", 0.0)))
	var split: float = float(shape.get("split", 0.0))
	if split <= 0.0:
		return local
	# 3) 가운데 불은 제자리. 조각은 각자 방향으로 split 만큼 밀려 있다.
	if local.length() <= BoardLayout.OUTER_BULL + BoardScorer.BOUNDARY_EPSILON:
		return local
	for group in range(GROUP_COUNT):
		var original: Vector2 = local - group_direction(group) * split
		var radius: float = original.length()
		if radius <= BoardLayout.OUTER_BULL or radius > 1.0 + BoardScorer.BOUNDARY_EPSILON:
			continue
		if group_of(BoardLayout.sector_at(original)) == group:
			return original
	return Vector2.INF


## 지금 모양에서 과녁 평면 위 다트가 "판에 꽂힐 수 있는" 가장 먼 반지름(벌어진 조각 끝까지).
static func reach(shape: Dictionary) -> float:
	return 1.0 + float(shape.get("split", 0.0))


## 꽂힌 자리의 점수(움직인 모양 반영). 숫자 섞기는 layout 이 이미 갖고 있다.
static func score(point: Vector2, shape: Dictionary, layout: BoardLayout) -> int:
	var original: Vector2 = locate(point, shape)
	return 0 if not original.is_finite() else BoardScorer.score(original, layout)
