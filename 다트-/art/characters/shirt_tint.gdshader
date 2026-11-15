// 선수 티셔츠 색 바꾸기(2026-11-15 꾸미기 방 "옷 색"). 디자인 담당 소유. 쓰는 곳: art/characters/player_outfit.gd tint_shirt.
//
// 선수 캐릭터(Tripo 리깅 모델)는 몸통 조각(tripo_part_0) 한 장의 그림에 티셔츠(어두운 자주)와 팔 피부가 같이 그려져 있다.
// 그림을 새로 그리지 않고, 그림의 색으로 "티셔츠 칸"을 골라 그 칸만 고른 색으로 다시 칠한다.
//   - 티셔츠: 빨강 − 파랑 ≈ 0(자주·회색 계열, 선형 색 값 −0.01~0.03 — 2026-11-15 그림 실측)
//   - 피부  : 빨강 − 파랑 ≈ 0.4~0.8(주황)
//   → 그 차이가 0.04~0.12 사이에서 부드럽게 갈라진다(경계 픽셀이 계단처럼 보이지 않게).
// 원래 그림의 명암(주름·그늘)은 밝기 비율로 남긴다: 새 색 × (그 픽셀 밝기 ÷ 티셔츠 평균 밝기 0.032).
// 원래 재질의 노멀맵·거칠기·금속 그림은 그대로 받아 쓴다(빛 받는 느낌이 원래 몸과 같다).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D metallic_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform bool use_normal = false;
uniform float normal_scale = 1.0;
uniform float roughness = 1.0;
uniform float metallic = 0.0;
uniform float specular = 0.5;
// 거칠기·금속을 그림의 어느 칸(R·G·B·A)에서 읽는지(StandardMaterial3D 의 *_texture_channel 과 같은 뜻).
uniform vec4 roughness_channel = vec4(0.0, 1.0, 0.0, 0.0);
uniform vec4 metallic_channel = vec4(0.0, 0.0, 1.0, 0.0);
// 새 티셔츠 색. 원래 색 그대로면 tint = 0.
uniform vec3 shirt_color : source_color = vec3(0.24, 0.15, 0.22);
uniform float tint = 1.0;
// 티셔츠 칸의 평균 밝기(선형). 밝은 색으로 칠해도 원래 주름 명암이 남게 이 값으로 나눈다.
const float SHIRT_LUMA = 0.032;

void fragment() {
	vec3 base = texture(albedo_tex, UV).rgb;
	float shirt_mask = 1.0 - smoothstep(0.04, 0.12, base.r - base.b);
	float luma = dot(base, vec3(0.299, 0.587, 0.114));
	vec3 painted = shirt_color * clamp(luma / SHIRT_LUMA, 0.35, 1.6);
	ALBEDO = mix(base, painted, shirt_mask * tint);
	ROUGHNESS = roughness * dot(texture(roughness_tex, UV), roughness_channel);
	METALLIC = metallic * dot(texture(metallic_tex, UV), metallic_channel);
	SPECULAR = specular;
	if (use_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = normal_scale;
	}
}
