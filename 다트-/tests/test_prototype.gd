extends SceneTree
## 실제 F5 시작 씬, 개발자 키, 서버 물리와 채점/비행 연계를 검증한다.

const BotDriver = preload("res://game/player/bot_driver.gd")

var _main: Node
var _game: GameView
var _hud: GameHUD

func _initialize() -> void:
	call_deferred("_run")

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	_hud._unhandled_input(event)

func _drive(axis: Vector2, duration: float, crouch: bool = false, jump: bool = false) -> void:
	var end: float = Time.get_ticks_msec() / 1000.0 + duration
	while Time.get_ticks_msec() / 1000.0 < end:
		_game.send_controls(axis, 0, 0, jump, crouch)
		jump = false
		await physics_frame
	if crouch:
		assert((_game.actors[1] as PlayerView).crouched)
	_game.send_controls(Vector2.ZERO, 0, 0, false, false)
	await physics_frame

## condition 이 참이 될 때까지 실제 물리 프레임을 기다린다. 제한시간을 넘기면 실패다.
func _wait_until(condition: Callable, seconds: float, label: String) -> void:
	var end: float = Time.get_ticks_msec() / 1000.0 + seconds
	while Time.get_ticks_msec() / 1000.0 < end:
		if condition.call():
			return
		await physics_frame
	assert(false, label)

func _run() -> void:
	_main = (load("res://app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await create_timer(0.3).timeout
	_game = _main.get_node("Game") as GameView
	_hud = _main.get_node("GameHUD") as GameHUD
	_game.set_process_unhandled_input(false)
	assert(_game.actors.size() == 4 and _game.controller.state.players.size() == 4)
	assert(_game.controller.config.turn_seconds == 20)
	var bots := _hud._bots()
	assert(bots.size() == 3)
	for bot in bots:
		assert(bot.position == TableView.SEATS[bot.identity.seat])
		assert(bot.velocity == Vector3.ZERO and bot.seated)
	assert(_hud._viewport.world_3d == _game.get_world_3d())
	assert(_hud._preview.visible and _hud._preview.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	assert(_hud._bot_camera.cull_mask & (1 << (bots[0].identity.seat + 1)) == 0)
	assert(_hud._bot_camera.cull_mask & 2 != 0)
	_key(KEY_F1)
	await create_timer(0.05).timeout
	assert(not _hud._preview.visible)
	_key(KEY_F1)
	_key(KEY_F2)
	await create_timer(0.05).timeout
	assert(_hud._bot_label.text.begins_with("봇 2"))
	_key(KEY_F4)
	assert(_game.controller.state.active_player().display_name == "봇 2")
	assert(_game.controller.remaining_seconds() > 19.8)
	# 봇은 자리에서 일어나 투척선까지 걸어가 3발을 던지고, 끝나면 자리로 돌아가 앉는다.
	var bot_two: PlayerView = null
	for bot in bots:
		if bot.identity.display_name == "봇 2":
			bot_two = bot
	assert(bot_two != null and _game.controller.state.active_player().peer_id == bot_two.identity.peer_id)
	var thrown: Array[Dictionary] = []
	_game.controller.dart_thrown.connect(func(data: Dictionary) -> void: thrown.append(data))
	var bot_turn: int = _game.controller.state.turn_id
	var turn_started: float = Time.get_ticks_msec() / 1000.0
	var spot: Vector3 = BotDriver.throw_spot()
	assert(spot.z > TableView.THROW_LINE_Z and spot.z < TableView.SEATS[bot_two.identity.seat].z)
	await _wait_until(func() -> bool: return not bot_two.seated, 2.0, "봇이 자리에서 일어나지 않았습니다.")
	await _wait_until(func() -> bool: return BotDriver.arrived(bot_two.position, spot), 8.0, "봇이 투척선까지 걸어오지 않았습니다.")
	await physics_frame
	# 투척선을 넘지 않고 과녁을 보고 선다.
	assert(bot_two.position.z > TableView.NO_ENTRY_Z and not bot_two.seated)
	assert(absf(angle_difference(bot_two.rotation.y, BotDriver.facing_board(bot_two.position))) < 0.05)
	await _wait_until(func() -> bool: return _game.controller.state.turn_id != bot_turn, 18.0, "봇의 차례가 끝나지 않았습니다.")
	# 3발을 모두 던졌고, 20초 시간 초과를 기다리지 않았다.
	assert(Time.get_ticks_msec() / 1000.0 - turn_started < _game.controller.config.turn_seconds)
	assert(thrown.size() == _game.controller.config.darts_per_turn)
	assert(_game.controller.state.last_hit.peer_id == bot_two.identity.peer_id)
	for data: Dictionary in thrown:
		# 판정 원점이 자리가 아니라 투척선이다.
		assert(BotDriver.arrived(Vector3(data.start.x, 0, data.start.z), spot))
	await _wait_until(func() -> bool: return bot_two.seated, 8.0, "봇이 자리로 돌아오지 않았습니다.")
	assert(bot_two.position == TableView.SEATS[bot_two.identity.seat])
	await _wait_until(func() -> bool: return _game.controller.state.phase == MatchState.Phase.AIMING, 10.0, "다음 차례가 시작되지 않았습니다.")
	_key(KEY_F4)
	var local := _game.actors[1] as PlayerView
	await _drive(Vector2(-1, 0), 0.25, true, true)
	assert(local.position.y > 0.1)
	assert(_game.controller.state.active_player().display_name == "봇 2")
	_key(KEY_F3)
	assert(_game.controller.state.phase == MatchState.Phase.SETTLING)
	assert(_game.controller.state.last_hit.points == 0)
	var revision: int = _game.controller.state.revision
	_key(KEY_F3)
	assert(_game.controller.state.revision == revision)
	await create_timer(1.1).timeout
	# 눈높이, 카메라 소유권과 제한 구역을 실제 서버 물리로 확인한다.
	await _drive(Vector2(0, -1), 3.0)
	assert(local.position.z >= -2.86 and local.position.y >= 0)
	_game.request_seat()
	assert(not local.seated)
	await _drive(Vector2(1, 0), 4.0)
	assert(local.position.x <= 5.56)
	await _drive(Vector2(0, 1), 4.0)
	assert(local.position.z <= 6.56)
	# 봇은 자기 차례에만 자리를 뜬다. 사람 차례로 되돌리고 모두 앉을 때까지 기다린다.
	_game.controller.state.turn_index = 0
	_game.controller._begin_turn()
	await _wait_until(func() -> bool: return bots.all(func(bot: PlayerView) -> bool: return bot.seated), 8.0, "봇이 모두 자리로 돌아오지 않았습니다.")
	for bot in bots:
		assert(bot.position == TableView.SEATS[bot.identity.seat])
	# 캐릭터가 경로에 있어도 레이 마스크 1은 캐릭터 레이어 2를 무시한다.
	var result: Dictionary = _game.solve_dart(Vector2.ZERO, 1)
	assert(result.points == 50 and result.target.is_equal_approx(TableView.BOARD_CENTER))
	assert(result.start.is_equal_approx(local.eye_position()))
	var remote_result: Dictionary = _game.solve_dart(Vector2.ZERO, 1, bots[0].identity.peer_id)
	assert(remote_result.start.is_equal_approx(bots[0].eye_position()))
	var blocker := bots[0]
	var original: Vector3 = blocker.position
	blocker.position = local.eye_position().lerp(TableView.BOARD_CENTER, 0.5)
	await physics_frame
	var with_blocker: Dictionary = _game.solve_dart(Vector2.ZERO, 1)
	assert(with_blocker == result)
	blocker.position = original
	var weak: Dictionary = _game.solve_dart(Vector2.ZERO, 0)
	assert(weak.points == 0)
	var outside: Dictionary = _game.solve_dart(Vector2(2, 0), 1)
	assert(outside.points == 0 and "벽" in outside.reason)
	var floor_hit: Dictionary = _game.solve_dart(Vector2(0, -15), 0)
	assert(floor_hit.points == 0 and "바닥" in floor_hit.reason)
	var limit: float = _game.throw_input.config.flight_limit
	_game.throw_input.config.flight_limit = 0.01
	var expired: Dictionary = _game.solve_dart(Vector2.ZERO, 1)
	assert(expired.points == 0 and "제한시간" in expired.reason)
	_game.throw_input.config.flight_limit = limit
	# 비행 중 F3/F4가 별도로 채점하거나 턴을 바꾸지 못한다.
	_game.controller.state.turn_index = 0
	_game.controller._begin_turn()
	assert(not local.seated)
	_game.controller.submit_throw(Vector2.ZERO, 1)
	assert(_game.controller.state.phase == MatchState.Phase.FLIGHT)
	revision = _game.controller.state.revision
	_key(KEY_F3)
	_key(KEY_F4)
	_game.controller.submit_throw(Vector2.ZERO, 1)
	assert(_game.controller.state.revision == revision)
	await create_timer(1.2).timeout
	assert(_game.controller.state.find_player(1).score == 50)
	assert(_game.controller.state.phase == MatchState.Phase.AIMING and _game.controller.state.darts_left == 2)
	var three_dart_turn: int = _game.controller.state.turn_id
	for dart_index: int in range(2):
		_game.controller.submit_throw(Vector2.ZERO, 1)
		await create_timer(1.2).timeout
		assert(_game.controller.state.find_player(1).score == (dart_index + 2) * 50)
		if dart_index == 0:
			assert(_game.controller.state.turn_id == three_dart_turn and _game.controller.state.darts_left == 1)
	assert(_game.controller.state.darts_left == 0)
	# 마감 시각과 요청이 겹쳐도 수락/실패 중 하나만 확정된다.
	_game.controller._land_dart()
	assert(_game.controller.state.find_player(1).score == 150)
	_game.controller._begin_turn()
	_game.controller._turn_end = _game.controller._now()
	_game.controller.submit_throw(Vector2.ZERO, 1)
	assert(_game.controller.state.phase == MatchState.Phase.AIMING)
	_game.controller._process(0)
	assert(_game.controller.state.phase == MatchState.Phase.SETTLING)
	_game.controller._process(0)
	assert(_game.controller.state.find_player(1).score == 150)
	_game.controller._begin_turn()
	_game.controller._turn_end = _game.controller._now() + 0.1
	_game.controller.submit_throw(Vector2.ZERO, 1)
	_game.controller._turn_end = _game.controller._now() - 1
	_game.controller._process(0)
	assert(_game.controller.state.phase == MatchState.Phase.FLIGHT)
	await create_timer(1.2).timeout
	assert(_game.controller.state.find_player(1).score == 200)
	# 라운드 사이 테이블 집합: 제한시간 안에 앉지 않으면 자동 착석 + 다음 라운드 슬로우. 봇은 늘 앉아 있다.
	var controller := _game.controller
	controller.config.table_seconds = 0.3
	controller.state.turn_index = 3
	controller.state.round_number = 1
	controller._begin_turn()
	controller._timeout_turn()
	controller._advance_turn()
	assert(controller.state.phase == MatchState.Phase.TABLE and controller.state.round_number == 2)
	assert(controller.state.turn_index == 0 and not local.seated)
	await create_timer(0.5).timeout
	assert(controller.state.phase == MatchState.Phase.AIMING and local.seated)
	assert(local.position == TableView.SEATS[local.identity.seat])
	assert(controller.state.find_player(1).speed_scale == controller.config.slow_speed_scale)
	for bot in bots:
		assert(bot.identity.speed_scale == 1.0)
	assert("지각" in controller.notice and "[슬로우]" in _hud._score.text)
	# 슬로우는 방장의 실제 이동 속도에 적용된다.
	_game.request_seat()
	assert(not local.seated)
	_game.send_controls(Vector2(1, 0), 0, 0, false, false)
	await physics_frame
	await physics_frame
	assert(is_equal_approx(Vector2(local.velocity.x, local.velocity.z).length(), PlayerView.SPEED * controller.config.slow_speed_scale))
	_game.send_controls(Vector2.ZERO, 0, 0, false, false)
	# 다음 집합이 시작되면 슬로우가 풀리고, 전원 앉아 있으면 기다리지 않고 바로 다음 라운드다.
	_game.force_seat(1)
	controller.state.turn_index = 3
	controller._begin_turn()
	controller._timeout_turn()
	controller._advance_turn()
	assert(controller.state.find_player(1).speed_scale == 1.0)
	controller._process(0)
	assert(controller.state.phase == MatchState.Phase.AIMING and controller.state.round_number == 3)
	# 마지막 차례 이탈은 다음 라운드 첫 차례가 되고, 종료 후 이탈은 경기를 재개하지 않는다.
	var room: RoomState = _main.get_node("NetworkSession").room
	_game.controller.state.turn_index = 3
	_game.controller.state.round_number = 1
	_game.controller._begin_turn()
	room.remove_player(-3)
	_game.controller.sync_roster(room)
	assert(_game.controller.state.round_number == 2 and _game.controller.state.turn_index == 0)
	_game.controller.state.phase = MatchState.Phase.FINISHED
	room.remove_player(-2)
	_game.controller.sync_roster(room)
	assert(_game.controller.state.phase == MatchState.Phase.FINISHED)
	# 순위 시험을 위해 제거한 참가자 데이터를 복원한다.
	for id: int in [-2, -3]:
		var player := MatchPlayer.new()
		player.peer_id = id
		player.display_name = "봇 %d" % -id
		_game.controller.state.players.append(player)
	# 동점은 공동 순위, 다음 순위는 인원 수만큼 건너뛴다.
	_game.controller.state.players[0].score = 50
	_game.controller.state.players[1].score = 50
	_game.controller.state.players[2].score = 20
	_game.controller.state.players[3].score = 0
	var ranking: String = _hud.ranking_text()
	assert(ranking.count("1위") == 2 and "3위" in ranking and "4위" in ranking)
	_main.get_node("NetworkSession").leave_room()
	await process_frame
	assert(_main.get_node("Lobby").visible and _main.get_node_or_null("Game") == null)
	print("PASS: F5 human+3 bots, shared-world viewport/masks, F1/F2/F3/F4, jump/crouch, floor/wall/protected zone, seating distance, host ballistic hits/misses/limit, blocker ignored, bot walks to the oche and throws three darts then returns to its seat, deadline race, table gathering auto-seat + slow, active/finished departure, duplicate/flight lock, joint ranking, menu return")
	_main.queue_free()
	await process_frame
	quit()
