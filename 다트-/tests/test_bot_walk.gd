extends SceneTree
## 봇 걸음 길찾기(BotDriver.walk_controls) 검사 — 2026-11-17 밤 사용자 지적
## "4번 봇이 앞에 나와 방해하는 거까지는 잘 되는데 하다가 좌우로 움직이며 버그가 걸렸네".
##   & $godot --headless --path . --script res://tests/test_bot_walk.gd
## 원인이던 것: 펜스 제거(2026-11-12) 뒤 몸막 판정(TableView.in_block_zone)이 투척선 앞 다트 홀 전체가 됐는데,
## 길찾기는 "몸막 구역에서 나갈 때 먼저 옆으로 빠진다"를 그대로 써서 옆으로 빠져도 여전히 구역 안 →
## 중간 목표가 지금 자리 → 그 자리를 넘었다 돌아왔다 하며 좌우로 떨고 투척선·자리에 영영 못 갔다.
## 여기서는 PlayerView.simulate 와 같은 걸음(정면 −Z, PlayerView.SPEED)으로 위치만 굴려
## 방해·헤클링 자리 ↔ 투척선·자리를 정해진 시간 안에 오가는지 본다(벽·충돌 없이 길찾기 계산만).

const BotDriver = preload("res://game/player/bot_driver.gd")
const BotSocial = preload("res://game/player/bot_social.gd")
const STEP: float = 1.0 / 60.0
## 곧은 길보다 이만큼 더 걸리면 길을 잃은 것으로 본다(테이블 돌아가기 여유 포함).
const SLACK_SECONDS: float = 4.0

var _failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var block: Vector3 = TableView.block_spot()
	var starts: Dictionary = {
		"몸막 자리": block,
		"몸막 자리 왼쪽 문": Vector3(-BotSocial.HECKLE_SIDE, 0, block.z),
		"몸막 자리 오른쪽 문": Vector3(BotSocial.HECKLE_SIDE, 0, block.z),
		"헤클링 왼쪽": Vector3(-BotSocial.HECKLE_SIDE, 0, BotSocial.HECKLE_DEPTH),
		"헤클링 오른쪽": Vector3(BotSocial.HECKLE_SIDE, 0, BotSocial.HECKLE_DEPTH),
		"과녁 바로 앞": Vector3(0.4, 0, TableView.BLOCK_ZONE.x - 1.0),
		"투척선 바로 앞 옆": Vector3(-2.5, 0, TableView.THROW_LINE_Z - 0.3),
	}
	var goals: Dictionary = {"투척선": BotDriver.throw_spot()}
	for seat in range(TableView.SEATS.size()):
		goals["%d번 자리" % (seat + 1)] = TableView.seat_spot(seat)
	for start_name: String in starts:
		for goal_name: String in goals:
			_walk(start_name + " → " + goal_name, starts[start_name], goals[goal_name])
	# 반대 방향: 자리에서 일어나 헤클링·몸막 자리로 나간다(BotSocial._heckle 의 두 걸음과 같은 순서).
	for seat in range(TableView.SEATS.size()):
		var up: Vector3 = TableView.standing_spot(seat)
		var side: float = 1.0 if TableView.seat_spot(seat).x >= 0.0 else -1.0
		var gate := Vector3(side * BotSocial.HECKLE_SIDE, 0, block.z)
		var at: Vector3 = _walk("%d번 자리 → 몸막 문" % (seat + 1), up, gate)
		_walk("%d번 몸막 문 → 몸막 자리" % (seat + 1), at, block)
		_walk("%d번 자리 → 헤클링" % (seat + 1), up, Vector3(side * BotSocial.HECKLE_SIDE, 0, BotSocial.HECKLE_DEPTH))
	print("BOT WALK %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)


## from 에서 goal 까지 봇 조작대로 걷는다. 시간 안에 닿지 못하면 FAIL(마지막 자리와 좌우로 떤 횟수를 적는다).
func _walk(label: String, from: Vector3, goal: Vector3) -> Vector3:
	var at: Vector3 = Vector3(from.x, 0, from.z)
	var limit: float = Vector2(goal.x - at.x, goal.z - at.z).length() / PlayerView.SPEED + SLACK_SECONDS
	var time: float = 0.0
	var flips: int = 0
	var last_dx: float = 0.0
	while not BotDriver.arrived(at, goal):
		if time > limit:
			_failed = true
			print("FAIL %s: %.1f초 안에 못 감 — 멈춘 자리 (%.2f, %.2f), 좌우 방향 바뀜 %d번" % [label, limit, at.x, at.z, flips])
			return at
		var controls: Dictionary = BotDriver.walk_controls(at, goal)
		var axis: Vector2 = controls.move
		var step: Vector3 = Basis(Vector3.UP, float(controls.yaw)) * Vector3(axis.x, 0, axis.y) * PlayerView.SPEED * STEP
		if step.x * last_dx < 0.0:
			flips += 1
		if absf(step.x) > 0.0001:
			last_dx = step.x
		at += step
		time += STEP
	return at
