class_name GameHUD
extends CanvasLayer
## 경기 상태를 표시하고 사용자 요청을 소유 노드에 전달한다.

signal leave_requested
signal lobby_requested

var game: GameView
var controller: MatchController
var throw_input: DartThrowController
var _root: Control
var _score: Label
var _turn: Label
var _help: Label
var _result: Label
var _charge: ProgressBar
var _buttons: HBoxContainer
var _restart: Button
var _lobby: Button
var _cross: Label
var _preview: TextureRect
var _bot_label: Label
var _viewport: SubViewport
var _bot_camera: Camera3D
var _selected_bot: int = 0
var _preview_enabled: bool = true
var _notice_text: String = ""
var _notice_at: float = 0


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_score = _label(Vector2(18, 16), 19)
	_turn = _label(Vector2(18, 175), 22)
	_help = _label(Vector2(18, -122), 16)
	_help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_KEEP_SIZE)
	_help.position = Vector2(18, -122)
	_result = _label(Vector2(18, 315), 20)
	_result.custom_minimum_size.x = 315
	_result.size.x = 315
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_charge = ProgressBar.new()
	_charge.position = Vector2(18, 275)
	_charge.size = Vector2(260, 24)
	_charge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_charge)
	_cross = _label(Vector2.ZERO, 28)
	_cross.text = "+"
	_cross.size = Vector2(32, 40)
	_cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cross.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	_buttons = HBoxContainer.new()
	_buttons.position = Vector2(18, 445)
	_root.add_child(_buttons)
	_restart = _button("재경기", _buttons, func() -> void:
		controller.restart()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	_lobby = _button("대기실 / 봇 교체", _buttons, func() -> void: lobby_requested.emit())
	_button("시작 화면으로", _buttons, func() -> void: leave_requested.emit())
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(320, 180)
	_viewport.gui_disable_input = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_bot_camera = Camera3D.new()
	_bot_camera.fov = 75
	_viewport.add_child(_bot_camera)
	_bot_camera.current = true
	_preview = TextureRect.new()
	_preview.texture = _viewport.get_texture()
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_SCALE
	_root.add_child(_preview)
	_bot_label = _label(Vector2.ZERO, 17)


func configure(match_controller: MatchController, input: DartThrowController) -> void:
	controller = match_controller
	throw_input = input
	game = controller.get_parent() as GameView
	_viewport.world_3d = game.get_world_3d()


func _label(at: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(label)
	return label


func _button(text: String, parent: Node, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _unhandled_input(event: InputEvent) -> void:
	if game == null or not game.developer_enabled or not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F1:
			_preview_enabled = not _preview_enabled
		KEY_F2:
			_selected_bot += 1
		KEY_F3:
			controller.developer_skip()
		KEY_F4:
			var bots := _bots()
			if not bots.is_empty():
				controller.developer_bot_turn(bots[_selected_bot % bots.size()].identity.peer_id)


func _bots() -> Array[PlayerView]:
	var bots: Array[PlayerView] = []
	for actor: PlayerView in game.actors.values():
		if actor.identity.is_bot:
			bots.append(actor)
	return bots


func _process(_delta: float) -> void:
	if game == null:
		return
	_help.position = Vector2(18, _root.size.y - (140 if game.developer_enabled else 116))
	_buttons.position = Vector2(18, _root.size.y - 38)
	var state := controller.state
	var lines := PackedStringArray(["DART PARTY  /  최고 누적 점수"])
	for player in state.players:
		lines.append("%s%s  %d점" % ["▶ " if player == state.active_player() else "   ", player.display_name, player.score])
	_score.text = "\n".join(lines)
	var active_name: String = state.active_player().display_name if state.active_player() != null else "대기"
	_turn.text = "라운드 %d / %d · %s\n남은 시간 %.1f초 · 다트 %d / %d발" % [state.round_number, controller.config.rounds, active_name, controller.remaining_seconds(), state.darts_left, controller.config.darts_per_turn]
	var id: int = controller.local_peer_id
	var seated: bool = game.is_seated(id)
	var seat_text: String = "E: 일어서기" if seated else ("E: 착석 가능 (선택)" if game.can_sit(id) else "서 있는 상태로도 투척 가능")
	var can_throw: bool = state.phase == MatchState.Phase.AIMING and state.active_player() != null and state.active_player().peer_id == id
	var throw_status: String = "투척 가능: 왼쪽 버튼을 누르고 놓으세요"
	if state.phase == MatchState.Phase.FINISHED:
		throw_status = "경기 종료"
	elif state.active_player() == null or state.active_player().peer_id != id:
		throw_status = "다른 플레이어 차례입니다"
	elif state.phase == MatchState.Phase.FLIGHT:
		throw_status = "다트 발사 중"
	elif state.phase == MatchState.Phase.SETTLING:
		throw_status = "착탄 정산 중"
	elif Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		throw_status = "게임 화면 클릭: 마우스 복귀"
	elif throw_input.charging:
		throw_status = "충전 중: 버튼을 놓으면 발사"
	_charge.value = throw_input.timing * 100
	_charge.visible = can_throw
	_help.text = "%s · %s\nWASD 이동 · 마우스 시점 · Space 점프 · Ctrl 숙이기\n왼쪽 버튼 유지: 충전 / 놓기: 투척 · Esc: 마우스 해제/복귀" % [seat_text, throw_status]
	if game.developer_enabled:
		_help.text += "\n개발: F1 봇 화면 · F2 다음 봇 · F3 턴 종료 · F4 선택 봇 차례"
	_result.text = ""
	if not state.last_hit.is_empty():
		_result.text = str(state.last_hit.reason)
	if controller.notice != _notice_text:
		_notice_text = controller.notice
		_notice_at = controller._now()
	if controller._now() - _notice_at < 5:
		_result.text += "\n" + _notice_text
	var finished: bool = state.phase == MatchState.Phase.FINISHED
	_cross.visible = not finished
	_buttons.visible = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or finished
	_restart.visible = finished and controller.session.is_room_host() and state.players.size() >= 2
	_lobby.visible = controller.session.is_room_host()
	if finished:
		_result.text = "경기 종료\n" + ranking_text()
	_update_bot_view()


func ranking_text() -> String:
	var players: Array[MatchPlayer] = controller.state.players.duplicate()
	players.sort_custom(func(a: MatchPlayer, b: MatchPlayer) -> bool: return a.score > b.score)
	var lines := PackedStringArray()
	var rank: int = 0
	var previous: int = -1
	for index in range(players.size()):
		if players[index].score != previous:
			rank = index + 1
		previous = players[index].score
		lines.append("%d위  %s  %d점" % [rank, players[index].display_name, players[index].score])
	return "\n".join(lines)


func _update_bot_view() -> void:
	var bots := _bots()
	var show: bool = game.developer_enabled and _preview_enabled and not bots.is_empty()
	_preview.visible = show
	_bot_label.visible = show
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if show else SubViewport.UPDATE_DISABLED
	if not show:
		return
	var bot: PlayerView = bots[_selected_bot % bots.size()]
	_bot_camera.global_position = bot.eye_position()
	_bot_camera.global_rotation = Vector3(bot.pitch, bot.rotation.y, 0)
	_bot_camera.cull_mask = 0xfffff & ~(1 << (bot.identity.seat + 1))
	var width: float = minf(320, _root.size.x * 0.32)
	_preview.size = Vector2(width, width * 9.0 / 16.0)
	_preview.position = Vector2(_root.size.x - width - 16, 40)
	_bot_label.position = _preview.position - Vector2(0, 26)
	_bot_label.text = "%s  /  1인칭 시야" % bot.identity.display_name
