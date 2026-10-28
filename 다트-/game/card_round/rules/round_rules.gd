extends RefCounted
## 카드 라운드 시연의 규칙 계산. 노드·화면·입력과 무관한 순수 계산이라 tests/test_card_round.gd 가 직접 검사한다.
## 실제 경기(MatchController)로 옮길 때는 방장이 이 계산을 돌리고 결과만 스냅샷으로 나눠 주면 된다.
##
## 사용자 확정(2026-10-25·10-28): 손패 7장 = 테이블 7칸과 왼손이 같은 카드. 버리기·바꾸기 없음.
## 라운드가 끝나면 쓴 만큼만 7장까지 다시 받는다(안 썼으면 0장). 쓴 카드는 소멸하고 테이블에 사용 표시가 남는다.
## 시연값(미확정): 대기 시간, 카드 효과 수치, 방해 보상, 승리 조건 수치, 골드, 순서(자리 순).

const CardCatalog = preload("res://game/card_round/rules/card_catalog.gd")

enum WinMode { TARGET_SCORE, ROUND_LIMIT, COUNTDOWN }
enum DrawFrom { TOP, MIDDLE, BOTTOM, RANDOM }
enum RewardMode { SCORE, ROUND_CARD, RANDOM }
## 효과 상태: 대기(차례·다트를 기다림) / 적용 중 / 끝남 / 무효로 막힘 / 라운드 끝 만료.
enum EffectState { QUEUED, ACTIVE, DONE, NULLIFIED, EXPIRED }

const HAND_SLOTS: int = CardHandRules.HAND_LIMIT
## 방해 성공 보상 카드가 들어가는 테이블 예약 칸 수(펍 자리 매트의 예약 2칸).
const RESERVE_SLOTS: int = 2
const DARTS_PER_TURN: int = 3
## 카드를 꺼내 든 뒤 쓸 수 있을 때까지 기다리는 시간(초). 이 사이에 다른 사람이 보고 무효(×0)로 막을 수 있다. 시연값.
const READY_SECONDS: float = 1.2
const DECK_SIZE: int = 40
const DISRUPT_SCORE: int = 15
const COUNTDOWN_START: int = 500
## 순위별 골드(1~4위)와 방해 성공 1회당 골드. 시연값.
const GOLD_BY_RANK: Array[int] = [100, 60, 40, 20]
const GOLD_PER_DISRUPT: int = 10


class Card:
	var uid: int
	var type: int
	## 방해 성공 보상으로 받은 "이번 라운드 한정" 카드. 라운드가 끝나면 사라진다.
	var temporary: bool = false


class Effect:
	var uid: int
	var card_type: int
	var source: int
	var target: int
	var label: String
	var kind: String
	var timing: int
	var add: int = 0
	var mul: float = 1.0
	var state: int = EffectState.QUEUED
	## 결과 한 줄(예: "60 → 130", "숫자 섞기 무효").
	var result: String = ""


class Seat:
	var index: int
	var name: String
	var is_bot: bool
	var score: int = 0
	## 테이블 7칸 = 왼손 7장. 빈 칸은 null(쓴 카드 자리).
	var slots: Array[Card] = []
	var reward: Array[Card] = []
	## 위로 꺼내 든(사용 전 대기) 카드. 없으면 null.
	var pending: Card = null
	var pending_since: float = 0.0
	var disrupts: int = 0
	var gold: int = 0


var seats: Array[Seat] = []
## 0 = 맨 아래, 마지막 = 맨 위.
var deck: Array[Card] = []
## 차례 순서(자리 번호). 정하는 방법은 미정 → 지금은 자리 순.
var order: Array[int] = []
var effects: Array[Effect] = []
var round_number: int = 1
var turn_position: int = -1
var darts_left: int = 0
var win_mode: WinMode = WinMode.ROUND_LIMIT
var target_score: int = 300
var round_limit: int = 7
var reward_mode: RewardMode = RewardMode.SCORE
var finished: bool = false
var winners: Array[int] = []
var random := RandomNumberGenerator.new()
var _next_uid: int = 0
var _turn_start_score: int = 0


func _init(names: Array[String], bots: Array[bool], mode: WinMode = WinMode.ROUND_LIMIT, seed_value: int = 0) -> void:
	win_mode = mode
	if seed_value != 0:
		random.seed = seed_value
	for index in range(names.size()):
		var seat := Seat.new()
		seat.index = index
		seat.name = names[index]
		seat.is_bot = bots[index]
		seat.score = COUNTDOWN_START if mode == WinMode.COUNTDOWN else 0
		for slot in range(HAND_SLOTS):
			seat.slots.append(null)
		seats.append(seat)
		order.append(index)


## 새 카드 한 장(번호 붙이기). temporary = 라운드 한정 카드(라운드가 끝나면 사라진다).
func new_card(type: int, temporary: bool = false) -> Card:
	_next_uid += 1
	var card := Card.new()
	card.uid = _next_uid
	card.type = type
	card.temporary = temporary
	return card


## 덱을 size 장까지 새 카드로 채운다(쓴 카드는 소멸하므로 덱은 늘 새 카드로 보충한다).
func fill_deck(size: int = DECK_SIZE) -> int:
	var added: int = 0
	while deck.size() < size:
		deck.append(new_card(CardCatalog.random_type(random)))
		added += 1
	return added


## 덱 순서를 무작위로 섞는다(규칙상 섞기. 화면 연출은 table_cards.shuffle).
func shuffle_deck() -> void:
	for index in range(deck.size() - 1, 0, -1):
		var other: int = random.randi_range(0, index)
		var card: Card = deck[index]
		deck[index] = deck[other]
		deck[other] = card


## 덱에서 뽑을 위치. 위 = 마지막 칸, 아래 = 0번 칸.
func draw_index(from: DrawFrom) -> int:
	if deck.is_empty():
		return -1
	match from:
		DrawFrom.TOP: return deck.size() - 1
		DrawFrom.MIDDLE: return deck.size() / 2
		DrawFrom.BOTTOM: return 0
	return random.randi_range(0, deck.size() - 1)


## 이번 한 장을 덱 어디서 뽑을지: 위·가운데·아래(밑장) 중 하나를 같은 확률로(시연값).
## 2026-10-28 사용자 피드백: "뽑는 곳" 설정을 없애고 한 장마다 무작위로 → 받는 사람이 밑장 빼기·중간 빼기를 보는 재미.
## DrawFrom 의 앞 세 값(TOP 0 · MIDDLE 1 · BOTTOM 2) 순서에 기대므로 enum 순서를 바꾸면 같이 고친다.
func random_draw_from() -> DrawFrom:
	return random.randi_range(0, 2) as DrawFrom


## 덱의 index 번째 카드를 뽑아 돌려준다.
func take_from_deck(index: int) -> Card:
	var card: Card = deck[index]
	deck.remove_at(index)
	return card


## 자리 seat 의 테이블 7칸 중 빈 칸 번호들(충전 라운드에 채울 칸).
func empty_slots(seat: int) -> Array[int]:
	var empty: Array[int] = []
	for slot in range(HAND_SLOTS):
		if seats[seat].slots[slot] == null:
			empty.append(slot)
	return empty


## 나눠 줄 순서: 차례 순서대로 한 사람에 한 장씩 돌고, 다시 처음부터 한 바퀴씩. 빈 칸이 없는 사람은 건너뛴다.
## 결과 Vector2i(x = 자리, y = 칸).
func deal_plan() -> Array[Vector2i]:
	var plan: Array[Vector2i] = []
	var empties: Array = []
	for seat in order:
		empties.append(empty_slots(seat))
	for lap in range(HAND_SLOTS):
		for position in range(order.size()):
			var slots: Array[int] = empties[position]
			if lap < slots.size():
				plan.append(Vector2i(order[position], slots[lap]))
	return plan


## 자리 seat 의 slot 칸에 카드를 놓는다(이미 카드가 있으면 오류).
func place(seat: int, slot: int, card: Card) -> void:
	assert(seats[seat].slots[slot] == null, "이미 카드가 있는 칸입니다.")
	seats[seat].slots[slot] = card


## 자리 seat 가 가진 카드 수(7칸 + 보상 카드).
func hand_count(seat: int) -> int:
	return HAND_SLOTS - empty_slots(seat).size() + seats[seat].reward.size()


## 손에 든 카드의 칸 번호(테이블과 같은 번호). 보상 카드는 HAND_SLOTS + 예약 칸 번호.
func slot_of(seat: int, card: Card) -> int:
	var index: int = seats[seat].slots.find(card)
	if index >= 0:
		return index
	index = seats[seat].reward.find(card)
	return HAND_SLOTS + index if index >= 0 else -1


## 자리 seat 의 slot 칸 카드. 7 이상은 보상 카드 칸(없으면 null).
func card_at(seat: int, slot: int) -> Card:
	if slot < HAND_SLOTS:
		return seats[seat].slots[slot]
	var reward_index: int = slot - HAND_SLOTS
	return seats[seat].reward[reward_index] if reward_index < seats[seat].reward.size() else null


# --- 꺼내기(대기)·사용 ---

## 카드를 위로 꺼내 든다. 한 번에 한 장만. 다른 카드를 꺼내면 앞 카드는 내려간다.
func lift(seat: int, slot: int, now: float) -> bool:
	var card: Card = card_at(seat, slot)
	if card == null or finished:
		return false
	seats[seat].pending = card
	seats[seat].pending_since = now
	return true


## 꺼내 든 카드를 손으로 내린다(카드는 그대로 남는다).
func lower(seat: int) -> void:
	seats[seat].pending = null


## 꺼내 든 카드가 준비 시간(READY_SECONDS)을 다 기다렸는가 — 기다려야 쓸 수 있다.
func is_ready(seat: int, now: float) -> bool:
	return seats[seat].pending != null and now - seats[seat].pending_since >= READY_SECONDS


## 준비 막대 진행도 0~1(꺼내 든 카드가 없으면 0).
func ready_ratio(seat: int, now: float) -> float:
	if seats[seat].pending == null:
		return 0.0
	return clampf((now - seats[seat].pending_since) / READY_SECONDS, 0.0, 1.0)


## 이 카드를 쓸 수 있는 대상 자리들(나 / 상대 / 카드를 꺼내 든 상대).
func valid_targets(seat: int, type: int) -> Array[int]:
	var targets: Array[int] = []
	match int(CardCatalog.card(type).target):
		CardCatalog.Target.SELF:
			targets.append(seat)
		CardCatalog.Target.OPPONENT:
			for other in order:
				if other != seat:
					targets.append(other)
		CardCatalog.Target.COUNTER:
			for other in order:
				if other != seat and seats[other].pending != null:
					targets.append(other)
	return targets


## 꺼내 든 카드를 쓸 수 없는 이유. 쓸 수 있으면 빈 글자.
func use_problem(seat: int, target: int, now: float) -> String:
	var card: Card = seats[seat].pending
	if finished:
		return "경기가 끝났다"
	if card == null:
		return "먼저 Q·E(또는 1~7)로 카드를 꺼내 든다"
	if not is_ready(seat, now):
		return "꺼내 든 뒤 %.1f초 기다려야 한다" % READY_SECONDS
	if not valid_targets(seat, card.type).has(target):
		return "카드를 꺼내 든 상대가 없다" if int(CardCatalog.card(card.type).target) == CardCatalog.Target.COUNTER else "대상이 맞지 않는다"
	return ""


## 꺼내 든 카드를 쓴다. 카드는 손·테이블에서 사라지고(테이블에는 사용 표시), 효과가 기록된다.
## 결과: {card, slot, effect, cancelled(무효로 사라진 상대 카드 또는 null), cancelled_slot}
func use(seat: int, target: int, now: float) -> Dictionary:
	if not use_problem(seat, target, now).is_empty():
		return {}
	var card: Card = seats[seat].pending
	var slot: int = slot_of(seat, card)
	_remove_card(seat, card)
	var data: Dictionary = CardCatalog.card(card.type)
	var effect := Effect.new()
	_next_uid += 1
	effect.uid = _next_uid
	effect.card_type = card.type
	effect.source = seat
	effect.target = target
	effect.kind = data.effect
	effect.timing = int(data.timing)
	effect.label = str(data.get("big", data.name)) if data.effect in ["math", "nullify"] else str(data.name)
	effect.add = int(data.get("add", 0))
	effect.mul = float(data.get("mul", 1.0))
	var result := {"card": card, "slot": slot, "effect": effect, "cancelled": null, "cancelled_slot": -1}
	if effect.kind == "random_math":
		var roll: Dictionary = CardCatalog.RANDOM_MATH[random.randi_range(0, CardCatalog.RANDOM_MATH.size() - 1)]
		effect.label = "랜덤 %s" % roll.label
		effect.add = int(roll.add)
		effect.mul = float(roll.mul)
	if effect.kind == "nullify":
		var victim: Card = seats[target].pending
		result.cancelled = victim
		result.cancelled_slot = slot_of(target, victim)
		_remove_card(target, victim)
		effect.state = EffectState.DONE
		effect.result = "「%s」 막음" % CardCatalog.card(victim.type).name
		_nullify_from(target, victim.type, effect)
	elif effect.timing == CardCatalog.Timing.TURN and is_turn_of(target):
		effect.state = EffectState.ACTIVE
	effects.append(effect)
	return result


## 무효로 사라진 카드도 로그에 남긴다(효과 패널에서 줄을 그어 보여 준다).
func _nullify_from(seat: int, type: int, by: Effect) -> void:
	var lost := Effect.new()
	_next_uid += 1
	lost.uid = _next_uid
	lost.card_type = type
	lost.source = seat
	lost.target = seat
	lost.kind = "lost"
	lost.timing = CardCatalog.Timing.NEXT_DART
	lost.label = CardCatalog.card(type).name
	lost.state = EffectState.NULLIFIED
	lost.result = "%s의 ×0에 막힘" % seats[by.source].name
	effects.append(lost)


## 자리 seat 에서 카드를 뺀다(7칸이면 칸을 비우고, 보상 카드면 목록에서 지운다).
func _remove_card(seat: int, card: Card) -> void:
	var owner: Seat = seats[seat]
	var index: int = owner.slots.find(card)
	if index >= 0:
		owner.slots[index] = null
	else:
		owner.reward.erase(card)
	if owner.pending == card:
		owner.pending = null


# --- 차례·다트 ---

## 지금 던지는 사람의 자리(다트 단계가 아니면 -1).
func active_seat() -> int:
	return order[turn_position] if turn_position >= 0 and turn_position < order.size() else -1


## 지금 자리 seat 가 던질 차례이고 다트가 남았는가.
func is_turn_of(seat: int) -> bool:
	return active_seat() == seat and darts_left > 0


## 차례 시작: 이 사람을 노린 "차례 동안" 효과가 켜진다.
func begin_turn(position: int) -> void:
	turn_position = position
	darts_left = DARTS_PER_TURN
	var seat: int = active_seat()
	_turn_start_score = seats[seat].score
	for effect in effects:
		if effect.target == seat and effect.state == EffectState.QUEUED and effect.timing == CardCatalog.Timing.TURN:
			effect.state = EffectState.ACTIVE


## 이 사람의 다음 다트에 걸린 조준·연출 효과(점수 연산은 resolve_dart).
func dart_modifiers(seat: int) -> Dictionary:
	var mods := {"drop": 0.0, "push": 0.0, "power": false, "triple": false, "shuffle": false, "cover": false, "drowsy": false}
	for effect in effects:
		if effect.target != seat:
			continue
		var turn_effect: bool = effect.timing == CardCatalog.Timing.TURN and effect.state == EffectState.ACTIVE
		var dart_effect: bool = effect.timing == CardCatalog.Timing.NEXT_DART and effect.state == EffectState.QUEUED
		if not (turn_effect or dart_effect):
			continue
		var data: Dictionary = CardCatalog.card(effect.card_type)
		match effect.kind:
			"heavy": mods.drop = float(mods.drop) + float(data.drop)
			"wind": mods.push = float(mods.push) + float(data.push)
			"power", "triple", "shuffle", "cover", "drowsy": mods[effect.kind] = true
	return mods


## 다트 한 발의 점수. 기본 점수에 "다음 다트" 연산을 곱하기 먼저, 더하기 나중으로 건다. 빗나가면(0점) 연산은 써 버린다.
## 결과: {points, formula}
func resolve_dart(seat: int, base: int) -> Dictionary:
	var multiplier: float = 1.0
	var bonus: int = 0
	var parts := PackedStringArray([str(base)])
	for effect in effects:
		if effect.target != seat or effect.state != EffectState.QUEUED or effect.timing != CardCatalog.Timing.NEXT_DART:
			continue
		if effect.kind in ["math", "random_math"]:
			multiplier *= effect.mul
			bonus += effect.add
			parts.append(effect.label.trim_prefix("랜덤 "))
		effect.state = EffectState.DONE
	var points: int = 0
	if base > 0:
		points = maxi(0, roundi(base * multiplier) + bonus)
	for effect in effects:
		if effect.target == seat and effect.state == EffectState.DONE and effect.result.is_empty():
			effect.result = "%d점" % points if effect.kind in ["math", "random_math"] else "적용"
	var formula: String = " ".join(parts) + (" = %d" % points if parts.size() > 1 else "")
	return {"points": points, "formula": formula}


## 점수 반영. 500→0 모드는 빼고, 0 아래로 내려가면 이번 차례 점수를 되돌린다(버스트).
## 결과: {bust, win}
func apply_points(seat: int, points: int) -> Dictionary:
	darts_left = maxi(0, darts_left - 1)
	var owner: Seat = seats[seat]
	if win_mode == WinMode.COUNTDOWN:
		var remaining: int = owner.score - points
		if remaining < 0:
			owner.score = _turn_start_score
			darts_left = 0
			return {"bust": true, "win": false}
		owner.score = remaining
		if remaining == 0:
			_finish([seat])
			return {"bust": false, "win": true}
		return {"bust": false, "win": false}
	owner.score += points
	if win_mode == WinMode.TARGET_SCORE and owner.score >= target_score:
		_finish([seat])
		return {"bust": false, "win": true}
	return {"bust": false, "win": false}


## 차례 끝: 이 사람의 "차례 동안" 효과가 끝난다.
func end_turn() -> void:
	var seat: int = active_seat()
	darts_left = 0
	for effect in effects:
		if effect.target == seat and effect.state == EffectState.ACTIVE:
			effect.state = EffectState.DONE
			if effect.result.is_empty():
				effect.result = "차례 끝"


## 라운드 끝: 남은 효과는 만료, 라운드 한정 카드는 사라진다. 사라진 카드를 돌려준다(화면에서 지우려고).
func end_round() -> Array[Card]:
	var vanished: Array[Card] = []
	for effect in effects:
		if effect.state in [EffectState.QUEUED, EffectState.ACTIVE]:
			effect.state = EffectState.EXPIRED
			effect.result = "라운드 끝 만료"
	for seat in seats:
		for card in seat.reward:
			vanished.append(card)
			if seat.pending == card:
				seat.pending = null
		seat.reward.clear()
	turn_position = -1
	darts_left = 0
	if win_mode == WinMode.ROUND_LIMIT and round_number >= round_limit and not finished:
		_finish(_best_seats())
	return vanished


## 다음 라운드로. 지난 라운드 효과 기록은 지운다(효과 패널은 라운드마다 새로 시작).
func next_round() -> void:
	round_number += 1
	effects.clear()


# --- 방해 성공(몸으로 다트를 막음) ---

## 맞은 사람(victim)이 방해에 성공했다 → 보상. 점수 또는 이번 라운드 한정 카드.
## 결과: {kind: "score"|"card", amount, card}
func disrupt(victim: int) -> Dictionary:
	var owner: Seat = seats[victim]
	owner.disrupts += 1
	var mode: RewardMode = reward_mode
	if mode == RewardMode.RANDOM:
		mode = RewardMode.SCORE if random.randf() < 0.5 else RewardMode.ROUND_CARD
	# 500→0 모드에서 점수 보상은 남은 점수를 줄이는 쪽이라 0 을 넘기면 카드로 바꾼다.
	var score_ok: bool = win_mode != WinMode.COUNTDOWN or owner.score - DISRUPT_SCORE > 0
	if mode == RewardMode.ROUND_CARD and owner.reward.size() < RESERVE_SLOTS or not score_ok:
		if owner.reward.size() < RESERVE_SLOTS:
			var card: Card = new_card(CardCatalog.random_type(random), true)
			owner.reward.append(card)
			return {"kind": "card", "amount": 0, "card": card}
	if not score_ok:
		return {"kind": "none", "amount": 0, "card": null}
	owner.score += -DISRUPT_SCORE if win_mode == WinMode.COUNTDOWN else DISRUPT_SCORE
	return {"kind": "score", "amount": DISRUPT_SCORE, "card": null}


# --- 종료·순위·골드 ---

## 좋은 순서(1등 먼저). 500→0 모드는 남은 점수가 적을수록 좋다. 동점은 자리 순.
func ranking() -> Array[int]:
	var ranked: Array[int] = order.duplicate()
	var countdown: bool = win_mode == WinMode.COUNTDOWN
	ranked.sort_custom(func(a: int, b: int) -> bool:
		if seats[a].score == seats[b].score:
			return a < b
		return seats[a].score < seats[b].score if countdown else seats[a].score > seats[b].score)
	return ranked


## 같은 점수는 같은 순위(0 = 1위).
func rank_of(seat: int) -> int:
	var better: int = 0
	for other in order:
		if win_mode == WinMode.COUNTDOWN:
			better += 1 if seats[other].score < seats[seat].score else 0
		else:
			better += 1 if seats[other].score > seats[seat].score else 0
	return better


## 벌칙(돌아가는 과녁) 대상 = 꼴찌. 꼴찌가 여럿이면 순서상 뒤쪽.
func loser() -> int:
	var ranked: Array[int] = ranking()
	return ranked[ranked.size() - 1]


## 경기 끝 골드 = 순위 골드(GOLD_BY_RANK) + 방해 성공 횟수 × GOLD_PER_DISRUPT. 쓰임새(옷·아바타·닉네임)는 아직 없다.
func award_gold() -> void:
	for seat in seats:
		seat.gold = GOLD_BY_RANK[mini(rank_of(seat.index), GOLD_BY_RANK.size() - 1)] + seat.disrupts * GOLD_PER_DISRUPT


## 화면에 쓰는 승리 조건 한 줄(점수판 제목·결과 화면). 규칙 값에서 바로 만들어 글과 규칙이 어긋나지 않게 한다.
func win_text() -> String:
	match win_mode:
		WinMode.TARGET_SCORE:
			return "승리 조건: %d점 먼저" % target_score
		WinMode.COUNTDOWN:
			return "승리 조건: %d → 0 딱 맞추기" % COUNTDOWN_START
	return "승리 조건: %d라운드 최고점" % round_limit


## 지금 1위(동점이면 여럿).
func _best_seats() -> Array[int]:
	var best: Array[int] = []
	for seat in order:
		if rank_of(seat) == 0:
			best.append(seat)
	return best


## 경기를 끝내고 우승자를 정한다.
func _finish(seat_list: Array[int]) -> void:
	finished = true
	winners = seat_list
