// 펍 창 밖 3D 달(2026-11-16). 디자인 담당 소유. 만드는 곳 = art/pub/street_outside.gd(_moon).
// 예전 = 창 유리에 붙인 평평한 만화 달 그림 → 진짜 공 모양 달. 크레이터는 표면 방향으로 만든 무늬라 어느 쪽에서 봐도 둥글다.
// 달 뒤 빛무리는 따로(art/pub/street_halo.gdshader — 늘 카메라를 보는 판, 더하기 섞기).
shader_type spatial;
render_mode unshaded, shadows_disabled;

uniform vec3 moon_color : source_color = vec3(1.0, 0.95, 0.80);
uniform vec3 crater_color : source_color = vec3(0.78, 0.72, 0.62);
uniform vec3 light_dir = vec3(-0.3, 0.2, -1.0);
uniform float brightness = 1.7;

varying vec3 local_n;

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

// 3D 값 노이즈(크레이터 얼룩).
float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}

void vertex() {
	local_n = normalize(VERTEX);
}

void fragment() {
	vec3 n = normalize(local_n);
	float spots = noise3(n * 3.2) * 0.6 + noise3(n * 7.5) * 0.4;
	vec3 col = mix(moon_color, crater_color, smoothstep(0.45, 0.7, spots));
	// 둥근 공처럼 보이게: 가장자리를 살짝 어둡게(테두리 감쇠) + 한쪽에서 비치는 빛.
	float facing = clamp(dot(normalize(NORMAL), vec3(0.0, 0.0, 1.0)), 0.0, 1.0);
	float shade = 0.72 + 0.28 * max(dot(n, normalize(light_dir)), 0.0);
	ALBEDO = col * brightness * shade * (0.55 + 0.45 * pow(facing, 0.6));
}
