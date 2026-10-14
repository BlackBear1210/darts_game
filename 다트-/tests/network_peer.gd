extends SceneTree
## 실제 앱 씬과 실제 ENet 연결을 사용하는 다중 프로세스 검증용 실행기.

var _session: NetworkSession
var _main: Node
var _options: Dictionary = {}
var _last_command: int = 0
var _elapsed: float = 0.0
var _tuned_match: int = 0
var _emote_count: int = 0


func _initialize() -> void:
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
	root.add_child(_main)
	current_scene = _main
	_session = _main.get_node("NetworkSession") as NetworkSession
	if _options.get("manual-loading", "false") == "true":
		_session.changed.connect(_refresh_manual_game)
	if _options.role == "host":
		_session.host_room(_options.name, int(_options.port))
	else:
		_session.join_room(_options.name, "127.0.0.1", int(_options.port))


func _process(delta: float) -> bool:
	if _session == null:
		return false
	_elapsed += delta
	if _elapsed < 0.1:
		return false
	_elapsed = 0.0
	_tune_game()
	_read_command()
	_write_status()
	return false


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
		"exit":
			_session.leave_room()
			quit()
		"throw":
			var controller := (_main.get_node("Game") as GameView).controller
			controller.submit_throw(Vector2(float(command.value[0]), float(command.value[1])), float(command.value[2]))
		"mouse_throw":
			var game := _main.get_node("Game") as GameView
			var point := game.camera.unproject_position(game.table.board.global_position)
			var motion := InputEventMouseMotion.new()
			motion.position = point
			game.get_viewport().push_input(motion, true)
			var press := InputEventMouseButton.new()
			press.button_index = MOUSE_BUTTON_LEFT
			press.position = point
			press.pressed = true
			game.get_viewport().push_input(press, true)
			await create_timer(0.4).timeout
			var release := InputEventMouseButton.new()
			release.button_index = MOUSE_BUTTON_LEFT
			release.position = point
			game.get_viewport().push_input(release, true)
		"raw_throw":
			var controller := (_main.get_node("Game") as GameView).controller
			controller._request_throw.rpc_id(1, int(command.value[0]), int(command.value[1]), int(command.value[2]),
				Vector2(float(command.value[3]), float(command.value[4])), float(command.value[5]))
		"choose":
			(_main.get_node("Game") as GameView).controller.choose_card(int(command.value))
		"card":
			(_main.get_node("Game") as GameView).controller.plan_card(int(command.value[0]), int(command.value[1]))
		"emote":
			(_main.get_node("Game") as GameView).controller.request_emote()


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
		game.configure(_session.room, _session.local_peer_id)


func _tune_game() -> void:
	var game := _main.get_node_or_null("Game") as GameView
	if game == null or game.controller.state.match_id == _tuned_match: return
	_tuned_match = game.controller.state.match_id
	game.controller.emote_received.connect(func(_data: Dictionary) -> void: _emote_count += 1)
	if _options.get("fast-match", "false") == "true" and _session.is_host():
		var config := game.controller.config
		config.rounds = 4
		config.turn_seconds = 6.0
		config.transition_seconds = 0.15
		config.flight_seconds = 0.15
		config.settle_seconds = 0.15
		config.card_seconds = 2.5
		config.emote_warning = 0.05
		config.emote_seconds = 0.1
		config.emote_gap = 0.05
	if _options.get("afk-match", "false") == "true" and _session.is_host():
		var config := game.controller.config
		config.rounds = 2
		config.turn_seconds = 0.2
		config.transition_seconds = 0.1
		config.settle_seconds = 0.05
		config.card_seconds = 0.25


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
		"emote_count": _emote_count,
	}
	if game != null:
		var view := game as GameView
		status["match"] = view.controller.state.to_snapshot()
		status["private"] = view.controller.private_cards
		status["table_ready"] = view.table.is_ready
	var file := FileAccess.open(_options.output + ".status.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(status))
