extends SceneTree
## 확정 카드 기획의 점수·형태·면적·라운드 상태 경계와 실제 경기 연결을 검증한다.
const Catalog = preload("res://game/card_round/rules/card_catalog.gd")
const Rules = preload("res://game/card_round/rules/round_rules.gd")
const Chaos = preload("res://game/board/board_chaos.gd")
const Adapter = preload("res://game/match/match_cards.gd")
var failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, reason: String) -> void:
	if not ok:
		failed = true
		push_error(reason)


func _rules() -> Rules:
	return Rules.new(["A", "B", "C"], [false, false, false], Rules.WinMode.ROUND_LIMIT, 12345)


func _use(rules: Rules, id: String, target: int = 0, choice: int = -1) -> Dictionary:
	rules.seats[0].slots[0] = rules.new_card(Catalog.type_of(id))
	rules.seats[0].slots[0].choice = choice
	rules.lift(0, 0, 0)
	return rules.use(0, target, 2)


func _math(rules: Rules, add: float, multiplier: float, label: String) -> void:
	var effect := Rules.Effect.new()
	effect.target = 0
	effect.kind = "math"
	effect.label = label
	effect.add = add
	effect.mul = multiplier
	effect.timing = Catalog.Timing.NEXT_DART
	rules.effects.append(effect)


func _run() -> void:
	var rules := _rules()
	_math(rules, -8, 1, "−8")
	_math(rules, 0, 3, "×3")
	_math(rules, 0, 0.5, "÷2")
	_check(rules.resolve_dart(0, 12).points == 6.0, "사용 순서: (12−8)×3÷2=6")
	_math(rules, -20, 1, "−20")
	_math(rules, 0, 2, "×2")
	_check(rules.resolve_dart(0, 5).points == -30.0, "음수에 배율 적용")
	_math(rules, 0, 1.0 / 3.0, "÷3")
	_check(is_equal_approx(rules.resolve_dart(0, 1).points, 0.3), "소수 한 자리 보존")
	_math(rules, 20, 1, "+20")
	_check(rules.resolve_dart(0, 0).points == 0 and rules.resolve_dart(0, 5).points == 5, "빗나가면 연산 소모")
	var countdown := _rules()
	countdown.win_mode = Rules.WinMode.COUNTDOWN
	countdown.seats[0].score = 0.3
	countdown.begin_turn(0)
	countdown.apply_points(0, 0.1)
	_check(countdown.apply_points(0, 0.2).win, "카운트다운 소수 누적 오차 없이 정확히 0")
	var operations: Array[int] = [0, 0, 0, 0]
	for trial in range(2000):
		rules.effects.clear()
		var result: Dictionary = _use(rules, "random_math")
		var effect: Rules.Effect = result.effect
		if effect.add > 0:
			operations[0] += 1
			_check(effect.add <= 20, "가산 범위")
		elif effect.add < 0:
			operations[2] += 1
			_check(effect.add >= -20, "감산 범위")
		elif effect.mul >= 1:
			operations[1] += 1
			_check(effect.mul <= 3, "배율 범위")
		else:
			operations[3] += 1
			_check(is_equal_approx(effect.mul, 0.5) or is_equal_approx(effect.mul, 1.0 / 3.0), "나누기 범위")
	for count in operations: _check(count > 400 and count < 600, "연산 종류별 25% 분포")
	_check(not Catalog.is_available(Catalog.type_of("plus_10")) and not Catalog.is_available(Catalog.type_of("times_2")) and not Catalog.is_available(Catalog.type_of("minus_20")), "삭제 카드 지급 제외")
	_check(CardHandRules.CATEGORY_NAMES.size() == 5 and Catalog.count() == 31, "28종 + 번호 보존용 삭제 카드 3칸")
	var layout := BoardLayout.new()
	layout.ring_multipliers = [3, 1, 2]
	layout.inner_bull_score = 59
	layout.outer_bull_score = 12
	_check(BoardScorer.score(Vector2.ZERO, layout) == 59, "내불 변경")
	_check(BoardScorer.score(Vector2(0, 0.08), layout) == 12, "외불 변경")
	_check(BoardScorer.score(Vector2(0, 0.4), layout) == 60 and BoardScorer.score(Vector2(0, 0.98), layout) == 20, "링 배수 역전")
	layout.blocked_sectors.append(0)
	_check(BoardScorer.score(Vector2(0, 0.98), layout) == 0, "봉쇄는 링 전체 0점")
	var restored := BoardLayout.new()
	restored.apply_snapshot(layout.to_snapshot())
	_check(restored.to_snapshot() == layout.to_snapshot(), "점수 표 스냅샷 왕복")
	layout.reset()
	var shape: Dictionary = Chaos.pose(1.2, -1, 1.0, -1, 1.5, 1.5, 0.75, Vector2.UP)
	var original := Vector2(0.35, 0.45)
	var shown: Vector2 = (original + Chaos.offset_at(original, shape)).rotated(shape.angle) + Vector2(shape.move)
	_check(Chaos.locate(shown, shape).distance_to(original) < 0.0001, "회전+피자+좌우+상하+이동 역변환")
	_check(is_equal_approx(Chaos.half_split_amount(1.5), 0.18) and is_equal_approx(Vector2(shape.move).length(), 0.25), "분리 1.5초·이동 진폭")
	var right_shutter: Dictionary = Chaos.pose(-1, 1, -1, 1, -1, -1, -1, Vector2.RIGHT, 1)
	_check(Chaos.score(Vector2(0.4, 0.1), right_shutter, layout) == 0 and Chaos.score(Vector2(-0.4, 0.1), right_shutter, layout) > 0, "오른쪽 셔터 판정")
	var random := RandomNumberGenerator.new()
	random.seed = 19
	_check(Chaos.area_result(Vector2.ZERO, Chaos.rest(), layout, random).points == 25, "큰 다트 중앙은 면적이 큰 외불, 최고점 선택 아님")
	_check(Chaos.area_result(Vector2(0, 0.4), Chaos.rest(), layout, random).points == 20, "구역 안 면적 채점")
	rules = _rules()
	_use(rules, "all_dizzy")
	rules.begin_turn(0)
	rules.end_turn()
	_check(rules.dart_modifiers(0).dizzy > 0 and rules.dart_modifiers(1).dizzy > 0, "전체 어지러움은 차례 종료 후에도 유지")
	rules.end_round()
	_check(rules.dart_modifiers(0).dizzy == 0 and rules.dart_modifiers(1).dizzy == 0, "라운드 종료 시 해제")
	rules = _rules()
	for slot in range(4): rules.seats[0].slots[slot] = rules.new_card(Catalog.type_of("wind"))
	for slot in range(7): rules.seats[1].slots[slot] = rules.new_card(Catalog.type_of("drowsy"))
	_use(rules, "hand_shuffle")
	_check(rules.hand_count(0) == 3 and rules.hand_count(1) == 7 and rules.hand_count(2) == 0, "손패 섞기는 사용 카드 제외 장수 유지")
	var seen_left: bool = false
	var seen_right: bool = false
	rules.begin_turn(1)
	for trial in range(40):
		rules.effects.clear()
		_use(rules, "wind", 1)
		seen_left = seen_left or rules.dart_modifiers(1).push < 0
		seen_right = seen_right or rules.dart_modifiers(1).push > 0
	_check(seen_left and seen_right, "바람은 양방향 추첨")
	var room := RoomState.new()
	room.settings.social_lobby = true
	room.add_player(1, "A")
	room.add_player(2, "B")
	var controller := MatchController.new()
	root.add_child(controller)
	controller.set_process(false)
	controller.configure(room, 1)
	controller.cards = Adapter.new(controller)
	controller.cards.begin_round()
	controller.state.phase = MatchState.Phase.AIMING
	controller.cards.begin_dart_turn()
	_match_use(controller, 1, "score_lock")
	var fixed: Dictionary = controller.state.players[0].layout.overrides.duplicate()
	_check(fixed.size() >= 5 and fixed.size() <= 20, "점수 고정 구역 수")
	controller.cards.end_dart_turn()
	controller.state.turn_index = 1
	controller.cards.begin_dart_turn()
	_check(controller.state.players[1].layout.overrides == fixed, "점수 고정은 다음 투척자에게도 유지")
	_match_use(controller, 0, "retry")
	_check(not controller.cards.rules.seats[0].retry_used, "남의 차례 재도전 거절")
	_match_use(controller, 1, "retry")
	controller._advance_turn()
	_check(controller.state.turn_index == 1 and controller.state.darts_left == 3, "재도전은 즉시 추가 3발")
	_match_use(controller, 1, "retry")
	_check(not controller.cards.rules.seats[1].extra_turn and controller.state.players[1].hand.size() == 1, "경기당 1회 초과는 손패 소모 없이 거절")
	_match_use(controller, 0, "sector_bid", 0)
	_check(controller.cards.score(0).points == -20, "구역 지목 실패는 미스에도 싱글 감점")
	_match_use(controller, 0, "sector_bid", 0)
	_check(controller.cards.score(20, {"hit_sectors": [0]}).points == 35, "구역 지목 성공 +15")
	controller.cards.begin_round()
	_check(controller.state.players[1].layout.overrides.is_empty(), "다음 라운드 점수 고정 해제")
	controller.state.turn_index = 0
	controller.cards.begin_dart_turn()
	var before_hit: float = controller.state.players[1].score
	controller.cards.disrupt(2)
	_check(controller.state.players[1].score == before_hit and float(controller.state.players[1].card_effects.dizzy) == 0.25, "카드 없는 피격은 보상 없이 라운드 어지러움")
	_check(int(controller.state.players[0].card_effects.hit_penalty) > 0, "투척자 벌도 적용")
	controller.cards.end_dart_turn()
	_check(int(controller.state.players[0].card_effects.hit_penalty) == 0, "투척자 벌은 차례 종료에 해제")
	controller.cards.begin_dart_turn()
	controller.solve_throw = func(aim: Vector2, _charge: float, _peer: int, speed: float = 1.0) -> Dictionary:
		return {"start": Vector3.ZERO, "target": Vector3(aim.x, aim.y, -1), "duration": 1.0, "x": aim.x, "y": aim.y, "points": 20, "speed": speed}
	_match_use(controller, 0, "special_dart")
	controller._launch(1, Vector2.ZERO, 0.5, 1)
	var flight_count: int = controller._pending_hit.flights.size()
	_check(flight_count in [2, 3] and controller._pending_hit.points == flight_count * 20, "특수 다트는 2~3개 실제 비행과 점수 합산")
	_match_use(controller, 0, "power_up")
	_check(controller._pending_hit.flights.size() == flight_count and is_equal_approx(controller._pending_hit.flights[0].speed, 1.3), "비행 중 힘 증가는 묶음 패턴 보존·속도 1.3배")
	_match_use(controller, 0, "dart_size")
	_check(controller._pending_hit.flights.all(func(flight: Dictionary) -> bool: return flight.large), "비행 중 크기 증가도 모든 다트에 반영")
	controller.queue_free()
	await process_frame
	print("FAIL: card plan" if failed else "PASS: card plan arithmetic, decimal wins, random distributions, score table, composed geometry, area, round lifetime and hand shuffle")
	quit(1 if failed else 0)


func _match_use(controller: MatchController, seat: int, id: String, choice: int = -1) -> void:
	var rules: Rules = controller.cards.rules
	rules.seats[seat].slots[0] = rules.new_card(Catalog.type_of(id))
	rules.seats[seat].slots[0].choice = choice
	rules.lift(seat, 0, controller._now() - Rules.READY_SECONDS - 0.1)
	controller.cards._sync()
	controller.cards.action(seat + 1, "use", controller.state.active_player().peer_id)
