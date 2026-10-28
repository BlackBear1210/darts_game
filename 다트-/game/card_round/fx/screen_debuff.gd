extends CanvasLayer
## 내 화면에만 걸리는 방해 효과. HUD(레이어 10)보다 아래에 깔려 UI 글자는 흐려지지 않는다.
## 맞힌 벌(다른 사람을 다트로 맞히면 내 차례가 끝날 때까지): 아래 셋 중 하나를 무작위로(turn_effects.gd 가 고른다).
##   취기   — 술기운이 돈 것처럼 화면이 좌우로 살짝살짝 흔들린다(round_camera.gd 가 sway 를 읽는다).
##   마우스 — 마우스 감도가 갑자기 빨라졌다 느려졌다 한다(round_camera.gd 가 mouse_factor 를 곱한다).
##   난시   — 안경을 벗은 것처럼 한 방향으로 겹쳐 흐릿하다. 과녁 숫자는 흐릿해도 읽힌다.
## 2026-10-28 피드백: 예전 "뿌연 화면"은 너무 뿌예서 셋으로 바꿨다.
## 졸림: 졸림 카드 — 눈꺼풀이 자꾸 내려와 화면 위아래가 감긴다.

enum Penalty { NONE, SWAY, MOUSE, ASTIGMATISM }

const PENALTY_NAMES: Array[String] = ["", "취기(화면 흔들림)", "마우스 감도 들쭉날쭉", "난시(겹쳐 흐릿)"]

## 난시: 비스듬한 한 방향으로만 몇 픽셀 겹쳐 번지게(전체를 뭉개지 않는다). amount 0~1.
const ASTIGMATISM_SHADER := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 smear = amount * vec2(0.0011, 0.0019);
	float lod = amount * 0.6;
	vec4 color = textureLod(screen, SCREEN_UV, lod) * 0.36;
	color += textureLod(screen, SCREEN_UV + smear, lod) * 0.2;
	color += textureLod(screen, SCREEN_UV - smear, lod) * 0.2;
	color += textureLod(screen, SCREEN_UV + smear * 2.2, lod) * 0.12;
	color += textureLod(screen, SCREEN_UV - smear * 2.2, lod) * 0.12;
	COLOR = vec4(color.rgb, 1.0);
}
"""
## 마우스 감도가 바뀌는 범위(배)와 바뀌는 간격(초). 시연값.
const MOUSE_SLOW: float = 0.4
const MOUSE_FAST: float = 2.2
const MOUSE_SWITCH_SECONDS := Vector2(0.5, 1.3)

## 지금 걸린 맞힌 벌(내 화면). turn_effects.gd 가 정한다.
var penalty: Penalty = Penalty.NONE
var drowsy: bool = false
## 지금 눈꺼풀이 감긴 정도(0 = 뜸, 1 = 감음). 카메라 흔들림에도 쓴다.
var eyelid: float = 0.0
## 취기 흔들림 세기(0~1, 천천히 들어오고 나간다). round_camera.gd 가 읽는다.
var sway: float = 0.0
## 마우스 감도 배수(1 = 보통). round_camera.gd 가 곱한다.
var mouse_factor: float = 1.0

var _astigmatism: float = 0.0
var _time: float = 0.0
var _next_mouse_switch: float = 0.0
var _smear_rect: ColorRect
var _material: ShaderMaterial
var _top: ColorRect
var _bottom: ColorRect


func _ready() -> void:
	layer = 5
	_smear_rect = ColorRect.new()
	_smear_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_smear_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = ASTIGMATISM_SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_smear_rect.material = _material
	_smear_rect.visible = false
	add_child(_smear_rect)
	_top = _lid(Control.PRESET_TOP_WIDE)
	_bottom = _lid(Control.PRESET_BOTTOM_WIDE)


func _process(delta: float) -> void:
	_time += delta
	_astigmatism = move_toward(_astigmatism, 1.0 if penalty == Penalty.ASTIGMATISM else 0.0, delta * 1.6)
	_material.set_shader_parameter("amount", _astigmatism)
	_smear_rect.visible = _astigmatism > 0.01
	sway = move_toward(sway, 1.0 if penalty == Penalty.SWAY else 0.0, delta * 0.8)
	_update_mouse()
	# 졸림: 2.6초마다 천천히 감겼다가 번쩍 뜬다.
	var target: float = 0.0
	if drowsy:
		var cycle: float = fmod(_time, 2.6) / 2.6
		target = smoothstep(0.35, 0.85, cycle) * 0.82 if cycle < 0.9 else 0.0
	eyelid = move_toward(eyelid, target, delta * (0.9 if target > eyelid else 6.0))
	var height: float = get_viewport().get_visible_rect().size.y * 0.5 * eyelid
	_top.offset_bottom = height
	_bottom.offset_top = -height
	_top.visible = eyelid > 0.005
	_bottom.visible = _top.visible


## 마우스 벌: 정해진 간격마다 감도를 느림·빠름 사이에서 갑자기 바꾼다(같은 쪽이 두 번 연달아 나오지 않게 번갈아).
func _update_mouse() -> void:
	if penalty != Penalty.MOUSE:
		mouse_factor = 1.0
		return
	if _time < _next_mouse_switch:
		return
	_next_mouse_switch = _time + randf_range(MOUSE_SWITCH_SECONDS.x, MOUSE_SWITCH_SECONDS.y)
	mouse_factor = randf_range(MOUSE_SLOW, 0.75) if mouse_factor >= 1.0 else randf_range(1.5, MOUSE_FAST)


## 졸음 눈꺼풀 한 장(화면 위 또는 아래를 덮는 어두운 띠).
func _lid(preset: Control.LayoutPreset) -> ColorRect:
	var lid := ColorRect.new()
	lid.color = Color("0c0806")
	lid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lid.set_anchors_and_offsets_preset(preset)
	lid.visible = false
	add_child(lid)
	return lid
