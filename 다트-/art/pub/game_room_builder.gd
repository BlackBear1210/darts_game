extends "res://art/pub/room/room_kit.gd"
## F5 실제 경기 방(art/pub/pub_game.tscn)의 "보이는 것"을 만든다. pub_builder.gd 가 부른다(게임 실행 중에는 안 쓰인다).
##
## [방 모양 — 2026-10-28 도면]
## 위쪽 좁은 "다트 홀"(과녁·투척선·럼주통)과 아래쪽 넓은 "라운지"(바·플레이어 테이블·NPC 자리·당구대)가
## 이어진 ㄱ자 한 방이다. 두 칸은 TableView.DART_HALL / LOUNGE 이고 z=0 에서 만난다.
##
## [2026-11-08 "라운드하우스" 다시 짓기 — 사용자 지적 "맵의 지형지물과 벽·창문·테이블 다리 등 전부 이상하다"]
## 기준 = 바탕화면 DARTY_프로젝트/2026-11-07_DARTY_디자인요청_프롬프트.md 2장 + 디자인_2026-11-07/01_pub_concept.png.
##   - 바닥: 판자 상자 수백 개 → 이음매 없는 판 한 장 + 헤링본 오크 셰이더(art/pub/roundhouse_floor.gdshader).
##   - 벽: 크림 회벽 + 아래 청록 누빔 가죽 징두리 + 월넛 걸레받이·허리 난간 + 기둥 사이 "아치 틀" 칸 나누기
##         + 위쪽 코니스(숨은 빛 띠) + 벽과 천장을 곡면으로 잇는 코브. 천장 보는 없앴다(요청서 "갑작스러운 두꺼운 보 금지").
##   - 창: 둥근 머리 아치 창 + 커튼. 문: 둥근 머리 문틀 + 작은 아치 유리.
##   - 가구: 상자 다리 4개 테이블 → 물레로 깎은 받침 하나(트럼펫 모양) + 둥근 난간 테두리 + 원형 러그.
##           의자·바 스툴·NPC 테이블·당구대·전등도 모두 물레 깎기/단면 밀기(art/pub/round_kit.gd)로 둥글게.
##   - 사람: 바텐더·손님은 선수와 같은 리깅 캐릭터(art/pub/npc_idle.gd) — 의자에 실제로 앉는다.
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
##
## [이름 약속 — 바꾸면 다른 곳도 고쳐야 한다]
## 묶음 이름(Shell·Bar·Guests…)은 오락실 테마가 빼는 목록(lounge_world.ARCADE_SKIP)과 시험이 본다.
## SeatMat_N·SeatRug_N·SeatStool_N·SeatLabel_N = 방 인원수에 따라 TableView.show_seats 가 숨긴다.
## Bell·Keg·PracticeTarget·Gramophone = "건드리기"(LoungeWorld.touch_spots)가 이름으로 찾아 흔든다.
## Pendant* = 오락실이 이 이름의 펜던트를 모두 뺀다 — 카드 테이블 등(TablePendant…)만 남는다(lounge_world._trim_arcade).
##
## [2026-11-08 Codex 라운드하우스 모델(묶음 1 v2)]
## 소파·안락의자·낮은 탁자·축음기·커튼·화분 3종·옷걸이는 art/environments/roundhouse/pub/ 의 GLB 를 그대로 인스턴스한다(_model).
## 이름(Sofa·Armchair·SideTable·Gramophone·Plant·CurtainPair·CoatRack)은 GLB 인스턴스 루트에 붙는다.
##
## [2026-11-17 모듈로 나눔 — 사용자 요청 "틀이 잡힌 부분들을 모듈로 만들어서 간단하게 찾을 수 있게"]
## 이 파일은 이제 "조립표"다: build() 가 아래 모듈을 차례로 부르기만 한다. 모양을 고치려면 해당 모듈 파일을 연다.
##   art/pub/room/room_kit.gd        공용 상수·재질·벽 계획·손 부품(모든 모듈이 extends)
##   art/pub/room/room_shell.gd      바닥·천장·벽·창 구멍·바깥 벽돌            → Shell · WindowPlugs · Outside/PubExterior
##   art/pub/room/room_board.gd      과녁 벽·레인·럼주통                      → BoardWall · Lane · Barrels
##   art/pub/room/room_board_sides.gd 과녁 벽 양옆 꾸밈(네온·시계·트로피·깃발)   → PubOnly/BoardSideDecor
##   art/pub/room/room_seating.gd    카드 테이블·의자·자리 매트                 → TableAndSeats
##   art/pub/room/room_bar.gd        바·뒤 선반·냉장고                         → Bar
##   art/pub/room/room_guests.gd     NPC 자리·손님·당구대                       → NpcCorner · Guests · PoolTable
##   art/pub/room/room_decor.gd      창·그림·가구·인디 소품                     → Decor · Windows · Furnishings · PubOnly
##   art/pub/room/room_fitting.gd    꾸미기 방 상자                            → PubOnly/FittingRoom
##   art/pub/room/room_lights.gd     전등·방 환경                              → Lights
##   art/pub/street_outside.gd       창 밖 3D 거리·밤하늘                       → Outside
## 모듈 지도(무엇을 고치려면 어디를 여는가) = art/pub/room/README.md. 편집기에서는 pub_game.tscn 의 묶음 노드에
## 마우스를 올리면(노드 설명) 만든 파일이 보인다.

const RoomShell = preload("res://art/pub/room/room_shell.gd")
const RoomBoard = preload("res://art/pub/room/room_board.gd")
const RoomSeating = preload("res://art/pub/room/room_seating.gd")
const RoomBar = preload("res://art/pub/room/room_bar.gd")
const RoomGuests = preload("res://art/pub/room/room_guests.gd")
const RoomDecor = preload("res://art/pub/room/room_decor.gd")
const RoomLights = preload("res://art/pub/room/room_lights.gd")
const RoomBoardSides = preload("res://art/pub/room/room_board_sides.gd")

## 장면 묶음 노드 → 만든 곳 설명(편집기 장면 목록에서 노드에 마우스를 올리면 보이는 "노드 설명"·editor_description).
## 다른 작업자가 pub_game.tscn 을 열고 "이건 어디서 고치나?"를 바로 알 수 있게 한다. 묶음을 새로 만들면 여기에도 한 줄 더한다.
const GROUP_SOURCES: Dictionary = {
	"Shell": "바닥·천장·벽(징두리·난간·코니스·코브·기둥·아치 틀)·창 구멍 — art/pub/room/room_shell.gd build_shell",
	"BoardWall": "과녁 벽(청록 판넬·큰 아치·칠판 두 장) — art/pub/room/room_board.gd build_board_wall",
	"Lane": "레인 매트·투척선 — art/pub/room/room_board.gd build_lane",
	"Barrels": "럼주통·작은 통 — art/pub/room/room_board.gd build_barrels (충돌 = TableView.BARRELS)",
	"TableAndSeats": "카드 테이블·의자·자리 매트(SeatMat_N…) — art/pub/room/room_seating.gd build_table_and_seats",
	"Bar": "바·맥주 꼭지·뒤 선반·냉장고·바 스툴 — art/pub/room/room_bar.gd build_bar",
	"NpcCorner": "NPC 구석 자리 — art/pub/room/room_guests.gd build_npc_corner",
	"Guests": "앉은 손님 NPC — art/pub/room/room_guests.gd build_guests (몸짓 = art/pub/npc_idle.gd)",
	"PoolTable": "당구대 — art/pub/room/room_guests.gd build_pool_table",
	"PubOnly": "펍에만 있는 것(오락실 테마에서 빠진다) — art/pub/room/room_decor.gd · room_fitting.gd · room_board_sides.gd",
	"PubOnly/IndieDecor": "인디 펍 선반 소품 — art/pub/room/room_decor.gd _indie_decor",
	"PubOnly/FittingRoom": "꾸미기 방 상자 — art/pub/room/room_fitting.gd build_fitting_room (충돌 = TableView.FITTING_ROOM_BOX)",
	"PubOnly/BoardSideDecor": "과녁 벽 양옆 꾸밈(네온·다트 꽂이·시계·트로피·거울·깃발) — art/pub/room/room_board_sides.gd",
	"Decor": "문·간판·화분·벽 그림 — art/pub/room/room_decor.gd build_decor",
	"Windows": "창 틀·커튼·유리 — art/pub/room/room_decor.gd _window",
	"Furnishings": "가구 모델(소파·축음기·연습 과녁…) — art/pub/room/room_decor.gd build_furnish",
	"Lights": "펜던트·벽등·방 환경 — art/pub/room/room_lights.gd build_lighting",
	"WindowPlugs": "오락실 전용 창 막이 회벽(펍에서는 숨김) — art/pub/room/room_shell.gd build_window_plugs",
	"Outside": "창 밖 3D 거리·밤하늘 — art/pub/street_outside.gd (재질 = street_night.gdshader)",
	"Outside/PubExterior": "펍 건물 바깥 벽돌 껍데기 — art/pub/room/room_shell.gd build_exterior",
}


## 방 전체를 만든다. 반환한 노드를 pub_builder.gd 가 pub_game.tscn 으로 저장한다.
static func build() -> Node3D:
	var room := Node3D.new()
	room.name = "PubGame"
	room.set_meta("layout_signature", TableView.layout_signature())
	RoomShell.build_shell(_group(room, "Shell"))
	RoomBoard.build_board_wall(_group(room, "BoardWall"))
	RoomBoard.build_lane(_group(room, "Lane"))
	RoomBoard.build_barrels(_group(room, "Barrels"))
	RoomSeating.build_table_and_seats(_group(room, "TableAndSeats"))
	RoomBar.build_bar(_group(room, "Bar"))
	RoomGuests.build_npc_corner(_group(room, "NpcCorner"))
	RoomGuests.build_guests(_group(room, "Guests"))
	RoomGuests.build_pool_table(_group(room, "PoolTable"))
	var pub_only := _group(room, "PubOnly")
	RoomDecor.build_decor(_group(room, "Decor"), _group(room, "Windows"), pub_only)
	RoomDecor.build_furnish(_group(room, "Furnishings"), pub_only)
	# 2026-11-17: 과녁 벽 양옆 꾸밈(네온 과녁·다트 꽂이·벽시계·트로피·거울 간판·깃발 줄 — 펍 전용).
	RoomBoardSides.build_board_sides(_group(pub_only, "BoardSideDecor"))
	RoomLights.build_lighting(_group(room, "Lights"))
	# 2026-11-16: 창 구멍 메우개(오락실 전용 — 펍에서는 숨긴다) · 창 밖 3D 거리와 밤하늘.
	RoomShell.build_window_plugs(_group(room, "WindowPlugs"))
	var outside := _group(room, "Outside")
	StreetOutside.build(outside)
	RoomShell.build_exterior(_group(outside, "PubExterior"))
	for path: String in GROUP_SOURCES:
		var group := room.get_node_or_null(path)
		if group != null:
			group.editor_description = "만든 곳: %s\n생성물이다 — 직접 고치지 말고 생성기를 고친 뒤 다시 만든다(art/pub/room/README.md)." % GROUP_SOURCES[path]
	return room


## 천장 줄 자리: [[칸, [z...]], ...]. 2026-11-08 부터 펍에는 천장 보가 없다(코브로 바꿈).
## 네온 오락실(game/lounge/arcade/arcade_room.gd)이 이 자리에 천장 네온 관을 단다 — 홀 길이가 바뀌어도 같이 따라가게 여기 둔다.
## 다트 홀은 입구 쪽부터 2.6m 간격, 과녁 스포트라이트(BOARD_CENTER.z + 1.8)부터 과녁 벽까지는 비운다.
static func ceiling_beams() -> Array:
	var hall: Rect2 = TableView.DART_HALL
	var lounge: Rect2 = TableView.LOUNGE
	var spot_z: float = TableView.BOARD_CENTER.z + 1.8
	var hall_rows: Array[float] = []
	var z: float = hall.end.y - 1.9
	while z > spot_z + 1.2:
		hall_rows.append(z)
		z -= 2.6
	return [[hall, hall_rows],
		[lounge, [lounge.position.y + lounge.size.y * 0.22, lounge.get_center().y, lounge.position.y + lounge.size.y * 0.8]]]
