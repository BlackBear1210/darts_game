extends Control
## 화면 위 가운데 라운드 표시(롤 아레나 모드의 라운드 표시 참고). 라운드마다 ◆ 카드 충전 + ● 다트 두 칸.
## 지난 칸은 채워지고, 지금 칸은 금빛으로 맥박치고, 앞으로 올 칸은 테두리만. 마우스를 올리면 그 칸 설명이 아래에 뜬다.
## 끝 라운드를 모르는 모드(목표 점수·500→0)는 지금 라운드 + 2칸까지 보이고 뒤에 … 를 붙인다.

const CardFaces = preload("res://game/card_round/cards/card_faces.gd")

enum Stage { CARDS, DARTS }

const PIP: float = 24.0
const PAIR_GAP: float = 12.0
const ROUND_GAP: float = 26.0
const TITLE_WIDTH: float = 168.0
const HEIGHT: float = 78.0
const DIM := Color("6f6a5c")

var round_number: int = 1
var stage: Stage = Stage.CARDS
## 0 = 끝을 모름.
var total_rounds: int = 7
## Vector2i(라운드, 단계) → 지난 일 요약 한 줄(예: "받은 카드 ● 2장 ▲ 0장").
var notes: Dictionary = {}
var _time: float = 0.0
var _hover := Vector2i(-1, -1)
var _tooltip: PanelContainer
var _tip_title: Label
var _tip_body: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_tooltip = PanelContainer.new()
	_tooltip.add_theme_stylebox_override("panel", PubTheme.box(Color(PubTheme.INK, 0.95), PubTheme.GOLD, 2, 10, 14))
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.top_level = true
	_tooltip.visible = false
	add_child(_tooltip)
	var column := VBoxContainer.new()
	_tooltip.add_child(column)
	_tip_title = Label.new()
	_tip_title.add_theme_font_override("font", CardFaces.bold_font())
	_tip_title.add_theme_font_size_override("font_size", 22)
	_tip_title.add_theme_color_override("font_color", PubTheme.GOLD)
	column.add_child(_tip_title)
	_tip_body = Label.new()
	_tip_body.add_theme_font_size_override("font_size", 18)
	_tip_body.custom_minimum_size.x = 380
	_tip_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_tip_body)


## 표시할 라운드 수(끝을 모르면 지금 라운드 + 2, 최소 5).
func shown_rounds() -> int:
	return total_rounds if total_rounds > 0 else maxi(round_number + 2, 5)


## 라운드 표시 전체 너비(px).
func preferred_width() -> float:
	return TITLE_WIDTH + shown_rounds() * (PIP * 2 + PAIR_GAP + ROUND_GAP) + (40.0 if total_rounds == 0 else 10.0)


## 지금 라운드·단계를 바꾸고 크기와 가운데 위치를 다시 맞춘다.
func set_stage(round_value: int, stage_value: Stage) -> void:
	round_number = round_value
	stage = stage_value
	size = Vector2(preferred_width(), HEIGHT)
	position.x = (get_viewport_rect().size.x - size.x) * 0.5


## 라운드 round_value 의 단계 stage_value 점이 그려지는 사각형(마우스 올려 보기 판정에도 쓴다).
func pip_rect(round_value: int, stage_value: int) -> Rect2:
	var x: float = TITLE_WIDTH + (round_value - 1) * (PIP * 2 + PAIR_GAP + ROUND_GAP) + stage_value * (PIP + PAIR_GAP)
	return Rect2(Vector2(x, 16), Vector2(PIP, PIP))


## 칸 설명: [제목, 본문].
func describe(round_value: int, stage_value: int) -> PackedStringArray:
	var key := Vector2i(round_value, stage_value)
	var state: int = _state(round_value, stage_value)
	var title: String
	var body: String
	if stage_value == Stage.CARDS:
		title = "%d라운드 · %s" % [round_value, "카드 나눠 주기" if round_value == 1 else "카드 충전 라운드"]
		body = "덱을 섞고 한 장씩 한 바퀴씩 나눠 7장을 채운다." if round_value == 1 else "쓴 카드만큼만 7장까지 다시 받는다. 안 썼으면 0장."
	else:
		title = "%d라운드 · 다트 라운드" % round_value
		body = "한 사람 3발씩. 카드는 언제든 1~7로 꺼내 들고 F로 쓴다."
	if total_rounds > 0 and round_value == total_rounds and stage_value == Stage.DARTS:
		body += "\n마지막 라운드!"
	var prefix: String = ["지난 단계", "지금 진행 중", "예정"][state]
	if notes.has(key):
		body += "\n" + str(notes[key])
	return PackedStringArray([title, "[%s] %s" % [prefix, body]])


func _process(delta: float) -> void:
	_time += delta
	var hover := Vector2i(-1, -1)
	var mouse: Vector2 = get_local_mouse_position()
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and Rect2(Vector2.ZERO, size).has_point(mouse):
		for round_value in range(1, shown_rounds() + 1):
			for stage_value in range(2):
				if pip_rect(round_value, stage_value).grow(8).has_point(mouse):
					hover = Vector2i(round_value, stage_value)
	if hover != _hover:
		_hover = hover
		_tooltip.visible = hover.x > 0
		if _tooltip.visible:
			var text: PackedStringArray = describe(hover.x, hover.y)
			_tip_title.text = text[0]
			_tip_body.text = text[1]
			_tooltip.reset_size()
	if _tooltip.visible:
		var rect: Rect2 = pip_rect(_hover.x, _hover.y)
		_tooltip.global_position = global_position + Vector2(clampf(rect.position.x - 180, 0, size.x - 300), size.y + 8)
	queue_redraw()


func _draw() -> void:
	draw_style_box(PubTheme.box(Color(PubTheme.INK, 0.86), Color(PubTheme.GOLD, 0.75), 2, 12), Rect2(Vector2.ZERO, size))
	var font: Font = CardFaces.bold_font()
	draw_string(font, Vector2(18, 36), "%d" % round_number, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, PubTheme.GOLD)
	draw_string(font, Vector2(58, 34), "라운드", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, PubTheme.PAPER)
	draw_string(font, Vector2(18, 64), "카드 충전" if stage == Stage.CARDS else "다트", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, PubTheme.GOLD if stage == Stage.CARDS else Color("9fd3c7"))
	for round_value in range(1, shown_rounds() + 1):
		var cards: Rect2 = pip_rect(round_value, Stage.CARDS)
		var darts: Rect2 = pip_rect(round_value, Stage.DARTS)
		draw_line(cards.get_center(), darts.get_center(), DIM, 2.0)
		_draw_pip(cards, round_value, Stage.CARDS)
		_draw_pip(darts, round_value, Stage.DARTS)
		var number_color: Color = PubTheme.PAPER if round_value == round_number else DIM
		draw_string(font, Vector2(cards.position.x + PIP * 0.5, 66), str(round_value), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, number_color)
	if total_rounds == 0:
		draw_string(font, Vector2(pip_rect(shown_rounds(), 1).end.x + 12, 36), "…", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, DIM)


## 0 = 지난 칸, 1 = 지금 칸, 2 = 앞으로 올 칸.
func _state(round_value: int, stage_value: int) -> int:
	if round_value < round_number or (round_value == round_number and stage_value < stage):
		return 0
	return 1 if round_value == round_number and stage_value == stage else 2


## 점 하나를 그린다(지난 단계 = 어두운 금색, 지금 = 금색, 앞으로 = 흐림).
func _draw_pip(rect: Rect2, round_value: int, stage_value: int) -> void:
	var state: int = _state(round_value, stage_value)
	var center: Vector2 = rect.get_center()
	var radius: float = PIP * 0.5
	var color: Color = [PubTheme.GOLD.darkened(0.25), PubTheme.GOLD, DIM][state]
	if state == 1:
		radius *= 1.0 + 0.16 * sin(_time * 5.0)
		draw_circle(center, radius * 1.6, Color(PubTheme.GOLD, 0.18))
	if _hover == Vector2i(round_value, stage_value):
		draw_circle(center, radius * 1.45, Color(PubTheme.PAPER, 0.2))
	if stage_value == Stage.CARDS:
		var diamond := PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)])
		if state == 2:
			diamond.append(diamond[0])
			draw_polyline(diamond, color, 2.0, true)
		else:
			draw_colored_polygon(diamond, color)
	else:
		if state == 2:
			draw_arc(center, radius * 0.85, 0, TAU, 24, color, 2.0, true)
		else:
			draw_circle(center, radius * 0.85, color)
			draw_circle(center, radius * 0.3, PubTheme.INK)
