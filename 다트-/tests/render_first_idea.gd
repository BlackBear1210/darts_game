extends SceneTree
## 실제 렌더러로 좌석·카드·결과·방해 화면을 저장하는 시각 검증용 장면.

var _output: String


func _initialize() -> void:
	_output = OS.get_cmdline_user_args()[0]
	call_deferred("_render_all")


func _render_all() -> void:
	for count in [2, 3, 4]:
		for seat in range(count):
			await _render_seat(count, seat, false)
	await _render_seat(4, 1, true)
	print("PASS: rendered every 2/3/4-player seat, cards, results, spectator and emote")
	quit()


func _render_seat(count: int, seat: int, spectator: bool) -> void:
	var room := RoomState.new()
	room.match_id = 1
	var names := ["산호", "민트", "노랑", "보라"]
	for index in range(count): room.add_player(index + 1, names[index])
	room.phase = RoomState.Phase.PLAYING
	var game := (load("res://game/game.tscn") as PackedScene).instantiate() as GameView
	root.add_child(game)
	game.configure(room, seat + 1)
	game.controller.set_process(false)
	game.controller.config.transition_seconds = 0.05
	game.controller.state.phase = MatchState.Phase.PREPARING
	game.controller.state.turn_index = 0 if spectator else seat
	game.controller.state.turn_id = 1
	game.controller.state.darts_left = 2
	game.controller._turn_end = Time.get_ticks_msec() / 1000.0 + 12.0
	var hud := (load("res://ui/game_hud.tscn") as PackedScene).instantiate() as GameHUD
	root.add_child(hud)
	hud.configure(game.controller, game.throw_input)
	hud.render(room, seat + 1, "")
	game.controller.changed.emit()
	await create_timer(0.1).timeout
	game.controller.state.phase = MatchState.Phase.AIMING
	game.controller.changed.emit()
	await _capture("%d_seat_%d%s" % [count, seat, "_spectator" if spectator else ""])
	if count == 4 and seat == 0:
		game._show_throw({"peer_id": 1, "x": 0.0, "y": 0.0, "duration": 0.05})
		await create_timer(0.1).timeout
		var dart := game.get_node("Darts").get_child(0) as DartView
		assert(dart.global_position.distance_to(Vector3.UP * TableView.RAISED_HEIGHT) < 0.001)
		game.controller.state.last_hit = {"peer_id": 1, "x": 0.0, "y": 0.0, "base": 50, "points": 50, "request_id": 1}
		game.controller.state.players[0].score = 50
		game.controller.state.darts_left = 1
		game.controller.changed.emit()
		await _capture("4_dart_landed")
		hud.get_node("Root/EmoteOverlay").show_event(game.controller.state.players[1], 0.01, 1.0)
		await create_timer(0.2).timeout
		await _capture("4_emote")
		game.controller.state.phase = MatchState.Phase.CARDS
		game.controller.state.round_number = 2
		game.controller._phase_end = Time.get_ticks_msec() / 1000.0 + 15.0
		game.controller._cards.begin(game.controller.state.players)
		game.controller.private_cards = game.controller._cards.private_snapshot(seat + 1)
		game.controller.changed.emit()
		await _capture("4_cards_candidates")
		game.controller._cards.choose(game.controller.state.players[0], 0, 3)
		game.controller.private_cards = game.controller._cards.private_snapshot(1)
		game.controller.changed.emit()
		hud._select_card(game.controller.state.players[0].hand[0].uid)
		await _capture("4_cards_target")
		game.controller.state.phase = MatchState.Phase.FINISHED
		for index in range(count): game.controller.state.players[index].score = [460, 700, 400, 460][index]
		game.controller.changed.emit()
		await _capture("4_results")
	root.remove_child(hud)
	hud.queue_free()
	root.remove_child(game)
	game.queue_free()
	await process_frame


func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	assert(picture.save_png(_output.path_join(label + ".png")) == OK)
