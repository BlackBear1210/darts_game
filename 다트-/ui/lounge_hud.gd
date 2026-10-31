extends CanvasLayer
## 경기 화면 HUD(2026-10-30 디자인 개편). 자세한 규칙은 ESC/모니터에서만 보여 준다.
##
##   왼쪽 위    점수판(자리 색 띠 · 자리 표식 · 이름 · 점수, 지금 차례는 금색 테두리) + 단계 카드(제목 · 설명 · 남은 시간 막대)
##   오른쪽 위  방 정보 칩 + 초대 코드 복사, 그 아래 킬로그(배틀그라운드처럼 "누가 [아이콘] 누구를")
##   가운데     조준점 + 충전 막대(다트·소품 던지기)
##   아래 가운데 키 안내 칩(키캡 + 할 일), 대기실이면 준비 현황 칩
##   가운데 위  라운드 칸(◆ 카드 충전 · ● 다트) · 지금 단계 → 다음 단계 · 남은 초(큰 숫자 + 막대) — ui/round_banner.gd
##   아래 가운데 키 안내 칩 위: 카드 쓰는 법 · 고른 카드와 대상 한 줄(카드 그림은 왼쪽 아래 3D 손패 부채가 보여 준다)
##   오른쪽 아래 꺼내 든 카드 설명(그림 · 이름 · 효과 · 대상 · 준비 막대) — 카드 라운드 시연과 같은 자리
##   화면 전체  장난 효과(인형에 얼굴 가림 · 가챠 먹물)
## 글자 크기·색·카드 모양은 ui/lounge_style.gd 한 곳에서 온다.
const Style = preload("res://ui/lounge_style.gd")
const Catalog = preload("res://game/card_round/rules/card_catalog.gd")
const Preferences = preload("res://ui/player_preferences.gd")
const UiIcon = preload("res://ui/ui_icon.gd")
const CardFaces = preload("res://game/card_round/cards/card_faces.gd")
const Rules = preload("res://game/card_round/rules/round_rules.gd")
const MatchCards = preload("res://game/match/match_cards.gd")
## 위 가운데 라운드·남은 시간 표시(2026-10-31 저녁 — 다트 라운드 → 다음 카드 충전 라운드).
const RoundBanner = preload("res://ui/round_banner.gd")
## 자리 표식(색약이어도 모양으로 구분 — 기획 2-4).
const SEAT_GLYPHS: Array[String] = ["●", "▲", "■", "◆"]
## 킬로그 한 줄이 떠 있는 시간(초)과 사라지는 시간.
const FEED_LIFE: float = 8.0
const FEED_FADE: float = 0.8

var game: GameView
var _root: Control
var _score_box: VBoxContainer
var _round_chip: Label
var _phase_title: Label
var _phase_detail: Label
var _timer_bar: ProgressBar
var _banner: RoundBanner
var _room: Label
var _copy: Button
var _feed_box: VBoxContainer
var _feed_seen: Dictionary = {}
var _feed_key: String = ""
var _prompt_box: HBoxContainer
var _prompt_key: String = ""
var _ready_box: HBoxContainer
var _ready_key: String = ""
var _card_hint: Label
var _card_panel: PanelContainer
var _card_art: TextureRect
var _card_name: Label
var _card_info: Label
var _card_text: Label
var _card_target: Label
var _card_bar: ProgressBar
var _card_status: Label
## 지금 꺼내 든 카드(손패 번호·종류)와 꺼낸 시각. 방장의 준비 시간(Rules.READY_SECONDS)을 화면에서 따라 센다.
var _shown_pending: Vector2i = Vector2i(-1, -1)
var _pending_since: float = 0.0
var _charge: ProgressBar
var _result: PanelContainer
var _result_rows: VBoxContainer
var _result_buttons: HBoxContainer
var _result_key: String = ""
var _score_key: String = ""
var _overlay: Control
var _target: int = 0
var _link_dialog: AcceptDialog
var _url: LineEdit
var _link_error: Label
var _time: float = 0.0


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = Style.theme()
	add_child(_root)
	# 장난 효과 덮개는 맨 아래에 깔아 다른 HUD 글자는 보이게 둔다.
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	_root.add_child(_overlay)
	_build_scoreboard()
	_banner = RoundBanner.new()
	_banner.name = "RoundBanner"
	_root.add_child(_banner)
	_build_room_corner()
	_build_bottom()
	_build_result()
	_build_link_dialog()


# ─────────────────────────────── 만들기 ───────────────────────────────

func _build_scoreboard() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Style.card(Color(Style.PANEL, 0.88), Style.INK, Style.SHADOW, 3, 16, 14))
	panel.position = Vector2(28, 26)
	panel.custom_minimum_size = Vector2(380, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var logo := Style.heading(header, "DARTY", 26, Style.GOLD)
	logo.add_theme_font_override("font", Style.font("logo"))
	header.add_child(_spacer())
	_round_chip = Style.label(header, "", 17, Style.INK)
	_round_chip.add_theme_stylebox_override("normal", Style.flat(Style.MINT, Style.INK, 2, 10, 10, 2))
	_score_box = VBoxContainer.new()
	_score_box.add_theme_constant_override("separation", 6)
	column.add_child(_score_box)
	# 단계 카드(점수판 아래 붙은 띠).
	var phase := PanelContainer.new()
	phase.add_theme_stylebox_override("panel", Style.flat(Color(Style.INK, 0.6), Color(0, 0, 0, 0), 0, 10, 12, 8))
	column.add_child(phase)
	var phase_column := VBoxContainer.new()
	phase_column.add_theme_constant_override("separation", 2)
	phase.add_child(phase_column)
	_phase_title = Style.heading(phase_column, "", 22, Style.CREAM)
	_phase_detail = Style.label(phase_column, "", 16, Style.MUTED)
	_phase_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_phase_detail.custom_minimum_size.x = 340
	_timer_bar = _bar(Style.GOLD, 8)
	phase_column.add_child(_timer_bar)


func _build_room_corner() -> void:
	_room = Style.label(_root, "", 16, Style.CREAM)
	_room.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_room.add_theme_stylebox_override("normal", Style.flat(Color(Style.PANEL, 0.82), Style.INK, 2, 12, 14, 8))
	_room.size = Vector2(440, 0)
	_copy = Style.secondary(_root, "초대 코드 복사", func() -> void:
		DisplayServer.clipboard_set(game.session.invitation())
		_copy.text = "복사했어요 ✓")
	_copy.icon = null
	_copy.custom_minimum_size = Vector2(210, 48)
	_feed_box = VBoxContainer.new()
	_feed_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_feed_box.add_theme_constant_override("separation", 6)
	_feed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_feed_box)


func _build_bottom() -> void:
	var reticle := Style.label(_root, "·", 40, Style.MINT)
	reticle.add_theme_color_override("font_outline_color", Style.INK)
	reticle.add_theme_constant_override("outline_size", 8)
	reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	reticle.offset_left = -8
	reticle.offset_right = 8
	reticle.offset_top = -22
	reticle.offset_bottom = 22
	_charge = _bar(Style.PINK, 10)
	_charge.custom_minimum_size = Vector2(180, 10)
	_charge.size = Vector2(180, 10)
	_root.add_child(_charge)
	_card_hint = Style.label(_root, "", 18, Style.INK)
	_card_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_hint.add_theme_stylebox_override("normal", Style.card(Style.GOLD, Style.INK, Vector2(0, 4), 3, 14, 16))
	_build_card_panel()
	_prompt_box = HBoxContainer.new()
	_prompt_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_prompt_box.add_theme_constant_override("separation", 14)
	_prompt_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_prompt_box)
	_ready_box = HBoxContainer.new()
	_ready_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_ready_box.add_theme_constant_override("separation", 10)
	_ready_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_ready_box)


## 오른쪽 아래 '꺼내 든 카드' 패널: 카드 그림 옆에 이름·분류·효과 글·대상·준비 막대·쓰는 키.
func _build_card_panel() -> void:
	_card_panel = PanelContainer.new()
	_card_panel.add_theme_stylebox_override("panel", Style.card(Color(Style.PANEL, 0.92), Style.INK, Style.SHADOW, 3, 16, 14))
	_card_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_panel.visible = false
	_root.add_child(_card_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_card_panel.add_child(row)
	_card_art = TextureRect.new()
	_card_art.custom_minimum_size = Vector2(120, 180)
	_card_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_card_art)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(380, 0)
	column.add_theme_constant_override("separation", 4)
	row.add_child(column)
	_card_name = Style.heading(column, "", 28, Style.GOLD)
	_card_info = Style.label(column, "", 15, Style.MUTED)
	_card_text = Style.label(column, "", 18, Style.CREAM)
	_card_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_text.custom_minimum_size.x = 380
	_card_target = Style.label(column, "", 18, Style.MINT)
	_card_bar = _bar(Style.MINT, 8)
	column.add_child(_card_bar)
	_card_status = Style.heading(column, "", 24, Style.GOLD)


func _build_result() -> void:
	_result = PanelContainer.new()
	_result.add_theme_stylebox_override("panel", Style.card(Style.PANEL, Style.INK, Vector2(0, 10), 4, 22, 28))
	_result.custom_minimum_size = Vector2(560, 0)
	_root.add_child(_result)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_result.add_child(column)
	var title := Style.heading(column, "경기 종료", 46, Style.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := Style.label(column, "좋은 한 판이었어요!", 18, Style.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_rows = VBoxContainer.new()
	_result_rows.add_theme_constant_override("separation", 8)
	column.add_child(_result_rows)
	_result_buttons = HBoxContainer.new()
	_result_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_result_buttons.add_theme_constant_override("separation", 14)
	column.add_child(_result_buttons)
	Style.button(_result_buttons, "한 판 더  →", func() -> void: game.controller.restart())
	Style.secondary(_result_buttons, "로비로 나가기", func() -> void: game.session.leave_room())


func _build_link_dialog() -> void:
	_link_dialog = AcceptDialog.new()
	_link_dialog.title = "주크박스 · YouTube 링크"
	_link_dialog.dialog_hide_on_ok = false
	_link_dialog.min_size = Vector2i(640, 270)
	_link_dialog.theme = Style.theme()
	_root.add_child(_link_dialog)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	_link_dialog.add_child(content)
	Style.heading(content, "YouTube 링크를 붙여 넣으세요", 24)
	_url = LineEdit.new()
	_url.placeholder_text = "https://www.youtube.com/watch?v=…"
	_url.max_length = 300
	content.add_child(_url)
	Style.label(content, "공식 플레이어가 브라우저에서 열립니다.\n각 참가자는 한 번 재생을 허용해야 소리가 나요.", 17, Style.MUTED)
	_link_error = Style.label(content, "", 17, Style.PINK)
	_link_dialog.confirmed.connect(func() -> void:
		if preload("res://game/lounge/youtube_bridge.gd").video_id(_url.text).is_empty():
			_link_error.text = "YouTube 영상 링크 형식을 확인하세요."
			return
		game.lounge.request("link", _url.text)
		if game.lounge.bridge != null: game.lounge.bridge.open_player()
		_link_dialog.hide()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	_link_dialog.canceled.connect(func() -> void: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)


# ─────────────────────────────── 매 프레임 ───────────────────────────────

func _process(delta: float) -> void:
	if game == null or game.session == null: return
	_time += delta
	var extent := get_viewport().get_visible_rect().size
	var ratio: float = Preferences.ui_scale
	_root.scale = Vector2.ONE * ratio
	_root.size = extent / ratio
	var width: float = _root.size.x
	var height: float = _root.size.y
	var state: MatchState = game.controller.state
	var room: RoomState = game.session.room
	var waiting: bool = room.phase == RoomState.Phase.LOBBY
	var finished: bool = state.phase == MatchState.Phase.FINISHED
	_update_scores(state, waiting)
	_update_phase(state, room, waiting, finished, delta)
	_banner.position = Vector2((width - _banner.size.x) / 2, 18)
	# 오른쪽 위: 방 정보 → 초대 버튼 → 킬로그.
	_room.text = "%s\n%s  ·  %s  ·  %d/%d명" % [room.settings.room_name, "초대 전용" if room.settings.private_room else "공개 접속",
		"암호 있음" if room.has_password else "암호 없음", room.players.size(), room.settings.capacity]
	_room.position = Vector2(width - 468, 26)
	_copy.visible = waiting and game.session.is_room_host() and not room.settings.solo
	_copy.position = Vector2(width - 238, 26 + _room.size.y + 10)
	_feed_box.position = Vector2(width - 28 - _feed_box.size.x, 26 + _room.size.y + (72 if _copy.visible else 14))
	_update_feed(state)
	_update_cards(state, waiting, finished)
	# 키 안내 칩(height - 92) 위에 둔다 — 부채가 열리면 칩이 오른쪽으로 비켜 겹칠 수 있다.
	_card_panel.position = Vector2(width - 28 - _card_panel.size.x, height - 112 - _card_panel.size.y)
	_update_prompt()
	# 손패 부채(왼쪽 아래 3D 카드)가 있으면 키 안내를 오른쪽으로 비켜 겹치지 않게 한다.
	var me: MatchPlayer = state.find_player(game.controller.local_peer_id)
	var fan_open: bool = me != null and not me.hand.is_empty() and not waiting
	var prompt_center: float = maxf(width * 0.5, 900.0 + _prompt_box.size.x * 0.5) if fan_open else width * 0.5
	_prompt_box.position = Vector2(prompt_center - _prompt_box.size.x / 2, height - 92)
	# 카드 한 줄 안내는 위 가운데(라운드 표시 자리)에서 키 안내 칩 바로 위로 옮겼다. 부채가 열리면 같이 오른쪽으로 비킨다.
	var hint_center: float = maxf(width * 0.5, 900.0 + _card_hint.size.x * 0.5) if fan_open else width * 0.5
	_card_hint.position = Vector2(hint_center - _card_hint.size.x / 2, height - 150)
	_update_ready(room, waiting)
	_ready_box.position = Vector2((width - _ready_box.size.x) / 2, height - 170)
	_result.visible = finished
	if finished: _update_result()
	_result.position = (Vector2(width, height) - _result.size) / 2
	_result_buttons.visible = game.session.is_room_host()
	# 충전 막대: 조준점 바로 아래.
	var charge: float = -1.0
	if game.throw_input.charging: charge = game.throw_input.timing
	elif game.has_method("prop_charge") and game.prop_charge() >= 0.0: charge = game.prop_charge()
	_charge.visible = charge >= 0.0
	_charge.value = charge * 100.0
	_charge.position = Vector2((width - 180) / 2, height / 2 + 34)
	_overlay.queue_redraw()


func _update_scores(state: MatchState, waiting: bool) -> void:
	_round_chip.text = " 라운지 " if waiting else " ROUND %02d / %02d " % [state.round_number, game.controller.config.rounds]
	var active: MatchPlayer = null if waiting else state.active_player()
	var key := PackedStringArray()
	for player in state.players:
		key.append("%d|%s|%d|%s" % [player.seat, player.display_name, player.score, "A" if player == active else ""])
	var joined := ",".join(key)
	if joined == _score_key: return
	_score_key = joined
	for child in _score_box.get_children():
		child.queue_free()
	for player in state.players:
		_score_box.add_child(_score_row(player, player == active, player.peer_id == game.controller.local_peer_id))


func _score_row(player: MatchPlayer, active: bool, me: bool) -> Control:
	var tint: Color = PlayerLook.COLORS[player.seat % PlayerLook.COLORS.size()]
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", Style.flat(Color(tint.darkened(0.55), 0.92), Style.GOLD if active else Color(tint, 0.6), 3 if active else 2, 10, 10, 4))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	row.add_child(line)
	var glyph := Style.label(line, SEAT_GLYPHS[player.seat % 4], 20, tint.lightened(0.25))
	glyph.custom_minimum_size.x = 22
	var name := Style.label(line, player.display_name + ("  (나)" if me else ""), 19, Style.CREAM)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.clip_text = true
	if active:
		Style.label(line, "▶ 차례", 14, Style.GOLD)
	var score := Style.heading(line, str(player.score), 26, Style.GOLD if active else Style.CREAM)
	score.add_theme_font_override("font", Style.font("logo"))
	score.custom_minimum_size.x = 54
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return row


func _update_phase(state: MatchState, room: RoomState, waiting: bool, finished: bool, delta: float) -> void:
	var seconds: float = game.controller.remaining_seconds()
	var limit: float = 1.0
	# 남은 초·막대는 위 가운데 라운드 표시(_banner)로 옮겼다(2026-10-31 저녁). 왼쪽 단계 카드는 설명만 한다.
	_timer_bar.visible = false
	var stage: int = RoundBanner.Stage.CARDS
	var sub: String = ""
	# 설명 줄은 340px 칸에 들어가도록 뜻이 끊기는 곳에서 직접 줄을 바꾼다(2026-10-31).
	# 자동 줄바꿈만 두면 한글이 글자 사이에서 끊겨 "써\n요." "사\n람에게" 처럼 보였다.
	if waiting:
		_phase_title.text = "준비 시간"
		_phase_detail.text = "자기 색 의자에 %s 로 앉고\nEnter 로 참여" % OS.get_keycode_string(Preferences.interact_key)
		if not room.settings.solo and room.players.size() < 2: _phase_detail.text += "\n친구가 들어오기를 기다리는 중…"
	elif finished:
		_phase_title.text = "경기 종료"
		_phase_detail.text = "결과를 확인하세요."
	elif state.phase == MatchState.Phase.CARDS:
		_phase_title.text = "카드 확인"
		_phase_detail.text = "받은 카드를 확인하세요.\n카드는 다트 턴에 써요."
		limit = MatchCards.VIEW_SECONDS
		sub = "받은 카드 확인 · 쓴 만큼만 7장까지 다시 채운다"
	elif state.phase == MatchState.Phase.TABLE:
		_phase_title.text = "테이블 집합!"
		_phase_detail.text = "자기 자리로 돌아와 앉으세요.\n늦으면 슬로우!"
		limit = game.controller.config.table_seconds
		sub = "테이블 집합! 자리에 앉으세요 · 늦으면 슬로우"
	else:
		var active: MatchPlayer = state.active_player()
		_phase_title.text = "%s의 다트" % (active.display_name if active != null else "대기")
		_phase_detail.text = "%d발 남음 · 누구나 카드 사용\n효과는 지금 던지는 사람에게" % state.darts_left
		limit = game.controller.config.turn_seconds
		stage = RoundBanner.Stage.DARTS
		sub = "%s 차례 · %d발 남음" % [active.display_name if active != null else "대기", state.darts_left]
	_banner.visible = not waiting and not finished
	if _banner.visible:
		_banner.show_state(state.round_number, game.controller.config.rounds, stage, sub, seconds, limit, delta)


## 킬로그: 새 줄이 들어오면 위에서 칩으로 쌓이고 몇 초 뒤 흐려져 사라진다.
func _update_feed(state: MatchState) -> void:
	var now: float = _time
	for entry in state.feed:
		if not _feed_seen.has(entry): _feed_seen[entry] = now
	for entry in _feed_seen.keys():
		if entry not in state.feed and now - float(_feed_seen[entry]) > FEED_LIFE: _feed_seen.erase(entry)
	var shown := PackedStringArray()
	for entry in state.feed:
		if now - float(_feed_seen[entry]) < FEED_LIFE: shown.append(entry)
	var joined := "\n".join(shown)
	if joined != _feed_key:
		_feed_key = joined
		for child in _feed_box.get_children():
			child.queue_free()
		for entry in shown:
			var chip := feed_chip(entry)
			chip.set_meta("entry", entry)
			_feed_box.add_child(chip)
	for chip in _feed_box.get_children():
		if not chip.has_meta("entry"): continue
		var age: float = now - float(_feed_seen.get(chip.get_meta("entry"), now))
		# 들어올 때 오른쪽에서 미끄러져 들어오고, 끝날 때 흐려진다.
		chip.modulate.a = clampf((FEED_LIFE - age) / FEED_FADE, 0.0, 1.0) * clampf(age / 0.15, 0.0, 1.0)


## 킬로그 한 줄을 칩으로 만든다. 예전 글자 한 줄(구분 글자 없음)도 그대로 보여 준다.
static func feed_chip(entry: String) -> Control:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", Style.flat(Color(Style.INK, 0.78), Color(Style.CREAM, 0.12), 1, 10, 12, 5))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	line.alignment = BoxContainer.ALIGNMENT_END
	chip.add_child(line)
	var parts := entry.split(MatchController.FEED_SEPARATOR)
	if parts.size() < 6:
		Style.label(line, entry, 16, Style.CREAM)
		return chip
	var actor_seat: int = int(parts[1])
	var target_seat: int = int(parts[4])
	if not parts[2].is_empty():
		Style.label(line, parts[2], 17, _seat_color(actor_seat))
	line.add_child(UiIcon.make(parts[0], 26, Style.CREAM))
	if not parts[5].is_empty():
		Style.label(line, parts[5], 17, _seat_color(target_seat))
	if not parts[3].is_empty():
		Style.label(line, parts[3], 15, Style.MUTED)
	return chip


static func _seat_color(seat: int) -> Color:
	if seat < 0: return Style.CREAM
	return PlayerLook.COLORS[seat % PlayerLook.COLORS.size()].lightened(0.3)


func _update_cards(state: MatchState, waiting: bool, finished: bool) -> void:
	var me: MatchPlayer = state.find_player(game.controller.local_peer_id)
	_card_hint.visible = false
	_card_panel.visible = false
	if waiting or finished or me == null or not _card_phase(state): return
	if me.pending_card >= 0:
		# 카드를 꺼내 들면 오른쪽 아래 카드 패널이 이름·대상·"F 로 쓰기"를 다 보여 준다 → 아래 한 줄 안내는 숨긴다(겹침 방지).
		_show_card_panel(me, _target_name(state, me))
	else:
		_card_hint.text = "Q·E 로 카드 꺼내기 (1–7 바로) → %s 로 쓰기 · 효과는 지금 던지는 사람에게" % OS.get_keycode_string(Preferences.interact_key)
		_card_hint.visible = true


## 카드를 쓸 수 있는 때 = 다트 턴(조준·비행). 2026-10-31부터 따로 카드 턴은 없다.
static func _card_phase(state: MatchState) -> bool:
	return state.phase in [MatchState.Phase.AIMING, MatchState.Phase.FLIGHT]


## 무효(×0)로 막을 수 있는 사람 = 나 말고 카드를 꺼내 든 사람.
func _counter_targets(state: MatchState, me: MatchPlayer) -> Array[int]:
	var ids: Array[int] = []
	for player in state.players:
		if player.peer_id != me.peer_id and player.pending_card >= 0: ids.append(player.peer_id)
	return ids


## 무효(×0)로 막을 사람. Tab 으로 고른 사람이 카드를 내려놨으면 첫 사람으로 바꾼다. 없으면 0.
func _counter_target(state: MatchState, me: MatchPlayer) -> int:
	var ids: Array[int] = _counter_targets(state, me)
	if ids.is_empty(): return 0
	if not ids.has(_target): _target = ids[0]
	return _target


## 꺼내 든 카드가 걸릴 사람. 무효는 Tab 으로 고른 사람, 나머지는 누가 쓰든 지금 던지는 사람이다.
func _target_name(state: MatchState, me: MatchPlayer) -> String:
	if int(Catalog.card(me.pending_card).target) == Catalog.Target.COUNTER:
		var victim: int = _counter_target(state, me)
		return "%s (Tab 바꾸기)" % state.find_player(victim).display_name if victim != 0 else "카드를 꺼내 든 사람 없음"
	var active: MatchPlayer = state.active_player()
	if active == null: return "대상 없음"
	return "나 (지금 던지는 사람)" if active == me else "%s (지금 던지는 사람)" % active.display_name


func _show_card_panel(me: MatchPlayer, target: String) -> void:
	var pending := Vector2i(me.pending_slot, me.pending_card)
	if pending != _shown_pending:
		_shown_pending = pending
		_pending_since = _time
	var type: int = me.pending_card
	_card_panel.visible = true
	_card_art.texture = CardFaces.face(type)
	_card_name.text = str(Catalog.card(type).name)
	_card_info.text = "%s · %s" % [Catalog.category_name(type), Catalog.timing_text(type)]
	_card_text.text = str(Catalog.card(type).text)
	_card_target.text = "대상 · " + target
	var ratio: float = clampf((_time - _pending_since) / Rules.READY_SECONDS, 0.0, 1.0)
	_card_bar.value = ratio * 100.0
	_card_status.text = "준비 중…" if ratio < 1.0 else "%s 로 쓰기" % OS.get_keycode_string(Preferences.interact_key)
	_card_status.add_theme_color_override("font_color", Style.GOLD if ratio < 1.0 else Style.MINT)


func _update_prompt() -> void:
	var pairs: Array = _prompt_for(game.lounge.focus(game.controller.local_peer_id) if game.lounge != null else {})
	var room: RoomState = game.session.room
	if game.throw_input.charging:
		pairs = [["놓기", "다트 발사 %d%%" % roundi(game.throw_input.timing * 100)], ["우클릭", "취소"]]
	if room.phase == RoomState.Phase.LOBBY and game.is_seated(game.controller.local_peer_id):
		pairs = [["Enter", "게임 참여"], ["A / D", "훔쳐보기"], ["S", "빙글빙글"], ["Space", "일어서기"], ["T", "감정표현"]]
	if game.lounge != null and game.lounge.is_stunned(game.controller.local_peer_id):
		pairs = [["✦", "잠깐 어질어질…"]]
	var key := str(pairs)
	if key == _prompt_key: return
	_prompt_key = key
	for child in _prompt_box.get_children():
		child.queue_free()
	for pair in pairs:
		_prompt_box.add_child(_key_chip(str(pair[0]), str(pair[1])))


## 키캡 + 할 일. 키캡은 크림색 작은 카드, 할 일은 그림자 진 글자.
static func _key_chip(key: String, action: String) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 7)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cap := Style.label(line, key, 17, Style.INK)
	cap.add_theme_stylebox_override("normal", Style.card(Style.CREAM, Style.INK, Vector2(0, 3), 2, 7, 9))
	var text := Style.label(line, action, 18, Style.CREAM)
	text.add_theme_color_override("font_outline_color", Style.INK)
	text.add_theme_constant_override("outline_size", 7)
	return line


func _update_ready(room: RoomState, waiting: bool) -> void:
	_ready_box.visible = waiting
	if not waiting: return
	var key := PackedStringArray()
	for player in room.players: key.append("%s|%s" % [player.display_name, player.is_ready])
	var joined := ",".join(key)
	if joined == _ready_key: return
	_ready_key = joined
	for child in _ready_box.get_children():
		child.queue_free()
	for player in room.players:
		var chip := Style.label(_ready_box, ("✓ " if player.is_ready else "○ ") + player.display_name, 18, Style.INK if player.is_ready else Style.CREAM)
		chip.add_theme_stylebox_override("normal", Style.flat(Style.MINT if player.is_ready else Color(Style.PANEL, 0.9), Style.INK, 2, 12, 14, 6))


func _update_result() -> void:
	var players: Array[MatchPlayer] = game.controller.state.players.duplicate()
	var countdown: bool = game.controller.room_settings.win_mode == 2
	players.sort_custom(func(a: MatchPlayer, b: MatchPlayer) -> bool: return a.score < b.score if countdown else a.score > b.score)
	var key := PackedStringArray()
	for player in players: key.append("%s|%d" % [player.display_name, player.score])
	var joined := ",".join(key)
	if joined == _result_key: return
	_result_key = joined
	for child in _result_rows.get_children():
		child.queue_free()
	var rank: int = 1
	for index in range(players.size()):
		if index > 0 and players[index].score != players[index - 1].score: rank = index + 1
		var row := _score_row(players[index], rank == 1, players[index].peer_id == game.controller.local_peer_id)
		var medal := Style.heading(row.get_child(0), "%d위" % rank, 22, Style.GOLD if rank == 1 else Style.MUTED)
		row.get_child(0).move_child(medal, 0)
		_result_rows.add_child(row)


# ─────────────────────────────── 장난 효과 덮개 ───────────────────────────────

## 인형에 맞으면 얼굴이 인형으로 가려지고, 가챠 먹물을 맞으면 먹물이 튄다. 내 화면에만 그린다.
func _draw_overlay() -> void:
	if game == null or game.lounge == null or not game.lounge.has_method("effect_left"): return
	var id: int = game.controller.local_peer_id
	var extent: Vector2 = _overlay.size
	var ink: float = game.lounge.effect_left(id, "ink")
	if ink > 0.0:
		var alpha: float = clampf(ink / 0.8, 0.0, 1.0)
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		for index in range(9):
			var at := Vector2(rng.randf_range(0.1, 0.9) * extent.x, rng.randf_range(0.15, 0.85) * extent.y)
			var radius: float = rng.randf_range(90, 220)
			_overlay.draw_circle(at, radius, Color(0.05, 0.03, 0.08, 0.92 * alpha))
			for drop in range(6):
				var angle: float = rng.randf() * TAU
				_overlay.draw_circle(at + Vector2.from_angle(angle) * radius * rng.randf_range(0.9, 1.4), radius * rng.randf_range(0.12, 0.26), Color(0.05, 0.03, 0.08, 0.92 * alpha))
	var blind: float = game.lounge.effect_left(id, "blind")
	if blind > 0.0:
		# 화면을 거의 덮는 곰 인형 얼굴(눈·코·귀). 끝날 때 아래로 미끄러진다.
		var slide: float = (1.0 - clampf(blind / 0.35, 0.0, 1.0)) * extent.y
		var c := Vector2(extent.x * 0.5, extent.y * 0.55 + slide)
		var r: float = extent.y * 0.62
		var fur := Color("c98a5a")
		_overlay.draw_circle(c + Vector2(-r * 0.78, -r * 0.72), r * 0.3, fur.darkened(0.1))
		_overlay.draw_circle(c + Vector2(r * 0.78, -r * 0.72), r * 0.3, fur.darkened(0.1))
		_overlay.draw_circle(c, r, fur)
		_overlay.draw_circle(c + Vector2(0, r * 0.28), r * 0.36, Color("f1d2b0"))
		_overlay.draw_circle(c + Vector2(-r * 0.34, -r * 0.12), r * 0.08, Style.INK)
		_overlay.draw_circle(c + Vector2(r * 0.34, -r * 0.12), r * 0.08, Style.INK)
		_overlay.draw_circle(c + Vector2(0, r * 0.16), r * 0.1, Style.INK)
		Style.font("heading").draw_string(_overlay.get_canvas_item(), c + Vector2(-140, -r * 0.42), "푹신!", HORIZONTAL_ALIGNMENT_CENTER, 280, 54, Style.INK)


# ─────────────────────────────── 입력·도우미 ───────────────────────────────

## 지금 바라보는 것에 맞는 키 안내. [키, 할 일] 쌍의 목록.
func _prompt_for(focus: Dictionary) -> Array:
	var key: String = OS.get_keycode_string(Preferences.interact_key)
	var lounge = game.lounge
	match str(focus.get("kind", "")):
		"monitor": return [[key, "방장 모니터 열기"]] if game.session.is_room_host() else [["!", "방장만 게임 규칙을 바꿀 수 있어요"]]
		"power": return [[key, "주크박스 전원 켜기 / 끄기"]]
		"volume": return [[key, "주크박스 볼륨 %d%% · 누를 때마다 한 단계" % roundi(float(lounge.music.volume) * 100)]]
		"link": return [[key, "YouTube 링크 넣기"], ["B", "음악 플레이어 열기"]]
		"prop": return [["좌클릭", "%s 잡기" % lounge.prop_name(int(focus.get("index", 0)))]]
		"claw", "gacha", "hoop": return [[key, lounge.machine_prompt(game.controller.local_peer_id, str(focus.kind))]]
		# 도면 v3 건드리기(종·통·과녁·축음기): 소리 + 흔들림.
		"touch": return [[key, str(lounge.touch_spots()[int(focus.get("index", 0))].text)]]
	if lounge != null and lounge.held(game.controller.local_peer_id) >= 0:
		var index: int = lounge.held(game.controller.local_peer_id)
		var pairs: Array = [["우클릭 꾹", "%s 던지기 (짧게 = 살짝 놓기)" % lounge.prop_name(index)]]
		if lounge.objects[index].kind in lounge.DRINKS: pairs.push_front(["좌클릭", "한 모금"])
		if lounge.objects[index].kind == "capsule": pairs.push_front(["좌클릭", "내가 열어 보기"])
		return pairs
	# 키 배치(2026-10-31 저녁 정리): 카드 = Q·E 로 꺼내고 F 로 쓴다 · 앉으면 A·D 엿보기 · Space 일어서기 · T 감정표현.
	# 카드 칩은 다트 턴(카드를 쓸 수 있을 때)에만 보인다. 꺼내 든 카드가 있으면 F 가 카드 쓰기다.
	var state: MatchState = game.controller.state
	var me: MatchPlayer = state.find_player(game.controller.local_peer_id)
	var card_keys: Array = []
	if me != null and _card_phase(state) and not me.hand.is_empty():
		card_keys = [[key, "카드 쓰기"]] if me.pending_card >= 0 else [["Q · E", "카드 꺼내기"]]
	if game.is_seated(game.controller.local_peer_id):
		return card_keys + [["A · D", "옆자리 엿보기"], ["Space", "일어서기"], ["T", "감정표현"]]
	# 카드를 들고 있으면 F 는 카드 쓰기라 "착석 · 기계" 칩은 뺀다(한 키에 두 안내가 겹치지 않게).
	var interact: Array = [] if me != null and me.pending_card >= 0 and _card_phase(state) else [[key, "착석 · 기계"]]
	return card_keys + [["WASD", "이동"]] + interact + [["좌클릭 꾹", "다트"], ["T", "감정표현"]]


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	var state: MatchState = game.controller.state
	if event.keycode == KEY_B and game.lounge.focus(game.controller.local_peer_id).get("kind") == "link":
		if game.lounge.bridge != null: game.lounge.bridge.open_player()
	if not _card_phase(state): return
	var me: MatchPlayer = state.find_player(game.controller.local_peer_id)
	if me == null: return
	if event.keycode >= KEY_1 and event.keycode <= KEY_7:
		game.controller.request_card("select", event.keycode - KEY_1)
	elif event.keycode >= KEY_KP_1 and event.keycode <= KEY_KP_7:
		game.controller.request_card("select", event.keycode - KEY_KP_1)
	elif event.keycode in [KEY_Q, KEY_E]:
		_browse_card(me, -1 if event.keycode == KEY_Q else 1)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_TAB:
		# 대상을 고르는 건 무효(×0)뿐이다. 나머지 카드는 언제나 지금 던지는 사람에게 걸린다.
		var ids: Array[int] = _counter_targets(state, me)
		if not ids.is_empty(): _target = ids[(ids.find(_target) + 1) % ids.size()]
	elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		# Enter 는 예전 습관용 예비 키로만 남긴다(화면 안내는 F).
		use_lifted_card()


## 꺼내 든 카드를 쓴다(F · Enter). 다트 턴이 아니거나 든 카드가 없으면 false → GameView 가 F 를 착석·기계로 넘긴다.
## 무효(×0)는 Tab 으로 고른 "카드를 꺼내 든 사람"에게, 나머지는 지금 던지는 사람에게 건다.
func use_lifted_card() -> bool:
	if game == null: return false
	var state: MatchState = game.controller.state
	if not _card_phase(state): return false
	var me: MatchPlayer = state.find_player(game.controller.local_peer_id)
	if me == null or me.pending_card < 0: return false
	var counter: bool = int(Catalog.card(me.pending_card).target) == Catalog.Target.COUNTER
	var active: MatchPlayer = state.active_player()
	game.controller.request_card("use", _counter_target(state, me) if counter else (active.peer_id if active != null else 0))
	return true


## Q(-1)·E(+1): 손패를 왼쪽·오른쪽으로 넘기며 꺼내 든다. 끝에서는 반대쪽 끝으로 돈다. 아무것도 안 들었으면 E = 첫 장, Q = 마지막 장.
func _browse_card(me: MatchPlayer, step: int) -> void:
	if me.hand.is_empty(): return
	var index: int = (0 if step > 0 else me.hand.size() - 1) if me.pending_slot < 0 else posmod(me.pending_slot + step, me.hand.size())
	game.controller.request_card("select", index)


func open_link() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_link_error.text = ""
	_link_dialog.popup_centered()
	_url.grab_focus()


func _spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


func _bar(fill: Color, thickness: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, thickness)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", Style.flat(Color(Style.INK, 0.8), Color(0, 0, 0, 0), 0, thickness / 2, 0, 0))
	bar.add_theme_stylebox_override("fill", Style.flat(fill, Color(0, 0, 0, 0), 0, thickness / 2, 0, 0))
	return bar
