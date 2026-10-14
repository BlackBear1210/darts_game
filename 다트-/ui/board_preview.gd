class_name BoardPreview
extends Control
## 3D 과녁과 같은 배치·링 데이터를 사용하는 공개 미리보기.

var layout := BoardLayout.new()
var _impact: Vector2
var _has_impact: bool = false


func show_layout(data: BoardLayout) -> void:
	layout = data
	queue_redraw()


func show_impact(hit: Dictionary) -> void:
	_has_impact = not hit.is_empty()
	if _has_impact: _impact = Vector2(hit.x, hit.y)
	queue_redraw()


func _draw() -> void:
	var radius := minf(size.x, size.y) * 0.40
	var center := size * 0.5
	draw_circle(center, radius * 1.18, Color("111925"))
	var rings: Array[float] = [BoardLayout.OUTER_BULL, BoardLayout.TRIPLE_INNER,
		BoardLayout.TRIPLE_OUTER, BoardLayout.DOUBLE_INNER, 1.0]
	for sector in range(20):
		for band in range(4):
			var color := Color("bc514b") if sector % 2 == 0 else Color("428e71")
			if band == 0 or band == 2: color = Color("e7d7b0") if sector % 2 == 0 else Color("282e36")
			var polygon := PackedVector2Array()
			for step in range(5):
				var angle := (sector - 0.5) * TAU / 20.0 + step * TAU / 80.0
				polygon.append(center + Vector2(sin(angle), -cos(angle)) * rings[band + 1] * radius)
			for step in range(4, -1, -1):
				var angle := (sector - 0.5) * TAU / 20.0 + step * TAU / 80.0
				polygon.append(center + Vector2(sin(angle), -cos(angle)) * rings[band] * radius)
			draw_colored_polygon(polygon, color)
		var angle := sector * TAU / 20.0
		var position := center + Vector2(sin(angle), -cos(angle)) * radius * 1.10
		var text := str(layout.numbers[sector])
		var font := ThemeDB.fallback_font
		var font_size := 12
		position.x -= font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * 0.5
		position.y += 4.0
		draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	draw_circle(center, radius * BoardLayout.OUTER_BULL, Color("428e71"))
	draw_circle(center, radius * BoardLayout.INNER_BULL, Color("bc514b"))
	if _has_impact:
		var point := center + Vector2(_impact.x, -_impact.y) * radius
		draw_circle(point, 5.0, Color("f9dc7a"))
		draw_circle(point, 2.0, Color("111925"))
