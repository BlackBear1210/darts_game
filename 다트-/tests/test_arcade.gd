extends SceneTree
## 2026-10-30 추가 기능 검사(화면 없이): 네온 오락실 방 바꾸기 · 깨지는 병/큐대 · 인형뽑기 · 가챠 · 농구 오락기 ·
## 인형/캡슐 장난 효과 · 맞으면 밀려남 · 킬로그 칸 형식.
## 실행: Godot --headless --path . --script res://tests/test_arcade.gd
const Rules = preload("res://game/lounge/arcade/arcade_rules.gd")
const PropLooks = preload("res://game/lounge/prop_looks.gd")
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
	var until: float = Time.get_ticks_msec() / 1000.0 + seconds
	while Time.get_ticks_msec() / 1000.0 < until:
		await physics_frame


func index_of(kind: String) -> int:
	for index in range(lounge.objects.size()):
		if lounge.objects[index].kind == kind: return index
	return -1


func _run() -> void:
	main = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	var options := RoomSettings.new()
	options.social_lobby = true
	options.solo = true
	options.capacity = 2
	options.bot_count = 1
	options.theme_id = 1
	main.session.host_room("테스터", 17641, options)
	await process_frame
	game = main._game
	game.set_physics_process(false)
	lounge = game.lounge
	var actor: PlayerView = game.actors[1]
	var victim: PlayerView = game.actors[-1]
	actor.seated = false
	victim.seated = false

	# 1) 오락실 방: 펍의 바·당구대 그림이 빠지고 기계가 선다. 인형뽑기 몸 충돌이 생긴다.
	var pub: Node = game.table.get_node("Pub")
	assert(pub.get_node_or_null("Bar") == null and pub.get_node_or_null("PoolTable") == null, "오락실은 바·당구대 그림을 뺀다")
	assert(pub.get_node_or_null("TableAndSeats") != null and pub.get_node_or_null("BoardWall") != null)
	assert(lounge._arcade_room != null)
	var space := game.get_world_3d().direct_space_state
	var probe := space.intersect_ray(PhysicsRayQueryParameters3D.create(Rules.CLAW_AT + Vector3(0, 1.2, -2), Rules.CLAW_AT + Vector3(0, 1.2, 0), 1))
	assert(not probe.is_empty(), "인형뽑기 기계에 몸이 부딪힌다")

	# 2) 병: 살짝 놓으면 안 깨지고, 높은 곳 · 세게 · 파워 카드면 깨진다. 깨진 병은 잠시 뒤 제자리.
	var bottle: int = index_of("bottle")
	lounge._launch(bottle, Vector3(-2, 1.2, 2.0), Vector3(0, 0.3, 0.5), 1, false)
	await wait_seconds(0.8)
	assert(float(lounge.objects[bottle].broken) == 0.0, "손 높이에서 툭 놓으면 안 깨진다")
	assert(bool(lounge.objects[bottle].lying), "떨어진 병은 눕는다")
	lounge._launch(bottle, Vector3(-2, 2.6, 2.0), Vector3.ZERO, 1, false)
	await wait_seconds(0.9)
	assert(float(lounge.objects[bottle].broken) > lounge.now(), "높은 곳에서 떨어지면 깨진다")
	assert(lounge.objects[bottle].position == lounge.objects[bottle].home)
	lounge.objects[bottle].broken = 0.0
	lounge._launch(bottle, Vector3(0, 1.4, 3.0), Vector3(-11, 0.5, 0), 1, false)
	await wait_seconds(0.8)
	assert(float(lounge.objects[bottle].broken) > lounge.now(), "세게 던져 벽(바)에 부딪히면 깨진다")
	lounge.objects[bottle].broken = lounge.now() + 0.05
	await wait_seconds(0.2)
	assert(float(lounge.objects[bottle].broken) == 0.0, "깨진 병은 새것으로 돌아온다")
	var feed_text := "\n".join(game.controller.state.feed)
	assert(feed_text.contains("와장창") and feed_text.contains(MatchController.FEED_SEPARATOR), "깨짐은 아이콘 킬로그로 남는다")

	# 3) 인형뽑기: E 세 번(시작 → 가로 멈춤 → 세로 멈춤) 뒤 집게가 내려가 인형을 집는다.
	actor.position = Vector3(Rules.CLAW_AT.x, 0, Rules.CLAW_AT.z - 1.35)
	aim(actor, Rules.CLAW_PANEL)
	await physics_frame
	assert(lounge.focus(1).get("kind") == "claw")
	var won: int = -1
	lounge._arcade._rng.seed = 7
	for attempt in range(8):
		await wait_seconds(0.2)
		lounge.request("claw", 0)
		assert(str(lounge._arcade.claw.phase) == "x")
		await wait_seconds(0.2)
		lounge.request("claw", 0)
		assert(str(lounge._arcade.claw.phase) == "z")
		# 인형 바로 위로 맞춘 뒤 내린다(시험은 타이밍 대신 좌표를 넣는다).
		var plush_spot: Vector3 = Rules.PLUSH_SPOTS[0]
		lounge._arcade.claw.x = plush_spot.x
		await wait_seconds(0.2)
		lounge._arcade.claw.z = plush_spot.z
		lounge._arcade._claw_drop(lounge.now())
		lounge._arcade.claw.x = plush_spot.x
		lounge._arcade.claw.z = plush_spot.z
		var until: float = Time.get_ticks_msec() / 1000.0 + 6.0
		while str(lounge._arcade.claw.phase) != "idle" and Time.get_ticks_msec() / 1000.0 < until:
			await physics_frame
		assert(str(lounge._arcade.claw.phase) == "idle", "집게가 한 바퀴 돌고 대기로 돌아온다")
		for index in range(lounge.objects.size()):
			if lounge.objects[index].kind == "plush" and not bool(lounge.objects[index].locked): won = index
		if won >= 0: break
	assert(won >= 0, "가운데 맞추면 인형을 뽑는다(8번 안에)")
	assert(lounge.objects[won].position.distance_to(Rules.CLAW_DOOR) < 0.05, "뽑은 인형은 상품 문으로 나온다")

	# 4) 인형 던지기: 맞은 사람은 얼굴이 가려지고(blind) 살짝 밀려난다.
	actor.position = Vector3(3, 0, 2)
	victim.position = Vector3(3, 0, 0.9)
	victim.knockback = Vector3.ZERO
	lounge.objects[won].holder = 1
	actor.rotation.y = 0
	actor.pitch = -0.22
	await wait_seconds(0.2)
	lounge.request("throw", 0.5)
	await wait_seconds(0.5)
	assert(lounge.effect_left(-1, "blind") > 0.0, "인형에 맞으면 얼굴이 가려진다")
	assert(victim.knockback.length() > 0.5 or lounge.is_stunned(-1), "맞은 사람은 밀려난다")
	await wait_seconds(0.5)

	# 5) 가챠: 손잡이를 돌리면 캡슐이 받침에 나온다. 캡슐을 직접 열면 효과가 나에게.
	actor.position = Rules.gacha_crank(0) + Vector3(-1.0, 0, 0)
	actor.position.y = 0
	aim(actor, Rules.gacha_crank(0))
	await wait_seconds(0.2)
	assert(lounge.focus(1).get("kind") == "gacha")
	lounge.request("gacha", 0)
	var capsule: int = -1
	for index in range(lounge.objects.size()):
		if lounge.objects[index].kind == "capsule" and not bool(lounge.objects[index].locked): capsule = index
	assert(capsule >= 0 and not str(lounge.objects[capsule].effect).is_empty(), "캡슐이 효과를 품고 나온다")
	await wait_seconds(0.9)
	aim(actor, lounge.objects[capsule].position)
	await physics_frame
	assert(lounge.focus(1).get("kind") == "prop")
	lounge.request("take")
	assert(lounge.held(1) == capsule)
	await wait_seconds(0.2)
	lounge.objects[capsule].effect = "bighead"
	lounge.request("drink")
	assert(lounge.effect_left(1, "bighead") > 0.0, "직접 연 캡슐 효과는 나에게")
	assert(bool(lounge.objects[capsule].locked), "연 캡슐은 기계로 돌아간다")
	await wait_seconds(0.1)
	assert(actor.head_scale > 1.5, "왕머리가 보인다")

	# 6) 농구: 버튼으로 HOOP FEVER 시작, 링을 위에서 아래로 지나면 골.
	actor.position = Rules.HOOP_BUTTON + Vector3(0, 0, -0.85)
	actor.position.y = 0
	aim(actor, Rules.HOOP_BUTTON)
	await wait_seconds(0.2)
	assert(lounge.focus(1).get("kind") == "hoop")
	lounge.request("hoop", 0)
	assert(bool(lounge._arcade.hoop.running))
	var ball: int = index_of("hoop_ball")
	lounge._launch(ball, Rules.HOOP_RING + Vector3(0, 0.5, 0), Vector3(0, -1, 0), 1, false)
	await wait_seconds(0.6)
	assert(int(lounge._arcade.hoop.scores.get(1, 0)) >= 2, "링 안으로 떨어지면 점수")
	await wait_seconds(1.2)
	assert(lounge.objects[ball].position.distance_to(lounge.objects[ball].home) < 0.05, "기계 안에 떨어진 공은 앞 받침으로 돌아온다")

	# 7) 큐대: 펍 테마로 돌아가면 큐대가 나오고, 세게 부딪히면 부러진다.
	main.session.room.settings.theme_id = 0
	lounge.apply_theme()
	assert(game.table.get_node("Pub").get_node_or_null("PoolTable") != null, "펍으로 돌아오면 당구대 그림이 다시 생긴다")
	var cue: int = index_of("cue")
	lounge._launch(cue, Vector3(4, 1.5, 3.0), Vector3(10, 0.5, 0), 1, true)
	await wait_seconds(0.8)
	assert(float(lounge.objects[cue].broken) > lounge.now(), "파워 카드로 던진 큐대는 부러진다")

	# 8) 공개 상태(네트워크): 남은 초로 보내고 받는 쪽이 그대로 되돌린다.
	var data: Dictionary = lounge._arcade.to_public()
	lounge._arcade.from_public(data)
	assert(lounge._arcade.hoop.has("scores"))

	# 9) 디자이너 소품 모델: M_Variant 재질만 변형 색으로 칠하고 다른 재질은 그대로 둔다.
	var model := Node3D.new()
	var part := MeshInstance3D.new()
	part.mesh = BoxMesh.new()
	var variant_material := StandardMaterial3D.new()
	variant_material.resource_name = "M_Variant"
	variant_material.albedo_color = Color(1, 1, 1, 0.7)
	part.mesh.surface_set_material(0, variant_material)
	model.add_child(part)
	var plain := MeshInstance3D.new()
	plain.mesh = SphereMesh.new()
	plain.mesh.surface_set_material(0, StandardMaterial3D.new())
	model.add_child(plain)
	PropLooks._tint_variant(model, PropLooks._variant_color("ball", 1))
	var tinted := part.get_surface_override_material(0) as StandardMaterial3D
	assert(tinted != null and tinted.albedo_color.is_equal_approx(Color(PropLooks.POOL_COLORS[1], 0.7)), "M_Variant 는 변형 색, 투명도 유지")
	assert(plain.get_surface_override_material(0) == null, "다른 재질은 건드리지 않는다")
	model.free()
	main.session.leave_room()
	main.queue_free()
	await process_frame
	print("PASS: arcade room swap, bottle/cue breaking (drop/height/speed/power) and respawn, claw win, plush blind + knockback, gacha capsule effect, hoop score + ball return, icon feed, designer prop M_Variant tint")
	quit()
