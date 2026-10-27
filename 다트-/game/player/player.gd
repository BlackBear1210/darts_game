class_name PlayerView
extends CharacterBody3D
## 입력 소유권은 Game에 있고 이 노드는 방장 시뮬레이션과 캐릭터 표현을 소유한다.
## 겉모습(디자인 담당): 자리(seat)마다 정해진 캐릭터 씬(art/player_look.gd) + 코드 몸짓(art/characters/character_rig.gd).
## 충돌 캡슐·눈높이·속도는 예전 그대로다 → 겉모습을 바꿔도 이동·판정은 바뀌지 않는다.

## 자리 색. 디자인 약속표(PlayerLook) 하나만 보도록 그대로 가져온다.
const COLORS: Array[Color] = PlayerLook.COLORS
const SPEED: float = 3.8
const JUMP_SPEED: float = 4.8
const GRAVITY: float = 12.0
const EYE_HEIGHT: float = 1.55
## 머리 위 이름표 높이(m). 캐릭터 키(약 1.6~1.75m) 바로 위. 앉거나 숙이면 LOW_LABEL_RATIO 만큼 내린다.
const LABEL_HEIGHT: float = 2.0
const LOW_LABEL_RATIO: float = 0.72

var identity: MatchPlayer
var seated: bool = false
var crouched: bool = false
var pitch: float = 0.0
var color: Color
## 지금 이 사람이 조준 중인지. GameView 가 매 프레임 넣고, 몸짓이 오른팔을 든다(모든 화면에서 보인다).
var aiming: bool = false
var _model: Node3D
var _rig: CharacterRig
var _label: Label3D
var _collision: CollisionShape3D


func _ready() -> void:
	collision_layer = 2
	collision_mask = 5
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = LABEL_HEIGHT
	_label.font_size = 32
	_label.pixel_size = 0.003
	_label.outline_size = 8
	_label.outline_modulate = Color("122b27")
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
	_dress(player.seat)
	# 캐릭터마다 고유 렌더 레이어. 각 카메라에서 자기 몸만 제외한다(모델의 모든 조각 + 이름표).
	_set_layers(self, 1 << (player.seat + 1))
	if player.is_bot:
		position = TableView.SEATS[player.seat]
		seated = true
		look_at(Vector3(TableView.BOARD_CENTER.x, position.y, TableView.BOARD_CENTER.z))
	show_state(player)


func show_state(player: MatchPlayer) -> void:
	identity = player
	# 이름표: 자리 표식(●▲■◆)을 붙이고 자리 색으로 칠한다(색약이어도 모양으로 구분 — 기획 2-4).
	_label.text = "%s · %d%s" % [PlayerLook.tag(player.seat, player.display_name), player.score, " · 슬로우" if player.speed_scale < 1.0 else ""]
	_label.modulate = COLORS[player.seat].lightened(0.35)


## 몸짓 재생(화면마다 따로 돈다. 네트워크로 보내는 값은 위치·자세·속도뿐이고 몸짓은 그 값으로 만든다).
func _process(delta: float) -> void:
	if _rig == null:
		return
	var posture := CharacterRig.Posture.SEAT if seated else (CharacterRig.Posture.CROUCH if crouched else CharacterRig.Posture.STAND)
	var ground_speed := Vector2(velocity.x, velocity.z).length() / SPEED
	var airborne := not seated and position.y > 0.05
	_rig.animate(delta, ground_speed, posture, airborne, pitch, aiming)


## 던지기 몸짓을 한 번 재생한다(GameView._show_throw 가 부른다).
func play_throw() -> void:
	if _rig != null:
		_rig.play_throw()


## 자리 캐릭터를 입힌다. 캐릭터 정면은 +Z 이고 이 노드는 -Z 가 정면이라 모델만 180도 돌린다.
func _dress(seat: int) -> void:
	if _model != null:
		remove_child(_model)
		_model.queue_free()
	_model = PlayerLook.character(seat)
	_model.name = "Model"
	_model.rotation.y = PI
	add_child(_model)
	# 네 명이 같은 박자로 깜빡이지 않게 자리마다 시작 시각을 다르게 준다.
	_rig = CharacterRig.new(_model, seat * 0.9)


func _set_layers(node: Node, layer: int) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = layer
	for child in node.get_children():
		_set_layers(child, layer)


func eye_position() -> Vector3:
	return global_position + Vector3.UP * (0.95 if crouched or seated else EYE_HEIGHT)


## 조작은 방장만 넣는다. 사람은 자기 입력(GameView._accept_controls), 봇은 GameView._drive_bot 이 만든 값이다.
func simulate(delta: float, controls: Dictionary) -> void:
	rotation.y = float(controls.get("yaw", rotation.y))
	pitch = float(controls.get("pitch", pitch))
	crouched = bool(controls.get("crouch", false)) and not seated
	if seated:
		velocity = Vector3.ZERO
		position = TableView.SEATS[identity.seat]
	else:
		var axis: Vector2 = controls.get("move", Vector2.ZERO)
		var direction := Basis(Vector3.UP, rotation.y) * Vector3(axis.x, 0, axis.y)
		# speed_scale: 테이블 집합 지각 페널티(슬로우). 방장 시뮬레이션에만 적용되고 위치로 모든 화면에 반영된다.
		var speed := SPEED * (0.5 if crouched else 1.0) * identity.speed_scale
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
	# 충돌 캡슐은 예전처럼 0.58배로 줄인다. 보이는 몸은 _process 의 몸짓이 따로 낮춘다.
	var height_scale: float = 0.58 if crouched or seated else 1.0
	# 앉아도 스툴 위라 머리 높이가 그대로다 → 숙일 때만 이름표를 내린다.
	_label.position.y = LABEL_HEIGHT * (LOW_LABEL_RATIO if crouched else 1.0)
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
