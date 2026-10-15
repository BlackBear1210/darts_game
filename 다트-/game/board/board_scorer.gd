class_name BoardScorer
extends RefCounted

const BOUNDARY_EPSILON: float = 0.0000001


static func score(point: Vector2, layout: BoardLayout) -> int:
	if not point.is_finite():
		return 0
	# Vector2는 float32이므로 경계 좌표의 반올림을 흡수한다(정규화 반지름 1e-7).
	var radius := point.length()
	if radius > 1.0 + BOUNDARY_EPSILON:
		return 0
	if radius <= BoardLayout.INNER_BULL + BOUNDARY_EPSILON:
		return 50
	if radius <= BoardLayout.OUTER_BULL + BOUNDARY_EPSILON:
		return 25
	var number := layout.numbers[BoardLayout.sector_at(point)]
	if radius >= BoardLayout.DOUBLE_INNER - BOUNDARY_EPSILON:
		return number * 2
	if radius >= BoardLayout.TRIPLE_INNER - BOUNDARY_EPSILON and radius <= BoardLayout.TRIPLE_OUTER + BOUNDARY_EPSILON:
		return number * 3
	return number
