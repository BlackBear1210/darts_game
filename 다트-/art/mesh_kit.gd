extends RefCounted
## 아트 공용 도형 도구. 다운로드한 모델·텍스처 없이 코드로 로우폴리 메시를 만든다.
## 사용처: art/characters/character_factory.gd, art/pub/pub_builder.gd, art/showcase/showcase.gd(손에 든 다트).
## 단위는 미터, 부모 노드 기준 로컬 좌표다.

## 같은 key 의 재질을 한 번만 만들어 재사용한다(배치 결합 시 같은 재질끼리 묶이게 하려는 목적).
static var materials: Dictionary = {}


## 단색 재질. metal > 0 이면 금속, glow > 0 이면 스스로 빛나는 재질(전구·선반 조명).
## resource_local_to_scene: 나중에 캐릭터별로 색을 바꿔도 다른 인스턴스에 번지지 않게 한다.
static func material(key: String, color: String, metal := 0.0, glow := 0.0) -> StandardMaterial3D:
	if materials.has(key):
		return materials[key]
	var m := StandardMaterial3D.new()
	m.resource_name = key
	m.resource_local_to_scene = true
	m.albedo_color = Color(color)
	m.roughness = 0.78 if metal == 0.0 else 0.35
	m.metallic = metal
	m.metallic_specular = 0.18
	if glow > 0:
		m.emission_enabled = true
		m.emission = Color(color)
		m.emission_energy_multiplier = glow
	materials[key] = m
	return m


static func mesh_node(parent: Node, name_: String, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name_
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	parent.add_child(node)
	return node


static func box(parent: Node, name_: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh_node(parent, name_, mesh, pos, mat)


## 각진 원기둥. sides 가 적을수록 각이 진다(캐릭터 팔다리 6각, 머리 8각).
## top 을 주면 위쪽 반지름이 달라져 원뿔대가 된다.
static func cylinder(parent: Node, name_: String, radius: float, height: float, pos: Vector3, mat: Material, sides := 12, top := -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0 else top
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	return mesh_node(parent, name_, flat_mesh(mesh), pos, mat)


## 면마다 법선을 따로 계산해 "스무딩 전 로우폴리" 각진 명암을 만든다(디자인 방향의 핵심).
static func flat_mesh(source: Mesh) -> ArrayMesh:
	var arrays := source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	for index in indices:
		surface.add_vertex(vertices[index])
	surface.generate_normals()
	return surface.commit()


static func sphere(parent: Node, name_: String, radius: float, pos: Vector3, mat: Material, scale_: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	mesh.radial_segments = 12
	mesh.rings = 6
	var node := mesh_node(parent, name_, mesh, pos, mat)
	node.scale = scale_
	return node


## 점 a 에서 b 까지 이어지는 막대(소매·다리·난간 줄). 원기둥의 위쪽(+Y)을 a→b 방향으로 돌린다.
static func rod(parent: Node, name_: String, a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var node := cylinder(parent, name_, radius, a.distance_to(b), (a + b) * 0.5, mat, 8)
	var direction := (b - a).normalized()
	var axis := Vector3.UP.cross(direction)
	if axis.length() > 0.0001:
		node.quaternion = Quaternion(axis.normalized(), Vector3.UP.angle_to(direction))
	return node


## 3D 공간에 쓰는 글자(간판·다트판 숫자). 글자를 이미지에 굽지 않는다는 디자인 규칙을 따른다.
static func label(parent: Node, name_: String, text_: String, pos: Vector3, size := 48, color: Color = Color("ecdfbf"), pixel := 0.002) -> Label3D:
	var node := Label3D.new()
	node.name = name_
	node.text = text_
	node.position = pos
	node.font_size = size
	node.pixel_size = pixel
	node.modulate = color
	node.outline_size = 0
	node.no_depth_test = false
	parent.add_child(node)
	return node


## 다트판의 부채꼴 한 칸(링 하나 × 숫자 구역 하나). 각도는 12시가 0, 시계 방향으로 증가한다.
## 앞면 법선은 +Z(Vector3.BACK) — 팀 과녁 규칙(앞면 XY, 법선 +Z)과 같다.
static func sector(parent: Node, name_: String, inner: float, outer: float, start: float, end: float, z: float, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 5
	for i in range(steps):
		var a := lerpf(start, end, float(i) / steps)
		var b := lerpf(start, end, float(i + 1) / steps)
		var p := Vector3(sin(a) * inner, cos(a) * inner, z)
		var q := Vector3(sin(a) * outer, cos(a) * outer, z)
		var r := Vector3(sin(b) * outer, cos(b) * outer, z)
		var s := Vector3(sin(b) * inner, cos(b) * inner, z)
		for v in [p, q, r, p, r, s]:
			st.set_normal(Vector3.BACK)
			st.add_vertex(v)
	var mesh := st.commit()
	# 양면 렌더: 다른 툴로 내보내도 앞뒤 방향 실수로 판이 사라지지 않게 한다.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mesh_node(parent, name_, mesh, Vector3.ZERO, mat)


## 씬으로 저장하기 전에 모든 자식의 owner 를 root 로 지정한다(owner 가 없으면 .tscn 에 저장되지 않는다).
## 다른 씬을 인스턴스한 노드(캐릭터)의 내부는 그 씬 파일이 소유하므로 내려가지 않는다.
static func own_tree(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		if child.scene_file_path.is_empty():
			own_tree(child, root)
