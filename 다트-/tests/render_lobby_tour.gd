extends SceneTree
## 로비 디자인 개편(2026-10-30) 화면 캡처: 3D 배경·로고·다트 포인터 조준/비행/꽂힘·방 만들기·참가·설정.
## 실행(화면 필요): Godot --path . --script res://tests/render_lobby_tour.gd
## 결과: res://.godot/lobby_render/*.png (Git 제외)
var main: Node
var output: String = "res://.godot/lobby_render"


func _initialize() -> void:
	_run.call_deferred()


func capture(label: String, wait: float = 0.25) -> void:
	await create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	assert(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK)


func _run() -> void:
	main = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	var front: Control = main.front
	await capture("01_lobby_intro", 0.35)
	await capture("02_lobby_home", 1.6)
	# 첫 메뉴 버튼 위로 포인터를 옮겨 조준 자세를 본다.
	var menu_button: Button = _find_button(front, "")
	root.warp_mouse(menu_button.get_global_rect().get_center() + Vector2(120, 0))
	await capture("03_pointer_aim", 0.3)
	# 버튼에 다트를 던진다(꽂히는 순간 페이지가 바뀌므로 비행 중간을 찍는다).
	var pointer: Control = front._pointer
	pointer._launch(menu_button.get_global_rect().get_center() + Vector2(120, 0), null, 1.5)
	await capture("04_pointer_flight", 0.1)
	await capture("05_pointer_stuck", 0.2)
	# 과녁 클릭 = 연습 다트.
	var board_point: Vector2 = front._backdrop.board_screen_point() + Vector2(18, -30)
	print("board on screen: ", board_point)
	var thrown: bool = front._backdrop.throw_at(board_point)
	assert(thrown, "lobby board throw")
	await capture("06_board_practice", 0.6)
	front._multi()
	await capture("07_multi", 0.3)
	front._create(false)
	await capture("08_create_room", 0.3)
	front._create(true)
	await capture("09_create_solo", 0.3)
	front._join()
	await capture("10_join", 0.3)
	front.show_home()
	main.open_settings()
	await capture("11_settings", 0.3)
	main.settings_panel._close()
	main.queue_free()
	await process_frame
	print("PASS: lobby tour screenshots")
	quit()


func _find_button(node: Node, text: String) -> Button:
	for child in node.find_children("*", "Button", true, false):
		if (child as Button).text == text and (child as Button).is_visible_in_tree():
			return child
	return null
