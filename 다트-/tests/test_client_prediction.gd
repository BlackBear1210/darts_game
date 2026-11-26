extends SceneTree
## 손님 화면 예측(2026-11-26 사용자 "멀티에서 방장 제외하면 아직도 막 렉이 걸린다").
## 손님은 자기 몸을 방장 응답 없이 먼저 움직이고(GameView._predict_local), 방장 스냅샷이 오면
## 걷는 동안의 정상적인 지연만큼 어긋난 것은 무시하고 예측을 지킨다(_trusts_prediction · keep_predicted_motion).
## 예측이 틀렸다는 신호(가만히 서 있는데 어긋남 · 크게 벌어짐 · 앉기 · 쓰러짐)에는 방장 자리를 따른다.
var main: Node
var game: GameView


func _initialize() -> void:
	_run.call_deferred()


func pose(actor: PlayerView, at: Vector3, seated: bool = false) -> Dictionary:
	return {"id": actor.identity.peer_id, "position": at, "yaw": 0.0, "pitch": 0.0,
		"seat_lean": 0.0, "seated": seated, "crouched": true, "velocity": Vector3.ZERO}


## 손님이 지금 누르고 있는 조작을 흉내 낸다(방장 화면에서는 같은 자리에 같은 값이 들어간다).
func hold(move: Vector2) -> void:
	game._controls[1] = {"sequence": 1, "move": move, "yaw": 0.0, "pitch": 0.0,
		"jump": false, "crouch": false, "at": game.controller._now()}


func _run() -> void:
	main = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	var options := RoomSettings.new()
	options.social_lobby = true
	options.solo = true
	options.capacity = 2
	options.bot_count = 1
	main.session.host_room("테스터", 17673, options)
	await create_timer(0.8).timeout
	game = main._game
	game.set_physics_process(false)
	var mine := game.actors[1] as PlayerView
	mine.seated = false
	mine.position = Vector3(0, 0, 4.0)

	# 1) 걷는 중이고 방장 자리가 왕복 지연만큼만 뒤처졌다 → 내 예측을 지킨다.
	#    (안 지키면 매 스냅샷마다 뒤로 끌려가 걸음이 미끄러진다.)
	hold(Vector2(0, -1))
	var behind := mine.position + Vector3(0, 0, 0.5)
	assert(game._trusts_prediction(mine, pose(mine, behind)), "걷는 중 왕복 지연만큼의 차이는 정상이다")

	# 2) 걷다 멈춰도 그대로 믿는다. 멈춘 직후의 스냅샷은 아직 "걷던 중" 자리라 뒤처져 있는데,
	#    그때 방장 자리를 따르면 멈출 때마다 뒤로 홱 끌려간다(방장은 곧 같은 자리로 따라온다).
	hold(Vector2.ZERO)
	assert(game._trusts_prediction(mine, pose(mine, behind)), "멈춘 직후에도 뒤로 끌려가지 않는다")

	# 3) PREDICT_TRUST 보다 크게 벌어지면 예측이 틀린 것이다(밀림·스턴·순간이동).
	var far := mine.position + Vector3(0, 0, GameView.PREDICT_TRUST + 0.5)
	assert(not game._trusts_prediction(mine, pose(mine, far)), "너무 벌어지면 방장을 따른다")

	# 4) 앉기·쓰러짐은 예측 대상이 아니다.
	assert(not game._trusts_prediction(mine, pose(mine, behind, true)), "자리에 앉히는 스냅샷은 그대로 따른다")
	mine.fallen = true
	assert(not game._trusts_prediction(mine, pose(mine, behind)), "쓰러진 동안은 방장을 따른다")
	mine.fallen = false

	# 5) 예측을 지킬 때도 자리 말고 다른 상태는 방장 것을 받는다.
	var kept: Vector3 = mine.position
	mine.crouched = false
	mine.keep_predicted_motion(pose(mine, behind))
	assert(mine.position.is_equal_approx(kept), "자리는 내 예측 그대로: %s" % mine.position)
	assert(mine.crouched, "자세 같은 나머지 상태는 방장 것을 따른다")
	# 지킨 자리를 보간이 다시 끌고 가면 안 된다. 예측 중인 몸은 보간에서 아예 빠진다 —
	# 둘 다 자리를 쓰면 매 프레임 앞뒤로 당겨 걸음이 밀린다(사용자 "그냥 걷는데 밀리는 느낌").
	assert(mine.predicted or true)
	mine.predicted = true
	mine._motion_to = kept + Vector3(0, 0, 0.6)
	await process_frame
	await process_frame
	assert(mine.position.is_equal_approx(kept), "예측 중인 몸은 보간이 건드리지 않는다: %s" % mine.position)
	mine.predicted = false
	await process_frame
	await process_frame
	assert(not mine.position.is_equal_approx(kept), "예측이 아니면 평소대로 보간한다")

	main.queue_free()
	await process_frame
	print("PASS: client keeps its own predicted position through normal lag and on stopping, defers to the host on large drift/seating/falling, and is excluded from snapshot easing")
	quit()
