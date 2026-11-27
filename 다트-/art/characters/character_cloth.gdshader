// [캐릭터 3안] 옷 색 구역 — 상의·바지·신발을 쉬는 자세 좌표(m)로 나눠 칠한다. art/characters/character_looks.gd 가 쓴다.
// 정점이 쉬는 자세 좌표를 실어 온다: UV = (x, y), UV2.x = z  (정면 −Z, 캐릭터 오른쪽 +X, 바닥 y = 0).
// 몸이 움직여도 무늬가 옷에 붙어 다닌다(좌표가 정점에 구워져 있으므로).
// pattern: 0 = 한 색 · 1 = 준 상의 · 2 = 솜 상의 · 3 = 온 상의 · 4 = 신발(밑창 줄)
// 색 칸: c_main = 큰 면(꾸미기 "옷 색"을 고르면 이 칸만 바뀐다) · c_a·c_b = 덧색.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform int pattern = 0;
uniform vec4 c_main : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 c_a : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 c_b : source_color = vec4(0.5, 0.5, 0.5, 1.0);
// 신발: 이 높이(m) 아래는 밑창색(c_a).
uniform float sole_line = 0.018;

// 거리 d(음수 = 안쪽)를 화면 한 칸 폭으로 부드럽게 0~1 로(경계 계단 없애기).
float aa(float d) { float w = max(fwidth(d), 1e-6); return clamp(0.5 - d / w, 0.0, 1.0); }
// 가운데 c, 반너비 h 인 사각형까지 거리.
float sd_box(vec2 q, vec2 c, vec2 h) { vec2 e = abs(q - c) - h; return length(max(e, 0.0)) + min(max(e.x, e.y), 0.0); }

// 준: 가지색 오버셔츠 · 앞 가운데 크림 속셔츠 띠 · 왼쪽 아래 황토 큰 주머니(바느질 선)
vec3 jun_top(vec3 p) {
	vec3 col = c_main.rgb;
	float front = smoothstep(-0.005, -0.04, p.z);
	float strip = sd_box(p.xy, vec2(0.006, 1.02), vec2(0.026, 0.26));
	col = mix(col, c_a.rgb, aa(strip) * front);
	float pocket = sd_box(p.xy, vec2(-0.094, 0.928), vec2(0.058, 0.080));
	pocket = max(pocket, -((-0.036 - p.x) + (1.008 - p.y) - 0.028));
	col = mix(col, c_b.rgb, aa(pocket) * front);
	float stitch = abs(pocket + 0.006) - 0.0012;
	col = mix(col, c_b.rgb * 0.72, aa(stitch) * front * aa(pocket));
	return col;
}

// 솜: 아이보리 티셔츠(c_main) · 계단형 사선 청록 패널(c_a, 몸통) · 왼쪽 가슴 짙은 청록 주머니(c_b)
vec3 som_top(vec3 p) {
	vec3 col = c_main.rgb;
	float torso = 1.0 - smoothstep(0.17, 0.205, abs(p.x));
	float front = smoothstep(0.03, -0.03, p.z);
	// 앞: 캐릭터 오른쪽(+X)은 낮고 왼쪽 어깨로 갈수록 올라가는 계단 사선
	float yb_front = (p.x > 0.012) ? (1.080 + (0.15 - p.x) * 0.12) : (1.150 + (0.012 - p.x) * 0.55);
	float yb_back = 1.105 + (0.15 - p.x) * 0.06;
	float yb = mix(yb_back, yb_front, front);
	col = mix(col, c_a.rgb, aa(p.y - yb) * torso);
	float pocket = sd_box(p.xy, vec2(-0.082, 1.088), vec2(0.040, 0.046));
	col = mix(col, c_b.rgb, aa(pocket) * smoothstep(0.0, -0.03, p.z));
	float flap = sd_box(p.xy, vec2(-0.082, 1.124), vec2(0.040, 0.010));
	col = mix(col, c_b.rgb * 0.75, aa(flap) * smoothstep(0.0, -0.03, p.z));
	return col;
}

// 온: 벽돌색 몸판(c_main) · 양 어깨를 잇는 크림 요크(c_a) · 가운데 짧은 플래킷
vec3 on_top(vec3 p) {
	vec3 col = c_main.rgb;
	float torso = 1.0 - smoothstep(0.215, 0.24, abs(p.x));
	float yoke_y = 1.172 + 0.32 * max(abs(p.x) - 0.085, 0.0);
	col = mix(col, c_a.rgb, aa(yoke_y - p.y) * torso);
	float placket = sd_box(p.xy, vec2(0.0, 1.12), vec2(0.024, 0.06));
	col = mix(col, c_a.rgb, aa(placket) * smoothstep(0.0, -0.03, p.z));
	float line = abs(p.x) - 0.0012;
	col = mix(col, c_a.rgb * 0.8, aa(line) * aa(sd_box(p.xy, vec2(0.0, 1.11), vec2(0.01, 0.05))) * smoothstep(0.0, -0.03, p.z));
	return col;
}

void fragment() {
	vec3 p = vec3(UV.x, UV.y, UV2.x);
	vec3 col = c_main.rgb;
	if (pattern == 1) col = jun_top(p);
	else if (pattern == 2) col = som_top(p);
	else if (pattern == 3) col = on_top(p);
	else if (pattern == 4) col = mix(c_a.rgb, c_main.rgb, aa(sole_line - p.y));
	ALBEDO = col;
	ROUGHNESS = 0.92;
	SPECULAR = 0.3;
}
