class_name MatchConfig
extends Resource

@export_range(1, 10) var rounds: int = 4
@export_range(1, 5) var darts_per_turn: int = 2
@export var turn_seconds: float = 12.0
@export var card_seconds: float = 15.0
@export var transition_seconds: float = 0.9
@export var flight_seconds: float = 0.45
@export var settle_seconds: float = 1.0
@export var hand_limit: int = 3
@export var emote_warning: float = 0.3
@export var emote_seconds: float = 1.0
@export var emote_gap: float = 0.5


func to_snapshot() -> Dictionary:
	return {
		"rounds": rounds, "darts_per_turn": darts_per_turn,
		"turn_seconds": turn_seconds, "card_seconds": card_seconds,
		"transition_seconds": transition_seconds, "flight_seconds": flight_seconds,
		"settle_seconds": settle_seconds, "hand_limit": hand_limit,
		"emote_warning": emote_warning, "emote_seconds": emote_seconds, "emote_gap": emote_gap,
	}


static func from_snapshot(data: Dictionary) -> MatchConfig:
	var config := MatchConfig.new()
	for key: String in data:
		config.set(key, data[key])
	return config
