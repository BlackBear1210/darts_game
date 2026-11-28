extends Node2D
## 벽 영사막과 머신 표시창. 숫자는 7세그먼트, 한글 이름은 메뉴와 같은 글꼴로 그린다.
const Style = preload("res://ui/lounge_style.gd")
const GLASS := Color("112622")
const LIT := Color("b5ff94")
const OFF := Color("233c32")
const IVORY := Color("faf1d6")
const BRASS := Color("e7c483")
const LINE := Color("527163")
const DIGITS := [0x3f, 0x06, 0x5b, 0x4f, 0x66, 0x6d, 0x7d, 0x07, 0x7f, 0x6f]
static var _bar := PackedVector2Array([Vector2(-0.19, 0), Vector2(-0.14, -0.045), Vector2(0.14, -0.045),
	Vector2(0.19, 0), Vector2(0.14, 0.045), Vector2(-0.14, 0.045)])
const CENTERS := [Vector2(0.25,0.06), Vector2(0.47,0.28), Vector2(0.47,0.72), Vector2(0.25,0.94),
	Vector2(0.03,0.72), Vector2(0.03,0.28), Vector2(0.25,0.50)]
var rows: Array[Dictionary] = []
var status := ""
var _wall := false
var _surface: SubViewport


func mount(parent: Node3D, at: Vector3, dimensions: Vector2, wall: bool) -> void:
	_wall = wall
	_surface = SubViewport.new()
	_surface.name = "DisplayTexture"
	_surface.size = Vector2i(432, 624) if wall else Vector2i(768, 128)
	_surface.disable_3d = true
	_surface.render_target_update_mode = SubViewport.UPDATE_ONCE
	parent.add_child(_surface)
	_surface.add_child(self)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = _surface.get_texture()
	var screen := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = dimensions
	screen.name = "DisplayGlass"
	screen.mesh = quad
	screen.material_override = material
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	screen.position = at
	parent.add_child(screen)


func present(next: Array[Dictionary], caption: String = "") -> void:
	if rows == next and status == caption:
		return
	rows = next
	status = caption
	queue_redraw()
	_surface.render_target_update_mode = SubViewport.UPDATE_ONCE


static func score_text(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else String.num(value, 1)


func _draw() -> void:
	if not _surface: return
	draw_rect(Rect2(Vector2.ZERO, Vector2(_surface.size)), GLASS)
	if _wall:
		_wall_face()
	else:
		_machine_face()


func _wall_face() -> void:
	_text("경기 점수", Vector2(20, 55), 45, IVORY)
	_text("SCORE", Vector2(285, 52), 28, BRASS)
	draw_rect(Rect2(18, 69, 396, 3), LINE)
	if rows.is_empty():
		_text("경기 대기", Vector2(20, 170), 42, IVORY)
		return
	var step := minf(169.0, 530.0 / rows.size())
	for i in rows.size():
		var row := rows[i]
		var top := 82.0 + i * step
		var color: Color = row.color
		draw_rect(Rect2(17, top + 7, 8, step - 16), color)
		_text(row.label, Vector2(42, top + 43), 39, IVORY, 365)
		_text(row.tag, Vector2(42, top + 99), 32, BRASS)
		_number(row.score, Vector2(405, top + 55), 62, 275)
		draw_rect(Rect2(35, top + step - 2, 370, 2), LINE)


func _machine_face() -> void:
	var playing := not rows.is_empty()
	var row: Dictionary = rows[0] if playing else {}
	var light: Color = row.get("color", BRASS)
	if not status.is_empty():
		draw_rect(Rect2(0, 0, 419, 128), BRASS)
		_text(status, Vector2(18, 49), 44, GLASS)
		_text(row.label, Vector2(19, 109), 53, GLASS, 390)
	else:
		draw_rect(Rect2(0, 0, 10, 128), light)
		_text("투척자" if playing else "DARTY", Vector2(25, 41), 31, BRASS)
		_text(row.get("label", "경기 대기"), Vector2(24, 108), 57, IVORY, 376)
	draw_rect(Rect2(423, 13, 3, 102), LINE)
	_number(row.get("score", "–"), Vector2(737, 19), 88, 281)


func _text(value: String, baseline: Vector2, pixels: int, tint: Color, limit: float = -1) -> void:
	draw_string(Style.font("body"), baseline, value, HORIZONTAL_ALIGNMENT_LEFT, limit, pixels, tint)


## 소수점은 좁은 한 칸, 음수 부호는 가운데 가로 막대 하나를 쓴다.
func _number(value: String, right: Vector2, height: float, max_width: float) -> void:
	var units := 0.0
	for ch in value: units += 0.21 if ch == "." else 0.67
	var scale_px := minf(height, max_width / maxf(units, 0.21))
	var pos := right + Vector2(-units * scale_px, (height - scale_px) * 0.5)
	for ch in value:
		if ch == ".":
			draw_circle(pos + Vector2(0.07, 0.93) * scale_px, 0.063 * scale_px, LIT, true, -1, true)
			pos.x += 0.21 * scale_px
			continue
		var mask: int = DIGITS[int(ch)] if ch.is_valid_int() else 0x40
		for i in 7:
			var angle := PI / 2 if i in [1,2,4,5] else 0.0
			draw_set_transform(pos + CENTERS[i] * scale_px, angle, Vector2.ONE * scale_px)
			draw_colored_polygon(_bar, LIT if (mask & (1 << i)) != 0 else OFF)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		pos.x += 0.67 * scale_px
