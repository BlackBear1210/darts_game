class_name BoardView
extends Node3D

var layout := BoardLayout.new()
var _face: MeshInstance3D
var _numbers: Node3D
var _shown_numbers: Array[int] = []


func _ready() -> void:
	_face = MeshInstance3D.new()
	_face.position.z = 0.001
	add_child(_face)
	_numbers = Node3D.new()
	add_child(_numbers)
	show_layout(layout)


func show_layout(data: BoardLayout) -> void:
	layout = data
	if _face == null: return
	if _shown_numbers == layout.numbers: return
	_shown_numbers = layout.numbers.duplicate()
	for child in _numbers.get_children():
		_numbers.remove_child(child)
		child.queue_free()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[float] = [BoardLayout.OUTER_BULL, BoardLayout.TRIPLE_INNER,
		BoardLayout.TRIPLE_OUTER, BoardLayout.DOUBLE_INNER, 1.0]
	for sector in range(20):
		for band in range(4):
			var special := band == 1 or band == 3
			var color := Color("bc514b") if sector % 2 == 0 else Color("428e71")
			if not special: color = Color("e7d7b0") if sector % 2 == 0 else Color("282e36")
			_add_band(surface, sector, rings[band], rings[band + 1], color)
		var number := Label3D.new()
		var angle := sector * TAU / 20.0
		number.position = Vector3(sin(angle), cos(angle), 0) * BoardLayout.RADIUS * 1.10
		number.position.z = 0.004
		number.text = str(layout.numbers[sector])
		number.font_size = 28
		number.pixel_size = 0.0011
		number.outline_size = 3
		_numbers.add_child(number)
	for sector in range(20):
		_add_band(surface, sector, 0.0, BoardLayout.OUTER_BULL, Color("428e71"))
		_add_band(surface, sector, 0.0, BoardLayout.INNER_BULL, Color("bc514b"), 0.001)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface.set_material(material)
	_face.mesh = surface.commit()


func _add_band(surface: SurfaceTool, sector: int, inner: float, outer: float, color: Color, depth: float = 0.0) -> void:
	var start := (sector - 0.5) * TAU / 20.0
	for step in range(4):
		var a := start + step * TAU / 80.0
		var b := start + (step + 1) * TAU / 80.0
		var corners: Array[Vector3] = [
			Vector3(sin(a) * inner, cos(a) * inner, depth),
			Vector3(sin(a) * outer, cos(a) * outer, depth),
			Vector3(sin(b) * outer, cos(b) * outer, depth),
			Vector3(sin(b) * inner, cos(b) * inner, depth),
		]
		for index in [0, 1, 2, 0, 2, 3]:
			surface.set_color(color)
			surface.set_normal(Vector3.BACK)
			surface.add_vertex(corners[index] * BoardLayout.RADIUS)
