extends CanvasLayer
## 경기 화면 HUD(2026-10-30 디자인 개편). 자세한 규칙은 ESC/모니터에서만 보여 준다.
##
##   왼쪽 위    점수판(자리 색 띠 · 자리 표식 · 이름 · 점수, 지금 차례는 금색 테두리) + 단계 카드(제목 · 설명 · 남은 시간 막대)
##   오른쪽 위  방 정보 칩 + 초대 코드 복사, 그 아래 킬로그(배틀그라운드처럼 "누가 [아이콘] 누구를")
##   가운데     조준점 + 충전 막대(다트·소품 던지기)
##   아래 가운데 키 안내 칩(키캡 + 할 일), 대기실이면 준비 현황 칩
##   가운데 위  카드 턴의 고른 카드·대상 한 줄(카드 그림은 왼쪽 아래 3D 손패 부채가 보여 준다)
##   화면 전체  장난 효과(인형에 얼굴 가림 · 가챠 먹물)
## 글자 크기·색·카드 모양은 ui/lounge_style.gd 한 곳에서 온다.
const Style = preload("res://ui/lounge_style.gd")
const Catalog = preload("res://game/card_round/rules/card_catalog.gd")
const Preferences = preload("res://ui/player_preferences.gd")
const UiIcon = preload("res://ui/ui_icon.gd")
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
	_update_phase(state, room, waiting, finished)
	# 오른쪽 위: 방 정보 → 초대 버튼 → 킬로그.
	_room.text = "%s\n%s  ·  %s  ·  %d/%d명" % [room.settings.room_name, "초대 전용" if room.settings.private_room else "공개 접속",
		"암호 있음" if room.has_password else "암호 없음", room.players.size(), room.settings.capacity]
	_room.position = Vector2(width - 468, 26)
	_copy.visible = waiting and game.session.is_room_host() and not room.settings.solo
	_copy.position = Vector2(width - 238, 26 + _room.size.y + 10)
	_feed_box.position = Vector2(width - 28 - _feed_box.size.x, 26 + _room.size.y + (72 if _copy.visible else 14))
	_update_feed(state)
	_update_cards(state, waiting, finished)
	_card_hint.position = Vector2((width - _card_hint.size.x) / 2, 30)
	_update_prompt()
	# 손패 부채(왼쪽 아래 3D 카드)가 있으면 키 안내를 오른쪽으로 비켜 겹치지 않게 한다.
	var me: MatchPlayer = state.find_player(game.controller.local_peer_id)
	var fan_open: bool = me != null and not me.hand.is_empty() and not waiting
	var prompt_center: float = maxf(width * 0.5, 900.0 + _prompt_box.size.x * 0.5) if fan_open else width * 0.5
	_prompt_box.position = Vector2(prompt_center - _prompt_box.size.x / 2, height - 92)
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


func _update_phase(state: MatchState, room: RoomState, waiting: bool, finished: bool) -> void:
	var seconds: float = game.controller.remaining_seconds()
	var limit: float = 1.0
	_timer_bar.visible = not waiting and not finished
	if waiting:
		_phase_title.text = "준비 시간"
		_phase_detail.text = "자기 색 의자에 %s 로 앉고 Enter 로 참여" % OS.get_keycode_string(Preferences.interact_key)
		if not room.settings.solo and room.players.size() < 2: _phase_detail.text += "\n친구가 들어오기를 기다리는 중…"
	elif finished:
		_phase_title.text = "경기 종료"
		_phase_detail.text = "결과를 확인하세요."
	elif state.phase == MatchState.Phase.CARDS:
		var player: MatchPlayer = state.find_player(state.card_peer)
		_phase_title.text = "카드 턴 · %s" % (player.display_name if player != null else "대기")
		_phase_detail.text = "1–7 카드 · Tab 대상 · Enter 사용/패스"
		limit = game.controller.config.card_seconds
	elif state.phase == MatchState.Phase.TABLE:
		_phase_title.text = "테이블 집합!"
		_phase_detail.text = "자기 자리로 돌아와 앉으세요. 늦으면 슬로우!"
		limit = game.controller.config.table_seconds
	else:
		var active: MatchPlayer = state.active_player()
		_phase_title.text = "%s의 다트" % (active.display_name if active != null else "대기")
		_phase_detail.text = "%d발 남음 · 다른 사람은 방해해도 좋아요" % state.darts_left
		limit = game.controller.config.turn_seconds
	_timer_bar.max_value = maxf(1.0, limit)
	_timer_bar.value = clampf(seconds, 0.0, _timer_bar.max_value)
	_phase_title.text += "   %.0f초" % seconds if _timer_bar.visible else ""


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
	if waiting or finished or me == null or state.phase != MatchState.Phase.CARDS: return
	if me.pending_card >= 0:
		var target: MatchPlayer = state.find_player(_target)
		_card_hint.text = "고른 카드 · %s   →   %s      Tab 대상 바꾸기 · Enter 사용" % [Catalog.card(me.pending_card).name, target.display_name if target != null else "대상 자동"]
		_card_hint.visible = true
	elif state.card_peer == me.peer_id:
		_card_hint.text = "내 카드 턴!  1–7 로 카드 고르기 · Enter 패스"
		_card_hint.visible = true


func _update_prompt() -> void:
	var pairs: Array = _prompt_for(game.lounge.focus(game.controller.local_peer_id) if game.lounge != null else {})
	var room: RoomState = game.session.room
	if game.throw_input.charging:
		pairs = [["놓기", "다트 발사 %d%%" % roundi(game.throw_input.timing * 100)], ["우클릭", "취소"]]
	if room.phase == RoomState.Phase.LOBBY and game.is_seated(game.controller.local_peer_id):
		pairs = [["Enter", "게임 참여"], ["A / D", "훔쳐보기"], ["S", "빙글빙글"]]
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
		"volume": return [["Q / E", "주크박스 볼륨 %d%%" % roundi(float(lounge.music.volume) * 100)]]
		"link": return [[key, "YouTube 링크 넣기"], ["B", "음악 플레이어 열기"]]
		"prop": return [["좌클릭", "%s 잡기" % lounge.prop_name(int(focus.get("index", 0)))]]
		"claw", "gacha", "hoop": return [[key, lounge.machine_prompt(game.controller.local_peer_id, str(focus.kind))]]
	if lounge != null and lounge.held(game.controller.local_peer_id) >= 0:
		var index: int = lounge.held(game.controller.local_peer_id)
		var pairs: Array = [["우클릭 꾹", "%s 던지기 (짧게 = 살짝 놓기)" % lounge.prop_name(index)]]
		if lounge.objects[index].kind == "bottle": pairs.push_front([OS.get_keycode_string(Preferences.drink_key), "한 모금"])
		if lounge.objects[index].kind == "capsule": pairs.push_front([OS.get_keycode_string(Preferences.drink_key), "내가 열어 보기"])
		return pairs
	return [["WASD", "이동"], [key, "착석 · 기계"], ["좌클릭 꾹", "다트"], ["Esc", "설정"]]


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	var state: MatchState = game.controller.state
	if event.keycode == KEY_B and game.lounge.focus(game.controller.local_peer_id).get("kind") == "link":
		if game.lounge.bridge != null: game.lounge.bridge.open_player()
	if state.phase != MatchState.Phase.CARDS: return
	if event.keycode >= KEY_1 and event.keycode <= KEY_7:
		game.controller.request_card("select", event.keycode - KEY_1)
	elif event.keycode == KEY_TAB:
		var ids: Array[int] = []
		for player in state.players:
			if player.peer_id != game.controller.local_peer_id: ids.append(player.peer_id)
		if not ids.is_empty(): _target = ids[(ids.find(_target) + 1) % ids.size()]
	elif event.keycode == KEY_ENTER:
		var me: MatchPlayer = state.find_player(game.controller.local_peer_id)
		if me == null: return
		if me.pending_card < 0: game.controller.request_card("pass")
		else:
			if _target == 0:
				for player in state.players:
					if player.peer_id != me.peer_id: _target = player.peer_id; break
			game.controller.request_card("use", _target)


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
