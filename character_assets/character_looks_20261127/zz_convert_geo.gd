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
	# 승인 모델 머리 면 정점 수(모델을 다시 만들면 달라진다 → 게임이 인형 머리 만들기를 건너뛰는 표시).
	var model: Node3D = (load("res://art/characters/rigged/approved_player.tscn") as PackedScene).instantiate()
	var body := model.find_child("Body", true, false) as MeshInstance3D
	data.head_vertex_count = (body.mesh.surface_get_arrays(data.head_surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	model.free()
	data.head_rigid_src = int(geo["head_rigid_src"])
	# 인형 머리: 캐릭터 키 → {v, n, k(색 키), seam(이음새 원래 정점 번호 또는 −1)}.
	var heads: Dictionary = {}
	var head_info: Array[String] = []
	for id: String in geo["heads"]:
		var src: Dictionary = geo["heads"][id]
		var v := PackedVector3Array()
		for p: Array in src["v"]:
			v.append(Vector3(p[0], p[1], p[2]))
		var n := PackedVector3Array()
		for q: Array in src["n"]:
			n.append(Vector3(q[0], q[1], q[2]).normalized())
		var k := PackedByteArray()
		for c in src["k"]:
			k.append(int(c))
		var seam := PackedInt32Array()
		for s in src["seam"]:
			seam.append(int(s))
		var head: Dictionary = {"v": v, "n": n, "k": k, "seam": seam}
		# v6(2026-11-28 밤): 승인 얼굴 원본 면을 그대로 쓰는 머리 — 정점을 나눠 쓰는 번호 목록(i)과 뼈 가중치 원본(w).
		if src.has("i"):
			var index := PackedInt32Array()
			for x in src["i"]:
				index.append(int(x))
			var bone_src := PackedInt32Array()
			for x in src["w"]:
				bone_src.append(int(x))
			assert(index.size() % 3 == 0 and bone_src.size() == v.size())
			head["i"] = index
			head["w"] = bone_src
		assert(v.size() == n.size() and v.size() == k.size() and v.size() == seam.size() and (src.has("i") or v.size() % 3 == 0))
		heads[id] = head
		head_info.append("%s=%d" % [id, (head["i"] as PackedInt32Array).size() / 3 if head.has("i") else v.size() / 3])
	data.heads = heads
	var parts: Array[Dictionary] = []
	# 헤어 부품: id = 헤어 키. 색 키는 조각마다(기본 "hair", 포니테일 머리끈 "tie").
	for hair: String in geo["hairs"]:
		for part: Dictionary in geo["hairs"][hair]:
			parts.append(_part(hair, "hair", str(part.get("c", "hair")), "head", float(part.get("shade", 0.04)), part))
	for id: String in geo.get("extras", {}):
		for part: Dictionary in geo["extras"][id]:
			parts.append(_part(id, "extra", str(part["c"]), str(part.get("bone", "spine")), float(part.get("shade", 0.03)), part))
	data.parts = parts
	var err := ResourceSaver.save(data, OUT, ResourceSaver.FLAG_COMPRESS)
	print("SAVED ", OUT, " err=", err, " head_vertices=", data.head_vertex_count, " doll_head_tris ", ", ".join(PackedStringArray(head_info)),
		" rigid_src=", data.head_rigid_src, " parts=", parts.size())
	quit()


func _part(id: String, kind: String, color: String, bone: String, shade: float, part: Dictionary) -> Dictionary:
	var v := PackedVector3Array()
	for p: Array in part["v"]:
		v.append(Vector3(p[0], p[1], p[2]))
	var t := PackedInt32Array()
	for tri: Array in part["t"]:
		t.append_array([int(tri[0]), int(tri[1]), int(tri[2])])
	return {"id": id, "kind": kind, "color": color, "bone": bone, "shade": shade, "v": v, "t": t}
