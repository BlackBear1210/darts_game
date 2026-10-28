extends CanvasLayer
## 내 화면에만 걸리는 방해 효과. HUD(레이어 10)보다 아래에 깔려 UI 글자는 흐려지지 않는다.
## 흐림: 다른 사람을 다트로 맞힌 벌칙 — 내 차례가 끝날 때까지 화면이 뿌옇다(사용자 기획 2026-10-28).
## 졸림: 졸림 카드 — 눈꺼풀이 자꾸 내려와 화면 위아래가 감긴다.

const BLUR_SHADER := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float lod = amount * 4.5;
	vec2 spread = amount * vec2(0.006, 0.0105);
	vec4 color = textureLod(screen, SCREEN_UV, lod);
	color += textureLod(screen, SCREEN_UV + vec2(spread.x, 0.0), lod);
	color += textureLod(screen, SCREEN_UV - vec2(spread.x, 0.0), lod);
	color += textureLod(screen, SCREEN_UV + vec2(0.0, spread.y), lod);
	color += textureLod(screen, SCREEN_UV - vec2(0.0, spread.y), lod);
	color /= 5.0;
	// 뿌연 유리: 밝은 안개를 조금 섞는다.
	color.rgb = mix(color.rgb, vec3(0.86, 0.84, 0.80), amount * 0.3);
	COLOR = vec4(color.rgb, 1.0);
}
"""

var blurred: bool = false
var drowsy: bool = false
## 지금 눈꺼풀이 감긴 정도(0 = 뜸, 1 = 감음). 카메라 흔들림에도 쓴다.
var eyelid: float = 0.0
var _amount: float = 0.0
var _time: float = 0.0
var _blur: ColorRect
var _material: ShaderMaterial
var _top: ColorRect
var _bottom: ColorRect


func _ready() -> void:
	layer = 5
	_blur = ColorRect.new()
	_blur.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = BLUR_SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_blur.material = _material
	_blur.visible = false
	add_child(_blur)
	_top = _lid(Control.PRESET_TOP_WIDE)
	_bottom = _lid(Control.PRESET_BOTTOM_WIDE)


func _process(delta: float) -> void:
	_time += delta
	_amount = move_toward(_amount, 1.0 if blurred else 0.0, delta * 1.6)
	_material.set_shader_parameter("amount", _amount)
	_blur.visible = _amount > 0.01
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


## 졸음 눈꺼풀 한 장(화면 위 또는 아래를 덮는 어두운 띠).
func _lid(preset: Control.LayoutPreset) -> ColorRect:
	var lid := ColorRect.new()
	lid.color = Color("0c0806")
	lid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lid.set_anchors_and_offsets_preset(preset)
	lid.visible = false
	add_child(lid)
	return lid
