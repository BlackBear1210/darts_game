extends SceneTree
## 원형 테이블 네 자리 모두 생성/일어서기 시 상판에 끼지 않고 바닥에 서야 한다.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var room := RoomState.new()
	for id in range(1, 5): room.add_player(id, "자리 %d" % id)
	var game := (load("res://game/game.tscn") as PackedScene).instantiate() as GameView
	root.add_child(game)
	game.configure(room, 1)
	await create_timer(0.6).timeout
	for id in range(1, 5):
		assert(game.actors[id].position.y < 0.08, "생성 후 테이블 위로 올라가면 안 된다")
		assert(game.can_sit(id), "생성 위치에서 자기 의자에 앉을 수 있어야 한다")
		game.force_seat(id)
		game._accept_seat(id)
		assert(not game.is_seated(id))
	await create_timer(0.6).timeout
	for id in range(1, 5):
		assert(game.actors[id].position.y < 0.08, "일어선 뒤 바닥 높이를 유지해야 한다")
		assert(game.can_sit(id))
	game.queue_free()
	await process_frame
	await _check_capacity_seats()
	print("PASS: four seats spawn and stand up outside table, floor physics, seating reach, capacity seat order + hidden empty seats")
	quit()


## 2026-11-07 인원수 자리: 2인 방은 마주 보는 0·2번, 3인 방은 0·1·2번 자리만 깔고 나머지 의자·매트는 숨긴다.
func _check_capacity_seats() -> void:
	var duo := RoomState.new()
	duo.settings.capacity = 2
	duo.add_player(1, "방장")
	duo.add_bots(1)
	assert(duo.players[0].seat == 0 and duo.players[1].seat == 2, "2인 방 = 왼쪽·오른쪽 자리")
	assert(duo.shown_seats() == [0, 2])
	var trio := RoomState.new()
	trio.settings.capacity = 3
	trio.add_player(1, "방장")
	assert(trio.shown_seats() == [0, 1, 2], "빈자리도 인원수만큼 깔린다")
	trio.add_bots(2)
	assert(trio.players.map(func(p: RoomPlayer) -> int: return p.seat) == [0, 1, 2])
	var table := (load("res://game/table/table.tscn") as PackedScene).instantiate() as TableView
	root.add_child(table)
	await process_frame
	table.show_seats(duo.shown_seats())
	var pub := table.get_node("Pub")
	for seat in range(4):
		var shown: bool = seat in [0, 2]
		for part: String in ["SeatMat_%d", "SeatRug_%d", "SeatStool_%d", "SeatLabel_%d"]:
			var node := pub.find_child(part % (seat + 1), true, false) as Node3D
			assert(node != null and node.visible == shown, "%s 보임=%s" % [part % (seat + 1), shown])
	# 방 그림을 다시 만들어도(오락실 테마 전환) 숨긴 자리는 숨긴 채다.
	table.rebuild_pub([])
	for part: String in ["SeatStool_2", "SeatMat_4"]:
		assert(not (table.get_node("Pub").find_child(part, true, false) as Node3D).visible, part + " 다시 만든 뒤에도 숨김")
	table.queue_free()
	await process_frame
