extends SceneTree
## 실제 진행 모델의 분기·발수·손패 7장 규칙·합동 라운드와 시연 씬 실행을 확인한다.

const Flow = preload("res://game/flow_preview/game_flow.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_hand_rules()
	for count in [2, 3, 4]:
		_check_match(count)
	var ranking := Flow.new()
	ranking.scores.assign([80, 120, 60, 100])
	var rows: Array[Dictionary] = ranking.standings()
	assert(rows[0].player == 4 and rows[0].rank == 1)
	assert(rows[1].rank == 2 and rows[2].rank == 2 and rows[3].rank == 4)
	var preview: Control = load("res://game/flow_preview/flow_preview.tscn").instantiate()
	root.add_child(preview)
	current_scene = preview
	await process_frame
	assert(preview.get_node("Content") != null)
	if OS.get_cmdline_user_args().has("--render"):
		preview._players.value = 4
		var folder := "res://.godot/flow_preview_render"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
		await _capture(folder + "/01_start.png")
		preview._act("next")
		preview._act("next")
		preview._act("next")
		while preview.flow.step != Flow.Step.CARD_CHOICE:
			preview._act("next")
		preview._act("skip")
		preview._act("next")
		preview._act(Flow.JAM_PREFIX + "1")
		await _capture(folder + "/02_aim.png")
		DisplayServer.window_set_size(Vector2i(960, 540))
		await create_timer(0.3).timeout
		await _capture(folder + "/03_small.png")
		while preview.flow.step != Flow.Step.FINISHED:
			var available: Dictionary = preview.flow.actions()
			preview._act("skip" if available.has("skip") else ("throw" if available.has("throw") else "next"))
		await _capture(folder + "/04_results.png")
	print("PASS: flow preview 2/3/4 players, hand 7 refill (unused = 0 drawn), 4 card types, own card + jam branches, joint round, cancel, target ranking, scene runtime")
	quit()


func _capture(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(path) == OK)


func _check_match(count: int) -> void:
	var flow := Flow.new()
	flow.player_count = count
	flow.round_limit = 2
	flow.joint_round = 2
	assert(not flow.act("throw"))
	var shots: int = 0
	var jams: int = 0
	var joints: int = 0
	var used_card: bool = false
	var visits: int = 0
	while flow.step != Flow.Step.FINISHED and visits < 2000:
		visits += 1
		match flow.step:
			Flow.Step.ORDER:
				# 첫 지급: 전원 7장.
				for index in range(count):
					assert(flow.hands[index].size() == CardHandRules.HAND_LIMIT and flow.last_drawn[index] == CardHandRules.HAND_LIMIT)
				assert(flow.act("next"))
			Flow.Step.JOINT_ROUND:
				joints += 1
				assert(flow.act("next"))
				for index in range(count):
					assert(flow.drunk[index] == joints)
			Flow.Step.CARD_CHOICE:
				var available: Dictionary = flow.actions()
				if used_card:
					assert(flow.act("skip"))
				else:
					var use_key: String = ""
					for key: String in available:
						if key.begins_with(Flow.USE_PREFIX):
							use_key = key
							break
					var before: int = flow.hands[flow.turn_index].size()
					assert(flow.act(use_key) and flow.act("next"))
					assert(flow.hands[flow.turn_index].size() == before - 1)
					used_card = true
			Flow.Step.AIM:
				var before: int = flow.throws_done
				var score: int = flow.scores[flow.turn_index]
				assert(flow.act("cancel"))
				assert(flow.step == Flow.Step.AIM and flow.throws_done == before)
				# 다음 사람이 방해 카드 1장 → 손패 1장 감소, 같은 발에 두 번은 불가.
				var jammer: int = (flow.turn_index + 1) % count
				var jammer_cards: int = flow.hands[jammer].size()
				assert(not flow.act(Flow.JAM_PREFIX + str(flow.turn_index)))
				assert(flow.act(Flow.JAM_PREFIX + str(jammer)))
				assert(flow.hands[jammer].size() == jammer_cards - 1)
				assert(not flow.act(Flow.JAM_PREFIX + str(jammer)))
				jams += 1
				assert(not flow.act("throw", 61) and flow.scores[flow.turn_index] == score)
				assert(flow.act("throw", 20))
				assert(not flow.act("throw", 20))
				shots += 1
			Flow.Step.ROUND_CARDS:
				assert(flow.act("next"))
				# 1라운드에서 P1 은 자기 카드 1장 + 방해 3장, 나머지는 방해 3장을 썼다 → 쓴 만큼만 받는다.
				for index in range(count):
					assert(flow.last_drawn[index] == (4 if index == 0 else 3))
					assert(flow.hands[index].size() == CardHandRules.HAND_LIMIT)
			_: assert(flow.act("next"))
	assert(visits < 2000 and flow.step == Flow.Step.FINISHED)
	assert(shots == count * 2 * 3 and jams == shots and joints == 1)
	for index in range(count):
		assert(flow.scores[index] == 120)
		# 2라운드에도 방해로 3장씩 썼고, 마지막 라운드 뒤에는 보충하지 않는다.
		assert(flow.hands[index].size() == CardHandRules.HAND_LIMIT - 3)
	assert(not flow.act("next"))
	flow.step = Flow.Step.CARD_CHOICE
	flow.hands[flow.turn_index].clear()
	assert(flow.actions().keys() == ["skip"])
	assert(not flow.act(Flow.USE_PREFIX + "0"))
	flow.reset()
	assert(flow.step == Flow.Step.START and flow.scores.is_empty() and flow.hands.is_empty() and flow.drunk.is_empty())


## 손패 규칙 단위 검사: 7장 채우기, 안 쓰면 0장, 쓴 만큼만 보충, 4종 범위, 없는 종류 사용 거부.
func _check_hand_rules() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 25
	var hand: Array[int] = []
	assert(CardHandRules.refill(hand, random) == 7 and hand.size() == 7)
	for category in hand:
		assert(category >= 0 and category < CardHandRules.CATEGORY_NAMES.size())
	assert(CardHandRules.refill(hand, random) == 0 and hand.size() == 7)
	var first: int = hand[0]
	assert(CardHandRules.take(hand, first) and hand.size() == 6)
	assert(CardHandRules.take(hand, hand[0]) and hand.size() == 5)
	assert(CardHandRules.refill(hand, random) == 2 and hand.size() == 7)
	var empty: Array[int] = []
	assert(not CardHandRules.take(empty, CardHandRules.Category.BOARD))
	var counts: Array[int] = [0, 0, 0, 0]
	for draw in range(4000):
		counts[CardHandRules.draw_category(random)] += 1
	for amount in counts:
		assert(amount > 800 and amount < 1200)
	assert(CardHandRules.summary([0, 0, 3] as Array[int]) == "연산2 다트0 과녁0 물리1")
