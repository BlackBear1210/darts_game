extends SkeletonModifier3D
## 줄 끊긴 인형(래그돌) — 2026-11-15 사용자 요청.
## "맞는 순간 애니메이터를 끄고 래그돌을 켠다. 캡슐과 관절로 된 줄 끊긴 인형이 되고, 관절이 꺾이는 범위를 정하고,
##  다 쓰러지면 재운다."
##
## [구조]
##   Skeleton3D
##   ├─ CharacterPoseLayer      (팔·머리 몸짓 — 래그돌 동안은 CharacterMotion 이 끈다)
##   ├─ RagdollBodies            PhysicalBoneSimulator3D: 아래 조각(PhysicalBone3D)들의 물리 결과를 뼈 자세로 옮긴다
##   │   ├─ hips …               몸 조각 11개 = 캡슐 충돌 모양 + 부모 조각과 잇는 관절(PIECES 표)
##   └─ Ragdoll(이 노드)         쓰러진 자세를 기억했다가, 일어날 때 그 자세 → 애니메이션 자세로 부드럽게 섞는다
##
## [관절 한계(도)] 사람 몸이 꺾일 수 있는 만큼만 꺾이게 정했다(PIECES 표의 숫자).
##   허리(골반↔가슴) 원뿔 25 · 비틀기 20      목(가슴↔머리) 원뿔 40 · 비틀기 35
##   어깨 원뿔 85 · 비틀기 50                    팔꿈치 경첩 0~140(앞으로만 굽는다)
##   엉덩이 관절 원뿔 60 · 비틀기 25            무릎 경첩 0~130(뒤로만 굽는다)
##   원뿔 = 기본 자세 방향에서 그 각도 안에서만 흔들린다. 경첩 = 한 축으로만, 한쪽으로만 굽는다(거꾸로 꺾이지 않는다).
##
## [재우기] 모든 조각의 속도가 SETTLE_* 아래로 SETTLE_HOLD 초 동안 이어지거나 SLEEP_AFTER 초가 지나면
##   물리 서버에 "잠들기"를 걸어 계산을 멈춘다(자세는 그대로 남는다). 일어날 때(stop) 물리를 끄고 애니메이션으로 돌아간다.
##
## [충돌] 조각은 물리 층 5(BODY_LAYER)에 있고 방(층 1 — 바닥·벽·가구)하고만 부딪힌다.
##   사람 캡슐(층 2)·다트 광선·소품 광선은 조각을 보지 않는다 → 쓰러진 몸이 다른 사람을 밀거나 판정을 막지 않는다.
##
## 보이기 전용이다: 화면마다 따로 계산한다(쓰러진 모양은 화면마다 조금 다를 수 있다). 누가 언제 쓰러지고 일어나는지는
## 방장이 정한다(GameView.knock_down). 화면 없는 서버에서는 만들지 않는다.
## class_name 을 쓰지 않는다(열린 편집기가 새 class_name 을 못 읽는 함정) — preload 로 부른다.

const BODY_LAYER: int = 16
const WORLD_MASK: int = 1
## 재우기 기준: 조각 속도(m/s)·회전 속도(rad/s)가 이보다 느린 채 SETTLE_HOLD 초가 지나면 재운다.
const SETTLE_LINEAR: float = 0.18
const SETTLE_ANGULAR: float = 1.0
const SETTLE_HOLD: float = 0.35
## 쓰러지기 시작하고 이 시간(초) 전에는 재우지 않는다(넘어지는 중에 잠깐 멈춘 순간을 "다 쓰러짐"으로 보지 않게).
const SETTLE_MIN_TIME: float = 0.6
## 이 시간(초)이 지나면 아직 꿈틀거려도 재운다(가구 모서리에 걸려 계속 떨리는 경우).
const SLEEP_AFTER: float = 3.0
## 일어날 때 쓰러진 자세 → 애니메이션 자세로 섞는 시간(초).
const GET_UP_BLEND: float = 0.45
## 굴러다니지 않게 하는 감쇠(공기 저항 같은 것). 숫자가 클수록 빨리 멈춘다.
const LINEAR_DAMP: float = 0.25
const ANGULAR_DAMP: float = 2.2
## 원뿔 관절: 관절 기준 X 축 = 뼈가 뻗는 방향(조각 기준 -Z). 이 축에서 벗어나는 각도가 "흔들림", 축 둘레가 "비틀기"다.
const CONE_FRAME := Basis(Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0))

## 몸 조각 표. [뼈, 캡슐 끝 뼈, 반지름 m, 질량 kg, 관절, 한계 A(도), 한계 B(도), 굽는 쪽(경첩만, 모델 기준)]
##   관절 "root" = 뿌리 조각(관절 없음) · "cone" = 원뿔(A = 흔들림, B = 비틀기) · "hinge" = 경첩(A = 펴는 쪽, B = 굽는 쪽 최대).
##   굽는 쪽: 팔꿈치는 앞(모델 정면 -Z)으로, 무릎은 뒤(+Z)로 굽는다.
const PIECES: Array = [
	["hips", "extra_Spine1", 0.13, 9.0, "root", 0.0, 0.0, Vector3.ZERO],
	["extra_Spine1", "neck", 0.14, 10.0, "cone", 25.0, 20.0, Vector3.ZERO],
	["head", "extra_HeadTop_End", 0.16, 4.0, "cone", 40.0, 35.0, Vector3.ZERO],
	["upper_arm.L", "forearm.L", 0.055, 1.6, "cone", 85.0, 50.0, Vector3.ZERO],
	["forearm.L", "hand.L", 0.048, 1.2, "hinge", 3.0, 140.0, Vector3(0, 0, -1)],
	["upper_arm.R", "forearm.R", 0.055, 1.6, "cone", 85.0, 50.0, Vector3.ZERO],
	["forearm.R", "hand.R", 0.048, 1.2, "hinge", 3.0, 140.0, Vector3(0, 0, -1)],
	["thigh.L", "shin.L", 0.075, 5.0, "cone", 60.0, 25.0, Vector3.ZERO],
	["shin.L", "foot.L", 0.06, 3.0, "hinge", 3.0, 130.0, Vector3(0, 0, 1)],
	["thigh.R", "shin.R", 0.075, 5.0, "cone", 60.0, 25.0, Vector3.ZERO],
	["shin.R", "foot.R", 0.06, 3.0, "hinge", 3.0, 130.0, Vector3(0, 0, 1)],
]

## 지금 물리로 쓰러지는 중인가(재운 뒤에도 일어나기 전까지 true).
var simulating: bool = false
## 다 쓰러져서 재웠는가.
var asleep: bool = false

var _rig: Skeleton3D
var _simulator: PhysicalBoneSimulator3D
var _bodies: Array[PhysicalBone3D] = []
var _hips: PhysicalBone3D
var _age: float = 0.0
var _still: float = 0.0
## 쓰러진 자세(뼈마다 부모 기준 자세). 물리 중에 매 프레임 적어 두고, 일어날 때 여기서부터 섞는다.
var _fallen: Array[Transform3D] = []
var _blend: float = 0.0


## model(리깅 캐릭터) 뼈대에 래그돌을 붙인다. 뼈대나 필요한 뼈가 없으면 null.
## 관절의 "0도"는 만드는 순간의 자세다 → 기본 자세(T자에 가까운 서 있는 자세)로 잠깐 되돌려 놓고 만든 뒤 원래 자세로 돌린다.
## (걷거나 앉은 자세에서 만들면 무릎이 굽은 채가 0도가 되어 한계가 틀어진다.)
static func attach(model: Node3D) -> Node:
	var found := model.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return null
	var rig := found[0] as Skeleton3D
	for piece: Array in PIECES:
		if rig.find_bone(piece[0]) < 0 or rig.find_bone(piece[1]) < 0:
			return null
	var ragdoll: Node = load("res://art/characters/ragdoll.gd").new()
	ragdoll.name = "Ragdoll"
	ragdoll._build(rig)
	return ragdoll


func _build(rig: Skeleton3D) -> void:
	_rig = rig
	var poses: Array[Transform3D] = []
	for bone in range(rig.get_bone_count()):
		poses.append(rig.get_bone_pose(bone))
	rig.reset_bone_poses()
	_simulator = PhysicalBoneSimulator3D.new()
	_simulator.name = "RagdollBodies"
	rig.add_child(_simulator)
	for piece: Array in PIECES:
		var body := _make_piece(piece)
		_simulator.add_child(body)
		_bodies.append(body)
		if str(piece[4]) == "root":
			_hips = body
	# 이 노드는 물리 뒤에 돈다(자식 순서) → 물리가 정한 자세를 읽어 기억할 수 있다.
	rig.add_child(self)
	for bone in range(rig.get_bone_count()):
		rig.set_bone_pose(bone, poses[bone])
	_fallen.resize(rig.get_bone_count())


## 조각 하나: 뼈 가운데에 놓인 캡슐 + 뼈가 시작하는 곳의 관절. 조각의 -Z 가 뼈가 뻗는 방향이다(엔진의 물리 뼈대 만들기와 같은 규칙).
func _make_piece(piece: Array) -> PhysicalBone3D:
	var bone: int = _rig.find_bone(piece[0])
	var bone_rest: Transform3D = _rig.get_bone_global_rest(bone)
	var tail: Vector3 = bone_rest.affine_inverse() * _rig.get_bone_global_rest(_rig.find_bone(piece[1])).origin
	var half: float = tail.length() * 0.5
	var radius: float = piece[2]
	var up := Vector3.UP if absf(tail.normalized().dot(Vector3.UP)) < 0.99 else Vector3.BACK
	var frame := Basis.looking_at(tail, up)
	var body := PhysicalBone3D.new()
	body.name = str(piece[0]).replace(".", "_")
	body.bone_name = piece[0]
	body.body_offset = Transform3D(frame, frame * Vector3(0, 0, -half))
	body.mass = piece[3]
	body.friction = 0.9
	body.bounce = 0.0
	body.linear_damp = LINEAR_DAMP
	body.angular_damp = ANGULAR_DAMP
	body.can_sleep = true
	body.collision_layer = BODY_LAYER
	body.collision_mask = WORLD_MASK
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = maxf(half * 2.0, radius * 2.0 + 0.02)
	shape.shape = capsule
	# 캡슐은 Y 로 길다 → 조각의 Z(뼈 방향)로 눕힌다.
	shape.transform = Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO)
	body.add_child(shape)
	var joint_at := Vector3(0, 0, half)
	match str(piece[4]):
		"cone":
			body.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
			body.joint_offset = Transform3D(CONE_FRAME, joint_at)
			body.set("joint_constraints/swing_span", float(piece[5]))
			body.set("joint_constraints/twist_span", float(piece[6]))
		"hinge":
			body.joint_type = PhysicalBone3D.JOINT_TYPE_HINGE
			# 경첩 축(관절 기준 Z) = 뼈 방향 × 굽는 쪽. 모델 기준으로 구한 축을 조각 기준으로 옮긴다.
			var world_frame: Basis = bone_rest.basis * frame
			var along: Vector3 = (world_frame * Vector3(0, 0, -1)).normalized()
			var axis: Vector3 = along.cross(piece[7] as Vector3).normalized()
			var local_axis: Vector3 = (world_frame.inverse() * axis).normalized()
			var local_x := Vector3(0, 0, -1)
			body.joint_offset = Transform3D(Basis(local_x, local_axis.cross(local_x).normalized(), local_axis), joint_at)
			body.set("joint_constraints/angular_limit_enabled", true)
			# 굽는 쪽이 음수 각도다(물리 시험으로 확인한 엔진 부호 — 2026-11-15 쓰러뜨리기 시험에서 무릎·팔꿈치가 한쪽으로만 굽는 것을 확인).
			body.set("joint_constraints/angular_limit_lower", -float(piece[6]))
			body.set("joint_constraints/angular_limit_upper", float(piece[5]))
	return body


## 쓰러지기 시작. push = 맞은 방향과 세기(m/s) — 온몸이 그 속도로 날아가며 줄이 끊긴다. at = 맞은 자리(가까운 조각이 더 세게 밀린다).
func start(push: Vector3, at: Vector3 = Vector3.INF) -> void:
	_blend = 0.0
	_age = 0.0
	_still = 0.0
	asleep = false
	simulating = true
	active = true
	_simulator.physical_bones_start_simulation()
	for body in _bodies:
		var near: float = 1.0
		if at.is_finite():
			near = clampf(1.6 - body.global_position.distance_to(at), 0.6, 1.5)
		body.linear_velocity = push * near
		# 조금씩 다른 회전을 줘서 나무토막처럼 통째로 넘어가지 않게 한다.
		body.angular_velocity = Vector3(push.z, 0, -push.x) * 0.6 * near
	set_physics_process(true)


## 일어난다: 물리를 끄고, 쓰러진 자세에서 애니메이션 자세로 GET_UP_BLEND 초 동안 섞는다.
func stop() -> void:
	if not simulating:
		return
	simulating = false
	asleep = false
	_simulator.physical_bones_stop_simulation()
	_blend = 1.0
	set_physics_process(false)


## 쓰러진 몸의 가운데(골반) 위치 — 카메라가 따라갈 곳.
func center() -> Vector3:
	return _hips.global_position if _hips != null and simulating else _rig.global_position + Vector3.UP * 0.9


func _ready() -> void:
	set_physics_process(false)


## 다 쓰러졌는지 보고 재운다.
func _physics_process(delta: float) -> void:
	if not simulating or asleep:
		return
	_age += delta
	var moving: bool = false
	for body in _bodies:
		if body.linear_velocity.length() > SETTLE_LINEAR or body.angular_velocity.length() > SETTLE_ANGULAR:
			moving = true
			break
	_still = 0.0 if moving else _still + delta
	if (_age >= SETTLE_MIN_TIME and _still >= SETTLE_HOLD) or _age >= SLEEP_AFTER:
		sleep()


## 조각을 모두 재운다: 속도를 0 으로 하고 물리 서버에 잠들기를 건다(깨우는 힘이 올 때까지 계산하지 않는다).
func sleep() -> void:
	asleep = true
	for body in _bodies:
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		PhysicsServer3D.body_set_state(body.get_rid(), PhysicsServer3D.BODY_STATE_SLEEPING, true)


## 뼈 자세 고치기(매 프레임, 물리 뒤). 쓰러지는 중 = 지금 자세를 기억만 한다. 일어나는 중 = 기억한 자세에서 애니메이션으로 섞는다.
func _process_modification() -> void:
	if _rig == null:
		return
	if simulating:
		for bone in range(_fallen.size()):
			_fallen[bone] = _rig.get_bone_pose(bone)
		return
	if _blend <= 0.0:
		return
	_blend = maxf(0.0, _blend - get_process_delta_time() / GET_UP_BLEND)
	# 끝으로 갈수록 천천히(벌떡 일어나다 멈춘다).
	var weight: float = _blend * _blend * (3.0 - 2.0 * _blend)
	for bone in range(_fallen.size()):
		var target: Transform3D = _rig.get_bone_pose(bone)
		_rig.set_bone_pose(bone, target.interpolate_with(_fallen[bone], weight))
