extends Node3D
## [부품 4] F5 1인칭 3D 다트 손 화면 — 경기 카메라 밑 Camera/Hand 에 붙는다(game.tscn).
## 팔과 손에 든 다트는 따로 떨어진 작은 3D 세계(first_person_hand_view.tscn)에 두고, 그 세계의 카메라를
## **내 눈 자리**(경기 카메라와 같은 자리·같은 시야각)에 둔다. 그래서
##   - 다트 촉이 화면 가운데(과녁)를 향하고, 팔이 벽·다른 선수에 묻히거나 남의 화면에 찍히지 않는다.
##   - 놓는 순간 손에 든 다트 촉 자리를 경기 세계의 같은 화면 자리·같은 깊이로 그대로 옮길 수 있다.
##
## 부품: ① 팔 뼈 맞추기 fp_arm_ik.gd · ② 손가락 모양 first_person_arm.gd(쥔 손/큰 다트/편 손)
##       ③ 몸짓 곡선 fp_throw_motion.gd · ④ 이 파일(손목이 지나갈 자리, 팔꿈치 자리, 다트 겨누기, 화면)
## [2026-11-27] 아스트라의 엄지 쪽 옆 구도(손이 휘어 보임)를 사용자 요청으로 바꿨다.
##
## [움직임] 손목 자리를 네 점 사이에서 섞는다 — 겨누기 · 다 당김(내 쪽) · 다 뻗음(과녁 쪽) · 내림(화면 밖).
## 어깨는 화면 밖 한 점에 고정이라, 손이 어깨에 가까워지면(당김) 팔꿈치가 굽고 멀어지면(뻗음) 펴진다.

const Arm = preload("res://art/characters/first_person_arm.gd")
const ArmIK = preload("res://art/characters/fp_arm_ik.gd")
const Motion = preload("res://art/characters/fp_throw_motion.gd")
const Grip = preload("res://art/characters/approved_dart_grip.gd")
const ARM_VIEW: PackedScene = preload("res://art/characters/first_person_hand_view.tscn")

## [조정값 — 카메라 기준, m] 바꾼 뒤 retune() 을 부르면 바로 반영된다(촬영 도구가 여러 값을 비교할 때 쓴다).
## 팔 모델 배율 = 팔 길이. 만화 비율 모델은 손이 크고 팔이 짧아서, 팔은 이 배율로 두고 손만 Arm.HAND_SCALE(0.52)로 줄인다.
var arm_scale: float = 0.8
## 어깨 관절 자리(화면 밖 오른쪽 아래).
var shoulder := Vector3(0.20, -0.30, -0.06)
## 팔꿈치가 튀어나가는 쪽(아래 · 바깥 · 조금 뒤).
var elbow_pole := Vector3(0.35, -1.0, 0.25)
## 손목 자리: 겨누기 · 다 당김(얼굴 쪽으로 같은 화면 자리를 따라 다가온다) · 다 뻗음(과녁 쪽, 팔이 닿는 만큼) · 내림.
var wrist_aim := Vector3(0.14, -0.15, -0.34)
var wrist_back := Vector3(0.11, -0.11, -0.23)
var wrist_reach := Vector3(0.08, -0.08, -0.62)
var wrist_drop := Vector3(0.26, -0.62, -0.24)
## 손목이 가장 덜 꺾이는 방향에서 다트 축 둘레로 손을 더 돌리는 각(도). −75 = 손등·엄지 쪽이 보이게 집는다.
var roll_offset: float = -75.0
## 놓은 뒤 손목이 앞으로 꺾이는 각(도).
var snap_angle: float = 35.0
## 놓은 뒤 손바닥이 아래를 보게 아래팔을 돌리는 정도(0~1).
var follow_turn: float = 1.0
## 다트가 겨누는 점(카메라 기준) = 화면 가운데의 먼 곳(과녁 거리쯤).
const AIM_POINT := Vector3(0.0, 0.0, -7.0)
## 손에 든 다트의 깃만 줄인다(팀 결정 2026-11-27). 날아가는 다트는 원래 크기.
const HELD_FLIGHT_SCALE: float = 0.6
## 2D 손(DartHand) 경로가 날아가는 다트 출발 깊이로 쓰는 값(game.gd).
const RELEASE_DEPTH: float = 0.55

var arm: Arm
@onready var held: DartView = $HeldDart
var _viewport: SubViewport
var _camera: Camera3D
var _screen: Sprite2D
var _pose: Node3D
var _rig: Skeleton3D
var _chain: ArmIK.Chain
var _upper_length: float
var _fore_length: float
var _large: bool = false
var _last_key: Array = []
## 뼈를 바꾼 프레임에는 스킨이 다음 프레임에야 따라온다 → 바뀐 뒤 몇 프레임 더 그린다.
var _settle: int = 0


## seat = 자리(다트 깃 색) · shirt = 꾸미기 옷 색 번호 · character = 꾸미기 캐릭터 번호(character_looks.gd IDS).
## 처음 한 번 팔 세계·화면을 만들고, 자리·캐릭터가 바뀌면 팔만 새로 만든다(피부·소매·손가락 모양이 캐릭터 메시에서 나온다).
func equip(seat: int, shirt: int, character: int = 0) -> void:
	if _viewport == null:
		_viewport = ARM_VIEW.instantiate() as SubViewport
		add_child(_viewport)
		_pose = _viewport.get_node("Pose")
		_camera = _viewport.get_node("Camera")
		var eye := get_parent() as Camera3D
		if eye != null:
			_camera.fov = eye.fov
		held.reparent(_pose, false)
		for plate: String in ["FlightHorizontal", "FlightVertical"]:
			(held.get_node("Visual/" + plate) as Node3D).scale = Vector3.ONE * HELD_FLIGHT_SCALE
		_screen = Sprite2D.new()
		_screen.centered = false
		_screen.texture = _viewport.get_texture()
		add_child(_screen)
		get_viewport().size_changed.connect(_resize)
		visibility_changed.connect(_sync_visibility)
		_resize()
		_sync_visibility()
	if arm == null or arm.seat != seat or arm.character != character:
		_build_arm(seat, shirt, character)
	arm.set_shirt(shirt)
	held.paint(PlayerLook.COLORS[seat])
	_redraw()


## 꾸미기 방에서 나오거나 방장 "looks" 이벤트로 차림이 바뀌었을 때(game.gd). 옷 색만 바뀌면 소매만 다시 칠한다.
func set_look(shirt: int, character: int) -> void:
	if arm == null: return
	equip(arm.seat, shirt, character)


## 팔(승인 모델 오른팔 + 캐릭터 메시)을 새로 만들어 팔 세계에 놓는다. 예전 팔은 지운다.
func _build_arm(seat: int, shirt: int, character: int) -> void:
	if arm != null:
		_pose.remove_child(arm)
		arm.queue_free()
	arm = Arm.new()
	arm.seat = seat
	arm.shirt = shirt
	arm.character = character
	arm.ik_driven = true
	_pose.add_child(arm)
	_rig = arm.skeleton()
	_chain = null
	if _rig != null:
		_chain = ArmIK.chain(_rig)
		_place_model()
	_last_key = []
	animate(0.0, 0.0, 0.0, 0.0, true, _large, 1.0, Vector2.ZERO)


## 모델을 arm_scale 로 두고 어깨 관절이 shoulder 에 오게 옮긴다.
func _place_model() -> void:
	var model: Node3D = arm.body_model()
	model.transform = Transform3D(Basis.from_scale(Vector3.ONE * arm_scale), Vector3.ZERO)
	_upper_length = _chain.upper_length * arm_scale
	_fore_length = _chain.fore_length * arm_scale
	var joint: Vector3 = _rig.get_bone_global_pose(_chain.upper).origin
	var skeleton_to_model: Transform3D = model.transform.affine_inverse() * _rig.global_transform
	model.position = shoulder - model.transform * (skeleton_to_model * joint)


## 조정값을 바꾼 뒤 부른다.
func retune() -> void:
	if _rig == null: return
	_place_model()
	_last_key = []


func _resize() -> void:
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	var pixels: Vector2 = get_viewport().get_texture().get_size()
	_viewport.size = Vector2i(pixels.ceil()).max(Vector2i.ONE)
	_screen.position = Vector2.ZERO
	_screen.scale = screen_size / Vector2(_viewport.size)
	_redraw()


func _sync_visibility() -> void:
	_screen.visible = is_visible_in_tree()
	if _screen.visible:
		_redraw()
	else:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _redraw() -> void:
	if _screen != null and _screen.visible:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func set_shirt(index: int) -> void:
	if arm == null or arm.shirt == index: return
	arm.set_shirt(index)
	_redraw()


## game.gd _animate_hand 가 매 프레임 부른다. pull = 당긴 정도 · kick = 놓은 뒤 1 → 0 · released = 놓을 때 당긴 정도
## reload = 다음 다트가 있는가 · large = 크기 카드 · motion = 움직임 크기 · tremble = 다 당겼을 때 떨림(화면 이동)
func animate(_delta: float, pull: float, kick: float, released: float, reload: bool,
		large: bool, motion: float, tremble: Vector2) -> void:
	if _rig == null or _chain == null or not _chain.valid():
		return
	var p := Motion.at(pull, kick, released, reload, motion)
	# 다 당긴 손의 미세 떨림은 화면 이동만 바꾼다(정지한 팔을 다시 그리지 않는다).
	_screen.position = tremble * get_viewport().get_visible_rect().size.y / 923.0
	var key: Array = [p.back, p.reach, p.drop, p.snap, p.open, p.aim, p.holding, large]
	if key == _last_key:
		if _settle > 0:
			_settle -= 1
			_redraw()
		return
	_last_key = key
	_settle = 2
	_large = large
	_pose_arm(p)
	arm.set_fingers(p.open, large)
	held.visible = p.holding
	_redraw()


## 손목이 지금 있을 자리.
func _wrist_at(p: Motion.Pose) -> Vector3:
	var wrist: Vector3 = wrist_aim + (wrist_back - wrist_aim) * p.back + (wrist_reach - wrist_aim) * p.reach
	return wrist.lerp(wrist_drop, p.drop)


## 두 마디 팔: 어깨·손목 자리와 팔꿈치가 튀어나가는 쪽으로 팔꿈치 자리를 구한다.
## 돌려주는 값 = [팔꿈치, 손목(팔이 닿지 않으면 닿는 데까지 당긴 자리), 팔꿈치를 굽히는 축]
func _solve_elbow(target: Vector3) -> Array[Vector3]:
	var to_wrist: Vector3 = target - shoulder
	var along: Vector3 = to_wrist.normalized()
	var reach: float = clampf(to_wrist.length(), absf(_upper_length - _fore_length) + 0.002, (_upper_length + _fore_length) * 0.995)
	var wrist: Vector3 = shoulder + along * reach
	var a: float = (_upper_length * _upper_length - _fore_length * _fore_length + reach * reach) / (2.0 * reach)
	var h: float = sqrt(maxf(0.0, _upper_length * _upper_length - a * a))
	var side: Vector3 = elbow_pole - along * elbow_pole.dot(along)
	if side.length() < 0.0001:
		side = Vector3.DOWN - along * along.y
	side = side.normalized()
	return [shoulder + along * a + side * h, wrist, side.cross(along).normalized()]


func _pose_arm(p: Motion.Pose) -> void:
	var solved: Array[Vector3] = _solve_elbow(_wrist_at(p))
	var elbow: Vector3 = solved[0]
	var wrist: Vector3 = solved[1]
	var toward_elbow: Vector3 = (elbow - wrist).normalized()
	var barrel: Transform3D = Grip.barrel(_large)
	var aimed: Basis = _aimed_hand(wrist, toward_elbow, barrel)
	var hand: Basis = aimed
	if p.aim < 1.0:
		var follow: Basis = _follow_hand(aimed, toward_elbow, p.snap)
		hand = Basis(aimed.get_rotation_quaternion().slerp(follow.get_rotation_quaternion(), 1.0 - p.aim))
	var to_skeleton: Transform3D = _rig.global_transform.affine_inverse()
	ArmIK.pose(_rig, _chain, to_skeleton * elbow, to_skeleton * wrist, (to_skeleton.basis * solved[2]).normalized(),
		to_skeleton.basis.orthonormalized() * hand, Arm.HAND_SCALE / arm_scale)
	# 손에 든 다트: 손 뼈 × 쥐는 자리(approved_dart_grip.barrel) — 3인칭 손과 같은 약속.
	var grip := Transform3D(hand * barrel.basis, wrist + hand * (barrel.origin * Arm.HAND_SCALE))
	var dart: Transform3D = grip * Transform3D(Basis.IDENTITY, -Arm.GRIP_PIVOT)
	held.transform = Arm.held_dart(dart, DartView.LARGE_SIZE if _large else 1.0)


## 다트 깃 쪽 축이 AIM_POINT 반대를 보고(촉이 과녁을 겨눔), 그 축 둘레로는 손목이 덜 꺾이는 쪽 + roll_offset 만큼 돌린 손 방향.
func _aimed_hand(wrist: Vector3, toward_elbow: Vector3, barrel: Transform3D) -> Basis:
	var elbow_in_hand: Vector3 = Grip.ELBOW_DIRECTION.normalized()
	var hand := Basis.IDENTITY
	var center: Vector3 = wrist
	for _i in range(3):
		var back: Vector3 = (center - AIM_POINT).normalized()
		var turn := Basis(ArmIK.arc(barrel.basis.z.normalized(), back))
		var roll: float = ArmIK.twist_to(turn * elbow_in_hand, toward_elbow, back)
		hand = Basis(back, roll + deg_to_rad(roll_offset)) * turn
		center = wrist + hand * (barrel.origin * Arm.HAND_SCALE)
	return hand


## 놓은 뒤: 손목을 아래팔과 나란히 펴고, 손바닥이 아래를 보게 아래팔을 돌리고, snap 만큼 앞으로 꺾는다.
func _follow_hand(aimed: Basis, toward_elbow: Vector3, snap: float) -> Basis:
	var straight := Basis(ArmIK.arc((aimed * Grip.ELBOW_DIRECTION).normalized(), toward_elbow)) * aimed
	var palm: Vector3 = straight * Grip.PALM.z
	var turn: float = ArmIK.twist_to(palm, Vector3(-0.3, -1.0, 0.0), toward_elbow) * follow_turn
	straight = Basis(toward_elbow, turn) * straight
	var across: Vector3 = (straight * Grip.PALM.x).normalized()
	return Basis(across, deg_to_rad(snap_angle) * snap) * straight


## 놓는 순간: 손에 든 다트 촉을 경기 세계 좌표로 돌려주고 손에서 숨긴다.
## 팔 카메라와 경기 카메라는 같은 자리·같은 시야각이라 화면 자리와 깊이를 그대로 옮기면 같은 점이다.
func release_start(camera: Camera3D) -> Vector3:
	var tip: Vector3 = held.global_position
	var screen: Vector2 = _camera.unproject_position(tip) * _screen.scale + _screen.position
	var world_tip: Vector3 = camera.project_position(screen, maxf(-tip.z, camera.near * 2.0))
	held.hide()
	_redraw()
	return world_tip
