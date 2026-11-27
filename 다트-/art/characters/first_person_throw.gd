extends RefCounted
## 1인칭 던지기 몸짓 곡선(보이기만 — 판정 좌표·다트 궤적은 그대로).
## GameView._animate_hand(game/game.gd)와 미리보기 tests/render_fp_arm.gd 가 같은 함수를 쓴다.
## class_name 을 새로 만들지 않고 preload 로 부른다(열린 편집기가 새 class_name 을 못 읽는 함정).
##
## [왜 만들었나 — 2026-11-17 사용자 지적 "던지는 모션이랑 손까지 신경을 써야겠지?"]
## 예전 몸짓: 충전하면 손이 카메라 쪽으로 6.5cm 미끄러지고(촉은 오히려 아래로 숙었다),
## 놓으면 앞으로 튕겼다가 제자리로 돌아왔다. 손목이 꺾이지 않아 막대를 밀어내는 것처럼 보였다.
##
## [실제 다트 던지기 — 오른손잡이, 눈 높이에서 겨눔]
##   1. 겨누기    다트를 눈 앞 오른쪽에 들고 촉으로 과녁을 본다. (기본 자세 = Camera/Hand)
##   2. 당기기    팔꿈치를 축으로 아래팔이 얼굴 쪽으로 접힌다. 촉이 들린다.
##   3. 던지기    위팔은 그대로, 아래팔만 앞으로 펴지며 빨라지고 손목이 앞으로 꺾이면서(스냅) 손가락이 다트를 놓는다.
##   4. 팔로 스루  손가락이 과녁을 가리킨 채 팔이 아래로 떨어진다(화면 밖).
##   5. 다시 쥐기  다음 다트가 있으면 손이 화면 아래에서 다시 올라와 겨누기 자세가 된다.
##
## [두 가지로 나눠 움직인다]
## - Hand 노드(팔·다트 통째): 당기기와 떨어지기. 다트를 쥔 동안은 손과 다트가 같이 움직여야 해서 뼈를 건드리지 않는다.
##   당기기는 팔꿈치를 축으로 통째 돈다(원점 = 다트 촉으로 돌리면 손이 촉 둘레로 휘둘린다).
## - 아래팔·손목 뼈(FirstPersonArm.swing): 놓은 뒤에만. 다트는 이미 손을 떠나 쥔 자리가 어긋나도 된다.
##   처음엔 놓은 뒤에도 통째로 돌렸더니 위팔까지 같이 돌아 화면 왼쪽에 소매가 튀어나오고, 편 손이 천장을 가리켰다.
##
## 놓은 뒤 몸짓은 kick 1 → 0 (GameView 가 KICK_SECONDS 동안 줄인다). 아래 *_END·RISE_START 는 그 진행 비율(u = 1 - kick)이다.

## 놓은 뒤 몸짓 전체 길이(초).
const KICK_SECONDS: float = 0.8
## 당기기: 다 당겼을 때 손이 옮겨 가는 양(Hand 기준 — 왼쪽·위·카메라 쪽).
const CHARGE_OFFSET := Vector3(-0.02, 0.03, 0.06)
## 당기기: 아래팔을 얼굴 쪽으로 접는 각(라디안). 촉이 들린다.
const CHARGE_COCK: float = 0.3
## 던지기: 손이 앞으로 따라 나가는 양(아래팔이 펴지는 것과 별개로 어깨가 조금 밀어 준다).
const THRUST_OFFSET := Vector3(-0.01, 0.0, -0.08)
## 던지기: 아래팔이 과녁 쪽으로 펴지는 각(라디안, 팔꿈치 축).
const FOREARM_SWING: float = 0.9
## 던지기: 손목이 앞으로 꺾이는 각(라디안). 손가락이 과녁을 가리킨다.
const WRIST_SNAP: float = 1.0
## 팔로 스루: 팔이 떨어지는 양(화면 아래로 빠질 만큼 — 시야각 65° 기준).
const DROP_OFFSET := Vector3(0.04, -0.4, 0.12)
## 놓은 순간 당긴 자세가 풀리는 구간 끝.
const UNCOCK_END: float = 0.15
## 아래팔이 다 펴지는 지점. 0.8초 × 0.2 = 0.16초 — 실제 놓는 순간처럼 빠르다.
const THRUST_END: float = 0.2
## 손목 스냅은 아래팔보다 조금 늦게 시작해 조금 늦게 끝난다(채찍처럼).
const SNAP_START: float = 0.05
const SNAP_END: float = 0.3
## 팔이 화면 밖으로 다 떨어지는 지점.
const DROP_START: float = 0.3
const DROP_END: float = 0.6
## 다음 다트를 쥐고 올라오기 시작하는 지점.
const RISE_START: float = 0.65


## Hand 노드 자세(팔·다트 통째).
##   base     겨누기 자세(Camera/Hand 의 씬 값)
##   elbow    팔꿈치 위치(Hand 기준). FirstPersonArm.elbow 를 넘긴다. 없으면 촉 둘레로 돈다.
##   pull     지금 당긴 정도 0~1
##   kick     놓은 뒤 몸짓 1 → 0(0 = 놓지 않음)
##   released 놓을 때 당겨 있던 정도(놓은 순간 거기서 출발한다)
##   reload   다음 다트가 있는가(없으면 팔로 스루 뒤 화면 밖에 머문다 — 곧 손을 숨긴다)
##   motion   움직임 크기(멀미 줄이기 설정이면 0.3)
##   extra    손 떨림 등 덧붙이는 이동
static func pose(base: Transform3D, elbow: Vector3, pull: float, kick: float = 0.0, released: float = 0.0, reload: bool = true, motion: float = 1.0, extra: Vector3 = Vector3.ZERO) -> Transform3D:
	var weights: Vector3 = pose_weights(pull, kick, released, reload)
	var offset: Vector3 = (CHARGE_OFFSET * weights.x + THRUST_OFFSET * weights.y + DROP_OFFSET * weights.z) * motion + extra
	var angle: float = CHARGE_COCK * weights.x * motion
	var about_elbow := Transform3D(Basis.IDENTITY, elbow) * Transform3D(Basis(Vector3.RIGHT, angle), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -elbow)
	return base.translated_local(offset) * about_elbow


## 시간에 따른 당김·뻗기·내림. 엄지 쪽 카메라에서도 같은 시점에 움직인다.
static func pose_weights(pull: float, kick: float, released: float, reload: bool) -> Vector3:
	var back: float = _ease_out(pull)
	var thrust: float = 0.0
	var drop: float = 0.0
	if kick > 0.0:
		var u: float = 1.0 - kick
		var away: float = 1.0 - _rise(u, reload)
		back = _ease_out(released) * (1.0 - smoothstep(0.0, UNCOCK_END, u)) * away + _ease_out(pull) * (1.0 - away)
		thrust = _ease_out(clampf(u / THRUST_END, 0.0, 1.0)) * away
		drop = smoothstep(DROP_START, DROP_END, u) * away
	return Vector3(back, thrust, drop)


## 놓은 뒤 아래팔이 펴지는 각(라디안, 음수 = 과녁 쪽). FirstPersonArm.swing 의 첫 인자.
static func forearm(kick: float, reload: bool = true, motion: float = 1.0) -> float:
	if kick <= 0.0:
		return 0.0
	var u: float = 1.0 - kick
	return -FOREARM_SWING * _ease_out(clampf(u / THRUST_END, 0.0, 1.0)) * (1.0 - _rise(u, reload)) * motion


## 놓은 뒤 손목이 꺾이는 각(라디안, 음수 = 손가락이 과녁 쪽). FirstPersonArm.swing 의 둘째 인자.
static func wrist(kick: float, reload: bool = true, motion: float = 1.0) -> float:
	if kick <= 0.0:
		return 0.0
	var u: float = 1.0 - kick
	return -WRIST_SNAP * smoothstep(SNAP_START, SNAP_END, u) * (1.0 - _rise(u, reload)) * motion


## 손가락이 펴져 있어야 하는가: 놓은 순간부터 다음 다트를 쥐고 올라오기 전까지.
static func fingers_open(kick: float) -> bool:
	return kick > 0.0 and 1.0 - kick < RISE_START


## 손에 다트가 보여야 하는가: 겨누는 중이거나, 다음 다트를 쥐고 올라오는 중.
static func dart_in_hand(kick: float, reload: bool) -> bool:
	return kick <= 0.0 or (reload and 1.0 - kick >= RISE_START)


## 카메라 반동(0~1): 놓는 순간 솟았다가 팔이 다 펴질 즈음 가라앉는다.
static func recoil(kick: float) -> float:
	if kick <= 0.0:
		return 0.0
	return sin(PI * clampf((1.0 - kick) / (THRUST_END * 2.0), 0.0, 1.0))


static func _rise(u: float, reload: bool) -> float:
	return smoothstep(RISE_START, 1.0, u) if reload else 0.0


static func _ease_out(x: float) -> float:
	var t: float = clampf(x, 0.0, 1.0)
	return 1.0 - (1.0 - t) * (1.0 - t)
