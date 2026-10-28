extends Node3D
## 3D 카드 한 장 = 앞면 판 + 뒷면 판(두께 1.6mm). 둥근 모서리는 텍스처 투명 부분을 잘라 낸다(알파 가위).
## 로컬 좌표: 누워 있을 때 앞면 = +Y, 그림 위쪽 = -Z → 카드 +Z 쪽에 앉은 사람이 똑바로 읽는다.
## 뒤집기·들기 연출은 자식 Body 만 돌리고 옮긴다 → 카드 자리(이 노드의 위치·방향)는 그대로다.
## 사용 표시: 빨간 페인트 X(기본) 또는 가장자리가 불에 그을림 — 설정에서 고른다.

const CardFaces = preload("res://game/card_round/cards/card_faces.gd")

enum Mark { PAINT, BURN }

## 실제 트럼프 카드(63×88mm)의 약 1.5배. 펍 테이블 자리 매트의 카드 칸(0.1 × 0.15m)에 들어간다.
const SIZE := Vector2(0.096, 0.144)
const THICKNESS: float = 0.0016
const PAINT_COLOR := Color("c3261f")
const GLOW_COLOR := Color("ffd27a")
const BURN_SECONDS: float = 1.3
const BURN_SHADER := """
shader_type spatial;
uniform sampler2D face : source_color, filter_linear_mipmap_anisotropic;
uniform float burn : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec4 tex = texture(face, UV);
	if (tex.a < 0.5) { discard; }
	// 가장자리까지 거리(세로가 1.5배 길어 가로 기준으로 맞춘다). 노이즈로 불규칙하게 타 들어간다.
	vec2 side = min(UV, 1.0 - UV) * vec2(1.0, 1.5);
	float edge = min(side.x, side.y);
	float n = noise(UV * vec2(9.0, 13.5)) * 0.65 + noise(UV * vec2(27.0, 40.0)) * 0.35;
	float front = burn * (0.17 + (n - 0.5) * 0.12);
	if (edge < front - 0.05 * burn) { discard; }
	float charred = 1.0 - smoothstep(front - 0.015, front + 0.06, edge);
	vec3 aged = mix(tex.rgb, tex.rgb * vec3(0.86, 0.72, 0.55), burn * 0.55);
	vec3 color = mix(aged, vec3(0.07, 0.045, 0.03), charred * 0.94);
	float ember = (1.0 - smoothstep(0.0, 0.022, abs(edge - (front - 0.05 * burn)))) * burn;
	ALBEDO = color;
	EMISSION = vec3(1.0, 0.42, 0.06) * ember * 2.5;
	ROUGHNESS = 0.85;
}
"""

static var _plane: PlaneMesh
static var _materials: Dictionary = {}
static var _glow_material: StandardMaterial3D
static var _paint_material: StandardMaterial3D
static var _burn_shader: Shader

var type: int = -1
var face_up: bool = false
var mark_style: int = -1
var body: Node3D
var _face: MeshInstance3D
var _back: MeshInstance3D
var _glow: MeshInstance3D
var _key: Label3D


func _init() -> void:
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	_face = _sheet("Face", THICKNESS / 2.0)
	_back = _sheet("Back", -THICKNESS / 2.0)
	_back.rotation.z = PI
	_back.material_override = material_for(CardFaces.back())
	show_face(false)


## 카드 종류를 바꾸고 앞면 그림을 다시 입힌다.
func set_type(card_type: int) -> void:
	type = card_type
	_face.material_override = material_for(CardFaces.face(type))


## true = 앞면이 위, false = 뒤집어 뒷면이 위.
func show_face(up: bool) -> void:
	face_up = up
	body.rotation.z = 0.0 if up else PI


## 그림자를 끈다(1인칭 부채처럼 카메라 바로 앞의 카드).
func set_shadow(enabled: bool) -> void:
	for sheet in [_face, _back]:
		(sheet as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## 렌더 레이어(캐릭터 손의 카드는 그 캐릭터 레이어 → 자기 1인칭 카메라에는 안 보인다).
func set_layers(mask: int) -> void:
	for node in find_children("*", "VisualInstance3D", true, false):
		(node as VisualInstance3D).layers = mask


## 1인칭 부채 카드 왼쪽 위에 숫자 키(1~7) 표시.
func show_key(text: String) -> void:
	if _key == null:
		_key = Label3D.new()
		_key.name = "Key"
		_key.font = CardFaces.bold_font()
		_key.font_size = 72
		_key.pixel_size = 0.0004
		_key.outline_size = 18
		_key.outline_modulate = Color("122b27")
		_key.modulate = Color("ffe3a3")
		_key.rotation.x = -PI / 2
		# 왼쪽 위 모서리: 부채에서 다음 카드가 오른쪽을 덮어도 보인다.
		_key.position = Vector3(-SIZE.x / 2.0 + 0.013, THICKNESS / 2.0 + 0.0006, -SIZE.y / 2.0 + 0.016)
		_key.double_sided = false
		body.add_child(_key)
	_key.text = text


## 꺼내 든(대기) 카드의 테두리 빛. strength 0 이면 끈다.
func set_glow(strength: float, color: Color = GLOW_COLOR) -> void:
	if _glow == null:
		if strength <= 0.0:
			return
		_glow = MeshInstance3D.new()
		_glow.name = "Glow"
		var mesh := PlaneMesh.new()
		mesh.size = SIZE * 1.22
		_glow.mesh = mesh
		_glow.position.y = -THICKNESS
		_glow.material_override = glow_material().duplicate()
		_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_glow.layers = _face.layers
		body.add_child(_glow)
	_glow.visible = strength > 0.0
	var material := _glow.material_override as StandardMaterial3D
	material.albedo_color = Color(color, clampf(strength, 0.0, 1.0))


## 다 쓴 카드 표시. PAINT = 붓으로 그은 빨간 X, BURN = 가장자리가 타 들어가며 그을림.
func mark_used(style: int) -> Tween:
	mark_style = style
	var tween := create_tween()
	if style == Mark.BURN:
		var material := ShaderMaterial.new()
		material.shader = burn_shader()
		material.set_shader_parameter("face", CardFaces.face(type))
		_face.material_override = material
		tween.tween_method(func(value: float) -> void: material.set_shader_parameter("burn", value), 0.0, 1.0, BURN_SECONDS)
		_embers()
		return tween
	# 붓 두 획: 왼쪽 위 → 오른쪽 아래, 오른쪽 위 → 왼쪽 아래. 획마다 붓끝에서 자라 나온다.
	var half := SIZE * 0.42
	for stroke in [[Vector2(-half.x, -half.y), Vector2(half.x, half.y)], [Vector2(half.x, -half.y), Vector2(-half.x, half.y)]]:
		var from: Vector2 = stroke[0]
		var to: Vector2 = stroke[1]
		var root := Node3D.new()
		root.position = Vector3(from.x, THICKNESS / 2.0 + 0.0008, from.y)
		root.rotation.y = atan2(-(to.x - from.x), -(to.y - from.y))
		root.scale = Vector3(1, 1, 0.001)
		body.add_child(root)
		var brush := MeshInstance3D.new()
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(0.016, from.distance_to(to))
		brush.mesh = mesh
		brush.position.z = -from.distance_to(to) / 2.0
		brush.material_override = paint_material()
		brush.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		brush.layers = _face.layers
		root.add_child(brush)
		tween.tween_property(root, "scale:z", 1.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return tween


## 사용 표시를 지우고 원래 앞면으로(시험·재사용용).
func clear_mark() -> void:
	mark_style = -1
	for child in body.get_children():
		if child != _face and child != _back and child != _glow and child != _key:
			child.queue_free()
	if type >= 0:
		set_type(type)


## 손에서 쓴 카드: 살짝 커졌다가 사라진다.
func vanish(duration: float = 0.35) -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", scale * 1.35, duration * 0.35)
	tween.chain().tween_property(self, "scale", Vector3.ONE * 0.001, duration * 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)


## 카드 한 면(얇은 판)을 만든다. height = 카드 몸 안에서의 높이(앞면·뒷면이 겹쳐 깜빡이지 않게).
func _sheet(sheet_name: String, height: float) -> MeshInstance3D:
	var sheet := MeshInstance3D.new()
	sheet.name = sheet_name
	sheet.mesh = plane_mesh()
	sheet.position.y = height
	body.add_child(sheet)
	return sheet


## 불씨: 짧은 주황 불꽃 입자.
func _embers() -> void:
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.amount = 26
	particles.lifetime = 0.9
	particles.explosiveness = 0.15
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(SIZE.x * 0.5, 0.001, SIZE.y * 0.5)
	particles.direction = Vector3.UP
	particles.spread = 25.0
	particles.initial_velocity_min = 0.05
	particles.initial_velocity_max = 0.16
	particles.gravity = Vector3(0, 0.08, 0)
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.0
	var mesh := SphereMesh.new()
	mesh.radius = 0.0025
	mesh.height = 0.005
	mesh.radial_segments = 6
	mesh.rings = 3
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("ff8a2a")
	mesh.material = material
	particles.mesh = mesh
	particles.position.y = THICKNESS
	body.add_child(particles)
	particles.emitting = true
	get_tree().create_timer(2.0).timeout.connect(particles.queue_free)


## 모든 카드가 함께 쓰는 판 메시(한 번만 만든다).
static func plane_mesh() -> PlaneMesh:
	if _plane == null:
		_plane = PlaneMesh.new()
		_plane.size = SIZE
	return _plane


## 같은 텍스처는 재질 하나를 같이 쓴다. 종이처럼 거칠고 반사가 약하다.
## 스스로 빛나게(발광) 하면 펍 조명·글로우와 겹쳐 색이 하얗게 바랜다(2026-10-28 화면 비교) → 발광은 쓰지 않는다.
static func material_for(texture: Texture2D) -> StandardMaterial3D:
	var key: int = texture.get_instance_id()
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_texture = texture
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.5
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		material.roughness = 0.9
		material.metallic_specular = 0.2
		_materials[key] = material
	return _materials[key]


## 꺼내 든 카드 테두리 빛 재질(모든 카드가 함께 쓴다).
static func glow_material() -> StandardMaterial3D:
	if _glow_material == null:
		_glow_material = StandardMaterial3D.new()
		_glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glow_material.albedo_texture = _soft_rect()
		_glow_material.albedo_color = GLOW_COLOR
	return _glow_material


## 사용 표시 '페인트 칠' 재질(모든 카드가 함께 쓴다).
static func paint_material() -> StandardMaterial3D:
	if _paint_material == null:
		_paint_material = StandardMaterial3D.new()
		_paint_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_paint_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		_paint_material.alpha_scissor_threshold = 0.5
		_paint_material.albedo_texture = _brush_stroke()
		_paint_material.albedo_color = PAINT_COLOR
	return _paint_material


## 사용 표시 '그을림' 셰이더(모든 카드가 함께 쓴다).
static func burn_shader() -> Shader:
	if _burn_shader == null:
		_burn_shader = Shader.new()
		_burn_shader.code = BURN_SHADER
	return _burn_shader


## 가장자리로 갈수록 투명해지는 둥근 사각형(빛 번짐).
static func _soft_rect() -> ImageTexture:
	var image := Image.create(48, 72, false, Image.FORMAT_RGBA8)
	for y in range(72):
		for x in range(48):
			var edge: float = minf(minf(x, 47 - x) / 6.0, minf(y, 71 - y) / 6.0)
			image.set_pixel(x, y, Color(1, 1, 1, clampf(edge, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)


## 붓 자국: 가운데는 진하고 양옆은 들쭉날쭉, 끝은 갈라진다(마른 붓).
static func _brush_stroke() -> ImageTexture:
	var random := RandomNumberGenerator.new()
	random.seed = 77
	var width: int = 32
	var height: int = 256
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var wobble: float = 0.0
	for y in range(height):
		wobble = clampf(wobble + random.randf_range(-0.08, 0.08), -0.25, 0.25)
		var taper: float = minf(1.0, minf(y, height - 1 - y) / 26.0)
		var half: float = (0.36 + wobble * 0.3) * taper + 0.12
		for x in range(width):
			var u: float = absf((x + 0.5) / width - 0.5)
			var dry: bool = taper < 1.0 and random.randf() < 0.35
			image.set_pixel(x, y, Color(1, 1, 1, 1.0 if u < half and not dry else 0.0))
	return ImageTexture.create_from_image(image)
