extends SceneTree
## 소품을 실제 맵에서 잡고 마시고 던진다. 거리/독점 소유/숨은 취기/스턴/다이얼을 검사한다.
var main: Node
var game: GameView
var lounge: Node3D

func _initialize() -> void:
	_run.call_deferred()

func aim(actor: PlayerView, at: Vector3) -> void:
	var direction: Vector3 = (at - actor.eye_position()).normalized()
	actor.rotation.y = atan2(-direction.x, -direction.z)
	actor.pitch = asin(direction.y)

func wait_seconds(seconds: float) -> void:
	# 소품 쿨다운은 실제 시계를 쓴다. GPU 검사와 병행해도 서버 제한을 정확히 기다린다.
	var until: float = Time.get_ticks_msec() / 1000.0 + seconds
	while Time.get_ticks_msec() / 1000.0 < until:
		await process_frame

func _run() -> void:
	main = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	var options := RoomSettings.new()
	options.social_lobby = true
	options.solo = true
	options.capacity = 2
	options.bot_count = 1
	main.session.host_room("테스터", 17631, options)
	await process_frame
	game = main._game
	game.set_physics_process(false)
	lounge = game.lounge
	var actor: PlayerView = game.actors[1]
	actor.seated = false
	actor.position = Vector3(-3.7, 0, 3.1)
	aim(actor, lounge.objects[0].position)
	await physics_frame
	assert(lounge.focus(1).get("kind") == "prop")
	lounge.request("take")
	assert(lounge.held(1) == 0)
	main.session.room.settings.props_enabled = false
	await physics_frame
	assert(lounge.held(1) == -1, "소품을 끄면 기존 소유권도 해제된다")
	lounge.request("take")
	assert(lounge.held(1) == -1)
	main.session.room.settings.props_enabled = true
	lounge.objects[0].position = Vector3(-4.7, 1.3, 3.1)
	aim(actor, lounge.objects[0].position)
	await wait_seconds(0.2)
	lounge.request("take")
	assert(lounge.held(1) == 0)
	await wait_seconds(0.2)
	lounge.request("drink")
	assert(float(lounge.intoxication.get(1, 0)) == 0, "캐주얼 음료는 취기를 만들지 않는다")
	main.session.room.settings.alcohol = true
	main.session.room.settings.intoxication = 2
	await wait_seconds(1.6)
	lounge.request("drink")
	assert(float(lounge.intoxication.get(1, 0)) > 0.9)
	assert(not game.controller.state.to_snapshot().has("intoxication"))
	# 던지는 손 위치부터 상대의 실제 캡슐을 통과하도록 만든다.
	actor.position = Vector3(3, 0, 2)
	var victim: PlayerView = game.actors[-1]
	victim.seated = false
	victim.position = Vector3(3, 0, 0.9)
	actor.rotation.y = 0
	actor.pitch = -0.22
	await physics_frame
	await wait_seconds(0.2)
	lounge.request("throw")
	assert(lounge.held(1) == -1)
	await wait_seconds(0.4)
	assert(lounge.is_stunned(-1), "실제 병 궤적이 캐릭터 캡슐을 맞히면 스턴")
	assert(float(lounge.objects[0].available) > game.controller._now())
	await wait_seconds(1.2)
	assert(not lounge.is_stunned(-1))
	actor.position = Vector3(7.32, 0, 2.4)
	aim(actor, lounge.JUKEBOX + Vector3(-0.48, 1.2, 0.42))
	assert(lounge.focus(1).get("kind") == "power")
	lounge.request("power")
	assert(lounge.music.playing)
	await wait_seconds(0.2)
	actor.position.x = 7.8
	aim(actor, lounge.JUKEBOX + Vector3(0, 1.2, 0.42))
	lounge.request("volume", -1)
	assert(is_equal_approx(lounge.music.volume, 0.45))
	# 시작 화면 전환에도 음악·손에 든 물체·취기 값은 유지된다.
	game.force_seat(1)
	main.session.set_ready(true)
	await create_timer(0.3).timeout
	assert(main._game.lounge.music.playing and is_equal_approx(main._game.lounge.music.volume, 0.45))
	assert(float(main._game.lounge.intoxication.get(1, 0)) > 0)
	main.session.leave_room()
	main.queue_free()
	await process_frame
	print("PASS: physical pickup/drink/projectile impact/stun expiration, casual alcohol gate, separate jukebox power/dial, transition persistence")
	quit()
