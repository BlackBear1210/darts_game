class_name MatchPlayer
extends RefCounted
## 로비의 신원과 경기의 가변 상태를 분리한다.

var peer_id: int
var display_name: String
var seat: int
var score: int = 0
var is_bot: bool = false
var layout := BoardLayout.new()
var bonus: int = 0
var multiplier: int = 1
var hand: Array[CardDefinition] = []


func score_hit(base_score: int) -> int:
	return base_score * multiplier + bonus if base_score > 0 else 0


func clear_effects() -> void:
	layout.reset()
	bonus = 0
	multiplier = 1


func find_card(uid: int) -> CardDefinition:
	for card in hand:
		if card.uid == uid:
			return card
	return null


func effects_text() -> String:
	var effects := PackedStringArray()
	if multiplier != 1: effects.append("×%d" % multiplier)
	if bonus != 0: effects.append("+%d" % bonus)
	if layout.numbers != BoardLayout.DEFAULT_NUMBERS: effects.append("점수 섞임")
	return " · ".join(effects) if not effects.is_empty() else "기본 과녁"


func to_snapshot() -> Dictionary:
	var cards: Array[Dictionary] = []
	for card in hand: cards.append(card.to_snapshot())
	return {"peer_id": peer_id, "name": display_name, "seat": seat, "score": score, "bot": is_bot,
		"numbers": layout.numbers, "bonus": bonus, "multiplier": multiplier, "hand": cards}


static func from_snapshot(data: Dictionary) -> MatchPlayer:
	var player := MatchPlayer.new()
	player.peer_id = data.peer_id
	player.display_name = data.name
	player.seat = data.seat
	player.score = data.score
	player.is_bot = data.get("bot", false)
	player.layout.numbers.assign(data.numbers)
	player.bonus = data.bonus
	player.multiplier = data.multiplier
	for card: Dictionary in data.hand: player.hand.append(CardDefinition.from_snapshot(card))
	return player
