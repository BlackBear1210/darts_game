class_name CharacterPoseLayer
extends SkeletonModifier3D
## AnimationPlayer 가 만든 온몸 모션 위에 코드 몸짓을 얹는다. 디자인 담당 소유.
##   팔: 왼팔·오른팔 자세를 weight 만큼 덮어쓴다 → 걷거나 앉아 있어도 카드 든 왼팔·조준하는 오른팔이 유지된다.
##   머리·윗몸: 시선 높이, 엿보기 기울기, 왕머리.
## 값을 넣는 곳은 CharacterMotion 하나다. 축은 모델 기준(정면 -Z, 오른쪽 +X, 위 +Y)이다.
## Skeleton3D 는 모디파이어를 돌린 뒤 뼈 자세를 되돌리므로 프레임마다 값이 쌓이지 않는다.

## 시선 높이(라디안, 위 +). 목과 머리가 반씩 나눠 든다.
var look_pitch := 0.0
## 윗몸이 오른쪽(+X)으로 기운 각도(라디안)와 머리를 더 꺾는 각도.
var lean := 0.0
var head_tilt := 0.0
var head_scale := 1.0
var left: Arm
var right: Arm
## 앉은 다리 자세 비율(0 = 모션 그대로, 1 = 허벅지는 방석 위에 수평 · 정강이는 아래로 · 발은 의자 발걸이 위).
## 2026-11-08 사용자 지적 "의자에 앉아 있는 모션이 이상하다": Seated_Stool 모션은 낮은 의자용이라 허벅지가
## 35도 아래로 기울어 무릎(높이 0.43m)이 앉는 면 0.6m 의자 방석을 뚫었다. CharacterMotion 이 넣는다.
var seat_legs := 0.0

## 앉은 다리 방향(모델 기준, 오른쪽 다리 = +X 쪽. 왼쪽은 x 를 뒤집는다).
## 허벅지: 앞(−Z)으로 거의 수평(무릎이 조금 벌어진다). 정강이: 아래로, 발이 의자 밑으로 25도 들어간다.
## 발은 모션의 발 방향(바닥과 평행)을 그대로 지켜 발걸이에 평평하게 얹힌다.
const SEAT_THIGH := Vector3(0.1, -0.02, -1.0)
const SEAT_SHIN := Vector3(0.05, -0.906, 0.423)

var _spine: int
var _neck: int
var _head: int
## [허벅지, 정강이, 발, 좌우 부호] — 왼쪽 -1, 오른쪽 +1.
var _legs: Array = []


## 팔 하나의 덧씌운 자세. 회전만 덮어쓴다(팔 뼈는 위치 이동이 없다).
class Arm:
	var bones := PackedInt32Array()
	var pose: Array[Quaternion] = []
	var weight := 0.0
	var _names := PackedStringArray()
	var _path := ""
	## Animation → 뼈 순서대로의 회전 트랙 번호.
	var _tracks: Dictionary = {}

	## skeleton_path = AnimationPlayer 기준 스켈레톤 경로. 트랙 경로 앞부분이다.
	func _init(rig: Skeleton3D, names: PackedStringArray, skeleton_path: String) -> void:
		_names = names
		_path = skeleton_path
		for bone_name in names:
			var bone := rig.find_bone(bone_name)
			bones.append(bone)
			pose.append(rig.get_bone_rest(bone).basis.get_rotation_quaternion())

	## clip 의 time 초 자세에서 이 팔의 회전을 꺼낸다.
	func sample(clip: Animation, time: float) -> Array[Quaternion]:
		if not _tracks.has(clip):
			var tracks := PackedInt32Array()
			for bone_name in _names:
				tracks.append(clip.find_track(NodePath("%s:%s" % [_path, bone_name]), Animation.TYPE_ROTATION_3D))
			_tracks[clip] = tracks
		var result: Array[Quaternion] = []
		for track: int in _tracks[clip]:
			result.append(clip.rotation_track_interpolate(track, time))
		return result

	## target 자세로 amount(0~1)만큼 따라간다. 보이지 않을 때는 바로 그 자세로 옮겨 시작이 튀지 않게 한다.
	func follow(target: Array[Quaternion], strength: float, amount: float) -> void:
		for index in range(pose.size()):
			pose[index] = target[index] if weight < 0.01 else pose[index].slerp(target[index], amount)
		weight = lerpf(weight, strength, amount)


func setup(rig: Skeleton3D, left_arm: Arm, right_arm: Arm) -> void:
	left = left_arm
	right = right_arm
	_spine = rig.find_bone("spine")
	_neck = rig.find_bone("neck")
	_head = rig.find_bone("head")
	_legs.clear()
	for side: String in ["L", "R"]:
		var bones := [rig.find_bone("thigh." + side), rig.find_bone("shin." + side), rig.find_bone("foot." + side), -1.0 if side == "L" else 1.0]
		if bones[0] >= 0 and bones[1] >= 0 and bones[2] >= 0:
			_legs.append(bones)


func _process_modification() -> void:
	var rig := get_skeleton()
	if rig == null or left == null:
		return
	for arm: Arm in [left, right]:
		if arm.weight > 0.001:
			for index in range(arm.bones.size()):
				var bone: int = arm.bones[index]
				rig.set_bone_pose_rotation(bone, rig.get_bone_pose_rotation(bone).slerp(arm.pose[index], arm.weight))
	if seat_legs > 0.001:
		for leg: Array in _legs:
			_seat_leg(rig, leg[0], leg[1], leg[2], leg[3])
	# 오른쪽(+X)으로 기우는 것은 앞에서 봤을 때 모델 Z 축 음의 방향 회전이다.
	_turn(rig, _spine, Vector3.BACK, -lean)
	_turn(rig, _neck, Vector3.BACK, -head_tilt)
	_turn(rig, _neck, Vector3.RIGHT, look_pitch * 0.5)
	_turn(rig, _head, Vector3.RIGHT, look_pitch * 0.5)
	rig.set_bone_pose_scale(_head, Vector3.ONE * head_scale)


## 다리 하나를 앉은 자세로: 허벅지 → 정강이 순서로 뼈 방향을 SEAT_THIGH·SEAT_SHIN 쪽으로 seat_legs 만큼 돌리고,
## 발은 돌리기 전(모션)의 바닥과 평행한 방향을 그대로 지킨다.
func _seat_leg(rig: Skeleton3D, thigh: int, shin: int, foot: int, side: float) -> void:
	var foot_facing := rig.get_bone_global_pose(foot).basis.get_rotation_quaternion()
	_aim(rig, thigh, shin, SEAT_THIGH * Vector3(side, 1, 1), seat_legs)
	_aim(rig, shin, foot, SEAT_SHIN * Vector3(side, 1, 1), seat_legs)
	var shin_facing := rig.get_bone_global_pose(shin).basis.get_rotation_quaternion()
	rig.set_bone_pose_rotation(foot, rig.get_bone_pose_rotation(foot).slerp(shin_facing.inverse() * foot_facing, seat_legs))


## bone(→ child 방향)을 모델 기준 direction 쪽으로 amount 만큼 돌린다(가장 짧게 도는 회전이라 다리가 비틀리지 않는다).
func _aim(rig: Skeleton3D, bone: int, child: int, direction: Vector3, amount: float) -> void:
	var from := rig.get_bone_global_pose(bone)
	var current := (rig.get_bone_global_pose(child).origin - from.origin).normalized()
	var target := current.slerp(direction.normalized(), amount)
	if current.is_equal_approx(target):
		return
	var facing := Quaternion(current, target) * from.basis.get_rotation_quaternion()
	var parent := rig.get_bone_parent(bone)
	var parent_facing := rig.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
	rig.set_bone_pose_rotation(bone, parent_facing.inverse() * facing)


## bone 을 모델 기준 axis 둘레로 돌린다. 뼈마다 로컬 축이 달라 모델 축을 뼈 축으로 옮겨 쓴다.
func _turn(rig: Skeleton3D, bone: int, axis: Vector3, angle: float) -> void:
	if is_zero_approx(angle):
		return
	var facing := rig.get_bone_global_pose(bone).basis.get_rotation_quaternion()
	var local_axis := (facing.inverse() * axis).normalized()
	rig.set_bone_pose_rotation(bone, rig.get_bone_pose_rotation(bone) * Quaternion(local_axis, angle))
