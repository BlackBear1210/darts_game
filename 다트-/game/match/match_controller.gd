class_name MatchController
extends Node
## 턴의 유일한 확정 경로. 비행 중에는 시간 초과/추가 요청/개발자 종료를 받지 않는다.
## 라운드 사이에는 테이블 집합(TABLE)이 있다: 제한시간 안에 자기 자리에 앉지 않은 사람은 자동 착석 + 다음 라운드 슬로우.

signal changed
signal dart_thrown(data: Dictionary)

@export var config: MatchConfig = preload("res://game/match/default_match.tres")

var session: NetworkSession
var state := MatchState.new()
var local_peer_id: int = 0
var solve_throw: Callable
## 테이블 집합 판정용 GameView 함수. check_seated(peer_id) -> bool, force_seat(peer_id). 없으면 집합을 바로 끝낸다.
var check_seated: Callable
var force_seat: Callable
var developer_enabled: bool = false
var notice: String = ""
var _turn_end: float = 0.0
var _phase_end: float = 0.0
var _received_at: float = 0.0
var _remote_seconds: float = 0.0
var _pending_hit: Dictionary = {}
var _request_number: int = 0
var _last_requests: Dictionary = {}


func configure(room: RoomState, peer_id: int, connection: NetworkSession = null) -> void:
	session = connection
	if session != null:
		session.game_action.connect(_receive_action)
		session.game_event.connect(_receive_event)
	config = config.duplicate() as MatchConfig
	local_peer_id = peer_id
	state.match_id = room.match_id
	for identity in room.players:
		var player := MatchPlayer.new()
		player.peer_id = identity.peer_id
		player.display_name = identity.display_name
		player.seat = identity.seat
		player.is_bot = identity.is_bot
		state.players.append(player)
	state.players.sort_custom(func(a: MatchPlayer, b: MatchPlayer) -> bool: return a.seat < b.seat)


func start() -> void:
	if local_peer_id == 1 and state.phase == MatchState.Phase.WAITING:
		_begin_turn()


func remaining_seconds() -> float:
	if multiplayer.is_server():
		return maxf(0, (_turn_end if state.phase == MatchState.Phase.AIMING else _phase_end) - _now())
	return maxf(0, _remote_seconds - (_now() - _received_at))


func submit_throw(aim: Vector2, charge: float) -> void:
	_request_number += 1
	if multiplayer.is_server():
		_accept_throw(local_peer_id, state.match_id, state.turn_id, _request_number, aim, charge)
	else:
		session.request_game_action.rpc_id(1, "throw", [state.match_id, state.turn_id, _request_number, aim, charge])


func _receive_action(sender: int, action: String, payload: Array) -> void:
	if action == "restart" and payload.is_empty() and sender == session.room.host_peer_id:
		restart()
	if action == "throw" and payload.size() == 5:
		if payload[0] is int and payload[1] is int and payload[2] is int and payload[3] is Vector2 and (payload[4] is float or payload[4] is int):
			_accept_throw(sender, payload[0], payload[1], payload[2], payload[3], payload[4])


func _receive_event(kind: String, data: Dictionary) -> void:
	if kind == "match":
		_receive_state(data)
	elif kind == "dart":
		_play_throw(data)


func _accept_throw(sender: int, match_id: int, turn_id: int, request_id: int, aim: Vector2, charge: float) -> void:
	var active := state.active_player()
	if state.phase != MatchState.Phase.AIMING or active == null or active.is_bot:
		return
	if sender != active.peer_id or match_id != state.match_id or turn_id != state.turn_id:
		return
	if state.darts_left <= 0 or _now() >= _turn_end:
		return
	if not aim.is_finite() or not is_finite(charge) or absf(aim.x) > 20 or absf(aim.y) > 20:
		return
	if charge < 0 or charge > 1 or request_id <= int(_last_requests.get(sender, 0)):
		return
	_last_requests[sender] = request_id
	_launch(sender, aim, charge, request_id)


## 봇의 투척. 방장이 봇을 투척선까지 몰고 간 뒤 부른다(GameView._drive_bot).
## 네트워크 발신자가 없으므로 차례·발수·시간·값 범위만 확인하고 사람과 같은 비행 경로로 보낸다.
func bot_throw(aim: Vector2, charge: float) -> void:
	if not multiplayer.is_server() or state.phase != MatchState.Phase.AIMING:
		return
	var active := state.active_player()
	if active == null or not active.is_bot:
		return
	if state.darts_left <= 0 or _now() >= _turn_end:
		return
	if not aim.is_finite() or not is_finite(charge) or charge < 0 or charge > 1:
		return
	_request_number += 1
	_launch(active.peer_id, aim, charge, _request_number)


## 확정된 한 발을 비행으로 보낸다. 사람과 봇이 같은 경로를 쓴다.
func _launch(peer_id: int, aim: Vector2, charge: float, request_id: int) -> void:
	var data: Dictionary = solve_throw.call(aim, charge, peer_id)
	_pending_hit = data.duplicate()
	_pending_hit.merge({"peer_id": peer_id, "request_id": request_id})
	state.darts_left -= 1
	_set_phase(MatchState.Phase.FLIGHT, float(data.duration))
	data.merge({"match_id": state.match_id, "turn_id": state.turn_id, "peer_id": peer_id})
	if session != null:
		session.receive_game_event.rpc("dart", data)
	_play_throw(data)


func _play_throw(data: Dictionary) -> void:
	if data.match_id == state.match_id and data.turn_id == state.turn_id:
		dart_thrown.emit(data)


func _process(_delta: float) -> void:
	if not multiplayer.is_server():
		return
	match state.phase:
		MatchState.Phase.AIMING:
			if _now() >= _turn_end:
				_timeout_turn()
		MatchState.Phase.FLIGHT:
			if _now() >= _phase_end:
				_land_dart()
		MatchState.Phase.SETTLING:
			if _now() >= _phase_end:
				_advance_turn()
		MatchState.Phase.TABLE:
			if _everyone_seated() or _now() >= _phase_end:
				_close_table()


func _begin_turn() -> void:
	state.turn_id += 1
	state.darts_left = config.darts_per_turn
	_pending_hit.clear()
	_turn_end = _now() + config.turn_seconds
	_set_phase(MatchState.Phase.AIMING, config.turn_seconds)


func _timeout_turn() -> void:
	if state.phase != MatchState.Phase.AIMING:
		return
	state.darts_left = 0
	state.last_hit = {"peer_id": state.active_player().peer_id, "points": 0,
		"reason": "시간 초과 · 0점", "request_id": -state.turn_id}
	_set_phase(MatchState.Phase.SETTLING, config.settle_seconds)


func _land_dart() -> void:
	if state.phase != MatchState.Phase.FLIGHT or _pending_hit.is_empty():
		return
	state.active_player().score += int(_pending_hit.points)
	state.last_hit = _pending_hit.duplicate()
	_pending_hit.clear()
	if state.darts_left > 0 and _now() < _turn_end:
		_set_phase(MatchState.Phase.AIMING, _turn_end - _now())
	else:
		state.darts_left = 0
		_set_phase(MatchState.Phase.SETTLING, config.settle_seconds)


func _advance_turn() -> void:
	state.turn_index += 1
	if state.turn_index >= state.players.size():
		state.turn_index = 0
		if state.round_number >= config.rounds:
			_set_phase(MatchState.Phase.FINISHED, 0)
			return
		state.round_number += 1
		_begin_table()
		return
	_begin_turn()


## 라운드 사이 테이블 집합. 지난 라운드의 슬로우는 여기서 풀어, 자리로 걸어올 때는 정상 속도다.
func _begin_table() -> void:
	_pending_hit.clear()
	for player in state.players:
		player.speed_scale = 1.0
	_set_phase(MatchState.Phase.TABLE, config.table_seconds)


func _everyone_seated() -> bool:
	if not check_seated.is_valid():
		return true
	for player in state.players:
		if not player.is_bot and not check_seated.call(player.peer_id):
			return false
	return true


## 전원 착석 또는 제한시간 종료. 서 있는 사람은 자기 자리로 옮기고 다음 라운드 동안 슬로우를 건다.
func _close_table() -> void:
	if state.phase != MatchState.Phase.TABLE:
		return
	var late := PackedStringArray()
	for player in state.players:
		if player.is_bot or not check_seated.is_valid() or check_seated.call(player.peer_id):
			continue
		if force_seat.is_valid():
			force_seat.call(player.peer_id)
		player.speed_scale = config.slow_speed_scale
		late.append(player.display_name)
	if not late.is_empty():
		notice = "지각: %s — 자동 착석, 이번 라운드 이동 속도 %d%%" % [", ".join(late), roundi(config.slow_speed_scale * 100)]
	_begin_turn()


func sync_roster(room: RoomState) -> void:
	if not multiplayer.is_server() or state.players.is_empty():
		return
	var active_id: int = state.active_player().peer_id
	var was_last: bool = state.turn_index == state.players.size() - 1
	var removed_active: bool = false
	var removed: bool = false
	for player in state.players.duplicate():
		if room.find_player(player.peer_id) == null:
			removed_active = removed_active or player.peer_id == active_id
			state.players.erase(player)
			removed = true
	if not removed:
		return
	if state.players.size() < RoomState.MIN_PLAYERS:
		state.turn_index = 0
		notice = "참가자가 2명 미만이어서 경기를 종료했습니다."
		_pending_hit.clear()
		_set_phase(MatchState.Phase.FINISHED, 0)
		return
	if state.phase == MatchState.Phase.FINISHED:
		state.turn_index = mini(state.turn_index, state.players.size() - 1)
		_publish()
		return
	if state.phase == MatchState.Phase.TABLE:
		# 집합 중에는 다음 라운드 첫 차례(0번)가 이미 정해져 있다. 남은 사람으로 집합을 계속한다.
		state.turn_index = 0
		_publish()
		return
	if removed_active:
		if was_last:
			state.turn_index = 0
			if state.round_number >= config.rounds:
				_pending_hit.clear()
				_set_phase(MatchState.Phase.FINISHED, 0)
				return
			state.round_number += 1
			_begin_table()
			return
		# 지워진 자리 다음 순서로 진행하며 비행 중 이탈한 투척은 취소한다.
		state.turn_index = mini(state.turn_index, state.players.size() - 1)
		_begin_turn()
	else:
		for index in range(state.players.size()):
			if state.players[index].peer_id == active_id:
				state.turn_index = index
		_publish()


func developer_skip() -> void:
	if multiplayer.is_server() and developer_enabled:
		_timeout_turn()


func developer_bot_turn(bot_id: int) -> void:
	if not multiplayer.is_server() or not developer_enabled or state.phase != MatchState.Phase.AIMING:
		return
	var bot := state.find_player(bot_id)
	if bot == null or not bot.is_bot:
		return
	_timeout_turn()
	state.turn_index = state.players.find(bot)
	notice = "F4 시험: 봇 차례로 변경했습니다. 정상 경기 순서와 달라질 수 있습니다."
	_begin_turn()


func restart() -> void:
	if not multiplayer.is_server():
		if session != null and session.is_room_host():
			session.request_game_action.rpc_id(1, "restart", [])
		return
	if not multiplayer.is_server() or state.phase != MatchState.Phase.FINISHED or state.players.size() < 2:
		return
	for player in state.players:
		player.score = 0
		player.speed_scale = 1.0
	state.round_number = 1
	state.turn_index = 0
	state.last_hit = {}
	_pending_hit.clear()
	_last_requests.clear()
	notice = "재경기를 시작했습니다."
	_begin_turn()


func _set_phase(phase: MatchState.Phase, duration: float) -> void:
	state.phase = phase
	_phase_end = _now() + duration
	_publish()


func _publish() -> void:
	state.revision += 1
	var snapshot := state.to_snapshot()
	snapshot["config"] = config.to_snapshot()
	snapshot["seconds"] = remaining_seconds()
	snapshot["notice"] = notice
	if session != null:
		session.receive_game_event.rpc("match", snapshot)
	changed.emit()


func _receive_state(snapshot: Dictionary) -> void:
	if snapshot.match_id != state.match_id or snapshot.revision <= state.revision:
		return
	state = MatchState.from_snapshot(snapshot)
	config = MatchConfig.from_snapshot(snapshot.config)
	_remote_seconds = snapshot.seconds
	_received_at = _now()
	notice = snapshot.notice
	changed.emit()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
