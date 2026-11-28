extends "res://art/pub/room/room_kit.gd"
## 꾸미기 방 상자(2026-11-16): 라운지 뒷벽 문 앞에서 방 안으로 튀어나온 작은 방(벽지·징두리·지붕·문·간판·코트 걸이).
## 디자인 담당 소유(2026-11-17 game_room_builder.gd 에서 나눔). 장면 안 묶음 = PubOnly/FittingRoom.
## 자리·충돌 = TableView.FITTING_ROOM_BOX · F 자리 = lounge_world.WARDROBE_DOOR · 들어가면 열리는 화면 = game/lounge/wardrobe.gd.

## 꾸미기 방(2026-11-16): 뒷벽 문 앞에 방 안으로 튀어나온 작은 방 상자 — 화장실·탈의실처럼 "건물 안의 방"으로 읽히게.
## 사용자 지적 "옆에 창문과 건물 구조상 밖으로 나가는 문으로 느껴진다": 예전 문은 바깥벽(창 사이)의 큰 아치 현관문이었다.
##   → 낮은 지붕(천장보다 1.85m 낮다) · 세이지색 줄무늬 벽지 · 아래 청록 누빔 징두리 · 평범한 네모 나무 문 + "비어 있음" 표시 ·
##     옷걸이 그림 간판 · 문 옆 작은 벽등 · 옆벽에 코트 걸이. 현관 매트는 없다.
## 자리·충돌 = TableView.FITTING_ROOM_BOX(펍 전용 충돌). F 자리 = lounge_world.WARDROBE_DOOR(문 가운데 손잡이 높이).
static func build_fitting_room(pub_only: Node3D) -> void:
	var f := _faces()
	var box: AABB = TableView.FITTING_ROOM_BOX
	var root := Node3D.new()
	root.name = "FittingRoom"
	pub_only.add_child(root, true)
	var x0: float = box.position.x
	var x1: float = box.end.x
	var z0: float = box.position.z
	var z1: float = f.back_z
	var height: float = box.size.y
	var depth: float = z1 - z0
	var paper := RoundKit.clay("FittingWallpaper", "7f9c86", 0.9)
	var stripe := RoundKit.clay("FittingStripe", "a7bea9", 0.9)
	var wall := 0.1
	MeshKit.box(root, "FittingWall", Vector3(x1 - x0, height, wall), Vector3((x0 + x1) / 2.0, height / 2.0, z0 + wall / 2.0), paper)
	for x: float in [x0 + wall / 2.0, x1 - wall / 2.0]:
		MeshKit.box(root, "FittingWall", Vector3(wall, height, depth), Vector3(x, height / 2.0, (z0 + z1) / 2.0), paper)
	# 지붕: 월넛 판 + 앞·옆 둘레 코니스 띠.
	MeshKit.rounded_box(root, "FittingRoof", Vector3(x1 - x0 + 0.12, 0.08, depth + 0.06), Vector3((x0 + x1) / 2.0, height + 0.04, (z0 + z1) / 2.0 - 0.03), _walnut(), 0.02)
	# 세 면(앞 · 왼쪽 · 오른쪽). from = 면 시작 점, along = 면을 따라, inward = 방 쪽(띠가 튀어나오는 쪽).
	var faces: Array = [{"from": Vector2(x0, z0), "along": Vector2(1, 0), "inward": Vector2(0, -1), "length": x1 - x0},
		{"from": Vector2(x0, z0), "along": Vector2(0, 1), "inward": Vector2(-1, 0), "length": depth},
		{"from": Vector2(x1, z0), "along": Vector2(0, 1), "inward": Vector2(1, 0), "length": depth}]
	# 직각으로 만나는 몰딩의 열린 단면을 모서리 기둥과 받침·머리 장식으로 감싼다.
	for x: float in [x0, x1]:
		MeshKit.rounded_box(root, "CornerStile", Vector3(0.115, height, 0.115),
			Vector3(x, height * 0.5, z0), _walnut(), 0.012, 2)
		MeshKit.rounded_box(root, "CornerPlinth", Vector3(0.16, BASE_TOP + 0.025, 0.16),
			Vector3(x, (BASE_TOP + 0.025) * 0.5, z0), _walnut_dark(), 0.009, 2)
		MeshKit.rounded_box(root, "CornerRailCap", Vector3(0.19, RAIL_TOP - WAINSCOT_TOP + 0.023, 0.19),
			Vector3(x, (RAIL_TOP + WAINSCOT_TOP) * 0.5, z0), _walnut(), 0.018, 2)
		MeshKit.rounded_box(root, "CornerCapital", Vector3(0.295, 0.135, 0.295),
			Vector3(x, height - 0.065, z0), _walnut(), 0.017, 2)
	var door_half := 0.56
	var stripe_bar := BoxMesh.new()
	stripe_bar.size = Vector3(0.035, height - 0.12 - RAIL_TOP, 0.006)
	for k in range(faces.size()):
		var face: Dictionary = faces[k]
		var length: float = face.length
		# 앞면은 문 자리(가운데 ± door_half)를 끊는다.
		var spans: Array = [Vector2(0.0, length)]
		if k == 0:
			spans = [Vector2(0.0, length / 2.0 - door_half), Vector2(length / 2.0 + door_half, length)]
		for span: Vector2 in spans:
			var mid := (span.x + span.y) / 2.0
			var width := span.y - span.x
			_on_wall(root, "FittingBaseboard", _band_mesh("base", _base_profile(), width), face, mid, 0.0, _walnut_dark())
			_on_wall(root, "FittingWainscot", RoundKit.channel_panel_mesh(width, WAINSCOT_TOP - BASE_TOP, 0.18, 0.04), face, mid, BASE_TOP, _leather())
			_on_wall(root, "FittingRail", _band_mesh("rail", _rail_profile(), width), face, mid, WAINSCOT_TOP, _walnut())
			# 줄무늬 벽지(허리 난간 위 ~ 코니스 아래, 0.22m 간격).
			var parts: Array = []
			var u := span.x + 0.11
			while u < span.y - 0.05:
				parts.append([stripe_bar, Transform3D(Basis.IDENTITY, Vector3(u - mid, 0, 0))])
				u += 0.22
			if not parts.is_empty():
				_on_wall(root, "FittingStripes", RoundKit.merge("fitting_stripes|%d|%.3f|%.3f" % [k, span.x, span.y], parts), face, mid, (RAIL_TOP + height - 0.12) / 2.0, stripe, 0.005)
		_on_wall(root, "FittingCornice", _band_mesh("cornice", _cornice_profile(), length + 0.1), face, length / 2.0, height - 0.12, _walnut())
	# 문(앞면 가운데): 네모 문틀 + 문짝(판넬 둘) + 손잡이 + 발판 + "비어 있음" 표시.
	var front: Dictionary = faces[0]
	var door := Node3D.new()
	door.name = "FittingDoor"
	door.position = Vector3((x0 + x1) / 2.0, 0, z0)
	door.rotation.y = _yaw(front.inward)
	root.add_child(door, true)
	var frame_path := RoundKit.arch_path(door_half * 2.0 - 0.02, 0.0, 2.22, 0.04, 3)
	MeshKit.mesh_node(door, "DoorFrame", RoundKit.sweep_mesh("fitting_door_frame", RoundKit.bead_profile(0.1, 0.06),
		RoundKit.wall_path_rails(frame_path, Vector3.ZERO, Vector3.RIGHT, Vector3.BACK), false, false), Vector3.ZERO, _walnut_dark())
	var leaf := RoundKit.rounded_polygon(PackedVector2Array([Vector2(-0.46, 0), Vector2(0.46, 0), Vector2(0.46, 2.15), Vector2(-0.46, 2.15)]),
		PackedFloat32Array([0.0, 0.0, 0.03, 0.03]), 3)
	MeshKit.mesh_node(door, "Door", RoundKit.panel_mesh("fitting_door_leaf", leaf, 0.04), Vector3(0, 0, 0.004), _walnut())
	for spec: Array in [[1.55, 0.78], [0.62, 0.72]]:
		MeshKit.rounded_box(door, "DoorPanel", Vector3(0.66, float(spec[1]), 0.022), Vector3(0, float(spec[0]), 0.05), _panel_wood(), 0.025)
	MeshKit.mesh_node(door, "DoorKnob", RoundKit.sphere_mesh(0.038, 14), Vector3(0.36, 1.02, 0.085), _brass())
	MeshKit.rounded_box(door, "DoorKnobRose", Vector3(0.07, 0.14, 0.012), Vector3(0.36, 1.02, 0.05), _brass(), 0.005)
	MeshKit.rounded_box(door, "DoorKick", Vector3(0.84, 0.14, 0.01), Vector3(0, 0.09, 0.05), _brass(), 0.004)
	# "비어 있음" 표시는 윗 판넬 아래쪽 가운데에 붙인다(판넬 앞면 z 0.061 보다 앞 — 판넬에 묻히지 않게).
	MeshKit.rounded_box(door, "VacancyPlate", Vector3(0.3, 0.085, 0.01), Vector3(0, 1.3, 0.068), _brass(), 0.004)
	MeshKit.mesh_node(door, "VacancyDot", RoundKit.sphere_mesh(0.014, 8), Vector3(-0.1, 1.3, 0.075), MeshKit.material("VacancyGreen", "5be37d", 0.0, 1.4))
	MeshKit.label(door, "VacancyText", "비어 있음", Vector3(0.025, 1.3, 0.0735), 24, Color("3b2a1d"), 0.0014)
	# 간판(문 위): 진한 판 + 놋쇠 테두리 + 옷걸이 그림 + "꾸미기 방".
	var sign_y := 2.56
	MeshKit.rounded_box(door, "FittingSignFrame", Vector3(0.86, 0.46, 0.035), Vector3(0, sign_y, 0.02), _brass(), 0.03)
	MeshKit.rounded_box(door, "FittingSignBoard", Vector3(0.8, 0.4, 0.03), Vector3(0, sign_y, 0.03), PubParts.dark(), 0.025)
	var hanger := PackedVector3Array([Vector3(-0.15, -0.04, 0), Vector3(0.15, -0.04, 0), Vector3(0.02, 0.05, 0), Vector3(0.0, 0.065, 0),
		Vector3(0.0, 0.09, 0), Vector3(0.025, 0.11, 0), Vector3(0.0, 0.13, 0), Vector3(-0.02, 0.115, 0)])
	var hanger_path := PackedVector3Array([hanger[2], hanger[0], hanger[1], hanger[2], hanger[3], hanger[4], hanger[5], hanger[6], hanger[7]])
	MeshKit.mesh_node(door, "FittingSignHanger", RoundKit.tube_mesh("fitting_hanger", hanger_path, 0.011, 6), Vector3(0, sign_y + 0.05, 0.05), MeshKit.material("SignGold", "e0c58d", 0.0, 0.5))
	MeshKit.label(door, "FittingSignText", "꾸미기 방", Vector3(0, sign_y - 0.12, 0.05), 40, Color("e0c58d"), 0.0024)
	# 문 옆 작은 벽등(방에서 보면 문 왼쪽).
	_sconce(root, Vector3((x0 + x1) / 2.0 + 0.82, 2.05, z0 - 0.005), Vector3(0, 0, -1), 0.28)
	# 옆벽(오른쪽, 당구대 쪽) 코트 걸이 — 예전엔 뒷벽 문 옆(x 9.62)에 있었다.
	_model(root, "coat_rack", Vector3(x1, COAT_RACK_Y, (z0 + z1) / 2.0), -PI / 2.0, "CoatRack")
