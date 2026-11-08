extends RefCounted
## 시가 연기(2026-11-08 사용자 요청 "재떨이랑 AI 캐릭터가 연기랑 '후' 부는, 실제 시가를 피는 모습").
##   wisp(): 시가 끝에서 가늘게 피어오르는 연기 — 늘 조금씩 나온다.
##   puff(): 입에서 "후" 내뿜는 연기 덩어리 — emitting 을 켠 동안만 앞으로 퍼져 나가며 커지고 옅어진다.
## 둘 다 CPUParticles3D(화면 없는 시험에서도 오류 없이 돈다). 연기 알갱이는 작은 반투명 회색 구슬(빛 안 받음)이라
## 점토 느낌의 방과 어울리고, 커지며 옅어지는 곡선으로 부드럽게 보인다. 쓰는 곳: art/pub/npc_idle.gd(style 4).


static func _material(alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = "CigarSmoke"
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(0.86, 0.85, 0.82, alpha)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = false
	return material


static func _grain() -> SphereMesh:
	var grain := SphereMesh.new()
	grain.radius = 0.5
	grain.height = 1.0
	grain.radial_segments = 8
	grain.rings = 4
	return grain


## 커지는 곡선(처음 size_from → 끝 1.0)과 옅어지는 색(진하게 → 투명).
static func _shape(particles: CPUParticles3D, size_from: float, alpha: float) -> void:
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, size_from))
	grow.add_point(Vector2(0.35, 0.6))
	grow.add_point(Vector2(1.0, 1.0))
	particles.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, alpha))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	fade.add_point(0.25, Color(1, 1, 1, alpha * 0.8))
	particles.color_ramp = fade


static func wisp() -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.name = "SmokeWisp"
	particles.mesh = _grain()
	particles.material_override = _material(1.0)
	# 알갱이를 촘촘히(2026-11-08 렌더: 22개면 구슬이 띄엄띄엄 떠 보였다) — 가는 연기 줄로 보이게.
	particles.amount = 44
	particles.lifetime = 2.4
	particles.local_coords = false
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.006
	particles.direction = Vector3.UP
	particles.spread = 8.0
	particles.gravity = Vector3(0.02, 0.06, 0.0)
	particles.initial_velocity_min = 0.05
	particles.initial_velocity_max = 0.08
	particles.damping_min = 0.02
	particles.damping_max = 0.05
	particles.scale_amount_min = 0.045
	particles.scale_amount_max = 0.07
	particles.angular_velocity_min = -40.0
	particles.angular_velocity_max = 40.0
	_shape(particles, 0.4, 0.3)
	return particles


static func puff() -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.name = "SmokePuff"
	particles.mesh = _grain()
	particles.material_override = _material(1.0)
	particles.amount = 36
	particles.lifetime = 1.9
	particles.local_coords = false
	particles.emitting = false
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.015
	# 방향은 npc_idle 이 머리 정면으로 매 프레임 맞춘다(전역 좌표).
	particles.direction = Vector3(0, 0.15, -1)
	particles.spread = 16.0
	particles.gravity = Vector3(0.0, 0.09, 0.0)
	particles.initial_velocity_min = 0.32
	particles.initial_velocity_max = 0.5
	particles.damping_min = 0.35
	particles.damping_max = 0.55
	particles.scale_amount_min = 0.12
	particles.scale_amount_max = 0.2
	_shape(particles, 0.2, 0.42)
	return particles
