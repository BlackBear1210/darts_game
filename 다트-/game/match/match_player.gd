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
## 손패. 원소는 카드 종류 번호(game/card_round/rules/card_catalog.gd).
## 2026-10-28부터 방장이 라운드 시작 전에 7장까지 채워 스냅샷으로 모두에게 보낸다(CardHandRules 규칙).
var hand: Array[int] = []
## 이동 속도 배율. 테이블 집합에 늦으면 다음 라운드 동안 MatchConfig.slow_speed_scale 이 된다.
var speed_scale: float = 1.0
var pending_card: int = -1
var card_effects: Dictionary = {}


func score_hit(base_score: int) -> int:
	return base_score * multiplier + bonus if base_score > 0 else 0


func clear_effects() -> void:
	layout.reset()
	bonus = 0
	multiplier = 1


func effects_text() -> String:
	var effects := PackedStringArray()
	if multiplier != 1: effects.append("×%d" % multiplier)
	if bonus != 0: effects.append("+%d" % bonus)
	if layout.numbers != BoardLayout.DEFAULT_NUMBERS: effects.append("점수 섞임")
	return " · ".join(effects) if not effects.is_empty() else "기본 과녁"


func to_snapshot() -> Dictionary:
	return {"peer_id": peer_id, "name": display_name, "seat": seat, "score": score, "bot": is_bot,
		"numbers": layout.numbers, "bonus": bonus, "multiplier": multiplier, "hand": hand,
		"speed_scale": speed_scale, "pending_card": pending_card, "card_effects": card_effects}


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
	player.speed_scale = data.get("speed_scale", 1.0)
	player.hand.assign(data.get("hand", []))
	player.pending_card = int(data.get("pending_card", -1))
	player.card_effects = data.get("card_effects", {})
	return player
