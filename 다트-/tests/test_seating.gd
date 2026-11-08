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
	# 2026-11-08 방장이 대기실에서 인원수를 다시 정한다(RoomState.resize).
	var host_room := RoomState.new()
	host_room.settings.capacity = 4
	host_room.add_player(1, "방장")
	host_room.add_player(2, "손님")
	host_room.resize(2, 0)
	assert(host_room.settings.capacity == 2 and host_room.shown_seats() == [0, 1], "4→2명: 앉은 두 자리만 남는다(빈 의자 없음)")
	host_room.resize(1, 0)
	assert(host_room.settings.capacity == 2, "들어온 사람 수보다 적게는 못 줄인다")
	host_room.resize(3, 0)
	assert(host_room.shown_seats() == [0, 1, 2] and host_room.add_player(3, "셋째") and host_room.find_player(3).seat == 2, "2→3명: 깔린 빈 의자 = 다음 사람 자리")
	var practice := RoomState.new()
	practice.settings.solo = true
	practice.settings.capacity = 4
	practice.settings.bot_count = 3
	practice.add_player(1, "나")
	practice.add_bots(3)
	practice.resize(2, 1)
	assert(practice.players.size() == 2 and practice.settings.bot_count == 1, "연습 방 봇 3 → 1")
	practice.resize(3, 2)
	assert(practice.players.size() == 3 and practice.settings.capacity == 3, "연습 방 봇 1 → 2")
	practice.phase = RoomState.Phase.PLAYING
	practice.resize(4, 3)
	assert(practice.settings.capacity == 3, "경기 중에는 인원수를 안 바꾼다")
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
	_check_even_seats(table)
	table.queue_free()
	await process_frame
	TableView.arrange_seats([0, 1, 2, 3])


## 2026-11-08: 인원수만큼 원형 테이블을 똑같이 나눈다 — 모든 자리가 가운데에서 같은 거리, 이웃끼리 360/인원 도.
## 그림(의자·매트)도 같은 자리로 옮겨지고, 경기 자리(seat_spot)도 같은 값이다.
func _check_even_seats(table: TableView) -> void:
	for shown: Array[int] in [[0, 2] as Array[int], [0, 1, 2] as Array[int], [0, 1, 3] as Array[int], [0, 1, 2, 3] as Array[int]]:
		var layout: Dictionary = TableView.seat_layout(shown)
		var step: float = 360.0 / shown.size()
		for rank in range(shown.size()):
			var at: Vector3 = layout[shown[rank]]
			var next: Vector3 = layout[shown[(rank + 1) % shown.size()]]
			assert(is_equal_approx(Vector2(at.x - TableView.TABLE_CENTER.x, at.z - TableView.TABLE_CENTER.z).length(), TableView.SEAT_RADIUS), "자리 거리 같음")
			var gap: float = rad_to_deg(wrapf(TableView.seat_yaw(next) - TableView.seat_yaw(at), 0.0, TAU))
			assert(absf(gap - step) < 0.01, "%s 이웃 사이 %.1f도(기대 %.1f)" % [shown, gap, step])
	assert(TableView.seat_layout([0, 1, 2, 3])[3].is_equal_approx(TableView.SEATS[3]), "4인 배치 = 기본 SEATS")
	# 3인: 의자가 실제로 새 자리로 돈다. 경기 자리(seat_spot)도 같은 곳이다.
	table.show_seats([0, 1, 2])
	TableView.arrange_seats([0, 1, 2])
	var chair := table.get_node("Pub").find_child("SeatStool_1", true, false) as Node3D
	assert(chair.global_position.is_equal_approx(table.global_transform * TableView.seat_spot(0)), "3인 1번 의자 = 경기 자리 %s / %s" % [chair.global_position, TableView.seat_spot(0)])
	assert(absf(wrapf(chair.rotation.y - TableView.seat_yaw(TableView.seat_spot(0)), -PI, PI)) < 0.001, "3인 1번 의자가 테이블을 본다")
	table.show_seats([0, 1, 2, 3])
	assert((table.get_node("Pub").find_child("SeatStool_1", true, false) as Node3D).global_position.is_equal_approx(TableView.SEATS[0]), "4인으로 돌아오면 제자리")
