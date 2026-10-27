extends RefCounted
## F5 실제 경기 방(art/pub/pub_game.tscn)의 "보이는 것"을 만든다. pub_builder.gd 가 부른다(게임 실행 중에는 안 쓰인다).
##
## [왜 쇼케이스 펍과 따로 만드나]
## 실제 경기는 프로그래머가 정한 규칙 좌표가 있다: 과녁 중심 높이 2.9m·2.5배 크기, 투척선 z=-3.1, 테이블·자리 4개 위치.
## (앉은 자리에서도 던지므로 과녁이 크고 높다 — docs/ARCHITECTURE.md "좌표와 적중")
## 그래서 펍 디자인(벽·바닥·조명·소품 모양)은 그대로 쓰고, 배치만 그 좌표에 맞춘 방을 따로 만든다.
##
## [규칙 좌표는 어디서 오나]
## 전부 game/table/table.gd(TableView) 상수를 읽는다. 여기에 숫자를 따로 적지 않는다.
## 프로그래머가 그 상수를 바꾸면 이 생성기를 다시 돌려야 한다. 안 돌리면 게임 시작 때 경고가 뜨고
## tests/test_game_look.gd 가 실패한다(방에 저장된 layout_signature 와 비교).
##
## [충돌은 여기서 안 만든다]
## 벽·테이블·바·스툴 장애물·주크박스의 충돌은 TableView 가 만든다. 여기 있는 건 모두 "보이기만" 하는 물체다.
## 그래서 소품을 옮길 때 사람이 부딪히는 소품(바·장애물 스툴·주크박스)은 TableView 의 충돌 상수도 같이 옮겨야 한다.

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
	_table_and_seats(_group(room, "TableAndSeats"))
	_obstacles(_group(room, "Obstacles"))
	_bar(_group(room, "Bar"))
	_decor(_group(room, "Decor"))
	_lighting(_group(room, "Lights"))
	return room


## 에디터 장면 목록에서 찾기 쉽도록 부위별 묶음 노드를 만든다.
static func _group(parent: Node3D, group_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = group_name
	parent.add_child(node)
	return node


## 벽 안쪽 면 좌표(벽 충돌 상자 두께의 절반만큼 안쪽).
static func _inner() -> Vector2:
	return TableView.ROOM_HALF - Vector2.ONE * TableView.WALL_THICKNESS / 2.0


## 바닥 판자·벽(크림 회벽 + 초록 징두리)·천장·보.
static func _shell(p: Node3D) -> void:
	var inner := _inner()
	var ceiling := TableView.CEILING_HEIGHT
	# 바닥 판자: 0.5m 폭 × 2.8m 길이, 색 5가지를 엇갈려 깐다.
	var columns := int(ceil(inner.x * 2 / 0.5)) + 1
	for i in range(columns):
		for j in range(5):
			var shade := (i + j * 3) % 5
			var mat := MeshKit.material("Floor_" + str(shade), ["785b42", "846247", "70523b", "8d6a4a", "796048"][shade])
			MeshKit.box(p, "Floorboard", Vector3(0.485, 0.07, 2.78), Vector3(-inner.x + 0.1 + i * 0.5, -0.025, -inner.y + 1.25 + j * 2.8), mat)
	# 벽 4면(크림). 안쪽 면이 충돌 벽 안쪽 면과 맞는다.
	MeshKit.box(p, "BackWall", Vector3(inner.x * 2 + 0.4, ceiling, 0.18), Vector3(0, ceiling / 2, -inner.y - 0.09), PubParts.cream())
	MeshKit.box(p, "EntranceWall", Vector3(inner.x * 2 + 0.4, ceiling, 0.18), Vector3(0, ceiling / 2, inner.y + 0.09), PubParts.cream())
	for side: float in [-1.0, 1.0]:
		MeshKit.box(p, "SideWall", Vector3(0.18, ceiling, inner.y * 2 + 0.4), Vector3(side * (inner.x + 0.09), ceiling / 2, 0), PubParts.cream())
		# 옆벽 징두리(허리 높이 초록 판)·놋쇠 난간·위쪽 몰딩.
		MeshKit.box(p, "SideWainscot", Vector3(0.06, 1.2, inner.y * 2), Vector3(side * (inner.x - 0.03), 0.6, 0), PubParts.green())
		MeshKit.box(p, "SideRail", Vector3(0.08, 0.06, inner.y * 2), Vector3(side * (inner.x - 0.04), 1.22, 0), PubParts.brass())
		MeshKit.box(p, "SideCornice", Vector3(0.14, 0.18, inner.y * 2), Vector3(side * (inner.x - 0.07), ceiling - 0.2, 0), PubParts.trim())
		# 기둥(벽에 붙은 납작한 기둥). 투척 구역 경계(z=-3.3)와 네 모서리.
		for z: float in [-inner.y + 0.15, TableView.NO_ENTRY_Z - 0.1, inner.y - 0.15]:
			MeshKit.box(p, "Pilaster", Vector3(0.08, ceiling, 0.26), Vector3(side * (inner.x - 0.04), ceiling / 2, z), PubParts.trim())
	# 뒷벽 징두리 패널 20칸(쇼케이스 펍과 같은 무늬). 가운데(과녁 특징 판넬 FEATURE_HALF 안쪽)는 판넬이 덮으므로 비운다.
	var panel_count := 20
	var panel_step := inner.x * 2 / panel_count
	for i in range(panel_count):
		var x := -inner.x + panel_step * (i + 0.5)
		if absf(x) < FEATURE_HALF + panel_step / 2:
			continue
		MeshKit.box(p, "BackPanel", Vector3(panel_step - 0.04, 1.15, 0.06), Vector3(x, 0.6, -inner.y + 0.03), PubParts.green())
		MeshKit.box(p, "PanelInset", Vector3(panel_step - 0.17, 0.88, 0.025), Vector3(x, 0.6, -inner.y + 0.07), PubParts.inset_green())
	for side: float in [-1.0, 1.0]:
		var width := inner.x - FEATURE_HALF
		var x := side * (FEATURE_HALF + width / 2)
		MeshKit.box(p, "BackRail", Vector3(width, 0.06, 0.08), Vector3(x, 1.22, -inner.y + 0.05), PubParts.brass())
		MeshKit.box(p, "BackCornice", Vector3(width, 0.18, 0.14), Vector3(x, ceiling - 0.2, -inner.y + 0.07), PubParts.trim())
	# 입구 쪽 벽 징두리.
	MeshKit.box(p, "EntranceWainscot", Vector3(inner.x * 2, 1.2, 0.06), Vector3(0, 0.6, inner.y - 0.03), PubParts.green())
	MeshKit.box(p, "EntranceRail", Vector3(inner.x * 2, 0.06, 0.08), Vector3(0, 1.22, inner.y - 0.04), PubParts.brass())
	MeshKit.box(p, "EntranceCornice", Vector3(inner.x * 2, 0.18, 0.14), Vector3(0, ceiling - 0.2, inner.y - 0.07), PubParts.trim())
	# 천장(어두운 나무)과 보. 천장은 그림자를 만들지 않는다(위에서 오는 은은한 빛을 막지 않게).
	var roof := MeshKit.box(p, "Ceiling", Vector3(inner.x * 2 + 0.4, 0.08, inner.y * 2 + 0.4), Vector3(0, ceiling + 0.04, 0), PubParts.trim())
	roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for z: float in [-5.0, -1.6, 1.8, 5.2]:
		var beam := MeshKit.box(p, "CeilingBeam", Vector3(inner.x * 2, 0.16, 0.2), Vector3(0, ceiling - 0.08, z), MeshKit.material("BeamWood", "3a2c22"))
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## 과녁 벽: 초록 특징 판넬 + 다트판 캐비닛(문 두 짝이 열린 모양, 문 안쪽은 칠판) + 간판 글자.
## 다트판 자체는 여기 없다 — game/board/board.gd(BoardView)가 art/board_art.gd 로 실행 때 그린다(카드로 숫자가 바뀌기 때문).
static func _board_wall(p: Node3D) -> void:
	var inner := _inner()
	var ceiling := TableView.CEILING_HEIGHT
	var center := TableView.BOARD_CENTER
	var board_outer := BoardLayout.RADIUS * TableView.BOARD_SCALE * 1.33 # 숫자 띠 포함 판 반지름(약 1m)
	var face := -inner.y
	MeshKit.box(p, "FeaturePanel", Vector3(FEATURE_HALF * 2, ceiling, 0.05), Vector3(center.x, ceiling / 2, face + 0.025), PubParts.green())
	for x: float in [-FEATURE_HALF + 0.05, FEATURE_HALF - 0.05]:
		MeshKit.box(p, "FeatureBorder", Vector3(0.03, ceiling - 0.4, 0.03), Vector3(center.x + x, ceiling / 2, face + 0.06), PubParts.brass())
	# 캐비닛 몸통(판보다 조금 큰 정사각) + 안쪽 어두운 판 + 테두리.
	var half := board_outer + 0.15
	MeshKit.box(p, "Cabinet", Vector3(half * 2, half * 2, 0.06), Vector3(center.x, center.y, face + 0.06), PubParts.wood())
	MeshKit.box(p, "CabinetBacking", Vector3(half * 2 - 0.16, half * 2 - 0.16, 0.02), Vector3(center.x, center.y, face + 0.095), PubParts.dark())
	for y: float in [-1.0, 1.0]:
		MeshKit.box(p, "CabinetRail", Vector3(half * 2 + 0.08, 0.08, 0.1), Vector3(center.x, center.y + y * (half + 0.02), face + 0.08), PubParts.trim())
	# 열린 문 두 짝(벽에 붙어 있음). 왼쪽 문 칠판 = 실시간 점수판(GameView 가 글자를 바꾼다), 오른쪽 = 하우스 룰.
	for side: float in [-1.0, 1.0]:
		var door_x := center.x + side * (half + half / 2.0 + 0.02)
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
	MeshKit.label(p, "Brand", "다 티", Vector3(center.x, bottom - 0.42, face + 0.06), 110, Color("e6ca90"), 0.0042)
	MeshKit.label(p, "BrandSubtitle", "소 셜   클 럽", Vector3(center.x, bottom - 0.82, face + 0.06), 34, Color("ecdfbf"), 0.0045)


## 레인: 과녁 앞 벨벳 매트 + 놋쇠 투척선 + 투척 구역 경계 로프(이 선 앞으로는 못 들어간다 = TableView 투명벽).
static func _lane(p: Node3D) -> void:
	var inner := _inner()
	var line_z := TableView.THROW_LINE_Z
	var fence_z := TableView.NO_ENTRY_Z - 0.15
	var lane_length := fence_z - (-inner.y)
	var lane_center := (fence_z - inner.y) / 2.0
	MeshKit.box(p, "LaneMat", Vector3(2.4, 0.02, lane_length), Vector3(0, 0.02, lane_center), MeshKit.material("LaneVelvet", "244d43"))
	for x: float in [-1.1, 1.1]:
		MeshKit.box(p, "LanePinstripe", Vector3(0.02, 0.006, lane_length), Vector3(x, 0.033, lane_center), PubParts.brass())
	# 투척선(Oche): 방 전체 폭. 이 선 뒤 어디서든 던질 수 있다(앉은 자리 포함).
	MeshKit.box(p, "Oche", Vector3(inner.x * 2 - 0.1, 0.03, 0.07), Vector3(0, 0.025, line_z), PubParts.brass())
	var oche_text := MeshKit.label(p, "OcheText", "투 척 선", Vector3(0, 0.045, line_z + 0.34), 48, Color("dcc68f"), 0.004)
	oche_text.rotation.x = -PI / 2
	# 서서 던지는 표시(예전 노란 선 자리, z=-0.6). 의미는 팀 확인 필요 — 표시만 유지.
	MeshKit.box(p, "StandMarker", Vector3(1.5, 0.012, 0.06), Vector3(0, 0.012, -0.6), PubParts.brass())
	# 가로 로프: 투척 구역 경계. 기둥 6개 사이를 잇는다.
	var posts: Array[float] = [-inner.x + 0.25, -3.4, -1.2, 1.2, 3.4, inner.x - 0.25]
	for i in range(posts.size()):
		PubParts.stanchion(p, Vector3(posts[i], 0, fence_z))
		if i > 0:
			PubParts.rope_between(p, Vector3(posts[i - 1], 0, fence_z), Vector3(posts[i], 0, fence_z))
	# 레인 양옆 세로 로프(과녁까지).
	for x: float in [-1.2, 1.2]:
		var previous := Vector3(x, 0, fence_z)
		for z: float in [-4.9, -inner.y + 0.45]:
			var post := Vector3(x, 0, z)
			PubParts.stanchion(p, post)
			PubParts.rope_between(p, previous, post, 0.14)
			previous = post
	# 로프 가운데에 매단 안내판.
	MeshKit.box(p, "NoEntryPlaque", Vector3(0.62, 0.24, 0.02), Vector3(0, 0.5, fence_z + 0.03), PubParts.brass())
	MeshKit.box(p, "NoEntryPaper", Vector3(0.56, 0.18, 0.01), Vector3(0, 0.5, fence_z + 0.045), PubParts.dark())
	MeshKit.label(p, "NoEntryText", "출입 금지", Vector3(0, 0.5, fence_z + 0.052), 40, Color("e0c58d"), 0.0022)


## 원형 카드 테이블 + 자리 4개(자리 색 스툴·모양 매트·이름 글자) + 테이블 위 자리 매트(손패 7칸 + 예약 2칸 자리표시).
static func _table_and_seats(p: Node3D) -> void:
	var table_center := TableView.TABLE_CENTER
	var height := TableView.TABLE_HEIGHT
	var table := PubParts.round_table(p, table_center, TableView.TABLE_RADIUS, height)
	for i in range(TableView.SEATS.size()):
		var seat: Vector3 = TableView.SEATS[i]
		var direction := Vector3(seat.x - table_center.x, 0, seat.z - table_center.z).normalized()
		# angle: 이 각도로 돌리면 로컬 +Z 가 자리 쪽을 본다.
		var angle := atan2(direction.x, direction.z)
		var color := MeshKit.material("PlayerColor_" + str(i), PlayerLook.hex(i))
		# 테이블 위 자리 매트: 카드 7칸(뒷면) + 예약 2칸. 실제 카드 연출은 카드 담당 작업(후속).
		var mat_root := Node3D.new()
		mat_root.name = "SeatMat_%d" % (i + 1)
		mat_root.rotation.y = angle
		table.add_child(mat_root)
		var top := height + 0.012 + i * 0.0006 # 매트끼리 모서리가 겹쳐도 깜빡이지 않게 높이를 조금씩 다르게
		MeshKit.box(mat_root, "PlayerMat", Vector3(0.86, 0.006, 0.42), Vector3(0, top, 0.6), color)
		for c in range(7):
			MeshKit.box(mat_root, "CardBack", Vector3(0.1, 0.006, 0.15), Vector3(-0.36 + c * 0.12, top + 0.006, 0.66), MeshKit.material("CardBack", "f0e6cf"))
		for c in range(2):
			MeshKit.box(mat_root, "ReserveSlot", Vector3(0.1, 0.004, 0.15), Vector3(-0.08 + c * 0.16, top + 0.005, 0.49), PubParts.dark())
		var symbol := MeshKit.label(mat_root, "SeatSymbol", PlayerLook.SYMBOLS[i], Vector3(0.36, top + 0.012, 0.47), 64, Color("f0e6cf"), 0.0014)
		symbol.rotation.x = -PI / 2
		# 바닥: 자리 표시 매트(색 + 모양) · 자리 색 스툴 · "● 1번 자리" 글자.
		var rug := MeshKit.cylinder(p, "SeatRug_%d" % (i + 1), 0.55, 0.02, seat + Vector3(0, 0.012, 0), color, PlayerLook.MAT_SIDES[i])
		rug.rotation.y = angle + (PI / 4 if i == 3 else 0.0)
		PubParts.stool(p, seat, color, "SeatStool_%d" % (i + 1))
		var label := MeshKit.label(p, "SeatLabel_%d" % (i + 1), "%s %d번 자리" % [PlayerLook.SYMBOLS[i], i + 1], seat + direction * 0.85 + Vector3(0, 0.03, 0), 40, Color("f0e6cf"), 0.003)
		label.rotation = Vector3(-PI / 2, angle, 0)


## 스툴 장애물 3개(기획 2-7 "이동 약 6m, 스툴 장애물 3개"). 충돌은 TableView.OBSTACLES.
static func _obstacles(p: Node3D) -> void:
	for i in range(TableView.OBSTACLES.size()):
		var stool := PubParts.stool(p, TableView.OBSTACLES[i], PubParts.green(), "ObstacleStool_%d" % (i + 1))
		stool.rotation.y = i * 0.7


## 왼쪽 벽 바: 카운터·발 난간·맥주 꼭지·종·컵, 벽 병 선반, 바 스툴, 바텐더 시안. 충돌은 TableView.BAR_BOX.
static func _bar(p: Node3D) -> void:
	var inner := _inner()
	var box := TableView.BAR_BOX
	var z0 := box.position.z
	var z1 := box.end.z
	var mid := (z0 + z1) / 2.0
	var length := z1 - z0
	var front := -3.95 # 카운터 앞면 x(방 쪽). 스툴은 이 앞에 놓인다.
	PubParts.bottle_shelf(p, Vector3(-inner.x + 0.06, 0, mid), PI / 2, length - 0.4)
	MeshKit.box(p, "BarBody", Vector3(0.62, 1.02, length), Vector3(front - 0.31 - 0.25, 0.51, mid), PubParts.green())
	MeshKit.box(p, "BarTop", Vector3(0.95, 0.08, length + 0.2), Vector3(front - 0.42, 1.06, mid), PubParts.wood())
	MeshKit.box(p, "CounterInlay", Vector3(0.025, 0.01, length + 0.1), Vector3(front + 0.02, 1.105, mid), PubParts.brass())
	MeshKit.rod(p, "FootRail", Vector3(front - 0.15, 0.19, z0 + 0.15), Vector3(front - 0.15, 0.19, z1 - 0.15), 0.028, PubParts.brass())
	var panel_count := int(length / 1.1)
	for i in range(panel_count):
		var z := z0 + length * (i + 0.5) / panel_count
		MeshKit.box(p, "BarPanel", Vector3(0.022, 0.73, length / panel_count - 0.2), Vector3(front - 0.24, 0.54, z), PubParts.inset_green())
	# 맥주 꼭지 3개 + 종(기획 M15) + 컵.
	for i in range(3):
		var tap := Vector3(front - 0.62, 1.1, mid - 0.4 + i * 0.4)
		MeshKit.cylinder(p, "TapPost", 0.03, 0.42, tap + Vector3(0, 0.21, 0), PubParts.brass())
		MeshKit.box(p, "TapHandle", Vector3(0.05, 0.16, 0.05), tap + Vector3(0.05, 0.47, 0), MeshKit.material("TapHandle_" + str(i), ["cf594f", "e4d7ad", "38806a"][i]))
	MeshKit.cylinder(p, "BellStand", 0.06, 0.03, Vector3(front - 0.2, 1.12, z0 + 0.45), PubParts.trim())
	MeshKit.sphere(p, "Bell", 0.09, Vector3(front - 0.2, 1.2, z0 + 0.45), PubParts.brass(), Vector3(1, 0.8, 1))
	for z: float in [z0 + 1.2, mid + 0.9, z1 - 0.8]:
		MeshKit.cylinder(p, "Coaster", 0.1, 0.008, Vector3(front - 0.18, 1.105, z), PubParts.brass())
		MeshKit.cylinder(p, "Cup", 0.055, 0.15, Vector3(front - 0.18, 1.185, z), PubParts.cream(), 12)
	for i in range(3):
		PubParts.stool(p, Vector3(front + 0.32, 0, z0 + length * (i + 0.5) / 3.0), PubParts.green(), "BarStool_%d" % (i + 1))
	# 바텐더 NPC 시안(움직이지 않음). 방 쪽(+X)을 본다.
	var bartender := (load(BARTENDER_SCENE) as PackedScene).instantiate() as Node3D
	# 맥주 꼭지(가운데 ±0.4m)에 얼굴이 가리지 않게 입구 쪽으로 1.1m 비켜 선다.
	bartender.position = Vector3((-inner.x + front - 0.6) / 2.0 + 0.1, 0, mid + 1.1)
	bartender.rotation.y = PI / 2
	p.add_child(bartender)


## 창문·간판·화분·술통·주크박스·조명 스위치·입구 문.
static func _decor(p: Node3D) -> void:
	var inner := _inner()
	for x: float in [-4.15, 4.15]:
		PubParts.window(p, Vector3(x, 2.5, -inner.y + 0.07))
	PubParts.window(p, Vector3(inner.x - 0.07, 2.4, -1.0), -PI / 2)
	# 오른쪽 벽 하우스 룰 간판(다트판과 헷갈리지 않게 네모 액자).
	var sign := Node3D.new()
	sign.name = "HouseRulesSign"
	sign.position = Vector3(inner.x - 0.05, 2.25, 2.6)
	sign.rotation.y = -PI / 2
	p.add_child(sign)
	MeshKit.box(sign, "Frame", Vector3(1.75, 1.25, 0.09), Vector3.ZERO, PubParts.brass())
	MeshKit.box(sign, "Paper", Vector3(1.66, 1.16, 0.04), Vector3(0, 0, 0.06), PubParts.dark())
	MeshKit.label(sign, "Title", "좋은 한 발,\n좋은 사람들.", Vector3(0, 0.16, 0.09), 55, Color("e0c58d"), 0.0018)
	MeshKit.label(sign, "Caption", "다 티   /   소 셜   클 럽", Vector3(0, -0.33, 0.09), 21)
	# 과녁 양옆(못 들어가는 구역) 장식: 화분·술통.
	for side: float in [-1.0, 1.0]:
		PubParts.plant(p, Vector3(side * (inner.x - 0.6), 0, -inner.y + 0.6))
		var barrel := Vector3(side * 4.5, 0, -4.3)
		MeshKit.cylinder(p, "Barrel", 0.36, 0.86, barrel + Vector3(0, 0.43, 0), PubParts.wood(), 12, 0.36)
		for y: float in [0.15, 0.71]:
			MeshKit.cylinder(p, "BarrelHoop", 0.375, 0.05, barrel + Vector3(0, y, 0), PubParts.trim(), 12)
		MeshKit.cylinder(p, "BarrelTop", 0.3, 0.02, barrel + Vector3(0, 0.87, 0), PubParts.trim(), 12)
	# 주크박스(기획 M10, 상호작용은 후속). 입구 벽에 붙어 방 쪽(-Z)을 본다. 충돌 = TableView.JUKEBOX_BOX.
	# 로컬 좌표: 폭 = x, 깊이 = z, 앞면 = +Z → 180도 돌려 방 쪽을 보게 한다.
	var jukebox := TableView.JUKEBOX_BOX
	var juke := Node3D.new()
	juke.name = "Jukebox"
	juke.position = Vector3(jukebox.get_center().x, 0, jukebox.get_center().z)
	juke.rotation.y = PI
	p.add_child(juke)
	var width := jukebox.size.x - 0.05
	var depth := jukebox.size.z - 0.05
	var dome_radius := width / 2.0
	var body_height := jukebox.size.y - dome_radius
	var juke_wood := MeshKit.material("JukeboxWood", "6b3f2c")
	MeshKit.box(juke, "JukeboxBody", Vector3(width, body_height, depth), Vector3(0, body_height / 2, 0), juke_wood)
	var dome := MeshKit.cylinder(juke, "JukeboxDome", dome_radius, depth, Vector3(0, body_height, 0), juke_wood, 12)
	dome.rotation.x = PI / 2
	var front := depth / 2 + 0.015
	MeshKit.box(juke, "JukeboxGlow", Vector3(width - 0.3, 0.45, 0.03), Vector3(0, 0.88, front), MeshKit.material("JukeboxLight", "ffb870", 0, 1.6))
	MeshKit.box(juke, "JukeboxGrill", Vector3(width - 0.3, 0.38, 0.03), Vector3(0, 0.38, front), PubParts.brass())
	var arch := MeshKit.cylinder(juke, "JukeboxArch", dome_radius - 0.08, 0.03, Vector3(0, body_height, front), MeshKit.material("JukeboxLight", "ffb870", 0, 1.6), 12)
	arch.rotation.x = PI / 2
	# 입구 문(입구 벽, 방 안쪽에서 보이는 면) + 문 옆 조명 스위치(기획 M11).
	var door := Vector3(2.6, 0, inner.y - 0.02)
	MeshKit.box(p, "LightSwitchPlate", Vector3(0.13, 0.2, 0.03), Vector3(door.x - 0.9, 1.35, inner.y - 0.015), PubParts.cream())
	MeshKit.box(p, "LightSwitchLever", Vector3(0.03, 0.08, 0.05), Vector3(door.x - 0.9, 1.38, inner.y - 0.05), PubParts.brass())
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
	var ceiling := TableView.CEILING_HEIGHT
	var table := TableView.TABLE_CENTER
	PubParts.pendant(p, table + Vector3(0, 3.0, 0), ceiling, 1.0, 7.5, true, 1.2)
	PubParts.pendant(p, Vector3(0, 3.25, -0.9), ceiling, 0.6, 6.5)
	var bar_x := -4.55
	for z: float in [TableView.BAR_BOX.position.z + 1.4, TableView.BAR_BOX.end.z - 1.4]:
		PubParts.pendant(p, Vector3(bar_x, 3.2, z), ceiling, 0.45, 5.0, false, 0.8)
	var inner := _inner()
	for z: float in [0.9, 4.4]:
		PubParts.sconce(p, Vector3(inner.x - 0.03, 2.6, z), Vector3.LEFT)
	var spot := SpotLight3D.new()
	spot.name = "BoardSpot"
	spot.position = Vector3(TableView.BOARD_CENTER.x, ceiling - 0.2, TableView.BOARD_CENTER.z + 2.4)
	spot.light_color = Color("ffe6c4")
	spot.light_energy = 2.2
	spot.spot_range = 5.5
	spot.spot_angle = 30
	spot.spot_attenuation = 0.6
	spot.shadow_enabled = true
	# 아직 장면 트리 밖이라 look_at 대신 방향 행렬을 직접 만든다(조명은 -Z 쪽을 비춘다).
	spot.basis = Basis.looking_at(TableView.BOARD_CENTER - spot.position)
	p.add_child(spot)
