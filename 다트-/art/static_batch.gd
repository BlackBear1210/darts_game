extends RefCounted
## 실행 중에만 정적 메시를 재질·공간 구역별로 합쳐 그리기 호출을 줄인다(펍 전경 3,445 → 1,747회).
## 에디터에서 여는 .tscn 원본은 바꾸지 않는다. 원래 메시는 숨기기만 한다.
## 다트판과 캐릭터는 묶지 않는다 — 카드 효과(과녁 변형)·애니메이션을 붙일 자리라서다.
## 캐릭터에 관절 애니메이션을 넣으면 그 캐릭터는 optimize() 대상에서 빼야 한다.

## 같은 재질이라도 이 크기(m) 격자 칸이 다르면 따로 묶는다. 화면 밖 묶음은 통째로 컬링되게 하려는 값.
const CELL_SIZE := Vector3(3.0, 2.0, 3.0)
## 표정·깜빡임용 얼굴 부품은 묶지 않는다.
const FACE_PREFIXES: Array[String] = ["Eye", "Pupil", "Brow", "Mouth"]
## 실행 중 움직이는 방 소품(2026-10-31 밤 "건드리기": 바 종이 흔들린다)은 묶지 않는다 — 묶이면 원본이 숨어 흔들림이 안 보인다.
const NO_BATCH_NAMES: Array[String] = ["Bell"]


## root 아래 정적 메시를 묶어 RuntimeStaticBatches 노드에 넣는다. 반환값은 로그·검증용 개수.
static func optimize(root: Node3D) -> Dictionary:
	var groups: Dictionary = {}
	collect(root, root, groups)
	var container := Node3D.new()
	container.name = "RuntimeStaticBatches"
	root.add_child(container)
	var source_count := 0
	var batch_count := 0
	var source_vertices := 0
	var batched_vertices := 0
	for key in groups:
		var group: Dictionary = groups[key]
		var sources: Array = group.sources
		if sources.size() < 2:
			continue
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for source in sources:
			var mesh_instance: MeshInstance3D = source
			var transform := root.global_transform.affine_inverse() * mesh_instance.global_transform
			var arrays := mesh_instance.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			# 크기를 바꾼(scale) 메시도 명암이 틀어지지 않도록 법선은 역전치 행렬로 옮긴다.
			var normal_basis := transform.basis.inverse().transposed()
			# 인덱스가 있는 기본 도형과 인덱스 없는 각진 메시를 같은 방식으로 풀어 넣는다.
			# append_from 만 쓰면 섞인 묶음에서 인덱스 없는 삼각형이 사라지는 문제가 있었다.
			var count := indices.size() if not indices.is_empty() else vertices.size()
			source_vertices += count
			for i in range(count):
				var index := indices[i] if not indices.is_empty() else i
				surface.set_normal((normal_basis * normals[index]).normalized())
				surface.add_vertex(transform * vertices[index])
			mesh_instance.hide()
			source_count += 1
		var batch := MeshInstance3D.new()
		batch.name = "Batch_%03d" % batch_count
		batch.mesh = surface.commit()
		batched_vertices += batch.mesh.surface_get_array_len(0)
		batch.material_override = group.material
		container.add_child(batch)
		batch_count += 1
	assert(source_vertices == batched_vertices, "Static batch dropped geometry")
	return {"source_meshes": source_count, "batches": batch_count, "preserved_triangles": source_vertices / 3}


## 묶을 후보를 "재질 + 격자 칸" 키로 모은다.
static func collect(node: Node, root: Node3D, groups: Dictionary) -> void:
	if node != root and (node.name == "Dartboard" or node.scene_file_path.contains("/characters/")):
		return
	if str(node.name) in NO_BATCH_NAMES:
		return
	if node is MeshInstance3D:
		for prefix in FACE_PREFIXES:
			if str(node.name).begins_with(prefix):
				return
	if node is MeshInstance3D and node.mesh != null and node.mesh.get_surface_count() == 1:
		var material: Material = node.material_override
		if material != null:
			var center: Vector3 = node.global_transform * node.mesh.get_aabb().get_center()
			var cell := Vector3i(floori(center.x / CELL_SIZE.x), floori(center.y / CELL_SIZE.y), floori(center.z / CELL_SIZE.z))
			var key := str(material.get_instance_id()) + "_" + str(cell)
			if not groups.has(key):
				groups[key] = {"material": material, "sources": []}
			groups[key].sources.append(node)
	for child in node.get_children():
		collect(child, root, groups)
