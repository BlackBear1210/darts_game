extends CanvasLayer
## ESC 개인 설정과 방장 모니터 설정. 적용 요청은 반드시 NetworkSession의 검증을 지난다.
signal closed
signal leave_requested
const Style = preload("res://ui/lounge_style.gd")
const Preferences = preload("res://ui/player_preferences.gd")
const Catalog = preload("res://game/card_round/rules/card_catalog.gd")
var session: NetworkSession
var developer: bool = false
var mode: String = "personal"
var _root: Control
var _body: VBoxContainer
var _draft: RoomSettings
var _note: Label

func _ready() -> void:
	layer = 30
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = Style.theme()
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.035, 0.06, 0.86)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(980, 860)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	# 머리: 큰 제목 + 탭(고른 탭은 청록 카드).
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	var title := Style.heading(header, "설정", 44)
	title.custom_minimum_size.x = 150
	var group := ButtonGroup.new()
	_tab(header, group, "개인 설정", "personal")
	if session != null and session.is_room_host():
		_tab(header, group, "방장 · 게임 규칙", "room")
		if developer and session.is_host():
			_tab(header, group, "개발자", "developer")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 12)
	scroll.add_child(_body)
	_note = Style.label(column, "", 17, Style.GOLD)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	column.add_child(buttons)
	if session != null and session.local_peer_id != 0:
		Style.secondary(buttons, "방 나가기", func() -> void: leave_requested.emit(); _close())
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(gap)
	Style.secondary(buttons, "닫기 · Esc", _close).custom_minimum_size.x = 180
	Style.button(buttons, "적용하고 닫기", _apply).custom_minimum_size.x = 260
	_draft = RoomSettings.from_snapshot(session.room.settings.to_snapshot()) if session != null else RoomSettings.new()
	_root.add_child(preload("res://ui/dart_cursor.gd").new())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_render()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_close()

## 위쪽 탭 하나(같은 묶음에서 하나만 눌린다).
func _tab(parent: Node, group: ButtonGroup, text: String, tab_mode: String) -> void:
	var open := func() -> void:
		mode = tab_mode
		_render()
	var tab := Style.button(parent, text, open, "ChoiceButton")
	tab.toggle_mode = true
	tab.button_group = group
	tab.button_pressed = mode == tab_mode


## 0~100% 같은 값은 끌어서 바꾸는 막대 + 숫자.
static func _slider(value: float, low: float, high: float, step: float, action: Callable) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.custom_minimum_size.x = 300
	box.add_theme_constant_override("separation", 12)
	var bar := HSlider.new()
	bar.min_value = low
	bar.max_value = high
	bar.step = step
	bar.value = value
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(bar)
	var shown := Style.label(box, str(roundi(value)), 20)
	shown.custom_minimum_size.x = 48
	shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.value_changed.connect(func(v: float) -> void: shown.text = str(roundi(v)))
	bar.value_changed.connect(action)
	return box


func _render() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_note.text = ""
	if mode == "personal": _personal()
	elif mode == "developer": _developer()
	else: _room()

func _personal() -> void:
	Style.section(_body, "사운드", Style.PINK)
	Style.row(_body, "전체 볼륨 %", _slider(Preferences.master * 100, 0, 100, 5, func(v: float) -> void: Preferences.master = v / 100; Preferences.apply()))
	Style.row(_body, "주크박스 음악 %", _slider(Preferences.music * 100, 0, 100, 5, func(v: float) -> void: Preferences.music = v / 100))
	Style.row(_body, "상호작용 효과음 %", _slider(Preferences.sfx * 100, 0, 100, 5, func(v: float) -> void: Preferences.sfx = v / 100))
	Style.section(_body, "그래픽 · UI", Style.MINT)
	Style.row(_body, "전체 화면", Style.toggle(Preferences.fullscreen, func(v: bool) -> void: Preferences.fullscreen = v))
	Style.row(_body, "그래픽 품질", Style.select(["가벼움", "기본", "높음"], Preferences.quality, func(v: int) -> void: Preferences.quality = v))
	Style.row(_body, "경기 HUD 크기 %", Style.number(Preferences.ui_scale * 100, 80, 130, 10, func(v: float) -> void: Preferences.ui_scale = v / 100))
	Style.row(_body, "카드 시각 효과", Style.toggle(Preferences.visual_effects, func(v: bool) -> void: Preferences.visual_effects = v))
	Style.row(_body, "움직임 줄이기", Style.toggle(Preferences.reduced_motion, func(v: bool) -> void: Preferences.reduced_motion = v))
	Style.label(_body, "시각 효과를 꺼도 카드의 게임 판정은 유지돼요.", 16, Style.MUTED)
	Style.section(_body, "게임 · 조작", Style.GOLD)
	Style.row(_body, "마우스 감도", Style.number(Preferences.sensitivity, 0.3, 2.0, 0.1, func(v: float) -> void: Preferences.sensitivity = v))
	Style.row(_body, "상호작용 / 착석", Style.select(["F", "R"], 0 if Preferences.interact_key == KEY_F else 1, func(v: int) -> void: Preferences.interact_key = KEY_F if v == 0 else KEY_R))
	Style.label(_body, "WASD 이동 · Enter 참여 · A/D 훔쳐보기 · S 의자 회전 · 병·캡슐 들고 좌클릭 = 마시기·열기\n다트 턴 중 Q·E / 1–7 카드 꺼내기 · Enter 사용 · Tab 무효 대상", 17, Style.MUTED)

func _room() -> void:
	Style.section(_body, "이 방의 플레이 규칙", Style.MINT)
	if not session.room.settings.solo:
		# ESC 모달을 연 상태에서도 초대 정보를 바로 확인하고 복사할 수 있다.
		var code := LineEdit.new()
		code.text = session.invitation()
		code.editable = false
		Style.row(_body, "초대 코드", code)
		Style.secondary(_body, "초대 코드 복사", func() -> void:
			DisplayServer.clipboard_set(session.invitation())
			_note.text = "초대 코드를 복사했어요. 친구에게 전달하세요.")
	Style.row(_body, "한 번에 설정", Style.select(RoomSettings.PRESETS, _draft.preset, func(v: int) -> void: _draft.apply_preset(v); _render()))
	var description := Style.label(_body, RoomSettings.DESCRIPTIONS[_draft.preset], 17, Style.MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Style.secondary(_body, "프리셋 설명 접기 / 펼치기", func() -> void: description.visible = not description.visible)
	Style.section(_body, "승리 · 라운드 · 시간", Style.GOLD)
	Style.row(_body, "승리 조건", Style.select(["라운드 종료 · 최고 점수", "목표 점수 먼저 도달", "카운트다운 · 정확히 0"], _draft.win_mode, func(v: int) -> void: _draft.win_mode = v))
	Style.row(_body, "목표 / 시작 점수", Style.number(_draft.target_score, 50, 1000, 10, func(v: float) -> void: _draft.target_score = int(v)))
	Style.row(_body, "최대 라운드", Style.number(_draft.rounds, 1, 20, 1, func(v: float) -> void: _draft.rounds = int(v)))
	Style.row(_body, "다트 턴 · 초", Style.number(_draft.dart_seconds, 5, 120, 5, func(v: float) -> void: _draft.dart_seconds = v))
	Style.section(_body, "카드", Style.PINK)
	Style.row(_body, "카드 사용", Style.toggle(_draft.cards_enabled, func(v: bool) -> void: _draft.cards_enabled = v))
	Style.row(_body, "특수 카드 포함", Style.toggle(_draft.special_cards, func(v: bool) -> void: _draft.special_cards = v))
	Style.row(_body, "특수 카드 추첨 확률 %", Style.number(_draft.special_chance, 0, 100, 5, func(v: float) -> void: _draft.special_chance = v))
	Style.section(_body, "맵 · 분위기 · 방해", Style.MINT)
	Style.row(_body, "맵 테마", Style.select(["따뜻한 펍", "네온 오락실"], _draft.theme_id, func(v: int) -> void: _draft.theme_id = v))
	Style.row(_body, "음주 연출", Style.toggle(_draft.alcohol, func(v: bool) -> void: _draft.alcohol = v))
	Style.row(_body, "취기 강도 · 0 꺼짐 / 3 강함", Style.number(_draft.intoxication, 0, 3, 1, func(v: float) -> void: _draft.intoxication = v))
	Style.row(_body, "카드를 받을 때 함께 마시기", Style.toggle(_draft.drink_on_deal, func(v: bool) -> void: _draft.drink_on_deal = v))
	Style.row(_body, "소품 잡기 / 방해", Style.toggle(_draft.props_enabled, func(v: bool) -> void: _draft.props_enabled = v))
	Style.row(_body, "공간 효과음 %", Style.number(_draft.object_volume * 100, 0, 100, 5, func(v: float) -> void: _draft.object_volume = v / 100))
	if session.room.phase != RoomState.Phase.LOBBY:
		_note.text = "경기 중 변경: 라운드 상한, 다음 턴부터 제한 시간, 다음 배부부터 특수 카드 확률. 나머지는 대기실에서 바꿔요."

func _developer() -> void:
	Style.section(_body, "개발자 · 밸런스 실험실", Style.PINK)
	Style.label(_body, "로컬 개발 실행(--developer) 방장만 사용 가능 · 수치는 팀 미확정", 17, Style.MUTED)
	Style.row(_body, "병 적중 스턴 · 초", Style.number(_draft.hit_stun, 0, 3, 0.1, func(v: float) -> void: _draft.hit_stun = v))
	Style.row(_body, "빗나감 회수 대기 · 초", Style.number(_draft.miss_cooldown, 0.5, 10, 0.5, func(v: float) -> void: _draft.miss_cooldown = v))
	for entry: Dictionary in Catalog.CARDS:
		var id: String = entry.id
		var line := HBoxContainer.new()
		_body.add_child(line)
		var caption := Style.label(line, str(entry.name), 18)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(Style.toggle(not _draft.disabled_cards.has(id), func(v: bool) -> void:
			if v: _draft.disabled_cards.erase(id)
			elif not _draft.disabled_cards.has(id): _draft.disabled_cards.append(id)))
		line.add_child(Style.number(float(_draft.card_weights.get(id, 1.0)), 0.01, 100, 0.1, func(v: float) -> void: _draft.card_weights[id] = v))
	Style.label(_body, "오른쪽 수치는 같은 카드 종류 안의 상대 가중치입니다.\n카드 추가·제외는 이 방의 추첨 목록에만 적용됩니다.", 17, Style.MUTED)

func _apply() -> void:
	if mode == "personal":
		Preferences.save()
	elif session != null:
		_draft.sanitize()
		session.change_settings(_draft.to_snapshot())
	_close()

func _close() -> void:
	closed.emit()
	queue_free()
