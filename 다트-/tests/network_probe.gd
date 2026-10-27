extends Node
## 실제 앱 씬과 실제 ENet 연결을 사용하는 다중 프로세스 검증용 실행기.

var _session: NetworkSession
var _main: Node
var _options: Dictionary = {}
var _last_command: int = 0
var _elapsed: float = 0.0
var _tuned_match: int = 0
var _test_controls: Dictionary = {}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for index in range(0, args.size(), 2):
		_options[args[index].trim_prefix("--")] = args[index + 1]
	call_deferred("_boot")


func _boot() -> void:
	if _options.get("manual-loading", "false") == "true":
		# 화면 없는 참가자로 로딩 완료를 일부러 늦춰 서버의 시작 장벽을 검증한다.
		_main = Node.new()
		_main.name = "Main"
		var session := NetworkSession.new()
		session.name = "NetworkSession"
		_main.add_child(session)
	else:
		var scene: PackedScene = load("res://app/main.tscn")
		_main = scene.instantiate()
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main
	_session = _main.get_node("NetworkSession") as NetworkSession
	if _options.get("manual-loading", "false") == "true":
		_session.changed.connect(_refresh_manual_game)
	if _options.role == "host":
		_session.host_room(_options.name, int(_options.port))
	else:
		if _options.has("backend-url"):
			var backend := _main.get_node("Backend") as BackendConnection
			var account_name: String = OS.get_environment("DART_TEST_ACCOUNT")
			await backend.login(_options.name if account_name.is_empty() else account_name, OS.get_environment("DART_TEST_PASSWORD"))
		_session.join_room(_options.name, "127.0.0.1", int(_options.port))


func _process(delta: float) -> void:
	if _session == null:
		return
	_elapsed += delta
	if _elapsed < 0.1:
		return
	_elapsed = 0.0
	_tune_game()
	_read_command()
	var game := _main.get_node_or_null("Game") as GameView
	if game != null:
		game.send_controls(Vector2(float(_test_controls.get("x", 0)), float(_test_controls.get("y", 0))),
			float(_test_controls.get("yaw", 0)), 0, bool(_test_controls.get("jump", false)), bool(_test_controls.get("crouch", false)))
		_test_controls["jump"] = false
	_write_status()
	return


func _read_command() -> void:
	var path: String = _options.output + ".command.json"
	if not FileAccess.file_exists(path):
		return
	var parser := JSON.new()
	# 외부 실행기가 기록 중인 파일은 다음 프레임에 다시 읽는다.
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return
	var command: Variant = parser.data
	if not command is Dictionary or int(command.id) <= _last_command:
		return
	_last_command = int(command.id)
	match command.action:
		"ready":
			_session.set_ready(command.value)
		"start":
			_session.start_match()
		"raw_room_action":
			_session._request_room_action.rpc_id(1, str(command.value))
		"raw_restart":
			_session.request_game_action.rpc_id(1, "restart", [])
		"lobby":
			_session.return_to_lobby()
		"loaded":
			_session.confirm_loaded(int(command.value))
		"leave":
			_session.leave_room()
		"host":
			_session.host_room(_options.name, int(_options.port))
		"join":
			_session.join_room(_options.name, "127.0.0.1", int(_options.port))
		"profile":
			(_main.get_node("Backend") as BackendConnection).refresh_profile()
		"exit":
			_session.leave_room()
			get_tree().quit()
		"throw":
			var controller := (_main.get_node("Game") as GameView).controller
			controller.submit_throw(Vector2(float(command.value[0]), float(command.value[1])), float(command.value[2]))
		"raw_throw":
			_session.request_game_action.rpc_id(1, "throw", [int(command.value[0]), int(command.value[1]), int(command.value[2]),
				Vector2(float(command.value[3]), float(command.value[4])), float(command.value[5])])
		"seat":
			(_main.get_node("Game") as GameView).request_seat()
		"move":
			_test_controls = {"x": command.value[0], "y": command.value[1], "yaw": command.value[2],
				"jump": command.value[3], "crouch": command.value[4]}
		"stop":
			_test_controls = {}
		"restart":
			(_main.get_node("Game") as GameView).controller.restart()
		"bots":
			_session.enable_bots()
		"dev_skip":
			(_main.get_node("Game") as GameView).controller.developer_skip()
		"dev_bot":
			(_main.get_node("Game") as GameView).controller.developer_bot_turn(int(command.value))



func _refresh_manual_game() -> void:
	var game := _main.get_node_or_null("Game") as GameView
	if _session.room.phase == RoomState.Phase.LOBBY:
		if game != null:
			_main.remove_child(game)
			game.queue_free()
	elif game == null:
		var scene: PackedScene = load("res://game/game.tscn")
		game = scene.instantiate() as GameView
		game.name = "Game"
		_main.add_child(game)
		game.configure(_session.room, _session.local_peer_id, _session)


func _tune_game() -> void:
	var game := _main.get_node_or_null("Game") as GameView
	if game == null or game.controller.state.match_id == _tuned_match: return
	_tuned_match = game.controller.state.match_id
	game.set_process_unhandled_input(false)
	if _options.get("fast-match", "false") == "true" and _session.is_host():
		game.controller.config.settle_seconds = 0.12
		game.controller.config.table_seconds = 1.0
	if _options.get("afk-match", "false") == "true" and _session.is_host():
		game.controller.config.rounds = 1
		game.controller.config.turn_seconds = 0.25
		game.controller.config.settle_seconds = 0.05



func _write_status() -> void:
	var game := _main.get_node_or_null("Game")
	var lobby := _main.get_node_or_null("Lobby") as Control
	var markers := game.get_node("Players").get_child_count() if game != null else 0
	var status := {
		"local_id": _session.local_peer_id,
		"connecting": _session.is_connecting,
		"message": _session.message,
		"room": _session.room.to_snapshot(),
		"markers": markers,
		"lobby_visible": lobby.visible if lobby != null else true,
		"command_id": _last_command,

	}
	var backend := _main.get_node_or_null("Backend") as BackendConnection
	if backend != null:
		status["profile"] = backend.profile
	if game != null:
		var view := game as GameView
		status["match"] = view.controller.state.to_snapshot()
		var poses: Array[Dictionary] = []
		for actor: PlayerView in view.actors.values():
			var motion := actor.to_motion()
			motion["position"] = [actor.position.x, actor.position.y, actor.position.z]
			motion["velocity"] = [actor.velocity.x, actor.velocity.y, actor.velocity.z]
			poses.append(motion)
		status["poses"] = poses
		status["remaining"] = view.controller.remaining_seconds()
		status["table_ready"] = view.table.is_ready
	var file := FileAccess.open(_options.output + ".status.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(status))
