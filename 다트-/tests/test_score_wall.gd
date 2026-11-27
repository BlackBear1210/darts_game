extends SceneTree
## 과녁 벽 사람별 점수판(game/table/score_wall.gd): 사람 수만큼 판이 서고, 점수·차례·벌칙이 판에 그대로 보인다.
## 화면 왼쪽 위 점수 목록은 경기 중에 사라진다.
## [2026-11-27 사용자 요청] "점수를 따로 UI 로 표시하지 말고 맵에 각각의 점수판을 만든다" ·
## "누구 차례인지 확실하게" · "벌칙 받는 사람이 누군지도 잘 알려 달라".

## 판 한 장의 칸 번호(ScoreWall._plates): [뿌리, 판, 띠, 이름, 꼬리표, 점수].
const TAG_SLOT: int = 4
const SCORE_SLOT: int = 5

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
	assert(wall._plates.size() == state.players.size(), "사람 수만큼 판이 선다: %d" % wall._plates.size())
	# 점수가 판에 그대로 적힌다(자리 번호 순서).
	for index in range(state.players.size()):
		state.players[index].score = 10.0 * (index + 1)
	game._apply_state()
	var sorted: Array = state.players.duplicate()
	sorted.sort_custom(func(a: MatchPlayer, b: MatchPlayer) -> bool: return a.seat < b.seat)
	for index in range(sorted.size()):
		var shown: String = (wall._plates[index][SCORE_SLOT] as Label3D).text
		assert(shown == "%.0f" % sorted[index].score, "%d번 판 점수: %s" % [index, shown])

	# 지금 던지는 사람 판에는 "차례", 그 판만 앞으로 나온다.
	var active: MatchPlayer = state.active_player()
	assert(active != null)
	var lifted: int = 0
	for index in range(sorted.size()):
		var tag: String = (wall._plates[index][TAG_SLOT] as Label3D).text
		var root_node := wall._plates[index][0] as Node3D
		if root_node.position.z > wall.wall_z + ScoreWall.DEPTH + 0.001:
			lifted += 1
		if sorted[index].peer_id == active.peer_id:
			assert("차례" in tag, "지금 던지는 사람 판에는 차례 표시가 붙는다: %s" % tag)
		else:
			assert(tag.is_empty(), "나머지 판은 비어 있다: %s" % tag)
	assert(lifted == 1, "앞으로 나온 판은 지금 차례 하나뿐이다: %d장" % lifted)
	# 이름표에도 차례가 붙는다(점수판을 안 보고 있어도 알게).
	var actor := game.actors[active.peer_id] as PlayerView
	assert("차례" in actor._label.text, "지금 던지는 사람 이름표: %s" % actor._label.text)

	# 벌칙 라운드: 묶인 사람 판에 "벌칙"이 붙는다.
	var victim: MatchPlayer = sorted[sorted.size() - 1]
	state.punish_target = victim.peer_id
	game._apply_state()
	var victim_tag: String = (wall._plates[sorted.size() - 1][TAG_SLOT] as Label3D).text
	assert("벌칙" in victim_tag, "벌칙 대상 판: %s" % victim_tag)
	print("PASS: wall scoreboards per player, turn and punishment marked, HUD score list off during the match")
	quit()
