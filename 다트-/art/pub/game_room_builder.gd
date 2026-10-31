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
	var pub_only := _group(room, "PubOnly")
	_decor(_group(room, "Decor"), _group(room, "Windows"), pub_only)
	_furnish(_group(room, "Furnishings"), pub_only)
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
## convex_from/to = 그 끝이 ㄱ자의 "튀어나온 모서리"(다트 홀 옆벽과 단차 벽이 만나는 곳)인지.
##   2026-10-31 늦은 밤 사용자 지적 "코드로 맵을 구성해서 갈라지거나 퀄이 좋지 않다":
##   예전에는 모든 벽판을 양끝 0.18m 씩 늘렸다 → 들어간 모서리에서는 벽 속에 숨지만 튀어나온 모서리에서는
##   벽판 끝이 방 안으로 0.18m 삐져나와 모서리가 계단처럼 깨져 보였다. 이제 튀어나온 끝은 늘리지 않고,
##   징두리·난간·몰딩은 제 두께만큼만 늘려 두 벽의 띠가 모서리에서 딱 맞물리게 한다(+ 모서리 기둥으로 이음매를 덮는다).
static func _wall_run(p: Node3D, from: Vector2, to: Vector2, inward: Vector2, ceiling: float, trim := true,
		convex_from := false, convex_to := false) -> void:
	var along := (to - from).normalized()
	var wall_from := from - along * (0.0 if convex_from else 0.18)
	var wall_to := to + along * (0.0 if convex_to else 0.18)
	_plank(p, "Wall", (wall_from + wall_to) / 2.0 - inward * 0.09, along, (wall_to - wall_from).length(), 0.18, ceiling / 2.0, ceiling, PubParts.cream())
	# 띠 하나: 튀어나온 모서리 쪽 끝만 제 두께(thickness)만큼 늘린다.
	var band := func(node_name: String, depth: float, thickness: float, y: float, height: float, mat: Material) -> void:
		var a := from - along * (thickness if convex_from else 0.0)
		var b := to + along * (thickness if convex_to else 0.0)
		_plank(p, node_name, (a + b) / 2.0 + inward * depth, along, (b - a).length(), thickness, y, height, mat)
	if trim:
		band.call("Wainscot", 0.03, 0.06, 0.6, 1.2, PubParts.green())
		band.call("WallRail", 0.04, 0.08, 1.22, 0.06, PubParts.brass())
	band.call("Cornice", 0.07, 0.14, ceiling - 0.2, 0.18, PubParts.trim())


## 바닥 판자·벽 8면·천장·보.
## 2026-10-31 늦은 밤 "갈라짐" 정리:
##   - 바닥: 판자 아래에 어두운 밑판(Subfloor)을 깔아 판자 사이 틈이 "구멍(배경색)"이 아니라 홈으로 보인다.
##     판자는 칸(다트 홀·라운지)마다 따로 깔고 칸 경계에서 잘라 ㄱ자 모서리에 빈 곳이 생기지 않는다.
##     줄마다 이음매 위치를 엇갈려(1.1m) 진짜 마루처럼 보이게 한다.
##   - 천장: 두 칸 천장판이 z=0 에서 0.4m 겹쳐 같은 높이에서 깜빡였다(z-fighting) → 겹치지 않게 맞붙인다.
##   - 보: 칸 길이에 맞춰 간격을 계산한다(라운지가 9m 로 길어져 보를 3개로).
static func _shell(p: Node3D) -> void:
	var f := _faces()
	var ceiling: float = TableView.CEILING_HEIGHT
	var hall: Rect2 = TableView.DART_HALL
	var lounge: Rect2 = TableView.LOUNGE
	var edge: float = TableView.WALL_THICKNESS / 2.0
	# 밑판: 다트 홀은 z 0 까지, 라운지는 z 0 부터(겹치지 않게). 바깥쪽은 벽 속까지 덮는다.
	var under := MeshKit.material("Subfloor", "2a1d15")
	for slab: Rect2 in [Rect2(hall.position.x - edge, hall.position.y - edge, hall.size.x + edge * 2.0, hall.size.y + edge),
			Rect2(lounge.position.x - edge, lounge.position.y, lounge.size.x + edge * 2.0, lounge.size.y + edge)]:
		MeshKit.box(p, "Subfloor", Vector3(slab.size.x, 0.1, slab.size.y), Vector3(slab.get_center().x, -0.08, slab.get_center().y), under)
	# 판자: 폭 0.5m(틈 1.5cm) · 길이 2.8m(틈 2cm), 색 5가지. 칸 테두리에서 잘라 낸다.
	var column := 0
	for room: Rect2 in [hall, lounge]:
		var x: float = room.position.x
		while x < room.end.x - 0.01:
			var width: float = minf(0.5, room.end.x - x)
			var z: float = room.position.y - fmod(column * 1.1, 2.8)
			var row := 0
			while z < room.end.y - 0.01:
				var z0: float = maxf(z, room.position.y)
				var z1: float = minf(z + 2.8, room.end.y)
				if z1 - z0 > 0.05:
					var shade := (column + row * 3) % 5
					var mat := MeshKit.material("Floor_" + str(shade), ["785b42", "846247", "70523b", "8d6a4a", "796048"][shade])
					MeshKit.box(p, "Floorboard", Vector3(width - 0.015, 0.07, z1 - z0 - 0.02), Vector3(x + width / 2.0, -0.025, (z0 + z1) / 2.0), mat)
				z += 2.8
				row += 1
			x += 0.5
			column += 1
	# 벽 8면(ㄱ자 둘레). 과녁 벽은 특징 판넬이 덮으므로 징두리를 생략한다.
	# 튀어나온 모서리 = (hall_x0, step_z) · (hall_x1, step_z). 그쪽 끝은 convex 로 만든다.
	_wall_run(p, Vector2(f.hall_x0, f.board_z), Vector2(f.hall_x1, f.board_z), Vector2.DOWN, ceiling, false)
	_wall_run(p, Vector2(f.hall_x0, f.board_z), Vector2(f.hall_x0, f.step_z), Vector2.RIGHT, ceiling, true, false, true)
	_wall_run(p, Vector2(f.hall_x1, f.board_z), Vector2(f.hall_x1, f.step_z), Vector2.LEFT, ceiling, true, false, true)
	_wall_run(p, Vector2(f.lounge_x0, f.step_z), Vector2(f.hall_x0, f.step_z), Vector2.DOWN, ceiling, true, false, true)
	_wall_run(p, Vector2(f.hall_x1, f.step_z), Vector2(f.lounge_x1, f.step_z), Vector2.DOWN, ceiling, true, true, false)
	_wall_run(p, Vector2(f.lounge_x0, f.step_z), Vector2(f.lounge_x0, f.back_z), Vector2.RIGHT, ceiling)
	_wall_run(p, Vector2(f.lounge_x1, f.step_z), Vector2(f.lounge_x1, f.back_z), Vector2.LEFT, ceiling)
	_wall_run(p, Vector2(f.lounge_x0, f.back_z), Vector2(f.lounge_x1, f.back_z), Vector2.UP, ceiling)
	# 튀어나온 모서리 기둥(어두운 나무): 두 벽이 만나는 세로 이음매를 덮는다.
	for corner: Vector2 in [Vector2(f.hall_x0, f.step_z), Vector2(f.hall_x1, f.step_z)]:
		MeshKit.box(p, "CornerPost", Vector3(0.16, ceiling, 0.16), Vector3(corner.x, ceiling / 2.0, corner.y), PubParts.trim())
	# 천장(어두운 나무). 칸마다 한 장이고 그림자를 만들지 않는다(위에서 오는 은은한 빛을 막지 않게).
	for roof_rect: Rect2 in [Rect2(hall.position.x - 0.2, hall.position.y - 0.2, hall.size.x + 0.4, hall.size.y + 0.2),
			Rect2(lounge.position.x - 0.2, lounge.position.y, lounge.size.x + 0.4, lounge.size.y + 0.2)]:
		var roof := MeshKit.box(p, "Ceiling", Vector3(roof_rect.size.x, 0.08, roof_rect.size.y),
			Vector3(roof_rect.get_center().x, ceiling + 0.04, roof_rect.get_center().y), PubParts.trim())
		roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 보: 칸마다 폭을 맞춰 가로로 지른다. 다트 홀 2개(과녁 조명 자리를 피해), 라운지는 길이에 맞춰 3개.
	var beams := {hall: [-5.4, -2.1], lounge: [lounge.position.y + lounge.size.y * 0.22, lounge.get_center().y, lounge.position.y + lounge.size.y * 0.8]}
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
			# 2026-10-31 밤: RG Poly 나무통(테·나뭇결 있는 모델)을 충돌 원기둥 크기에 맞춰 놓는다. 통마다 조금씩 돌려 똑같아 보이지 않게.
			var big: bool = entry[3] == "RumBarrel"
			var source: Vector3 = Vector3(0.864, 0.907, 0.887) if big else Vector3(0.864, 0.878, 0.887)
			var fit := Vector3(radius * 2.0 / source.x, height / source.y, radius * 2.0 / source.z)
			if PubParts.asset(p, "barrel" if big else "barrel_small", at, i * 1.3 + 0.4, fit, node_name) != null:
				continue
			# 배가 부른 통: 가운데가 넓고 위가 좁다(cylinder 의 top 인자).
			MeshKit.cylinder(p, node_name, radius, height, at + Vector3(0, height / 2.0, 0), PubParts.wood(), 12, radius * 0.86)
			for ratio: float in [0.17, 0.8]:
				MeshKit.cylinder(p, node_name + "_Hoop", radius * 0.98, height * 0.06, at + Vector3(0, height * ratio, 0), PubParts.trim(), 12)
			MeshKit.cylinder(p, node_name + "_Top", radius * 0.8, 0.02, at + Vector3(0, height + 0.01, 0), PubParts.trim(), 12)
	# 투척 구역 안 큰 통 둘(3·4번)은 뚜껑을 덮어 "서서 마시는 탁자"로 쓴다: 맥주잔·잔·치즈/빵 — 구경꾼이 기대는 자리.
	for i: int in [2, 3]:
		var top: Vector3 = TableView.BARRELS[i] + Vector3(0, TableView.BARREL_HEIGHT, 0)
		var side: float = -1.0 if TableView.BARRELS[i].x < 0 else 1.0
		if PubParts.asset(p, "barrel_lid", top, 0.3, Vector3(1.0, 0.5, 1.0), "BarrelTableLid_%d" % (i + 1)) == null:
			continue
		var surface: Vector3 = top + Vector3(0, 0.06, 0)
		PubParts.asset(p, "mug", surface + Vector3(0.12 * side, 0, -0.1), 2.2 * side, Vector3.ONE * 0.6)
		PubParts.asset(p, "goblet", surface + Vector3(-0.1 * side, 0, 0.14), 0.0, Vector3.ONE * 0.7)
		PubParts.asset(p, "cheese" if i == 2 else "bread", surface + Vector3(-0.12 * side, 0, -0.15), 0.6, Vector3.ONE * 0.6)


## 원형 카드 테이블(2026-10-29 요청) + 자리 4개(자리 색 스툴·모양 매트·이름 글자) + 테이블 위 자리 매트(손패 7칸 + 예약 2칸).
static func _table_and_seats(p: Node3D) -> void:
	var table_center: Vector3 = TableView.TABLE_CENTER
	var size: Vector2 = TableView.TABLE_SIZE
	var height: float = TableView.TABLE_HEIGHT
	var table := Node3D.new()
	table.name = "CardTable"
	table.position = table_center
	p.add_child(table)
	MeshKit.cylinder(table, "TableTop", size.x / 2.0, 0.08, Vector3(0, height - 0.04, 0), PubParts.wood(), 48)
	MeshKit.cylinder(table, "TableFelt", size.x / 2.0 - 0.08, 0.006, Vector3(0, height + 0.003, 0), PubParts.felt(), 48)
	MeshKit.cylinder(table, "TableApron", size.x / 2.0 - 0.06, 0.12, Vector3(0, height - 0.14, 0), PubParts.green(), 48)
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
		# 테이블 위 자리 매트 + 예약 2칸. 카드 7칸은 그리지 않는다(2026-10-31):
		# F5 는 game/table/seat_cards.gd, F6 시연은 table_cards.gd 가 실제 손패 장수만큼 진짜 카드를 이 매트 위에 깐다.
		# 예전처럼 흰 상자 7개를 구워 두면 손패가 줄어도 그대로 남아 "카드가 있는 것처럼" 보였다.
		var mat_root := Node3D.new()
		mat_root.name = "SeatMat_%d" % (i + 1)
		mat_root.rotation.y = angle
		table.add_child(mat_root)
		var top := height + 0.012 + i * 0.0006 # 매트끼리 모서리가 겹쳐도 깜빡이지 않게 높이를 조금씩 다르게
		MeshKit.box(mat_root, "PlayerMat", Vector3(0.86, 0.006, 0.42), Vector3(0, top, 0.55), color)
		# 카드 칸 자리 표시: 얇고 어두운 테두리 홈(카드가 없을 때도 "여기에 카드가 놓인다"가 보인다).
		# 2026-10-31 밤: 검은 상자(NearBlack)는 F5 화면에서 "구멍"처럼 보였다 → 자리 색을 어둡게 한 얕은 홈으로 바꾼다.
		var groove := MeshKit.material("PlayerSlot_" + str(i), Color(PlayerLook.hex(i)).darkened(0.35).to_html(false))
		for c in range(7):
			MeshKit.box(mat_root, "CardSlot", Vector3(0.104, 0.002, 0.15), Vector3(-0.36 + c * 0.12, top + 0.004, 0.66), groove)
		for c in range(2):
			MeshKit.box(mat_root, "ReserveSlot", Vector3(0.1, 0.002, 0.15), Vector3(-0.08 + c * 0.16, top + 0.004, 0.44), groove)
		var symbol := MeshKit.label(mat_root, "SeatSymbol", PlayerLook.SYMBOLS[i], Vector3(0.36, top + 0.012, 0.42), 64, Color("f0e6cf"), 0.0014)
		symbol.rotation.x = -PI / 2
		# 바닥: 자리 표시 매트(색 + 모양) · 자리 색 스툴 · "● 1번 자리" 글자.
		var rug := MeshKit.cylinder(p, "SeatRug_%d" % (i + 1), 0.55, 0.02, seat + Vector3(0, 0.012, 0), color, PlayerLook.MAT_SIDES[i])
		rug.rotation.y = angle + (PI / 4 if i == 3 else 0.0)
		# 자리 스툴: RG Poly 스툴(방석 = 자리 색으로 구움, 0.57m → 1.05배 = 충돌 높이 0.6m). 없으면 도형 스툴.
		if PubParts.asset(p, "seat_stool_%d" % i, seat, angle, Vector3.ONE * 1.05, "SeatStool_%d" % (i + 1)) == null:
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
	# 컵받침: 맥주잔(집어 마시고 던지는 소품, LoungeWorld)이 놓이는 자리. 잔을 들고 가도 받침은 남는다.
	for at: Vector3 in TableView.BAR_MUGS:
		MeshKit.cylinder(p, "Coaster", 0.1, 0.008, at + Vector3(0, 0.005, 0), PubParts.brass())
	# 바 위 안주(빵·치즈) — 맥주잔과 병 소품 줄 사이 빈자리. 과일 그릇은 측정표에서 빈 그릇처럼 보여 뺐다.
	PubParts.asset(p, "bread", Vector3(front - 0.3, TableView.BAR_TOP_Y, 2.45), 0.5, Vector3.ONE * 0.7)
	PubParts.asset(p, "cheese", Vector3(front - 0.32, TableView.BAR_TOP_Y, 2.72), 1.2, Vector3.ONE * 0.55)
	for i in range(3):
		var stool_at := Vector3(front + 0.45, 0, z0 + length * (i + 0.5) / 3.0)
		# 바 스툴: RG Poly 높은 스툴(0.81m, 바 윗면 1.1m 에 맞는 높이). 없으면 도형 스툴.
		if PubParts.asset(p, "bar_stool", stool_at, i * 0.7, Vector3.ONE, "BarStool_%d" % (i + 1)) == null:
			PubParts.stool(p, stool_at, PubParts.green(), "BarStool_%d" % (i + 1))
	_bar_fridge(p)
	# 바텐더 NPC 시안(움직이지 않음). 카운터 뒤에 서서 방 쪽(+X)을 본다.
	var bartender := (load(BARTENDER_SCENE) as PackedScene).instantiate() as Node3D
	bartender.position = Vector3((f.lounge_x0 + box.position.x) / 2.0, 0, mid + 1.0)
	bartender.rotation.y = PI / 2
	p.add_child(bartender)


## 바 끝 유리문 음료 냉장고(2026-10-31 늦은 밤). 라운지가 뒤로 길어지며 생긴 바 끝 틈을 막는다.
## 충돌은 TableView.decor_blocks()(BAR_FRIDGE_AT · BAR_FRIDGE_SIZE). 문(유리)은 방 쪽 +X, 안쪽은 따뜻한 빛 + 병 선반 4칸.
static func _bar_fridge(p: Node3D) -> void:
	var at: Vector3 = TableView.BAR_FRIDGE_AT
	var size: Vector3 = TableView.BAR_FRIDGE_SIZE
	var front: float = at.x + size.x / 2.0
	var fridge := Node3D.new()
	fridge.name = "DrinkFridge"
	p.add_child(fridge)
	# 몸통은 속이 빈 틀(뒤판·옆판·아래·위)이다 — 꽉 찬 상자면 유리문 안의 선반·병이 가려져 안 보인다.
	var depth: float = size.x - 0.02
	MeshKit.box(fridge, "FridgeBack", Vector3(0.06, size.y, size.z), Vector3(at.x - size.x / 2.0 + 0.03, size.y / 2.0, at.z), PubParts.green())
	for dz: float in [-1.0, 1.0]:
		MeshKit.box(fridge, "FridgeSide", Vector3(depth, size.y, 0.06), Vector3(at.x - 0.01, size.y / 2.0, at.z + dz * (size.z / 2.0 - 0.03)), PubParts.green())
	MeshKit.box(fridge, "FridgeBase", Vector3(depth, 0.16, size.z), Vector3(at.x - 0.01, 0.08, at.z), PubParts.green())
	MeshKit.box(fridge, "FridgeCrown", Vector3(depth, 0.22, size.z), Vector3(at.x - 0.01, size.y - 0.11, at.z), PubParts.green())
	MeshKit.box(fridge, "FridgeTop", Vector3(size.x + 0.04, 0.06, size.z + 0.04), at + Vector3(0, size.y + 0.03, 0), PubParts.trim())
	MeshKit.box(fridge, "FridgeKick", Vector3(0.04, 0.12, size.z - 0.04), Vector3(front, 0.06, at.z), PubParts.trim())
	# 안쪽: 따뜻한 빛 판(뒤) + 선반 4칸 + 병. 문 유리는 반투명이라 안이 보인다.
	var inside: float = front - 0.4
	MeshKit.box(fridge, "FridgeGlow", Vector3(0.02, size.y - 0.42, size.z - 0.22), Vector3(inside - 0.08, size.y / 2.0 + 0.06, at.z), MeshKit.material("FridgeLight", "f3e2b8", 0.0, 1.4))
	for shelf in range(4):
		var y: float = 0.36 + shelf * 0.38
		MeshKit.box(fridge, "FridgeShelf", Vector3(0.42, 0.02, size.z - 0.2), Vector3(inside + 0.12, y, at.z), PubParts.brass())
		for slot in range(5):
			var z: float = at.z - size.z / 2.0 + 0.28 + slot * (size.z - 0.56) / 4.0
			PubParts.asset(fridge, "shelf_bottle_%d" % ((shelf + slot) % 4), Vector3(inside + 0.14, y + 0.01, z), slot * 0.9, Vector3.ONE * 0.75)
	var glass := StandardMaterial3D.new()
	glass.resource_name = "FridgeGlass"
	glass.albedo_color = Color(0.75, 0.88, 0.92, 0.18)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic_specular = 0.9
	MeshKit.box(fridge, "FridgeDoorGlass", Vector3(0.02, size.y - 0.32, size.z - 0.12), Vector3(front + 0.005, size.y / 2.0 + 0.04, at.z), glass)
	for dz: float in [-1.0, 1.0]:
		MeshKit.box(fridge, "FridgeDoorFrame", Vector3(0.05, size.y - 0.3, 0.05), Vector3(front + 0.01, size.y / 2.0 + 0.04, at.z + dz * (size.z / 2.0 - 0.05)), PubParts.trim())
	MeshKit.rod(fridge, "FridgeHandle", Vector3(front + 0.06, 0.8, at.z - size.z / 2.0 + 0.16), Vector3(front + 0.06, 1.35, at.z - size.z / 2.0 + 0.16), 0.016, PubParts.brass())
	var label := MeshKit.label(fridge, "FridgeSign", "시원한 음료", Vector3(front + 0.035, size.y - 0.09, at.z), 40, Color("e0c58d"), 0.003)
	label.rotation.y = PI / 2


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
	# 테이블 위: 먹다 만 저녁(피자·버거·감자튀김) + 맥주잔 둘(앉은 NPC 가 쓰는 자리라는 표시).
	# 2026-10-31 밤: 크림색 원기둥 컵 → RG Poly 맥주잔·음식. 모델이 없으면 예전 컵을 쓴다.
	var surface := height + 0.006
	if PubParts.asset(table, "pizza", Vector3(0.1, surface, 0.0), 0.4, Vector3.ONE * 0.85) != null:
		PubParts.asset(table, "burger", Vector3(-0.45, surface, -0.38), 1.1, Vector3.ONE * 0.8)
		PubParts.asset(table, "fries", Vector3(0.5, surface, 0.4), -0.5, Vector3.ONE * 0.8)
		# 맥주잔은 의자 쪽 가장자리(의자가 z 앞뒤에 있다).
		for sz: float in [-0.5, 0.5]:
			MeshKit.cylinder(table, "NpcCoaster", 0.1, 0.008, Vector3(-0.35 * sz * 2.0, height + 0.012, sz), PubParts.brass())
			PubParts.asset(table, "mug", Vector3(-0.35 * sz * 2.0, surface + 0.008, sz), PI if sz > 0 else 0.0, Vector3.ONE * 0.6)
	else:
		for sz: float in [-0.4, 0.4]:
			MeshKit.cylinder(table, "NpcCoaster", 0.1, 0.008, Vector3(0, height + 0.012, sz), PubParts.brass())
			MeshKit.cylinder(table, "NpcCup", 0.055, 0.15, Vector3(0, height + 0.09, sz), PubParts.cream(), 12)
	for i in range(TableView.NPC_STOOLS.size()):
		# NPC 자리: RG Poly 나무 의자가 테이블을 보게 돌린다(모델 앞 = -Z 로 보고 확인 후 맞춤 — 렌더 투어로 확인).
		var chair_at: Vector3 = TableView.NPC_STOOLS[i]
		var facing: float = 0.0 if chair_at.z < center.z else PI
		if PubParts.asset(p, "chair", chair_at, facing, Vector3.ONE * 0.95, "NpcStool_%d" % (i + 1)) == null:
			PubParts.stool(p, chair_at, PubParts.green(), "NpcStool_%d" % (i + 1))


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
## 창문은 windows 묶음(Windows)에 따로 둔다 — 네온 오락실은 창 없는 방이라 통째로 빼고(LoungeWorld.ARCADE_SKIP)
## 그 벽에 네온 간판을 단다(2026-10-31 늦은 밤: 오락실 간판 글자가 창문·과녁 판넬에 겹쳐 잘려 보였다).
static func _decor(p: Node3D, windows: Node3D, pub_only: Node3D) -> void:
	var f := _faces()
	# 다트 홀 옆창(특징 판넬을 피해 옆벽에).
	for side: float in [-1.0, 1.0]:
		var x: float = (f.hall_x1 if side > 0 else f.hall_x0) - side * 0.07
		PubParts.window(windows, Vector3(x, 2.5, -5.1), -PI / 2 * side)
	# 라운지 뒷벽 창 셋(넓어진 오른쪽에 하나 더)과 오른쪽 벽 창 하나.
	for x: float in [-2.4, 1.8, 11.2]:
		PubParts.window(windows, Vector3(x, 2.5, f.back_z - 0.07), PI)
	PubParts.window(windows, Vector3(f.lounge_x1 - 0.07, 2.5, 4.6), -PI / 2)
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
	# 바 뒤 구석 화분은 _furnish 의 PubOnly 로 옮겼다(오락실 경품 진열대 안에 들어가 보였다).
	# 오른쪽 앞 구석 화분은 안락의자 자리라 오른쪽 뒤 구석으로 옮겼다(2026-10-31 밤 도면 v3).
	# 오른쪽 뒤 구석 화분은 오락실에서 인형뽑기 코너 자리라 펍 전용(PubOnly)으로 둔다.
	PubParts.plant(pub_only, Vector3(f.lounge_x1 - 0.6, 0, f.back_z - 0.6))
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


## 도면 v3(2026-10-31 밤) 에셋 가구: 비어 보이던 곳을 RG Poly 모델로 채운다(docs/MAP_PLAN_2026-10-31.md).
## 자리·충돌은 TableView *_AT 상수와 decor_blocks(), 모양·방향·배율은 여기서 정한다.
## p(Furnishings)는 오락실 테마에서도 남는다. pub_only(PubOnly)는 오락실에서 빠진다(LoungeWorld.ARCADE_SKIP) —
## 오락실 기계·경품 진열대와 같은 자리에 겹치는 것(뒷벽 소파·바 뒤 통·조리대·바 뒤 화분)이다. 구운 모델이 없으면 그 자리는 비워 둔다.
## 이름이 붙은 노드(Keg·PracticeTarget·Gramophone)는 LoungeWorld 가 "건드리기"(F) 때 찾아 흔든다 — 이름을 바꾸면 거기도 고친다.
static func _furnish(p: Node3D, pub_only: Node3D) -> void:
	var f := _faces()
	# 바 뒤: 받침대에 누운 생맥주 통(꼭지가 방 쪽) · 뒤 조리대 + 커피 머신 · 병조림 · 구석 화분(오락실에서는 경품 진열대 자리).
	PubParts.asset(pub_only, "keg", TableView.KEG_AT, PI / 2, Vector3.ONE * 0.95, "Keg")
	PubParts.asset(pub_only, "back_counter", TableView.BACK_COUNTER_AT, PI / 2, Vector3.ONE, "BackCounter")
	PubParts.plant(pub_only, Vector3(f.lounge_x0 + 0.6, 0, f.back_z - 0.6))
	# 조리대 윗면 1.0m. 병 선반 판(벽에서 0.34m)과 겹치지 않게 방 쪽 절반에만 올린다.
	var counter_top: Vector3 = TableView.BACK_COUNTER_AT + Vector3(0.22, 1.0, 0)
	PubParts.asset(pub_only, "coffee_machine", counter_top + Vector3(0, 0, -0.32), PI / 2, Vector3.ONE * 0.8, "CoffeeMachine")
	PubParts.asset(pub_only, "honey_jar", counter_top + Vector3(0.02, 0, 0.22), 0.3, Vector3.ONE * 0.7)
	PubParts.asset(pub_only, "jar", counter_top + Vector3(0.08, 0, 0.48), 0.0, Vector3.ONE * 0.8)
	# 다트 홀: 연습 과녁(장식 — 점수 없음, 건드리면 흔들린다) · 양동이와 벽에 기댄 빗자루.
	# 과녁 면이 투척 구역 가운데(x 0, z -2) 쪽을 보게 돌린다(모델 과녁 면은 처음에 왼쪽 앞을 본다 — 렌더 투어로 맞춘 값).
	PubParts.asset(p, "practice_target", TableView.PRACTICE_TARGET_AT, 1.4, Vector3.ONE, "PracticeTarget")
	PubParts.asset(p, "bucket", TableView.BUCKET_AT, 0.7, Vector3.ONE, "Bucket")
	var broom := PubParts.asset(p, "broom", Vector3(f.hall_x1 - 0.2, 0, TableView.BUCKET_AT.z - 0.55), 0.0, Vector3.ONE, "Broom")
	if broom != null:
		broom.rotation.z = -0.1 # 위쪽이 벽(+X)에 기댄다
	# 다트 홀 옆벽 선반(구경꾼 잔 놓는 곳): 왼쪽·오른쪽 벽, 투척 구역 높이 1.75m.
	# 오락실에서는 이 벽에 오락기를 세우므로 펍 전용(PubOnly)이다(2026-10-31 늦은 밤).
	for side: float in [-1.0, 1.0]:
		var wall_x: float = f.hall_x1 - 0.26 if side > 0 else f.hall_x0 + 0.26
		var shelf := PubParts.asset(pub_only, "hang_shelf", Vector3(wall_x, 1.75, -1.5), 0.0 if side < 0 else PI, Vector3.ONE, "WallShelf", false)
		if shelf == null:
			continue
		var top: float = 1.75 + shelf.mesh.get_aabb().end.y
		PubParts.asset(pub_only, "mug", Vector3(wall_x + side * 0.05, top, -1.85), 1.0, Vector3.ONE * 0.55)
		PubParts.asset(pub_only, "goblet", Vector3(wall_x + side * 0.05, top, -1.45), 0.0, Vector3.ONE * 0.65)
		PubParts.asset(pub_only, "jar", Vector3(wall_x + side * 0.05, top, -1.05), 0.6, Vector3.ONE * 0.7)
	# 라운지 뒷벽: 구경 소파(카드 테이블 쪽을 본다). 창턱(1.55m)보다 등받이(1.49m)가 낮다. 오락실에서는 오락기 자리라 뺀다.
	PubParts.asset(pub_only, "sofa", TableView.SOFA_AT, PI / 2, Vector3.ONE, "Sofa")
	# 오른쪽 귀퉁이: 안락의자(창 쪽 벽을 등지고 방 안을 본다) + 낮은 탁자 위 축음기.
	PubParts.asset(p, "armchair", TableView.ARMCHAIR_AT, -PI / 2, Vector3.ONE, "Armchair")
	PubParts.asset(p, "side_table", TableView.SIDE_TABLE_AT, 0.0, Vector3(0.45, 0.5, 0.45), "SideTable")
	PubParts.asset(p, "gramophone", TableView.SIDE_TABLE_AT + Vector3(0, 0.4, 0), -2.3, Vector3.ONE * 0.75, "Gramophone")
	# 문 옆 짐: 나무 상자 둘을 엇갈려 쌓고 곡물 자루를 기대 둔다(배달 온 술·안주).
	PubParts.asset(p, "crate", TableView.CRATES_AT, 0.15, Vector3.ONE, "Crate")
	PubParts.asset(p, "crate", TableView.CRATES_AT + Vector3(0.03, 0.59, -0.02), 0.5, Vector3.ONE * 0.9, "CrateTop")
	PubParts.asset(p, "grain_bag", TableView.GRAIN_BAG_AT, 0.9, Vector3.ONE, "GrainBag")
	# 문 오른쪽 옷걸이 고리 셋(오락실에서는 인형뽑기 기계 자리라 펍 전용).
	for k in range(3):
		PubParts.asset(pub_only, "hook", Vector3(9.55 + k * 0.35, 1.75, f.back_z - 0.06), PI, Vector3.ONE, "CoatHook", false)
	# 천장 아래 전구 줄: 다트 홀 옆벽과 라운지 뒷벽을 따라(위쪽 빈 곳 채우기). 실제 빛은 펜던트가 낸다.
	# 높이는 천장 0.4m 아래(층고가 4.8m 로 높아져 고정값 3.85 대신 천장 기준).
	var string_y: float = TableView.CEILING_HEIGHT - 0.4
	for side: float in [-1.0, 1.0]:
		for z: float in [-6.3, -4.1, -1.9]:
			PubParts.asset(p, "string_lights", Vector3(side * (f.hall_x1 - 0.1), string_y, z), 0.0, Vector3.ONE, "StringLights", false)
	for x: float in [-6.7, -4.5, -2.3, 2.3, 4.5, 6.7]:
		PubParts.asset(p, "string_lights", Vector3(x, string_y, f.back_z - 0.1), PI / 2, Vector3.ONE, "StringLights", false)


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
	# 넓어진 라운지(뒤쪽 소파 · 입구 · 오른쪽 안락의자)도 어둡지 않게.
	for at: Vector3 in [Vector3(-3.1, 3.4, 7.4), Vector3(8.4, 3.4, 7.6), Vector3(12.4, 3.3, 1.6)]:
		PubParts.pendant(p, at, ceiling, 0.4, 5.0)
	# 벽등: 하우스 룰 간판(z 0.5~2.3)과 창(z 3.5~5.7)을 피해.
	for z: float in [2.9, 6.6]:
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
