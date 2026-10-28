extends RefCounted
## 카드 행동(사람·봇이 같은 함수를 쓴다): 1~7 꺼내 들기 · 내려놓기 · 쓰기(대상 고르기) · ×0 무효로 막기 · 쓴 카드 표시,
## 그리고 왼손 부채·테이블 카드를 규칙 상태에 맞추기, 봇의 카드 판단(BotBrain) 부르기.
## 규칙 판단(쓸 수 있나, 무엇이 되나)은 전부 rules/round_rules.gd 가 한다. 여기는 그 결과를 화면·소리·부채에 옮긴다.

## 테이블 7칸 카드에 사용 표시(페인트 X·그을림)를 남겼다 → 캡처(round_capture.gd)가 듣는다.
signal card_marked(seat: int, slot: int)
## ×0 무효로 상대가 꺼내 든 카드를 없앴다.
signal nullified(by: int, target: int)
## 지금 던지는 사람에게 "차례 동안" 효과가 걸렸다 → 과녁 소품을 바로 보이게 한다(turn_effects.gd).
signal turn_effect_added(target: int)

const Context = preload("res://game/card_round/flow/round_context.gd")
const SeatMover = preload("res://game/card_round/flow/seat_mover.gd")
const Rules = preload("res://game/card_round/rules/round_rules.gd")
const CardCatalog = preload("res://game/card_round/rules/card_catalog.gd")
const BotBrain = preload("res://game/card_round/rules/bot_brain.gd")
const HandFan = preload("res://game/card_round/cards/hand_fan.gd")

## 자리별 "쓰면 누구에게"(꺼내 들 때 기본값, 사람은 Tab 으로 바꾼다).
var target_choice: Dictionary = {}

var _ctx: Context
var _mover: SeatMover
var _bot_next_think: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _last_pending: Array[int] = [-1, -1, -1, -1]


## 감독(card_round.gd)이 시작할 때 한 번: 함께 쓰는 상자와 자리 이동 부품을 받는다.
func setup(ctx: Context, mover: SeatMover) -> void:
	_ctx = ctx
	_mover = mover


## 숫자 키: 들고 있는 카드와 같은 칸이면 내려놓고, 아니면 그 칸을 꺼내 든다.
func press_slot(seat: int, slot: int) -> void:
	var owner: Rules.Seat = _ctx.rules.seats[seat]
	if owner.pending != null and _ctx.rules.slot_of(seat, owner.pending) == slot:
		lower(seat)
		return
	lift(seat, slot)


## 꺼내 들기 = 대기 상태. 모두가 보고(알림), READY_SECONDS 뒤부터 쓸 수 있다.
func lift(seat: int, slot: int) -> void:
	if not _ctx.cards_open or _ctx.game_over:
		return
	if not _ctx.rules.lift(seat, slot, _ctx.now):
		return
	target_choice[seat] = default_target(seat)
	var card: Rules.Card = _ctx.rules.seats[seat].pending
	if seat != Context.LOCAL_SEAT or _ctx.autoplay:
		var card_name: String = CardCatalog.card(card.type).name
		_ctx.hud.toast("%s 「%s」%s 꺼내 들었다!" % [Context.josa(_ctx.name_of(seat), "이", "가"), card_name, Context.josa(card_name, "을", "를", false)],
			PlayerLook.COLORS[seat].lightened(0.45), 2.0)


## 꺼내 든 카드를 다시 손에 넣는다(허세로 내려놓기도 이것).
func lower(seat: int) -> void:
	_ctx.rules.lower(seat)


## 꺼내 든 카드를 target 에게 쓴다. 못 쓰면 이유를 알리고 false.
func use(seat: int, target: int) -> bool:
	var problem: String = _ctx.rules.use_problem(seat, target, _ctx.now)
	if not problem.is_empty():
		if seat == Context.LOCAL_SEAT and not _ctx.autoplay:
			_ctx.hud.toast(problem, Color("ff9a8a"), 1.6)
		return false
	var result: Dictionary = _ctx.rules.use(seat, target, _ctx.now)
	if result.is_empty():
		return false
	_ctx.stats.used = int(_ctx.stats.used) + 1
	var card: Rules.Card = result.card
	var effect: Rules.Effect = result.effect
	_spend(seat, int(result.slot))
	var data: Dictionary = CardCatalog.card(card.type)
	if result.cancelled != null:
		# ×0 무효: 상대가 꺼내 든 카드도 같이 사라진다(소모).
		var lost: Rules.Card = result.cancelled
		var lost_name: String = CardCatalog.card(lost.type).name
		_ctx.stats.nullified = int(_ctx.stats.nullified) + 1
		_spend(target, int(result.cancelled_slot))
		_ctx.hud.toast("×0 무효! %s의 「%s」%s 사라졌다" % [_ctx.name_of(target), lost_name, Context.josa(lost_name, "이", "가", false)], Color("ff9a8a"))
		nullified.emit(seat, target)
	else:
		var to_text: String = "자신" if target == seat else _ctx.name_of(target)
		_ctx.hud.toast("%s → %s : 「%s」 %s" % [_ctx.name_of(seat), to_text, data.name, effect.label if effect.kind in ["math", "random_math"] else ""],
			PlayerLook.COLORS[seat].lightened(0.45))
	if effect.timing == CardCatalog.Timing.TURN and _ctx.rules.is_turn_of(target):
		turn_effect_added.emit(target)
	_ctx.voice.say(seat, "talk")
	sync_fans()
	return true


## 꺼내 든 카드를 쓸 때 기본 대상: 지금 던지는 사람이 대상이 될 수 있으면 그 사람, 아니면 첫 번째 가능한 사람.
func default_target(seat: int) -> int:
	var card: Rules.Card = _ctx.rules.seats[seat].pending
	if card == null:
		return -1
	var targets: Array[int] = _ctx.rules.valid_targets(seat, card.type)
	if targets.is_empty():
		return -1
	var thrower: int = _ctx.rules.active_seat()
	if targets.has(thrower):
		return thrower
	return targets[0]


## Tab: 내 카드 대상을 다음 사람으로.
func cycle_target() -> void:
	var card: Rules.Card = _ctx.rules.seats[Context.LOCAL_SEAT].pending
	if card == null:
		return
	var targets: Array[int] = _ctx.rules.valid_targets(Context.LOCAL_SEAT, card.type)
	if targets.is_empty():
		return
	var index: int = targets.find(int(target_choice.get(Context.LOCAL_SEAT, -1)))
	target_choice[Context.LOCAL_SEAT] = targets[(index + 1) % targets.size()]


## 왼손 부채를 규칙 상태(테이블 7칸 + 보상 2칸)에 맞춘다. 카드마다 uid 를 붙여 같은 카드는 다시 만들지 않는다.
func sync_fans() -> void:
	for seat in range(Context.SEAT_COUNT):
		for slot in range(Rules.HAND_SLOTS + Rules.RESERVE_SLOTS):
			var card: Rules.Card = _ctx.rules.card_at(seat, slot)
			for fan in fans_of(seat):
				if card == null:
					if fan.has_card(slot):
						fan.remove_card(slot)
				elif not fan.has_card(slot) or int(fan.cards[slot].get_meta("uid", -1)) != card.uid:
					fan.set_card(slot, card.type, card.temporary)
					fan.cards[slot].set_meta("uid", card.uid)


## 이 자리 카드를 보여 주는 부채들(캐릭터 왼손 + 내 자리면 1인칭 부채).
func fans_of(seat: int) -> Array[HandFan]:
	var list: Array[HandFan] = [_ctx.fans[seat]]
	if seat == Context.LOCAL_SEAT:
		list.append(_ctx.local_fan)
	return list


## 매 프레임: 꺼내 든 카드 → 테이블 카드가 떠오르고 손 부채 카드가 위로 빠진다. 사용 가능까지 남은 비율도 보여 준다.
func update_pending() -> void:
	var rules: Rules = _ctx.rules
	for seat in range(Context.SEAT_COUNT):
		var pending: Rules.Card = rules.seats[seat].pending
		var slot: int = rules.slot_of(seat, pending) if pending != null else -1
		var ratio: float = rules.ready_ratio(seat, _ctx.now)
		_ctx.table_cards.set_pending(seat, slot, ratio)
		for fan in fans_of(seat):
			if fan.lifted_slot != slot:
				if slot < 0:
					fan.lower()
				else:
					fan.lift(slot)
			fan.ready_ratio = ratio
		# 카드가 한 장이라도 있으면 왼팔을 들어 부채를 든다(art/characters/character_rig.gd holding_cards).
		var rig: CharacterRig = _ctx.actors[seat].get("_rig")
		if rig != null:
			rig.holding_cards = rules.hand_count(seat) > 0 and _ctx.actors[seat].visible
		if pending != null and _last_pending[seat] != pending.uid and seat == Context.LOCAL_SEAT and not _ctx.autoplay:
			target_choice[seat] = default_target(seat)
		_last_pending[seat] = pending.uid if pending != null else -1
		if pending != null and not rules.valid_targets(seat, pending.type).has(int(target_choice.get(seat, -1))):
			target_choice[seat] = default_target(seat)


## 매 프레임: 봇이 카드를 꺼내 들지·쓸지·내려놓을지(BotBrain). 봇마다 생각하는 간격이 다르다.
func think_bots() -> void:
	if not _ctx.cards_open or _ctx.game_over or _ctx.phase in ["punish", "ending", "results"]:
		return
	for seat in range(Context.SEAT_COUNT):
		if not _ctx.bot_driven(seat) or _ctx.now < _bot_next_think[seat] or _mover.stunned(seat):
			continue
		_bot_next_think[seat] = _ctx.now + BotBrain.think_delay(_ctx.random)
		var decision: Dictionary = BotBrain.decide(_ctx.rules, seat, _ctx.now, _ctx.random, _ctx.phase == "darts")
		if decision.has("lift"):
			lift(seat, int(decision.lift))
		elif decision.has("use"):
			use(seat, int(decision.use))
		elif decision.has("lower"):
			lower(seat)


## 쓴(또는 무효로 사라진) 카드: 손에서 사라지고, 테이블 7칸이면 사용 표시가 남는다. 보상 칸은 그냥 사라진다.
func _spend(seat: int, slot: int) -> void:
	if slot < 0:
		return
	if slot < Rules.HAND_SLOTS:
		_ctx.table_cards.mark_used(seat, slot, _ctx.settings.mark())
		card_marked.emit(seat, slot)
	else:
		_ctx.table_cards.remove(seat, slot)
		_ctx.table_cards.compact_rewards(seat)
