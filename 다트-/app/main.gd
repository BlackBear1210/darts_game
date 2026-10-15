extends Node
## 지속되는 연결 노드와 교체되는 화면을 조립한다.

const GAME_SCENE: PackedScene = preload("res://game/game.tscn")
const HUD_SCENE: PackedScene = preload("res://ui/game_hud.tscn")

@onready var session: NetworkSession = $NetworkSession
@onready var lobby: LobbyView = $Lobby

@export var developer_mode: bool = true

var _game: GameView
var _hud: GameHUD
var _loaded_match_id: int = 0
var _dedicated: bool = false
var _backend: BackendConnection


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
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
	developer_mode = developer_mode and not _dedicated and _backend == null and OS.is_debug_build() and not args.has("--normal") and not args.has("--role")
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
	if developer_mode:
		_boot_developer.call_deferred()


func _boot_developer() -> void:
	session.host_room("PLAYER", NetworkSession.DEFAULT_PORT)
	if not session.is_host():
		return
	session.enable_bots()
	session.set_ready(true)
	session.start_match()


func _refresh_screen() -> void:
	var in_game := session.room.phase != RoomState.Phase.LOBBY
	lobby.visible = not in_game and not _dedicated
	lobby.render(session.room, session.local_peer_id, session.is_connecting, session.message)
	if not in_game:
		_remove_game()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if _game == null:
		_game = GAME_SCENE.instantiate() as GameView
		_game.name = "Game"
		add_child(_game)
		_game.developer_enabled = developer_mode
		_game.controller.developer_enabled = developer_mode
		_game.configure(session.room, session.local_peer_id, session)
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
	_game.controller.sync_roster(session.room)
	if session.room.phase == RoomState.Phase.PLAYING:
		_game.controller.start()
	if not _dedicated and session.room.phase == RoomState.Phase.LOADING and _loaded_match_id != session.room.match_id:
		_loaded_match_id = session.room.match_id
		# 화면 생성과 signal 처리를 끝낸 뒤 로딩 완료를 알린다.
		session.confirm_loaded.call_deferred(_loaded_match_id)


func _remove_game() -> void:
	if _game != null:
		remove_child(_game)
		_game.queue_free()
		_game = null
	if _hud != null:
		remove_child(_hud)
		_hud.queue_free()
		_hud = null
	_loaded_match_id = 0


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
