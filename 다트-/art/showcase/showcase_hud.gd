extends CanvasLayer
## 쇼케이스 화면 UI(점수판·시점 버튼·카드 버튼·크레딧). 노드를 코드로 만든다.
## 이 HUD 는 게임 상태를 직접 바꾸지 않는다. 버튼을 누르면 signal 만 보내고, showcase.gd 가 처리한 뒤
## update_state() 로 다시 그려 준다(UI 와 규칙 분리).
## 글자는 한국어다. 지금은 Godot 기본 글꼴 + 시스템 대체 글꼴(Windows 맑은 고딕)로 그린다.
## 배포 전에 재배포 가능한 한글 글꼴을 정해 테마에 넣는다(docs/ASSET_REGISTER.md 에 기록).

signal view_requested(index: int)
signal card_requested
signal next_requested
signal reset_requested
signal sound_requested
signal credits_requested

## 색 팔레트(따뜻한 펍 톤). 진초록 바탕 + 금색 강조 + 미색 글자.
const INK := Color("122b27")
const GOLD := Color("d7bb7f")
const PAPER := Color("f0e6cf")
const MUTED := Color("a7b8ac")
const FOOTER_VIEW := "1–4  시점 바꾸기     /     2  투척 시작     /     R  초기화"
const FOOTER_THROW := "마우스 시선  ·  A/D 좌우  ·  왼쪽 꾹 충전 → 놓기 투척  ·  오른쪽 취소  ·  Q 카드  ·  Space 다음  ·  Esc 마우스 풀기  ·  R 초기화"
var root: Control
var view_title: Label
var view_description: Label
var score_value: Label
var turn_label: Label
var result_label: Label
var dart_labels: Array[Label] = []
var card_button: Button
var action_button: Button
var aim_dot: Control
## 투척 시점 충전 막대(왼쪽 버튼을 누르고 있는 동안만 보인다).
var charge_bar: ProgressBar
var footer: Label
var view_buttons: Array[Button] = []
var sound_button: Button
var current_view := 0
var credits: PanelContainer


## 둥근 모서리 패널 스타일(배경색·테두리색·반지름).
func panel_style(color: Color, border: Color = Color.TRANSPARENT, radius := 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style


## 마우스를 통과시키는 글자. 3D 화면 클릭(투척)을 막지 않게 MOUSE_FILTER_IGNORE.
func label(text_: String, size: int, color: Color = PAPER) -> Label:
	var node := Label.new()
	node.text = text_
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


func button(text_: String, callback: Callable) -> Button:
	var node := Button.new()
	node.text = text_
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.add_theme_font_size_override("font_size", 15)
	node.add_theme_color_override("font_color", PAPER)
	node.add_theme_color_override("font_hover_color", PAPER)
	node.add_theme_stylebox_override("normal", panel_style(Color("1d3c34"), Color("395349"), 7))
	node.add_theme_stylebox_override("hover", panel_style(Color("365a49"), GOLD, 7))
	node.add_theme_stylebox_override("pressed", panel_style(Color("47654d"), GOLD, 7))
	node.add_theme_stylebox_override("focus", panel_style(Color(0, 0, 0, 0), GOLD, 7))
	node.pressed.connect(callback)
	return node


## 화면 전체를 한 번 만든다. 위: 로고 줄 / 왼쪽: 시점 제목 / 오른쪽: 점수판·카드 / 아래: 시점 버튼·안내.
func build() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# 3D 화면이 주인공이 되도록 테두리·패널은 차분하게 둔다.
	var top := PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 28
	top.offset_top = 24
	top.offset_right = -28
	top.add_theme_stylebox_override("panel", panel_style(Color(0.04, 0.09, 0.075, 0.92), Color("53604b"), 10))
	root.add_child(top)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 18)
	top.add_child(top_row)
	var wordmark := label("다 티", 29, GOLD)
	top_row.add_child(wordmark)
	var subtitle := label("소셜 클럽   /   3D 디자인 시안", 12, MUTED)
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(subtitle)
	var version := label("제1호     •     고도 엔진 4.6", 12, MUTED)
	top_row.add_child(version)
	var title_box := VBoxContainer.new()
	title_box.position = Vector2(44, 124)
	title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title_box)
	view_title = label("좋은 밤은 여기서 시작돼요.", 31)
	title_box.add_child(view_title)
	view_description = label("따뜻한 나무, 은은한 놋쇠, 그리고 약간의 승부욕.", 14, MUTED)
	title_box.add_child(view_description)
	var score_panel := PanelContainer.new()
	score_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	score_panel.offset_left = -254
	score_panel.offset_right = -28
	score_panel.offset_top = 124
	score_panel.add_theme_stylebox_override("panel", panel_style(Color(0.04, 0.09, 0.075, 0.92), Color("53604b")))
	root.add_child(score_panel)
	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 9)
	score_panel.add_child(stats)
	stats.add_child(label("연습  /  혼자", 12, GOLD))
	turn_label = label("1번째 차례  ·  0 / 3발", 14, MUTED)
	stats.add_child(turn_label)
	var score_row := HBoxContainer.new()
	stats.add_child(score_row)
	score_value = label("000", 58)
	score_row.add_child(score_value)
	var pts := label("점", 13, GOLD)
	pts.size_flags_vertical = Control.SIZE_SHRINK_END
	score_row.add_child(pts)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	stats.add_child(row)
	for i in range(3):
		var dart := label("—", 18, MUTED)
		dart.custom_minimum_size.x = 50
		row.add_child(dart)
		dart_labels.append(dart)
	result_label = label("자리가 준비됐어요.", 14, GOLD)
	stats.add_child(result_label)
	var line := HSeparator.new()
	stats.add_child(line)
	stats.add_child(label("예시 카드  ·  연산", 11, MUTED))
	card_button = button("Q  /  다음 한 발 ×2", func(): card_requested.emit())
	card_button.tooltip_text = "연산 카드 예시: 다음 한 발 ×2. 차례당 1회, 빗나가도 소비. 연습용 규칙."
	stats.add_child(card_button)
	action_button = button("투척 자리로  →", func(): next_requested.emit())
	stats.add_child(action_button)
	var nav := HBoxContainer.new()
	nav.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	nav.position = Vector2(28, -132)
	nav.add_theme_constant_override("separation", 8)
	root.add_child(nav)
	for i in range(4):
		var index := i
		var b := button(["1   펍 전경", "2   투척", "3   캐릭터", "4   테이블"][i], func(): view_requested.emit(index))
		nav.add_child(b)
		view_buttons.append(b)
	var bottom := HBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 40
	bottom.offset_right = -28
	bottom.offset_top = -68
	bottom.offset_bottom = -15
	bottom.add_theme_constant_override("separation", 8)
	root.add_child(bottom)
	footer = label(FOOTER_VIEW, 12, MUTED)
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(footer)
	sound_button = button("소리 켬", func(): sound_requested.emit())
	bottom.add_child(sound_button)
	bottom.add_child(button("크레딧", func(): credits_requested.emit()))
	aim_dot = Control.new()
	aim_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aim_dot.set_script(preload("res://art/showcase/showcase_reticle.gd"))
	root.add_child(aim_dot)
	aim_dot.hide()
	charge_bar = ProgressBar.new()
	charge_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	charge_bar.offset_left = -130
	charge_bar.offset_right = 130
	charge_bar.offset_top = 70
	charge_bar.offset_bottom = 84
	charge_bar.max_value = 1.0
	charge_bar.step = 0.0
	charge_bar.show_percentage = false
	charge_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar_back := panel_style(Color(0.04, 0.09, 0.075, 0.85), Color("53604b"), 7)
	var bar_fill := panel_style(GOLD, GOLD, 7)
	for style in [bar_back, bar_fill]:
		style.content_margin_top = 0
		style.content_margin_bottom = 0
	charge_bar.add_theme_stylebox_override("background", bar_back)
	charge_bar.add_theme_stylebox_override("fill", bar_fill)
	root.add_child(charge_bar)
	charge_bar.hide()
	_build_credits()
	set_view(0)


## 크레딧: 엔진 라이선스 고지를 실행 중 엔진에서 직접 읽어 보여 준다(상업 배포 시 고지 의무).
func _build_credits() -> void:
	credits = PanelContainer.new()
	credits.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	credits.offset_left = -440
	credits.offset_top = -280
	credits.offset_right = 440
	credits.offset_bottom = 280
	credits.add_theme_stylebox_override("panel", panel_style(INK, GOLD))
	root.add_child(credits)
	var column := VBoxContainer.new()
	credits.add_child(column)
	column.add_child(label("다티  /  크레딧 · 라이선스", 24, GOLD))
	var text := RichTextLabel.new()
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("normal_font_size", 14)
	# 엔진 라이선스 원문은 법적 고지라 번역하지 않고 그대로 보여 준다.
	text.text = "이 시안의 절차 생성 모델·재질·아이콘·합성 효과음은 이 프로토타입용으로 새로 만들었습니다. 기존 참고 이미지는 들어 있지 않습니다.\n\n고도 엔진(Godot Engine) — https://godotengine.org/license/\n\n" + Engine.get_license_text() + "\n\n포함된 구성 요소 고지\n" + JSON.stringify(Engine.get_copyright_info(), "  ") + "\n\n" + JSON.stringify(Engine.get_license_info(), "  ")
	column.add_child(text)
	column.add_child(button("닫기  /  Esc", func(): credits.hide()))
	credits.hide()


## 시점이 바뀔 때 제목·설명·하단 안내·선택된 버튼 강조를 바꾼다.
func set_view(index: int) -> void:
	current_view = index
	view_title.text = ["좋은 밤은 여기서 시작돼요.", "세 발을 제대로 던져 봐요.", "단골손님을 소개합니다.", "손패마다 이야기가 있어요."][index]
	view_description.text = ["따뜻한 나무, 은은한 놋쇠, 그리고 약간의 승부욕.", "화면을 클릭하면 마우스로 시선을 돌려요. 왼쪽 버튼을 꾹 눌러 충전, 놓으면 투척.", "네 가지 실루엣. 포커페이스가 수상한 한 명.", "펼친 손패, 함께 쓰는 자리, 장난칠 틈."][index]
	footer.text = FOOTER_THROW if index == 1 else FOOTER_VIEW
	for i in range(4):
		view_buttons[i].add_theme_stylebox_override("normal", panel_style(Color("3c5845") if i == index else Color("1d3c34"), GOLD if i == index else Color("395349"), 7))
	aim_dot.visible = index == 1


## showcase.gd 의 상태를 그대로 받아 점수·발수·카드 버튼·다음 버튼을 다시 그린다.
func update_state(visit: int, total: int, hits: Array, armed: bool, used: bool, busy: bool) -> void:
	score_value.text = "%03d" % total
	turn_label.text = "%d번째 차례  ·  %d / 3발" % [visit, hits.size()]
	for i in range(3):
		dart_labels[i].text = str(hits[i]) if i < hits.size() else "—"
		dart_labels[i].modulate = PAPER if i < hits.size() else MUTED
	card_button.text = "×2  준비됨" if armed else ("카드 사용함" if used else "Q  /  다음 한 발 ×2")
	card_button.disabled = used or hits.size() >= 3 or busy or current_view != 1
	action_button.text = "다음 차례  /  Space" if hits.size() >= 3 else ("다트판을 조준하세요" if current_view == 1 else "투척 자리로  →")
	action_button.disabled = busy or (current_view == 1 and hits.size() < 3)


## 조준점을 다트판 위 조준 위치(보통 화면 가운데)로 옮긴다.
func set_reticle(screen_position: Vector2, enabled: bool) -> void:
	aim_dot.position = screen_position
	aim_dot.visible = enabled and current_view == 1 and not credits.visible


## 충전 막대: value 0~1. 충전 중일 때만 보인다.
func set_charge(value: float, shown: bool) -> void:
	charge_bar.value = value
	charge_bar.visible = shown and current_view == 1 and not credits.visible
