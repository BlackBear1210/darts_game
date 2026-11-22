extends RefCounted
## 다트판 그림(실제 펍 다트판 모양). 쇼케이스 펍(pub_builder.gd)과 F5 경기 과녁(game/board/board.gd)이 같이 쓴다.
## → 다트판 색·숫자 크기·철사 틈을 바꾸려면 이 파일만 고치면 두 곳이 같이 바뀐다.
##
## 판정과 어긋나지 않는 이유: 링 반지름은 팀 판정 코드 BoardLayout 의 비율(0~1)에 득점 반지름을 곱해서만 그린다.
## 숫자 순서도 넘겨받은 numbers(BoardLayout.numbers)를 그대로 쓴다. 다트판은 AI 이미지로 그리지 않는다(기획 2-8).
##
## 좌표: parent 기준. 판 중심 = 원점, 앞면 = +Z(법선), 12시 방향 = +Y.

const MeshKit = preload("res://art/mesh_kit.gd")

## 실제 규격(mm): 득점 반지름 170, 숫자 띠까지 포함한 판 바깥 225.5, 숫자 중심 197.
const REAL_SCORING_RADIUS := 0.170
const BACKING_RATIO := 0.2255 / 0.170
const NUMBER_RATIO := 0.197 / 0.170
## 칸 사이 틈(라디안). 철사(spider) 경계처럼 보이게 한다.
const WIRE_GAP := 0.0017
## 숫자 글자 해상도(px). 실제 크기는 pixel_size 로 맞추므로 이 값은 선명도만 바꾼다.
const NUMBER_FONT_SIZE := 48


## 전자 과녁의 작은 구멍을 반복하는 내부 생성 재질. 거리에 따라 밉맵을 사용해 투척선에서 깜박이지 않는다.
static var _socket_texture: ImageTexture
static func _socket_tile() -> ImageTexture:
	if _socket_texture != null: return _socket_texture
	var tile := Image.create_empty(32, 32, false, Image.FORMAT_RGB8)
	for y in range(32):
		for x in range(32):
			var radius := Vector2(x - 15.5, y - 15.5).length()
			var level := lerpf(0.79, 1.0, smoothstep(3.0, 6.8, radius))
			tile.set_pixel(x, y, Color(level, level, level))
	tile.generate_mipmaps()
	_socket_texture = ImageTexture.create_from_image(tile)
	return _socket_texture


## parent 아래에 다트판을 만든다.
## scoring_radius: 더블 링 바깥 반지름(판정 반지름 1). 쇼케이스 = 0.17(실제), F5 = BoardLayout.RADIUS(0.30, 노드 배율 2.5 별도).
## glow: 0 보다 크면 칸 색이 스스로 조금 빛난다(어두운 경기장에서 다트판이 가장 밝게 보이도록 — 기획 2-6 가독성 위계).
## number_scale: 숫자 글자 배율. 1 = 실제 다트판 비율. 멀리서 봐야 하는 경기장은 크게.
## sector_groups(2026-11-07 아수라장 머신): 노드를 주면(F5 = 5개) 섹터 i 의 칸·숫자를 sector_groups[i / 4] 아래에 만든다
##   (연속 4섹터 = 피자 한 조각). 조각 노드를 옮기면 숫자가 자기 칸과 함께 움직인다. 비우면 예전처럼 parent 하나에 만든다.
## ring_scale(2026-11-21 링 확장 카드): 트리플·더블 두께 배율 — 판정과 같은 BoardLayout.ring_edges 로 그린다.
static func build(parent: Node3D, numbers: Array[int], scoring_radius: float, glow := 0.0, number_scale := 1.0,
		sector_groups: Array[Node3D] = [], ring_scale := 1.0) -> void:
	var k := scoring_radius / REAL_SCORING_RADIUS
	var suffix := "_Glow" if glow > 0.0 else ""
	var dark := MeshKit.material("BoardBacking", "172523")
	var mats: Array[StandardMaterial3D] = [
		MeshKit.material("BoardBlack" + suffix, "172623", 0.0, glow),
		MeshKit.material("BoardIvory" + suffix, "e4d7ad", 0.0, glow),
		MeshKit.material("BoardRed" + suffix, "bc4d42", 0.0, glow),
		MeshKit.material("BoardGreen" + suffix, "38806a", 0.0, glow),
	]
	if sector_groups.size() == 40:
		for material in mats:
			material.albedo_texture = _socket_tile()
			material.uv1_triplanar = true
			material.uv1_scale = Vector3.ONE * 123.0
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	# 뒤판(숫자 띠 포함). 두께는 배율과 무관하게 4cm.
	if sector_groups.size() != 40:
		var backing := MeshKit.cylinder(parent, "Backing", scoring_radius * BACKING_RATIO, 0.04, Vector3(0, 0, -0.022), dark, 64)
		backing.rotation.x = PI / 2
	var outer_bull := BoardLayout.OUTER_BULL * scoring_radius
	var edges: Vector3 = BoardLayout.ring_edges(ring_scale)
	var triple_in := edges.x * scoring_radius
	var triple_out := edges.y * scoring_radius
	var double_in := edges.z * scoring_radius
	for i in range(20):
		var number: int = numbers[i]
		# BoardLayout 규칙: 0번 칸이 12시, 시계 방향으로 증가.
		var angle := i * TAU / 20.0
		var start := angle - PI / 20.0 + WIRE_GAP
		var end := angle + PI / 20.0 - WIRE_GAP
		var single := mats[i % 2]
		var special := mats[2 + i % 2]
		var pieces: int = 2 if sector_groups.size() == 40 else 1
		for piece in range(pieces):
			var holder: Node3D = sector_groups[i * pieces + piece] if pieces == 2 else (sector_groups[i * sector_groups.size() / 20] if not sector_groups.is_empty() else parent)
			var from_angle: float = start if piece == 0 else angle
			var to_angle: float = end if piece == pieces - 1 else angle
			if pieces == 2:
				_carrier(holder, outer_bull, scoring_radius * BACKING_RATIO, from_angle, to_angle, dark)
				MeshKit.sector(holder, "BeveledRim", scoring_radius * 1.276, scoring_radius * 1.322, from_angle + 0.002, to_angle - 0.002, -0.0014, MeshKit.material("BoardRim", "8b6a48", 0.33))
				# 득점 면 밖의 월계색 인레이와 황동 인덱스로 교체식 타일을 읽게 한다.
				MeshKit.sector(holder, "OuterInlay", scoring_radius * 1.242, scoring_radius * 1.270, from_angle + 0.006, to_angle - 0.006, -0.0011, MeshKit.material("OuterBottleGreen", "396658", 0.22))
				if piece == 0:
					MeshKit.sector(holder, "BrassIndex", scoring_radius * 1.252, scoring_radius * 1.319, angle - 0.009, angle + 0.009, -0.0008, MeshKit.material("BoardIndexBrass", "cba471", 0.42))

			MeshKit.sector(holder, "SingleInner_%s" % number, outer_bull, triple_in, from_angle, to_angle, 0, single)
			MeshKit.sector(holder, "Triple_%s" % number, triple_in, triple_out, from_angle, to_angle, 0.0003 * k, special)
			MeshKit.sector(holder, "SingleOuter_%s" % number, triple_out, double_in, from_angle, to_angle, 0, single)
			MeshKit.sector(holder, "Double_%s" % number, double_in, scoring_radius, from_angle, to_angle, 0.0003 * k, special)
		if sector_groups.size() != 40:
			var holder: Node3D = sector_groups[i * sector_groups.size() / 20] if not sector_groups.is_empty() else parent
			var label := MeshKit.label(holder, "Number_%s" % number, str(number),
				Vector3(sin(angle), cos(angle), 0) * scoring_radius * NUMBER_RATIO + Vector3(0, 0, 0.003 * k),
				NUMBER_FONT_SIZE, Color("f0e6cd"), 0.00055 * k * 34.0 / NUMBER_FONT_SIZE * number_scale)
			label.double_sided = false
	var bull := MeshKit.cylinder(parent, "OuterBull", outer_bull, 0.001 * k, Vector3(0, 0, 0.001 * k), mats[3], 48)
	bull.rotation.x = PI / 2
	var inner := MeshKit.cylinder(parent, "InnerBull", BoardLayout.INNER_BULL * scoring_radius, 0.001 * k, Vector3(0, 0, 0.002 * k), mats[2], 48)
	inner.rotation.x = PI / 2


## 두께가 있는 교체식 점수 타일. 같은 칸의 두 하위 메시가 경첩 기준선 양쪽에서 같은 타일로 움직인다.
static func _carrier(parent: Node3D, inner: float, outer: float, start: float, end: float, material: StandardMaterial3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := (end - start) / 5.0
	var z_front := -0.0028
	var z_rear := -0.026
	for i in range(5):
		var a := start + step*i
		var b := a+step
		var va := Vector3(sin(a), cos(a), 0)
		var vb := Vector3(sin(b), cos(b), 0)
		var p := va*inner
		var q := va*outer
		var r := vb*outer
		var s := vb*inner
		for face: Array in [[p,q,r,s,z_front,Vector3.BACK],[s,r,q,p,z_rear,Vector3.FORWARD]]:
			for j: int in [0,1,2,0,2,3]:
				st.set_normal(face[5])
				st.add_vertex(Vector3(face[j])+Vector3.BACK*float(face[4]))
		var walls: Array = [[q,r],[s,p]]
		if i == 0: walls.append([p,q])
		if i == 4: walls.append([r,s])
		for wall: Array in walls:
			var u: Vector3 = wall[0]
			var v: Vector3 = wall[1]
			var n := Vector3(-(v.y-u.y),v.x-u.x,0).normalized()
			for vertex: Vector3 in [v+Vector3.BACK*z_front,u+Vector3.BACK*z_front,u+Vector3.BACK*z_rear,v+Vector3.BACK*z_front,u+Vector3.BACK*z_rear,v+Vector3.BACK*z_rear]:
				st.set_normal(n)
				st.add_vertex(vertex)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	MeshKit.mesh_node(parent,"TileCarrier",st.commit(),Vector3.ZERO,material)
