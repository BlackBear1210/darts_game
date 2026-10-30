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

# 착석은 GameView가 검사한다. 비밀번호 검증값은 공개 RoomState에 넣지 않는다.
var check_ready: Callable
var developer_authorized: bool = false
var _join_code: String = ""
var _join_password: String = ""
var _password_verifier: String = ""
var _challenges: Dictionary = {}
var room_port: int = DEFAULT_PORT

var room := RoomState.new()
var local_peer_id: int = 0
var is_connecting: bool = false
var message: String = "오늘의 한 판, 함께 시작해 볼까요?"
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


func host_room(display_name: String, port: int = DEFAULT_PORT, options: RoomSettings = null, password: String = "") -> void:
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
	if options != null:
		room.settings = RoomSettings.from_snapshot(options.to_snapshot())
	room_port = port
	room.room_code = Crypto.new().generate_random_bytes(4).hex_encode().to_upper()
	_password_verifier = password.sha256_text() if not password.is_empty() else ""
	room.has_password = not _password_verifier.is_empty()
	room.add_player(HOST_ID, _clean_name(display_name))
	if room.settings.solo: room.add_bots(room.settings.bot_count)
	message = "방을 만들었습니다. 참가자를 기다리는 중입니다."
	_publish_room()


func join_room(display_name: String, address: String, port: int = DEFAULT_PORT, code: String = "", password: String = "") -> void:
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
	_join_code = code.strip_edges().to_upper()
	_join_password = password
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
	_request_challenge.rpc_id(HOST_ID)


@rpc("any_peer", "call_remote", "reliable")
func _register_player(display_name: String, session_token: String = "", code: String = "", proof: String = "") -> void:
	if not is_host():
		return
	var sender := multiplayer.get_remote_sender_id()
	var player_name := _clean_name(display_name)
	if not multiplayer.get_peers().has(sender) or room.find_player(sender) != null:
		return
	if room.settings.solo:
		_reject_join.rpc_id(sender, "싱글 연습방에는 참가할 수 없습니다.")
		return
	if room.settings.private_room and code != room.room_code:
		_reject_join.rpc_id(sender, "초대 코드가 일치하지 않습니다.")
		return
	if not code.is_empty() and code != room.room_code:
		_reject_join.rpc_id(sender, "다른 방의 초대 코드입니다.")
		return
	var nonce: String = str(_challenges.get(sender, ""))
	_challenges.erase(sender)
	if room.has_password and (nonce.is_empty() or proof != (nonce + _password_verifier).sha256_text()):
		_reject_join.rpc_id(sender, "방 비밀번호가 일치하지 않습니다.")
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
	if room.players.size() >= room.settings.capacity:
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
	if value and room.settings.social_lobby and (not check_ready.is_valid() or not check_ready.call(peer_id)):
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
	# 준비 버튼뿐 아니라 미참여자의 이탈 뒤에도 남은 전원의 참여를 평가한다.
	if room.settings.social_lobby and room.can_start(): _start_match.call_deferred()


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
	if not is_host():
		return
	_challenges.erase(peer_id)
	if room.find_player(peer_id) == null:
		if room.settings.social_lobby and room.can_start(): _start_match.call_deferred()
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
	_challenges.clear()
	_password_verifier = ""
	_join_password = ""
	_join_code = ""
	check_ready = Callable()
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


# 비밀번호 원문 대신 연결마다 새로 만든 nonce의 응답을 보낸다.
# 운영 로그인/인터넷 중계는 별도 백엔드 영역이며 이 코드는 LAN 방 입장용이다.
@rpc("any_peer", "call_remote", "reliable")
func _request_challenge() -> void:
	if not is_host(): return
	var sender: int = multiplayer.get_remote_sender_id()
	if room.find_player(sender) != null or _challenges.has(sender): return
	var nonce: String = Crypto.new().generate_random_bytes(16).hex_encode()
	_challenges[sender] = nonce
	_receive_challenge.rpc_id(sender, nonce)

@rpc("authority", "call_remote", "reliable")
func _receive_challenge(nonce: String) -> void:
	if not is_connecting: return
	var proof: String = (nonce + _join_password.sha256_text()).sha256_text()
	_register_player.rpc_id(HOST_ID, _local_name, backend.token if backend != null else "", _join_code, proof)
	_join_password = ""

func invitation() -> String:
	var address: String = "127.0.0.1"
	for candidate in IP.get_local_addresses():
		if candidate.begins_with("192.168.") or candidate.begins_with("10.") or candidate.begins_with("172."):
			address = candidate
			break
	return "DARTY-%s-%d-%s" % [address, room_port, room.room_code]

func change_settings(data: Dictionary) -> void:
	if is_host(): _accept_settings(local_peer_id, data)
	elif is_room_host(): _request_settings.rpc_id(HOST_ID, data)

@rpc("any_peer", "call_remote", "reliable")
func _request_settings(data: Dictionary) -> void:
	if is_host(): _accept_settings(multiplayer.get_remote_sender_id(), data)

func _accept_settings(sender: int, data: Dictionary) -> void:
	if sender != room.host_peer_id: return
	var updated := RoomSettings.from_snapshot(data)
	# 참가자 수·방 공개 여부는 개설 시 결정한다. UI를 우회해도 개발자 수치는 바꿀 수 없다.
	for field in ["solo", "capacity", "bot_count", "private_room", "social_lobby"]:
		updated.set(field, room.settings.get(field))
	if not (developer_authorized and sender == HOST_ID):
		for field in ["card_weights", "disabled_cards", "hit_stun", "miss_cooldown"]:
			updated.set(field, room.settings.get(field))
	updated.sanitize()
	if room.phase != RoomState.Phase.LOBBY:
		# 진행 중 점수/손패는 보존한다. 새 시간은 다음 턴, 새 확률은 다음 보충부터 쓴다.
		for field in ["rounds", "dart_seconds", "card_seconds", "special_chance"]:
			room.settings.set(field, updated.get(field))
	else:
		room.settings = updated
		# 규칙을 읽고 동의한 준비만 유효하다. 규칙이 바뀌면 다시 참여해야 한다.
		for player in room.players: player.is_ready = player.is_bot
	_publish_room()
