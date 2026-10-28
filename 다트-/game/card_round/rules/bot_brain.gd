extends RefCounted
## 시연용 봇의 카드 판단(상태 없음). 몇 초마다 한 번 "지금 무엇을 할지"만 고른다.
## 심리전을 보여 주려는 값이다: 자기 차례엔 자기 강화 카드를, 남의 차례엔 방해 카드를 꺼내 들고,
## 누가 카드를 꺼내 들면 무효(×0)로 막으려 하고, 가끔은 꺼냈다가 그냥 내려놓는다(허세). 확률은 전부 시연값.

const CardCatalog = preload("res://game/card_round/rules/card_catalog.gd")
const Rules = preload("res://game/card_round/rules/round_rules.gd")

## 다음 판단까지 기다리는 시간(초) 범위.
const THINK_MIN: float = 0.8
const THINK_MAX: float = 2.2


## 결과: {} = 아무것도 안 함 · {"lift": slot} · {"use": target} · {"lower": true}
static func decide(rules: Rules, seat: int, now: float, random: RandomNumberGenerator, darts_phase: bool) -> Dictionary:
	var me: Rules.Seat = rules.seats[seat]
	var my_turn: bool = darts_phase and rules.is_turn_of(seat)
	var thrower: int = rules.active_seat() if darts_phase else -1
	if me.pending != null:
		if not rules.is_ready(seat, now):
			return {}
		var type: int = me.pending.type
		var targets: Array[int] = rules.valid_targets(seat, type)
		match int(CardCatalog.card(type).target):
			CardCatalog.Target.SELF:
				if my_turn and random.randf() < 0.8:
					return {"use": seat}
			CardCatalog.Target.OPPONENT:
				if thrower >= 0 and thrower != seat and random.randf() < 0.7:
					return {"use": thrower}
				if not darts_phase and random.randf() < 0.25 and not targets.is_empty():
					return {"use": targets[random.randi_range(0, targets.size() - 1)]}
			CardCatalog.Target.COUNTER:
				if not targets.is_empty() and random.randf() < 0.85:
					return {"use": targets[random.randi_range(0, targets.size() - 1)]}
		return {"lower": true} if random.randf() < 0.18 else {}
	var someone_lifted: bool = false
	for other in rules.order:
		someone_lifted = someone_lifted or (other != seat and rules.seats[other].pending != null)
	var wanted: int = -1
	if someone_lifted and random.randf() < 0.5:
		wanted = CardCatalog.Target.COUNTER
	elif my_turn and random.randf() < 0.55:
		wanted = CardCatalog.Target.SELF
	elif thrower >= 0 and thrower != seat and random.randf() < 0.3:
		wanted = CardCatalog.Target.OPPONENT
	elif random.randf() < 0.06:
		wanted = CardCatalog.Target.OPPONENT
	if wanted < 0:
		return {}
	var choices: Array[int] = []
	for slot in range(Rules.HAND_SLOTS + me.reward.size()):
		var card: Rules.Card = rules.card_at(seat, slot)
		if card != null and int(CardCatalog.card(card.type).target) == wanted:
			choices.append(slot)
	if choices.is_empty():
		return {}
	return {"lift": choices[random.randi_range(0, choices.size() - 1)]}


## 봇이 카드를 다시 생각하기까지 기다리는 시간(초, 무작위).
static func think_delay(random: RandomNumberGenerator) -> float:
	return random.randf_range(THINK_MIN, THINK_MAX)
