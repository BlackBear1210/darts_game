extends RefCounted
## 경기 끝 벌칙(2026-11-23 사용자 요청): 꼴찌를 **점수 과녁판에 묶고** 판을 돌린다. 나머지가 거기에 다트를 던진다.
## 이 파일은 "묶인 몸이 판 위에서 어디를 차지하는가" 하나만 소유한다 — 방장의 명중 판정과 각 화면의 그림이 같은 값을 쓴다.
##
## [좌표] 정규화 과녁 좌표. 1.0 = 점수 원의 반지름(BoardLayout.RADIUS × TableView.BOARD_SCALE = 0.75 m).
## 판정은 BoardChaos.locate 로 **회전을 되돌린 뒤**의 자리로 한다 → 몸은 판과 함께 돌지만 치수는 고정이다.
## 팔은 판정하지 않는다(F6 벌칙 원판과 같은 규칙 — 팔까지 넣으면 거의 다 맞는다).

## 발끝 · 몸통(다리 포함) 윗면 · 몸통 반폭 · 머리 중심 높이 · 머리 반지름.
const FEET_Y: float = -1.10
const BODY_TOP_Y: float = 0.45
const BODY_HALF_X: float = 0.32
const HEAD_Y: float = 0.80
const HEAD_RADIUS: float = 0.30
## 선수 캐릭터 키(m). 위 치수에 맞춰 모델을 줄일 때 쓴다.
const CHARACTER_HEIGHT: float = 1.85


## 판 위 한 점(회전을 되돌린 정규화 좌표)이 묶인 몸에 맞았는지.
static func hit(print_point: Vector2) -> bool:
	if not print_point.is_finite():
		return false
	if print_point.distance_to(Vector2(0.0, HEAD_Y)) <= HEAD_RADIUS:
		return true
	return absf(print_point.x) <= BODY_HALF_X and print_point.y >= FEET_Y and print_point.y <= BODY_TOP_Y


## 몸이 판에서 차지하는 세로 길이(정규화) = 발끝에서 머리 꼭대기까지.
static func span() -> float:
	return HEAD_Y + HEAD_RADIUS - FEET_Y


## 과녁판 Spin 노드 안에 캐릭터를 놓을 때의 크기. Spin 의 지역 단위는 BoardLayout.RADIUS 가 1.0 이다.
static func model_scale() -> float:
	return span() / CHARACTER_HEIGHT * BoardLayout.RADIUS


## 같은 좌표계에서 캐릭터 발밑을 둘 자리. z 는 판 앞면보다 살짝 앞(다트가 몸 앞에 꽂히게).
static func model_position() -> Vector3:
	return Vector3(0.0, FEET_Y * BoardLayout.RADIUS, 0.03)
