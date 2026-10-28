extends CanvasLayer
## 카드 라운드 시연의 화면 UI. 3D 장면 위에 얹는 글자·판넬만 맡고 규칙은 모른다(card_round.gd 가 값을 넣어 준다).
## 배치(1920×1080 기준): 위 가운데 = 라운드 표시(롤 아레나 참고) · 왼쪽 위 = 점수판 · 오른쪽 = 효과 목록(누가 누구에게 무엇을) ·
## 가운데 = 배너·알림 · 오른쪽 아래 = 꺼내 든 카드 설명 · 아래 = 조작 안내. Esc = 설정, 경기 끝 = 결과.

const CardCatalog = preload("res://game/card_round/rules/card_catalog.gd")
const CardFaces = preload("res://game/card_round/cards/card_faces.gd")
const Rules = preload("res://game/card_round/rules/round_rules.gd")
const RoundTracker = preload("res://game/card_round/ui/round_tracker.gd")

signal setting_changed(key: String, value: int)
signal restart_requested

## 설정 항목. 값 = 옵션 번호. card_round.gd 가 번호를 규칙 값으로 바꾼다.
const SETTINGS: Array[Dictionary] = [
	{"key": "mark", "label": "쓴 카드 표시", "options": ["빨간 페인트 X (기본)", "불에 그을림"]},
	{"key": "shuffle", "label": "섞기 모션", "options": ["매번 무작위", "정석 리플", "마술사", "딜러"]},
	{"key": "draw", "label": "나눠 줄 때 뽑는 곳", "options": ["맨 위", "가운데", "맨 아래", "무작위"]},
	{"key": "reward", "label": "방해 성공 보상", "options": ["점수 +15", "라운드 한정 카드", "무작위"]},
	{"key": "win", "label": "승리 조건 (새 게임부터)", "options": ["7라운드 최고점", "300점 먼저", "500 → 0 딱 맞추기"]},
	{"key": "speed", "label": "진행 속도", "options": ["보통", "1.5배", "2배"]},
	{"key": "voice", "label": "합성 목소리", "options": ["켜기", "끄기"]},
]
const KEY_HELP := "1~7 카드 꺼내기(한 번 더 = 내리기) · 8·9 보상 카드 · F 쓰기 · Tab 대상 바꾸기\nWASD 이동 · E 앉기/일어나기 · 왼클릭 길게 = 던지기 · V 말하기 · C 전체 보기 · Shift 빨리 감기 · Alt 마우스 꺼내기"
## 오른쪽 효과 패널: 맨 위 연산 줄은 최근 6개, 아래 목록은 최근 8개만 보인다(다 보이면 화면 아래로 넘친다).
const EFFECT_LINE_MAX := 6
const EFFECT_ROWS_MAX := 8
const STATE_TEXT: Array[String] = ["대기", "적용 중", "끝", "무효", "만료"]
const STATE_COLORS: Array[Color] = [Color("f0e6cf"), Color("ffd27a"), Color("9a958a"), Color("e0574f"), Color("6f6a5c")]

static var _regular: SystemFont

var tracker: RoundTracker
var settings_open: bool = false
var _root: Control
var _scores: RichTextLabel
var _turn: Label
var _effects: RichTextLabel
var _effects_text: String = ""
var _scores_text: String = ""
var _banner: PanelContainer
var _banner_title: Label
var _banner_sub: Label
var _toasts: VBoxContainer
var _card_panel: PanelContainer
var _card_art: TextureRect
var _card_name: Label
var _card_info: Label
var _card_text: Label
var _card_target: Label
var _card_status: Label
var _card_bar: ProgressBar
var _prompt: Label
var _crosshair: Control
var _charge: ProgressBar
var _settings: PanelContainer
var _options: Dictionary = {}
var _announce: PanelContainer
var _announce_rows: VBoxContainer
var _results: PanelContainer
var _results_body: RichTextLabel


## 보통 굵기 한글 글꼴(시스템 글꼴, 한 번만 만든다).
static func regular_font() -> Font:
	if _regular == null:
		_regular = SystemFont.new()
		_regular.font_names = PackedStringArray(["Malgun Gothic", "Apple SD Gothic Neo", "Noto Sans CJK KR", "sans-serif"])
		_regular.font_weight = 500
	return _regular


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme: Theme = PubTheme.build().duplicate()
	theme.default_font = regular_font()
	_root.theme = theme
	add_child(_root)
	tracker = RoundTracker.new()
	tracker.position = Vector2(0, 14)
	_root.add_child(tracker)
	_turn = _label(30, PubTheme.PAPER, true)
	_turn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_turn.position.y = 104
	_turn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_turn.add_theme_color_override("font_outline_color", PubTheme.INK)
	_turn.add_theme_constant_override("outline_size", 10)
	_root.add_child(_turn)
	_build_scores()
	_build_effects()
	_build_banner()
	_build_card_panel()
	_build_aim()
	_build_prompt()
	_build_settings()
	_build_announce()
	_build_results()


# --- 점수판·차례 ---

## rows: [{seat, name, score, hand, active, local, chips: PackedStringArray}]
func set_scores(title: String, rows: Array) -> void:
	var lines := PackedStringArray(["[font_size=20][color=#d7bb7f]%s[/color][/font_size]" % title])
	for row: Dictionary in rows:
		var seat: int = row.seat
		var color: String = PlayerLook.COLORS[seat].lightened(0.3).to_html(false)
		var marker: String = "▶ " if row.active else "   "
		var name_text: String = "%s%d번 %s%s" % [PlayerLook.SYMBOLS[seat] + " ", seat + 1, row.name, " (나)" if row.local else ""]
		lines.append("[font_size=26]%s[color=#%s][b]%s[/b][/color]  [color=#f0e6cf][b]%d[/b][/color][/font_size]  [font_size=18][color=#9a958a]카드 %d장[/color][/font_size]" % [marker, color, name_text, row.score, row.hand])
		var chips: PackedStringArray = row.get("chips", PackedStringArray())
		if not chips.is_empty():
			lines.append("[font_size=18]      [color=#ffb36b]%s[/color][/font_size]" % "  ".join(chips))
	var text: String = "\n".join(lines)
	if text != _scores_text:
		_scores_text = text
		_scores.text = text


## 위 가운데 차례 표시 글.
func set_turn(text: String) -> void:
	_turn.text = text


## 위 라운드 표시(카드·다트 단계 점)를 맞춘다. total_rounds = 0 이면 끝 라운드 모름.
func set_round(round_value: int, stage: int, total_rounds: int) -> void:
	tracker.total_rounds = total_rounds
	tracker.set_stage(round_value, stage)


# --- 효과 목록(오른쪽) ---

## 이번 라운드에 쓴 카드 전부. 맨 위 한 줄 = "+10 [1번 삐죽이]  −20 [2번 바가지]" 처럼 대상별 계산을 이어 쓴다(사용자 기획 2026-10-28).
func show_effects(rules: Rules) -> void:
	var line := PackedStringArray()
	var rows := PackedStringArray()
	for effect: Rules.Effect in rules.effects:
		var target: String = _seat_tag(rules, effect.target)
		var value: String = _effect_value(effect)
		# 맨 위 한 줄은 연산만(+10 [1번] −20 [2번]). 이름 효과(가림판 등)는 아래 목록에만 둔다.
		if effect.kind in ["math", "random_math", "nullify"]:
			line.append("[color=#ffe3a3]%s[/color] %s" % [value, target])
		var state_color: String = STATE_COLORS[effect.state].to_html(false)
		var detail: String = STATE_TEXT[effect.state] if effect.result.is_empty() else effect.result
		var from: String = "" if effect.source == effect.target else "  [color=#9a958a]← %s[/color]" % _seat_tag(rules, effect.source, false)
		var body: String = "%s %s%s" % [value, target, from]
		if effect.state == Rules.EffectState.NULLIFIED:
			body = "[s]%s %s[/s]" % [value, target]
		rows.append("[font_size=21]%s[/font_size]\n[font_size=17][color=#%s]     %s · %s[/color][/font_size]" % [body, state_color, CardCatalog.timing_text(effect.card_type), detail])
	var text: String = "[font_size=20][color=#d7bb7f]카드 효과 · %d라운드[/color][/font_size]\n" % rules.round_number
	if rows.is_empty():
		text += "[font_size=18][color=#9a958a]아직 쓴 카드가 없다.\n1~7로 꺼내 들고 F로 쓴다.[/color][/font_size]"
	else:
		# 화면 아래로 넘치지 않게 최근 것만 보인다.
		var hidden_line: int = maxi(line.size() - EFFECT_LINE_MAX, 0)
		var hidden_rows: int = maxi(rows.size() - EFFECT_ROWS_MAX, 0)
		var shown_line: String = "  ".join(line.slice(hidden_line))
		if hidden_line > 0:
			shown_line = "[color=#9a958a]…[/color]  " + shown_line
		if line.is_empty():
			shown_line = "[font_size=18][color=#9a958a]연산 카드 없음[/color][/font_size]"
		var shown_rows: String = "\n".join(rows.slice(hidden_rows))
		if hidden_rows > 0:
			shown_rows = "[font_size=16][color=#9a958a]… 앞의 %d개 줄임[/color][/font_size]\n" % hidden_rows + shown_rows
		text += "[font_size=24]%s[/font_size]\n[font_size=10] [/font_size]\n%s" % [shown_line, shown_rows]
	if text != _effects_text:
		_effects_text = text
		_effects.text = text


## 효과 목록 한 줄의 값 글(계산식·무효·잃음 등).
func _effect_value(effect: Rules.Effect) -> String:
	match effect.kind:
		"math", "random_math", "nullify":
			return effect.label
		"lost":
			return "✕ " + effect.label
	return "「%s」" % effect.label


## 자리 이름표(자리 색 글자). bracket = [1번 이름] 꼴, 아니면 모양 기호 + 이름.
func _seat_tag(rules: Rules, seat: int, bracket: bool = true) -> String:
	var color: String = PlayerLook.COLORS[seat].lightened(0.3).to_html(false)
	var text: String = "%d번 %s" % [seat + 1, rules.seats[seat].name]
	return "[color=#%s]%s[/color]" % [color, "[%s]" % text if bracket else PlayerLook.SYMBOLS[seat] + text]


# --- 배너·알림 ---

## 화면 가운데 큰 글자. seconds 동안 보였다가 사라진다(await 가능).
func banner(title: String, subtitle: String = "", seconds: float = 1.6) -> void:
	_banner_title.text = title
	_banner_sub.text = subtitle
	_banner_sub.visible = not subtitle.is_empty()
	_banner.visible = true
	_banner.modulate.a = 0.0
	_banner.reset_size()
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2(1.0, 0.6)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_banner, "modulate:a", 1.0, 0.18)
	tween.tween_property(_banner, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(seconds).timeout
	var out := create_tween()
	out.tween_property(_banner, "modulate:a", 0.0, 0.25)
	await out.finished
	_banner.visible = false


## 짧은 알림 한 줄(가운데 위). 몇 초 뒤 사라진다.
func toast(text: String, color: Color = PubTheme.PAPER, seconds: float = 2.8) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", PubTheme.box(Color(PubTheme.INK, 0.86), Color(color, 0.6), 2, 10, 7))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var label := _label(21, color, true)
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	_toasts.add_child(panel)
	while _toasts.get_child_count() > 3:
		var old: Node = _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	var tween := panel.create_tween()
	tween.tween_interval(seconds)
	tween.tween_property(panel, "modulate:a", 0.0, 0.4)
	tween.tween_callback(panel.queue_free)


# --- 꺼내 든 카드 설명(오른쪽 아래) ---

## 내가 꺼내 든 카드. ratio = 쓸 수 있게 될 때까지 진행, problem = 지금 못 쓰는 이유(없으면 빈 글자).
func show_card(card_type: int, ratio: float, target_text: String, problem: String, temporary: bool) -> void:
	var data: Dictionary = CardCatalog.card(card_type)
	_card_panel.visible = true
	_card_art.texture = CardFaces.face(card_type)
	_card_name.text = str(data.name) + ("  · 라운드 한정" if temporary else "")
	_card_info.text = "%s · %s · %s" % [CardCatalog.category_name(card_type), CardCatalog.target_text(card_type), CardCatalog.timing_text(card_type)]
	_card_text.text = str(data.text)
	_card_target.text = target_text
	_card_bar.value = ratio
	if ratio < 1.0:
		_card_status.text = "준비 중… 다른 사람도 지금 이 카드를 본다"
		_card_status.add_theme_color_override("font_color", PubTheme.GOLD)
	elif problem.is_empty():
		_card_status.text = "F 로 쓰기 · 같은 숫자 키 = 내려놓기"
		_card_status.add_theme_color_override("font_color", Color("8cf0a0"))
	else:
		_card_status.text = problem
		_card_status.add_theme_color_override("font_color", Color("ff9a8a"))


## 내 카드 패널을 숨긴다(꺼내 든 카드가 없을 때).
func hide_card() -> void:
	_card_panel.visible = false


# --- 조준·안내 ---

## 조준 십자선과 충전 막대를 보이거나 숨긴다(charge = 0~1).
func set_aim(shown: bool, charge: float) -> void:
	_crosshair.visible = shown
	_charge.visible = shown and charge > 0.0
	_charge.value = charge


## 화면 아래 안내 줄(빈 글이면 숨긴다).
func set_prompt(text: String) -> void:
	_prompt.text = text
	_prompt.get_parent().visible = not text.is_empty()


# --- 충전 라운드 점수 발표 ---

## rows: [{seat, name, score, rank}] 좋은 순서. 꼴찌부터 한 줄씩 올라온다(await 가능).
func announce_scores(title: String, rows: Array, seconds_per_row: float = 0.55) -> void:
	for child in _announce_rows.get_children():
		child.queue_free()
	(_announce.get_child(0).get_child(0) as Label).text = title
	_announce.visible = true
	var labels: Array[Label] = []
	for row: Dictionary in rows:
		var label := _label(32, PlayerLook.COLORS[int(row.seat)].lightened(0.35), true)
		label.text = "%d위   %s%d번 %s   %d점" % [int(row.rank) + 1, PlayerLook.SYMBOLS[int(row.seat)], int(row.seat) + 1, row.name, int(row.score)]
		label.modulate.a = 0.0
		_announce_rows.add_child(label)
		labels.append(label)
	for i in range(labels.size() - 1, -1, -1):
		var tween := create_tween().set_parallel(true)
		tween.tween_property(labels[i], "modulate:a", 1.0, 0.2)
		labels[i].pivot_offset = Vector2(0, 20)
		labels[i].scale = Vector2(1.25, 1.25)
		tween.tween_property(labels[i], "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await get_tree().create_timer(seconds_per_row).timeout
	await get_tree().create_timer(1.4).timeout
	_announce.visible = false


# --- 설정(Esc) ---

## 설정 창의 선택 상자들을 저장된 값으로 맞춘다.
func set_settings(values: Dictionary) -> void:
	for key: String in _options:
		(_options[key] as OptionButton).select(int(values.get(key, 0)))


## 설정 창(Esc)을 열고 닫는다.
func toggle_settings(open: bool) -> void:
	settings_open = open
	_settings.visible = open


# --- 결과(경기 끝) ---

## 결과 화면을 연다(BBCode 글).
func show_results(text: String) -> void:
	_results_body.text = text
	_results.visible = true


## 결과·발표 창을 닫는다.
func hide_overlays() -> void:
	_results.visible = false
	_announce.visible = false


# --- 만들기 ---

## 왼쪽 위 점수판(승리 조건 + 자리별 줄)을 만든다.
func _build_scores() -> void:
	var panel := _panel(Color(PubTheme.INK, 0.8))
	panel.position = Vector2(20, 20)
	panel.custom_minimum_size = Vector2(470, 0)
	_root.add_child(panel)
	_scores = _rich(Vector2(450, 0))
	_scores.fit_content = true
	panel.add_child(_scores)


## 오른쪽 효과 목록 패널을 만든다.
func _build_effects() -> void:
	var panel := _panel(Color(PubTheme.INK, 0.78))
	panel.position = Vector2(1920 - 470, 120)
	panel.custom_minimum_size = Vector2(450, 0)
	_root.add_child(panel)
	_effects = _rich(Vector2(430, 0))
	_effects.fit_content = true
	panel.add_child(_effects)


## 화면 크기는 1920×1080 고정(canvas_items 늘이기)이라 가운데 맞춤은 화면 폭 상자(CenterContainer)로 한다.
## 앵커 프리셋은 부모 크기가 정해지기 전에 계산돼 판넬이 화면 밖으로 밀려난다(2026-10-28 캡처에서 확인).
func _build_banner() -> void:
	var holder := _center_holder(Vector2(0, 330), Vector2(1920, 260))
	_banner = _panel(Color(PubTheme.INK, 0.9), PubTheme.GOLD, 3)
	_banner.custom_minimum_size = Vector2(1000, 0)
	_banner.visible = false
	holder.add_child(_banner)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner.add_child(column)
	_banner_title = _label(60, PubTheme.GOLD, true)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_banner_title)
	_banner_sub = _label(26, PubTheme.PAPER)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_banner_sub)
	_toasts = VBoxContainer.new()
	_toasts.position = Vector2(0, 152)
	_toasts.size = Vector2(1920, 0)
	_toasts.add_theme_constant_override("separation", 6)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toasts)


## 오른쪽 아래 '내가 꺼내 든 카드' 패널(그림·이름·설명·대상·준비 막대)을 만든다.
func _build_card_panel() -> void:
	_card_panel = _panel(Color(PubTheme.INK, 0.92), PubTheme.GOLD, 2)
	_card_panel.position = Vector2(1920 - 700, 1080 - 330)
	_card_panel.custom_minimum_size = Vector2(680, 250)
	_card_panel.visible = false
	_root.add_child(_card_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_card_panel.add_child(row)
	_card_art = TextureRect.new()
	_card_art.custom_minimum_size = Vector2(150, 225)
	_card_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_card_art)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(480, 0)
	row.add_child(column)
	_card_name = _label(32, PubTheme.GOLD, true)
	column.add_child(_card_name)
	_card_info = _label(18, Color("b9b2a0"))
	column.add_child(_card_info)
	_card_text = _label(21, PubTheme.PAPER)
	_card_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_text.custom_minimum_size = Vector2(480, 0)
	column.add_child(_card_text)
	_card_target = _label(22, Color("ffe3a3"), true)
	column.add_child(_card_target)
	_card_bar = ProgressBar.new()
	_card_bar.max_value = 1.0
	_card_bar.show_percentage = false
	_card_bar.custom_minimum_size = Vector2(480, 12)
	column.add_child(_card_bar)
	_card_status = _label(19, PubTheme.GOLD)
	column.add_child(_card_status)


## 화면 가운데 조준 십자선과 충전 막대를 만든다.
func _build_aim() -> void:
	_crosshair = Crosshair.new()
	_crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.visible = false
	_root.add_child(_crosshair)
	_charge = ProgressBar.new()
	_charge.max_value = 1.0
	_charge.show_percentage = false
	_charge.position = Vector2(960 - 110, 600)
	_charge.custom_minimum_size = Vector2(220, 14)
	_charge.visible = false
	_root.add_child(_charge)


## 화면 아래 안내 줄을 만든다.
func _build_prompt() -> void:
	var holder := _center_holder(Vector2(0, 1080 - 62), Vector2(1920, 52))
	var panel := _panel(Color(PubTheme.INK, 0.72), Color(PubTheme.GOLD, 0.4), 1)
	holder.add_child(panel)
	_prompt = _label(21, PubTheme.PAPER)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_prompt)


## 설정 창(Esc)을 만든다: 사용 표시·섞기·뽑는 곳·보상·승리 조건·속도·목소리.
func _build_settings() -> void:
	_settings = _panel(Color(PubTheme.INK, 0.96), PubTheme.GOLD, 3)
	_settings.position = Vector2(560, 150)
	_settings.custom_minimum_size = Vector2(800, 0)
	_settings.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings.visible = false
	_root.add_child(_settings)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_settings.add_child(column)
	var title := _label(40, PubTheme.GOLD, true)
	title.text = "설정"
	column.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 10)
	column.add_child(grid)
	for item: Dictionary in SETTINGS:
		var label := _label(24, PubTheme.PAPER)
		label.text = item.label
		label.custom_minimum_size.x = 320
		grid.add_child(label)
		var option := OptionButton.new()
		option.add_theme_font_size_override("font_size", 22)
		option.custom_minimum_size = Vector2(380, 44)
		for text: String in item.options:
			option.add_item(text)
		var key: String = item.key
		option.item_selected.connect(func(index: int) -> void: setting_changed.emit(key, index))
		grid.add_child(option)
		_options[key] = option
	var help := _label(18, Color("b9b2a0"))
	help.text = KEY_HELP
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size.x = 760
	column.add_child(help)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 16)
	column.add_child(buttons)
	var restart := _button("새 게임 (설정 적용)")
	restart.pressed.connect(func() -> void: restart_requested.emit())
	buttons.add_child(restart)
	var close := _button("닫기 (Esc)")
	close.pressed.connect(func() -> void: toggle_settings(false))
	buttons.add_child(close)


## 충전 라운드 점수 발표 창을 만든다.
func _build_announce() -> void:
	_announce = _panel(Color(PubTheme.INK, 0.94), PubTheme.GOLD, 3)
	_announce.position = Vector2(560, 300)
	_announce.custom_minimum_size = Vector2(800, 0)
	_announce.visible = false
	_root.add_child(_announce)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_announce.add_child(column)
	var title := _label(40, PubTheme.GOLD, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	_announce_rows = VBoxContainer.new()
	_announce_rows.add_theme_constant_override("separation", 8)
	column.add_child(_announce_rows)


## 결과 화면(순위·골드·'한 판 더' 단추)을 만든다.
func _build_results() -> void:
	_results = _panel(Color(PubTheme.INK, 0.96), PubTheme.GOLD, 3)
	_results.position = Vector2(510, 170)
	_results.custom_minimum_size = Vector2(900, 0)
	_results.mouse_filter = Control.MOUSE_FILTER_STOP
	_results.visible = false
	_root.add_child(_results)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	_results.add_child(column)
	_results_body = _rich(Vector2(860, 0))
	_results_body.fit_content = true
	column.add_child(_results_body)
	var again := _button("한 판 더")
	again.pressed.connect(func() -> void: restart_requested.emit())
	column.add_child(again)


## 가운데 정렬 상자(at·size 영역 안에서 내용을 가운데에 둔다).
func _center_holder(at: Vector2, size: Vector2) -> CenterContainer:
	var holder := CenterContainer.new()
	holder.position = at
	holder.size = size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(holder)
	return holder


## 펍 색 테두리 패널(마우스는 통과).
func _panel(fill: Color, border: Color = Color(PubTheme.GOLD, 0.6), border_width: int = 2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", PubTheme.box(fill, border, border_width, 12, 16))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


## 글자 크기·색을 정한 글 칸(bold = 굵은 글꼴).
func _label(size: int, color: Color, bold: bool = false) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if bold:
		label.add_theme_font_override("font", CardFaces.bold_font())
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## BBCode 글 칸(스크롤 없음, 내용만큼 늘어난다).
func _rich(minimum: Vector2) -> RichTextLabel:
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.custom_minimum_size = minimum
	rich.scroll_active = false
	rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rich.add_theme_font_override("normal_font", regular_font())
	rich.add_theme_font_override("bold_font", CardFaces.bold_font())
	rich.add_theme_color_override("default_color", PubTheme.PAPER)
	return rich


## 펍 색 단추.
func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_font_override("font", CardFaces.bold_font())
	button.custom_minimum_size = Vector2(240, 54)
	return button


## 가운데 조준점: 작은 원 + 점.
class Crosshair extends Control:
	func _draw() -> void:
		draw_arc(Vector2.ZERO, 14, 0, TAU, 32, Color(PubTheme.PAPER, 0.85), 2.0, true)
		draw_circle(Vector2.ZERO, 3, PubTheme.GOLD)
