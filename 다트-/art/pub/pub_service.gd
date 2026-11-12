extends Node3D
## 바텐더(펍)·주스 가게 직원(오락실)이 카운터 뒤를 걸어 다니며 손님에게 음료를 따라 주고,
## 뒤돌아 주방 기구(전자레인지)에서 음식을 꺼내 손님 앞에 놓는다(2026-11-08 사용자 요청
## "바텐더도 가만히 있으면 어색하니까 움직이면서 바에 앉은 AI 캐릭터들한테 따라 주고 · 오락실도 똑같이 서빙 ·
##  음식은 뒤돌아서 주방의 전자레인지 같은 가구에서 꺼내서 서빙하는 느낌").
##
## 움직임은 차례 목록(_steps)을 하나씩 처리하는 상태 기계다(await 를 쓰지 않는다 — 테마를 바꿔 방이 지워져도 멈춘 함수가 남지 않는다).
##   한 번의 일 = [통로를 따라 걷기 → 몸 돌리기 → 손 뻗고 기다리기(잔·캔·접시가 손에 생긴다) → 손님 자리로 걷기 → 카운터에 내려놓기].
##   손님 자리가 다 차 있으면 오래된 잔·접시 하나를 치운다(집어 들고 뒤돌아 내려놓으면 사라진다).
## 직원은 NPC(art/pub/npc_idle.gd, style 3)다: 걷는 빠르기(walk_ratio)·오른팔 뻗기(reaching)만 여기서 넣고 몸짓은 CharacterMotion 이 튼다.
## 좌표는 모두 이 노드의 부모(펍 방 / 오락실) 기준이다. 이 노드는 원점에 둔다. 충돌·규칙과는 상관없는 보이기만 하는 장식이다.
## 만드는 곳: art/pub/game_room_builder.gd(펍 → pub_game.tscn 에 저장) · game/lounge/arcade/arcade_room.gd(오락실, 실행 때).

const PubParts = preload("res://art/pub/pub_parts.gd")
const SCRIPT_PATH := "res://art/pub/pub_service.gd"

## 직원 노드 경로(이 노드 기준).
@export var server_path: NodePath
## 직원이 걷는 통로(카운터 뒤) x, 걸을 수 있는 z 범위.
@export var lane_x: float = 0.0
## 손님 앞에 잔·접시를 놓을 때 카운터 쪽으로 다가서는 x(통로보다 카운터에 가깝다).
@export var serve_x: float = 0.0
@export var lane_min_z: float = 0.0
@export var lane_max_z: float = 1.0
## 손님을 볼 때(카운터 쪽) 몸 방향 yaw. 직원 모델 정면 = -Z.
@export var counter_yaw: float = -PI / 2
## 가져오는 곳: [종류 "drink"|"food", 설 z, 볼 yaw, 기다리는 초, 소품 이름들(PackedStringArray), 배율, 빛 자리(Vector3, 없으면 Vector3.ZERO), 설 x].
## 소품 이름 "plate+steak@1.15" = 접시(plate) 위에 스테이크를 1.15배로. "@배율"이 없으면 그 줄의 배율을 쓴다.
@export var sources: Array = []
## 손님: [직원이 설 z, 음료 놓을 자리(Vector3), 음식 놓을 자리(Vector3)].
@export var customers: Array = []
## 걷는 빠르기(m/s). 선수 최고 속도(3.8)에 대한 비율로 걷기 모션 빠르기가 정해진다.
@export var walk_speed: float = 1.15

## 직원 손에 든 물건이 손뼈에서 내려오는 거리(m) — 잔 바닥이 손바닥 아래에 오게.
const HAND_DROP := 0.07
## 카운터에 놓은 잔·접시를 치우기 전 최소 시간(초).
const KEEP_SECONDS := 26.0
## 몸을 돌리는 빠르기.
const TURN_RATE := 7.0
const PLAYER_TOP_SPEED := 3.8
## 잔·접시를 내려놓거나 집는 데 걸리는 초.
const PLACE_SECONDS := 0.55

var _server: Node3D
var _skeleton: Skeleton3D
var _hand: int = -1
var _steps: Array = []
var _step_time: float = 0.0
var _carried: Node3D
## 손님 번호 → {"drink": 노드, "food": 노드, "drink_at": 초, "food_at": 초}
var _served: Dictionary = {}
var _time: float = 0.0
var _random := RandomNumberGenerator.new()
var _flash: OmniLight3D
## 내려놓기·집기 동안 물건을 손 ↔ 카운터 사이로 미끄러뜨린다(그동안 손 따라가기를 멈춘다).
var _slide_from: Vector3
var _sliding: bool = false
## 뼈 수정(팔 뻗기)이 끝난 오른손 자리(이 노드 기준). Skeleton3D.skeleton_updated 때마다 새로 잰다.
var _hand_at: Vector3


## 서빙 노드("Service")를 만들어 직원(server)과 같은 부모 아래에 둔다. 펍 생성기(바텐더)·오락실(주스 가게 직원)이 부른다.
## lane = 통로 x, serve = 손님 앞에 다가서는 x, lane_z = 걸을 수 있는 z(x~y), facing = 손님을 볼 때 yaw,
## from = sources(가져오는 곳), to = customers(손님) — 모양은 위 @export 설명과 같다.
static func make(parent: Node3D, server: Node3D, lane: float, serve: float, lane_z: Vector2, facing: float, from: Array, to: Array) -> Node3D:
	var service := (load(SCRIPT_PATH) as GDScript).new() as Node3D
	service.name = "Service"
	service.set("server_path", NodePath("../" + str(server.name)))
	service.set("lane_x", lane)
	service.set("serve_x", serve)
	service.set("lane_min_z", lane_z.x)
	service.set("lane_max_z", lane_z.y)
	service.set("counter_yaw", facing)
	service.set("sources", from)
	service.set("customers", to)
	parent.add_child(service)
	return service


func _ready() -> void:
	_server = get_node_or_null(server_path) as Node3D
	if _server == null or sources.is_empty() or customers.is_empty():
		set_process(false)
		return
	var model := _server.get_node_or_null("Character")
	if model != null:
		var found := model.find_children("*", "Skeleton3D", true, false)
		if not found.is_empty():
			_skeleton = found[0] as Skeleton3D
			_hand = _skeleton.find_bone("hand.R")
			# 팔 뻗기는 뼈 수정기(CharacterPoseLayer)가 넣는다 → _process 에서 읽은 손뼈는 수정 전 자세다.
			# 수정이 끝난 뒤 알려 주는 신호에서 손 자리를 재고 든 물건을 옮긴다(BoneAttachment3D 와 같은 방식).
			if _hand >= 0:
				_skeleton.skeleton_updated.connect(_on_skeleton_updated)
	_server.set("style", 3)
	_random.randomize()
	_flash = OmniLight3D.new()
	_flash.name = "KitchenFlash"
	_flash.light_color = Color("ffb35c")
	_flash.light_energy = 0.0
	_flash.omni_range = 1.4
	# 실행 중에 생기는 노드는 안쪽(internal) 자식으로 둔다 — 방 생성기가 장면을 저장할 때(MeshKit.own_tree) 같이 저장되지 않는다.
	add_child(_flash, false, Node.INTERNAL_MODE_BACK)
	for index in range(customers.size()):
		_served[index] = {}
	_steps.append(["wait", _random.randf_range(0.8, 2.0)])


func _process(delta: float) -> void:
	_time += delta
	if _steps.is_empty():
		_plan()
	if not _steps.is_empty():
		_run_step(delta)
	_follow_hand()


## 다음 일을 정한다: 빈 손님 자리 하나에 음료나 음식을 가져다 놓는다. 다 차 있으면 오래된 것 하나를 치운다.
func _plan() -> void:
	var open: Array = []
	for index in range(customers.size()):
		for kind: String in ["drink", "food"]:
			if not is_instance_valid(_served[index].get(kind)):
				open.append([index, kind])
	if not open.is_empty():
		var pick: Array = open[_random.randi_range(0, open.size() - 1)]
		_plan_serve(int(pick[0]), str(pick[1]))
		return
	var oldest: Array = []
	var oldest_at: float = INF
	for index in range(customers.size()):
		for kind: String in ["drink", "food"]:
			var at: float = float(_served[index].get(kind + "_at", 0.0))
			if at < oldest_at:
				oldest_at = at
				oldest = [index, kind]
	if _time - oldest_at < KEEP_SECONDS:
		_steps.append(["wait", minf(KEEP_SECONDS - (_time - oldest_at), 4.0)])
		return
	_plan_clear(int(oldest[0]), str(oldest[1]))


func _plan_serve(index: int, kind: String) -> void:
	var choices: Array = []
	for source: Array in sources:
		if str(source[0]) == kind:
			choices.append(source)
	if choices.is_empty():
		_served[index][kind + "_at"] = _time
		_steps.append(["wait", 1.0])
		return
	var source: Array = choices[_random.randi_range(0, choices.size() - 1)]
	var keys: PackedStringArray = source[4]
	var customer: Array = customers[index]
	_steps.append(["walk", float(source[1])])
	if source.size() > 7:
		_steps.append(["side", float(source[7])])
	_steps.append(["turn", float(source[2])])
	_steps.append(["reach", float(source[3]), str(keys[_random.randi_range(0, keys.size() - 1)]), float(source[5]), source[6] if source.size() > 6 else Vector3.ZERO])
	_steps.append(["walk", float(customer[0])])
	_steps.append(["side", serve_x])
	_steps.append(["turn", counter_yaw])
	_steps.append(["place", index, kind])
	_steps.append(["wait", _random.randf_range(1.5, 4.0)])


## 다 먹은(마신) 것을 치운다: 손님 앞에서 집어 들고 → 첫 가져오는 곳으로 돌아가 뒤돌면 사라진다.
func _plan_clear(index: int, kind: String) -> void:
	var customer: Array = customers[index]
	var back: Array = sources[0]
	_steps.append(["walk", float(customer[0])])
	_steps.append(["side", serve_x])
	_steps.append(["turn", counter_yaw])
	_steps.append(["pick", index, kind])
	_steps.append(["walk", float(back[1])])
	if back.size() > 7:
		_steps.append(["side", float(back[7])])
	_steps.append(["turn", float(back[2])])
	_steps.append(["drop"])
	_steps.append(["wait", _random.randf_range(1.0, 2.5)])


func _run_step(delta: float) -> void:
	var step: Array = _steps[0]
	_step_time += delta
	var done := false
	match str(step[0]):
		"wait":
			_server.set("walk_ratio", 0.0)
			done = _step_time >= float(step[1])
		"walk":
			# 통로(lane_x)로 돌아가며 z 를 따라 걷는다. 걷는 쪽을 본다.
			var target := Vector3(lane_x, _server.position.y, clampf(float(step[1]), lane_min_z, lane_max_z))
			done = _move_to(target, delta, true)
		"side":
			# 카운터·주방 쪽으로 반걸음 다가서기(또는 통로로 물러나기). 몸 방향은 그대로 두고 발만 옮긴다.
			var target := Vector3(float(step[1]), _server.position.y, _server.position.z)
			done = _move_to(target, delta, false)
		"turn":
			_server.set("walk_ratio", 0.0)
			done = _turn_towards(float(step[1]), delta)
		"reach":
			# 손을 뻗고(전자레인지 문 열기·꼭지 당기기·캔 꺼내기) 기다린다. 반쯤 지나 손에 물건이 생긴다.
			_server.set("reaching", _step_time < float(step[1]) * 0.85)
			var light_at: Vector3 = step[4]
			if light_at != Vector3.ZERO:
				_flash.position = light_at
				_flash.light_energy = 1.4 if _step_time < float(step[1]) * 0.7 else 0.0
			if _carried == null and _step_time >= float(step[1]) * 0.5:
				_carried = _make_item(str(step[2]), float(step[3]))
			done = _step_time >= float(step[1])
			if done:
				_server.set("reaching", false)
				_flash.light_energy = 0.0
		"place":
			# 팔을 뻗으며 손에 든 것을 손님 앞 자리로 미끄러뜨려 내려놓는다.
			_server.set("reaching", true)
			var index: int = int(step[1])
			var kind: String = str(step[2])
			var spot: Vector3 = customers[index][1 if kind == "drink" else 2]
			if _carried != null:
				if not _sliding:
					_sliding = true
					_slide_from = _carried.position
				_carried.position = _slide_from.lerp(spot, smoothstep(0.0, PLACE_SECONDS, _step_time))
			if _step_time >= PLACE_SECONDS:
				if _carried != null:
					_carried.position = spot
					_served[index][kind] = _carried
					_served[index][kind + "_at"] = _time
					_carried = null
				_sliding = false
				_server.set("reaching", false)
				done = true
		"pick":
			# 팔을 뻗어 다 먹은 잔·접시를 손 쪽으로 끌어온다.
			_server.set("reaching", true)
			var node: Node3D = _served[int(step[1])].get(str(step[2]))
			if is_instance_valid(node):
				if not _sliding:
					_sliding = true
					_slide_from = node.position
				node.position = _slide_from.lerp(_hand_point(), smoothstep(0.0, PLACE_SECONDS, _step_time))
			if _step_time >= PLACE_SECONDS:
				if is_instance_valid(node):
					_carried = node
				_served[int(step[1])].erase(str(step[2]))
				_sliding = false
				_server.set("reaching", false)
				done = true
		"drop":
			_server.set("reaching", true)
			if _step_time >= 0.5:
				if _carried != null:
					_carried.queue_free()
					_carried = null
				_server.set("reaching", false)
				done = true
	if done:
		_steps.pop_front()
		_step_time = 0.0


## target(부모 좌표)까지 걷는다. face = 걷는 쪽으로 몸을 돌릴지(모델 정면 = -Z → 방향 d 를 보는 yaw = atan2(-d.x, -d.z)).
## 도착하면 true.
func _move_to(target: Vector3, delta: float, face: bool) -> bool:
	var here: Vector3 = _server.position
	var gap := Vector3(target.x - here.x, 0, target.z - here.z)
	if gap.length() < 0.02:
		_server.position = Vector3(target.x, here.y, target.z)
		_server.set("walk_ratio", 0.0)
		return true
	var move: Vector3 = gap.normalized() * minf(gap.length(), walk_speed * delta)
	_server.position = here + move
	if face:
		_turn_towards(atan2(-gap.x, -gap.z), delta)
	# 옆걸음은 짧아서 걷기 모션을 반만 튼다.
	_server.set("walk_ratio", walk_speed / PLAYER_TOP_SPEED * (1.0 if face else 0.5))
	return false


## 몸을 yaw 쪽으로 돌린다. 다 돌았으면 true.
func _turn_towards(yaw: float, delta: float) -> bool:
	var now: float = _server.rotation.y
	var next: float = lerp_angle(now, yaw, 1.0 - exp(-TURN_RATE * delta))
	_server.rotation.y = next
	return absf(wrapf(yaw - next, -PI, PI)) < 0.05


## 들고 있는 물건을 오른손 아래에 붙인다(몸 방향으로 똑바로 세운다). 내려놓는·집는 중에는 그 단계가 옮긴다.
func _follow_hand() -> void:
	if _carried == null or not is_instance_valid(_carried):
		_carried = null
		return
	if _sliding:
		return
	_carried.position = _hand_point()
	_carried.rotation.y = _server.rotation.y


func _on_skeleton_updated() -> void:
	# 트리 이탈 뒤 도착한 뼈 갱신은 전역 좌표를 읽지 않는다.
	if not is_inside_tree() or not is_instance_valid(_skeleton) or not _skeleton.is_inside_tree() or _hand < 0:
		return
	_hand_at = to_local((_skeleton.global_transform * _skeleton.get_bone_global_pose(_hand)).origin) + Vector3(0, -HAND_DROP, 0)
	_follow_hand()


## 오른손 바로 아래(이 노드 기준). 뼈를 못 찾으면 가슴 앞.
func _hand_point() -> Vector3:
	if _skeleton != null and _hand >= 0 and _hand_at != Vector3.ZERO:
		return _hand_at
	return _server.position + Vector3(0, 1.0, 0) - _server.basis.z * 0.3


## 손에 생기는 잔·캔·접시. "plate+음식" 이면 접시(plate) 위에 음식을 얹고, 아니면 그 소품 하나(dish_N = 접시째 요리).
## 이름 끝 "@배율" 은 그 소품만의 배율이다(예: "plate+steak@1.15").
func _make_item(key: String, scale_value: float) -> Node3D:
	if key.contains("@"):
		scale_value = float(key.get_slice("@", 1))
		key = key.get_slice("@", 0)
	var holder := Node3D.new()
	holder.name = "Served"
	add_child(holder, false, Node.INTERNAL_MODE_BACK)
	var food_on_plate: bool = key.begins_with("plate+")
	if food_on_plate:
		PubParts.asset(holder, "plate", Vector3.ZERO, 0.0, Vector3.ONE * 0.62)
		var food := PubParts.asset(holder, key.trim_prefix("plate+"), Vector3(0, 0.022, 0), _random.randf_range(-PI, PI), Vector3.ONE * scale_value)
		if food == null:
			holder.queue_free()
			return null
	elif PubParts.asset(holder, key, Vector3.ZERO, 0.0, Vector3.ONE * scale_value) == null:
		holder.queue_free()
		return null
	return holder
