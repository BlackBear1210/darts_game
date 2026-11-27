// [캐릭터 3안] 승인 모델 몸 그림(텍스처)의 피부·머리 색만 바꾼다 — art/characters/character_looks.gd 가 쓴다.
// 텍스처 색으로 피부(밝고 따뜻한 칸)·머리카락(어둡고 따뜻한 칸)을 가려 각각 새 색으로 바꾼다. 눈·옷 그림은 그대로.
// 앞면만 그리는 판(character_skin.gdshader)과 양면 판(character_skin_two_sided.gdshader)이 이 파일을 같이 쓴다.
//
// 머리 면(is_head) — 2026-11-27 v2: 그림 속 머리카락·눈썹은 모두 살색으로 지운다.
//   머리카락은 캐릭터마다 새로 만든 입체 머리(CharacterParts)가, 눈썹은 이마 앞에 붙인 입체 눈썹이 맡는다.
//   (그림 눈썹은 튀어나온 눈알 뒤 이마에 납작하게 그려져 있어 "눈썹이 눈 안쪽에 박혀" 보였다.)
//   남기는 그림 선은 입술선(얼굴 앞 아래쪽)뿐이다 — 정점에 실어 온 쉬는 자세 좌표 UV2 = (y, z)로 고른다.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// 새 피부색 / 원래 피부색(선형 색 공간 비율). 그림의 명암은 그대로 남는다.
uniform vec3 skin_mul = vec3(1.0);
// 새 피부색(선형). 그림 머리카락·눈썹을 지운 자리를 이 색으로 칠한다.
uniform vec3 skin_new = vec3(0.6, 0.4, 0.3);
uniform vec3 hair_new = vec3(0.05);
uniform vec3 brow_new = vec3(0.03);
// 원래 머리색 밝기(선형). 머리카락 명암을 새 색에 옮길 때 기준.
uniform float hair_ref_lum = 0.03;
// 팔·다리처럼 그림 전체가 피부인 면.
uniform bool all_skin = false;
uniform bool is_head = false;

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	vec3 s = pow(max(c, vec3(0.0)), vec3(1.0 / 2.2));
	float v = max(s.r, max(s.g, s.b));
	float warm = s.r - s.b;
	float hair_w = (1.0 - smoothstep(0.42, 0.56, v)) * smoothstep(0.03, 0.09, warm);
	float skin_w = smoothstep(0.40, 0.58, v) * smoothstep(0.13, 0.24, warm);
	if (all_skin) { skin_w = 1.0; hair_w = 0.0; }
	float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));
	vec3 hair_c = hair_new * clamp(lum / hair_ref_lum, 0.45, 1.9);
	if (is_head) {
		// 얼굴 앞 아래(입술선·콧방울 선, 높이 1.56 m 아래 · 앞 z < -0.15)만 짙은 선으로 남기고, 나머지 그림 머리카락은 살색.
		float lips = step(UV2.x, 1.56) * step(UV2.y, -0.15);
		hair_c = mix(skin_new, brow_new * clamp(lum / hair_ref_lum, 0.6, 1.4), lips);
	}
	vec3 outc = mix(c, c * skin_mul, skin_w * (1.0 - hair_w));
	outc = mix(outc, hair_c, hair_w);
	ALBEDO = outc;
	ROUGHNESS = 0.88;
	SPECULAR = 0.35;
}
