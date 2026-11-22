extends Node3D
## 월넛 마감 날개를 번갈아 접어 양쪽 수납문 안에 보관한다. 좌우 레일은 과녁의 확장 반경을 따른다.
const Kit = preload("res://art/mesh_kit.gd")
const Chaos = preload("res://game/board/board_chaos.gd")
const UNIT := BoardLayout.RADIUS * 2.5
const BAY := 1.055
const DOOR_WIDTH := 0.143
const HINGES := Chaos.SHUTTER_LEAVES
var _bays: Array[Node3D] = []
var _returns: Array[MeshInstance3D] = []
var _slides: Array[MeshInstance3D] = []
var _doors: Array[Node3D] = []
var _packs: Array[Node3D] = []
var _last_amount := -1.0
var _last_side := 0
var _last_radius := -1.0


func build(wood: Material, steel: Material, iron: Material, brass: Material) -> void:
	# 동일한 월넛 결을 두 가지 착색으로 공유한다. 경첩·끝단은 금속으로 남긴다.
	var stains: Array[Material] = []
	for color: String in ["80ac93", "ab806a"]:
		var veneer := wood.duplicate() as StandardMaterial3D
		veneer.albedo_color = Color(color)
		veneer.roughness = 0.48
		stains.append(veneer)
	for side: int in [-1, 1]:
		var bay := Node3D.new()
		bay.name = "LeftMagazine" if side < 0 else "RightMagazine"
		add_child(bay)
		_bays.append(bay)
		Kit.rounded_box(bay, "GuideHousing", Vector3(0.138, 2.04, 0.24), Vector3(side * 0.060, 0, -0.122), iron, 0.023)
		var shoe := Kit.box(self, "CrossSlide", Vector3(1.0, 0.11, 0.12), Vector3.ZERO, iron)
		_slides.append(shoe)
		_returns.append(Kit.box(self, "ReturnArm", Vector3(0.10, 0.102, 1.0), Vector3.ZERO, iron))
		for y: float in [-0.86, 0.86]:
			Kit.cylinder(bay, "PivotCollar", 0.034, 0.066, Vector3(side * DOOR_WIDTH, y, 0.002), brass, 16)
		var door := Node3D.new()
		door.name = "LeftHatch" if side < 0 else "RightHatch"
		bay.add_child(door)
		door.position = Vector3(side * DOOR_WIDTH, 0, 0.026)
		_doors.append(door)
		Kit.box(door, "FlushWalnutDoor", Vector3(DOOR_WIDTH, 2.017, 0.032), Vector3(-side * DOOR_WIDTH * 0.5, 0, 0), wood)
		Kit.box(door, "DoorLip", Vector3(0.012, 1.99, 0.021), Vector3(-side * DOOR_WIDTH, 0, 0.008), brass)
		var pack := Node3D.new()
		pack.name = "LeftConcertina" if side < 0 else "RightConcertina"
		add_child(pack)
		_packs.append(pack)
		for i in range(HINGES):
			var blade := Kit.mesh_node(pack, "Leaf%02d" % i, _leaf_mesh(i, side), Vector3.ZERO, stains[0 if side < 0 else 1])
			if i == 0:
				Kit.box(blade, "LeadingRail", Vector3(0.014, 1.98, 0.018), Vector3(side * 0.009, 0, 0.002), steel)
				for y: float in [-0.54, 0.54]:
					Kit.box(blade, "LatchShoe", Vector3(0.029, 0.074, 0.015), Vector3(side * 0.019, y, 0.006), brass)
	show_pose(Chaos.rest())


func show_pose(shape: Dictionary) -> void:
	var amount := float(shape.get("shutter", 0.0))
	var side := -1 if int(shape.get("cover_side", -1)) < 0 else 1
	var radius := Chaos.shutter_radius(shape) * UNIT
	if is_equal_approx(amount, _last_amount) and side == _last_side and is_equal_approx(radius, _last_radius):
		return
	_last_radius = radius
	_last_amount = amount
	_last_side = side
	for i in range(2):
		var sign_side := -1 if i == 0 else 1
		var close := amount if sign_side == side else 0.0
		var open := smoothstep(0.0, 0.24, close)
		var bay := _bays[i]
		bay.position = Vector3(sign_side * lerpf(maxf(BAY, radius - 0.09), radius, open), 0.0, lerpf(-0.57, Chaos.SHUTTER_FRONT - 0.015, open))
		bay.scale.y = lerpf(1.0, radius, open)
		var anchor_x := sign_side * 0.62
		var tip_x := bay.position.x + sign_side * 0.052
		_slides[i].position = Vector3((anchor_x + tip_x) * 0.5, 0.0, -0.655)
		_slides[i].scale.x = absf(tip_x - anchor_x) + 0.07
		var port_z := bay.position.z - 0.10
		_returns[i].position = Vector3(tip_x, 0, (-0.655 + port_z) * 0.5)
		_returns[i].scale.z = absf(port_z + 0.655) + 0.045
		_doors[i].rotation.y = sign_side * open * deg_to_rad(102.0)
		var pack := _packs[i]
		var spread := Chaos.shutter_spread(close)
		pack.visible = spread > 0.00001
		if not pack.visible:
			continue
		pack.position = Vector3(sign_side * radius * (1.0 - spread), 0, Chaos.SHUTTER_FRONT)
		pack.scale = Vector3.ONE * radius
		var fold := acos(spread)
		var pitch := 1.0 / HINGES
		for j in range(HINGES):
			var blade := pack.get_child(j) as MeshInstance3D
			var even := j % 2 == 0
			blade.rotation.y = sign_side * (fold if even else -fold)
			blade.position = Vector3(sign_side * j * pitch * spread, 0, 0.0 if even else -pitch * sin(fold))


## 판 폭은 고정이다. 옆 가장자리와 횡방향 프레스 비드를 같은 메시에서 성형한다.
func _leaf_mesh(index: int, side: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sections := PackedFloat32Array([0.0, 0.065, 0.14, 0.38, 0.64, 0.84, 0.93, 0.985, 1.0])
	var rows := PackedFloat32Array([-1.0, -0.965, -0.60, -0.58, -0.55, 0.55, 0.58, 0.60, 0.965, 1.0])
	var front := PackedVector3Array()
	for t in sections:
		var x: float = (index + t) / HINGES
		var height := sqrt(maxf(0, 1.0 - x * x))
		for row in rows:
			var z := -0.008 * (1.0 - smoothstep(0, 0.14, minf(t, 1.0 - t)))
			if is_equal_approx(absf(row), 0.58):
				z -= 0.005
			front.append(Vector3(side * t / HINGES, row * height, z))
	var depth := Vector3.FORWARD * 0.011
	var n := rows.size()
	for i in range(sections.size() - 1):
		for j in range(n - 1):
			var a := front[i * n + j]
			var b := front[i * n + j + 1]
			var c := front[(i + 1) * n + j + 1]
			var d := front[(i + 1) * n + j]
			_quad(st, a, b, c, d, Vector3.BACK)
			_quad(st, a + depth, b + depth, c + depth, d + depth, Vector3.FORWARD)
			if j == 0: _quad(st, a, d, d + depth, a + depth, Vector3.DOWN)
			if j == n - 2: _quad(st, b, c, c + depth, b + depth, Vector3.UP)
			if i == 0: _quad(st, a, b, b + depth, a + depth, Vector3.LEFT * side)
			if i == sections.size() - 2: _quad(st, d, c, c + depth, d + depth, Vector3.RIGHT * side)
	st.index()
	return st.commit()


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, facing: Vector3) -> void:
	var normal := (c - a).cross(b - a)
	if normal.length_squared() < 1e-15:
		normal = (d - a).cross(c - a)
	var reverse := normal.dot(facing) < 0.0
	normal = (-normal if reverse else normal).normalized()
	for v: Vector3 in [a, d, c, a, c, b] if reverse else [a, b, c, a, c, d]:
		st.set_normal(normal)
		st.set_uv(Vector2(absf(v.x) * 3.8, v.y * 0.41 + 0.50))
		st.add_vertex(v)
