extends SceneTree
## F5 실제 경기에 디자인(펍 방·다트판·캐릭터·다트)이 제대로 붙었는지 화면 없이 검사한다.
##   & $godot --headless --path . --script res://tests/test_game_look.gd
## 실패하면 대개 "규칙 좌표(TableView)를 바꾸고 생성기를 다시 안 돌렸다"는 뜻이다:
##   & $godot --headless --path . --script res://art/pub/pub_builder.gd

const PUB_GAME_SCENE := "res://art/pub/pub_game.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_room_matches_rules()
	await _check_table_scene()
	_check_characters_and_rig()
	await _check_player_view()
	await _check_board_follows_layout()
	await _check_dart_paint_and_scale()
	print("PASS: game look — room signature, collision-only table, chalk scores, 4 rigged characters + bartender, seat/crouch/aim/throw poses, per-seat render layers, board numbers follow layout, dart flight color + landed scale")
	quit()


## 방 그림에 저장된 배치 서명 = 지금 TableView 상수. 다르면 생성기를 다시 돌려야 한다.
func _check_room_matches_rules() -> void:
	var room := (load(PUB_GAME_SCENE) as PackedScene).instantiate() as Node3D
	assert(str(room.get_meta("layout_signature", "")) == TableView.layout_signature(), "pub_game.tscn 이 TableView 상수와 다릅니다 → pub_builder.gd 재실행")
	for group in ["Shell", "BoardWall", "Lane", "Barrels", "TableAndSeats", "Bar", "NpcCorner", "PoolTable", "Decor", "Windows", "Furnishings", "PubOnly", "Lights"]:
		assert(room.get_node_or_null(group) != null, "방 묶음 없음: " + group)
	# 방 그림에는 충돌이 없어야 한다(충돌은 TableView 만 소유).
	assert(room.find_children("*", "CollisionObject3D", true, false).is_empty())
	# 자리 4개마다 스툴·매트·이름 글자.
	for i in range(TableView.SEATS.size()):
		assert(room.get_node_or_null("TableAndSeats/SeatStool_%d" % (i + 1)) != null)
		assert(room.get_node_or_null("TableAndSeats/SeatRug_%d" % (i + 1)) != null)
	assert(room.find_child("ChalkScores", true, false) is Label3D)
	assert(room.find_child("BoardSpot", true, false) is SpotLight3D)
	room.free()


## 테이블 장면: 보이는 방 + 보이지 않는 충돌. 칠판 글자 바꾸기.
func _check_table_scene() -> void:
	var table := (load("res://game/table/table.tscn") as PackedScene).instantiate() as TableView
	root.add_child(table)
	await process_frame
	assert(table.get_node_or_null("Pub") != null)
	assert(table.board.position == TableView.BOARD_CENTER and table.board.scale.is_equal_approx(Vector3.ONE * TableView.BOARD_SCALE))
	# TableView 가 만든 충돌 몸체에는 보이는 메시가 붙지 않는다(그림은 Pub 담당).
	var bodies := 0
	for child in table.get_children():
		if child is StaticBody3D:
			bodies += 1
			assert(child.find_children("*", "MeshInstance3D", true, false).is_empty())
	# 바닥2·천장2·벽8·레인 벽3(앞+양옆)·테이블·바·NPC 테이블·당구대·럼주통4·작은 통4·NPC 스툴2 = 29
	# + 도면 v3 가구 상자 9개(TableView.decor_blocks: 생맥주 통·뒤 조리대·연습 과녁·양동이·소파·안락의자·낮은 탁자·상자·자루) = 38
	assert(bodies == 29 + TableView.decor_blocks().size(), "충돌 몸체 수 %d" % bodies)
	table.set_chalk_scores("점 수\n\n● 시험  42")
	assert((table.find_child("ChalkScores", true, false) as Label3D).text.contains("42"))
	table.queue_free()
	await process_frame


## 캐릭터 4종 + 바텐더: 관절 이름이 있고, 몸짓이 자세마다 관절을 움직인다.
func _check_characters_and_rig() -> void:
	for seat in range(4):
		var model := PlayerLook.character(seat)
		var rig := CharacterRig.new(model, 0.0)
		assert(rig.is_valid(), "관절 없음: " + PlayerLook.CHARACTER_SCENES[seat])
		root.add_child(model)
		# 앉기: 다리가 앞으로(음수) 든다.
		_animate(rig, 1.0, 0.0, CharacterRig.Posture.SEAT, false, false)
		assert(absf(rig.leg_l.rotation.x - CharacterRig.SEAT_LEG_ANGLE) < 0.05)
		# 숙이기: 다리가 줄고 몸이 낮아진다.
		_animate(rig, 1.0, 0.0, CharacterRig.Posture.CROUCH, false, false)
		assert(rig.leg_l.scale.y < 0.7 and rig.body.position.y < CharacterRig.HIP_HEIGHT * 0.7)
		# 서서 조준: 오른팔을 앞-위로 든다.
		_animate(rig, 1.0, 0.0, CharacterRig.Posture.STAND, false, true)
		assert(absf(rig.arm_r.rotation.x - CharacterRig.AIM_ARM_ANGLE) < 0.05)
		# 던지기: 팔이 휘둘러 내려간다.
		rig.play_throw()
		_animate(rig, CharacterRig.THROW_SECONDS * 0.95, 0.0, CharacterRig.Posture.STAND, false, false)
		assert(rig.arm_r.rotation.x > -1.0)
		# 걷기: 다리가 앞뒤로 엇갈린다.
		_animate(rig, 0.2, 1.0, CharacterRig.Posture.STAND, false, false)
		assert(absf(rig.leg_l.rotation.x - rig.leg_r.rotation.x) > 0.1)
		model.queue_free()
	var bartender := (load("res://art/characters/chr_bartender.tscn") as PackedScene).instantiate() as Node3D
	assert(CharacterRig.new(bartender).is_valid() and bartender.find_child("Vest", true, false) != null)
	bartender.free()


func _animate(rig: CharacterRig, seconds: float, speed: float, posture: CharacterRig.Posture, airborne: bool, aiming: bool) -> void:
	var frames := int(seconds * 60)
	for i in range(frames):
		rig.animate(1.0 / 60.0, speed, posture, airborne, 0.0, aiming)


## PlayerView: 자리 캐릭터를 입고, 모든 조각이 자기 자리 렌더 레이어에 있다(자기 카메라에서만 빠진다).
func _check_player_view() -> void:
	assert(PlayerView.COLORS == PlayerLook.COLORS)
	var player := MatchPlayer.new()
	player.peer_id = 7
	player.display_name = "시험"
	player.seat = 2
	var view := (load("res://game/player/player.tscn") as PackedScene).instantiate() as PlayerView
	root.add_child(view)
	view.configure(player)
	await process_frame
	var model := view.get_node("Model") as Node3D
	assert(model.scene_file_path == PlayerLook.CHARACTER_SCENES[2])
	assert(is_equal_approx(model.rotation.y, PI))
	var visuals := view.find_children("*", "VisualInstance3D", true, false)
	assert(visuals.size() > 20)
	for visual: VisualInstance3D in visuals:
		assert(visual.layers == 1 << 3, "레이어가 다른 조각: " + str(visual.name))
	assert((view.get_node("Model/Body/ArmR") as Node3D) != null)
	view.queue_free()
	await process_frame


## 다트판: 카드로 숫자 순서가 바뀌면 그림 숫자도 같이 바뀐다.
func _check_board_follows_layout() -> void:
	var board := (load("res://game/board/board.tscn") as PackedScene).instantiate() as BoardView
	root.add_child(board)
	await process_frame
	var face := board.get_node("Face")
	assert(face.get_node_or_null("Number_20") != null and face.get_node_or_null("Triple_20") != null)
	var shuffled := BoardLayout.new()
	shuffled.numbers = BoardLayout.DEFAULT_NUMBERS.duplicate()
	shuffled.numbers.reverse()
	board.show_layout(shuffled)
	await process_frame
	# 12시(0번 칸) 숫자 글자가 새 순서의 첫 숫자와 같다.
	var top := face.get_node("Number_%d" % shuffled.numbers[0]) as Label3D
	assert(top.text == str(shuffled.numbers[0]) and top.position.x > -0.001 and top.position.x < 0.001 and top.position.y > 0)
	assert(face.find_children("Triple_*", "MeshInstance3D", false, false).size() == 20)
	board.queue_free()
	await process_frame


## 다트: 깃 = 던진 사람 색, 꽂히면 과녁 배율에 맞게 커진다.
func _check_dart_paint_and_scale() -> void:
	var dart := (load("res://game/dart/dart.tscn") as PackedScene).instantiate() as DartView
	root.add_child(dart)
	dart.paint(PlayerLook.COLORS[1])
	var flight := dart.get_node("Visual/FlightHorizontal") as MeshInstance3D
	assert((flight.material_override as StandardMaterial3D).albedo_color == PlayerLook.COLORS[1])
	dart.fly(Vector3(0, 1.5, 0), Vector3(0, 1.5, -3), 0.2)
	await create_timer(0.35).timeout
	assert((dart.get_node("Visual") as Node3D).scale.is_equal_approx(Vector3.ONE * DartView.LANDED_SCALE))
	dart.queue_free()
	await process_frame
