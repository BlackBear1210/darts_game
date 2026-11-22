extends SceneTree
## 방해 카드 밸런스(2026-11-22): "방해 카드가 맞는 사람을 도와주면 안 된다".
##
## 협동 시너지를 없앤 뒤 실제로 재 보니 점수 랜덤 변경이 상대 점수를 +44% 올려 주고 있었고
## (링 배수까지 무작위로 바꿔 가장 넓은 싱글 링이 평균 ×2 가 됐다), 점수 고정도 높은 값이 걸리면 도움이 됐다.
## 무게 증가는 0.45 만 밀려 ±0% 였다(아래로만 밀면 과녁이 위아래로 대칭이라 점수가 안 깎인다).
## 여기서는 같은 조준 묶음을 던져 평균 점수를 재고, 고친 수치가 되돌아가지 않게 지킨다.
const Catalog = preload("res://game/card_round/rules/card_catalog.gd")
## 사람 손떨림을 흉내낸 조준(과녁 반지름 1 기준)과 표본 수. 수를 늘리면 정확해지고 느려진다.
const SAMPLES: int = 200
const AIM_SPREAD: float = 0.22

var main: Node
var controller: MatchController
var cards: RefCounted
var _aims: Array[Vector2] = []


func _initialize() -> void:
	_run.call_deferred()


## 지금 걸린 효과로 SAMPLES 발을 던진 평균 점수. 움직이는 과녁은 나이를 흩어 공평하게 본다.
func _average() -> float:
	var total: float = 0.0
	var now: float = controller._now()
	for i in range(_aims.size()):
		for kind: String in cards._chaos_from.keys():
			cards._chaos_from[kind] = now - fmod(float(i) * 0.37, 6.0)
		controller._flight_input = {}
		total += float(cards.landing_points(controller._solve(1, _aims[i], 1.0)))
	return total / float(_aims.size())


## 카드를 rounds 번 새로 걸어 평균(쓸 때마다 무작위인 카드가 있다).
func _with_card(card_id: String, rounds: int) -> float:
	var total: float = 0.0
	for attempt in range(rounds):
		controller.developer_clear_effects()
		var problem: String = controller.developer_card(1, Catalog.type_of(card_id), 0)
		assert(problem.is_empty(), "%s 를 못 씀: %s" % [card_id, problem])
		total += _average()
	controller.developer_clear_effects()
	return total / float(rounds)


func _run() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 20261122
	for i in range(SAMPLES):
		_aims.append(Vector2(random.randfn(0.0, AIM_SPREAD), random.randfn(0.0, AIM_SPREAD)).limit_length(1.0))
	main = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	var options := RoomSettings.new()
	options.social_lobby = true
	options.solo = true
	options.bot_count = 3
	main.session.host_room("테스터", 17698, options)
	await create_timer(0.8).timeout
	main._game.force_seat(1)
	await create_timer(0.3).timeout
	main.session.set_ready(true)
	var until: float = Time.get_ticks_msec() / 1000.0 + 12.0
	while Time.get_ticks_msec() / 1000.0 < until and (main._game == null or main._game.controller.state.phase != MatchState.Phase.CARDS):
		await process_frame
	controller = main._game.controller
	cards = controller.cards
	main.set_developer_mode(true)
	controller._phase_end = controller._now()
	await create_timer(0.3).timeout
	for peer in cards._bot_plans.keys():
		cards._bot_plans[peer] = -1.0
	var local := main._game.actors[1] as PlayerView
	local.seated = false
	local.position = Vector3(0, 0, TableView.THROW_LINE_Z + 0.4)
	await create_timer(0.3).timeout
	assert(controller.state.phase == MatchState.Phase.AIMING and controller.state.active_player().peer_id == 1)

	controller.developer_clear_effects()
	var base: float = _average()
	assert(base > 5.0, "카드 없이 평균 %.1f점 — 조준 묶음이 과녁을 벗어났습니다" % base)

	# 1) 무게 증가: 0.45 로는 ±0% 였다. 지금 값은 눈에 띄게 깎여야 한다(실측 -19%).
	assert(float(Catalog.card(Catalog.type_of("heavy_dart")).drop) >= 0.7, "무게 증가 drop 이 너무 작으면 점수가 안 깎인다")
	var heavy: float = _with_card("heavy_dart", 1)
	assert(heavy < base * 0.92, "무게 증가가 점수를 깎아야 한다: %.1f → %.1f" % [base, heavy])

	# 2) 봉쇄 구역: 고른 칸 + 양옆 세 칸이 0점이 된다.
	var block: float = _with_card("sector_block", 3)
	assert(block < base, "봉쇄 구역이 점수를 깎아야 한다: %.1f → %.1f" % [base, block])

	# 3) 점수 랜덤 변경: 링 배수는 건드리지 않는다(여기서 +44% 가 났다). 불도 기본보다 높아지지 않는다.
	for attempt in range(8):
		controller.developer_clear_effects()
		assert(controller.developer_card(1, Catalog.type_of("score_random"), 0).is_empty())
		var layout: BoardLayout = controller.state.find_player(1).layout
		assert(layout.ring_multipliers == [1, 2, 3], "링 배수를 바꾸면 방해 카드가 상대를 도와준다: %s" % [layout.ring_multipliers])
		assert(layout.inner_bull_score <= 50 and layout.outer_bull_score <= 25, "불 점수가 기본보다 높아지면 안 된다")

	# 4) 점수 고정: 낮은 값으로만 고정한다(높은 값이면 상대를 도와준다).
	for attempt in range(8):
		controller.developer_clear_effects()
		assert(controller.developer_card(1, Catalog.type_of("score_lock"), 0).is_empty())
		for region in controller.state.find_player(1).layout.overrides:
			assert(int(controller.state.find_player(1).layout.overrides[region]) <= 6, "고정 값이 높으면 방해가 아니다")
	var lock: float = _with_card("score_lock", 3)
	assert(lock < base, "점수 고정이 점수를 깎아야 한다: %.1f → %.1f" % [base, lock])

	controller.developer_clear_effects()
	main.queue_free()
	await process_frame
	print("PASS: disruption cards lower the target's average score (base %.1f / heavy %.1f / block %.1f / lock %.1f), and random/lock never buff the board" % [base, heavy, block, lock])
	quit()
