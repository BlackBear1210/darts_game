extends SceneTree
## 경기 끝 꼴찌 벌칙(과녁판에 묶기)과 토큰 규칙(2026-11-23 사용자 요청).
## 화면·네트워크 없이 진행기(MatchController)와 순수 규칙만 돌린다.

const BoardVictim = preload("res://game/board/board_victim.gd")
const PlayerWallet = preload("res://app/player_wallet.gd")
const PlayerOutfit = preload("res://art/characters/player_outfit.gd")
const BoardChaos = preload("res://game/board/board_chaos.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_body_shape()
	_token_rules()
	_price_table()
	_wallet_buying()
	await _spin_control()
	await _punish_flow()
	await _punish_disabled()
	await _two_players()
	print("PASS: 꼴찌 벌칙(과녁판) 진행·명중 판정·토큰 보상")
	quit()


## 묶인 몸이 판 위에서 차지하는 자리. 팔은 판정하지 않는다.
func _body_shape() -> void:
	assert(BoardVictim.hit(Vector2(0.0, BoardVictim.HEAD_Y)), "머리 한가운데는 맞는다")
	assert(BoardVictim.hit(Vector2(0.0, 0.0)), "가슴은 맞는다")
	assert(BoardVictim.hit(Vector2(0.0, BoardVictim.FEET_Y + 0.01)), "발밑도 몸이다")
	assert(not BoardVictim.hit(Vector2(0.0, BoardVictim.FEET_Y - 0.05)), "발끝보다 아래는 빗나감")
	assert(not BoardVictim.hit(Vector2(0.9, 0.0)), "벌린 팔 쪽(몸통 밖)은 빗나감")
	assert(not BoardVictim.hit(Vector2(0.0, BoardVictim.HEAD_Y + BoardVictim.HEAD_RADIUS + 0.05)), "머리 위는 빗나감")
	assert(not BoardVictim.hit(Vector2.INF), "판에 안 꽂힌 발은 빗나감")
	# 몸은 과녁 뒤판(BoardArt.BACKING_RATIO) 안에 들어가야 던질 수 있다.
	assert(BoardVictim.HEAD_Y + BoardVictim.HEAD_RADIUS < BoardView.BoardArt.BACKING_RATIO, "머리가 뒤판 밖으로 나가면 맞힐 수 없다")
	assert(absf(BoardVictim.FEET_Y) < BoardView.BoardArt.BACKING_RATIO, "발도 뒤판 안")


## 사용자 확정 규칙: 1등 +10 · 2등 +5 · 3등 0 · 꼴찌는 벌칙에서 맞은 횟수 × 3 차감(빚도 가능).
func _token_rules() -> void:
	assert(PlayerWallet.match_reward(1, false, 0) == 10, "1등 +10")
	assert(PlayerWallet.match_reward(2, false, 0) == 5, "2등 +5")
	assert(PlayerWallet.match_reward(3, false, 0) == 0, "3등 0")
	assert(PlayerWallet.match_reward(4, false, 0) == 0, "벌칙을 안 받은 4등은 0")
	assert(PlayerWallet.match_reward(4, true, 0) == 0, "한 대도 안 맞으면 깎이지 않는다")
	assert(PlayerWallet.match_reward(4, true, 1) == -3, "한 대 = −3")
	assert(PlayerWallet.match_reward(4, true, 6) == -18, "여섯 대 = −18")
	assert(PlayerWallet.match_reward(2, true, 2) == -6, "3인·2인 경기의 꼴찌도 같은 규칙")


## 값표는 꾸미기 칸 목록과 길이가 같아야 한다(물건을 늘릴 때 둘 다 고치게).
func _price_table() -> void:
	for slot: Array in PlayerOutfit.SLOTS:
		var key: String = slot[0]
		assert(PlayerWallet.PRICES.has(key), "값표에 없는 꾸미기 칸: %s" % key)
		var prices: Array = PlayerWallet.PRICES[key]
		assert(prices.size() == (slot[2] as Array).size(), "%s 의 값 개수가 물건 수와 다르다" % key)
		assert(int(prices[0]) == 0, "%s 의 0번(없음·기본)은 공짜여야 한다" % key)


func _wallet_buying() -> void:
	PlayerWallet.loaded = true
	PlayerWallet.owned.clear()
	PlayerWallet.tokens = 12
	assert(PlayerWallet.owns("hat", 0), "없음은 늘 쓸 수 있다")
	assert(not PlayerWallet.owns("hat", 4), "실크햇은 처음엔 잠겨 있다")
	assert(not PlayerWallet.buy("hat", 4), "30토큰짜리를 12토큰으로는 못 산다")
	assert(PlayerWallet.tokens == 12, "못 산 뒤에도 토큰은 그대로")
	assert(PlayerWallet.buy("hat", 2), "10토큰짜리 야구 모자는 산다")
	assert(PlayerWallet.tokens == 2 and PlayerWallet.owns("hat", 2), "산 만큼 줄고 쓸 수 있다")
	PlayerWallet.tokens = -5
	assert(not PlayerWallet.buy("eyes", 1), "빚진 상태로는 못 산다")
	assert(PlayerWallet.owns("hat", 2), "빚을 져도 이미 산 것은 남는다")
	# 산 적 없는 물건은 차림에서 빠진다.
	var clamped: Dictionary = PlayerWallet.clamp_look({"hat": 4, "eyes": 2})
	assert(int(clamped.hat) == 0 and int(clamped.eyes) == 0, "안 산 물건은 '없음'으로 되돌린다")


## 묶인 사람이 A·D 로 판 돌리는 방향을 바꾼다. 가속이 있어 곧바로 뒤집히지 않는다.
func _spin_control() -> void:
	var controller := _controller()
	controller.state.players[3].score = -10.0
	controller._begin_punish()
	var loser: int = controller.state.punish_target
	assert(controller.state.punish_dir == 1, "처음엔 오른쪽으로 돈다")
	# 1초 굴리면 기본 속도에 닿고 각도가 그만큼 는다.
	for step in range(60):
		controller._tick_punish_spin(1.0 / 60.0)
	assert(is_equal_approx(controller.state.punish_spin, MatchController.PUNISH_SPIN_SPEED), "1초면 기본 속도에 닿는다")
	var turned: float = controller.state.punish_angle
	assert(turned > 0.0, "오른쪽 방향이면 각도가 는다")

	# 묶인 사람만 방향을 바꿀 수 있다.
	controller._accept_punish_spin(loser + 1, -1)
	assert(controller.state.punish_dir == 1, "묶이지 않은 사람이 보낸 방향은 무시한다")
	controller._accept_punish_spin(loser, -1)
	assert(controller.state.punish_dir == -1, "묶인 사람은 방향을 바꿀 수 있다")

	# 방향을 바꾼 직후에도 한동안은 원래 방향으로 돈다(홱 뒤집히지 않는다).
	controller._tick_punish_spin(0.2)
	assert(controller.state.punish_spin > 0.0, "0.2초 뒤에도 아직 원래 방향 · 실제 %.2f" % controller.state.punish_spin)
	assert(controller.state.punish_angle > turned, "그 사이에도 같은 쪽으로 더 돈다")
	for step in range(60):
		controller._tick_punish_spin(1.0 / 60.0)
	assert(controller.state.punish_spin < 0.0, "1초 뒤에는 반대로 돈다 · 실제 %.2f" % controller.state.punish_spin)

	# 다 돌아선 각도로 판정한다 — 몸이 돌면 같은 자리를 노려도 빗나간다.
	controller.state.punish_angle = 0.0
	assert(BoardVictim.hit(BoardChaos.locate(Vector2(0, 0.8), BoardChaos.spun(0.0))), "제자리면 머리에 맞는다")
	assert(not BoardVictim.hit(BoardChaos.locate(Vector2(0, 0.8), BoardChaos.spun(PI / 2.0))), "90도 돌면 같은 자리는 빗나간다")
	controller.queue_free()
	await process_frame


## 4인 경기: 꼴찌가 묶이고 나머지 셋이 2발씩 던진다. 맞은 발만 센다.
func _punish_flow() -> void:
	var controller := _controller()
	var scores: Array[float] = [50.0, 30.0, 70.0, 10.0]
	for index in range(4):
		controller.state.players[index].score = scores[index]
	var loser: MatchPlayer = controller.state.players[3]
	controller._begin_punish()
	assert(controller.state.punish_target == loser.peer_id, "점수가 가장 낮은 사람이 묶인다")
	assert(loser.darts == 0, "묶인 사람은 던지지 않는다")
	assert(controller.state.active_player().peer_id != loser.peer_id, "묶인 사람 차례는 건너뛴다")
	for player in controller.state.players:
		if player.peer_id != loser.peer_id:
			assert(player.darts == 2, "4인 = 한 사람 2발")
	# 셋이 2발씩: 첫 발은 가슴(명중), 둘째 발은 판 밖(빗나감).
	var thrown: int = 0
	while controller.state.phase != MatchState.Phase.FINISHED and thrown < 20:
		assert(controller.state.active_player().peer_id != loser.peer_id, "벌칙 중 묶인 사람 차례가 오면 안 된다")
		var aim := Vector2(0.0, 0.0) if thrown % 2 == 0 else Vector2(3.0, 3.0)
		_land(controller, aim)
		thrown += 1
		await process_frame
	assert(controller.state.phase == MatchState.Phase.FINISHED, "한 바퀴를 다 돌면 경기가 끝난다")
	assert(thrown == 6, "총 6발이어야 한다(3명 × 2발) · 실제 %d발" % thrown)
	assert(loser.punish_hits == 3, "가슴에 꽂힌 3발만 센다 · 실제 %d" % loser.punish_hits)
	assert(controller.state.punish_target == loser.peer_id, "결과 화면이 읽도록 묶였던 사람은 남긴다")
	assert(PlayerWallet.match_reward(4, true, loser.punish_hits) == -9, "3대 맞았으니 −9")
	controller.queue_free()
	await process_frame


## 벌칙을 끈 방은 바로 결과 화면으로 간다.
func _punish_disabled() -> void:
	var controller := _controller()
	controller.room_settings.punishment = false
	controller._begin_punish()
	assert(controller.state.phase == MatchState.Phase.FINISHED, "벌칙을 끄면 바로 끝난다")
	assert(controller.state.punish_target == 0, "묶인 사람이 없다")
	controller.queue_free()
	await process_frame


## 2인 경기: 던지는 사람이 하나뿐이라 혼자 6발 던진다(벌칙 길이를 비슷하게).
func _two_players() -> void:
	var controller := _controller(2)
	controller.state.players[0].score = 40.0
	controller.state.players[1].score = 5.0
	controller._begin_punish()
	assert(controller.state.players[1].darts == 0, "꼴찌는 던지지 않는다")
	assert(controller.state.players[0].darts == 6, "2인이면 혼자 6발 · 실제 %d" % controller.state.players[0].darts)
	controller.queue_free()
	await process_frame


## 한 발을 그 자리에 꽂은 셈 치고 방장 판정을 돌린다. 회전각이 0 인 순간으로 맞춰 자리를 예측할 수 있게 한다.
func _land(controller: MatchController, aim: Vector2) -> void:
	controller.state.punish_angle = 0.0
	assert(is_zero_approx(float(controller.chaos_shape().angle)) or controller.state.phase not in MatchController.DART_PHASES, "각도를 0 으로 맞춘 판")
	controller._pending_hit = {"x": aim.x, "y": aim.y, "points": 0, "request_id": 1, "reason": ""}
	# MatchController._launch 가 던질 때 줄이는 값(여기서는 비행을 건너뛰므로 직접 줄인다).
	controller.state.darts_left -= 1
	controller.state.active_player().darts = maxi(controller.state.active_player().darts - 1, 0)
	controller.state.phase = MatchState.Phase.FLIGHT
	controller._land_punish_dart()
	if controller.state.phase == MatchState.Phase.SETTLING:
		controller._advance_turn()


## 사람 네 명(또는 count 명) 경기 진행기. 화면·네트워크 없이 상태만 돌린다.
func _controller(count: int = 4) -> MatchController:
	var room := RoomState.new()
	room.settings.social_lobby = false
	room.settings.punishment = true
	for id in range(1, count + 1):
		room.add_player(id, "자리 %d" % id)
	var controller := MatchController.new()
	root.add_child(controller)
	controller.configure(room, 1)
	return controller
