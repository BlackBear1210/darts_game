class_name DartView
extends Node3D

@export var config: DartConfig = preload("res://game/dart/default_dart.tres")

@onready var _visual: Node3D = $Visual

var velocity: Vector3 = Vector3.ZERO
var _start: Vector3 = Vector3.ZERO
var _initial_velocity: Vector3 = Vector3.ZERO
var _target: Vector3 = Vector3.ZERO
var _elapsed: float = 0.0
var _duration: float = 0.0
var _hit_board: bool = true
var _release_offset: Vector3 = Vector3.ZERO


func _ready() -> void:
	set_physics_process(false)


func fly(start: Vector3, target: Vector3, duration: float, hit_board: bool = true,
		release_offset: Vector3 = Vector3.ZERO) -> void:
	assert(duration > 0.0, "다트 비행 시간은 양수여야 합니다.")
	_start = start
	_target = target
	_duration = duration
	_hit_board = hit_board
	_elapsed = 0.0
	_initial_velocity = config.initial_velocity(start, target, duration)
	velocity = _initial_velocity
	global_position = start
	look_at(start + velocity, Vector3.UP)
	# 판정 원점은 유지하고 외형만 손에서 출발해 착탄점으로 합류시킨다.
	_release_offset = global_basis * release_offset
	_visual.global_position = global_position + _release_offset
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	var flight_time: float = minf(_elapsed, _duration) if _hit_board else _elapsed
	global_position = config.position_at(_start, _initial_velocity, flight_time)
	velocity = _initial_velocity + Vector3.DOWN * config.gravity * flight_time
	look_at(global_position + velocity, Vector3.UP)
	_visual.global_position = global_position + _release_offset * (1.0 - minf(flight_time / _duration, 1.0))
	if _elapsed >= _duration:
		if _hit_board:
			global_position = _target
			velocity = Vector3.ZERO
			set_physics_process(false)
		elif _elapsed >= _duration + config.miss_lifetime:
			queue_free()
