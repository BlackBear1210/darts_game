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
## 충전할 때 뒤로 빠지고 놓을 때 튕기는 연출은 예전처럼 GameView._animate_hand 가 이 노드의 부모를 움직여 만든다
## → 손맛 코드는 그대로 두고 보이는 모양만 바뀐다.

## 1인칭에 남기는 메시 조각(위 주석의 측정 결과). 목록에 없는 조각은 전부 끈다 —
## 모델을 다시 구워 조각이 늘어나도 얼굴·다리가 화면에 튀어나오지 않는다.
const ARM_PARTS: Array[String] = ["tripo_part_0", "tripo_part_4"]
## 손에 쥔 다트 위치를 맞출 소켓(GLB 에 들어 있는 BoneAttachment 자식). 없으면 hand.R 뼈로 맞춘다.
const DART_SOCKET := "Socket_Dart_R"
const HAND_BONE := "hand.R"
## 다트 자루(barrel)를 쥐는 지점. 다트는 원점이 촉이고 몸통이 +Z 로 뻗는다(game/dart/dart.tscn 실측):
## 촉 0~0.02 · **자루 0.02~0.07** · 대 0.07~0.14 · 깃 0.10~0.17. 엄지·검지 끝 사이에 자루를 맞춘다.
const GRIP_ALONG_SHAFT: float = 0.045
## 손바닥 대신 엄지·검지 사이의 쥔 부분이 보이도록 다트 축 둘레로 손목을 돌린다.
const GRIP_ROLL: float = PI / 9.0
## 1인칭 팔 크기. 캐릭터는 만화 비율이라 주먹 폭이 약 0.15m 로, 길이 0.17m 짜리 다트를 통째로 삼킨다
## → 1인칭 뷰모델 관례대로 줄여 다트와 비율을 맞춘다(3인칭 몸은 그대로다).
const HAND_SCALE: float = 0.52
## 모든 1인칭 손이 같은 원본을 쓰므로 오른팔 메시를 한 번만 만든다.
static var _right_arm_mesh: ArrayMesh

var seat: int = 0
## 카드 시연의 가리키는 손도 같은 메시를 쓰되 Point_R 자세를 고정한다.
var pointing: bool = false
## 손이 맞출 다트의 자세(이 노드 기준). 비워 두면 이 노드 축에 그대로 맞춘다.
## 다트 회전은 씬(game/game.tscn 의 HeldDart)이 갖고 있으므로 숫자를 여기 베껴 적지 않고 받아 쓴다.
var dart_grip: Transform3D = Transform3D.IDENTITY
var _rig: Skeleton3D
var _fingers: Array[int] = []
var _closed: Array[Quaternion] = []
var _open: Array[Quaternion] = []
var _opening: float = 0.0


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
	_grip_at_origin(model, rig)
	if not pointing:
		_prepare_fingers(rig)
		animate_grip(false, 0.0)


## 엄지·검지는 자루를 잡고, 나머지 세 손가락은 덜 말아 쥐는 자세로 둔다.
func _prepare_fingers(rig: Skeleton3D) -> void:
	_rig = rig
	for bone_name: String in CharacterMotion.RIGHT_ARM:
		if not (bone_name.begins_with("thumb_") or bone_name.begins_with("index_") or bone_name.begins_with("middle_") or bone_name.begins_with("ring_") or bone_name.begins_with("pinky_")):
			continue
		var bone: int = rig.find_bone(bone_name)
		if bone < 0: continue
		var rest: Quaternion = rig.get_bone_rest(bone).basis.get_rotation_quaternion()
		var closed: Quaternion = rig.get_bone_pose_rotation(bone)
		if not bone_name.begins_with("thumb_") and not bone_name.begins_with("index_"):
			closed = closed.slerp(rest, 0.4)
		_fingers.append(bone)
		_closed.append(closed)
		_open.append(rest)


## 판정과 별개인 손가락 연출. 놓으면 손이 펴지고 다음 다트를 들 때 다시 쥔다.
func animate_grip(releasing: bool, delta: float) -> void:
	if not is_instance_valid(_rig): return
	_opening = move_toward(_opening, 1.0 if releasing else 0.0, delta * 12.0)
	for index in range(_fingers.size()):
		_rig.set_bone_pose_rotation(_fingers[index], _closed[index].slerp(_open[index], _opening))


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
	# 다트와 같은 방향으로 자루를 잡는다: 다트 자세를 그대로 쓰고 축을 따라 자루 쪽으로 물러난다.
	var target: Transform3D = dart_grip if pointing else dart_grip.rotated_local(Vector3.BACK, GRIP_ROLL).translated_local(Vector3(0, 0, GRIP_ALONG_SHAFT))
	# 크기는 쥔 자리를 축으로 줄인다 — 손은 작아져도 다트를 쥔 지점은 그대로다.
	target.basis = target.basis.scaled(Vector3.ONE * HAND_SCALE)
	model.transform = target * grip.affine_inverse()


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
		# 소켓 방향은 유지하되 손바닥 중심 대신 실제 엄지·검지 끝 사이를 쥐는 원점으로 쓴다.
		var index_tip: int = rig.find_bone("extra_RightHandIndex4")
		var thumb_tip: int = rig.find_bone("extra_RightHandThumb4")
		if index_tip >= 0 and thumb_tip >= 0:
			grip.origin = (rig.get_bone_global_pose(index_tip).origin + rig.get_bone_global_pose(thumb_tip).origin) * 0.5
	if pointing:
		# 다트 소켓은 쥐는 자세 기준이다. 가리킬 때는 실제 검지 방향을 화면 앞으로 맞춘다.
		var base: int = rig.find_bone("index_01.R")
		var tip: int = rig.find_bone("index_03.R")
		if base >= 0 and tip >= 0:
			var forward: Vector3 = (rig.get_bone_global_pose(tip).origin - rig.get_bone_global_pose(base).origin).normalized()
			var right: Vector3 = forward.cross(grip.basis.y).normalized()
			grip.basis = Basis(right, right.cross(forward).normalized(), -forward)
	return _relative(model, rig) * grip


## rig 좌표 → model 좌표 변환(스켈레톤이 모델 아래 몇 단계에 있든 부모를 따라 곱한다).
func _relative(model: Node3D, rig: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var node: Node = rig
	while node != null and node != model:
		if node is Node3D:
			result = (node as Node3D).transform * result
		node = node.get_parent()
	return result
