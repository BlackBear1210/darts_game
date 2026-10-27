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


## parent 아래에 다트판을 만든다.
## scoring_radius: 더블 링 바깥 반지름(판정 반지름 1). 쇼케이스 = 0.17(실제), F5 = BoardLayout.RADIUS(0.30, 노드 배율 2.5 별도).
## glow: 0 보다 크면 칸 색이 스스로 조금 빛난다(어두운 경기장에서 다트판이 가장 밝게 보이도록 — 기획 2-6 가독성 위계).
## number_scale: 숫자 글자 배율. 1 = 실제 다트판 비율. 멀리서 봐야 하는 경기장은 크게.
static func build(parent: Node3D, numbers: Array[int], scoring_radius: float, glow := 0.0, number_scale := 1.0) -> void:
	var k := scoring_radius / REAL_SCORING_RADIUS
	var suffix := "_Glow" if glow > 0.0 else ""
	var dark := MeshKit.material("BoardBacking", "172523")
	var mats: Array[StandardMaterial3D] = [
		MeshKit.material("BoardBlack" + suffix, "172623", 0.0, glow),
		MeshKit.material("BoardIvory" + suffix, "e4d7ad", 0.0, glow),
		MeshKit.material("BoardRed" + suffix, "bc4d42", 0.0, glow),
		MeshKit.material("BoardGreen" + suffix, "38806a", 0.0, glow),
	]
	# 뒤판(숫자 띠 포함). 두께는 배율과 무관하게 4cm.
	var backing := MeshKit.cylinder(parent, "Backing", scoring_radius * BACKING_RATIO, 0.04, Vector3(0, 0, -0.022), dark, 64)
	backing.rotation.x = PI / 2
	var outer_bull := BoardLayout.OUTER_BULL * scoring_radius
	var triple_in := BoardLayout.TRIPLE_INNER * scoring_radius
	var triple_out := BoardLayout.TRIPLE_OUTER * scoring_radius
	var double_in := BoardLayout.DOUBLE_INNER * scoring_radius
	for i in range(20):
		var number: int = numbers[i]
		# BoardLayout 규칙: 0번 칸이 12시, 시계 방향으로 증가.
		var angle := i * TAU / 20.0
		var start := angle - PI / 20.0 + WIRE_GAP
		var end := angle + PI / 20.0 - WIRE_GAP
		var single := mats[i % 2]
		var special := mats[2 + i % 2]
		MeshKit.sector(parent, "SingleInner_%s" % number, outer_bull, triple_in, start, end, 0, single)
		MeshKit.sector(parent, "Triple_%s" % number, triple_in, triple_out, start, end, 0.0003 * k, special)
		MeshKit.sector(parent, "SingleOuter_%s" % number, triple_out, double_in, start, end, 0, single)
		MeshKit.sector(parent, "Double_%s" % number, double_in, scoring_radius, start, end, 0.0003 * k, special)
		var label := MeshKit.label(parent, "Number_%s" % number, str(number),
			Vector3(sin(angle), cos(angle), 0) * scoring_radius * NUMBER_RATIO + Vector3(0, 0, 0.003 * k),
			NUMBER_FONT_SIZE, Color("f0e6cd"), 0.00055 * k * 34.0 / NUMBER_FONT_SIZE * number_scale)
		label.double_sided = false
	var bull := MeshKit.cylinder(parent, "OuterBull", outer_bull, 0.001 * k, Vector3(0, 0, 0.001 * k), mats[3], 48)
	bull.rotation.x = PI / 2
	var inner := MeshKit.cylinder(parent, "InnerBull", BoardLayout.INNER_BULL * scoring_radius, 0.001 * k, Vector3(0, 0, 0.002 * k), mats[2], 48)
	inner.rotation.x = PI / 2
