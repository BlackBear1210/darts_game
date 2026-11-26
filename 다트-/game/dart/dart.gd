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
## 크기 카드("다트 크기 증가") 겉모습 배율. 날아가는 다트·손에 든 다트(FirstPersonArm.held_dart)가 같이 쓴다.
## 판정(겹친 면적)은 BoardChaos.LARGE_RADIUS 가 따로 정한다.
const LARGE_SIZE: float = 1.8

## [힘 증가 카드 — 2026-11-17 밤 사용자 요청 "날아갈 때 다트 뒤로 바람을 표현해서 빠르게 날아가는 효과"]
## 깃 뒤에 깔때기 모양 원뿔 두 겹을 붙이고 줄무늬(바람 줄기)를 다트 → 꼬리 쪽으로 빠르게 흘린다.
## 던진 사람은 다트를 뒤에서 보므로 다트로 빨려 드는 속도선처럼, 옆에서 보면 바람 꼬리처럼 보인다.
## Visual 아래에 붙여 다트와 같이 커지고(LANDED_SCALE) 돈다. 꽂히면 WIND_FADE_SECONDS 동안 사라진다. 판정과 무관.
## [바깥 원뿔 길이, 깃 쪽 반지름, 꼬리 반지름, 줄기 수, 흐름 빠르기]
## 날아가며 Visual 이 LANDED_SCALE 까지 커지므로 실제 길이는 꽂힐 때 약 2배다.
## 카메라에 가까운 부분은 셰이더가 흐리게 한다 — 던진 사람 화면을 바람 띠가 덮지 않게(2026-11-17 밤 화면 확인).
const WIND_LAYERS: Array = [[0.6, 0.02, 0.05, 18.0, 2.6], [0.4, 0.008, 0.025, 11.0, 3.6]]
## 원뿔이 시작하는 자리(깃 가운데, Visual 기준 z).
const WIND_FROM: float = 0.12
const WIND_FADE_SECONDS: float = 0.25
const WIND_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec4 tint : source_color = vec4(0.9, 0.97, 1.0, 1.0);
uniform float strength = 0.0;
uniform float streaks = 16.0;
uniform float speed = 3.0;
uniform float seed = 0.0;
float hash(float n) { return fract(sin(n * 12.9898 + seed * 78.233) * 43758.5453); }
void fragment() {
	float around = UV.x * streaks;
	float r = hash(floor(around));
	float across = abs(fract(around) - 0.5) * 2.0;
	float line = 1.0 - smoothstep(0.1, 0.4 + 0.25 * r, across);
	float run = fract(UV.y * (1.2 + r) - TIME * speed * (0.8 + 0.6 * r) + r);
	float dash = smoothstep(0.0, 0.12, run) * (1.0 - smoothstep(0.35, 0.9, run));
	float fade = smoothstep(0.0, 0.06, UV.y) * pow(1.0 - UV.y, 1.6);
	fade *= smoothstep(0.35, 1.0, -VERTEX.z);
	ALBEDO = tint.rgb;
	ALPHA = clamp(line * dash * fade * strength * (0.5 + 0.5 * r), 0.0, 1.0);
}
"""
static var _wind_shader: Shader

## 다트가 멈춘 순간(꽂힘 또는 벽·바닥). 과녁 흔들림·소리·가루 효과를 붙이는 곳(GameView, 로비 배경).
signal landed(at: Vector3, hit_board: bool)

@export var config: DartConfig = preload("res://game/dart/default_dart.tres")

@onready var _visual: Node3D = $Visual

var size_multiplier: float = 1.0
## 힘 증가 카드가 걸린 다트(fly 전에 정한다) — 바람 줄기를 단다.
var powered: bool = false
var _wind: Array[ShaderMaterial] = []
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
## 고무 다트(2026-11-21): 처음 닿은 뒤 이어 갈 구간들 [[도착점, 초], ...]. 비어 있으면 닿는 곳에 바로 꽂힌다.
var _hops: Array = []
var pierced := false
## 이 다트가 맞은 사람의 peer ID(0 = 사람에게 안 맞음). 몸에 맞은 다트는 꽂아 두지 않는다 — 몸은 움직이므로
## 그대로 두면 허공에 떠 있는 다트가 된다(2026-11-26 사용자 보고).
var victim_id: int = 0
var _bounced: bool = false


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
	set_visual_start(global_position + global_basis * release_offset)
	_visual.scale = Vector3.ONE * size_multiplier
	if powered and _wind.is_empty():
		_add_wind()
	_set_wind(0.0)
	set_physics_process(true)


## 로컬 화면의 다트 촉에서 출발한 외형이 비행 동안 판정 궤적에 합류한다.
func set_visual_start(at: Vector3) -> void:
	_release_offset = at - global_position
	_visual.global_position = at


## 날아가는 중에 착탄점이 바뀌었다(궤적 카드, MatchController.redirect_flight). 지금 자리·지금 시각에서 출발해
## 남은 시간 뒤 새 착탄점에 닿는 포물선으로 바꾼다. 경과 시간은 그대로라 커지기·깃 회전 연출이 끊기지 않는다.
func redirect(target: Vector3, remaining: float) -> void:
	if not is_physics_processing() or not _hit_board:
		return
	_hops.clear()
	var now: float = _elapsed
	var landing: float = now + remaining
	var gravity := Vector3.DOWN * config.gravity
	var from: Vector3 = global_position
	# position_at(시작, 속도, t) = 시작 + 속도·t + 중력·t²/2 가 t = now 에서 지금 자리, t = landing 에서 착탄점이 되게 푼다.
	_initial_velocity = (target - from - gravity * (landing * landing - now * now) * 0.5) / remaining
	_start = from - _initial_velocity * now - gravity * now * now * 0.5
	_target = target
	_duration = landing


## 고무 다트: fly 의 도착점에 닿으면 꽂히지 않고 바깥(via)으로 튕겨 나왔다가 seconds 뒤 target 에 꽂힌다.
## fly 다음에 부른다. 판정은 방장이 이미 끝냈다 — 겉모습만 두 구간 포물선으로 잇는다.
func bounce_via(via: Vector3, target: Vector3, seconds: float) -> void:
	var half: float = maxf(seconds * 0.5, 0.05)
	_hops = [[via, half], [target, half]]


func queue_hops(hops: Array) -> void:
	_hops = hops.duplicate(true)


func _next_hop() -> void:
	var hop: Array = _hops.pop_front()
	_bounced = true
	_start = global_position
	_target = hop[0]
	_duration = float(hop[1])
	_elapsed = 0.0
	_initial_velocity = config.initial_velocity(_start, _target, _duration)
	velocity = _initial_velocity
	_release_offset = Vector3.ZERO


func _physics_process(delta: float) -> void:
	_elapsed += delta
	var flight_time: float = minf(_elapsed, _duration) if _hit_board else _elapsed
	global_position = config.position_at(_start, _initial_velocity, flight_time)
	velocity = _initial_velocity + Vector3.DOWN * config.gravity * flight_time
	look_at(global_position + velocity, Vector3.UP)
	var progress := 1.0 if _bounced else minf(flight_time / _duration, 1.0)
	_visual.global_position = global_position + _release_offset * (1.0 - progress)
	_visual.scale = Vector3.ONE * lerpf(1.0, LANDED_SCALE, progress) * size_multiplier
	# 깃이 공기를 타며 몸통 축으로 돈다(손을 떠난 직후 빠르고 점점 느려진다).
	_visual.rotation.z = TAU * SPIN_TURNS * _duration * (1.0 - pow(1.0 - progress, 2.0)) * 0.5
	# 바람 줄기: 손을 떠나며 바로 켜지고, 빗나가 계속 날아가면 멈춘 뒤처럼 사라진다.
	_set_wind(minf(_elapsed / 0.06, 1.0) * clampf(1.0 - maxf(_elapsed - _duration, 0.0) / WIND_FADE_SECONDS, 0.0, 1.0))
	if _elapsed >= _duration:
		if _hit_board and not _hops.is_empty():
			_next_hop()
			return
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
	_set_wind(1.0 - _stuck_age / WIND_FADE_SECONDS)
	var fade := exp(-_stuck_age * WOBBLE_DAMPING)
	_visual.rotation.x = sin(_stuck_age * WOBBLE_SPEED) * WOBBLE_ANGLE * fade
	_visual.rotation.y = cos(_stuck_age * WOBBLE_SPEED * 0.8) * WOBBLE_ANGLE * 0.6 * fade
	if fade < 0.01:
		_visual.rotation.x = 0.0
		_visual.rotation.y = 0.0
		set_process(false)


## 바람 줄기 원뿔을 Visual 아래에 붙인다(WIND_LAYERS). 원뿔 위(+Y)가 깃 쪽, 아래가 꼬리(뒤 +Z)다.
func _add_wind() -> void:
	if _wind_shader == null:
		_wind_shader = Shader.new()
		_wind_shader.code = WIND_SHADER_CODE
	for index in range(WIND_LAYERS.size()):
		var layer: Array = WIND_LAYERS[index]
		var length: float = layer[0]
		var cone := CylinderMesh.new()
		cone.height = length
		cone.top_radius = layer[1]
		cone.bottom_radius = layer[2]
		cone.radial_segments = 24
		cone.rings = 1
		cone.cap_top = false
		cone.cap_bottom = false
		var material := ShaderMaterial.new()
		material.shader = _wind_shader
		material.set_shader_parameter("streaks", layer[3])
		material.set_shader_parameter("speed", layer[4])
		material.set_shader_parameter("seed", float(index) * 3.7)
		var mesh := MeshInstance3D.new()
		mesh.name = "Wind%d" % index
		mesh.mesh = cone
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.rotation_degrees = Vector3(-90, 0, 0)
		mesh.position = Vector3(0, 0, WIND_FROM + length * 0.5)
		_visual.add_child(mesh)
		_wind.append(material)


## 바람 줄기 세기(0 = 안 보임). 다 사라지면 원뿔을 지운다.
func _set_wind(strength: float) -> void:
	if _wind.is_empty():
		return
	for material in _wind:
		material.set_shader_parameter("strength", clampf(strength, 0.0, 1.0))
	if strength <= 0.0 and _stuck_age >= 0.0:
		for index in range(_wind.size()):
			var mesh := _visual.get_node_or_null("Wind%d" % index)
			if mesh != null: mesh.queue_free()
		_wind.clear()
