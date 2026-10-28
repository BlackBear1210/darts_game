extends RefCounted
## 카드 라운드 시연의 다트 비행 판정. 실제 경기(GameView.solve_dart)와 같은 운동식을 쓰고,
## 시연에서는 캐릭터 몸에도 맞는다(방해하는 사람이 몸으로 막기 · 다른 사람 맞히기 → 스턴).
## 결과 kind: "board"(과녁 평면 도착) · "body"(사람) · "wall"(벽·바닥·테이블) · "none"(비행 제한).

const DART_CONFIG: DartConfig = preload("res://game/dart/default_dart.tres")
## 사람 몸 판정 = 발에서 머리끝까지 세운 캡슐(큰 머리 포함).
const BODY_RADIUS: float = 0.3
const BODY_BOTTOM: float = 0.15
const BODY_TOP: float = 1.75
const STEP: float = 1.0 / 120.0


## start 에서 aim_point 를 보고 charge(0~1)로 던진다. 최대 충전이면 aim_point 에 도착하고 약하면 아래로 떨어진다.
## plane_z = 도착 판정 평면(과녁·벌칙 과녁). bodies = [{seat, position}] (던진 사람은 빼고 넘긴다).
static func solve(space: PhysicsDirectSpaceState3D, start: Vector3, aim_point: Vector3, charge: float, plane_z: float, bodies: Array) -> Dictionary:
	var speed: float = lerpf(DART_CONFIG.minimum_speed, DART_CONFIG.maximum_speed, clampf(charge, 0.0, 1.0))
	var direction: Vector3 = (aim_point - start).normalized()
	var nominal_time: float = start.distance_to(aim_point) / DART_CONFIG.maximum_speed
	var initial: Vector3 = direction * speed + Vector3.UP * DART_CONFIG.gravity * nominal_time * 0.5
	var plane_time: float = (plane_z - start.z) / initial.z if absf(initial.z) > 0.001 else INF
	var previous: Vector3 = start
	var previous_time: float = 0.0
	while previous_time < DART_CONFIG.flight_limit:
		var time: float = minf(previous_time + STEP, DART_CONFIG.flight_limit)
		var crosses: bool = plane_time > previous_time and plane_time <= time
		if crosses:
			time = plane_time
		var point: Vector3 = DART_CONFIG.position_at(start, initial, time)
		for body: Dictionary in bodies:
			var base: Vector3 = body.position
			var closest: PackedVector3Array = Geometry3D.get_closest_points_between_segments(previous, point,
				base + Vector3.UP * BODY_BOTTOM, base + Vector3.UP * BODY_TOP)
			if closest[0].distance_to(closest[1]) <= BODY_RADIUS:
				var ratio: float = previous.distance_to(closest[0]) / maxf(previous.distance_to(point), 0.0001)
				return _result("body", start, closest[0], lerpf(previous_time, time, ratio), int(body.seat))
		if space != null:
			var query := PhysicsRayQueryParameters3D.create(previous, point, 1)
			var hit: Dictionary = space.intersect_ray(query)
			if not hit.is_empty():
				var ratio: float = previous.distance_to(hit.position) / maxf(previous.distance_to(point), 0.0001)
				return _result("wall", start, hit.position, lerpf(previous_time, time, ratio), -1)
		if crosses:
			return _result("board", start, point, time, -1)
		previous = point
		previous_time = time
	return _result("none", start, previous, DART_CONFIG.flight_limit, -1)


## 던지기 결과 한 묶음(kind = 맞은 곳 종류, point = 맞은 점, time = 날아가는 시간, seat = 맞은 사람).
static func _result(kind: String, start: Vector3, point: Vector3, time: float, seat: int) -> Dictionary:
	return {"kind": kind, "start": start, "point": point, "time": maxf(time, 0.02), "seat": seat}
