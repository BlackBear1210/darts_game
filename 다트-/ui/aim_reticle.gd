extends Control
## 과녁을 가리지 않도록 끝까지 가운데를 비운다. 반경은 HUD 논리 픽셀 단위다.
const Preferences = preload("res://ui/player_preferences.gd")
const OPEN_RADIUS := 20.0
const CROSS_MIN := 5.5
const RING_MIN := 8.0
const ARM := 8.0
const INK := Color("211c19")
var _charge := 0.0
var _shape := 0
var _color := Color.WHITE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	refresh(0.0)


func refresh(charge: float) -> void:
	var next := clampf(charge, 0.0, 1.0)
	if next == _charge and _shape == Preferences.reticle_shape and _color == Preferences.reticle_color:
		return
	_charge = next
	_shape = Preferences.reticle_shape
	_color = Preferences.reticle_color
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := lerpf(OPEN_RADIUS, RING_MIN if _shape == 1 else CROSS_MIN, _charge)
	for width: float in [4.5, 2.3]:
		var tint := INK if width > 3.0 else _color
		if _shape == 1:
			draw_arc(center, radius, 0, TAU, 64, tint, width, true)
		else:
			for direction: Vector2 in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
				draw_line(center + direction * radius, center + direction * (radius + ARM), tint, width, true)
