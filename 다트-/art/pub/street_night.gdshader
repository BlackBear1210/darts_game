// 펍 창 밖 3D 밤거리 재질(2026-11-16). 디자인 담당 소유. 만드는 곳 = art/pub/street_outside.gd.
// 사용자 지적 "밖의 풍경이 고도 엔진 안에서 안 보인다 · 건물들이 전부 누워 있다 · 하늘이 2D 라 3D 처럼 느껴지게":
//   예전 창 = 유리판에 그림(PNG·SVG)을 그리는 셰이더 → 이제 벽에 진짜 창 구멍을 내고 바깥에 3D 거리(건물·가로등·나무·차)를 세웠다.
//
// [왜 스스로 빛나는(unshaded) 재질인가]
//   바깥은 방 조명(펜던트·벽등·채움빛)을 받으면 안 된다. 받으면 밤거리가 방 안처럼 노랗게 물든다.
//   그래서 빛 계산을 엔진에 맡기지 않고 여기서 직접 한다: 달빛(한 방향) + 하늘빛 + 가로등 불빛 웅덩이 + 먼 곳 안개.
//   → 방 안 조명·그림자·SSAO 와 서로 영향을 주지 않는다(빛 새기 없음).
//
// [색은 어디서 오나]
//   RG Poly 로 구운 모델 = 정점 색(sRGB). 정점 색 알파 0 = 유리창 면(굽기 옵션 "mark_glass").
//   정점 색이 없는 도형(길·보도·잔디 상자)은 흰색이 들어오므로 base_color 로 칠한다.
//
// [인스턴스마다 다른 값](노드의 instance_shader_parameters)
//   glass_mode : 0 = 건물 창(창마다 무작위로 불이 켜짐) · 1 = 늘 켜진 불(가로등 유리) · 2 = 차 유리(어둡게 반짝)
//   base_color : 정점 색에 곱하는 색(도형 바닥은 이 색이 곧 바닥 색)
//   lit_share  : 건물 창 가운데 불 켜진 몫(0~1)
shader_type spatial;
render_mode unshaded, cull_back;

instance uniform float glass_mode = 0.0;
instance uniform vec4 base_color : source_color = vec4(1.0);
instance uniform float lit_share = 0.45;
// 0 보다 크면 빛 계산 없이 base_color × 이 값으로 스스로 빛난다(전구·전조등·관람차 불빛). 1 넘으면 빛 번짐(glow)이 생긴다.
instance uniform float self_glow = 0.0;
// 겉 무늬: 0 없음 · 1 벽돌(펍 건물 바깥 벽) · 2 보도 타일(윗면만).
instance uniform float pattern = 0.0;

// 달빛: 방향(빛이 오는 쪽) · 색. 하늘빛(그늘 쪽 밝기).
uniform vec3 moon_dir = vec3(0.35, 0.75, 0.55);
uniform vec3 moon_color : source_color = vec3(0.52, 0.58, 0.88);
uniform vec3 sky_light : source_color = vec3(0.17, 0.18, 0.32);
uniform vec3 ground_light : source_color = vec3(0.09, 0.08, 0.10);
// 가로등 불빛 웅덩이: xyz = 전구 자리(세계 좌표), w = 닿는 거리(m). 최대 32개.
uniform vec4 lamps[32];
uniform int lamp_count = 0;
uniform vec3 lamp_color : source_color = vec3(1.0, 0.72, 0.45);
uniform float lamp_strength = 1.05;
// 창 불빛 색 두 가지(따뜻한 전등 · 푸른 TV).
uniform vec3 window_warm : source_color = vec3(1.0, 0.78, 0.46);
uniform vec3 window_tv : source_color = vec3(0.55, 0.75, 1.0);
// 먼 곳 안개(밤하늘 지평선 색으로 흐려진다 — 거리감).
uniform vec3 haze_color : source_color = vec3(0.20, 0.17, 0.30);
uniform float haze_start = 30.0;
uniform float haze_end = 190.0;
uniform float haze_max = 0.78;

varying vec3 world_pos;
varying vec3 world_normal;

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045)));
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

// 줄눈(벽돌·타일 사이 홈) 무늬: 1 = 줄눈, 0 = 벽돌 면. cell = 한 칸 크기(m), shift = 줄마다 반 칸 엇갈림.
// 멀어서 한 칸이 몇 픽셀이 안 되면 무늬를 지운다(자글자글한 물결 무늬 방지).
// fw = 화면 한 픽셀이 덮는 길이(m, fragment 에서 fwidth 로 재서 넘긴다).
float joints(vec2 p, vec2 cell, bool shift, float fw, out vec2 id) {
	float row = floor(p.y / cell.y);
	vec2 q = vec2(p.x / cell.x + (shift ? mod(row, 2.0) * 0.5 : 0.0), p.y / cell.y);
	id = floor(q);
	vec2 f = fract(q);
	vec2 edge = min(f, 1.0 - f) * cell;
	float line = 1.0 - smoothstep(0.007, 0.014 + fw, min(edge.x, edge.y));
	return line * (1.0 - smoothstep(0.02, 0.05, fw));
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 albedo = srgb_to_linear(COLOR.rgb) * base_color.rgb;
	if (pattern > 0.5 && pattern < 1.5 && abs(n.y) < 0.5) {
		// 벽돌: 벽을 따라가는 축(x 또는 z) × 높이. 벽돌마다 밝기를 조금씩 다르게.
		vec2 p = vec2(abs(n.x) > abs(n.z) ? world_pos.z : world_pos.x, world_pos.y);
		vec2 id;
		float line = joints(p, vec2(0.24, 0.085), true, length(fwidth(p)), id);
		albedo *= (0.9 + 0.2 * hash3(vec3(id, floor(world_pos.x + world_pos.z)))) * mix(1.0, 0.45, line);
	} else if (pattern > 1.5 && n.y > 0.5) {
		// 보도 타일(0.6m 네모).
		vec2 id;
		float line = joints(world_pos.xz, vec2(0.6, 0.6), false, length(fwidth(world_pos.xz)), id);
		albedo *= (0.94 + 0.12 * hash3(vec3(id, 3.0))) * mix(1.0, 0.6, line);
	}
	// 달빛 + 하늘빛(위를 볼수록 밝다) + 땅에서 올라오는 어두운 빛.
	float up = n.y * 0.5 + 0.5;
	vec3 light = moon_color * max(dot(n, normalize(moon_dir)), 0.0) + mix(ground_light, sky_light, up);
	// 가로등 웅덩이: 가까울수록 · 전구 쪽을 볼수록 따뜻하게.
	for (int i = 0; i < lamp_count; i++) {
		vec3 to_lamp = lamps[i].xyz - world_pos;
		float d = length(to_lamp);
		float fall = clamp(1.0 - d / lamps[i].w, 0.0, 1.0);
		light += lamp_color * lamp_strength * fall * fall * (0.35 + 0.65 * max(dot(n, to_lamp / max(d, 0.001)), 0.0));
	}
	vec3 col = albedo * light;
	if (COLOR.a < 0.5) {
		// 유리창 면.
		if (glass_mode < 0.5) {
			// 건물 창: 창 하나 크기 칸(가로 1.6m · 세로 1.5m)마다 켜짐·꺼짐을 정한다. 켜진 창 몇 개는 푸른 TV 빛이 일렁인다.
			vec3 cell = floor(world_pos / vec3(1.6, 1.5, 1.6) + n * 0.5);
			float pick = hash3(cell);
			float tone = hash3(cell + 17.3);
			vec3 dark = vec3(0.025, 0.035, 0.07) + moon_color * 0.05 * max(n.y + 0.3, 0.0);
			vec3 lit = window_warm * (1.25 + 0.75 * tone);
			if (tone > 0.86) {
				lit = window_tv * (0.9 + 0.35 * sin(TIME * (3.0 + tone * 4.0) + pick * 30.0));
			}
			col = pick < lit_share ? lit : dark;
		} else if (glass_mode < 1.5) {
			col = window_warm * 2.2;
		} else {
			// 차 유리: 어두운 유리에 하늘이 살짝 비친다.
			col = vec3(0.03, 0.04, 0.08) + sky_light * 0.35 * up;
		}
	}
	if (self_glow > 0.0) {
		col = base_color.rgb * self_glow;
	}
	// 먼 곳은 지평선 안개로 흐려진다(불 켜진 창·전구는 조금 덜 흐려져 먼 도시 불빛이 남는다).
	float far = smoothstep(haze_start, haze_end, distance(world_pos, CAMERA_POSITION_WORLD)) * haze_max;
	float keep = (COLOR.a < 0.5 || self_glow > 0.0) ? 0.45 : 1.0;
	ALBEDO = mix(col, haze_color, far * keep);
}
