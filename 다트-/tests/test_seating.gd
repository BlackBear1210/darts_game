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
	print("PASS: four seats spawn and stand up outside table, floor physics, seating reach")
	quit()
