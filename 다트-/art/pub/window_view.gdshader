// 펍 아치 창 밖 풍경: 밤거리 그림. 2026-11-08, 디자인 담당 소유.
// 사용자 지적 "창문이라고 설치한 모형에 밖의 풍경이 안 나오는데 그냥 그림을 붙여 주는 게 좋을 것 같다":
//   예전 창 = 청록 단색 유리 + 아래 갈색 띠뿐이라 벽에 붙은 판처럼 보였다.
//   → 창 유리 자리에 밤거리 그림을 그린다: 하늘(별·달) · 먼 빌딩 실루엣 · 길 건너 건물(불 켜진 창·네온 간판) · 가로등 · 길바닥.
//
// [왜 그림 파일(PNG) 대신 셰이더인가]
//   - 그림 파일은 편집기가 import 해야 열린다(열린 편집기 + 새 PNG = 시험이 깨지는 함정). 셰이더는 글자 파일이라 바로 열린다.
//   - 풍경을 유리 뒤 여러 깊이(가로등 7m · 건물 18m · 스카이라인 60m)에 놓고 눈 위치에서 광선을 쏴 그린다 →
//     걸어 다니면 가까운 것이 더 많이 움직여(시차) "창 밖"처럼 보인다. 창마다 달·건물 배치가 다르다(창 위치로 씨앗).
//
// 좌표: 이 메시의 로컬 공간 = 창 유리 면(z 0), +Z = 방 안쪽, y = 바닥에서의 높이(m). 그래서 정적 묶기(art/static_batch.gd)에서
//   빼야 한다(묶이면 로컬 좌표가 사라진다 — NO_BATCH_NAMES 의 "WindowView").
// 밖은 방 조명을 받지 않으므로 unshaded(스스로 보이는 그림)다. 전체 밝기는 brightness 로 맞춘다.
shader_type spatial;
render_mode unshaded, cull_back;

uniform vec3 sky_top : source_color = vec3(0.035, 0.06, 0.15);
uniform vec3 sky_horizon : source_color = vec3(0.24, 0.19, 0.33);
uniform vec3 city_haze : source_color = vec3(0.45, 0.30, 0.30);      // 지평선 근처 도시 불빛 안개
uniform vec3 far_building : source_color = vec3(0.075, 0.08, 0.16);
uniform vec3 mid_building : source_color = vec3(0.15, 0.11, 0.15);
uniform vec3 mid_building_alt : source_color = vec3(0.11, 0.10, 0.17);
uniform vec3 window_warm : source_color = vec3(1.0, 0.78, 0.45);
uniform vec3 window_cool : source_color = vec3(0.55, 0.78, 1.0);
uniform vec3 neon_a : source_color = vec3(1.0, 0.35, 0.66);
uniform vec3 neon_b : source_color = vec3(0.23, 0.9, 0.86);
uniform vec3 street : source_color = vec3(0.09, 0.08, 0.10);
uniform vec3 lamp_light : source_color = vec3(1.0, 0.8, 0.5);
uniform float brightness = 1.0;
// 유리 반사 줄(아주 옅게) — 그림이 아니라 유리 너머로 보인다는 느낌.
uniform float glass_streak = 0.05;

varying vec3 local_pos;
varying vec3 cam_local;
varying float seed;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	local_pos = VERTEX;
	cam_local = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	seed = hash(NODE_POSITION_WORLD.xz * 0.37);
}

// 유리 뒤 depth(m) 떨어진 세로 판과 만나는 점(x, y). ray = 눈 → 유리 점 방향.
vec2 hit_at(vec3 ray, float depth) {
	float t = (-depth - local_pos.z) / ray.z;
	return (local_pos + ray * t).xy;
}

// 하늘: 높이각에 따른 색 띠 + 지평선 도시 안개 + 별 + 달.
vec3 sky(vec3 ray) {
	float elevation = ray.y / max(length(ray.xz), 0.001);
	vec3 col = mix(sky_horizon, sky_top, smoothstep(0.02, 0.75, elevation));
	col = mix(col, city_haze, (1.0 - smoothstep(-0.02, 0.14, elevation)) * 0.65);
	// 별: 하늘을 격자로 나눠 칸마다 한 점(일부 칸만).
	vec2 q = vec2(ray.x / -ray.z, elevation) * 46.0;
	vec2 cell = floor(q);
	float pick = hash(cell + seed * 17.0);
	if (pick > 0.9 && elevation > 0.18) {
		vec2 spot = vec2(hash(cell + 3.1), hash(cell + 7.7)) * 0.6 + 0.2;
		float twinkle = 0.65 + 0.35 * sin(TIME * (1.5 + pick * 3.0) + pick * 40.0);
		col += vec3(0.9, 0.92, 1.0) * smoothstep(0.09, 0.0, length(fract(q) - spot)) * twinkle * 0.8;
	}
	// 달: 창마다 다른 자리. 둥근 판 + 넓은 빛무리.
	vec3 moon_dir = normalize(vec3(mix(-0.55, 0.55, seed), 0.5 + 0.25 * fract(seed * 7.0), -1.0));
	float facing = dot(normalize(ray), moon_dir);
	col += vec3(1.0, 0.95, 0.82) * smoothstep(0.99935, 0.99955, facing) * 1.1;
	col += vec3(0.55, 0.5, 0.6) * pow(max(facing, 0.0), 220.0) * 0.45;
	return col;
}

// 건물 줄 하나: x 를 cell 폭 칸으로 나눠 칸마다 높이·색이 다른 건물. 틈(gap)은 비워 뒤가 보인다.
// 반환: x = 건물 안인지(0/1), y = 칸 번호, z = 칸 안 x(0~1).
vec3 building(vec2 p, float cell, float h_min, float h_max, float gap, float salt) {
	float id = floor(p.x / cell);
	float u = fract(p.x / cell);
	float height = mix(h_min, h_max, hash(vec2(id, salt + seed * 5.0)));
	float inside = step(gap, u) * step(u, 1.0 - gap) * step(p.y, height) * step(0.0, p.y);
	return vec3(inside, id, u);
}

void fragment() {
	vec3 ray = normalize(local_pos - cam_local);
	// 방 안에서 보면 ray.z < 0(유리 너머). 거의 옆에서 보는 각도는 잘라서 무한대로 튀지 않게 한다.
	ray.z = min(ray.z, -0.08);
	ray = normalize(ray);
	vec3 col = sky(ray);

	// 먼 스카이라인(60m): 어두운 실루엣 + 드문드문 작은 불빛.
	vec2 far_p = hit_at(ray, 60.0);
	vec3 far_b = building(far_p, 9.0, 10.0, 34.0, 0.03, 1.0);
	if (far_b.x > 0.5) {
		col = far_building;
		// 창 칸은 크게(3.2 × 4.0m): 60m 밖 작은 칸은 화면에서 1~2px 이라 반짝반짝 깨져 보였다.
		vec2 w = vec2(far_p.x / 3.2, far_p.y / 4.0);
		vec2 wf = fract(w);
		float lit = step(0.84, hash(floor(w) + far_b.y * 13.0));
		col += window_warm * 0.35 * lit * step(0.3, wf.x) * step(wf.x, 0.7) * step(0.35, wf.y) * step(wf.y, 0.7);
		// 꼭대기 빨간 항공등(키 큰 건물만).
		float top = mix(10.0, 34.0, hash(vec2(far_b.y, 1.0 + seed * 5.0)));
		if (top > 26.0) {
			float blink = step(0.5, fract(TIME * 0.5 + far_b.y * 0.13));
			col += vec3(1.0, 0.2, 0.15) * blink * smoothstep(0.7, 0.0, length(vec2((far_b.z - 0.5) * 9.0, far_p.y - top - 0.5)));
		}
	}

	// 길 건너 건물(18m): 3~5층, 칸마다 다른 벽색, 불 켜진 창(따뜻한 빛·TV 푸른빛), 가끔 네온 간판, 1층 가게 불빛.
	vec2 mid_p = hit_at(ray, 18.0);
	vec3 mid_b = building(mid_p, 7.0, 8.0, 15.5, 0.025, 2.0);
	if (mid_b.x > 0.5) {
		float kind = hash(vec2(mid_b.y, 4.0 + seed));
		col = mix(mid_building, mid_building_alt, step(0.5, kind));
		// 층 띠(조금 밝은 선) — 그림 같은 단순한 결.
		col += vec3(0.03) * step(0.93, fract(mid_p.y / 3.0));
		vec2 w = vec2(mid_p.x / 1.75, mid_p.y / 3.0);
		vec2 wf = fract(w);
		float in_window = step(0.22, wf.x) * step(wf.x, 0.78) * step(0.3, wf.y) * step(wf.y, 0.8) * step(3.0, mid_p.y);
		float roll = hash(floor(w) + mid_b.y * 7.0 + seed);
		vec3 glow = roll > 0.86 ? window_cool * 0.7 : window_warm * (0.55 + 0.45 * roll);
		// 커튼 그림자: 창 위쪽 절반이 조금 어둡다.
		glow *= mix(1.0, 0.7, step(0.6, wf.y));
		col = mix(col, glow, in_window * step(0.5, roll));
		col = mix(col, vec3(0.04, 0.04, 0.07), in_window * (1.0 - step(0.5, roll)));
		// 1층 가게 진열창(0.4~2.4m): 따뜻한 빛.
		float shop = step(0.1, mid_b.z) * step(mid_b.z, 0.9) * step(0.4, mid_p.y) * step(mid_p.y, 2.4);
		col = mix(col, window_warm * 0.8, shop * step(0.35, kind));
		// 네온 간판(건물 셋 중 하나): 2층 높이 가로 띠, 테두리만 밝은 관.
		if (hash(vec2(mid_b.y, 9.0 + seed)) > 0.62) {
			vec2 sign_p = vec2(mid_b.z, (mid_p.y - 3.3) / 0.9);
			float box = step(0.25, sign_p.x) * step(sign_p.x, 0.75) * step(0.0, sign_p.y) * step(sign_p.y, 1.0);
			float edge = box * (1.0 - step(0.29, sign_p.x) * step(sign_p.x, 0.71) * step(0.12, sign_p.y) * step(sign_p.y, 0.88));
			vec3 tone = hash(vec2(mid_b.y, 11.0)) > 0.5 ? neon_a : neon_b;
			col = mix(col, vec3(0.05, 0.03, 0.08), box);
			col += tone * 1.6 * edge * (0.85 + 0.15 * sin(TIME * 7.0 + mid_b.y));
		}
	}

	// 길바닥: 광선이 건물(18m)보다 먼저 땅(y 0)에 닿으면 길. 가로등 불빛 웅덩이.
	float lamp_x = mix(-2.6, 2.6, fract(seed * 13.7));
	if (ray.y < 0.0) {
		float t_ground = -local_pos.y / ray.y;
		vec3 g = local_pos + ray * t_ground;
		if (-g.z < 18.0) {
			col = street;
			// 보도와 차도 경계(연석) 선.
			col += vec3(0.05) * smoothstep(0.08, 0.0, abs(-g.z - 9.0));
			float pool = exp(-pow(length(vec2(g.x - lamp_x, -g.z - 7.0)) / 2.4, 2.0));
			col += lamp_light * pool * 0.45;
		}
	}

	// 가로등(7m): 가는 기둥 + 등 머리 + 빛무리(뒤 그림 위에 더한다).
	vec2 lamp_p = hit_at(ray, 7.0);
	float pole = step(abs(lamp_p.x - lamp_x), 0.07) * step(0.0, lamp_p.y) * step(lamp_p.y, 4.3);
	col = mix(col, vec3(0.03, 0.03, 0.04), pole);
	vec2 head = vec2(lamp_x, 4.45);
	float d_head = length(lamp_p - head);
	col = mix(col, lamp_light * 1.8, smoothstep(0.24, 0.19, d_head));
	col += lamp_light * exp(-d_head * 1.1) * 0.35;

	// 유리: 비스듬한 옅은 반사 줄 두 개(유리 면 기준 — 시차 없이 유리에 붙어 있다).
	float diag = local_pos.x * 0.8 + local_pos.y * 0.6;
	col += vec3(glass_streak) * (smoothstep(0.1, 0.0, abs(fract(diag * 0.55) - 0.3)) + 0.6 * smoothstep(0.05, 0.0, abs(fract(diag * 0.55) - 0.42)));

	ALBEDO = col * brightness;
}
