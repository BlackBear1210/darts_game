extends RefCounted
## 봇의 차례 행동 계산. 방장에서만 쓴다(GameView._drive_bot).
##
## 상태를 가지지 않고 지금 위치와 목표만 보고 "사람이 보내는 것과 같은 모양"의 조작을 만든다.
## 그래서 봇도 PlayerView.simulate 의 같은 이동·충돌·속도 규칙을 그대로 지나며,
## 결과 위치는 기존 이동 스냅샷으로 모든 화면에 전달된다(봇 전용 네트워크 메시지는 없다).

## 투척선(TableView.THROW_LINE_Z) 바로 뒤에 서는 자리. 선을 넘지 않게 뒤로 조금 띄운다.
const LINE_MARGIN: float = 0.45
## 이 거리(m) 안에 들어오면 다 온 것으로 보고 멈춘다.
const ARRIVE_RADIUS: float = 0.2
## 테이블을 감싸는 원에서 더 떨어져 지나갈 거리(몸 반지름 + 여유).
const TABLE_MARGIN: float = 0.8
## 투척선에 선 뒤 한 발을 던지기까지 조준하는 시간(초). 시연값 — 팀 확정 필요.
const AIM_SECONDS: float = 1.2
## 조준이 과녁 중심에서 흔들리는 정도(1.0 = 과녁 반지름). 시연값 — 팀 확정 필요.
const AIM_SPREAD: float = 0.4
## 충전 범위. 1.0 이면 조준한 곳에 그대로 꽂히고 약하면 아래로 떨어진다. 시연값 — 팀 확정 필요.
const MIN_CHARGE: float = 0.95
const MAX_CHARGE: float = 1.0


## 봇이 던지는 자리(바닥 좌표). 레인 한가운데, 투척선 바로 뒤다.
static func throw_spot() -> Vector3:
	return Vector3(0, 0, TableView.THROW_LINE_Z + LINE_MARGIN)


## 목표에 다 왔는지. 높이는 보지 않는다.
static func arrived(from: Vector3, target: Vector3) -> bool:
	return Vector2(target.x - from.x, target.z - from.z).length() <= ARRIVE_RADIUS


## 목표를 보고 걸어가는 조작. 테이블에 막히는 길이면 옆으로 돌아간다.
static func walk_controls(from: Vector3, target: Vector3) -> Dictionary:
	return _controls(Vector2(0, -1), _facing(_steer(from, target)), 0.0)


## 과녁을 보고 멈춰 선 조작. 눈높이에서 과녁 중심을 본다.
static func aim_controls(from: Vector3) -> Dictionary:
	var to_board: Vector3 = TableView.BOARD_CENTER - (from + Vector3.UP * PlayerView.EYE_HEIGHT)
	return _controls(Vector2.ZERO, _facing(to_board), asin(to_board.normalized().y))


## 앉아서도 과녁을 바라보는 방향(PlayerView.configure 의 처음 자세와 같다).
static func facing_board(from: Vector3) -> float:
	return _facing(TableView.BOARD_CENTER - from)


## 이번 한 발의 조준점. 과녁 반지름 기준 좌표라 사람의 조준값과 단위가 같다.
static func random_aim() -> Vector2:
	return Vector2(randf_range(-1, 1), randf_range(-1, 1)).limit_length(1.0) * AIM_SPREAD


static func random_charge() -> float:
	return randf_range(MIN_CHARGE, MAX_CHARGE)


## 테이블은 뚫고 갈 수 없다. 가는 길이 테이블에 걸리면 옆으로 비껴 선 지점을 먼저 본다.
## 매 프레임 다시 계산하므로 기억하는 경로가 없다 — 테이블을 지나면 바로 목표로 향한다.
static func _steer(from: Vector3, target: Vector3) -> Vector3:
	var flat_from := Vector3(from.x, 0, from.z)
	var to_target: Vector3 = Vector3(target.x, 0, target.z) - flat_from
	var distance: float = to_target.length()
	if distance < 0.01:
		return to_target
	var center := Vector3(TableView.TABLE_CENTER.x, 0, TableView.TABLE_CENTER.z)
	var to_center: Vector3 = center - flat_from
	var forward: float = to_center.dot(to_target / distance)
	# 테이블이 등 뒤이거나 목표 너머면 그대로 간다.
	if forward <= 0 or forward >= distance:
		return to_target
	var side: Vector3 = to_center - to_target / distance * forward
	var clearance: float = TableView.TABLE_SIZE.length() / 2.0 + TABLE_MARGIN
	if side.length() >= clearance:
		return to_target
	# 테이블 옆(지금 비껴 있는 쪽)으로 clearance 만큼 떨어진 지점을 본다.
	var away: Vector3 = -side if side.length() > 0.01 else Vector3(to_target.z, 0, -to_target.x)
	return center + away.normalized() * clearance - flat_from


## 캐릭터의 정면은 -Z 다.
static func _facing(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)


static func _controls(move: Vector2, yaw: float, pitch: float) -> Dictionary:
	return {"move": move, "yaw": yaw, "pitch": pitch, "jump": false, "crouch": false}
