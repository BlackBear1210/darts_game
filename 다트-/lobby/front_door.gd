extends Control
## F5 시작 화면(2026-10-30 디자인 개편). 방 연결을 소유하지 않고 선택된 값을 Main 에 전달한다.
##
## [구성] 뒤: 실제 3D 펍과 과녁(lobby_backdrop.gd) · 위: 어둡게 감싸는 그늘 · 가운데: 로고 + 메뉴(요청: 가운데 배치)
## · 오른쪽 아래: 로그인 · 왼쪽 아래: 버전. 마우스 포인터는 3D 다트(ui/dart_cursor.gd)이고 버튼을 맞히면 눌린다.
## 과녁을 클릭하면 연습 다트가 진짜로 날아가 꽂히고 점수가 뜬다(기록 없음).
##
## [페이지] home → (싱글) create / (멀티) multi → create 또는 join. 페이지는 _page 에 이름을 두고 매번 새로 만든다.

signal host_requested(settings: RoomSettings, player_name: String, password: String, port: int)
signal join_requested(player_name: String, address: String, port: int, code: String, password: String)
signal settings_requested
signal login_requested

const Style = preload("res://ui/lounge_style.gd")
const Cursor = preload("res://ui/dart_cursor.gd")
const Icon = preload("res://ui/ui_icon.gd")
const Logo = preload("res://ui/darty_logo.gd")
const Backdrop = preload("res://lobby/lobby_backdrop.gd")
const THEME_NAMES: Array[String] = ["따뜻한 펍", "네온 오락실"]
const THEME_NOTES: Array[String] = ["나무 바·당구대·바텐더", "인형뽑기·가챠·농구 오락기"]
const PRESET_ICONS: Array[String] = ["casual", "party", "classic"]

var settings := RoomSettings.new()
var player_name: String = "플레이어"
var password: String = ""
var port: int = 7000
var _backdrop: Control
var _logo: Control
var _page_root: VBoxContainer
var _content: VBoxContainer
var _status: Label
var _page: String = "home"
var _address: LineEdit
var _code: LineEdit
var _join_password: LineEdit
var _port_value: Label
var _popups: Array[Dictionary] = []
var _pointer: Control


## 화면 가장자리를 어둡게 감싸 글자가 3D 배경 위에서도 읽히게 한다(비네팅 + 아래 그라데이션).
class Shade extends Control:
	var strength: float = 1.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var ink := Color(0.07, 0.045, 0.07)
		var clear := Color(ink, 0.0)
		var dark := Color(ink, 0.82 * strength)
		var w := size.x
		var h := size.y
		# 왼쪽·가운데를 어둡게(메뉴 뒤), 오른쪽 과녁은 밝게 남긴다.
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w * 0.72, 0), Vector2(w * 0.72, h), Vector2(0, h)]),
			PackedColorArray([dark, Color(ink, 0.25 * strength), Color(ink, 0.25 * strength), dark]))
		draw_polygon(PackedVector2Array([Vector2(0, h * 0.62), Vector2(w, h * 0.62), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([clear, clear, Color(ink, 0.9), Color(ink, 0.9)]))
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h * 0.16), Vector2(0, h * 0.16)]),
			PackedColorArray([Color(ink, 0.7), Color(ink, 0.7), clear, clear]))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Style.theme()
	# 화면 없는 서버·검사에서는 3D 배경을 만들지 않는다(펍 장면 로딩 시간 절약).
	if DisplayServer.get_name() != "headless":
		_backdrop = Backdrop.new()
		_backdrop.name = "Backdrop"
		add_child(_backdrop)
		_backdrop.scored.connect(_show_score_popup)
	add_child(Shade.new())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_page_root = VBoxContainer.new()
	_page_root.alignment = BoxContainer.ALIGNMENT_CENTER
	_page_root.add_theme_constant_override("separation", 6)
	center.add_child(_page_root)
	_logo = Logo.new()
	_page_root.add_child(_logo)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 14)
	_page_root.add_child(_content)
	_corner_items()
	_pointer = Cursor.new()
	_pointer.empty_target = func(point: Vector2) -> bool:
		return _page == "home" and _backdrop != null and _backdrop.throw_at(point)
	add_child(_pointer)
	show_home()


func _corner_items() -> void:
	var login := Button.new()
	login.theme_type_variation = "SecondaryButton"
	login.text = "게스트로 플레이 중  ·  로그인"
	login.icon = null
	login.pressed.connect(func() -> void: login_requested.emit())
	add_child(login)
	login.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	login.offset_left = -440
	login.offset_right = -48
	login.offset_top = -92
	login.offset_bottom = -36
	var badge := Icon.make("login", 30, Style.CREAM)
	badge.position = Vector2(16, 12)
	login.add_child(badge)
	login.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var version := Style.label(self, "DARTY  ·  프로토타입 2026.10  ·  LAN 1–4명", 17, Style.MUTED)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	version.offset_left = 48
	version.offset_right = 700
	version.offset_top = -66
	version.offset_bottom = -36
	var tip := Style.label(self, "TIP  ·  오른쪽 과녁을 클릭하면 연습 다트가 진짜로 날아가요", 17, Style.GOLD)
	tip.name = "BoardTip"
	tip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	tip.offset_left = -640
	tip.offset_right = -48
	tip.offset_top = -130
	tip.offset_bottom = -100
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tip.add_theme_color_override("font_outline_color", Style.INK)
	tip.add_theme_constant_override("outline_size", 6)


func _process(delta: float) -> void:
	var tip := get_node_or_null("BoardTip") as Label
	if tip != null:
		tip.visible = _page == "home" and _backdrop != null
	for popup in _popups.duplicate():
		popup.age += delta
		var label: Label = popup.label
		label.position = popup.at + Vector2(-label.size.x * 0.5, -60.0 - ease(minf(1.0, popup.age / 1.4), 0.3) * 70.0)
		label.modulate.a = clampf(2.0 - popup.age, 0.0, 1.0)
		label.scale = Vector2.ONE * (1.0 + maxf(0.0, 0.25 - popup.age) * 1.6)
		if popup.age > 2.0:
			label.queue_free()
			_popups.erase(popup)


## 연습 다트 점수를 과녁 위에 띄운다.
func _show_score_popup(text: String, at: Vector2) -> void:
	var label := Style.heading(self, text, 44, Style.GOLD if text.contains("불") or text.contains("트리플") else Style.CREAM)
	label.pivot_offset = Vector2(120, 30)
	_popups.append({"label": label, "at": at, "age": 0.0})


## 페이지 내용을 비우고 제목을 단다. home 에서만 큰 로고를 보인다.
func _clear(title: String, subtitle: String) -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_status = null
	_logo.visible = _page == "home"
	if _page == "home":
		_logo.replay()
		return
	var heading := Style.heading(_content, title, 46, Style.CREAM)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := Style.label(_content, subtitle, 19, Style.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func show_home() -> void:
	_page = "home"
	_clear("", "")
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 16)
	menu.custom_minimum_size.x = 600
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content.add_child(menu)
	_menu_button(menu, "single", "싱글 플레이", "혼자 연습 · 봇 0~3명과 한 판", func() -> void: _create(true))
	_menu_button(menu, "multi", "멀티 플레이", "2~4명 · 방 만들기 / 초대 코드로 참가", _multi)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	menu.add_child(row)
	var options := Style.secondary(row, "설정", func() -> void: settings_requested.emit())
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.icon = null
	_attach_icon(options, "settings")
	var leave := Style.secondary(row, "나가기", func() -> void: get_tree().quit())
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_attach_icon(leave, "exit")
	_status_label(menu)


## 큰 메뉴 버튼: 왼쪽 아이콘 동그라미 + 굵은 제목 + 작은 설명. 글자 노드는 클릭을 통과시킨다(버튼이 받는다).
func _menu_button(parent: Node, icon_id: String, title: String, detail: String, action: Callable) -> Button:
	var button := Style.button(parent, "", action)
	button.custom_minimum_size = Vector2(600, 98)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 18)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 26
	row.offset_right = -26
	button.add_child(row)
	var disc := Panel.new()
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.custom_minimum_size = Vector2(64, 64)
	disc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	disc.add_theme_stylebox_override("panel", Style.flat(Style.INK, Style.INK, 0, 32, 0))
	row.add_child(disc)
	var icon := Icon.make(icon_id, 40, Style.CREAM)
	icon.position = Vector2(12, 12)
	disc.add_child(icon)
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 0)
	row.add_child(words)
	var heading := Style.label(words, title, 32, Style.INK)
	heading.add_theme_font_override("font", Style.font("heading"))
	Style.label(words, detail, 17, Color(Style.INK, 0.72))
	var arrow := Style.label(row, "→", 34, Style.INK)
	arrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return button


func _attach_icon(button: Button, icon_id: String) -> void:
	var icon := Icon.make(icon_id, 26, Style.CREAM)
	icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	icon.offset_left = 22
	icon.offset_top = -13
	icon.offset_right = 48
	icon.offset_bottom = 13
	button.add_child(icon)


func _multi() -> void:
	_page = "multi"
	_clear("함께 놀 준비 됐나요?", "2–4명 · 방을 만들거나 친구에게 받은 초대 코드로 들어가요")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(row)
	_choice_card(row, "multi", "방 만들기", "내가 방장 · 규칙과 맵을 정해요", func() -> void: _create(false))
	_choice_card(row, "login", "초대받은 방 참가", "초대 코드를 붙여 넣어요", _join)
	var back := Style.secondary(_content, "돌아가기", show_home)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.custom_minimum_size.x = 260
	_attach_icon(back, "back")
	_status_label(_content)


## 큰 정사각 선택 카드(멀티 화면).
func _choice_card(parent: Node, icon_id: String, title: String, detail: String, action: Callable) -> Button:
	var card := Style.button(parent, "", action)
	card.custom_minimum_size = Vector2(340, 250)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 10)
	card.add_child(column)
	var icon := Icon.make(icon_id, 76, Style.INK)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(icon)
	var heading := Style.label(column, title, 32, Style.INK)
	heading.add_theme_font_override("font", Style.font("heading"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var note := Style.label(column, detail, 17, Color(Style.INK, 0.7))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return card


func _create(solo: bool, reset: bool = true) -> void:
	_page = "create"
	settings.social_lobby = true
	settings.solo = solo
	if reset:
		settings.capacity = 4
		settings.bot_count = 3 if solo else 0
		password = ""
	_clear("혼자서도, 재밌게" if solo else "오늘의 방 만들기", "입장한 뒤 맵 안의 모니터(방장)에서 세부 규칙을 더 바꿀 수 있어요")
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1180, 0)
	_content.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	panel.add_child(body)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 34)
	body.add_child(columns)
	# 왼쪽: 놀이 방식(프리셋) + 맵 테마 카드.
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 560
	left.add_theme_constant_override("separation", 12)
	columns.add_child(left)
	Style.section(left, "놀이 방식", Style.GOLD)
	var presets := ButtonGroup.new()
	for index in range(RoomSettings.PRESETS.size()):
		var preset_index := index
		_option_card(left, presets, PRESET_ICONS[index], RoomSettings.PRESETS[index], RoomSettings.DESCRIPTIONS[index],
			settings.preset == index, func() -> void:
				settings.apply_preset(preset_index)
				_create(solo, false))
	Style.section(left, "맵 테마", Style.MINT)
	var themes := HBoxContainer.new()
	themes.add_theme_constant_override("separation", 14)
	left.add_child(themes)
	var theme_group := ButtonGroup.new()
	for index in range(THEME_NAMES.size()):
		var theme_index := index
		var card := _option_card(themes, theme_group, ["pub", "arcade"][index], THEME_NAMES[index], THEME_NOTES[index],
			settings.theme_id == index, func() -> void:
				settings.theme_id = theme_index
				_create(solo, false))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 오른쪽: 방 정보.
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 520
	right.add_theme_constant_override("separation", 12)
	columns.add_child(right)
	Style.section(right, "방 정보", Style.PINK)
	_name_field(right)
	var room_name := LineEdit.new()
	room_name.text = settings.room_name
	room_name.max_length = 32
	room_name.text_changed.connect(func(v: String) -> void: settings.room_name = v)
	Style.row(right, "방 이름", room_name)
	if solo:
		Style.row(right, "연습 상대 봇", _stepper(settings.bot_count, 0, 3, func(v: int) -> void:
			settings.bot_count = v
			settings.capacity = v + 1))
	else:
		Style.row(right, "최대 인원", _stepper(settings.capacity, 2, 4, func(v: int) -> void: settings.capacity = v))
		Style.row(right, "비공개 · 초대 코드 필수", Style.toggle(settings.private_room, func(v: bool) -> void: settings.private_room = v))
		var pass_input := LineEdit.new()
		pass_input.secret = true
		pass_input.text = password
		pass_input.placeholder_text = "비워두면 비밀번호 없음"
		pass_input.max_length = 64
		pass_input.text_changed.connect(func(v: String) -> void: password = v)
		Style.row(right, "방 비밀번호", pass_input)
		_port_value = null
		Style.row(right, "접속 포트 (고급)", _stepper(port, 1024, 65535, func(v: int) -> void: port = v))
		Style.label(right, "같은 와이파이·LAN 친구는 초대 코드만 있으면 들어와요.", 16, Style.MUTED)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 18)
	body.add_child(actions)
	var back := Style.secondary(actions, "돌아가기", show_home if solo else _multi)
	back.custom_minimum_size.x = 240
	_attach_icon(back, "back")
	var go := Style.button(actions, "방 만들고 입장하기  →", func() -> void:
		settings.sanitize()
		host_requested.emit(settings, player_name, password, port))
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.custom_minimum_size.y = 66
	go.add_theme_font_size_override("font_size", 26)
	_status_label(body)


## 고를 수 있는 카드(같은 묶음에서 하나만 눌린다). 아이콘 + 제목 + 한 줄 설명.
func _option_card(parent: Node, group: ButtonGroup, icon_id: String, title: String, detail: String, selected: bool, action: Callable) -> Button:
	var card := Button.new()
	card.theme_type_variation = "ChoiceButton"
	card.toggle_mode = true
	card.button_group = group
	card.button_pressed = selected
	card.custom_minimum_size = Vector2(0, 88)
	card.pressed.connect(action)
	parent.add_child(card)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 18
	row.offset_right = -14
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	var ink: Color = Style.INK if selected else Style.CREAM
	var icon := Icon.make(icon_id, 44, ink)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	row.add_child(words)
	var heading := Style.label(words, title, 22, ink)
	heading.add_theme_font_override("font", Style.font("heading"))
	var note := Style.label(words, detail, 15, Color(ink, 0.75))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return card


## − 값 + 고르기(작은 화살표 숫자칸 대신 큰 버튼).
func _stepper(value: int, low: int, high: int, action: Callable) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var shown := Label.new()
	var minus := Style.secondary(box, "−", func() -> void: pass)
	minus.custom_minimum_size = Vector2(58, 50)
	shown.text = str(value)
	shown.custom_minimum_size = Vector2(110, 50)
	shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	shown.add_theme_font_override("font", Style.font("logo"))
	shown.add_theme_font_size_override("font_size", 30)
	shown.add_theme_color_override("font_color", Style.CREAM)
	box.add_child(shown)
	var plus := Style.secondary(box, "+", func() -> void: pass)
	plus.custom_minimum_size = Vector2(58, 50)
	var change := func(step: int) -> void:
		var next := clampi(int(shown.text) + step, low, high)
		shown.text = str(next)
		action.call(next)
	minus.pressed.connect(change.bind(-1))
	plus.pressed.connect(change.bind(1))
	return box


func _name_field(parent: Node) -> void:
	var field := LineEdit.new()
	field.text = player_name
	field.max_length = 20
	field.text_changed.connect(func(v: String) -> void: player_name = v)
	Style.row(parent, "플레이어 이름", field)


func _join() -> void:
	_page = "join"
	_clear("초대받은 자리로", "초대 코드를 붙여 넣으면 방장 주소와 포트가 저절로 채워져요")
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 0)
	_content.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	panel.add_child(body)
	Style.section(body, "초대 코드", Style.GOLD)
	_code = LineEdit.new()
	_code.placeholder_text = "DARTY-주소-포트-방코드"
	_code.custom_minimum_size.y = 68
	_code.add_theme_font_size_override("font_size", 28)
	_code.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code.text_changed.connect(_parse_invite)
	body.add_child(_code)
	Style.section(body, "내 정보 · 접속", Style.MINT)
	_name_field(body)
	_address = LineEdit.new()
	_address.text = "127.0.0.1"
	Style.row(body, "방장 주소", _address)
	var port_box := _stepper(port, 1024, 65535, func(v: int) -> void: port = v)
	_port_value = port_box.get_child(1) as Label
	Style.row(body, "접속 포트", port_box)
	_join_password = LineEdit.new()
	_join_password.secret = true
	_join_password.placeholder_text = "비밀번호가 없으면 비워 두세요"
	Style.row(body, "방 비밀번호", _join_password)
	Style.label(body, "같은 네트워크에서 바로 연결해요. 외부 인터넷 접속은 방장의 주소·UDP 포트 설정이 필요해요.", 16, Style.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 18)
	body.add_child(actions)
	var back := Style.secondary(actions, "돌아가기", _multi)
	back.custom_minimum_size.x = 220
	_attach_icon(back, "back")
	var go := Style.button(actions, "참가하기  →", func() -> void:
		var parts := _code.text.strip_edges().split("-")
		var code: String = parts[-1] if parts.size() == 4 else _code.text.strip_edges()
		join_requested.emit(player_name, _address.text, port, code, _join_password.text))
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.custom_minimum_size.y = 62
	go.add_theme_font_size_override("font_size", 24)
	_status_label(body)


func _status_label(parent: Node) -> void:
	_status = Style.label(parent, "", 18, Style.PINK)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.custom_minimum_size.x = 560
	_status.add_theme_color_override("font_outline_color", Style.INK)
	_status.add_theme_constant_override("outline_size", 6)


func _parse_invite(value: String) -> void:
	var parts := value.strip_edges().split("-")
	if parts.size() == 4 and parts[0].to_upper() == "DARTY" and parts[2].is_valid_int():
		_address.text = parts[1]
		port = clampi(int(parts[2]), 1024, 65535)
		if _port_value != null: _port_value.text = str(port)


func show_status(value: String, busy: bool = false) -> void:
	if is_instance_valid(_status): _status.text = value
	_set_busy(_content, busy)


func _set_busy(node: Node, busy: bool) -> void:
	for item in node.get_children():
		if item is Button and item.text.contains("→"): item.disabled = busy
		_set_busy(item, busy)
