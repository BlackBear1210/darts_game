class_name MatchPlayer
extends RefCounted
## 로비의 신원과 경기의 가변 상태를 분리한다.

var peer_id: int
var display_name: String
var seat: int
var score: float = 0.0
var is_bot: bool = false
var layout := BoardLayout.new()
var bonus: int = 0
var multiplier: int = 1
## 손패. 원소는 카드 종류 번호(game/card_round/rules/card_catalog.gd).
## 2026-10-28부터 방장이 라운드 시작 전에 7장까지 채워 스냅샷으로 모두에게 보낸다(CardHandRules 규칙).
var hand: Array[int] = []
## 이동 속도 배율. 테이블 집합에 늦으면 다음 라운드 동안 MatchConfig.slow_speed_scale 이 된다.
var speed_scale: float = 1.0
## 손에 든 다트 수(2026-11-15 "턴마다가 아니라 라운드마다 모두가 다트를 받는다").
## 라운드가 시작될 때(카드 나눠 주기) MatchConfig.darts_per_turn 만큼 다시 채운다. 자기 차례가 아닐 때 던져도 줄고,
## 그렇게 쓴 다트는 다음 라운드까지 돌려받지 못한다 → 자기 차례에 던질 다트가 그만큼 모자란다.
var darts: int = 0
## 이번 라운드에 다트에 맞은 횟수. MatchController.DART_HITS_TO_FALL(2)번이면 쓰러진다(래그돌) → 0 으로 돌아간다.
var dart_hits: int = 0
## 경기 끝 벌칙에서 과녁판에 묶인 채 몸에 맞은 횟수(2026-11-23). 토큰이 이 수만큼 깎인다.
var punish_hits: int = 0
var pending_card: int = -1
## 꺼내 든 카드의 손패 번호(hand 의 몇 번째). -1 = 안 꺼냄. 같은 종류가 여러 장이어도 부채의 어느 카드인지 알려 준다.
var pending_slot: int = -1
var card_effects: Dictionary = {}


func score_hit(base_score: float) -> float:
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
		"numbers": layout.numbers, "board_values": layout.to_snapshot(), "bonus": bonus, "multiplier": multiplier, "hand": hand,
		"speed_scale": speed_scale, "pending_card": pending_card, "pending_slot": pending_slot, "card_effects": card_effects,
		"darts": darts, "dart_hits": dart_hits, "punish_hits": punish_hits}


static func from_snapshot(data: Dictionary) -> MatchPlayer:
	var player := MatchPlayer.new()
	player.peer_id = data.peer_id
	player.display_name = data.name
	player.seat = data.seat
	player.score = data.score
	player.is_bot = data.get("bot", false)
	player.layout.numbers.assign(data.numbers)
	if data.has("board_values"): player.layout.apply_snapshot(data.board_values)
	player.bonus = data.bonus
	player.multiplier = data.multiplier
	player.speed_scale = data.get("speed_scale", 1.0)
	player.hand.assign(data.get("hand", []))
	player.pending_card = int(data.get("pending_card", -1))
	player.pending_slot = int(data.get("pending_slot", -1))
	player.card_effects = data.get("card_effects", {})
	player.darts = int(data.get("darts", 0))
	player.dart_hits = int(data.get("dart_hits", 0))
	player.punish_hits = int(data.get("punish_hits", 0))
	return player
