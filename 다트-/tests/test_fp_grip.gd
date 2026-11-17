extends SceneTree
## 1인칭 손과 손에 든 다트 검사(2026-11-17 밤 사용자 지적 "손이 다트를 통과한다", "크기 카드를 쓰면 손도 커진다").
##   & $godot --headless --path . --script res://tests/test_fp_grip.gd
## 1. 보통 다트: 손 살이 다트(촉·자루·대·깃) 안으로 ALLOWED_DEPTH 넘게 들어가지 않는다 + 엄지·검지 끝마디가 자루에 닿는다.
## 2. 크기 카드(DartView.LARGE_SIZE): 커진 다트도 뚫지 않는다 + 손 크기는 FirstPersonArm.HAND_SCALE 그대로다
##    (커진 다트 자세를 dart_grip 으로 넘겨도 손이 커지지 않는다).
## 3. 힘 카드: 날아가는 다트에 바람 줄기가 붙고, 꽂힌 뒤 사라진다.
## 손 살 = 스킨드 정점(뼈 자세로 CPU 에서 계산) + 삼각형 가운데·변 가운데 표본. 다트 치수 = game/dart/dart.tscn.
## FirstPersonArm.GRIP_BEND · PINCH_NUDGE · LARGE_NUDGE · GRIP_ROLL 이나 HeldDart 방향을 바꾸면 이 시험을 돌린다.

const FirstPersonArm = preload("res://art/characters/first_person_arm.gd")
const GAME_SCENE: PackedScene = preload("res://game/game.tscn")
const DART_SCENE: PackedScene = preload("res://game/dart/dart.tscn")
## 살이 다트 안으로 들어가도 봐주는 깊이(m) — 표본 간격 오차.
const ALLOWED_DEPTH: float = 0.0005
## 엄지·검지 끝마디가 자루에 "닿았다"고 보는 거리(m).
const TOUCH: float = 0.0015

var _failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game := GAME_SCENE.instantiate()
	var camera := game.get_node("Camera") as Camera3D
	game.remove_child(camera)
	game.free()
	root.add_child(camera)
	var hand := camera.get_node("Hand") as Node3D
	var held := hand.get_node("HeldDart") as Node3D
	var base: Transform3D = held.transform
	var arm := FirstPersonArm.new()
	arm.dart_grip = base
	hand.add_child(arm)
	# 커진 다트 자세를 그대로 넘겨받은 팔(예전엔 이렇게 팔을 다시 붙이면 손이 1.8배가 됐다).
	var arm_from_large := FirstPersonArm.new()
	arm_from_large.dart_grip = FirstPersonArm.held_dart(base, DartView.LARGE_SIZE)
	hand.add_child(arm_from_large)
	arm_from_large.visible = false
	await process_frame
	var model := arm.get_node("Model") as Node3D
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D

	held.transform = FirstPersonArm.held_dart(base, 1.0)
	arm.hold_large(false)
	var normal: Dictionary = _measure(hand, base, 1.0, model, rig)
	_check(float(normal.depth) <= ALLOWED_DEPTH, "보통 다트: 손이 다트를 %.2fmm 뚫는다(%s)" % [float(normal.depth) * 1000.0, normal.where])
	_check(normal.touch.has("thumb_03.R") and normal.touch.has("index_03.R"), "보통 다트: 엄지·검지 끝마디가 자루에 닿아야 한다(닿은 마디 %s)" % [normal.touch.keys()])

	held.transform = FirstPersonArm.held_dart(base, DartView.LARGE_SIZE)
	arm.hold_large(true)
	var large: Dictionary = _measure(hand, base, DartView.LARGE_SIZE, model, rig)
	_check(float(large.depth) <= ALLOWED_DEPTH, "큰 다트: 손이 다트를 %.2fmm 뚫는다(%s)" % [float(large.depth) * 1000.0, large.where])
	_check(is_equal_approx(model.transform.basis.get_scale().x, FirstPersonArm.HAND_SCALE), "큰 다트: 손 크기가 바뀌었다")
	var other := arm_from_large.get_node("Model") as Node3D
	_check(is_equal_approx(other.transform.basis.get_scale().x, FirstPersonArm.HAND_SCALE), "커진 다트 자세로 붙인 팔이 커졌다(%.3f)" % other.transform.basis.get_scale().x)

	await _check_wind()
	print("FP GRIP %s  보통 깊이 %.2fmm 자루까지 %.2fmm · 큰 다트 깊이 %.2fmm" % ["FAIL" if _failed else "PASS", float(normal.depth) * 1000.0, float(normal.gap) * 1000.0, float(large.depth) * 1000.0])
	quit(1 if _failed else 0)


## 힘 카드 다트: 날아가는 동안 Visual 아래에 바람 원뿔이 있고, 꽂히고 조금 뒤 없어진다.
func _check_wind() -> void:
	var dart := DART_SCENE.instantiate() as DartView
	root.add_child(dart)
	dart.powered = true
	dart.fly(Vector3(0, 1.4, 2.0), Vector3(0, 1.5, 0), 0.2)
	var visual := dart.get_node("Visual")
	_check(visual.get_node_or_null("Wind0") != null, "힘 카드: 날아가는 다트에 바람 줄기가 없다")
	var plain := DART_SCENE.instantiate() as DartView
	root.add_child(plain)
	plain.fly(Vector3(0, 1.4, 2.0), Vector3(0, 1.5, 0), 0.2)
	_check(plain.get_node("Visual").get_node_or_null("Wind0") == null, "힘 카드가 아닌 다트에 바람 줄기가 붙었다")
	await create_timer(0.2 + DartView.WIND_FADE_SECONDS + 0.4).timeout
	_check(visual.get_node_or_null("Wind0") == null, "힘 카드: 꽂힌 뒤에도 바람 줄기가 남아 있다")


## 손 살이 다트 안으로 들어간 가장 깊은 곳(m)과 자루에 닿은 마디. size = 다트 배율(자루 가운데 기준).
func _measure(hand: Node3D, base: Transform3D, size: float, model: Node3D, rig: Skeleton3D) -> Dictionary:
	var to_dart: Transform3D = (hand.global_transform * base).affine_inverse() * rig.global_transform
	var bones: Array[String] = []
	for finger: String in ["thumb", "index", "middle", "ring", "pinky"]:
		for joint: String in ["_01.R", "_02.R", "_03.R"]:
			bones.append(finger + joint)
	bones.append("hand.R")
	var result := {"depth": 0.0, "where": "", "gap": 1.0, "touch": {}}
	for part: String in FirstPersonArm.ARM_PARTS:
		var mesh := model.find_child(part, true, false) as MeshInstance3D
		for point: Vector3 in _samples(mesh, rig):
			var local: Vector3 = FirstPersonArm.GRIP_PIVOT + (to_dart * point - FirstPersonArm.GRIP_PIVOT) / size
			var inside: Array = _inside(local)
			var depth: float = float(inside[0]) * size
			if depth > float(result.depth):
				result.depth = depth
				result.where = "%s · %s" % [inside[1], _nearest_bone(rig, point, bones)]
			var barrel_gap: float = float(inside[2]) * size
			if barrel_gap < float(result.gap) and barrel_gap >= 0.0:
				result.gap = barrel_gap
			if barrel_gap >= 0.0 and barrel_gap < TOUCH:
				result.touch[_nearest_bone(rig, point, bones)] = true
	return result


## 다트(배율 1, 원점 = 촉 끝, +Z = 뒤) 안으로 들어간 깊이, 부위 이름, 자루 겉면까지 거리(자루 길이 밖이면 -1).
func _inside(p: Vector3) -> Array:
	var radial: float = Vector2(p.x, p.y).length()
	var depth: float = 0.0
	var where: String = ""
	var barrel_gap: float = -1.0
	if p.z >= 0.0 and p.z < 0.02 and radial < 0.003 * p.z / 0.02:
		depth = 0.003 * p.z / 0.02 - radial
		where = "촉"
	elif p.z >= 0.02 and p.z <= 0.07:
		var barrel: float = lerpf(0.0045, 0.0058, (p.z - 0.02) / 0.05)
		barrel_gap = radial - barrel
		if radial < barrel:
			depth = barrel - radial
			where = "자루"
	elif p.z > 0.07 and p.z <= 0.14 and radial < 0.003:
		depth = 0.003 - radial
		where = "대"
	if p.z >= 0.1 and p.z <= 0.17:
		var flat: float = minf(absf(p.x), absf(p.y))
		var wide: float = maxf(absf(p.x), absf(p.y))
		if wide <= 0.0375 and flat <= 0.003 and 0.003 - flat > depth:
			depth = 0.003 - flat
			where = "깃"
	return [depth, where, barrel_gap]


func _nearest_bone(rig: Skeleton3D, point: Vector3, bones: Array[String]) -> String:
	var best: String = ""
	var best_distance: float = INF
	for bone_name: String in bones:
		var distance: float = rig.get_bone_global_pose(rig.find_bone(bone_name)).origin.distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best = bone_name
	return best


## 스킨드 정점 + 삼각형 가운데·변 가운데(스켈레톤 좌표). 그려지는 삼각형만 쓴다.
func _samples(mesh: MeshInstance3D, rig: Skeleton3D) -> PackedVector3Array:
	var result := PackedVector3Array()
	var binds: Array[Transform3D] = []
	for bind in range(mesh.skin.get_bind_count()):
		var bone: int = mesh.skin.get_bind_bone(bind)
		if bone < 0:
			bone = rig.find_bone(mesh.skin.get_bind_name(bind))
		binds.append(rig.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(bind))
	for surface in range(mesh.mesh.get_surface_count()):
		var arrays: Array = mesh.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var influences: int = bones.size() / vertices.size()
		var skinned := PackedVector3Array()
		skinned.resize(vertices.size())
		for vertex in range(vertices.size()):
			var sum := Vector3.ZERO
			for influence in range(influences):
				var weight: float = weights[vertex * influences + influence]
				if weight > 0.0:
					sum += (binds[bones[vertex * influences + influence]] * vertices[vertex]) * weight
			skinned[vertex] = sum
		for triangle in range(0, indices.size(), 3):
			var a: Vector3 = skinned[indices[triangle]]
			var b: Vector3 = skinned[indices[triangle + 1]]
			var c: Vector3 = skinned[indices[triangle + 2]]
			result.append_array([a, (a + b + c) / 3.0, (a + b) * 0.5, (b + c) * 0.5, (c + a) * 0.5])
	return result


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		print("FAIL ", message)
