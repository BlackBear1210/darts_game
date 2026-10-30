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
const FLIGHT_KINDS: Array[String] = ["heavy", "wind", "power", "triple"]
## 봇 카드(2026-10-31 사용자 요청): 다트 턴마다 봇마다 이 확률로 한 장을 쓴다. 시연값.
## 효과는 늘 던지는 사람에게 걸리므로 자기 차례면 나에게 거는 카드(×2·+10 등), 남의 차례면 방해 카드를 고른다.
## 자기 차례에 남이 카드를 꺼내 들면 가진 무효(×0)로 막는다.
const BOT_USE_CHANCE: float = 0.6
## 차례가 시작되고 봇이 카드를 꺼내기까지의 시간 범위(초). 시연값.
const BOT_THINK_SECONDS := Vector2(1.0, 6.0)
var controller: MatchController
var rules: RefCounted
var peers: Array[int] = []
## 봇 peer ID → 이번 다트 턴에 카드를 꺼낼 시각(-1 = 이번 차례엔 안 씀).
var _bot_plans: Dictionary = {}
var _random := RandomNumberGenerator.new()

## F5 경기 규칙: 무효(×0) 말고는 누가 쓰든 대상이 지금 던지는 사람 하나다. 효과 계산은 RoundRules 그대로 쓴다.
class MatchRules extends "res://game/card_round/rules/round_rules.gd":
	func valid_targets(seat: int, type: int) -> Array[int]:
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
	elif action_name == "use":
		var pending = rules.seats[seat].pending
		if pending == null: return
		var result: Dictionary = _use(seat, pending.type, value)
		if result.is_empty(): return
		controller.add_feed(controller.feed_entry("card", player, str(Catalog.card(result.card.type).big), controller.state.find_player(peers[result.effect.target])))
		_apply_now(result.effect)
	else: return
	_sync()
	controller._publish()

## 무효(×0)는 value 로 고른 "카드를 꺼내 든 사람"에게, 나머지는 지금 던지는 사람에게 건다(대상 검사는 MatchRules).
func _use(seat: int, type: int, value: int) -> Dictionary:
	var counter: bool = int(Catalog.card(type).target) == Catalog.Target.COUNTER
	var target: int = peers.find(value if counter else controller.state.active_player().peer_id)
	return rules.use(seat, target, controller._now())

## 쓰는 순간 바로 건다: 숫자 섞기는 과녁을 지금 섞고, 날아가는 다트에 걸린 궤적 카드는 꽂히는 자리를 다시 계산한다.
## 점수 카드·가림판은 꽂히는 순간 계산(landing_points·score)이라 따로 할 일이 없다.
func _apply_now(effect) -> void:
	var thrower: MatchPlayer = controller.state.active_player()
	if effect.kind == "shuffle": thrower.layout.numbers.shuffle()
	if effect.kind in FLIGHT_KINDS and controller.state.phase == MatchState.Phase.FLIGHT: controller.redirect_flight()

func begin_dart_turn() -> void:
	var active: MatchPlayer = controller.state.active_player()
	if active == null: return
	var seat: int = peers.find(active.peer_id)
	rules.begin_turn(rules.order.find(seat))
	var mods: Dictionary = rules.dart_modifiers(seat)
	active.layout.reset()
	if mods.shuffle: active.layout.numbers.shuffle()
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
			var index: int = _bot_card(player, [Catalog.Target.SELF] if player == thrower else [Catalog.Target.OPPONENT])
			if index >= 0: action(player.peer_id, "select", index)

## 봇 손패에서 대상 종류(targets)가 맞는 카드 하나의 번호(무작위). 없으면 -1.
func _bot_card(player: MatchPlayer, targets: Array) -> int:
	var found: Array[int] = []
	for index in range(player.hand.size()):
		if int(Catalog.card(player.hand[index]).target) in targets: found.append(index)
	return found[_random.randi_range(0, found.size() - 1)] if not found.is_empty() else -1

## 무효로 막을 사람 = 봇 말고 카드를 꺼내 든 첫 사람. 없으면 0.
func _victim(bot: MatchPlayer) -> int:
	for player in controller.state.players:
		if player != bot and player.pending_card >= 0: return player.peer_id
	return 0

## 준비된 봇 카드를 쓴다. 무효를 들었는데 막을 카드가 사라졌으면 내려놓는다.
func _bot_use(player: MatchPlayer, seat: int, type: int) -> void:
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
	_sync()

func modifiers(peer_id: int) -> Dictionary:
	var seat: int = peers.find(peer_id)
	return rules.dart_modifiers(seat) if seat >= 0 else {}

## 꽂히는 순간의 과녁(숫자 섞기·가림판)으로 기본 점수를 다시 센다. 날아가는 중에 쓴 과녁 카드도 그 다트에 걸린다.
## 벽·바닥(정규화 좌표 99)은 과녁 밖이라 0점이다.
func landing_points(hit: Dictionary) -> int:
	var player: MatchPlayer = controller.state.active_player()
	var aim := Vector2(float(hit.x), float(hit.y))
	if bool(modifiers(player.peer_id).get("cover", false)) and aim.x < 0: return 0
	return BoardScorer.score(aim, player.layout)

func score(base: int) -> Dictionary:
	var player: MatchPlayer = controller.state.active_player()
	var seat: int = peers.find(player.peer_id)
	var result: Dictionary = rules.resolve_dart(seat, base)
	var outcome: Dictionary = rules.apply_points(seat, int(result.points))
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
		player.card_effects = rules.dart_modifiers(seat)
