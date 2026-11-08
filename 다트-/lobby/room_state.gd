class_name RoomState
extends RefCounted
## 서버가 확정하는 방 상태와 시작 조건. 통신과 화면 코드는 별도로 둔다.

enum Phase { LOBBY, LOADING, PLAYING }

const MIN_PLAYERS: int = 2
const MAX_PLAYERS: int = 4
## 인원수(capacity)별로 먼저 채우는 자리 순서(2026-11-07 사용자 요청 "정해진 인원수대로 테이블 카드·의자 세팅").
## 자리 번호는 TableView.SEATS 순서(0 왼쪽 · 1 안쪽 · 2 오른쪽 · 3 바깥쪽 = 다트 홀 쪽)다.
##   2명 = 왼쪽·오른쪽(테이블을 사이에 두고 마주 본다) · 3명 = 왼쪽·안쪽·오른쪽(다트 홀 쪽 바깥 자리를 비워 길을 연다) · 4명 = 전부.
## 뒤에 붙은 번호는 예비 자리다(인원보다 사람이 많아지는 일은 없지만 자리가 꼬여도 빈자리를 찾게).
const SEAT_ORDER := {1: [0, 2, 1, 3], 2: [0, 2, 1, 3], 3: [0, 1, 2, 3], 4: [0, 1, 2, 3]}

var settings := RoomSettings.new()
var room_code: String = ""
var has_password: bool = false

var phase: Phase = Phase.LOBBY
var match_id: int = 0
var host_peer_id: int = 0
var players: Array[RoomPlayer] = []


func find_player(peer_id: int) -> RoomPlayer:
	for player in players:
		if player.peer_id == peer_id:
			return player
	return null


func add_player(peer_id: int, display_name: String) -> bool:
	if phase != Phase.LOBBY or players.size() >= settings.capacity:
		return false
	if find_player(peer_id) != null:
		return false
	var occupied_seats: Array[int] = []
	for player in players:
		occupied_seats.append(player.seat)
	# 인원수에 맞는 자리부터 채운다(2인 방이면 0 → 2번 자리).
	for seat: int in seat_order(settings.capacity):
		if not occupied_seats.has(seat):
			players.append(RoomPlayer.new(peer_id, display_name, seat))
			if host_peer_id == 0:
				host_peer_id = peer_id
			return true
	return false


## 인원수별 자리 채우는 순서(SEAT_ORDER). 범위를 벗어난 인원은 4명 순서를 쓴다.
static func seat_order(capacity: int) -> Array[int]:
	var order: Array[int] = []
	order.assign(SEAT_ORDER.get(clampi(capacity, 1, MAX_PLAYERS), SEAT_ORDER[MAX_PLAYERS]))
	return order


## 테이블에 깔아 둘 자리(의자·매트·바닥 자리 표시): 지금 앉아 있는 사람 자리 + 빈자리를 인원수만큼 채운다.
## 빈자리는 그대로 깔려 있어야 "누가 들어올 수 있는 자리"가 보이므로 사람 수가 아니라 방 인원수로 정한다.
## 빈자리는 add_player 가 다음 사람을 앉힐 순서(seat_order)대로 고른다 → 깔린 빈 의자 = 실제로 다음 사람이 앉을 자리.
## 2026-11-08: 방장이 대기실에서 인원수를 줄이면(resize) 이미 앉은 사람 자리는 남기고 빈자리만 줄인다
##   (예: 0·1번에 둘이 있는데 4명 → 2명 = 0·1번만. 예전 계산은 0·2번 + 1번 = 의자 3개가 남았다).
func shown_seats() -> Array[int]:
	var seats: Array[int] = []
	for player in players:
		if not seats.has(player.seat):
			seats.append(player.seat)
	for seat: int in seat_order(settings.capacity):
		if seats.size() >= clampi(settings.capacity, 1, MAX_PLAYERS):
			break
		if not seats.has(seat):
			seats.append(seat)
	seats.sort()
	return seats


## 2026-11-08 사용자 요청 "인원수를 방장이 다시 정할 수 없는 것도 설정에서 다시 정할 수 있게":
## 대기실(LOBBY)에서만 인원수를 바꾼다. 경기 중에는 자리·턴 순서가 꼬이므로 무시한다.
##   - 지금 들어와 있는 사람 수보다 적게는 줄이지 않는다(사람을 내쫓지 않는다).
##   - 인원이 넘치면 번호가 큰 봇부터 뺀다.
##   - 연습 방(solo)은 봇 수 = 인원 − 사람 수로 맞춰 봇을 더 넣거나 뺀다.
## 이미 앉은 사람의 자리 번호(= 색·모양)는 바꾸지 않는다. 빈 의자만 shown_seats 가 다시 고른다.
func resize(capacity: int, bot_count: int) -> void:
	if phase != Phase.LOBBY:
		return
	var humans: int = 0
	for player in players:
		if not player.is_bot:
			humans += 1
	settings.capacity = clampi(capacity, maxi(humans, 1 if settings.solo else MIN_PLAYERS), MAX_PLAYERS)
	settings.bot_count = clampi(bot_count, 0, settings.capacity - humans) if settings.solo else 0
	var bot_limit: int = settings.capacity - humans
	if settings.solo:
		bot_limit = settings.bot_count
	for index in range(MAX_PLAYERS - 1, 0, -1):
		if players.size() - humans <= bot_limit:
			break
		var bot := find_player(-index)
		if bot != null and bot.is_bot:
			players.erase(bot)
	if settings.solo:
		add_bots(settings.bot_count)


func remove_player(peer_id: int) -> void:
	var player := find_player(peer_id)
	if player != null:
		players.erase(player)
		if host_peer_id == peer_id:
			host_peer_id = 0
			for remaining in players:
				if not remaining.is_bot:
					host_peer_id = remaining.peer_id
					break


func can_start() -> bool:
	if phase != Phase.LOBBY or players.size() < (1 if settings.solo else MIN_PLAYERS):
		return false
	for player in players:
		if not player.is_ready:
			return false
	return true


func add_bots(count: int = 3) -> void:
	if phase != Phase.LOBBY:
		return
	# 음수는 방 내부 참가자 식별자이며 RPC 수신 대상으로 사용하지 않는다.
	for index in range(1, MAX_PLAYERS):
		if players.size() >= settings.capacity or index > count:
			break
		if find_player(-index) == null and add_player(-index, "봇 %d" % index):
			var bot := find_player(-index)
			bot.is_bot = true
			bot.is_ready = true
			bot.is_loaded = true


func all_loaded() -> bool:
	if players.size() < (1 if settings.solo else MIN_PLAYERS):
		return false
	for player in players:
		if not player.is_loaded:
			return false
	return true


func return_to_lobby() -> void:
	phase = Phase.LOBBY
	for player in players:
		player.is_ready = player.is_bot
		player.is_loaded = player.is_bot


func to_snapshot() -> Dictionary:
	var roster: Array[Dictionary] = []
	for player in players:
		roster.append(player.to_snapshot())
	return {"settings": settings.to_snapshot(), "room_code": room_code, "has_password": has_password, "phase": phase, "match_id": match_id, "host_peer_id": host_peer_id, "players": roster}


static func from_snapshot(data: Dictionary) -> RoomState:
	var state := RoomState.new()
	state.settings = RoomSettings.from_snapshot(data.get("settings", {}))
	state.room_code = str(data.get("room_code", ""))
	state.has_password = bool(data.get("has_password", false))
	state.phase = data.phase
	state.match_id = data.match_id
	state.host_peer_id = int(data.get("host_peer_id", 1))
	for player_data: Dictionary in data.players:
		state.players.append(RoomPlayer.from_snapshot(player_data))
	return state
