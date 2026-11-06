extends SceneTree
## 리깅 캐릭터가 실제 방·조명에서 어떻게 보이는지 찍는다. 창 모드로 돌고 마우스를 잡지 않는다(약 30초).
##   & $godot --path . --script res://tests/render_characters.gd
## 결과: 저장소 루트의 output/character_motions/*.png
##   1) F5 경기: 테이블에 앉은 봇, 왼손 카드 부채(앞·어깨 너머), 봇 조준
##   2) 몸짓 줄 세우기: 서기·걷기·숙이기·점프·조준·던지기·만세·가리키기·마시기·카드·엿보기·왕머리
##   3) 벌칙 원판에 묶인 캐릭터, 로비 배경이 던지는 순간까지 오류 없이 도는지

const PLAYER_SCENE: PackedScene = preload("res://game/player/player.tscn")
const WHEEL = preload("res://game/card_round/fx/punishment_wheel.gd")
const LOBBY_BACKDROP = preload("res://lobby/lobby_backdrop.gd")
## 몸짓을 세울 빈 바닥. 캐릭터 간격(m)과 카메라 거리(m).
const STAGE_Z: float = 1.6
const STAGE_GAP: float = 1.25
const STAGE_CAMERA_DISTANCE: float = 5.6

var _output: String = ""
var _tour: Camera3D


func _initialize() -> void:
	_output = ProjectSettings.globalize_path("res://").path_join("../output/character_motions").simplify_path()
	DirAccess.make_dir_recursive_absolute(_output)
	root.size = Vector2i(1600, 900)
	_run.call_deferred()


func _run() -> void:
	await _shoot_match()
	await _shoot_stage()
	await _run_lobby()
	print("PASS: character shots → ", _output)
	quit()


func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(_output.path_join(label + ".png")) == OK)
	print("SHOT ", label)


func _look(from: Vector3, at: Vector3, label: String) -> void:
	_tour.global_position = from
	_tour.look_at(at)
	_tour.current = true
	await create_timer(0.3).timeout
	await _capture(label)


func _shoot_match() -> void:
	var main: Node = (load("res://app/main.tscn") as PackedScene).instantiate()
	main.developer_mode = true
	root.add_child(main)
	main._boot_developer()
	await create_timer(1.0).timeout
	var game := main.get_node("Game") as GameView
	main.get_node("GameHUD").set("visible", false)
	while game.controller.state.phase == MatchState.Phase.CARDS:
		await process_frame
	game.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_tour = Camera3D.new()
	_tour.fov = 50
	game.add_child(_tour)
	await create_timer(0.8).timeout
	await _look(Vector3(4.4, 1.7, 9.0), Vector3(0, 0.8, 5.1), "01_table_and_seats")
	var bots: Array = game.actors.values().filter(func(actor: PlayerView) -> bool: return actor.identity.is_bot)
	var bot := bots[0] as PlayerView
	var front := -bot.global_basis.z
	var feet := bot.global_position
	await _look(feet + front * 1.7 + Vector3.UP * 1.35, feet + Vector3.UP * 1.0, "02_seated_bot_front")
	var side := bot.global_basis.x
	await _look(feet + side * 1.7 + front * 0.2 + Vector3.UP * 1.1, feet + Vector3.UP * 0.8, "03_seated_bot_side")
	var fan := bot.find_child("LeftHandCards", true, false) as Node3D
	assert(fan != null, "봇 왼손에 카드 부채가 없습니다")
	# 왼쪽 어깨 너머(캐릭터 왼쪽 = -side)에서 앞면이 보인다.
	await _look(feet - front * 0.35 - side * 0.75 + Vector3.UP * 1.75, fan.global_position, "04_cards_over_shoulder")
	await _look(feet + front * 1.0 - side * 0.9 + Vector3.UP * 1.1, fan.global_position, "04b_cards_back")
	game.controller.developer_bot_turn(bot.identity.peer_id)
	var waited := 0.0
	while not bot.aiming and waited < 8.0:
		await process_frame
		waited += root.get_process_delta_time()
	var ahead := -bot.global_basis.z
	await _look(bot.global_position + ahead * 2.2 + bot.global_basis.x * 1.2 + Vector3.UP * 1.5, bot.global_position + Vector3.UP * 1.1, "05_bot_aiming")
	main.get_node("NetworkSession").leave_room()
	await create_timer(0.1).timeout
	main.queue_free()
	await process_frame


## 빈 바닥에 PlayerView 를 한 줄로 세운다. setup = 각 캐릭터에 몸짓을 넣는 함수.
func _stand(parent: Node3D, index: int, count: int, setup: Callable) -> PlayerView:
	var player := MatchPlayer.new()
	player.peer_id = 100 + index
	player.seat = index % 4
	player.display_name = "몸짓 %d" % index
	var view := PLAYER_SCENE.instantiate() as PlayerView
	parent.add_child(view)
	view.configure(player)
	view.position = Vector3((index - (count - 1) * 0.5) * STAGE_GAP, 0, STAGE_Z)
	view.rotation.y = 0.45
	setup.call(view)
	return view


func _shoot_stage() -> void:
	var table := (load("res://game/table/table.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(table)
	_tour = Camera3D.new()
	_tour.fov = 42
	table.add_child(_tour)
	var rows: Array = [
		[func(_v: PlayerView) -> void: pass,
		func(v: PlayerView) -> void: v.velocity = Vector3(0, 0, -PlayerView.SPEED),
		func(v: PlayerView) -> void: v.crouched = true,
		func(v: PlayerView) -> void:
			v.crouched = true
			v.velocity = Vector3(0, 0, -PlayerView.SPEED * 0.5),
		func(v: PlayerView) -> void: v.position.y = 0.45,
		func(v: PlayerView) -> void: v.aiming = true],
		[func(v: PlayerView) -> void: v.ready_pose = true,
		func(v: PlayerView) -> void: (v.get("_rig") as CharacterMotion).pointing = true,
		func(v: PlayerView) -> void: v.drink_pose = 0.5,
		func(v: PlayerView) -> void: (v.get("_rig") as CharacterMotion).holding_cards = true,
		func(v: PlayerView) -> void:
			v.seated = true
			v.seat_lean = 1.0,
		func(v: PlayerView) -> void: v.head_scale = 1.8],
	]
	for row in range(rows.size()):
		var views: Array[PlayerView] = []
		for index in range(rows[row].size()):
			views.append(_stand(table, index, rows[row].size(), rows[row][index]))
		await create_timer(1.0).timeout
		await _look(Vector3(0, 1.25, STAGE_Z - STAGE_CAMERA_DISTANCE * 1.6), Vector3(0, 1.0, STAGE_Z), "1%d_motions" % row)
		for view in views:
			view.queue_free()
		await process_frame
	# 던지기는 순간이 짧아 놓는 순간에 맞춰 따로 찍는다.
	var thrower := _stand(table, 2, 5, func(v: PlayerView) -> void: v.aiming = true)
	await create_timer(0.9).timeout
	thrower.aiming = false
	thrower.play_throw()
	_tour.global_position = thrower.global_position + Vector3(-1.4, 0.3, -3.0)
	_tour.look_at(thrower.global_position + Vector3.UP * 1.1)
	for frame in range(3):
		await create_timer(0.08).timeout
		await _capture("12_throw_%d" % frame)
	thrower.queue_free()
	var wheel: Node3D = WHEEL.new()
	wheel.position = Vector3(0, 1.1, STAGE_Z)
	table.add_child(wheel)
	wheel.attach(2)
	wheel.set("speed", 0.0)
	wheel.set_process(false)
	await _look(Vector3(0, 1.1, STAGE_Z + 3.0), wheel.global_position, "13_punishment_wheel")
	table.queue_free()
	await process_frame


## 로비 배경은 던지는 사람이 카메라 뒤에 서 있어 화면에 안 보인다. 첫 투척까지 오류 없이 도는지만 본다.
func _run_lobby() -> void:
	var backdrop: Control = LOBBY_BACKDROP.new()
	root.add_child(backdrop)
	await create_timer(2.2).timeout
	var thrower: Node3D = backdrop.get("_thrower")
	var to_board := (TableView.BOARD_CENTER - thrower.global_position).normalized()
	assert((-thrower.global_basis.z).dot(Vector3(to_board.x, 0, to_board.z).normalized()) > 0.9, "로비 캐릭터가 과녁을 안 봅니다")
	await _capture("20_lobby")
	backdrop.queue_free()
	await process_frame
