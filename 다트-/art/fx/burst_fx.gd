extends Node3D
## 한 번 터지고 사라지는 3D 효과: 다트 코르크 가루 · 유리 파편 · 술 웅덩이 · 나무 조각 · 색종이 · 별.
## 화면마다 각자 재생하는 "보이기만 하는 것"이다. 판정·점수와 무관하고 네트워크로 보내지 않는다.
## 실제 물리 엔진 대신 포물선 + 바닥 튕김만 계산해 가볍다(파편 수십 개).
##
## 쓰는 법: const BurstFx = preload("res://art/fx/burst_fx.gd") 후 BurstFx.spawn(부모, "glass", 위치, 밀어낼 방향, 색)

const FLOOR_Y: float = 0.012
const GRAVITY: float = 9.8

## kind → 조각 수·크기·속도·수명·바닥에 남는지. 숫자는 보기 좋게 맞춘 연출값이다.
const KINDS := {
	"cork": {"count": 12, "size": Vector3(0.012, 0.012, 0.012), "speed": Vector2(0.8, 2.0), "up": 0.4, "life": 0.7, "rest": false, "colors": ["8a6a45", "d9c39a", "3b2a1e"]},
	"glass": {"count": 22, "size": Vector3(0.035, 0.005, 0.022), "speed": Vector2(1.4, 3.6), "up": 1.4, "life": 6.0, "rest": true, "colors": []},
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
		var disc := CylinderMesh.new()
		disc.top_radius = 0.32
		disc.bottom_radius = 0.32
		disc.height = 0.004
		disc.radial_segments = 20
		_puddle.mesh = disc
		var puddle_color := tint
		puddle_color.a = 0.55
		_puddle.material_override = _material(puddle_color, "puddle")
		add_child(_puddle)
		_puddle.global_position = Vector3(global_position.x, FLOOR_Y, global_position.z)
		_puddle.scale = Vector3(0.1, 1, 0.1)
		_life = 7.0


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
		if node.global_position.y <= FLOOR_Y:
			if piece.rest:
				# 바닥에 닿으면 조금 튕기고 미끄러지다 멈춘다(파편이 바닥에 남는다).
				node.global_position.y = FLOOR_Y
				velocity = Vector3(velocity.x * 0.45, absf(velocity.y) * 0.25, velocity.z * 0.45)
				piece.spin = piece.spin * 0.4
				if velocity.length() < 0.25:
					velocity = Vector3.ZERO
					piece.spin = Vector3.ZERO
					node.rotation.x = 0.0
					node.rotation.z = 0.0
			else:
				node.visible = false
		piece.velocity = velocity
		node.scale = Vector3.ONE * float(piece.scale) * fade
	if _puddle != null:
		var grow: float = minf(1.0, _age * 3.0)
		_puddle.scale = Vector3(grow, 1, grow) * maxf(0.05, fade)
	if _age >= _life:
		queue_free()


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
	material.albedo_color = color
	material.roughness = 0.25 if kind in ["glass", "splash", "puddle"] else 0.8
	if color.a < 0.99 or kind in ["glass", "puddle"]:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if kind == "glass":
			material.albedo_color.a = 0.8
	if kind in ["stars", "sparks"]:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.6
	_materials[key] = material
	return material
