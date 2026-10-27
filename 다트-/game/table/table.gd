class_name TableView
extends Node3D
## 공간의 배치와 환경 충돌만 소유한다. 캐릭터끼리는 충돌하지 않는다.
##
## [보이는 방은 따로 있다]
## 벽·바닥·바·소품·조명 같은 "보이는 것"은 자식 Pub(art/pub/pub_game.tscn, 디자인 담당 생성물)이 그린다.
## 이 스크립트는 같은 좌표에 "보이지 않는 충돌 상자"만 만든다.
## 아래 상수를 바꾸면 art/pub/pub_builder.gd 를 다시 돌려야 방 모양이 따라온다.
## 안 돌리면 게임 시작 때 경고가 뜨고 tests/test_game_look.gd 가 실패한다(layout_signature 비교).

# 투척선 앞 평지의 최대 점프 머리 높이(약 2.66m)보다 중심과 시점을 높인다.
const BOARD_CENTER := Vector3(0, 2.9, -6.7)
const BOARD_SCALE: float = 2.5
const SEATS: Array[Vector3] = [Vector3(-2, 0, 3.5), Vector3(0, 0, 5.5), Vector3(2, 0, 3.5), Vector3(0, 0, 1.5)]
const SEAT_DISTANCE: float = 1.0
const RAISED_HEIGHT: float = 1.6
## 방 크기: 벽 충돌 상자 중심까지의 반폭(x)·반길이(z), 벽 두께, 천장 아랫면 높이(m).
const ROOM_HALF := Vector2(6, 7)
const WALL_THICKNESS: float = 0.3
const CEILING_HEIGHT: float = 4.25
## 플레이어만 막는 투명 벽(투척 구역 경계)과 투척선 위치(z).
const NO_ENTRY_Z: float = -3.2
const THROW_LINE_Z: float = -3.1
## 원형 카드 테이블(바닥 중심·반지름·높이).
const TABLE_CENTER := Vector3(0, 0, 3.5)
const TABLE_RADIUS: float = 1.05
const TABLE_HEIGHT: float = 0.85
## 기획 2-7 "스툴 장애물 3개". 바닥 중심 위치와 충돌 원기둥 크기. 점프로 넘을 수 있는 높이다.
const OBSTACLES: Array[Vector3] = [Vector3(-3.8, 0, -0.8), Vector3(1.6, 0, -1.4), Vector3(3.4, 0, 1.0)]
const OBSTACLE_RADIUS: float = 0.3
const OBSTACLE_HEIGHT: float = 0.6
## 왼쪽 벽 바 카운터(바 스툴 포함)와 입구 벽 주크박스가 차지하는 상자.
const BAR_BOX := AABB(Vector3(-5.85, 0, 0.8), Vector3(2.5, 1.2, 5.4))
const JUKEBOX_BOX := AABB(Vector3(-2.0, 0, 6.1), Vector3(1.0, 1.65, 0.75))

## 정적 메시 묶기(그리기 호출 줄이기). class_name 이 없는 도구라 preload 로 부른다.
const StaticBatch = preload("res://art/static_batch.gd")

@onready var board: BoardView = $Board
var is_ready: bool = true


## 방 배치 상수를 한 줄 글자로 만든다. 생성기가 방(pub_game.tscn)에 저장하고, 실행 때 같은지 비교한다.
static func layout_signature() -> String:
	return var_to_str([BOARD_CENTER, BOARD_SCALE, SEATS, ROOM_HALF, WALL_THICKNESS, CEILING_HEIGHT,
		NO_ENTRY_Z, THROW_LINE_Z, TABLE_CENTER, TABLE_RADIUS, TABLE_HEIGHT,
		OBSTACLES, OBSTACLE_RADIUS, OBSTACLE_HEIGHT, BAR_BOX, JUKEBOX_BOX])


func _ready() -> void:
	board.position = BOARD_CENTER
	board.scale = Vector3.ONE * BOARD_SCALE
	var half_wall := WALL_THICKNESS / 2.0
	var wall_height := CEILING_HEIGHT + 0.25
	var wall_y := CEILING_HEIGHT - wall_height / 2.0
	# 바닥·벽 4면·천장(보이지 않는 충돌. 그림은 Pub).
	_box(Vector3(0, -half_wall, 0), Vector3(ROOM_HALF.x * 2, WALL_THICKNESS, ROOM_HALF.y * 2))
	_box(Vector3(-ROOM_HALF.x, wall_y, 0), Vector3(WALL_THICKNESS, wall_height, ROOM_HALF.y * 2))
	_box(Vector3(ROOM_HALF.x, wall_y, 0), Vector3(WALL_THICKNESS, wall_height, ROOM_HALF.y * 2))
	_box(Vector3(0, wall_y, -ROOM_HALF.y), Vector3(ROOM_HALF.x * 2, wall_height, WALL_THICKNESS))
	_box(Vector3(0, wall_y, ROOM_HALF.y), Vector3(ROOM_HALF.x * 2, wall_height, WALL_THICKNESS))
	_box(Vector3(0, CEILING_HEIGHT + half_wall, 0), Vector3(ROOM_HALF.x * 2, WALL_THICKNESS, ROOM_HALF.y * 2))
	# 플레이어 마스크에만 포함되는 투명 벽: 다트 레이는 통과한다.
	_box(Vector3(0, 2, NO_ENTRY_Z), Vector3(ROOM_HALF.x * 2, 6, 0.1), 4)
	# 사람이 부딪히는 가구: 테이블·바·주크박스·스툴 장애물.
	_cylinder(TABLE_CENTER, TABLE_RADIUS, TABLE_HEIGHT)
	_box(BAR_BOX.get_center(), BAR_BOX.size)
	_box(JUKEBOX_BOX.get_center(), JUKEBOX_BOX.size)
	for obstacle in OBSTACLES:
		_cylinder(obstacle, OBSTACLE_RADIUS, OBSTACLE_HEIGHT)
	_prepare_pub()


## 칠판 점수판(과녁 왼쪽 문)의 글자를 바꾼다. 방이 없으면(생성 전) 아무것도 안 한다.
func set_chalk_scores(text: String) -> void:
	var pub := get_node_or_null("Pub")
	if pub == null:
		return
	var label := pub.find_child("ChalkScores", true, false) as Label3D
	if label != null:
		label.text = text


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
