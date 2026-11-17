// 펍 창 밖 빛무리(2026-11-16). 디자인 담당 소유. 만드는 곳 = art/pub/street_outside.gd(_moon · _car 전조등 바닥 빛).
// 늘 카메라를 보는 네모 판(billboard)에 가운데가 밝고 가장자리로 갈수록 사라지는 동그란 빛을 "더하기"로 그린다.
// 달 둘레 은은한 빛 · 차 전조등이 길에 비치는 빛처럼 "빛이 번진다"는 느낌을 준다. 그림자·깊이 쓰기 없음.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 halo_color : source_color = vec3(0.55, 0.6, 0.85);
uniform float strength = 0.6;
// 1 이면 카메라를 본다(달), 0 이면 놓인 그대로(길 위 전조등 빛).
uniform float billboard = 1.0;
// 가장자리 부드러움(클수록 가운데에 몰린다).
uniform float falloff = 2.2;

void vertex() {
	if (billboard > 0.5) {
		// 판의 크기(노드 배율)는 지키고 방향만 카메라를 보게 한다.
		vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * scale.x, INV_VIEW_MATRIX[1] * scale.y, INV_VIEW_MATRIX[2] * scale.z, MODEL_MATRIX[3]);
	}
}

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float glow = pow(clamp(1.0 - d, 0.0, 1.0), falloff);
	ALBEDO = halo_color * glow * strength;
}
