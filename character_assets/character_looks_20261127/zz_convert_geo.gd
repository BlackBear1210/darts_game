extends SceneTree
## geo.json(hair_geo.py 출력) → res://art/characters/character_look_data.res (압축 이진).
## 저장소 밖 생성 도구. 쓰는 법은 character_assets/character_looks_20261127/README.md.
##   godot --headless --path <다트-> --script res://tests/zz_convert_geo.gd -- <geo.json 절대 경로>

const DataScript = preload("res://art/characters/character_look_data.gd")
const OUT := "res://art/characters/character_look_data.res"


func _initialize() -> void:
	var path: String = OS.get_cmdline_user_args()[0]
	var geo: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var data: Resource = DataScript.new()
	data.head_surface = int(geo["head_surface"])
	# 승인 모델 머리 면 정점 수(모델을 다시 만들면 달라진다 → 게임이 눌러 넣기를 건너뛰는 표시).
	var model: Node3D = (load("res://art/characters/rigged/approved_player.tscn") as PackedScene).instantiate()
	var body := model.find_child("Body", true, false) as MeshInstance3D
	data.head_vertex_count = (body.mesh.surface_get_arrays(data.head_surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	model.free()
	var index := PackedInt32Array()
	var position := PackedVector3Array()
	var moved_pos: Array = geo["moved_pos"]
	var moved_idx: Array = geo["moved_idx"]
	for k in range(moved_idx.size()):
		index.append(int(moved_idx[k]))
		var p: Array = moved_pos[k]
		position.append(Vector3(p[0], p[1], p[2]))
	data.moved_index = index
	data.moved_position = position
	var parts: Array[Dictionary] = []
	for id: String in geo["styles"]:
		for part: Dictionary in geo["styles"][id]:
			parts.append(_part(id, "hair", str(part.get("c", "hair")), "head", 0.035, part))
	for id: String in geo.get("extras", {}):
		for part: Dictionary in geo["extras"][id]:
			parts.append(_part(id, "extra", str(part["c"]), str(part.get("bone", "spine")), float(part.get("shade", 0.03)), part))
	data.parts = parts
	var err := ResourceSaver.save(data, OUT, ResourceSaver.FLAG_COMPRESS)
	print("SAVED ", OUT, " err=", err, " head_vertices=", data.head_vertex_count, " moved=", index.size(), " parts=", parts.size())
	quit()


func _part(id: String, kind: String, color: String, bone: String, shade: float, part: Dictionary) -> Dictionary:
	var v := PackedVector3Array()
	for p: Array in part["v"]:
		v.append(Vector3(p[0], p[1], p[2]))
	var t := PackedInt32Array()
	for tri: Array in part["t"]:
		t.append_array([int(tri[0]), int(tri[1]), int(tri[2])])
	return {"id": id, "kind": kind, "color": color, "bone": bone, "shade": shade, "v": v, "t": t}
