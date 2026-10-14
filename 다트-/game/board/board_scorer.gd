class_name BoardScorer
extends RefCounted


static func score(point: Vector2, layout: BoardLayout) -> int:
	var radius := point.length()
	if radius > 1.0:
		return 0
	if radius <= BoardLayout.INNER_BULL:
		return 50
	if radius <= BoardLayout.OUTER_BULL:
		return 25
	var number := layout.numbers[BoardLayout.sector_at(point)]
	if radius >= BoardLayout.DOUBLE_INNER:
		return number * 2
	if radius >= BoardLayout.TRIPLE_INNER and radius <= BoardLayout.TRIPLE_OUTER:
		return number * 3
	return number
