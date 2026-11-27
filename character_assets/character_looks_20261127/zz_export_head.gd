extends SceneTree
## 머리·몸 메시 정점(쉬는 자세 좌표 = 메시 정점, 스킨 바인드가 단위 행렬이라고 가정 → 확인)과 텍스처 색을 JSON 으로 내보낸다.
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var model: Node3D = (load("res://art/characters/rigged/approved_player.tscn") as PackedScene).instantiate()
	root.add_child(model)
	var data := {}
	var tex := {}
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var surfs := []
		for s in range(mi.mesh.get_surface_count()):
			var a := mi.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var nn: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
			var uv = a[Mesh.ARRAY_TEX_UV]
			var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
			var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
			var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
			var mat := mi.mesh.surface_get_material(s) as StandardMaterial3D
			var img: Image = null
			if mat and mat.albedo_texture:
				var p := mat.albedo_texture.resource_path
				if not tex.has(p):
					var im := Image.load_from_file(ProjectSettings.globalize_path(p))
					tex[p] = im
				img = tex[p]
			var pos := []
			var cols := []
			var uvs := []
			var nor := []
			for i in v.size():
				pos.append([snappedf(v[i].x, 0.00001), snappedf(v[i].y, 0.00001), snappedf(v[i].z, 0.00001)])
				nor.append([snappedf(nn[i].x, 0.001), snappedf(nn[i].y, 0.001), snappedf(nn[i].z, 0.001)])
				if uv != null and img != null:
					var u: Vector2 = (uv as PackedVector2Array)[i]
					uvs.append([u.x, u.y])
					var px := Vector2i(clampi(int(fposmod(u.x, 1.0) * img.get_width()), 0, img.get_width() - 1), clampi(int(fposmod(u.y, 1.0) * img.get_height()), 0, img.get_height() - 1))
					var c := img.get_pixelv(px)
					cols.append([snappedf(c.r, 0.001), snappedf(c.g, 0.001), snappedf(c.b, 0.001)])
			var stride := bones.size() / v.size()
			var bw := []
			for i in v.size():
				var best := -1
				var bwv := 0.0
				for j in stride:
					if w[i * stride + j] > bwv:
						bwv = w[i * stride + j]; best = bones[i * stride + j]
				bw.append(best)
			surfs.append({"pos": pos, "nor": nor, "col": cols, "uv": uvs, "bone": bw, "idx": Array(idx), "stride": stride})
		var binds := []
		for b in mi.skin.get_bind_count():
			binds.append([str(mi.skin.get_bind_name(b)), var_to_str(mi.skin.get_bind_pose(b))])
		data[str(mi.name)] = {"surfaces": surfs, "binds": binds}
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	print("EXPORTED")
	quit()
