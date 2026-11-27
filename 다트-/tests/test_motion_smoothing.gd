extends SceneTree
## 손님 화면 보간(2026-11-26 사용자 "게임 시작하면 사람들이 막 덜덜덜 떨려").
## 방장만 simulate 를 돌리고 손님 화면은 초당 20번 오는 스냅샷으로만 사람을 옮긴다 → 그대로 꽂으면
## 화면 주사율만큼 자주 그려지는 동안 사람이 뚝뚝 끊겨 순간이동한다.
## 받은 자리로 매 프레임 좁혀 가는지, 멀리 건너뛴 자리는 그대로 붙이는지 본다.
var main: Node
var game: GameView


func _initialize() -> void:
	_run.call_deferred()


func pose(actor: PlayerView, at: Vector3, yaw: float = 0.0) -> Dictionary:
	return {"id": actor.identity.peer_id, "position": at, "yaw": yaw, "pitch": 0.0,
		"seat_lean": 0.0, "seated": actor.seated, "crouched": false, "velocity": Vector3.ZERO}


func _run() -> void:
	main = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	var options := RoomSettings.new()
	options.social_lobby = true
	options.solo = true
	options.capacity = 2
	options.bot_count = 1
	main.session.host_room("테스터", 17672, options)
	await create_timer(0.8).timeout
	game = main._game
	# 방장 시뮬레이션을 멈춰 스냅샷만으로 움직이는 손님 화면과 같은 조건을 만든다.
	game.set_physics_process(false)
	var actor := game.actors[-1] as PlayerView
	actor.seated = false

	# 1) 첫 스냅샷은 바로 그 자리로(보간할 이전 자리가 없다).
	var start := Vector3(0, 0, 4.0)
	actor.apply_motion(pose(actor, start))
	assert(actor.position.is_equal_approx(start), "첫 스냅샷은 바로 붙인다: %s" % actor.position)

	# 2) 한 걸음(0.05초치)만큼 떨어진 다음 스냅샷은 한 프레임에 다 가지 않고 나눠 간다.
	var next := start + Vector3(0, 0, -0.19)
	actor.apply_motion(pose(actor, next))
	assert(actor.position.is_equal_approx(start), "스냅샷을 받은 순간에는 아직 안 움직인다")
	# process_frame 은 노드 _process 보다 먼저 울린다 → 한 번 더 기다려야 보간이 한 프레임 돈 결과를 본다.
	await process_frame
	await process_frame
	var after_one: float = start.distance_to(actor.position)
	assert(after_one > 0.0, "다음 프레임부터 목표 쪽으로 움직인다")
	assert(after_one < start.distance_to(next), "한 프레임에 다 가지 않는다(= 순간이동하지 않는다): %.4f" % after_one)

	# 3) 여러 프레임이 지나면 목표에 닿는다(뒤처진 채 남지 않는다).
	for frame in range(30):
		await process_frame
	assert(actor.position.distance_to(next) < 0.01, "곧 목표 자리에 닿는다: %.4f" % actor.position.distance_to(next))

	# 4) 멀리 건너뛴 자리(자리 앉기·쓰러진 뒤 복귀)는 보간하지 않고 바로 옮긴다.
	var far := next + Vector3(4.0, 0, 0)
	actor.apply_motion(pose(actor, far))
	assert(actor.position.is_equal_approx(far), "MOTION_SNAP 보다 멀면 바로 붙인다: %s" % actor.position)

	# 5) 좌우 각도도 끊기지 않고 따라간다.
	actor.apply_motion(pose(actor, far, 1.0))
	assert(is_equal_approx(actor.rotation.y, 0.0), "각도도 받은 순간에는 그대로다")
	await process_frame
	await process_frame
	assert(actor.rotation.y > 0.0 and actor.rotation.y < 1.0, "각도는 나눠서 돈다: %.4f" % actor.rotation.y)

	# 6) 스냅샷을 한 번도 안 받은 사람(방장 화면)은 보간이 건드리지 않는다.
	var mine := game.actors[1] as PlayerView
	var kept: Vector3 = mine.position
	await process_frame
	assert(mine.position.is_equal_approx(kept), "방장이 직접 시뮬레이션하는 사람은 그대로다")

	# 7) [2026-11-27 "중간중간 툭툭"] 스냅샷 사이를 받은 속도로 메운다. 안 메우면 목표가 멈춘 점이라
	#    매 구간 감속했다가 다음 스냅샷에 튀어, 일정하게 걷는 사람도 화면에서는 2~6m/s 로 출렁인다.
	var walker := game.actors[-1] as PlayerView
	walker.seated = false
	var speed := Vector3(0, 0, -3.8)
	var at := Vector3(0, 0, 6.0)
	walker.apply_motion(pose(walker, at))
	walker.velocity = speed
	walker.apply_motion({"id": -1, "position": at, "yaw": 0.0, "pitch": 0.0, "seat_lean": 0.0,
		"seated": false, "crouched": false, "velocity": speed})
	var before: Vector3 = walker._motion_to
	await process_frame
	await process_frame
	assert(walker._motion_to.z < before.z - 0.001, "스냅샷 사이에도 목표가 받은 속도로 나아간다: %s → %s" % [before, walker._motion_to])
	# 다음 스냅샷이 끊겨도 끝없이 앞서가지는 않는다(MOTION_LEAD 만큼만).
	var lead_start: Vector3 = walker._motion_to
	for frame in range(40):
		await process_frame
	var led: float = lead_start.distance_to(walker._motion_to)
	assert(led <= speed.length() * PlayerView.MOTION_LEAD + 0.05, "꾸러미가 끊기면 정해진 만큼만 밀고 멈춘다: %.3f m" % led)

	main.queue_free()
	await process_frame
	print("PASS: client snapshots are eased between frames, far jumps snap, and host-simulated actors are untouched")
	quit()
