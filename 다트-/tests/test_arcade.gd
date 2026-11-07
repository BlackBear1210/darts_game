extends SceneTree
## 2026-10-30 추가 기능 검사(화면 없이): 네온 오락실 방 바꾸기 · 깨지는 병/큐대 · 인형뽑기 · 가챠 · 농구 오락기 ·
## 인형/캡슐 장난 효과 · 맞으면 밀려남 · 킬로그 칸 형식.
## 2026-11-07: 인형뽑기 WASD 조종(몸 대신 집게) · 시간 초과 자동 내리기 · 가챠 캡슐이 굴러 나옴(-Z 전면) ·
## 농구 던지기 보정(맞는 힘 = 링 가운데, 약하면 짧음) · 림 튕김 검사를 더했다.
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


## 포물선(중력 9.8)이 높이 y 를 위에서 아래로 지나는 점(농구 보정 시험용).
func _crossing(from: Vector3, velocity: Vector3, y: float) -> Vector3:
	var at := from
	var speed := velocity
	for step in range(600):
		speed += Vector3.DOWN * 9.8 / 240.0
		var next: Vector3 = at + speed / 240.0
		if at.y >= y and next.y < y:
			return at.lerp(next, (at.y - y) / (at.y - next.y))
		at = next
	return Vector3(INF, INF, INF)


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

	# 3) 인형뽑기(2026-11-07 새 조작): 상호작용 키로 시작 → WASD 가 집게를 움직이고(steer) 몸은 제자리 → 한 번 더 누르면 내린다.
	actor.position = Vector3(Rules.CLAW_AT.x, 0, Rules.CLAW_AT.z - 1.35)
	aim(actor, Rules.CLAW_PANEL)
	await physics_frame
	assert(lounge.focus(1).get("kind") == "claw")
	assert(not lounge.machine_prompt(1, "claw").contains("E"), "안내 글자에 옛 키 이름 E 가 남지 않는다")
	# 3-1) 시간이 다 되면 그 자리(상품 구멍 위)에서 저절로 내린다 — 구멍 위엔 인형이 없어 빈 집게.
	lounge.request("claw", 0)
	assert(str(lounge._arcade.claw.phase) == "move", "한 번 누르면 조종 시작")
	lounge._arcade.claw.until = lounge.now() - 0.01
	await physics_frame
	await physics_frame
	assert(str(lounge._arcade.claw.phase) == "drop", "시간이 다 되면 저절로 내린다")
	var idle_until: float = Time.get_ticks_msec() / 1000.0 + 6.0
	while str(lounge._arcade.claw.phase) != "idle" and Time.get_ticks_msec() / 1000.0 < idle_until:
		await physics_frame
	assert(int(lounge._arcade.claw.grab) == -1 and str(lounge._arcade.claw.phase) == "idle")
	# 3-2) GameView 방장 이동 루프: 조종 중 W 를 누르면 몸은 그대로, 집게만 안쪽(+Z)으로 간다.
	await wait_seconds(0.2)
	lounge.request("claw", 0)
	assert(lounge._arcade.operating(1) and not lounge._arcade.operating(-1))
	game._accept_controls(1, 1000000, Vector2(0, -1), PI, 0.0, false, false)
	game._send_elapsed = -100.0
	var body_before := Vector2(actor.position.x, actor.position.z)
	var claw_before: float = float(lounge._arcade.claw.z)
	for frame in range(10):
		game._physics_process(1.0 / 60.0)
	assert(Vector2(actor.position.x, actor.position.z).distance_to(body_before) < 0.001, "조종 중에는 몸이 움직이지 않는다")
	assert(float(lounge._arcade.claw.z) > claw_before + 0.05, "W = 집게가 안쪽(+Z)으로")
	assert(float(lounge._arcade.claw.stick_z) > 0.5, "조이스틱도 안쪽으로 기운다(그림)")
	assert(not lounge.steer_machine(-1, {"move": Vector2(0, -1), "yaw": PI}, 0.1), "조종자가 아닌 사람의 이동은 그대로 몸 이동")
	# 고개를 돌려 유리 속을 봐도 상호작용 대상은 계속 인형뽑기(내리기)다.
	aim(actor, Rules.CLAW_AT + Vector3(0.3, 1.2, 0.3))
	assert(lounge.focus(1).get("kind") == "claw", "조종 중에는 어디를 봐도 상호작용 = 집게 내리기")
	assert(lounge.machine_prompt(1, "claw").contains("내리기"))
	await wait_seconds(0.2)
	lounge.request("claw", 0)
	assert(str(lounge._arcade.claw.phase) == "drop", "두 번째 누름 = 내리기")
	idle_until = Time.get_ticks_msec() / 1000.0 + 6.0
	while str(lounge._arcade.claw.phase) != "idle" and Time.get_ticks_msec() / 1000.0 < idle_until:
		await physics_frame
	for index in range(lounge.objects.size()):
		if lounge.objects[index].kind == "plush" and not bool(lounge.objects[index].locked): lounge._arcade.return_plush(index)
	# 3-3) 인형 위로 집게를 몰아 내리면 뽑힌다(WASD 를 steer 로 직접 넣는다 — 기계를 보고 서면 yaw = PI: A = +X, W = +Z).
	var won: int = -1
	lounge._arcade._rng.seed = 7
	for attempt in range(8):
		await wait_seconds(0.2)
		lounge.request("claw", 0)
		assert(str(lounge._arcade.claw.phase) == "move")
		var plush_spot: Vector3 = Rules.PLUSH_SPOTS[0]
		for step in range(600):
			var want := Vector2(plush_spot.x - float(lounge._arcade.claw.x), plush_spot.z - float(lounge._arcade.claw.z))
			if want.length() < 0.008: break
			var move := Vector2(-signf(want.x) if absf(want.x) > 0.004 else 0.0, -signf(want.y) if absf(want.y) > 0.004 else 0.0)
			assert(lounge.steer_machine(1, {"move": move, "yaw": PI}, 1.0 / 60.0))
		assert(Vector2(float(lounge._arcade.claw.x), float(lounge._arcade.claw.z)).distance_to(Vector2(plush_spot.x, plush_spot.z)) < 0.02, "WASD 로 인형 위까지 간다")
		await wait_seconds(0.2)
		lounge.request("claw", 0)
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
	# 3-2 에서 GameView 방장 루프를 직접 돌려 봇이 자기 자리에 앉았을 수 있다 → 다시 세운다(앉으면 몸 캡슐이 낮아져 인형이 머리 위로 지나간다).
	victim.seated = false
	victim.update_posture()
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

	# 5) 가챠(2026-11-07): 기계는 앞(-Z, 통로 쪽)을 본다. 손잡이를 돌리면 캡슐이 GACHA_DROP 초 동안 굴러 나와 받침에서 풀린다.
	# 캡슐을 직접 열면 효과가 나에게.
	actor.position = Rules.gacha_crank(0) + Vector3(0, 0, -1.0)
	actor.position.y = 0
	aim(actor, Rules.gacha_crank(0))
	await wait_seconds(0.2)
	assert(lounge.focus(1).get("kind") == "gacha")
	lounge.request("gacha", 0)
	var capsule: int = int(lounge._arcade.gacha[0].pending)
	assert(capsule >= 0 and lounge.objects[capsule].kind == "capsule" and not str(lounge.objects[capsule].effect).is_empty(), "캡슐이 효과를 품고 굴러 나오기 시작한다")
	assert(bool(lounge.objects[capsule].locked), "굴러 나오는 동안은 아무도 못 집는다")
	var start_y: float = float(lounge.objects[capsule].position.y)
	await wait_seconds(Rules.GACHA_DROP * 0.6)
	assert(bool(lounge.objects[capsule].locked) and float(lounge.objects[capsule].position.y) < start_y, "구슬에서 배출구 쪽으로 내려오는 중")
	await wait_seconds(Rules.GACHA_DROP * 0.4 + 0.3)
	assert(not bool(lounge.objects[capsule].locked) and lounge.objects[capsule].position.distance_to(Rules.gacha_tray(0)) < 0.05, "받침에 닿으면 풀린다")
	assert(int(lounge._arcade.gacha[0].pending) == -1)
	# 받침은 기계 앞(-Z)으로 나와 있어야 통로에서 집힌다.
	assert(Rules.gacha_tray(0).z < Rules.GACHA_AT[0].z - 0.2 and Rules.gacha_tray(0).z > TableView.NPC_TABLE_BOX.position.z - 0.1)
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
	# 6-2) 던지기 보정(2026-11-07): 3.5m 밖에서 골대 쪽으로 이 거리에 맞는 힘으로 던지면 링 가운데로 떨어져 3점.
	var arcade: RefCounted = lounge._arcade
	var center: Vector3 = arcade.hoop_center()
	var from := Vector3(center.x, 1.5, center.z - 3.5)
	var ideal: float = clampf(remap(3.5, Rules.ASSIST_RANGE.x, Rules.ASSIST_RANGE.y, 0.2, 0.9), 0.15, 0.95)
	# 살짝(0.0125 라디안) 비껴 던져도 반만 남으니 링 가운데 근처(2cm)로 간다.
	var good: Vector3 = arcade.assist_throw(from, Vector3(0.1, 2.0, 8.0), ideal)
	assert(good != Vector3(0.1, 2.0, 8.0), "골대 쪽으로 던지면 보정된다")
	# 포물선을 직접 따라가 링 높이를 위→아래로 지나는 점을 본다.
	var cross := _crossing(from, good, center.y)
	assert(Vector2(cross.x - center.x, cross.z - center.z).length() < 0.06, "맞는 힘이면 링 가운데")
	var weak: Vector3 = arcade.assist_throw(from, Vector3(0, 2.0, 8.0), ideal - 0.4)
	var short := _crossing(from, weak, center.y)
	assert(Vector2(short.x - center.x, short.z - center.z).length() > Rules.HOOP_RADIUS, "힘이 많이 모자라면 짧다(보정이 다 넣어 주지 않는다)")
	var sideways := Vector3(8.0, 2.0, 0.0)
	assert(arcade.assist_throw(from, sideways, ideal) == sideways, "골대 반대쪽으로 던진 공은 보정하지 않는다")
	# 실제 소품 물리로도 들어간다(백보드·그물 충돌을 지나 골 판정).
	var before: int = int(arcade.hoop.scores.get(1, 0))
	actor.position = Vector3(from.x, 0, from.z)
	lounge._launch(ball, from, good, 1, false)
	await wait_seconds(1.6)
	assert(int(arcade.hoop.scores.get(1, 0)) == before + 3, "보정된 3.5m 슛 = 3점 골")
	# 6-3) 림: 링 가장자리를 지나면 "탕" 위로 튕기고(true → 공을 림 위로), 림 시각이 그림용으로 남는다.
	var rim_shot := {"velocity": Vector3(0, -3, 0.5), "owner": 1, "origin": from, "scored": false}
	var edge: Vector3 = center + Vector3(Rules.HOOP_RADIUS, 0, 0)
	assert(arcade.ball_moved(rim_shot, edge + Vector3(0, 0.05, 0), edge - Vector3(0, 0.05, 0)), "림을 맞으면 튕긴다")
	assert((rim_shot.velocity as Vector3).y > 0.0 and int(rim_shot.rims) == 1 and (rim_shot.rim_at as Vector3).y > center.y)
	assert(lounge.now() - float(arcade.hoop.rim) < 0.1, "림 시각(링 떨림 그림)")
	assert(lounge.now() - float(arcade.hoop.goal) < 3.0, "골 시각(그물 출렁임 그림)")

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
	print("PASS: arcade room swap, bottle/cue breaking (drop/height/speed/power) and respawn, claw WASD steer/timeout/win, plush blind + knockback, gacha rolling capsule effect, hoop score + assist + rim + ball return, icon feed, designer prop M_Variant tint")
	quit()
