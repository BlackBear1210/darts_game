// 펍 아치 창 밖 풍경: 만화 밤거리 그림. 2026-11-08, 디자인 담당 소유.
// 사용자 지적(오후) "창문이라고 설치한 모형에 밖의 풍경이 안 나오는데 그냥 그림을 붙여 주는 게 좋을 것 같다":
//   예전 창 = 청록 단색 유리 + 아래 갈색 띠뿐이라 벽에 붙은 판처럼 보였다 → 셰이더로 네모 빌딩 밤거리를 그렸다.
// 사용자 지적(저녁) "그림이 너무 아쉽다 — 캐주얼한 그림인데 재밌는 느낌으로":
//   네모 빌딩·가로등 → 손으로 그린 만화 그림 층(art/pub/pictures/window_*.svg)을 유리 뒤 깊이별로 붙인다.
//   - 먼 층 window_far.svg    : 스카이라인 · 대관람차 · 열기구 · 방송탑(유리 뒤 60m)
//   - 가운데 window_street.svg: 길 건너 건물 6채 — 창마다 고양이·춤·건배·TV, 네온 다트·맥주잔 간판, 빨랫줄(18m)
//   - 앞 층 window_front.svg  : 알전구 줄 · 가로등 위 고양이 · 목도리 새(6.5m)
//   - 달 window_moon.svg       : 다트가 꽂혀 "아야!" 하는 달(하늘 방향에 붙는다)
//   그림은 SVG(벡터)라 디자이너가 일러스트레이터·피그마에서 바로 고칠 수 있다. 크기(m)는 아래 *_size 와 맞춘다.
//
// [어떻게 그리나]
//   눈(카메라)에서 유리 점으로 광선을 쏴, 유리 뒤 깊이 d 의 세로 판과 만나는 점(x, y m)에서 그 층 그림을 읽는다.
//   → 걸어 다니면 가까운 층이 더 많이 움직여(시차) "창 밖"처럼 보인다. 창마다 그림의 다른 곳이 보인다(창 위치로 씨앗).
//   하늘 색·별·길바닥·유리 반사는 셰이더가 그린다(그림의 투명한 곳으로 하늘이 보인다).
//
// 좌표: 이 메시의 로컬 공간 = 창 유리 면(z 0), +Z = 방 안쪽, y = 바닥에서의 높이(m). 그래서 정적 묶기(art/static_batch.gd)에서
//   빼야 한다(묶이면 로컬 좌표가 사라진다 — NO_BATCH_NAMES 의 "WindowView").
// 밖은 방 조명을 받지 않으므로 unshaded(스스로 보이는 그림)다. 전체 밝기는 brightness 로 맞춘다.
shader_type spatial;
render_mode unshaded, cull_back;

// 그림 층(방 생성기 game_room_builder._window_view_material 이 넣는다).
uniform sampler2D far_layer : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D street_layer : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D front_layer : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D moon_picture : source_color, filter_linear_mipmap, repeat_disable;
// 층마다 (유리 뒤 깊이 m, 그림 한 장 폭 m, 그림 높이 m). 그림 아래 끝 = 땅(y 0). 그림 폭은 옆으로 이어 붙는다.
uniform vec3 far_size = vec3(60.0, 96.0, 48.0);
uniform vec3 street_size = vec3(18.0, 42.0, 16.0);
uniform vec3 front_size = vec3(6.5, 14.0, 6.0);
// 앞 층 그림에서 가로등이 서 있는 x(m) — 길바닥 불빛 웅덩이 자리.
uniform float front_lamp_x = 10.5;
// 달 반지름(라디안). 만화 느낌으로 실제 달보다 훨씬 크다.
uniform float moon_radius = 0.075;

uniform vec3 sky_top : source_color = vec3(0.035, 0.06, 0.15);
uniform vec3 sky_horizon : source_color = vec3(0.24, 0.19, 0.33);
uniform vec3 city_haze : source_color = vec3(0.45, 0.30, 0.30);      // 지평선 근처 도시 불빛 안개
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

// 그림 층 하나: size = (깊이, 폭, 높이), offset = 창마다 다른 가로 위치(m). 그림 위·아래 밖은 투명.
// (조건문 안에서 읽으면 밉맵 고르는 미분이 깨지므로 항상 읽고 마스크로 지운다.)
vec4 picture_layer(sampler2D picture, vec3 ray, vec3 size, float offset) {
	vec2 p = hit_at(ray, size.x);
	vec2 uv = vec2((p.x + offset) / size.y, 1.0 - p.y / size.z);
	vec4 c = texture(picture, uv);
	return c * step(0.0, uv.y) * step(uv.y, 1.0);
}

// 하늘: 높이각에 따른 색 띠 + 지평선 도시 안개 + 반짝이는 별.
vec3 sky(vec3 ray) {
	float elevation = ray.y / max(length(ray.xz), 0.001);
	vec3 col = mix(sky_horizon, sky_top, smoothstep(0.02, 0.75, elevation));
	col = mix(col, city_haze, (1.0 - smoothstep(-0.02, 0.14, elevation)) * 0.65);
	// 별: 하늘을 격자로 나눠 칸마다 한 점(일부 칸만).
	vec2 q = vec2(ray.x / -ray.z, elevation) * 46.0;
	vec2 cell = floor(q);
	float pick = hash(cell + seed * 17.0);
	if (pick > 0.88 && elevation > 0.18) {
		vec2 spot = vec2(hash(cell + 3.1), hash(cell + 7.7)) * 0.6 + 0.2;
		float twinkle = 0.65 + 0.35 * sin(TIME * (1.5 + pick * 3.0) + pick * 40.0);
		col += vec3(0.9, 0.92, 1.0) * smoothstep(0.09, 0.0, length(fract(q) - spot)) * twinkle * 0.8;
	}
	return col;
}

// 다트 꽂힌 달: 창마다 다른 하늘 방향에 그림을 붙이고 둘레에 빛무리. 살짝 둥실거린다.
vec3 moon(vec3 ray, vec3 col) {
	vec3 dir = normalize(vec3(mix(-0.5, 0.5, seed), 0.48 + 0.2 * fract(seed * 7.0) + 0.006 * sin(TIME * 0.8), -1.0));
	vec3 right = normalize(cross(dir, vec3(0.0, 1.0, 0.0)));
	vec3 up = cross(right, dir);
	float facing = dot(ray, dir);
	col += vec3(0.55, 0.5, 0.6) * pow(max(facing, 0.0), 200.0) * 0.5;
	vec2 q = vec2(dot(ray, right), dot(ray, up)) / max(facing, 0.01);
	vec2 uv = vec2(0.5 + q.x / (2.0 * moon_radius), 0.5 - q.y / (2.0 * moon_radius));
	vec4 m = texture(moon_picture, uv);
	float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0) * step(0.0, facing);
	return mix(col, m.rgb, m.a * inside);
}

void fragment() {
	vec3 ray = normalize(local_pos - cam_local);
	// 방 안에서 보면 ray.z < 0(유리 너머). 거의 옆에서 보는 각도는 잘라서 무한대로 튀지 않게 한다.
	ray.z = min(ray.z, -0.08);
	ray = normalize(ray);
	vec3 col = moon(ray, sky(ray));

	// 창마다 그림의 다른 곳이 보이게 층마다 다른 가로 위치.
	float far_offset = fract(seed * 3.7) * far_size.y;
	float street_offset = fract(seed * 7.3) * street_size.y;
	float front_offset = fract(seed * 11.1) * front_size.y;

	vec4 far_c = picture_layer(far_layer, ray, far_size, far_offset);
	col = mix(col, far_c.rgb, far_c.a);
	vec4 street_c = picture_layer(street_layer, ray, street_size, street_offset);
	// 네온·불 켜진 창이 아주 살짝 숨 쉬듯 밝아졌다 어두워진다(밝은 곳만, 건물 칸마다 다른 박자).
	float glow_mask = smoothstep(0.55, 0.9, max(street_c.r, max(street_c.g, street_c.b)));
	street_c.rgb *= 1.0 + glow_mask * 0.08 * sin(TIME * 1.7 + floor((hit_at(ray, street_size.x).x + street_offset) / 3.5) * 2.1);
	col = mix(col, street_c.rgb, street_c.a);

	// 길바닥: 광선이 길 건너 건물보다 먼저 땅(y 0)에 닿으면 길. 가로등 불빛 웅덩이.
	float lamp_x = front_lamp_x - front_offset;
	lamp_x -= front_size.y * round(lamp_x / front_size.y);
	if (ray.y < 0.0) {
		float t_ground = -local_pos.y / ray.y;
		vec3 g = local_pos + ray * t_ground;
		if (-g.z < street_size.x) {
			col = street;
			// 보도와 차도 경계(연석) 선.
			col += vec3(0.05) * smoothstep(0.08, 0.0, abs(-g.z - 9.0));
			float pool = exp(-pow(length(vec2(g.x - lamp_x, -g.z - front_size.x)) / 2.4, 2.0));
			col += lamp_light * pool * 0.45;
		}
	}

	// 앞 층: 알전구는 하나씩 다른 박자로 반짝인다(전구 간격 0.7m).
	vec4 front_c = picture_layer(front_layer, ray, front_size, front_offset);
	float bulb = floor((hit_at(ray, front_size.x).x + front_offset) / 0.7);
	float bright = smoothstep(0.6, 0.85, max(front_c.r, max(front_c.g, front_c.b)));
	front_c.rgb *= 1.0 + bright * 0.18 * sin(TIME * 2.3 + bulb * 1.9);
	col = mix(col, front_c.rgb, front_c.a);

	// 유리: 비스듬한 옅은 반사 줄 두 개(유리 면 기준 — 시차 없이 유리에 붙어 있다).
	float diag = local_pos.x * 0.8 + local_pos.y * 0.6;
	col += vec3(glass_streak) * (smoothstep(0.1, 0.0, abs(fract(diag * 0.55) - 0.3)) + 0.6 * smoothstep(0.05, 0.0, abs(fract(diag * 0.55) - 0.42)));

	ALBEDO = col * brightness;
}
