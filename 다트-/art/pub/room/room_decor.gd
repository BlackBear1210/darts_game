extends "res://art/pub/room/room_kit.gd"
## 꾸밈: 창(틀·커튼·유리) · 벽 그림(포스터) · 문·간판·화분 · 가구 모델(소파·축음기·옷걸이…) · 인디 펍 선반 소품.
## 디자인 담당 소유(2026-11-17 game_room_builder.gd 에서 나눔). 장면 안 묶음 = Decor · Windows · Furnishings · PubOnly(IndieDecor…).
## PubOnly 안의 것은 오락실 테마에서 빠진다(lounge_world.ARCADE_SKIP). 꾸미기 방 상자는 room_fitting.gd, 과녁 벽 양옆은 room_board_sides.gd.
## Keg·PracticeTarget·Gramophone 이름은 "건드리기"(LoungeWorld.touch_spots)가 찾는다 — 이름을 바꾸지 않는다.

const RoomFitting = preload("res://art/pub/room/room_fitting.gd")

# ─────────────────────────────── 창·문·간판·화분·그림 ───────────────────────────────

## 둥근 머리 아치 창(요청서 P09: 창 밖은 추상적인 밤 색면). 로컬 +Z = 방 쪽, 원점 = 벽 면 바닥.
static func _window(parent: Node3D, at: Vector2, inward: Vector2) -> Node3D:
	var root := Node3D.new()
	root.name = "Window"
	root.position = Vector3(at.x, 0, at.y)
	root.rotation.y = _yaw(inward)
	parent.add_child(root, true)
	var half := GLASS_HALF
	var spring := WINDOW_TOP - half
	# 유리: 벽 구멍(_window_hole) 한가운데(벽 면에서 6cm 바깥)의 거의 투명한 판. 너머로 art/pub/street_outside.gd 의 3D 거리가 보인다.
	# 2026-11-16 이전 = 유리판에 그린 밤거리 그림(WindowView, window_view.gdshader) → 편집기에서는 바깥이 안 보였고 창마다 그림이 따로 놀았다.
	MeshKit.mesh_node(root, "WindowGlass", RoundKit.flat_shape_mesh("window_glass", _window_outline(12)), Vector3(0, 0, -0.06), _window_glass()).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 틀: 둥근 띠를 아치 길 따라 민다 + 창살(세로 1 · 가로 1 · 반원 안 부챗살 2).
	var frame_path := RoundKit.arch_path(half * 2.0 + 0.05, WINDOW_BOTTOM - 0.02, WINDOW_TOP + 0.025, half + 0.025, 14)
	MeshKit.mesh_node(root, "WindowFrame", RoundKit.sweep_mesh("window_frame", RoundKit.bead_profile(0.11, 0.06),
		RoundKit.wall_path_rails(frame_path, Vector3.ZERO, Vector3.RIGHT, Vector3.BACK), false, false), Vector3.ZERO, _walnut())
	MeshKit.rounded_box(root, "Mullion", Vector3(0.035, WINDOW_TOP - WINDOW_BOTTOM, 0.03), Vector3(0, (WINDOW_TOP + WINDOW_BOTTOM) / 2.0, 0.03), _walnut_dark(), 0.012)
	MeshKit.rounded_box(root, "MullionHorizontal", Vector3(half * 2.0, 0.035, 0.03), Vector3(0, spring, 0.03), _walnut_dark(), 0.012)
	for side: float in [-1.0, 1.0]:
		var tip := Vector3(cos(PI / 2.0 - side * PI / 4.0) * half, spring + sin(PI / 2.0 - side * PI / 4.0) * half, 0.03)
		RoundKit.rod(root, "MullionFan", Vector3(0, spring, 0.03), tip, 0.014, _walnut_dark(), -1.0, 8)
	MeshKit.rounded_box(root, "Sill", Vector3(half * 2.0 + 0.3, 0.07, 0.24), Vector3(0, WINDOW_BOTTOM - 0.06, 0.1), _walnut(), 0.03)
	# 커튼: 라운드하우스 커튼 한 쌍(봉·좌우 커튼·묶는 끈·봉 끝 장식이 한 모델 — 2026-11-08 Codex 묶음 1 v2).
	# 예전 주름 천 두 폭 + 놋쇠 봉 + 봉 끝 공을 이 모델로 바꿨다. 원점 = 봉 가운데, 예전 봉 자리(높이 CURTAIN_ROD_Y, 벽에서 0.12m)에 둔다.
	# 모델 정면(-Z)이 방 안(창 로컬 +Z)을 보게 반 바퀴 돌린다.
	_model(root, "curtain_pair", Vector3(0, CURTAIN_ROD_Y, 0.12), PI, "CurtainPair")
	return root


## 벽 그림 액자: 월넛 틀 + 크림 받침 + 만화 포스터(POSTER_PICTURES[kind]).
## 2026-11-08 저녁: 예전 추상 도형(해·아치·언덕, 요청서 C18)은 사용자 "그림이 너무 아쉽다 — 캐주얼한데 재밌게"로
## 펍 주제(다트·건배·카드) 만화 포스터로 바꿨다. 포스터 판 이름 "WallPoster" 는 정적 묶기에서 빠진다(묶으면 그림 UV 가 사라진다).
static func _wall_art(parent: Node3D, at: Vector2, inward: Vector2, kind: int, y: float) -> void:
	var root := Node3D.new()
	root.name = "WallArt_%d" % (kind + 1)
	root.position = Vector3(at.x, y, at.y)
	root.rotation.y = _yaw(inward)
	parent.add_child(root, true)
	MeshKit.rounded_box(root, "ArtFrame", Vector3(0.78, 0.98, 0.05), Vector3(0, 0, 0.03), _walnut(), 0.02)
	# 2026-11-15 겹침 깜빡임 수정: 틀 앞면 = 0.055m. 받침(ArtCanvas) 앞면을 0.064m 로(틀보다 9mm 앞),
	# 포스터는 받침보다 WALL_LAYER_GAP(8mm) 앞에 띄운다 — 예전에는 포스터가 받침에서 1.5mm 라 방 건너편에서 보면 깨졌다.
	var canvas_front: float = 0.064
	MeshKit.rounded_box(root, "ArtCanvas", Vector3(0.64, 0.84, 0.02), Vector3(0, 0, canvas_front - 0.01), RoundKit.clay("ArtCanvas", "e9dcc4", 0.95), 0.006)
	var print_sheet := QuadMesh.new()
	print_sheet.size = Vector2(0.62, 0.814)
	var paper := StandardMaterial3D.new()
	paper.resource_name = "Poster%d" % (kind + 1)
	paper.albedo_texture = load(POSTER_PICTURES[kind % POSTER_PICTURES.size()])
	paper.roughness = 0.82
	paper.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	MeshKit.mesh_node(root, "WallPoster", print_sheet, Vector3(0, 0, canvas_front + WALL_LAYER_GAP), paper)


## 창·간판·화분·입구 문·조명 스위치·벽 그림.
## 창은 windows 묶음(Windows)에 따로 둔다 — 네온 오락실은 창 없는 방이라 통째로 빼고(LoungeWorld.ARCADE_SKIP) 그 벽에 네온 간판을 단다.
static func build_decor(p: Node3D, windows: Node3D, pub_only: Node3D) -> void:
	var f := _faces()
	for spot: Array in _window_spots():
		_window(windows, spot[0], spot[1])
	# 오른쪽 벽 하우스 룰 간판(다트판과 헷갈리지 않게 네모 액자).
	var sign := Node3D.new()
	sign.name = "HouseRulesSign"
	sign.position = Vector3(f.lounge_x1 - 0.05, 2.3, SIGN_Z)
	sign.rotation.y = -PI / 2
	p.add_child(sign, true)
	MeshKit.rounded_box(sign, "Frame", Vector3(1.75, 1.25, 0.08), Vector3.ZERO, _brass(), 0.04)
	MeshKit.rounded_box(sign, "Paper", Vector3(1.62, 1.12, 0.04), Vector3(0, 0, 0.03), PubParts.dark(), 0.02)
	MeshKit.label(sign, "Title", "좋은 한 발,\n좋은 사람들.", Vector3(0, 0.16, 0.06), 55, Color("e0c58d"), 0.0018)
	MeshKit.label(sign, "Caption", "DARTY   /   소 셜   클 럽", Vector3(0, -0.33, 0.06), 21)
	# 벽 그림 액자(펍 전용 — 오락실은 그 벽에 간판·기계).
	for art: Array in _art_spots():
		var at: Vector2 = art[0]
		_wall_art(pub_only, at, art[1], art[2], art[3])
	# 화분: 주크박스 왼쪽(다트 홀 입구 오른쪽 모서리 옆) — 2026-11-08 주크박스와 겹쳐서 둘 다 옮겼다.
	# 오른쪽 뒤 구석 화분은 오락실에서 인형뽑기 코너 자리라 펍 전용(PubOnly)으로 둔다.
	# 2026-11-08 Codex 묶음 1 v2: 도형 화분 → 라운드하우스 화분. 주크박스 옆 = 중간(놋쇠 화분, 0.74 × 0.9m),
	# 오른쪽 뒤 구석 = 큰 것(테라코타, 1.18 × 1.4m). 큰 화분은 잎이 넓어 두 벽에서 각각 3cm 띄우도록 구석 자리를 조금 당겼다
	# (모델 잎 끝 = 원점에서 +x 0.636 · +z 0.649m).
	_model(p, "plant_medium", Vector3(f.hall_x1 + 0.55, 0, f.step_z + 0.6), 0.0, "Plant")
	_model(pub_only, "plant_large", Vector3(f.lounge_x1 - 0.67, 0, f.back_z - 0.68), 0.0, "Plant")
	# 입구 문(뒷벽, 방 안쪽에서 보이는 면): 둥근 머리 문틀 + 문짝 판넬 둘 + 작은 아치 유리 + 손잡이 + 문 매트.
	var door := Node3D.new()
	door.name = "EntranceDoor"
	door.position = Vector3(DOOR_X, 0, f.back_z)
	door.rotation.y = PI
	p.add_child(door, true)
	var frame_path := RoundKit.arch_path(1.36, 0.0, 2.52, 0.38, 10)
	MeshKit.mesh_node(door, "DoorFrame", RoundKit.sweep_mesh("door_frame", RoundKit.bead_profile(0.12, 0.07),
		RoundKit.wall_path_rails(frame_path, Vector3.ZERO, Vector3.RIGHT, Vector3.BACK), false, false), Vector3.ZERO, _walnut_dark())
	var leaf_outline := RoundKit.rounded_polygon(PackedVector2Array([Vector2(-0.6, 0), Vector2(0.6, 0), Vector2(0.6, 2.48), Vector2(-0.6, 2.48)]),
		PackedFloat32Array([0.0, 0.0, 0.34, 0.34]), 8)
	MeshKit.mesh_node(door, "Door", RoundKit.panel_mesh("door_leaf", leaf_outline, 0.04), Vector3(0, 0, 0.005), _walnut())
	for y: float in [0.62, 1.42]:
		MeshKit.rounded_box(door, "DoorPanel", Vector3(0.82, 0.62, 0.025), Vector3(0, y, 0.05), _panel_wood(), 0.03)
	var glass := PackedVector2Array()
	for s in range(13):
		var angle := PI * s / 12.0
		glass.append(Vector2(cos(angle) * 0.32, 1.92 + sin(angle) * 0.32))
	# 2026-11-15: 유리가 문짝 앞면(0.045m)에서 2mm 라 멀리서 깜빡였다 → WALL_LAYER_GAP(8mm) 앞.
	MeshKit.mesh_node(door, "DoorGlass", RoundKit.flat_shape_mesh("door_glass", glass), Vector3(0, 0, 0.045 + WALL_LAYER_GAP), MeshKit.material("DoorGlass", "f2d4a0", 0.0, 0.45))
	MeshKit.mesh_node(door, "DoorKnob", RoundKit.sphere_mesh(0.04, 14), Vector3(-0.44, 1.05, 0.09), _brass())
	MeshKit.rounded_box(door, "DoorKick", Vector3(1.0, 0.16, 0.012), Vector3(0, 0.1, 0.05), _brass(), 0.005)
	var mat := MeshKit.mesh_node(p, "DoorMat", RoundKit.rounded_slab_mesh(Vector2(1.4, 0.7), 0.012, 0.12), Vector3(DOOR_X, 0.002, f.back_z - 0.55), RoundKit.clay("DoorMat", "6b3f33", 1.0))
	mat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 2026-11-15: 이 문이 꾸미기 방 입구가 됐다. 2026-11-16: 펍에서는 이 문 앞에 꾸미기 방 상자(room_fitting.gd)가 서서 문이 가려지고,
	# 꾸미기 방 문·간판은 상자 앞면에 있다. 이 뒷벽 문은 오락실(상자가 빠지는 테마)에서만 보인다.
	RoomFitting.build_fitting_room(pub_only)
	# 문 옆 조명 스위치(기획 M11). 2026-11-16: 꾸미기 방 상자 왼쪽 바깥으로 옮겼다(예전 자리는 상자 옆벽 속).
	MeshKit.rounded_box(p, "LightSwitchPlate", Vector3(0.13, 0.2, 0.03), Vector3(DOOR_X - 1.25, 1.35, f.back_z - 0.015), _plaster(), 0.015)
	MeshKit.rounded_box(p, "LightSwitchLever", Vector3(0.03, 0.08, 0.05), Vector3(DOOR_X - 1.25, 1.38, f.back_z - 0.05), _brass(), 0.01)


## 도면 v3(2026-10-31 밤) 에셋 가구: 비어 보이던 곳을 RG Poly 모델로 채운다(docs/MAP_PLAN_2026-10-31.md).
## 자리·충돌은 TableView *_AT 상수와 decor_blocks(), 모양·방향·배율은 여기서 정한다.
## p(Furnishings)는 오락실 테마에서도 남는다. pub_only(PubOnly)는 오락실에서 빠진다(LoungeWorld.ARCADE_SKIP).
## 이름이 붙은 노드(Keg·PracticeTarget·Gramophone)는 LoungeWorld 가 "건드리기"(F) 때 찾아 흔든다 — 이름을 바꾸면 거기도 고친다.
## 2026-11-08: 천장 아래 전구 줄(string lights)은 뺐다 — 요청서 P11 "천장 전선 대신 벽면 장식으로 밀도 확보"(빛은 코브 띠가 낸다).
static func build_furnish(p: Node3D, pub_only: Node3D) -> void:
	var f := _faces()
	# 바 뒤: 받침대에 누운 생맥주 통(꼭지가 방 쪽) · 뒤 조리대 + 커피 머신 · 병조림 · 구석 화분(오락실에서는 경품 진열대 자리).
	PubParts.asset(pub_only, "keg", TableView.KEG_AT, PI / 2, Vector3.ONE * 0.95, "Keg")
	PubParts.asset(pub_only, "back_counter", TableView.BACK_COUNTER_AT, PI / 2, Vector3.ONE, "BackCounter")
	# 바 뒤 구석 화분: 라운드하우스 중간 화분(놋쇠 화분 — 예전 도형 화분과 같은 놋쇠, 2026-11-08).
	_model(pub_only, "plant_medium", Vector3(f.lounge_x0 + 0.6, 0, f.back_z - 0.6), 0.0, "Plant")
	# 조리대 윗면 1.0m. 병 선반 판과 겹치지 않게 방 쪽 절반에만 올린다.
	var counter_top: Vector3 = TableView.BACK_COUNTER_AT + Vector3(0.22, 1.0, 0)
	# 2026-11-08 사용자 "음식은 뒤돌아서 주방의 전자레인지 같은 가구에서 꺼내서 서빙": 조리대 = 작은 주방.
	# 사용자가 고른 RG Poly 전자레인지(문 = 모델 -X → 반 바퀴 돌려 바텐더 통로 +X 를 본다, 크림·벽돌색) · 토스터 ·
	# 커피 머신(앞 = 모델 -X → 반 바퀴). 바텐더(art/pub/pub_service.gd)가 여기서 음식·커피를 꺼낸다(z = MICROWAVE_Z · COFFEE_Z).
	PubParts.asset(pub_only, "microwave", Vector3(counter_top.x, counter_top.y, MICROWAVE_Z), PI, Vector3.ONE * 0.9, "Microwave")
	PubParts.asset(pub_only, "toaster", Vector3(counter_top.x + 0.04, counter_top.y, TOASTER_Z), 0.0, Vector3.ONE * 0.85, "Toaster")
	PubParts.asset(pub_only, "coffee_machine_g", Vector3(counter_top.x + 0.02, counter_top.y, COFFEE_Z), PI, Vector3.ONE * 0.72, "CoffeeMachine")
	# 다트 홀: 연습 과녁(장식 — 점수 없음, 건드리면 흔들린다) · 양동이와 벽에 기댄 빗자루.
	PubParts.asset(p, "practice_target", TableView.PRACTICE_TARGET_AT, 1.4, Vector3.ONE, "PracticeTarget")
	PubParts.asset(p, "bucket", TableView.BUCKET_AT, 0.7, Vector3.ONE, "Bucket")
	var broom := PubParts.asset(p, "broom", Vector3(f.hall_x1 - 0.2, 0, TableView.BUCKET_AT.z - 0.55), 0.0, Vector3.ONE, "Broom")
	if broom != null:
		broom.rotation.z = -0.1 # 위쪽이 벽(+X)에 기댄다
	# 다트 홀 옆벽 선반(구경꾼 잔 놓는 곳): 왼쪽·오른쪽 벽, 1.75m. 벽 칸 나누기가 이 자리(z −1.5)를 비워 둔다.
	for side: float in [-1.0, 1.0]:
		var wall_x: float = f.hall_x1 - 0.26 if side > 0 else f.hall_x0 + 0.26
		var shelf := PubParts.asset(pub_only, "hang_shelf", Vector3(wall_x, 1.75, -1.5), 0.0 if side < 0 else PI, Vector3.ONE, "WallShelf", false)
		if shelf == null:
			continue
		var top: float = 1.75 + shelf.mesh.get_aabb().end.y
		PubParts.asset(pub_only, "mug", Vector3(wall_x + side * 0.05, top, -1.85), 1.0, Vector3.ONE * 0.55)
		PubParts.asset(pub_only, "goblet", Vector3(wall_x + side * 0.05, top, -1.45), 0.0, Vector3.ONE * 0.65)
		PubParts.asset(pub_only, "jar", Vector3(wall_x + side * 0.05, top, -1.05), 0.6, Vector3.ONE * 0.7)
	# 2026-11-08 Codex 묶음 1 v2: 소파·안락의자·낮은 탁자·축음기를 라운드하우스 GLB 로 바꿨다(팔걸이·등받이가 이어진 가죽 곡면,
	# 월넛·놋쇠 텍스처). 새 모델 정면은 -Z 라 옛 RG Poly(정면 +X)의 yaw 를 그대로 쓰지 않는다. 노드 이름(Sofa …)은 그대로다.
	# 라운지 뒷벽: 구경 소파(정면 -Z = 카드 테이블 쪽). 오락실에서는 오락기 자리라 뺀다.
	_model(pub_only, "sofa", TableView.SOFA_AT, 0.0, "Sofa")
	# 오른쪽 귀퉁이: 안락의자(창 쪽 앞벽을 등지고 방 안 +Z 를 본다 — 반 바퀴) + 낮은 탁자(윗면 0.4m) 위 축음기(나팔이 방 안쪽 −X·+Z 를 본다).
	_model(p, "armchair", TableView.ARMCHAIR_AT, PI, "Armchair")
	_model(p, "side_table", TableView.SIDE_TABLE_AT, 0.0, "SideTable")
	# 축음기: 2026-11-08 사용자 "내가 넣은 측음기로 에셋을 교체해 줘" → 사용자가 고른 RG Poly 축음기(Restaurant 팩 Gramophone).
	PubParts.asset(p, "gramophone_classic", TableView.SIDE_TABLE_AT + Vector3(0, 0.4, 0), GRAMOPHONE_YAW, Vector3.ONE, "Gramophone")
	# 문 옆 짐: 나무 상자 둘을 엇갈려 쌓고 곡물 자루를 기대 둔다(배달 온 술·안주).
	PubParts.asset(p, "crate", TableView.CRATES_AT, 0.15, Vector3.ONE, "Crate")
	# 위 상자는 꾸미기 방 상자(x 7.4~) 쪽으로 모서리가 나가지 않게 살짝 왼쪽으로(2026-11-16).
	PubParts.asset(p, "crate", TableView.CRATES_AT + Vector3(-0.03, 0.59, -0.02), 0.5, Vector3.ONE * 0.9, "CrateTop")
	PubParts.asset(p, "grain_bag", TableView.GRAIN_BAG_AT, 0.9, Vector3.ONE, "GrainBag")
	# 벽걸이 옷걸이(라운드하우스 — 고리 4개 + 걸린 코트·모자가 한 모델)는 2026-11-16 부터 꾸미기 방 상자 옆벽에 있다(room_fitting.gd).
	_indie_decor(pub_only)


# ─────────────────────────────── 인디 펍 소품(2026-11-15) ───────────────────────────────

## 사용자 "맵이 너무 휑하니까 인디 펍 느낌 나게 채워줘": 비어 있던 크림 벽 칸(다트 홀 양옆 · 과녁 벽 양 끝 · 라운지 뒷벽)과
## 창턱을 구경판에서 고른 RG Poly 소품(물약병·병조림·빵·마늘 다발·꽃·허브 화분·오리·뿔·화살)으로 채운다.
## 전부 펍 전용(PubOnly) — 오락실은 그 벽에 제 간판·기계가 있다.
## 바닥에는 아무것도 두지 않는다: 충돌 상자가 없는 물건은 사람이 뚫고 지나가고, 다트 홀 바닥은 던지는 길이다.
## 겹침 깜빡임(z-fighting) 방지: 벽에 붙는 판은 벽면에서 WALL_LAYER_GAP(8mm) 띄우고, 선반 위 물건은 판 윗면에 세우며
## 물건끼리는 모델 상자 가운데를 맞춰 칸마다 떨어뜨린다. 선반 길이는 칸 안 아치 틀(칸 폭 − 0.34m) 안쪽에 들어가게 정했다.
static func _indie_decor(pub_only: Node3D) -> void:
	var f := _faces()
	var group := _group(pub_only, "IndieDecor")
	for side: float in [-1.0, 1.0]:
		var x: float = f.hall_x1 if side > 0 else f.hall_x0
		var inward := Vector2(-side, 0)
		# 과녁 쪽 끝 칸(z −11.2, 폭 2.35 · 벽등 아래): 왼쪽 = 엇갈린 화살 두 자루, 오른쪽 = 뿔 벽걸이.
		if side < 0:
			_crossed_arrows(_wall_mount(group, Vector2(x, -11.175), inward, 1.75, "ArrowTrophy"))
		else:
			_horn_trophy(_wall_mount(group, Vector2(x, -11.175), inward, 1.72, "HornTrophy"))
		# 창 둘 사이 좁은 칸(z −6.9, 폭 1.0 → 틀 안 0.6m): 작은 물약병 선반.
		var potions: Array = ["potion_a", "potion_e", "potion_c"] if side < 0 else ["potion_d", "potion_f", "potion_b"]
		_plank_shelf(_wall_mount(group, Vector2(x, -6.9), inward, 1.72, "PotionShelf"), 0.5, potions)
		# 입구 쪽 칸(z −3.05, 폭 1.5 → 틀 안 1.1m): 왼쪽 = 식료품(병조림·빵·마늘), 오른쪽 = 잡동사니(밀가루·허브·오리·물약).
		var goods: Array = ["pickle_jar_a", "bread_loaf", "garlic_braid", "pickle_jar_b"] if side < 0 \
			else ["flour_sack", "herb_pot_a", "duck_small", "potion_e"]
		_plank_shelf(_wall_mount(group, Vector2(x, -3.05), inward, 1.72, "PantryShelf" if side < 0 else "TrinketShelf"), 0.92, goods)
	# 과녁 벽 양 끝 칸(x ±5.5, 폭 1.87 → 틀 안 1.5m): 꽃 선반(구석 럼주통 위).
	_plank_shelf(_wall_mount(group, Vector2(-5.5125, f.board_z), Vector2(0, 1), 1.78, "FlowerShelf"), 1.15, ["flowers_a", "herb_pot_b", "flowers_c"])
	_plank_shelf(_wall_mount(group, Vector2(5.5125, f.board_z), Vector2(0, 1), 1.78, "FlowerShelf"), 1.15, ["flowers_b", "potion_b", "rolling_pin"])
	# 라운지 뒷벽 뒤 창 둘 사이(x −0.3, 폭 1.6, 비스트로 탁자 위): 꽃·물약·치즈 선반.
	_plank_shelf(_wall_mount(group, Vector2(-0.3, f.back_z), Vector2(0, -1), 1.85, "BackWallShelf"), 1.0, ["flowers_b", "potion_c", "cheese_wedge", "potion_d"])
	# 창턱(윗면 = WINDOW_BOTTOM − 0.025): 창마다 긴 꽃 상자 하나(0.8배 → 길이 0.72m · 깊이 0.26m).
	# 길이를 벽을 따라 눕히고(90도), 뒷면을 창틀 띠(벽에서 6cm)보다 1cm 앞에 둔다 → 창살·틀·유리와 겹치지 않는다.
	# 양쪽 커튼 자락(창 가운데에서 ±0.6m 바깥)과도 닿지 않는다. 앞쪽은 창턱(깊이 0.24m)보다 9cm 나온다.
	for spot: Array in _window_spots():
		var sill := _wall_mount(group, spot[0], spot[1], WINDOW_BOTTOM - 0.025, "SillFlowers")
		_on_shelf(sill, "flower_box", Vector3(0, 0, 0.07 + 0.13), PI / 2.0, 0.8)
		# 상자에 꽂힌 풀·꽃: 밑동을 상자 안(테두리 높이 0.245m 아래)에 묻어 화분 부분은 가려지고 잎·꽃만 보인다.
		# 창마다 꽃 색을 돌려 쓴다(상자끼리 똑같아 보이지 않게).
		var bloom: String = ["flowers_a", "flowers_b", "flowers_c"][_window_spots().find(spot) % 3]
		for planted: Array in [["herb_pot_a", -0.22, 1.0], [bloom, 0.0, 0.6], ["herb_pot_b", 0.22, 1.0]]:
			_on_shelf(sill, str(planted[0]), Vector3(planted[1], 0.13, 0.2), 0.5 * float(planted[1]), planted[2])


## 뿔 벽걸이: 월넛 방패 판 + 그 위 가로로 누운 뿔(모델 길이 = 로컬 z 1.17m → 반 바퀴의 반 돌려 벽을 따라 눕힌다).
static func _horn_trophy(root: Node3D) -> void:
	MeshKit.rounded_box(root, "TrophyBoard", Vector3(1.0, 0.5, 0.04), Vector3(0, 0.0, WALL_LAYER_GAP + 0.02), _walnut_dark(), 0.06)
	MeshKit.rounded_box(root, "TrophyPlate", Vector3(0.26, 0.07, 0.012), Vector3(0, -0.21,WALL_LAYER_GAP + 0.04 + 0.006 + WALL_LAYER_GAP), _brass(), 0.004)
	# 뿔 몸통 두께(모델 x 0.23m)의 절반 + 판 앞면 + 틈 → 판에 닿지 않고 붙어 보인다.
	var horn := _on_shelf(root, "horn_trophy", Vector3(0, -0.15, WALL_LAYER_GAP + 0.04 + 0.125), PI / 2.0)
	if horn != null:
		horn.name = "Horn"


## 엇갈린 화살 두 자루: 마름모 월넛 판 위에 X 자로. 두 화살은 앞뒤로 10cm 떨어뜨려 서로 뚫지 않는다.
static func _crossed_arrows(root: Node3D) -> void:
	var board := MeshKit.rounded_box(root, "TrophyBoard", Vector3(0.56, 0.56, 0.04), Vector3(0, 0.0, WALL_LAYER_GAP + 0.02), _walnut_dark(), 0.05)
	board.rotation.z = PI / 4.0
	var board_front: float = WALL_LAYER_GAP + 0.04
	for i in range(2):
		var arrow := PubParts.asset(root, "arrow_a" if i == 0 else "arrow_b", Vector3.ZERO, 0.0, Vector3.ONE, "Arrow", false)
		if arrow == null:
			continue
		# 화살 원점 = 아래 끝 근처(모델 y −0.04 ~ 0.98) → 가운데(y 0.49)가 판 가운데에 오도록 돌린 뒤 옮긴다.
		arrow.rotation = Vector3(0, 0, 0.62 if i == 0 else -0.62)
		var mid: Vector3 = arrow.basis * arrow.mesh.get_aabb().get_center()
		arrow.position = Vector3(-mid.x, -mid.y, board_front + 0.06 + i * 0.1 - mid.z)
