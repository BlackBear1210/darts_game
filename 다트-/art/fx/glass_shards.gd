extends RefCounted
## 깨진 유리병 파편 모양을 코드로 만든다(2026-10-31 사용자 요청 — 예전엔 똑같은 네모 상자 22개가 튀어서 부자연스러웠다).
## 실제 병이 깨지는 모양을 따른다:
##   몸통 벽 = 각도·높이로 어긋나게 잘린 "휜" 조각(사다리꼴과 삼각형이 섞인다, 두께가 있어 모서리가 빛난다)
##   목     = 어깨 일부까지 붙은 채 들쭉날쭉한 고리로 남는다(병목만 통째로 굴러가는 그 모양)
##   바닥   = 낮은 컵 모양으로 남는다(가장자리가 이빨처럼 깨진 바닥)
##   라벨   = 종이 띠가 두세 조각으로 찢어져 팔랑 떨어진다
##   뚜껑   = 따로 튕겨 나간다
## 크기는 game/lounge/prop_looks.gd 의 병(몸통 반지름 0.07m·높이 0.2m, 목 반지름 0.026m)에 맞췄다.
## 보이기만 하는 모양이다. 판정·네트워크와 무관하다(BurstFx 가 화면마다 각자 만든다).

const BODY_RADIUS: float = 0.07
const BODY_BOTTOM: float = -0.13
const BODY_TOP: float = 0.07
## 어깨(몸통 → 목으로 좁아지는 곳)와 목.
const SHOULDER_TOP: float = 0.13
const NECK_RADIUS: float = 0.026
const NECK_TOP: float = 0.22
const LABEL_RADIUS: float = 0.072
const LABEL_BOTTOM: float = -0.06
const LABEL_TOP: float = 0.02
## 유리 두께(m). 실제 병(3~4mm)과 같게. 종이는 아주 얇다.
const GLASS_THICKNESS: float = 0.004
const PAPER_THICKNESS: float = 0.0008
## 몸통 벽을 자르는 칸 수(둘레 × 높이). 칸마다 모서리 점을 흔들어 조각 모양이 매번 다르다.
const SECTORS: int = 7
const BANDS: int = 3
## 사다리꼴 칸을 대각선으로 한 번 더 잘라 삼각형 두 개로 만들 확률.
const SPLIT_CHANCE: float = 0.5
## 휜 면을 따라가도록 조각 테두리 한 변을 몇 번 나눌지.
const EDGE_STEPS: int = 3


## 병 한 개의 파편 목록. 각 원소:
##   mesh   = ArrayMesh(조각 원점 = 조각 가운데)
##   origin = 병 원점 기준 조각 가운데 위치(m)
##   basis  = 병 기준 조각 방향(이 방향으로 놓으면 원래 병 모양이 된다)
##   lie    = 바닥에 누웠을 때의 회전(x, z — y 는 그대로). lift = 누웠을 때 바닥에서 원점까지 높이(m)
##   kind   = "glass" | "paper" | "cap" — BurstFx 가 재질을 고른다
static func pieces(rng: RandomNumberGenerator) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var grid := _jittered_grid(rng)
	for i in range(SECTORS):
		for j in range(BANDS):
			var a: Vector2 = grid[i][j]
			var b: Vector2 = grid[i + 1][j]
			var c: Vector2 = grid[i + 1][j + 1]
			var d: Vector2 = grid[i][j + 1]
			if rng.randf() < SPLIT_CHANCE:
				# 어느 대각선으로 자를지도 무작위 → 긴 삼각형·뾰족한 조각이 섞인다.
				if rng.randf() < 0.5:
					result.append(_wall_piece([a, b, c], BODY_RADIUS, GLASS_THICKNESS, "glass", rng))
					result.append(_wall_piece([a, c, d], BODY_RADIUS, GLASS_THICKNESS, "glass", rng))
				else:
					result.append(_wall_piece([a, b, d], BODY_RADIUS, GLASS_THICKNESS, "glass", rng))
					result.append(_wall_piece([b, c, d], BODY_RADIUS, GLASS_THICKNESS, "glass", rng))
			else:
				result.append(_wall_piece([a, b, c, d], BODY_RADIUS, GLASS_THICKNESS, "glass", rng))
	result.append(_neck_piece(rng))
	result.append(_base_piece(rng))
	# 라벨 종이: 둘레의 일부만 2~3조각으로 찢어진다(나머지는 유리에 붙어 같이 흩어졌다고 본다).
	var start: float = rng.randf() * TAU
	for n in range(rng.randi_range(2, 3)):
		var a0: float = start + n * 1.3 + rng.randf_range(0.0, 0.3)
		var a1: float = a0 + rng.randf_range(0.6, 1.1)
		var outline: Array[Vector2] = [Vector2(a0, LABEL_BOTTOM + rng.randf_range(0.0, 0.015)), Vector2(a1, LABEL_BOTTOM + rng.randf_range(0.0, 0.015)),
			Vector2(a1 + rng.randf_range(-0.15, 0.15), LABEL_TOP - rng.randf_range(0.0, 0.02)), Vector2(a0 + rng.randf_range(-0.15, 0.15), LABEL_TOP - rng.randf_range(0.0, 0.02))]
		result.append(_wall_piece(outline, LABEL_RADIUS, PAPER_THICKNESS, "paper", rng))
	result.append({"mesh": _cap_mesh(), "origin": Vector3(0, NECK_TOP + 0.01, 0), "basis": Basis.IDENTITY,
		"lie": Vector2.ZERO, "lift": 0.011, "kind": "cap"})
	return result


## 몸통 벽 칸의 모서리 점 표(둘레 SECTORS+1 × 높이 BANDS+1, x = 각도, y = 높이). 마지막 둘레 줄은 첫 줄과 같아 빈틈이 없다.
## 위·아래 끝줄은 목·바닥 조각의 깨진 선과 대충 맞도록 조금만 흔든다.
static func _jittered_grid(rng: RandomNumberGenerator) -> Array:
	var grid: Array = []
	var step: float = TAU / SECTORS
	var bottom: float = BODY_BOTTOM + 0.035
	for i in range(SECTORS + 1):
		var column: Array[Vector2] = []
		for j in range(BANDS + 1):
			var ratio: float = float(j) / BANDS
			var height: float = lerpf(bottom, BODY_TOP, ratio)
			var wobble: float = 0.012 if j == 0 or j == BANDS else 0.024
			column.append(Vector2(i * step + rng.randf_range(-0.3, 0.3) * step, height + rng.randf_range(-wobble, wobble)))
		grid.append(column)
	for j in range(BANDS + 1):
		grid[SECTORS][j] = Vector2(grid[0][j].x + TAU, grid[0][j].y)
	return grid


## 원통 벽 위의 다각형(outline: x = 각도, y = 높이) 한 조각. 바깥면·안쪽면·옆 모서리가 있는 휜 판이다.
## 조각 좌표: X = 둘레 방향, Y = 바깥(병 중심에서 밖으로), Z = X × Y. 바닥에 Y 가 위로 누우면 볼록한 면이 위다.
static func _wall_piece(outline: Array, radius: float, thickness: float, kind: String, rng: RandomNumberGenerator) -> Dictionary:
	var center := Vector2.ZERO
	for point: Vector2 in outline:
		center += point
	center /= outline.size()
	var tangent := Vector3(cos(center.x), 0, -sin(center.x))
	var normal := Vector3(sin(center.x), 0, cos(center.x))
	var frame := Basis(tangent, normal, tangent.cross(normal))
	var origin := _on_cylinder(center, radius)
	var to_local := frame.inverse()
	# 테두리를 잘게 나눠 휜 면을 따라가게 한다.
	var ring: Array[Vector2] = []
	for k in range(outline.size()):
		var from: Vector2 = outline[k]
		var to: Vector2 = outline[(k + 1) % outline.size()]
		for s in range(EDGE_STEPS):
			ring.append(from.lerp(to, float(s) / EDGE_STEPS))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)  # 면마다 납작한 법선 → 깨진 유리처럼 면이 따로따로 반짝인다
	var outer_center: Vector3 = to_local * (_on_cylinder(center, radius) - origin)
	var inner_center: Vector3 = to_local * (_on_cylinder(center, radius - thickness) - origin)
	for k in range(ring.size()):
		var p0: Vector2 = ring[k]
		var p1: Vector2 = ring[(k + 1) % ring.size()]
		var o0: Vector3 = to_local * (_on_cylinder(p0, radius) - origin)
		var o1: Vector3 = to_local * (_on_cylinder(p1, radius) - origin)
		var i0: Vector3 = to_local * (_on_cylinder(p0, radius - thickness) - origin)
		var i1: Vector3 = to_local * (_on_cylinder(p1, radius - thickness) - origin)
		_triangle(tool, outer_center, o0, o1)
		_triangle(tool, inner_center, i1, i0)
		_triangle(tool, o0, i0, i1)
		_triangle(tool, o0, i1, o1)
	tool.generate_normals()
	var lie := Vector2(0.0 if rng.randf() < 0.5 else PI, 0.0)
	return {"mesh": tool.commit(), "origin": origin, "basis": frame, "lie": lie, "lift": thickness, "kind": kind}


## 병목 + 어깨 일부. 아래 가장자리가 들쭉날쭉한 고리. 바닥에서는 옆으로 누워 구른다.
static func _neck_piece(rng: RandomNumberGenerator) -> Dictionary:
	var segments: int = 12
	var breaks: Array[float] = []
	for k in range(segments):
		breaks.append(rng.randf_range(BODY_TOP + 0.012, SHOULDER_TOP - 0.008))
	var mid: float = (BODY_TOP + NECK_TOP) * 0.5
	var mesh := _tube(breaks, func(_k: int) -> float: return NECK_TOP, func(h: float) -> float: return _neck_radius(h), Vector3(0, mid, 0), false)
	# 옆으로 누우면 넓은 어깨 쪽이 조금 더 높다 → 목 반지름과 어깨 반지름 사이 높이로 띄운다.
	return {"mesh": mesh, "origin": Vector3(0, mid, 0), "basis": Basis.IDENTITY, "lie": Vector2(0.0, PI / 2), "lift": 0.038, "kind": "glass"}


## 바닥 컵: 바닥판 + 이빨처럼 깨진 낮은 벽. 바닥에 똑바로 선다.
static func _base_piece(rng: RandomNumberGenerator) -> Dictionary:
	var segments: int = 14
	var tops: Array[float] = []
	for k in range(segments):
		# 이빨 모양: 높고 낮은 곳이 번갈아 나온다.
		tops.append(BODY_BOTTOM + (rng.randf_range(0.03, 0.055) if k % 2 == 0 else rng.randf_range(0.012, 0.03)))
	var bottoms: Array[float] = []
	bottoms.resize(segments)
	bottoms.fill(BODY_BOTTOM)
	var mesh := _tube(bottoms, func(k: int) -> float: return tops[k], func(_h: float) -> float: return BODY_RADIUS, Vector3(0, BODY_BOTTOM, 0), true)
	return {"mesh": mesh, "origin": Vector3(0, BODY_BOTTOM, 0), "basis": Basis.IDENTITY, "lie": Vector2.ZERO, "lift": 0.0, "kind": "glass"}


## 어깨에서 목까지 좁아지는 반지름.
static func _neck_radius(height: float) -> float:
	if height >= SHOULDER_TOP:
		return NECK_RADIUS
	return lerpf(BODY_RADIUS * 0.92, NECK_RADIUS, smoothstep(BODY_TOP, SHOULDER_TOP, height))


## 둘레를 bottoms.size() 칸으로 나눈 관(고리). 칸 k 의 아래 높이 = bottoms[k], 위 높이 = top_of.call(k), 반지름 = radius_of.call(높이).
## closed_bottom = true 면 아래를 바닥판으로 막는다(병 바닥). origin 을 빼서 조각 원점으로 옮긴다.
static func _tube(bottoms: Array[float], top_of: Callable, radius_of: Callable, origin: Vector3, closed_bottom: bool) -> ArrayMesh:
	var segments: int = bottoms.size()
	var rows: int = 3
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)
	for k in range(segments):
		var next: int = (k + 1) % segments
		var a0: float = TAU * k / segments
		var a1: float = TAU * (k + 1) / segments
		for r in range(rows):
			var s0: float = float(r) / rows
			var s1: float = float(r + 1) / rows
			var h00: float = lerpf(bottoms[k], top_of.call(k), s0)
			var h01: float = lerpf(bottoms[k], top_of.call(k), s1)
			var h10: float = lerpf(bottoms[next], top_of.call(next), s0)
			var h11: float = lerpf(bottoms[next], top_of.call(next), s1)
			for inset: float in [0.0, GLASS_THICKNESS]:
				var p00: Vector3 = _ring_point(a0, h00, radius_of.call(h00) - inset) - origin
				var p01: Vector3 = _ring_point(a0, h01, radius_of.call(h01) - inset) - origin
				var p10: Vector3 = _ring_point(a1, h10, radius_of.call(h10) - inset) - origin
				var p11: Vector3 = _ring_point(a1, h11, radius_of.call(h11) - inset) - origin
				_triangle(tool, p00, p10, p11)
				_triangle(tool, p00, p11, p01)
		# 위·아래 가장자리 두께 면(깨진 단면이 반짝이는 곳).
		for edge in [[bottoms[k], bottoms[next]], [top_of.call(k), top_of.call(next)]]:
			var o0: Vector3 = _ring_point(a0, edge[0], radius_of.call(edge[0])) - origin
			var o1: Vector3 = _ring_point(a1, edge[1], radius_of.call(edge[1])) - origin
			var i0: Vector3 = _ring_point(a0, edge[0], radius_of.call(edge[0]) - GLASS_THICKNESS) - origin
			var i1: Vector3 = _ring_point(a1, edge[1], radius_of.call(edge[1]) - GLASS_THICKNESS) - origin
			_triangle(tool, o0, i0, i1)
			_triangle(tool, o0, i1, o1)
		if closed_bottom:
			var center: Vector3 = Vector3(0, bottoms[k], 0) - origin
			_triangle(tool, center, _ring_point(a1, bottoms[k], radius_of.call(bottoms[k])) - origin, _ring_point(a0, bottoms[k], radius_of.call(bottoms[k])) - origin)
	tool.generate_normals()
	return tool.commit()


## 금색 뚜껑(작은 원통). 깨질 때 튕겨 나가 바닥을 구른다.
static func _cap_mesh() -> CylinderMesh:
	var cap := CylinderMesh.new()
	cap.top_radius = 0.03
	cap.bottom_radius = 0.03
	cap.height = 0.022
	cap.radial_segments = 10
	cap.rings = 1
	return cap


## 원통 위 한 점(x = 각도, y = 높이). 각도 0 = +Z 쪽.
static func _on_cylinder(point: Vector2, radius: float) -> Vector3:
	return Vector3(sin(point.x) * radius, point.y, cos(point.x) * radius)


static func _ring_point(angle: float, height: float, radius: float) -> Vector3:
	return Vector3(sin(angle) * radius, height, cos(angle) * radius)


static func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	tool.add_vertex(a)
	tool.add_vertex(b)
	tool.add_vertex(c)
