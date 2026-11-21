extends CanvasLayer
## [화면 카드] 정전·딸꾹질·유체이탈·망원경·원샷을 내 화면(1인칭 카메라 + 덮개 한 장씩)에 보인다(2026-11-21 새 카드).
##
## GameView 가 자식으로 하나 붙이고(화면 있는 실행만), _process 에서 조준(throw_input.aim_at)보다 먼저 apply 를 부른다
## → 카메라가 흔들리면 조준점(화면 가운데 → 과녁)도 같이 흔들린다. 그게 이 카드들의 방해다. 점수 판정은 건드리지 않는다.
## 효과 값은 경기 상태(card_effects 의 "mod" 이름, RoundRules.MOD_DEFAULTS)만 읽는다 — 여기서 새 상태를 만들지 않는다.
## 덮개는 짧은 셰이더 한 장(ColorRect)이라 그림 파일이 없다. 움직임 큰 효과는 "화면 흔들림 줄이기" 설정을 따른다.

const Preferences = preload("res://ui/player_preferences.gd")
## 정전: 과녁만 희미하게 보이는 둥근 빛(화면 높이 비율)과 켜지고 꺼지는 빠르기(초당).
const BLACKOUT_HOLE: float = 0.11
const FADE_RATE: float = 3.0
## 딸꾹질: 다음 딸꾹까지(초)와 위로 튀는 각도(라디안).
const HICCUP_GAP := Vector2(1.4, 2.6)
const HICCUP_KICK: float = 0.16
## 유체이탈: 몸 뒤·위로 물러나는 거리(m).
const OUTBODY_BACK: float = 1.4
const OUTBODY_UP: float = 0.8
## 망원경: 시야각(도)과 흔들림(라디안).
const SCOPE_FOV: float = 22.0
const SCOPE_DRIFT: float = 0.018
## 원샷: 출렁이는 크기(라디안).
const ONESHOT_ROLL: float = 0.14

const BLACKOUT_SHADER := """
shader_type canvas_item;
uniform vec2 hole = vec2(0.5, 0.5);
uniform float radius = 0.11;
uniform float strength = 0.0;
uniform float aspect = 1.777;
void fragment() {
	vec2 d = (UV - hole) * vec2(aspect, 1.0);
	float lit = 1.0 - smoothstep(radius * 0.55, radius, length(d));
	float flicker = 0.93 + 0.07 * sin(TIME * 23.0) * sin(TIME * 7.3);
	COLOR = vec4(0.0, 0.0, 0.03, strength * (0.94 - lit * 0.7) * flicker);
}
"""
const SCOPE_SHADER := """
shader_type canvas_item;
uniform float strength = 0.0;
uniform float aspect = 1.777;
void fragment() {
	vec2 d = (UV - vec2(0.5)) * vec2(aspect, 1.0);
	float r = length(d);
	float outside = smoothstep(0.40, 0.415, r);
	float rim = smoothstep(0.36, 0.40, r) * (1.0 - outside);
	float cross = (1.0 - smoothstep(0.0015, 0.003, abs(d.x))) + (1.0 - smoothstep(0.0015, 0.003, abs(d.y)));
	COLOR = vec4(0.0, 0.0, 0.0, strength * max(max(outside, rim * 0.7), clamp(cross, 0.0, 1.0) * 0.35 * (1.0 - outside)));
}
"""

var _blackout: ColorRect
var _scope: ColorRect
var _dark: float = 0.0
var _zoom: float = 0.0
var _hiccup: float = 0.0
var _next_hiccup: float = 0.0
var _base_fov: float = -1.0
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	layer = 4
	_random.randomize()
	_blackout = _cover(BLACKOUT_SHADER, "Blackout")
	_scope = _cover(SCOPE_SHADER, "Telescope")


func _cover(code: String, title: String) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = title
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = code
	var material := ShaderMaterial.new()
	material.shader = shader
	rect.material = material
	rect.visible = false
	add_child(rect)
	return rect


## 내 카메라에 화면 카드를 건다. local = 내 캐릭터, active = 지금 던지는 사람(없으면 null), board = 과녁 가운데(월드).
## 정전은 던지는 사람에게 걸리면 모두의 화면이 어두워진다(펍 불이 나간다). 나머지는 내게 걸린 것만 보인다.
func apply(camera: Camera3D, local: PlayerView, active: MatchPlayer, board: Vector3, delta: float) -> void:
	if _base_fov < 0.0:
		_base_fov = camera.fov
	var mine: Dictionary = local.identity.card_effects
	var time: float = Time.get_ticks_msec() / 1000.0
	var motion: float = 0.0 if not Preferences.visual_effects else (0.3 if Preferences.reduced_motion else 1.0)
	var size: Vector2 = get_viewport().get_visible_rect().size
	var aspect: float = size.x / maxf(size.y, 1.0)
	# 정전
	var dark: bool = active != null and bool(active.card_effects.get("blackout", false))
	_dark = move_toward(_dark, 1.0 if dark else 0.0, delta * FADE_RATE)
	_blackout.visible = _dark > 0.0
	if _blackout.visible:
		var material := _blackout.material as ShaderMaterial
		var hole := Vector2(-1, -1)
		if not camera.is_position_behind(board):
			hole = camera.unproject_position(board) / size
		material.set_shader_parameter("hole", hole)
		material.set_shader_parameter("radius", BLACKOUT_HOLE)
		material.set_shader_parameter("strength", _dark)
		material.set_shader_parameter("aspect", aspect)
	# 딸꾹질: 가끔 화면(조준)이 위로 툭 튀었다가 돌아온다.
	if bool(mine.get("hiccup", false)):
		if time >= _next_hiccup:
			_hiccup = 1.0
			_next_hiccup = time + _random.randf_range(HICCUP_GAP.x, HICCUP_GAP.y)
	else:
		_next_hiccup = time + HICCUP_GAP.x
	_hiccup = move_toward(_hiccup, 0.0, delta * 3.5)
	camera.rotation.x += sin(_hiccup * PI) * HICCUP_KICK * maxf(motion, 0.5)
	# 원샷: 크게 출렁인다(취한 사람처럼 좌우로 쏠리고 화면이 기운다).
	if bool(mine.get("oneshot", false)) and motion > 0.0:
		camera.rotation.z += sin(time * 1.3) * ONESHOT_ROLL * motion
		camera.rotation.y += sin(time * 0.83 + 1.0) * 0.05 * motion
		camera.rotation.x += sin(time * 1.07) * 0.035 * motion
		camera.h_offset += sin(time * 0.9) * 0.15 * motion
	# 망원경: 시야를 확 좁히고 동그란 테두리만 남긴다. 손떨림처럼 천천히 흔들린다.
	_zoom = move_toward(_zoom, 1.0 if bool(mine.get("telescope", false)) else 0.0, delta * FADE_RATE)
	camera.fov = lerpf(_base_fov, SCOPE_FOV, _zoom)
	_scope.visible = _zoom > 0.0
	if _scope.visible:
		var scope := _scope.material as ShaderMaterial
		scope.set_shader_parameter("strength", _zoom)
		scope.set_shader_parameter("aspect", aspect)
		camera.rotation.x += sin(time * 0.7) * SCOPE_DRIFT * _zoom
		camera.rotation.y += sin(time * 0.53 + 2.0) * SCOPE_DRIFT * _zoom
	# 유체이탈: 내 몸 뒤·위에서 본다(내 몸도 보이게). 벽에 막히면 그 앞까지만.
	if bool(mine.get("outbody", false)) and not local.fallen:
		var eye: Vector3 = camera.position
		var want: Vector3 = eye + camera.basis.z * OUTBODY_BACK + Vector3.UP * OUTBODY_UP
		var wall := camera.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye, want, 1))
		if not wall.is_empty():
			want = (wall.position as Vector3) + (eye - (wall.position as Vector3)).normalized() * 0.25
		camera.position = want
		camera.cull_mask = 0xfffff
