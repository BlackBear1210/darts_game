extends SceneTree
## 서버의 중복 차단·손패 보존과 효과 설명 스냅샷을 실제 카드 사용 경로로 확인한다.
const Catalog = preload("res://game/card_round/rules/card_catalog.gd")
const Adapter = preload("res://game/match/match_cards.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for id: String in ["power_up", "special_dart", "cover", "drowsy", "board_spin", "board_split", "vertical_split", "horizontal_split", "board_move", "dizzy", "reverse"]:
		var controller := _controller()
		_use(controller, id)
		var before: int = controller.cards.rules.effects.size()
		_use(controller, id)
		assert(controller.cards.rules.effects.size() == before, "중복 효과를 만들지 않는다: " + id)
		assert(controller.state.players[1].hand.size() == 1, "거절된 카드는 손패에 남는다: " + id)
		assert(controller.state.players[1].pending_card == Catalog.type_of(id))
		assert(not Adapter.duplicate_reason(Catalog.type_of(id), controller.state.players[0].card_effects).is_empty())
		if id == "special_dart": controller.cards.score(20)
		controller.cards.end_dart_turn()
		assert(controller.state.players[0].card_effects.details.is_empty())
		assert(Adapter.duplicate_reason(Catalog.type_of(id), controller.state.players[0].card_effects).is_empty())
		controller.queue_free()
	var controller := _controller()
	for id: String in ["wind", "heavy_dart", "precision", "number_shuffle"]:
		_use(controller, id)
		assert(controller.state.players[1].hand.is_empty(), "중첩 또는 다시 섞기가 의미 있는 카드는 허용한다")
	var active: MatchPlayer = controller.state.players[0]
	assert(active.card_effects.details.filter(func(line: String) -> bool: return line.begins_with("바람 ")).size() > 0)
	assert(active.card_effects.details.has("무게 증가 · 이번 차례 끝까지"))
	assert(active.card_effects.details.has("+5 · 다음 한 발"))
	var restored := MatchState.from_snapshot(controller.state.to_snapshot())
	assert(restored.players[0].card_effects.details == active.card_effects.details, "다른 참가자에게도 효과·지속 범위를 전송한다")
	controller.cards.score(20)
	assert(active.card_effects.details.has("무게 증가 · 이번 차례 끝까지"))
	assert(active.card_effects.details.filter(func(line: String) -> bool: return line.begins_with("바람 ")).size() > 0)
	controller.queue_free()
	await process_frame
	print("PASS: duplicate-card preservation, meaningful stacking, effect duration labels, snapshot round-trip and next-dart expiry")
	quit()


func _controller() -> MatchController:
	var room := RoomState.new()
	room.settings.social_lobby = true
	room.add_player(1, "투척자")
	room.add_player(2, "방해자")
	var controller := MatchController.new()
	root.add_child(controller)
	controller.set_process(false)
	controller.configure(room, 1)
	controller.cards = Adapter.new(controller)
	controller.cards.begin_round()
	controller.state.phase = MatchState.Phase.AIMING
	controller.cards.begin_dart_turn()
	return controller


func _use(controller: MatchController, id: String) -> void:
	var rules: RefCounted = controller.cards.rules
	rules.seats[1].slots[0] = rules.new_card(Catalog.type_of(id))
	rules.seats[1].slots[0].choice = 0
	assert(rules.lift(1, 0, controller._now() - rules.READY_SECONDS - 0.1))
	controller.cards._sync()
	controller.cards.action(2, "use", 1)
