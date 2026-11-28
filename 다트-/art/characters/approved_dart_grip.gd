extends RefCounted
## 승인 오른손은 손목에 강체로 스킨되어 있다. 1인칭 복사 메시만 이 쥐기 자세와 원래 펴진 자세 사이를 보간한다.

const SHAPE := &"ThreeFingerGrip"
const LARGE_SHAPE := &"ThreeFingerGripLarge"
## 손바닥 좌표의 엄지·검지·중지 끝마디 보정. 자루 둘레의 서로 다른 세 면에 맞춘다.
const PAD_OFFSETS: Array[Vector3] = [
	Vector3(-0.0209, -0.0167, 0.0162), Vector3(0.021865, -0.018622, -0.000214), Vector3(0.013144, 0.005941, 0.006699)]
const LARGE_PAD_OFFSETS: Array[Vector3] = [
	Vector3(-0.005047, -0.024178, 0.006202), Vector3(0.038005, -0.015348, 0.007589), Vector3(0.021545, 0.006937, 0.000345)]
const PAD_ANGLES := Vector3(218.5, 83.5, -6.5)
## 손목 뼈 기준. +X는 새끼에서 엄지, +Y는 손목에서 손끝, +Z는 손바닥 안쪽.
const PALM := Basis(Vector3(0.7846, 0.0, 0.62), Vector3.UP, Vector3(-0.62, 0.0, 0.7846))
## 손바닥 길이 축 기준, 아래팔이 손목에서 살짝 손등 쪽으로 이어진다.
const ELBOW_DIRECTION := PALM * Vector3(0.03, -1.0, -0.18)
const JOINTS: Array[Vector3] = [
	Vector3(0.112, 0.153, 0.179), Vector3(0.110, 0.152, 0.179),
	Vector3(0.108, 0.150, 0.177), Vector3(0.106, 0.149, 0.175),
]
const FLEXION: Array[Vector3] = [
	Vector3(66, 62, 21), Vector3(58, 57, 18), Vector3(42, 35, 13), Vector3(43, 40, 16),
]
## 승인 손등 쪽으로 편 자세. 검지부터 새끼 순서로 밑·가운데·끝마디 각도다.
const OPEN_FLEX: Array[Vector3] = [Vector3(-16, -12, -4), Vector3(-14, -10, -4), Vector3(-10, -6, -2), Vector3(-6, -4, 0)]
const OPEN_SPREAD := Vector4(-6, -2, 3, 8)
const OPEN_THUMB := Vector3(-12, -18, -6)
const FINGER_COLUMNS := Vector4(-0.042, -0.013, 0.013, 0.042)
const SPREAD := Vector4(-8.0, -4.0, 2.0, 9.0)
const DEPTH := Vector3(0.002, 0.011, 0.022)
const THUMB_ROOT := Vector3(0.049, 0.043, 0.004)
const THUMB_JOINT := Vector3(0.080, 0.086, 0.015)
const THUMB_FLEXION := Vector3(24, 32, 17)


## 다트 자루 중심과 길이 방향을 쥔 손의 손목 좌표로 돌려준다.
static func barrel(large: bool) -> Transform3D:
	var center := Vector3(0.057555, 0.097399, 0.068694) if large else Vector3(0.042718, 0.100762, 0.070292)
	var back := (Vector3(1.0, 0.015623, -0.381852) if large else Vector3(1.0, -0.248788, -0.611394)).normalized()
	var up: Vector3 = (Vector3.BACK - back * back.z).normalized()
	return Transform3D(PALM * Basis(up.cross(back), up, back), PALM * center)


## 원본 엄지 끝에는 아래팔의 가중치도 섞여 있다. 1인칭 복사본에서만 끝마디를 손목에 고정한다.
static func bind_thumb(arrays: Array, skin: Skin, hand_rest: Transform3D) -> void:
	var hand: int = _hand_bind(skin)
	if hand < 0:
		return
	var to_palm := (hand_rest * Transform3D(PALM, Vector3.ZERO)).affine_inverse()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES].duplicate()
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS].duplicate()
	var stride: int = bones.size() / vertices.size()
	for i in range(vertices.size()):
		var p: Vector3 = to_palm * vertices[i]
		if p.x < 0.044 or p.x > 0.11 or p.y < 0.045 or p.y > 0.123 or absf(p.z) > 0.056:
			continue
		var blend: float = smoothstep(0.044, 0.066, p.x) * smoothstep(0.045, 0.08, p.y)
		var first: int = i * stride
		var slot: int = first
		for j in range(first, first + stride):
			if bones[j] == hand:
				slot = j
				break
			if weights[j] < weights[slot]:
				slot = j
		bones[slot] = hand
		for j in range(first, first + stride):
			weights[j] *= 1.0 - blend
		weights[slot] += blend
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights


static func surface_pose(arrays: Array, skin: Skin, hand_rest: Transform3D, large: bool, side: StringName = &"hand.R", palm: Basis = PALM, opened: bool = false) -> Array:
	var shape: Array = []
	shape.resize(Mesh.ARRAY_MAX)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX].duplicate()
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL].duplicate()
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var hand_bind: int = _hand_bind(skin, side)
	if hand_bind >= 0:
		var from_palm := hand_rest * Transform3D(palm, Vector3.ZERO)
		var to_palm := from_palm.affine_inverse()
		var joints: Array[Transform3D] = _joint_transforms(OPEN_FLEX, OPEN_SPREAD, OPEN_THUMB) if opened else _joint_transforms()
		var socket := Transform3D(PALM.inverse(), Vector3.ZERO) * barrel(large)
		var contacts: Array[Vector3] = []
		for digit in range(3):
			var angle: float = deg_to_rad(PAD_ANGLES[digit])
			contacts.append(socket.basis * Vector3(cos(angle), sin(angle), 0))
		var influences: int = bones.size() / points.size()
		for index in range(points.size()):
			var offset: int = index * influences
			var hand_weight: float = 0.0
			for influence in range(influences):
				if bones[offset + influence] == hand_bind:
					hand_weight += weights[offset + influence]
			if hand_weight <= 0.5:
				continue
			var point: Vector3 = to_palm * points[index]
			if point.y <= 0.038:
				continue
			var normal: Vector3 = to_palm.basis * normals[index]
			var bent: PackedVector3Array = _bend(point, normal, joints)
			if not opened:
				_seat_pads(point, bent, socket, contacts, large)
			if side == &"hand.L":
				var thumb := smoothstep(0.053,0.066,point.x)*smoothstep(0.067,0.099,point.y)*(1.0-smoothstep(0.119,0.132,point.y))
				var fingers := _middle_weight(point)*smoothstep(0.147,0.176,point.y)*(1.0-thumb)
				# The thumb pad and the two fingertips straddle the thin packet.
				bent[0].z = lerpf(bent[0].z,0.077,thumb)
				bent[0].z = lerpf(bent[0].z,0.063,fingers)
			points[index] = from_palm * bent[0]
			normals[index] = (from_palm.basis * bent[1]).normalized()
	shape[Mesh.ARRAY_VERTEX] = points
	shape[Mesh.ARRAY_NORMAL] = normals
	shape[Mesh.ARRAY_TANGENT] = arrays[Mesh.ARRAY_TANGENT]
	return shape


static func _hand_bind(skin: Skin, side: StringName = &"hand.R") -> int:
	for index in range(skin.get_bind_count()):
		if skin.get_bind_name(index) == side:
			return index
	return -1


## 끝마디에서 손가락 배가 팔각 자루에 눌리는 부분만 해당 면을 따라 편다.
static func _seat_pads(rest: Vector3, bent: PackedVector3Array, socket: Transform3D, contacts: Array[Vector3], large: bool) -> void:
	var index: float = _index_weight(rest)
	var thumb: float = smoothstep(0.053, 0.066, rest.x) * smoothstep(0.051, 0.094, rest.y) * (1.0 - smoothstep(0.119, 0.132, rest.y))
	var fingers: float = smoothstep(0.112, 0.153, rest.y) * (1.0 - thumb)
	var weights := Vector3(thumb, index * fingers, (1.0 - index) * _middle_weight(rest) * fingers)
	var offsets: Array[Vector3] = LARGE_PAD_OFFSETS if large else PAD_OFFSETS
	var size: float = DartView.LARGE_SIZE if large else 1.0
	var point: Vector3 = bent[0] + offsets[0] * weights.x + offsets[1] * weights.y + offsets[2] * weights.z
	if large:
		# 굵은 자루의 앞쪽에서는 약지 끝을 손바닥 쪽으로 조금 더 접는다.
		point -= socket.basis.y * 0.023 * (1.0 - _middle_weight(rest)) * smoothstep(0.14, 0.185, rest.y)
	var relative: Vector3 = point - socket.origin
	var along: float = relative.dot(socket.basis.z)
	# 끝마디는 지정한 면에 닿고 중간 마디는 자루 옆을 돌아 손바닥으로 이어진다.
	var base_side: Vector3 = (socket.basis.x - socket.basis.y * 0.6).normalized()
	var free: float = clampf(1.0 - weights.x - weights.y - weights.z, 0.0, 1.0)
	var side: Vector3 = (base_side * free + contacts[0] * weights.x + contacts[1] * weights.y + contacts[2] * weights.z).normalized()
	var radius: float = (0.00515 * size / 0.52 + along * 0.026)
	var radial: Vector3 = relative - socket.basis.z * along
	var nearby: float = 1.0 - smoothstep(radius * 2.5, radius * 4.5, radial.length())
	var on_barrel: float = 1.0 - smoothstep(0.025 * size / 0.52, 0.036 * size / 0.52, absf(along))
	var face: float = radius * lerpf(cos(PI / 8.0), 1.15, free)
	point += side * maxf(0.0, face - relative.dot(side)) * nearby * on_barrel
	bent[0] = point


## 손끝의 경계는 손바닥 깊이에 따라 기울어져 있다. 서로 떨어진 끝마디끼리 가중치를 섞지 않는다.
static func _index_weight(p: Vector3) -> float:
	var width: float = lerpf(0.005, 0.00012, smoothstep(0.143, 0.169, p.y))
	return smoothstep(-width, width, p.x - 0.25 * p.z - 0.02547)


static func _middle_weight(p: Vector3) -> float:
	var width: float = lerpf(0.005, 0.00035, smoothstep(0.143, 0.169, p.y))
	return smoothstep(-width, width, p.x - 0.25 * p.z - 0.08 * p.y + 0.01556)


static func _joint_transforms(flex: Array[Vector3] = FLEXION, spread: Vector4 = SPREAD, thumb: Vector3 = THUMB_FLEXION) -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	for finger in range(JOINTS.size()):
		for joint in range(3):
			var center := Vector3(FINGER_COLUMNS[finger], JOINTS[finger][joint], DEPTH[joint])
			var turn := Basis(Vector3.RIGHT, deg_to_rad(flex[finger][joint]))
			if joint == 0:
				turn = Basis(Vector3.BACK, deg_to_rad(-spread[finger])) * turn
			transforms.append(Transform3D(turn, center - turn * center))
	var opposition := Basis(Vector3.BACK, deg_to_rad(thumb.y)) * Basis(Vector3.RIGHT, deg_to_rad(thumb.x))
	var tip := Basis(Vector3(1, 0, 1).normalized(), deg_to_rad(thumb.z))
	transforms.append(Transform3D(opposition, THUMB_ROOT - opposition * THUMB_ROOT))
	transforms.append(Transform3D(tip, THUMB_JOINT - tip * THUMB_JOINT))
	return transforms


## 각 마디는 중심을 축으로 돌린다. 마디 경계에서만 피부 위치와 법선을 두 쪽 사이로 보간한다.
static func _bend(point: Vector3, normal: Vector3, joints: Array[Transform3D]) -> PackedVector3Array:
	# 엄지와 손바닥 사이가 벌어진 지점에서는 가중치 경계가 검지 쪽 피부에 걸리지 않게 좁힌다.
	var thumb_clear: float = smoothstep(0.069, 0.084, point.y)
	var thumb_edge: float = smoothstep(lerpf(0.048, 0.057, thumb_clear), lerpf(0.067, 0.064, thumb_clear), point.x)
	var thumb: float = thumb_edge * (1.0 - smoothstep(0.119, 0.132, point.y)) * smoothstep(0.046, 0.069, point.y)
	var thumb_index: int = JOINTS.size() * 3
	var thumb_base: Transform3D = joints[thumb_index]
	var thumb_tip: Transform3D = joints[thumb_index + 1]
	var tip_weight: float = smoothstep(0.076, 0.096, point.y)
	var thumb_point: Vector3 = thumb_base * point.lerp(thumb_tip * point, tip_weight)
	var thumb_normal: Vector3 = thumb_base.basis * normal.lerp(thumb_tip.basis * normal, tip_weight)
	var bent_point: Vector3 = point.lerp(thumb_point, thumb)
	var bent_normal: Vector3 = normal.lerp(thumb_normal, thumb)
	var pinky: float = smoothstep(-0.031, -0.021, point.x)
	var ring: float = _middle_weight(point)
	var middle: float = _index_weight(point)
	var influences := Vector4(1.0 - pinky, pinky - ring, ring - middle, middle)
	for finger in range(4):
		var amount: float = influences[finger] * (1.0 - thumb)
		if amount <= 0.0:
			continue
		var finger_point: Vector3 = point
		var finger_normal: Vector3 = normal
		for joint in [2, 1, 0]:
			var height: float = JOINTS[finger][joint]
			var blend: float = smoothstep(height - 0.011, height + 0.011, point.y)
			var joint_pose: Transform3D = joints[finger * 3 + joint]
			finger_point = finger_point.lerp(joint_pose * finger_point, blend)
			finger_normal = finger_normal.lerp(joint_pose.basis * finger_normal, blend)
		bent_point += (finger_point - point) * amount
		bent_normal += (finger_normal - normal) * amount
	return PackedVector3Array([bent_point, bent_normal])
