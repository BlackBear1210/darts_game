class_name BackendConnection
extends Node
## 로컬 계정 API 연결과 서버 결과 전송. 경기 물리·점수는 계산하지 않는다.

signal changed
signal result_saved

var base_url: String = ""
var token: String = ""
var profile: Dictionary = {}
var status: String = "개발 계정 로그인 전"
var busy: bool = false

var _server_key: String = ""
var _outbox_dir: String = ""
var _pending: Dictionary = {}
var _posting: bool = false
var _retry_at: int = 0
var _result_id: String = ""
var _finished: bool = false


func configure(url: String, dedicated: bool, data_dir: String = "") -> Error:
	# 개발 API는 loopback에만 연다. 외부 서비스의 HTTPS/Steam 인증은 별도 단계다.
	var prefix: String = "http://127.0.0.1:"
	var port_text := url.trim_prefix(prefix)
	if not url.begins_with(prefix) or not port_text.is_valid_int() or int(port_text) < 1024 or int(port_text) > 65535:
		return ERR_INVALID_PARAMETER
	base_url = url
	if not dedicated:
		return OK
	_server_key = OS.get_environment("DART_SERVER_KEY")
	if _server_key.length() < 32:
		return ERR_UNAUTHORIZED
	_outbox_dir = data_dir
	if _outbox_dir.is_empty():
		_outbox_dir = "res://.godot/backend_outbox" if OS.has_feature("editor") else OS.get_executable_path().get_base_dir().path_join("data/results")
	_outbox_dir = ProjectSettings.globalize_path(_outbox_dir)
	var error := DirAccess.make_dir_recursive_absolute(_outbox_dir)
	if error != OK:
		return error
	var probe := FileAccess.open(_outbox_dir.path_join(".write_check"), FileAccess.WRITE)
	if probe == null:
		return ERR_FILE_CANT_WRITE
	probe.close()
	DirAccess.remove_absolute(_outbox_dir.path_join(".write_check"))
	for file_name in DirAccess.get_files_at(_outbox_dir):
		if file_name.ends_with(".json"):
			var record: Variant = JSON.parse_string(FileAccess.get_file_as_string(_outbox_dir.path_join(file_name)))
			if record is Dictionary and _valid_id(file_name.get_basename()):
				_pending[file_name.get_basename()] = record
	return OK


func login(display_name: String, password: String) -> bool:
	if busy:
		return false
	busy = true
	status = "개발 계정 로그인 중..."
	changed.emit()
	var response := await _request("/v1/dev/login", HTTPClient.METHOD_POST, {"name": display_name, "password": password})
	busy = false
	if response.code == 200:
		token = str(response.data.token)
		profile = response.data.profile
		status = "개발 계정 로그인 완료"
	else:
		token = ""
		profile = {}
		match str(response.data.get("error", "")):
			"invalid_credentials":
				status = "로그인 실패: 이름 또는 비밀번호를 확인하세요."
			"password_requires_8_to_128_characters":
				status = "로그인 실패: 비밀번호는 8~128자로 입력하세요."
			"name_requires_1_to_20_printable_characters":
				status = "로그인 실패: 이름은 앞뒤 공백 없이 1~20자로 입력하세요."
			_:
				status = "로그인 실패: 로컬 계정 서버 연결을 확인하세요."
	changed.emit()
	return not token.is_empty()


func refresh_profile() -> void:
	if token.is_empty():
		return
	var response := await _request("/v1/profile", HTTPClient.METHOD_GET, {}, token)
	if response.code == 200:
		profile = response.data
		status = "프로필 갱신 완료"
	else:
		status = "프로필 조회 실패: 다시 로그인하세요"
	changed.emit()


func verify_session(session_token: String) -> Dictionary:
	if session_token.is_empty() or session_token.length() > 256:
		return {}
	var response := await _request("/internal/session/verify", HTTPClient.METHOD_POST, {"token": session_token}, _server_key)
	return response.data if response.code == 200 else {}


func watch_match(controller: MatchController, accounts: Dictionary) -> void:
	_result_id = Crypto.new().generate_random_bytes(16).hex_encode()
	_finished = false
	controller.changed.connect(_observe_match.bind(controller, accounts.duplicate()))


func _observe_match(controller: MatchController, accounts: Dictionary) -> void:
	var state := controller.state
	if state.phase != MatchState.Phase.FINISHED:
		if _finished:
			_result_id = Crypto.new().generate_random_bytes(16).hex_encode()
			_finished = false
		return
	if _finished:
		return
	_finished = true
	# 중도 이탈/봇/다른 규칙 경기는 현재 프로필 전적으로 집계하지 않는다.
	if controller.config.rounds != 5 or controller.config.darts_per_turn != 3 or state.round_number != 5 or state.players.size() != accounts.size() or accounts.size() < 2:
		return
	var players: Array[Dictionary] = []
	for player in state.players:
		if player.is_bot or not accounts.has(player.peer_id):
			return
		players.append({"account_id": accounts[player.peer_id], "score": player.score})
	var record := {"rules": {"rounds": 5, "darts_per_turn": 3}, "players": players}
	var temporary := _outbox_dir.path_join(_result_id + ".tmp")
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		printerr("경기 결과 대기 파일 저장 실패")
		return
	file.store_string(JSON.stringify(record))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or DirAccess.rename_absolute(temporary, _outbox_dir.path_join(_result_id + ".json")) != OK:
		printerr("경기 결과 대기 파일 확정 실패")
		return
	_pending[_result_id] = record
	_retry_at = 0


func _process(_delta: float) -> void:
	if _server_key.is_empty() or _pending.is_empty() or _posting or Time.get_ticks_msec() < _retry_at:
		return
	_deliver_next()


func _deliver_next() -> void:
	_posting = true
	var id: String = _pending.keys()[0]
	var response := await _request("/internal/results/" + id, HTTPClient.METHOD_POST, _pending[id], _server_key)
	if response.code == 200:
		# 삭제 실패해도 같은 ID의 재전송은 백엔드에서 중복 반영하지 않는다.
		DirAccess.remove_absolute(_outbox_dir.path_join(id + ".json"))
		_pending.erase(id)
		print("경기 결과 저장 완료: ", id)
		result_saved.emit()
	else:
		printerr("경기 결과 저장 대기 (HTTP %d, %s). 5초 뒤 재시도합니다." % [response.code, str(response.data.get("error", "연결 실패"))])
	_retry_at = Time.get_ticks_msec() + 5000
	_posting = false


func _request(path: String, method: HTTPClient.Method, body: Dictionary = {}, bearer: String = "") -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = 5.0
	request.body_size_limit = 16384
	request.max_redirects = 0
	add_child(request)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if not bearer.is_empty():
		headers.append("Authorization: Bearer " + bearer)
	var error := request.request(base_url + path, headers, method, JSON.stringify(body) if method != HTTPClient.METHOD_GET else "")
	if error != OK:
		request.queue_free()
		return {"code": 0, "data": {}}
	var result: Array = await request.request_completed
	request.queue_free()
	var data: Variant = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
	return {"code": int(result[1]) if result[0] == HTTPRequest.RESULT_SUCCESS else 0, "data": data if data is Dictionary else {}}


func _valid_id(id: String) -> bool:
	return id.length() == 32 and id.is_valid_hex_number(false)
