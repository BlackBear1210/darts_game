class_name NetworkSession
extends Node
## 연결과 RPC의 경계. 이 노드는 화면 전환 중에도 같은 경로에 유지한다.

signal changed
signal game_action(sender: int, action: String, payload: Array)
signal game_event(kind: String, data: Dictionary)
signal movement_input(sender: int, match_id: int, sequence: int, controls: Dictionary)
signal movement_snapshot(match_id: int, sequence: int, poses: Array)

const DEFAULT_PORT: int = 7000
const HOST_ID: int = 1
const CONNECTION_TIMEOUT: float = 8.0
const LOADING_TIMEOUT: float = 10.0
const MAX_NAME_LENGTH: int = 20

var room := RoomState.new()
var local_peer_id: int = 0
var is_connecting: bool = false
var message: String = "이름을 입력하고 방을 만들거나 참가하세요."
var backend: BackendConnection
var account_ids: Dictionary = {}
var _registering: Dictionary = {}

var _peer: ENetMultiplayerPeer
var _local_name: String = ""
var _timeout: Timer
var _departure_pending: bool = false


func _ready() -> void:
	# 모든 요청은 서버를 통한다. 참가자끼리의 자동 연결 알림/패킷 중계는 필요 없다.
	(multiplayer as SceneMultiplayer).server_relay = false
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_timeout = Timer.new()
	_timeout.one_shot = true
	_timeout.timeout.connect(_on_timeout)
	add_child(_timeout)


func is_host() -> bool:
	# 연결의 서버 권한이다. 선수 방장은 is_room_host()로 구분한다.
	return local_peer_id == HOST_ID


func is_room_host() -> bool:
	return local_peer_id != 0 and local_peer_id == room.host_peer_id


func host_dedicated(port: int = DEFAULT_PORT) -> Error:
	if _peer != null or port < 1024 or port > 65535:
		return ERR_INVALID_PARAMETER
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, 8)
	if error != OK:
		return error
	_peer = peer
	multiplayer.multiplayer_peer = peer
	local_peer_id = HOST_ID
	room = RoomState.new()
	_publish_room()
	return OK


func host_room(display_name: String, port: int = DEFAULT_PORT) -> void:
	if backend != null:
		message = "계정 모드는 전용 서버에 방 참가로 접속하세요."
		changed.emit()
		return
	if _peer != null or not _validate_connection(display_name, port):
		return
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, 8)
	if error != OK:
		message = "방 생성 실패: 포트가 사용 중인지 확인하세요. (%s)" % error_string(error)
		changed.emit()
		return
	_peer = peer
	multiplayer.multiplayer_peer = peer
	local_peer_id = HOST_ID
	room = RoomState.new()
	room.add_player(HOST_ID, _clean_name(display_name))
	message = "방을 만들었습니다. 참가자를 기다리는 중입니다."
	_publish_room()


func join_room(display_name: String, address: String, port: int = DEFAULT_PORT) -> void:
	if _peer != null or not _validate_connection(display_name, port):
		return
	if address.strip_edges().is_empty():
		message = "접속할 방장의 IP 주소를 입력하세요."
		changed.emit()
		return
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address.strip_edges(), port)
	if error != OK:
		message = "접속 요청 실패: %s" % error_string(error)
		changed.emit()
		return
	_local_name = _clean_name(display_name)
	_peer = peer
	multiplayer.multiplayer_peer = peer
	is_connecting = true
	message = "방에 접속하는 중입니다..."
	_timeout.start(CONNECTION_TIMEOUT)
	changed.emit()


func leave_room() -> void:
	_close("방에서 나왔습니다.")


func set_ready(value: bool) -> void:
	if local_peer_id == 0 or is_connecting:
		return
	if is_host():
		_accept_ready(HOST_ID, value)
	else:
		_request_ready.rpc_id(HOST_ID, value)


func start_match() -> void:
	if not is_room_host():
		return
	if is_host():
		_start_match()
	else:
		_request_room_action.rpc_id(HOST_ID, "start")


func _start_match() -> void:
	if not room.can_start():
		return
	# 등록을 마치지 않은 접속까지 기다려야 시작 중인 방에 인원이 끼어들지 않는다.
	var local_players: int = 1 if room.find_player(HOST_ID) != null else 0
	if multiplayer.get_peers().size() != human_count() - local_players:
		message = "접속 중인 참가자가 있습니다. 잠시 후 다시 시작하세요."
		changed.emit()
		return
	room.match_id += 1
	room.phase = RoomState.Phase.LOADING
	for player in room.players:
		player.is_loaded = player.is_bot
	# 접속 후 등록 RPC에서 구체적인 거부 사유를 전달한다.
	_timeout.start(LOADING_TIMEOUT)
	_publish_room()


func confirm_loaded(match_id: int) -> void:
	if is_host():
		_accept_loaded(HOST_ID, match_id)
	elif local_peer_id != 0:
		_confirm_loaded.rpc_id(HOST_ID, match_id)


func return_to_lobby() -> void:
	if not is_room_host():
		return
	if is_host():
		_return_to_lobby()
	else:
		_request_room_action.rpc_id(HOST_ID, "lobby")


@rpc("any_peer", "call_remote", "reliable")
func _request_room_action(action: String) -> void:
	if not is_host() or multiplayer.get_remote_sender_id() != room.host_peer_id:
		return
	match action:
		"start":
			_start_match()
		"lobby":
			_return_to_lobby()


func _return_to_lobby() -> void:
	if room.phase == RoomState.Phase.LOBBY:
		return
	_timeout.stop()
	room.return_to_lobby()
	_peer.refuse_new_connections = false
	_publish_room()


func _validate_connection(display_name: String, port: int) -> bool:
	if _clean_name(display_name).is_empty():
		message = "플레이어 이름을 입력하세요."
	elif port < 1024 or port > 65535:
		message = "포트는 1024~65535 사이로 입력하세요."
	else:
		return true
	changed.emit()
	return false


func _clean_name(display_name: String) -> String:
	return display_name.strip_escapes().strip_edges().left(MAX_NAME_LENGTH)


func _on_connected_to_server() -> void:
	local_peer_id = multiplayer.get_unique_id()
	_register_player.rpc_id(HOST_ID, _local_name, backend.token if backend != null else "")


@rpc("any_peer", "call_remote", "reliable")
func _register_player(display_name: String, session_token: String = "") -> void:
	if not is_host():
		return
	var sender := multiplayer.get_remote_sender_id()
	var player_name := _clean_name(display_name)
	if not multiplayer.get_peers().has(sender) or room.find_player(sender) != null:
		return
	var account_id: String = ""
	if backend != null:
		if _registering.has(sender):
			return
		_registering[sender] = true
		var connection := _peer
		var identity := await backend.verify_session(session_token)
		if _peer != connection:
			return
		_registering.erase(sender)
		if not multiplayer.get_peers().has(sender):
			return
		if identity.is_empty():
			_reject_join.rpc_id(sender, "로그인 인증 실패: 개발 계정에 다시 로그인하세요.")
			return
		account_id = str(identity.account_id)
		if account_ids.values().has(account_id):
			_reject_join.rpc_id(sender, "같은 계정이 이미 방에 접속해 있습니다.")
			return
		player_name = _clean_name(str(identity.name))
	if room.phase != RoomState.Phase.LOBBY:
		_reject_join.rpc_id(sender, "경기가 진행 중이므로 참가할 수 없습니다.")
		return
	if room.players.size() >= RoomState.MAX_PLAYERS:
		for bot in room.players:
			if bot.is_bot:
				room.remove_player(bot.peer_id)
				break
	if player_name.is_empty() or not room.add_player(sender, player_name):
		_reject_join.rpc_id(sender, "방이 가득 찼습니다. 최대 4명까지 참가할 수 있습니다.")
		return
	if not account_id.is_empty():
		account_ids[sender] = account_id
	_publish_room()


@rpc("any_peer", "call_remote", "reliable")
func _request_ready(value: bool) -> void:
	if is_host():
		_accept_ready(multiplayer.get_remote_sender_id(), value)


func _accept_ready(peer_id: int, value: bool) -> void:
	var player := room.find_player(peer_id)
	if room.phase != RoomState.Phase.LOBBY or player == null:
		return
	player.is_ready = value
	_publish_room()


@rpc("any_peer", "call_remote", "reliable")
func _confirm_loaded(match_id: int) -> void:
	if is_host():
		_accept_loaded(multiplayer.get_remote_sender_id(), match_id)


func _accept_loaded(peer_id: int, match_id: int) -> void:
	var player := room.find_player(peer_id)
	if room.phase != RoomState.Phase.LOADING or room.match_id != match_id or player == null:
		return
	player.is_loaded = true
	if room.all_loaded():
		_timeout.stop()
		room.phase = RoomState.Phase.PLAYING
	_publish_room()


func _publish_room() -> void:
	# 먼저 전송하고 로컬 알림을 보낸다. 화면 로딩 콜백이 재진입해도 전송 순서가 유지된다.
	_receive_room.rpc(room.to_snapshot())
	_update_message()
	changed.emit()


@rpc("authority", "call_remote", "reliable")
func _receive_room(snapshot: Dictionary) -> void:
	room = RoomState.from_snapshot(snapshot)
	if room.find_player(local_peer_id) != null and is_connecting:
		is_connecting = false
		_timeout.stop()
	_update_message()
	changed.emit()


func _update_message() -> void:
	match room.phase:
		RoomState.Phase.LOBBY:
			message = "전원 준비 후 방장이 시작할 수 있습니다. (%d/%d)" % [room.players.size(), RoomState.MAX_PLAYERS]
		RoomState.Phase.LOADING:
			message = "모든 참가자의 경기 화면을 기다리는 중입니다..."
		RoomState.Phase.PLAYING:
			message = "전원 입장 완료. 멀티플레이 공간이 열렸습니다."


func _on_peer_disconnected(peer_id: int) -> void:
	if not is_host() or room.find_player(peer_id) == null:
		return
	room.remove_player(peer_id)
	account_ids.erase(peer_id)
	# 같은 poll에서 여러 연결이 닫힐 수 있으므로 ENet 이탈 처리가 끝난 뒤 전송한다.
	if not _departure_pending:
		_departure_pending = true
		_refresh_after_departures.call_deferred()


func _refresh_after_departures() -> void:
	_departure_pending = false
	if not is_host():
		return
	if room.phase == RoomState.Phase.LOADING or human_count() == 0:
		_return_to_lobby()
	else:
		_publish_room()



func _on_connection_failed() -> void:
	_close("접속 실패: 주소·포트·방 상태를 확인하세요. 방이 가득 찼거나 시작 중일 수 있습니다.")


func _on_server_disconnected() -> void:
	_close("방장과 연결이 끊어졌습니다. 방을 다시 만들거나 참가하세요.")


func _on_timeout() -> void:
	if is_connecting:
		_close("접속 시간이 초과되었습니다. 주소·포트와 방 상태를 확인하세요.")
	elif is_host() and room.phase == RoomState.Phase.LOADING:
		_return_to_lobby()
		message = "화면 로딩 시간이 초과되어 로비로 돌아왔습니다."
		changed.emit()


func _close(reason: String) -> void:
	_timeout.stop()
	if _peer != null:
		_peer.close()
	_peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	local_peer_id = 0
	is_connecting = false
	room = RoomState.new()
	account_ids.clear()
	_registering.clear()
	message = reason
	changed.emit()


func human_count() -> int:
	var count: int = 0
	for player in room.players:
		if not player.is_bot:
			count += 1
	return count


func enable_bots() -> void:
	if is_host() and room.phase == RoomState.Phase.LOBBY:
		room.add_bots()
		_publish_room()


@rpc("authority", "call_remote", "reliable")
func _reject_join(reason: String) -> void:
	_close(reason)


# 화면이 사라진 직후 도착한 패킷도 지속 노드에서 받고 구독자가 없으면 폐기한다.
# 이 노드는 규칙을 계산하지 않고 실제 RPC 발신자와 메시지만 전달한다.
@rpc("any_peer", "call_remote", "reliable")
func request_game_action(action: String, payload: Array) -> void:
	if is_host():
		game_action.emit(multiplayer.get_remote_sender_id(), action, payload)


@rpc("authority", "call_remote", "reliable")
func receive_game_event(kind: String, data: Dictionary) -> void:
	game_event.emit(kind, data)


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func request_movement(match_id: int, sequence: int, controls: Dictionary) -> void:
	if is_host():
		movement_input.emit(multiplayer.get_remote_sender_id(), match_id, sequence, controls)


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func receive_movement(match_id: int, sequence: int, poses: Array) -> void:
	movement_snapshot.emit(match_id, sequence, poses)
