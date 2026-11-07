extends SceneTree
## 아수라장 다트 머신(2026-11-07) 판정 시험: "보이는 과녁 모양 = 점수"가 어긋나지 않는지 본다.
## 실행: godot --headless --path . --script res://tests/test_board_chaos.gd   (끝에 PASS 한 줄)
## 순수 계산(BoardChaos) → 과녁 그림(BoardView 회전·조각 자리·다트 붙이기) → 카드 목록 순서로 확인한다.

const BoardChaos = preload("res://game/board/board_chaos.gd")
const CardCatalog = preload("res://game/card_round/rules/card_catalog.gd")

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FAIL: " + message)


func _run() -> void:
	var layout := BoardLayout.new()
	# 1) 제자리: 모양이 그대로면 점수도 그대로다.
	var rest: Dictionary = BoardChaos.rest()
	for point: Vector2 in [Vector2.ZERO, Vector2(0, 0.3), Vector2(0.3, 0), Vector2(-0.45, -0.2), Vector2(0, 0.6)]:
		_check(BoardChaos.score(point, rest, layout) == BoardScorer.score(point, layout), "제자리 점수 %s" % point)
	# 2) 회전: 판이 angle 만큼 돌면 판 위의 점 q 는 화면에서 q.rotated(angle) 에 보인다 → 거기 꽂으면 q 의 점수.
	var spin: Dictionary = BoardChaos.pose(3.0, 1.0, -1.0, -1.0)
	_check(absf(float(spin.angle)) > 0.5, "3초 돌면 각도가 충분히 커야 한다")
	for q: Vector2 in [Vector2(0, 0.3), Vector2(0.3, 0), Vector2(0.2, -0.5), Vector2(0, 0.98)]:
		var seen: Vector2 = q.rotated(float(spin.angle))
		_check(BoardChaos.score(seen, spin, layout) == BoardScorer.score(q, layout), "회전 점수 %s" % q)
	# 반대 방향(두 번째 회전 카드)도 같은 식이다.
	var back_spin: Dictionary = BoardChaos.pose(3.0, -1.0, -1.0, -1.0)
	_check(is_equal_approx(float(back_spin.angle), -float(spin.angle)), "회전 방향 뒤집기")
	# 회전은 처음에 천천히 시작한다(덜컥 튀지 않게).
	_check(BoardChaos.spin_angle(0.1, 1.0) < BoardChaos.SPIN_SPEED * 0.1, "회전 시작이 부드럽다")
	# 3) 피자 분리: 조각 g 의 점 q 는 화면에서 q + 방향 × 벌어짐 에 보인다.
	var split: Dictionary = BoardChaos.pose(-1.0, 1.0, BoardChaos.SPLIT_OPEN, -1.0)
	_check(is_equal_approx(float(split.split), BoardChaos.SPLIT_MAX), "다 벌어지면 SPLIT_MAX")
	for sector in range(20):
		# 섹터 i 의 가운데 = 12시에서 시계 방향 i × 18°.
		var angle: float = sector * TAU / 20.0
		var q := Vector2(sin(angle), cos(angle)) * 0.45
		var group: int = BoardChaos.group_of(BoardLayout.sector_at(q))
		var seen: Vector2 = q + BoardChaos.group_direction(group) * float(split.split)
		_check(BoardChaos.score(seen, split, layout) == BoardScorer.score(q, layout), "분리 점수 섹터 %d" % sector)
	# 가운데 불은 제자리다.
	_check(BoardChaos.score(Vector2.ZERO, split, layout) == 50, "분리 중에도 불은 50")
	# 조각 사이 틈(조각 경계 방향, 반지름 0.5 — 벌어지면 비어 있는 곳)은 0점이다.
	var seam: float = 4.0 * TAU / 20.0 - TAU / 40.0
	var gap := Vector2(sin(seam), cos(seam)) * 0.5
	_check(not BoardChaos.locate(gap, split).is_finite(), "조각 틈은 0점(INF)")
	# 벌어지면 판 밖(반지름 1 너머)에도 조각이 있다 → 다트 판정 반지름이 넓어진다.
	_check(BoardChaos.reach(split) > 1.0, "분리 중 판정 반지름 > 1")
	var outer := Vector2(0, 0.98) + BoardChaos.group_direction(0) * float(split.split)
	_check(outer.length() > 1.0 and BoardChaos.score(outer, split, layout) == 40, "판 밖으로 나간 더블 칸도 점수")
	# 분리는 숨 쉬듯 좁혀졌다 벌어진다(계속 벌어져 있지 않다).
	var narrow: float = BoardChaos.split_amount(BoardChaos.SPLIT_OPEN + BoardChaos.SPLIT_PERIOD / 2.0)
	_check(narrow < BoardChaos.SPLIT_MAX * 0.5, "분리 주기 중간에는 좁혀진다")
	# 4) 셔터: 왼쪽 절반 0점, 오른쪽은 그대로. 회전·분리와 겹쳐도 셔터가 먼저다(머신에 고정).
	var all_on: Dictionary = BoardChaos.pose(2.0, 1.0, 2.0, 0.1)
	_check(bool(all_on.cover) and float(all_on.shutter) > 0.0 and float(all_on.shutter) < 1.0, "셔터 닫히는 중")
	_check(BoardChaos.score(Vector2(-0.3, 0.1), all_on, layout) == 0, "셔터 쪽 0점")
	_check(BoardChaos.score(Vector2(-0.3, 0.1), rest, layout) > 0, "셔터 없으면 왼쪽도 점수")
	_check(is_equal_approx(BoardChaos.shutter_amount(BoardChaos.SHUTTER_CLOSE), 1.0), "셔터 다 닫힘")
	# 5) 과녁 그림: 회전각·조각 자리가 pose 와 같고, 다트는 맞은 조각에 붙는다.
	var board := (load("res://game/board/board.tscn") as PackedScene).instantiate() as BoardView
	root.add_child(board)
	await process_frame
	var both: Dictionary = BoardChaos.pose(1.5, 1.0, BoardChaos.SPLIT_OPEN, -1.0)
	board.show_chaos(both)
	var spin_root := board.get_node("Face/Spin") as Node3D
	_check(is_equal_approx(spin_root.rotation.z, float(both.angle)), "그림 회전각 = pose")
	var group0 := spin_root.get_node("SectorGroup0") as Node3D
	var expected: Vector2 = BoardChaos.group_direction(0) * float(both.split) * BoardLayout.RADIUS
	_check(Vector2(group0.position.x, group0.position.y).is_equal_approx(expected), "조각 0 자리 = 방향 × 벌어짐")
	# 20번 칸(12시, 조각 0) 한가운데를 노려 꽂으면 조각 0 에 붙는다.
	var q20 := Vector2(0, 0.45)
	var seen20: Vector2 = (q20 + BoardChaos.group_direction(0) * float(both.split)).rotated(float(both.angle))
	_check(BoardChaos.score(seen20, both, layout) == 20, "회전+분리 겹쳐도 20점")
	var dart := Node3D.new()
	root.add_child(dart)
	_check(board.pin(dart, seen20) and dart.get_parent() == group0, "다트가 조각 0 에 붙는다")
	# 틈에 꽂힌 다트는 붙지 않는다(머신 뒤판 앞에 그대로 남는다).
	var loose := Node3D.new()
	root.add_child(loose)
	_check(not board.pin(loose, gap.rotated(float(both.angle))), "틈 다트는 붙지 않는다")
	# 숫자 섞기로 판을 다시 그려도 붙은 다트는 남는다.
	var shuffled := BoardLayout.new()
	shuffled.numbers = BoardLayout.DEFAULT_NUMBERS.duplicate()
	shuffled.numbers.reverse()
	board.show_layout(shuffled)
	await process_frame
	_check(is_instance_valid(dart) and dart.get_parent() == group0, "숫자 섞기 뒤에도 다트가 남는다")
	board.clear_pins()
	await process_frame
	_check(not is_instance_valid(dart), "차례가 바뀌면 붙은 다트를 지운다")
	board.queue_free()
	loose.queue_free()
	# 6) 카드: 회전판·피자 분리는 맨 뒤에 붙어 기존 카드 번호가 밀리지 않는다. 셔터는 예전 가림판 자리 그대로.
	_check(CardCatalog.type_of("cover") == 9, "셔터(가림판) 카드 번호 유지")
	_check(CardCatalog.type_of("board_spin") == CardCatalog.count() - 2 and CardCatalog.type_of("board_split") == CardCatalog.count() - 1, "새 카드는 맨 뒤")
	for id: String in ["board_spin", "board_split"]:
		var card: Dictionary = CardCatalog.card(CardCatalog.type_of(id))
		_check(int(card.category) == CardHandRules.Category.BOARD and int(card.timing) == CardCatalog.Timing.TURN, id + " = 과녁 · 차례 동안")
	await process_frame
	if _failed:
		print("FAIL: board chaos")
		quit(1)
		return
	print("PASS: board chaos — rest/spin/split/shutter scoring matches the drawn board, pins follow pieces, card ids kept")
	quit()
