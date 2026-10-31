extends Node3D
## 한 번 터지고 사라지는 3D 효과: 다트 코르크 가루 · 유리 파편 · 술 웅덩이 · 나무 조각 · 색종이 · 별.
## 화면마다 각자 재생하는 "보이기만 하는 것"이다. 판정·점수와 무관하고 네트워크로 보내지 않는다.
## 실제 물리 엔진 대신 포물선 + 바닥 튕김만 계산해 가볍다(파편 수십 개).
##
## 쓰는 법: const BurstFx = preload("res://art/fx/burst_fx.gd") 후 BurstFx.spawn(부모, "glass", 위치, 밀어낼 방향, 색)

const FLOOR_Y: float = 0.012
const GRAVITY: float = 9.8
## 유리병 파편 모양(휜 벽 조각·병목 고리·바닥 컵·라벨 종이·뚜껑). 2026-10-31 네모 상자 파편을 바꿨다.
const GlassShards = preload("res://art/fx/glass_shards.gd")
## 유리가 깨지는 순간 반짝이는 작은 빛 알갱이 수.
const GLASS_GLINTS: int = 18
## 술 웅덩이 크기(m, 평균 반지름)·테두리 점 수·옆에 튄 작은 방울 수(2026-10-31 완벽한 원판 → 흘러나간 모양).
const PUDDLE_RADIUS: float = 0.32
const PUDDLE_STEPS: int = 36
const PUDDLE_DROPS: int = 4

## kind → 조각 수·크기·속도·수명·바닥에 남는지. 숫자는 보기 좋게 맞춘 연출값이다.
const KINDS := {
	"cork": {"count": 12, "size": Vector3(0.012, 0.012, 0.012), "speed": Vector2(0.8, 2.0), "up": 0.4, "life": 0.7, "rest": false, "colors": ["8a6a45", "d9c39a", "3b2a1e"]},
	# glass 는 아래 _build_glass 가 진짜 파편 모양으로 만든다(count·size 는 쓰지 않는다). speed = 파편이 밖으로 튀는 빠르기.
	"glass": {"count": 0, "size": Vector3.ZERO, "speed": Vector2(0.9, 2.8), "up": 1.3, "life": 6.0, "rest": true, "colors": []},
	"splash": {"count": 14, "size": Vector3(0.022, 0.022, 0.022), "speed": Vector2(0.8, 2.6), "up": 2.0, "life": 0.9, "rest": false, "colors": []},
	"wood": {"count": 10, "size": Vector3(0.09, 0.012, 0.014), "speed": Vector2(1.2, 2.8), "up": 1.6, "life": 5.0, "rest": true, "colors": ["6b4a2b", "c9a36b", "3a2618"]},
	"confetti": {"count": 42, "size": Vector3(0.035, 0.002, 0.026), "speed": Vector2(1.0, 3.0), "up": 3.0, "life": 2.6, "rest": true, "colors": ["ff6b5b", "37d9bf", "ffc845", "9b77b9", "4e92bd", "fff3dc"]},
	"stars": {"count": 6, "size": Vector3(0.05, 0.05, 0.05), "speed": Vector2(0.6, 1.0), "up": 1.2, "life": 0.9, "rest": false, "colors": ["ffe66b", "fff3dc"]},
	"sparks": {"count": 16, "size": Vector3(0.018, 0.018, 0.018), "speed": Vector2(1.5, 3.5), "up": 1.0, "life": 0.5, "rest": false, "colors": ["ffe66b", "ff9a3c", "fff3dc"]},
}

static var _materials: Dictionary = {}

var _pieces: Array[Dictionary] = []
var _age: float = 0.0
var _life: float = 1.0
var _puddle: MeshInstance3D


## 효과 하나를 띄운다. 화면 없는 시험(--headless)에서는 아무것도 만들지 않는다.
static func spawn(parent: Node, kind: String, at: Vector3, push: Vector3 = Vector3.ZERO, tint: Color = Color.WHITE) -> Node3D:
	if parent == null or not parent.is_inside_tree() or DisplayServer.get_name() == "headless" or not KINDS.has(kind):
		return null
	var fx: Node3D = (load("res://art/fx/burst_fx.gd") as GDScript).new()
	parent.add_child(fx)
	fx.global_position = at
	fx._build(kind, push, tint)
	return fx


func _build(kind: String, push: Vector3, tint: Color) -> void:
	var spec: Dictionary = KINDS[kind]
	_life = spec.life
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if kind == "glass":
		_build_glass(spec, push, tint, rng)
		return
	var colors: Array = spec.colors
	var box := BoxMesh.new()
	box.size = spec.size
	var direction := push.normalized() if push.length() > 0.01 else Vector3.ZERO
	for index in range(int(spec.count)):
		var piece := MeshInstance3D.new()
		piece.mesh = box if kind not in ["splash", "stars", "sparks"] else _round_mesh(spec.size.x)
		var color: Color = Color(colors[index % colors.size()]) if not colors.is_empty() else tint
		if kind == "glass":
			color = tint.lerp(Color.WHITE, rng.randf_range(0.0, 0.35))
		piece.material_override = _material(color, kind)
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(piece)
		var spread := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.2, 1), rng.randf_range(-1, 1)).normalized()
		var velocity := (spread + direction * 1.2).normalized() * rng.randf_range(spec.speed.x, spec.speed.y)
		velocity.y += float(spec.up) * rng.randf_range(0.4, 1.0)
		piece.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
		_pieces.append({"node": piece, "velocity": velocity, "spin": Vector3(rng.randf_range(-14, 14), rng.randf_range(-14, 14), rng.randf_range(-14, 14)),
			"rest": bool(spec.rest), "drag": 2.2 if kind == "confetti" else 0.0, "scale": rng.randf_range(0.6, 1.4)})
	# 깨진 병은 바닥에 술(음료) 웅덩이를 남긴다.
	if kind == "splash":
		_puddle = MeshInstance3D.new()
		_puddle.mesh = _puddle_mesh(rng)
		_puddle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var puddle_color := tint
		puddle_color.a = 0.55
		_puddle.material_override = _material(puddle_color, "puddle")
		add_child(_puddle)
		_puddle.global_position = Vector3(global_position.x, FLOOR_Y, global_position.z)
		_puddle.scale = Vector3(0.1, 1, 0.1)
		_life = 7.0


## 깨진 유리병: 병 모양 그대로 조각을 놓은 뒤 병 중심에서 밖으로 흩뿌린다.
## 큰 조각(병목·바닥)은 무거워 덜 튀고, 라벨 종이는 팔랑 떨어지고, 뚜껑은 위로 튕긴다. 반짝이 알갱이가 잠깐 빛난다.
func _build_glass(spec: Dictionary, push: Vector3, tint: Color, rng: RandomNumberGenerator) -> void:
	var direction := push.normalized() if push.length() > 0.01 else Vector3.ZERO
	# 병이 어느 쪽으로 기운 채 깨졌는지 매번 다르게(조각 배치가 매번 달라 보인다).
	var turn := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.5, 0.5))
	for shard: Dictionary in GlassShards.pieces(rng):
		var piece := MeshInstance3D.new()
		piece.mesh = shard.mesh
		var shard_kind: String = shard.kind
		piece.material_override = _material(Color("f3e9d2") if shard_kind == "paper" else (Color("e8c34a") if shard_kind == "cap" else tint), "shard_" + shard_kind)
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(piece)
		var offset: Vector3 = turn * (shard.origin as Vector3)
		piece.position = offset
		piece.basis = turn * (shard.basis as Basis)
		var heavy: bool = shard.lift > 0.03 or shard.origin.y < GlassShards.BODY_BOTTOM + 0.01
		var outward := Vector3(offset.x, 0, offset.z).normalized() if Vector2(offset.x, offset.z).length() > 0.005 else Vector3.ZERO
		var speed: float = rng.randf_range(spec.speed.x, spec.speed.y) * (0.45 if heavy else 1.0)
		var velocity := (outward + direction * 0.9 + Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))) * speed
		velocity.y += float(spec.up) * rng.randf_range(0.3, 1.0) * (0.5 if heavy else 1.0) + (1.6 if shard_kind == "cap" else 0.0)
		var spin_size: float = 4.0 if heavy else 16.0
		_pieces.append({"node": piece, "velocity": velocity,
			"spin": Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * spin_size,
			"rest": true, "drag": 2.6 if shard_kind == "paper" else 0.0, "scale": 1.0,
			"lift": float(shard.lift), "lie": shard.lie, "landed": false, "twinkle": -1.0})
	# 반짝이: 깨지는 순간 사방으로 튀는 작은 빛. 바닥에 닿으면 사라진다.
	for index in range(GLASS_GLINTS):
		var glint := MeshInstance3D.new()
		glint.mesh = _round_mesh(0.009)
		glint.material_override = _material(tint.lerp(Color.WHITE, 0.7), "glint")
		glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(glint)
		var spread := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.0, 1.2), rng.randf_range(-1, 1)).normalized()
		_pieces.append({"node": glint, "velocity": (spread + direction * 0.6) * rng.randf_range(1.5, 3.8), "spin": Vector3.ZERO,
			"rest": false, "drag": 0.0, "scale": rng.randf_range(0.6, 1.3), "lift": 0.0, "lie": Vector2.ZERO, "landed": false,
			"twinkle": rng.randf() * TAU})


func _process(delta: float) -> void:
	_age += delta
	var fade: float = clampf((_life - _age) / 0.6, 0.0, 1.0)
	for piece in _pieces:
		var node: MeshInstance3D = piece.node
		if not node.visible:
			continue
		var velocity: Vector3 = piece.velocity
		velocity.y -= GRAVITY * delta * (0.25 if piece.drag > 0.0 else 1.0)
		velocity = velocity * (1.0 - minf(1.0, piece.drag * delta))
		node.position += velocity * delta
		node.rotation += piece.spin * delta
		# lift = 누웠을 때 바닥에서 조각 원점까지 높이(유리 조각 두께·병목 반지름). 예전 상자 파편은 0.
		var lift: float = float(piece.get("lift", 0.0))
		if node.global_position.y <= FLOOR_Y + lift:
			if piece.rest:
				# 바닥에 닿으면 조금 튕기고 미끄러지다 멈춘다(파편이 바닥에 남는다).
				node.global_position.y = FLOOR_Y + lift
				velocity = Vector3(velocity.x * 0.45, absf(velocity.y) * 0.25, velocity.z * 0.45)
				piece.spin = piece.spin * 0.4
				piece.landed = true
				if velocity.length() < 0.25:
					velocity = Vector3.ZERO
					piece.spin = Vector3.ZERO
			else:
				node.visible = false
		# 바닥에 한 번 닿은 조각은 누운 자세(lie: x·z 회전)로 부드럽게 눕는다 — 멈출 때 툭 돌아가지 않게.
		if piece.get("landed", false):
			var lie: Vector2 = piece.get("lie", Vector2.ZERO)
			var settle: float = minf(1.0, delta * 9.0)
			node.rotation.x = lerp_angle(node.rotation.x, lie.x, settle)
			node.rotation.z = lerp_angle(node.rotation.z, lie.y, settle)
		piece.velocity = velocity
		var twinkle: float = float(piece.get("twinkle", -1.0))
		var sparkle: float = 1.0 if twinkle < 0.0 else (0.35 + 0.65 * absf(sin(_age * 26.0 + twinkle))) * clampf(1.0 - _age / 0.7, 0.0, 1.0)
		node.scale = Vector3.ONE * float(piece.scale) * fade * sparkle
	if _puddle != null:
		var grow: float = minf(1.0, _age * 3.0)
		_puddle.scale = Vector3(grow, 1, grow) * maxf(0.05, fade)
	if _age >= _life:
		queue_free()


## 술 웅덩이 바닥 모양: 각도마다 반지름이 조금씩 다른 납작한 부채꼴 메시 + 옆으로 튄 작은 방울 몇 개.
## 완벽한 원판은 바닥에 붙인 스티커처럼 보였다. 낮은 주파수 사인 세 개를 겹쳐 흘러나간 듯한 혹을 만든다.
## 한 장짜리 메시라 반투명 원판 여러 개를 겹칠 때처럼 겹친 곳만 진해지는 일이 없다.
static func _puddle_mesh(rng: RandomNumberGenerator) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_normal(Vector3.UP)
	var phases := Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
	var outline: Array[Vector3] = []
	for step in range(PUDDLE_STEPS):
		var angle: float = TAU * step / PUDDLE_STEPS
		var wobble: float = 0.2 * sin(angle * 2.0 + phases.x) + 0.12 * sin(angle * 3.0 + phases.y) + 0.06 * sin(angle * 5.0 + phases.z)
		outline.append(Vector3(cos(angle), 0, sin(angle)) * PUDDLE_RADIUS * (1.0 + wobble) * rng.randf_range(0.95, 1.05))
	_fan(tool, Vector3.ZERO, outline)
	# 웅덩이 밖에 떨어진 작은 방울. 본체 테두리(최대 약 1.4배)보다 바깥에 둬서 겹치지 않는다.
	for drop in range(PUDDLE_DROPS):
		var angle: float = rng.randf() * TAU
		var center := Vector3(cos(angle), 0, sin(angle)) * PUDDLE_RADIUS * rng.randf_range(1.55, 1.9)
		var radius: float = PUDDLE_RADIUS * rng.randf_range(0.07, 0.14)
		var ring: Array[Vector3] = []
		for step in range(10):
			var around: float = TAU * step / 10.0
			ring.append(center + Vector3(cos(around), 0, sin(around)) * radius * rng.randf_range(0.85, 1.15))
		_fan(tool, center, ring)
	return tool.commit()


## 가운데 점과 둘레 점들로 바닥에 눕는 부채꼴 삼각형을 쌓는다.
## Godot 은 시계 방향이 앞면이다: 위(+Y)에서 내려다보면 각도가 커지는 쪽이 시계 방향이라 (가운데, i, i+1) 순서가 위를 향한다.
static func _fan(tool: SurfaceTool, center: Vector3, ring: Array[Vector3]) -> void:
	for step in range(ring.size()):
		tool.add_vertex(center)
		tool.add_vertex(ring[step])
		tool.add_vertex(ring[(step + 1) % ring.size()])


static func _round_mesh(diameter: float) -> SphereMesh:
	var sphere := SphereMesh.new()
	sphere.radius = diameter * 0.5
	sphere.height = diameter
	sphere.radial_segments = 6
	sphere.rings = 3
	return sphere


static func _material(color: Color, kind: String) -> StandardMaterial3D:
	var key := "%s_%s" % [kind, color.to_html()]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	if kind.begins_with("shard_"):
		_shard_material(material, color, kind)
		_materials[key] = material
		return material
	material.albedo_color = color
	material.roughness = 0.25 if kind in ["glass", "splash", "puddle"] else 0.8
	if color.a < 0.99 or kind in ["glass", "puddle"]:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if kind == "glass":
			material.albedo_color.a = 0.8
	if kind in ["stars", "sparks", "glint"]:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.6
	_materials[key] = material
	return material


## 깨진 병 조각 재질. 유리 = 반투명 + 아주 매끈한 반사 + 가장자리 빛(rim) + 양면(휜 조각 안쪽도 보인다).
## 어두운 펍에서도 조각이 보이도록 병 색으로 아주 약하게 빛낸다. 라벨 종이·뚜껑은 불투명.
static func _shard_material(material: StandardMaterial3D, color: Color, kind: String) -> void:
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	match kind:
		"shard_paper":
			material.albedo_color = color
			material.roughness = 0.9
		"shard_cap":
			material.albedo_color = color
			material.metallic = 0.7
			material.roughness = 0.3
		_:
			material.albedo_color = Color(color.lerp(Color.WHITE, 0.12), 0.55)
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.roughness = 0.04
			material.metallic_specular = 1.0
			material.rim_enabled = true
			material.rim = 0.6
			material.rim_tint = 0.4
			material.emission_enabled = true
			material.emission = color * 0.35
