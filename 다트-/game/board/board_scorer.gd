class_name BoardScorer
extends RefCounted
## 과녁 점수 계산(순수 함수). 입력은 과녁 중심 기준 정규화 좌표(반지름 1 = 더블 링 바깥). 아트 쇼케이스도 이 함수를 쓴다.

const BOUNDARY_EPSILON: float = 0.0000001


## ring_scale = 링 확장 카드 배율(BoardLayout.ring_scale). 1 이면 원래 판 경계 그대로다.
static func region_at(point: Vector2, ring_scale: float = 1.0) -> int:
	if not point.is_finite(): return -1
	var radius: float = point.length()
	if radius > 1.0 + BOUNDARY_EPSILON: return -1
	if radius <= BoardLayout.INNER_BULL + BOUNDARY_EPSILON: return 80
	if radius <= BoardLayout.OUTER_BULL + BOUNDARY_EPSILON: return 81
	var edges: Vector3 = BoardLayout.ring_edges(ring_scale)
	var ring: int = 0
	if radius >= edges.z - BOUNDARY_EPSILON: ring = 3
	elif radius >= edges.x - BOUNDARY_EPSILON and radius <= edges.y + BOUNDARY_EPSILON: ring = 1
	elif radius > edges.y: ring = 2
	return BoardLayout.sector_at(point) * 4 + ring


static func score(point: Vector2, layout: BoardLayout) -> int:
	return layout.region_score(region_at(point, layout.ring_scale))
