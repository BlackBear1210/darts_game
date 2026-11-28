// [캐릭터 3안] 승인 모델 몸 그림(텍스처)의 피부·머리 색만 바꾼다 — art/characters/character_looks.gd 가 쓴다.
// 텍스처 색으로 피부(밝고 따뜻한 칸)·머리카락(어둡고 따뜻한 칸)을 가려 각각 새 색으로 바꾼다. 눈·옷 그림은 그대로.
// 앞면만 그리는 판(character_skin.gdshader)과 양면 판(character_skin_two_sided.gdshader)이 이 파일을 같이 쓴다.
//
// 인형 머리(vertex_paint) — 2026-11-28 v3: 새 로우폴리 머리는 그림이 없고, 정점 색(sRGB)에 피부·흰자·눈동자·입·눈썹 색을,
//   정점 알파에 거칠기를 실었다(character_looks.gd _doll_head). 몸(목)과 같은 셰이더·같은 빛 계산이라 목 이음새에 차이가 없다.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// 새 피부색 / 원래 피부색(선형 색 공간 비율). 그림의 명암은 그대로 남는다.
uniform vec3 skin_mul = vec3(1.0);
// 새 피부색(선형). 그림 머리카락·눈썹을 지운 자리를 이 색으로 칠한다.
uniform vec3 skin_new = vec3(0.6, 0.4, 0.3);
uniform vec3 hair_new = vec3(0.05);
uniform vec3 brow_new = vec3(0.03);
// 원래 머리색 밝기(선형). 머리카락 명암을 새 색에 옮길 때 기준.
uniform float hair_ref_lum = 0.03;
// 그림 전체가 피부인 면(목). 2026-11-28: 그림 명암 대신 새 피부색 한 색 — 인형 머리(단색)와 목 이음새에서 밝기 띠가 생기지 않게.
uniform bool all_skin = false;
uniform bool vertex_paint = false;

void fragment() {
	if (vertex_paint) {
		vec3 sc = COLOR.rgb;
		ALBEDO = mix(sc / 12.92, pow((sc + 0.055) / 1.055, vec3(2.4)), step(0.04045, sc));
		ROUGHNESS = COLOR.a;
		SPECULAR = 0.35;
	} else {
		vec3 c = texture(albedo_tex, UV).rgb;
		vec3 s = pow(max(c, vec3(0.0)), vec3(1.0 / 2.2));
		float v = max(s.r, max(s.g, s.b));
		float warm = s.r - s.b;
		float hair_w = (1.0 - smoothstep(0.42, 0.56, v)) * smoothstep(0.03, 0.09, warm);
		float skin_w = smoothstep(0.40, 0.58, v) * smoothstep(0.13, 0.24, warm);
		if (all_skin) { skin_w = 1.0; hair_w = 0.0; }
		float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));
		vec3 hair_c = hair_new * clamp(lum / hair_ref_lum, 0.45, 1.9);
		vec3 outc = mix(c, c * skin_mul, skin_w * (1.0 - hair_w));
		outc = mix(outc, hair_c, hair_w);
		if (all_skin) { outc = skin_new; }
		ALBEDO = outc;
		ROUGHNESS = 0.88;
		SPECULAR = 0.35;
	}
}
