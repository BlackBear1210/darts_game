extends RefCounted
## 몸으로 막기(방해) — 기획 중인 부분(2026-10-28).
## 1) 남의 차례에 봇이 막으러 나갈지 정한다(DISRUPT_CHANCE). 나간 사람은 방해선 너머(과녁 쪽)에서 던지는 사람을 따라 옆으로 움직이고
##    (seat_mover.gd · throw_zone.gd), 던지는 사람이 조준하면 점프로 막으려 할 수도 있다(JUMP_CHANCE).
## 2) 다트가 사람 몸에 맞으면:
##    맞은 사람 = 스턴 별 + 옆으로 튕김 + (다트 라운드면) 방해 성공 보상(점수 또는 라운드 한정 카드, 설정 "방해 보상")
##    던진 사람 = 자기 차례가 끝날 때까지 취기·마우스·난시 중 하나 + 목소리 변조(turn_effects.gd)

## 몸 맞음 처리가 끝났다 → 머리 위 글자 갱신·캡처가 듣는다.
signal hit_resolved(thrower: int, victim: int)

const Context = preload("res://game/card_round/flow/round_context.gd")
const SeatMover = preload("res://game/card_round/flow/seat_mover.gd")
const CardActions = preload("res://game/card_round/flow/card_actions.gd")
const TurnEffects = preload("res://game/card_round/flow/turn_effects.gd")
const Rules = preload("res://game/card_round/rules/round_rules.gd")
const CardCatalog = preload("res://game/card_round/rules/card_catalog.gd")
const StunStars = preload("res://game/card_round/fx/stun_stars.gd")

## 봇이 남의 차례에 몸으로 막으러 나갈 확률(시연값). 높이면 몸 맞기가 잦아진다.
const DISRUPT_CHANCE: float = 0.3
## 맞은 사람이 못 움직이는 시간(시연값).
const STUN_SECONDS: float = 3.0
## 막는 봇이 조준을 보고 점프할 확률(시연값). 방해선 거리에서는 서 있으면 다트가 대부분 머리 위로 지나간다.
const JUMP_CHANCE: float = 0.5

var _ctx: Context
var _mover: SeatMover
var _cards: CardActions
var _effects: TurnEffects
var _local_charging: bool = false


## 감독이 시작할 때 한 번: 자리 이동·카드 행동·차례 효과 부품을 받는다.
func setup(ctx: Context, mover: SeatMover, cards: CardActions, effects: TurnEffects) -> void:
	_ctx = ctx
	_mover = mover
	_cards = cards
	_effects = effects


## thrower 의 차례 시작: 봇 한 명이 몸으로 막으러 나갈 수도 있다(한 차례에 최대 한 명).
func plan(thrower: int) -> void:
	for seat in _ctx.rules.order:
		if seat == thrower or not _ctx.bot_driven(seat) or _mover.stunned(seat):
			continue
		if _ctx.random.randf() < DISRUPT_CHANCE:
			_mover.stand(seat)
			_mover.walk_to(seat, _mover.block_spot(thrower), _ctx.actors[thrower].global_position, thrower)
			_ctx.hud.toast("%s 몸으로 막으러 나간다!" % Context.josa(_ctx.name_of(seat), "이", "가"), PlayerLook.COLORS[seat].lightened(0.45))
			return


## 던지는 사람이 곧 던진다 → 그 앞에서 막고 있는 봇은 JUMP_CHANCE 로 earliest~latest 초 뒤에 점프한다.
func jump_blockers(thrower: int, earliest: float, latest: float) -> void:
	for seat in range(Context.SEAT_COUNT):
		if _ctx.bot_driven(seat) and _mover.is_following(seat, thrower) and _mover.arrived(seat) and _ctx.random.randf() < JUMP_CHANCE:
			_mover.jump_after(seat, _ctx.random.randf_range(earliest, latest))


## 매 프레임: 내가 던지려고 충전을 시작한 순간(왼클릭 누름) → 막는 봇이 점프할 수도 있다(놓기까지 0.8초 안팎).
func watch_local_charge(charging: bool) -> void:
	if charging and not _local_charging:
		jump_blockers(Context.LOCAL_SEAT, 0.2, 0.9)
	_local_charging = charging


## 다트가 사람 몸에 맞았다(dart_actions.gd body_hit 신호).
func on_body_hit(thrower: int, victim: int) -> void:
	_ctx.stats.body_hits = int(_ctx.stats.body_hits) + 1
	_mover.knock_aside(thrower, victim)
	var stars := StunStars.new()
	stars.seconds = STUN_SECONDS
	_ctx.actors[victim].add_child(stars)
	_mover.stun(victim, STUN_SECONDS)
	_ctx.voice.say(victim, "ouch")
	# 막으러 나왔던 사람은 한 번 맞으면(방해 성공) 스턴이 풀린 뒤 자리로 돌아간다.
	if _mover.is_following(victim, thrower):
		_mover.send_home(victim)
	if _ctx.phase == "darts":
		_give_reward(victim)
	if thrower != victim:
		var penalty: String = _effects.penalize(thrower)
		_ctx.hud.toast("%s: 사람을 맞힌 벌 — 차례가 끝날 때까지 %s + 목소리 변조" % [_ctx.name_of(thrower), penalty], Color("c9a6ff"))
	hit_resolved.emit(thrower, victim)


## 방해 성공 보상(규칙: rules.disrupt). 점수면 바로 더하고(500→0 모드는 빼고), 카드면 테이블 예약 칸과 손 부채 끝에 금빛 카드.
func _give_reward(victim: int) -> void:
	var reward: Dictionary = _ctx.rules.disrupt(victim)
	match str(reward.kind):
		"score":
			var sign: String = "−" if _ctx.rules.win_mode == Rules.WinMode.COUNTDOWN else "+"
			_ctx.hud.toast("방해 성공! %s %s%d점" % [_ctx.name_of(victim), sign, int(reward.amount)], PubTheme.GOLD)
		"card":
			var card: Rules.Card = reward.card
			_ctx.table_cards.give_reward(victim, _ctx.rules.seats[victim].reward.size() - 1, card.type)
			_cards.sync_fans()
			_ctx.hud.toast("방해 성공! %s에게 라운드 한정 카드 「%s」" % [_ctx.name_of(victim), CardCatalog.card(card.type).name], PubTheme.GOLD)
		_:
			_ctx.hud.toast("방해 성공! (보상 없음: 남은 점수가 모자란다)", PubTheme.GOLD)
