extends RefCounted
## 펍 창 밖 3D 밤거리와 밤하늘(2026-11-16). 디자인 담당 소유. art/pub/game_room_builder.gd 의 build() 가 "Outside" 묶음으로 부른다(모듈 지도 = art/pub/room/README.md).
##
## [왜 바꿨나 — 사용자 2026-11-16]
##   "밖의 풍경이 고도 엔진 안에서 안 보인다 — 맵이랑 연동해서 보여 주는 거야?" → 예전에는 유리판에 그린 그림이라 편집기 장면엔 바깥이 없었다.
##   "건물들이 전부 누워 있다" → 그림을 찍은 모델 일부가 누운 모델(Cartoon City Building_2·3·19 폴더)이었다. 이제 세워서 구웠다
##     (art/vendor/rg_poly/rg_poly_catalog.gd street_models "stand_up").
##   "하늘이 2D 라 3D 처럼 느껴지게" → 하늘 공(별·은하수) + 진짜 공 모양 달 + 멀리 도는 관람차 + 떠 있는 열기구 + 흐르는 구름.
##   이제 벽에 진짜 창 구멍이 있고(art/pub/room/room_shell.gd _window_hole) 그 너머에 이 거리가 실제로 있다. 편집기에서 pub_game.tscn 을 열면 보인다.
##
## [도시 배치 — 위에서 본 모양]
##   펍 건물(TableView.DART_HALL + LOUNGE)이 든 블록 둘레를 차도 4개(폭 ROAD_WIDTH)가 감싸고, 길 건너 8개 블록에 건물이 선다.
##   블록 경계는 TableView 방 크기에서 계산한다(pub_block) → 방 크기가 바뀌면 거리도 같이 따라간다.
##     창이 보는 쪽: 다트 홀 왼쪽 창 = 서쪽(−X) 길 · 다트 홀 오른쪽 창 = 분수 광장 너머 동쪽 길 · 뒷벽 창 = 남쪽(+Z) 길 · 라운지 오른쪽 창 = 동쪽 길.
##   길 건너 첫 줄 = 2~3층 건물, 그 뒤 = 높은 건물, 아주 멀리 = 스카이라인 탑. 관람차 = 서쪽, 열기구 = 동쪽·남쪽, 달 = 남쪽 하늘.
##
## [재질 하나 — art/pub/street_night.gdshader]
##   바깥은 모두 "StreetNight" 셰이더 재질 하나를 쓰고, 메시마다 색·창 불빛·스스로 빛남·무늬만 다르게 준다(instance_shader_parameters).
##   방 조명이 밖을 물들이지 않고, 밖 메시는 그림자를 만들지 않는다(성능 + 방 안 그림자 그대로).
##   가로등 자리는 셰이더의 lamps 배열(최대 MAX_LAMPS 개)에 넣어 땅·건물에 불빛 웅덩이를 만든다.
##
## [움직임 — art/pub/street_motion.gd] Outside 노드에 붙는다. 움직일 노드에는 메타 "motion" 을 붙인다(관람차·열기구·차·구름).
## [오락실] 창 없는 방이라 이 묶음을 통째로 뺀다(lounge_world.ARCADE_SKIP "Outside"). 정적 묶기에서도 빠진다(static_batch NO_BATCH_NAMES).

const MeshKit = preload("res://art/mesh_kit.gd")
const RoundKit = preload("res://art/pub/round_kit.gd")
const RgPoly = preload("res://art/vendor/rg_poly/rg_poly_catalog.gd")
const NIGHT_SHADER := "res://art/pub/street_night.gdshader"
const SKY_SHADER := "res://art/pub/street_sky.gdshader"
const MOON_SHADER := "res://art/pub/street_moon.gdshader"
const HALO_SHADER := "res://art/pub/street_halo.gdshader"
const MOTION_SCRIPT := "res://art/pub/street_motion.gd"

## 높이(m): 차도 윗면 · 보도 윗면(펍 바닥 0 보다 2cm 낮다).
const ROAD_TOP := -0.17
const WALK_TOP := -0.02
## 차도 폭 · 길 건너 보도 폭(건물 앞면까지) · 땅 끝(원점에서 ±).
const ROAD_WIDTH := 7.0
const WALK_WIDTH := 3.0
const WORLD_HALF := 130.0
## 하늘 공 반지름 · 달 방향(펍에서 본 쪽)·거리·반지름. 달 높이각 약 38° — 길 건너 첫 줄 건물 지붕(약 29°) 위로 보인다.
const SKY_RADIUS := 420.0
const MOON_DIR := Vector3(0.3, 0.62, 0.72)
const MOON_DISTANCE := 300.0
const MOON_RADIUS := 20.0
## 가로등: 모델 배율 · 전구 높이(배율 뒤) · 불빛이 닿는 거리 · 셰이더 가로등 칸 수(street_night.gdshader lamps[32]).
const LAMP_SCALE := 1.3
const LAMP_BULB_Y := 4.6
const LAMP_REACH := 9.0
const MAX_LAMPS := 32
## 겉색(sRGB). 도형(땅·보도·벽돌 껍데기)은 이 색이 곧 겉색이고, 구운 모델은 정점 색 그대로다(흰색 = 바꾸지 않음).
const ASPHALT := Color("3b3c47")
const CONCRETE := Color("8f8a86")
const LANE_PAINT := Color("d9cfa6")
const GRASS := Color("355d3f")
const BRICK := Color("8e4b3b")
const STONE := Color("cbbda6")
const ROOF := Color("3c3b44")
const STEEL := Color("5d6577")
## 펍 건물 바깥 벽돌 껍데기 윗면 = 천장 + 난간 높이.
const PARAPET := 0.5
## 길가에 세운 차 가운데 = 펍 쪽 연석에서 이만큼(m).
const PARK_LANE := 1.0

static var _night: ShaderMaterial
static var _lamps := PackedVector4Array()
static var _rng := RandomNumberGenerator.new()


## Outside 묶음을 채운다. 같은 씨앗이라 다시 만들어도 배치·창 불빛이 같다(장면 파일 차이가 작다).
static func build(root: Node3D) -> void:
	_night = null
	_lamps = PackedVector4Array()
	_rng.seed = 20261116
	root.set_script(load(MOTION_SCRIPT))
	_ground(_group(root, "Ground"))
	_pub_block_props(_group(root, "Sidewalk"))
	_city(_group(root, "City"))
	_traffic(_group(root, "Traffic"))
	_sky(_group(root, "Sky"))
	_ferris_wheel(_group(root, "FerrisWheel"))
	_balloons(_group(root, "Balloons"))
	_clouds(_group(root, "Clouds"))
	var padded := _lamps.duplicate()
	while padded.size() < MAX_LAMPS:
		padded.append(Vector4(0, -1000, 0, 0.01))
	night().set_shader_parameter("lamps", padded)
	night().set_shader_parameter("lamp_count", mini(_lamps.size(), MAX_LAMPS))


static func _group(parent: Node3D, group_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = group_name
	parent.add_child(node, true)
	return node


## 바깥 공용 재질(art/pub/street_night.gdshader). 펍 건물 바깥 벽돌 껍데기(art/pub/room/room_shell.gd build_exterior)도 쓴다.
static func night() -> ShaderMaterial:
	if _night == null:
		_night = ShaderMaterial.new()
		_night.resource_name = "StreetNight"
		_night.shader = load(NIGHT_SHADER)
		# 달빛은 거의 위에서(조금 남쪽) 비춘다 — 길 건너 건물 앞면(펍 쪽)도 하늘빛으로 형태가 읽힌다.
		_night.set_shader_parameter("moon_dir", Vector3(0.25, 0.85, 0.35))
	return _night


## 밤거리 재질 메시 하나. color = 정점 색에 곱하는 색 · glass = 유리 모드(0 건물 창 · 1 늘 켜진 불 · 2 차 유리)
## · glow = 스스로 빛남(0 = 빛 계산) · pattern = 무늬(0 없음 · 1 벽돌 · 2 보도 타일).
static func shaded(parent: Node, name_: String, mesh: Mesh, pos: Vector3, color := Color.WHITE, glass := 0, glow := 0.0, pattern := 0) -> MeshInstance3D:
	var node := MeshKit.mesh_node(parent, name_, mesh, pos, night())
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	if color != Color.WHITE:
		node.set_instance_shader_parameter("base_color", color)
	if glass != 0:
		node.set_instance_shader_parameter("glass_mode", float(glass))
	if glow > 0.0:
		node.set_instance_shader_parameter("self_glow", glow)
	if pattern != 0:
		node.set_instance_shader_parameter("pattern", float(pattern))
	return node


## 상자 하나(위에서 본 rect · 아래 bottom ~ 위 top).
static func _slab(parent: Node, name_: String, rect: Rect2, bottom: float, top: float, color: Color, pattern := 0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(rect.size.x, top - bottom, rect.size.y)
	return shaded(parent, name_, mesh, Vector3(rect.get_center().x, (top + bottom) / 2.0, rect.get_center().y), color, 0, 0.0, pattern)


## 펍 건물이 든 블록(위에서 본 x·z). 방 둘레에 보도 3~3.5m.
static func pub_block() -> Rect2:
	var hall: Rect2 = TableView.DART_HALL
	var lounge: Rect2 = TableView.LOUNGE
	var x0: float = minf(hall.position.x, lounge.position.x) - 3.1
	var x1: float = maxf(hall.end.x, lounge.end.x) + 3.4
	var z0: float = hall.position.y - 3.5
	var z1: float = lounge.end.y + 3.5
	return Rect2(x0, z0, x1 - x0, z1 - z0)


## 하늘·달이 둘러싸는 가운데(펍 블록 가운데 바닥).
static func sky_center() -> Vector3:
	var block := pub_block()
	return Vector3(block.get_center().x, 0.0, block.get_center().y)


## 모델 앞면(−X)을 2D 방향 facing(x, z) 으로 돌리는 Y 회전.
static func _face(facing: Vector2) -> float:
	return atan2(facing.y, -facing.x)


# ─────────────────────────────── 땅·길 ───────────────────────────────

## 보도 블록 9개(가운데 = 펍 블록, 둘레 8개 = 길 건너). 블록 사이 = 차도.
static func _blocks() -> Array[Rect2]:
	var b := pub_block()
	var xs: Array[float] = [-WORLD_HALF, b.position.x - ROAD_WIDTH, b.position.x, b.end.x, b.end.x + ROAD_WIDTH, WORLD_HALF]
	var zs: Array[float] = [-WORLD_HALF, b.position.y - ROAD_WIDTH, b.position.y, b.end.y, b.end.y + ROAD_WIDTH, WORLD_HALF]
	var rects: Array[Rect2] = []
	for i: int in [0, 2, 4]:
		for j: int in [0, 2, 4]:
			rects.append(Rect2(xs[i], zs[j], xs[i + 1] - xs[i], zs[j + 1] - zs[j]))
	return rects


## 차도(아스팔트 한 장) + 보도 블록 + 차선 점선 + 펍 앞 횡단보도 + 분수 광장 화단.
static func _ground(p: Node3D) -> void:
	var b := pub_block()
	_slab(p, "Asphalt", Rect2(-WORLD_HALF, -WORLD_HALF, WORLD_HALF * 2.0, WORLD_HALF * 2.0), ROAD_TOP - 0.3, ROAD_TOP, ASPHALT)
	for rect in _blocks():
		_slab(p, "SidewalkBlock", rect, ROAD_TOP - 0.05, WALK_TOP, CONCRETE, 2)
	# 차선 가운데 점선(길마다 메시 하나로 합친다 — 노드 수를 줄인다). 펍 둘레 ±75m 만(그 너머는 안개).
	var dash := BoxMesh.new()
	dash.size = Vector3(2.2, 0.012, 0.13)
	var roads := [["LaneWest", Vector3(b.position.x - ROAD_WIDTH / 2.0, 0, 0), Vector3.BACK],
		["LaneEast", Vector3(b.end.x + ROAD_WIDTH / 2.0, 0, 0), Vector3.BACK],
		["LaneNorth", Vector3(0, 0, b.position.y - ROAD_WIDTH / 2.0), Vector3.RIGHT],
		["LaneSouth", Vector3(0, 0, b.end.y + ROAD_WIDTH / 2.0), Vector3.RIGHT]]
	for road: Array in roads:
		var axis: Vector3 = road[2]
		var parts: Array = []
		var s := -75.0
		while s < 75.0:
			var at: Vector3 = (road[1] as Vector3) + axis * s + Vector3.UP * ROAD_TOP
			parts.append([dash, Transform3D(Basis(Vector3.UP, 0.0 if axis.x > 0.5 else PI / 2.0), at)])
			s += 5.5
		shaded(p, road[0], RoundKit.merge("street_lane|%s|%.2f" % [road[0], (road[1] as Vector3).length()], parts), Vector3.ZERO, LANE_PAINT)
	# 횡단보도: 뒷벽 앞 남쪽 길 · 광장 앞 동쪽 길(창에서 내려다보이는 곳).
	_crosswalk(p, Vector3(4.2, ROAD_TOP, b.end.y + ROAD_WIDTH / 2.0), Vector3.BACK)
	_crosswalk(p, Vector3(b.end.x + ROAD_WIDTH / 2.0, ROAD_TOP, -6.3), Vector3.RIGHT)
	# 분수 광장 화단 두 곳(잔디가 보도보다 12cm 높다).
	var plaza := _plaza()
	_slab(p, "GrassBed", Rect2(plaza.end.x - 4.0, plaza.end.y - 2.8, 3.0, 2.2), WALK_TOP - 0.02, WALK_TOP + 0.12, GRASS)
	_slab(p, "GrassBed", Rect2(plaza.end.x - 4.6, plaza.position.y + 0.9, 3.6, 2.4), WALK_TOP - 0.02, WALK_TOP + 0.12, GRASS)


## 횡단보도 줄무늬(가운데 at, across = 길을 건너는 방향).
static func _crosswalk(p: Node3D, at: Vector3, across: Vector3) -> void:
	var stripe := BoxMesh.new()
	stripe.size = Vector3(0.55, 0.012, ROAD_WIDTH - 1.2)
	var side := Vector3(across.z, 0, -across.x)
	var parts: Array = []
	for k in range(-3, 4):
		parts.append([stripe, Transform3D(Basis(Vector3.UP, 0.0 if across.z > 0.5 else PI / 2.0), at + side * (k * 0.95))])
	shaded(p, "Crosswalk", RoundKit.merge("street_crosswalk|%.2f|%.2f" % [at.x, at.z], parts), Vector3.ZERO, Color("e4e0d4"))


## 다트 홀 오른쪽(동쪽) 분수 광장 자리(위에서 본 x·z).
static func _plaza() -> Rect2:
	var b := pub_block()
	var hall: Rect2 = TableView.DART_HALL
	var lounge: Rect2 = TableView.LOUNGE
	return Rect2(hall.end.x + 0.6, b.position.y + 0.6, b.end.x - hall.end.x - 1.2, lounge.position.y - b.position.y - 1.2)


# ─────────────────────────────── 소품 ───────────────────────────────

## 구운 모델 소품을 세운다: 바닥 가운데가 at, 모델 앞(−X)이 yaw 만큼 돈다.
static func _prop(p: Node3D, key: String, at: Vector3, yaw := 0.0, scale := 1.0, glass := 0, name_ := "Prop") -> MeshInstance3D:
	var mesh := RgPoly.mesh(key)
	if mesh == null:
		push_warning("창 밖 모델이 없습니다: %s (rg_poly_baker.gd --bake 로 구우세요)" % key)
		return null
	var box := mesh.get_aabb()
	var node := shaded(p, name_, mesh, Vector3.ZERO, Color.WHITE, glass)
	node.rotation.y = yaw
	node.scale = Vector3.ONE * scale
	node.position = at - node.basis * Vector3(box.get_center().x, box.position.y, box.get_center().z)
	return node


## 가로등(유리 = 늘 켜진 불) + 셰이더 불빛 웅덩이 자리 등록.
static func _lamp(p: Node3D, at: Vector3) -> void:
	_prop(p, "street_lamp_c" if _rng.randf() < 0.5 else "street_lamp_d", at, 0.0, LAMP_SCALE, 1, "StreetLamp")
	if _lamps.size() < MAX_LAMPS:
		_lamps.append(Vector4(at.x, at.y + LAMP_BULB_Y, at.z, LAMP_REACH))


static func _tree(p: Node3D, at: Vector3, scale := 1.3) -> void:
	var keys: Array[String] = ["street_tree_2", "street_tree_3", "street_tree_4", "street_tree_6", "street_tree_7"]
	_prop(p, keys[_rng.randi() % keys.size()], at, _rng.randf_range(-PI, PI), scale * _rng.randf_range(0.9, 1.15), 0, "Tree")


## 펍 블록 보도(창 바로 밖): 가로등·가로수·벤치·소화전·우체통·화분, 분수 광장(분수·벤치·매점), 길가에 세운 차.
static func _pub_block_props(p: Node3D) -> void:
	var b := pub_block()
	var hall: Rect2 = TableView.DART_HALL
	var lounge: Rect2 = TableView.LOUNGE
	var curb_s: float = b.end.y - 0.45
	var curb_w: float = b.position.x + 0.45
	var curb_e: float = b.end.x - 0.45
	var curb_n: float = b.position.y + 0.45
	# 뒷벽(남쪽) 보도 — 뒷벽 창(x −2.4 · 1.8 · 11.2) 앞은 비운다(창 바로 앞 나무·가로등이 바깥 풍경을 가렸다 — 2026-11-16 화면 확인).
	for x: float in [-6.4, 8.0, 14.0]:
		_lamp(p, Vector3(x, WALK_TOP, curb_s))
	for x: float in [-9.8, 4.0, 16.0]:
		_tree(p, Vector3(x, WALK_TOP, curb_s - 0.2))
	_prop(p, "street_bench", Vector3(-4.0, WALK_TOP, lounge.end.y + 0.75), _face(Vector2(0, 1)), 1.0, 0, "Bench")
	_prop(p, "street_hydrant", Vector3(2.6, WALK_TOP, curb_s), 0.4, 1.0, 0, "Hydrant")
	_prop(p, "street_trashbin", Vector3(-5.2, WALK_TOP, curb_s), 0.0, 1.0, 0, "Trashbin")
	_prop(p, "street_postbox", Vector3(9.9, WALK_TOP, lounge.end.y + 0.6), _face(Vector2(0, 1)), 1.0, 0, "PostBox")
	for x: float in [-2.4, 1.8, 11.2]:
		_prop(p, "street_pot_f" if x < 5.0 else "street_pot_g", Vector3(x, WALK_TOP, lounge.end.y + 0.42), _face(Vector2(0, 1)), 1.4, 0, "WindowPlanter")
	# 다트 홀 왼쪽(서쪽) 보도 · 라운지 왼쪽 보도.
	for z: float in [-2.0, -13.0]:
		_lamp(p, Vector3(curb_w, WALK_TOP, z))
	_lamp(p, Vector3(curb_w, WALK_TOP, 6.0))
	_tree(p, Vector3(curb_w + 0.4, WALK_TOP, -12.6))
	_tree(p, Vector3(curb_w + 0.4, WALK_TOP, 2.6))
	_prop(p, "street_bench", Vector3(hall.position.x - 0.75, WALK_TOP, -10.6), _face(Vector2(-1, 0)), 1.0, 0, "Bench")
	_prop(p, "street_bush", Vector3(hall.position.x - 0.75, WALK_TOP, -1.6), _face(Vector2(-1, 0)), 1.2, 0, "Bush")
	# 북쪽(과녁 벽 뒤) 보도.
	for x: float in [-7.0, 3.0, 13.0]:
		_lamp(p, Vector3(x, WALK_TOP, curb_n))
	# 분수 광장(다트 홀 오른쪽 창 밖) + 라운지 오른쪽 보도.
	var plaza := _plaza()
	var middle := Vector3(plaza.get_center().x, WALK_TOP, plaza.get_center().y)
	_prop(p, "street_fountain", middle, 0.0, 1.3, 0, "Fountain")
	_prop(p, "street_bench", middle + Vector3(0, 0, 3.6), _face(Vector2(0, -1)), 1.0, 0, "Bench")
	_prop(p, "street_bench", middle + Vector3(0, 0, -3.6), _face(Vector2(0, 1)), 1.0, 0, "Bench")
	_prop(p, "street_bench", middle + Vector3(3.6, 0, 0), _face(Vector2(-1, 0)), 1.0, 0, "Bench")
	_prop(p, "street_kiosk", Vector3(plaza.position.x + 1.8, WALK_TOP, plaza.position.y + 2.6), _face(Vector2(1, 0)), 1.0, 2, "Kiosk")
	for corner: Vector3 in [middle + Vector3(-2.6, 0, -2.6), middle + Vector3(2.6, 0, 2.6)]:
		_prop(p, "street_pot_g", corner, 0.8, 1.6, 0, "FlowerPot")
	_tree(p, Vector3(plaza.end.x - 2.5, WALK_TOP + 0.12, plaza.end.y - 1.7), 1.5)
	_tree(p, Vector3(plaza.end.x - 2.8, WALK_TOP + 0.12, plaza.position.y + 2.1), 1.5)
	for z: float in [-11.5, -5.4]:
		_lamp(p, Vector3(curb_e, WALK_TOP, z))
	_lamp(p, Vector3(curb_e, WALK_TOP, 7.6))
	_tree(p, Vector3(curb_e - 0.5, WALK_TOP, 1.6))
	# 길가에 세운 차(움직이지 않는다): 펍 쪽 길가(PARK_LANE). 지나가는 차 차선(_traffic)과 겹치지 않는다. 횡단보도도 피했다.
	_parked(p, "street_car_3", Vector3(-7.6, ROAD_TOP, b.end.y + PARK_LANE), Vector2(1, 0))
	_parked(p, "street_car_12", Vector3(9.6, ROAD_TOP, b.end.y + PARK_LANE), Vector2(1, 0))
	_parked(p, "street_car_10", Vector3(b.end.x + PARK_LANE, ROAD_TOP, 1.0), Vector2(0, -1))


# ─────────────────────────────── 건물 ───────────────────────────────

## 건물 하나: 앞면 아래 가운데가 front, 앞면이 facing 쪽을 본다. 창마다 불 켜진 몫을 조금씩 다르게.
static func _building(p: Node3D, key: String, front: Vector3, facing: Vector2, scale := 1.0) -> MeshInstance3D:
	var mesh := RgPoly.mesh(key)
	if mesh == null:
		push_warning("창 밖 건물 모델이 없습니다: %s" % key)
		return null
	var box := mesh.get_aabb()
	var node := shaded(p, "Building", mesh, Vector3.ZERO)
	node.rotation.y = _face(facing)
	node.scale = Vector3.ONE * scale
	node.position = front - node.basis * Vector3(box.position.x, box.position.y, box.get_center().z)
	node.set_instance_shader_parameter("lit_share", snappedf(_rng.randf_range(0.3, 0.62), 0.01))
	return node


## 건물 줄: start(첫 건물 앞면 한쪽 끝)에서 along 방향으로 keys 를 늘어놓는다(모델 폭 = 로컬 z 크기).
static func _row(p: Node3D, keys: Array, start: Vector3, along: Vector2, facing: Vector2, gap := 0.6, scale := 1.0) -> void:
	var cursor := 0.0
	for key: String in keys:
		var mesh := RgPoly.mesh(key)
		if mesh == null:
			continue
		var width: float = mesh.get_aabb().size.z * scale
		_building(p, key, start + Vector3(along.x, 0, along.y) * (cursor + width / 2.0), facing, scale)
		cursor += width + gap


## 길 건너 건물 줄(첫 줄 2~3층 · 둘째 줄 높은 건물) + 먼 스카이라인 + 길 건너 보도 가로등·가로수.
static func _city(p: Node3D) -> void:
	var b := pub_block()
	var reach: float = ROAD_WIDTH + WALK_WIDTH
	var west: float = b.position.x - reach
	var east: float = b.end.x + reach
	var north: float = b.position.y - reach
	var south: float = b.end.y + reach
	# 첫 줄(길 바로 건너). 서쪽은 낮은 건물 — 그 너머 관람차가 지붕 위로 보이게.
	_row(p, ["street_b2_3f", "street_b12", "street_b3", "street_b2_1c"], Vector3(west, WALK_TOP, b.position.y + 0.05), Vector2(0, 1), Vector2(1, 0), 0.05)
	_row(p, ["street_b2_5b", "street_b11", "street_b8"], Vector3(east, WALK_TOP, b.position.y + 0.3), Vector2(0, 1), Vector2(-1, 0), 0.6)
	_row(p, ["street_b19", "street_b2_4j", "street_b26", "street_b2_6h"], Vector3(b.position.x + 0.2, WALK_TOP, south), Vector2(1, 0), Vector2(0, -1), 0.6)
	_row(p, ["street_b14", "street_b1"], Vector3(b.position.x + 0.5, WALK_TOP, north), Vector2(1, 0), Vector2(0, 1), 1.0)
	# 모퉁이 블록(길 건너 대각선).
	_row(p, ["street_b24", "street_b2_5b", "street_b17"], Vector3(west, WALK_TOP, south), Vector2(-1, 0), Vector2(0, -1), 0.8)
	_row(p, ["street_b5", "street_b2_1c"], Vector3(east, WALK_TOP, south), Vector2(1, 0), Vector2(0, -1), 0.8)
	_row(p, ["street_b26", "street_b2_4j"], Vector3(west, WALK_TOP, north), Vector2(-1, 0), Vector2(0, 1), 0.8)
	_row(p, ["street_b12", "street_b8"], Vector3(east, WALK_TOP, north), Vector2(1, 0), Vector2(0, 1), 0.8)
	# 둘째 줄(첫 줄 지붕 위로 솟는 높은 건물). 블록 안(길 위로 안 넘게)만. 서쪽은 관람차 자리라 비운다.
	# 남쪽 둘째 줄은 왼쪽 절반만 — 오른쪽(동쪽) 위 하늘은 달 자리라 비운다(뒷벽 창에서 달이 높은 건물에 가렸다 — 2026-11-16 화면 확인).
	_row(p, ["street_b18", "street_b21"], Vector3(b.position.x + 0.05, WALK_TOP, south + 13.5), Vector2(1, 0), Vector2(0, -1), 1.0)
	_row(p, ["street_b15", "street_b4"], Vector3(east + 14.0, WALK_TOP, b.position.y + 0.5), Vector2(0, 1), Vector2(-1, 0), 1.8)
	_row(p, ["street_b18", "street_b9"], Vector3(b.position.x + 2.0, WALK_TOP, north - 14.0), Vector2(1, 0), Vector2(0, 1), 2.0)
	# 먼 스카이라인(안개에 반쯤 묻힌다). 68m 탑(street_b7)은 남서쪽 — 달(남동쪽)과 하늘을 나눠 갖는다.
	var skyline: Array = [["street_b7", Vector3(-48, WALK_TOP, 112), Vector2(0.3, -1), 1.0],
		["street_b25", Vector3(62, WALK_TOP, 88), Vector2(-0.4, -1), 1.0],
		["street_b4", Vector3(-82, WALK_TOP, 42), Vector2(1, -0.3), 1.2],
		["street_b15", Vector3(96, WALK_TOP, -8), Vector2(-1, 0.1), 1.4],
		["street_b18", Vector3(-72, WALK_TOP, -72), Vector2(1, 1), 1.3],
		["street_b27", Vector3(34, WALK_TOP, -96), Vector2(0, 1), 1.4],
		["street_b7", Vector3(104, WALK_TOP, 64), Vector2(-1, -0.5), 0.8],
		["street_b9", Vector3(-98, WALK_TOP, -24), Vector2(1, 0.2), 1.3],
		["street_b21", Vector3(4, WALK_TOP, 118), Vector2(0, -1), 1.6],
		["street_b15", Vector3(78, WALK_TOP, -64), Vector2(-1, 1), 1.2]]
	for spot: Array in skyline:
		_building(p, spot[0], spot[1], (spot[2] as Vector2).normalized(), spot[3])
	# 길 건너 보도 가로등·가로수(건물 앞).
	for z: float in [-12.0, -2.0, 8.0]:
		_lamp(p, Vector3(west + 0.45 + 2.1, WALK_TOP, z))
		_lamp(p, Vector3(east - 0.45 - 2.1, WALK_TOP, z + 1.5))
	for x: float in [-6.5, 3.5, 13.5]:
		_lamp(p, Vector3(x, WALK_TOP, south - 2.55))
	for z: float in [-7.0, 3.0]:
		_tree(p, Vector3(west + 1.6, WALK_TOP, z))
		_tree(p, Vector3(east - 1.6, WALK_TOP, z - 1.4))
	for x: float in [-1.5, 8.5]:
		_tree(p, Vector3(x, WALK_TOP, south - 1.6))
	_prop(p, "street_bench", Vector3(-3.6, WALK_TOP, south - 0.7), _face(Vector2(0, -1)), 1.0, 0, "Bench")
	_prop(p, "street_hydrant", Vector3(west + 2.6, WALK_TOP, -4.4), 0.0, 1.0, 0, "Hydrant")


# ─────────────────────────────── 차 ───────────────────────────────

## 차 한 대(뿌리 노드 = 바퀴 바닥 가운데, 앞 = 로컬 −X) + 전조등·미등 + 앞 길에 비치는 빛.
static func _car_body(p: Node3D, key: String, at: Vector3, heading: Vector2, name_: String) -> Node3D:
	var root := Node3D.new()
	root.name = name_
	root.position = at
	root.rotation.y = _face(heading)
	p.add_child(root, true)
	var mesh := RgPoly.mesh(key)
	if mesh == null:
		return root
	var box := mesh.get_aabb()
	shaded(root, "Body", mesh, -Vector3(box.get_center().x, box.position.y, box.get_center().z), Color.WHITE, 2)
	var half := box.size / 2.0
	var lamp := BoxMesh.new()
	lamp.size = Vector3(0.06, 0.12, 0.26)
	for side: float in [-1.0, 1.0]:
		shaded(root, "HeadLight", lamp, Vector3(-half.x - 0.01, 0.62, side * (half.z - 0.32)), Color("fff1c8"), 0, 3.2)
		shaded(root, "TailLight", lamp, Vector3(half.x + 0.01, 0.7, side * (half.z - 0.28)), Color("ff3b2e"), 0, 2.2)
	return root


## 세워 둔 차(전조등은 끈다).
static func _parked(p: Node3D, key: String, at: Vector3, heading: Vector2) -> void:
	var car := _car_body(p, key, at, heading, "ParkedCar")
	for child in car.get_children():
		if str(child.name).begins_with("HeadLight") or str(child.name).begins_with("TailLight"):
			(child as MeshInstance3D).set_instance_shader_parameter("self_glow", 0.35)


## 지나가는 차: 차선 끝에서 끝까지 달리다 처음으로 돌아온다(street_motion.gd "drive").
static func _traffic(p: Node3D) -> void:
	var b := pub_block()
	var span := 115.0
	var cars: Array[String] = ["street_car_1", "street_car_3", "street_car_10", "street_car_12", "street_car_14", "street_car_16", "street_truck"]
	# [차선 가운데 한 점, 달리는 방향, 차 수]. 남쪽·동쪽 길은 펍 쪽 길가에 세운 차(PARK_LANE)가 있어 차선을 바깥으로 뺐다.
	var lanes: Array = [[Vector3(0, ROAD_TOP, b.end.y + ROAD_WIDTH * 0.8), Vector2(1, 0), 2],
		[Vector3(0, ROAD_TOP, b.end.y + ROAD_WIDTH * 0.38), Vector2(-1, 0), 2],
		[Vector3(b.position.x - ROAD_WIDTH * 0.28, ROAD_TOP, 0), Vector2(0, 1), 2],
		[Vector3(b.position.x - ROAD_WIDTH * 0.75, ROAD_TOP, 0), Vector2(0, -1), 1],
		[Vector3(b.end.x + ROAD_WIDTH * 0.8, ROAD_TOP, 0), Vector2(0, 1), 2],
		[Vector3(b.end.x + ROAD_WIDTH * 0.38, ROAD_TOP, 0), Vector2(0, -1), 1]]
	var glow := ShaderMaterial.new()
	glow.resource_name = "HeadlightPool"
	glow.shader = load(HALO_SHADER)
	glow.set_shader_parameter("halo_color", Color("ffdca0"))
	glow.set_shader_parameter("strength", 0.32)
	glow.set_shader_parameter("billboard", 0.0)
	glow.set_shader_parameter("falloff", 1.6)
	var pool := QuadMesh.new()
	pool.size = Vector2(6.0, 3.2)
	pool.orientation = PlaneMesh.FACE_Y
	var k := 0
	for lane: Array in lanes:
		var heading: Vector2 = lane[1]
		var dir := Vector3(heading.x, 0, heading.y)
		var mid: Vector3 = lane[0]
		for n in range(int(lane[2])):
			var car := _car_body(p, cars[k % cars.size()], mid, heading, "Car")
			# 앞 길에 비치는 전조등 빛(로컬 −X 앞 3.5m, 길 위 2cm).
			var light := MeshKit.mesh_node(car, "HeadlightPool", pool, Vector3(-4.6, 0.02, 0), glow)
			light.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			car.set_meta("motion", {"kind": "drive", "from": mid - dir * span, "to": mid + dir * span,
				"speed": snappedf(_rng.randf_range(7.5, 11.0), 0.1), "offset": snappedf(float(n) / float(lane[2]) + _rng.randf() * 0.3, 0.01)})
			# 처음(편집기) 자리도 motion 의 offset 자리에 둔다 → 편집기에서 본 모습 = 게임 시작 모습.
			var motion: Dictionary = car.get_meta("motion")
			car.position = (motion.from as Vector3).lerp(motion.to, fposmod(float(motion.offset), 1.0))
			k += 1


# ─────────────────────────────── 하늘 ───────────────────────────────

## 하늘 공(안쪽 면에 별·은하수) + 3D 달(크레이터) + 달 둘레 빛무리 + 달에 꽂힌 다트(펍 다트 게임 농담).
static func _sky(p: Node3D) -> void:
	var center := sky_center()
	var dome := SphereMesh.new()
	dome.radius = SKY_RADIUS
	dome.height = SKY_RADIUS * 2.0
	dome.radial_segments = 48
	dome.rings = 24
	var sky := ShaderMaterial.new()
	sky.resource_name = "StreetSky"
	sky.shader = load(SKY_SHADER)
	sky.set_shader_parameter("center", center)
	var dome_node := MeshKit.mesh_node(p, "SkyDome", dome, center, sky)
	dome_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dome_node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	# 달.
	var direction := MOON_DIR.normalized()
	var moon_at := center + direction * MOON_DISTANCE
	var moon := ShaderMaterial.new()
	moon.resource_name = "StreetMoon"
	moon.shader = load(MOON_SHADER)
	var moon_node := MeshKit.mesh_node(p, "Moon", RoundKit.sphere_mesh(MOON_RADIUS, 40), moon_at, moon)
	moon_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 달이 펍 쪽을 보게 돌린다(크레이터 무늬·밝은 쪽이 앞에 온다).
	moon_node.basis = Basis.looking_at(-direction, Vector3.UP)
	var halo := ShaderMaterial.new()
	halo.resource_name = "MoonHalo"
	halo.shader = load(HALO_SHADER)
	halo.set_shader_parameter("halo_color", Color("8f9fd8"))
	halo.set_shader_parameter("strength", 0.55)
	var halo_quad := QuadMesh.new()
	halo_quad.size = Vector2.ONE * MOON_RADIUS * 6.0
	MeshKit.mesh_node(p, "MoonHalo", halo_quad, moon_at + direction * MOON_RADIUS * 1.5, halo).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 달에 꽂힌 다트: 펍 쪽으로 비스듬히 튀어나온다(앞에서 보면 달 위의 검은 실루엣 + 빨간 깃).
	var side := Vector3.UP.cross(direction).normalized()
	var axis := (-direction * 0.55 + side * 0.65 + Vector3.UP * 0.5).normalized()
	var tip := moon_at + (side * 0.45 + Vector3.UP * 0.5 - direction * 0.2).normalized() * MOON_RADIUS * 0.9
	var dart := Node3D.new()
	dart.name = "MoonDart"
	dart.position = tip
	dart.basis = Basis.looking_at(axis, Vector3.UP)
	p.add_child(dart, true)
	# 다트 로컬 −Z = 꽂힌 곳에서 바깥으로. 통(은색) → 대(검정) → 깃 셋(빨강, 120° 간격).
	var barrel := RoundKit.lathe_mesh(PackedVector2Array([Vector2(0, 0), Vector2(0.55, 1.0), Vector2(0.85, 2.0), Vector2(0.85, 5.0), Vector2(0.5, 6.0), Vector2(0, 6.0)]), 12)
	var shaft := RoundKit.lathe_mesh(PackedVector2Array([Vector2(0, 0), Vector2(0.28, 0), Vector2(0.28, 6.5), Vector2(0, 6.5)]), 8)
	for part: Array in [[barrel, 0.0, Color("aeb6c4"), 0.0], [shaft, 5.8, Color("2b2d36"), 0.0]]:
		var node := shaded(dart, "DartPart", part[0], Vector3(0, 0, -float(part[1])), part[2], 0, part[3])
		node.rotation.x = -PI / 2.0
	var fin := BoxMesh.new()
	fin.size = Vector3(0.12, 2.6, 4.2)
	for k in range(3):
		var flight := shaded(dart, "DartFlight", fin, Vector3.ZERO, Color("e0473c"), 0, 0.9)
		flight.basis = Basis(Vector3.BACK, TAU * k / 3.0)
		flight.position = Vector3(0, 0, -11.0) + flight.basis * Vector3(0, 1.3, 0)


## 서쪽 관람차(다트 홀 왼쪽 창 정면 너머, 낮은 첫 줄 건물 지붕 위로 위쪽이 보인다). 바퀴가 천천히 돌고 칸은 늘 똑바로 매달린다.
static func _ferris_wheel(p: Node3D) -> void:
	var b := pub_block()
	var at := Vector3(b.position.x - 40.5, WALK_TOP, b.position.y + 14.0)
	var radius := 16.0
	var hub_y := radius + 6.0
	p.position = at
	# 바퀴 축(로컬 X)이 펍 가운데를 보게.
	var toward := sky_center() - at
	p.rotation.y = atan2(-toward.z, toward.x)
	# 받침 다리(A 자) 넷 + 축.
	for side: float in [-1.0, 1.0]:
		for lean: float in [-1.0, 1.0]:
			var leg := RoundKit.rod(p, "WheelLeg", Vector3(side * 2.8, 0, lean * 7.0), Vector3(side * 1.45, hub_y, 0), 0.32, night(), 0.22, 8)
			_set_look(leg, STEEL)
	_set_look(RoundKit.rod(p, "WheelAxle", Vector3(-1.7, hub_y, 0), Vector3(1.7, hub_y, 0), 0.45, night(), -1.0, 10), STEEL)
	_slab(p, "WheelBase", Rect2(-4.0, -8.5, 8.0, 17.0), -0.05, 0.25, Color("5b5560"))
	if _lamps.size() < MAX_LAMPS:
		_lamps.append(Vector4(at.x, at.y + 3.0, at.z, 12.0))
	var wheel := Node3D.new()
	wheel.name = "Wheel"
	wheel.position = Vector3(0, hub_y, 0)
	wheel.set_meta("motion", {"kind": "spin", "axis": Vector3.RIGHT, "speed": 0.06})
	p.add_child(wheel, true)
	# 테 두 줄(빛나는 전구 띠) + 바퀴살(합친 메시 하나).
	for x: float in [-1.0, 1.0]:
		var rim := shaded(wheel, "WheelRim", RoundKit.ring_mesh("ferris_rim", radius, RoundKit.circle_profile(0.22, 8), 64), Vector3(x, 0, 0), Color("ffc46b"), 0, 2.4)
		rim.rotation.z = PI / 2.0
	var spoke := RoundKit.lathe_mesh(PackedVector2Array([Vector2(0, 0), Vector2(0.09, 0), Vector2(0.09, radius), Vector2(0, radius)]), 6)
	var parts: Array = []
	for k in range(16):
		for x: float in [-1.0, 1.0]:
			parts.append([spoke, Transform3D(Basis(Vector3.RIGHT, TAU * k / 16.0), Vector3(x, 0, 0))])
	shaded(wheel, "WheelSpokes", RoundKit.merge("ferris_spokes", parts), Vector3.ZERO, Color("ff7fb0"), 0, 1.3)
	# 칸 12개: 테에 매달리고, 바퀴와 반대로 돌아 늘 똑바로 선다.
	var cabin_colors: Array[Color] = [Color("d9534f"), Color("f0ad4e"), Color("5bc0de"), Color("8e6bd6"), Color("5cb85c"), Color("f78fb3")]
	for k in range(12):
		var angle := TAU * k / 12.0
		var hang := Node3D.new()
		hang.name = "Cabin"
		hang.position = Vector3(0, cos(angle) * radius, sin(angle) * radius)
		hang.set_meta("motion", {"kind": "spin", "axis": Vector3.RIGHT, "speed": -0.06})
		wheel.add_child(hang, true)
		shaded(hang, "CabinBody", MeshKit.rounded_box_mesh(Vector3(1.2, 1.7, 1.5), 0.3, 3), Vector3(0, -1.2, 0), cabin_colors[k % cabin_colors.size()])
		shaded(hang, "CabinWindow", MeshKit.rounded_box_mesh(Vector3(1.26, 0.55, 1.56), 0.12, 2), Vector3(0, -1.0, 0), Color("ffd89a"), 0, 1.1)


## 둥근 막대처럼 RoundKit 이 만든 노드에 바깥 겉색을 준다.
static func _set_look(node: MeshInstance3D, color: Color, glow := 0.0) -> void:
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.set_instance_shader_parameter("base_color", color)
	if glow > 0.0:
		node.set_instance_shader_parameter("self_glow", glow)


## 열기구 셋(동쪽 둘 · 남쪽 하나): 줄무늬 풍선 + 바구니 + 버너 불빛. 위아래로 둥실 뜬다.
static func _balloons(p: Node3D) -> void:
	var specs: Array = [[Vector3(58, 42, -12), 4.5, Color("d64541"), Color("f3e3c3")],
		[Vector3(88, 55, 22), 4.0, Color("3f6fd1"), Color("f2c94c")],
		[Vector3(24, 50, 80), 5.0, Color("3aa676"), Color("f08a3c")]]
	var size := 0
	for spec: Array in specs:
		var root := Node3D.new()
		root.name = "Balloon"
		root.position = spec[0]
		root.rotation.y = _rng.randf_range(0.0, TAU)
		root.set_meta("motion", {"kind": "bob", "amp": 1.2, "speed": 0.35 + 0.1 * size, "phase": float(size) * 2.1})
		p.add_child(root, true)
		_balloon(root, spec[1], spec[2], spec[3])
		size += 1


## 풍선 한 개(바닥 = 버너 아래 바구니 바닥 위 2.6m). radius = 가장 넓은 반지름.
static func _balloon(root: Node3D, radius: float, color_a: Color, color_b: Color) -> void:
	var r := radius
	var profile := PackedVector2Array([Vector2(0.22 * r, 0), Vector2(0.34 * r, 0.27 * r), Vector2(0.6 * r, 0.67 * r), Vector2(0.82 * r, 1.1 * r),
		Vector2(0.96 * r, 1.5 * r), Vector2(1.0 * r, 1.82 * r), Vector2(0.93 * r, 2.15 * r), Vector2(0.72 * r, 2.45 * r), Vector2(0.4 * r, 2.66 * r), Vector2(0, 2.74 * r)])
	var stripes := 12
	var wedge := RoundKit.lathe_mesh(profile, 3, TAU / stripes)
	for pick in range(2):
		var parts: Array = []
		for k in range(pick, stripes, 2):
			parts.append([wedge, Transform3D(Basis(Vector3.UP, TAU * k / stripes), Vector3.ZERO)])
		shaded(root, "Envelope", RoundKit.merge("balloon_envelope|%.2f|%d" % [r, pick], parts), Vector3.ZERO, color_a if pick == 0 else color_b)
	# 바구니 · 줄 · 버너 불빛.
	shaded(root, "Basket", MeshKit.rounded_box_mesh(Vector3(1.3, 1.0, 1.3), 0.12, 2), Vector3(0, -2.4, 0), Color("8a5a35"))
	var rope_parts: Array = []
	var rope := RoundKit.lathe_mesh(PackedVector2Array([Vector2(0, 0), Vector2(0.03, 0), Vector2(0.03, 1.0), Vector2(0, 1.0)]), 4)
	for corner: Vector2 in [Vector2(-0.6, -0.6), Vector2(0.6, -0.6), Vector2(0.6, 0.6), Vector2(-0.6, 0.6)]:
		var a := Vector3(corner.x, -1.9, corner.y)
		var top := Vector3(corner.x * 0.36 * r / 0.6, 0.0, corner.y * 0.36 * r / 0.6) * 0.6
		var along := top - a
		var turn := Basis(Quaternion(Vector3.UP, along.normalized())).scaled_local(Vector3(1, along.length(), 1))
		rope_parts.append([rope, Transform3D(turn, a)])
	shaded(root, "Ropes", RoundKit.merge("balloon_ropes|%.2f" % r, rope_parts), Vector3.ZERO, Color("3a3030"))
	shaded(root, "Burner", RoundKit.sphere_mesh(0.35, 10), Vector3(0, -0.6, 0), Color("ff9a3c"), 0, 3.0)


## 구름: 납작한 공 여러 개를 합친 덩어리. 달빛이 위에서 비쳐 윗면이 밝다. 천천히 동쪽으로 흐른다.
static func _clouds(p: Node3D) -> void:
	var sphere := RoundKit.sphere_mesh(1.0, 14)
	var spots: Array = [Vector3(-160, 92, 150), Vector3(40, 105, 210), Vector3(150, 88, 120), Vector3(-90, 80, -40),
		Vector3(210, 98, -30), Vector3(-200, 110, 40), Vector3(90, 84, -170), Vector3(-30, 120, 260)]
	var index := 0
	for spot: Vector3 in spots:
		var parts: Array = []
		var puffs := 5 + index % 3
		for k in range(puffs):
			var width := _rng.randf_range(9.0, 17.0)
			var offset := Vector3(_rng.randf_range(-16.0, 16.0), _rng.randf_range(-2.0, 3.0), _rng.randf_range(-8.0, 8.0))
			parts.append([sphere, Transform3D(Basis.from_scale(Vector3(width, width * 0.38, width * 0.7)), offset)])
		var cloud := shaded(p, "Cloud", RoundKit.merge("street_cloud|%d" % index, parts), spot, Color("6d6a88"))
		cloud.set_meta("motion", {"kind": "drift", "speed": 0.8 + 0.15 * (index % 4), "span": 520.0})
		index += 1
