class_name CharacterMotion
extends RefCounted
## 리깅 캐릭터(rigged/tripo_character.glb)의 몸짓을 정한다. 디자인 담당 소유.
## PlayerView·로비가 쓰는 겉면은 예전 CharacterRig 와 같다: 매 프레임 animate(), 던질 때 play_throw().
##
## 온몸: AnimationPlayer 가 서기·걷기·숙이기·점프·앉기·일어서기 모션을 튼다.
## 팔: Dart_Throw·Card_Hold_L·Cheer·Point_R·Drink_R 자세를 CharacterPoseLayer 가 팔 뼈에만 덮어쓴다.
##     오른팔 우선순위 = 던지기 > 조준 > 마시기 > 만세 > 가리키기. 왼팔 = 만세 > 카드 들기.
## 기본 몸짓은 위치·자세·속도로 만든다. 선택 모션은 방장이 승인한 감정표현 이벤트로 시작한다.
## 모델 정면은 -Z(PlayerView 와 같다). 생성기: character_assets/.../incoming_tripo_20261107/build_game_character.py

enum Posture { STAND, CROUCH, SEAT }
const MotionEmotes = preload("res://art/characters/motion_emotes.gd")

const IDLE := "Idle"
const WALK := "Walk"
const CROUCH_IDLE := "Crouch_Idle"
const CROUCH_WALK := "Crouch_Walk"
const JUMP := "Jump_Air"
const SIT := "Sit_Stool"
const SEATED := "Seated_Stool"
const STAND_UP := "Stand_Stool"
const THROW := "Dart_Throw"
const CARD_HOLD := "Card_Hold_L"
const CHEER := "Cheer"
const POINT := "Point_R"
const DRINK := "Drink_R"
const LOOPS: Array[String] = [IDLE, WALK, CROUCH_IDLE, CROUCH_WALK, SEATED, CARD_HOLD]
const LEFT_ARM: PackedStringArray = ["upper_arm.L", "forearm.L", "hand.L", "thumb_01.L", "thumb_02.L", "thumb_03.L",
	"index_01.L", "index_02.L", "index_03.L", "middle_01.L", "middle_02.L", "middle_03.L",
	"ring_01.L", "ring_02.L", "ring_03.L", "pinky_01.L", "pinky_02.L", "pinky_03.L"]
const RIGHT_ARM: PackedStringArray = ["clavicle.R", "upper_arm.R", "forearm.R", "hand.R", "thumb_01.R", "thumb_02.R", "thumb_03.R",
	"index_01.R", "index_02.R", "index_03.R", "middle_01.R", "middle_02.R", "middle_03.R",
	"ring_01.R", "ring_02.R", "ring_03.R", "pinky_01.R", "pinky_02.R", "pinky_03.R"]

## 온몸 모션이 바뀔 때 섞는 시간(초)과, 팔 자세를 따라가는 빠르기.
const BLEND := 0.18
const FOLLOW := 12.0
## 이 비율(지금 속도 / 최고 속도)을 넘으면 걷는다.
const MOVE_THRESHOLD := 0.05
## 앉은 채 춤에서 엉덩이를 묶는 뼈(CharacterPoseLayer.seat_pin). 다리는 seat_legs 가 맡는다.
const SEAT_PIN_BONES: PackedStringArray = ["root", "hips"]
## 앉은 채 춤으로 바뀌는 빠르기.
const SEAT_PIN_RATE := 10.0
## 걷기 재생 배속 = 속도 비율 × WALK_RATE(MIN~MAX 사이). 최고 속도 3.8m/s 에서 한 걸음 주기 0.4초.
const WALK_RATE := 3.0
const WALK_RATE_MIN := 0.7
const WALK_RATE_MAX := 2.0
## Dart_Throw 시각(초, 30fps). 겨누기 = 27프레임, 뒤로 당긴 뒤 휘두름 시작 = 34프레임, 팔로스루 끝 = 60프레임.
## 게임은 던지는 순간 다트를 띄우므로 34프레임부터 빠르게 틀어 39프레임(놓는 순간)을 0.1초 안에 맞춘다.
const AIM_TIME := 0.9
const AIM_RATE := 1.8
const THROW_START := 34.0 / 30.0
const THROW_END := 2.0
const THROW_RATE := 1.6
## Jump_Air 는 높이 이동을 뺀 모션이다(높이는 PlayerView 물리). 발이 떨어지는 10프레임부터 튼다.
const JUMP_TAKEOFF := 10.0 / 30.0
const JUMP_RATE := 0.8
## 마시는 동안 고개를 뒤로 젖히는 각도(라디안).
const DRINK_HEAD_BACK := 0.45
const BLINK_EVERY := 3.4
const BLINK_TIME := 0.12
## 왕머리가 커지는 빠르기.
const HEAD_SCALE_RATE := 8.0
## 앉은 다리 자세(CharacterPoseLayer.seat_legs)로 바뀌는 빠르기. 앉는 모션(Sit_Stool)과 비슷하게 0.5초쯤 걸린다.
const SEAT_LEGS_RATE := 5.0
## 카드 앞면이 보는 방향(모델 기준): 든 사람 쪽(+Z)에서 몸 안쪽(+X)과 위로 비스듬히.
## 눈을 곧바로 보게 하면 손이 눈 바로 아래라 부채가 눕는다. 앉거나 걸어도 같은 각도로 세워 둔다.
const CARD_FAN_FACING := Vector3(0.45, 0.55, 0.7)

## 왼손에 카드를 들고 있는지. 켜면 걷거나 앉아도 왼팔은 카드 든 자세를 유지한다.
var holding_cards := false
var pointing := false
var cheering := false
## 마시는 몸짓 진행(0 = 안 마심, 0~1 = 진행). PlayerView 가 매 프레임 넣는다.
var drinking := 0.0
## 윗몸 기울기·머리 꺾기(라디안, 오른쪽 +). 앉아서 엿볼 때 PlayerView 가 넣는다.
var lean := 0.0
var head_tilt := 0.0
## 왕머리 배율. PlayerView 가 넣고 여기서 부드럽게 따라간다.
var head_scale := 1.0
## 지금 틀고 있는 온몸 모션.
var clip := ""
## 선택한 Tripo 모션. 한 번 재생하고 기본 동작으로 돌아간다.
var emote_clip: String = ""

var _model: Node3D
var _player: AnimationPlayer
var _layer: CharacterPoseLayer
var _card_socket: Node3D
var _card_fan: Node3D
var _eyes: Array[MeshInstance3D] = []
var _pupils: Array[Node3D] = []
var _skin: Material
var _eyes_closed := false
var _seed := 0.0
var _time := 0.0
var _aim_time := 0.0
var _throw_time := -1.0
var _next_blink := 0.0


## model = PlayerLook.character() 로 만든 캐릭터. 트리에 붙인 뒤에 만든다.
func _init(model: Node3D, seed_offset := 0.0) -> void:
	_model = model
	_player = model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_card_socket = model.find_child("Socket_Card_L", true, false) as Node3D
	# Tripo 얼굴은 눈과 피부가 하나의 텍스처 메시다. 분리된 눈이 있을 때만 기존 깜빡임을 쓴다.
	var head := model.find_child("Head_Base", true, false) as MeshInstance3D
	if head != null:
		_eyes.assign([model.find_child("Eye_L", true, false), model.find_child("Eye_R", true, false)])
		_pupils.assign([model.find_child("Pupil_L", true, false), model.find_child("Pupil_R", true, false)])
		_skin = head.mesh.surface_get_material(0)
	for name: String in LOOPS:
		_player.get_animation(name).loop_mode = Animation.LOOP_LINEAR
	for name: String in MotionEmotes.CLIPS:
		if _player.has_animation(name):
			_player.get_animation(name).loop_mode = Animation.LOOP_NONE
	var path := String(_player.get_node(_player.root_node).get_path_to(rig))
	_layer = CharacterPoseLayer.new()
	rig.add_child(_layer)
	_layer.setup(rig, CharacterPoseLayer.Arm.new(rig, LEFT_ARM, path), CharacterPoseLayer.Arm.new(rig, RIGHT_ARM, path))
	_setup_seat_pin(rig, path)
	# 네 명이 같은 박자로 숨쉬고 깜빡이지 않게 자리마다 시작 시각을 다르게 준다.
	_seed = seed_offset
	_time = seed_offset
	_next_blink = seed_offset + BLINK_EVERY


## 카드 부채를 왼손에 든다. 위치는 매 프레임 왼손 소켓을 따라가고 방향은 몸 기준으로 고정이다.
func attach_cards(fan: Node3D) -> void:
	_model.add_child(fan)
	fan.basis = Basis.looking_at(-CARD_FAN_FACING, Vector3.UP)
	_card_fan = fan


## 던지기 동작을 재생한다(GameView 가 다트를 띄우는 순간에 부른다).
func play_throw() -> void:
	stop_emote()
	_throw_time = THROW_START


func play_emote(index: int) -> bool:
	if index == MotionEmotes.STOP:
		stop_emote()
		return true
	if index < 0 or index >= MotionEmotes.CLIPS.size():
		return false
	var name: String = MotionEmotes.CLIPS[index]
	if not _player.has_animation(name):
		return false
	emote_clip = name
	clip = name
	_player.speed_scale = 1.0
	_player.play(name, BLEND)
	_player.seek(0.0, true)
	return true


func stop_emote() -> void:
	emote_clip = ""


## 매 프레임 호출. speed_ratio = 지금 이동 속도 / 최고 속도, look_pitch = 위아래 시선(라디안, 위 +).
func animate(delta: float, speed_ratio: float, posture: Posture, airborne: bool, look_pitch: float, aiming: bool) -> void:
	_time += delta
	var amount := 1.0 - exp(-FOLLOW * delta)
	# 앉아 있어도 모션은 계속된다(엉덩이·다리는 의자에 묶고 윗몸만 춘다). 숙이기·점프·조준·마시기·던지기는 멈춘다.
	if posture == Posture.CROUCH or airborne or aiming or drinking > 0.0 or _throw_time >= 0.0:
		stop_emote()
	var pin_target: float = 1.0 if posture == Posture.SEAT and not emote_clip.is_empty() else 0.0
	_layer.seat_pin = lerpf(_layer.seat_pin, pin_target, 1.0 - exp(-SEAT_PIN_RATE * delta))
	_update_body(speed_ratio, posture, airborne)
	var drink: Vector2 = CharacterRig.drink_curve(drinking)
	if not emote_clip.is_empty():
		_layer.right.follow(_layer.right.pose, 0.0, amount)
	else:
		_update_right_arm(delta, amount, aiming, drink.x)
	_update_left_arm(amount)
	var head_pitch: float = 0.0 if not emote_clip.is_empty() else clampf(look_pitch * 0.6, -0.45, 0.5) + drink.y * DRINK_HEAD_BACK
	_layer.look_pitch = lerpf(_layer.look_pitch, head_pitch, amount)
	_layer.lean = lean
	_layer.head_tilt = head_tilt
	# 앉아 있으면 허벅지는 방석 위 수평, 발은 의자 발걸이 위(2026-11-08 — 모션 그대로면 무릎이 방석을 뚫는다).
	_layer.seat_legs = lerpf(_layer.seat_legs, 1.0 if posture == Posture.SEAT else 0.0, 1.0 - exp(-SEAT_LEGS_RATE * delta))
	_layer.head_scale = lerpf(_layer.head_scale, head_scale, minf(1.0, delta * HEAD_SCALE_RATE))
	if is_instance_valid(_card_fan):
		_card_fan.position = _model.to_local(_card_socket.global_position)
	_blink()


## 몸짓 없이 clip_name 자세로 굳힌다(벌칙 원판처럼 움직이지 않는 캐릭터). 트리에 붙인 뒤에 부른다.
static func freeze(model: Node3D, clip_name: String) -> void:
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	player.play(clip_name)


## 앉은 자세(Seated_Stool 첫 장면)의 엉덩이 뼈 위치·회전을 꺼내 CharacterPoseLayer 에 넣는다.
func _setup_seat_pin(rig: Skeleton3D, path: String) -> void:
	var seated := _player.get_animation(SEATED)
	var bones := PackedInt32Array()
	var positions: Array[Vector3] = []
	var rotations: Array[Quaternion] = []
	for bone_name: String in SEAT_PIN_BONES:
		var bone := rig.find_bone(bone_name)
		var position_track := seated.find_track(NodePath("%s:%s" % [path, bone_name]), Animation.TYPE_POSITION_3D)
		var rotation_track := seated.find_track(NodePath("%s:%s" % [path, bone_name]), Animation.TYPE_ROTATION_3D)
		if bone < 0 or position_track < 0 or rotation_track < 0:
			continue
		bones.append(bone)
		positions.append(seated.position_track_interpolate(position_track, 0.0))
		rotations.append(seated.rotation_track_interpolate(rotation_track, 0.0))
	_layer.set_seat_pin(bones, positions, rotations)


func _update_body(speed_ratio: float, posture: Posture, airborne: bool) -> void:
	if not emote_clip.is_empty():
		if _player.is_playing():
			_player.speed_scale = 1.0
			return
		stop_emote()
	var moving := speed_ratio > MOVE_THRESHOLD and posture != Posture.SEAT and not airborne
	var next := _next_clip(moving, posture, airborne)
	if next != clip:
		var first := clip.is_empty()
		clip = next
		_player.play(next, 0.0 if first else BLEND)
		if next == JUMP:
			_player.seek(JUMP_TAKEOFF, true)
		elif first:
			_player.seek(fmod(_seed, _player.get_animation(next).length), true)
			# 처음부터 앉아 있던 사람(봇·NPC)은 다리도 바로 앉은 자세다.
			if next == SEATED:
				_layer.seat_legs = 1.0
	if moving:
		_player.speed_scale = clampf(speed_ratio * WALK_RATE, WALK_RATE_MIN, WALK_RATE_MAX)
	else:
		_player.speed_scale = JUMP_RATE if next == JUMP else 1.0


func _next_clip(moving: bool, posture: Posture, airborne: bool) -> String:
	if posture == Posture.SEAT:
		# 처음부터 앉아 있던 사람(봇)은 앉는 동작 없이 시작한다.
		if clip.is_empty() or clip == SEATED or (clip == SIT and not _player.is_playing()):
			return SEATED
		return SIT
	if clip == SIT or clip == SEATED:
		return STAND_UP
	if airborne:
		return JUMP
	if clip == STAND_UP and _player.is_playing() and not moving:
		return STAND_UP
	if posture == Posture.CROUCH:
		return CROUCH_WALK if moving else CROUCH_IDLE
	return WALK if moving else IDLE


func _update_right_arm(delta: float, amount: float, aiming: bool, drink_lift: float) -> void:
	var arm := _layer.right
	_aim_time = move_toward(_aim_time, AIM_TIME if aiming else 0.0, delta * AIM_RATE)
	if _throw_time >= 0.0:
		_throw_time += delta * THROW_RATE
		if _throw_time < THROW_END:
			arm.pose = arm.sample(_player.get_animation(THROW), _throw_time)
			arm.weight = 1.0
			return
		_throw_time = -1.0
		_aim_time = 0.0
	if aiming:
		arm.follow(arm.sample(_player.get_animation(THROW), _aim_time), 1.0, amount)
	elif drink_lift > 0.0:
		arm.follow(arm.sample(_player.get_animation(DRINK), 0.0), drink_lift, amount)
	elif cheering:
		arm.follow(arm.sample(_player.get_animation(CHEER), 0.0), 1.0, amount)
	elif pointing:
		arm.follow(arm.sample(_player.get_animation(POINT), 0.0), 1.0, amount)
	else:
		arm.follow(arm.pose, 0.0, amount)


func _update_left_arm(amount: float) -> void:
	var arm := _layer.left
	if cheering and emote_clip.is_empty():
		arm.follow(arm.sample(_player.get_animation(CHEER), 0.0), 1.0, amount)
	elif holding_cards:
		var hold := _player.get_animation(CARD_HOLD)
		arm.follow(arm.sample(hold, fmod(_time, hold.length)), 1.0, amount)
	else:
		arm.follow(arm.pose, 0.0, amount)


## 눈꺼풀 조각이 없어 감는 동안 흰자를 피부색으로 칠하고 눈동자를 숨긴다.
## 눈을 눌러 납작하게 만들면 뒤의 눈구멍이 검게 드러난다.
func _blink() -> void:
	var closed := _time >= _next_blink and _time < _next_blink + BLINK_TIME
	if _time >= _next_blink + BLINK_TIME:
		_next_blink = _time + BLINK_EVERY + fmod(_time * 7.3, 1.6)
	if closed == _eyes_closed:
		return
	_eyes_closed = closed
	for eye in _eyes:
		eye.material_override = _skin if closed else null
	for pupil in _pupils:
		pupil.visible = not closed
