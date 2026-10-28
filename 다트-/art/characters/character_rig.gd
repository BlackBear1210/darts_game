class_name CharacterRig
extends RefCounted
## 캐릭터 몸짓을 코드로 만든다(뼈대·애니메이션 파일 없이). 디자인 담당 소유.
## character_factory.gd 가 만든 관절 노드(LegL/LegR/Body/ArmL/ArmR/Neck)의 회전·위치만 바꾼다.
##
## 몸짓 목록: 서기(숨쉬기) · 걷기(팔다리 흔들기) · 앉기(다리 앞으로) · 숙이기(몸 낮추고 구부정) ·
##           점프(다리 접기) · 조준(오른팔 들기) · 던지기(팔 휘두르기) · 눈 깜빡임 · 카드 들기(왼팔, holding_cards).
## 사용법: PlayerView 가 매 프레임 animate() 를 부른다. 던질 때 play_throw() 한 번.
## 나중에 블렌더 리깅 + Mixamo 애니메이션(.glb)으로 바꾸면 이 파일 대신 AnimationPlayer/AnimationTree 를 쓴다.
## 그때도 PlayerView 가 넘겨주는 값(속도·자세·조준 중·던지기)은 그대로 쓰면 된다.
##
## 회전 방향 메모(캐릭터 정면 = +Z 기준):
##   다리/팔 rotation.x 가 음수(-) → 앞으로 든다(앉기·조준). 양수(+) → 뒤로 간다.
##   Body rotation.x 가 양수 → 앞으로 숙인다. Neck rotation.x 가 음수 → 위를 본다.

enum Posture { STAND, CROUCH, SEAT }

## 골반 높이(m). character_factory.gd 의 HIP 과 같아야 한다.
const HIP_HEIGHT := 0.59
## 걷기: 다리 최대 흔들림(라디안)과 걸음 빠르기.
const WALK_SWING := 0.6
const WALK_RATE := 9.0
## 앉기: 다리를 앞으로 드는 각도. 3등신이라 다리가 짧아 의자에 앉으면 발이 앞으로 뻗는다(귀여운 앉은 자세).
const SEAT_LEG_ANGLE := -1.35
## 숙이기: 다리를 이 비율로 줄이고 몸을 그만큼 내린다. 몸은 앞으로 조금 숙인다.
const CROUCH_LEG_SCALE := 0.62
const CROUCH_LEAN := 0.28
## 조준할 때 오른팔 각도(앞-위로 든다), 던진 뒤 팔이 내려오는 시간(초).
const AIM_ARM_ANGLE := -2.35
const THROW_SECONDS := 0.38
## 눈 깜빡임 간격(초)과 감은 시간.
const BLINK_EVERY := 3.4
const BLINK_TIME := 0.12
## 목표 자세로 따라가는 빠르기. 클수록 딱딱하게, 작을수록 흐느적하게 움직인다.
const FOLLOW := 12.0
## 카드 들기(카드 라운드 시연): 왼팔을 앞으로 들고 몸 안쪽으로 모은다. 부채는 Body 자식으로 손 앞에 붙는다.
const HOLD_ARM_ANGLE := -1.35
const HOLD_ARM_INWARD := -0.35

## 왼손에 카드를 들고 있는지. 켜면 걷거나 앉아도 왼팔은 카드 든 자세를 유지한다.
var holding_cards := false

var leg_l: Node3D
var leg_r: Node3D
var body: Node3D
var arm_l: Node3D
var arm_r: Node3D
var neck: Node3D
var _eyes: Array[Node3D] = []
var _eye_scales: Array[Vector3] = []
var _walk_phase := 0.0
var _time := 0.0
var _throw_age := -1.0
var _next_blink := 0.0


## model = PlayerLook.character() 로 만든 캐릭터 루트. 관절 이름이 없으면(옛 생성물) 아무것도 움직이지 않는다.
func _init(model: Node3D, seed_offset := 0.0) -> void:
	leg_l = model.get_node_or_null("LegL")
	leg_r = model.get_node_or_null("LegR")
	body = model.get_node_or_null("Body")
	arm_l = model.get_node_or_null("Body/ArmL")
	arm_r = model.get_node_or_null("Body/ArmR")
	neck = model.get_node_or_null("Body/Neck")
	for eye_name in ["EyeL", "EyeR", "PupilL", "PupilR"]:
		var eye := model.get_node_or_null("Body/Neck/" + eye_name) as Node3D
		if eye != null:
			_eyes.append(eye)
			_eye_scales.append(eye.scale)
	# 네 명이 동시에 깜빡이지 않도록 자리마다 시작 시간을 조금 다르게 한다.
	_time = seed_offset
	_next_blink = seed_offset + BLINK_EVERY


func is_valid() -> bool:
	return leg_l != null and leg_r != null and body != null and arm_l != null and arm_r != null and neck != null


## 던지기 동작을 처음부터 재생한다(팔을 뒤로 → 앞으로 휘두름).
func play_throw() -> void:
	_throw_age = 0.0


## 매 프레임 호출. speed_ratio = 지금 이동 속도 / 최고 속도(0~1), look_pitch = 위아래 시선(라디안, 위 +).
func animate(delta: float, speed_ratio: float, posture: Posture, airborne: bool, look_pitch: float, aiming: bool) -> void:
	if not is_valid():
		return
	_time += delta
	var weight := 1.0 - exp(-FOLLOW * delta)
	var moving := speed_ratio > 0.05 and posture != Posture.SEAT and not airborne
	if moving:
		_walk_phase += delta * WALK_RATE * (0.55 + 0.45 * speed_ratio)
	else:
		# 멈추면 다리가 가운데로 돌아오도록 위상을 0 쪽으로 감는다.
		_walk_phase = lerpf(_walk_phase, roundf(_walk_phase / PI) * PI, weight)
	var stride := sin(_walk_phase) * WALK_SWING * clampf(speed_ratio, 0.0, 1.0)
	# --- 목표 자세 계산 ---
	var leg_l_angle := stride
	var leg_r_angle := -stride
	var leg_scale := 1.0
	var hip := HIP_HEIGHT + absf(cos(_walk_phase)) * 0.025 * speed_ratio
	var lean := 0.06 # 기획 2-3: 등이 살짝 굽고 머리가 앞으로 나온 멍한 자세
	var arm_l_angle := -stride * 0.8
	var arm_r_angle := stride * 0.8
	var arm_spread := 0.0
	match posture:
		Posture.SEAT:
			leg_l_angle = SEAT_LEG_ANGLE
			leg_r_angle = SEAT_LEG_ANGLE + 0.08
			lean = -0.05
			arm_l_angle = -0.35
			arm_r_angle = -0.35
		Posture.CROUCH:
			leg_scale = CROUCH_LEG_SCALE
			hip = HIP_HEIGHT * CROUCH_LEG_SCALE
			lean = CROUCH_LEAN
	if airborne:
		leg_l_angle = -0.55
		leg_r_angle = 0.25
		arm_spread = 0.45
	# 숨쉬기: 서 있을 때 몸이 아주 조금 오르내린다.
	hip += sin(_time * 2.2) * 0.006
	# 조준 중이면 오른팔을 앞-위로 들고, 던지는 중이면 뒤로 젖혔다가 앞으로 내린다.
	if aiming:
		arm_r_angle = AIM_ARM_ANGLE
	if holding_cards:
		arm_l_angle = HOLD_ARM_ANGLE
		arm_spread = 0.0
	if _throw_age >= 0.0:
		_throw_age += delta
		var t := clampf(_throw_age / THROW_SECONDS, 0.0, 1.0)
		# 0~0.3: 더 뒤로 젖힘(-2.9) → 0.3~1: 앞으로 휘둘러 아래(-0.6)까지.
		arm_r_angle = lerpf(-2.35, -2.9, t / 0.3) if t < 0.3 else lerpf(-2.9, -0.6, (t - 0.3) / 0.7)
		lean += sin(t * PI) * 0.12
		if _throw_age >= THROW_SECONDS:
			_throw_age = -1.0
	# --- 목표로 부드럽게 따라가기(던지기 팔은 빠르게) ---
	leg_l.rotation.x = lerpf(leg_l.rotation.x, leg_l_angle, weight)
	leg_r.rotation.x = lerpf(leg_r.rotation.x, leg_r_angle, weight)
	leg_l.scale.y = lerpf(leg_l.scale.y, leg_scale, weight)
	leg_r.scale.y = lerpf(leg_r.scale.y, leg_scale, weight)
	leg_l.position.y = lerpf(leg_l.position.y, hip, weight)
	leg_r.position.y = lerpf(leg_r.position.y, hip, weight)
	body.position.y = lerpf(body.position.y, hip, weight)
	body.rotation.x = lerpf(body.rotation.x, lean, weight)
	arm_l.rotation.x = lerpf(arm_l.rotation.x, arm_l_angle, weight)
	arm_l.rotation.z = lerpf(arm_l.rotation.z, arm_spread, weight)
	arm_l.rotation.y = lerpf(arm_l.rotation.y, HOLD_ARM_INWARD if holding_cards else 0.0, weight)
	arm_r.rotation.z = lerpf(arm_r.rotation.z, -arm_spread, weight)
	var arm_weight := 1.0 if _throw_age >= 0.0 else weight
	arm_r.rotation.x = lerpf(arm_r.rotation.x, arm_r_angle, arm_weight)
	neck.rotation.x = lerpf(neck.rotation.x, clampf(-look_pitch * 0.6, -0.5, 0.45) - lean * 0.5, weight)
	_blink()


## 몇 초마다 눈(흰자·눈동자)을 세로로 납작하게 눌렀다 편다.
func _blink() -> void:
	var closed := _time >= _next_blink and _time < _next_blink + BLINK_TIME
	if _time >= _next_blink + BLINK_TIME:
		_next_blink = _time + BLINK_EVERY + fmod(_time * 7.3, 1.6)
	for i in range(_eyes.size()):
		var base := _eye_scales[i]
		_eyes[i].scale = Vector3(base.x, base.y * (0.12 if closed else 1.0), base.z)
