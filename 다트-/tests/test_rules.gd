extends SceneTree


func _initialize() -> void:
	var layout := BoardLayout.new()
	assert(BoardScorer.score(Vector2.ZERO, layout) == 50)
	assert(BoardScorer.score(Vector2(0, 0.06), layout) == 25)
	assert(BoardScorer.score(Vector2(0, 0.3), layout) == 20)
	assert(BoardScorer.score(Vector2(0, 0.60), layout) == 60)
	assert(BoardScorer.score(Vector2(0, 0.98), layout) == 40)
	assert(BoardScorer.score(Vector2(0, 1.01), layout) == 0)
	assert(BoardScorer.score(Vector2(0.3, 0), layout) == 6)
	assert(BoardScorer.score(Vector2(0, -0.3), layout) == 3)
	assert(BoardScorer.score(Vector2(-0.3, 0), layout) == 11)
	for boundary in [BoardLayout.INNER_BULL, BoardLayout.OUTER_BULL, BoardLayout.TRIPLE_INNER, BoardLayout.TRIPLE_OUTER, BoardLayout.DOUBLE_INNER]:
		assert(BoardScorer.score(Vector2(0, boundary - 0.0001), layout) != BoardScorer.score(Vector2(0, boundary + 0.0001), layout))
	var before := Vector2(sin(PI / 20.0 - 0.001), cos(PI / 20.0 - 0.001)) * 0.3
	var after := Vector2(sin(PI / 20.0 + 0.001), cos(PI / 20.0 + 0.001)) * 0.3
	assert(BoardScorer.score(before, layout) == 20 and BoardScorer.score(after, layout) == 1)
	# 반지름 경계는 불/특수 링에 포함, 각도 경계는 시계 방향 다음 섹터다.
	assert(BoardScorer.score(Vector2(0, BoardLayout.INNER_BULL), layout) == 50)
	assert(BoardScorer.score(Vector2(0, BoardLayout.OUTER_BULL), layout) == 25)
	assert(BoardScorer.score(Vector2(0, BoardLayout.TRIPLE_INNER), layout) == 60)
	assert(BoardScorer.score(Vector2(0, BoardLayout.TRIPLE_OUTER), layout) == 60)
	assert(BoardScorer.score(Vector2(0, BoardLayout.DOUBLE_INNER), layout) == 40)
	assert(BoardScorer.score(Vector2(0, 1), layout) == 40)
	assert(BoardScorer.score(Vector2.INF, layout) == 0)
	var player := MatchPlayer.new()
	player.peer_id = 1
	var bot := MatchPlayer.new()
	bot.peer_id = -1
	bot.is_bot = true
	var state := MatchState.new()
	state.players = [player, bot]
	var restored := MatchState.from_snapshot(state.to_snapshot())
	assert(restored.to_snapshot() == state.to_snapshot())
	var config := load("res://game/match/default_match.tres") as MatchConfig
	assert(config.rounds == 5 and config.darts_per_turn == 3 and config.turn_seconds == 20)
	var room := RoomState.new()
	room.add_player(1, "HOST")
	room.add_bots()
	assert(room.players.size() == 4)
	for identity in room.players:
		assert(identity.is_bot == (identity.peer_id < 0))
	assert(RoomState.from_snapshot(room.to_snapshot()).to_snapshot() == room.to_snapshot())
	print("PASS: standard board sectors, exact ring/angle boundaries, miss/nonfinite, human+bot snapshots, 5 rounds/three darts/20 seconds")
	quit()
