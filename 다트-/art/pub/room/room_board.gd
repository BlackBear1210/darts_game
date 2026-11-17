extends "res://art/pub/room/room_kit.gd"
## 다트 홀 과녁 쪽: 과녁 벽(청록 판넬·큰 아치·칠판 두 장) · 레인 매트·투척선 · 럼주통.
## 디자인 담당 소유(2026-11-17 game_room_builder.gd 에서 나눔). 장면 안 묶음 = BoardWall · Lane · Barrels.
## 다트판 자체는 여기 없다 — 다트 머신(art/dart_machine/dart_machine.gd)이 TableView 실행 때 세운다.
## 과녁 벽 양옆 칸 꾸밈(네온·시계·트로피·깃발 줄)은 room_board_sides.gd.

# ─────────────────────────────── 과녁 벽·레인·통 ───────────────────────────────

## 과녁 벽: 청록 특징 판넬 + 머신을 감싸는 큰 아치 틀 + 양옆 칠판 두 장(점수·하우스 룰).
## 다트판 자체는 여기 없다 — 다트 머신(art/dart_machine/dart_machine.gd)이 TableView 실행 때 세워진다.
## 칠판(ChalkScores — GameView 가 글자를 바꾼다)은 투척선에서 보면 머신 어깨(x ±1.35) 바깥이다(x ±2.05).
static func build_board_wall(p: Node3D) -> void:
	var f := _faces()
	var ceiling: float = TableView.CEILING_HEIGHT
	var center: Vector3 = TableView.BOARD_CENTER
	var face: float = f.board_z
	# 2026-11-15: 판넬 두께 0.05 → 0.042. 판넬 가장자리에 서는 벽 기둥(Pilaster, 앞면이 벽에서 0.05m)과
	# 앞면이 똑같은 평면이라 청록·월넛이 겹쳐 깜빡였다(z-파이팅) → 판넬 앞면을 기둥보다 8mm 뒤로 물렸다.
	var panel_depth: float = 0.05 - WALL_LAYER_GAP
	MeshKit.box(p, "FeaturePanel", Vector3(FEATURE_HALF * 2, ceiling, panel_depth), Vector3(center.x, ceiling / 2, face + panel_depth / 2.0), _teal())
	# 머신 뒤 큰 아치(요청서 콘셉트의 둥근 벽감): 판넬 가장자리(x ±FEATURE_HALF)를 따라 서는 굵은 월넛 틀.
	# 틀 다리가 판넬 옆 징두리·허리 난간·걸레받이의 잘린 끝을 덮는다. 칠판(바깥 끝 x ±2.61)과는 닿지 않는다.
	var top: float = ceiling - COVE_R - 0.4
	var outer := RoundKit.arch_path(FEATURE_HALF * 2.0, 0.0, top, 1.3, 12)
	MeshKit.mesh_node(p, "FeatureArch", RoundKit.sweep_mesh("feature_arch", RoundKit.bead_profile(0.13, 0.11),
		RoundKit.wall_path_rails(outer, Vector3.ZERO, Vector3.RIGHT, Vector3.BACK), false, false), Vector3(center.x, 0, face), _walnut())
	# 칠판 두 장: 둥근 나무 틀 + 칠판면. 왼쪽 = 실시간 점수판, 오른쪽 = 하우스 룰.
	var board_size := Vector2(1.0, 1.7)
	var chalk := Color("e6e3d6")
	for side: float in [-1.0, 1.0]:
		var x: float = center.x + side * 2.05
		MeshKit.rounded_box(p, "ChalkFrame", Vector3(board_size.x + 0.12, board_size.y + 0.12, 0.06), Vector3(x, center.y - 0.1, face + 0.08), _walnut(), 0.03)
		MeshKit.rounded_box(p, "ChalkBoard", Vector3(board_size.x - 0.04, board_size.y - 0.04, 0.012), Vector3(x, center.y - 0.1, face + 0.11), PubParts.chalk_board(), 0.005)
		for y: float in [-1.0, 1.0]:
			MeshKit.mesh_node(p, "ChalkPin", RoundKit.sphere_mesh(0.025, 12), Vector3(x, center.y - 0.1 + y * (board_size.y / 2.0 + 0.03), face + 0.115), _brass())
	var scores := MeshKit.label(p, "ChalkScores", "점 수\n\n―", Vector3(center.x - 2.05, center.y - 0.05, face + 0.12), 28, chalk, 0.0036)
	scores.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	MeshKit.label(p, "ChalkRules", "하 우 스  룰\n\n한 차례 3발\n꾹 = 충전\n오른쪽 = 취소\n늦으면 슬로우!", Vector3(center.x + 2.05, center.y - 0.05, face + 0.12), 30, chalk, 0.0036)


## 레인: 벨벳 매트와 놋쇠 투척선. 중앙 펜스·출입 금지판은 사용자 요청으로 제거(2026-11-12).
static func build_lane(p: Node3D) -> void:
	var f := _faces()
	var line_z: float = TableView.THROW_LINE_Z
	var mat_end_z: float = TableView.NO_ENTRY_Z - 0.15
	# 레인 매트는 과녁 벽이 아니라 다트 머신 받침 앞(과녁 면 바로 아래)에서 끝난다.
	var lane_end: float = TableView.BOARD_CENTER.z
	var lane_length: float = mat_end_z - lane_end
	var lane_center: float = (mat_end_z + lane_end) / 2.0
	var lane_half: float = TableView.LANE_HALF
	MeshKit.mesh_node(p, "LaneMat", RoundKit.rounded_slab_mesh(Vector2(lane_half * 2, lane_length), 0.02, 0.12), Vector3(0, 0.01, lane_center), MeshKit.material("LaneVelvet", "244d43"))
	for side: float in [-1.0, 1.0]:
		MeshKit.box(p, "LanePinstripe", Vector3(0.02, 0.006, lane_length - 0.3), Vector3(side * (lane_half - 0.1), 0.033, lane_center), _brass())
	# 투척선(Oche): 다트 홀 전체 폭. 이 선 뒤에서 던진다.
	MeshKit.rounded_box(p, "Oche", Vector3(f.hall_x1 - f.hall_x0 - 0.1, 0.03, 0.07), Vector3(0, 0.025, line_z), _brass(), 0.012)
	var oche_text := MeshKit.label(p, "OcheText", "투 척 선", Vector3(0, 0.045, line_z + 0.34), 48, Color("dcc68f"), 0.004)
	oche_text.rotation.x = -PI / 2


## 도면의 럼주통. 큰 통 4개와 곁의 작은 통. 충돌은 TableView.BARRELS / SMALL_BARRELS.
static func build_barrels(p: Node3D) -> void:
	var sets := [[TableView.BARRELS, TableView.BARREL_RADIUS, TableView.BARREL_HEIGHT, "RumBarrel"],
		[TableView.SMALL_BARRELS, TableView.SMALL_BARREL_RADIUS, TableView.SMALL_BARREL_HEIGHT, "SmallBarrel"]]
	for entry in sets:
		var spots: Array = entry[0]
		var radius: float = entry[1]
		var height: float = entry[2]
		for i in range(spots.size()):
			var at: Vector3 = spots[i]
			var node_name: String = "%s_%d" % [entry[3], i + 1]
			# RG Poly 나무통(테·나뭇결 있는 모델)을 충돌 원기둥 크기에 맞춰 놓는다. 통마다 조금씩 돌려 똑같아 보이지 않게.
			var big: bool = entry[3] == "RumBarrel"
			var source: Vector3 = Vector3(0.864, 0.907, 0.887) if big else Vector3(0.864, 0.878, 0.887)
			var fit := Vector3(radius * 2.0 / source.x, height / source.y, radius * 2.0 / source.z)
			if PubParts.asset(p, "barrel" if big else "barrel_small", at, i * 1.3 + 0.4, fit, node_name) != null:
				continue
			# 모델이 없으면 배가 부른 통을 물레로 깎는다.
			var belly := RoundKit.rounded_profile(PackedVector2Array([Vector2(0, 0), Vector2(radius * 0.86, 0), Vector2(radius, height * 0.5),
				Vector2(radius * 0.86, height), Vector2(0, height)]), radius * 0.2, 4)
			RoundKit.lathe(p, node_name, belly, at, _walnut(), 24)
	# 투척 구역 안 큰 통 둘(3·4번)은 뚜껑을 덮어 "서서 마시는 탁자"로 쓴다: 맥주잔·잔·치즈/빵.
	for i: int in [2, 3]:
		var top: Vector3 = TableView.BARRELS[i] + Vector3(0, TableView.BARREL_HEIGHT, 0)
		var side: float = -1.0 if TableView.BARRELS[i].x < 0 else 1.0
		if PubParts.asset(p, "barrel_lid", top, 0.3, Vector3(1.0, 0.5, 1.0), "BarrelTableLid_%d" % (i + 1)) == null:
			continue
		var surface: Vector3 = top + Vector3(0, 0.06, 0)
		PubParts.asset(p, "mug", surface + Vector3(0.12 * side, 0, -0.1), 2.2 * side, Vector3.ONE * 0.6)
		PubParts.asset(p, "goblet", surface + Vector3(-0.1 * side, 0, 0.14), 0.0, Vector3.ONE * 0.7)
		PubParts.asset(p, "cheese" if i == 2 else "bread", surface + Vector3(-0.12 * side, 0, -0.15), 0.6, Vector3.ONE * 0.6)
