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

var _spine: int
var _neck: int
var _head: int


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


func _process_modification() -> void:
	var rig := get_skeleton()
	if rig == null or left == null:
		return
	for arm: Arm in [left, right]:
		if arm.weight > 0.001:
			for index in range(arm.bones.size()):
				var bone: int = arm.bones[index]
				rig.set_bone_pose_rotation(bone, rig.get_bone_pose_rotation(bone).slerp(arm.pose[index], arm.weight))
	# 오른쪽(+X)으로 기우는 것은 앞에서 봤을 때 모델 Z 축 음의 방향 회전이다.
	_turn(rig, _spine, Vector3.BACK, -lean)
	_turn(rig, _neck, Vector3.BACK, -head_tilt)
	_turn(rig, _neck, Vector3.RIGHT, look_pitch * 0.5)
	_turn(rig, _head, Vector3.RIGHT, look_pitch * 0.5)
	rig.set_bone_pose_scale(_head, Vector3.ONE * head_scale)


## bone 을 모델 기준 axis 둘레로 돌린다. 뼈마다 로컬 축이 달라 모델 축을 뼈 축으로 옮겨 쓴다.
func _turn(rig: Skeleton3D, bone: int, axis: Vector3, angle: float) -> void:
	if is_zero_approx(angle):
		return
	var facing := rig.get_bone_global_pose(bone).basis.get_rotation_quaternion()
	var local_axis := (facing.inverse() * axis).normalized()
	rig.set_bone_pose_rotation(bone, rig.get_bone_pose_rotation(bone) * Quaternion(local_axis, angle))
