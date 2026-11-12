class_name BoardScorer
extends RefCounted
## 과녁 점수 계산(순수 함수). 입력은 과녁 중심 기준 정규화 좌표(반지름 1 = 더블 링 바깥). 아트 쇼케이스도 이 함수를 쓴다.

const BOUNDARY_EPSILON: float = 0.0000001


static func region_at(point: Vector2) -> int:
	if not point.is_finite(): return -1
	var radius: float = point.length()
	if radius > 1.0 + BOUNDARY_EPSILON: return -1
	if radius <= BoardLayout.INNER_BULL + BOUNDARY_EPSILON: return 80
	if radius <= BoardLayout.OUTER_BULL + BOUNDARY_EPSILON: return 81
	var ring: int = 0
	if radius >= BoardLayout.DOUBLE_INNER - BOUNDARY_EPSILON: ring = 3
	elif radius >= BoardLayout.TRIPLE_INNER - BOUNDARY_EPSILON and radius <= BoardLayout.TRIPLE_OUTER + BOUNDARY_EPSILON: ring = 1
	elif radius > BoardLayout.TRIPLE_OUTER: ring = 2
	return BoardLayout.sector_at(point) * 4 + ring


static func score(point: Vector2, layout: BoardLayout) -> int:
	return layout.region_score(region_at(point))
