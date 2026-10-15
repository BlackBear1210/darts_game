class_name DartThrowController
extends Node

signal throw_requested(aim: Vector2, timing: float)

var config: DartConfig = preload("res://game/dart/default_dart.tres")

var camera: Camera3D
var board: BoardView
var enabled: bool = false:
	set(value):
		enabled = value
		if not enabled:
			_cancel_charge()
			aim = Vector2.INF
var charging: bool = false
var timing: float = 0.0
var aim: Vector2 = Vector2.INF
var _held_seconds: float = 0.0


func _process(delta: float) -> void:
	if charging:
		_held_seconds += delta
		timing = minf(_held_seconds / config.charge_seconds, 1.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_cancel_charge()


func _input(event: InputEvent) -> void:
	if not enabled or not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	# 시점 조작 중에는 중앙 HUD에 가로막히지 않고 누름·해제를 한 번씩 처리한다.
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_unhandled_input(event)
		get_viewport().set_input_as_handled()
	elif charging and not event.pressed:
		_unhandled_input(event)


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseMotion:
		aim = aim_at(get_viewport().get_visible_rect().size * 0.5)
		return
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	aim = aim_at(get_viewport().get_visible_rect().size * 0.5)
	if event.pressed:
		charging = true
		_held_seconds = 0.0
		timing = 0.0
	elif charging:
		charging = false
		if aim.is_finite():
			throw_requested.emit(aim, timing)


func aim_at(screen: Vector2) -> Vector2:
	var origin: Vector3 = camera.project_ray_origin(screen)
	var direction: Vector3 = camera.project_ray_normal(screen)
	var normal: Vector3 = board.global_basis.z
	var divisor: float = normal.dot(direction)
	if absf(divisor) < 0.001:
		return Vector2.INF
	var distance: float = normal.dot(board.global_position - origin) / divisor
	if distance <= 0.0:
		return Vector2.INF
	var local: Vector3 = board.to_local(origin + direction * distance)
	var normalized_aim: Vector2 = Vector2(local.x, local.y) / BoardLayout.RADIUS
	return normalized_aim.clamp(Vector2(-20, -20), Vector2(20, 20))


func _cancel_charge() -> void:
	charging = false
	_held_seconds = 0.0
	timing = 0.0
