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
var rebound_contact: Callable
## 테이블 집합 판정용 GameView 함수. check_seated(peer_id) -> bool, force_seat(peer_id). 없으면 집합을 바로 끝낸다.
var check_seated: Callable
## 투척 위치 판정용 GameView 함수. in_throw_zone(peer_id) -> bool. 없으면 위치를 보지 않는다(씬 없는 시험).
var in_throw_zone: Callable
var force_seat: Callable
## 몸으로 막혔을 때 맞은 사람을 못 움직이게 하는 GameView 함수. stun_player(peer_id, seconds). 없으면 보상만 준다.
var stun_player: Callable
## [라운드당 다트 — 2026-11-15] 차례가 아니거나 던지는 칸 밖에서 던진 "그냥 던진 다트"를 날리는 GameView 함수.
## throw_stray(peer_id, charge) -> bool(던졌으면 true). 없으면(씬 없는 시험) 그냥 던지기를 받지 않는다.
var throw_stray: Callable
## 다트에 두 번 맞은 사람을 쓰러뜨리는 GameView 함수. knock_down(peer_id, push). 없으면 횟수만 센다.
var knock_down: Callable
## [2026-11-21 새 카드] 사람 몸이 필요한 카드 처리(GameView 의 CardWorld.host_action): card_world(action, data) -> Variant.
## "bind"/"pull" → 맞은 사람 peer ID(0 = 빗나감), "card_throw" → 던졌으면 true. 없으면(씬 없는 시험) 빗나감으로 본다.
var card_world: Callable
var developer_enabled: bool = false
var card_test_active: bool = false
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
## 경기 끝 벌칙(2026-11-23 사용자 요청): 꼴찌를 돌아가는 점수 과녁판에 묶고 나머지가 던진다.
## 인원이 몇이든 전체 발수를 이만큼 안팎으로 맞춘다 → 벌칙 길이가 늘 비슷하다(한 사람 최소 2발).
const PUNISH_TOTAL_DARTS: int = 6
## 벌칙 회전(라디안/초)과 방향을 바꿀 때의 가속(라디안/초²).
## 2026-11-24 사용자 요청 "좀 더 속도감있게": 1.1 → 2.0(약 19초에 한 바퀴 → 3.1초에 한 바퀴).
## 가속도 같이 올려 방향 전환이 1초 안에 끝나게 둔다 — 다트 비행(0.4초)보다는 길어서 홱 피하지는 못한다.
const PUNISH_SPIN_SPEED: float = 2.0
const PUNISH_SPIN_ACCEL: float = 4.0
const BoardVictim = preload("res://game/board/board_victim.gd")
const PlayerWallet = preload("res://app/player_wallet.gd")
## 다트에 이만큼 맞으면 쓰러진다(줄 끊긴 인형). 횟수는 라운드마다 0 으로 돌아간다(2026-11-15 사용자 요청 "2번 맞으면").
const DART_HITS_TO_FALL: int = 2
## 그냥 던진 다트에 맞았을 때 잠깐 움찔하는 시간(초). 몸으로 막기(BODY_STUN_SECONDS)보다 짧다.
const STRAY_HIT_STUN: float = 1.0
## 고무 다트: 과녁에 맞고 튕겨 다시 꽂히기까지(초)와 튕겨 가는 거리(과녁 반지름 비율). 시연값.
const RUBBER_SECONDS: float = 0.35
const RUBBER_REACH := Vector2(0.15, 0.35)
## 다트를 던질 수 있는 단계(조준·비행·정산). 카드 충전·테이블 집합·대기 중에는 다트를 꺼내지 않는다.
const DART_PHASES: Array[MatchState.Phase] = [MatchState.Phase.AIMING, MatchState.Phase.FLIGHT, MatchState.Phase.SETTLING]


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


## [2026-11-18 "방 만든 뒤 대기 없애기"] 경기 화면은 그대로 두고 경기 상태만 처음으로 되돌린다.
## 예전엔 경기 번호(match_id)가 바뀌거나 로비로 돌아올 때 app/main.gd 가 경기 화면을 통째로 지우고 다시 만들었다
## (펍 1.2초 · 오락실 1.9초 멈춤). 지금은 GameView.begin_match 가 이 함수를 부른다.
## 연결(session 신호)·규칙(config)·내 번호(local_peer_id)·요청 번호(_request_number, 계속 올라가야 한다)는 그대로 둔다.
func reset_match(room: RoomState) -> void:
	room_settings = room.settings
	if card_test_active and cards != null:
		cards.actions.cards = null
	card_test_active = false
	state = MatchState.new()
	state.match_id = room.match_id
	for identity in room.players:
		var player := MatchPlayer.new()
		player.peer_id = identity.peer_id
		player.display_name = identity.display_name
		player.seat = identity.seat
		player.is_bot = identity.is_bot
		state.players.append(player)
	state.players.sort_custom(func(a: MatchPlayer, b: MatchPlayer) -> bool: return a.seat < b.seat)
	cards = null
	notice = ""
	_turn_end = 0.0
	_phase_end = 0.0
	_received_at = 0.0
	_remote_seconds = 0.0
	_pending_hit.clear()
	_chaos_ages = {}
	_flight_input = {}
	_last_requests.clear()
	_nullify_dealt = false
	changed.emit()


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


## 그냥 던지기 요청(자기 차례가 아니거나, 던지는 칸 밖이거나, 과녁을 안 보고 던졌다). 점수는 없고 다트만 준다.
func submit_stray(charge: float) -> void:
	_request_number += 1
	if multiplayer.is_server():
		_accept_stray(local_peer_id, state.match_id, _request_number, charge)
	else:
		session.request_game_action.rpc_id(1, "stray", [state.match_id, _request_number, charge])


func _receive_action(sender: int, action: String, payload: Array) -> void:
	if action == "stray" and payload.size() == 3 and payload[0] is int and payload[1] is int and (payload[2] is float or payload[2] is int):
		_accept_stray(sender, payload[0], payload[1], payload[2])
	if action == "card" and payload.size() == 3 and payload[0] == state.match_id and payload[1] is String and payload[2] is int:
		if cards != null: cards.action(sender, payload[1], payload[2])
	if action == "restart" and payload.is_empty() and sender == session.room.host_peer_id:
		restart()
	if action == "punish_spin" and payload.size() == 2 and payload[0] == state.match_id and payload[1] is int:
		_accept_punish_spin(sender, payload[1])
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
	if _card_throw(sender, charge):
		return
	_launch(sender, aim, charge, request_id)


## 그냥 던진 다트를 방장이 확정한다. 다트 단계에 다트가 남은 사람이면 누구나(자기 차례가 아니어도) 던질 수 있다.
## 날아가는 계산·사람 맞히기는 GameView.throw_stray 가 한다(컨트롤러는 씬을 모른다). 쓴 다트는 이번 라운드에 돌려받지 못한다.
func _accept_stray(sender: int, match_id: int, request_id: int, charge: float) -> void:
	var player: MatchPlayer = state.find_player(sender)
	if player == null or player.is_bot or match_id != state.match_id:
		return
	# 카드 던지기 카드가 걸려 있으면 다트가 없어도 카드는 던질 수 있다.
	var card_ready: bool = cards != null and bool(cards.modifiers(sender).get("card_throw", false))
	if state.phase not in DART_PHASES or (player.darts <= 0 and not card_ready):
		return
	if not is_finite(charge) or charge < 0 or charge > 1 or request_id <= int(_last_requests.get(sender, 0)):
		return
	# 지금 던지는 사람이 자기 다트가 날아가는 동안(비행·정산) 한 번 더 누른 것은 실수로 보고 받지 않는다.
	var active := state.active_player()
	var mine: bool = active != null and active.peer_id == sender
	if mine and state.phase != MatchState.Phase.AIMING:
		return
	if _card_throw(sender, charge):
		_last_requests[sender] = request_id
		return
	if not throw_stray.is_valid() or not bool(throw_stray.call(sender, charge)):
		return
	_last_requests[sender] = request_id
	player.darts -= 1
	add_feed(feed_entry("dart", player, "다트를 그냥 던짐 · 남은 다트 %d" % player.darts))
	if mine:
		state.darts_left = player.darts
		if state.darts_left <= 0:
			state.last_hit = {"peer_id": sender, "points": 0, "reason": "다트를 다 써 버림 · 0점", "request_id": -state.turn_id}
			_set_phase(MatchState.Phase.SETTLING, config.settle_seconds)
			return
	_publish()


## 사람이 다트에 맞았다(몸으로 막기 · 그냥 던진 다트 공통). 횟수를 세고 DART_HITS_TO_FALL 번째면 쓰러뜨린다.
## push = 밀려나는 방향과 세기(0 이면 GameView 가 던진 사람 반대쪽으로 정한다). 쓰러졌으면 true.
func dart_hit_player(victim_id: int, push: Vector3 = Vector3.ZERO) -> bool:
	var victim: MatchPlayer = state.find_player(victim_id)
	if victim == null:
		return false
	victim.dart_hits += 1
	if victim.dart_hits < DART_HITS_TO_FALL:
		add_feed(feed_entry("dizzy", null, "다트에 맞음 %d/%d" % [victim.dart_hits, DART_HITS_TO_FALL], victim))
		return false
	victim.dart_hits = 0
	add_feed(feed_entry("dizzy", null, "다트 %d번 맞고 쓰러짐!" % DART_HITS_TO_FALL, victim))
	if knock_down.is_valid():
		knock_down.call(victim_id, push)
	return true


## 그냥 던진 다트가 사람에게 꽂혔다(GameView 가 꽂히는 시각에 부른다). 잠깐 움찔 + 맞은 횟수.
func stray_hit(victim_id: int, push: Vector3) -> void:
	if not multiplayer.is_server() or state.find_player(victim_id) == null:
		return
	if not dart_hit_player(victim_id, push) and stun_player.is_valid():
		stun_player.call(victim_id, STRAY_HIT_STUN)
	_publish()


## 라운드가 시작될 때 모두에게 다트를 다시 채운다(카드 나눠 주기와 같은 때). 맞은 횟수도 0 으로.
func _refill_darts() -> void:
	for player in state.players:
		player.darts = config.darts_per_turn
		player.dart_hits = 0


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
	if _card_throw(active.peer_id, charge):
		return
	_launch(active.peer_id, aim, charge, _request_number)


## 카드 던지기 카드(2026-11-21): 걸려 있으면 이번 투척은 다트 대신 카드가 날아간다(다트·점수·차례는 그대로).
## 맞은 사람 기절·병 깨기는 CardWorld 가 한다. 던졌으면 true.
func _card_throw(peer_id: int, charge: float) -> bool:
	if cards == null or not bool(cards.modifiers(peer_id).get("card_throw", false)) or not card_world.is_valid():
		return false
	if not bool(card_world.call("card_throw", {"peer_id": peer_id, "charge": charge})):
		return false
	cards.consume_card_throw(peer_id)
	add_feed(feed_entry("card", state.find_player(peer_id), "카드를 휙 던짐!"))
	_publish()
	return true


## 차례 바꾸기 카드: 지금 차례를 끝내지 않고 같은 차례 번호(turn_index)에서 바뀐 사람으로 다시 시작한다.
func restart_turn() -> void:
	_pending_hit.clear()
	_begin_turn()


## 타이머 감소 카드: 남은 조준 시간을 ratio 배로 줄인다(그래도 floor_seconds 는 남긴다). 줄인 뒤 남은 초.
func cut_timer(ratio: float, floor_seconds: float) -> float:
	var left: float = maxf(_turn_end - _now(), 0.0)
	var cut: float = minf(left, maxf(floor_seconds, left * ratio))
	_turn_end = _now() + cut
	if state.phase == MatchState.Phase.AIMING:
		_phase_end = _turn_end
	return cut


## 확정된 한 발을 비행으로 보낸다. 사람과 봇이 같은 경로를 쓴다.
func _launch(peer_id: int, aim: Vector2, charge: float, request_id: int) -> void:
	_flight_input = {"aim": aim, "charge": charge}
	var data: Dictionary = _solve(peer_id, aim, charge)
	_pending_hit = data.duplicate()
	_pending_hit.merge({"peer_id": peer_id, "request_id": request_id})
	state.darts_left -= 1
	# 손에 든 다트도 같이 준다(라운드당 다트 — 이번 차례의 남은 발수 = 던지는 사람의 남은 다트).
	var thrower: MatchPlayer = state.find_player(peer_id)
	if thrower != null:
		thrower.darts = maxi(thrower.darts - 1, 0)
	_set_phase(MatchState.Phase.FLIGHT, float(data.duration))
	data.merge({"match_id": state.match_id, "turn_id": state.turn_id, "peer_id": peer_id})
	if session != null:
		session.receive_game_event.rpc("dart", data)
	_play_throw(data)


## 카드 궤적 효과를 넣은 비행 계산. 가림판·숫자 섞기는 꽂힐 때 센다(MatchCards.landing_points).
## 2026-11-21 새 다트 카드: 좌표 고정(마지막 꽂힌 자리로 똑같이 — 바람·무게·졸림 무시, 충전 1) · 관통(몸·셔터 무시) · 고무(맞고 튕김).
func _solve(peer_id: int, aim: Vector2, charge: float) -> Dictionary:
	var mods: Dictionary = cards.modifiers(peer_id) if cards != null else {}
	var pierce: bool = bool(mods.get("pierce", false))
	var fixed: bool = bool(mods.get("repeat", false)) and cards != null and cards.last_landing.is_finite()
	var adjusted := aim + Vector2(float(mods.get("push", 0)), -float(mods.get("drop", 0)))
	if fixed:
		adjusted = cards.last_landing
		charge = 1.0
	elif mods.get("drowsy", false):
		if not _flight_input.has("drowsy_offset"):
			var spread := CardCatalog.DROWSY_AIM_SPREAD
			_flight_input.drowsy_offset = Vector2(_random.randf_range(-spread, spread), _random.randf_range(-spread, spread))
		adjusted += Vector2(_flight_input.drowsy_offset)
	var offsets: Array[Vector2] = [Vector2.ZERO]
	if mods.get("triple", false):
		if not _flight_input.has("pattern"): _flight_input.pattern = CardCatalog.special_offsets(_random)
		offsets.assign(_flight_input.pattern)
	var flights: Array[Dictionary] = []
	for index in range(offsets.size()):
		var offset: Vector2 = offsets[index]
		var one: Dictionary = _call_solve(adjusted + offset, charge, peer_id, CardCatalog.POWER_SPEED_MULTIPLIER if mods.get("power", false) else 1.0, pierce)
		var arrival := float(one.duration)
		if state.phase == MatchState.Phase.FLIGHT: arrival = maxf(0, _phase_end - _now())
		if absf(float(one.x)) < 50 and not bool(one.get("infill_hit", false)) and not _shutter_stops(one, pierce, arrival):
			if bool(mods.get("rubber", false)):
				one = _bounce(one, peer_id, index, pierce, arrival)
		one["large"] = bool(mods.get("large", false))
		one["power"] = bool(mods.get("power", false))
		one["pierce"] = pierce
		flights.append(one)
	var data: Dictionary = flights[0].duplicate()
	data["flights"] = flights
	data.points = 0
	for one in flights:
		data.points += int(one.points)
		data.duration = maxf(float(data.duration), float(one.duration))

	return data


## 시험용 가짜 solve_throw(인자 4개)와도 맞도록 관통일 때만 5번째 인자를 넘긴다.
func _call_solve(aim: Vector2, charge: float, peer_id: int, speed: float, pierce: bool) -> Dictionary:
	if pierce:
		return solve_throw.call(aim, charge, peer_id, speed, true)
	return solve_throw.call(aim, charge, peer_id, speed)


## 고무 다트: 처음 닿은 자리(bounce_at · bounce_time)에서 무작위 방향으로 튕겨 RUBBER_SECONDS 뒤 새 자리에 꽂힌다.
## 튕길 방향·거리는 한 발에 한 번만 뽑는다(비행 중 다른 카드로 다시 계산해도 같은 자리). 판정은 새 자리(x, y)다.
func _bounce(first: Dictionary, peer_id: int, index: int, pierce: bool, arrival: float) -> Dictionary:
	var key: String = "bounce_%d" % index
	if not _flight_input.has(key):
		_flight_input[key] = Vector2.from_angle(_random.randf_range(0, TAU)) * _random.randf_range(RUBBER_REACH.x, RUBBER_REACH.y)
	var landing: Vector2 = Vector2(float(first.x), float(first.y)) + Vector2(_flight_input[key])
	var second := first.duplicate()
	var offset := Vector2(_flight_input[key]) * TableView.BOARD_SCALE * BoardLayout.RADIUS
	var start: Vector3 = first.target
	var via := start + Vector3(0, 0.20, 0.55)
	second.x = landing.x
	second.y = landing.y
	second.target = start + Vector3(offset.x, offset.y, 0)
	second["shutter_hit"] = false
	var final_age := arrival + (0.0 if state.phase == MatchState.Phase.FLIGHT else RUBBER_SECONDS)
	if not _shutter_stops(second, pierce, final_age):
		var shape: Dictionary = shape_at(final_age)
		shape.cover = false
		if BoardChaos.on_infill(landing, shape) and not BoardChaos.locate(landing, shape, BoardView.BoardArt.BACKING_RATIO).is_finite():
			second.target = Vector3(second.target) + Vector3.BACK * BoardChaos.INFILL_FRONT
			second["infill_hit"] = true
			second.points = 0
	var hops: Array = []
	var from := start
	var elapsed := 0.0
	for to: Vector3 in [via, second.target]:
		var duration := RUBBER_SECONDS * 0.5
		var contact: Dictionary = rebound_contact.call(from, to, duration, peer_id, pierce) if rebound_contact.is_valid() else {}
		if not contact.is_empty():
			second.merge(contact, true)
			to = second.target
			duration = float(contact.duration)
		hops.append([to, duration])
		elapsed += duration
		if not contact.is_empty(): break
		from = to
	second["start"] = first.start
	second["bounce_at"] = start
	second["bounce_time"] = float(first.duration)
	second["hops"] = hops
	second["duration"] = float(first.duration) + elapsed
	second["reason"] = "고무 다트 튕김 · " + str(second.get("reason", ""))
	return second


func _shutter_stops(flight: Dictionary, pierce: bool, arrival: float) -> bool:
	var shape: Dictionary = shape_at(arrival)
	var stopped := not pierce and BoardChaos.covered(Vector2(flight.x, flight.y), shape)
	flight["shutter_hit"] = stopped
	if stopped:
		flight.target = Vector3(flight.target) + Vector3.BACK * BoardChaos.shutter_depth(Vector2(flight.x, flight.y), shape, BoardLayout.RADIUS * TableView.BOARD_SCALE)
		flight.points = 0
	return stopped


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


func _process(delta: float) -> void:
	if state.punish_target != 0 and state.phase in DART_PHASES:
		_tick_punish_spin(delta)
	if not multiplayer.is_server():
		return
	match state.phase:
		MatchState.Phase.AIMING:
			if cards != null and not card_test_active:
				cards.tick_bots()
			if _now() >= _turn_end:
				_timeout_turn()
		MatchState.Phase.FLIGHT:
			if cards != null and not card_test_active:
				cards.tick_bots()
			if _now() >= _phase_end:
				_land_dart()
		MatchState.Phase.SETTLING:
			if not card_test_active and _now() >= _phase_end:
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
	# 라운드 시작 = 모두가 다트를 받는 때(2026-11-15). 카드를 끈 방도 여기를 지나므로 맨 먼저 채운다.
	_refill_darts()
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
	var punishing: bool = state.punish_target != 0
	if cards != null and not punishing: cards.begin_dart_turn()
	state.turn_id += 1
	# 이번 차례의 발수 = 이 사람이 라운드 시작 때 받은 다트 중 아직 남은 것(차례 밖에서 던져 버렸으면 그만큼 적다).
	var thrower: MatchPlayer = state.active_player()
	state.darts_left = thrower.darts if thrower != null else 0
	_pending_hit.clear()
	_turn_end = _now() + config.turn_seconds
	if thrower != null and cards != null and not punishing and cards.actions.take_skip(thrower.peer_id):
		# 점프 카드(2026-11-21): 이 사람의 이번 차례는 통째로 건너뛴다(다트는 남는다 — 그냥 던지기에는 쓸 수 있다).
		state.darts_left = 0
		state.last_hit = {"peer_id": thrower.peer_id, "points": 0, "reason": "점프 카드 · 차례 건너뜀", "request_id": -state.turn_id}
		add_feed(feed_entry("card", thrower, "점프! 차례를 건너뜀"))
		_set_phase(MatchState.Phase.SETTLING, config.settle_seconds)
		return
	if thrower != null and state.darts_left <= 0:
		# 차례가 오기 전에 다트를 다 던져 버렸다 → 던질 것이 없으니 바로 다음 사람에게 넘긴다.
		state.last_hit = {"peer_id": thrower.peer_id, "points": 0, "reason": "다트 없음 · 차례 넘김", "request_id": -state.turn_id}
		add_feed(feed_entry("dart", thrower, "다트가 없어 차례를 넘김"))
		_set_phase(MatchState.Phase.SETTLING, config.settle_seconds)
		return
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
	if state.punish_target != 0:
		_land_punish_dart()
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
		_pending_hit.taken = float(result.get("taken", 0.0))
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
		_begin_punish()
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
	# 몸으로 막은 것도 "다트에 맞은 것"이다 → 두 번째면 쓰러진다(2026-11-15).
	dart_hit_player(victim_id)


func _advance_turn() -> void:
	if state.punish_target != 0:
		_advance_punish()
		return
	if cards != null: cards.end_dart_turn()
	if cards != null and state.active_player() != null and cards.take_retry(state.active_player().peer_id):
		# 재도전 카드: 바로 이어서 한 차례 더 → 그 차례에 던질 다트를 새로 준다.
		state.active_player().darts = config.darts_per_turn
		_begin_turn()
		return
	state.turn_index += 1
	if state.turn_index >= state.players.size():
		state.turn_index = 0
		# 차례 바꾸기 카드로 섞인 순서는 라운드가 끝나면 자리 순서로 돌아간다.
		state.players.sort_custom(func(a: MatchPlayer, b: MatchPlayer) -> bool: return a.seat < b.seat)
		if state.round_number >= config.rounds:
			_begin_punish()
			return
		state.round_number += 1
		_begin_table()
		return
	_begin_turn()


## 경기 끝 벌칙 시작(2026-11-23 사용자 요청). 꼴찌를 점수 과녁판에 묶고 판을 돌린다 → 나머지가 거기에 던진다.
## 벌칙을 끈 방·혼자 하는 방은 그냥 끝낸다. 다트 단계를 그대로 쓰므로 차례·시간 제한·봇 투척이 평소와 같다.
func _begin_punish() -> void:
	var loser: MatchPlayer = _punish_loser()
	if not room_settings.punishment or loser == null or state.players.size() < 2:
		_set_phase(MatchState.Phase.FINISHED, 0)
		return
	state.punish_target = loser.peer_id
	state.punish_angle = 0.0
	state.punish_spin = 0.0
	state.punish_dir = 1
	var throwers: int = state.players.size() - 1
	var each: int = maxi(2, ceili(float(PUNISH_TOTAL_DARTS) / float(throwers)))
	for player in state.players:
		player.clear_effects()
		player.hand.clear()
		player.pending_card = -1
		player.pending_slot = -1
		player.punish_hits = 0
		player.speed_scale = 1.0
		player.darts = 0 if player.peer_id == loser.peer_id else each
	notice = "벌칙 · 꼴찌 %s 과녁판에 묶였다 — 한 사람 %d발 · 맞을 때마다 토큰 −%d (꼴찌는 A·D 로 판을 돌린다)" % [loser.display_name, each, PlayerWallet.PUNISH_COST]
	add_feed(feed_entry("dizzy", loser, "꼴찌 · 과녁판에 묶였다"))
	state.turn_index = -1
	_advance_punish()


## 벌칙 회전을 한 프레임 굴린다. 방장과 손님이 같은 식으로 굴리고, 방장이 보내는 스냅샷이 틈틈이 다시 맞춘다.
## 가속이 있어서 묶인 사람이 방향을 바꿔도 곧바로 뒤집히지 않는다(다트가 날아오는 동안 홱 피하지 못하게).
func _tick_punish_spin(delta: float) -> void:
	state.punish_spin = move_toward(state.punish_spin, float(state.punish_dir) * PUNISH_SPIN_SPEED, PUNISH_SPIN_ACCEL * delta)
	state.punish_angle += state.punish_spin * delta


## 묶인 사람이 판을 돌릴 방향을 바꾼다(-1 = 왼쪽 · 1 = 오른쪽). 손님은 방장에게 부탁한다.
func request_punish_spin(direction: int) -> void:
	if multiplayer.is_server() or session == null:
		_accept_punish_spin(local_peer_id, direction)
	else:
		session.request_game_action.rpc_id(1, "punish_spin", [state.match_id, direction])


## 방장만: 지금 과녁판에 묶여 있는 사람이 보낸 방향만 받는다.
func _accept_punish_spin(sender: int, direction: int) -> void:
	if not multiplayer.is_server() or state.punish_target == 0 or sender != state.punish_target or direction == 0:
		return
	var want: int = 1 if direction > 0 else -1
	if want == state.punish_dir:
		return
	state.punish_dir = want
	_publish()


## 벌칙 대상 = 점수가 가장 낮은 사람. 동점이면 자리 순서상 뒤쪽(F6 RoundRules.loser 와 같은 규칙).
func _punish_loser() -> MatchPlayer:
	var rows: Array[Dictionary] = state.ranking()
	return rows[rows.size() - 1].player if not rows.is_empty() else null


## 벌칙 차례 넘기기: 묶인 꼴찌는 건너뛰고, 한 바퀴를 다 돌면 경기를 끝낸다.
func _advance_punish() -> void:
	state.turn_index += 1
	while state.turn_index < state.players.size() and state.players[state.turn_index].peer_id == state.punish_target:
		state.turn_index += 1
	if state.turn_index >= state.players.size():
		state.turn_index = 0
		var victim: MatchPlayer = state.find_player(state.punish_target)
		if victim != null:
			notice = "벌칙 끝 · %s 가 %d대 맞았다 (토큰 %+d)" % [victim.display_name, victim.punish_hits,
				PlayerWallet.match_reward(0, true, victim.punish_hits)]
		_set_phase(MatchState.Phase.FINISHED, 0)
		return
	_begin_turn()


## 벌칙 한 발. 점수는 없다 — 돌아가는 판 위의 몸에 맞았는지만 센다.
## 판정은 회전을 되돌린 자리(BoardChaos.locate)로 한다 → 몸은 판과 함께 돌지만 치수는 고정이다.
func _land_punish_dart() -> void:
	var victim: MatchPlayer = state.find_player(state.punish_target)
	var thrower: MatchPlayer = state.active_player()
	var shape: Dictionary = BoardChaos.spun(state.punish_angle)
	var struck: bool = false
	for flight: Dictionary in _pending_hit.get("flights", [_pending_hit]):
		if bool(flight.get("shutter_hit", false)) or bool(flight.get("infill_hit", false)):
			continue
		var aim := Vector2(float(flight.x), float(flight.y))
		if BoardVictim.hit(BoardChaos.locate(aim, shape, BoardView.BoardArt.BACKING_RATIO)):
			struck = true
	_pending_hit.points = 0
	if struck and victim != null:
		victim.punish_hits += 1
		_pending_hit.reason = "%s 명중! 토큰 −%d" % [victim.display_name, PlayerWallet.PUNISH_COST]
		if thrower != null:
			add_feed(feed_entry("dizzy", thrower, "벌칙 명중", victim))
	else:
		_pending_hit.reason = "벌칙 · 빗나감"
	state.last_hit = _pending_hit.duplicate()
	_pending_hit.clear()
	if state.darts_left > 0 and _now() < _turn_end:
		_set_phase(MatchState.Phase.AIMING, _turn_end - _now())
	else:
		state.darts_left = 0
		_set_phase(MatchState.Phase.SETTLING, config.settle_seconds)


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


## [개발자 모드] 카드 시험대: 손패와 상관없이 카드 한 장을 바로 쓴다. 못 쓰면 이유를 돌려준다.
## 방장 화면에서만 부른다(ui/settings_panel.gd) — 클라이언트는 이 길로 들어올 수 없다.
func developer_card(peer_id: int, type: int, target_peer: int) -> String:
	if not multiplayer.is_server() or not developer_enabled:
		return "방장의 개발자 모드에서만 쓸 수 있습니다"
	if cards == null:
		return "이 방은 카드를 쓰지 않습니다"
	return cards.developer_play(peer_id, type, target_peer)


## 같은 맵의 혼자 플레이 대기실에서 조합 한 턴을 바로 연다.
func start_card_test(selection: Dictionary) -> void:
	if not multiplayer.is_server() or not developer_enabled or not room_settings.solo or state.phase != MatchState.Phase.WAITING:
		return
	var thrower := state.find_player(local_peer_id)
	if thrower == null:
		return
	card_test_active = true
	state.turn_index = state.players.find(thrower)
	cards = MatchCards.new(self)
	cards.begin_round()
	_refill_darts()
	_begin_turn()
	var failures: PackedStringArray = []
	var participants := state.players.duplicate()
	# 무효 카드의 대상 효과가 먼저 있어야 한다. 나머지는 자리 순서대로 적용한다.
	for counter_pass: bool in [false, true]:
		for player: MatchPlayer in participants:
			var type: int = int(selection.get(player.peer_id, -1))
			if not CardCatalog.is_available(type):
				continue
			var counter: bool = int(CardCatalog.card(type).target) == CardCatalog.Target.COUNTER
			if counter != counter_pass:
				continue
			var target: int = local_peer_id
			if player == thrower:
				target = 0
				for other: MatchPlayer in participants:
					if other != thrower and (not counter or int(selection.get(other.peer_id, -1)) >= 0):
						target = other.peer_id
						break
			var problem: String = developer_card(player.peer_id, type, target)
			if not problem.is_empty():
				failures.append("%s: %s (%s)" % [player.display_name, CardCatalog.card(type).name, problem])
	notice = "카드 조합 테스트 · Esc에서 다시 시작" if failures.is_empty() else "적용 실패 · " + " / ".join(failures)
	_publish()


## [개발자 모드] 점수를 직접 넣는다.
func developer_set_score(peer_id: int, points: int) -> void:
	if not multiplayer.is_server() or not developer_enabled:
		return
	var player: MatchPlayer = state.find_player(peer_id)
	if player == null:
		return
	player.score = maxi(0, points)
	if cards != null:
		cards.developer_set_score(peer_id, player.score)
	_publish()


## [개발자 모드] 걸려 있는 카드 효과를 전부 지운다.
func developer_clear_effects() -> void:
	if not multiplayer.is_server() or not developer_enabled or cards == null:
		return
	cards.developer_clear_effects()
	notice = "개발자: 카드 효과를 모두 지웠습니다."
	_publish()


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
		player.punish_hits = 0
		player.hand.clear()
	state.punish_target = 0
	state.punish_angle = 0.0
	state.punish_spin = 0.0
	state.punish_dir = 1
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
	snapshot["chaos"] = board_ages()
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
	if state.phase not in DART_PHASES:
		return BoardChaos.rest()
	# 벌칙 회전은 방장이 적분해 보낸 각도를 모두가 같이 굴린다(_tick_punish_spin) — 손님도 제 화면에서 이어 돌린다.
	if state.punish_target != 0:
		return BoardChaos.spun(state.punish_angle)
	if multiplayer.is_server() or session == null:
		return shape_at(0.0)
	return BoardChaos.from_ages(_chaos_ages, _now() - _received_at)


## 방장이 보는 elapsed 초 뒤 과녁 모양. 비행 판정이 "다트가 닿을 때의 판"을 보는 데 쓴다.
## 벌칙 회전은 묶인 사람이 도중에 바꿀 수 있으므로 이 예측은 어림이다 — **맞았는지는 꽂히는 순간의 각도로 센다**(_land_punish_dart).
func shape_at(elapsed: float) -> Dictionary:
	if state.punish_target != 0:
		return BoardChaos.spun(state.punish_angle + state.punish_spin * elapsed)
	return BoardChaos.from_ages(board_ages(), elapsed)


## 방장이 세는 카드 과녁 효과 시각. 벌칙 회전은 여기 들어가지 않는다(상태의 punish_angle 이 소유한다).
func board_ages() -> Dictionary:
	return cards.chaos_ages() if cards != null else {}


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
