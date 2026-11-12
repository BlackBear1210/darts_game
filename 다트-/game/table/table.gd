class_name TableView
extends Node3D
## 공간의 배치와 환경 충돌만 소유한다. 캐릭터끼리는 충돌하지 않는다.
##
## [보이는 방은 따로 있다]
## 벽·바닥·바·소품·조명 같은 "보이는 것"은 자식 Pub(art/pub/pub_game.tscn, 디자인 담당 생성물)이 그린다.
## 이 스크립트는 같은 좌표에 "보이지 않는 충돌 상자"만 만든다.
## 아래 상수를 바꾸면 art/pub/pub_builder.gd 를 다시 돌려야 방 모양이 따라온다.
## 안 돌리면 게임 시작 때 경고가 뜨고 tests/test_game_look.gd 가 실패한다(layout_signature 비교).
##
## [방 모양 — 2026-10-28 도면]
## 위쪽 "다트 홀"(좁음)과 아래쪽 "라운지"(넓음)가 이어진 한 방이다. 두 사각형의 합집합이 바닥이다.
## 도면 비율은 그대로 두고 "너무 좁다"는 사용자 요청으로 방 전체를 1.5배로 넓혔다(가구 크기는 그대로).
## 도면의 좌우 단차 0.7m 차이는 z=0 한 줄로 정리했다.
## Rect2 는 바닥 평면이고 (x 최소, z 최소, 가로, 세로) 순서다. 벽은 이 테두리 위에 놓여 안쪽 면이 0.15m 안으로 들어온다.
## 2026-10-31 늦은 밤 사용자 요청 "펍 맵과 네온 오락실 맵의 크기를 더 늘리고 층고도 조금 높이자":
##   다트 홀 양옆 +0.6m(가로 12 → 13.2), 라운지 오른쪽 +1.5m · 뒤쪽 +1.5m(20.5×7.5 → 22×9), 층고 4.25 → 4.8m.
##   과녁·투척선·레인·카드 테이블·자리·바·NPC 자리·당구대(오락실 기계 자리)는 한 칸도 안 옮겼다 — 규칙·봇 길·오락실 규칙 좌표가 그대로다.
##   벽에 붙어 있던 것(럼주통·양동이·소파·안락의자·짐)만 벽을 따라 같이 옮겼다. 왼쪽 벽(바 뒤)과 과녁 벽은 그대로다.
## 2026-11-02 사용자 요청 "다트와 던지는 곳 거리를 두 배는 늘리자":
##   다트 홀을 과녁 쪽으로 3.6m 늘렸다(깊이 7.5 → 11.1). 투척선·레인 폭·라운지·테이블·자리·바는 한 칸도 안 옮겼다 —
##   사람이 서는 곳과 봇 길, 규칙(in_throw_zone)이 그대로다. 과녁 벽과 거기 붙은 것(큰 통 둘·작은 통 하나·연습 과녁)만 벽을 따라갔다.
## 2026-11-07 아수라장 다트 머신(디자인 요청서 5장 "벽에서 떨어진 독립 머신"):
##   과녁 벽 앞에 깊이 0.9m 머신이 서려면 자리가 없어 다트 홀을 과녁 뒤쪽으로 1.4m 늘렸다(깊이 11.1 → 12.5).
##   과녁 중심·투척선·레인·자리·라운지는 그대로 — 투척 거리 7.2m 와 규칙 좌표가 바뀌지 않는다.
##   과녁 벽에 붙어 있던 것(큰 통 둘·작은 통 하나·연습 과녁)만 벽을 따라 1.4m 물렸다.
const DART_HALL := Rect2(-6.6, -12.5, 13.2, 12.5)
const LOUNGE := Rect2(-8.4, 0.0, 22.0, 9.0)

## 과녁은 다트 홀 끝 벽 가운데에 건다. 높이·크기는 바꾸지 않았다(팀 확정 대기).
const BOARD_CENTER := Vector3(0, 2.9, -10.8)
const BOARD_SCALE: float = 2.5
## 투척선 위치(z)와 그 앞 보호 레인의 경계. 투척선에서 과녁 면까지 7.2m다
## (2026-11-02 "두 배는 늘리자" — 3.6m 의 두 배. 투척선을 두는 대신 다트 홀을 그만큼 늘려 과녁 벽을 물렸다:
##  투척선을 라운지 쪽으로 밀면 던지는 칸이 사라지고 카드 라운드 시연의 방해 구역과 겹친다).
## 제거된 펜스의 옛 기준선. 매트 끝 배치와 과거 검사 좌표 호환에만 사용한다.
const NO_ENTRY_Z: float = -3.7
const THROW_LINE_Z: float = -3.6
## 바닥 매트의 반폭. 이동을 제한하지 않는다.
const LANE_HALF: float = 1.2
## 봇이 서서 몸으로 막기 좋은 선호 구간. 펜스 제거 후 실제 몸 판정은 투척선 앞 다트 홀 전체다.
## 기존 다트 궤적을 기준으로 골랐으며 더 앞에서는 머리 위를 지나가므로 점프가 필요하다.
const BLOCK_ZONE := Vector2(-5.2, -4.5)
## 벽 안쪽 면에서 몸 중심이 더 들어오지 못하는 거리(벽 두께 절반 + 몸 반지름).
const BODY_MARGIN: float = 0.45

## 방 크기: 벽 두께와 천장 아랫면 높이(m).
const WALL_THICKNESS: float = 0.3
const CEILING_HEIGHT: float = 4.8

## 카드 테이블(도면 "플레이어 테이블")과 자리 4개. 자리 순서는 왼쪽·안쪽·오른쪽·바깥쪽이다.
const TABLE_CENTER := Vector3(0, 0, 4.4)
const TABLE_SIZE := Vector2(2.15, 1.55)
const TABLE_HEIGHT: float = 0.85
## 4인 자리(F6 카드 라운드 시연과 방 생성기가 쓰는 기본 배치). F5 경기는 인원수에 맞춘 seat_spot() 을 쓴다.
## 2026-11-08: 원형 테이블이라 모든 자리를 가운데에서 같은 거리(SEAT_RADIUS)에 둔다
## (예전 왼쪽·오른쪽 1.5m · 안쪽 1.25m · 바깥쪽 1.2m 는 네모 테이블 시절 값이었다).
const SEAT_RADIUS: float = 1.4
const SEATS: Array[Vector3] = [Vector3(-1.4, 0, 4.4), Vector3(0, 0, 5.8), Vector3(1.4, 0, 4.4), Vector3(0, 0, 3.0)]
## 인원수별 첫 자리 방향(도). 자리 방향 = atan2(x, z)(테이블 가운데 기준 — 0 = 안쪽 +Z, 90 = 오른쪽 +X, −90 = 왼쪽, 180 = 다트 홀 쪽).
## 깔린 자리를 번호 순서로 360/인원 도씩 돌려 놓는다 → 2인 = 왼쪽·오른쪽 마주 보기, 3인 = 안쪽 하나 + 다트 홀 쪽 양옆(120도씩),
## 4인 = 왼쪽·안쪽·오른쪽·바깥쪽(SEATS 와 같다).
const SEAT_START_YAW := {1: -90.0, 2: -90.0, 3: -120.0, 4: -90.0}
const SEAT_DISTANCE: float = 1.0
const RAISED_HEIGHT: float = 1.6

## 도면의 럼주통. 큰 통 4개는 다트 홀 네 귀퉁이(둘은 투척 구역 안), 작은 통은 그 곁이다.
## 2026-10-31 늦은 밤: 다트 홀이 양옆으로 0.6m 넓어져 벽과의 거리를 유지하려고 통도 0.6m 바깥으로 옮겼다.
## 2026-11-02: 과녁 벽이 3.6m 물러났으므로 그 벽 쪽 두 개도 같이 물렸다(투척선 쪽 두 개는 그대로).
## 2026-11-07: 과녁 벽이 1.4m 물러나 벽 쪽 두 개를 또 같이 물렸다(-10.4 → -11.8, -10.8 → -12.2).
const BARRELS: Array[Vector3] = [Vector3(-5.7, 0, -11.8), Vector3(5.6, 0, -12.2),
	Vector3(-5.7, 0, -3.1), Vector3(5.6, 0, -3.15)]
const BARREL_RADIUS: float = 0.4
const BARREL_HEIGHT: float = 0.9
const SMALL_BARRELS: Array[Vector3] = [Vector3(6.0, 0, -11.15), Vector3(-6.15, 0, -2.4),
	Vector3(5.1, 0, -2.5), Vector3(6.0, 0, -2.3)]
const SMALL_BARREL_RADIUS: float = 0.2
const SMALL_BARREL_HEIGHT: float = 0.5

## 라운지 가구: 왼쪽 벽 바 카운터, NPC 자리 테이블과 스툴 2개, 오른쪽 당구대.
const BAR_BOX := AABB(Vector3(-5.85, 0, 0.0), Vector3(0.95, 1.2, 7.4))
const NPC_TABLE_BOX := AABB(Vector3(4.95, 0, 3.3), Vector3(1.65, 0.85, 1.5))
## 2026-11-08: 둘째 의자를 z 6.3 → 5.5 로(테이블 가운데에서 첫째 의자와 같은 거리 — 예전엔 테이블에서 1.5m 떨어져 앉아 앞 접시가 멀었다).
const NPC_STOOLS: Array[Vector3] = [Vector3(5.8, 0, 2.6), Vector3(5.8, 0, 5.5)]
const STOOL_RADIUS: float = 0.3
const STOOL_HEIGHT: float = 0.6
const POOL_TABLE_BOX := AABB(Vector3(10.4, 0, 2.8), Vector3(1.5, 0.8, 2.55))

## [도면 v3 — 2026-10-31 밤 에셋 가구] 다른 작업자가 보낸 RG Poly 모델(art/vendor/rg_poly)로 빈 곳을 채웠다.
## 놓는 자리(바닥 가운데)만 여기 두고, 모양·방향은 art/pub/game_room_builder.gd _furnish 가 정한다.
## 플레이어가 지나는 길(자리 ↔ 투척선 가운데 복도, x -2~2)은 비워 둔다 — 봇도 그 길로 다닌다.
##   바 뒤: 받침대 위 생맥주 통(KEG) · 뒤 조리대(BACK_COUNTER, 커피 머신)
##   다트 홀: 연습 과녁(장식, 점수 없음) · 빗자루와 양동이
##   라운지: 뒷벽 구경 소파 · 오른쪽 귀퉁이 안락의자 + 축음기 탁자 · 문 옆 짐(나무 상자·곡물 자루)
const KEG_AT := Vector3(-7.5, 0, 0.95)
const BACK_COUNTER_AT := Vector3(-7.8, 0, 6.3)
const PRACTICE_TARGET_AT := Vector3(-3.4, 0, -11.6) # 2026-11-07 과녁 벽을 따라 1.4m 뒤로
const BUCKET_AT := Vector3(5.9, 0, -5.0)
const SOFA_AT := Vector3(-3.1, 0, 8.35)
const ARMCHAIR_AT := Vector3(12.75, 0, 1.0)
const SIDE_TABLE_AT := Vector3(12.85, 0, 2.05)
const CRATES_AT := Vector3(6.95, 0, 8.35)
const GRAIN_BAG_AT := Vector3(6.35, 0, 8.5)
## 바 끝 냉장고(2026-10-31 늦은 밤): 라운지가 뒤로 1.5m 길어지며 바 끝(z 7.4)과 뒷벽 사이가 열렸다.
## 그 틈으로 바 뒤에 들어가지 못하게 음료 냉장고로 막는다(펍 = 유리문 음료 냉장고, 오락실 = 주스 자판기). 문은 방 쪽(+X).
const BAR_FRIDGE_AT := Vector3(-5.375, 0, 8.12)
const BAR_FRIDGE_SIZE := Vector3(0.95, 1.95, 1.44)
## 주크박스(라운지 오른쪽 앞벽). 그림은 LoungeWorld._build_jukebox 가 이 자리에 그린다(LoungeWorld.JUKEBOX = 이 값).
## 2026-11-08 사용자 지적 "펍 느낌의 주크박스가 왜 플레이어가 통과되는 거야?": 그림만 있고 충돌 상자가 없었다 →
## decor_blocks() 에 넣어 사람이 막힌다. 크기 = 받침(폭 1.42) × 아치 꼭대기(2.08m) × 몸통 깊이. 앞 버튼(z +0.42)은 상자 밖에 둬 누를 수 있다.
const JUKEBOX_AT := Vector3(8.6, 0, 0.5)
const JUKEBOX_SIZE := Vector3(1.42, 2.1, 0.62)
## 펍 뒤쪽 빈자리에 더한 둥근 비스트로 테이블 2개(2026-11-08 사용자 "펍에 테이블이 2개 더 설치할까? 너무 공간이 비어 보여").
## 자리마다 손님 둘이 마주 앉아(의자는 ±BISTRO_CHAIR_OFFSET x) 랜덤 음식을 먹는다. 카드 테이블 안쪽 자리(z 5.8)·소파(x −4.4~−1.8)·
## 짐(x 6.6~)·문(x 8.4) 사이 뒤쪽 띠(z 7.2~7.9)라 선수 동선(자리 ↔ 투척선)과 겹치지 않는다.
## 충돌은 펍에서만 켠다(pub_only_blocks — 오락실은 그 자리가 오락기 앞이라 LoungeWorld 가 테마를 바꿀 때 끈다).
const BISTRO_TABLES: Array[Vector3] = [Vector3(2.0, 0, 7.55), Vector3(4.6, 0, 7.55)]
const BISTRO_TABLE_RADIUS: float = 0.42
const BISTRO_TABLE_HEIGHT: float = 0.8
const BISTRO_CHAIR_OFFSET: float = 0.74
## 바 스툴 3개 자리 z(2026-11-08): 바 위 집는 맥주잔(z 1.4·1.9·6.2·6.7)·병(3.1~5.02) 줄 사이 빈 곳 앞에 둔다 —
## 앉은 손님 앞에 바텐더가 잔·접시를 놓을 자리가 있어야 한다(art/pub/pub_service.gd). 예전 = 바 길이 3등분(1.3·3.7·6.1).
const BAR_STOOLS_Z: Array[float] = [0.95, 2.5, 5.6]
## 바 위 물건 자리(바 윗면 높이 1.1m). 맥주잔 = 집어 마시고 던지는 소품(LoungeWorld), 컵받침은 그 아래에 그려 둔다.
const BAR_TOP_Y: float = 1.1
const BAR_MUGS: Array[Vector3] = [Vector3(-5.2, 1.1, 1.4), Vector3(-5.2, 1.1, 1.9), Vector3(-5.2, 1.1, 6.2), Vector3(-5.2, 1.1, 6.7)]
const BAR_BOTTLES_Z: Array[float] = [3.1, 3.58, 4.06, 4.54, 5.02]


## 장식 가구의 충돌 상자(바닥 기준). 크기는 측정표(docs/MAP_PLAN_2026-10-31.md)의 모델 크기에 맞췄다.
static func decor_blocks() -> Array[AABB]:
	var blocks: Array[AABB] = []
	for spec: Array in [[KEG_AT, Vector3(1.0, 1.05, 1.2)], [BACK_COUNTER_AT, Vector3(0.9, 1.0, 1.26)],
			[PRACTICE_TARGET_AT, Vector3(0.62, 1.35, 0.6)], [BUCKET_AT, Vector3(0.45, 0.4, 0.45)],
			[SOFA_AT, Vector3(2.6, 0.9, 0.95)], [ARMCHAIR_AT, Vector3(1.16, 0.9, 0.95)],
			[SIDE_TABLE_AT, Vector3(0.56, 0.4, 0.56)], [CRATES_AT, Vector3(0.75, 1.2, 0.75)], [GRAIN_BAG_AT, Vector3(0.56, 0.62, 0.56)],
			[BAR_FRIDGE_AT, BAR_FRIDGE_SIZE], [JUKEBOX_AT, JUKEBOX_SIZE]]:
		var at: Vector3 = spec[0]
		var size: Vector3 = spec[1]
		blocks.append(AABB(at - Vector3(size.x / 2.0, 0, size.z / 2.0), size))
	return blocks

## 펍에서만 막는 가구(비스트로 테이블 + 의자). 오락실에서는 그 자리에 오락기 앞 통로가 있어 끈다(rebuild_pub).
static func pub_only_blocks() -> Array[AABB]:
	var blocks: Array[AABB] = []
	for at: Vector3 in BISTRO_TABLES:
		var r: float = BISTRO_TABLE_RADIUS
		blocks.append(AABB(at - Vector3(r, 0, r), Vector3(r * 2.0, BISTRO_TABLE_HEIGHT, r * 2.0)))
		for side: float in [-1.0, 1.0]:
			var chair: Vector3 = at + Vector3(side * BISTRO_CHAIR_OFFSET, 0, 0)
			blocks.append(AABB(chair - Vector3(0.27, 0, 0.27), Vector3(0.54, 0.9, 0.54)))
	return blocks

## 정적 메시 묶기(그리기 호출 줄이기). class_name 이 없는 도구라 preload 로 부른다.
const StaticBatch = preload("res://art/static_batch.gd")
## 아수라장 다트 머신 몸체(셔터·테두리 조명·상태 화면). 과녁 그림(BoardView)은 그대로 $Board 가 그린다.
## class_name 을 새로 만들지 않고 preload 로 부른다(열린 편집기가 새 class_name 을 못 읽어 파스 오류가 나는 함정).
const DartMachine = preload("res://art/dart_machine/dart_machine.gd")
## 머신 충돌 상자의 폭·높이(m). 그림 치수(어깨 포함 폭 약 2.7m, 아치 꼭대기 4.2m)에 맞췄다.
## 앞면은 과녁 면보다 0.12m 뒤라서 다트 판정(과녁 평면 통과)을 가로막지 않는다 — 판 밖으로 빗나간 다트만 몸체에 박힌다.
## 뒤는 과녁 벽까지 막는다(머신 뒤 틈으로 들어가 끼이지 않게).
const MACHINE_WIDTH: float = 2.7
const MACHINE_HEIGHT: float = 4.2
const MACHINE_FACE_GAP: float = 0.12

@onready var board: BoardView = $Board
var is_ready: bool = true
## 다트 머신 그림(_ready 에서 만든다). 테마가 바뀌면 set_machine_skin 으로 다시 칠한다.
var machine: DartMachine
## 지금 깔아 둔 자리 번호(0~3). 방 인원수에 맞춰 GameView.sync_room 이 정한다(기본 = 4자리 전부).
## 방 그림을 다시 만들면(_prepare_pub) 이 값으로 다시 숨긴다.
var _shown_seats: Array[int] = [0, 1, 2, 3]


## 방 배치 상수를 한 줄 글자로 만든다. 생성기가 방(pub_game.tscn)에 저장하고, 실행 때 같은지 비교한다.
static func layout_signature() -> String:
	# "dart_machine_v1"(2026-11-07): 과녁 벽 캐비닛을 독립 머신으로 바꾼 방 — 이 글자가 다르면 방을 다시 만들라고 경고한다.
	return var_to_str(["round_table_v1", "dart_machine_v1", BOARD_CENTER, BOARD_SCALE, SEATS, DART_HALL, LOUNGE, WALL_THICKNESS, CEILING_HEIGHT,
		NO_ENTRY_Z, THROW_LINE_Z, LANE_HALF, BLOCK_ZONE, TABLE_CENTER, TABLE_SIZE, TABLE_HEIGHT,
		BARRELS, BARREL_RADIUS, SMALL_BARRELS, SMALL_BARREL_RADIUS,
		BAR_BOX, NPC_TABLE_BOX, NPC_STOOLS, POOL_TABLE_BOX,
		# 도면 v3(2026-10-31 밤): 에셋 가구 자리·바 위 물건 자리
		KEG_AT, BACK_COUNTER_AT, PRACTICE_TARGET_AT, BUCKET_AT, SOFA_AT, ARMCHAIR_AT, SIDE_TABLE_AT, CRATES_AT, GRAIN_BAG_AT,
		BAR_TOP_Y, BAR_MUGS, BAR_BOTTLES_Z,
		# 방 넓히기 v4(2026-10-31 늦은 밤): 바 끝 냉장고
		BAR_FRIDGE_AT, BAR_FRIDGE_SIZE,
		# 2026-11-08: 비스트로 테이블 2개 · 바 스툴 자리
		BISTRO_TABLES, BISTRO_TABLE_RADIUS, BISTRO_TABLE_HEIGHT, BISTRO_CHAIR_OFFSET, BAR_STOOLS_Z])


## 사람이 설 수 있는 바닥 두 칸(벽 안쪽에서 몸 반지름만큼 뺀 것).
## 중앙 펜스와 투명 제한벽이 없어 두 칸 전체를 자유롭게 걸을 수 있다.
## 다트 홀 칸은 라운지까지 이어지므로 z 끝을 라운지와 같이 둔다 — 둘의 합집합이 ㄱ자다.
static func walkable_halls() -> Array[Rect2]:
	var front: float = DART_HALL.position.y + BODY_MARGIN
	var hall := Rect2(DART_HALL.position.x + BODY_MARGIN, front,
		DART_HALL.size.x - BODY_MARGIN * 2, LOUNGE.end.y - BODY_MARGIN - front)
	var lounge := LOUNGE.grow(-BODY_MARGIN)
	return [hall, lounge]


## 몸으로 막고 설 자리(레인 한가운데 = 다트가 지나는 x, 구역에서 던지는 사람과 가장 가까운 쪽).
## 구역 안에서도 앞쪽 끝은 다트가 더 높이 지나가므로 서서 막으려면 뒤쪽 끝에 서야 한다.
static func block_spot() -> Vector3:
	return Vector3(0, 0, BLOCK_ZONE.y - 0.2)


## 투척선 앞 다트 홀 어디서든 몸으로 막을 수 있다. 투척자 뒤 대기 인원은 제외한다.
static func in_block_zone(point: Vector3) -> bool:
	return DART_HALL.has_point(Vector2(point.x, point.z)) and point.z < THROW_LINE_Z


## 여기서만 던질 수 있다. 라운지(테이블·바)에서는 못 던진다.
## 레인 양옆이 뚫려 있어 투척선을 지나 과녁 옆까지 갈 수 있으므로 "투척선 뒤"도 함께 본다.
static func in_throw_zone(point: Vector3) -> bool:
	return DART_HALL.has_point(Vector2(point.x, point.z)) and point.z >= THROW_LINE_Z


## 깔린 자리들(자리 번호)을 원형 테이블 둘레에 똑같은 간격으로 놓은 위치: 자리 번호 → 바닥 위치(의자 가운데).
## 2026-11-08 사용자 요청 "4명에서 3명으로 줄면 원형 테이블을 정확하게 3등분해 그곳에 앉게":
## 자리 번호(= 색·모양)는 그대로 두고 위치만 인원수에 맞춰 다시 나눈다. 번호 순서대로 시계 방향이다.
static func seat_layout(shown: Array[int]) -> Dictionary:
	var seats: Array[int] = shown.duplicate()
	seats.sort()
	var result: Dictionary = {}
	if seats.is_empty():
		return result
	var start: float = float(SEAT_START_YAW.get(clampi(seats.size(), 1, SEATS.size()), -90.0))
	for rank in range(seats.size()):
		var yaw: float = deg_to_rad(start + 360.0 * rank / seats.size())
		# 1μm 로 반올림한다: 4.4+1.4 같은 계산 찌꺼기(float 끝자리)가 남으면 4인 자리가 SEATS 상수와 정확히 같지 않다.
		result[seats[rank]] = Vector3(snappedf(TABLE_CENTER.x + sin(yaw) * SEAT_RADIUS, 0.000001), 0.0,
			snappedf(TABLE_CENTER.z + cos(yaw) * SEAT_RADIUS, 0.000001))
	return result


## 지금 경기에 깔린 자리 위치(자리 번호 → 위치). GameView.sync_room 이 방 인원수로 정한다(arrange_seats).
## 경기 규칙(앉기 거리·봇이 걸어갈 곳·일어설 곳)과 그림(카드 매트·엿보기)이 모두 이 값을 본다.
static var _seat_spots: Dictionary = {}


## 경기 자리 배치를 바꾼다. shown = RoomState.shown_seats(). 방장·손님 모두 같은 방 상태로 부르므로 같은 결과다.
static func arrange_seats(shown: Array[int]) -> void:
	_seat_spots = seat_layout(shown)


## 자리 seat 의 바닥 위치(의자 가운데). 지금 배치에 없는 번호면 4인 배치 자리.
static func seat_spot(seat: int) -> Vector3:
	if _seat_spots.has(seat):
		return _seat_spots[seat]
	return SEATS[clampi(seat, 0, SEATS.size() - 1)]


## 자리에서 테이블 가운데를 등지는 방향(rotation.y) — 이 각도로 돌리면 로컬 +Z 가 자리 바깥쪽을 본다(방 생성기와 같다).
static func seat_yaw(at: Vector3) -> float:
	return atan2(at.x - TABLE_CENTER.x, at.z - TABLE_CENTER.z)


## 각 자리에서 테이블 바깥쪽으로 일어선다. 고정 +Z는 4번 자리를 상판 안에 넣는다.
static func standing_spot(seat: int) -> Vector3:
	var origin: Vector3 = seat_spot(seat)
	var outward: Vector3 = (origin - TABLE_CENTER).normalized()
	return clamp_floor(origin + outward * 0.8 + Vector3.UP * 0.05)


## 몸이 방 밖으로 새지 않게 하는 마지막 안전망. 가까운 칸 안으로 당긴다(벽 충돌이 먼저 막는다).
static func clamp_floor(point: Vector3) -> Vector3:
	var best := point
	var best_distance: float = INF
	for hall: Rect2 in walkable_halls():
		var inside := Vector3(clampf(point.x, hall.position.x, hall.end.x), point.y,
			clampf(point.z, hall.position.y, hall.end.y))
		var distance: float = point.distance_squared_to(inside)
		if distance < best_distance:
			best_distance = distance
			best = inside
	return best


func _ready() -> void:
	board.position = BOARD_CENTER
	board.scale = Vector3.ONE * BOARD_SCALE
	var half_wall := WALL_THICKNESS / 2.0
	var wall_height := CEILING_HEIGHT + 0.25
	var wall_y := CEILING_HEIGHT - wall_height / 2.0
	# 바닥·천장(보이지 않는 충돌. 그림은 Pub). 두 칸을 각각 덮는다.
	for room: Rect2 in [DART_HALL, LOUNGE]:
		_slab(room, -half_wall)
		_slab(room, CEILING_HEIGHT + half_wall)
	# 벽 8면: 도면 ㄱ자 둘레를 따라간다.
	_wall_z(DART_HALL.position.y, DART_HALL.position.x, DART_HALL.end.x, wall_y, wall_height)
	_wall_x(DART_HALL.position.x, DART_HALL.position.y, DART_HALL.end.y, wall_y, wall_height)
	_wall_x(DART_HALL.end.x, DART_HALL.position.y, DART_HALL.end.y, wall_y, wall_height)
	_wall_z(LOUNGE.position.y, LOUNGE.position.x, DART_HALL.position.x, wall_y, wall_height)
	_wall_z(LOUNGE.position.y, DART_HALL.end.x, LOUNGE.end.x, wall_y, wall_height)
	_wall_x(LOUNGE.position.x, LOUNGE.position.y, LOUNGE.end.y, wall_y, wall_height)
	_wall_x(LOUNGE.end.x, LOUNGE.position.y, LOUNGE.end.y, wall_y, wall_height)
	_wall_z(LOUNGE.end.y, LOUNGE.position.x, LOUNGE.end.x, wall_y, wall_height)
	# 중앙 펜스와 레이어 4 진입 제한벽을 제거하여 과녁 앞을 자유롭게 걷는다.
	# 사람이 부딪히는 가구.
	_cylinder(TABLE_CENTER, TABLE_SIZE.x / 2.0, TABLE_HEIGHT)
	_box(BAR_BOX.get_center(), BAR_BOX.size)
	_box(NPC_TABLE_BOX.get_center(), NPC_TABLE_BOX.size)
	_box(POOL_TABLE_BOX.get_center(), POOL_TABLE_BOX.size)
	for barrel in BARRELS:
		_cylinder(barrel, BARREL_RADIUS, BARREL_HEIGHT)
	for barrel in SMALL_BARRELS:
		_cylinder(barrel, SMALL_BARREL_RADIUS, SMALL_BARREL_HEIGHT)
	for stool in NPC_STOOLS:
		_cylinder(stool, STOOL_RADIUS, STOOL_HEIGHT)
	# 도면 v3 장식 가구(소파·안락의자·짐·연습 과녁 등). 오락실 테마에서도 같은 자리에 남는다.
	for block in decor_blocks():
		_box(block.get_center(), block.size)
	# 펍 전용 가구(비스트로 테이블). 테마가 바뀌면 rebuild_pub 가 켜고 끈다.
	for block in pub_only_blocks():
		_box(block.get_center(), block.size)
		get_child(get_child_count() - 1).set_meta("pub_only", true)
	# 다트 머신 충돌: 과녁 면 0.12m 뒤부터 과녁 벽까지(사람·다트 레이어 1).
	var machine_front: float = BOARD_CENTER.z - MACHINE_FACE_GAP
	var machine_depth: float = machine_front - DART_HALL.position.y
	_box(Vector3(BOARD_CENTER.x, MACHINE_HEIGHT / 2.0, machine_front - machine_depth / 2.0), Vector3(MACHINE_WIDTH, MACHINE_HEIGHT, machine_depth))
	# 다트 머신 그림: 원점 = 과녁 바로 아래 바닥. 기본은 펍 스킨이고 오락실 테마면 LoungeWorld 가 바꾼다.
	machine = DartMachine.new()
	machine.name = "DartMachine"
	machine.position = Vector3(BOARD_CENTER.x, 0, BOARD_CENTER.z)
	add_child(machine)
	machine.build(false)
	_prepare_pub()


## 다트 머신 스킨(false = 펍 월넛, true = 오락실 크림·시안/마젠타). 같은 스킨이면 다시 만들지 않는다.
func set_machine_skin(arcade: bool) -> void:
	if machine != null and machine.arcade != arcade:
		machine.build(arcade)


## 칠판 점수판(과녁 왼쪽 문)의 글자를 바꾼다. 방이 없으면(생성 전) 아무것도 안 한다.
func set_chalk_scores(text: String) -> void:
	var pub := get_node_or_null("Pub")
	if pub == null:
		return
	var label := pub.find_child("ChalkScores", true, false) as Label3D
	if label != null:
		label.text = text


## 방 그림(Pub)을 새로 만든다. skip 에 든 묶음(예: "Bar")은 빼고 만든다.
## 네온 오락실 테마가 같은 자리(같은 충돌 상자)에 기계를 세울 때 쓴다(game/lounge/lounge_world.gd).
## 실행 중 메시 묶기(StaticBatch)가 끝난 뒤에는 묶음 하나만 숨길 수 없어서 통째로 다시 만든다.
## trim 을 주면 묶기 전에 새 그림을 한 번 더 손볼 수 있다(예: 기계 위에 걸리는 펜던트 조명 빼기).
func rebuild_pub(skip: Array[String], trim: Callable = Callable()) -> void:
	var old := get_node_or_null("Pub")
	var order: int = old.get_index() if old != null else 0
	if old != null:
		remove_child(old)
		old.queue_free()
	var pub := (load("res://art/pub/pub_game.tscn") as PackedScene).instantiate() as Node3D
	for group_name in skip:
		var group := pub.get_node_or_null(group_name)
		if group != null:
			pub.remove_child(group)
			group.free()
	pub.name = "Pub"
	# 펍 전용 충돌(비스트로 테이블)은 그 그림이 빠지는 테마(오락실)에서 끈다.
	for child in get_children():
		if child is StaticBody3D and child.has_meta("pub_only"):
			(child as StaticBody3D).collision_layer = 0 if skip.has("BistroTables") else 1
	if trim.is_valid(): trim.call(pub)
	add_child(pub)
	move_child(pub, order)
	_prepare_pub()


## 방 인원수만큼만 자리(테이블 위 매트·바닥 자리 표시·스툴·자리 글자)를 보인다(2026-11-07 사용자 요청).
## seats = 보일 자리 번호(0~3, RoomState.shown_seats). 빈자리 매트에는 카드가 깔리지 않는다(seat_cards.gd 는 앉은 사람만).
## 충돌은 건드리지 않는다 — 자리에는 원래 충돌 상자가 없고(테이블 원기둥만), 숨긴 자리는 그냥 지나다닐 수 있는 바닥이 된다.
func show_seats(seats: Array[int]) -> void:
	if seats == _shown_seats:
		return
	_shown_seats = seats.duplicate()
	var pub := get_node_or_null("Pub")
	if pub != null:
		_apply_seats(pub)


## 자리 노드 이름은 1부터 센다(SeatMat_1 … — art/pub/game_room_builder.gd _table_and_seats).
## 2026-11-08: 보이는 자리는 인원수만큼 똑같이 나눈 자리(seat_layout)로 옮긴다. 방 생성기는 4인 자리(SEATS)에 만들어 두므로
## 그 자리에서 테이블 가운데를 축으로 (새 방향 − 만든 방향)만큼 돌린다 → 의자·깔개·글자·매트가 함께 돈다.
## 자리 노드는 정적 묶기에서 빠져 있어(StaticBatch "Seat") 실행 중에 옮길 수 있다.
func _apply_seats(pub: Node) -> void:
	var layout: Dictionary = seat_layout(_shown_seats)
	for seat in range(SEATS.size()):
		var shown: bool = _shown_seats.has(seat)
		var turn: float = 0.0
		if shown:
			turn = seat_yaw(layout[seat]) - seat_yaw(SEATS[seat])
		for part: String in ["SeatMat_%d", "SeatRug_%d", "SeatStool_%d", "SeatLabel_%d"]:
			var node := pub.find_child(part % (seat + 1), true, false) as Node3D
			if node == null:
				continue
			node.visible = shown
			if not node.has_meta("built_transform"):
				node.set_meta("built_transform", node.transform)
			var built: Transform3D = node.get_meta("built_transform")
			# 테이블 가운데를 이 노드 부모 좌표로 옮겨 그 둘레로 돌린다(매트는 테이블 노드 아래라 부모 원점이 곧 가운데다).
			var pivot: Vector3 = _table_space(node.get_parent()).affine_inverse() * TABLE_CENTER
			var spin := Basis(Vector3.UP, turn)
			node.transform = Transform3D(spin, pivot - spin * pivot) * built


## node 좌표 → 이 TableView 좌표 변환(트리 밖에서도 부모를 따라 곱한다).
func _table_space(node: Node) -> Transform3D:
	var result := Transform3D.IDENTITY
	while node != null and node != self:
		if node is Node3D:
			result = (node as Node3D).transform * result
		node = node.get_parent()
	return result


## 방 그림이 지금 규칙 좌표로 만들어졌는지 확인하고, 화면이 있을 때만 메시를 묶는다.
func _prepare_pub() -> void:
	var pub := get_node_or_null("Pub") as Node3D
	if pub == null:
		push_warning("art/pub/pub_game.tscn 이 없습니다. art/pub/pub_builder.gd 를 실행하세요.")
		return
	if str(pub.get_meta("layout_signature", "")) != layout_signature():
		push_warning("방 그림(pub_game.tscn)이 TableView 상수와 다릅니다. art/pub/pub_builder.gd 를 다시 실행하세요.")
	_apply_seats(pub)
	# 화면 없는 시험(--headless)에서는 그리지 않으므로 묶는 시간만 아낀다.
	if DisplayServer.get_name() != "headless":
		StaticBatch.optimize(pub)


## 방 한 칸을 덮는 판(바닥·천장). 가장자리는 벽 두께만큼 넉넉히 덮는다.
func _slab(room: Rect2, y: float) -> void:
	_box(Vector3(room.get_center().x, y, room.get_center().y),
		Vector3(room.size.x + WALL_THICKNESS, WALL_THICKNESS, room.size.y + WALL_THICKNESS))


## x 에 세운 벽(z 구간). 벽 상자는 테두리 위에 놓이고 안쪽 면이 WALL_THICKNESS/2 안으로 들어온다.
func _wall_x(x: float, z_from: float, z_to: float, wall_y: float, wall_height: float) -> void:
	_box(Vector3(x, wall_y, (z_from + z_to) / 2.0),
		Vector3(WALL_THICKNESS, wall_height, absf(z_to - z_from) + WALL_THICKNESS))


## z 에 세운 벽(x 구간).
func _wall_z(z: float, x_from: float, x_to: float, wall_y: float, wall_height: float) -> void:
	_box(Vector3((x_from + x_to) / 2.0, wall_y, z),
		Vector3(absf(x_to - x_from) + WALL_THICKNESS, wall_height, WALL_THICKNESS))


func _box(at: Vector3, size: Vector3, layer: int = 1) -> void:
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	_body(at, layer).add_child(collision)


## 바닥에 선 원기둥 충돌(base = 바닥 중심).
func _cylinder(base: Vector3, radius: float, height: float) -> void:
	var collision := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = height
	collision.shape = cylinder
	_body(base + Vector3.UP * height / 2.0, 1).add_child(collision)


func _body(at: Vector3, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	body.collision_layer = layer
	add_child(body)
	return body
