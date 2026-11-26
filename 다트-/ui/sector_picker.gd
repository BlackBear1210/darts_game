extends Control
## 구역을 고르는 카드(봉쇄 구역·더블 오어 낫싱·지뢰 심기)를 쓸 때 뜨는 다트판 팝업
## (2026-11-24 사용자 요청 "다트판 팝업시켜서 클릭으로 지정하게 하기").
##
## 예전에는 Z·X 로 20칸을 하나씩 넘겨야 했다. 이제 판을 그려 놓고 누르면 그 칸이다.
## 칸 번호(0~19)는 판 위의 **자리**다 — 적힌 숫자는 카드로 섞일 수 있으므로 지금 판의 숫자를 받아서 그린다.
## 각도 규칙은 BoardLayout.sector_at 과 같다: 0번이 12시, 시계 방향.
##
## 지뢰 심기는 마우스 포인터가 폭탄으로 바뀌고, 같은 칸에 겹쳐 심을 수 있다(판정은 MatchCards.landing_points).

signal picked(sector: int)
signal closed

const Style = preload("res://ui/lounge_style.gd")

const RADIUS: float = 190.0
## 숫자를 적는 반지름(바깥 테두리 바로 안쪽).
const NUMBER_RADIUS: float = RADIUS * 0.84
## 폭탄 포인터 크기(반지름).
const BOMB_RADIUS: float = 13.0

var numbers: Array[int] = BoardLayout.DEFAULT_NUMBERS.duplicate()
## 지뢰 심기면 포인터가 폭탄이 되고 안내 글이 바뀐다.
var bomb: bool = false
## 이미 고른 칸(-1 = 아직). 다시 열었을 때 어디를 골랐는지 보여 준다.
var chosen: int = -1
var _hover: int = -1
var _face: Control
var _mouse := Vector2.INF
var _title: Label
var _note: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 뒤를 어둡게 덮는 막은 _draw 맨 앞에서 그린다. 자식 ColorRect 로 두면 Control 의 _draw 그림 위를 덮는다.
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(column)
	_title = Style.heading(column, "구역을 고르세요", 38, Style.GOLD)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 판 자리만 잡아 두는 빈 칸이다. 실제 그림은 이 팝업이 _draw 에서 한 번에 그린다
	# (자식의 draw 신호로 나눠 그리면 다시 그리기 타이밍이 어긋났다).
	_face = Control.new()
	_face.custom_minimum_size = Vector2(RADIUS * 2.0 + 16, RADIUS * 2.0 + 16)
	_face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 팝업을 띄운 첫 그림은 판 자리가 배치되기 전이라 왼쪽 위에 그려진다 → 자리가 정해지면 다시 그린다(2026-11-26).
	_face.item_rect_changed.connect(queue_redraw)
	column.add_child(_face)
	_note = Style.label(column, "", 19, Style.CREAM)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## 지금 팝업을 띄워야 하는가(2026-11-25). 부르는 쪽이 매 프레임 묻는다.
##   wants  = 꺼내 든 구역 카드(-1 = 구역 카드가 아니거나 안 꺼냄)
##   opened = 지금 띄워 둔 카드 · done = 이 카드는 이미 고르거나 닫았다
## 닫을 때 opened 만 비우면 다음 프레임에 wants != opened 가 되어 **곧바로 다시 열린다**(겪은 버그).
## 그래서 닫은 카드를 done 에 적어 두고 여기서 같이 본다.
static func should_open(wants: int, opened: int, done: int) -> bool:
	return wants >= 0 and wants != opened and wants != done


## 지금 판의 숫자와 카드 종류를 받아 다시 그린다. 팝업을 띄울 때마다 부른다.
func show_board(board_numbers: Array[int], is_bomb: bool, headline: String, hint: String) -> void:
	numbers = board_numbers.duplicate()
	bomb = is_bomb
	_title.text = headline
	_note.text = hint
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse = (event as InputEventMouseMotion).position
		var was: int = _hover
		_hover = _sector_at(_mouse)
		if was != _hover or bomb: queue_redraw()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var button: int = (event as InputEventMouseButton).button_index
		if button == MOUSE_BUTTON_LEFT:
			var sector: int = _sector_at((event as InputEventMouseButton).position)
			if sector >= 0:
				picked.emit(sector)
				accept_event()
		elif button == MOUSE_BUTTON_RIGHT:
			closed.emit()
			accept_event()
	elif event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		closed.emit()
		accept_event()


## 판 한가운데(이 팝업의 좌표). 팝업은 화면 전체를 덮으므로 전역 좌표와 같다.
func _board_center() -> Vector2:
	return _face.position + _face.size / 2.0


## 팝업 좌표의 한 점이 몇 번 칸인가. 판 밖이면 -1.
func _sector_at(point: Vector2) -> int:
	var offset: Vector2 = point - _board_center()
	if offset.length() > RADIUS:
		return -1
	# 화면 y 는 아래로 자란다 → 과녁 좌표로 뒤집어 BoardLayout 과 같은 규칙을 쓴다.
	return BoardLayout.sector_at(Vector2(offset.x, -offset.y))


## 판·숫자·폭탄 포인터를 한 번에 그린다.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(Style.INK, 0.62))
	var center: Vector2 = _board_center()
	draw_circle(center, RADIUS + 6.0, Style.INK)
	for sector in range(20):
		var from: float = (sector - 0.5) * TAU / 20.0
		var points := PackedVector2Array([center])
		for step in range(9):
			var angle: float = from + TAU / 20.0 * step / 8.0
			points.append(center + Vector2(sin(angle), -cos(angle)) * RADIUS)
		var tint: Color = Style.PANEL_HI if sector % 2 == 0 else Style.PANEL
		if sector == chosen:
			tint = Style.MINT
		if sector == _hover:
			tint = Style.PINK if bomb else Style.GOLD
		draw_colored_polygon(points, tint)
		draw_polyline(points, Color(Style.INK, 0.6), 1.5, true)
	# 숫자: 칸 가운데 방향으로 밀어 적는다.
	var font: Font = Style.font("heading")
	for sector in range(20):
		var angle: float = sector * TAU / 20.0
		var at: Vector2 = center + Vector2(sin(angle), -cos(angle)) * NUMBER_RADIUS
		var text: String = str(numbers[sector % numbers.size()])
		var extent: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
		var ink: Color = Style.INK if sector == _hover or sector == chosen else Style.CREAM
		draw_string(font, at - Vector2(extent.x / 2.0, -8.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, ink)
	draw_arc(center, RADIUS, 0, TAU, 64, Style.GOLD, 2.0, true)
	_draw_bomb()


## 지뢰 심기일 때만: 마우스 자리에 폭탄을 그린다(포인터 대신).
func _draw_bomb() -> void:
	if not bomb or not _mouse.is_finite():
		return
	draw_circle(_mouse, BOMB_RADIUS, Color("22191f"))
	draw_circle(_mouse - Vector2(BOMB_RADIUS * 0.3, BOMB_RADIUS * 0.3), BOMB_RADIUS * 0.3, Color(1, 1, 1, 0.5))
	# 심지와 불꽃.
	var fuse: Vector2 = _mouse + Vector2(BOMB_RADIUS * 0.55, -BOMB_RADIUS * 0.8)
	draw_line(_mouse + Vector2(BOMB_RADIUS * 0.2, -BOMB_RADIUS * 0.85), fuse, Color("8a7a5c"), 3.0, true)
	draw_circle(fuse, 4.5, Style.GOLD)
	draw_circle(fuse, 2.2, Color("fff1c4"))
