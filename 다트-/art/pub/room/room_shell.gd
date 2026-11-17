extends "res://art/pub/room/room_kit.gd"
## 펍 방 껍데기: 바닥·천장·벽 8면(징두리·허리 난간·코니스·코브·기둥·칸 아치 틀) · 창 구멍 · 바깥 벽돌 껍데기 · 오락실 창 막이.
## 디자인 담당 소유(2026-11-17 game_room_builder.gd 에서 나눔). 장면(pub_game.tscn) 안 묶음 = Shell · WindowPlugs · Outside/PubExterior.
## [고칠 때] 벽 칸 나누기·창 자리는 room_kit.gd(_walls·_all_fixtures·_window_spots)에 있다. 창틀·커튼·유리는 room_decor.gd(_window).

# ─────────────────────────────── 바닥·벽·천장 ───────────────────────────────

## 바닥 한 장 · 벽 8면 · 튀어나온 모서리 둥근 기둥 · 천장.
static func build_shell(p: Node3D) -> void:
	var f := _faces()
	var ceiling: float = TableView.CEILING_HEIGHT
	var hall: Rect2 = TableView.DART_HALL
	var lounge: Rect2 = TableView.LOUNGE
	var edge: float = TableView.WALL_THICKNESS / 2.0
	# 바닥: 칸마다 판 한 장(윗면 y = 0). 헤링본 무늬는 세계 좌표로 그려서 두 판 사이에서 끊기지 않는다.
	var floor_mat := _floor_material()
	for slab: Rect2 in [Rect2(hall.position.x - edge, hall.position.y - edge, hall.size.x + edge * 2.0, hall.size.y + edge),
			Rect2(lounge.position.x - edge, lounge.position.y, lounge.size.x + edge * 2.0, lounge.size.y + edge)]:
		MeshKit.box(p, "Floor", Vector3(slab.size.x, 0.1, slab.size.y), Vector3(slab.get_center().x, -0.05, slab.get_center().y), floor_mat)
	for wall: Dictionary in _walls():
		_wall_run(p, wall, ceiling)
	# 튀어나온 모서리(다트 홀 입구 양옆): 둥근 월넛 기둥이 두 벽 띠의 끝을 덮고, 그 위 코브는 모서리를 따라 휘돈다.
	var cornice_top: float = ceiling - COVE_R - 0.06
	for corner: Vector2 in [Vector2(f.hall_x0, f.step_z), Vector2(f.hall_x1, f.step_z)]:
		var column := RoundKit.rounded_profile(PackedVector2Array([Vector2(0, 0), Vector2(0.22, 0), Vector2(0.22, 0.17), Vector2(0.17, 0.22),
			Vector2(0.16, 0.3), Vector2(0.16, cornice_top - 0.2), Vector2(0.21, cornice_top - 0.08), Vector2(0.23, cornice_top), Vector2(0, cornice_top)]), 0.025, 3)
		RoundKit.lathe(p, "CornerColumn", column, Vector3(corner.x, 0, corner.y), _walnut(), 28)
		var cove := MeshKit.mesh_node(p, "CoveCorner", RoundKit.lathe_mesh(_cove_profile(), 12, PI / 2.0), Vector3(corner.x, ceiling, corner.y), _cove_mat())
		cove.rotation.y = 0.0 if corner.x < 0.0 else -PI / 2.0
	# 천장(크림 회벽). 칸마다 한 장이고 그림자를 만들지 않는다. 보는 없다 — 벽 위 코브가 천장으로 부드럽게 넘어간다.
	# 2026-11-16: 벽 밖으로 0.2m → 0.1m 만 나오게 줄였다. 건물 바깥 벽돌 껍데기(build_exterior, 벽 경계 +0.15m) 안에 숨는다.
	for roof_rect: Rect2 in [Rect2(hall.position.x - 0.1, hall.position.y - 0.1, hall.size.x + 0.2, hall.size.y + 0.1),
			Rect2(lounge.position.x - 0.1, lounge.position.y, lounge.size.x + 0.2, lounge.size.y + 0.1)]:
		var roof := MeshKit.box(p, "Ceiling", Vector3(roof_rect.size.x, 0.08, roof_rect.size.y),
			Vector3(roof_rect.get_center().x, ceiling + 0.04, roof_rect.get_center().y), _ceiling_mat())
		roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## 벽 한 면: 회벽 판 + (끊긴 곳 빼고) 걸레받이·누빔 징두리·허리 난간 + 코니스·숨은 빛·코브 + 칸마다 기둥·아치 틀.
## 띠들은 들어간 모서리에서 서로 엇갈려 맞물리고(같은 단면이라 이음이 깔끔하다), 튀어나온 모서리는 둥근 기둥이 덮는다.
static func _wall_run(p: Node3D, wall: Dictionary, ceiling: float) -> void:
	var from: Vector2 = wall.from
	var to: Vector2 = wall.to
	var along: Vector2 = wall.along
	var inward: Vector2 = wall.inward
	var length: float = wall.length
	# 1) 회벽 판: 들어간 모서리 쪽 끝만 0.18m 늘려 벽 속에 숨긴다(튀어나온 끝을 늘리면 방 안으로 삐져나온다).
	#    2026-11-16: 창 자리는 판을 끊고 구멍(창턱 아래 판 + 아치 위 판)을 낸다 → 창 너머로 진짜 바깥이 보인다.
	var cursor: float = -(0.0 if wall.convex_from else 0.18)
	var end_u: float = length + (0.0 if wall.convex_to else 0.18)
	for fixture: Dictionary in wall.fixtures:
		if not bool(fixture.get("window", false)):
			continue
		var hole_u: float = fixture.u
		_wall_piece(p, wall, cursor, hole_u - GLASS_HALF, ceiling)
		_window_hole(p, wall, hole_u, ceiling)
		cursor = hole_u + GLASS_HALF
	_wall_piece(p, wall, cursor, end_u, ceiling)
	# 2) 아래 띠 셋(문·과녁 판넬 자리는 끊는다).
	for segment: Vector2 in _segments(wall):
		var mid := (segment.x + segment.y) / 2.0
		var span := segment.y - segment.x
		_on_wall(p, "Baseboard", _band_mesh("base", _base_profile(), span), wall, mid, 0.0, _walnut_dark())
		_on_wall(p, "Wainscot", RoundKit.channel_panel_mesh(span, WAINSCOT_TOP - BASE_TOP, 0.18, 0.04), wall, mid, BASE_TOP, _leather())
		_on_wall(p, "ChairRail", _band_mesh("rail", _rail_profile(), span), wall, mid, WAINSCOT_TOP, _walnut())
	# 3) 위 띠: 코니스 선반 + 그 위 숨은 빛 + 코브(끊김 없이).
	var cornice_y: float = ceiling - COVE_R - 0.16
	_on_wall(p, "Cornice", _band_mesh("cornice", _cornice_profile(), length), wall, length / 2.0, cornice_y, _walnut())
	var strip := _on_wall(p, "CoveGlowStrip", BoxMesh.new(), wall, length / 2.0, cornice_y + 0.115, _glow(), 0.05)
	(strip.mesh as BoxMesh).size = Vector3(length, 0.03, 0.05)
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cove := _on_wall(p, "Cove", _band_mesh("cove", _cove_profile(), length), wall, length / 2.0, ceiling, _cove_mat())
	cove.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 4) 칸: 경계마다 기둥, 칸마다 둥근 머리 아치 틀(고정물 칸은 고정물 가운데에 맞춘다).
	var frame_top: float = cornice_y - 0.22
	var bays: Array = wall.bays
	for i in range(bays.size()):
		var bay: Dictionary = bays[i]
		if i > 0:
			var post_u: float = bay.from
			var post_height: float = cornice_y - RAIL_TOP
			_on_wall(p, "Pilaster", MeshKit.rounded_box_mesh(Vector3(0.14, post_height, 0.05), 0.02, 3), wall, post_u, RAIL_TOP + post_height / 2.0, _walnut(), 0.025)
			_on_wall(p, "PilasterCap", MeshKit.rounded_box_mesh(Vector3(0.2, 0.07, 0.075), 0.025, 3), wall, post_u, cornice_y - 0.035, _walnut(), 0.037)
		var fixture: Dictionary = bay.fixture
		var center: float = (float(bay.from) + float(bay.to)) / 2.0
		var width: float = float(bay.to) - float(bay.from)
		if not fixture.is_empty():
			if not bool(fixture.frame):
				continue
			center = float(fixture.u)
			width = 2.0 * minf(center - float(bay.from), float(bay.to) - center)
		var frame_width := width - 0.34
		if frame_width < 0.6:
			continue
		var path := RoundKit.arch_path(frame_width, RAIL_TOP, frame_top, minf(0.5, frame_width / 2.0), 8)
		var mesh := RoundKit.sweep_mesh("bayframe|%.3f|%.3f" % [frame_width, frame_top], RoundKit.bead_profile(0.055, 0.03),
			RoundKit.wall_path_rails(path, Vector3.ZERO, Vector3.RIGHT, Vector3.BACK), false, false)
		_on_wall(p, "BayFrame", mesh, wall, center, 0.0, _walnut())


## 벽 판 한 토막(벽 시작점에서 잰 u0 ~ u1). 판은 벽 안쪽 면에서 바깥으로 0.18m 두께다.
static func _wall_piece(p: Node3D, wall: Dictionary, u0: float, u1: float, ceiling: float) -> void:
	if u1 - u0 < 0.001:
		return
	var from: Vector2 = wall.from
	var along: Vector2 = wall.along
	var inward: Vector2 = wall.inward
	_plank(p, "Wall", from + along * ((u0 + u1) / 2.0) - inward * 0.09, along, u1 - u0, 0.18, ceiling / 2.0, ceiling, _plaster())


## 창 구멍 둘레 벽(2026-11-16): 창턱 아래 판(WallSill) + 아치 위를 파낸 판(WallArch). 구멍 = 아래 네모 + 위 반원.
## 구멍 안쪽 옆면(두께 0.18m)이 보여서 벽이 진짜 두께 있는 벽처럼 보인다.
static func _window_hole(p: Node3D, wall: Dictionary, u: float, ceiling: float) -> void:
	var from: Vector2 = wall.from
	var along: Vector2 = wall.along
	var inward: Vector2 = wall.inward
	_plank(p, "WallSill", from + along * u - inward * 0.09, along, GLASS_HALF * 2.0, 0.18, WINDOW_BOTTOM / 2.0, WINDOW_BOTTOM, _plaster())
	var spring: float = WINDOW_TOP - GLASS_HALF
	var outline := PackedVector2Array()
	for s in range(17):
		var angle := PI * s / 16.0
		outline.append(Vector2(cos(angle) * GLASS_HALF, spring + sin(angle) * GLASS_HALF))
	outline.append(Vector2(-GLASS_HALF, ceiling))
	outline.append(Vector2(GLASS_HALF, ceiling))
	_on_wall(p, "WallArch", RoundKit.solid_shape_mesh("window_arch_top|%.3f" % ceiling, outline, 0.18), wall, u, 0.0, _plaster())


## 펍 건물 바깥 벽(2026-11-16): 창 밖 3D 거리에서 펍 건물도 "건물"로 보이게(편집기 지도 · 옆 창으로 비스듬히 보이는 라운지 벽).
## 회벽 판(안쪽 면 ~ 0.18m) 바깥, 충돌 벽 끝(0.30m)까지 0.12m 두께 벽돌 껍데기. 창 자리는 같은 구멍 + 바깥 돌 창턱·아치 테.
## 아래 = 보도 밑 · 위 = 천장 + 난간(StreetOutside.PARAPET). 지붕 윗면도 덮는다. 바깥 재질(밤거리 셰이더)이라 방 조명을 받지 않는다.
## 모서리: 벽 방향(x 를 따라가는 벽 / z 를 따라가는 벽)마다 늘이고 줄이는 길이를 달리해 두 껍데기가 겹치지 않고 꼭 맞는다.
static func build_exterior(p: Node3D) -> void:
	var ceiling: float = TableView.CEILING_HEIGHT
	var top: float = ceiling + StreetOutside.PARAPET
	var bottom: float = StreetOutside.WALK_TOP - 0.05
	var skin := 0.12
	var spring: float = WINDOW_TOP - GLASS_HALF
	var arch := PackedVector2Array()
	for s in range(17):
		var angle := PI * s / 16.0
		arch.append(Vector2(cos(angle) * GLASS_HALF, spring + sin(angle) * GLASS_HALF))
	arch.append(Vector2(-GLASS_HALF, top))
	arch.append(Vector2(GLASS_HALF, top))
	var arch_mesh := RoundKit.solid_shape_mesh("exterior_arch|%.3f" % top, arch, skin)
	var trim_path := RoundKit.arch_path(GLASS_HALF * 2.0 + 0.1, WINDOW_BOTTOM, WINDOW_TOP + 0.05, GLASS_HALF + 0.05, 14)
	var trim_mesh := RoundKit.sweep_mesh("exterior_window_trim", RoundKit.bead_profile(0.16, 0.05),
		RoundKit.wall_path_rails(trim_path, Vector3.ZERO, Vector3.RIGHT, Vector3.BACK), false, false)
	for wall: Dictionary in _walls():
		var along: Vector2 = wall.along
		var inward: Vector2 = wall.inward
		var from: Vector2 = wall.from
		var along_x: bool = absf(along.x) > 0.5
		# 방 안쪽에서 들어간 모서리(= 바깥으로 튀어나온 모서리)는 늘이고, 방 안쪽으로 튀어나온 모서리(= 바깥 오목)는 줄인다.
		var stretch: float = 0.30 if along_x else 0.18
		var shrink: float = 0.18 if along_x else 0.30
		var start: float = shrink if wall.convex_from else -stretch
		var end: float = float(wall.length) - shrink if wall.convex_to else float(wall.length) + stretch
		var pieces: Array = []
		var cursor := start
		for fixture: Dictionary in wall.fixtures:
			if bool(fixture.get("window", false)):
				pieces.append(Vector2(cursor, float(fixture.u) - GLASS_HALF))
				cursor = float(fixture.u) + GLASS_HALF
		pieces.append(Vector2(cursor, end))
		for piece: Vector2 in pieces:
			if piece.y - piece.x < 0.001:
				continue
			var mid: Vector2 = from + along * ((piece.x + piece.y) / 2.0) - inward * (0.18 + skin / 2.0)
			var size := Vector3(absf(along.x) * (piece.y - piece.x) + absf(along.y) * skin, top - bottom, absf(along.y) * (piece.y - piece.x) + absf(along.x) * skin)
			var box := BoxMesh.new()
			box.size = size
			StreetOutside.shaded(p, "BrickWall", box, Vector3(mid.x, (top + bottom) / 2.0, mid.y), StreetOutside.BRICK, 0, 0.0, 1)
		# 창 자리: 창턱 아래 · 아치 위 벽돌 + 바깥 돌 창턱 · 아치 테.
		for fixture: Dictionary in wall.fixtures:
			if not bool(fixture.get("window", false)):
				continue
			var at: Vector2 = from + along * float(fixture.u)
			var sill_mid: Vector2 = at - inward * (0.18 + skin / 2.0)
			var sill := BoxMesh.new()
			sill.size = Vector3(absf(along.x) * GLASS_HALF * 2.0 + absf(along.y) * skin, WINDOW_BOTTOM - bottom, absf(along.y) * GLASS_HALF * 2.0 + absf(along.x) * skin)
			StreetOutside.shaded(p, "BrickWall", sill, Vector3(sill_mid.x, (WINDOW_BOTTOM + bottom) / 2.0, sill_mid.y), StreetOutside.BRICK, 0, 0.0, 1)
			var face: Vector2 = at - inward * 0.30
			var outward_yaw := _yaw(-inward)
			# 아치 위 판: 앞면(로컬 +Z = 바깥) = 껍데기 바깥 면, 뒤로(안쪽으로) skin 두께.
			var upper := StreetOutside.shaded(p, "BrickWall", arch_mesh, Vector3(face.x, 0, face.y), StreetOutside.BRICK, 0, 0.0, 1)
			upper.rotation.y = outward_yaw
			var ledge := BoxMesh.new()
			ledge.size = Vector3(GLASS_HALF * 2.0 + 0.36, 0.08, 0.2)
			var stone := StreetOutside.shaded(p, "StoneSill", ledge, Vector3(face.x, WINDOW_BOTTOM - 0.04, face.y) - Vector3(inward.x, 0, inward.y) * 0.07, StreetOutside.STONE)
			stone.rotation.y = outward_yaw
			var trim := StreetOutside.shaded(p, "StoneTrim", trim_mesh, Vector3(face.x, 0, face.y), StreetOutside.STONE)
			trim.rotation.y = outward_yaw
		# 지붕 난간 돌 덮개(껍데기 윗면).
		var cap := BoxMesh.new()
		var cap_length: float = end - start
		cap.size = Vector3(absf(along.x) * cap_length + absf(along.y) * (skin + 0.08), 0.07, absf(along.y) * cap_length + absf(along.x) * (skin + 0.08))
		var cap_mid: Vector2 = from + along * ((start + end) / 2.0) - inward * (0.18 + skin / 2.0)
		StreetOutside.shaded(p, "ParapetCap", cap, Vector3(cap_mid.x, top + 0.035, cap_mid.y), StreetOutside.STONE)
	# 지붕 윗면(천장 판 위 — 위에서 보면 어두운 평지붕).
	var hall: Rect2 = TableView.DART_HALL
	var lounge: Rect2 = TableView.LOUNGE
	var edge: float = TableView.WALL_THICKNESS / 2.0
	for rect: Rect2 in [Rect2(hall.position.x - edge, hall.position.y - edge, hall.size.x + edge * 2.0, hall.size.y + edge),
			Rect2(lounge.position.x - edge, lounge.position.y, lounge.size.x + edge * 2.0, lounge.size.y + edge)]:
		var roof := BoxMesh.new()
		roof.size = Vector3(rect.size.x - 0.02, 0.06, rect.size.y - 0.02)
		StreetOutside.shaded(p, "RoofTop", roof, Vector3(rect.get_center().x, ceiling + 0.125, rect.get_center().y), StreetOutside.ROOF)


## 창 구멍 메우개(2026-11-16): 네온 오락실은 창 없는 방이다(Windows·Outside 묶음을 뺀다) → 구멍을 회벽으로 메운다.
## 펍에서는 숨겨 두고(visible = false) 오락실이 lounge_world._trim_arcade 에서 켠다.
## 정적 묶기는 숨김을 보지 않으므로 이 묶음은 묶지 않는다(art/static_batch.gd NO_BATCH_NAMES "WindowPlugs").
static func build_window_plugs(p: Node3D) -> void:
	p.visible = false
	var plug := RoundKit.solid_shape_mesh("window_plug", _window_outline(), 0.18)
	for spot: Array in _window_spots():
		var at: Vector2 = spot[0]
		var node := MeshKit.mesh_node(p, "WindowPlug", plug, Vector3(at.x, 0, at.y), _plaster())
		node.rotation.y = _yaw(spot[1])
