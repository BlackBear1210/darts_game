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
const DART_HALL := Rect2(-6.6, -7.5, 13.2, 7.5)
const LOUNGE := Rect2(-8.4, 0.0, 22.0, 9.0)

## 과녁은 다트 홀 끝 벽 가운데에 건다. 높이·크기는 바꾸지 않았다(팀 확정 대기).
const BOARD_CENTER := Vector3(0, 2.9, -7.2)
const BOARD_SCALE: float = 2.5
## 투척선 위치(z)와 그 앞 보호 레인의 경계. 투척선에서 과녁 면까지 3.15m다.
const NO_ENTRY_Z: float = -4.15
const THROW_LINE_Z: float = -4.05
## 보호 레인 반폭. 다트가 날아가는 이 가운데 복도만 막고, 양옆은 지나다니며 구경·방해할 수 있다.
const LANE_HALF: float = 1.2
## 벽 안쪽 면에서 몸 중심이 더 들어오지 못하는 거리(벽 두께 절반 + 몸 반지름).
const BODY_MARGIN: float = 0.45

## 방 크기: 벽 두께와 천장 아랫면 높이(m).
const WALL_THICKNESS: float = 0.3
const CEILING_HEIGHT: float = 4.8

## 카드 테이블(도면 "플레이어 테이블")과 자리 4개. 자리 순서는 왼쪽·안쪽·오른쪽·바깥쪽이다.
const TABLE_CENTER := Vector3(0, 0, 4.4)
const TABLE_SIZE := Vector2(2.15, 1.55)
const TABLE_HEIGHT: float = 0.85
const SEATS: Array[Vector3] = [Vector3(-1.5, 0, 4.4), Vector3(0, 0, 5.65), Vector3(1.5, 0, 4.4), Vector3(0, 0, 3.2)]
const SEAT_DISTANCE: float = 1.0
const RAISED_HEIGHT: float = 1.6

## 도면의 럼주통. 큰 통 4개는 다트 홀 네 귀퉁이(둘은 투척 구역 안), 작은 통은 그 곁이다.
## 2026-10-31 늦은 밤: 다트 홀이 양옆으로 0.6m 넓어져 벽과의 거리를 유지하려고 통도 0.6m 바깥으로 옮겼다.
const BARRELS: Array[Vector3] = [Vector3(-5.7, 0, -6.8), Vector3(5.6, 0, -7.2),
	Vector3(-5.7, 0, -3.1), Vector3(5.6, 0, -3.15)]
const BARREL_RADIUS: float = 0.4
const BARREL_HEIGHT: float = 0.9
const SMALL_BARRELS: Array[Vector3] = [Vector3(6.0, 0, -6.15), Vector3(-6.15, 0, -2.4),
	Vector3(5.1, 0, -2.5), Vector3(6.0, 0, -2.3)]
const SMALL_BARREL_RADIUS: float = 0.2
const SMALL_BARREL_HEIGHT: float = 0.5

## 라운지 가구: 왼쪽 벽 바 카운터, NPC 자리 테이블과 스툴 2개, 오른쪽 당구대.
const BAR_BOX := AABB(Vector3(-5.85, 0, 0.0), Vector3(0.95, 1.2, 7.4))
const NPC_TABLE_BOX := AABB(Vector3(4.95, 0, 3.3), Vector3(1.65, 0.85, 1.5))
const NPC_STOOLS: Array[Vector3] = [Vector3(5.8, 0, 2.6), Vector3(5.8, 0, 6.3)]
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
const PRACTICE_TARGET_AT := Vector3(-3.4, 0, -6.6)
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
			[BAR_FRIDGE_AT, BAR_FRIDGE_SIZE]]:
		var at: Vector3 = spec[0]
		var size: Vector3 = spec[1]
		blocks.append(AABB(at - Vector3(size.x / 2.0, 0, size.z / 2.0), size))
	return blocks

## 정적 메시 묶기(그리기 호출 줄이기). class_name 이 없는 도구라 preload 로 부른다.
const StaticBatch = preload("res://art/static_batch.gd")

@onready var board: BoardView = $Board
var is_ready: bool = true


## 방 배치 상수를 한 줄 글자로 만든다. 생성기가 방(pub_game.tscn)에 저장하고, 실행 때 같은지 비교한다.
static func layout_signature() -> String:
	return var_to_str(["round_table_v1", BOARD_CENTER, BOARD_SCALE, SEATS, DART_HALL, LOUNGE, WALL_THICKNESS, CEILING_HEIGHT,
		NO_ENTRY_Z, THROW_LINE_Z, LANE_HALF, TABLE_CENTER, TABLE_SIZE, TABLE_HEIGHT,
		BARRELS, BARREL_RADIUS, SMALL_BARRELS, SMALL_BARREL_RADIUS,
		BAR_BOX, NPC_TABLE_BOX, NPC_STOOLS, POOL_TABLE_BOX,
		# 도면 v3(2026-10-31 밤): 에셋 가구 자리·바 위 물건 자리
		KEG_AT, BACK_COUNTER_AT, PRACTICE_TARGET_AT, BUCKET_AT, SOFA_AT, ARMCHAIR_AT, SIDE_TABLE_AT, CRATES_AT, GRAIN_BAG_AT,
		BAR_TOP_Y, BAR_MUGS, BAR_BOTTLES_Z,
		# 방 넓히기 v4(2026-10-31 늦은 밤): 바 끝 냉장고
		BAR_FRIDGE_AT, BAR_FRIDGE_SIZE])


## 사람이 설 수 있는 바닥 두 칸(벽 안쪽에서 몸 반지름만큼 뺀 것).
## 가운데 보호 레인은 여기서 빼지 않는다 — 레인 벽(레이어 4)이 막고 양옆은 지나다닐 수 있다.
## 다트 홀 칸은 라운지까지 이어지므로 z 끝을 라운지와 같이 둔다 — 둘의 합집합이 ㄱ자다.
static func walkable_halls() -> Array[Rect2]:
	var front: float = DART_HALL.position.y + BODY_MARGIN
	var hall := Rect2(DART_HALL.position.x + BODY_MARGIN, front,
		DART_HALL.size.x - BODY_MARGIN * 2, LOUNGE.end.y - BODY_MARGIN - front)
	var lounge := LOUNGE.grow(-BODY_MARGIN)
	return [hall, lounge]


## 여기서만 던질 수 있다. 라운지(테이블·바)에서는 못 던진다.
## 레인 양옆이 뚫려 있어 투척선을 지나 과녁 옆까지 갈 수 있으므로 "투척선 뒤"도 함께 본다.
static func in_throw_zone(point: Vector3) -> bool:
	return DART_HALL.has_point(Vector2(point.x, point.z)) and point.z >= THROW_LINE_Z


## 각 자리에서 테이블 바깥쪽으로 일어선다. 고정 +Z는 4번 자리를 상판 안에 넣는다.
static func standing_spot(seat: int) -> Vector3:
	var origin: Vector3 = SEATS[seat]
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
	# 플레이어 마스크에만 포함되는 투명 벽(다트 레이는 통과한다): 가운데 보호 레인 복도.
	# 앞(투척선)과 양옆만 막아 레인 안으로 못 들어오게 하고, 레인 바깥 양옆 통로는 열어 둔다.
	var lane_depth: float = NO_ENTRY_Z - DART_HALL.position.y
	var lane_middle: float = (NO_ENTRY_Z + DART_HALL.position.y) / 2.0
	_box(Vector3(0, 2, NO_ENTRY_Z), Vector3(LANE_HALF * 2, 6, 0.1), 4)
	for side: float in [-1.0, 1.0]:
		_box(Vector3(side * LANE_HALF, 2, lane_middle), Vector3(0.1, 6, lane_depth), 4)
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
	_prepare_pub()


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
	if trim.is_valid(): trim.call(pub)
	add_child(pub)
	move_child(pub, order)
	_prepare_pub()


## 방 그림이 지금 규칙 좌표로 만들어졌는지 확인하고, 화면이 있을 때만 메시를 묶는다.
func _prepare_pub() -> void:
	var pub := get_node_or_null("Pub") as Node3D
	if pub == null:
		push_warning("art/pub/pub_game.tscn 이 없습니다. art/pub/pub_builder.gd 를 실행하세요.")
		return
	if str(pub.get_meta("layout_signature", "")) != layout_signature():
		push_warning("방 그림(pub_game.tscn)이 TableView 상수와 다릅니다. art/pub/pub_builder.gd 를 다시 실행하세요.")
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
