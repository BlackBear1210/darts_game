extends RefCounted
## 아트(실제 크기, 미터)의 다트판과 팀 판정 코드(game/board/BoardLayout, 반지름 1 정규화)를 잇는 규격.
## 점수 계산은 여기서 하지 않는다. 링 비율·숫자 순서는 BoardLayout 이 유일한 기준이고,
## 아트는 그 비율에 실제 반지름을 곱해서 그린다. 그래서 그림과 판정이 어긋날 수 없다.
##
## 좌표 기준: 다트판 중심 원점, x 오른쪽 +, y 위 +, 앞면 법선 +Z.

## 더블 링 바깥 반지름(표준 규격 170mm). 판정 좌표 반지름 1 에 해당한다.
const SCORING_RADIUS: float = 0.170
## 숫자 띠·검은 뒤판까지 포함한 판 전체 반지름.
const BACKING_RADIUS: float = 0.2255
## 바닥에서 불(정중앙)까지 높이 — 표준 1.73m.
const CENTER_HEIGHT: float = 1.73
## 다트판 앞면에서 투척선(Oche)까지 거리 — 표준 2.37m.
const THROW_DISTANCE: float = 2.37
## 펍(art/pub/pub.tscn) 안에서 다트판 중심의 월드 좌표. 생성기와 쇼케이스 카메라가 같이 쓴다.
## 옮기려면 이 값만 바꾸고 pub_builder.gd 를 다시 실행한다.
const PUB_BOARD_CENTER := Vector3(0, CENTER_HEIGHT, -4.45)


## BoardLayout 의 비율(예: TRIPLE_INNER = 0.582)을 실제 반지름(m)으로 바꾼다.
static func ring_radius(ratio: float) -> float:
	return ratio * SCORING_RADIUS


## 다트판 중심 기준 실제 좌표(m)를 BoardScorer 가 받는 정규화 좌표로 바꾼다.
static func to_board_point(offset_m: Vector2) -> Vector2:
	return offset_m / SCORING_RADIUS
