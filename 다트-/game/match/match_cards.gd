extends RefCounted
## 기존 카드 시연의 순수 규칙을 방장 경기로 연결한다. 카드 효과 계산은 RoundRules 한 곳에 둔다.
const Rules = preload("res://game/card_round/rules/round_rules.gd")
const Catalog = preload("res://game/card_round/rules/card_catalog.gd")
var controller: MatchController
var rules: RefCounted
var peers: Array[int] = []
var turn_position: int = 0
var card_order: Array[int] = []
var _bot_at: float = 0.0

func _init(owner: MatchController) -> void:
	controller = owner
	var names: Array[String] = []
	var bots: Array[bool] = []
	for player in owner.state.players:
		peers.append(player.peer_id)
		names.append(player.display_name)
		bots.append(player.is_bot)
	rules = Rules.new(names, bots)
	var settings: RoomSettings = owner.room_settings
	rules.win_mode = [Rules.WinMode.ROUND_LIMIT, Rules.WinMode.TARGET_SCORE, Rules.WinMode.COUNTDOWN][settings.win_mode]
	rules.target_score = settings.target_score
	for index in range(peers.size()):
		if settings.win_mode == 2: owner.state.players[index].score = settings.target_score
		rules.seats[index].score = owner.state.players[index].score

func begin_round() -> void:
	rules.effects.clear()
	rules.turn_position = -1
	card_order.clear()
	for player in controller.state.players:
		var seat: int = peers.find(player.peer_id)
		card_order.append(seat)
		var slots: Array = rules.seats[seat].slots
		for index in range(slots.size()): slots[index] = null
		for index in range(player.hand.size()): slots[index] = rules.new_card(player.hand[index])
		rules.seats[seat].pending = null
	rules.order.assign(card_order)
	turn_position = 0
	_next_turn()

func _next_turn() -> void:
	if turn_position >= card_order.size():
		controller.state.card_peer = 0
		controller._begin_turn()
		return
	controller.state.card_peer = peers[card_order[turn_position]]
	var player: MatchPlayer = controller.state.find_player(controller.state.card_peer)
	if player == null:
		turn_position += 1
		_next_turn()
		return
	_bot_at = controller._now() + 1.0
	controller.notice = "%s의 카드 턴 · 1–7 선택 → Enter 사용 / 선택 없이 Enter 패스" % player.display_name
	controller._set_phase(MatchState.Phase.CARDS, 3.5 if player.is_bot else controller.room_settings.card_seconds)
	_sync()

func tick() -> void:
	var player: MatchPlayer = controller.state.find_player(controller.state.card_peer)
	if player == null or controller._now() >= controller._phase_end:
		advance()
		return
	if player.is_bot and controller._now() >= _bot_at:
		var seat: int = peers.find(player.peer_id)
		if rules.seats[seat].pending != null:
			var targets: Array[int] = rules.valid_targets(seat, rules.seats[seat].pending.type)
			targets = targets.filter(func(t: int) -> bool: return controller.state.find_player(peers[t]) != null)
			if not targets.is_empty(): action(player.peer_id, "use", peers[targets[0]])
			else: advance()
		else:
			var index: int = 0
			while index < player.hand.size() and int(Catalog.card(player.hand[index]).target) == Catalog.Target.COUNTER: index += 1
			if index < player.hand.size():
				action(player.peer_id, "select", index)
				_bot_at = controller._now() + Rules.READY_SECONDS + 0.1
			else: advance()

func action(sender: int, action_name: String, value: int) -> void:
	if controller.state.phase != MatchState.Phase.CARDS: return
	var player: MatchPlayer = controller.state.find_player(sender)
	var seat: int = peers.find(sender)
	if player == null or seat < 0: return
	if action_name == "select":
		if value < 0 or value >= player.hand.size(): return
		var type: int = player.hand[value]
		if sender != controller.state.card_peer and int(Catalog.card(type).target) != Catalog.Target.COUNTER: return
		# 공유 손패는 압축 배열, 규칙 손패는 빈 칸을 유지한다. 실제 카드 슬롯으로 변환한다.
		var occupied: Array[int] = []
		for index in range(Rules.HAND_SLOTS):
			if rules.seats[seat].slots[index] != null: occupied.append(index)
		if value >= occupied.size(): return
		rules.lift(seat, occupied[value], controller._now())
	elif action_name == "pass":
		if sender != controller.state.card_peer: return
		advance()
		return
	elif action_name == "use":
		var pending = rules.seats[seat].pending
		if pending == null: return
		var target_type: int = int(Catalog.card(pending.type).target)
		if sender != controller.state.card_peer and target_type != Catalog.Target.COUNTER: return
		var target: int = seat if target_type == Catalog.Target.SELF else peers.find(value)
		if target < 0 or controller.state.find_player(peers[target]) == null: return
		var result: Dictionary = rules.use(seat, target, controller._now())
		if result.is_empty(): return
		controller.add_feed(controller.feed_entry("card", player, str(Catalog.card(result.card.type).big), controller.state.find_player(peers[target])))
		_sync()
		if sender == controller.state.card_peer: advance()
		return
	_sync()
	controller._publish()

func advance() -> void:
	var seat: int = peers.find(controller.state.card_peer)
	if seat >= 0: rules.lower(seat)
	turn_position += 1
	_sync()
	_next_turn()

func begin_dart_turn() -> void:
	var active: MatchPlayer = controller.state.active_player()
	if active == null: return
	var seat: int = peers.find(active.peer_id)
	rules.begin_turn(rules.order.find(seat))
	var mods: Dictionary = rules.dart_modifiers(seat)
	active.layout.reset()
	if mods.shuffle: active.layout.numbers.shuffle()
	_sync()

func end_dart_turn() -> void:
	rules.end_turn()
	_sync()

func modifiers(peer_id: int) -> Dictionary:
	var seat: int = peers.find(peer_id)
	return rules.dart_modifiers(seat) if seat >= 0 else {}

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
		player.pending_card = rules.seats[seat].pending.type if rules.seats[seat].pending != null else -1
		player.card_effects = rules.dart_modifiers(seat)
