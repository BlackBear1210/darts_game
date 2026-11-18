extends Node3D
## 1인칭 오른팔(투척 화면). 카메라 자식 Camera/Hand 아래에 붙는다 — 이 노드의 원점 = 손에 쥔 다트 촉.
## class_name 을 새로 만들지 않고 preload 로 부른다(열린 편집기가 새 class_name 을 못 읽어 파스 오류가 나는 함정 — table.gd 참고).
##
## [왜 바꿨나] 2026-11-09 사용자 지적 "게임 시점에서 플레이어 팔이 아직 예전 프로토타입으로 보인다".
## 몸·NPC·바텐더는 2026-11-06·11-08 에 리깅 캐릭터로 바뀌었는데 1인칭 손만 옛 도형 모델
## (character_factory.create_hand — 구 + 막대로 만든 벙어리장갑과 소매)로 남아 있었다.
## 이제 선수 몸과 **같은 리깅 캐릭터**(art/characters/rigged/player_character.tscn)의 오른팔을 그대로 쓴다
## → 3인칭으로 보이는 내 팔과 1인칭 내 팔의 소매·피부·손 모양이 같다.
##
## [어떻게 팔만 보이나]
## 캐릭터는 스킨드 메시 9조각이고 조각마다 매달린 뼈가 다르다(2026-11-09 측정):
##   part_0 몸통 + 양쪽 위팔 + 오른 아래팔 · part_1 다리 · part_2·3 머리·목 · part_4 **오른손**
##   part_5 오른발 · part_6 왼팔 · part_7 왼손 · part_8 왼발
## 오른팔에 필요한 것은 part_0 과 part_4 뿐이라 나머지는 끈다(ARM_PARTS 외 전부).
## part_0 의 몸통·왼팔은 오른팔 뼈의 가중치로 삼각형을 걸러 1인칭 복사본에서만 뺀다.
## 카메라 뒤로 숨기는 방식은 가리키는 자세에서 몸통이 화면을 덮어 쓸 수 없다.
##
## [자세] Dart_Throw 모션의 겨누기 시각(CharacterMotion.AIM_TIME)에서 한 장면만 꺼내 고정한다.
## 당기기·던지기·팔로 스루 몸짓은 art/characters/first_person_throw.gd 의 곡선으로 GameView._animate_hand 가
## 이 노드의 부모(Camera/Hand)를 움직여 만든다. 팔꿈치를 축으로 돌도록 팔꿈치 위치(elbow)를 여기서 알려 준다.
## 손가락은 이 노드가 맡는다: 쥘 때 = 다트 그립(GRIP_BEND), 놓은 뒤 = 거의 편 손(RELEASE_BEND).

## 1인칭에 남기는 메시 조각(위 주석의 측정 결과). 목록에 없는 조각은 전부 끈다 —
## 모델을 다시 구워 조각이 늘어나도 얼굴·다리가 화면에 튀어나오지 않는다.
const ARM_PARTS: Array[String] = ["tripo_part_0", "tripo_part_4"]
## 손에 쥔 다트 위치를 맞출 소켓(GLB 에 들어 있는 BoneAttachment 자식). 없으면 hand.R 뼈로 맞춘다.
const DART_SOCKET := "Socket_Dart_R"
const HAND_BONE := "hand.R"
## 다트 자루(barrel)를 쥐는 지점. 다트는 원점이 촉이고 몸통이 +Z 로 뻗는다(game/dart/dart.tscn 실측):
## 촉 0~0.02 · **자루 0.02~0.07** · 대 0.07~0.14 · 깃 0.10~0.17. 엄지·검지 끝 사이에 자루를 맞춘다.
const GRIP_ALONG_SHAFT: float = 0.045
## 손에 든 다트를 키울 때(크기 카드)의 축 = 자루 가운데. 촉 끝을 축으로 키우면 자루가 손에서 빠져나가고
## 굵어진 몸통이 손가락을 뚫는다(2026-11-17 밤 사용자 지적 "손이 다트를 통과한다").
const GRIP_PIVOT := Vector3(0, 0, GRIP_ALONG_SHAFT)
## 손을 다트 축 둘레로 돌리는 각.
## 225° = 몸 안쪽에서 보면 다트가 말린 손가락 위에 얹히고 엄지가 받친다(사용자 참고 그림 4번째 칸과 같은 모양).
## 내 화면에서는 손등·엄지 쪽이 보이고 아래팔이 화면 아래로 내려간다.
## 2026-11-17 밤 스크래치 각도표(0~330° 30° 간격, 150~255° 15° 간격)를 카메라·옆에서 찍어 골랐다.
## 180° 는 내 화면이 깔끔하지만 손바닥이 얼굴을 봐서(쟁반 든 손) 실제 투척 자세가 아니다.
const GRIP_ROLL: float = PI * 1.25
## 1인칭에서만 팔꿈치를 펴는 각(도). 1인칭 팔은 HAND_SCALE 로 줄여 아래팔이 약 12cm 라
## 겨누기 모션의 90° 팔꿈치가 화면 안에서 꺾여 위팔까지 보였다 → 펴서 위팔이 아래팔을 따라 화면 밖으로 빠지게 한다.
## 손·다트 자리는 그대로다(쥔 자리에 맞춰 모델을 옮기므로 팔꿈치 각은 위팔 방향만 바꾼다).
const ELBOW_OPEN: float = 90.0

## [다트 쥐는 손가락 — 2026-11-17 밤, 사용자 참고 그림(손가락 위에 다트를 가로로 얹고 → 엄지로 누르고 → 손가락을 말아 쥔다)]
## 엄지 끝마디 배와 검지 끝마디 배가 자루를 양쪽에서 집는다. 중지는 검지 옆에서 같이 말리고
## 약지·새끼는 더 말아 자루 아래로 접는다. 옆에서 보면 다트가 말린 손가락 위에 얹혀 촉은 앞, 깃은 엄지 뒤로 나온다.
## 값 = 펴진 손(쉬는 자세)에서 굽히는 각도(도). 굽히는 축은 리깅 모션이 그 손가락을 굽히는 축을 그대로 쓴다.
## 고른 방법(스크래치 측정 도구): 손 살(스킨드 정점 + 삼각형 표본)을 다트 좌표로 옮겨 자루 안에 들어간 깊이를 쟀다.
##   이 각도에서 자루에 닿는 살 = 엄지 끝마디 · 검지 끝마디, 살을 뚫는 곳 0, 자루 표면까지 가장 가까운 살 0.66mm.
##   엄지를 1~2° 더 굽히면 자루가 엄지를 뚫고(thumb 8° → 3.4mm), 덜 굽히면 자루가 손에서 뜬다.
##   예전 값(펜 쥐기, 검지 30/50/20 · 엄지 20/15/10)은 자루가 손가락에 2.9mm 묻혀 있었다.
## 바꿀 때는 tests/render_fp_arm.gd 로 찍어 손이 다트를 뚫는지 꼭 본다.
## (숫자로 재던 확인용 시험 test_fp_grip.gd 는 2026-11-18 사용자 요청으로 지웠다 — 커밋 445f67d 에서 꺼내 쓸 수 있다.)
const GRIP_BEND: Dictionary = {
	"thumb_01.R": 7.0, "thumb_02.R": 7.0, "thumb_03.R": 7.0,
	"index_01.R": 50.0, "index_02.R": 60.0, "index_03.R": 20.0,
	"middle_01.R": 50.0, "middle_02.R": 60.0, "middle_03.R": 20.0,
	"ring_01.R": 60.0, "ring_02.R": 80.0, "ring_03.R": 40.0,
	"pinky_01.R": 60.0, "pinky_02.R": 80.0, "pinky_03.R": 40.0,
}
## 손가락 끝마디에서 "배"(자루가 닿는 자리) 비율. 0 = 셋째 마디 머리, 1 = 손가락 끝.
const PAD_ALONG: float = 0.6
## 집는 자리 보정(모델 단위, _pinch_frame 축 기준): 엄지·검지·중지 끝 배 가운데 → 자루 중심.
## 위 측정 도구가 자루 축에 수직인 면에서 살과 가장 멀리 떨어진 빈 곳을 찾은 값이다(GRIP_BEND 를 바꾸면 다시 잰다).
const PINCH_NUDGE := Vector3(-0.0394, 0.0007, 0.0)
## 크기 카드(DartView.LARGE_SIZE)로 굵어진 자루를 손에서 비켜 놓는 거리(같은 축, 모델 단위 ≈ 5mm).
## 손 모양과 크기는 그대로 두고 다트만 커진다. 굵은 자루가 살을 뚫지 않는 가장 가까운 자리(측정 도구).
const LARGE_NUDGE := Vector3(-0.0100, 0.0010, 0.0)
## 놓은 뒤(팔로 스루) 손가락은 과녁 쪽으로 쭉 펴진다. 쥔 각도에 이 비율만 남긴다.
const RELEASE_BEND: float = 0.12
## 1인칭 팔 크기. 캐릭터는 만화 비율이라 주먹 폭이 약 0.15m 로, 길이 0.17m 짜리 다트를 통째로 삼킨다
## → 1인칭 뷰모델 관례대로 줄여 다트와 비율을 맞춘다(3인칭 몸은 그대로다).
const HAND_SCALE: float = 0.52
## 모든 1인칭 손이 같은 원본을 쓰므로 오른팔 메시를 한 번만 만든다.
static var _right_arm_mesh: ArrayMesh

var seat: int = 0
## 꾸미기 옷 색 번호(art/characters/player_outfit.gd SHIRT_COLORS). 0 = 원래 그림 색. 소매가 3인칭 내 몸과 같은 색이 된다.
var shirt: int = 0
const PlayerOutfit = preload("res://art/characters/player_outfit.gd")
## 카드 시연의 가리키는 손도 같은 메시를 쓰되 Point_R 자세를 고정한다.
var pointing: bool = false
## 손이 맞출 다트의 자세(이 노드 기준). 비워 두면 이 노드 축에 그대로 맞춘다.
## 다트 회전은 씬(game/game.tscn 의 HeldDart)이 갖고 있으므로 숫자를 여기 베껴 적지 않고 받아 쓴다.
var dart_grip: Transform3D = Transform3D.IDENTITY
## 팔꿈치 위치(부모 Camera/Hand 기준). 던지기 몸짓이 이 점을 축으로 아래팔을 접고 편다(first_person_throw.gd).
var elbow: Vector3 = Vector3.ZERO
var _rig: Skeleton3D
var _fingers: Array[int] = []
var _closed: Array[Quaternion] = []
var _open: Array[Quaternion] = []
var _opening: float = 0.0
## 던진 뒤 휘두르는 뼈(아래팔·손목)와 각 뼈의 부모 기준 "화면 가로축", 겨누기 자세 회전.
var _swing_bones: Array[int] = []
var _swing_axes: Array[Vector3] = []
var _swing_aim: Array[Quaternion] = []
## 보통 다트 / 큰 다트를 쥘 때 모델 자리(hold_large 가 고른다).
var _model: Node3D
var _hold_normal: Transform3D = Transform3D.IDENTITY
var _hold_large: Transform3D = Transform3D.IDENTITY


## 손에 든 다트의 자세(Camera/Hand 기준). size = 겉모습 배율(크기 카드면 DartView.LARGE_SIZE).
## 자루 가운데(GRIP_PIVOT)를 축으로 키운다 — 쥔 자리는 그대로고 다트만 커진다.
static func held_dart(base: Transform3D, size: float) -> Transform3D:
	return base * Transform3D(Basis.from_scale(Vector3.ONE * size), GRIP_PIVOT * (1.0 - size))


## 큰 다트(크기 카드)를 쥐면 손을 굵어진 자루 바깥으로 살짝 비켜 둔다. 손 크기는 바꾸지 않는다.
func hold_large(large: bool) -> void:
	if pointing or not is_instance_valid(_model): return
	_model.transform = _hold_large if large else _hold_normal


func _ready() -> void:
	var model: Node3D = PlayerLook.character(seat)
	model.name = "Model"
	add_child(model)
	var skeletons: Array[Node] = model.find_children("*", "Skeleton3D", true, false)
	var players: Array[Node] = model.find_children("*", "AnimationPlayer", true, false)
	if skeletons.is_empty() or players.is_empty():
		push_warning("1인칭 팔: 리깅 캐릭터에 Skeleton3D/AnimationPlayer 가 없습니다.")
		return
	var rig := skeletons[0] as Skeleton3D
	_pose_hand(players[0] as AnimationPlayer)
	_show_arm_only(model)
	PlayerOutfit.tint_shirt(model, shirt)
	# 손가락을 먼저 다트 그립으로 굽힌 뒤 쥔 자리를 잰다(주먹 자세로 재면 자루가 손 속에 묻힌다).
	if not pointing:
		_open_elbow(rig)
		_prepare_fingers(rig)
		animate_grip(false, 0.0)
	_grip_at_origin(model, rig)
	if not pointing:
		_prepare_swing(model, rig)


## 손가락을 GRIP_BEND 각도로 굽힌 자세(쥠)와 거의 편 자세(놓음)를 만든다.
func _prepare_fingers(rig: Skeleton3D) -> void:
	_rig = rig
	for bone_name: String in GRIP_BEND:
		var bone: int = rig.find_bone(bone_name)
		if bone < 0: continue
		var rest: Quaternion = rig.get_bone_rest(bone).basis.get_rotation_quaternion()
		# 굽히는 축 = 모션(주먹)이 쉬는 자세에서 굽힌 축. 손가락마다 축이 조금씩 달라 직접 읽는다.
		var bend: Quaternion = rest.inverse() * rig.get_bone_pose_rotation(bone)
		if bend.w < 0.0: bend = -bend
		var axis: Vector3 = bend.get_axis().normalized() if bend.get_angle() > 0.01 else Vector3.RIGHT
		var angle: float = deg_to_rad(float(GRIP_BEND[bone_name]))
		_fingers.append(bone)
		_closed.append(rest * Quaternion(axis, angle))
		_open.append(rest * Quaternion(axis, angle * RELEASE_BEND))


## 팔꿈치를 ELBOW_OPEN 만큼 편다: 아래팔 뼈를 위팔 쪽으로 (위팔 × 아래팔) 축 둘레로 되돌린다.
func _open_elbow(rig: Skeleton3D) -> void:
	var upper: int = rig.find_bone("upper_arm.R")
	var fore: int = rig.find_bone("forearm.R")
	var hand: int = rig.find_bone(HAND_BONE)
	if upper < 0 or fore < 0 or hand < 0: return
	var shoulder: Vector3 = rig.get_bone_global_pose(upper).origin
	var joint: Vector3 = rig.get_bone_global_pose(fore).origin
	var wrist: Vector3 = rig.get_bone_global_pose(hand).origin
	var bend_axis: Vector3 = (joint - shoulder).cross(wrist - joint)
	if bend_axis.length() < 0.000001: return
	var parent_turn: Quaternion = rig.get_bone_global_pose(upper).basis.get_rotation_quaternion()
	var axis: Vector3 = (parent_turn.inverse() * bend_axis.normalized()).normalized()
	rig.set_bone_pose_rotation(fore, Quaternion(axis, -deg_to_rad(ELBOW_OPEN)) * rig.get_bone_pose_rotation(fore))


## 판정과 별개인 손가락 연출. 놓으면 손이 펴지고 다음 다트를 들 때 다시 쥔다.
func animate_grip(releasing: bool, delta: float) -> void:
	if not is_instance_valid(_rig): return
	_opening = move_toward(_opening, 1.0 if releasing else 0.0, delta * 12.0)
	for index in range(_fingers.size()):
		_rig.set_bone_pose_rotation(_fingers[index], _closed[index].slerp(_open[index], _opening))


## 던진 뒤 몸짓: 아래팔과 손목 뼈를 화면 가로축(Camera/Hand 의 X) 둘레로 돌린다(first_person_throw.gd 가 각을 준다).
## forearm < 0 = 아래팔이 팔꿈치를 축으로 과녁 쪽으로 펴진다 · wrist < 0 = 손목이 앞으로 꺾여 손가락이 과녁을 가리킨다.
## 위팔은 그대로라 소매가 화면에 들어오지 않는다. 다트를 쥔 동안엔 0 으로 둔다(쥔 자리가 어긋난다).
func swing(forearm: float, wrist_angle: float) -> void:
	if not is_instance_valid(_rig): return
	for index in range(_swing_bones.size()):
		var angle: float = forearm if index == 0 else wrist_angle
		_rig.set_bone_pose_rotation(_swing_bones[index], Quaternion(_swing_axes[index], angle) * _swing_aim[index])


## 화면 가로축을 각 뼈의 부모 기준으로 바꿔 둔다. 아래팔이 그 축으로 돌아도 축은 그대로라
## 손목 뼈의 축도 겨누기 자세에서 한 번만 재면 된다.
func _prepare_swing(model: Node3D, rig: Skeleton3D) -> void:
	var to_hand: Basis = (transform * model.transform * _relative(model, rig)).basis
	var axis: Vector3 = (to_hand.inverse() * Vector3.RIGHT).normalized()
	for bone_name: String in ["forearm.R", HAND_BONE]:
		var bone: int = rig.find_bone(bone_name)
		if bone < 0: continue
		var parent_turn: Quaternion = rig.get_bone_global_pose(rig.get_bone_parent(bone)).basis.get_rotation_quaternion()
		_swing_bones.append(bone)
		_swing_axes.append((parent_turn.inverse() * axis).normalized())
		_swing_aim.append(rig.get_bone_pose_rotation(bone))


## 선택한 손 자세로 뼈를 세우고 재생을 멈춘다.
func _pose_hand(player: AnimationPlayer) -> void:
	var motion: String = CharacterMotion.POINT if pointing else CharacterMotion.THROW
	if not player.has_animation(motion):
		return
	player.play(motion)
	player.seek(0.0 if pointing else CharacterMotion.AIM_TIME, true)
	player.pause()
	# seek 만으로는 다음 프레임에야 뼈에 반영된다. 지금 자세를 읽어 쓰려면 한 번 밀어 준다.
	player.advance(0.0)


## 오른팔 조각만 남기고 끈다. 1인칭이라 그림자도 끈다(내 팔 그림자가 바닥에 따라다니면 어색하다).
func _show_arm_only(model: Node3D) -> void:
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.visible = ARM_PARTS.has(mesh.name)
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mesh.name == "tripo_part_0":
			if _right_arm_mesh == null:
				_right_arm_mesh = _extract_right_arm(mesh)
			mesh.mesh = _right_arm_mesh


## 원본의 정점·UV·스킨은 유지하고 오른팔에 속한 면만 그린다. 3인칭 공유 리소스는 수정하지 않는다.
func _extract_right_arm(instance: MeshInstance3D) -> ArrayMesh:
	var result := ArrayMesh.new()
	var arm_binds: Array[int] = []
	for bind in range(instance.skin.get_bind_count()):
		var bone_name: String = str(instance.skin.get_bind_name(bind))
		if bone_name in ["upper_arm.R", "forearm.R", "hand.R"]:
			arm_binds.append(bind)
	for surface in range(instance.mesh.get_surface_count()):
		var arrays: Array = instance.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var influences: int = bones.size() / vertices.size()
		var on_arm: Array[bool] = []
		for vertex in range(vertices.size()):
			var arm_weight: float = 0.0
			for influence in range(influences):
				var offset: int = vertex * influences + influence
				if bones[offset] in arm_binds:
					arm_weight += weights[offset]
			on_arm.append(arm_weight > 0.5)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var kept := PackedInt32Array()
		for triangle in range(0, indices.size(), 3):
			if on_arm[indices[triangle]] and on_arm[indices[triangle + 1]] and on_arm[indices[triangle + 2]]:
				kept.append(indices[triangle])
				kept.append(indices[triangle + 1])
				kept.append(indices[triangle + 2])
		if kept.is_empty():
			continue
		arrays[Mesh.ARRAY_INDEX] = kept
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		result.surface_set_material(result.get_surface_count() - 1, instance.mesh.surface_get_material(surface))
	return result


## 다트를 쥐는 자리가 이 노드의 원점에 오도록 모델 전체를 옮긴다.
## 투척·가리키기 모두 같은 손 크기를 유지한다.
func _grip_at_origin(model: Node3D, rig: Skeleton3D) -> void:
	var grip: Transform3D = _grip_transform(model, rig)
	# 다트 방향만 받는다(크기는 뺀다). 크기 카드로 커진 다트의 자세를 넘겨받아도 손이 같이 커지지 않는다
	# (2026-11-17 밤 사용자 지적 "다트 크기 카드를 쓰면 손 크기도 같이 커진다").
	var held: Transform3D = dart_grip.orthonormalized()
	# 다트와 같은 방향으로 자루를 잡는다: 다트 자세를 그대로 쓰고 축을 따라 자루 쪽으로 물러난다.
	var target: Transform3D = held if pointing else held.rotated_local(Vector3.BACK, GRIP_ROLL).translated_local(GRIP_PIVOT)
	# 크기는 쥔 자리를 축으로 줄인다 — 손은 작아져도 다트를 쥔 지점은 그대로다.
	target.basis = target.basis.scaled(Vector3.ONE * HAND_SCALE)
	model.transform = target * grip.affine_inverse()
	_model = model
	_hold_normal = model.transform
	# 큰 다트: 자루 중심이 집는 자리 축으로 LARGE_NUDGE 만큼 옮겨진 것과 같다 → 손을 그 반대로 옮긴다.
	_hold_large = _hold_normal.translated(-(target.basis * LARGE_NUDGE))
	var elbow_bone: int = rig.find_bone("forearm.R")
	if elbow_bone >= 0:
		elbow = transform * (model.transform * _relative(model, rig) * rig.get_bone_global_pose(elbow_bone).origin)


## 모델 기준 다트 그립 좌표(손 뼈 + 소켓 오프셋).
## BoneAttachment3D(hand_R)의 global_transform 은 다음 프레임에야 따라오므로 뼈 자세에서 직접 만든다 —
## 그걸 그냥 읽으면 쉬는 자세 그대로라 팔이 엉뚱한 곳에 붙는다(2026-11-09에 실제로 겪었다).
func _grip_transform(model: Node3D, rig: Skeleton3D) -> Transform3D:
	var bone: int = rig.find_bone(HAND_BONE)
	if bone < 0:
		return Transform3D.IDENTITY
	var grip: Transform3D = rig.get_bone_global_pose(bone)
	var socket := model.find_child(DART_SOCKET, true, false) as Node3D
	if socket != null:
		grip = grip * socket.transform
	if not pointing:
		var pinch: Variant = _pinch_frame(rig)
		if pinch != null:
			grip = pinch
	if pointing:
		# 다트 소켓은 쥐는 자세 기준이다. 가리킬 때는 실제 검지 방향을 화면 앞으로 맞춘다.
		var base: int = rig.find_bone("index_01.R")
		var tip: int = rig.find_bone("index_03.R")
		if base >= 0 and tip >= 0:
			var forward: Vector3 = (rig.get_bone_global_pose(tip).origin - rig.get_bone_global_pose(base).origin).normalized()
			var right: Vector3 = forward.cross(grip.basis.y).normalized()
			grip.basis = Basis(right, right.cross(forward).normalized(), -forward)
	return _relative(model, rig) * grip


## 집는 자리(rig 좌표). 다트 좌표계와 같은 약속이다: 원점 = 자루 중심, +Z = 깃 쪽(뒤).
## X = 엄지 끝 배 → 검지·중지 끝 배, Z = 중지 → 검지(촉은 새끼 쪽 = 그림처럼 손가락을 가로지른다).
## 원점 = 세 배의 가운데 + PINCH_NUDGE(살을 뚫지 않고 엄지·검지 끝마디에 닿는 자리, 측정값).
## 뼈가 없는 모델이면 null.
func _pinch_frame(rig: Skeleton3D) -> Variant:
	var pads: Array[Vector3] = []
	for finger: String in ["Thumb", "Index", "Middle"]:
		var joint: int = rig.find_bone(finger.to_lower() + "_03.R")
		var tip: int = rig.find_bone("extra_RightHand" + finger + "4")
		if joint < 0 or tip < 0:
			return null
		pads.append(rig.get_bone_global_pose(joint).origin.lerp(rig.get_bone_global_pose(tip).origin, PAD_ALONG))
	var fingers: Vector3 = (pads[1] + pads[2]) * 0.5
	var across: Vector3 = (fingers - pads[0]).normalized()
	var back: Vector3 = pads[1] - pads[2]
	back = (back - across * back.dot(across)).normalized()
	var basis := Basis(across, back.cross(across).normalized(), back)
	return Transform3D(basis, (pads[0] + fingers) * 0.5 + basis * PINCH_NUDGE)


## rig 좌표 → model 좌표 변환(스켈레톤이 모델 아래 몇 단계에 있든 부모를 따라 곱한다).
func _relative(model: Node3D, rig: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var node: Node = rig
	while node != null and node != model:
		if node is Node3D:
			result = (node as Node3D).transform * result
		node = node.get_parent()
	return result
