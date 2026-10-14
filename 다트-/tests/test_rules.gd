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
	var player := MatchPlayer.new()
	player.peer_id = 1
	player.bonus = 10
	player.multiplier = 2
	assert(player.score_hit(20) == 50 and player.score_hit(0) == 0)
	player.clear_effects()
	assert(player.score_hit(20) == 20)
	var other := MatchPlayer.new()
	other.peer_id = 2
	var state := MatchState.new()
	state.players = [player, other]
	var cards := CardController.new()
	cards.begin(state.players)
	var private_data := cards.private_snapshot(1)
	assert(private_data.candidates.size() == 3)
	assert(not state.to_snapshot().has("candidates"))
	var ids: Array[int] = []
	for candidate: Dictionary in private_data.candidates: ids.append(candidate.uid)
	for candidate: Dictionary in cards.private_snapshot(2).candidates: assert(not ids.has(candidate.uid))
	var bonus_index: int = 0
	for index in range(3):
		if private_data.candidates[index].kind == CardDefinition.Kind.BONUS: bonus_index = index
	assert(cards.choose(player, bonus_index, 3))
	assert(not cards.choose(player, 0, 3))
	var card := player.hand[0]
	assert(not cards.plan_use(player, card.uid, 2, state))
	assert(cards.plan_use(player, card.uid, 1, state))
	cards.finish(state, 3)
	assert(player.bonus == 10 and player.hand.is_empty() and other.hand.size() == 1)
	player.clear_effects()
	var random := RandomNumberGenerator.new()
	random.seed = 42
	player.layout.shuffle_with(random)
	var sorted := player.layout.numbers.duplicate()
	sorted.sort()
	assert(sorted == range(1, 21))
	var restored := MatchState.from_snapshot(state.to_snapshot())
	assert(restored.to_snapshot() == state.to_snapshot())
	print("PASS: bull/rings/angle/miss boundaries, score effects, card ownership/privacy/default, shuffled layout, snapshot roundtrip")
	quit()
