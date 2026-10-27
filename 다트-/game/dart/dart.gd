class_name DartView
extends Node3D
## 날아가는 다트 1개. 방장이 확정한 시작점·착탄점·비행 시간으로 포물선을 재생만 한다(판정 근거 아님).
## 겉모습: 은색 촉 + 금색 몸통 + 깃(던진 사람 자리 색, paint()). 원점 = 촉 끝, 몸통은 +Z 쪽으로 뻗는다.

## 과녁에 꽂혔을 때 겉모습 배율. 과녁이 실제의 2.5배(TableView.BOARD_SCALE)라서 손 크기 다트는 판 위에서 너무 작다.
## 손을 떠날 때 1배 → 꽂힐 때 이 배율로 서서히 커진다(촉 끝 기준이라 착탄점은 그대로).
const LANDED_SCALE: float = 2.2

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


## 깃 색을 칠한다(던진 사람 자리 색). 깃 재질은 장면 안에서 공유되므로 다트마다 새로 만든다.
func paint(color: Color) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	for flight_name in ["FlightHorizontal", "FlightVertical"]:
		(get_node("Visual/" + flight_name) as MeshInstance3D).material_override = material


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
	var progress := minf(flight_time / _duration, 1.0)
	_visual.global_position = global_position + _release_offset * (1.0 - progress)
	_visual.scale = Vector3.ONE * lerpf(1.0, LANDED_SCALE, progress)
	if _elapsed >= _duration:
		if _hit_board:
			global_position = _target
			velocity = Vector3.ZERO
			set_physics_process(false)
		elif _elapsed >= _duration + config.miss_lifetime:
			queue_free()
