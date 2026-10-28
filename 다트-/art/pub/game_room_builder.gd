extends RefCounted
## F5 실제 경기 방(art/pub/pub_game.tscn)의 "보이는 것"을 만든다. pub_builder.gd 가 부른다(게임 실행 중에는 안 쓰인다).
##
## [방 모양 — 2026-10-28 도면]
## 위쪽 좁은 "다트 홀"(과녁·투척선·럼주통)과 아래쪽 넓은 "라운지"(바·플레이어 테이블·NPC 자리·당구대)가
## 이어진 ㄱ자 한 방이다. 두 칸은 TableView.DART_HALL / LOUNGE 이고 z=0 에서 만난다.
##
## [왜 쇼케이스 펍과 따로 만드나]
## 실제 경기는 프로그래머가 정한 규칙 좌표가 있다: 과녁 중심 높이·크기, 투척선, 테이블·자리 4개 위치.
## 그래서 펍 디자인(벽·바닥·조명·소품 모양)은 그대로 쓰고, 배치만 그 좌표에 맞춘 방을 따로 만든다.
##
## [규칙 좌표는 어디서 오나]
## 전부 game/table/table.gd(TableView) 상수를 읽는다. 여기에 숫자를 따로 적지 않는다.
## 프로그래머가 그 상수를 바꾸면 이 생성기를 다시 돌려야 한다. 안 돌리면 게임 시작 때 경고가 뜨고
## tests/test_game_look.gd 가 실패한다(방에 저장된 layout_signature 와 비교).
##
## [충돌은 여기서 안 만든다]
## 벽·테이블·바·럼주통·NPC 테이블·당구대의 충돌은 TableView 가 만든다. 여기 있는 건 모두 "보이기만" 하는 물체다.
## 그래서 사람이 부딪히는 소품을 옮길 때는 TableView 의 충돌 상수도 같이 옮겨야 한다.

const MeshKit = preload("res://art/mesh_kit.gd")
const PubParts = preload("res://art/pub/pub_parts.gd")
const BARTENDER_SCENE := "res://art/characters/chr_bartender.tscn"
## 과녁 뒤 초록 특징 판넬의 절반 폭(m). 캐비닛 문 두 짝이 열린 폭보다 넓어야 한다.
const FEATURE_HALF := 2.7


## 방 전체를 만든다. 반환한 노드를 pub_builder.gd 가 pub_game.tscn 으로 저장한다.
static func build() -> Node3D:
	var room := Node3D.new()
	room.name = "PubGame"
	room.set_meta("layout_signature", TableView.layout_signature())
	_shell(_group(room, "Shell"))
	_board_wall(_group(room, "BoardWall"))
	_lane(_group(room, "Lane"))
	_barrels(_group(room, "Barrels"))
	_table_and_seats(_group(room, "TableAndSeats"))
	_bar(_group(room, "Bar"))
	_npc_corner(_group(room, "NpcCorner"))
	_pool_table(_group(room, "PoolTable"))
	_decor(_group(room, "Decor"))
	_lighting(_group(room, "Lights"))
	return room


## 에디터 장면 목록에서 찾기 쉽도록 부위별 묶음 노드를 만든다.
static func _group(parent: Node3D, group_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = group_name
	parent.add_child(node)
	return node


## 벽 안쪽 면 좌표(벽 상자 두께의 절반만큼 안쪽). 바닥 평면 x·z 다.
static func _faces() -> Dictionary:
	var half: float = TableView.WALL_THICKNESS / 2.0
	return {
		"hall_x0": TableView.DART_HALL.position.x + half,
		"hall_x1": TableView.DART_HALL.end.x - half,
		"board_z": TableView.DART_HALL.position.y + half,
		"step_z": TableView.LOUNGE.position.y + half,
		"lounge_x0": TableView.LOUNGE.position.x + half,
		"lounge_x1": TableView.LOUNGE.end.x - half,
		"back_z": TableView.LOUNGE.end.y - half,
	}


## 축에 나란한 널빤지 하나. along 은 (1,0) 또는 (0,1), thickness 는 그 반대 축 두께다.
static func _plank(p: Node3D, node_name: String, mid: Vector2, along: Vector2, length: float,
		thickness: float, y: float, height: float, mat: Material) -> void:
	var size := Vector3(absf(along.x) * length + absf(along.y) * thickness, height,
		absf(along.y) * length + absf(along.x) * thickness)
	MeshKit.box(p, node_name, size, Vector3(mid.x, y, mid.y), mat)


## 벽 한 면: 크림 회벽 + 허리 초록 징두리 + 놋쇠 난간 + 위쪽 몰딩.
## from/to 는 안쪽 면 위의 바닥 좌표, inward 는 방 안쪽을 가리키는 단위 벡터다.
static func _wall_run(p: Node3D, from: Vector2, to: Vector2, inward: Vector2, ceiling: float, trim := true) -> void:
	var along := (to - from).normalized()
	var length := (to - from).length()
	var mid := (from + to) / 2.0
	_plank(p, "Wall", mid - inward * 0.09, along, length + 0.36, 0.18, ceiling / 2.0, ceiling, PubParts.cream())
	if trim:
		_plank(p, "Wainscot", mid + inward * 0.03, along, length, 0.06, 0.6, 1.2, PubParts.green())
		_plank(p, "WallRail", mid + inward * 0.04, along, length, 0.08, 1.22, 0.06, PubParts.brass())
	_plank(p, "Cornice", mid + inward * 0.07, along, length, 0.14, ceiling - 0.2, 0.18, PubParts.trim())


## 바닥 판자·벽 8면·천장·보.
static func _shell(p: Node3D) -> void:
	var f := _faces()
	var ceiling: float = TableView.CEILING_HEIGHT
	var bounds: Rect2 = TableView.DART_HALL.merge(TableView.LOUNGE)
	# 바닥 판자: 0.5m 폭 × 2.8m 길이, 색 5가지를 엇갈려 깐다. ㄱ자 밖(두 칸 모두 아닌 곳)은 비운다.
	var columns := int(ceil(bounds.size.x / 0.5)) + 1
	var rows := int(ceil(bounds.size.y / 2.8)) + 1
	for i in range(columns):
		for j in range(rows):
			var at := Vector2(bounds.position.x + 0.1 + i * 0.5, bounds.position.y + 1.25 + j * 2.8)
			if not TableView.DART_HALL.has_point(at) and not TableView.LOUNGE.has_point(at):
				continue
			var shade := (i + j * 3) % 5
			var mat := MeshKit.material("Floor_" + str(shade), ["785b42", "846247", "70523b", "8d6a4a", "796048"][shade])
			MeshKit.box(p, "Floorboard", Vector3(0.485, 0.07, 2.78), Vector3(at.x, -0.025, at.y), mat)
	# 벽 8면(ㄱ자 둘레). 과녁 벽은 특징 판넬이 덮으므로 징두리를 생략한다.
	_wall_run(p, Vector2(f.hall_x0, f.board_z), Vector2(f.hall_x1, f.board_z), Vector2.DOWN, ceiling, false)
	_wall_run(p, Vector2(f.hall_x0, f.board_z), Vector2(f.hall_x0, f.step_z), Vector2.RIGHT, ceiling)
	_wall_run(p, Vector2(f.hall_x1, f.board_z), Vector2(f.hall_x1, f.step_z), Vector2.LEFT, ceiling)
	_wall_run(p, Vector2(f.lounge_x0, f.step_z), Vector2(f.hall_x0, f.step_z), Vector2.DOWN, ceiling)
	_wall_run(p, Vector2(f.hall_x1, f.step_z), Vector2(f.lounge_x1, f.step_z), Vector2.DOWN, ceiling)
	_wall_run(p, Vector2(f.lounge_x0, f.step_z), Vector2(f.lounge_x0, f.back_z), Vector2.RIGHT, ceiling)
	_wall_run(p, Vector2(f.lounge_x1, f.step_z), Vector2(f.lounge_x1, f.back_z), Vector2.LEFT, ceiling)
	_wall_run(p, Vector2(f.lounge_x0, f.back_z), Vector2(f.lounge_x1, f.back_z), Vector2.UP, ceiling)
	# 천장(어두운 나무). 칸마다 한 장이고 그림자를 만들지 않는다(위에서 오는 은은한 빛을 막지 않게).
	for room: Rect2 in [TableView.DART_HALL, TableView.LOUNGE]:
		var roof := MeshKit.box(p, "Ceiling", Vector3(room.size.x + 0.4, 0.08, room.size.y + 0.4),
			Vector3(room.get_center().x, ceiling + 0.04, room.get_center().y), PubParts.trim())
		roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 보: 칸마다 폭을 맞춰 가로로 지른다.
	var beams := {TableView.DART_HALL: [-5.4, -2.1], TableView.LOUNGE: [2.0, 5.4]}
	for room: Rect2 in beams:
		for z: float in beams[room]:
			var beam := MeshKit.box(p, "CeilingBeam", Vector3(room.size.x - 0.3, 0.16, 0.2),
				Vector3(room.get_center().x, ceiling - 0.08, z), MeshKit.material("BeamWood", "3a2c22"))
			beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## 과녁 벽: 초록 특징 판넬 + 다트판 캐비닛(문 두 짝이 열린 모양, 문 안쪽은 칠판) + 간판 글자.
## 다트판 자체는 여기 없다 — game/board/board.gd(BoardView)가 art/board_art.gd 로 실행 때 그린다(카드로 숫자가 바뀌기 때문).
static func _board_wall(p: Node3D) -> void:
	var f := _faces()
	var ceiling: float = TableView.CEILING_HEIGHT
	var center: Vector3 = TableView.BOARD_CENTER
	var board_outer: float = BoardLayout.RADIUS * TableView.BOARD_SCALE * 1.33 # 숫자 띠 포함 판 반지름(약 1m)
	var face: float = f.board_z
	MeshKit.box(p, "FeaturePanel", Vector3(FEATURE_HALF * 2, ceiling, 0.05), Vector3(center.x, ceiling / 2, face + 0.025), PubParts.green())
	for x: float in [-FEATURE_HALF + 0.05, FEATURE_HALF - 0.05]:
		MeshKit.box(p, "FeatureBorder", Vector3(0.03, ceiling - 0.4, 0.03), Vector3(center.x + x, ceiling / 2, face + 0.06), PubParts.brass())
	# 특징 판넬 양옆에만 징두리(판넬과 겹치지 않게 벽 생성에서는 건너뛰었다).
	for side: float in [-1.0, 1.0]:
		var width: float = (f.hall_x1 - FEATURE_HALF)
		var x: float = side * (FEATURE_HALF + width / 2.0)
		MeshKit.box(p, "BackWainscot", Vector3(width, 1.2, 0.06), Vector3(x, 0.6, face + 0.03), PubParts.green())
		MeshKit.box(p, "BackRail", Vector3(width, 0.06, 0.08), Vector3(x, 1.22, face + 0.05), PubParts.brass())
	# 캐비닛 몸통(판보다 조금 큰 정사각) + 안쪽 어두운 판 + 테두리.
	var half := board_outer + 0.15
	MeshKit.box(p, "Cabinet", Vector3(half * 2, half * 2, 0.06), Vector3(center.x, center.y, face + 0.06), PubParts.wood())
	MeshKit.box(p, "CabinetBacking", Vector3(half * 2 - 0.16, half * 2 - 0.16, 0.02), Vector3(center.x, center.y, face + 0.095), PubParts.dark())
	for y: float in [-1.0, 1.0]:
		MeshKit.box(p, "CabinetRail", Vector3(half * 2 + 0.08, 0.08, 0.1), Vector3(center.x, center.y + y * (half + 0.02), face + 0.08), PubParts.trim())
	# 열린 문 두 짝(벽에 붙어 있음). 왼쪽 문 칠판 = 실시간 점수판(GameView 가 글자를 바꾼다), 오른쪽 = 하우스 룰.
	for side: float in [-1.0, 1.0]:
		var door_x: float = center.x + side * (half + half / 2.0 + 0.02)
		MeshKit.box(p, "CabinetDoor", Vector3(half - 0.02, half * 2, 0.05), Vector3(door_x, center.y, face + 0.055), PubParts.wood())
		MeshKit.box(p, "DoorChalk", Vector3(half - 0.2, half * 2 - 0.22, 0.012), Vector3(door_x, center.y, face + 0.086), PubParts.chalk_board())
		for y: float in [-0.6, 0.6]:
			MeshKit.box(p, "Hinge", Vector3(0.05, 0.14, 0.03), Vector3(center.x + side * (half + 0.01), center.y + y * half, face + 0.09), PubParts.brass())
	var chalk := Color("e6e3d6")
	var scores := MeshKit.label(p, "ChalkScores", "점 수\n\n―", Vector3(center.x - (half + half / 2.0 + 0.02), center.y + 0.05, face + 0.095), 28, chalk, 0.003)
	scores.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	MeshKit.label(p, "ChalkRules", "하 우 스  룰\n\n한 차례 3발\n꾹 = 충전\n오른쪽 = 취소\n늦으면 슬로우!", Vector3(center.x + (half + half / 2.0 + 0.02), center.y + 0.05, face + 0.095), 30, chalk, 0.003)
	# 간판 글자(캐비닛 아래).
	var bottom := center.y - half
	MeshKit.label(p, "Brand", "DARTY", Vector3(center.x, bottom - 0.42, face + 0.06), 96, Color("e6ca90"), 0.0042)
	MeshKit.label(p, "BrandSubtitle", "소 셜   클 럽", Vector3(center.x, bottom - 0.82, face + 0.06), 34, Color("ecdfbf"), 0.0045)


## 레인: 과녁 앞 벨벳 매트 + 놋쇠 투척선 + 투척 구역 경계 로프(이 선 앞으로는 못 들어간다 = TableView 투명벽).
static func _lane(p: Node3D) -> void:
	var f := _faces()
	var line_z: float = TableView.THROW_LINE_Z
	var fence_z: float = TableView.NO_ENTRY_Z - 0.15
	var lane_length: float = fence_z - f.board_z
	var lane_center: float = (fence_z + f.board_z) / 2.0
	var lane_half: float = TableView.LANE_HALF
	MeshKit.box(p, "LaneMat", Vector3(lane_half * 2, 0.02, lane_length), Vector3(0, 0.02, lane_center), MeshKit.material("LaneVelvet", "244d43"))
	for side: float in [-1.0, 1.0]:
		MeshKit.box(p, "LanePinstripe", Vector3(0.02, 0.006, lane_length), Vector3(side * (lane_half - 0.1), 0.033, lane_center), PubParts.brass())
	# 투척선(Oche): 다트 홀 전체 폭. 이 선 뒤에서 던진다.
	MeshKit.box(p, "Oche", Vector3(f.hall_x1 - f.hall_x0 - 0.1, 0.03, 0.07), Vector3(0, 0.025, line_z), PubParts.brass())
	var oche_text := MeshKit.label(p, "OcheText", "투 척 선", Vector3(0, 0.045, line_z + 0.34), 48, Color("dcc68f"), 0.004)
	oche_text.rotation.x = -PI / 2
	# 로프는 가운데 보호 복도만 두른다(TableView 의 레인 벽과 같은 자리).
	# 복도 바깥 양옆은 비워 둔다 — 걸어 들어가 구경하거나 방해할 수 있는 통로다.
	for side: float in [-1.0, 1.0]:
		var front_post := Vector3(side * lane_half, 0, fence_z)
		var back_post := Vector3(side * lane_half, 0, f.board_z + 0.45)
		PubParts.stanchion(p, front_post)
		PubParts.stanchion(p, back_post)
		PubParts.rope_between(p, front_post, back_post, 0.14)
	PubParts.rope_between(p, Vector3(-lane_half, 0, fence_z), Vector3(lane_half, 0, fence_z))
	# 로프 가운데에 매단 안내판.
	MeshKit.box(p, "NoEntryPlaque", Vector3(0.62, 0.24, 0.02), Vector3(0, 0.5, fence_z + 0.03), PubParts.brass())
	MeshKit.box(p, "NoEntryPaper", Vector3(0.56, 0.18, 0.01), Vector3(0, 0.5, fence_z + 0.045), PubParts.dark())
	MeshKit.label(p, "NoEntryText", "출입 금지", Vector3(0, 0.5, fence_z + 0.052), 40, Color("e0c58d"), 0.0022)


## 도면의 럼주통. 큰 통 4개와 곁의 작은 통. 충돌은 TableView.BARRELS / SMALL_BARRELS.
static func _barrels(p: Node3D) -> void:
	var sets := [[TableView.BARRELS, TableView.BARREL_RADIUS, TableView.BARREL_HEIGHT, "RumBarrel"],
		[TableView.SMALL_BARRELS, TableView.SMALL_BARREL_RADIUS, TableView.SMALL_BARREL_HEIGHT, "SmallBarrel"]]
	for entry in sets:
		var spots: Array = entry[0]
		var radius: float = entry[1]
		var height: float = entry[2]
		for i in range(spots.size()):
			var at: Vector3 = spots[i]
			var node_name: String = "%s_%d" % [entry[3], i + 1]
			# 배가 부른 통: 가운데가 넓고 위가 좁다(cylinder 의 top 인자).
			MeshKit.cylinder(p, node_name, radius, height, at + Vector3(0, height / 2.0, 0), PubParts.wood(), 12, radius * 0.86)
			for ratio: float in [0.17, 0.8]:
				MeshKit.cylinder(p, node_name + "_Hoop", radius * 0.98, height * 0.06, at + Vector3(0, height * ratio, 0), PubParts.trim(), 12)
			MeshKit.cylinder(p, node_name + "_Top", radius * 0.8, 0.02, at + Vector3(0, height + 0.01, 0), PubParts.trim(), 12)


## 네모 카드 테이블(도면) + 자리 4개(자리 색 스툴·모양 매트·이름 글자) + 테이블 위 자리 매트(손패 7칸 + 예약 2칸).
static func _table_and_seats(p: Node3D) -> void:
	var table_center: Vector3 = TableView.TABLE_CENTER
	var size: Vector2 = TableView.TABLE_SIZE
	var height: float = TableView.TABLE_HEIGHT
	var table := Node3D.new()
	table.name = "CardTable"
	table.position = table_center
	p.add_child(table)
	MeshKit.box(table, "TableTop", Vector3(size.x, 0.08, size.y), Vector3(0, height - 0.04, 0), PubParts.wood())
	MeshKit.box(table, "TableFelt", Vector3(size.x - 0.16, 0.006, size.y - 0.16), Vector3(0, height + 0.003, 0), PubParts.felt())
	MeshKit.box(table, "TableApron", Vector3(size.x - 0.12, 0.12, size.y - 0.12), Vector3(0, height - 0.14, 0), PubParts.green())
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			MeshKit.box(table, "TableLeg", Vector3(0.1, height - 0.2, 0.1),
				Vector3(sx * (size.x / 2.0 - 0.14), (height - 0.2) / 2.0, sz * (size.y / 2.0 - 0.14)), PubParts.trim())
	for i in range(TableView.SEATS.size()):
		var seat: Vector3 = TableView.SEATS[i]
		var direction := Vector3(seat.x - table_center.x, 0, seat.z - table_center.z).normalized()
		# angle: 이 각도로 돌리면 로컬 +Z 가 자리 쪽을 본다.
		var angle := atan2(direction.x, direction.z)
		var color := MeshKit.material("PlayerColor_" + str(i), PlayerLook.hex(i))
		# 테이블 위 자리 매트: 카드 7칸(뒷면) + 예약 2칸.
		var mat_root := Node3D.new()
		mat_root.name = "SeatMat_%d" % (i + 1)
		mat_root.rotation.y = angle
		table.add_child(mat_root)
		var top := height + 0.012 + i * 0.0006 # 매트끼리 모서리가 겹쳐도 깜빡이지 않게 높이를 조금씩 다르게
		MeshKit.box(mat_root, "PlayerMat", Vector3(0.86, 0.006, 0.42), Vector3(0, top, 0.55), color)
		for c in range(7):
			MeshKit.box(mat_root, "CardBack", Vector3(0.1, 0.006, 0.15), Vector3(-0.36 + c * 0.12, top + 0.006, 0.61), MeshKit.material("CardBack", "f0e6cf"))
		for c in range(2):
			MeshKit.box(mat_root, "ReserveSlot", Vector3(0.1, 0.004, 0.15), Vector3(-0.08 + c * 0.16, top + 0.005, 0.44), PubParts.dark())
		var symbol := MeshKit.label(mat_root, "SeatSymbol", PlayerLook.SYMBOLS[i], Vector3(0.36, top + 0.012, 0.42), 64, Color("f0e6cf"), 0.0014)
		symbol.rotation.x = -PI / 2
		# 바닥: 자리 표시 매트(색 + 모양) · 자리 색 스툴 · "● 1번 자리" 글자.
		var rug := MeshKit.cylinder(p, "SeatRug_%d" % (i + 1), 0.55, 0.02, seat + Vector3(0, 0.012, 0), color, PlayerLook.MAT_SIDES[i])
		rug.rotation.y = angle + (PI / 4 if i == 3 else 0.0)
		PubParts.stool(p, seat, color, "SeatStool_%d" % (i + 1))
		var label := MeshKit.label(p, "SeatLabel_%d" % (i + 1), "%s %d번 자리" % [PlayerLook.SYMBOLS[i], i + 1], seat + direction * 0.85 + Vector3(0, 0.03, 0), 40, Color("f0e6cf"), 0.003)
		label.rotation = Vector3(-PI / 2, angle, 0)


## 라운지 왼쪽 벽 바: 카운터·발 난간·맥주 꼭지·종·컵, 벽 병 선반, 바 스툴, 바텐더 시안. 충돌은 TableView.BAR_BOX.
static func _bar(p: Node3D) -> void:
	var f := _faces()
	var box: AABB = TableView.BAR_BOX
	var z0: float = box.position.z + 0.1
	var z1: float = box.end.z - 0.1
	var mid: float = (z0 + z1) / 2.0
	var length: float = z1 - z0
	var front: float = box.end.x # 카운터 앞면 x(방 쪽). 스툴은 이 앞에 놓인다.
	var body_x: float = box.get_center().x
	PubParts.bottle_shelf(p, Vector3(f.lounge_x0 + 0.06, 0, mid), PI / 2, length - 0.4)
	MeshKit.box(p, "BarBody", Vector3(box.size.x - 0.3, 1.02, length), Vector3(body_x - 0.1, 0.51, mid), PubParts.green())
	MeshKit.box(p, "BarTop", Vector3(box.size.x, 0.08, length + 0.2), Vector3(body_x, 1.06, mid), PubParts.wood())
	MeshKit.box(p, "CounterInlay", Vector3(0.025, 0.01, length + 0.1), Vector3(front - 0.05, 1.105, mid), PubParts.brass())
	MeshKit.rod(p, "FootRail", Vector3(front - 0.15, 0.19, z0 + 0.15), Vector3(front - 0.15, 0.19, z1 - 0.15), 0.028, PubParts.brass())
	var panel_count := maxi(int(length / 1.1), 1)
	for i in range(panel_count):
		var z := z0 + length * (i + 0.5) / panel_count
		MeshKit.box(p, "BarPanel", Vector3(0.022, 0.73, length / panel_count - 0.2), Vector3(body_x + 0.24, 0.54, z), PubParts.inset_green())
	# 맥주 꼭지 3개 + 종(기획 M15) + 컵.
	for i in range(3):
		var tap := Vector3(body_x - 0.2, 1.1, mid - 0.4 + i * 0.4)
		MeshKit.cylinder(p, "TapPost", 0.03, 0.42, tap + Vector3(0, 0.21, 0), PubParts.brass())
		MeshKit.box(p, "TapHandle", Vector3(0.05, 0.16, 0.05), tap + Vector3(0.05, 0.47, 0), MeshKit.material("TapHandle_" + str(i), ["cf594f", "e4d7ad", "38806a"][i]))
	MeshKit.cylinder(p, "BellStand", 0.06, 0.03, Vector3(front - 0.25, 1.12, z0 + 0.45), PubParts.trim())
	MeshKit.sphere(p, "Bell", 0.09, Vector3(front - 0.25, 1.2, z0 + 0.45), PubParts.brass(), Vector3(1, 0.8, 1))
	for z: float in [z0 + 1.0, mid + 0.6, z1 - 0.6]:
		MeshKit.cylinder(p, "Coaster", 0.1, 0.008, Vector3(front - 0.22, 1.105, z), PubParts.brass())
		MeshKit.cylinder(p, "Cup", 0.055, 0.15, Vector3(front - 0.22, 1.185, z), PubParts.cream(), 12)
	for i in range(3):
		PubParts.stool(p, Vector3(front + 0.45, 0, z0 + length * (i + 0.5) / 3.0), PubParts.green(), "BarStool_%d" % (i + 1))
	# 바텐더 NPC 시안(움직이지 않음). 카운터 뒤에 서서 방 쪽(+X)을 본다.
	var bartender := (load(BARTENDER_SCENE) as PackedScene).instantiate() as Node3D
	bartender.position = Vector3((f.lounge_x0 + box.position.x) / 2.0, 0, mid + 1.0)
	bartender.rotation.y = PI / 2
	p.add_child(bartender)


## 도면의 "npc 자리": 네모 테이블 + 스툴 2개. 충돌은 TableView.NPC_TABLE_BOX / NPC_STOOLS.
static func _npc_corner(p: Node3D) -> void:
	var box: AABB = TableView.NPC_TABLE_BOX
	var center := box.get_center()
	var height: float = box.size.y
	var table := Node3D.new()
	table.name = "NpcTable"
	table.position = Vector3(center.x, 0, center.z)
	p.add_child(table)
	MeshKit.box(table, "NpcTableTop", Vector3(box.size.x, 0.07, box.size.z), Vector3(0, height - 0.035, 0), PubParts.wood())
	MeshKit.box(table, "NpcTableApron", Vector3(box.size.x - 0.12, 0.1, box.size.z - 0.12), Vector3(0, height - 0.13, 0), PubParts.green())
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			MeshKit.box(table, "NpcTableLeg", Vector3(0.09, height - 0.18, 0.09),
				Vector3(sx * (box.size.x / 2.0 - 0.13), (height - 0.18) / 2.0, sz * (box.size.z / 2.0 - 0.13)), PubParts.trim())
	# 테이블 위 잔과 컵받침(앉은 NPC 가 쓰는 자리라는 표시).
	for sz: float in [-0.4, 0.4]:
		MeshKit.cylinder(table, "NpcCoaster", 0.1, 0.008, Vector3(0, height + 0.012, sz), PubParts.brass())
		MeshKit.cylinder(table, "NpcCup", 0.055, 0.15, Vector3(0, height + 0.09, sz), PubParts.cream(), 12)
	for i in range(TableView.NPC_STOOLS.size()):
		PubParts.stool(p, TableView.NPC_STOOLS[i], PubParts.green(), "NpcStool_%d" % (i + 1))


## 도면의 당구대. 충돌은 TableView.POOL_TABLE_BOX.
static func _pool_table(p: Node3D) -> void:
	var box: AABB = TableView.POOL_TABLE_BOX
	var height: float = box.size.y
	var table := Node3D.new()
	table.name = "PoolTable"
	table.position = Vector3(box.get_center().x, 0, box.get_center().z)
	p.add_child(table)
	var half := Vector2(box.size.x / 2.0, box.size.z / 2.0)
	var felt := MeshKit.material("PoolFelt", "1f6b4a")
	MeshKit.box(table, "PoolBody", Vector3(box.size.x, height - 0.25, box.size.z), Vector3(0, (height - 0.25) / 2.0 + 0.1, 0), PubParts.wood())
	MeshKit.box(table, "PoolBed", Vector3(box.size.x - 0.18, 0.04, box.size.z - 0.18), Vector3(0, height - 0.06, 0), felt)
	# 쿠션(네 변 레일)과 포켓 6개.
	for sx: float in [-1.0, 1.0]:
		MeshKit.box(table, "PoolRail", Vector3(0.12, 0.1, box.size.z), Vector3(sx * (half.x - 0.06), height - 0.01, 0), PubParts.wood())
	for sz: float in [-1.0, 1.0]:
		MeshKit.box(table, "PoolRail", Vector3(box.size.x, 0.1, 0.12), Vector3(0, height - 0.01, sz * (half.y - 0.06)), PubParts.wood())
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 0.0, 1.0]:
			MeshKit.cylinder(table, "PoolPocket", 0.07, 0.03, Vector3(sx * (half.x - 0.08), height, sz * (half.y - 0.08)), PubParts.dark())
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			MeshKit.box(table, "PoolLeg", Vector3(0.16, 0.1, 0.16), Vector3(sx * (half.x - 0.18), 0.05, sz * (half.y - 0.18)), PubParts.trim())
	# 공 몇 개와 큐대(세워 놓음).
	var balls := [[Vector2(-0.2, -0.5), "f0e6cf"], [Vector2(0.1, 0.4), "cf594f"], [Vector2(0.25, 0.62), "e4c45a"]]
	for i in range(balls.size()):
		var spot: Vector2 = balls[i][0]
		MeshKit.sphere(table, "PoolBall_%d" % (i + 1), 0.055, Vector3(spot.x, height + 0.015, spot.y), MeshKit.material("PoolBall_" + str(i), balls[i][1]))
	MeshKit.rod(table, "PoolCue", Vector3(half.x + 0.1, 0.02, -half.y + 0.2), Vector3(half.x + 0.3, 1.45, -half.y + 0.1), 0.022, PubParts.wood())


## 창문·간판·화분·입구 문·조명 스위치.
static func _decor(p: Node3D) -> void:
	var f := _faces()
	# 다트 홀 옆창(특징 판넬을 피해 옆벽에).
	for side: float in [-1.0, 1.0]:
		var x: float = (f.hall_x1 if side > 0 else f.hall_x0) - side * 0.07
		PubParts.window(p, Vector3(x, 2.5, -5.1), -PI / 2 * side)
	# 라운지 뒷벽 창 둘과 오른쪽 벽 창 하나.
	for x: float in [-2.4, 1.8]:
		PubParts.window(p, Vector3(x, 2.5, f.back_z - 0.07), PI)
	PubParts.window(p, Vector3(f.lounge_x1 - 0.07, 2.5, 4.6), -PI / 2)
	# 오른쪽 벽 하우스 룰 간판(다트판과 헷갈리지 않게 네모 액자).
	var sign := Node3D.new()
	sign.name = "HouseRulesSign"
	sign.position = Vector3(f.lounge_x1 - 0.05, 2.3, 1.4)
	sign.rotation.y = -PI / 2
	p.add_child(sign)
	MeshKit.box(sign, "Frame", Vector3(1.75, 1.25, 0.09), Vector3.ZERO, PubParts.brass())
	MeshKit.box(sign, "Paper", Vector3(1.66, 1.16, 0.04), Vector3(0, 0, 0.06), PubParts.dark())
	MeshKit.label(sign, "Title", "좋은 한 발,\n좋은 사람들.", Vector3(0, 0.16, 0.09), 55, Color("e0c58d"), 0.0018)
	MeshKit.label(sign, "Caption", "DARTY   /   소 셜   클 럽", Vector3(0, -0.33, 0.09), 21)
	# 화분: 라운지 두 귀퉁이와 단차 모서리.
	PubParts.plant(p, Vector3(f.lounge_x0 + 0.6, 0, f.back_z - 0.6))
	PubParts.plant(p, Vector3(f.lounge_x1 - 0.6, 0, f.step_z + 0.6))
	PubParts.plant(p, Vector3(f.hall_x1 + 0.9, 0, f.step_z + 0.7))
	# 입구 문(뒷벽, 방 안쪽에서 보이는 면) + 문 옆 조명 스위치(기획 M11).
	var door := Vector3(8.4, 0, f.back_z - 0.02)
	MeshKit.box(p, "LightSwitchPlate", Vector3(0.13, 0.2, 0.03), Vector3(door.x - 0.9, 1.35, f.back_z - 0.015), PubParts.cream())
	MeshKit.box(p, "LightSwitchLever", Vector3(0.03, 0.08, 0.05), Vector3(door.x - 0.9, 1.38, f.back_z - 0.05), PubParts.brass())
	MeshKit.box(p, "DoorFrame", Vector3(1.3, 2.35, 0.06), door + Vector3(0, 1.175, 0), PubParts.trim())
	MeshKit.box(p, "Door", Vector3(1.1, 2.2, 0.04), door + Vector3(0, 1.1, -0.03), PubParts.wood())
	MeshKit.sphere(p, "DoorKnob", 0.04, door + Vector3(-0.42, 1.05, -0.07), PubParts.brass())
	var entrance := MeshKit.label(p, "EntranceSign", "입 구", door + Vector3(0, 2.6, -0.05), 48, Color("e0c58d"), 0.003)
	entrance.rotation.y = PI


## 환경(배경색·주변광·톤)과 조명. 다트판에 가장 밝은 흰 스포트라이트(기획 2-6), 나머지는 주황빛 펜던트.
## 밝기는 light_energy 로 조절한다. 그림자는 다트판 스포트·테이블 펜던트만 켠다(성능).
static func _lighting(p: Node3D) -> void:
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("182924")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b8b3a6")
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_hdr_threshold = 1.1
	world.environment = env
	p.add_child(world)
	var fill := DirectionalLight3D.new()
	fill.name = "SoftFill"
	fill.rotation_degrees = Vector3(-55, -25, 0)
	fill.light_color = Color("ffe2b6")
	fill.light_energy = 0.22
	p.add_child(fill)
	var f := _faces()
	var ceiling: float = TableView.CEILING_HEIGHT
	var table: Vector3 = TableView.TABLE_CENTER
	PubParts.pendant(p, table + Vector3(0, 3.0, 0), ceiling, 1.0, 7.5, true, 1.2)
	# 다트 홀: 투척 자리 위와 레인 위.
	PubParts.pendant(p, Vector3(0, 3.25, TableView.THROW_LINE_Z + 0.6), ceiling, 0.6, 6.5)
	PubParts.pendant(p, Vector3(0, 3.4, -1.4), ceiling, 0.5, 6.0)
	for side: float in [-1.0, 1.0]:
		PubParts.pendant(p, Vector3(side * 3.6, 3.3, TableView.THROW_LINE_Z + 1.6), ceiling, 0.4, 5.5)
	for z: float in [TableView.BAR_BOX.position.z + 1.4, TableView.BAR_BOX.end.z - 1.4]:
		PubParts.pendant(p, Vector3(TableView.BAR_BOX.get_center().x - 0.2, 3.2, z), ceiling, 0.45, 5.0, false, 0.8)
	PubParts.pendant(p, Vector3(TableView.NPC_TABLE_BOX.get_center().x, 3.1, TableView.NPC_TABLE_BOX.get_center().z), ceiling, 0.55, 5.5, false, 0.9)
	PubParts.pendant(p, Vector3(TableView.POOL_TABLE_BOX.get_center().x, 3.1, TableView.POOL_TABLE_BOX.get_center().z), ceiling, 0.6, 5.5, false, 1.1)
	for z: float in [2.1, 6.3]:
		PubParts.sconce(p, Vector3(f.lounge_x1 - 0.03, 2.6, z), Vector3.LEFT)
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
	p.add_child(spot)
