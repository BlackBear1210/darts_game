class_name MatchController
extends Node
## 턴의 유일한 확정 경로. 비행 중에는 시간 초과/추가 요청/개발자 종료를 받지 않는다.
## 라운드 사이에는 테이블 집합(TABLE)이 있다: 제한시간 안에 자기 자리에 앉지 않은 사람은 자동 착석 + 다음 라운드 슬로우.

signal changed
signal dart_thrown(data: Dictionary)
## 날아가는 다트에 궤적 카드가 걸려 꽂히는 자리가 바뀌었다. {target, remaining}
signal dart_redirected(data: Dictionary)

@export var config: MatchConfig = preload("res://game/match/default_match.tres")

## 카드 목록(이름·분류·효과)은 카드 라운드 시연의 것을 그대로 쓴다 — 카드 정의는 한 곳만 유지한다.
const CardCatalog = preload("res://game/card_round/rules/card_catalog.gd")

const MatchCards = preload("res://game/match/match_cards.gd")
var cards: RefCounted
var room_settings := RoomSettings.new()
var session: NetworkSession
var state := MatchState.new()
var local_peer_id: int = 0
var solve_throw: Callable
## 테이블 집합 판정용 GameView 함수. check_seated(peer_id) -> bool, force_seat(peer_id). 없으면 집합을 바로 끝낸다.
var check_seated: Callable
## 투척 위치 판정용 GameView 함수. in_throw_zone(peer_id) -> bool. 없으면 위치를 보지 않는다(씬 없는 시험).
var in_throw_zone: Callable
var force_seat: Callable
## 몸으로 막혔을 때 맞은 사람을 못 움직이게 하는 GameView 함수. stun_player(peer_id, seconds). 없으면 보상만 준다.
var stun_player: Callable
var developer_enabled: bool = false
var notice: String = ""
var _turn_end: float = 0.0
var _phase_end: float = 0.0
var _received_at: float = 0.0
var _remote_seconds: float = 0.0
var _pending_hit: Dictionary = {}
## 아수라장 머신(2026-11-07): 방장이 마지막으로 보낸 "효과가 걸린 지 몇 초"(MatchCards.chaos_ages)와 받은 시각.
## 손님 화면은 받은 뒤 흐른 시간을 더해 같은 회전·벌어짐을 재생한다(프레임마다 RPC 를 보내지 않는다).
var _chaos_ages: Dictionary = {}
const BoardChaos = preload("res://game/board/board_chaos.gd")
## 지금 날아가는 다트의 조준·충전·졸림 오차. 궤적 카드가 걸리면 같은 값으로 다시 계산한다.
var _flight_input: Dictionary = {}
var _request_number: int = 0
var _last_requests: Dictionary = {}
## 카드 추첨·졸림 오차의 난수. 방장만 돌리고 확정 상태·비행 결과를 전송한다.
var _random := RandomNumberGenerator.new()
## 무효(×0)는 한 경기에 딱 한 장(2026-10-31 사용자 요청). 기본 방 설정은 거의 연산 카드만 뽑혀서 무효가 다섯 장에 한 장꼴로
## 나왔다(첫 나눠 주기 28장 중 평균 5~6장) → 막기 카드가 너무 흔했다. 이제 첫 나눠 주기에서 무작위 한 사람에게만 한 장 넣고,
## 나머지 모든 뽑기에서는 무효가 나오면 다시 뽑는다. 방 설정에서 무효를 꺼 두었으면 한 장도 넣지 않는다.
const NULLIFY_ID := "times_0"
## 무효를 빼고 다시 뽑는 최대 횟수. 방 설정에 무효 말고 고를 카드가 없으면 그만 뽑는다(무한 반복 방지).
const REDRAW_LIMIT: int = 12
## 이번 경기에 무효 한 장을 이미 넣었는지(첫 나눠 주기에서 켜진다).
var _nullify_dealt: bool = false
## 몸으로 막은 사람이 못 움직이는 시간(초). F6 카드 라운드 시연(Disruption.STUN_SECONDS)과 같은 시연값이다.
const BODY_STUN_SECONDS: float = 3.0


func configure(room: RoomState, peer_id: int, connection: NetworkSession = null) -> void:
	session = connection
	if session != null:
		session.game_action.connect(_receive_action)
		session.game_event.connect(_receive_event)
	config = config.duplicate() as MatchConfig
	room_settings = room.settings
	if room_settings.social_lobby:
		config.rounds = room_settings.rounds
		config.turn_seconds = room_settings.dart_seconds
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
		if room_settings.social_lobby: cards = MatchCards.new(self)
		_begin_cards()


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
	if action == "card" and payload.size() == 3 and payload[0] == state.match_id and payload[1] is String and payload[2] is int:
		if cards != null: cards.action(sender, payload[1], payload[2])
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
	elif kind == "redirect":
		_play_redirect(data)


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
	if in_throw_zone.is_valid() and not in_throw_zone.call(sender):
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
	if in_throw_zone.is_valid() and not in_throw_zone.call(active.peer_id):
		return
	_request_number += 1
	_launch(active.peer_id, aim, charge, _request_number)


## 확정된 한 발을 비행으로 보낸다. 사람과 봇이 같은 경로를 쓴다.
func _launch(peer_id: int, aim: Vector2, charge: float, request_id: int) -> void:
	_flight_input = {"aim": aim, "charge": charge}
	var data: Dictionary = _solve(peer_id, aim, charge)
	_pending_hit = data.duplicate()
	_pending_hit.merge({"peer_id": peer_id, "request_id": request_id})
	state.darts_left -= 1
	_set_phase(MatchState.Phase.FLIGHT, float(data.duration))
	data.merge({"match_id": state.match_id, "turn_id": state.turn_id, "peer_id": peer_id})
	if session != null:
		session.receive_game_event.rpc("dart", data)
	_play_throw(data)


## 카드 궤적 효과를 넣은 비행 계산. 가림판·숫자 섞기는 꽂힐 때 센다(MatchCards.landing_points).
func _solve(peer_id: int, aim: Vector2, charge: float) -> Dictionary:
	var mods: Dictionary = cards.modifiers(peer_id) if cards != null else {}
	var adjusted: Vector2 = aim + Vector2(float(mods.get("push", 0)), -float(mods.get("drop", 0)))
	if mods.get("drowsy", false):
		# 방장이 한 발에 한 번만 정한다. 비행 중 다른 카드로 재계산해도 오차를 다시 뽑지 않는다.
		if not _flight_input.has("drowsy_offset"):
			var spread: float = CardCatalog.DROWSY_AIM_SPREAD
			_flight_input.drowsy_offset = Vector2(_random.randf_range(-spread, spread), _random.randf_range(-spread, spread))
		adjusted += Vector2(_flight_input.drowsy_offset) * float(mods.get("drowsy_strength", 1.0))
	var offsets: Array[Vector2] = [Vector2.ZERO]
	if mods.get("triple", false):
		if not _flight_input.has("pattern"): _flight_input.pattern = CardCatalog.special_offsets(_random)
		offsets.assign(_flight_input.pattern)
	var flights: Array[Dictionary] = []
	for offset in offsets:
		var one: Dictionary = solve_throw.call(adjusted + offset, charge, peer_id, CardCatalog.POWER_SPEED_MULTIPLIER if mods.get("power", false) else 1.0)
		one["large"] = bool(mods.get("large", false))
		var shape: Dictionary = cards.shape_now() if cards != null else BoardChaos.rest()
		if BoardChaos.covered(Vector2(float(one.x), float(one.y)), shape) and absf(float(one.x)) < 50:
			one.target = (one.target as Vector3) + Vector3(0, 0, BoardChaos.SHUTTER_FRONT)
		flights.append(one)
	var data: Dictionary = flights[0].duplicate()
	data["flights"] = flights
	data.points = 0
	for one in flights:
		data.points += int(one.points)
		data.duration = maxf(float(data.duration), float(one.duration))

	return data


## 날아가는 다트에 궤적 카드가 걸렸다(2026-10-31 사용자 결정: 비행 중에 써도 적용). 같은 조준으로 다시 계산해
## 꽂히는 자리만 바꾸고, 꽂히는 시각은 그대로 둔다. 모든 화면의 다트가 남은 시간 동안 새 자리로 휘어 간다.
func redirect_flight() -> void:
	if state.phase != MatchState.Phase.FLIGHT or _pending_hit.is_empty():
		return
	var data: Dictionary = _solve(int(_pending_hit.peer_id), _flight_input.aim, _flight_input.charge)
	_pending_hit.merge(data, true)
	var event := {"match_id": state.match_id, "turn_id": state.turn_id, "target": data.target, "flights": data.get("flights", []), "peer_id": _pending_hit.peer_id, "remaining": maxf(0.05, _phase_end - _now())}
	if session != null:
		session.receive_game_event.rpc("redirect", event)
	_play_redirect(event)


func _play_throw(data: Dictionary) -> void:
	if data.match_id == state.match_id and data.turn_id == state.turn_id:
		dart_thrown.emit(data)


func _play_redirect(data: Dictionary) -> void:
	if data.match_id == state.match_id and data.turn_id == state.turn_id:
		dart_redirected.emit(data)


func _process(_delta: float) -> void:
	if not multiplayer.is_server():
		return
	match state.phase:
		MatchState.Phase.AIMING:
			if cards != null:
				cards.tick_bots()
			if _now() >= _turn_end:
				_timeout_turn()
		MatchState.Phase.FLIGHT:
			if cards != null:
				cards.tick_bots()
			if _now() >= _phase_end:
				_land_dart()
		MatchState.Phase.SETTLING:
			if _now() >= _phase_end:
				_advance_turn()
		MatchState.Phase.TABLE:
			if _everyone_seated() or _now() >= _phase_end:
				_close_table()
		MatchState.Phase.CARDS:
			if _now() >= _phase_end:
				_begin_turn()


## 라운드의 다트가 시작되기 전 카드 나눠 주기(2026-10-28 사용자 요청).
## 쓴 만큼만 7장까지 채운다 — 한 장도 안 썼으면 한 장도 받지 않는다(CardHandRules 확정 규칙).
## 라운지 경기는 받은 카드를 MatchCards.VIEW_SECONDS 동안 확인만 하고 바로 다트로 간다(카드는 다트 턴에 쓴다).
## before 는 이 단계로 넘어오며 알릴 말(집합 지각 같은 것). 카드 알림이 그것을 덮지 않게 앞에 붙인다.
func _begin_cards(before: String = "") -> void:
	if room_settings.social_lobby and not room_settings.cards_enabled:
		_begin_turn()
		return
	var dealt: int = 0
	for player in state.players:
		while player.hand.size() < CardHandRules.HAND_LIMIT:
			var type: int = _draw_card()
			if type < 0: break
			player.hand.append(type)
			dealt += 1
	_deal_single_nullify()
	var text: String = "카드 나눠 주기 — 각자 %d장" % CardHandRules.HAND_LIMIT if dealt > 0 else "모두 %d장 그대로" % CardHandRules.HAND_LIMIT
	notice = text if before.is_empty() else "%s · %s" % [before, text]
	if cards != null:
		notice += " · %d초 뒤 다트" % roundi(MatchCards.VIEW_SECONDS)
		cards.begin_round()
	_set_phase(MatchState.Phase.CARDS, MatchCards.VIEW_SECONDS if cards != null else config.card_seconds)


## 카드 한 장 뽑기(방 설정 비율). 무효(×0)가 나오면 다시 뽑는다 — 무효는 _deal_single_nullify 로만 들어온다. 못 뽑으면 -1.
func _draw_card() -> int:
	var nullify: int = CardCatalog.type_of(NULLIFY_ID)
	for attempt in range(REDRAW_LIMIT):
		var type: int = room_settings.draw_card(_random) if room_settings.social_lobby else CardCatalog.random_type(_random)
		if type != nullify:
			return type
	return -1


## 경기의 첫 나눠 주기에서 한 번만: 카드를 받은 사람 중 무작위 한 명의 무작위 한 칸을 무효(×0)로 바꾼다.
## 그 뒤로는 다시 넣지 않는다 → 누가 쓰든 버리든 경기 전체에 무효는 딱 한 장이다.
func _deal_single_nullify() -> void:
	if _nullify_dealt:
		return
	_nullify_dealt = true
	var nullify: int = CardCatalog.type_of(NULLIFY_ID)
	if nullify < 0 or (room_settings.social_lobby and (not room_settings.special_cards or room_settings.disabled_cards.has(NULLIFY_ID))):
		return
	var holders: Array[MatchPlayer] = []
	for player in state.players:
		if not player.hand.is_empty():
			holders.append(player)
	if holders.is_empty():
		return
	var lucky: MatchPlayer = holders[_random.randi_range(0, holders.size() - 1)]
	lucky.hand[_random.randi_range(0, lucky.hand.size() - 1)] = nullify


func _begin_turn() -> void:
	if cards != null: cards.begin_dart_turn()
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
	var won: bool = false
	# 몸에 맞은 발은 "○○ 몸에 맞음!" 이라고 적힌 채로 둔다(점수 식으로 덮지 않는다).
	var victims: Array[int] = []
	for flight: Dictionary in _pending_hit.get("flights", [_pending_hit]):
		var victim: int = int(flight.get("victim", 0))
		if victim != 0 and victim not in victims: victims.append(victim)
	var victim_id: int = victims[0] if not victims.is_empty() else 0
	if cards != null:
		var result: Dictionary = cards.score(cards.landing_points(_pending_hit), _pending_hit)
		_pending_hit.points = result.points
		if victim_id == 0:
			_pending_hit.reason = "버스트 · 차례 시작 점수로 복귀" if result.bust else str(result.formula) + "점"
		if result.bust: state.darts_left = 0
		won = result.win
	else:
		state.active_player().score += int(_pending_hit.points)
	state.last_hit = _pending_hit.duplicate()
	_pending_hit.clear()
	if victim_id != 0:
		for victim in victims: _body_blocked(victim)
	else:
		add_feed(feed_entry("dart", state.active_player(), str(state.last_hit.reason)))
	if won:
		_set_phase(MatchState.Phase.FINISHED, 0)
		return
	if state.darts_left > 0 and _now() < _turn_end:
		_set_phase(MatchState.Phase.AIMING, _turn_end - _now())
	else:
		state.darts_left = 0
		_set_phase(MatchState.Phase.SETTLING, config.settle_seconds)


## 몸으로 막혔다(2026-11-02 F6 이식). 다트는 0점이고, 맞은 사람은 스턴 + 방해 성공 보상을 받는다.
## 보상 계산은 카드 규칙(RoundRules.disrupt) 한 곳에 둔다 — 지금 경기 보상은 점수다(라운드 한정 카드 보상은 F6 전용).
## 던진 사람의 취기·감도·난시 및 음성 변조는 MatchCards가 차례 효과로 기록한다.
func _body_blocked(victim_id: int) -> void:
	var victim: MatchPlayer = state.find_player(victim_id)
	if victim == null:
		return
	if stun_player.is_valid():
		stun_player.call(victim_id, BODY_STUN_SECONDS)
	var reward: String = cards.disrupt(victim_id) if cards != null else ""
	add_feed(feed_entry("dizzy", state.active_player(), "몸에 막힘%s" % reward, victim))


func _advance_turn() -> void:
	if cards != null: cards.end_dart_turn()
	if cards != null and state.active_player() != null and cards.take_retry(state.active_player().peer_id):
		_begin_turn()
		return
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
	var late_text: String = ""
	if not late.is_empty():
		late_text = "지각: %s — 자동 착석, 이번 라운드 이동 속도 %d%%" % [", ".join(late), roundi(config.slow_speed_scale * 100)]
	# 다음 라운드도 다트 전에 카드를 채운다(지각 알림은 그대로 앞에 남긴다).
	_begin_cards(late_text)


func sync_roster(room: RoomState) -> void:
	if state.phase == MatchState.Phase.WAITING:
		state.players.clear()
		for identity in room.players:
			var player := MatchPlayer.new()
			player.peer_id = identity.peer_id
			player.display_name = identity.display_name
			player.seat = identity.seat
			player.is_bot = identity.is_bot
			state.players.append(player)
		return
	if not multiplayer.is_server() or state.players.is_empty(): return
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
	if state.players.size() < (1 if room_settings.solo else RoomState.MIN_PLAYERS):
		state.turn_index = 0
		notice = "참가자가 2명 미만이어서 경기를 종료했습니다."
		_pending_hit.clear()
		_set_phase(MatchState.Phase.FINISHED, 0)
		return
	if state.phase == MatchState.Phase.FINISHED:
		state.turn_index = mini(state.turn_index, state.players.size() - 1)
		_publish()
		return
	if cards != null:
		cards.drop_missing()
	if state.phase == MatchState.Phase.CARDS:
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
	if room_settings.social_lobby and state.phase == MatchState.Phase.FINISHED:
		if session != null: session.return_to_lobby()
		return
	if not multiplayer.is_server():
		if session != null and session.is_room_host():
			session.request_game_action.rpc_id(1, "restart", [])
		return
	if not multiplayer.is_server() or state.phase != MatchState.Phase.FINISHED or state.players.size() < 2:
		return
	for player in state.players:
		player.score = 0
		player.speed_scale = 1.0
		player.hand.clear()
	state.round_number = 1
	state.turn_index = 0
	state.last_hit = {}
	_pending_hit.clear()
	_last_requests.clear()
	notice = "재경기를 시작했습니다."
	_begin_cards()


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
	snapshot["chaos"] = cards.chaos_ages() if cards != null else {}
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
	var chaos: Variant = snapshot.get("chaos", {})
	_chaos_ages = chaos if chaos is Dictionary else {}
	changed.emit()


## 지금 다트 머신 과녁 모양(BoardChaos.pose). 방장은 직접 세고, 손님은 받은 값에 흐른 시간을 더한다.
## 다트 단계(조준·비행)가 아니면 늘 제자리 모양이다.
func chaos_shape() -> Dictionary:
	if state.phase not in [MatchState.Phase.AIMING, MatchState.Phase.FLIGHT, MatchState.Phase.SETTLING]:
		return BoardChaos.rest()
	if multiplayer.is_server() or session == null:
		return cards.shape_now() if cards != null else BoardChaos.rest()
	var passed: float = _now() - _received_at
	var age := func(kind: String) -> float:
		return float(_chaos_ages[kind]) + passed if _chaos_ages.has(kind) else -1.0
	return BoardChaos.boost(BoardChaos.pose(age.call("spin"), float(_chaos_ages.get("dir", 1.0)), age.call("split"), age.call("cover"), age.call("vertical"), age.call("horizontal"), age.call("move"), _chaos_ages.get("move_dir", Vector2.RIGHT), int(_chaos_ages.get("cover_side", -1))), _chaos_ages.get("levels", {}))


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func request_card(action: String, value: int = 0) -> void:
	if session == null: return
	if session.is_host():
		if cards != null: cards.action(local_peer_id, action, value)
	else: session.request_game_action.rpc_id(1, "card", [state.match_id, action, value])

func add_feed(text: String) -> void:
	state.feed.append(text.left(160))
	while state.feed.size() > 5: state.feed.pop_front()


## 킬로그 칸 구분(탭). 이름은 strip_escapes 로 탭이 빠지므로 섞이지 않는다.
## 2026-10-30: 처음엔 보이지 않는 제어 글자(U+001F)를 썼는데, Godot JSON 이 그 글자를 이스케이프하지 않아
## 상태 JSON 을 읽는 쪽(네트워크 시험의 파이썬)이 깨졌다. JSON 이 \t 로 적는 탭으로 바꿨다.
const FEED_SEPARATOR := "\t"

## 킬로그 한 줄(화면 오른쪽 위 칩으로 그린다). 칸은 FEED_SEPARATOR 로 나눈다.
## 형식: 아이콘 · 주체 자리 · 주체 이름 · 내용 · 대상 자리 · 대상 이름 (자리 -1 = 없음).
## 자리 번호가 있어 화면마다 자리 색으로 이름을 칠한다(배틀그라운드 킬로그처럼 "누가 [무엇으로] 누구를").
static func feed_entry(icon: String, actor: MatchPlayer, text: String, target: MatchPlayer = null) -> String:
	return FEED_SEPARATOR.join(PackedStringArray([icon, str(actor.seat if actor != null else -1), actor.display_name if actor != null else "",
		text, str(target.seat if target != null else -1), target.display_name if target != null else ""]))
