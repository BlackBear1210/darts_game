class_name DartView
extends Node3D
## 날아가는 다트 1개. 방장이 확정한 시작점·착탄점·비행 시간으로 포물선을 재생만 한다(판정 근거 아님).
## 겉모습: 은색 촉 + 금색 몸통 + 깃(던진 사람 자리 색, paint()). 원점 = 촉 끝, 몸통은 +Z 쪽으로 뻗는다.

## 과녁에 꽂혔을 때 겉모습 배율. 과녁이 실제의 2.5배(TableView.BOARD_SCALE)라서 손 크기 다트는 판 위에서 너무 작다.
## 손을 떠날 때 1배 → 꽂힐 때 이 배율로 서서히 커진다(촉 끝 기준이라 착탄점은 그대로).
const LANDED_SCALE: float = 2.2
## 비행 중 깃 회전 속도(바퀴/초)와 꽂힌 뒤 떨림(진폭 라디안·초당 감쇠·각속도).
const SPIN_TURNS: float = 2.5
const WOBBLE_ANGLE: float = 0.16
const WOBBLE_DAMPING: float = 5.5
const WOBBLE_SPEED: float = 42.0

## 다트가 멈춘 순간(꽂힘 또는 벽·바닥). 과녁 흔들림·소리·가루 효과를 붙이는 곳(GameView, 로비 배경).
signal landed(at: Vector3, hit_board: bool)

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
## 꽂힌 뒤 지난 시간(음수 = 아직 날아가는 중).
var _stuck_age: float = -1.0


func _ready() -> void:
	set_physics_process(false)
	set_process(false)


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


## 날아가는 중에 착탄점이 바뀌었다(궤적 카드, MatchController.redirect_flight). 지금 자리·지금 시각에서 출발해
## 남은 시간 뒤 새 착탄점에 닿는 포물선으로 바꾼다. 경과 시간은 그대로라 커지기·깃 회전 연출이 끊기지 않는다.
func redirect(target: Vector3, remaining: float) -> void:
	if not is_physics_processing() or not _hit_board:
		return
	var now: float = _elapsed
	var landing: float = now + remaining
	var gravity := Vector3.DOWN * config.gravity
	var from: Vector3 = global_position
	# position_at(시작, 속도, t) = 시작 + 속도·t + 중력·t²/2 가 t = now 에서 지금 자리, t = landing 에서 착탄점이 되게 푼다.
	_initial_velocity = (target - from - gravity * (landing * landing - now * now) * 0.5) / remaining
	_start = from - _initial_velocity * now - gravity * now * now * 0.5
	_target = target
	_duration = landing


func _physics_process(delta: float) -> void:
	_elapsed += delta
	var flight_time: float = minf(_elapsed, _duration) if _hit_board else _elapsed
	global_position = config.position_at(_start, _initial_velocity, flight_time)
	velocity = _initial_velocity + Vector3.DOWN * config.gravity * flight_time
	look_at(global_position + velocity, Vector3.UP)
	var progress := minf(flight_time / _duration, 1.0)
	_visual.global_position = global_position + _release_offset * (1.0 - progress)
	_visual.scale = Vector3.ONE * lerpf(1.0, LANDED_SCALE, progress)
	# 깃이 공기를 타며 몸통 축으로 돈다(손을 떠난 직후 빠르고 점점 느려진다).
	_visual.rotation.z = TAU * SPIN_TURNS * _duration * (1.0 - pow(1.0 - progress, 2.0)) * 0.5
	if _elapsed >= _duration:
		if _hit_board:
			global_position = _target
			velocity = Vector3.ZERO
			set_physics_process(false)
			_stuck_age = 0.0
			set_process(true)
			landed.emit(_target, true)
		elif _elapsed >= _duration + config.miss_lifetime:
			queue_free()
		elif _stuck_age < 0.0:
			_stuck_age = 0.0
			landed.emit(global_position, false)


## 꽂힌 직후: 촉 끝을 축으로 꼬리가 부르르 떤다(줄어드는 사인). 판정·위치는 바꾸지 않는다.
func _process(delta: float) -> void:
	_stuck_age += delta
	var fade := exp(-_stuck_age * WOBBLE_DAMPING)
	_visual.rotation.x = sin(_stuck_age * WOBBLE_SPEED) * WOBBLE_ANGLE * fade
	_visual.rotation.y = cos(_stuck_age * WOBBLE_SPEED * 0.8) * WOBBLE_ANGLE * 0.6 * fade
	if fade < 0.01:
		_visual.rotation.x = 0.0
		_visual.rotation.y = 0.0
		set_process(false)
