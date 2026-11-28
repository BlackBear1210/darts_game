extends RefCounted
## 기존 카드 시연의 순수 규칙을 방장 경기로 연결한다. 카드 효과 계산은 RoundRules 한 곳에 둔다.
## 2026-10-31 사용자 결정: 카드 턴은 없다. 라운드 시작에 7장을 채우고 VIEW_SECONDS 동안 확인한 뒤 바로 다트.
## 다트 턴(조준·비행) 동안 누구나 어떤 카드든 쓰고, 효과는 누가 쓰든 지금 던지는 사람에게 바로 걸린다.
## 예외: 무효(×0)는 카드를 꺼내 들었거나 방금 쓴 사람, 카드 사용자(CASTER)는 나, PICK 카드는 Tab 으로 고른 사람.
## 2026-11-21: 꺼낸 뒤 기다리기(Rules.READY_SECONDS)를 없앴다 — 고르면 바로 쓴다.
## 쓰는 순간 끝나는 카드(차례 바꾸기·속박 등)와 카드별 사용 조건은 match_card_actions.gd 한 곳이다.
const Rules = preload("res://game/card_round/rules/round_rules.gd")
const Catalog = preload("res://game/card_round/rules/card_catalog.gd")
## 카드를 나눠 준 뒤 받은 카드를 확인하는 시간(초). 이 동안에는 카드를 쓰지 않는다.
const VIEW_SECONDS: float = 5.0
## 날아가는 다트에 쓰면 꽂히는 자리가 바뀌는 효과(궤적 카드).
const FLIGHT_KINDS: Array[String] = ["heavy", "wind", "power", "triple", "drowsy", "large", "pierce", "rubber", "repeat_spot", "cover", "board_zoom", "spin", "split", "vertical", "horizontal", "move"]
## 봇 카드(2026-10-31 사용자 요청): 다트 턴마다 봇마다 이 확률로 한 장을 쓴다. 시연값.
## 효과는 늘 던지는 사람에게 걸리므로 자기 차례면 나에게 거는 카드(×2·+10 등), 남의 차례면 방해 카드를 고른다.
## 자기 차례에 남이 카드를 꺼내 들면 가진 무효(×0)로 막는다.
const BOT_USE_CHANCE: float = 0.6
## 차례가 시작되고 봇이 카드를 꺼내기까지의 시간 범위(초). 시연값.
const BOT_THINK_SECONDS := Vector2(1.0, 6.0)
## 아수라장 다트 머신 효과(2026-11-07): 과녁 모양을 바꾸는 카드. 시작 시각을 재서 회전각·벌어짐을 시간으로 계산한다.
const BoardChaos = preload("res://game/board/board_chaos.gd")
const CHAOS_KINDS: Array[String] = ["spin", "split", "cover", "vertical", "horizontal", "move"]
## 추가로 써도 강도가 늘지 않는 효과만 차단한다. 숫자 섞기는 다시 섞는 의미가 있다.
const NON_STACKING_KINDS: Array[String] = ["power", "triple", "cover", "drowsy", "spin", "split", "vertical", "horizontal", "move", "large", "dizzy", "reverse", "body_reward"]
var controller: MatchController
var rules: RefCounted
var peers: Array[int] = []
## 봇 peer ID → 이번 다트 턴에 카드를 꺼낼 시각(-1 = 이번 차례엔 안 씀).
var _bot_plans: Dictionary = {}
var _random := RandomNumberGenerator.new()
## 이번 차례에 켜진 머신 효과의 시작 시각(방장 시계): "spin"·"split"·"cover" → 초. 차례가 바뀌면 비운다.
var _chaos_from: Dictionary = {}
## 회전 방향(+1 = 앞에서 볼 때 반시계). 카드를 쓸 때마다 번갈아 정해 같은 방향만 외우지 못하게 한다.
var _spin_direction: float = 1.0
var _cover_side: int = -1
var _seams := Vector2i.ONE
var _move_direction := Vector2.RIGHT
var _round_overrides: Dictionary = {}
## 이번 라운드에 쓴 카드 한 장의 상태(card_effects["used_cards"] 의 Vector2i.y, 2026-11-28 HUD A 보완안).
## LIVE = 아직 걸려 있음 · SPENT = 끝남 · NULLIFIED = 무효(×0)에 막힘.
enum UsedCard { LIVE, SPENT, NULLIFIED }
## 쓰는 순간 끝나는 카드·사용 조건(2026-11-21).
const Actions = preload("res://game/match/match_card_actions.gd")
var actions: RefCounted
## 지뢰 심기 카드가 심은 숫자 구역(0~19, 경기 끝까지 남는다 — 라운드가 바뀌어도 지우지 않는다). 아무에게도 공개하지 않는다.
## 같은 칸이 여러 번 들어갈 수 있다(겹쳐 심기) — 그 칸을 맞히면 겹친 수만큼 벌점이 곱해진다.
var mines: Array[int] = []
## 이번 라운드에 마지막으로 과녁에 꽂힌 자리(과녁 정규화 좌표, 좌표 고정 카드). 없으면 INF.
var last_landing := Vector2.INF

## F5 경기 규칙: 무효(×0) 말고는 누가 쓰든 대상이 지금 던지는 사람 하나다. 효과 계산은 RoundRules 그대로 쓴다.
class MatchRules extends "res://game/card_round/rules/round_rules.gd":
	func valid_targets(seat: int, type: int) -> Array[int]:
		if int(CardCatalog.card(type).target) == CardCatalog.Target.CASTER:
			return [seat]
		if int(CardCatalog.card(type).target) in [CardCatalog.Target.COUNTER, CardCatalog.Target.PICK]:
			return super(seat, type)
		var targets: Array[int] = []
		if active_seat() >= 0: targets.append(active_seat())
		return targets

func _init(owner: MatchController) -> void:
	controller = owner
	_random.randomize()
	actions = Actions.new(self)
	var names: Array[String] = []
	var bots: Array[bool] = []
	for player in owner.state.players:
		peers.append(player.peer_id)
		names.append(player.display_name)
		bots.append(player.is_bot)
	rules = MatchRules.new(names, bots)
	var settings: RoomSettings = owner.room_settings
	rules.win_mode = [Rules.WinMode.ROUND_LIMIT, Rules.WinMode.TARGET_SCORE, Rules.WinMode.COUNTDOWN][settings.win_mode]
	rules.target_score = settings.target_score
	for index in range(peers.size()):
		if settings.win_mode == 2: owner.state.players[index].score = settings.target_score
		rules.seats[index].score = owner.state.players[index].score

## 새 라운드: 공유 손패로 규칙 칸을 다시 채우고 지난 라운드 효과·꺼내 든 카드를 지운다.
func begin_round() -> void:
	_round_overrides.clear()
	last_landing = Vector2.INF
	for player in controller.state.players:
		player.layout.reset()
	rules.effects.clear()
	rules.turn_position = -1
	rules.order.clear()
	for player in controller.state.players:
		var seat: int = peers.find(player.peer_id)
		rules.order.append(seat)
		var slots: Array = rules.seats[seat].slots
		for index in range(slots.size()): slots[index] = null
		for index in range(player.hand.size()): slots[index] = rules.new_card(player.hand[index])
		rules.seats[seat].pending = null
	_sync()

## 차례 순서(controller.state.players)가 바뀌었다(차례 바꾸기 카드) → 규칙 쪽 순서도 같게.
func reorder() -> void:
	rules.order.clear()
	for player in controller.state.players:
		rules.order.append(peers.find(player.peer_id))


## 나간 사람은 차례·무효 대상에서 뺀다.
func drop_missing() -> void:
	rules.order = rules.order.filter(func(index: int) -> bool: return controller.state.find_player(peers[index]) != null)

func action(sender: int, action_name: String, value: int) -> void:
	if controller.state.phase not in [MatchState.Phase.AIMING, MatchState.Phase.FLIGHT]: return
	var player: MatchPlayer = controller.state.find_player(sender)
	var seat: int = peers.find(sender)
	if player == null or seat < 0 or controller.state.active_player() == null: return
	if action_name == "select":
		if value < 0 or value >= player.hand.size(): return
		# 공유 손패는 압축 배열, 규칙 손패는 빈 칸을 유지한다. 실제 카드 슬롯으로 변환한다.
		var occupied: Array[int] = []
		for index in range(Rules.HAND_SLOTS):
			if rules.seats[seat].slots[index] != null: occupied.append(index)
		if value >= occupied.size(): return
		rules.lift(seat, occupied[value], controller._now())
	elif action_name == "choice":
		var pending = rules.seats[seat].pending
		if pending == null or not Catalog.card(pending.type).has("choice"): return
		var two_way: bool = str(Catalog.card(pending.type).choice) in ["adjust", "parity"]
		if two_way and value not in [0, 1] or not two_way and (value < 0 or value > 19): return
		pending.choice = value
	elif action_name == "use":
		var pending = rules.seats[seat].pending
		if pending == null: return
		var result: Dictionary = _use(seat, pending.type, value)
		if result.is_empty(): return
		_after_use(player, seat, result, value)
	else: return
	_sync()
	controller._publish()

## 쓴 카드를 킬로그에 적고 바로 건다. 쓰는 순간 끝나는 카드는 Actions.apply 가 처리하고, 랜덤 카드는 다른 카드를 대신 쓴다.
func _after_use(player: MatchPlayer, seat: int, result: Dictionary, value: int) -> void:
	var effect = result.effect
	var data: Dictionary = Catalog.card(result.card.type)
	var card_text: String = str(data.big)
	if int(data.timing) == Catalog.Timing.INSTANT and str(data.effect) != "random_card":
		var said: String = actions.apply(effect, player.peer_id, peers[effect.target] if effect.target >= 0 else 0)
		if not said.is_empty(): card_text += " · " + said
	elif data.has("value_names") or str(data.effect) == "parity":
		card_text += " · " + str(effect.label)
	if result.has("cancelled_effect"):
		card_text += " · 「%s」 되돌림" % Catalog.card(result.cancelled_effect.card_type).name
	controller.add_feed(controller.feed_entry("card", player, card_text, controller.state.find_player(peers[effect.target])))
	_apply_now(effect)
	if str(data.effect) == "random_card":
		_random_card(player, seat, value)


## 랜덤 카드: 지금 쓸 수 있는 카드 중 무작위 한 장을 내 손에 잠깐 쥐여 바로 쓴다(값·대상도 무작위).
## 쓸 수 있는 것을 못 찾으면 꽝(카드만 사라진다).
func _random_card(player: MatchPlayer, seat: int, value: int) -> void:
	var skip: Array[String] = ["random_card", "nullify", "retry"]
	var types: Array[int] = []
	for type in range(Catalog.count()):
		if Catalog.is_available(type) and str(Catalog.card(type).effect) not in skip: types.append(type)
	for attempt in range(12):
		var type: int = types[_random.randi_range(0, types.size() - 1)]
		var target: int = _default_pick(player.peer_id) if int(Catalog.card(type).target) == Catalog.Target.PICK else value
		var free: Array[int] = rules.empty_slots(seat)
		if free.is_empty(): return
		var card = rules.new_card(type)
		rules.place(seat, free[0], card)
		rules.lift(seat, free[0], controller._now())
		var result: Dictionary = _use(seat, type, target)
		if not result.is_empty():
			controller.add_feed(controller.feed_entry("card", player, "랜덤 카드 → %s" % Catalog.card(type).name))
			_after_use(player, seat, result, target)
			return
		rules._remove_card(seat, card)
	controller.add_feed(controller.feed_entry("card", player, "랜덤 카드 · 꽝!"))


## PICK 카드의 기본 대상: 지금 던지는 사람(내가 던지는 중이면 다른 사람 중 무작위).
func _default_pick(caster: int) -> int:
	var active: MatchPlayer = controller.state.active_player()
	if active != null and active.peer_id != caster: return active.peer_id
	var others: Array[int] = []
	for player in controller.state.players:
		if player.peer_id != caster: others.append(player.peer_id)
	return others[_random.randi_range(0, others.size() - 1)] if not others.is_empty() else 0


## 무효(×0)·PICK 은 value 로 고른 사람에게, 카드 사용자(CASTER) 카드는 나에게, 나머지는 지금 던지는 사람에게 건다.
## 카드별 사용 조건(내 차례에 못 쓰는 카드 등)은 Actions.context_problem — 화면 안내와 같은 함수다.
func _use(seat: int, type: int, value: int) -> Dictionary:
	var target_kind: int = int(Catalog.card(type).target)
	var counter: bool = target_kind == Catalog.Target.COUNTER
	var pick: bool = target_kind == Catalog.Target.PICK
	if pick and (value == peers[seat] or peers.find(value) < 0):
		value = _default_pick(peers[seat])
	var target: int = seat if target_kind == Catalog.Target.CASTER else peers.find(value if counter or pick else controller.state.active_player().peer_id)
	if target < 0:
		return {}
	if str(Catalog.card(type).effect) == "retry" and peers[seat] != controller.state.active_player().peer_id:
		return {}
	if not Actions.context_problem(type, peers[seat], controller.state, peers[target]).is_empty():
		return {}
	if not counter and not duplicate_reason(type, modifiers(peers[target]), peers[seat]).is_empty():
		return {}
	return rules.use(seat, target, controller._now())


## 화면 안내와 방장 검증이 같은 중복 조건을 쓴다. 거절해도 손패는 소모하지 않는다.
## 2026-11-22 협동 시너지를 없앴다: 같은 효과는 대상에게 한 번만 걸린다 — 누가 쓰든 두 번째는 여기서 막힌다.
## 셋째 인자는 예전에 "내가 이미 참여했나"를 가렸다. 지금은 보지 않지만 부르는 쪽을 바꾸지 않으려고 남겨 둔다.
static func duplicate_reason(type: int, effects: Dictionary, _source_peer: int = 0) -> String:
	var kind: String = str(Catalog.card(type).effect)
	var mod: String = str(Catalog.card(type).get("mod", ""))
	if kind in effects.get("active_kinds", []) or (not mod.is_empty() and mod in effects.get("active_mods", [])):
		return "이미 적용 중 · 다른 카드를 선택하세요"
	if kind == "reverse" and effects.get("reverse_axes", Vector2.ONE) != Vector2.ONE:
		return "이미 적용 중 · 다른 카드를 선택하세요"
	return "이미 적용 중 · 다른 카드를 선택하세요" if kind in NON_STACKING_KINDS and bool(effects.get(kind, false)) else ""

## 쓰는 순간 바로 건다: 숫자 섞기는 과녁을 지금 섞고, 날아가는 다트에 걸린 궤적 카드는 꽂히는 자리를 다시 계산한다.
## 점수 카드는 꽂히는 순간 계산(landing_points·score)이라 따로 할 일이 없다.
## 머신 효과(셔터·회전·분리)는 지금 시각을 시작으로 적어 둔다 — 꽂히는 순간 그 시각의 모양으로 판정한다.
func _apply_now(effect) -> void:
	var thrower: MatchPlayer = controller.state.active_player()
	if thrower == null: return
	thrower.layout.apply_card_change(effect.kind, effect.choice, _random)
	_refresh_live()
	if effect.kind == "lock_scores":
		_round_overrides = thrower.layout.overrides.duplicate()
		for player in controller.state.players: player.layout.overrides = _round_overrides.duplicate()
	if effect.kind in CHAOS_KINDS: _start_chaos(effect.kind)
	if effect.kind in FLIGHT_KINDS and controller.state.phase == MatchState.Phase.FLIGHT: controller.redirect_flight()

## 머신 효과 하나를 켠다. 이미 켜진 효과를 또 쓰면 시작 시각은 그대로(모양이 덜컥 튀지 않게) 두고 카드만 소모된다.
func _start_chaos(kind: String) -> void:
	if _chaos_from.has(kind): return
	_chaos_from[kind] = controller._now()
	if kind == "spin": _spin_direction = -_spin_direction
	if kind == "cover": _cover_side = -1 if _random.randf() < 0.5 else 1
	# 방장이 시전마다 한 번 결정한다. 클라이언트와 비행 중 예측은 같은 경계를 쓴다.
	if kind == "vertical": _seams.x = -1 if _random.randf() < 0.5 else 1
	if kind == "horizontal": _seams.y = -1 if _random.randf() < 0.5 else 1
	if kind == "move": _move_direction = Vector2.from_angle(_random.randf_range(0, TAU))

## 카드가 걸리거나 무효(×0)로 풀린 뒤 "지금 걸린 효과"에 머신·링을 맞춘다: 풀린 머신 효과는 끄고, 링 두께는 던지는 사람 효과대로.
func _refresh_live() -> void:
	var thrower: MatchPlayer = controller.state.active_player()
	if thrower == null: return
	var mods: Dictionary = modifiers(thrower.peer_id)
	for kind: String in CHAOS_KINDS:
		if _chaos_from.has(kind) and not bool(mods.get(kind, false)): _chaos_from.erase(kind)
	if not is_equal_approx(float(mods.get("board_scale", 1.0)), 1.0):
		_start_chaos("board_zoom")
	else:
		_chaos_from.erase("board_zoom")
	thrower.layout.ring_scale = float(mods.get("ring_scale", 1.0))


## 공개용: 켜진 머신 효과마다 "걸린 지 몇 초"(방장 시계) + 회전 방향. MatchController._publish 가 스냅샷에 싣는다.
func chaos_ages() -> Dictionary:
	var now: float = controller._now()
	var active := controller.state.active_player()
	var active_mods: Dictionary = modifiers(active.peer_id) if active != null else {}
	var ages: Dictionary = {"vertical_sign": _seams.x, "horizontal_sign": _seams.y, "dir": _spin_direction, "cover_side": _cover_side, "move_dir": _move_direction, "scale": float(active_mods.get("board_scale", 1.0))}
	for kind: String in _chaos_from:
		ages[kind] = now - float(_chaos_from[kind])
	return ages

## 방장이 보는 지금 과녁 모양(BoardChaos.pose). 점수 판정과 방장 화면이 같이 쓴다.
func shape_now(elapsed: float = 0.0) -> Dictionary:
	return BoardChaos.from_ages(chaos_ages(), elapsed)


func begin_dart_turn() -> void:
	var active: MatchPlayer = controller.state.active_player()
	if active == null: return
	var seat: int = peers.find(active.peer_id)
	rules.begin_turn(rules.order.find(seat))
	var mods: Dictionary = rules.dart_modifiers(seat)
	active.layout.reset()
	active.layout.overrides = _round_overrides.duplicate()
	active.layout.ring_scale = float(mods.get("ring_scale", 1.0))
	if mods.shuffle: active.layout.numbers.shuffle()
	# 머신은 차례마다 제자리에서 시작한다. 차례 시작에 켜지는 효과(미리 걸어 둔 "차례 동안" 카드)는 지금부터 움직인다.
	_chaos_from.clear()
	if not is_equal_approx(float(mods.get("board_scale", 1.0)), 1.0): _start_chaos("board_zoom")
	for kind in CHAOS_KINDS:
		if bool(mods.get(kind, false)): _start_chaos(kind)
	for player in controller.state.players:
		if player.is_bot:
			_bot_plans[player.peer_id] = controller._now() + _random.randf_range(BOT_THINK_SECONDS.x, BOT_THINK_SECONDS.y) if _random.randf() < BOT_USE_CHANCE else -1.0
	_sync()

## 방장 매 프레임(다트 턴 중): 봇이 꺼내 든 카드는 준비되면 쓰고, 정해 둔 시각이 되면 한 장을 꺼낸다.
func tick_bots() -> void:
	var now: float = controller._now()
	var thrower: MatchPlayer = controller.state.active_player()
	if thrower == null: return
	for player in controller.state.players:
		if not player.is_bot: continue
		var seat: int = peers.find(player.peer_id)
		var pending = rules.seats[seat].pending
		var plan: float = float(_bot_plans.get(player.peer_id, -1.0))
		var counter: int = _bot_card(player, [Catalog.Target.COUNTER])
		if pending != null:
			if rules.is_ready(seat, now): _bot_use(player, seat, pending.type)
		elif player == thrower and counter >= 0 and _victim(player) != 0:
			action(player.peer_id, "select", counter)
		elif plan >= 0.0 and now >= plan:
			_bot_plans[player.peer_id] = -1.0
			# 내 차례 = 나에게 거는 카드·카드 사용자 카드, 남의 차례 = 방해 카드·PICK(던지는 사람을 고른다)·카드 사용자 카드.
			var index: int = _bot_card(player, [Catalog.Target.SELF, Catalog.Target.CASTER, Catalog.Target.ALL] if player == thrower else [Catalog.Target.OPPONENT, Catalog.Target.ALL, Catalog.Target.PICK, Catalog.Target.CASTER])
			if index >= 0:
				action(player.peer_id, "select", index)
				var picked = rules.seats[seat].pending
				if picked != null and Catalog.card(picked.type).has("choice"):
					picked.choice = _random.randi_range(0, 1 if str(Catalog.card(picked.type).choice) in ["adjust", "parity"] else 19)

## 봇 손패에서 대상 종류(targets)가 맞는 카드 하나의 번호(무작위). 없으면 -1.
func _bot_card(player: MatchPlayer, targets: Array) -> int:
	var found: Array[int] = []
	for index in range(player.hand.size()):
		var type: int = player.hand[index]
		if int(Catalog.card(type).target) not in targets: continue
		# 봇이 고르지 않는 것: 조준이 필요한 카드(속박·끌어당기기 — 봇은 사람을 겨누지 않는다)·카드 던지기, 지금 쓸 수 없는 카드.
		if bool(Catalog.card(type).get("aim", false)) or str(Catalog.card(type).effect) == "card_throw": continue
		var target: int = _default_pick(player.peer_id) if int(Catalog.card(type).target) == Catalog.Target.PICK else 0
		if not Actions.context_problem(type, player.peer_id, controller.state, target).is_empty(): continue
		var aimed: int = player.peer_id if int(Catalog.card(type).target) == Catalog.Target.CASTER else (target if target != 0 else controller.state.active_player().peer_id)
		if duplicate_reason(type, modifiers(aimed), player.peer_id).is_empty():
			found.append(index)
	return found[_random.randi_range(0, found.size() - 1)] if not found.is_empty() else -1

## 무효로 막을 사람 = 봇 말고 카드를 꺼내 든 첫 사람. 없으면 0.
func _victim(bot: MatchPlayer) -> int:
	for player in controller.state.players:
		if player != bot and player.pending_card >= 0: return player.peer_id
	return 0

## 준비된 봇 카드를 쓴다. 무효를 들었는데 막을 카드가 사라졌으면 내려놓는다.
func _bot_use(player: MatchPlayer, seat: int, type: int) -> void:
	var aimed: int = player.peer_id if int(Catalog.card(type).target) == Catalog.Target.CASTER else controller.state.active_player().peer_id
	if int(Catalog.card(type).target) != Catalog.Target.COUNTER and not duplicate_reason(type, modifiers(aimed), player.peer_id).is_empty():
		rules.lower(seat)
		_sync()
		controller._publish()
		return
	if int(Catalog.card(type).target) == Catalog.Target.PICK:
		action(player.peer_id, "use", _default_pick(player.peer_id))
		return
	if int(Catalog.card(type).target) != Catalog.Target.COUNTER:
		action(player.peer_id, "use", controller.state.active_player().peer_id)
		return
	var victim: int = _victim(player)
	if victim != 0:
		action(player.peer_id, "use", victim)
		return
	rules.lower(seat)
	_sync()
	controller._publish()

func end_dart_turn() -> void:
	rules.end_turn()
	_chaos_from.clear()
	_sync()


func take_retry(peer_id: int) -> bool:
	var seat: int = peers.find(peer_id)
	return seat >= 0 and rules.take_retry(seat)

## 몸으로 막은 사람에게 주는 방해 성공 보상(계산은 RoundRules.disrupt). 점수판까지 맞추고
## 킬로그 뒤에 붙일 짧은 글자를 돌려준다.
func disrupt(peer_id: int) -> String:
	var seat: int = peers.find(peer_id)
	var player: MatchPlayer = controller.state.find_player(peer_id)
	if seat < 0 or player == null:
		return ""
	var reward: Dictionary = rules.disrupt(seat)
	rules.penalize_thrower(peers.find(controller.state.active_player().peer_id))
	player.score = rules.seats[seat].score
	_sync()
	if str(reward.kind) != "score":
		return " · 이번 라운드 약한 어지러움"
	var mark: String = "+"
	return " · 방해 성공 %s%d점" % [mark, int(reward.amount)]

## [개발자 모드] 손패와 상관없이 카드 한 장을 바로 쓴다(방장 전용 치트, ui/settings_panel.gd 의 카드 시험대).
## 진짜 사용 경로(_use → _after_use)를 그대로 지나므로 시험대에서 본 것이 경기에서 보는 것과 같다.
## 돌려주는 글자: 빈 글자 = 썼음, 아니면 못 쓴 이유.
func developer_play(peer_id: int, type: int, target_peer: int) -> String:
	var seat: int = peers.find(peer_id)
	var player: MatchPlayer = controller.state.find_player(peer_id)
	if seat < 0 or player == null:
		return "그 사람이 경기에 없습니다"
	if controller.state.phase not in [MatchState.Phase.AIMING, MatchState.Phase.FLIGHT]:
		return "다트 턴(조준·비행) 중에만 쓸 수 있습니다"
	var free: Array[int] = rules.empty_slots(seat)
	if free.is_empty():
		rules._remove_card(seat, rules.seats[seat].slots[0])
		free = rules.empty_slots(seat)
	var card = rules.new_card(type)
	rules.place(seat, free[0], card)
	rules.lift(seat, free[0], controller._now())
	var result: Dictionary = _use(seat, type, target_peer)
	if result.is_empty():
		rules._remove_card(seat, card)
		_sync()
		controller._publish()
		return "지금은 조건이 안 맞습니다(차례·대상·이미 적용 중)"
	_after_use(player, seat, result, target_peer)
	_sync()
	controller._publish()
	return ""


## [개발자 모드] 점수를 직접 바꾼다. 규칙 쪽 점수판도 같이 맞춘다.
func developer_set_score(peer_id: int, points: int) -> void:
	var seat: int = peers.find(peer_id)
	var player: MatchPlayer = controller.state.find_player(peer_id)
	if seat < 0 or player == null:
		return
	rules.seats[seat].score = points
	player.score = points


## [개발자 모드] 지금 걸려 있는 카드 효과를 전부 지운다(과녁 모양도 기본으로).
func developer_clear_effects() -> void:
	rules.effects.clear()
	for player in controller.state.players:
		player.layout.reset()
	_chaos_from.clear()
	_sync()


func modifiers(peer_id: int) -> Dictionary:
	var seat: int = peers.find(peer_id)
	if seat < 0: return {}
	var mods: Dictionary = rules.dart_modifiers(seat)
	# 중복 검사(duplicate_reason)용: 지금 이 사람에게 걸린 효과 이름·"mod" 이름.
	var kinds: Array[String] = []
	var mod_names: Array[String] = []
	for effect in rules.effects:
		if effect.target != seat or effect.state not in [Rules.EffectState.QUEUED, Rules.EffectState.ACTIVE]: continue
		kinds.append(str(effect.kind))
		var mod: String = str(Catalog.card(effect.card_type).get("mod", "")) if effect.card_type >= 0 else ""
		if not mod.is_empty(): mod_names.append(mod)
	mods["active_kinds"] = kinds
	mods["active_mods"] = mod_names
	return mods


## 꽂히는 순간의 과녁(숫자 섞기·셔터·회전·분리)으로 기본 점수를 다시 센다. 날아가는 중에 쓴 과녁 카드도 그 다트에 걸린다.
## 벽·바닥(정규화 좌표 99)은 과녁 밖이라 0점이다. 판정 순서는 BoardChaos.locate(셔터 → 회전 → 조각).
func landing_points(hit: Dictionary) -> int:
	var player: MatchPlayer = controller.state.active_player()
	var mods: Dictionary = modifiers(player.peer_id)
	var shape: Dictionary = shape_now()
	# 관통 다트는 셔터를 뚫는다(MatchController._solve 도 셔터 앞면에 박지 않는다).
	shape.cover = bool(mods.get("cover", false)) and not bool(mods.get("pierce", false))
	var total: int = 0
	var sectors: Array[int] = []
	var mine_hits: int = 0
	for flight: Dictionary in hit.get("flights", [hit]):
		var aim := Vector2(float(flight.x), float(flight.y))
		# 방장이 날개에 실제로 부딪힌 발은 착탄면 전체가 셔터다. 큰 다트의 면적 표본도 그 뒤로 새지 않는다.
		if bool(flight.get("shutter_hit", false)) or bool(flight.get("infill_hit", false)): continue
		var region: int = BoardScorer.region_at(BoardChaos.locate(aim, shape), player.layout.ring_scale)
		if bool(mods.get("large", false)):
			var area: Dictionary = BoardChaos.area_result(aim, shape, player.layout, _random)
			region = int(area.region)
		var points: int = player.layout.region_score(region)
		total += points
		if region >= 0 and region < 80:
			sectors.append(region / 4)
			# 같은 칸에 겹쳐 심은 지뢰는 겹친 수만큼 터진다(2026-11-24).
			mine_hits += mines.count(region / 4)
		# 좌표 고정 카드가 다시 노릴 자리 = 마지막으로 과녁(판 위)에 꽂힌 곳.
		if region >= 0: last_landing = aim
	hit["hit_sectors"] = sectors
	hit["mine_hits"] = mine_hits
	return total

func score(base: float, hit: Dictionary = {}) -> Dictionary:
	var player: MatchPlayer = controller.state.active_player()
	var seat: int = peers.find(player.peer_id)
	var hit_sectors: Array[int] = []
	hit_sectors.assign(hit.get("hit_sectors", []))
	var result: Dictionary = rules.resolve_dart(seat, base, hit_sectors, player.layout, int(hit.get("mine_hits", 0)))
	var outcome: Dictionary = rules.apply_points(seat, float(result.points))
	player.score = rules.seats[seat].score
	result.merge(outcome)
	if int(hit.get("mine_hits", 0)) > 0:
		controller.add_feed(controller.feed_entry("broken", player, "지뢰 쾅! −%d" % (Rules.MINE_PENALTY * int(hit.mine_hits))))
	# 가로채기·반띵: 카드 쓴 사람에게 점수를 넘긴다. 그쪽이 목표 점수에 닿으면 그 사람이 이긴다.
	# taken = 이 발에서 뺏긴 점수 합(점수 팝업 "-20 TAKEN" — GameView._show_score_popup).
	result["taken"] = 0.0
	for transfer: Dictionary in result.get("transfers", []):
		result.taken = float(result.taken) + float(transfer.points)
		var taker: MatchPlayer = controller.state.find_player(peers[int(transfer.seat)])
		var gained: Dictionary = rules.give_points(int(transfer.seat), float(transfer.points))
		if taker != null:
			taker.score = rules.seats[int(transfer.seat)].score
			controller.add_feed(controller.feed_entry("card", taker, "%.1f점 가져감" % float(transfer.points), player))
		if bool(gained.get("win", false)): result.win = true
	_sync()
	return result


## 카드 던지기 카드를 한 번 썼다(던졌다) — 효과를 끝낸다.
func consume_card_throw(peer_id: int) -> void:
	var seat: int = peers.find(peer_id)
	if seat >= 0 and rules.consume_mod(seat, "card_throw"):
		_sync()

func _sync() -> void:
	for player in controller.state.players:
		var seat: int = peers.find(player.peer_id)
		player.hand.clear()
		for card in rules.seats[seat].slots:
			if card != null: player.hand.append(card.type)
		var pending = rules.seats[seat].pending
		player.pending_card = pending.type if pending != null else -1
		# 규칙 칸 번호(빈 칸 포함) → 압축된 hand 번호.
		var raw: int = rules.slot_of(seat, pending) if pending != null else -1
		player.pending_slot = -1
		if raw >= 0 and raw < Rules.HAND_SLOTS:
			player.pending_slot = rules.seats[seat].slots.slice(0, raw).filter(func(card) -> bool: return card != null).size()
		player.card_effects = modifiers(player.peer_id)
		player.card_effects["details"] = _effect_details(seat)
		player.card_effects["used_cards"] = _used_cards(seat)
		player.card_effects["choice"] = pending.choice if pending != null else -1
		player.card_effects["retry_used"] = rules.seats[seat].retry_used
		player.card_effects["extra_turn"] = rules.seats[seat].extra_turn
		# 2026-11-21: 무효로 되돌릴 수 있는 방금 쓴 카드가 있는가(화면 Tab 대상) · 좌표 고정 가능 · 지뢰 수(위치는 비밀).
		player.card_effects["cancellable"] = rules.cancellable(rules.seats[seat].last_effect)
		player.card_effects["repeat_ready"] = last_landing.is_finite()
		player.card_effects["mine_count"] = mines.size()


## 이번 라운드에 seat 가 쓴 카드, 쓴 순서대로 Vector2i(카드 번호, UsedCard 상태). HUD 가 사람별로 그린다(ui/used_cards.gd).
## 2026-11-28 A 보완안: 예전 '적용 중' 카드 줄(지금 던지는 사람에게 걸린 카드)을 이 기록으로 합쳤다 — 걸려 있는 카드는 LIVE 로 밝게 보인다.
## 카드를 실제로 쓴 기록 = RoundRules.use()·_nullify_from() 이 uid 를 매긴 효과다. 몸 명중 어지러움·모두 어지러움 나눔은
## uid 가 0 이고, 투척자 벌칙(hit_penalty)은 카드가 아니라 뺀다. rules.effects 는 begin_round 에서 비우므로 기록도 라운드 단위다.
func _used_cards(seat: int) -> Array[Vector2i]:
	var used: Array[Vector2i] = []
	for effect in rules.effects:
		if effect.source != seat or effect.uid <= 0 or effect.kind == "hit_penalty":
			continue
		var status: int = UsedCard.SPENT
		if effect.state == Rules.EffectState.NULLIFIED:
			status = UsedCard.NULLIFIED
		elif effect.state in [Rules.EffectState.QUEUED, Rules.EffectState.ACTIVE]:
			status = UsedCard.LIVE
		used.append(Vector2i(effect.card_type, status))
	return used


## 같은 효과는 횟수를 합쳐 실제 유효한 효과와 남은 범위만 공개한다.
func _effect_details(seat: int) -> Array[String]:
	var counts: Dictionary = {}
	for effect in rules.effects:
		if effect.target != seat:
			continue
		var next_dart: bool = effect.timing == Catalog.Timing.NEXT_DART and effect.state == Rules.EffectState.QUEUED
		var turn: bool = effect.timing in [Catalog.Timing.TURN, Catalog.Timing.ROUND] and effect.state == Rules.EffectState.ACTIVE
		if not next_dart and not turn:
			continue
		var labelled: bool = effect.kind in ["math", "random_math", "precision", "wind", "body_dizzy", "hit_penalty", "parity"] or (effect.card_type >= 0 and Catalog.card(effect.card_type).has("value_names"))
		var name: String = str(effect.label) if labelled else str(Catalog.card(effect.card_type).name)
		var key: String = "%s · %s" % [name, "다음 한 발" if next_dart else ("이번 라운드 끝까지" if effect.timing == Catalog.Timing.ROUND else "이번 차례 끝까지")]
		counts[key] = int(counts.get(key, 0)) + 1
	var lines: Array[String] = []
	for key: String in counts:
		lines.append(key + (" ×%d" % counts[key] if counts[key] > 1 else ""))
	if not _round_overrides.is_empty() and not lines.any(func(line: String) -> bool: return line.begins_with("점수 고정")):
		lines.append("점수 고정 · 이번 라운드 끝까지")
	return lines
