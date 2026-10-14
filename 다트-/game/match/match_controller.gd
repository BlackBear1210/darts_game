class_name MatchController
extends Node
## 경기 RPC와 시간 진행은 방장이 소유한다. 점수·카드 규칙은 별도 데이터 코드에 둔다.

signal changed
signal private_changed
signal dart_thrown(data: Dictionary)
signal emote_received(data: Dictionary)

const EMPTY_PRIVATE: Dictionary = {"candidates": [], "picked": -1, "planned": {"uid": 0, "target": 0}}

@export var config: MatchConfig = preload("res://game/match/default_match.tres")

var state := MatchState.new()
var private_cards: Dictionary = EMPTY_PRIVATE.duplicate(true)
var local_peer_id: int = 0

var _cards := CardController.new()
var _phase_end: float = 0.0
var _turn_end: float = 0.0
var _received_at: float = 0.0
var _remote_phase_seconds: float = 0.0
var _remote_turn_seconds: float = 0.0
var _pending_hit: Dictionary = {}
var _request_number: int = 0
var _last_requests: Dictionary = {}
var _emote_users: Array[int] = []
var _emote_available: float = 0.0


func configure(room: RoomState, peer_id: int) -> void:
	config = config.duplicate() as MatchConfig
	local_peer_id = peer_id
	state.match_id = room.match_id
	for identity in room.players:
		var player := MatchPlayer.new()
		player.peer_id = identity.peer_id
		player.display_name = identity.display_name
		player.seat = identity.seat
		state.players.append(player)
	state.players.sort_custom(func(a: MatchPlayer, b: MatchPlayer) -> bool: return a.seat < b.seat)


func start() -> void:
	if local_peer_id == NetworkSession.HOST_ID and state.phase == MatchState.Phase.WAITING:
		_begin_turn()


func remaining_seconds() -> float:
	var uses_turn_clock := state.phase in [MatchState.Phase.AIMING, MatchState.Phase.FLIGHT]
	if multiplayer.is_server():
		return maxf(0.0, (_turn_end if uses_turn_clock else _phase_end) - _now())
	var duration := _remote_turn_seconds if uses_turn_clock else _remote_phase_seconds
	return maxf(0.0, duration - (_now() - _received_at))


func submit_throw(aim: Vector2, timing: float) -> void:
	_request_number += 1
	if multiplayer.is_server():
		_accept_throw(local_peer_id, state.match_id, state.turn_id, _request_number, aim, timing)
	else:
		_request_throw.rpc_id(NetworkSession.HOST_ID, state.match_id, state.turn_id, _request_number, aim, timing)


func choose_card(index: int) -> void:
	if multiplayer.is_server(): _accept_choice(local_peer_id, state.match_id, state.round_number, index)
	else: _request_choice.rpc_id(NetworkSession.HOST_ID, state.match_id, state.round_number, index)


func plan_card(uid: int, target: int) -> void:
	if multiplayer.is_server(): _accept_card(local_peer_id, state.match_id, state.round_number, uid, target)
	else: _request_card.rpc_id(NetworkSession.HOST_ID, state.match_id, state.round_number, uid, target)


func request_emote() -> void:
	if multiplayer.is_server(): _accept_emote(local_peer_id, state.match_id, state.turn_id)
	else: _request_emote.rpc_id(NetworkSession.HOST_ID, state.match_id, state.turn_id)


func _process(_delta: float) -> void:
	if not multiplayer.is_server() or state.phase in [MatchState.Phase.WAITING, MatchState.Phase.FINISHED]:
		return
	var now := _now()
	match state.phase:
		MatchState.Phase.PREPARING:
			if now >= _phase_end:
				_turn_end = now + config.turn_seconds
				_set_phase(MatchState.Phase.AIMING, config.turn_seconds)
		MatchState.Phase.AIMING:
			if now >= _turn_end:
				state.darts_left = 0
				_set_phase(MatchState.Phase.SETTLING, config.settle_seconds)
		MatchState.Phase.FLIGHT:
			if now >= _phase_end: _land_dart()
		MatchState.Phase.SETTLING:
			if now >= _phase_end: _advance_turn()
		MatchState.Phase.CARDS:
			if now >= _phase_end:
				_cards.finish(state, config.hand_limit)
				state.turn_index = 0
				_begin_turn()


func _begin_turn() -> void:
	state.turn_id += 1
	state.darts_left = config.darts_per_turn
	state.last_hit = {}
	_emote_users.clear()
	_emote_available = 0.0
	_set_phase(MatchState.Phase.PREPARING, config.transition_seconds)


func _advance_turn() -> void:
	state.active_player().clear_effects()
	state.turn_index += 1
	if state.turn_index < state.players.size():
		_begin_turn()
	elif state.round_number >= config.rounds:
		state.turn_index = 0
		_set_phase(MatchState.Phase.FINISHED, 0.0)
	else:
		state.round_number += 1
		state.turn_index = 0
		_cards.begin(state.players)
		_set_phase(MatchState.Phase.CARDS, config.card_seconds)


@rpc("any_peer", "call_remote", "reliable")
func _request_throw(match_id: int, turn_id: int, request_id: int, aim: Vector2, timing: float) -> void:
	if multiplayer.is_server():
		_accept_throw(multiplayer.get_remote_sender_id(), match_id, turn_id, request_id, aim, timing)


func _accept_throw(sender: int, match_id: int, turn_id: int, request_id: int, aim: Vector2, timing: float) -> void:
	if not _valid_turn(sender, match_id, turn_id) or state.darts_left <= 0 or _now() >= _turn_end:
		return
	if not aim.is_finite() or not is_finite(timing) or absf(aim.x) > 1.5 or absf(aim.y) > 1.5:
		return
	if timing < 0.0 or timing > 1.0 or request_id <= int(_last_requests.get(sender, 0)):
		return
	_last_requests[sender] = request_id
	var impact := aim + Vector2((timing - 0.5) * 0.14, absf(timing - 0.5) * 0.15)
	var player := state.active_player()
	var base := BoardScorer.score(impact, player.layout)
	_pending_hit = {"peer_id": sender, "x": impact.x, "y": impact.y,
		"base": base, "points": player.score_hit(base), "request_id": request_id}
	state.darts_left -= 1
	_set_phase(MatchState.Phase.FLIGHT, config.flight_seconds)
	_play_throw.rpc({"match_id": match_id, "turn_id": turn_id, "peer_id": sender,
		"x": impact.x, "y": impact.y, "duration": config.flight_seconds})


func _land_dart() -> void:
	state.active_player().score += int(_pending_hit.points)
	state.last_hit = _pending_hit.duplicate()
	_pending_hit.clear()
	if state.darts_left == 0 or _now() >= _turn_end:
		state.darts_left = 0
		_set_phase(MatchState.Phase.SETTLING, config.settle_seconds)
	else:
		_set_phase(MatchState.Phase.AIMING, maxf(0.0, _turn_end - _now()))


@rpc("authority", "call_local", "reliable")
func _play_throw(data: Dictionary) -> void:
	if data.match_id == state.match_id and data.turn_id == state.turn_id:
		dart_thrown.emit(data)


@rpc("any_peer", "call_remote", "reliable")
func _request_choice(match_id: int, round_number: int, index: int) -> void:
	if multiplayer.is_server(): _accept_choice(multiplayer.get_remote_sender_id(), match_id, round_number, index)


func _accept_choice(sender: int, match_id: int, round_number: int, index: int) -> void:
	if not _valid_card_phase(match_id, round_number): return
	if _cards.choose(state.find_player(sender), index, config.hand_limit): _publish()


@rpc("any_peer", "call_remote", "reliable")
func _request_card(match_id: int, round_number: int, uid: int, target: int) -> void:
	if multiplayer.is_server(): _accept_card(multiplayer.get_remote_sender_id(), match_id, round_number, uid, target)


func _accept_card(sender: int, match_id: int, round_number: int, uid: int, target: int) -> void:
	if not _valid_card_phase(match_id, round_number): return
	if _cards.plan_use(state.find_player(sender), uid, target, state): _publish()


@rpc("any_peer", "call_remote", "reliable")
func _request_emote(match_id: int, turn_id: int) -> void:
	if multiplayer.is_server(): _accept_emote(multiplayer.get_remote_sender_id(), match_id, turn_id)


func _accept_emote(sender: int, match_id: int, turn_id: int) -> void:
	if state.phase != MatchState.Phase.AIMING or match_id != state.match_id or turn_id != state.turn_id:
		return
	if state.find_player(sender) == null or sender == state.active_player().peer_id:
		return
	if _emote_users.has(sender) or _emote_users.size() >= 2 or _now() < _emote_available:
		return
	_emote_users.append(sender)
	_emote_available = _now() + config.emote_warning + config.emote_seconds + config.emote_gap
	_play_emote.rpc({"match_id": match_id, "turn_id": turn_id, "peer_id": sender,
		"warning": config.emote_warning, "duration": config.emote_seconds})


@rpc("authority", "call_local", "reliable")
func _play_emote(data: Dictionary) -> void:
	if data.match_id == state.match_id and data.turn_id == state.turn_id:
		emote_received.emit(data)


func _valid_turn(sender: int, match_id: int, turn_id: int) -> bool:
	return state.phase == MatchState.Phase.AIMING and state.match_id == match_id \
		and state.turn_id == turn_id and state.active_player().peer_id == sender


func _valid_card_phase(match_id: int, round_number: int) -> bool:
	return state.phase == MatchState.Phase.CARDS and state.match_id == match_id \
		and state.round_number == round_number and _now() < _phase_end


func _set_phase(phase: MatchState.Phase, duration: float) -> void:
	state.phase = phase
	_phase_end = _now() + duration
	_publish()


func _publish() -> void:
	state.revision += 1
	var snapshot := state.to_snapshot()
	snapshot["config"] = config.to_snapshot()
	snapshot["phase_seconds"] = maxf(0.0, _phase_end - _now())
	snapshot["turn_seconds"] = maxf(0.0, _turn_end - _now())
	_receive_state.rpc(snapshot)
	if state.phase == MatchState.Phase.CARDS:
		for player in state.players:
			var data := _cards.private_snapshot(player.peer_id)
			if player.peer_id == local_peer_id:
				private_cards = data
				private_changed.emit()
			else:
				_receive_private.rpc_id(player.peer_id, state.match_id, state.round_number, data)
	else:
		private_cards = EMPTY_PRIVATE.duplicate(true)
	changed.emit()


@rpc("authority", "call_remote", "reliable")
func _receive_state(snapshot: Dictionary) -> void:
	if snapshot.match_id != state.match_id or snapshot.revision <= state.revision: return
	if snapshot.phase != MatchState.Phase.CARDS or state.phase != MatchState.Phase.CARDS or snapshot.round != state.round_number:
		private_cards = EMPTY_PRIVATE.duplicate(true)
	state = MatchState.from_snapshot(snapshot)
	config = MatchConfig.from_snapshot(snapshot.config)
	_received_at = _now()
	_remote_phase_seconds = snapshot.phase_seconds
	_remote_turn_seconds = snapshot.turn_seconds
	changed.emit()


@rpc("authority", "call_remote", "reliable")
func _receive_private(match_id: int, round_number: int, data: Dictionary) -> void:
	if state.match_id != match_id or state.round_number != round_number or state.phase != MatchState.Phase.CARDS:
		return
	private_cards = data
	private_changed.emit()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
