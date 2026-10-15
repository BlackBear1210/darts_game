class_name PlayerView
extends CharacterBody3D
## 입력 소유권은 Game에 있고 이 노드는 방장 시뮬레이션과 캐릭터 표현을 소유한다.

const COLORS: Array[Color] = [Color("f08475"), Color("79ceb5"), Color("eed16c"), Color("b897e5")]
const SPEED: float = 3.8
const JUMP_SPEED: float = 4.8
const GRAVITY: float = 12.0
const EYE_HEIGHT: float = 1.55

var identity: MatchPlayer
var seated: bool = false
var crouched: bool = false
var pitch: float = 0.0
var color: Color
var _body: MeshInstance3D
var _nose: MeshInstance3D
var _label: Label3D
var _collision: CollisionShape3D


func _ready() -> void:
	collision_layer = 2
	collision_mask = 5
	_body = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.28
	capsule.height = 1.7
	_body.mesh = capsule
	_body.position.y = 0.85
	add_child(_body)
	_nose = MeshInstance3D.new()
	var nose := BoxMesh.new()
	nose.size = Vector3(0.16, 0.12, 0.24)
	_nose.mesh = nose
	_nose.position = Vector3(0, 1.45, -0.3)
	add_child(_nose)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = 1.95
	_label.font_size = 32
	_label.pixel_size = 0.003
	add_child(_label)
	_collision = CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.28
	shape.height = 1.7
	_collision.shape = shape
	_collision.position.y = 0.85
	add_child(_collision)


func configure(player: MatchPlayer, _angle: float = 0.0, _is_local: bool = false) -> void:
	identity = player
	position = TableView.SEATS[player.seat] + Vector3(0, 0.05, 0.8)
	color = COLORS[player.seat]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	_body.material_override = material
	var front := StandardMaterial3D.new()
	front.albedo_color = Color.WHITE
	_nose.material_override = front
	# 캐릭터마다 고유 렌더 레이어. 각 카메라에서 자기 몸만 제외한다.
	for visual: VisualInstance3D in [_body, _nose, _label]:
		visual.layers = 1 << (player.seat + 1)
	if player.is_bot:
		position = TableView.SEATS[player.seat]
		seated = true
		look_at(Vector3(TableView.BOARD_CENTER.x, position.y, TableView.BOARD_CENTER.z))
	show_state(player)


func show_state(player: MatchPlayer) -> void:
	identity = player
	_label.text = "%s · %d" % [player.display_name, player.score]


func eye_position() -> Vector3:
	return global_position + Vector3.UP * (0.95 if crouched or seated else EYE_HEIGHT)


func simulate(delta: float, controls: Dictionary) -> void:
	if identity.is_bot:
		return
	rotation.y = float(controls.get("yaw", rotation.y))
	pitch = float(controls.get("pitch", pitch))
	crouched = bool(controls.get("crouch", false)) and not seated
	if seated:
		velocity = Vector3.ZERO
		position = TableView.SEATS[identity.seat]
	else:
		var axis: Vector2 = controls.get("move", Vector2.ZERO)
		var direction := Basis(Vector3.UP, rotation.y) * Vector3(axis.x, 0, axis.y)
		var speed := SPEED * (0.5 if crouched else 1.0)
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		elif bool(controls.get("jump", false)):
			velocity.y = JUMP_SPEED
		else:
			velocity.y = 0
		move_and_slide()
		# 추가 좌표 경계는 네트워크 입력과 접촉 오차에도 경기장을 벗어나지 않게 한다.
		position.x = clampf(position.x, -5.55, 5.55)
		position.z = clampf(position.z, -2.85, 6.55)
		position.y = maxf(position.y, 0)
	update_posture()


func update_posture() -> void:
	var height_scale: float = 0.58 if crouched or seated else 1.0
	_body.scale.y = height_scale
	_body.position.y = 0.85 * height_scale
	_nose.position.y = 1.45 * height_scale
	_label.position.y = 1.95 * height_scale
	var shape := _collision.shape as CapsuleShape3D
	shape.height = 1.7 * height_scale
	_collision.position.y = shape.height * 0.5


func to_motion() -> Dictionary:
	return {"id": identity.peer_id, "position": position, "yaw": rotation.y, "pitch": pitch,
		"seated": seated, "crouched": crouched, "velocity": velocity}


func apply_motion(data: Dictionary) -> void:
	position = data.position
	rotation.y = data.yaw
	pitch = data.pitch
	seated = data.seated
	crouched = data.crouched
	velocity = data.velocity
	update_posture()
