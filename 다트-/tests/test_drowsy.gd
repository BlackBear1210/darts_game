extends SceneTree
## 실제 F5 카드 사용 → 투척 계산 경로. 한 발의 졸림 오차는 비행 재계산에도 유지돼야 한다.
const Catalog = preload("res://game/card_round/rules/card_catalog.gd")
const Adapter = preload("res://game/match/match_cards.gd")
const Preferences = preload("res://ui/player_preferences.gd")

var _aims: Array[Vector2] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var controller := _controller()
	var aim := Vector2(0.1, 0.1)
	controller._launch(1, aim, 1.0, 1)
	assert(_aims.back().is_equal_approx(aim), "졸림이 없으면 조준을 바꾸지 않는다")
	# 이미 날아가는 다트에 졸림을 쓴 경우에도 궤적을 즉시 바꿔야 한다.
	_use(controller, "drowsy")
	assert(_aims.size() == 2, "비행 중 졸림 사용은 궤적을 재계산한다")
	var first: Vector2 = _aims.back()
	assert(not first.is_equal_approx(aim), "졸림이 실제 투척 조준에 적용된다")
	assert(absf(first.x - aim.x) <= Catalog.DROWSY_AIM_SPREAD)
	assert(absf(first.y - aim.y) <= Catalog.DROWSY_AIM_SPREAD)
	controller.redirect_flight()
	assert(_aims.back().is_equal_approx(first), "같은 한 발의 오차를 다시 뽑지 않는다")
	_use(controller, "wind")
	assert(_aims.back().is_equal_approx(first + Vector2(float(controller.cards.modifiers(1).push), 0)), "바람과 겹쳐도 졸림 오차는 유지한다")
	_use(controller, "drowsy")
	assert(_aims.back().is_equal_approx(first + Vector2(float(controller.cards.modifiers(1).push), 0)), "졸림 중복 사용은 같은 한 발의 오차를 재추첨하지 않는다")
	controller.cards.end_dart_turn()
	controller._launch(1, aim, 1.0, 2)
	assert(_aims.back().is_equal_approx(aim), "차례 종료 후 졸림과 바람이 남지 않는다")
	controller.queue_free()

	# 조준 중 사용과 다음 발의 새 오차, 화면 효과 OFF도 같은 판정을 유지하는지 확인한다.
	controller = _controller()
	_use(controller, "drowsy")
	var saved_visual_effects: bool = Preferences.visual_effects
	Preferences.visual_effects = false
	controller._launch(1, aim, 1.0, 1)
	first = _aims.back()
	assert(not first.is_equal_approx(aim), "화면 효과를 꺼도 졸림의 조준 오차는 유지한다")
	controller._launch(1, aim, 1.0, 2)
	assert(not _aims.back().is_equal_approx(first), "다음 발은 새로운 오차를 적용한다")
	Preferences.visual_effects = saved_visual_effects
	controller.queue_free()
	await process_frame
	print("PASS: F5 drowsy aim spread, mid-flight use, stable redirect, wind stacking, turn expiry, next dart and visual-effects-off")
	quit()


func _controller() -> MatchController:
	_aims.clear()
	var room := RoomState.new()
	room.settings.social_lobby = true
	room.add_player(1, "투척자")
	room.add_player(2, "방해자")
	var controller := MatchController.new()
	root.add_child(controller)
	controller.set_process(false)
	controller.configure(room, 1)
	controller._random.seed = 20261111
	controller.solve_throw = func(aim: Vector2, _charge: float, _peer: int, _speed: float = 1.0) -> Dictionary:
		_aims.append(aim)
		return {"start": Vector3.ZERO, "target": Vector3(aim.x, aim.y, -1), "duration": 10.0, "x": aim.x, "y": aim.y, "points": 20}
	controller.cards = Adapter.new(controller)
	controller.cards.begin_round()
	controller.state.phase = MatchState.Phase.AIMING
	controller.state.darts_left = 3
	controller.cards.begin_dart_turn()
	return controller


func _use(controller: MatchController, id: String) -> void:
	var rules: RefCounted = controller.cards.rules
	# 방해자의 손패를 준비한 뒤 실제 카드 사용 진입점으로 사용한다.
	rules.seats[1].slots[0] = rules.new_card(Catalog.type_of(id))
	assert(rules.lift(1, 0, controller._now() - rules.READY_SECONDS - 0.1))
	controller.cards._sync()
	controller.cards.action(2, "use", 1)
