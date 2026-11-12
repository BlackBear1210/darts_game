class_name BoardView
extends Node3D
## 과녁 표시(3D). 점수 계산은 BoardScorer 담당.
## 그림은 art/board_art.gd(디자인 담당)가 그린다 — 아트 쇼케이스 펍의 다트판과 같은 코드라서 모양이 같다.
## 링 반지름 = BoardLayout 비율 × RADIUS, 숫자 순서 = layout.numbers 그대로 → 그림과 판정이 어긋나지 않는다.
## 카드로 숫자 순서가 바뀌면 show_layout() 이 판을 다시 그린다.
##
## [아수라장 머신 — 2026-11-07] 과녁은 Face/Spin(평면 안에서 도는 뿌리) 아래에 불·뒤판과 피자 조각 5개(SectorGroup0~4)로 나뉜다.
## show_chaos(BoardChaos.pose) 가 회전각과 벌어짐을 옮긴다. 방장 점수도 같은 pose 로 BoardChaos.locate 를 거쳐 센다.
## 꽂힌 다트는 pin() 으로 맞은 조각(또는 불)에 붙어 함께 돈다.

const BoardArt = preload("res://art/board_art.gd")
const MeshKit = preload("res://art/mesh_kit.gd")
const BoardChaos = preload("res://game/board/board_chaos.gd")
## 칸 색이 스스로 조금 빛나는 정도. 어두운 펍에서도 과녁이 가장 잘 보이게 한다(기획 2-6 가독성 위계).
const GLOW := 0.15
## 숫자 글자 배율. 앉은 자리(약 10m)에서도 읽히도록 실제 다트판 비율보다 키운다.
const NUMBER_SCALE := 1.6
## 판에 붙은 다트 표시(판을 다시 그릴 때 지우지 않는다).
const PINNED_META := "pinned_dart"

var layout := BoardLayout.new()
var _face: Node3D
var _spin: Node3D
var _groups: Array[Node3D] = []
var _shown_values: Dictionary = {}
var _bull_groups: Array[Node3D] = []
var _selected_sector: int = -2
var _choice_marks: Array[Node3D] = []
var _shape: Dictionary = BoardChaos.rest()


func _ready() -> void:
	_face = Node3D.new()
	_face.name = "Face"
	add_child(_face)
	_spin = Node3D.new()
	_spin.name = "Spin"
	_face.add_child(_spin)
	for group in range(40):
		var node := Node3D.new()
		node.name = "SectorGroup%d" % group
		_spin.add_child(node)
		_groups.append(node)
	for quadrant in range(4):
		var node := Node3D.new()
		node.name = "BullPart%d" % quadrant
		_spin.add_child(node)
		_bull_groups.append(node)
	show_layout(layout)


func show_layout(data: BoardLayout) -> void:
	layout = data
	if _face == null: return
	var values: Dictionary = layout.to_snapshot()
	if _shown_values == values: return
	_shown_values = values
	# 조각 노드와 거기 꽂힌 다트는 남기고 칸·숫자 그림만 지운다(숫자 섞기가 차례 도중에 와도 다트가 사라지지 않게).
	for child in _spin.get_children():
		if child in _groups or child in _bull_groups:
			for part in child.get_children():
				if not part.has_meta(PINNED_META):
					child.remove_child(part)
					part.queue_free()
		elif not child.has_meta(PINNED_META):
			_spin.remove_child(child)
			child.queue_free()
	BoardArt.build(_spin, layout.numbers, BoardLayout.RADIUS, GLOW, NUMBER_SCALE, _groups)
	_selected_sector = -2
	_choice_marks.clear()
	_build_bulls()
	_show_values()
	show_chaos(_shape)


## 아수라장 모양을 그림에 옮긴다(모든 화면에서 매 프레임). shape = BoardChaos.pose(...).
func show_chaos(shape: Dictionary) -> void:
	_shape = shape
	if _spin == null:
		return
	_spin.rotation.z = float(shape.get("angle", 0.0))
	var movement: Vector2 = shape.get("move", Vector2.ZERO)
	_spin.position = Vector3(movement.x, movement.y, 0) * BoardLayout.RADIUS
	for fragment in range(_groups.size()):
		var angle: float = (fragment / 2 + (-0.25 if fragment % 2 == 0 else 0.25)) * TAU / 20.0
		var point := Vector2(sin(angle), cos(angle)) * 0.7
		var offset: Vector2 = BoardChaos.offset_at(point, shape)
		_groups[fragment].position = Vector3(offset.x, offset.y, 0) * BoardLayout.RADIUS
	for quadrant in range(4):
		var point := Vector2(1 if quadrant % 2 else -1, 1 if quadrant >= 2 else -1) * 0.01
		var offset: Vector2 = BoardChaos.offset_at(point, shape)
		_bull_groups[quadrant].position = Vector3(offset.x, offset.y, 0) * BoardLayout.RADIUS



## 꽂힌 다트를 맞은 조각(가운데 불이면 회전 뿌리)에 붙인다. point = 과녁 평면 정규화 좌표(MatchState.last_hit 의 x, y).
## 틈·뒤판·판 밖이면 붙이지 않고 false — 다트는 머신 몸체에 꽂힌 채 제자리에 남는다.
## 셔터가 가린 쪽도 false — 그 다트는 셔터 날개 앞면에 박혀 있다(MatchController._solve 가 자리를 당겼다).
func pin(dart: Node3D, point: Vector2) -> bool:
	var original: Vector2 = BoardChaos.locate(point, _shape)
	if not original.is_finite() or original.length() > 1.0 + BoardScorer.BOUNDARY_EPSILON or _spin == null:
		return false
	var sector: int = BoardLayout.sector_at(original)
	var relative: float = wrapf(atan2(original.x, original.y) - sector * TAU / 20.0, -PI, PI)
	var fragment: int = sector * 2 + (1 if relative >= 0 else 0)
	var quadrant: int = (1 if original.x >= 0 else 0) + (2 if original.y >= 0 else 0)
	var holder: Node3D = _bull_groups[quadrant] if original.length() <= BoardLayout.OUTER_BULL else _groups[fragment]
	dart.set_meta(PINNED_META, true)
	dart.reparent(holder, true)
	return true


## 판에 붙여 둔 다트를 모두 지운다(차례가 바뀔 때 GameView 가 부른다).
func clear_pins() -> void:
	if _spin == null:
		return
	for node in _spin.find_children("*", "", true, false):
		if node.has_meta(PINNED_META):
			node.get_parent().remove_child(node)
			node.queue_free()


func _build_bulls() -> void:
	for name in ["OuterBull", "InnerBull"]:
		var old: Node = _spin.get_node_or_null(name)
		if old != null:
			_spin.remove_child(old)
			old.queue_free()
	var starts: Array[float] = [PI, PI / 2.0, PI * 1.5, 0.0]
	for quadrant in range(4):
		var start: float = starts[quadrant]
		var outer: float = BoardLayout.OUTER_BULL * BoardLayout.RADIUS
		var inner: float = BoardLayout.INNER_BULL * BoardLayout.RADIUS
		MeshKit.sector(_bull_groups[quadrant], "OuterBull", inner, outer, start, start + PI / 2, 0.001, MeshKit.material("BoardGreen_Glow", "38806a", 0, GLOW))
		MeshKit.sector(_bull_groups[quadrant], "InnerBull", 0, inner, start, start + PI / 2, 0.002, MeshKit.material("BoardRed_Glow", "bc4d42", 0, GLOW))


func _show_values() -> void:
	for fragment in range(_groups.size()):
		var sector: int = fragment / 2
		for node in _groups[fragment].get_children():
			if node is Label3D:
				(node as Label3D).text = "" if sector in layout.hidden_sectors else ("0" if sector in layout.blocked_sectors else str(layout.numbers[sector]))
				if sector in layout.hidden_sectors:
					MeshKit.sphere(_groups[fragment], "Ink", 0.017, (node as Node3D).position, MeshKit.material("BoardInk", "100e16"), Vector3(1.6, 1.2, 0.12))
			elif node is MeshInstance3D and sector in layout.blocked_sectors:
				(node as MeshInstance3D).material_override = MeshKit.material("BlockedSector", "3b4141")
	if layout.ring_multipliers != [1, 2, 3] or layout.region_score(80) != 50 or layout.region_score(81) != 25:
		MeshKit.label(_spin, "ScoreLegend", "S×%d  D×%d  T×%d   불 %d/%d" % [layout.ring_multipliers[0], layout.ring_multipliers[1], layout.ring_multipliers[2], layout.region_score(81), layout.region_score(80)], Vector3(0, -0.45, 0.01), 32, Color("ffd27a"), 0.0005)
	for key in layout.overrides:
		var region: int = int(key)
		if region >= 80: continue
		var sector: int = region / 4
		var radii: Array[float] = [0.33, 0.605, 0.79, 0.976]
		var angle: float = sector * TAU / 20.0
		MeshKit.label(_groups[sector * 2], "FixedScore%d" % region, str(layout.overrides[key]), Vector3(sin(angle), cos(angle), 0) * radii[region % 4] * BoardLayout.RADIUS + Vector3(0, 0, 0.003), 32, Color("ffd27a"), 0.00045)


## 카드로 지목할 칸을 두 반쪽 모두 강조한다. 조각을 따라 움직이는 표시다.
func show_choice(sector: int) -> void:
	if sector == _selected_sector: return
	_selected_sector = sector
	for marker in _choice_marks:
		if is_instance_valid(marker):
			marker.get_parent().remove_child(marker)
			marker.queue_free()
	_choice_marks.clear()
	if sector < 0 or sector >= 20: return
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.8, 0.15, 0.3)
	var angle: float = sector * TAU / 20.0
	for half in range(2):
		var marker := MeshKit.sector(_groups[sector * 2 + half], "CardChoice", BoardLayout.OUTER_BULL * BoardLayout.RADIUS, BoardLayout.RADIUS, angle - PI / 20 if half == 0 else angle, angle if half == 0 else angle + PI / 20, 0.006, material)
		_choice_marks.append(marker)
