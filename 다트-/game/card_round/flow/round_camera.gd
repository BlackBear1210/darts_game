extends RefCounted
## 내 화면 카메라: 앉아 있으면 테이블 쪽으로 몸을 기울인 시점, 서 있으면 눈 높이 1인칭,
## C = 위에서 보는 전체 보기, 내가 벌칙 원판에 묶이면 옆에서 본다. 자동 진행 때는 시선을 스스로 돌린다.
## 마우스 시선(yaw·pitch)도 여기서 들고 있다(local_input.gd 가 turn() 으로 넣는다).

const Context = preload("res://game/card_round/flow/round_context.gd")
const Rules = preload("res://game/card_round/rules/round_rules.gd")

const MOUSE_SENSITIVITY: float = 0.0025
## 앉아서 카드를 볼 때: 자리에서 테이블 쪽으로 이만큼 기울이고, 이 높이에 눈을 둔다.
const LEAN: float = 0.45
const LEAN_HEIGHT: float = 1.36
## C 전체 보기 카메라 위치와 보는 곳.
const OVERVIEW_POSITION := Vector3(0, 3.9, 6.6)
const OVERVIEW_TARGET := Vector3(0, 0.6, -0.4)
## 내가 원판에 묶였을 때 카메라 위치.
const WHEEL_VIEW_POSITION := Vector3(2.4, 1.7, -2.6)

var yaw: float = PI
var pitch: float = 0.0
## C 키 전체 보기 중.
var overview: bool = false

var _ctx: Context
var _look_override := Vector3.ZERO
var _look_override_until: float = -1.0


## 감독이 시작할 때 한 번: 함께 쓰는 상자를 받는다(카메라 노드는 ctx.camera).
func setup(ctx: Context) -> void:
	_ctx = ctx


## 마우스 움직임만큼 시선을 돌린다.
func turn(relative: Vector2) -> void:
	yaw -= relative.x * MOUSE_SENSITIVITY
	pitch = clampf(pitch - relative.y * MOUSE_SENSITIVITY, -1.25, 1.25)


## 앉은 자리에서 테이블 가운데를 보게 한다(앉을 때·시작할 때).
func face_table() -> void:
	look_from_seat(TableView.TABLE_CENTER + Vector3.UP * 0.85)


## 앉은 자리 눈 위치에서 point 를 보는 시선으로 바로 맞춘다.
func look_from_seat(point: Vector3) -> void:
	var seat_position: Vector3 = TableView.SEATS[Context.LOCAL_SEAT]
	var toward: Vector3 = (TableView.TABLE_CENTER - seat_position).normalized()
	var eye: Vector3 = seat_position + toward * LEAN + Vector3.UP * LEAN_HEIGHT
	var direction: Vector3 = (point - eye).normalized()
	yaw = atan2(-direction.x, -direction.z)
	pitch = asin(direction.y)


## 자동 진행 때 seconds 동안 point 를 본다(화면 캡처가 쓴다).
func look_at_for(point: Vector3, seconds: float) -> void:
	_look_override = point
	_look_override_until = _ctx.now + seconds


## 매 프레임: 카메라 위치·방향. 졸림 카드면 화면이 살짝 기운다(debuff.eyelid).
func update(delta: float) -> void:
	var camera: Camera3D = _ctx.camera
	var actor: PlayerView = _ctx.actors[Context.LOCAL_SEAT]
	var weight: float = 1.0 - exp(-10.0 * delta)
	_ctx.local_fan.visible = not overview and actor.visible
	if overview:
		camera.cull_mask = 0xfffff
		camera.global_position = camera.global_position.lerp(OVERVIEW_POSITION, weight)
		camera.look_at(OVERVIEW_TARGET)
		return
	# 내 캐릭터(레이어 = 자리 + 1)는 내 화면에 안 그린다.
	camera.cull_mask = 0xfffff & ~(1 << (Context.LOCAL_SEAT + 1))
	if not actor.visible:
		camera.global_position = camera.global_position.lerp(WHEEL_VIEW_POSITION, weight)
		camera.look_at(Context.WHEEL_POSITION)
		return
	var target: Vector3
	if actor.seated:
		var seat_position: Vector3 = TableView.SEATS[Context.LOCAL_SEAT]
		var toward: Vector3 = (TableView.TABLE_CENTER - seat_position).normalized()
		target = seat_position + toward * LEAN + Vector3.UP * LEAN_HEIGHT
	else:
		target = actor.eye_position()
	camera.global_position = camera.global_position.lerp(target, weight) if actor.seated else target
	if _ctx.autoplay:
		_auto_look(delta)
	camera.rotation = Vector3(pitch, yaw, sin(_ctx.now * 1.7) * 0.035 * _ctx.debuff.eyelid)


## 자동 진행 때 내 시선: 카드 단계 = 테이블, 다트 = 던지는 사람과 과녁 사이, 벌칙 = 원판.
func _auto_look(delta: float) -> void:
	var focus: Vector3 = TableView.TABLE_CENTER + Vector3.UP * 0.85
	var rules: Rules = _ctx.rules
	if _ctx.now < _look_override_until:
		focus = _look_override
	elif _ctx.phase == "darts" and rules.active_seat() >= 0:
		if rules.active_seat() == Context.LOCAL_SEAT and not _ctx.actors[Context.LOCAL_SEAT].seated:
			focus = TableView.BOARD_CENTER
		else:
			focus = _ctx.actors[rules.active_seat()].global_position.lerp(TableView.BOARD_CENTER, 0.45) + Vector3.UP * 0.6
	elif _ctx.phase in ["punish", "ending", "results"]:
		focus = Context.WHEEL_POSITION
	var direction: Vector3 = (focus - _ctx.camera.global_position).normalized()
	var weight: float = 1.0 - exp(-3.0 * delta)
	yaw = lerp_angle(yaw, atan2(-direction.x, -direction.z), weight)
	pitch = lerpf(pitch, asin(clampf(direction.y, -1.0, 1.0)), weight)
