extends SceneTree
## 실제 진행 모델의 분기·발수·카드 수량과 시연 씬 실행을 확인한다.

const Flow = preload("res://game/flow_preview/game_flow.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
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
		await _capture(folder + "/02_aim.png")
		DisplayServer.window_set_size(Vector2i(960, 540))
		await create_timer(0.3).timeout
		await _capture(folder + "/03_small.png")
		while preview.flow.step != Flow.Step.FINISHED:
			var available: Dictionary = preview.flow.actions()
			preview._act("skip" if available.has("skip") else ("throw" if available.has("throw") else "next"))
		await _capture(folder + "/04_results.png")
	print("PASS: flow preview 2/3/4 players, all throws/rounds, card branches, cancel, exchange guards, target ranking, scene runtime")
	quit()


func _capture(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(path) == OK)


func _check_match(count: int) -> void:
	var flow := Flow.new()
	flow.player_count = count
	flow.round_limit = 2
	assert(not flow.act("throw"))
	var shots: int = 0
	var exchanges: int = 0
	var used_card: bool = false
	var visits: int = 0
	while flow.step != Flow.Step.FINISHED and visits < 1000:
		visits += 1
		match flow.step:
			Flow.Step.CARD_CHOICE:
				assert(flow.act("skip" if used_card else "use"))
				used_card = true
			Flow.Step.AIM:
				var before: int = flow.throws_done
				var score: int = flow.scores[flow.turn_index]
				assert(flow.act("cancel"))
				assert(flow.step == Flow.Step.AIM and flow.throws_done == before)
				assert(not flow.act("throw", 61) and flow.scores[flow.turn_index] == score)
				assert(flow.act("throw", 20))
				assert(not flow.act("throw", 20))
				shots += 1
			Flow.Step.EXCHANGE:
				var before: int = flow.hands[flow.turn_index]
				assert(flow.act("exchange"))
				assert(flow.hands[flow.turn_index] == before - 1)
				assert(not flow.act("exchange"))
				exchanges += 1
				assert(flow.act("next"))
			_: assert(flow.act("next"))
	assert(visits < 1000 and flow.step == Flow.Step.FINISHED)
	assert(shots == count * 2 * 3 and exchanges == count)
	for index in range(count):
		assert(flow.scores[index] == 120)
		assert(flow.hands[index] == (2 if index == 0 else 3))
	assert(not flow.act("next"))
	flow.step = Flow.Step.CARD_CHOICE
	flow.hands[flow.turn_index] = 0
	assert(not flow.act("use"))
	flow.step = Flow.Step.EXCHANGE
	flow.exchanged = false
	flow.hands[flow.turn_index] = 1
	assert(not flow.act("exchange"))
	flow.reset()
	assert(flow.step == Flow.Step.START and flow.scores.is_empty() and flow.hands.is_empty())
