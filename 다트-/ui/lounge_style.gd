extends RefCounted
## DARTY 로비·설정·라운지 HUD 의 공용 시각 언어(디자인 담당 소유, 2026-10-30 개편).
##
## [방향] 따뜻한 펍 + 파티 게임. 굵은 잉크 테두리와 아래로 떨어지는 단단한 그림자로
## "책상 위에 붙인 스티커 카드"처럼 보이게 한다. 색은 다트판(크림·토마토·초록)과 다트 배럴 금색에서 골랐다.
## 기존 경기 HUD 테마(ui/pub_theme.gd, 개발자 예시 경기용)는 건드리지 않는다.
##
## [글꼴] art/fonts/ 에 디자인 요청서(DARTY_프로젝트/디자인 요청)로 고른 글꼴 파일이 들어오면 그것을 쓰고,
## 없으면 Windows 기본 글꼴(맑은 고딕·Impact)로 그린다. 파일 이름은 아래 FONT_FILES 를 따른다.

## 바탕·판넬은 자두빛 검정(펍 조명 아래 어두운 나무 느낌), 글자·주 버튼은 다트판 크림색.
const BG := Color("17111a")
const PANEL := Color("241b29")
const PANEL_HI := Color("33273a")
const INK := Color("120c12")
const CREAM := Color("fff3dc")
## MINT / PINK 는 예전 이름을 유지한다(설정 창·HUD 가 이 이름을 쓴다). 지금 값은 청록(분필·네온)과 토마토(강조·경고)다.
const MINT := Color("37d9bf")
const PINK := Color("ff6b5b")
const GOLD := Color("ffc845")
const MUTED := Color("b7a7b1")
## 다트판 색(로고·과녁 장식에서 쓴다).
const BOARD_RED := Color("e0453a")
const BOARD_GREEN := Color("1f9d68")

## 단단한 그림자 거리(px). 누르면 0 으로 줄어 "눌린" 느낌을 준다.
const SHADOW := Vector2(0, 6)
## 버튼 기울기(StyleBoxFlat.skew). 다트 깃처럼 살짝 기울인다.
const SKEW: float = -0.08

const FONT_FILES := {
	"logo": "res://art/fonts/darty_logo.ttf",
	"heading": "res://art/fonts/darty_heading.ttf",
	"body": "res://art/fonts/darty_body.ttf",
}

static var _fonts: Dictionary = {}
static var _theme: Theme


## kind = "logo"(영문 로고·숫자), "heading"(한글 제목), "body"(본문). 같은 글꼴은 한 번만 만든다.
static func font(kind: String) -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var result: Font
	var path: String = FONT_FILES.get(kind, "")
	if not path.is_empty() and ResourceLoader.exists(path):
		result = load(path) as Font
	if result == null:
		var system := SystemFont.new()
		match kind:
			"logo":
				system.font_names = PackedStringArray(["Impact", "Arial Black", "Malgun Gothic", "sans-serif"])
			_:
				system.font_names = PackedStringArray(["Malgun Gothic", "Apple SD Gothic Neo", "Noto Sans CJK KR", "sans-serif"])
				system.font_weight = 700
		system.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		result = system
		if kind == "heading":
			# 맑은 고딕 Bold 도 제목으로는 얇다. 획을 조금 두껍게 만든다.
			var heavy := FontVariation.new()
			heavy.base_font = system
			heavy.variation_embolden = 0.55
			result = heavy
	_fonts[kind] = result
	return result


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var result := Theme.new()
	result.default_font = font("body")
	result.default_font_size = 20
	result.set_color("font_color", "Label", CREAM)
	# 주 버튼: 크림 카드 + 잉크 테두리 + 단단한 그림자. 올리면 금색, 누르면 그림자가 사라진다.
	for type in ["Button", "OptionButton", "CheckButton"]:
		result.set_stylebox("normal", type, card(CREAM))
		result.set_stylebox("hover", type, card(GOLD, INK, SHADOW + Vector2(0, 2)))
		result.set_stylebox("pressed", type, card(GOLD.darkened(0.08), INK, Vector2.ZERO))
		result.set_stylebox("hover_pressed", type, card(GOLD, INK, Vector2(0, 2)))
		result.set_stylebox("focus", type, card(Color.TRANSPARENT, MINT, Vector2.ZERO, 3))
		result.set_stylebox("disabled", type, card(Color("5a4d57"), Color("2b222a"), Vector2(0, 3)))
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			result.set_color(state, type, INK)
		result.set_color("font_disabled_color", type, Color("a3959e"))
		result.set_constant("h_separation", type, 12)
	result.set_font_size("font_size", "Button", 22)
	# 보조 버튼(돌아가기·탭 등): 어두운 판에 크림 테두리.
	result.set_type_variation("SecondaryButton", "Button")
	result.set_stylebox("normal", "SecondaryButton", card(PANEL_HI, CREAM.darkened(0.45), Vector2(0, 4)))
	result.set_stylebox("hover", "SecondaryButton", card(PANEL_HI.lightened(0.12), CREAM, Vector2(0, 5)))
	result.set_stylebox("pressed", "SecondaryButton", card(MINT, INK, Vector2.ZERO))
	for state in ["font_color", "font_hover_color", "font_focus_color"]:
		result.set_color(state, "SecondaryButton", CREAM)
	result.set_color("font_pressed_color", "SecondaryButton", INK)
	result.set_font_size("font_size", "SecondaryButton", 19)
	# 선택된 탭·카드(토글 버튼이 눌린 상태).
	result.set_type_variation("ChoiceButton", "Button")
	result.set_stylebox("normal", "ChoiceButton", card(PANEL_HI, Color("4a3c4f"), Vector2(0, 4)))
	result.set_stylebox("hover", "ChoiceButton", card(PANEL_HI.lightened(0.1), CREAM.darkened(0.2), Vector2(0, 5)))
	result.set_stylebox("pressed", "ChoiceButton", card(MINT, INK, Vector2(0, 4)))
	result.set_stylebox("hover_pressed", "ChoiceButton", card(MINT.lightened(0.1), INK, Vector2(0, 5)))
	for state in ["font_color", "font_hover_color", "font_focus_color"]:
		result.set_color(state, "ChoiceButton", CREAM)
	result.set_color("font_pressed_color", "ChoiceButton", INK)
	result.set_color("font_hover_pressed_color", "ChoiceButton", INK)
	# 켜기/끄기 스위치: 글자색을 판 위에서 읽히게 크림으로.
	result.set_stylebox("normal", "CheckButton", card(PANEL_HI, Color("4a3c4f"), Vector2(0, 3)))
	result.set_stylebox("hover", "CheckButton", card(PANEL_HI.lightened(0.1), CREAM.darkened(0.2), Vector2(0, 4)))
	result.set_stylebox("pressed", "CheckButton", card(PANEL_HI, Color("4a3c4f"), Vector2(0, 3)))
	result.set_stylebox("hover_pressed", "CheckButton", card(PANEL_HI.lightened(0.1), CREAM.darkened(0.2), Vector2(0, 4)))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		result.set_color(state, "CheckButton", CREAM)
	result.set_icon("checked", "CheckButton", _switch_icon(true))
	result.set_icon("unchecked", "CheckButton", _switch_icon(false))
	result.set_icon("checked_disabled", "CheckButton", _switch_icon(true))
	result.set_icon("unchecked_disabled", "CheckButton", _switch_icon(false))
	# 펼침 목록.
	result.set_stylebox("panel", "PopupMenu", flat(PANEL, CREAM.darkened(0.4), 2, 12, 8))
	result.set_stylebox("hover", "PopupMenu", flat(GOLD, GOLD, 0, 8, 6))
	result.set_color("font_color", "PopupMenu", CREAM)
	result.set_color("font_hover_color", "PopupMenu", INK)
	result.set_font_size("font_size", "PopupMenu", 19)
	result.set_constant("v_separation", "PopupMenu", 10)
	# 입력칸: 잉크 홈에 크림 글자. 포커스면 청록 테두리.
	result.set_stylebox("normal", "LineEdit", flat(INK, Color("4a3c4f"), 2, 10, 12))
	result.set_stylebox("focus", "LineEdit", flat(INK, MINT, 3, 10, 12))
	result.set_stylebox("read_only", "LineEdit", flat(Color("1d151d"), Color("3a2e3d"), 2, 10, 12))
	result.set_color("font_color", "LineEdit", CREAM)
	result.set_color("font_placeholder_color", "LineEdit", Color(MUTED, 0.7))
	result.set_color("caret_color", "LineEdit", GOLD)
	result.set_color("selection_color", "LineEdit", Color(MINT, 0.35))
	# 슬라이더·스크롤바.
	result.set_stylebox("slider", "HSlider", flat(INK, Color("4a3c4f"), 2, 8, 0, 4))
	result.set_stylebox("grabber_area", "HSlider", flat(MINT, MINT, 0, 8, 0, 4))
	result.set_stylebox("grabber_area_highlight", "HSlider", flat(GOLD, GOLD, 0, 8, 0, 4))
	result.set_icon("grabber", "HSlider", _knob_icon(CREAM))
	result.set_icon("grabber_highlight", "HSlider", _knob_icon(GOLD))
	result.set_stylebox("scroll", "VScrollBar", flat(Color(INK, 0.6), Color.TRANSPARENT, 0, 6, 0, 3))
	result.set_stylebox("grabber", "VScrollBar", flat(Color(CREAM, 0.35), Color.TRANSPARENT, 0, 6, 0, 3))
	result.set_stylebox("grabber_highlight", "VScrollBar", flat(GOLD, Color.TRANSPARENT, 0, 6, 0, 3))
	result.set_stylebox("grabber_pressed", "VScrollBar", flat(GOLD, Color.TRANSPARENT, 0, 6, 0, 3))
	# 큰 판: 자두빛 판 + 굵은 잉크 테두리 + 깊은 그림자.
	result.set_stylebox("panel", "PanelContainer", card(PANEL, INK, Vector2(0, 12), 4, 26, 30))
	result.set_type_variation("SoftPanel", "PanelContainer")
	result.set_stylebox("panel", "SoftPanel", flat(Color(INK, 0.55), Color(CREAM, 0.12), 2, 16, 16))
	_theme = result
	return result


## 굵은 테두리 + 단단한 그림자 카드 모양. 버튼·판넬 공용.
static func card(fill: Color, edge: Color = INK, shadow: Vector2 = SHADOW, border: int = 3,
		radius: int = 14, margin: int = 16) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(border)
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin + 4
	style.content_margin_right = margin + 4
	style.content_margin_top = margin * 0.55
	style.content_margin_bottom = margin * 0.55
	style.skew = Vector2(SKEW, 0) if radius <= 16 else Vector2.ZERO
	if shadow != Vector2.ZERO:
		style.shadow_color = Color(INK, 0.92)
		style.shadow_size = 1
		style.shadow_offset = shadow
	style.anti_aliasing = true
	return style


## 그림자 없는 평평한 상자(입력칸·목록·막대).
static func flat(fill: Color, edge: Color, border: int = 1, radius: int = 8, margin: int = 8,
		vertical_margin: int = -1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(border)
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = vertical_margin if vertical_margin >= 0 else margin * 0.7
	style.content_margin_bottom = vertical_margin if vertical_margin >= 0 else margin * 0.7
	return style


static func label(parent: Node, text: String, font_size: int = 20, color: Color = CREAM) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	if font_size >= 28:
		item.add_theme_font_override("font", font("heading"))
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	return item


## 제목 글자: 굵은 한글 + 잉크 외곽선 + 단단한 그림자(스티커 글자).
static func heading(parent: Node, text: String, font_size: int = 40, color: Color = CREAM) -> Label:
	var item := label(parent, text, font_size, color)
	item.add_theme_font_override("font", font("heading"))
	item.add_theme_color_override("font_outline_color", INK)
	item.add_theme_constant_override("outline_size", maxi(6, font_size / 5))
	item.add_theme_color_override("font_shadow_color", Color(INK, 0.95))
	item.add_theme_constant_override("shadow_offset_x", 0)
	item.add_theme_constant_override("shadow_offset_y", maxi(3, font_size / 10))
	item.add_theme_constant_override("shadow_outline_size", maxi(6, font_size / 5))
	return item


static func button(parent: Node, text: String, action: Callable, variation: String = "") -> Button:
	var item := Button.new()
	item.text = text
	item.custom_minimum_size.y = 56
	item.theme_type_variation = variation
	item.pressed.connect(action)
	parent.add_child(item)
	return item


static func secondary(parent: Node, text: String, action: Callable) -> Button:
	return button(parent, text, action, "SecondaryButton")


static func row(parent: Node, title: String, control: Control) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 20)
	parent.add_child(line)
	var caption := label(line, title, 19)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	control.custom_minimum_size.x = maxf(control.custom_minimum_size.x, 260)
	line.add_child(control)


## 설정 묶음 제목(작은 색 띠 + 글자).
static func section(parent: Node, text: String, color: Color = PINK) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	parent.add_child(line)
	var bar := ColorRect.new()
	bar.color = color
	bar.custom_minimum_size = Vector2(8, 26)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(bar)
	var caption := label(line, text, 22, color)
	caption.add_theme_font_override("font", font("heading"))


static func select(items: Array[String], value: int, action: Callable) -> OptionButton:
	var control := OptionButton.new()
	for item in items: control.add_item(item)
	control.select(value)
	control.item_selected.connect(action)
	control.add_theme_font_size_override("font_size", 19)
	return control


static func number(value: float, low: float, high: float, step: float, action: Callable) -> SpinBox:
	var control := SpinBox.new()
	control.min_value = low
	control.max_value = high
	control.step = step
	control.value = value
	control.alignment = HORIZONTAL_ALIGNMENT_CENTER
	control.value_changed.connect(action)
	return control


## 켜기/끄기 스위치. 글자도 상태에 맞춰 바뀐다(예전에는 늘 "켜기"라고 적혀 헷갈렸다).
static func toggle(value: bool, action: Callable) -> CheckButton:
	var control := CheckButton.new()
	control.button_pressed = value
	control.text = "켜짐" if value else "꺼짐"
	control.toggled.connect(func(on: bool) -> void: control.text = "켜짐" if on else "꺼짐")
	control.toggled.connect(action)
	return control


## 스위치 그림(알약 모양 + 동그란 손잡이). 이미지 파일 없이 만든다.
static func _switch_icon(on: bool) -> ImageTexture:
	var width := 60
	var height := 32
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var track: Color = MINT if on else Color("4a3c4f")
	var knob_x: float = width - height / 2.0 if on else height / 2.0
	for y in range(height):
		for x in range(width):
			var px := Vector2(x + 0.5, y + 0.5)
			# 알약: 양 끝 반원 + 가운데 사각형. 경계 1px 를 부드럽게 섞는다.
			var cx: float = clampf(px.x, height / 2.0, width - height / 2.0)
			var pill: float = clampf(height / 2.0 - px.distance_to(Vector2(cx, height / 2.0)), 0.0, 1.0)
			var knob: float = clampf(height / 2.0 - 4.0 - px.distance_to(Vector2(knob_x, height / 2.0)), 0.0, 1.0)
			var edge: float = clampf(height / 2.0 - px.distance_to(Vector2(cx, height / 2.0)) - 2.5, 0.0, 1.0)
			var color := INK.lerp(track, edge)
			color = color.lerp(CREAM, knob)
			color.a = pill
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


static func _knob_icon(color: Color) -> ImageTexture:
	var size := 26
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var distance := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(size / 2.0, size / 2.0))
			var outer: float = clampf(size / 2.0 - distance, 0.0, 1.0)
			var inner: float = clampf(size / 2.0 - 3.0 - distance, 0.0, 1.0)
			var pixel := INK.lerp(color, inner)
			pixel.a = outer
			image.set_pixel(x, y, pixel)
	return ImageTexture.create_from_image(image)
