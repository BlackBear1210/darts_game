class_name MatchState
extends RefCounted
## 방장이 확정해 모든 화면에 보내는 경기 상태 스냅샷(단계·라운드·차례·남은 발수·참가자).

## TABLE(라운드 사이 테이블 집합)은 기존 숫자 값이 바뀌지 않게 맨 뒤에 둔다. 시험과 저장 결과가 2=AIMING, 6=FINISHED 를 쓴다.
enum Phase { WAITING, PREPARING, AIMING, FLIGHT, SETTLING, CARDS, FINISHED, TABLE }

var match_id: int = 0
var revision: int = 0
var phase: Phase = Phase.WAITING
var round_number: int = 1
var turn_index: int = 0
var turn_id: int = 0
var darts_left: int = 0
var players: Array[MatchPlayer] = []
var last_hit: Dictionary = {}


func active_player() -> MatchPlayer:
	return players[turn_index] if not players.is_empty() else null


func find_player(peer_id: int) -> MatchPlayer:
	for player in players:
		if player.peer_id == peer_id: return player
	return null


func to_snapshot() -> Dictionary:
	var roster: Array[Dictionary] = []
	for player in players: roster.append(player.to_snapshot())
	return {"match_id": match_id, "revision": revision, "phase": phase,
		"round": round_number, "turn_index": turn_index, "turn_id": turn_id,
		"darts_left": darts_left, "players": roster, "last_hit": last_hit}


static func from_snapshot(data: Dictionary) -> MatchState:
	var state := MatchState.new()
	state.match_id = data.match_id
	state.revision = data.revision
	state.phase = data.phase
	state.round_number = data.round
	state.turn_index = data.turn_index
	state.turn_id = data.turn_id
	state.darts_left = data.darts_left
	state.last_hit = data.last_hit
	for player: Dictionary in data.players: state.players.append(MatchPlayer.from_snapshot(player))
	return state
