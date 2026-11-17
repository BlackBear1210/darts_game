// 펍 창 밖 밤하늘 돔(2026-11-16). 디자인 담당 소유. 만드는 곳 = art/pub/street_outside.gd(_sky).
// 예전 하늘은 창 유리에 그린 그림이라 창마다 다른 하늘이 보였다 → 방 전체를 감싸는 큰 공(안쪽 면) 하나에 그린다.
// 어느 창에서 보든 같은 하늘·같은 별 자리 → 걸어 다니면 건물·달·관람차가 진짜 깊이로 움직이고 하늘은 멀리 그대로 있다.
//   - 높이각에 따른 색 띠(지평선 보라 안개 → 위 짙은 남색) + 지평선 도시 불빛(따뜻한 띠)
//   - 별: 방향을 3D 칸으로 나눠 칸마다 한 점, 반짝임 · 옅은 은하수 띠
//   - 지평선 아래(땅 쪽)는 먼 안개 색 — 바닥 끝이 보여도 하늘과 이어진다.
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled, depth_draw_opaque;

uniform vec3 center = vec3(0.0);
uniform vec3 top_color : source_color = vec3(0.02, 0.035, 0.11);
uniform vec3 mid_color : source_color = vec3(0.07, 0.07, 0.20);
uniform vec3 horizon_color : source_color = vec3(0.26, 0.17, 0.32);
uniform vec3 city_glow : source_color = vec3(0.55, 0.32, 0.28);
uniform vec3 below_color : source_color = vec3(0.20, 0.17, 0.30);
uniform float star_density = 0.92;
uniform float star_brightness = 1.6;

varying vec3 dir;

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void vertex() {
	dir = normalize((MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - center);
}

void fragment() {
	vec3 d = normalize(dir);
	float e = d.y;
	vec3 col = mix(horizon_color, mid_color, smoothstep(0.0, 0.22, e));
	col = mix(col, top_color, smoothstep(0.18, 0.75, e));
	col += city_glow * (1.0 - smoothstep(-0.02, 0.12, e)) * 0.55;
	// 은하수: 기울어진 큰 원 둘레의 옅은 띠.
	float band = exp(-pow(dot(d, normalize(vec3(0.35, 0.55, -0.76))) / 0.16, 2.0));
	col += vec3(0.10, 0.09, 0.16) * band * smoothstep(0.05, 0.4, e);
	// 별: 방향을 3D 격자로 나눠 칸마다 한 점(일부 칸만). 지평선 근처는 안개에 묻힌다.
	vec3 q = d * 140.0;
	vec3 cell = floor(q);
	float pick = hash3(cell);
	if (pick > star_density && e > 0.06) {
		vec3 spot = vec3(hash3(cell + 3.1), hash3(cell + 7.7), hash3(cell + 1.3)) * 0.6 + 0.2;
		float size = 0.10 + 0.12 * hash3(cell + 9.9) + band * 0.05;
		float twinkle = 0.6 + 0.4 * sin(TIME * (1.3 + pick * 3.0) + pick * 50.0);
		float star = smoothstep(size, 0.0, length(fract(q) - spot));
		vec3 tint = mix(vec3(0.85, 0.9, 1.0), vec3(1.0, 0.85, 0.7), hash3(cell + 4.4));
		col += tint * star * twinkle * star_brightness * smoothstep(0.06, 0.3, e);
	}
	// 지평선 아래 = 먼 안개(바닥이 끝나는 곳이 하늘과 자연스럽게 이어진다).
	col = mix(col, below_color, smoothstep(0.0, -0.08, e));
	ALBEDO = col;
}
