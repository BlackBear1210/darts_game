extends RefCounted
## [부품 3] 1인칭 3D 손의 몸짓 곡선 — 차징 정도와 놓은 뒤 시간을 "손이 어디쯤 있나" 값으로 바꾼다(보이기만).
## first_person_hand_view.gd 가 이 값으로 손목이 지나갈 자리를 섞고, 팔꿈치는 팔 뼈 맞추기(fp_arm_ik.gd)가 따라 굽힌다.
## 2D 손(dart_hand.gd)은 예전 곡선(first_person_throw.gd)을 그대로 쓴다.
## 시간 약속(놓은 뒤 0.8초, 다음 다트를 쥐고 올라오는 때)은 game.gd 와 같은 first_person_throw.gd 상수를 쓴다.
##
## [2026-11-27 사용자 요청]
##   차징(좌클릭 누름)  손을 점점 내 쪽(얼굴 쪽)으로 당긴다 → 어깨와 손이 가까워져 팔꿈치가 점점 굽혀진다.
##   던지기(놓음)       손이 과녁 쪽으로 뻗어 나가며 팔꿈치가 펴지고, 다트를 쥔 손가락이 펴진다.

const ThrowPose = preload("res://art/characters/first_person_throw.gd")

## 놓은 뒤 진행 비율(u = 1 − kick, 0.8초 기준)로 적은 구간.
## 당긴 손이 풀리는 구간(뻗기와 겹친다).
const UNCOCK_END: float = 0.12
## 팔이 다 뻗는 때: 0.8 × 0.18 ≈ 0.14초 — 실제 놓는 순간처럼 빠르다.
const REACH_END: float = 0.18
## 손가락이 다 펴지는 때(놓자마자 빠르게).
const OPEN_END: float = 0.1
## 손목이 앞으로 꺾이는(스냅) 구간 — 팔보다 조금 늦게(채찍처럼).
const SNAP_START: float = 0.03
const SNAP_END: float = 0.24
## 손이 다트 겨누기를 그만두고 팔을 따라가는 구간.
const AIM_RELEASE_END: float = 0.12
## 팔이 화면 아래로 떨어지는 구간.
const DROP_START: float = 0.34
const DROP_END: float = 0.62


class Pose:
	## 내 쪽으로 당긴 정도 0~1
	var back: float = 0.0
	## 과녁 쪽으로 뻗은 정도 0~1
	var reach: float = 0.0
	## 팔 내림 0~1(1 = 화면 밖)
	var drop: float = 0.0
	## 손목 스냅 0~1
	var snap: float = 0.0
	## 손가락 펴짐 0~1
	var open: float = 0.0
	## 손이 다트로 과녁을 겨누는 정도 0~1(0 = 손목이 아래팔을 따라간다)
	var aim: float = 1.0
	## 손에 다트가 보이는가
	var holding: bool = true


## pull = 지금 당긴 정도 0~1 · kick = 놓은 뒤 1 → 0(0 = 아직 안 놓음) · released = 놓을 때 당겨 있던 정도
## reload = 다음 다트가 있는가 · motion = 움직임 크기(멀미 줄이기면 0.3)
static func at(pull: float, kick: float, released: float, reload: bool, motion: float = 1.0) -> Pose:
	var p := Pose.new()
	if kick <= 0.0:
		p.back = _ease_out(pull) * motion
		return p
	var u: float = 1.0 - kick
	p.back = _ease_out(released) * motion * (1.0 - smoothstep(0.0, UNCOCK_END, u))
	p.reach = _ease_out(clampf(u / REACH_END, 0.0, 1.0)) * motion
	p.drop = smoothstep(DROP_START, DROP_END, u)
	p.open = smoothstep(0.0, OPEN_END, u)
	p.snap = smoothstep(SNAP_START, SNAP_END, u) * motion
	p.aim = 1.0 - smoothstep(0.0, AIM_RELEASE_END, u)
	p.holding = false
	if reload and u >= ThrowPose.RISE_START:
		# 다음 다트를 쥐고 화면 아래에서 올라온다. 이미 다음 차징을 시작했으면 그만큼 당긴 자리로 온다.
		var rise: float = smoothstep(ThrowPose.RISE_START, 1.0, u)
		p.back = lerpf(0.0, _ease_out(pull) * motion, rise)
		p.reach = p.reach * (1.0 - rise)
		p.drop = p.drop * (1.0 - rise)
		p.snap = p.snap * (1.0 - rise)
		p.open = 0.0
		p.aim = 1.0
		p.holding = true
	return p


static func _ease_out(x: float) -> float:
	var t: float = clampf(x, 0.0, 1.0)
	return 1.0 - (1.0 - t) * (1.0 - t)
