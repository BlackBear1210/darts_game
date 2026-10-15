class_name TableView
extends Node3D
## 공간의 배치와 환경 충돌만 소유한다. 캐릭터끼리는 충돌하지 않는다.

# 투척선 앞 평지의 최대 점프 머리 높이(약 2.66m)보다 중심과 시점을 높인다.
const BOARD_CENTER := Vector3(0, 2.9, -6.7)
const BOARD_SCALE: float = 2.5
const SEATS: Array[Vector3] = [Vector3(-2, 0, 3.5), Vector3(0, 0, 5.5), Vector3(2, 0, 3.5), Vector3(0, 0, 1.5)]
const SEAT_DISTANCE: float = 1.0
const RAISED_HEIGHT: float = 1.6

@onready var board: BoardView = $Board
var is_ready: bool = true


func _ready() -> void:
	board.position = BOARD_CENTER
	board.scale = Vector3.ONE * BOARD_SCALE
	_box(Vector3(0, -0.15, 0), Vector3(12, 0.3, 14), Color("303b49"))
	_box(Vector3(-6, 2, 0), Vector3(0.3, 4.5, 14), Color("526477"))
	_box(Vector3(6, 2, 0), Vector3(0.3, 4.5, 14), Color("526477"))
	_box(Vector3(0, 2, -7), Vector3(12, 4.5, 0.3), Color("526477"))
	_box(Vector3(0, 2, 7), Vector3(12, 4.5, 0.3), Color("526477"))
	_box(Vector3(0, 4.4, 0), Vector3(12, 0.3, 14), Color("526477"))
	# 플레이어 마스크에만 포함되는 투명 벽: 다트 레이는 통과한다.
	_box(Vector3(0, 2, -3.2), Vector3(12, 6, 0.1), Color.TRANSPARENT, 4)
	_box(Vector3(0, 0.015, -3.1), Vector3(11.5, 0.03, 0.08), Color("ea7657"), 0)
	_box(Vector3(0, 0.02, -0.6), Vector3(1.5, 0.03, 0.08), Color("eed16c"), 0)
	var table := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.05
	cylinder.bottom_radius = 1.05
	cylinder.height = 0.85
	table.mesh = cylinder
	table.position = Vector3(0, 0.425, 3.5)
	table.material_override = _material(Color("786f62"))
	add_child(table)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var collider := CylinderShape3D.new()
	collider.radius = 1.05
	collider.height = 0.85
	shape.shape = collider
	body.add_child(shape)
	table.add_child(body)
	for index in range(4):
		var marker := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.55
		disc.bottom_radius = 0.55
		disc.height = 0.025
		marker.mesh = disc
		marker.position = SEATS[index] + Vector3.UP * 0.02
		marker.material_override = _material(PlayerView.COLORS[index])
		add_child(marker)
		var label := Label3D.new()
		label.text = "SEAT %d" % (index + 1)
		label.position = SEATS[index] + Vector3(0, 0.08, 0.6)
		label.rotation.x = -PI / 2
		label.font_size = 40
		add_child(label)
	var sign := Label3D.new()
	sign.text = "DART PARTY  /  KEEP OUT"
	sign.position = Vector3(0, 3.8, -6.8)
	sign.font_size = 60
	add_child(sign)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material


func _box(at: Vector3, size: Vector3, color: Color, layer: int = 1) -> void:
	var body := StaticBody3D.new()
	body.position = at
	body.collision_layer = layer
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	body.add_child(collision)
	if color.a > 0:
		var visual := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = size
		visual.mesh = mesh
		visual.material_override = _material(color)
		body.add_child(visual)
	add_child(body)
