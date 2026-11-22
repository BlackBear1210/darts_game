extends "res://art/pub/room/room_kit.gd"
## 플레이어 카드 테이블과 자리: 둥근 테이블 · 클럽 의자 · 바 스툴 · 자리 매트/러그/번호(SeatMat_N…).
## 디자인 담당 소유(2026-11-17 game_room_builder.gd 에서 나눔). 장면 안 묶음 = TableAndSeats.
## club_chair · bar_stool 은 바(room_bar.gd)·NPC 자리(room_guests.gd)도 부른다.
## SeatMat_N·SeatRug_N·SeatStool_N·SeatLabel_N 이름은 TableView.show_seats 가 인원수에 따라 숨긴다 — 이름을 바꾸지 않는다.

## 테이블 위 카드 칸 자리(카드 7칸 x·z)는 실제로 카드를 까는 두 파일과 같은 상수를 읽는다(F5 seat_cards.gd · F6 table_cards.gd).
const TableCards = preload("res://game/card_round/cards/table_cards.gd")
## 펠트 윗면 = 테이블 높이 + 이 값(아래 build_table_and_seats 의 TableFelt 옆모습 맨 위 점).
const FELT_SURFACE: float = 0.004
## 카드 칸 흰 선(2026-11-22 포커 테이블 방식): 바깥 크기 = 카드(CardView.SIZE 0.096 × 0.144) + 가로 8mm·세로 9mm,
## 선 굵기 3mm → 선과 카드 사이에 펠트가 5~6mm 보여 "카드 테두리"가 아니라 "카드 놓는 칸"으로 읽힌다.
## 이웃 칸(0.12m 간격)과는 8mm 떨어진다. 펠트에서 1.5mm 띄워 멀리서 봐도 깜빡이지 않게 한다.
## 선은 메시가 아니라 셰이더(art/pub/card_spot_line.gdshader)로 그린다 — 멀리서 점선처럼 끊기지 않는다.
const CARD_SPOT_SHADER := "res://art/pub/card_spot_line.gdshader"
const CARD_SPOT_SIZE := Vector2(0.112, 0.162)
## 셰이더를 그릴 판은 선보다 사방 4mm 크다(멀리서 넓어진 선 가장자리가 판 끝에서 잘리지 않게).
const CARD_SPOT_QUAD := CARD_SPOT_SIZE + Vector2(0.008, 0.008)
const CARD_SPOT_RADIUS: float = 0.012
const CARD_SPOT_LINE: float = 0.003
const CARD_SPOT_LIFT: float = 0.0015
## 흰색(크림색 카드 테두리와 구별) + 약한 자체 발광(따뜻한 펍 조명 아래서도 흰색으로 남는다).
const CARD_SPOT_COLOR := Color("ffffff")
const CARD_SPOT_GLOW: float = 0.25

# ─────────────────────────────── 카드 테이블·의자 ───────────────────────────────

## 둥근 클럽 의자(요청서 4장: 폭 0.5~0.58m · 낮은 등받이 · 팔걸이 없음). 앉는 면 = TableView.STOOL_HEIGHT
## (선수·NPC 앉기 몸짓 Seated_Stool 이 맞춰진 높이). 로컬 +Z = 등받이 쪽(앉은 사람 등 뒤).
## piping = 방석 테두리 띠(자리 의자 = 자리 색, NPC 의자 = 놋쇠).
static func club_chair(parent: Node3D, at: Vector3, yaw: float, node_name: String, piping: Material) -> Node3D:
	var chair := Node3D.new()
	chair.name = node_name
	chair.position = at
	chair.rotation.y = yaw
	parent.add_child(chair, true)
	var top: float = TableView.STOOL_HEIGHT
	# 방석: 물레로 깎은 도톰한 원판(윗면 가운데가 살짝 부푼다).
	var cushion := RoundKit.rounded_profile(PackedVector2Array([Vector2(0, top - 0.1), Vector2(0.26, top - 0.1), Vector2(0.278, top - 0.045),
		Vector2(0.25, top - 0.004), Vector2(0, top + 0.006)]), 0.035, 4)
	RoundKit.lathe(chair, "Cushion", cushion, Vector3.ZERO, _leather(), 32)
	var base := RoundKit.rounded_profile(PackedVector2Array([Vector2(0, top - 0.16), Vector2(0.22, top - 0.16), Vector2(0.25, top - 0.1), Vector2(0, top - 0.1)]), 0.02, 3)
	RoundKit.lathe(chair, "SeatBase", base, Vector3.ZERO, _walnut(), 28)
	MeshKit.mesh_node(chair, "Piping", RoundKit.ring_mesh("piping", 0.262, RoundKit.circle_profile(0.011, 8), 40), Vector3(0, top - 0.1, 0), piping)
	# 낮은 등받이: 둥근 띠 단면을 등 뒤 140° 원호로 민다(양 끝은 막힌다).
	var rails: Array = []
	for k in range(15):
		var angle := PI / 2.0 + deg_to_rad(-70.0 + 140.0 * k / 14.0)
		var out := Vector3(cos(angle), 0, sin(angle))
		rails.append([out * 0.236 + Vector3.UP * (top + 0.115), out, Vector3.UP])
	MeshKit.mesh_node(chair, "Backrest", RoundKit.sweep_mesh("chair_back", RoundKit.rounded_rect_profile(Vector2(0.07, 0.25), 0.033, 4), rails, true, true), Vector3.ZERO, _leather())
	# 다리 4개: 바깥으로 살짝 벌어진 가는 나무 다리 + 놋쇠 발끝.
	var cap := PackedVector2Array([Vector2(0, 0), Vector2(0.021, 0), Vector2(0.021, 0), Vector2(0.021, 0.035), Vector2(0.021, 0.035), Vector2(0, 0.035)])
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var foot := Vector3(sx * 0.2, 0.0, sz * 0.2)
			RoundKit.rod(chair, "Leg", foot, Vector3(sx * 0.15, top - 0.15, sz * 0.15), 0.017, _walnut_dark(), 0.024, 10)
			RoundKit.lathe(chair, "LegCap", cap, foot, _brass(), 10)
	# 발걸이(2026-11-08): 앉는 면이 0.6m 로 높아(테이블에 팔이 닿게) 앉은 발이 바닥에 안 닿는다 → 다리 네 개를 꿰는
	# 놋쇠 고리에 발을 얹는다. 높이는 앉은 다리 자세(CharacterPoseLayer.SEAT_THIGH·SEAT_SHIN)의 발바닥 높이에 맞춘다.
	_foot_ring(chair, "FootRing", top, 0.2, 0.15, top - 0.15)
	return chair


## 앉은 발이 얹힐 놋쇠 발 고리. 다리는 바닥에서 반폭 foot_offset, 높이 leg_top 에서 반폭 top_offset 이다
## (고리 높이에서 다리 위치를 보간한 반지름으로 네 다리를 꿴다). 고리 윗면 = 앉는 면 − SEATED_SOLE_DROP.
static func _foot_ring(parent: Node3D, node_name: String, seat_top: float, foot_offset: float, top_offset: float, leg_top: float) -> void:
	var tube: float = 0.013
	var y: float = seat_top - SEATED_SOLE_DROP - tube
	var offset: float = lerpf(foot_offset, top_offset, y / leg_top)
	MeshKit.mesh_node(parent, node_name, RoundKit.ring_mesh("foot_ring_%d" % roundi(offset * 1000.0), offset * sqrt(2.0), RoundKit.circle_profile(tube, 8), 40),
		Vector3(0, y, 0), _brass())


## 높은 바 스툴(방석 윗면 BAR_STOOL_TOP): 도톰한 청록 가죽 방석 + 놋쇠 테 + 다리 4개 + 놋쇠 발 고리.
static func bar_stool(parent: Node3D, at: Vector3, node_name: String) -> Node3D:
	var stool := Node3D.new()
	stool.name = node_name
	stool.position = at
	parent.add_child(stool, true)
	var top := BAR_STOOL_TOP
	var cushion := RoundKit.rounded_profile(PackedVector2Array([Vector2(0, top - 0.09), Vector2(0.2, top - 0.09), Vector2(0.212, top - 0.04),
		Vector2(0.19, top - 0.003), Vector2(0, top + 0.006)]), 0.03, 4)
	RoundKit.lathe(stool, "Cushion", cushion, Vector3.ZERO, _leather(), 28)
	MeshKit.mesh_node(stool, "CushionRing", RoundKit.ring_mesh("stool_ring", 0.203, RoundKit.circle_profile(0.012, 8), 36), Vector3(0, top - 0.09, 0), _brass())
	var plate := RoundKit.rounded_profile(PackedVector2Array([Vector2(0, top - 0.13), Vector2(0.17, top - 0.13), Vector2(0.19, top - 0.09), Vector2(0, top - 0.09)]), 0.015, 3)
	RoundKit.lathe(stool, "SeatPlate", plate, Vector3.ZERO, _walnut(), 24)
	var hip: float = top - 0.13
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			RoundKit.rod(stool, "Leg", Vector3(sx * 0.19, 0, sz * 0.19), Vector3(sx * 0.12, hip, sz * 0.12), 0.018, _walnut_dark(), 0.022, 10)
	# 발 고리: 앉은 NPC 발바닥 높이(앉는 면 − SEATED_SOLE_DROP)에서 다리 네 개를 꿴다(2026-11-08 — 예전 0.3m 는 발보다 낮았다).
	_foot_ring(stool, "FootRing", top, 0.19, 0.12, hip)
	return stool


## 원형 카드 테이블(요청서 4장: 완전 원형 · 가운데 받침 하나 · 손 얹기 편한 둥근 테두리) + 원형 러그
## + 자리 4개(자리 색 띠 의자·모양 깔개·이름 글자) + 테이블 위 카드 7칸 흰 선(2026-11-22 — 예전 자리 색 매트·홈·예약 2칸 대신).
## 2026-11-08: 예전 상자 다리 4개(사용자 지적 "테이블 다리가 이상하다") → 물레로 깎은 트럼펫 받침 + 놋쇠 발 고리.
static func build_table_and_seats(p: Node3D) -> void:
	var table_center: Vector3 = TableView.TABLE_CENTER
	var size: Vector2 = TableView.TABLE_SIZE
	var height: float = TableView.TABLE_HEIGHT
	var radius: float = size.x / 2.0
	var table := Node3D.new()
	table.name = "CardTable"
	table.position = table_center
	p.add_child(table, true)
	# 큰 원형 러그(청록 + 놋쇠빛 줄 두 겹). 의자가 다 올라가는 크기.
	var rug := RoundKit.rounded_profile(PackedVector2Array([Vector2(0, 0.002), Vector2(2.5, 0.002), Vector2(2.55, 0.008), Vector2(2.5, 0.012), Vector2(0, 0.012)]), 0.01, 2)
	RoundKit.lathe(table, "TableRug", rug, Vector3.ZERO, RoundKit.clay("RugTeal", "1f3d36", 0.98), 64)
	# 2026-11-15: 줄무늬가 러그 윗면(0.012m)보다 0.5mm 만 높아 멀리서 보면 깜빡였다 → FLOOR_LAYER_GAP(4mm) 위에 깐다.
	var stripe_y: float = 0.012 + FLOOR_LAYER_GAP
	for ring: Vector2 in [Vector2(2.36, 2.3), Vector2(2.2, 2.17)]:
		RoundKit.lathe(table, "RugStripe", PackedVector2Array([Vector2(ring.x, stripe_y), Vector2(ring.y, stripe_y)]), Vector3.ZERO, RoundKit.clay("RugStripe", "a98552", 0.9), 64)
	# 받침: 바닥 원판 → 오목하게 좁아지는 목 → 상판 아래 받침판.
	var pedestal := RoundKit.rounded_profile(PackedVector2Array([Vector2(0, 0), Vector2(0.62, 0), Vector2(0.62, 0.04), Vector2(0.42, 0.1), Vector2(0.2, 0.24),
		Vector2(0.14, 0.42), Vector2(0.13, height - 0.3), Vector2(0.2, height - 0.2), Vector2(0.45, height - 0.165), Vector2(0, height - 0.16)]), 0.05, 5)
	RoundKit.lathe(table, "Pedestal", pedestal, Vector3.ZERO, _walnut(), 40)
	MeshKit.mesh_node(table, "PedestalFootRing", RoundKit.ring_mesh("table_foot", 0.6, RoundKit.circle_profile(0.022, 8), 56), Vector3(0, 0.035, 0), _brass())
	MeshKit.mesh_node(table, "PedestalCollar", RoundKit.ring_mesh("table_collar", 0.14, RoundKit.circle_profile(0.016, 8), 32), Vector3(0, 0.42, 0), _brass())
	# 상판 몸통(아래가 둥글게 말려 들어간 월넛) + 펠트 + 손 얹는 둥근 난간 테두리. 윗면 모서리(4번 점)는 난간이 덮으니 각지게 둔다.
	var top_edge: Array[int] = [4]
	var body := RoundKit.rounded_profile(PackedVector2Array([Vector2(0, height - 0.16), Vector2(radius - 0.3, height - 0.16), Vector2(radius - 0.12, height - 0.085),
		Vector2(radius - 0.1, height - 0.03), Vector2(radius - 0.1, height - 0.002), Vector2(0, height - 0.002)]), 0.03, 4, top_edge)
	RoundKit.lathe(table, "TableTop", body, Vector3.ZERO, _walnut(), 64)
	var felt := PackedVector2Array([Vector2(0, height - 0.01), Vector2(radius - 0.14, height - 0.01), Vector2(radius - 0.14, height - 0.01),
		Vector2(radius - 0.14, height + 0.004), Vector2(radius - 0.14, height + 0.004), Vector2(0, height + 0.004)])
	RoundKit.lathe(table, "TableFelt", felt, Vector3.ZERO, _felt(), 64)
	var spot_line := _card_spot_material()
	var spot_quad := PlaneMesh.new()
	spot_quad.size = CARD_SPOT_QUAD
	MeshKit.mesh_node(table, "TableRim", RoundKit.ring_mesh("table_rim", radius - 0.075, RoundKit.rounded_rect_profile(Vector2(0.15, 0.075), 0.035, 4), 72),
		Vector3(0, height - 0.01, 0), _walnut())
	MeshKit.mesh_node(table, "RimInlay", RoundKit.ring_mesh("table_inlay", radius - 0.152, RoundKit.circle_profile(0.006, 6), 72), Vector3(0, height + 0.004, 0), _brass())
	for i in range(TableView.SEATS.size()):
		var seat: Vector3 = TableView.SEATS[i]
		var direction := Vector3(seat.x - table_center.x, 0, seat.z - table_center.z).normalized()
		# angle: 이 각도로 돌리면 로컬 +Z 가 자리 쪽을 본다.
		var angle := atan2(direction.x, direction.z)
		var color := MeshKit.material("PlayerColor_" + str(i), PlayerLook.hex(i))
		# 테이블 위 자리 표시(2026-11-22 사용자 요청 "자리마다 카드 놓는 구역을 없애고 포커 테이블처럼 카드 놓는 곳만 흰 선으로"):
		# 예전 자리 색 매트(PlayerMat)·칸 홈·예약 2칸(F5 경기에서는 한 번도 안 쓰여 늘 비어 있었다)·자리 기호를 지우고
		# 펠트 위에 카드 7칸 흰 테두리만 남긴다. 누구 자리인지는 의자 띠·바닥 깔개·"● 1번 자리" 글자가 자리 색으로 알려 준다.
		# 카드는 그리지 않는다: F5 는 game/table/seat_cards.gd, F6 시연은 table_cards.gd 가 실제 손패 장수만큼 이 칸 위에 깐다.
		# 노드 이름 SeatMat_N 은 그대로 둔다(TableView.show_seats 가 인원수에 따라 이 묶음째 숨기고 돌린다).
		var mat_root := Node3D.new()
		mat_root.name = "SeatMat_%d" % (i + 1)
		mat_root.rotation.y = angle
		table.add_child(mat_root, true)
		# 자리마다 0.2mm 씩 높이를 달리해 이웃 자리 선이 겹쳐도 깜빡이지 않게 한다.
		var line_y := height + FELT_SURFACE + CARD_SPOT_LIFT + i * 0.0002
		for c in range(CardHandRules.HAND_LIMIT):
			var spot := MeshKit.mesh_node(mat_root, "CardSpot", spot_quad,
				Vector3(TableCards.SLOT_X0 + c * TableCards.SLOT_GAP, line_y, TableCards.SLOT_Z), spot_line)
			spot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# 바닥: 자리 표시 깔개(색 + 모양: 원·세모·네모·마름모 — 요청서 "색과 함께 서로 다른 기호") · 자리 의자 · "● 1번 자리" 글자.
		var sides: int = PlayerLook.MAT_SIDES[i]
		# 2026-11-15: 두께 0.012 → 0.02(윗면 0.0325m). 오락실에서는 이 아래에 둥근 러그(윗면 0.026m)가 깔리는데
		# 예전 윗면(0.0245m)은 그 러그와 2.5mm 차이라 깜빡였다 → 6mm 넘게 벌린다(arcade_room.gd _table_rug 와 약속된 높이).
		var rug_mesh := RoundKit.slab_mesh("seat_rug_%d" % sides, RoundKit.regular_outline(sides, 0.55, 0.08), SEAT_RUG_THICKNESS)
		var seat_rug := MeshKit.mesh_node(p, "SeatRug_%d" % (i + 1), rug_mesh, seat + Vector3(0, SEAT_RUG_BASE, 0), color)
		seat_rug.rotation.y = angle + (PI / 4 if i == 3 else 0.0)
		club_chair(p, seat, angle, "SeatStool_%d" % (i + 1), color)
		var label := MeshKit.label(p, "SeatLabel_%d" % (i + 1), "%s %d번 자리" % [PlayerLook.SYMBOLS[i], i + 1], seat + direction * 0.85 + Vector3(0, 0.03, 0), 40, Color("f0e6cf"), 0.003)
		label.rotation = Vector3(-PI / 2, angle, 0)


## 카드 칸 흰 테두리 재질(art/pub/card_spot_line.gdshader). 28칸이 재질 하나를 같이 쓴다.
static func _card_spot_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.resource_name = "CardSpotLine"
	material.shader = load(CARD_SPOT_SHADER)
	material.set_shader_parameter("line_color", CARD_SPOT_COLOR)
	material.set_shader_parameter("quad_size", CARD_SPOT_QUAD)
	material.set_shader_parameter("frame_size", CARD_SPOT_SIZE)
	material.set_shader_parameter("corner_radius", CARD_SPOT_RADIUS)
	material.set_shader_parameter("line_width", CARD_SPOT_LINE)
	material.set_shader_parameter("glow", CARD_SPOT_GLOW)
	return material
