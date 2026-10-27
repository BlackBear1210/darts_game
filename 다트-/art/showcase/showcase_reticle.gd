extends Control
## 쇼케이스 투척 시점의 조준점(원 + 점 + 십자 눈금). 이미지 없이 그린다. 위치는 showcase_hud.set_reticle 이 옮긴다.


func _draw() -> void:
	draw_arc(Vector2.ZERO, 10, 0, TAU, 32, Color(0.95, 0.85, 0.58, 0.9), 1.2, true)
	draw_circle(Vector2.ZERO, 2, Color("f9ecc7"))
	for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(direction * 14, direction * 19, Color("f9ecc7"), 1.2, true)
