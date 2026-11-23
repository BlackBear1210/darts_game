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
## 경기 끝 벌칙으로 판에 묶인 꼴찌(2026-11-23). 판을 다시 그려도 지우지 않는다.
const VICTIM_NAME := "StrappedVictim"
const BoardVictim = preload("res://game/board/board_victim.gd")

var layout := BoardLayout.new()
## 고정 점수 글자는 같은 타일의 외곽 숫자와 각도·방향을 공유하고 반경만 다르다.
class RingPrint:
	var badge: Label3D
	var label: Label3D
	var radius_ratio: float

	func _init(anchor: Label3D, value: Label3D, ratio: float) -> void:
		badge = anchor
		label = value
		radius_ratio = ratio

	func align() -> void:
		label.transform = badge.transform
		label.scale = Vector3.ONE * maxf(badge.scale.x, 0.8)
		label.position = Vector3(badge.position.x * radius_ratio, badge.position.y * radius_ratio, 0.003)
		label.visible = badge.visible

var _ring_prints: Array[RingPrint] = []
var _primary: Array[Label3D] = []
var _pins: Array[Node3D] = []
var _legend: Label3D
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
	for sector in range(20):
		var node := Node3D.new()
		node.name = "BullPart%d" % sector
		_spin.add_child(node)
		_bull_groups.append(node)
	_legend = MeshKit.label(self, "ScoreLegend", "", Vector3(0, -0.73, 0.018), 36, Color("ffe3ad"), 0.00085)
	show_layout(layout)


func show_layout(data: BoardLayout) -> void:
	layout = data
	if _face == null: return
	var values: Dictionary = layout.to_snapshot()
	if _shown_values == values: return
	_shown_values = values
	_ring_prints.clear()
	_primary.clear()
	# 조각 노드와 거기 꽂힌 다트는 남기고 칸·숫자 그림만 지운다(숫자 섞기가 차례 도중에 와도 다트가 사라지지 않게).
	for child in _spin.get_children():
		if child in _groups or child in _bull_groups:
			for part in child.get_children():
				if not part.has_meta(PINNED_META):
					child.remove_child(part)
					part.queue_free()
		elif not child.has_meta(PINNED_META) and child.name != VICTIM_NAME:
			_spin.remove_child(child)
			child.queue_free()
	BoardArt.build(_spin, layout.numbers, BoardLayout.RADIUS, GLOW, NUMBER_SCALE, _groups, layout.ring_scale)
	_selected_sector = -2
	_choice_marks.clear()
	_build_bulls()
	_build_badges()
	_show_values()
	show_chaos(_shape)


## 경기 끝 벌칙(2026-11-23 사용자 요청): 꼴찌를 판 앞면에 묶는다. Spin 의 자식이라 판이 돌면 함께 돈다.
## 크기·자리는 board_victim.gd 가 정한다 — 방장의 명중 판정도 같은 치수를 본다.
func strap_victim(model: Node3D) -> void:
	release_victim()
	model.name = VICTIM_NAME
	model.position = BoardVictim.model_position()
	model.scale = Vector3.ONE * BoardVictim.model_scale()
	# 캐릭터 정면은 -Z → 던지는 쪽(판 앞면 +Z)을 보도록 돌린다.
	model.rotation.y = PI
	_spin.add_child(model)


## 묶인 사람의 1인칭 눈(벌칙 카메라). 원점 = 눈 자리, basis.z = 판 앞면 방향(던지는 쪽), basis.y = 판과 함께 도는 위쪽.
## 묶인 사람이 없으면 크기 0 인 Transform3D 를 돌려준다(부르는 쪽이 basis.y 로 판별한다).
func victim_eye() -> Transform3D:
	if _spin == null or _spin.get_node_or_null(VICTIM_NAME) == null:
		return Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO)
	var axes := Basis(_spin.global_basis.x.normalized(), _spin.global_basis.y.normalized(), _spin.global_basis.z.normalized())
	var local := Vector3(0.0, BoardVictim.HEAD_Y * BoardLayout.RADIUS, BoardVictim.EYE_FORWARD * BoardLayout.RADIUS)
	return Transform3D(axes, _spin.to_global(local))


func release_victim() -> void:
	if _spin == null:
		return
	var strapped: Node = _spin.get_node_or_null(VICTIM_NAME)
	if strapped != null:
		_spin.remove_child(strapped)
		strapped.queue_free()


## 아수라장 모양을 그림에 옮긴다(모든 화면에서 매 프레임). shape = BoardChaos.pose(...).
func show_chaos(shape: Dictionary) -> void:
	_shape = shape
	if _spin == null:
		return
	_spin.rotation.z = float(shape.get("angle", 0.0))
	var zoom := float(shape.get("scale", 1.0))
	if not is_equal_approx(_spin.scale.x, zoom):
		var ratio := _spin.scale.x / zoom
		_spin.scale = Vector3.ONE * zoom
		for dart in _pins:
			if is_instance_valid(dart): dart.scale *= ratio
	var movement: Vector2 = shape.get("move", Vector2.ZERO)
	_spin.position = Vector3(movement.x, movement.y, 0) * BoardLayout.RADIUS
	for fragment in range(_groups.size()):
		var angle: float = (fragment / 2 + (-0.25 if fragment % 2 == 0 else 0.25)) * TAU / 20.0
		var point := Vector2(sin(angle), cos(angle)) * 0.7
		var offset: Vector2 = BoardChaos.offset_at(point, shape)
		_groups[fragment].position = Vector3(offset.x, offset.y, 0) * BoardLayout.RADIUS
	# 불도 외부 타일과 같은 18도 경계를 써야 두 방향을 겹쳐도 엇갈리지 않는다.
	for sector in range(20):
		var angle := sector * TAU / 20.0
		var sample := Vector2(sin(angle), cos(angle)) * 0.01
		var offset := BoardChaos.offset_at(sample, shape)
		_bull_groups[sector].position = Vector3(offset.x, offset.y, 0) * BoardLayout.RADIUS
	_place_badges()



## 꽂힌 다트를 맞은 조각(가운데 불이면 회전 뿌리)에 붙인다. point = 과녁 평면 정규화 좌표(MatchState.last_hit 의 x, y).
## 틈·뒤판·판 밖이면 붙이지 않고 false — 다트는 머신 몸체에 꽂힌 채 제자리에 남는다.
## 셔터가 가린 쪽도 false — 그 다트는 셔터 날개 앞면에 박혀 있다(MatchController._solve 가 자리를 당겼다).
func pin(dart: Node3D, point: Vector2, pierced: bool = false) -> bool:
	var shape := _shape.duplicate()
	if pierced: shape.cover = false
	var original: Vector2 = BoardChaos.locate(point, shape, BoardArt.BACKING_RATIO)
	if not original.is_finite() or _spin == null:
		return false
	var sector: int = BoardLayout.sector_at(original)
	var relative: float = wrapf(atan2(original.x, original.y) - sector * TAU / 20.0, -PI, PI)
	var fragment: int = sector * 2 + (1 if relative >= 0 else 0)
	var holder: Node3D = _bull_groups[sector] if original.length() <= BoardLayout.OUTER_BULL else _groups[fragment]
	dart.set_meta(PINNED_META, true)
	dart.reparent(holder, true)
	_pins.append(dart)
	return true


## 판에 붙여 둔 다트를 모두 지운다(차례가 바뀔 때 GameView 가 부른다).
func clear_pins() -> void:
	if _spin == null:
		return
	for node in _pins:
		if is_instance_valid(node):
			node.get_parent().remove_child(node)
			node.queue_free()
	_pins.clear()


func sight_center() -> Vector3:
	return _spin.global_position


func sight_radius() -> float:
	var travel := BoardChaos.split_travel(_shape)
	return (BoardChaos.PRINT_RADIUS + travel) * _spin.global_basis.x.length() * BoardLayout.RADIUS


func _build_bulls() -> void:
	for name in ["OuterBull", "InnerBull"]:
		var old: Node = _spin.get_node_or_null(name)
		if old != null:
			_spin.remove_child(old)
			old.queue_free()
	for sector in range(20):
		var start := (sector - 0.5) * TAU / 20.0
		var outer: float = BoardLayout.OUTER_BULL * BoardLayout.RADIUS
		var inner: float = BoardLayout.INNER_BULL * BoardLayout.RADIUS
		MeshKit.sector(_bull_groups[sector], "OuterBull", inner, outer, start, start + TAU / 20.0, 0.001, MeshKit.material("BoardGreen_Glow", "38806a", 0, GLOW))
		MeshKit.sector(_bull_groups[sector], "InnerBull", 0, inner, start, start + TAU / 20.0, 0.002, MeshKit.material("BoardRed_Glow", "bc4d42", 0, GLOW))


## 숫자판은 구역마다 하나씩 득점 타일에 붙인다. 절단선이 지날 때 한쪽 타일 안으로 붙인다.
## 무효화·먹물·섞기에서도 각 숫자는 구역 인덱스를 따르며, 같은 점수가 여럿이어도 섞이지 않는다.
func _build_badges() -> void:
	var typeface := FontVariation.new()
	typeface.base_font = ThemeDB.fallback_font
	typeface.variation_embolden = 0.7
	for sector in range(20):
		_primary.append(_badge(sector, typeface))

func _badge(sector: int, typeface: Font) -> Label3D:
	var holder := _groups[sector * 2]
	var title := "Number_%d" % layout.numbers[sector]
	var label := MeshKit.label(holder,title,str(layout.numbers[sector]),Vector3.ZERO,72,Color("fff5cc"),0.00083)
	label.font = typeface
	label.outline_size = 4
	label.outline_modulate = Color("111e25")
	label.double_sided = false
	if sector in layout.blocked_sectors: label.text = "0"
	if sector in layout.hidden_sectors: label.text = "●"
	return label

func _place_badges() -> void:
	var r := BoardLayout.RADIUS * BoardArt.NUMBER_RATIO
	for sector in range(_primary.size()):
		var label := _primary[sector]
		# 분리는 칸 경계에서만 일어난다. 번호는 한 장의 타일 중심을 따라가고 글자만 바로 세운다.
		var angle := sector * TAU / 20.0
		label.position = Vector3(sin(angle) * r, cos(angle) * r, 0.004)
		label.rotation.z = -_spin.rotation.z
		label.scale = Vector3.ONE
		label.visible = true
		if _shape.get("cover", false):
			_fit_guard_edge(label, sector, angle, r)
	for mark in _ring_prints:
		mark.align()


## 가림막 경계에서 '20'의 뒷자리만 읽히지 않게 한다. 같은 원래 구역 안에서만 옮긴다.
func _fit_guard_edge(label: Label3D, sector: int, angle: float, radius: float) -> void:
	var origin := _groups[sector * 2].position
	var center: Vector3 = _spin.transform * (origin + label.position) / BoardLayout.RADIUS
	var half_width := 0.072 * label.text.length() * label.scale.x * _spin.scale.x
	var xy := Vector2(center.x, center.y)
	var left := BoardChaos.covered(xy - Vector2.RIGHT * half_width, _shape)
	var right := BoardChaos.covered(xy + Vector2.RIGHT * half_width, _shape)
	if left == right:
		return
	for sign_side: float in [-1.0, 1.0]:
		var theta := angle + sign_side * PI / 32.0
		var candidate := Vector3(sin(theta) * radius, cos(theta) * radius, label.position.z)
		center = _spin.transform * (origin + candidate) / BoardLayout.RADIUS
		xy = Vector2(center.x, center.y)
		var half := Vector2.RIGHT * half_width * 0.74
		if not BoardChaos.covered(xy - half, _shape) and not BoardChaos.covered(xy + half, _shape):
			label.scale *= 0.74
			label.position = candidate
			return
	label.visible = false


func _show_values() -> void:
	for fragment in range(_groups.size()):
		var sector: int = fragment / 2
		for node in _groups[fragment].get_children():
			if node is MeshInstance3D and sector in layout.blocked_sectors and not node.has_meta(PINNED_META):
				(node as MeshInstance3D).material_override = MeshKit.material("BlockedSector", "3b4141")
	_legend.visible = layout.ring_multipliers != [1, 2, 3] or layout.region_score(80) != 50 or layout.region_score(81) != 25
	if _legend.visible:
		_legend.text = "S×%d  D×%d  T×%d   B %d/%d" % [layout.ring_multipliers[0], layout.ring_multipliers[1], layout.ring_multipliers[2], layout.region_score(81), layout.region_score(80)]
	for key in layout.overrides:
		var region: int = int(key)
		if region >= 80: continue
		var sector: int = region / 4
		var edges := BoardLayout.ring_edges(layout.ring_scale)
		var radii: Array[float] = [(BoardLayout.OUTER_BULL + edges.x) / 2, (edges.x + edges.y) / 2, (edges.y + edges.z) / 2, (edges.z + 1) / 2]
		if sector in layout.hidden_sectors: continue
		var radius_ratio: float = radii[region % 4] / BoardArt.NUMBER_RATIO
		var text := str(layout.overrides[key])
		_add_ring_print(_primary[sector], "FixedScore%d" % region, text, radius_ratio)


func _add_ring_print(badge: Label3D, title: String, text: String, radius_ratio: float) -> void:
	var tag := MeshKit.label(badge.get_parent(), title, text, Vector3.ZERO, 46, Color("ffda86"), 0.00065)
	tag.font = badge.font
	tag.outline_size = 5
	tag.outline_modulate = Color("192126")
	tag.shaded = false
	tag.double_sided = false
	_ring_prints.append(RingPrint.new(badge, tag, radius_ratio))


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
