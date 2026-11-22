extends SceneTree

const BoardChaos = preload("res://game/board/board_chaos.gd")
## F5 실제 경기에 디자인(펍 방·다트판·캐릭터·다트)이 제대로 붙었는지 화면 없이 검사한다.
##   & $godot --headless --path . --script res://tests/test_game_look.gd
## 실패하면 대개 "규칙 좌표(TableView)를 바꾸고 생성기를 다시 안 돌렸다"는 뜻이다:
##   & $godot --headless --path . --script res://art/pub/pub_builder.gd

const PUB_GAME_SCENE := "res://art/pub/pub_game.tscn"
## 승인 기본 차림: 머리·눈을 포함한 피부와 별도 상의·하의·신발.
const WORN_PART_COUNT := 4
const MotionEmotes = preload("res://art/characters/motion_emotes.gd")
const Outfit = preload("res://art/characters/player_outfit.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_room_matches_rules()
	await _check_table_scene()
	await _check_characters_and_rig()
	await _check_player_view()
	await _check_motion_emotes()
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
	assert(room.get_node("Lane").find_children("*Rope*", "", true, false).is_empty())
	assert(room.find_child("NoEntryText", true, false) == null)
	assert(room.find_child("ChalkScores", true, false) is Label3D)
	assert(room.find_child("BoardSpot", true, false) is SpotLight3D)
	room.free()


## 테이블 장면: 보이는 방 + 보이지 않는 충돌. 칠판 글자 바꾸기.
func _check_table_scene() -> void:
	var table := (load("res://game/table/table.tscn") as PackedScene).instantiate() as TableView
	root.add_child(table)
	await process_frame
	assert(table.get_node_or_null("Pub") != null)
	assert(table.board.global_position == TableView.BOARD_CENTER and table.board.scale.is_equal_approx(Vector3.ONE * TableView.BOARD_SCALE))
	# TableView 가 만든 충돌 몸체에는 보이는 메시가 붙지 않는다(그림은 Pub 담당).
	var bodies := 0
	for child in table.get_children():
		if child is StaticBody3D:
			bodies += 1
			assert(child.collision_layer != 4, "중앙 진입 제한벽이 남아 있으면 안 된다")
			assert(child.find_children("*", "MeshInstance3D", true, false).is_empty())
	# 바닥2·천장2·벽8(2026-11-12 중앙 레인 벽 6개 제거)
	# ·테이블·바·NPC 테이블·당구대·럼주통4·작은 통4·NPC 스툴2 = 26
	# + 도면 v3 가구 상자(TableView.decor_blocks: 생맥주 통·뒤 조리대·연습 과녁·양동이·소파·안락의자·낮은 탁자·상자·자루·냉장고)
	# + 다트 머신 몸체 1(2026-11-07 — 과녁 면 0.12m 뒤부터 과녁 벽까지)
	# + 펍 전용 가구(꾸미기 방 상자, TableView.pub_only_blocks — 오락실 테마에서는 꺼진다. 비스트로 테이블은 2026-11-21 삭제)
	assert(bodies == 28 + TableView.decor_blocks().size() + TableView.pub_only_blocks().size(), "충돌 몸체 수 %d" % bodies)
	# 고정 몸체 안에 움직이는 캐리지와 전자 가림판이 있다.
	assert(table.machine.find_child("HorizontalCarriage", true, false) != null)
	assert(table.machine.find_child("ContinuousCatchPan", true, false) is MeshInstance3D)
	var hatch := table.machine.find_child("LeftHatch", true, false) as Node3D
	assert(hatch != null and is_zero_approx(hatch.rotation.y))
	table.machine.show_chaos(BoardChaos.from_ages({"cover": BoardChaos.SHUTTER_CLOSE}), 0.0)
	assert(absf(hatch.rotation.y) > 1.0)
	var leaves := table.machine.find_child("LeftConcertina", true, false) as Node3D
	assert(leaves.visible and leaves.get_child_count() == BoardChaos.SHUTTER_LEAVES)
	table.machine.show_chaos(BoardChaos.rest(), 0.0)
	assert(table.machine.find_child("StatusText", true, false) is Label3D)
	table.set_chalk_scores("점 수\n\n● 시험  42")
	assert((table.find_child("ChalkScores", true, false) as Label3D).text.contains("42"))
	table.queue_free()
	await process_frame


## 네 자리 캐릭터 + 바텐더: 자세마다 맞는 모션을 틀고, 팔 자세가 온몸 모션 위에 얹힌다.
func _check_characters_and_rig() -> void:
	for seat in range(4):
		var worn := PlayerLook.character(seat)
		var parts := _worn_parts(worn)
		assert(parts.size() == WORN_PART_COUNT, "기본 차림이 아닙니다: " + str(parts))
		for expected in ["Body", "Top_01", "Bottom_01", "Shoes_01"]:
			assert(expected in parts, "모듈 부품 누락: " + expected)
		for mesh: MeshInstance3D in worn.find_children("*", "MeshInstance3D", true, false):
			var material := mesh.mesh.surface_get_material(0) as StandardMaterial3D
			assert(material != null and mesh.skin != null, "재질 또는 스킨이 빠졌습니다")
		# 상의 색 선택은 피부·머리·눈 재질에 영향을 주지 않는다.
		var top := worn.find_child("Top_01", true, false) as MeshInstance3D
		var body := worn.find_child("Body", true, false) as MeshInstance3D
		Outfit.tint_shirt(worn, 1)
		assert(top.get_surface_override_material(0) != null and body.get_surface_override_material(0) == null)
		Outfit.tint_shirt(worn, 0)
		assert(top.get_surface_override_material(0) == null)
		if seat == 0:
			var pants := worn.find_child("Bottom_01", true, false) as MeshInstance3D
			var base_mesh: Mesh = pants.mesh
			var skin: Skin = pants.skin
			var base_vertices: PackedVector3Array = base_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			for style in range(1, Outfit.PANTS_COLORS.size()):
				Outfit.dress(worn, {"pants": style})
				assert(pants.skin == skin and pants.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] != base_vertices)
			Outfit.undress(worn)
			assert(pants.mesh == base_mesh and Outfit.sanitize({}).pants == 0)
		worn.free()
	var model := PlayerLook.character(0)
	root.add_child(model)
	var rig := CharacterMotion.new(model, 0.0)
	var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var animations := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for preset: String in ["afraid", "cheer", "dance_02", "dance_03", "dance_05", "freaky", "walk"]:
		assert(animations.has_animation("Tripo_" + preset), "수신 프리셋 누락: " + preset)
	# 팔·머리 덧씌움은 모디파이어 결과라 뼈 값이 아니라 뼈에 붙은 노드(BoneAttachment3D)로 잰다.
	var hand_l := model.find_child("hand_L", true, false) as Node3D
	var hand_r := model.find_child("hand_R", true, false) as Node3D
	# 처음부터 앉아 있으면 앉는 동작 없이 앉은 모션이다.
	await _animate(rig, 0.1, 0.0, CharacterMotion.Posture.SEAT, false, false)
	assert(rig.clip == CharacterMotion.SEATED)
	assert(_bone_height(skeleton, "hips") < 0.75, "앉았는데 골반이 높습니다")
	_check_clothing_edges(model, skeleton)
	# 일어서면 일어나는 모션을 끝낸 뒤 서기로 돌아간다.
	await _animate(rig, 0.1, 0.0, CharacterMotion.Posture.STAND, false, false)
	assert(rig.clip == CharacterMotion.STAND_UP)
	await _animate(rig, animations.get_animation(CharacterMotion.STAND_UP).length + 0.2, 0.0, CharacterMotion.Posture.STAND, false, false)
	assert(rig.clip == CharacterMotion.IDLE)
	# 숙이기: 골반이 낮아진다.
	await _animate(rig, 0.6, 0.0, CharacterMotion.Posture.CROUCH, false, false)
	assert(rig.clip == CharacterMotion.CROUCH_IDLE and _bone_height(skeleton, "hips") < 0.55)
	# 걷기: 발이 앞뒤로 엇갈린다.
	await _animate(rig, 0.3, 1.0, CharacterMotion.Posture.STAND, false, false)
	assert(rig.clip == CharacterMotion.WALK)
	await _animate(rig, 0.1, 1.0, CharacterMotion.Posture.STAND, false, false)
	# 점프: 공중 모션이고 뼈대 자체는 위로 뜨지 않는다(높이는 PlayerView 물리).
	await _animate(rig, 0.3, 0.0, CharacterMotion.Posture.STAND, true, false)
	assert(rig.clip == CharacterMotion.JUMP and _bone_height(skeleton, "root") < 0.01)
	# 조준: 걷는 중에도 오른손이 어깨보다 높이 올라온다.
	await _animate(rig, 0.8, 1.0, CharacterMotion.Posture.STAND, false, true)
	assert(hand_r.global_position.y > 1.3, "조준 팔이 안 올라갑니다")
	# 던지기: 휘두른 뒤 팔이 내려온다.
	rig.play_throw()
	await _animate(rig, 1.2, 0.0, CharacterMotion.Posture.STAND, false, false)
	assert(hand_r.global_position.y < 1.0, "던진 뒤 팔이 안 내려옵니다")
	# 카드 들기: 왼손이 가슴 앞으로 올라오고, 부채는 손을 따라간다.
	rig.holding_cards = true
	var fan := Node3D.new()
	fan.name = "LeftHandCards"
	rig.attach_cards(fan)
	await _animate(rig, 0.6, 1.0, CharacterMotion.Posture.STAND, false, false)
	assert(hand_l.global_position.y > 0.85, "카드 든 왼손이 안 올라갑니다")
	assert(fan.global_position.distance_to(hand_l.global_position) < 0.2)
	# 왕머리: 머리 뼈가 커진다.
	rig.head_scale = 2.0
	await _animate(rig, 0.8, 0.0, CharacterMotion.Posture.STAND, false, false)
	assert((model.find_child("head", true, false) as Node3D).global_basis.get_scale().y > 1.8, "왕머리가 안 커집니다")
	model.queue_free()
	var bartender := (load("res://art/characters/chr_bartender.tscn") as PackedScene).instantiate() as Node3D
	assert(CharacterRig.new(bartender).is_valid() and bartender.find_child("Vest", true, false) != null)
	bartender.free()


## 가까운 정점이 다른 손·발에 붙어 옷이 긴 가시로 늘어나는 내보내기 오류를 잡는다.
func _check_clothing_edges(model: Node3D, skeleton: Skeleton3D) -> void:
	for part in ["Top_01", "Bottom_01"]:
		var instance := model.find_child(part, true, false) as MeshInstance3D
		var transforms: Array[Transform3D] = []
		for bind in range(instance.skin.get_bind_count()):
			var bone: int = skeleton.find_bone(instance.skin.get_bind_name(bind))
			transforms.append(skeleton.get_bone_global_pose(bone) * instance.skin.get_bind_pose(bind))
		for surface in range(instance.mesh.get_surface_count()):
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var influences: int = bones.size() / vertices.size()
			var posed := PackedVector3Array()
			for vertex in range(vertices.size()):
				var point := Vector3.ZERO
				for influence in range(influences):
					var index: int = vertex * influences + influence
					point += transforms[bones[index]] * vertices[vertex] * weights[index]
				posed.append(point)
			for triangle in range(0, indices.size(), 3):
				for edge in range(3):
					var a: int = indices[triangle + edge]
					var b: int = indices[triangle + (edge + 1) % 3]
					if vertices[a].distance_to(vertices[b]) < 0.05:
						assert(posed[a].distance_to(posed[b]) < 0.2, part + "의 면이 비정상적으로 늘어났습니다")
	print("PASS: seated clothing has no stretched spike edges")


## 실제 시간으로 프레임을 돌린다. AnimationPlayer 가 실제 시간으로 흐르고 뼈에는 프레임이 지나야 반영된다.
func _animate(rig: CharacterMotion, seconds: float, speed: float, posture: CharacterMotion.Posture, airborne: bool, aiming: bool) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		rig.animate(root.get_process_delta_time(), speed, posture, airborne, 0.0, aiming)
		await process_frame


func _check_motion_emotes() -> void:
	var model := PlayerLook.character(0)
	root.add_child(model)
	var rig := CharacterMotion.new(model)
	rig.holding_cards = true
	for index in range(MotionEmotes.CLIPS.size()):
		assert(rig.play_emote(index))
		await _animate(rig, 0.15, 1.0, CharacterMotion.Posture.STAND, false, false)
		assert(rig.emote_clip == MotionEmotes.CLIPS[index] and rig.clip == MotionEmotes.CLIPS[index])
		assert((rig.get("_layer") as CharacterPoseLayer).left.weight > 0.7, "모션 중에도 왼손 카드 자세 유지")
		assert(rig.play_emote(MotionEmotes.STOP))
		await _animate(rig, 0.05, 0.0, CharacterMotion.Posture.STAND, false, false)
		assert(rig.emote_clip.is_empty() and rig.clip == CharacterMotion.IDLE)
	assert(not rig.play_emote(-1) and not rig.play_emote(99))
	# 새 승인 리깅은 앉은 감정표현에도 기존 승인 발 위치를 유지한다.
	var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var foot_probe := BoneAttachment3D.new()
	foot_probe.bone_name = "foot.L"
	skeleton.add_child(foot_probe)
	await _animate(rig, 2.3, 0.0, CharacterMotion.Posture.SEAT, false, false)
	var seated_foot: Vector3 = foot_probe.global_position
	assert(rig.play_emote(1))
	await _animate(rig, 0.6, 0.0, CharacterMotion.Posture.SEAT, false, false)
	assert(foot_probe.global_position.distance_to(seated_foot) < 0.035, "앉은 감정표현에서 승인 다리 자세가 풀렸습니다")
	rig.stop_emote()
	await _animate(rig, 2.3, 0.0, CharacterMotion.Posture.STAND, false, false)
	# 짧은 프리셋은 끝나면 자동으로 기본 동작으로 복귀한다.
	assert(rig.play_emote(5))
	await _animate(rig, 1.2, 0.0, CharacterMotion.Posture.STAND, false, false)
	assert(rig.emote_clip.is_empty() and rig.clip == CharacterMotion.IDLE)
	# 앉은 춤은 엉덩이·다리를 고정하고 계속된다. 점프·조준·투척은 중단한다.
	assert(rig.play_emote(0))
	await _animate(rig, 0.1, 0.0, CharacterMotion.Posture.SEAT, false, false)
	assert(not rig.emote_clip.is_empty(), "앉은 춤이 중단됐습니다")
	rig.play_emote(MotionEmotes.STOP)
	for reason in range(3):
		assert(rig.play_emote(0))
		await _animate(rig, 0.02, 0.0, CharacterMotion.Posture.STAND, reason == 0, reason == 1)
		if reason == 2:
			rig.play_throw()
		assert(rig.emote_clip.is_empty(), "점프/조준/투척 시 모션 취소")
	model.queue_free()
	await process_frame
	print("PASS: 7 motion emotes while moving, left-hand cards, stop, natural completion, gameplay interruption")


func _worn_parts(model: Node3D) -> Array[String]:
	var parts: Array[String] = []
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.visible:
			parts.append(str(mesh.name))
	return parts


func _bone_height(skeleton: Skeleton3D, bone: String) -> float:
	return skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin.y


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
	view.seated = false
	view.position.y = 0.0
	view.velocity = Vector3(0, 0, -PlayerView.SPEED)
	assert(view.can_emote(), "이동 중에도 모션 시작 가능")
	view.velocity = Vector3.ZERO
	var model := view.get_node("Model") as Node3D
	assert(model.scene_file_path == PlayerLook.CHARACTER_SCENE)
	assert(is_zero_approx(model.rotation.y), "캐릭터 정면은 PlayerView 정면과 같은 -Z 입니다")
	var visuals := view.find_children("*", "VisualInstance3D", true, false)
	assert(visuals.size() > WORN_PART_COUNT)
	for visual: VisualInstance3D in visuals:
		assert(visual.layers == 1 << 3, "레이어가 다른 조각: " + str(visual.name))
	assert(view.get("_rig") is CharacterMotion)
	view.queue_free()
	await process_frame


## 다트판: 카드로 숫자 순서가 바뀌면 그림 숫자도 같이 바뀐다.
func _check_board_follows_layout() -> void:
	var board := (load("res://game/board/board.tscn") as PackedScene).instantiate() as BoardView
	root.add_child(board)
	await process_frame
	var face := board.get_node("Face")
	# 2026-11-07: 칸·숫자는 Face/Spin/SectorGroup0~4(피자 조각) 아래에 있다 → 깊이 찾기.
	assert(face.find_child("Number_20", true, false) != null and face.find_child("Triple_20", true, false) != null)
	var shuffled := BoardLayout.new()
	shuffled.numbers = BoardLayout.DEFAULT_NUMBERS.duplicate()
	shuffled.numbers.reverse()
	board.show_layout(shuffled)
	await process_frame
	# 12시(0번 칸) 숫자 글자가 새 순서의 첫 숫자와 같다.
	var top := face.find_child("Number_%d" % shuffled.numbers[0], true, false) as Label3D
	assert(top.text == str(shuffled.numbers[0]) and top.position.x > -0.001 and top.position.x < 0.001 and top.position.y > 0)
	assert(face.find_children("Triple_*", "MeshInstance3D", true, false).size() == 40)
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
