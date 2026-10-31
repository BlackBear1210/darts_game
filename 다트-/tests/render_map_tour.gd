extends SceneTree
## 도면 v3(2026-10-31 밤, RG Poly 에셋 가구) 방을 구역별로 찍어 깨지거나 튀어나온 곳이 없는지 눈으로 본다.
##   godot --path . --script res://tests/render_map_tour.gd
## 화면은 .godot/map_render/*.png(Git 제외). 창 모드 — 시간 제한을 두고 돌린다.
## 건드리기(F) 상호작용도 확인한다: 종·럼주통을 건드리면 흔들림이 시작되고, 맥주잔은 집어 마실 수 있다.
var main: Node
var game: GameView
var output: String = "res://.godot/map_render"


func _initialize() -> void:
	_run.call_deferred()


var failed: bool = false


func check(value: bool, message: String) -> void:
	if not value:
		printerr("FAIL: ", message)
		failed = true


func capture(label: String, eye: Vector3, target: Vector3, wait: float = 0.25) -> void:
	game.camera.position = eye
	game.camera.look_at(target)
	await create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.get_texture().get_image().save_png(output.path_join(label + ".png"))


## 도면: 정사영 카메라로 내려다본 실제 방 + 구역 이름표(docs/MAP_PLAN_2026-10-31.md 그림).
## 카메라 근거리 면(near)으로 높이 2.6m 위를 잘라낸다 → 천장·펜던트·전구 줄이 빠지고 벽은 단면으로 보인다(건축 도면처럼).
func _floor_plan() -> void:
	var camera := game.camera
	var old := [camera.projection, camera.near, camera.far]
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	# 방 넓히기 v4(2026-10-31 늦은 밤): 방 전체(x -8.4~13.6 · z -7.5~9.0)가 들어오게. 눈은 천장(4.8m) 아래.
	var bounds: Rect2 = TableView.DART_HALL.merge(TableView.LOUNGE)
	camera.size = bounds.size.y + 1.0
	camera.near = 1.3
	camera.far = 12.0
	camera.position = Vector3(bounds.get_center().x, TableView.CEILING_HEIGHT - 0.4, bounds.get_center().y)
	camera.rotation = Vector3(-PI / 2, 0, 0)
	await create_timer(0.2).timeout
	var labels := Control.new()
	root.add_child(labels)
	var zones := [["다트 홀 (투척 구역)", Vector3(0, 0, -2.0)], ["투척선", Vector3(3.2, 0, TableView.THROW_LINE_Z)],
		["과녁", Vector3(0, 0, -6.9)], ["연습 과녁", TableView.PRACTICE_TARGET_AT], ["럼주통 탁자", TableView.BARRELS[2]],
		["양동이·빗자루", TableView.BUCKET_AT], ["바 (맥주잔·병·종)", Vector3(-5.4, 0, 3.7)], ["바 끝 냉장고", TableView.BAR_FRIDGE_AT], ["바 뒤 (생맥주 통·조리대)", Vector3(-7.2, 0, 2.6)],
		["카드 테이블", TableView.TABLE_CENTER], ["구경 소파", TableView.SOFA_AT], ["NPC 자리 (저녁상)", TableView.NPC_TABLE_BOX.get_center()],
		["주크박스", Vector3(7.8, 0, 1.1)], ["당구대", TableView.POOL_TABLE_BOX.get_center()], ["안락의자·축음기", TableView.ARMCHAIR_AT],
		["입구·짐", TableView.CRATES_AT + Vector3(0.8, 0, 0)]]
	for zone in zones:
		var label := Label.new()
		label.text = zone[0]
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_color", Color("fff4d8"))
		label.add_theme_color_override("font_outline_color", Color("1a1410"))
		label.add_theme_constant_override("outline_size", 8)
		labels.add_child(label)
		label.position = camera.unproject_position(zone[1] + Vector3.UP * 1.2) - label.get_combined_minimum_size() * 0.5
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.get_texture().get_image().save_png(output.path_join("00_floor_plan_top.png"))
	labels.queue_free()
	camera.projection = old[0]
	camera.near = old[1]
	camera.far = old[2]


func _run() -> void:
	main = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	var options := RoomSettings.new()
	options.social_lobby = true
	options.solo = true
	options.bot_count = 3
	options.theme_id = 0 # 펍 테마(기본값은 방 설정을 따른다)
	main.session.host_room("테스터", 17652, options)
	await create_timer(0.8).timeout
	game = main._game
	game.force_seat(1)
	await create_timer(0.8).timeout
	game.set_process(false)
	game.set_physics_process(false)
	game.camera.cull_mask = 0xfffff
	game.lounge_hud.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var pub: Node = game.table.get_node("Pub")
	for name in ["Keg", "BackCounter", "PracticeTarget", "Sofa", "Armchair", "Gramophone", "Crate", "SeatStool_1", "BarStool_1", "RumBarrel_1"]:
		check(pub.find_child(name, true, false) != null, "방에 %s 가 있다" % name)
	await _floor_plan()
	# 구역별 시점(눈 → 보는 곳).
	await capture("01_overview_lounge", Vector3(-1.0, 3.4, -0.6), Vector3(2.0, 0.6, 5.2))
	await capture("02_bar_front", Vector3(-2.6, 1.7, 3.4), Vector3(-5.6, 1.1, 3.6))
	await capture("03_back_bar", Vector3(-5.0, 2.0, 1.2), Vector3(-7.8, 1.0, 4.2))
	await capture("04_table_seats", Vector3(2.6, 2.3, 1.6), Vector3(0, 0.6, 4.4))
	await capture("05_sofa_back_wall", Vector3(-1.0, 1.8, 4.4), Vector3(-3.1, 0.7, 8.4))
	await capture("06_npc_booth", Vector3(3.6, 1.9, 2.0), Vector3(5.8, 0.8, 4.0))
	await capture("07_right_corner", Vector3(9.6, 1.8, 4.0), Vector3(12.7, 0.7, 1.4))
	await capture("08_door_crates", Vector3(4.8, 1.9, 5.4), Vector3(7.6, 0.8, 8.5))
	await capture("08b_bar_end_fridge", Vector3(-2.4, 1.7, 5.6), Vector3(-5.3, 1.0, 8.0))
	await capture("08c_hall_corner_seam", Vector3(-3.0, 1.7, -2.6), Vector3(-6.6, 1.5, 0.6))
	await capture("08d_ceiling_beams", Vector3(2.0, 1.6, 1.0), Vector3(3.0, 4.6, 6.0))
	await capture("09_hall_from_line", Vector3(0.0, 1.9, -1.0), Vector3(0, 1.4, -7.0))
	await capture("10_hall_left", Vector3(-1.2, 1.9, -2.4), Vector3(-4.6, 1.0, -5.8))
	await capture("11_hall_right", Vector3(1.6, 1.9, -1.6), Vector3(5.2, 1.0, -4.4))
	await capture("12_hall_wall_shelf", Vector3(-2.6, 2.0, -1.2), Vector3(-5.8, 1.9, -1.5))
	# 건드리기: 종 → 흔들림이 시작된다.
	var lounge = game.lounge
	var spots: Array[Dictionary] = lounge.touch_spots()
	check(spots.size() >= 8, "건드리기 자리 8곳 이상")
	lounge._play_fx({"match_id": game.controller.state.match_id, "kind": "sound", "at": spots[0].at, "push": Vector3.ZERO,
		"tint": Color.WHITE, "sound": "ding", "wobble": "Bell"})
	var bell := pub.find_child("Bell", true, false) as Node3D
	check(bell != null and bell.visible, "종은 묶음 그리기에서 빠져 보인다")
	await create_timer(0.1).timeout
	lounge._process(0.016)
	check(lounge._wobbles.has(bell), "종이 흔들린다")
	# 맥주잔: 바 위에 4개, 마실 수 있다.
	var mugs: int = 0
	for object: Dictionary in lounge.objects:
		if object.kind == "mug": mugs += 1
	check(mugs == TableView.BAR_MUGS.size(), "맥주잔이 바 위에 놓였다")
	await capture("13_bar_mugs_close", Vector3(-3.9, 1.6, 1.4), Vector3(-5.2, 1.15, 1.9))
	# 오락실 테마에서도 가구가 기계를 가리지 않는지.
	main.session.room.settings.theme_id = 1
	lounge.apply_theme()
	await create_timer(0.4).timeout
	await capture("14_arcade_overview", Vector3(-1.5, 3.2, 0.6), Vector3(7.5, 0.8, 5.0))
	await capture("15_arcade_back_left", Vector3(-1.5, 2.2, 2.0), Vector3(-6.5, 1.0, 5.0))
	# 네온 오락실 개편(2026-10-31 늦은 밤): 주스 가게 · 음료 냉장고 · 인형뽑기 코너 · 창 없는 벽의 네온 간판.
	await capture("16_arcade_juice_bar", Vector3(-2.2, 1.8, 3.8), Vector3(-6.8, 1.6, 3.6))
	await capture("17_arcade_juice_close", Vector3(-3.6, 1.6, 6.0), Vector3(-5.8, 1.2, 6.8))
	await capture("17b_arcade_soda_fridge", Vector3(-3.3, 1.5, 7.2), Vector3(-5.0, 1.0, 8.1))
	await capture("18_arcade_claw_corner", Vector3(7.0, 1.9, 3.4), Vector3(11.2, 1.8, 8.2))
	await capture("19_arcade_hall_signs", Vector3(0.0, 1.8, 2.0), Vector3(0, 2.6, -7.0))
	await capture("20_arcade_hall_left", Vector3(1.5, 1.8, -2.0), Vector3(-6.4, 2.4, -2.6))
	await capture("21_arcade_back_wall", Vector3(1.0, 1.8, 3.6), Vector3(0.5, 2.4, 8.8))
	await capture("22_arcade_vendor", Vector3(-4.2, 1.65, 4.0), Vector3(-6.6, 1.4, 4.0))
	check(game.lounge._arcade_room.find_child("JuiceVendor", true, false) != null, "오락실 주스 가게 직원이 있다")
	check(game.table.get_node("Pub").find_child("Window", true, false) == null, "오락실에는 창문이 없다(간판이 창에 겹쳐 잘리지 않게)")
	if failed:
		quit(1)
		return
	print("PASS: map v3 furnishings present, touch wobble, bar mugs — screenshots in ", ProjectSettings.globalize_path(output))
	quit()
