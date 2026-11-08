extends RefCounted
## 라운드하우스 키트(2026-11-08): 블렌더 없이 코드로 "둥근 점토 느낌" 3D 모델을 깎는 도구. 디자인 담당 소유.
##
## [왜 만들었나] 사용자 지적(2026-11-08): "맵의 지형지물과 벽·창문·테이블 다리 등 전부 이상하다",
##   "폴리곤이 너무 많지 않은 게 우리 게임 장점이니 클레이 같은 느낌이지만 디테일은 필요".
##   기준 = 바탕화면 DARTY_프로젝트/2026-11-07_DARTY_디자인요청_프롬프트.md 2장 "부드러움은 폴리곤 수보다 구조에서 만든다".
##
## [원리 — 게임 아트에서 흔히 쓰는 방법 세 가지를 코드로 옮겼다]
##   1) 물레 깎기(lathe): 옆모습 선 하나를 Y축으로 한 바퀴 돌린다 → 테이블 기둥·스툴·전등갓·화분·병.
##   2) 단면 밀기(sweep): 단면 모양을 길을 따라 민다 → 몰딩·난간·아치 틀·천장 코브(벽과 천장을 잇는 곡면).
##   3) 부드러운 법선: 곡면은 매끈하게 보이고, 같은 점을 두 번 넣은 곳만 각진 모서리가 된다
##      (요청서 "곡면은 smooth normals, 평평한 상판·패널은 평면 유지").
##   + 점토 재질 clay(): 빛이 표면을 감싸 도는 확산(Lambert Wrap) + 약한 테두리 빛(rim) → 명암 경계가 부드러워
##      손으로 빚은 클레이 느낌이 난다. 화면 공간 그림자(SSAO)는 방 환경(game_room_builder._lighting)이 켠다.
##
## [옆모습·단면 점을 적는 규칙] (x 오른쪽, y 위) 평면에서 "재료가 왼쪽, 바깥이 오른쪽"이 되게 돈다.
##   - 물레 깎기: (반지름, 높이)를 바닥 가운데 → 바깥 → 위 → 윗면 가운데 순서로.
##   - 닫힌 단면: 반시계 방향.
##   이 순서를 지키면 법선(빛 받는 방향)이 저절로 바깥을 본다. 삼각형 앞뒤 순서는 법선을 보고 알아서 맞춘다.
## [저장 크기] 같은 모양은 한 번만 만든다(_cache) → 생성 장면(pub_game.tscn)에 메시가 한 벌만 저장된다.
##   점을 합쳐(index) 저장해 파일이 커지지 않게 한다. 반복 가구 한 개 = 수백~수천 삼각형(요청서 7.1 예산 안).

const MeshKit = preload("res://art/mesh_kit.gd")

static var _cache: Dictionary = {}


# ─────────────────────────────── 재질 ───────────────────────────────

## 점토 느낌 재질. MeshKit.material 과 같은 이름이면 같은 재질을 고쳐 쓴다(오락실 테마가 이름으로 색을 바꾼다 —
## game/lounge/lounge_world.gd _recolor). rough = 거칠기(높을수록 무광), metal = 금속(황동만), glow = 스스로 빛남.
static func clay(key: String, color: String, rough := 0.82, metal := 0.0, glow := 0.0) -> StandardMaterial3D:
	var material := MeshKit.material(key, color, metal, glow)
	# 같은 이름을 예전 도구(PubParts)가 먼저 만들었어도 이 색·거칠기로 맞춘다(요청서 2장 재질표 색).
	material.albedo_color = Color(color)
	material.roughness = rough
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	if metal < 0.3:
		# 테두리 빛: 물체 가장자리가 살짝 밝아져 둥근 부피가 읽힌다(점토 사진의 반사광 흉내).
		material.rim_enabled = true
		material.rim = 0.16
		material.rim_tint = 0.75
	return material


# ─────────────────────────────── 공용 계산 ───────────────────────────────

## 옆모습/단면 점마다 2D 법선(바깥 방향). 같은 점이 두 번 연달아 있으면 그 자리는 각진 모서리다.
static func _profile_normals(profile: PackedVector2Array, closed: bool) -> PackedVector2Array:
	var count := profile.size()
	var result := PackedVector2Array()
	for i in range(count):
		var here := profile[i]
		var back := Vector2.ZERO
		var ahead := Vector2.ZERO
		if closed or i > 0:
			back = here - profile[posmod(i - 1, count)]
		if closed or i < count - 1:
			ahead = profile[posmod(i + 1, count)] - here
		var tangent: Vector2
		if back.length() < 0.00001:
			tangent = ahead
		elif ahead.length() < 0.00001:
			tangent = back
		else:
			tangent = back.normalized() + ahead.normalized()
		# 진행 방향의 오른쪽 = 바깥(점 적는 규칙 참고).
		result.append(Vector2(tangent.y, -tangent.x).normalized())
	return result


## 사각형 하나(점 4개·법선 4개)를 삼각형 둘로. 법선 평균이 바깥이 되도록 앞뒤 순서를 맞춘다(Godot 앞면 = 시계 방향).
static func _quad(surface: SurfaceTool, points: Array[Vector3], normals: Array[Vector3], uvs: Array[Vector2]) -> void:
	for tri: Array in [[0, 1, 2], [0, 2, 3]]:
		var a: Vector3 = points[tri[0]]
		var b: Vector3 = points[tri[1]]
		var c: Vector3 = points[tri[2]]
		var face := (c - a).cross(b - a)
		if face.length_squared() < 1e-14:
			continue # 축 위에서 한 점으로 모인 삼각형(뚜껑 가운데)은 넓이가 0 이라 건너뛴다.
		var order: Array = tri
		if face.dot(normals[tri[0]] + normals[tri[1]] + normals[tri[2]]) < 0.0:
			order = [tri[0], tri[2], tri[1]]
		# UV(텍스처 좌표)는 저장하지 않는다(2026-11-08): 점토 재질은 단색이고 실행 중 메시 묶기(static_batch.gd)도 UV 를 버린다.
		# 그래야 index() 가 이음매의 점까지 합쳐 pub_game.tscn 이 작아진다. uvs 인자는 부르는 쪽 호환용으로 남긴다.
		for index: int in order:
			surface.set_normal(normals[index])
			surface.add_vertex(points[index])


static func _finish(key: String, surface: SurfaceTool) -> ArrayMesh:
	surface.index()
	var mesh := surface.commit()
	_cache[key] = mesh
	return mesh


# ─────────────────────────────── 1) 물레 깎기 ───────────────────────────────

## profile = (반지름, 높이) 점들(바닥 가운데 → 바깥 → 위 → 윗면 가운데). segments = 둘레 조각 수(24~40).
## arc < TAU 면 그 각도만큼만 돈다(반원 끝머리 같은 것) — 시작 0 = +X, Z 쪽으로 돈다.
static func lathe_mesh(profile: PackedVector2Array, segments := 32, arc := TAU) -> ArrayMesh:
	var key := "lathe|%s|%d|%.3f" % [profile, segments, arc]
	if _cache.has(key):
		return _cache[key]
	var normals := _profile_normals(profile, false)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var last := float(profile.size() - 1)
	for i in range(profile.size() - 1):
		var a := profile[i]
		var b := profile[i + 1]
		if a.distance_to(b) < 0.00001:
			continue
		for j in range(segments):
			var points: Array[Vector3] = []
			var norms: Array[Vector3] = []
			var uvs: Array[Vector2] = []
			for pick: Vector2i in [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]:
				var angle: float = arc * pick.y / segments
				var spot := profile[pick.x]
				var normal := normals[pick.x]
				var around := Vector3(cos(angle), 0.0, sin(angle))
				points.append(around * spot.x + Vector3.UP * spot.y)
				norms.append((around * normal.x + Vector3.UP * normal.y).normalized())
				uvs.append(Vector2(float(pick.y) / segments, pick.x / last))
			_quad(surface, points, norms, uvs)
	return _finish(key, surface)


## 물레 깎기 노드. pos = 바닥 가운데(부모 기준).
static func lathe(parent: Node, name_: String, profile: PackedVector2Array, pos: Vector3, mat: Material, segments := 32) -> MeshInstance3D:
	return MeshKit.mesh_node(parent, name_, lathe_mesh(profile, segments), pos, mat)


## 옆모습에 둥근 모서리 한 군데를 넣는다: corner 를 꼭짓점으로 a→corner→b 를 radius 로 깎은 점들(steps 조각).
## 옆모습 배열을 만들 때 꼭짓점 대신 이걸 이어 붙이면 모서리가 매끈해진다.
static func fillet(a: Vector2, corner: Vector2, b: Vector2, radius: float, steps := 4) -> PackedVector2Array:
	var into := (corner - a).normalized()
	var out := (b - corner).normalized()
	var reach := minf(radius, minf(corner.distance_to(a), corner.distance_to(b)) * 0.5)
	var start := corner - into * reach
	var finish := corner + out * reach
	var points := PackedVector2Array()
	for s in range(steps + 1):
		var t := float(s) / steps
		# 2차 베지어(start → corner → finish): 원호에 아주 가까운 부드러운 모서리.
		points.append(start.lerp(corner, t).lerp(corner.lerp(finish, t), t))
	return points


## 꼭짓점 목록을 받아 모든 모서리를 radius 로 둥글린 옆모습을 만든다(처음·끝 점은 그대로).
## sharp 에 넣은 번호의 꼭짓점은 둥글리지 않고 각진 모서리(점 두 번)로 둔다.
static func rounded_profile(corners: PackedVector2Array, radius: float, steps := 4, sharp: Array[int] = []) -> PackedVector2Array:
	var result := PackedVector2Array([corners[0]])
	for i in range(1, corners.size() - 1):
		if sharp.has(i):
			result.append(corners[i])
			result.append(corners[i])
		else:
			result.append_array(fillet(corners[i - 1], corners[i], corners[i + 1], radius, steps))
	result.append(corners[corners.size() - 1])
	return result


# ─────────────────────────────── 2) 단면 밀기 ───────────────────────────────

## 단면 밀기. rails[k] = [점, 단면 x 가 향할 3D 방향, 단면 y 가 향할 3D 방향] — 경로 한 점의 틀.
## closed_profile = 단면이 닫힌 고리인가(난간 관) / 열린 띠인가(벽에 붙는 몰딩). caps = 열린 경로 양 끝을 막는가.
static func sweep_mesh(key: String, profile: PackedVector2Array, rails: Array, closed_profile := true, caps := true) -> ArrayMesh:
	if _cache.has(key):
		return _cache[key]
	var normals := _profile_normals(profile, closed_profile)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := profile.size()
	var spans := count if closed_profile else count - 1
	for k in range(rails.size() - 1):
		for i in range(spans):
			var next := (i + 1) % count
			if profile[i].distance_to(profile[next]) < 0.00001:
				continue
			var points: Array[Vector3] = []
			var norms: Array[Vector3] = []
			var uvs: Array[Vector2] = []
			for pick: Vector2i in [Vector2i(k, i), Vector2i(k, next), Vector2i(k + 1, next), Vector2i(k + 1, i)]:
				var rail: Array = rails[pick.x]
				var spot := profile[pick.y]
				var normal := normals[pick.y]
				points.append(rail[0] + rail[1] * spot.x + rail[2] * spot.y)
				norms.append((rail[1] * normal.x + rail[2] * normal.y).normalized())
				uvs.append(Vector2(float(pick.x), float(pick.y) / count))
			_quad(surface, points, norms, uvs)
	if caps and closed_profile:
		var center := Vector2.ZERO
		for spot in profile:
			center += spot
		center /= count
		for end: int in [0, rails.size() - 1]:
			var rail: Array = rails[end]
			var other: Array = rails[1 if end == 0 else end - 1]
			var facing: Vector3 = (rail[0] - other[0]).normalized()
			var middle: Vector3 = rail[0] + rail[1] * center.x + rail[2] * center.y
			for i in range(count):
				var p: Vector2 = profile[i]
				var q: Vector2 = profile[(i + 1) % count]
				var points: Array[Vector3] = [middle, rail[0] + rail[1] * p.x + rail[2] * p.y, rail[0] + rail[1] * q.x + rail[2] * q.y, middle]
				var norms: Array[Vector3] = [facing, facing, facing, facing]
				_quad(surface, points, norms, [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	return _finish(key, surface)


## 곧은 길 a→b 의 틀 두 개. across = 단면 x 방향(예: 방 안쪽), up = 단면 y 방향.
static func line_rails(a: Vector3, b: Vector3, across: Vector3, up: Vector3) -> Array:
	return [[a, across, up], [b, across, up]]


## 벽 위의 2D 길(u = 벽을 따라, v = 위)을 3D 틀로 바꾼다. 단면 x = 벽에서 방 안쪽(inward), 단면 y = 길 옆 방향.
## origin = 벽 위 기준점, along = 벽을 따라가는 방향.
static func wall_path_rails(path: PackedVector2Array, origin: Vector3, along: Vector3, inward: Vector3) -> Array:
	var rails: Array = []
	for k in range(path.size()):
		var back := path[k] - path[maxi(k - 1, 0)]
		var ahead := path[mini(k + 1, path.size() - 1)] - path[k]
		var tangent2 := (back.normalized() if back.length() > 0.00001 else Vector2.ZERO) + (ahead.normalized() if ahead.length() > 0.00001 else Vector2.ZERO)
		var tangent: Vector3 = (along * tangent2.x + Vector3.UP * tangent2.y).normalized()
		var side: Vector3 = inward.cross(tangent).normalized()
		rails.append([origin + along * path[k].x + Vector3.UP * path[k].y, inward, side])
	return rails


## 아치 머리 틀의 길(벽 위 2D): 왼쪽 아래 → 위로 → 둥근 모서리 → 가로 → 둥근 모서리 → 오른쪽 아래.
## radius 가 폭의 절반이면 반원 아치, 작으면 모서리만 둥근 사각 아치.
static func arch_path(width: float, bottom: float, top: float, radius: float, steps := 8) -> PackedVector2Array:
	var half := width / 2.0
	var r := minf(radius, minf(half, top - bottom))
	var path := PackedVector2Array([Vector2(-half, bottom)])
	path.append_array(fillet(Vector2(-half, bottom), Vector2(-half, top), Vector2(half, top), r, steps))
	path.append_array(fillet(Vector2(-half, top), Vector2(half, top), Vector2(half, bottom), r, steps))
	path.append(Vector2(half, bottom))
	return path


## 반둥근 띠 단면(벽에 붙는 몰딩·틀): 깊이 depth(방 쪽으로 나온 정도) × 폭 width. 뒤(벽 쪽)는 열려 있다.
static func bead_profile(width: float, depth: float, steps := 4) -> PackedVector2Array:
	var half := width / 2.0
	return rounded_profile(PackedVector2Array([Vector2(0, -half), Vector2(depth, -half), Vector2(depth, half), Vector2(0, half)]), minf(depth, half) * 0.8, steps)


## 닫힌 둥근 사각 단면(가운데 = 원점, 반시계). 테이블 난간·의자 등받이처럼 사방이 둥근 띠에 쓴다.
static func rounded_rect_profile(size: Vector2, radius: float, steps := 4) -> PackedVector2Array:
	var half := size / 2.0
	var r := minf(radius, minf(half.x, half.y) - 0.0005)
	var points := PackedVector2Array()
	var corners: Array[Vector2] = [Vector2(half.x - r, half.y - r), Vector2(-half.x + r, half.y - r), Vector2(-half.x + r, -half.y + r), Vector2(half.x - r, -half.y + r)]
	for c in range(4):
		for s in range(steps + 1):
			var angle := c * PI / 2.0 + (PI / 2.0) * s / steps
			points.append(corners[c] + Vector2(cos(angle), sin(angle)) * r)
	return points


## 동그란 관 단면(난간·발받침·전선).
static func circle_profile(radius: float, sides := 12) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(sides):
		var angle := TAU * i / sides
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


## 원 둘레를 도는 관(테이블 테두리·스툴 발받침 고리). 고리는 XZ 평면, 가운데 = 원점.
## profile 의 x = 바깥(반지름) 방향, y = 위.
static func ring_mesh(key: String, ring_radius: float, profile: PackedVector2Array, segments := 48) -> ArrayMesh:
	var rails: Array = []
	for k in range(segments + 1):
		var angle := TAU * k / segments
		var out := Vector3(cos(angle), 0.0, sin(angle))
		rails.append([out * ring_radius, out, Vector3.UP])
	return sweep_mesh("ring|%s|%.3f|%d" % [key, ring_radius, segments], profile, rails, true, false)


# ─────────────────────────────── 3) 판·띠 모양 ───────────────────────────────

## 세로 골이 진 누빔 판(바 앞면·벽 아래 징두리의 가죽 패딩 — 요청서 콘셉트 01 의 청록 누빔 벽).
## 크기 length(벽을 따라) × height, 골 하나 폭 channel, 가장 볼록한 곳 depth. 앞면 = +Z, 바닥 가운데 = 원점.
## 같은 길이는 한 번만 만든다 → 긴 벽은 이 판을 여러 장 이어 붙인다(game_room_builder._wainscot).
static func channel_panel_mesh(length: float, height: float, channel: float, depth: float) -> ArrayMesh:
	var key := "channel|%.3f|%.3f|%.3f|%.3f" % [length, height, channel, depth]
	if _cache.has(key):
		return _cache[key]
	var count := maxi(roundi(length / channel), 1)
	var width := length / count
	var columns := 6
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for c in range(count):
		var left := -length / 2.0 + c * width
		for s in range(columns):
			var points: Array[Vector3] = []
			var norms: Array[Vector3] = []
			var uvs: Array[Vector2] = []
			for pick: Vector2i in [Vector2i(s, 0), Vector2i(s + 1, 0), Vector2i(s + 1, 1), Vector2i(s, 1)]:
				# 골 하나 = 반원에 가까운 볼록 띠(sin), 이음매에서 0 → 골 사이가 오목하게 접힌다.
				var t := float(pick.x) / columns
				var bulge := sin(t * PI)
				var slope := cos(t * PI) * PI / width * depth
				points.append(Vector3(left + t * width, height * pick.y, depth * pow(bulge, 0.6)))
				norms.append(Vector3(-slope * (0.6 * pow(maxf(bulge, 0.05), -0.4)), 0.0, 1.0).normalized())
				uvs.append(Vector2(t, float(pick.y)))
			_quad(surface, points, norms, uvs)
	return _finish(key, surface)


## 모서리가 둥근 판(위에서 보면 둥근 사각형). size = 가로(X)·세로(Z), 두께 thickness, 바닥 = y 0.
## 테이블 위 자리 매트·바 윗면처럼 "위에서 본 모서리"가 둥글어야 하는 것에 쓴다(rounded_box 는 두께가 얇으면 못 둥글린다).
static func rounded_slab_mesh(size: Vector2, thickness: float, radius: float, steps := 6) -> ArrayMesh:
	var key := "slab|%s|%.4f|%.3f|%d" % [size, thickness, radius, steps]
	if _cache.has(key):
		return _cache[key]
	var half := size / 2.0
	var r := minf(radius, minf(half.x, half.y) - 0.001)
	var outline := PackedVector2Array()
	# 반시계(위에서 볼 때 x 오른쪽, z 아래 → 2D (x, z)): 네 모서리를 r 로 둥글린다.
	var corners: Array[Vector2] = [Vector2(half.x - r, half.y - r), Vector2(-half.x + r, half.y - r), Vector2(-half.x + r, -half.y + r), Vector2(half.x - r, -half.y + r)]
	for c in range(4):
		var corner := corners[c]
		var start := c * PI / 2.0 # 오른쪽 위 모서리는 0°→90°, 왼쪽 위는 90°→180° …
		for s in range(steps + 1):
			var angle := start + (PI / 2.0) * s / steps
			outline.append(corner + Vector2(cos(angle), sin(angle)) * r)
	var rails := [[Vector3.ZERO, Vector3.RIGHT, Vector3.BACK], [Vector3.UP * thickness, Vector3.RIGHT, Vector3.BACK]]
	return sweep_mesh(key, outline, rails, true, true)


## 위에서 본 테두리(outline, 2D x·z 반시계)를 두께만큼 위로 세운 판(바닥 = y 0). 자리 깔개·러그·문 매트.
static func slab_mesh(key: String, outline: PackedVector2Array, thickness: float) -> ArrayMesh:
	var rails := [[Vector3.ZERO, Vector3.RIGHT, Vector3.BACK], [Vector3.UP * thickness, Vector3.RIGHT, Vector3.BACK]]
	return sweep_mesh("slab|" + key, outline, rails, true, true)


## 앞에서 본 테두리(outline, 2D x 오른쪽·y 위, 반시계)를 두께만큼 앞(+Z)으로 낸 판(뒷면 = z 0). 문짝·액자 그림 조각.
static func panel_mesh(key: String, outline: PackedVector2Array, thickness: float) -> ArrayMesh:
	var rails := [[Vector3.ZERO, Vector3.RIGHT, Vector3.UP], [Vector3.BACK * thickness, Vector3.RIGHT, Vector3.UP]]
	return sweep_mesh("panel|" + key, outline, rails, true, true)


## 닫힌 다각형(반시계)의 꼭짓점마다 반지름 radii[i] 로 둥글린 테두리. radii[i] = 0 이면 그 꼭짓점은 각지게 둔다.
static func rounded_polygon(points: PackedVector2Array, radii: PackedFloat32Array, steps := 5) -> PackedVector2Array:
	var count := points.size()
	var result := PackedVector2Array()
	for i in range(count):
		var before := points[posmod(i - 1, count)]
		var here := points[i]
		var after := points[(i + 1) % count]
		if radii[i] <= 0.0:
			result.append(here)
		else:
			var curve := fillet(before, here, after, radii[i], steps)
			# 마지막 점은 다음 모서리 시작과 겹치지 않게 그대로 둔다(직선 구간이 생긴다).
			result.append_array(curve)
	return result


## 정다각형(자리 깔개 모양: 3 = 세모, 4 = 네모, 12 이상 = 원) 테두리. 첫 꼭짓점이 +Z(2D +y)를 본다 —
## 예전 원기둥 깔개(CylinderMesh 첫 꼭짓점 = +Z)와 같은 방향이라 자리 기호 방향이 그대로다.
static func regular_outline(sides: int, radius: float, corner: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count := sides if sides < 12 else 48
	for k in range(count):
		var angle := PI / 2.0 + TAU * k / count
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	if sides >= 12:
		return points
	var radii := PackedFloat32Array()
	radii.resize(count)
	radii.fill(corner)
	return rounded_polygon(points, radii, 5)


## 매끈한 공(당구공·문고리·전구). 가운데 = 원점.
static func sphere_mesh(radius: float, segments := 16) -> ArrayMesh:
	var profile := PackedVector2Array()
	var rings := maxi(segments / 2, 4)
	for i in range(rings + 1):
		var angle := -PI / 2.0 + PI * i / rings
		profile.append(Vector2(cos(angle) * radius, sin(angle) * radius))
	profile[0] = Vector2(0.0, -radius)
	profile[rings] = Vector2(0.0, radius)
	return lathe_mesh(profile, segments)


## 평평한 볼록 도형(아치 창 유리 같은 것). outline = 2D 테두리(x 오른쪽, y 위), 앞면 = +Z.
static func flat_shape_mesh(key: String, outline: PackedVector2Array) -> ArrayMesh:
	if _cache.has(key):
		return _cache[key]
	var center := Vector2.ZERO
	for spot in outline:
		center += spot
	center /= outline.size()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(outline.size()):
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		var points: Array[Vector3] = [Vector3(center.x, center.y, 0), Vector3(a.x, a.y, 0), Vector3(b.x, b.y, 0), Vector3(center.x, center.y, 0)]
		var uvs: Array[Vector2] = [center, a, b, center]
		_quad(surface, points, [Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK], uvs)
	return _finish(key, surface)


## 꺾인 길을 따라가는 매끈한 관(밧줄·발받침·전선·큐대). points = 3D 길, radius = 관 반지름.
static func tube_mesh(key: String, points: PackedVector3Array, radius: float, sides := 10) -> ArrayMesh:
	var rails: Array = []
	for k in range(points.size()):
		var ahead := points[mini(k + 1, points.size() - 1)] - points[maxi(k - 1, 0)]
		var tangent := ahead.normalized()
		var helper := Vector3.UP if absf(tangent.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
		var across := tangent.cross(helper).normalized()
		var up := across.cross(tangent).normalized()
		rails.append([points[k], across, up])
	return sweep_mesh("tube|%s|%s|%.4f|%d" % [key, points, radius, sides], circle_profile(radius, sides), rails, true, true)


## 점 a 에서 b 까지 매끈한 막대(다리·기둥·탭 손잡이). MeshKit.rod 는 각진 8각이라 가구에서는 이걸 쓴다.
## top_radius 를 주면 끝이 가늘어지는 다리(테이퍼)가 된다.
static func rod(parent: Node, name_: String, a: Vector3, b: Vector3, radius: float, mat: Material, top_radius := -1.0, sides := 14) -> MeshInstance3D:
	var length := a.distance_to(b)
	var tip: float = radius if top_radius < 0.0 else top_radius
	var profile := PackedVector2Array([Vector2(0, 0), Vector2(radius, 0), Vector2(radius, 0), Vector2(tip, length), Vector2(tip, length), Vector2(0, length)])
	var node := MeshKit.mesh_node(parent, name_, lathe_mesh(profile, sides), a, mat)
	var direction := (b - a).normalized()
	var axis := Vector3.UP.cross(direction)
	if axis.length() > 0.0001:
		node.quaternion = Quaternion(axis.normalized(), Vector3.UP.angle_to(direction))
	elif direction.y < 0.0:
		node.rotation.x = PI
	return node


## 여러 메시를 하나로 합친다(같은 재질 조각을 한 번에 그리게). parts = [[메시, Transform3D], ...].
static func merge(key: String, parts: Array) -> ArrayMesh:
	if _cache.has(key):
		return _cache[key]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part: Array in parts:
		surface.append_from(part[0], 0, part[1])
	return _finish(key, surface)
