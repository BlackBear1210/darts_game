class_name MatchConfig
extends Resource
## 경기 규칙 수치(Resource). 기본값은 game/match/default_match.tres. hand_limit 은 이전 카드 계획 값이며 새 7장 규칙과 아직 연결 전.

@export_range(1, 10) var rounds: int = 5
@export_range(1, 5) var darts_per_turn: int = 3
@export var turn_seconds: float = 20.0
@export var card_seconds: float = 15.0
@export var transition_seconds: float = 0.9
@export var flight_seconds: float = 0.45
@export var settle_seconds: float = 1.0
## 라운드 사이 테이블 집합 제한시간. 이 안에 자기 자리에 앉지 않으면 자동 착석 + 슬로우.
@export var table_seconds: float = 10.0
## 지각 페널티: 다음 라운드 동안 이동 속도 배율.
@export_range(0.1, 1.0) var slow_speed_scale: float = 0.5
@export var hand_limit: int = 3
@export var emote_warning: float = 0.3
@export var emote_seconds: float = 1.0
@export var emote_gap: float = 0.5


func to_snapshot() -> Dictionary:
	return {
		"rounds": rounds, "darts_per_turn": darts_per_turn,
		"turn_seconds": turn_seconds, "card_seconds": card_seconds,
		"transition_seconds": transition_seconds, "flight_seconds": flight_seconds,
		"settle_seconds": settle_seconds, "table_seconds": table_seconds,
		"slow_speed_scale": slow_speed_scale, "hand_limit": hand_limit,
		"emote_warning": emote_warning, "emote_seconds": emote_seconds, "emote_gap": emote_gap,
	}


static func from_snapshot(data: Dictionary) -> MatchConfig:
	var config := MatchConfig.new()
	for key: String in data:
		config.set(key, data[key])
	return config
