extends SceneTree
## 카드 라운드 시연(game/card_round/) 검사.
## 1) 규칙 계산: 한 바퀴씩 나눠 주기·뽑는 위치·7장 보충·꺼내기 대기·사용·무효·점수 연산·승리 조건 3종·방해 보상·순위/골드.
## 2) 씬 실행(-- --play): 봇 4명(내 자리도 자동)으로 끝까지 빠르게 진행해 실행 오류가 없는지.
## 3) 화면(-- --render): 실제 렌더 장면을 output/card_round/ 에 저장한다(디자인 피드백용, 창이 뜬다).
## 실행: godot --headless --path . --script res://tests/test_card_round.gd [-- --play]
##       godot --path . --script res://tests/test_card_round.gd -- --render

const Rules = preload("res://game/card_round/rules/round_rules.gd")
const CardCatalog = preload("res://game/card_round/rules/card_catalog.gd")

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_deal_and_draw()
	_check_lift_and_use()
	_check_scoring()
	_check_turn_effects()
	_check_win_modes()
	_check_disrupt_and_ranking()
	var args := OS.get_cmdline_user_args()
	if args.has("--play") or args.has("--render"):
		await _check_scene(args.has("--render"))
	if failures == 0:
		print("PASS: card round rules (round-robin deal, top/middle/bottom draw, refill to 7, ready wait, use/nullify, math order, turn effects, 3 win modes, disrupt reward, ranking/gold)%s" % (" + scene" if args.has("--play") or args.has("--render") else ""))
	# 합성음 재생이 남은 채 바로 끝나면 누수 경고가 날 수 있어 잠깐 기다린다.
	await create_timer(0.2, true, false, true).timeout
	quit(1 if failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)


func _rules(mode: int = Rules.WinMode.ROUND_LIMIT) -> Rules:
	var names: Array[String] = ["가", "나", "다", "라"]
	var bots: Array[bool] = [false, true, true, true]
	return Rules.new(names, bots, mode, 1234)


func _give(rules: Rules, seat: int, slot: int, id: String) -> void:
	rules.seats[seat].slots[slot] = rules.new_card(CardCatalog.type_of(id))


func _check_deal_and_draw() -> void:
	var rules := _rules()
	rules.fill_deck()
	_check(rules.deck.size() == Rules.DECK_SIZE, "덱 40장")
	_check(rules.draw_index(Rules.DrawFrom.TOP) == 39 and rules.draw_index(Rules.DrawFrom.BOTTOM) == 0, "위=39 아래=0")
	_check(rules.draw_index(Rules.DrawFrom.MIDDLE) == 20, "중간=20")
	var plan: Array[Vector2i] = rules.deal_plan()
	_check(plan.size() == 28, "처음엔 4명 × 7장 = 28장")
	_check(plan[0] == Vector2i(0, 0) and plan[1] == Vector2i(1, 0) and plan[3] == Vector2i(3, 0) and plan[4] == Vector2i(0, 1), "한 사람에 한 장씩 한 바퀴")
	for step in plan:
		rules.place(step.x, step.y, rules.take_from_deck(rules.draw_index(Rules.DrawFrom.TOP)))
	_check(rules.deck.size() == 12, "28장을 뽑으면 12장 남음")
	for seat in range(4):
		_check(rules.hand_count(seat) == 7, "모두 7장")
	# 0번은 2장, 2번은 7장 다 썼고, 1·3번은 안 썼다 → 0번 2장, 2번 7장만 받는다.
	rules.seats[0].slots[2] = null
	rules.seats[0].slots[5] = null
	for slot in range(7):
		rules.seats[2].slots[slot] = null
	plan = rules.deal_plan()
	_check(plan.size() == 9, "쓴 만큼만 보충(2 + 7)")
	_check(plan[0] == Vector2i(0, 2) and plan[1] == Vector2i(2, 0) and plan[2] == Vector2i(0, 5) and plan[3] == Vector2i(2, 1), "보충도 한 바퀴씩, 빈 칸 순서")
	var refilled: Array[int] = [0, 0, 0, 0]
	for step in plan:
		refilled[step.x] += 1
	_check(refilled == [2, 0, 7, 0], "안 쓴 사람은 0장")


func _check_lift_and_use() -> void:
	var rules := _rules()
	_give(rules, 0, 0, "plus_10")
	_give(rules, 0, 1, "times_0")
	_give(rules, 1, 3, "times_2")
	_check(rules.lift(0, 0, 0.0), "카드 꺼내기")
	_check(not rules.use_problem(0, 0, 0.5).is_empty(), "대기 시간 전에는 못 쓴다")
	var used: Dictionary = rules.use(0, 0, 1.3)
	_check(not used.is_empty() and used.slot == 0, "대기 후 사용")
	_check(rules.seats[0].slots[0] == null and rules.seats[0].pending == null, "쓴 카드는 손·테이블 칸에서 빠진다")
	var effect: Rules.Effect = used.effect
	_check(effect.state == Rules.EffectState.QUEUED and effect.label == "+10", "효과는 다음 다트까지 대기")
	# 무효: 꺼내 든 상대가 없으면 못 쓴다 → 상대가 꺼내면 그 카드를 없앤다.
	rules.lift(0, 1, 2.0)
	_check(rules.use_problem(0, 1, 4.0) == "카드를 꺼내 든 상대가 없다", "무효는 꺼내 든 상대가 필요")
	rules.lift(1, 3, 4.0)
	var counter: Dictionary = rules.use(0, 1, 4.0)
	_check(not counter.is_empty() and counter.cancelled != null and counter.cancelled_slot == 3, "무효가 상대 카드를 없앤다")
	_check(rules.seats[1].slots[3] == null and rules.seats[1].pending == null, "무효 당한 카드도 테이블 칸에서 빠진다")
	var lost: int = 0
	for item in rules.effects:
		lost += 1 if item.state == Rules.EffectState.NULLIFIED else 0
	_check(lost == 1, "무효 당한 카드도 기록된다")


func _check_scoring() -> void:
	var rules := _rules()
	_give(rules, 0, 0, "plus_10")
	_give(rules, 0, 1, "times_2")
	for slot in [0, 1]:
		rules.lift(0, slot, 0.0)
		rules.use(0, 0, 2.0)
	rules.begin_turn(0)
	var hit: Dictionary = rules.resolve_dart(0, 20)
	_check(hit.points == 50, "곱하기 먼저, 더하기 나중: 20 ×2 +10 = 50 (실제 %d)" % hit.points)
	_check(rules.resolve_dart(0, 20).points == 20, "다음 다트 효과는 한 번만")
	_give(rules, 1, 0, "minus_20")
	rules.lift(1, 0, 0.0)
	rules.use(1, 0, 2.0)
	_check(rules.resolve_dart(0, 15).points == 0, "빼기는 0점 아래로 안 내려간다")
	_give(rules, 0, 2, "plus_10")
	rules.lift(0, 2, 0.0)
	rules.use(0, 0, 2.0)
	_check(rules.resolve_dart(0, 0).points == 0, "빗나가면 0점")
	_check(rules.resolve_dart(0, 5).points == 5, "빗나간 다트가 연산을 써 버렸다")


func _check_turn_effects() -> void:
	var rules := _rules()
	_give(rules, 0, 0, "number_shuffle")
	_give(rules, 0, 1, "drowsy")
	rules.lift(0, 0, 0.0)
	rules.use(0, 2, 2.0)
	_check(rules.effects[0].state == Rules.EffectState.QUEUED, "차례 효과는 대상 차례를 기다린다")
	rules.begin_turn(2)
	_check(rules.effects[0].state == Rules.EffectState.ACTIVE and rules.dart_modifiers(2).shuffle, "대상 차례가 되면 켜진다")
	rules.lift(0, 1, 2.0)
	rules.use(0, 2, 4.0)
	_check(rules.effects[1].state == Rules.EffectState.ACTIVE and rules.dart_modifiers(2).drowsy, "대상 차례 중에 쓰면 바로 켜진다")
	_check(not rules.dart_modifiers(1).shuffle, "다른 사람에게는 안 걸린다")
	rules.end_turn()
	_check(rules.effects[0].state == Rules.EffectState.DONE and not rules.dart_modifiers(2).shuffle, "차례가 끝나면 꺼진다")


func _check_win_modes() -> void:
	var countdown := _rules(Rules.WinMode.COUNTDOWN)
	_check(countdown.seats[0].score == 500, "500에서 시작")
	countdown.seats[0].score = 40
	countdown.begin_turn(0)
	countdown.apply_points(0, 30)
	_check(countdown.seats[0].score == 10, "맞힌 만큼 뺀다")
	var bust: Dictionary = countdown.apply_points(0, 20)
	_check(bust.bust and countdown.seats[0].score == 40 and countdown.darts_left == 0, "0 아래 = 버스트, 차례 시작 점수로 되돌림")
	countdown.begin_turn(0)
	_check(countdown.apply_points(0, 40).win and countdown.finished and countdown.winners == [0], "정확히 0 = 우승")
	var target := _rules(Rules.WinMode.TARGET_SCORE)
	target.target_score = 100
	target.seats[2].score = 90
	target.begin_turn(2)
	_check(not target.apply_points(2, 5).win and target.apply_points(2, 5).win and target.winners == [2], "목표 점수 도달 = 우승")
	var limit := _rules(Rules.WinMode.ROUND_LIMIT)
	limit.round_limit = 2
	limit.seats[1].score = 70
	limit.seats[3].score = 70
	limit.end_round()
	_check(not limit.finished, "1라운드 끝은 계속")
	limit.next_round()
	limit.end_round()
	_check(limit.finished and limit.winners == [1, 3], "마지막 라운드 최고점(공동 우승)")


func _check_disrupt_and_ranking() -> void:
	var rules := _rules()
	rules.reward_mode = Rules.RewardMode.ROUND_CARD
	var reward: Dictionary = rules.disrupt(1)
	_check(reward.kind == "card" and reward.card.temporary and rules.hand_count(1) == 1, "방해 보상: 라운드 한정 카드")
	rules.disrupt(1)
	rules.disrupt(1)
	_check(rules.seats[1].reward.size() == Rules.RESERVE_SLOTS and rules.seats[1].score == Rules.DISRUPT_SCORE, "예약 칸이 차면 점수로")
	var vanished: Array = rules.end_round()
	_check(vanished.size() == 2 and rules.seats[1].reward.is_empty(), "라운드 한정 카드는 라운드 끝에 사라진다")
	rules.reward_mode = Rules.RewardMode.SCORE
	rules.seats[0].score = 50
	rules.seats[1].score = 80
	rules.seats[2].score = 80
	rules.seats[3].score = 10
	_check(rules.ranking() == [1, 2, 0, 3], "순위: 점수 높은 순, 동점은 자리 순")
	_check(rules.rank_of(1) == 0 and rules.rank_of(2) == 0 and rules.rank_of(0) == 2, "동점 = 같은 순위")
	_check(rules.loser() == 3, "꼴찌 = 벌칙 대상")
	rules.award_gold()
	_check(rules.seats[1].gold == 100 + 3 * Rules.GOLD_PER_DISRUPT and rules.seats[2].gold == 100 and rules.seats[3].gold == 20, "골드: 순위 + 방해 성공")


## 씬을 실제로 돌린다. 모든 자리를 자동(봇)으로 두고 시간을 빠르게 해 끝까지 간다.
func _check_scene(render: bool) -> void:
	var scene: Node = load("res://game/card_round/card_round.tscn").instantiate()
	scene.set("autoplay", true)
	scene.set("persist_settings", false)
	if render:
		root.size = Vector2i(1920, 1080)
		scene.set("capture_folder", ProjectSettings.globalize_path("res://").path_join("../output/card_round").simplify_path())
	root.add_child(scene)
	current_scene = scene
	var limit_seconds: float = 900.0
	var waited: float = 0.0
	# 2026-10-28: 카드 턴 단계가 돌고, 다트 중에는 카드를 낼 수 없어야 한다.
	var saw_card_turn: bool = false
	var cards_open_in_darts: bool = false
	# is_instance_valid: 장면이 도중에 다시 시작되면(설정 창 "새 게임") 옛 장면이 지워진다 → 오류로 멈추지 않고 실패로 알린다(2026-10-28).
	while is_instance_valid(scene) and not bool(scene.get("game_over")) and waited < limit_seconds:
		var ctx: Object = scene.get("ctx")
		if ctx != null:
			saw_card_turn = saw_card_turn or str(ctx.get("phase")) == "card_turn"
			cards_open_in_darts = cards_open_in_darts or (str(ctx.get("phase")) == "darts" and bool(ctx.get("cards_open")))
		await create_timer(0.5, true, false, true).timeout
		waited += 0.5
	_check(is_instance_valid(scene), "씬이 도중에 다시 시작되지 않았다")
	if not is_instance_valid(scene):
		return
	_check(bool(scene.get("game_over")), "씬이 끝까지 진행된다(%.0f초)" % waited)
	_check(saw_card_turn, "카드 턴 단계가 돈다(자리 순서대로 한 장씩)")
	_check(not cards_open_in_darts, "다트 중에는 카드를 낼 수 없다")
	var stats: Dictionary = scene.get("stats")
	_check(int(stats.get("dealt", 0)) >= 28, "처음에 28장 이상 나눠 줌")
	_check(int(stats.get("used", 0)) >= 1, "카드가 한 장 이상 쓰였다")
	_check(int(stats.get("darts", 0)) >= 12, "다트를 던졌다")
	_check(bool(stats.get("refilled_to_7", false)), "충전 라운드 뒤 모두 7장")
	# 2026-10-28 방해선: 봇(자동 진행이면 내 자리도)은 구역을 옆길로 돌아가야 한다 → 구역에 부딪혀 되돌려진 적이 없어야 한다.
	_check(int(stats.get("zone_bumps", -1)) == 0, "차례 아닌 사람이 던지는 칸 근처 구역에 들어가지 않았다")
	print("SCENE STATS ", stats)
	scene.queue_free()
	await process_frame
