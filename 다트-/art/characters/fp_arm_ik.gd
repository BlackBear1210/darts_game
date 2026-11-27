extends RefCounted
## [부품 1] 1인칭 오른팔 뼈 맞추기 — 어깨·팔꿈치·손목 자리와 손 방향을 받아 승인 모델 팔 뼈 세 개를 세운다.
## first_person_hand_view.gd 가 매 프레임 부른다. class_name 을 새로 만들지 않고 preload 로 부른다.
##
## [왜] 2026-11-27 사용자 지적 "손이 왜 휘어서 다트를 잡고 있는지 모르겠다".
## 예전 방식은 팔 뼈를 쉬는 자세(A 자세)로 둔 채 모델 전체를 다트에 맞춰 돌려서, 아래팔과 손목이 이상하게 꺾였다.
## 이제 팔꿈치가 실제 관절처럼 한 평면에서만 접히고, 손목은 다트를 겨누는 만큼만 꺾인다.
##
## 좌표는 모두 스켈레톤 기준(모델 크기 배율이 빠진 값)이다. 부르는 쪽이 카메라 기준 점을 스켈레톤 기준으로 바꿔 넘긴다.

const UPPER := "upper_arm.R"
const FORE := "forearm.R"
const HAND := "hand.R"


## 뼈 번호와 쉬는 자세를 한 번만 읽어 둔다.
class Chain:
	var upper: int = -1
	var fore: int = -1
	var hand: int = -1
	## 위팔 쉬는 자세 기준 "팔꿈치를 굽히는 축"(위팔 → 아래팔 쪽으로 도는 축, 위팔 자기 좌표).
	var hinge_local: Vector3 = Vector3.RIGHT
	## 아래팔 자기 좌표의 길이 방향(팔꿈치 → 손목).
	var fore_axis_local: Vector3 = Vector3.UP
	var upper_length: float = 0.0
	var fore_length: float = 0.0

	func valid() -> bool:
		return upper >= 0 and fore >= 0 and hand >= 0


static func chain(rig: Skeleton3D) -> Chain:
	var c := Chain.new()
	c.upper = rig.find_bone(UPPER)
	c.fore = rig.find_bone(FORE)
	c.hand = rig.find_bone(HAND)
	if not c.valid():
		return c
	var fore_rest: Transform3D = rig.get_bone_rest(c.fore)
	var hand_rest: Transform3D = rig.get_bone_rest(c.hand)
	c.upper_length = fore_rest.origin.length()
	c.fore_length = hand_rest.origin.length()
	c.fore_axis_local = hand_rest.origin.normalized()
	# 쉬는 자세에서도 팔꿈치가 몸 앞쪽으로 살짝(약 8°) 굽어 있다 → 그 굽힘 축이 해부학적인 팔꿈치 축이다.
	var to_fore: Vector3 = fore_rest.origin.normalized()
	var to_hand: Vector3 = fore_rest.basis * hand_rest.origin.normalized()
	var axis: Vector3 = to_fore.cross(to_hand)
	c.hinge_local = axis.normalized() if axis.length() > 0.0001 else Vector3.RIGHT
	return c


## 팔 뼈 세 개를 세운다.
##   elbow, wrist  팔꿈치·손목 자리(스켈레톤 기준). 길이는 부르는 쪽이 Chain 길이로 맞춰 둔다.
##   hinge         팔꿈치를 굽히는 축(위팔 → 아래팔로 도는 축, 스켈레톤 기준). 팔이 거의 펴져도 축이 흔들리지 않게 밖에서 받는다.
##   hand_basis    손 뼈의 방향(회전만, 스켈레톤 기준)
##   hand_scale    손 뼈 크기 배율(모델 배율 대비). 팔은 길게, 손은 다트에 맞는 크기로 따로 맞춘다.
##   twist_share   손목 비틀림 중 아래팔이 나눠 갖는 몫(0~1). 손목 살이 사탕 포장지처럼 꼬이지 않게 한다.
static func pose(rig: Skeleton3D, c: Chain, elbow: Vector3, wrist: Vector3, hinge: Vector3, hand_basis: Basis, hand_scale: float, twist_share: float = 0.75) -> void:
	if not c.valid():
		return
	var parent_global: Transform3D = rig.get_bone_global_pose(rig.get_bone_parent(c.upper))
	var parent_turn: Basis = parent_global.basis.orthonormalized()
	var upper_rest: Transform3D = rig.get_bone_rest(c.upper)
	var shoulder: Vector3 = (parent_global * upper_rest).origin
	# 1) 위팔: 길이 방향을 팔꿈치 쪽으로 돌리고, 굽히는 축이 hinge 와 같아지게 자기 축 둘레로 비튼다.
	var upper_turn: Basis = (parent_turn * upper_rest.basis).orthonormalized()
	var fore_offset: Vector3 = rig.get_bone_rest(c.fore).origin
	upper_turn = _aim(upper_turn, fore_offset, elbow - shoulder)
	var along: Vector3 = (elbow - shoulder).normalized()
	upper_turn = Basis(along, twist_to(upper_turn * c.hinge_local, hinge, along)) * upper_turn
	# 2) 아래팔: 쉬는 자세의 굽힘에서 출발해 손목 쪽으로 돌린다.
	var fore_rest: Transform3D = rig.get_bone_rest(c.fore)
	var fore_turn: Basis = (upper_turn * fore_rest.basis).orthonormalized()
	fore_turn = _aim(fore_turn, rig.get_bone_rest(c.hand).origin, wrist - elbow)
	# 3) 손목 비틀림을 아래팔에 나눠 준다(손이 돈 만큼 아래팔도 같이 돈다 — 실제로도 아래팔뼈 두 개가 꼬이며 돈다).
	var hand_turn: Basis = hand_basis.orthonormalized()
	var hand_rest: Transform3D = rig.get_bone_rest(c.hand)
	var relative: Basis = fore_turn.inverse() * hand_turn * hand_rest.basis.orthonormalized().inverse()
	var twist: float = _twist_angle(relative.get_rotation_quaternion(), c.fore_axis_local)
	fore_turn = fore_turn * Basis(c.fore_axis_local, twist * twist_share)
	# 부모 기준 회전으로 바꿔 넣는다(위치는 쉬는 자세 그대로 — 뼈 길이가 안 바뀐다).
	rig.set_bone_pose_rotation(c.upper, (parent_turn.inverse() * upper_turn).get_rotation_quaternion())
	rig.set_bone_pose_rotation(c.fore, (upper_turn.inverse() * fore_turn).get_rotation_quaternion())
	rig.set_bone_pose_rotation(c.hand, (fore_turn.inverse() * hand_turn).get_rotation_quaternion())
	rig.set_bone_pose_scale(c.hand, Vector3.ONE * hand_scale)


## turn 의 자기 축(local)이 가리키는 방향을 target 방향으로 가장 짧게 돌린다.
## (hand_basis 는 손 뼈 자기 좌표 — approved_dart_grip.barrel 이 쓰는 좌표 — 를 스켈레톤으로 옮기는 회전이다.)
static func _aim(turn: Basis, local: Vector3, target: Vector3) -> Basis:
	var now: Vector3 = (turn * local).normalized()
	var want: Vector3 = target.normalized()
	return Basis(arc(now, want)) * turn


static func arc(a: Vector3, b: Vector3) -> Quaternion:
	var d: float = clampf(a.dot(b), -1.0, 1.0)
	if d > 0.999999:
		return Quaternion.IDENTITY
	if d < -0.999999:
		var side: Vector3 = a.cross(Vector3.RIGHT)
		if side.length() < 0.001:
			side = a.cross(Vector3.UP)
		return Quaternion(side.normalized(), PI)
	return Quaternion(a.cross(b).normalized(), acos(d))


## axis 둘레로 얼마나 돌려야 now 가 want 와 같은 쪽을 보는가(둘 다 axis 에 수직인 성분만 본다).
static func twist_to(now: Vector3, want: Vector3, axis: Vector3) -> float:
	var a: Vector3 = now - axis * now.dot(axis)
	var b: Vector3 = want - axis * want.dot(axis)
	if a.length() < 0.0001 or b.length() < 0.0001:
		return 0.0
	a = a.normalized()
	b = b.normalized()
	return atan2(axis.dot(a.cross(b)), a.dot(b))


## 회전 q 중 axis 둘레로 비튼 각(스윙·트위스트 분해의 트위스트).
static func _twist_angle(q: Quaternion, axis: Vector3) -> float:
	var p: Vector3 = Vector3(q.x, q.y, q.z)
	var projected: Vector3 = axis * p.dot(axis)
	var twist := Quaternion(projected.x, projected.y, projected.z, q.w)
	if twist.length_squared() < 0.0000001:
		return 0.0
	twist = twist.normalized()
	var angle: float = 2.0 * atan2(Vector3(twist.x, twist.y, twist.z).dot(axis), twist.w)
	return wrapf(angle, -PI, PI)
