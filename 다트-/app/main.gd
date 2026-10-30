extends Node
## 지속되는 연결 노드와 교체되는 화면을 조립한다.

const GAME_SCENE: PackedScene = preload("res://game/game.tscn")
const HUD_SCENE: PackedScene = preload("res://ui/game_hud.tscn")

@onready var session: NetworkSession = $NetworkSession
@onready var lobby: LobbyView = $Lobby

@export var developer_mode: bool = false

const FrontDoor = preload("res://lobby/front_door.gd")
const SettingsPanel = preload("res://ui/settings_panel.gd")
const Preferences = preload("res://ui/player_preferences.gd")
var front: Control
var settings_panel: CanvasLayer
var _account_open: bool = false
var _lounge_memory: Dictionary = {}
var _game: GameView
var _hud: GameHUD
var _loaded_match_id: int = 0
var _dedicated: bool = false
var _backend: BackendConnection


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	Preferences.load_saved()
	front = FrontDoor.new()
	front.name = "FrontDoor"
	add_child(front)
	front.host_requested.connect(func(options: RoomSettings, player_name: String, password: String, port: int) -> void:
		session.host_room(player_name, port, options, password))
	front.join_requested.connect(func(player_name: String, address: String, port: int, code: String, password: String) -> void:
		session.join_room(player_name, address, port, code, password))
	front.settings_requested.connect(open_settings)
	front.login_requested.connect(func() -> void:
		if _backend == null: front.show_status("로그인은 추후 계정 서비스 연결 후 사용할 수 있습니다. 지금은 게스트로 플레이하세요.")
		else:
			_account_open = true
			front.hide()
			lobby.show())
	_dedicated = OS.has_feature("dedicated_server") or args.has("--server")
	if not _dedicated and args.has("--port"):
		var port_index := args.find("--port") + 1
		if port_index < args.size() and args[port_index].is_valid_int():
			lobby.get_node("%PortInput").value = int(args[port_index])
	if args.has("--backend-url") and not _configure_backend(args):
		get_tree().quit(1)
		return
	lobby.host_requested.connect(session.host_room)
	lobby.join_requested.connect(_join_room)
	lobby.ready_requested.connect(session.set_ready)
	lobby.start_requested.connect(session.start_match)
	lobby.leave_requested.connect(session.leave_room)
	session.changed.connect(_refresh_screen)
	_refresh_screen()
	developer_mode = (developer_mode or args.has("--developer")) and not _dedicated and _backend == null and OS.is_debug_build() and not args.has("--normal") and not args.has("--role")
	if _dedicated:
		var port: int = NetworkSession.DEFAULT_PORT
		if args.has("--port"):
			var index := args.find("--port") + 1
			if index >= args.size() or not args[index].is_valid_int():
				printerr("--port requires an integer (1024~65535)")
				get_tree().quit(1)
				return
			port = int(args[index])
		var error := session.host_dedicated(port)
		if error != OK:
			printerr("Dedicated server startup failed: %s" % error_string(error))
			get_tree().quit(1)
			return
		print("Dedicated server listening on UDP %d (2~4 players)" % port)
	session.developer_authorized = developer_mode
	if developer_mode and args.has("--quick-test"):
		_boot_developer.call_deferred()


func _boot_developer() -> void:
	session.host_room("플레이어", NetworkSession.DEFAULT_PORT)
	if not session.is_host():
		return
	session.enable_bots()
	session.set_ready(true)
	session.start_match()


func _refresh_screen() -> void:
	var social: bool = session.room.settings.social_lobby
	var in_game: bool = session.room.phase != RoomState.Phase.LOBBY or (social and session.local_peer_id != 0 and not session.is_connecting)
	lobby.visible = not in_game and not _dedicated and _account_open
	if front != null:
		front.visible = not in_game and not _dedicated and not _account_open
		front.show_status(session.message if session.local_peer_id == 0 else "", session.is_connecting)
	lobby.render(session.room, session.local_peer_id, session.is_connecting, session.message)
	if not in_game:
		_remove_game()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if _game != null and (_game.controller.state.match_id != session.room.match_id or (session.room.phase == RoomState.Phase.LOBBY and _game.controller.state.phase != MatchState.Phase.WAITING)):
		_remove_game()
	if _game == null:
		_game = GAME_SCENE.instantiate() as GameView
		_game.name = "Game"
		add_child(_game)
		_game.developer_enabled = developer_mode
		_game.controller.developer_enabled = developer_mode
		_game.configure(session.room, session.local_peer_id, session)
		if social and session.room.phase != RoomState.Phase.LOBBY:
			# 로딩 장면을 교체해도 참여한 사람은 테이블에 앉아서 카드 턴을 맞는다.
			for player in session.room.players:
				_game.force_seat(player.peer_id)
		if _game.lounge != null and not _lounge_memory.is_empty():
			_game.lounge.objects.assign(_lounge_memory.objects)
			_game.lounge.music = _lounge_memory.music.duplicate(true)
			_game.lounge.intoxication = _lounge_memory.intoxication.duplicate(true)
		_game.settings_requested.connect(open_settings)
		session.check_ready = _game.is_seated
		if _dedicated and _backend != null:
			_backend.watch_match(_game.controller, session.account_ids)
		if _dedicated:
			_game.set_process_unhandled_input(false)
			_game.camera.current = false
		else:
			_hud = HUD_SCENE.instantiate() as GameHUD
			_hud.name = "GameHUD"
			add_child(_hud)
			_hud.leave_requested.connect(session.leave_room)
			_hud.lobby_requested.connect(session.return_to_lobby)
			_hud.configure(_game.controller, _game.throw_input)
	_game.sync_room(session.room)
	if session.room.phase == RoomState.Phase.PLAYING:
		_game.controller.start()
	if not _dedicated and session.room.phase == RoomState.Phase.LOADING and _loaded_match_id != session.room.match_id:
		_loaded_match_id = session.room.match_id
		# 화면 생성과 signal 처리를 끝낸 뒤 로딩 완료를 알린다.
		session.confirm_loaded.call_deferred(_loaded_match_id)


func _remove_game() -> void:
	if _game != null:
		if _game.lounge != null and session.local_peer_id != 0:
			_lounge_memory = {"objects": _game.lounge.objects.duplicate(true), "music": _game.lounge.music.duplicate(true), "intoxication": _game.lounge.intoxication.duplicate(true)}
		else: _lounge_memory.clear()
		remove_child(_game)
		_game.queue_free()
		_game = null
	if _hud != null:
		remove_child(_hud)
		_hud.queue_free()
		_hud = null
	_loaded_match_id = 0
	if session.local_peer_id == 0: _lounge_memory.clear()


func _configure_backend(args: PackedStringArray) -> bool:
	_backend = BackendConnection.new()
	_backend.name = "Backend"
	add_child(_backend)
	var url_index := args.find("--backend-url") + 1
	var url: String = args[url_index] if url_index < args.size() else ""
	var data_dir: String = ""
	if args.has("--outbox-dir"):
		var index := args.find("--outbox-dir") + 1
		data_dir = args[index] if index < args.size() else ""
	var error := _backend.configure(url, _dedicated, data_dir)
	if error != OK:
		printerr("Backend configuration failed: ", error_string(error))
		return false
	session.backend = _backend
	if _dedicated:
		_backend.result_saved.connect(func() -> void: session.receive_game_event.rpc("profile_saved", {}))
	else:
		lobby.enable_accounts()
		lobby.login_requested.connect(_login)
		lobby.profile_requested.connect(_backend.refresh_profile)
		_backend.changed.connect(_refresh_account_view)
		session.game_event.connect(func(kind: String, _data: Dictionary) -> void:
			if kind == "profile_saved":
				_backend.refresh_profile())
		_refresh_account_view()
	return true


func _login(display_name: String, password: String) -> void:
	if session.local_peer_id != 0 or session.is_connecting:
		return
	await _backend.login(display_name, password)


func _refresh_account_view() -> void:
	lobby.render_account(_backend.status, _backend.profile, _backend.busy)


func _join_room(display_name: String, address: String, port: int) -> void:
	if _backend != null:
		if _backend.token.is_empty() or _backend.busy:
			session.message = "먼저 개발 계정으로 로그인하세요."
			session.changed.emit()
			return
		display_name = str(_backend.profile.name)
	session.join_room(display_name, address, port)


func open_settings(mode: String = "personal") -> void:
	if is_instance_valid(settings_panel): return
	settings_panel = SettingsPanel.new()
	settings_panel.session = session
	settings_panel.developer = developer_mode
	settings_panel.mode = mode
	settings_panel.closed.connect(func() -> void:
		settings_panel = null
		if _game != null: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	settings_panel.leave_requested.connect(session.leave_room)
	add_child(settings_panel)

func _input(event: InputEvent) -> void:
	if is_instance_valid(settings_panel): return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _account_open:
			_account_open = false
			_refresh_screen()
		else: open_settings()
		get_viewport().set_input_as_handled()
