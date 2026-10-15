extends SceneTree
## 실제 D3D12 로비에서 개발 로그인 입력과 프로필 표시를 확인한다.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var lobby := main.get_node("Lobby") as LobbyView
	var backend := main.get_node("Backend") as BackendConnection
	assert(lobby.get_node("%AccountControls").visible)
	assert(lobby.get_node("%PasswordInput").secret)
	assert(lobby.get_node("%HostButton").disabled)
	lobby.get_node("%NameInput").text = "화면시험"
	lobby.get_node("%PasswordInput").text = "render-test-password"
	lobby.get_node("%LoginButton").pressed.emit()
	var deadline: int = Time.get_ticks_msec() + 10000
	while backend.profile.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(not backend.profile.is_empty(), backend.status)
	assert(lobby.get_node("%PasswordInput").text.is_empty())
	assert("0경기" in lobby.get_node("%ProfileLabel").text)
	var folder: String = "res://.godot/accounts_render"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder + "/01_account_profile.png")
	DisplayServer.window_set_size(Vector2i(960, 540))
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder + "/02_account_small.png")
	print("PASS: actual account login UI, masked/cleared password, profile, 1920x1080 and 960x540 rendering")
	quit()
