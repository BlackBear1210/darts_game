extends CanvasLayer
## Tab 플레이어 목록(2026-11-01 사용자 요청: "Tab 을 누르면 누가 방에 들어왔는지 + 사람마다 음성 볼륨").
## Tab 을 누르고 있는 동안 보이고 떼면 닫힌다. 톡 누르고 바로 떼면(TAP_SECONDS 미만) 열린 채로 남고 마우스 포인터가 나와
## 볼륨 막대·음소거를 만질 수 있다 → Tab·Esc 를 다시 누르거나 빈 곳을 눌러 화면을 다시 잡으면 닫힌다.
## 사람마다 볼륨·음소거는 이름으로 저장한다(ui/player_preferences.gd — 다음 판에도 같은 사람이면 그대로).
## 목록은 방 명단(RoomState)과 경기 점수만 읽는다. 아무것도 바꾸지 않는다(볼륨은 내 화면에서만).

const Style = preload("res://ui/lounge_style.gd")
const Preferences = preload("res://ui/player_preferences.gd")
const UiIcon = preload("res://ui/ui_icon.gd")
const VoiceChat = preload("res://network/voice_chat.gd")

## 이보다 짧게 누르면 "고정"(열린 채로 마우스 사용), 길게 누르면 떼는 순간 닫는다(초).
const TAP_SECONDS: float = 0.3
## 핑·말하는 중 표시를 다시 읽는 간격(초).
const REFRESH_SECONDS: float = 0.5

var game: GameView
var _panel: PanelContainer
var _title: Label
var _subtitle: Label
var _rows: VBoxContainer
var _hint: Label
var _pinned: bool = false
var _pressed_at: float = -1.0
## 명단이 바뀌었는지 보는 글자(이름·자리·봇·방장) — 같으면 줄을 다시 만들지 않는다(막대를 끄는 중에 사라지지 않게).
var _roster_key: String = ""
## peer_id → {"speaker": TextureRect, "score": Label, "ping": Label, "status": Label(나만)}
var _cells: Dictionary = {}
var _refresh_in: float = 0.0


func _ready() -> void:
	layer = 25
	visible = false
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.theme = Style.theme()
	_panel.custom_minimum_size = Vector2(900, 0)
	_panel.add_theme_stylebox_override("panel", Style.card(Color(Style.PANEL, 0.96), Style.INK, Style.SHADOW, 3, 18, 22))
	center.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	column.add_child(header)
	_title = Style.heading(header, "플레이어", 34)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_subtitle = Style.label(header, "", 18, Style.MUTED)
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 8)
	column.add_child(_rows)
	_hint = Style.label(column, "", 16, Style.MUTED)


## GameView._unhandled_input 가 먼저 넘겨준다. Tab 을 처리했으면 true.
func handle(event: InputEvent) -> bool:
	if not event is InputEventKey or (event as InputEventKey).keycode != KEY_TAB or event.echo:
		return false
	# 무효(×0) 카드를 꺼내 들고 막을 사람이 둘 이상이면 Tab 은 예전처럼 대상 바꾸기다(lounge_hud.gd).
	if game.lounge_hud != null and game.lounge_hud.has_method("tab_picks_target") and game.lounge_hud.tab_picks_target():
		return false
	var now: float = Time.get_ticks_msec() / 1000.0
	if event.pressed:
		if visible:
			close()
		else:
			_open()
			_pressed_at = now
		return true
	if visible and not _pinned and _pressed_at >= 0.0:
		if now - _pressed_at < TAP_SECONDS: _pin()
		else: close()
	_pressed_at = -1.0
	return true


## 고정해 둔 목록은 Esc 로 닫는다(설정 창보다 먼저 받는다 — app/main.gd 의 Esc 는 부모라 나중에 받는다).
func _input(event: InputEvent) -> void:
	if _pinned and event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func close() -> void:
	visible = false
	_pressed_at = -1.0
	if _pinned:
		_pinned = false
		Preferences.save()
		if game.controller.state.phase != MatchState.Phase.FINISHED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _open() -> void:
	visible = true
	_roster_key = ""
	_refresh(true)


func _pin() -> void:
	_pinned = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_hint.text = "볼륨 막대를 끌어 사람마다 목소리 크기를 바꿔요 · Tab / Esc 닫기"


func _process(delta: float) -> void:
	if not visible:
		return
	# 고정해 둔 동안 다른 곳(빈 곳 클릭·설정 창 닫기)에서 화면을 다시 잡았으면 같이 닫는다.
	if _pinned and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_pinned = false
		Preferences.save()
		visible = false
		return
	_refresh_in -= delta
	_refresh(_refresh_in <= 0.0)
	var voice: VoiceChat = game.session.voice if game.session != null else null
	for peer: int in _cells:
		var speaking: bool = voice != null and voice.is_speaking(peer)
		var icon := (_cells[peer] as Dictionary).speaker as TextureRect
		icon.modulate.a = 1.0 if speaking else 0.12
		icon.scale = Vector2.ONE * (1.0 + (voice.level(peer) * 0.25 if speaking else 0.0))


## 명단이 바뀌었으면 줄을 다시 만들고, 아니면 점수·핑·내 마이크 상태 글자만 고친다.
func _refresh(slow_parts: bool) -> void:
	var room: RoomState = game.session.room
	var key := PackedStringArray([str(room.host_peer_id)])
	for player in room.players:
		key.append("%d|%s|%d|%s" % [player.peer_id, player.display_name, player.seat, player.is_bot])
	if ",".join(key) != _roster_key:
		_roster_key = ",".join(key)
		_build_rows(room)
	if not slow_parts:
		return
	_refresh_in = REFRESH_SECONDS
	var humans: int = game.session.human_count()
	var room_title: String = room.settings.room_name if not room.settings.room_name.is_empty() else "DARTY"
	_title.text = "플레이어 · %d/%d" % [room.players.size(), room.settings.capacity]
	_subtitle.text = "%s  ·  사람 %d · 봇 %d%s" % [room_title, humans, room.players.size() - humans, _my_ping_text()]
	if not _pinned:
		_hint.text = "Tab 을 톡 누르면 고정돼요(마우스로 볼륨 조절) · 누르고 있으면 떼는 순간 닫혀요"
	for peer: int in _cells:
		var cells: Dictionary = _cells[peer]
		var match_player: MatchPlayer = game.controller.state.find_player(peer)
		(cells.score as Label).text = "%d점" % match_player.score if match_player != null else "-"
		var member: RoomPlayer = room.find_player(peer)
		if member != null: (cells.ping as Label).text = _ping_text(member)
		if cells.has("status"):
			(cells.status as Label).text = _my_voice_text()


func _build_rows(room: RoomState) -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_cells.clear()
	var players: Array[RoomPlayer] = []
	players.assign(room.players)
	players.sort_custom(func(a: RoomPlayer, b: RoomPlayer) -> bool: return a.seat < b.seat)
	for player in players:
		_rows.add_child(_row(player, room))


## 한 줄: 자리 색 이름 · 표식(나/방장/봇) · 점수 · 핑 · 말하는 중 스피커 · 목소리 볼륨(다른 사람) 또는 내 마이크 상태.
func _row(player: RoomPlayer, room: RoomState) -> Control:
	var line := PanelContainer.new()
	line.add_theme_stylebox_override("panel", Style.flat(Color(Style.INK, 0.55), Color(PlayerLook.COLORS[player.seat], 0.8), 2, 12, 14, 8))
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	line.add_child(box)
	var mine: bool = player.peer_id == game.controller.local_peer_id
	var title := Style.label(box, PlayerLook.tag(player.seat, player.display_name), 22, PlayerLook.COLORS[player.seat].lightened(0.35))
	title.custom_minimum_size.x = 230
	title.clip_text = true
	var marks := PackedStringArray()
	if mine: marks.append("나")
	if player.peer_id == room.host_peer_id: marks.append("방장")
	if player.is_bot: marks.append("봇")
	var mark := Style.label(box, " · ".join(marks), 16, Style.GOLD)
	mark.custom_minimum_size.x = 90
	var score := Style.label(box, "-", 20)
	score.custom_minimum_size.x = 70
	var ping := Style.label(box, _ping_text(player), 16, Style.MUTED)
	ping.custom_minimum_size.x = 70
	var speaker := TextureRect.new()
	speaker.texture = UiIcon.speaker_texture()
	speaker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	speaker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	speaker.custom_minimum_size = Vector2(34, 34)
	speaker.pivot_offset = Vector2(17, 17)
	speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(speaker)
	var cells: Dictionary = {"speaker": speaker, "score": score, "ping": ping}
	if player.is_bot:
		Style.label(box, "봇 · 목소리 없음", 17, Style.MUTED)
	elif mine:
		cells.status = Style.label(box, _my_voice_text(), 17, Style.MINT)
	else:
		box.add_child(_volume_control(player.display_name))
	_cells[player.peer_id] = cells
	return line


## 다른 사람 목소리 볼륨(0~200%) + 음소거. 바꾸는 즉시 voice_chat.gd 가 그 사람 재생기에 적용한다.
func _volume_control(person: String) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bar := HSlider.new()
	bar.min_value = 0
	bar.max_value = 200
	bar.step = 5
	bar.value = Preferences.person_volume(person) * 100
	bar.custom_minimum_size.x = 170
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(bar)
	var shown := Style.label(box, "%d%%" % roundi(bar.value), 17)
	shown.custom_minimum_size.x = 56
	var mute := CheckButton.new()
	mute.text = "음소거"
	mute.button_pressed = Preferences.person_muted(person)
	mute.add_theme_font_size_override("font_size", 16)
	box.add_child(mute)
	bar.value_changed.connect(func(value: float) -> void:
		shown.text = "%d%%" % roundi(value)
		Preferences.set_person(person, value / 100.0, mute.button_pressed))
	mute.toggled.connect(func(on: bool) -> void: Preferences.set_person(person, bar.value / 100.0, on))
	return box


## 내 마이크 상태 한 줄(설정 창의 방식·키를 그대로 보여 준다).
func _my_voice_text() -> String:
	var voice: VoiceChat = game.session.voice if game.session != null else null
	if not Preferences.voice_enabled or voice == null:
		return "음성 채팅 꺼짐 · Esc 설정"
	if not voice.has_listeners():
		return "들을 사람이 없어요(혼자)"
	if not voice.input_active:
		return "마이크를 열 수 없어요 · Esc 설정에서 장치 확인"
	if Preferences.voice_mode == Preferences.VOICE_DETECT:
		return "음성 감지 · 말하면 자동으로 나가요"
	return "%s 누르고 말하기" % Preferences.VOICE_KEY_NAMES[Preferences.VOICE_KEYS.find(Preferences.voice_key)]


## 핑(왕복 시간). 방장은 모든 손님 것을 알고, 손님은 방장까지의 자기 것만 안다.
func _ping_text(player: RoomPlayer) -> String:
	if player.is_bot:
		return ""
	var enet := game.multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet == null:
		return ""
	if game.session.is_host() and player.peer_id != game.session.local_peer_id:
		var peer := enet.get_peer(player.peer_id)
		return "%dms" % int(peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)) if peer != null else ""
	return ""


func _my_ping_text() -> String:
	var enet := game.multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet == null or game.session.is_host():
		return ""
	var peer := enet.get_peer(NetworkSession.HOST_ID)
	return "  ·  내 핑 %dms" % int(peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)) if peer != null else ""
