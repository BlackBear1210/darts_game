extends Node3D
## 게임이 끝나면 점수가 가장 낮은 사람이 묶이는 서커스 칼 던지기 원판(사용자 기획 2026-10-28). 다른 사람들이 다트를 던진다.
## 원판 면 = 로컬 XY, 정면 = +Z(투척선 쪽). 꽂힌 다트는 돌아가는 판(spinner)의 자식이 되어 같이 돈다.
## 펍 레인(투척 금지선 너머, 과녁 앞)에 세운다. 충돌은 없다(다트 판정은 원판 평면으로 한다).

const MeshKit = preload("res://art/mesh_kit.gd")

const RADIUS: float = 0.95
const WEDGES: int = 16
const SPIN_SPEED: float = 1.5
## 묶인 캐릭터 크기·발 위치(원판 중심 기준).
const VICTIM_SCALE: float = 0.9
const VICTIM_FEET_Y: float = -0.84

var spinner: Node3D
var speed: float = SPIN_SPEED
var _flip_in: float = 3.0
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	spinner = Node3D.new()
	spinner.name = "Spinner"
	add_child(spinner)
	var red := MeshKit.material("WheelRed", "b8392f")
	var cream := MeshKit.material("WheelCream", "efe2c4")
	for i in range(WEDGES):
		var start: float = TAU * i / WEDGES
		MeshKit.sector(spinner, "Wedge_%d" % i, 0.0, RADIUS, start, start + TAU / WEDGES, 0.0, red if i % 2 == 0 else cream)
	# 놋쇠 테두리 = 고리(속이 찬 원기둥이면 칸 무늬를 덮는다).
	var brass := MeshKit.material("WheelBrass", "c9a463", 0.6)
	for i in range(WEDGES):
		var start: float = TAU * i / WEDGES
		MeshKit.sector(spinner, "Rim_%d" % i, RADIUS - 0.005, RADIUS + 0.05, start, start + TAU / WEDGES, 0.004, brass)
	var back := MeshKit.cylinder(spinner, "Back", RADIUS, 0.04, Vector3(0, 0, -0.035), MeshKit.material("WheelWood", "5b3a26"), 32)
	back.rotation.x = PI / 2
	var hub := MeshKit.cylinder(spinner, "Hub", 0.07, 0.05, Vector3(0, 0, 0.02), brass, 10)
	hub.rotation.x = PI / 2
	# 받침대: 바닥에서 원판 뒤까지 비스듬한 다리 둘 + 가로대(돌지 않는다).
	var wood := MeshKit.material("WheelStand", "3c2a22")
	var floor_y: float = -position.y
	for side in [-1.0, 1.0]:
		MeshKit.rod(self, "Leg", Vector3(side * 0.62, floor_y, -0.25), Vector3(side * 0.12, 0.0, -0.08), 0.045, wood)
	MeshKit.box(self, "Foot", Vector3(1.5, 0.06, 0.4), Vector3(0, floor_y + 0.03, -0.25), wood)


func _process(delta: float) -> void:
	spinner.rotation.z += speed * delta
	_flip_in -= delta
	if _flip_in <= 0.0 and absf(speed) > 0.01:
		# 가끔 방향과 빠르기를 바꿔 맞히기 어렵게 한다.
		speed = -signf(speed) * SPIN_SPEED * _random.randf_range(0.7, 1.4)
		_flip_in = _random.randf_range(2.0, 4.0)


## 꼴찌 캐릭터를 팔다리를 벌린 채 원판에 묶는다. 캐릭터 정면(+Z)이 던지는 사람 쪽이다.
func attach(seat: int) -> Node3D:
	var model: Node3D = PlayerLook.character(seat)
	model.name = "Victim"
	model.position = Vector3(0, VICTIM_FEET_Y, 0.03)
	model.scale = Vector3.ONE * VICTIM_SCALE
	spinner.add_child(model)
	# 팔은 위로 비스듬히(만세), 다리는 양옆으로. L = 캐릭터 본인 왼쪽 = +X.
	var pose := {"Body/ArmL": 2.25, "Body/ArmR": -2.25, "LegL": 0.32, "LegR": -0.32}
	for path: String in pose:
		var joint := model.get_node_or_null(path) as Node3D
		if joint != null:
			joint.rotation.z = float(pose[path])
	return model


## 꽂힌 다트를 판에 붙여 같이 돌게 한다.
func stick(dart: Node3D) -> void:
	dart.reparent(spinner, true)


## 판 위 한 점이 묶인 사람 몸(머리 원 + 몸통·다리 상자)에 맞았는지. 팔은 판정하지 않는다.
func hits_body(world_point: Vector3) -> bool:
	var local: Vector3 = spinner.to_local(world_point)
	var head := Vector2(0, VICTIM_FEET_Y + 1.34 * VICTIM_SCALE)
	if Vector2(local.x, local.y).distance_to(head) <= 0.19:
		return true
	return absf(local.x) <= 0.2 and local.y >= VICTIM_FEET_Y and local.y <= VICTIM_FEET_Y + 1.08 * VICTIM_SCALE


## 원판 회전을 1.2초에 걸쳐 멈춘다.
func stop() -> void:
	create_tween().tween_property(self, "speed", 0.0, 1.2)
