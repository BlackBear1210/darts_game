class_name RoomState
extends RefCounted
## 서버가 확정하는 방 상태와 시작 조건. 통신과 화면 코드는 별도로 둔다.

enum Phase { LOBBY, LOADING, PLAYING }

const MIN_PLAYERS: int = 2
const MAX_PLAYERS: int = 4

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
	if phase != Phase.LOBBY or players.size() >= MAX_PLAYERS:
		return false
	if find_player(peer_id) != null:
		return false
	var occupied_seats: Array[int] = []
	for player in players:
		occupied_seats.append(player.seat)
	for seat in range(MAX_PLAYERS):
		if not occupied_seats.has(seat):
			players.append(RoomPlayer.new(peer_id, display_name, seat))
			if host_peer_id == 0:
				host_peer_id = peer_id
			return true
	return false


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
	if phase != Phase.LOBBY or players.size() < MIN_PLAYERS:
		return false
	for player in players:
		if not player.is_ready:
			return false
	return true


func add_bots() -> void:
	if phase != Phase.LOBBY:
		return
	# 음수는 방 내부 참가자 식별자이며 RPC 수신 대상으로 사용하지 않는다.
	for index in range(1, MAX_PLAYERS):
		if players.size() >= MAX_PLAYERS:
			break
		if find_player(-index) == null and add_player(-index, "봇 %d" % index):
			var bot := find_player(-index)
			bot.is_bot = true
			bot.is_ready = true
			bot.is_loaded = true


func all_loaded() -> bool:
	if players.size() < MIN_PLAYERS:
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
	return {"phase": phase, "match_id": match_id, "host_peer_id": host_peer_id, "players": roster}


static func from_snapshot(data: Dictionary) -> RoomState:
	var state := RoomState.new()
	state.phase = data.phase
	state.match_id = data.match_id
	state.host_peer_id = int(data.get("host_peer_id", 1))
	for player_data: Dictionary in data.players:
		state.players.append(RoomPlayer.from_snapshot(player_data))
	return state
