extends Node3D
## 월넛 섀시에 고정된 리프트, 판과 함께 도는 캐리지, 그 앞에서 벌어지는 캡스턴 보조판.
const Kit = preload("res://art/mesh_kit.gd")
const Chaos = preload("res://game/board/board_chaos.gd")
const SCORING_RADIUS := BoardLayout.RADIUS * 2.5
const LEAF_COUNT := 20

var _lift: Node3D
var _carriage: Node3D
var _rotor: Node3D
var _infill: Node3D
var _leaves: Array[MeshInstance3D] = []
var _rails: Node3D
var _pinion: Node3D
var _rollers: Array[MeshInstance3D] = []


func _joint(parent: Node3D, title: String, location: Vector3 = Vector3.ZERO) -> Node3D:
	var node := Node3D.new()
	node.name = title
	node.position = location
	parent.add_child(node)
	return node


func build(metal: Material, frame: Material, dark: Material, bronze: Material) -> void:
	for side: float in [-1.0, 1.0]:
		Kit.rounded_box(self, "LiftRail", Vector3(0.06, 1.42, 0.12), Vector3(side * 0.28, 0, -0.617), metal, 0.018)
	_lift = _joint(self, "VerticalLift", Vector3(0, 0, -0.54))
	for y: float in [-0.115, 0.115]:
		Kit.rounded_box(_lift, "TraverseRail", Vector3(1.42, 0.052, 0.086), Vector3(0, y, 0), metal, 0.015)
	_carriage = _joint(_lift, "HorizontalCarriage", Vector3(0, 0, 0.12))
	_axle(_carriage, "RotaryBearing", 0.39, 0.21, Vector3.ZERO, dark)
	_rotor = _joint(_carriage, "Rotor", Vector3(0, 0, 0.42))
	_rails = _joint(_rotor, "CamTrack", Vector3(0, 0, -0.274))
	_axle(_rails, "CamDisk", 0.74, 0.078, Vector3.ZERO, frame)
	_axle(_rails, "OuterRace", 0.755, 0.022, Vector3(0, 0, 0.023), bronze)
	_axle(_rails, "RaceInsert", 0.681, 0.026, Vector3(0, 0, 0.035), dark)
	_pinion = _joint(_rails, "CamPinion", Vector3(0, 0, 0.057))
	_axle(_pinion, "GearCore", 0.174, 0.045, Vector3.ZERO, metal)
	for i in range(22):
		var direction := Vector3(sin(i * TAU / 22.0), cos(i * TAU / 22.0), 0.0)
		var tooth := Kit.box(_pinion, "GearTooth", Vector3(0.024, 0.043, 0.036), direction * 0.181, bronze)
		tooth.rotation.z = -i * TAU / 22.0
	for i in range(5):
		var angle := atan2(Chaos.group_direction(i).x, Chaos.group_direction(i).y)
		var guide := _joint(_rails, "TelescopingGuide", Vector3(0, 0, 0.067))
		guide.rotation.z = -angle
		Kit.rounded_box(guide, "Rail", Vector3(0.16, 0.59, 0.058), Vector3(0, 0.46, 0), metal, 0.014)
		Kit.rounded_box(guide, "GuideSlot", Vector3(0.058, 0.47, 0.010), Vector3(0, 0.46, 0.032), dark, 0.003)
		_rollers.append(_axle(guide, "CamRoller", 0.072, 0.045, Vector3(0, 0.30, 0.050), bronze))
	_infill = _joint(_rotor, "CatchAssembly")
	_axle(_infill, "ContinuousCatchPan", 1.0, 0.038, Vector3(0, 0, Chaos.INFILL_FRONT - 0.029), dark, 128)
	_axle(_infill, "OuterBead", 0.86, 0.041, Vector3(0, 0, Chaos.INFILL_FRONT - 0.033), bronze)
	var patina := Kit.material("CatchPatina", "355b53", 0.24)
	for i in range(LEAF_COUNT):
		var angle := (i - 0.5) * TAU / LEAF_COUNT
		var leaf := Kit.sector(_infill, "ExtensionLeaf_%02d" % i, 0.058, 0.999,
			angle + 0.006, angle + TAU / LEAF_COUNT - 0.006, 0, patina)
		_leaves.append(leaf)
		Kit.sector(leaf, "LeafEdge", 0.961, 0.988,
			angle + 0.010, angle + TAU / LEAF_COUNT - 0.010, 0.0009, bronze)
	_axle(_infill, "CenterStop", 0.224, 0.022, Vector3(0, 0, Chaos.INFILL_FRONT - 0.011), frame, 20)
	# 원형 중앙판도 실제 막힌 면이다. 5개의 작은 동색 고정구로 깊이를 읽게 한다.
	for i in range(5):
		var a := i * TAU / 5.0
		var p := Vector3(cos(a) * 0.171, sin(a) * 0.171, Chaos.INFILL_FRONT + 0.001)
		_axle(_infill, "StopFastener", 0.016, 0.006, p, bronze, 12)
	show_pose(Chaos.rest())


func show_pose(shape: Dictionary) -> void:
	var movement: Vector2 = shape.get("move", Vector2.ZERO)
	_lift.position.y = movement.y * SCORING_RADIUS
	_carriage.position.x = movement.x * SCORING_RADIUS
	_rotor.rotation.z = float(shape.get("angle", 0))
	var radius := Chaos.infill_radius(shape) * SCORING_RADIUS
	_infill.scale = Vector3(radius, radius, 1.0)
	var travel := Chaos.split_travel(shape)
	# 확대 후에는 각 칸 뒤의 잎이 캠을 타고 전진한다. 보이는 동안에도 연속 후판이 막고 있다.
	var insert := float(shape.get("insert", 0.0))
	var lift := maxf(insert, smoothstep(0.0, 0.46, travel - float(shape.get("petal", 0))))
	for i in range(LEAF_COUNT):
		# 겉 조각 사이로 드러나는 보조판을 전진시킨다. 연속 후판은 전 구간에서 틈을 막는다.
		var dock := smoothstep(0.025 * (i % 4), 1.0, lift)
		var center := Chaos.sector_direction(i)
		var extension := 0.021 * dock
		_leaves[i].position = Vector3(center.x * extension, center.y * extension, Chaos.INFILL_FRONT - 0.032 + 0.031 * dock)
		_leaves[i].scale = Vector3.ONE * lerpf(0.915, 0.979, dock)
		if i % 2 == 1:
			_leaves[i].position.z -= 0.002
	for roller: MeshInstance3D in _rollers:
		roller.position.y = lerpf(0.29, 0.65, lift)
	_pinion.rotation.z = -travel * 2.4


func _axle(parent: Node3D, title: String, radius: float, length: float, location: Vector3, material: Material, count := 64) -> MeshInstance3D:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = length
	cylinder.radial_segments = count
	cylinder.rings = 0
	var node := Kit.mesh_node(parent, title, cylinder, location, material)
	node.rotation.x = PI / 2.0
	return node
