extends "res://art/pub/room/room_kit.gd"
## 바: 카운터 · 맥주 꼭지 · 뒤 선반(병) · 냉장고 · 바 스툴 · 바텐더가 꺼내는 것(커피 머신·전자레인지·토스터)과 손님 자리.
## 디자인 담당 소유(2026-11-17 game_room_builder.gd 에서 나눔). 장면 안 묶음 = Bar.
## 바텐더가 걷는 길·꺼내는 자리는 room_kit.gd 의 BAR_LANE_* 상수와 art/pub/pub_service.gd 가 같이 쓴다.

const RoomGuests = preload("res://art/pub/room/room_guests.gd")
const RoomSeating = preload("res://art/pub/room/room_seating.gd")

# ─────────────────────────────── 바 ───────────────────────────────

## 라운지 왼쪽 벽 바(요청서 P01 "둥근 끝의 바 카운터·발받침"): 월넛 몸통 + 둥근 끝 대리석 상판 + 놋쇠 발받침 +
## 맥주 꼭지·종·컵받침, 뒤 아치 병 선반, 바 스툴 3개, 바텐더. 충돌은 TableView.BAR_BOX.
static func build_bar(p: Node3D) -> void:
	var f := _faces()
	var box: AABB = TableView.BAR_BOX
	var z0: float = box.position.z + 0.1
	var z1: float = box.end.z - 0.1
	var mid: float = (z0 + z1) / 2.0
	var length: float = z1 - z0
	var front: float = box.end.x # 카운터 윗면 앞 끝 x(방 쪽). 스툴은 이 앞에 놓인다.
	var body_x: float = box.get_center().x - 0.08
	var body_front: float = body_x + 0.36
	_back_bar(p, Vector3(f.lounge_x0 + 0.04, 0, mid), length - 0.6)
	# 몸통(둥근 모서리) + 들어간 발치 + 앞면 판넬(조금 밝은 월넛, 칸마다 둥근 상자).
	MeshKit.rounded_box(p, "BarBody", Vector3(0.72, 0.96, length), Vector3(body_x, 0.56, mid), _walnut(), 0.06)
	MeshKit.rounded_box(p, "BarKick", Vector3(0.62, 0.12, length - 0.06), Vector3(body_x - 0.06, 0.06, mid), _walnut_dark(), 0.03)
	var panel_count := maxi(int(length / 1.2), 1)
	for i in range(panel_count):
		var z := z0 + length * (i + 0.5) / panel_count
		MeshKit.rounded_box(p, "BarPanel", Vector3(0.04, 0.66, length / panel_count - 0.22), Vector3(body_front + 0.005, 0.6, z), _panel_wood(), 0.018)
	# 상판: 위에서 보면 끝이 둥근 대리석 판(윗면 = BAR_TOP_Y) + 아래 월넛 테.
	var top_y: float = TableView.BAR_TOP_Y
	MeshKit.mesh_node(p, "BarTop", RoundKit.rounded_slab_mesh(Vector2(box.size.x + 0.04, length + 0.2), 0.06, 0.35), Vector3(box.get_center().x + 0.02, top_y - 0.06, mid), _marble())
	MeshKit.mesh_node(p, "BarTopBand", RoundKit.rounded_slab_mesh(Vector2(box.size.x - 0.02, length + 0.14), 0.05, 0.32), Vector3(box.get_center().x + 0.01, top_y - 0.11, mid), _walnut())
	# 발받침: 앞면을 따라가다 양 끝에서 몸통으로 휘어 드는 놋쇠 관 + 받침 다리.
	var rail_x: float = body_front + 0.14
	var rail := PackedVector3Array([Vector3(body_front, 0.2, z0 + 0.12), Vector3(rail_x - 0.04, 0.2, z0 + 0.2), Vector3(rail_x, 0.2, z0 + 0.32),
		Vector3(rail_x, 0.2, z1 - 0.32), Vector3(rail_x - 0.04, 0.2, z1 - 0.2), Vector3(body_front, 0.2, z1 - 0.12)])
	MeshKit.mesh_node(p, "FootRail", RoundKit.tube_mesh("bar_foot_rail", rail, 0.026, 12), Vector3.ZERO, _brass())
	var bracket_count := maxi(int(length / 1.5), 2)
	for i in range(bracket_count + 1):
		var z := lerpf(z0 + 0.5, z1 - 0.5, float(i) / bracket_count)
		RoundKit.rod(p, "FootRailBracket", Vector3(body_front, 0.12, z), Vector3(rail_x, 0.2, z), 0.012, _brass(), -1.0, 8)
	# 맥주 꼭지 3개(물레 깎은 놋쇠 기둥 + 색 손잡이).
	var tap_post := RoundKit.rounded_profile(PackedVector2Array([Vector2(0, 0), Vector2(0.05, 0), Vector2(0.04, 0.03), Vector2(0.025, 0.06), Vector2(0.025, 0.36), Vector2(0.035, 0.4), Vector2(0, 0.42)]), 0.01, 2)
	for i in range(3):
		var tap := Vector3(body_x - 0.12, top_y, mid - 0.4 + i * 0.4)
		RoundKit.lathe(p, "TapPost", tap_post, tap, _brass(), 16)
		RoundKit.rod(p, "TapHandle", tap + Vector3(0.03, 0.42, 0), tap + Vector3(0.08, 0.6, 0), 0.022, MeshKit.material("TapHandle_" + str(i), ["cf594f", "e4d7ad", "38806a"][i]), 0.03, 10)
	# 종(건드리기 대상 "Bell" — 노드 하나여야 흔들린다) + 받침. 자리는 LoungeWorld.touch_spots 와 같다.
	var bell_at := Vector3(front - 0.25, top_y, z0 + 0.45)
	RoundKit.lathe(p, "BellStand", RoundKit.rounded_profile(PackedVector2Array([Vector2(0, 0), Vector2(0.07, 0), Vector2(0.07, 0.018), Vector2(0.02, 0.03), Vector2(0, 0.032)]), 0.008, 2), bell_at, _walnut_dark(), 20)
	var bell := RoundKit.rounded_profile(PackedVector2Array([Vector2(0, 0.03), Vector2(0.095, 0.03), Vector2(0.088, 0.05), Vector2(0.062, 0.1), Vector2(0.052, 0.15), Vector2(0.03, 0.18), Vector2(0, 0.19)]), 0.02, 3)
	RoundKit.lathe(p, "Bell", bell, bell_at, _brass(), 24)
	# 컵받침: 맥주잔(집어 마시고 던지는 소품, LoungeWorld)이 놓이는 자리. 잔을 들고 가도 받침은 남는다.
	var coaster := PackedVector2Array([Vector2(0, 0), Vector2(0.1, 0), Vector2(0.1, 0), Vector2(0.1, 0.008), Vector2(0.1, 0.008), Vector2(0, 0.008)])
	for at: Vector3 in TableView.BAR_MUGS:
		RoundKit.lathe(p, "Coaster", coaster, at + Vector3(0, 0.001, 0), _brass(), 24)
	# 바 위 안주(빵·치즈). 2026-11-08: 스툴 손님 앞(z 2.5)은 바텐더가 잔·접시를 놓는 자리라 바 안쪽(바텐더 쪽) 끝으로 옮겼다.
	PubParts.asset(p, "bread", Vector3(box.position.x + 0.27, top_y, 1.62), 0.5, Vector3.ONE * 0.7)
	PubParts.asset(p, "cheese", Vector3(box.position.x + 0.25, top_y, 2.02), 1.2, Vector3.ONE * 0.55)
	# 바 끝 재떨이: 여기 서서 시가를 피우는 손님(room_guests.gd build_guests 의 Guest_3)의 자리 표시.
	RoomGuests.ashtray(p, BAR_ASHTRAY, "BarAshtray")
	# 바 끝 작은 화분(라운드하우스 작은 화분, 2026-11-08): 뒤쪽 맥주잔(z 6.7)과 바 끝(z 7.4) 사이, 벽 쪽 절반.
	# 바 묶음(Bar)이라 오락실에서는 바와 함께 빠진다.
	_model(p, "plant_small", Vector3(box.get_center().x - 0.1, top_y, z1 - 0.3), 0.4, "BarPlant")
	for i in range(3):
		RoomSeating.bar_stool(p, Vector3(front + 0.45, 0, _bar_stool_z(i)), "BarStool_%d" % (i + 1))
	_bar_fridge(p)
	# 바텐더: 선수와 같은 리깅 캐릭터 + 바텐더 옷(중절모·콧수염·나비넥타이·조끼·소매 밴드·어깨 수건·앞치마, art/pub/npc_outfit.gd).
	# 2026-11-08 사용자 "바텐더도 가만히 있으면 어색하니까 움직이면서 바에 앉은 AI 캐릭터들한테 따라 주던가 ·
	#   음식은 뒤돌아서 주방의 전자레인지 같은 가구에서 꺼내서 서빙": 바 뒤 통로(BAR_LANE_X)를 걸어 다니며
	#   가운데 꼭지에서 맥주를 따르고, 뒤돌아 조리대 커피 머신에서 커피를 · 전자레인지에서 음식을 꺼내
	#   바 스툴 손님 앞(바 윗면)에 놓고, 다 먹은 잔·접시는 치운다(art/pub/pub_service.gd — 실행 중에만 움직인다).
	var stand := Vector3(BAR_LANE_X, 0, mid)
	var bartender := NpcIdle.spawn(p, "Bartender", stand, stand + Vector3(3.0, 0, 0), Color("e9e2d0"), false, 3, 0.4, NpcIdle.SEAT_TOP, false, NpcOutfit.Outfit.BARTENDER)
	var counter_top: Vector3 = TableView.BACK_COUNTER_AT + Vector3(0.22, 1.0, 0)
	var foods := PackedStringArray(["plate+steak@1.15", "plate+pancakes@0.62", "plate+hotdog@0.72", "plate+burger_ready@0.7",
		"plate+roast_chicken@0.75", "plate+eggs_ready@0.62", "dish_2@0.62", "dish_6@0.62"])
	var customers: Array = []
	# 손님이 앉은 스툴 = 0 · 2번(2026-11-21: 모니터 앞 1번 손님을 0번으로 옮김 — room_guests.gd build_guests).
	for i: int in [0, 2]:
		var z: float = _bar_stool_z(i)
		# [바텐더가 설 z, 음료 자리(손님 오른손 쪽 = −Z), 음식 자리] — 바 윗면 방 쪽 절반.
		customers.append([z, Vector3(front - 0.22, top_y, z - 0.17), Vector3(front - 0.22, top_y, z + 0.15)])
	PubService.make(p, bartender, BAR_LANE_X, BAR_SERVE_X, BAR_LANE_Z, -PI / 2, [
		["drink", mid, -PI / 2, 2.6, PackedStringArray(["mug"]), 0.6, Vector3.ZERO, BAR_SERVE_X],
		["drink", COFFEE_Z, PI / 2, 2.2, PackedStringArray(["coffee_cup_a", "coffee_cup_b"]), 0.62, Vector3.ZERO, BACK_COUNTER_REACH_X],
		["food", MICROWAVE_Z, PI / 2, 3.2, foods, 1.0, Vector3(counter_top.x + 0.3, counter_top.y + 0.18, MICROWAVE_Z), BACK_COUNTER_REACH_X]],
		customers)


## 바 뒤 병 선반(아치 머리 월넛 틀 + 선반 4단 + 선반 아래 빛 + 병). 로컬 +Z = 방 쪽(+X 를 보게 돌린다).
static func _back_bar(p: Node3D, pos: Vector3, width: float) -> void:
	var shelf := Node3D.new()
	shelf.name = "BottleLibrary"
	shelf.position = pos
	shelf.rotation.y = PI / 2
	p.add_child(shelf, true)
	var top: float = 3.75
	MeshKit.rounded_box(shelf, "ShelfBack", Vector3(width, top - 1.1, 0.06), Vector3(0, (top + 1.1) / 2.0, 0.03), _walnut_dark(), 0.02)
	var arch := RoundKit.arch_path(width, 1.1, top, 0.7, 10)
	MeshKit.mesh_node(shelf, "ShelfArch", RoundKit.sweep_mesh("back_bar_arch|%.3f" % width, RoundKit.bead_profile(0.14, 0.09),
		RoundKit.wall_path_rails(arch, Vector3.ZERO, Vector3.RIGHT, Vector3.BACK), false, false), Vector3(0, 0, 0.06), _walnut())
	var shelf_mesh := RoundKit.rounded_slab_mesh(Vector2(width - 0.2, 0.3), 0.045, 0.03)
	for y: float in [1.25, 1.93, 2.61, 3.29]:
		MeshKit.mesh_node(shelf, "Shelf", shelf_mesh, Vector3(0, y - 0.045, 0.21), _walnut())
		var strip := MeshKit.box(shelf, "ShelfLight", Vector3(width - 0.4, 0.014, 0.02), Vector3(0, y - 0.055, 0.32), _warm_glow())
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var count := int(width / 0.365) - 1
	for row in range(3):
		for j in range(count):
			var x := -0.365 * (count - 1) / 2.0 + j * 0.365
			var y := 1.30 + row * 0.68
			# RG Poly 병(코르크 마개·라벨 모양 2종 × 4색). 몇 칸은 비우거나 병조림 단지를 섞어 "줄 맞춘 도형" 느낌을 줄인다.
			var pick: int = (j * 7 + row * 3) % 11
			if pick == 4:
				continue
			var spot := Vector3(x + (0.04 if pick % 3 == 0 else -0.03), y - 0.005, 0.2)
			if PubParts.asset(shelf, "jar" if pick == 7 else "shelf_bottle_%d" % ((j + row) % 4), spot,
					0.4 * (pick % 5) - 0.8, Vector3.ONE * (0.85 if pick == 7 else 1.5)) != null:
				continue
			var bottle := RoundKit.rounded_profile(PackedVector2Array([Vector2(0, 0), Vector2(0.065, 0), Vector2(0.067, 0.24), Vector2(0.03, 0.3), Vector2(0.026, 0.4), Vector2(0, 0.41)]), 0.02, 3)
			RoundKit.lathe(shelf, "Bottle", bottle, spot, MeshKit.material("Bottle_" + str((j + row) % 4), ["3c695b", "af7948", "516a77", "7b4641"][(j + row) % 4], 0.15), 14)


## 바 끝 유리문 음료 냉장고. 라운지가 뒤로 길어지며 생긴 바 끝 틈을 막는다.
## 충돌은 TableView.decor_blocks()(BAR_FRIDGE_AT · BAR_FRIDGE_SIZE). 문(유리)은 방 쪽 +X, 안쪽은 따뜻한 빛 + 병 선반 4칸.
## 2026-11-08: 모서리를 모두 둥글렸다(요청서 "상자를 쌓은 외형 대신 둥근 실루엣").
static func _bar_fridge(p: Node3D) -> void:
	var at: Vector3 = TableView.BAR_FRIDGE_AT
	var size: Vector3 = TableView.BAR_FRIDGE_SIZE
	var front: float = at.x + size.x / 2.0
	var fridge := Node3D.new()
	fridge.name = "DrinkFridge"
	p.add_child(fridge, true)
	# 몸통은 속이 빈 틀(뒤판·옆판·아래·위)이다 — 꽉 찬 상자면 유리문 안의 선반·병이 가려져 안 보인다.
	var depth: float = size.x - 0.02
	MeshKit.rounded_box(fridge, "FridgeBack", Vector3(0.06, size.y, size.z), Vector3(at.x - size.x / 2.0 + 0.03, size.y / 2.0, at.z), _teal(), 0.02)
	for dz: float in [-1.0, 1.0]:
		MeshKit.rounded_box(fridge, "FridgeSide", Vector3(depth, size.y, 0.07), Vector3(at.x - 0.01, size.y / 2.0, at.z + dz * (size.z / 2.0 - 0.035)), _teal(), 0.03)
	MeshKit.rounded_box(fridge, "FridgeBase", Vector3(depth, 0.16, size.z), Vector3(at.x - 0.01, 0.08, at.z), _teal(), 0.03)
	MeshKit.rounded_box(fridge, "FridgeCrown", Vector3(depth, 0.22, size.z), Vector3(at.x - 0.01, size.y - 0.11, at.z), _teal(), 0.04)
	MeshKit.rounded_box(fridge, "FridgeTop", Vector3(size.x + 0.04, 0.06, size.z + 0.04), at + Vector3(0, size.y + 0.03, 0), _walnut(), 0.025)
	MeshKit.rounded_box(fridge, "FridgeKick", Vector3(0.04, 0.12, size.z - 0.04), Vector3(front, 0.06, at.z), _walnut_dark(), 0.015)
	# 안쪽: 따뜻한 빛 판(뒤) + 선반 4칸 + 병. 문 유리는 반투명이라 안이 보인다.
	var inside: float = front - 0.4
	MeshKit.box(fridge, "FridgeGlow", Vector3(0.02, size.y - 0.42, size.z - 0.22), Vector3(inside - 0.08, size.y / 2.0 + 0.06, at.z), MeshKit.material("FridgeLight", "f3e2b8", 0.0, 1.4))
	for shelf in range(4):
		var y: float = 0.36 + shelf * 0.38
		MeshKit.rounded_box(fridge, "FridgeShelf", Vector3(0.42, 0.02, size.z - 0.2), Vector3(inside + 0.12, y, at.z), _brass(), 0.008)
		for slot in range(5):
			var z: float = at.z - size.z / 2.0 + 0.28 + slot * (size.z - 0.56) / 4.0
			if shelf % 2 == 1:
				# 2026-11-08 사용자 "음료도 다양한 에셋(캔 음료)": 둘째·넷째 칸은 캔 음료(RG Poly SodaCan 5종)를 두 개씩 세운다.
				for k in range(2):
					PubParts.asset(fridge, "soda_can_" + "abcde"[(slot * 2 + k + shelf) % 5], Vector3(inside + 0.14, y + 0.01, z + (k - 0.5) * 0.09), slot * 0.7 + k, Vector3.ONE * 1.1)
			else:
				PubParts.asset(fridge, "shelf_bottle_%d" % ((shelf + slot) % 4), Vector3(inside + 0.14, y + 0.01, z), slot * 0.9, Vector3.ONE * 0.75)
	var glass := StandardMaterial3D.new()
	glass.resource_name = "FridgeGlass"
	glass.albedo_color = Color(0.75, 0.88, 0.92, 0.18)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic_specular = 0.9
	MeshKit.box(fridge, "FridgeDoorGlass", Vector3(0.02, size.y - 0.32, size.z - 0.12), Vector3(front + 0.005, size.y / 2.0 + 0.04, at.z), glass)
	for dz: float in [-1.0, 1.0]:
		MeshKit.rounded_box(fridge, "FridgeDoorFrame", Vector3(0.05, size.y - 0.3, 0.06), Vector3(front + 0.01, size.y / 2.0 + 0.04, at.z + dz * (size.z / 2.0 - 0.05)), _walnut_dark(), 0.02)
	RoundKit.rod(fridge, "FridgeHandle", Vector3(front + 0.06, 0.8, at.z - size.z / 2.0 + 0.16), Vector3(front + 0.06, 1.35, at.z - size.z / 2.0 + 0.16), 0.016, _brass(), -1.0, 10)
	var label := MeshKit.label(fridge, "FridgeSign", "시원한 음료", Vector3(front + 0.035, size.y - 0.09, at.z), 40, Color("e0c58d"), 0.003)
	label.rotation.y = PI / 2
