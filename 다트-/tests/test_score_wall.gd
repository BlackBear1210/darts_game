extends SceneTree
## 스냅샷이 벽면 영사막과 머신 헤더에 같은 점수·차례를 표시하는지 본다.
var main: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	main = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	var options := RoomSettings.new()
	options.social_lobby = true
	options.solo = true
	options.bot_count = 3
	main.session.host_room("테스터", 17761, options)
	var until: float = Time.get_ticks_msec() / 1000.0 + 10.0
	while Time.get_ticks_msec() / 1000.0 < until and main._game == null:
		await process_frame
	var game: GameView = main._game
	assert(game != null, "경기 화면이 열리지 않았다")
	# 라운지(경기 전)에서는 화면 점수 목록이 보인다.
	await create_timer(0.4).timeout
	assert(game.lounge_hud._scores.visible, "라운지에서는 화면 점수 목록을 띄운다")
	game.force_seat(1)
	await create_timer(0.3).timeout
	main.session.set_ready(true)
	until = Time.get_ticks_msec() / 1000.0 + 10.0
	while Time.get_ticks_msec() / 1000.0 < until and game.controller.state.phase != MatchState.Phase.AIMING:
		await process_frame
	var state: MatchState = game.controller.state
	assert(state.phase == MatchState.Phase.AIMING, "조준 단계까지 가지 못했다")
	await create_timer(0.4).timeout
	assert(not game.lounge_hud._scores.visible, "경기 중에는 화면 점수 목록을 빼고 맵 점수판만 쓴다")

	var wall: ScoreWall = game.table.scores
	assert(wall != null, "과녁 벽 점수판이 세워져야 한다")
	assert(wall.face.rows.size() == state.players.size())
	# 정수·반 점·음수를 같은 점수로 양쪽에 보내야 한다.
	for index in state.players.size():
		state.players[index].score = [128.5, -7.5, 0.0, 81.0][index]
	var active: MatchPlayer = state.active_player()
	game._apply_state()
	var sorted: Array = state.players.duplicate()
	sorted.sort_custom(func(a: MatchPlayer, b: MatchPlayer) -> bool: return a.seat < b.seat)
	var header = game.table.machine._cabinet.header
	for index in sorted.size():
		var player: MatchPlayer = sorted[index]
		var row := wall.face.rows[index]
		assert(row.label == player.display_name)
		assert(float(row.score) == player.score)
		assert(row.tag == ("차례" if player == active else ""))
		if player == active:
			assert(header.rows[0].score == row.score)
			assert(header.rows[0].label == player.display_name)
	assert(header.status == ("내 차례!" if active.peer_id == game.controller.local_peer_id else "이번 차례"))
	game.table.machine._caption_timer.timeout.emit()
	assert(header.status.is_empty() and not header.rows.is_empty())
	game._apply_state()
	assert(header.status.is_empty(), "같은 차례의 점수 갱신은 팝업을 다시 켜지 않는다")
	# 이름표에도 차례가 붙는다(점수판을 안 보고 있어도 알게).
	var actor := game.actors[active.peer_id] as PlayerView
	assert("차례" in actor._label.text, "지금 던지는 사람 이름표: %s" % actor._label.text)

	# 벌칙 라운드: 묶인 사람 판에 "벌칙"이 붙는다.
	var victim: MatchPlayer = sorted[sorted.size() - 1]
	state.punish_target = victim.peer_id
	game._apply_state()
	var victim_tag: String = wall.face.rows.back().tag
	assert("벌칙" in victim_tag, "벌칙 대상 판: %s" % victim_tag)
	state.phase = MatchState.Phase.FINISHED
	game._apply_state()
	assert(header.status.is_empty() and header.rows.is_empty())
	print("PASS: wall scoreboards per player, turn and punishment marked, HUD score list off during the match")
	quit()
