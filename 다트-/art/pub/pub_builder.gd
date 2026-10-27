extends SceneTree
## 아트 생성물 전부를 코드로 다시 만드는 생성기. 게임 실행 때는 쓰이지 않는다.
## 만드는 것:
##   art/characters/chr_*.tscn   캐릭터 4종 + 바텐더(관절 이름 포함 — character_factory.gd)
##   art/pub/pub.tscn            아트 쇼케이스 펍(실제 다트판 규격 1.73m·2.37m)
##   art/pub/pub_game.tscn       F5 실제 경기 방(팀 규칙 좌표 — game_room_builder.gd)
## 디자인 수치를 바꾼 뒤 아래 명령으로 한 번 실행해 .tscn 을 덮어쓴다.
##   godot --headless --path <다트- 폴더> --script res://art/pub/pub_builder.gd
## 완료 로그: ART BUILD COMPLETE
##
## 주의: 생성 결과를 에디터에서 손으로 고친 뒤 이 생성기를 돌리면 수정이 사라진다.
## 손으로 고칠 씬은 다른 이름(예: pub_custom.tscn)으로 저장해 두고 그 씬을 쓰자.
## 같은 코드로 다시 만들면 파일이 한 바이트도 다르지 않다(무작위 없음, unique_id 제거 — save_scene 참고).

const MeshKit = preload("res://art/mesh_kit.gd")
const CharacterFactory = preload("res://art/characters/character_factory.gd")
const BoardSpec = preload("res://art/board_spec.gd")
const BoardArt = preload("res://art/board_art.gd")
const PubParts = preload("res://art/pub/pub_parts.gd")
const GameRoomBuilder = preload("res://art/pub/game_room_builder.gd")

const PUB_SCENE_PATH := "res://art/pub/pub.tscn"
const GAME_ROOM_SCENE_PATH := "res://art/pub/pub_game.tscn"
const CHARACTER_SCENE_PATH := "res://art/characters/chr_%s.tscn"
## Godot 4.6 이 저장할 때마다 노드마다 새로 붙이는 무작위 번호.
const UNIQUE_ID_PATTERN := " unique_id=\\d+"

# 펍 전체에서 같이 쓰는 기본 재질. build() 에서 한 번 만든다.
var wood: StandardMaterial3D
var trim: StandardMaterial3D
var green: StandardMaterial3D
var brass: StandardMaterial3D
var cream: StandardMaterial3D
var dark: StandardMaterial3D


func _initialize() -> void:
	call_deferred("build")


## node 와 모든 자식을 하나의 .tscn 으로 저장한다.
func save_scene(node: Node, path: String) -> void:
	MeshKit.own_tree(node, node)
	var packed := PackedScene.new()
	var error := packed.pack(node)
	if error == OK:
		error = ResourceSaver.save(packed, path)
	if error != OK:
		push_error("저장 실패 %s (오류 %d)" % [path, error])
		quit(1)
		return
	# unique_id 는 저장할 때마다 무작위로 바뀌어, 다시 만들 때마다 Git diff 가 수천 줄 생긴다.
	# 이 생성물은 그 번호가 필요 없으므로(팀의 다른 .tscn 에도 없다) 지워서 같은 코드 → 같은 파일로 만든다.
	var text := FileAccess.get_file_as_string(path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(RegEx.create_from_string(UNIQUE_ID_PATTERN).sub(text, "", true))
	file.close()
	print("SAVED ", path)


func build() -> void:
	wood = PubParts.wood()
	trim = PubParts.trim()
	green = PubParts.green()
	brass = PubParts.brass()
	cream = PubParts.cream()
	dark = PubParts.dark()
	# 1) 캐릭터를 먼저 저장한다. 펍·경기 방·PlayerView 는 이 씬들을 인스턴스로 참조한다.
	for i in range(4):
		var character := CharacterFactory.create(i)
		save_scene(character, CHARACTER_SCENE_PATH % CharacterFactory.NAMES[i].to_lower())
		character.free()
	var bartender := CharacterFactory.create_bartender()
	save_scene(bartender, CHARACTER_SCENE_PATH % CharacterFactory.BARTENDER_NAME.to_lower())
	bartender.free()
	# 2) 펍: 건물 → 다트판 벽 → 카드 테이블·캐릭터 → 바 → 조명 순서로 쌓는다.
	var pub := Node3D.new()
	pub.name = "Pub"
	root.add_child(pub)
	architecture(pub)
	board_wall(pub)
	table_area(pub)
	bar_area(pub)
	lighting(pub)
	save_scene(pub, PUB_SCENE_PATH)
	pub.free()
	# 3) F5 실제 경기 방. 배치는 game/table/table.gd(TableView) 상수를 따른다.
	var game_room := GameRoomBuilder.build()
	root.add_child(game_room)
	save_scene(game_room, GAME_ROOM_SCENE_PATH)
	game_room.free()
	print("ART BUILD COMPLETE")
	quit()

## 건물 뼈대: 바닥 판자, 벽, 초록 징두리 패널, 놋쇠 난간, 천장 보, 창문, 왼쪽 벽 간판.
func architecture(p: Node3D) -> void:
	MeshKit.box(p, "Foundation", Vector3(12.2, 0.25, 14), Vector3(0, -0.18, 2), trim)
	for i in range(24):
		for j in range(5):
			var mat := MeshKit.material("Floor_" + str((i + j * 3) % 5), ["785b42", "846247", "70523b", "8d6a4a", "796048"][(i + j * 3) % 5])
			MeshKit.box(p, "Floorboard", Vector3(0.485, 0.07, 2.78), Vector3(-5.75 + i * 0.5, -0.025, -3.6 + j * 2.8), mat)
	MeshKit.box(p, "BackWall", Vector3(12, 4.2, 0.18), Vector3(0, 2.1, -5.0), cream)
	MeshKit.box(p, "LeftWall", Vector3(0.18, 4.2, 14), Vector3(-6, 2.1, 2), cream)
	MeshKit.box(p, "RightWall", Vector3(0.18, 4.2, 14), Vector3(6, 2.1, 2), cream)
	for i in range(20):
		var x := -5.7 + i * 0.6
		MeshKit.box(p, "BackPanel", Vector3(0.56, 1.15, 0.08), Vector3(x, 0.6, -4.86), green)
		MeshKit.box(p, "PanelInset", Vector3(0.43, 0.88, 0.025), Vector3(x, 0.6, -4.80), MeshKit.material("InsetGreen", "1d3b34"))
	for side in [-1.0, 1.0]:
		MeshKit.box(p, "SideWainscot", Vector3(0.12, 1.2, 14), Vector3(side * 5.87, 0.6, 2), green)
		MeshKit.box(p, "SideRail", Vector3(0.16, 0.06, 14), Vector3(side * 5.83, 1.22, 2), brass)
		MeshKit.box(p, "SideCornice", Vector3(0.22, 0.18, 14), Vector3(side * 5.82, 3.95, 2), trim)
		for z in [-4.7, -0.3, 4.1, 8.5]:
			MeshKit.box(p, "Pillar", Vector3(0.25, 4, 0.25), Vector3(side * 5.7, 2, z), trim)
	MeshKit.box(p, "BackRail", Vector3(12, 0.06, 0.12), Vector3(0, 1.22, -4.78), brass)
	MeshKit.box(p, "Cornice", Vector3(12, 0.18, 0.25), Vector3(0, 3.95, -4.80), trim)
	for z in [-3.8, 1.6, 6.8]:
		MeshKit.box(p, "CeilingBeam", Vector3(12, 0.18, 0.18), Vector3(0, 4.1, z), trim)
	# 뒤쪽 장식 창문: 사진 배경 없이 도형으로만 만든 밤 유리.
	for x in [-4.1, 4.1]:
		MeshKit.box(p, "WindowFrame", Vector3(2.15, 1.9, 0.14), Vector3(x, 2.5, -4.8), trim)
		MeshKit.box(p, "NightGlass", Vector3(1.96, 1.7, 0.03), Vector3(x, 2.5, -4.70), MeshKit.material("BlueNightGlass", "344f5b", 0.15, 0.12))
		for dx in [-0.65, 0.0, 0.65]:
			MeshKit.box(p, "Mullion", Vector3(0.04, 1.7, 0.05), Vector3(x + dx, 2.5, -4.66), brass)
		MeshKit.box(p, "MullionHorizontal", Vector3(1.96, 0.04, 0.05), Vector3(x, 2.5, -4.66), brass)
		MeshKit.box(p, "Sill", Vector3(2.26, 0.11, 0.30), Vector3(x, 1.54, -4.66), wood)
	# 왼쪽 벽 간판: 다트판과 헷갈리지 않게 네모 액자로 둔다.
	var sign := Node3D.new()
	sign.name = "HouseRulesSign"
	p.add_child(sign)
	sign.position = Vector3(-5.78, 2.25, 1)
	sign.rotation.y = PI / 2
	MeshKit.box(sign, "Frame", Vector3(1.75, 1.25, 0.09), Vector3.ZERO, brass)
	MeshKit.box(sign, "Paper", Vector3(1.66, 1.16, 0.04), Vector3(0, 0, 0.06), dark)
	MeshKit.label(sign, "Title", "좋은 한 발,\n좋은 사람들.", Vector3(0, 0.16, 0.09), 55, Color("e0c58d"), 0.0018)
	MeshKit.label(sign, "Caption", "다 티   /   소 셜   클 럽", Vector3(0, -0.33, 0.09), 21)

## 다트판 벽: 초록 패널, 간판, 캐비닛, 다트판, 투척 레인과 투척선(Oche).
## 다트판 링 반지름 = BoardLayout(팀 판정 기준) 비율 × BoardSpec.SCORING_RADIUS. 숫자 순서도 BoardLayout 것을 쓴다(board_art.gd).
func board_wall(p: Node3D) -> void:
	MeshKit.box(p, "FeaturePanel", Vector3(3.2, 3.55, 0.16), Vector3(0, 1.86, -4.74), green)
	for x in [-1.5, 1.5]:
		MeshKit.box(p, "FeatureBorder", Vector3(0.025, 3.3, 0.025), Vector3(x, 1.87, -4.64), brass)
	MeshKit.label(p, "Brand", "다 티", Vector3(0, 3.16, -4.62), 110, Color("e6ca90"), 0.0025)
	MeshKit.label(p, "BrandSubtitle", "소 셜   클 럽", Vector3(0, 2.88, -4.61), 30)
	MeshKit.label(p, "LaneTitle", "01   /   멋진 한 발을 던져요", Vector3(0, 0.79, -4.60), 25)
	MeshKit.box(p, "Cabinet", Vector3(1.38, 1.55, 0.10), Vector3(0, 1.80, -4.58), wood)
	MeshKit.box(p, "CabinetBacking", Vector3(1.26, 1.43, 0.02), Vector3(0, 1.80, -4.52), dark)
	# 다트판 앞면은 PUB_BOARD_CENTER.z(-4.45). 투척선은 그 앞 2.37m.
	var board := Node3D.new()
	board.name = "Dartboard"
	board.position = BoardSpec.PUB_BOARD_CENTER
	p.add_child(board)
	# 판 그림은 art/board_art.gd 가 그린다(F5 경기 과녁과 같은 코드). 쇼케이스는 실제 크기(득점 반지름 0.17m).
	BoardArt.build(board, BoardLayout.DEFAULT_NUMBERS, BoardSpec.SCORING_RADIUS)
	MeshKit.box(p, "LaneMat", Vector3(1.5, 0.025, 3.0), Vector3(0, 0.025, -3.08), MeshKit.material("LaneVelvet", "244d43"))
	for x in [-0.69, 0.69]:
		MeshKit.box(p, "LanePinstripe", Vector3(0.015, 0.006, 2.85), Vector3(x, 0.042, -3.08), brass)
	MeshKit.box(p, "Oche", Vector3(1.48, 0.035, 0.06), Vector3(0, 0.047, BoardSpec.PUB_BOARD_CENTER.z + BoardSpec.THROW_DISTANCE), brass)
	var lane_label := MeshKit.label(p, "OcheText", "투 척 선", Vector3(0, 0.048, -1.84), 28, Color("dcc68f"), 0.0013)
	lane_label.rotation.x = -PI / 2
	for side in [-1.0, 1.0]:
		for z in [-4.1, -2.85, -1.6]:
			MeshKit.cylinder(p, "StanchionBase", 0.14, 0.04, Vector3(side * 1.05, 0.04, z), brass)
			MeshKit.cylinder(p, "Stanchion", 0.025, 0.87, Vector3(side * 1.05, 0.48, z), brass)
			MeshKit.sphere(p, "Finial", 0.055, Vector3(side * 1.05, 0.94, z), brass)
		for z in [-4.1, -2.85]:
			for j in range(8):
				var t := float(j) / 8
				var u := float(j + 1) / 8
				MeshKit.rod(p, "VelvetRope", Vector3(side * 1.05, 0.91 - sin(t * PI) * 0.17, z + t * 1.25), Vector3(side * 1.05, 0.91 - sin(u * PI) * 0.17, z + u * 1.25), 0.022, MeshKit.material("RopeBurgundy", "854c40"))

## 원형 카드 테이블(지름 약 2.4m) + 4인 자리(좌석 색 매트·전시용 카드 3장·스툴)
## + 레인 왼쪽 캐릭터 라인업. 테이블 카드는 상호작용 없는 장식이다(손패 7장 연출은 후속 작업).
func table_area(p: Node3D) -> void:
	# 테이블 모양은 pub_parts.gd(F5 경기 방과 같은 부품). 쇼케이스는 지름 2.48m·높이 0.765m.
	var t := PubParts.round_table(p, Vector3(-0.5, 0, 3.2), 1.24, 0.765)
	for i in range(4):
		var angle := i * PI / 2
		var seat := Node3D.new()
		seat.name = "Seat_" + str(i + 1)
		t.add_child(seat)
		seat.rotation.y = angle
		var color := MeshKit.material("PlayerMat_" + str(i), PlayerLook.hex(i))
		MeshKit.box(seat, "PlayerMat", Vector3(0.68, 0.008, 0.34), Vector3(0, 0.785, 0.80), color)
		for card_index in range(3):
			var x := (card_index - 1) * 0.19
			MeshKit.box(seat, "CardPaper", Vector3(0.17, 0.008, 0.25), Vector3(x, 0.796, 0.81), MeshKit.material("CardPaper", "ecdfbc"))
			MeshKit.box(seat, "CardArtwork", Vector3(0.145, 0.003, 0.14), Vector3(x, 0.802, 0.78), color)
			var symbol := MeshKit.label(seat, "CardGlyph", ["+", "x2", "o"][card_index], Vector3(x, 0.808, 0.78), 42, Color("f8ecca"), 0.0012)
			symbol.rotation.x = -PI / 2
		PubParts.stool(t, Vector3(sin(angle) * 1.64, 0, cos(angle) * 1.64), green)
	# 레인 왼쪽 캐릭터 라인업: 저장된 캐릭터 씬을 인스턴스로 넣는다(캐릭터 씬을 고치면 펍에도 반영).
	# 받침 모양으로도 구분한다: 원(삐죽이)·삼각(바가지)·사각(반짝이)·마름모(뽀글이).
	for i in range(4):
		var character_scene: PackedScene = load(CHARACTER_SCENE_PATH % CharacterFactory.NAMES[i].to_lower())
		var c: Node3D = character_scene.instantiate()
		p.add_child(c)
		c.position = Vector3(-4.75 + i * 0.76, 0.025, -0.35)
		c.rotation.y = 0.20
		var plinth := MeshKit.cylinder(p, "CastMarker", 0.31, 0.025, c.position + Vector3(0, -0.007, 0), MeshKit.material("CastColor_" + str(i), PlayerLook.hex(i)), PlayerLook.MAT_SIDES[i])
		if i == 3:
			plinth.rotation.y = PI / 4
	MeshKit.label(p, "CastTitle", "단 골 손 님", Vector3(-3.6, 2.25, -0.7), 35, Color("eddbab"), 0.002)
	for i in range(3):
		PubParts.stool(p, Vector3(2.15 + (i % 2) * 0.8, 0, 1.6 + i * 1.3), green)

## 오른쪽 바: 카운터, 발 난간, 병 선반(라벨 없는 병), 컵, 스툴, 구석 화분.
## 바텐더 NPC 자리와 합동 라운드(바텐더와 한잔) 연출은 여기 앞 공간을 쓰면 된다.
func bar_area(p: Node3D) -> void:
	MeshKit.box(p, "BarBody", Vector3(1.0, 1.02, 5.8), Vector3(4.35, 0.51, 1.2), green)
	MeshKit.box(p, "BarTop", Vector3(1.3, 0.16, 6.0), Vector3(4.35, 1.1, 1.2), wood)
	MeshKit.box(p, "CounterInlay", Vector3(0.025, 0.01, 5.85), Vector3(3.75, 1.187, 1.2), brass)
	MeshKit.rod(p, "FootRail", Vector3(3.66, 0.19, -1.45), Vector3(3.66, 0.19, 3.85), 0.028, brass)
	for z in [-0.9, 0.2, 1.3, 2.4, 3.5]:
		MeshKit.box(p, "BarPanel", Vector3(0.022, 0.73, 0.9), Vector3(3.837, 0.54, z), MeshKit.material("InsetGreen", "1d3b34"))
		MeshKit.box(p, "PanelBrass", Vector3(0.03, 0.015, 0.74), Vector3(3.82, 0.84, z), brass)
	var shelf := Node3D.new()
	shelf.name = "BottleLibrary"
	p.add_child(shelf)
	shelf.position = Vector3(5.78, 0, 0.8)
	shelf.rotation.y = -PI / 2
	MeshKit.box(shelf, "ShelfBack", Vector3(4.2, 2.2, 0.12), Vector3(0, 2.2, 0), trim)
	for y in [1.25, 1.93, 2.61, 3.29]:
		MeshKit.box(shelf, "Shelf", Vector3(4.4, 0.07, 0.34), Vector3(0, y, 0.12), wood)
		MeshKit.box(shelf, "ShelfLight", Vector3(4.0, 0.018, 0.02), Vector3(0, y - 0.045, 0.24), MeshKit.material("WarmLight", "ffd9a0", 0, 1.2))
	for row in range(3):
		for j in range(11):
			var x := -1.83 + j * 0.365
			var y := 1.30 + row * 0.68
			var col: String = ["3c695b", "af7948", "516a77", "7b4641"][(j + row) % 4]
			var mat := MeshKit.material("Bottle_" + str((j + row) % 4), col, 0.15)
			MeshKit.cylinder(shelf, "Bottle", 0.067, 0.26, Vector3(x, y + 0.13, 0.14), mat, 8, 0.052)
			MeshKit.cylinder(shelf, "BottleNeck", 0.028, 0.12, Vector3(x, y + 0.32, 0.14), mat, 8)
			MeshKit.box(shelf, "BlankLabel", Vector3(0.075, 0.09, 0.008), Vector3(x, y + 0.15, 0.202), cream)
	for z in [-0.7, 0.1, 2.3]:
		MeshKit.cylinder(p, "Coaster", 0.11, 0.008, Vector3(4.1, 1.189, z), brass)
		MeshKit.cylinder(p, "Cup", 0.06, 0.16, Vector3(4.1, 1.27, z), cream, 12)
	for z in [-1.0, 1.1, 3.2]:
		PubParts.stool(p, Vector3(3.05, 0, z), green)
	# 구석 화분: 각진 가구 사이에 다른 실루엣을 하나 둔다.
	PubParts.plant(p, Vector3(-5, 0, 6.5))
	# 바텐더 NPC 시안(카운터 안쪽, 손님 쪽 -X 를 본다). 움직임·합동 라운드 연출은 후속.
	var bartender: Node3D = (load(CHARACTER_SCENE_PATH % CharacterFactory.BARTENDER_NAME.to_lower()) as PackedScene).instantiate()
	bartender.position = Vector3(5.3, 0, 1.6)
	bartender.rotation.y = -PI / 2
	p.add_child(bartender)

## 조명: 어두운 초록 배경 + 약한 주광 + 펜던트 3개(레인·테이블·바) + 다트판 스포트라이트.
## 밝기를 바꿀 때는 light_energy 를 조절한다. 그림자는 주광과 스포트만 켠다(성능).
func lighting(p: Node3D) -> void:
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("182924")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("aabac0")
	world.environment.ambient_light_energy = 0.32
	world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	p.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "SoftKey"
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_color = Color("ffe2b6")
	sun.light_energy = 0.28
	sun.shadow_enabled = true
	sun.shadow_bias = 0.12
	sun.shadow_normal_bias = 1.5
	p.add_child(sun)
	for pos in [Vector3(0, 3.05, -2.75), Vector3(-0.5, 3.0, 3.2), Vector3(4.0, 3.1, 0.5)]:
		PubParts.pendant(p, pos, 4.1)
	var spot := SpotLight3D.new()
	spot.name = "BoardSpot"
	spot.position = Vector3(0, 3.2, -3.7)
	spot.light_color = Color("ffe6c4")
	spot.light_energy = 0.65
	spot.spot_range = 4
	spot.spot_angle = 40
	spot.shadow_enabled = true
	p.add_child(spot)
	spot.look_at(BoardSpec.PUB_BOARD_CENTER)
