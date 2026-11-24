extends RefCounted
## 실행 중에만 정적 메시를 재질·공간 구역별로 합쳐 그리기 호출을 줄인다(펍 전경 3,445 → 1,747회).
## 에디터에서 여는 .tscn 원본은 바꾸지 않는다.
## [2026-11-24 저사양 최적화] 합친 원본은 **지운다**(예전에는 숨기기만 해서 568개가 트리에 남아 매 프레임 순회 대상이었다).
##   자식이 달린 원본만 숨긴 채 남긴다 — 지우면 묶기에서 빠진 자식까지 같이 사라지기 때문이다.
##   묶은 뒤에 묶음 하나만 되돌리는 길은 원래도 없었다. 방 일부를 빼야 하면 TableView.rebuild_pub 이 씬에서 통째로 다시 만든다.
## 다트판과 캐릭터는 묶지 않는다 — 카드 효과(과녁 변형)·애니메이션을 붙일 자리라서다.
## 캐릭터에 관절 애니메이션을 넣으면 그 캐릭터는 optimize() 대상에서 빼야 한다.

## 같은 재질이라도 이 크기(m) 격자 칸이 다르면 따로 묶는다. 화면 밖 묶음은 통째로 컬링되게 하려는 값.
const CELL_SIZE := Vector3(3.0, 2.0, 3.0)
## 표정·깜빡임용 얼굴 부품은 묶지 않는다.
const FACE_PREFIXES: Array[String] = ["Eye", "Pupil", "Brow", "Mouth"]
## 실행 중 움직이는 방 소품(2026-10-31 밤 "건드리기": 바 종이 흔들린다)은 묶지 않는다 — 묶이면 원본이 숨어 흔들림이 안 보인다.
## "WallPoster"(2026-11-08 저녁) = 벽 액자 만화 포스터. 묶음은 UV 를 옮기지 않아 그림이 사라진다.
## "Service"·"TableFood"·"SmokeFx"(2026-11-08) = 바텐더·직원이 나르는 잔·접시, 손님 앞 랜덤 음식, 시가·연기 — 실행 중에 생기고 움직인다.
## 2026-11-16 창 밖 3D(art/pub/street_outside.gd):
##   "Outside"      = 창 밖 거리·하늘·달. 메시마다 다른 셰이더 값(instance_shader_parameters — 창 불빛·색)이 있고 차·관람차가 움직인다.
##   "WindowGlass"  = 투명 유리(묶으면 투명도·반짝임이 사라진다).
##   "WindowPlugs"  = 오락실에서만 켜는 창 구멍 메우개. 묶기는 숨김을 보지 않아 펍에서도 보이게 된다.
##   (예전 "WindowView" = 유리판에 그린 창 밖 그림 — 2026-11-16 에 없앴다.)
const NO_BATCH_NAMES: Array[String] = ["Bell", "WallPoster", "Service", "TableFood", "SmokeFx", "Outside", "WindowGlass", "WindowPlugs"]
## 이름이 이렇게 시작하는 묶음(아래 전부)은 묶지 않는다.
## "Seat" = 자리 매트·바닥 자리 표시·스툴·자리 글자(2026-11-07): 방 인원수에 따라 TableView.show_seats 가 숨기므로
## 묶여 버리면 원본을 숨겨도 묶음 메시에 그대로 남는다.
const NO_BATCH_PREFIXES: Array[String] = ["Seat"]
## 라운드하우스 GLB(2026-11-08 Codex 묶음 1 v2·2·3) 아래는 통째로 묶지 않는다.
## 이 묶기는 정점·법선만 옮기고 UV·탄젠트·면별 재질을 버려서, 텍스처·노멀맵이 사라진다. 오락기 화면(Screen)처럼
## 대마다 다른 재질을 덮는 부품, 투명 유리·캡슐도 있어 따로 둔다. 묶기를 지원하려면 UV·탄젠트·면 재질·투명도 보존 검증이 먼저다.
const ROUNDHOUSE_DIR := "res://art/environments/roundhouse/"


## optimize_spread 가 한 프레임에 묶는 시간(마이크로초). 넘으면 다음 프레임으로 넘긴다.
const SPREAD_BUDGET_USEC: int = 6000


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
		if group.sources.size() < 2:
			continue
		var counts := _batch_group(root, group, container, batch_count)
		source_count += group.sources.size()
		source_vertices += counts.x
		batched_vertices += counts.y
		batch_count += 1
	assert(source_vertices == batched_vertices, "Static batch dropped geometry")
	return {"source_meshes": source_count, "batches": batch_count, "preserved_triangles": source_vertices / 3}


## optimize 와 같은 묶기를 여러 프레임에 나눠 한다(한 프레임 SPREAD_BUDGET_USEC 까지). 기다리지 않고 부르면 된다.
## [2026-11-17 밤 "실행할 때 렉"] 타이틀 뒤 펍(lobby/lobby_backdrop.gd)이 나타날 때 한 번에 묶으면 0.45초 멈췄다.
## 다 묶기 전에는 아직 안 묶인 메시가 원래대로 보인다(그림은 같고 그리기 호출만 많다).
## 경기 방에는 쓰지 않는다 — 오락실 테마가 묶은 뒤 재질을 바꾸는데(lounge_world._recolor), 늦게 생긴 묶음은 그 색을 놓친다.
static func optimize_spread(root: Node3D, budget_usec: int = SPREAD_BUDGET_USEC) -> void:
	var groups: Dictionary = {}
	collect(root, root, groups)
	var container := Node3D.new()
	container.name = "RuntimeStaticBatches"
	root.add_child(container)
	var started := Time.get_ticks_usec()
	var batch_count := 0
	for key in groups:
		var group: Dictionary = groups[key]
		if group.sources.size() < 2:
			continue
		if Time.get_ticks_usec() - started > budget_usec:
			if not root.is_inside_tree():
				return
			await root.get_tree().process_frame
			# 기다리는 사이 방이 지워졌거나 화면에서 빠졌으면 그만둔다.
			if not is_instance_valid(root) or not root.is_inside_tree() or not is_instance_valid(container):
				return
			started = Time.get_ticks_usec()
		var alive: Array = group.sources.filter(func(source: Variant) -> bool: return is_instance_valid(source))
		if alive.size() < 2:
			continue
		group.sources = alive
		_batch_group(root, group, container, batch_count)
		batch_count += 1


## 한 묶음(같은 재질·같은 격자 칸)을 메시 하나로 합치고 원본은 숨긴다. 반환 = (원본 정점 수, 묶은 정점 수).
static func _batch_group(root: Node3D, group: Dictionary, container: Node3D, batch_index: int) -> Vector2i:
	var source_vertices := 0
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for source in group.sources:
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
		if mesh_instance.get_child_count() == 0:
			mesh_instance.queue_free()
		else:
			mesh_instance.hide()
	var batch := MeshInstance3D.new()
	batch.name = "Batch_%03d" % batch_index
	batch.mesh = surface.commit()
	batch.material_override = group.material
	container.add_child(batch)
	return Vector2i(source_vertices, batch.mesh.surface_get_array_len(0))


## 묶을 후보를 "재질 + 격자 칸" 키로 모은다.
static func collect(node: Node, root: Node3D, groups: Dictionary) -> void:
	if node != root and (node.name == "Dartboard" or node.scene_file_path.contains("/characters/") or node.scene_file_path.begins_with(ROUNDHOUSE_DIR)):
		return
	if str(node.name) in NO_BATCH_NAMES:
		return
	for prefix in NO_BATCH_PREFIXES:
		if str(node.name).begins_with(prefix):
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
