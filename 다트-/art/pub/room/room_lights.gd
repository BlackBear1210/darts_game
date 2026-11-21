extends "res://art/pub/room/room_kit.gd"
## 조명: 펜던트 · 벽등 · 과녁 스포트라이트 · 방 환경(WorldEnvironment — 안개·빛 번짐·SSAO).
## 디자인 담당 소유(2026-11-17 game_room_builder.gd 에서 나눔). 장면 안 묶음 = Lights.
## 펜던트·벽등 부품 함수(_pendant·_sconce)는 여러 모듈이 같이 써서 room_kit.gd 에 있다. 전등 규칙은 build_lighting 머리 주석.

## 환경(배경색·주변광·톤·SSAO)과 조명. 다트판에 가장 밝은 흰 스포트라이트(기획 2-6), 나머지는 주황빛 펜던트·벽등·코브 빛.
## 2026-11-08: 화면 공간 접촉 그림자(SSAO)를 켠다 — 가구가 바닥·벽에 "붙어" 보이게 하는 점토 느낌의 핵심(요청서 2장 "부드러운 접촉 그림자").
static func build_lighting(p: Node3D) -> void:
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("182924")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c4b59c")
	env.ambient_light_energy = 0.36
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_hdr_threshold = 1.05
	env.ssao_enabled = true
	env.ssao_radius = 0.9
	env.ssao_intensity = 1.6
	env.ssao_power = 1.4
	env.ssao_detail = 0.4
	world.environment = env
	p.add_child(world, true)
	var fill := DirectionalLight3D.new()
	fill.name = "SoftFill"
	fill.rotation_degrees = Vector3(-55, -25, 0)
	fill.light_color = Color("ffe2b6")
	fill.light_energy = 0.2
	p.add_child(fill, true)
	var ceiling: float = TableView.CEILING_HEIGHT
	var table: Vector3 = TableView.TABLE_CENTER
	# 2026-11-08 사용자 "펍과 오락실 전부 전등이 안 어울리거나 너무 무규칙적으로 설치된 느낌" → 등 다는 규칙:
	#   ① 높이: 라운지 펜던트는 모두 갓 아래 끝 LOUNGE_PENDANT_Y(3.2m), 다트 홀은 HALL_PENDANT_Y 한 줄.
	#   ② 자리: 사람이 쓰는 가구 하나에 등 하나, 그 가구 가운데 위(카드 테이블 · NPC 테이블 · 비스트로 테이블 · 소파 · 안락의자 · 입구).
	#      긴 가구(바 · 당구대)는 길이를 똑같이 나눈 줄. 뒤쪽 등(소파 · 비스트로 테이블 · 입구)은 한 줄(z = 비스트로 테이블 줄)에 선다.
	#   ③ 크기: 카드 테이블만 큰 갓(1.3), 바 줄은 작은 갓(0.75), 나머지는 모두 0.9.
	# 카드 테이블 등(요청서: 최하단 3.2m 이상). 오락실에서도 남는 유일한 펜던트라 이름 앞머리가 다르다("TablePendant").
	_pendant(p, Vector3(table.x, LOUNGE_PENDANT_Y, table.z), ceiling, 1.05, 7.5, true, 1.3, "TablePendant")
	# 다트 홀: 투척선 뒤 한 줄(가운데 + 양옆 같은 간격). 레인 위에는 달지 않는다.
	for x: float in [-3.6, 0.0, 3.6]:
		_pendant(p, Vector3(x, HALL_PENDANT_Y, HALL_PENDANT_Z), ceiling, 0.6 if x == 0.0 else 0.45, 6.0, false, 0.9)
	# 바: 바 길이를 셋으로 똑같이 나눈 줄(작은 갓).
	var bar: AABB = TableView.BAR_BOX
	for i in range(3):
		_pendant(p, Vector3(bar.get_center().x - 0.1, LOUNGE_PENDANT_Y, bar.position.z + bar.size.z * (i + 0.5) / 3.0), ceiling, 0.4, 4.5, false, 0.75)
	_pendant(p, Vector3(TableView.NPC_TABLE_BOX.get_center().x, LOUNGE_PENDANT_Y, TableView.NPC_TABLE_BOX.get_center().z), ceiling, 0.55, 5.5, false, 0.9)
	# 당구대: 긴 쪽(z)을 따라 둘.
	var pool: Vector3 = TableView.POOL_TABLE_BOX.get_center()
	for dz: float in [-0.65, 0.65]:
		_pendant(p, Vector3(pool.x, LOUNGE_PENDANT_Y, pool.z + dz), ceiling, 0.4, 5.0, false, 0.9)
	# 뒤쪽 줄: 소파 위 · 입구 앞(뒷벽에서 0.95m 앞 줄 — 2026-11-21 비스트로 테이블을 지우며 그 z 를 그대로 숫자로 남김).
	var back_row: float = 7.55
	# 2026-11-16: 입구 앞 등은 꾸미기 방 상자(앞면 z 7.55) 지붕 위에 걸리지 않게 상자 앞 0.9m 로 당겼다.
	for spot: Vector2 in [Vector2(TableView.SOFA_AT.x, back_row), Vector2(DOOR_X, TableView.FITTING_ROOM_BOX.position.z - 0.9)]:
		_pendant(p, Vector3(spot.x, LOUNGE_PENDANT_Y, spot.y), ceiling, 0.4, 5.0, false, 0.9)
	# 오른쪽 귀퉁이: 안락의자와 축음기 탁자 사이 위.
	var corner: Vector3 = (TableView.ARMCHAIR_AT + TableView.SIDE_TABLE_AT) / 2.0
	_pendant(p, Vector3(corner.x, LOUNGE_PENDANT_Y, corner.z), ceiling, 0.4, 5.0, false, 0.9)
	# 벽등: 벽 칸 나누기에서 고정물이 없는 칸 가운데(다트 홀 양옆 · 라운지 오른쪽 벽).
	for wall: Dictionary in _walls():
		if not bool(wall.sconces):
			continue
		for bay: Dictionary in wall.bays:
			if not (bay.fixture as Dictionary).is_empty() or float(bay.to) - float(bay.from) < 0.9:
				continue
			var u: float = (float(bay.from) + float(bay.to)) / 2.0
			var at: Vector2 = wall.from + wall.along * u
			var inward: Vector2 = wall.inward
			_sconce(p, Vector3(at.x, 2.55, at.y), Vector3(inward.x, 0, inward.y))
	var spot := SpotLight3D.new()
	spot.name = "BoardSpot"
	spot.position = Vector3(TableView.BOARD_CENTER.x, ceiling - 0.2, TableView.BOARD_CENTER.z + 1.8)
	spot.light_color = Color("ffe6c4")
	spot.light_energy = 2.2
	spot.spot_range = 5.5
	spot.spot_angle = 32
	spot.spot_attenuation = 0.6
	spot.shadow_enabled = true
	# 아직 장면 트리 밖이라 look_at 대신 방향 행렬을 직접 만든다(조명은 -Z 쪽을 비춘다).
	spot.basis = Basis.looking_at(TableView.BOARD_CENTER - spot.position)
	p.add_child(spot, true)
