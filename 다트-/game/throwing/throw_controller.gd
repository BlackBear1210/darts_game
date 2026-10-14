class_name ThrowController
extends Node

signal throw_requested(aim: Vector2, timing: float)

var camera: Camera3D
var board: BoardView
var enabled: bool = false
var charging: bool = false
var timing: float = 0.0
var _held_seconds: float = 0.0


func _process(delta: float) -> void:
	if not enabled:
		charging = false
		_held_seconds = 0.0
		timing = 0.0
	elif charging:
		_held_seconds += delta
		timing = 1.0 - absf(fposmod(_held_seconds, 1.6) / 0.8 - 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if not enabled or not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		charging = true
		_held_seconds = 0.0
		timing = 0.0
	elif charging:
		charging = false
		var screen: Vector2 = event.position
		var origin := camera.project_ray_origin(screen)
		var direction := camera.project_ray_normal(screen)
		var normal := board.global_basis.z
		var divisor := normal.dot(direction)
		if absf(divisor) < 0.001: return
		var distance := normal.dot(board.global_position - origin) / divisor
		if distance <= 0.0: return
		var local := board.to_local(origin + direction * distance)
		var aim := Vector2(local.x, local.y) / BoardLayout.RADIUS
		throw_requested.emit(aim.clamp(Vector2(-1.5, -1.5), Vector2(1.5, 1.5)), timing)
