extends "res://art/pub/room/room_kit.gd"
## NPC 쪽: NPC 구석 자리 · 둥근 탁자 · 탁자 음식 · 재떨이 · 손님(앉은 NPC) · 당구대.
## 디자인 담당 소유(2026-11-17 game_room_builder.gd 에서 나눔). 장면 안 묶음 = NpcCorner · Guests · PoolTable.
## 2026-11-21 사용자 요청: 카드 테이블 뒤 벽쪽 비스트로 테이블 2개 + 손님 4명을 지웠다(맵을 줄이기 전 정리).
## 손님 몸짓은 art/pub/npc_idle.gd, 탁자 음식 바꾸기는 art/pub/npc_table_food.gd 가 실행 때 한다.

const RoomSeating = preload("res://art/pub/room/room_seating.gd")

# ─────────────────────────────── NPC 자리·손님·당구대 ───────────────────────────────

## 도면의 "npc 자리": 둥근 비스트로 테이블(물레 받침) + 클럽 의자 2개. 충돌은 TableView.NPC_TABLE_BOX / NPC_STOOLS.
static func build_npc_corner(p: Node3D) -> void:
	var box: AABB = TableView.NPC_TABLE_BOX
	var center := box.get_center()
	var height: float = box.size.y
	var top_r: float = minf(box.size.x, box.size.z) / 2.0 - 0.03
	var table := _round_table(p, "NpcTable", center, top_r, height)
	# 테이블 위: 2026-11-08 사용자 "음식들은 랜덤으로 AI 캐릭터들 앞에 접시랑 음식을 놔 줘" — 예전 고정 피자·버거·감자튀김 대신
	# 손님 앞마다 접시·요리·음료를 실행 때 랜덤으로 차린다(art/pub/npc_table_food.gd).
	_table_food(table, TableView.NPC_STOOLS, height, top_r - 0.33)
	for i in range(TableView.NPC_STOOLS.size()):
		var chair_at: Vector3 = TableView.NPC_STOOLS[i]
		var away := Vector2(chair_at.x - center.x, chair_at.z - center.z).normalized()
		RoomSeating.club_chair(p, chair_at, _yaw(away), "NpcStool_%d" % (i + 1), _brass())


## 둥근 테이블(물레 받침 + 둥근 상판). 원점 = 테이블 가운데 바닥. 이름 + "Top" / "Stem" 이 상판·받침 노드 이름이다.
## NPC 구석 테이블(상판 반지름 0.72)을 기준 모양으로, 더 작은 테이블은 받침 폭을 같은 비율로 줄인다.
static func _round_table(p: Node3D, node_name: String, at: Vector3, top_r: float, height: float) -> Node3D:
	var table := Node3D.new()
	table.name = node_name
	table.position = Vector3(at.x, 0, at.z)
	p.add_child(table, true)
	var k: float = top_r / 0.72
	var top := RoundKit.rounded_profile(PackedVector2Array([Vector2(0, height - 0.06), Vector2(top_r - 0.05, height - 0.06), Vector2(top_r, height - 0.03),
		Vector2(top_r - 0.01, height), Vector2(0, height)]), 0.02, 4)
	RoundKit.lathe(table, node_name + "Top", top, Vector3.ZERO, _walnut(), 48)
	var stem := RoundKit.rounded_profile(PackedVector2Array([Vector2(0, 0), Vector2(0.4 * k, 0), Vector2(0.4 * k, 0.035), Vector2(0.18 * k, 0.1), Vector2(0.07, 0.25),
		Vector2(0.06, height - 0.2), Vector2(0.12 * k, height - 0.1), Vector2(0.3 * k, height - 0.065), Vector2(0, height - 0.06)]), 0.035 * minf(k, 1.0), 4)
	RoundKit.lathe(table, node_name + "Stem", stem, Vector3.ZERO, _walnut_dark(), 32)
	return table


## 손님 앞 랜덤 차림 노드(art/pub/npc_table_food.gd). diners = 손님 자리(바닥 좌표) — 자리마다 테이블 위 표시(Marker3D)를 하나 둔다.
## 표시는 테이블 가운데에서 손님 쪽으로 inset m, 높이 = 상판 윗면, -Z 가 손님 → 테이블 가운데를 본다.
## 접시·음식은 실행 때 표시 아래에 만들어진다(저장되지 않는다 — 실행할 때마다 차림이 다르다).
static func _table_food(table: Node3D, diners: Array, height: float, inset: float) -> Node3D:
	var food := Node3D.new()
	food.name = "TableFood"
	food.set_script(load(TABLE_FOOD_SCRIPT))
	table.add_child(food, true)
	for i in range(diners.size()):
		var diner: Vector3 = diners[i]
		var toward := Vector2(diner.x - table.position.x, diner.z - table.position.z).normalized()
		var spot := Marker3D.new()
		spot.name = "FoodSpot_%d" % (i + 1)
		spot.position = Vector3(toward.x * inset, height + 0.004, toward.y * inset)
		spot.rotation.y = _yaw(toward)
		food.add_child(spot, true)
	return food


## 재떨이(물레로 깎은 낮은 유리 그릇 + 재 한 줌). 시가 피우는 손님 앞(바 끝).
static func ashtray(p: Node3D, at: Vector3, node_name: String) -> void:
	var dish := RoundKit.rounded_profile(PackedVector2Array([Vector2(0, 0), Vector2(0.068, 0), Vector2(0.072, 0.014), Vector2(0.068, 0.03),
		Vector2(0.052, 0.032), Vector2(0.046, 0.012), Vector2(0, 0.012)]), 0.006, 2)
	RoundKit.lathe(p, node_name, dish, at, MeshKit.material("AshtrayGlass", "3d4441", 0.25), 22)
	var ash := MeshKit.mesh_node(p, node_name + "Ash", RoundKit.sphere_mesh(0.024, 10), at + Vector3(0.008, 0.012, -0.006), MeshKit.material("CigarAsh", "8f8b84"))
	ash.scale = Vector3(1.0, 0.35, 1.0)


## 펍 손님 NPC 5명: 구석 테이블에 둘(앉아서 마시기), 바 끝에 서서 시가를 피우는 하나, 바 스툴에 앉은 둘(바텐더가 서빙).
## 2026-11-08 사용자 지적 "바에 사람이 디자인이 다르고 의자에 앉아 있지도 않아" → 선수와 같은 리깅 캐릭터 + 실제 앉기 몸짓.
## 경기에 끼어들지 않는 장식이라 충돌을 주지 않는다(art/pub/npc_idle.gd). 오락실에서는 이 묶음째 빠진다(ARCADE_SKIP).
static func build_guests(p: Node3D) -> void:
	var bar: AABB = TableView.BAR_BOX
	var npc_center: Vector3 = TableView.NPC_TABLE_BOX.get_center()
	var npc_look := Vector3(npc_center.x, 0, npc_center.z)
	var stool_x: float = bar.end.x + 0.45
	var smoke_z: float = BAR_ASHTRAY.z
	# [자리, 바라볼 곳, 앉는가, 모자 색, 안경, 앉는 면 높이, 옷(NpcOutfit.Outfit), 몸짓(0 = 마시기, 4 = 시가)]
	# 2026-11-08: 캐릭터가 Tripo 모델로 바뀌며 셔츠 색 바꾸기가 없어졌다 → 손님마다 비니·안경·야구 모자로 구분(선수와도 구분).
	# 2026-11-08 저녁: 바 스툴 손님을 둘로(바텐더가 서빙하는 손님), 바 끝 손님은 재떨이 앞에서 시가를 피운다(사용자 요청).
	# 2026-11-21 사용자 "모니터 바로 옆에 붙어있는 1명을 모니터를 가리지 않게 치워": 방장 모니터(LoungeWorld.MONITOR, z 2.0 · +Z 를 본다)
	#   바로 앞 스툴(z 2.5) 손님을 모니터 뒤쪽 첫 스툴(z 0.95)로 옮겼다. 가운데 스툴은 빈자리로 둔다.
	var spots: Array = [
		[TableView.NPC_STOOLS[0], npc_look, true, "b8674a", false, TableView.STOOL_HEIGHT, NpcOutfit.Outfit.GUEST_BEANIE, 0],
		[TableView.NPC_STOOLS[1], npc_look, true, "4f6d8f", true, TableView.STOOL_HEIGHT, NpcOutfit.Outfit.GUEST, 0],
		[Vector3(bar.end.x + 0.42, 0, smoke_z), Vector3(bar.position.x, 0, smoke_z - 0.25), false, "7d8f4f", false, TableView.STOOL_HEIGHT, NpcOutfit.Outfit.GUEST_CAP, 4],
		[Vector3(stool_x, 0, _bar_stool_z(2)), Vector3(bar.position.x, 0, _bar_stool_z(2)), true, "a8576b", false, BAR_STOOL_TOP, NpcOutfit.Outfit.GUEST_BEANIE, 0],
		[Vector3(stool_x, 0, _bar_stool_z(0)), Vector3(bar.position.x, 0, _bar_stool_z(0)), true, "c79a45", true, BAR_STOOL_TOP, NpcOutfit.Outfit.GUEST_CAP, 0],
	]
	for i in range(spots.size()):
		var spot: Array = spots[i]
		NpcIdle.spawn(p, "Guest_%d" % (i + 1), spot[0], spot[1], Color(spot[3]), spot[2], int(spot[7]), i * 1.7, spot[5], spot[4], spot[6])


## 도면의 당구대(요청서 P08 "곡면 모서리"). 충돌은 TableView.POOL_TABLE_BOX.
## 높이는 예전과 같다(펠트 윗면 = 높이 − 0.04, 쿠션 윗면 = 높이 + 0.04) — 공·큐대 소품 자리(LoungeWorld)가 이 높이에 맞춰져 있다.
static func build_pool_table(p: Node3D) -> void:
	var box: AABB = TableView.POOL_TABLE_BOX
	var height: float = box.size.y
	var table := Node3D.new()
	table.name = "PoolTable"
	table.position = Vector3(box.get_center().x, 0, box.get_center().z)
	p.add_child(table, true)
	var half := Vector2(box.size.x / 2.0, box.size.z / 2.0)
	var felt := RoundKit.clay("PoolFelt", "1f6b4a", 0.95)
	MeshKit.rounded_box(table, "PoolBody", Vector3(box.size.x - 0.06, 0.3, box.size.z - 0.06), Vector3(0, height - 0.21, 0), _walnut(), 0.08)
	MeshKit.rounded_box(table, "PoolBed", Vector3(box.size.x - 0.2, 0.04, box.size.z - 0.2), Vector3(0, height - 0.06, 0), felt, 0.015)
	# 쿠션(네 변 레일): 둥근 월넛 띠 + 안쪽 펠트 쿠션.
	for sx: float in [-1.0, 1.0]:
		MeshKit.rounded_box(table, "PoolRail", Vector3(0.13, 0.11, box.size.z), Vector3(sx * (half.x - 0.065), height - 0.015, 0), _walnut(), 0.04)
		MeshKit.rounded_box(table, "PoolCushion", Vector3(0.04, 0.05, box.size.z - 0.26), Vector3(sx * (half.x - 0.14), height - 0.025, 0), felt, 0.018)
	for sz: float in [-1.0, 1.0]:
		MeshKit.rounded_box(table, "PoolRail", Vector3(box.size.x, 0.11, 0.13), Vector3(0, height - 0.015, sz * (half.y - 0.065)), _walnut(), 0.04)
		MeshKit.rounded_box(table, "PoolCushion", Vector3(box.size.x - 0.26, 0.05, 0.04), Vector3(0, height - 0.025, sz * (half.y - 0.14)), felt, 0.018)
	var pocket := PackedVector2Array([Vector2(0, 0), Vector2(0.075, 0), Vector2(0.075, 0), Vector2(0.075, 0.012), Vector2(0.075, 0.012), Vector2(0, 0.012)])
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 0.0, 1.0]:
			RoundKit.lathe(table, "PoolPocket", pocket, Vector3(sx * (half.x - 0.08), height + 0.035, sz * (half.y - 0.08)), PubParts.dark(), 20)
	# 다리 넷: 물레로 깎은 굵은 다리(아래가 부풀었다가 좁아짐) + 놋쇠 발.
	var leg := RoundKit.rounded_profile(PackedVector2Array([Vector2(0, 0), Vector2(0.1, 0), Vector2(0.1, 0.05), Vector2(0.075, 0.08), Vector2(0.12, 0.2),
		Vector2(0.085, 0.34), Vector2(0.1, height - 0.32), Vector2(0, height - 0.32)]), 0.03, 4)
	var foot := PackedVector2Array([Vector2(0, 0), Vector2(0.105, 0), Vector2(0.105, 0), Vector2(0.105, 0.05), Vector2(0.105, 0.05), Vector2(0, 0.05)])
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var at := Vector3(sx * (half.x - 0.2), 0, sz * (half.y - 0.25))
			RoundKit.lathe(table, "PoolLeg", leg, at, _walnut_dark(), 24)
			RoundKit.lathe(table, "PoolFoot", foot, at, _brass(), 24)
	# 공 몇 개와 큐대(세워 놓음).
	var balls := [[Vector2(-0.2, -0.5), "f0e6cf"], [Vector2(0.1, 0.4), "cf594f"], [Vector2(0.25, 0.62), "e4c45a"]]
	for i in range(balls.size()):
		var spot: Vector2 = balls[i][0]
		MeshKit.mesh_node(table, "PoolBall_%d" % (i + 1), RoundKit.sphere_mesh(0.055, 18), Vector3(spot.x, height - 0.04 + 0.055, spot.y), RoundKit.clay("PoolBall_" + str(i), balls[i][1], 0.3))
	RoundKit.rod(table, "PoolCue", Vector3(half.x + 0.1, 0.02, -half.y + 0.2), Vector3(half.x + 0.3, 1.45, -half.y + 0.1), 0.017, _walnut(), 0.008, 10)
