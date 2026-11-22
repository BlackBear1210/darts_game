extends Node3D
## 월넛 측판, 발판, 고정 마키와 매립형 차례·점수 표시창.
const Kit = preload("res://art/mesh_kit.gd")
const HALF_WIDTH := 1.20
const TOP := 4.56
const BACK := -1.12
const KICK_HEIGHT := 1.22
const KICK_FRONT := 1.12
const TOE_HEIGHT := 0.15
const UPPER_FRONT := -0.70

static var _grain: ImageTexture
var turn_text: Label3D
var score_text: Label3D
var _travel_index: MeshInstance3D

static func walnut() -> StandardMaterial3D:
	var wood := Kit.material("MachineWalnut", "e8ded1")
	if wood.albedo_texture == null:
		wood.albedo_texture = _veneer()
		wood.roughness = 0.49
		wood.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return wood


static func _veneer() -> ImageTexture:
	if _grain != null:
		return _grain
	var image := Image.create_empty(256, 384, false, Image.FORMAT_RGB8)
	var growth := FastNoiseLite.new()
	growth.seed = 1207
	growth.frequency = 0.04
	var dark := Color("332720")
	var light := Color("68503f")
	for y in range(384):
		for x in range(256):
			var twist := growth.get_noise_2d(x * 0.21, y * 0.11)
			var wave := sin(y * 0.014 + x * 0.008) * 1.9 + twist * 10.0
			var rings := pow(0.5 + 0.5 * sin(x * 0.62 + wave), 5.0)
			var pores := growth.get_noise_2d(x * 7.5, y * 0.35) * 0.12
			var stripes := growth.get_noise_2d(x * 1.4, y * 0.13) * 0.33
			image.set_pixel(x, y, dark.lerp(light, clampf(0.58 + stripes - rings * 0.15 + pores, 0.0, 1.0)))
	image.generate_mipmaps()
	_grain = ImageTexture.create_from_image(image)
	return _grain


static func lower_profile() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(TOE_HEIGHT, BACK), Vector2(TOE_HEIGHT, KICK_FRONT - 0.14),
		Vector2(0.26, KICK_FRONT), Vector2(0.81, KICK_FRONT),
		Vector2(1.18, 0.94), Vector2(KICK_HEIGHT, 0.84), Vector2(1.26, 0.25), Vector2(1.28, -0.21), Vector2(1.28, BACK)
	])


func build(wood: Material, trim: Material, frame: Material, metal: Material, lamp: Material) -> void:
	var outline := lower_profile()
	outline.resize(outline.size() - 1)
	outline.append_array(PackedVector2Array([
		Vector2(1.45, -0.54), Vector2(1.76, UPPER_FRONT), Vector2(4.17, UPPER_FRONT),
		Vector2(4.24, -0.49), Vector2(4.42, -0.49), Vector2(TOP, -0.65),
		Vector2(TOP, -1.00), Vector2(4.45, BACK)
	]))
	_profile("WalnutCabinet", outline, wood)
	Kit.rounded_box(self, "RecessedBackboard", Vector3(2.18, 2.46, 0.032), Vector3(0, 2.98, UPPER_FRONT + 0.018), trim, 0.013)
	for side: float in [-1.0, 1.0]:
		Kit.rounded_box(self, "BackboardInlay", Vector3(0.014, 2.39, 0.021), Vector3(side * 1.106, 2.97, UPPER_FRONT + 0.017), metal, 0.005)
		var outer_x := side * (HALF_WIDTH + 0.006)
		for i in range(7):
			Kit.box(self, "SideLouvre", Vector3(0.014, 0.035, 0.47 - i * 0.024), Vector3(outer_x, 0.47 + i * 0.069, -0.53), trim)
	var depth := KICK_FRONT - BACK
	Kit.rounded_box(self, "Plinth", Vector3(2.34, TOE_HEIGHT + 0.025, depth - 0.10), Vector3(0, 0.085, (BACK + KICK_FRONT) * 0.5), frame, 0.042)
	Kit.rounded_box(self, "ServiceRebate", Vector3(1.97, 0.45, 0.016), Vector3(0, 0.51, KICK_FRONT + 0.004), trim, 0.017)
	Kit.box(self, "WalnutAccessDoor", Vector3(1.94, 0.421, 0.019), Vector3(0, 0.51, KICK_FRONT + 0.011), wood)
	Kit.rounded_box(self, "FlushPull", Vector3(0.21, 0.043, 0.022), Vector3(0, 0.638, KICK_FRONT + 0.027), metal, 0.010)
	for side: float in [-1.0, 1.0]:
		for i in range(4):
			Kit.box(self, "IntakeSlot", Vector3(0.28, 0.012, 0.012), Vector3(side * 0.64, 0.43 + 0.035 * i, KICK_FRONT + 0.025), trim)
	Kit.rounded_box(self, "DeckLip", Vector3(2.28, 0.034, 0.046), Vector3(0, 1.202, 0.906), metal, 0.012)
	# 고정 눈금과 캐리지 포인터는 단독 이동·회전을 읽는 기준선이다.
	Kit.rounded_box(self, "TravelScale", Vector3(0.84, 0.069, 0.025), Vector3(0, 4.115, -0.662), frame, 0.008)
	for i in range(-4, 5):
		var tick_height := 0.027 if i % 2 == 0 else 0.015
		Kit.box(self, "IndexTick", Vector3(0.009, tick_height, 0.008), Vector3(i * 0.084, 4.125, -0.645), metal)
	_travel_index = Kit.box(self, "TravelPointer", Vector3(0.029, 0.048, 0.017), Vector3(0, 4.092, -0.637), metal)
	var tray := Node3D.new()
	tray.name = "ReturnTray"
	tray.position = Vector3(0, 1.249, 0.56)
	tray.rotation.x = 0.068
	add_child(tray)
	Kit.rounded_box(tray, "RecessedLip", Vector3(1.73, 0.026, 0.42), Vector3.ZERO, frame, 0.012)
	Kit.rounded_box(tray, "RubberBed", Vector3(1.67, 0.012, 0.36), Vector3(0, 0.014, 0), trim, 0.005)
	for i in range(-3, 4):
		Kit.box(tray, "GripRib", Vector3(1.59, 0.008, 0.009), Vector3(0, 0.022, i * 0.044), frame)
	_build_readout(trim, frame, metal)
	Kit.rounded_box(self, "MarqueeFrame", Vector3(2.16, 0.168, 0.085), Vector3(0, 4.343, -0.471), trim, 0.035)
	var brand := Kit.label(self, "Marquee", "DARTY", Vector3(0, 4.344, -0.420), 64, Color("ffe6ad"), 0.00135)
	brand.shaded = false
	Kit.rounded_box(self, "TaskLight", Vector3(1.15, 0.035, 0.056), Vector3(0, 4.239, -0.446), lamp, 0.016)


func set_travel(offset_x: float) -> void:
	_travel_index.position.x = offset_x


func _build_readout(trim: Material, frame: Material, metal: Material) -> void:
	var console := Node3D.new()
	console.name = "Readout"
	console.position = Vector3(0, 0.998, 1.037)
	console.rotation.x = -0.452
	add_child(console)
	Kit.rounded_box(console, "Bezel", Vector3(1.92, 0.353, 0.065), Vector3.ZERO, metal, 0.030)
	Kit.rounded_box(console, "Seal", Vector3(1.85, 0.306, 0.041), Vector3(0, 0, 0.033), frame, 0.020)
	Kit.rounded_box(console, "SmokedGlass", Vector3(1.77, 0.257, 0.021), Vector3(0, 0, 0.052), trim, 0.010)
	turn_text = Kit.label(console, "StatusText", "DARTY", Vector3(-0.39, 0.014, 0.071), 52, Color("fff2cf"), 0.00146)
	score_text = Kit.label(console, "ScoreText", "—", Vector3(0.40, 0.014, 0.071), 64, Color("ffcd82"), 0.00188)
	turn_text.shaded = false
	score_text.shaded = false


## 양 측판과 전후면에 길이 방향 나뭇결을 입힌다.
func _profile(title: String, path: PackedVector2Array, wood: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris := Geometry2D.triangulate_polygon(path)
	for side: float in [-1.0, 1.0]:
		for i in range(0, tris.size(), 3):
			var a := path[tris[i]]
			var b := path[tris[i + 1]]
			var c := path[tris[i + 2]]
			var outward := (c - a).cross(b - a) * side > 0.0
			for j: int in [0, 1, 2] if outward else [2, 1, 0]:
				var p := path[tris[i + j]]
				surface.set_uv(Vector2((p.y - BACK) / (KICK_FRONT - BACK), 1.0 - p.x / TOP))
				surface.set_normal(Vector3.RIGHT * side)
				surface.add_vertex(Vector3(side * HALF_WIDTH, p.x, p.y))
	Kit.mesh_node(self, title, surface.commit(), Vector3.ZERO, wood)
	var edge := SurfaceTool.new()
	edge.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(path.size()):
		var a := path[i]
		var b := path[(i + 1) % path.size()]
		var n := Vector3(0, a.y - b.y, b.x - a.x).normalized()
		var p := Vector3(-HALF_WIDTH, a.x, a.y)
		var q := Vector3(HALF_WIDTH, a.x, a.y)
		var r := Vector3(HALF_WIDTH, b.x, b.y)
		var s := Vector3(-HALF_WIDTH, b.x, b.y)
		for v: Vector3 in [q, p, s, q, s, r]:
			edge.set_normal(n)
			edge.set_uv(Vector2((v.x + HALF_WIDTH) / (HALF_WIDTH * 2.0), 1.0 - v.y / TOP))
			edge.add_vertex(v)
	Kit.mesh_node(self, "CabinetFrame", edge.commit(), Vector3.ZERO, wood)
