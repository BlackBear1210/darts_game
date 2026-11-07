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


## 테이블에 깔아 둘 자리(의자·매트·바닥 자리 표시): 인원수만큼의 기본 자리 + 지금 앉아 있는 사람 자리.
## 빈자리는 그대로 깔려 있어야 "누가 들어올 수 있는 자리"가 보이므로 사람 수가 아니라 방 인원수로 정한다.
## 인원수를 줄였는데 이미 다른 자리에 앉은 사람이 있으면 그 자리도 남긴다(의자가 사라져 허공에 앉지 않게).
func shown_seats() -> Array[int]:
	var seats: Array[int] = []
	var order: Array[int] = seat_order(settings.capacity)
	for index in range(clampi(settings.capacity, 1, MAX_PLAYERS)):
		seats.append(order[index])
	for player in players:
		if not seats.has(player.seat):
			seats.append(player.seat)
	seats.sort()
	return seats


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
