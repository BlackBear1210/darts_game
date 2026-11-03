extends RefCounted
## 날아가는 다트가 사람 몸에 맞았는지 보는 판정. F5 실제 경기(GameView.solve_dart)와
## F6 카드 라운드 시연(game/card_round/rules/dart_solver.gd)이 같은 몸 크기를 쓰도록 여기 한 곳에 둔다.
##
## 몸 = 발에서 머리끝까지 세운 캡슐(큰 머리 포함). 던진 사람은 목록에서 빼고 넘긴다.
## 캐릭터는 다트 판정 광선(층 1)에 없다 — 몸 맞기는 이 계산으로만 난다.

const RADIUS: float = 0.3
const BOTTOM: float = 0.15
const TOP: float = 1.75


## previous → point 한 구간에서 처음 맞는 몸. bodies = [{"position": 발 밑 좌표, ...}] (순서대로 본다).
## 맞으면 {"index", "point", "ratio"}(ratio = 구간 안에서 맞은 지점 비율), 아니면 빈 사전.
static func first(previous: Vector3, point: Vector3, bodies: Array) -> Dictionary:
	for index in range(bodies.size()):
		var base: Vector3 = bodies[index].position
		var closest: PackedVector3Array = Geometry3D.get_closest_points_between_segments(previous, point,
			base + Vector3.UP * BOTTOM, base + Vector3.UP * TOP)
		if closest[0].distance_to(closest[1]) <= RADIUS:
			var ratio: float = previous.distance_to(closest[0]) / maxf(previous.distance_to(point), 0.0001)
			return {"index": index, "point": closest[0], "ratio": ratio}
	return {}
