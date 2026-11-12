extends SceneTree
## 실제 카드 사용 경로로 서로 다른 사용자의 협동·중복 보존·판정/스냅샷을 확인한다.
const Catalog = preload("res://game/card_round/rules/card_catalog.gd")
const Adapter = preload("res://game/match/match_cards.gd")
const Chaos = preload("res://game/board/board_chaos.gd")
var failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, reason: String) -> void:
	if not ok:
		failed = true
		push_error(reason)

func _controller() -> MatchController:
	var room := RoomState.new()
	room.settings.social_lobby = true
	for peer in range(1, 5): room.add_player(peer, "P%d" % peer)
	var controller := MatchController.new()
	root.add_child(controller)
	controller.set_process(false)
	controller.configure(room, 1)
	controller.cards = Adapter.new(controller)
	controller.cards._random.seed = 13
	controller.cards.begin_round()
	controller.state.phase = MatchState.Phase.AIMING
	controller.cards.begin_dart_turn()
	return controller

func _use(controller: MatchController, source: int, type: int) -> void:
	var rules: RefCounted = controller.cards.rules
	rules.seats[source].slots[0] = rules.new_card(type)
	rules.seats[source].slots[0].choice = 0
	rules.lift(source, 0, controller._now() - rules.READY_SECONDS - 0.1)
	controller.cards._sync()
	controller.cards.action(source + 1, "use", 1)

func _run() -> void:
	var count: int = 0
	for type in range(Catalog.count()):
		if not Catalog.supports_synergy(type): continue
		count += 1
		var controller := _controller()
		var kind: String = str(Catalog.card(type).effect)
		_use(controller, 1, type)
		var first: Dictionary = controller.cards.modifiers(1)
		_check(int(first.synergies[kind].players) == 1, kind + " 단독")
		var before: int = controller.cards.rules.effects.size()
		_use(controller, 1, type)
		_check(controller.cards.rules.effects.size() == before and controller.state.players[1].hand.size() == 1, kind + " 자기 중복 손패 보존")
		_use(controller, 2, type)
		var second: Dictionary = controller.cards.modifiers(1)
		_check(int(second.synergies[kind].players) == 2 and second.synergies[kind].factor == 1.5, kind + " 2인 강화")
		_use(controller, 3, type)
		var third: Dictionary = controller.cards.modifiers(1)
		_check(int(third.synergies[kind].players) == 3 and third.synergies[kind].factor == 2.0, kind + " 3인 강화")
		_check(third.synergies[kind].contributors == [2, 3, 4], kind + " 실제 사용자 ID 공개")
		var active: MatchPlayer = controller.state.players[0]
		_check(active.card_effects.details.any(func(line: String) -> bool: return "3인 시너지" in line), kind + " HUD 단계")
		var restored := MatchState.from_snapshot(controller.state.to_snapshot())
		_check(restored.players[0].card_effects == active.card_effects, kind + " 원격 스냅샷 일치")
		match kind:
			"wind": _check(is_equal_approx(absf(third.push), 0.64) and signf(first.push) == signf(third.push), "바람 방향 유지·2배")
			"heavy": _check(is_equal_approx(third.drop, 0.9), "낙하 2배")
			"drowsy": _check(third.drowsy_strength == 2.0, "졸림 오차 2배")
			"dizzy": _check(third.dizzy == 2.0, "어지러움 2배")
			"reverse": _check(third.reverse_axes == Vector2(-1, -1) and third.reverse_sensitivity == 1.35, "양축 반전·3인 감도")
			"ink_board": _check(active.layout.hidden_sectors.size() == 10, "먹물 총 10칸")
			"block_sector": _check(active.layout.blocked_sectors.size() == 3, "봉쇄 선택+양옆 3칸")
			"shuffle": _check(active.layout.hidden_sectors.size() == 5, "3인 숫자 섞기+먹물")
		controller.cards.end_dart_turn()
		if int(Catalog.card(type).timing) == Catalog.Timing.TURN:
			_check(not controller.cards.modifiers(1).synergies.has(kind), kind + " 차례 종료 초기화")
		controller.cards.begin_round()
		_check(controller.cards.modifiers(1).synergies.is_empty(), kind + " 라운드 종료 초기화")
		controller.queue_free()
	_check(count == 16, "방해카드 16종 모두 협동 가능")
	var base: Dictionary = Chaos.pose(1.5, 1, 1.5, 1.3, 1.5, 1.5, 0.75)
	var boosted: Dictionary = Chaos.boost(base, {"spin": 3, "split": 3, "vertical": 3, "horizontal": 3, "move": 3, "cover": 2})
	_check(is_equal_approx(boosted.angle, base.angle * 2) and is_equal_approx(boosted.split, base.split * 2), "회전/분리 실제 2배")
	_check(Vector2(boosted.move).is_equal_approx(Vector2(base.move) * 2) and boosted.cover_side == 1, "이동 2배·셔터 교대")
	var point := Vector2(0.35, 0.45)
	boosted.cover = false
	var shown: Vector2 = (point + Chaos.offset_at(point, boosted)).rotated(boosted.angle) + Vector2(boosted.move)
	_check(Chaos.locate(shown, boosted).distance_to(point) < 0.0001, "협동 변형도 그림과 판정 일치")
	var live := _controller()
	live.solve_throw = func(aim: Vector2, _charge: float, _peer: int, _speed: float = 1.0) -> Dictionary:
		return {"start": Vector3.ZERO, "target": Vector3(aim.x, aim.y, -1), "duration": 1.0, "x": aim.x, "y": aim.y, "points": 20}
	_use(live, 1, Catalog.type_of("drowsy"))
	live._launch(1, Vector2.ZERO, 1.0, 1)
	var first_offset := Vector2(live._pending_hit.x, live._pending_hit.y)
	_use(live, 2, Catalog.type_of("drowsy"))
	_check(Vector2(live._pending_hit.x, live._pending_hit.y).is_equal_approx(first_offset * 1.5), "비행 중 2인 졸림은 오차를 재추첨하지 않고 강화")
	_use(live, 3, Catalog.type_of("drowsy"))
	_check(Vector2(live._pending_hit.x, live._pending_hit.y).is_equal_approx(first_offset * 2.0), "비행 중 3인 졸림도 기존 오차 강화")
	live.queue_free()
	await process_frame
	print("FAIL: synergy" if failed else "PASS: 16 interference cards, distinct contributors, 2/3-player boosts, duplicate preservation, snapshots, lifetime and boosted geometry")
	quit(1 if failed else 0)
