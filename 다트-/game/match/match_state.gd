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
var feed: Array[String] = []
## 경기 끝 벌칙(2026-11-23): 과녁판에 묶인 꼴찌의 peer id. 0 = 벌칙 없음.
## 벌칙이 끝나도 지우지 않는다 — 결과 화면이 "누가 몇 대 맞았는지" 를 이 값으로 찾는다.
## 벌칙이 **진행 중**인지는 `punish_target != 0 and phase in DART_PHASES` 로 본다.
var punish_target: int = 0
## 벌칙 회전(2026-11-23): 지금 각도(라디안) · 각속도(라디안/초) · 묶인 사람이 고른 방향(-1 왼쪽 / 1 오른쪽).
## 카드 회전과 달리 **방장이 적분해서 보낸다** — 묶인 사람이 도중에 방향을 바꾸므로 "걸린 지 몇 초" 공식으로는 못 센다.
var punish_angle: float = 0.0
var punish_spin: float = 0.0
var punish_dir: int = 1


func active_player() -> MatchPlayer:
	return players[turn_index] if not players.is_empty() else null


## 점수 높은 순. 원소 = {"player": MatchPlayer, "rank": 1부터(동점은 같은 순위)}.
## 결과 화면과 토큰 보상이 같은 순위를 쓰도록 여기 한 곳에서만 센다.
func ranking() -> Array[Dictionary]:
	var sorted: Array[MatchPlayer] = players.duplicate()
	sorted.sort_custom(func(a: MatchPlayer, b: MatchPlayer) -> bool: return a.score > b.score)
	var rows: Array[Dictionary] = []
	var rank: int = 0
	var previous: float = NAN
	for index in range(sorted.size()):
		if not is_equal_approx(sorted[index].score, previous):
			rank = index + 1
		previous = sorted[index].score
		rows.append({"player": sorted[index], "rank": rank})
	return rows


func find_player(peer_id: int) -> MatchPlayer:
	for player in players:
		if player.peer_id == peer_id: return player
	return null


func to_snapshot() -> Dictionary:
	var roster: Array[Dictionary] = []
	for player in players: roster.append(player.to_snapshot())
	return {"match_id": match_id, "revision": revision, "phase": phase,
		"round": round_number, "turn_index": turn_index, "turn_id": turn_id,
		"feed": feed, "darts_left": darts_left, "players": roster, "last_hit": last_hit,
		"punish_target": punish_target, "punish_angle": punish_angle,
		"punish_spin": punish_spin, "punish_dir": punish_dir}


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
	state.punish_target = int(data.get("punish_target", 0))
	state.punish_angle = float(data.get("punish_angle", 0.0))
	state.punish_spin = float(data.get("punish_spin", 0.0))
	state.punish_dir = int(data.get("punish_dir", 1))
	state.feed.assign(data.get("feed", []))
	for player: Dictionary in data.players: state.players.append(MatchPlayer.from_snapshot(player))
	return state
