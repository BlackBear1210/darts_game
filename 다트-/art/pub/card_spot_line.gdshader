// 카드 테이블 펠트 위 "카드 놓는 칸" 흰 테두리(2026-11-22, 포커 테이블 방식). 디자인 담당 소유.
// 사용자 요청 "자리마다 카드 놓는 구역을 없애고 포커 테이블처럼 카드 놓는 곳만 흰색 선으로".
// 만드는 곳: art/pub/room/room_seating.gd build_table_and_seats (칸마다 평평한 판 하나 + 이 셰이더).
//
// [왜 셰이더인가] 3mm 선을 메시로 만들면 멀리서(라운지를 걸어 다닐 때) 선이 1화소보다 가늘어져 점선처럼 끊기고 반짝였다
//   (프로젝트는 MSAA·FXAA 를 쓰지 않는다). 그래서 판 위에 둥근 사각형까지의 거리(SDF)로 선을 그리고,
//   선이 화면에서 1화소보다 가늘어지면 굵기는 1화소로 두고 그만큼 옅게 만든다 → 멀리서는 끊김 없는 옅은 선이 된다.
//   (화면 공간 미분 fwidth 로 선 굵기를 화소 단위로 다루는 흔한 방법. 격자 셰이더에서 쓰는 "선 굵기 고정 + 옅게" 방식.)
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, diffuse_lambert_wrap, specular_disabled;

uniform vec3 line_color : source_color = vec3(1.0);
// 판 전체 크기(m). 선 바깥으로 여유가 있어야 멀리서 넓어진 선 가장자리가 잘리지 않는다.
uniform vec2 quad_size = vec2(0.12, 0.17);
// 테두리 바깥 크기·모서리 반지름·선 굵기(m).
uniform vec2 frame_size = vec2(0.112, 0.162);
uniform float corner_radius = 0.012;
uniform float line_width = 0.003;
// 따뜻한 펍 조명 아래서도 흰색으로 남게 하는 약한 자체 발광.
uniform float glow = 0.25;

// 가운데 = 원점인 둥근 사각형까지의 부호 있는 거리(안쪽 음수).
float rounded_box(vec2 p, vec2 half_size, float radius) {
	vec2 q = abs(p) - half_size + vec2(radius);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
}

void fragment() {
	vec2 p = (UV - 0.5) * quad_size;
	// 선의 가운데를 지나는 둥근 사각형(바깥 크기에서 선 굵기 반만큼 안쪽).
	float signed_distance = rounded_box(p, frame_size * 0.5 - line_width * 0.5, corner_radius - line_width * 0.5);
	float pixel = max(fwidth(signed_distance), 1e-6);
	float drawn = max(line_width, pixel);
	float cover = 1.0 - smoothstep(drawn * 0.5 - pixel * 0.5, drawn * 0.5 + pixel * 0.5, abs(signed_distance));
	ALBEDO = line_color;
	EMISSION = line_color * glow;
	ROUGHNESS = 0.9;
	ALPHA = cover * (line_width / drawn);
}
