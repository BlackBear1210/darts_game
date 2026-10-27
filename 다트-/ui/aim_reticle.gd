extends Control
## 실제 경기(F5) 화면 중앙 조준점. 이미지 없이 그린다.


func _draw() -> void:
	var center := Vector2(12, 12)
	draw_arc(center, 6.0, 0, TAU, 24, Color("f9dc7a"), 1.5, true)
	draw_line(center + Vector2(-11, 0), center + Vector2(-7, 0), Color.WHITE)
	draw_line(center + Vector2(7, 0), center + Vector2(11, 0), Color.WHITE)
	draw_line(center + Vector2(0, -11), center + Vector2(0, -7), Color.WHITE)
	draw_line(center + Vector2(0, 7), center + Vector2(0, 11), Color.WHITE)
