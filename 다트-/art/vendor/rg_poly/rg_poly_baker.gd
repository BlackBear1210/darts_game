extends SceneTree
## RG Poly 모델(.glb) 측정·굽기 도구(2026-10-31 밤). 게임 실행 중에는 쓰이지 않는다.
## 원본 팩은 저장소 밖에 둔다. --source 에는 팩을 푼 폴더(rest/Models/…, med/Models/… 가 있는 곳)를 준다.
##
##   측정표(창 모드): godot --path . --script res://art/vendor/rg_poly/rg_poly_baker.gd -- --sheet --source=<팩 폴더> [--only=city:]
##     → .godot/rg_poly_sheet/sheet_N.png(모델 그림 + 가로×높이×깊이 m) + sizes.tsv
##     --only=<앞글자> 를 주면 그 글자로 시작하는 후보만 찍는다(2026-10-31 늦은 밤: city: = Cartoon City 팩).
##   굽기(창 없이):   godot --headless --path . --script res://art/vendor/rg_poly/rg_poly_baker.gd -- --bake --source=<팩 폴더>
##     → art/vendor/rg_poly/meshes/<이름>.res (rg_poly_catalog.gd used() 목록)
##
## 굽는 방법: 삼각형마다 텍스처 좌표(UV) 가운데 점의 색을 읽어 그 삼각형 세 꼭짓점에 같은 색을 준다(면마다 한 색).
## 그 색은 RgPolyCatalog.pub_color 로 펍 팔레트 쪽으로 옮긴다. 텍스처가 없는 재질은 재질 색을 쓴다.
## 편집기를 열어 둔 채 돌려도 된다(--import 를 쓰지 않는다). 새 .res 는 편집기가 다시 훑을 때 목록에 나타난다.

const Catalog = preload("res://art/vendor/rg_poly/rg_poly_catalog.gd")
## 측정표 한 칸 크기(px)와 한 장의 칸 수.
const CELL := 240
const COLUMNS := 8
const ROWS := 5

var _source: String = ""
## 텍스처 → Image (같은 아틀라스를 여러 번 읽지 않게)
var _images: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--source="): _source = arg.trim_prefix("--source=")
	if _source.is_empty() or not DirAccess.dir_exists_absolute(_source):
		printerr("팩 폴더를 --source=<경로> 로 주세요: ", _source)
		quit(1)
		return
	if "--sheet" in args:
		await _sheet()
	else:
		_bake_all()
	quit()


## "팩:파일이름" → .glb 절대 경로(팩 폴더 안을 뒤진다). 못 찾으면 "".
func find_glb(spec: String) -> String:
	var parts := spec.split(":")
	return _search(_source.path_join(parts[0]), parts[1] + ".glb")


func _search(dir: String, file_name: String) -> String:
	if FileAccess.file_exists(dir.path_join(file_name)):
		return dir.path_join(file_name)
	for sub in DirAccess.get_directories_at(dir):
		var found := _search(dir.path_join(sub), file_name)
		if not found.is_empty(): return found
	return ""


## glb 를 읽어 면마다 한 색인 메시 하나로 합친다. pull·overrides 는 RgPolyCatalog.pub_color 와 같다.
func bake_mesh(path: String, pull: float, overrides: Dictionary) -> ArrayMesh:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(path, state) != OK:
		return null
	var scene := document.generate_scene(state)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	_collect(scene, Transform3D.IDENTITY, pull, overrides, vertices, normals, colors)
	scene.free()
	if vertices.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## 노드 트리를 내려가며 메시 삼각형을 모은다. parent_xform = 장면 뿌리 기준 변환.
func _collect(node: Node, parent_xform: Transform3D, pull: float, overrides: Dictionary,
		vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray) -> void:
	var xform := parent_xform
	if node is Node3D:
		xform = parent_xform * (node as Node3D).transform
	var mesh: Mesh = null
	if node is MeshInstance3D:
		mesh = (node as MeshInstance3D).mesh
	elif node is ImporterMeshInstance3D and (node as ImporterMeshInstance3D).mesh != null:
		mesh = (node as ImporterMeshInstance3D).mesh.get_mesh()
	if mesh != null:
		var normal_basis := xform.basis.inverse().transposed()
		for surface in range(mesh.get_surface_count()):
			var arrays := mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var surface_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var material := mesh.surface_get_material(surface) as BaseMaterial3D
			var image: Image = _image_of(material)
			var flat: Color = material.albedo_color if material != null else Color.WHITE
			var count := indices.size() if not indices.is_empty() else points.size()
			for t in range(0, count - 2, 3):
				var ids := [indices[t], indices[t + 1], indices[t + 2]] if not indices.is_empty() else [t, t + 1, t + 2]
				var color := flat
				if image != null and not uvs.is_empty():
					var uv: Vector2 = (uvs[ids[0]] + uvs[ids[1]] + uvs[ids[2]]) / 3.0
					color = image.get_pixel(clampi(int(fposmod(uv.x, 1.0) * image.get_width()), 0, image.get_width() - 1),
						clampi(int(fposmod(uv.y, 1.0) * image.get_height()), 0, image.get_height() - 1)) * flat
				color = Catalog.pub_color(color, pull, overrides)
				for id: int in ids:
					vertices.append(xform * points[id])
					normals.append((normal_basis * surface_normals[id]).normalized() if not surface_normals.is_empty() else Vector3.UP)
					colors.append(color)
	for child in node.get_children():
		_collect(child, xform, pull, overrides, vertices, normals, colors)


func _image_of(material: BaseMaterial3D) -> Image:
	if material == null or material.albedo_texture == null:
		return null
	var texture := material.albedo_texture
	if not _images.has(texture):
		var image := texture.get_image()
		if image != null and image.is_compressed(): image.decompress()
		_images[texture] = image
	return _images[texture]


## 모든 메시가 같이 쓰는 재질: 정점 색 = 바탕색, 펍 소품처럼 무광.
static func shared_material() -> StandardMaterial3D:
	if ResourceLoader.exists(Catalog.MATERIAL_PATH):
		return load(Catalog.MATERIAL_PATH)
	var material := StandardMaterial3D.new()
	material.resource_name = "RgPolyVertexColor"
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.8
	material.metallic_specular = 0.2
	ResourceSaver.save(material, Catalog.MATERIAL_PATH)
	return load(Catalog.MATERIAL_PATH)


## used() 목록을 전부 굽는다.
func _bake_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Catalog.MESH_DIR))
	var material := shared_material()
	var made := 0
	var used: Dictionary = Catalog.used()
	for key: String in used:
		var entry: Array = used[key]
		var path := find_glb(entry[0])
		if path.is_empty():
			printerr("원본 없음: ", entry[0])
			continue
		var mesh := bake_mesh(path, float(entry[1]), entry[2] if entry.size() > 2 else {})
		if mesh == null:
			printerr("굽기 실패: ", entry[0])
			continue
		mesh.resource_name = key
		mesh.surface_set_material(0, material)
		ResourceSaver.save(mesh, Catalog.MESH_DIR.path_join(key + ".res"), ResourceSaver.FLAG_COMPRESS)
		var size := mesh.get_aabb().size
		print("%s ← %s  %.2f×%.2f×%.2f m  %d면" % [key, entry[0], size.x, size.y, size.z, mesh.surface_get_array_len(0) / 3])
		made += 1
	print("BAKED %d / %d" % [made, used.size()])


## 측정표: 후보마다 구운 모양을 같은 각도로 찍고 크기를 적는다(창 모드라야 그림이 나온다).
func _sheet() -> void:
	var output := "res://.godot/rg_poly_sheet"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(CELL, CELL)
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("e9e3d4")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("ffffff")
	environment.environment.ambient_light_energy = 0.55
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.1
	world.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	world.add_child(camera)
	camera.make_current()
	var label := Label.new()
	label.position = Vector2(4, 2)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("1c1a17"))
	root.add_child(label)
	var holder := MeshInstance3D.new()
	world.add_child(holder)
	var sheet: Image = null
	var page := 0
	var slot := 0
	var table := "name\tsize_x\tsize_y\tsize_z\tmin_y\tfaces\n"
	# --only=<앞글자>[,<앞글자>...] : 쉼표로 여러 개 줄 수 있다(하나라도 맞으면 찍는다).
	var only: PackedStringArray = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=").split(",", false)
	for spec: String in Catalog.CANDIDATES:
		if not only.is_empty() and not Array(only).any(func(prefix: String) -> bool: return spec.begins_with(prefix)):
			continue
		var path := find_glb(spec)
		var mesh: ArrayMesh = bake_mesh(path, 0.75, {}) if not path.is_empty() else null
		if mesh == null:
			table += "%s\tMISSING\n" % spec
			continue
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.vertex_color_is_srgb = true
		mesh.surface_set_material(0, material)
		holder.mesh = mesh
		var box := mesh.get_aabb()
		var radius: float = maxf(box.size.length() * 0.5, 0.05)
		camera.size = radius * 2.2
		camera.position = box.get_center() + Vector3(1, 0.8, 1.4).normalized() * radius * 4.0
		camera.look_at(box.get_center())
		camera.near = 0.01
		camera.far = radius * 10.0
		label.text = "%s\n%.2f × %.2f × %.2f m" % [spec, box.size.x, box.size.y, box.size.z]
		table += "%s\t%.3f\t%.3f\t%.3f\t%.3f\t%d\n" % [spec, box.size.x, box.size.y, box.size.z, box.position.y, mesh.surface_get_array_len(0) / 3]
		await process_frame
		await RenderingServer.frame_post_draw
		var shot := root.get_texture().get_image()
		if sheet == null:
			sheet = Image.create(CELL * COLUMNS, CELL * ROWS, false, shot.get_format())
			sheet.fill(Color.WHITE)
		sheet.blit_rect(shot, Rect2i(0, 0, CELL, CELL), Vector2i((slot % COLUMNS) * CELL, (slot / COLUMNS) * CELL))
		slot += 1
		if slot == COLUMNS * ROWS:
			sheet.save_png(output.path_join("sheet_%d.png" % page))
			page += 1
			slot = 0
			sheet = null
	if sheet != null:
		sheet.save_png(output.path_join("sheet_%d.png" % page))
	var file := FileAccess.open(output.path_join("sizes.tsv"), FileAccess.WRITE)
	file.store_string(table)
	file.close()
	print("SHEET pages=%d → %s" % [page + 1, ProjectSettings.globalize_path(output)])
