// 펍 바닥: 이음매 없는 한 장 위에 그린 헤링본(청어뼈) 오크 마루. 2026-11-08, 디자인 담당 소유.
// 사용자 지적 "맵의 지형지물 … 전부 이상해" + 디자인 요청서 2장 "바닥은 한 장으로 이어진 면 위의 잔잔한 목재 —
// 판재마다 높이가 다른 큐브·3D 격자 홈·타일마다 극단적인 색은 쓰지 않는다".
// 예전 바닥은 판자 상자 수백 개(틈 사이로 밑판이 보임)였다 → 평평한 판 하나 + 이 셰이더로 판자 무늬만 그린다.
//
// [헤링본 계산] 판자 크기 폭 1 × 길이 k(폭 단위). 가로 판(H)과 세로 판(V) 한 쌍이 격자 t1=(1,1), t2=(k,-k) 로 반복된다.
//   점이 어느 판 안에 있는지 이웃 칸 9개만 확인한다 → 판마다 번호(색 흔들림)·안쪽 좌표(나뭇결·이음매)를 얻는다.
// 좌표는 세계 기준(world_pos.xz)이라 바닥 판을 몇 장으로 나눠도 무늬가 이어진다.
shader_type spatial;
render_mode diffuse_lambert_wrap;

uniform vec3 oak : source_color = vec3(0.474, 0.345, 0.239);       // #79583D (요청서 펍 바닥)
uniform vec3 oak_light : source_color = vec3(0.560, 0.420, 0.290);
uniform vec3 oak_dark : source_color = vec3(0.392, 0.275, 0.184);
uniform vec3 seam_color : source_color = vec3(0.215, 0.150, 0.105);
uniform float plank_width = 0.12;      // 판자 폭(m)
uniform float plank_ratio = 6.0;       // 길이 = 폭 × 이 값(정수)
uniform float seam = 0.035;            // 이음매 굵기(폭 단위) — 아주 가늘게
uniform float grain = 0.05;            // 나뭇결 세기(약하게)
uniform float roughness_base = 0.58;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float k = plank_ratio;
	vec2 p = world_pos.xz / plank_width;
	vec2 t1 = vec2(1.0, 1.0);
	vec2 t2 = vec2(k, -k);
	// 격자 좌표(대략) → 이웃 칸을 뒤져 실제로 점을 품은 판을 찾는다.
	// 판 안의 점은 자기 칸 기준 a 가 0~(k+2)/2, b 가 −1/(2k)~1 만큼 떨어져 있다 → a 는 4칸 뒤까지, b 는 앞뒤 1칸.
	float a0 = floor((p.x + p.y) * 0.5);
	float b0 = floor((p.x - p.y) / (2.0 * k));
	vec2 local = vec2(0.0);
	vec2 id = vec2(0.0);
	float vertical = 0.0;
	bool found = false;
	for (int da = -4; da <= 0; da++) {
		for (int db = -1; db <= 1; db++) {
			if (found) { break; }
			vec2 cell = vec2(a0 + float(da), b0 + float(db));
			vec2 q = p - (cell.x * t1 + cell.y * t2);
			// 가로 판 H = [0,k] × [0,1]
			if (q.x >= 0.0 && q.x < k && q.y >= 0.0 && q.y < 1.0) {
				local = vec2(q.x / k, q.y);
				id = cell * 2.0;
				vertical = 0.0;
				found = true;
			// 세로 판 V = [k,k+1] × [1-k,1]
			} else if (q.x >= k && q.x < k + 1.0 && q.y >= 1.0 - k && q.y < 1.0) {
				local = vec2((q.y - (1.0 - k)) / k, q.x - k);
				id = cell * 2.0 + vec2(1.0, 0.0);
				vertical = 1.0;
				found = true;
			}
		}
	}
	// local.x = 판 길이 방향 0~1, local.y = 폭 방향 0~1.
	float tone = hash(id);
	vec3 base = mix(oak_dark, oak_light, smoothstep(0.1, 0.9, tone));
	base = mix(oak, base, 0.55);
	// 나뭇결: 길이 방향으로 늘어진 가는 줄(판마다 위상이 다름). 아주 약하게.
	float lines = sin((local.y * 9.0 + sin(local.x * 6.2831 * 1.3 + tone * 20.0) * 0.6) * 3.14159 + tone * 40.0);
	base *= 1.0 + lines * grain;
	// 이음매: 판 가장자리(폭 방향은 가늘게, 끝 이음은 조금 더 가늘게).
	float edge_w = min(local.y, 1.0 - local.y);
	float edge_l = min(local.x, 1.0 - local.x) * k;
	float edge = min(edge_w, edge_l);
	float line = 1.0 - smoothstep(seam * 0.5, seam, edge);
	vec3 color = mix(base, seam_color, line * 0.85);
	ALBEDO = color;
	ROUGHNESS = roughness_base + tone * 0.08 + line * 0.3;
	SPECULAR = 0.35;
}
