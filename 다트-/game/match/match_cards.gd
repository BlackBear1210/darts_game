extends RefCounted
## 기존 카드 시연의 순수 규칙을 방장 경기로 연결한다. 카드 효과 계산은 RoundRules 한 곳에 둔다.
## 2026-10-31 사용자 결정: 카드 턴은 없다. 라운드 시작에 7장을 채우고 VIEW_SECONDS 동안 확인한 뒤 바로 다트.
## 다트 턴(조준·비행) 동안 누구나 어떤 카드든 쓰고, 효과는 누가 쓰든 지금 던지는 사람에게 바로 걸린다.
## 무효(×0)만 예외로 카드를 꺼내 든 사람을 노린다. 꺼내 들고 Rules.READY_SECONDS 기다리기는 그대로다.
const Rules = preload("res://game/card_round/rules/round_rules.gd")
const Catalog = preload("res://game/card_round/rules/card_catalog.gd")
## 카드를 나눠 준 뒤 받은 카드를 확인하는 시간(초). 이 동안에는 카드를 쓰지 않는다.
const VIEW_SECONDS: float = 5.0
## 날아가는 다트에 쓰면 꽂히는 자리가 바뀌는 효과(궤적 카드).
const FLIGHT_KINDS: Array[String] = ["heavy", "wind", "power", "triple", "drowsy", "large"]
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
var _move_direction := Vector2.RIGHT
var _round_overrides: Dictionary = {}

## F5 경기 규칙: 무효(×0) 말고는 누가 쓰든 대상이 지금 던지는 사람 하나다. 효과 계산은 RoundRules 그대로 쓴다.
class MatchRules extends "res://game/card_round/rules/round_rules.gd":
	func valid_targets(seat: int, type: int) -> Array[int]:
		if int(CardCatalog.card(type).target) == CardCatalog.Target.CASTER:
			return [seat]
		if int(CardCatalog.card(type).target) == CardCatalog.Target.COUNTER:
			return super(seat, type)
		var targets: Array[int] = []
		if active_seat() >= 0: targets.append(active_seat())
		return targets

func _init(owner: MatchController) -> void:
	controller = owner
	_random.randomize()
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
		var adjust: bool = str(Catalog.card(pending.type).choice) == "adjust"
		if adjust and value not in [0, 1] or not adjust and (value < 0 or value > 19): return
		pending.choice = value
	elif action_name == "use":
		var pending = rules.seats[seat].pending
		if pending == null: return
		var result: Dictionary = _use(seat, pending.type, value)
		if result.is_empty(): return
		var card_text: String = str(Catalog.card(result.card.type).big)
		if result.effect.contributors.size() >= 2: card_text += " · %d인 시너지" % result.effect.contributors.size()
		controller.add_feed(controller.feed_entry("card", player, card_text, controller.state.find_player(peers[result.effect.target])))
		_apply_now(result.effect)
	else: return
	_sync()
	controller._publish()

## 무효(×0)는 value 로 고른 "카드를 꺼내 든 사람"에게, 나머지는 지금 던지는 사람에게 건다(대상 검사는 MatchRules).
func _use(seat: int, type: int, value: int) -> Dictionary:
	var counter: bool = int(Catalog.card(type).target) == Catalog.Target.COUNTER
	var caster: bool = int(Catalog.card(type).target) == Catalog.Target.CASTER
	var target: int = seat if caster else peers.find(value if counter else controller.state.active_player().peer_id)
	if str(Catalog.card(type).effect) == "retry" and peers[seat] != controller.state.active_player().peer_id:
		return {}
	if Catalog.card(type).has("choice") and controller.state.phase != MatchState.Phase.AIMING:
		return {}
	if not counter and not duplicate_reason(type, modifiers(peers[target]), peers[seat]).is_empty():
		return {}
	return rules.use(seat, target, controller._now())


## 화면 안내와 방장 검증이 같은 중복 조건을 쓴다. 거절해도 손패는 소모하지 않는다.
static func duplicate_reason(type: int, effects: Dictionary, source_peer: int = 0) -> String:
	var kind: String = str(Catalog.card(type).effect)
	var together: Dictionary = effects.get("synergies", {}).get(kind, {})
	if Catalog.supports_synergy(type) and not together.is_empty():
		if source_peer == 0 or source_peer in together.contributors: return "이미 참여한 방해카드 · 다른 카드를 선택하세요"
		if int(together.players) >= Catalog.SYNERGY_MAX_PLAYERS: return "시너지 최대 단계 · 다른 카드를 선택하세요"
		return ""
	if kind == "reverse" and effects.get("reverse_axes", Vector2.ONE) != Vector2.ONE:
		return "이미 적용 중 · 다른 카드를 선택하세요"
	return "이미 적용 중 · 다른 카드를 선택하세요" if kind in NON_STACKING_KINDS and bool(effects.get(kind, false)) else ""

## 쓰는 순간 바로 건다: 숫자 섞기는 과녁을 지금 섞고, 날아가는 다트에 걸린 궤적 카드는 꽂히는 자리를 다시 계산한다.
## 점수 카드는 꽂히는 순간 계산(landing_points·score)이라 따로 할 일이 없다.
## 머신 효과(셔터·회전·분리)는 지금 시각을 시작으로 적어 둔다 — 꽂히는 순간 그 시각의 모양으로 판정한다.
func _apply_now(effect) -> void:
	var thrower: MatchPlayer = controller.state.active_player()
	thrower.layout.apply_card_change(effect.kind, effect.choice, effect.contributors.size(), _random)
	if effect.kind == "lock_scores":
		_round_overrides = thrower.layout.overrides.duplicate()
		for player in controller.state.players: player.layout.overrides = _round_overrides.duplicate()
	if effect.kind in FLIGHT_KINDS and controller.state.phase == MatchState.Phase.FLIGHT: controller.redirect_flight()
	if effect.kind in CHAOS_KINDS: _start_chaos(effect.kind)

## 머신 효과 하나를 켠다. 이미 켜진 효과를 또 쓰면 시작 시각은 그대로(모양이 덜컥 튀지 않게) 두고 카드만 소모된다.
func _start_chaos(kind: String) -> void:
	if _chaos_from.has(kind): return
	_chaos_from[kind] = controller._now()
	if kind == "spin": _spin_direction = -_spin_direction
	if kind == "cover": _cover_side = -1 if _random.randf() < 0.5 else 1
	if kind == "move": _move_direction = Vector2.from_angle(_random.randf_range(0, TAU))

## 공개용: 켜진 머신 효과마다 "걸린 지 몇 초"(방장 시계) + 회전 방향. MatchController._publish 가 스냅샷에 싣는다.
func chaos_ages() -> Dictionary:
	var now: float = controller._now()
	var ages: Dictionary = {"dir": _spin_direction, "cover_side": _cover_side, "move_dir": _move_direction, "levels": modifiers(controller.state.active_player().peer_id).get("synergy_levels", {})}
	for kind: String in _chaos_from:
		ages[kind] = now - float(_chaos_from[kind])
	return ages

## 방장이 보는 지금 과녁 모양(BoardChaos.pose). 점수 판정과 방장 화면이 같이 쓴다.
func shape_now() -> Dictionary:
	var now: float = controller._now()
	var age := func(kind: String) -> float:
		return now - float(_chaos_from[kind]) if _chaos_from.has(kind) else -1.0
	return BoardChaos.boost(BoardChaos.pose(age.call("spin"), _spin_direction, age.call("split"), age.call("cover"), age.call("vertical"), age.call("horizontal"), age.call("move"), _move_direction, _cover_side), modifiers(controller.state.active_player().peer_id).get("synergy_levels", {}))

func begin_dart_turn() -> void:
	var active: MatchPlayer = controller.state.active_player()
	if active == null: return
	var seat: int = peers.find(active.peer_id)
	rules.begin_turn(rules.order.find(seat))
	var mods: Dictionary = rules.dart_modifiers(seat)
	active.layout.reset()
	active.layout.overrides = _round_overrides.duplicate()
	if mods.shuffle: active.layout.numbers.shuffle()
	# 머신은 차례마다 제자리에서 시작한다. 차례 시작에 켜지는 효과(미리 걸어 둔 "차례 동안" 카드)는 지금부터 움직인다.
	_chaos_from.clear()
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
			var index: int = _bot_card(player, [Catalog.Target.SELF, Catalog.Target.CASTER, Catalog.Target.ALL] if player == thrower else [Catalog.Target.OPPONENT, Catalog.Target.ALL])
			if index >= 0:
				action(player.peer_id, "select", index)
				var picked = rules.seats[seat].pending
				if picked != null and Catalog.card(picked.type).has("choice"):
					picked.choice = _random.randi_range(0, 1 if str(Catalog.card(picked.type).choice) == "adjust" else 19)

## 봇 손패에서 대상 종류(targets)가 맞는 카드 하나의 번호(무작위). 없으면 -1.
func _bot_card(player: MatchPlayer, targets: Array) -> int:
	var found: Array[int] = []
	for index in range(player.hand.size()):
		if int(Catalog.card(player.hand[index]).target) in targets and duplicate_reason(player.hand[index], modifiers(controller.state.active_player().peer_id), player.peer_id).is_empty():
			found.append(index)
	return found[_random.randi_range(0, found.size() - 1)] if not found.is_empty() else -1

## 무효로 막을 사람 = 봇 말고 카드를 꺼내 든 첫 사람. 없으면 0.
func _victim(bot: MatchPlayer) -> int:
	for player in controller.state.players:
		if player != bot and player.pending_card >= 0: return player.peer_id
	return 0

## 준비된 봇 카드를 쓴다. 무효를 들었는데 막을 카드가 사라졌으면 내려놓는다.
func _bot_use(player: MatchPlayer, seat: int, type: int) -> void:
	if not duplicate_reason(type, modifiers(controller.state.active_player().peer_id), player.peer_id).is_empty():
		rules.lower(seat)
		_sync()
		controller._publish()
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

func modifiers(peer_id: int) -> Dictionary:
	var seat: int = peers.find(peer_id)
	if seat < 0: return {}
	var mods: Dictionary = rules.dart_modifiers(seat)
	mods["synergies"] = _synergy_details(seat)
	return mods


func _synergy_details(seat: int) -> Dictionary:
	var groups: Dictionary = {}
	for effect in rules.effects:
		if effect.target != seat or effect.contributors.is_empty() or effect.state not in [Rules.EffectState.QUEUED, Rules.EffectState.ACTIVE]: continue
		var contributors: Array[int] = []
		for source: int in effect.contributors: contributors.append(peers[source])
		groups[effect.kind] = {"contributors": contributors, "players": contributors.size(), "factor": Catalog.synergy_factor(contributors.size())}
	return groups

## 꽂히는 순간의 과녁(숫자 섞기·셔터·회전·분리)으로 기본 점수를 다시 센다. 날아가는 중에 쓴 과녁 카드도 그 다트에 걸린다.
## 벽·바닥(정규화 좌표 99)은 과녁 밖이라 0점이다. 판정 순서는 BoardChaos.locate(셔터 → 회전 → 조각).
func landing_points(hit: Dictionary) -> int:
	var player: MatchPlayer = controller.state.active_player()
	var shape: Dictionary = shape_now()
	shape.cover = bool(modifiers(player.peer_id).get("cover", false))
	var total: int = 0
	var sectors: Array[int] = []
	for flight: Dictionary in hit.get("flights", [hit]):
		var aim := Vector2(float(flight.x), float(flight.y))
		var region: int = BoardScorer.region_at(BoardChaos.locate(aim, shape))
		if bool(modifiers(player.peer_id).get("large", false)):
			var area: Dictionary = BoardChaos.area_result(aim, shape, player.layout, _random)
			region = int(area.region)
		var points: int = player.layout.region_score(region)
		total += points
		if region >= 0 and region < 80: sectors.append(region / 4)
	hit["hit_sectors"] = sectors
	return total

func score(base: float, hit: Dictionary = {}) -> Dictionary:
	var player: MatchPlayer = controller.state.active_player()
	var seat: int = peers.find(player.peer_id)
	var hit_sectors: Array[int] = []
	hit_sectors.assign(hit.get("hit_sectors", []))
	var result: Dictionary = rules.resolve_dart(seat, base, hit_sectors, player.layout)
	var outcome: Dictionary = rules.apply_points(seat, float(result.points))
	player.score = rules.seats[seat].score
	result.merge(outcome)
	_sync()
	return result

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
		player.card_effects["choice"] = pending.choice if pending != null else -1
		player.card_effects["retry_used"] = rules.seats[seat].retry_used
		player.card_effects["extra_turn"] = rules.seats[seat].extra_turn


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
		var name: String = str(effect.label) if effect.kind in ["math", "random_math", "precision", "wind", "body_dizzy", "hit_penalty"] else str(Catalog.card(effect.card_type).name)
		if effect.contributors.size() >= 2: name += " · %d인 시너지 ×%.1f" % [effect.contributors.size(), Catalog.synergy_factor(effect.contributors.size())]
		var key: String = "%s · %s" % [name, "다음 한 발" if next_dart else ("이번 라운드 끝까지" if effect.timing == Catalog.Timing.ROUND else "이번 차례 끝까지")]
		counts[key] = int(counts.get(key, 0)) + 1
	var lines: Array[String] = []
	for key: String in counts:
		lines.append(key + (" ×%d" % counts[key] if counts[key] > 1 else ""))
	if not _round_overrides.is_empty() and not lines.any(func(line: String) -> bool: return line.begins_with("점수 고정")):
		lines.append("점수 고정 · 이번 라운드 끝까지")
	return lines
