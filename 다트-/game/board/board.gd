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
var _shown_numbers: Array[int] = []
var _shape: Dictionary = BoardChaos.rest()


func _ready() -> void:
	_face = Node3D.new()
	_face.name = "Face"
	add_child(_face)
	_spin = Node3D.new()
	_spin.name = "Spin"
	_face.add_child(_spin)
	for group in range(BoardChaos.GROUP_COUNT):
		var node := Node3D.new()
		node.name = "SectorGroup%d" % group
		_spin.add_child(node)
		_groups.append(node)
	show_layout(layout)


func show_layout(data: BoardLayout) -> void:
	layout = data
	if _face == null: return
	if _shown_numbers == layout.numbers: return
	_shown_numbers = layout.numbers.duplicate()
	# 조각 노드와 거기 꽂힌 다트는 남기고 칸·숫자 그림만 지운다(숫자 섞기가 차례 도중에 와도 다트가 사라지지 않게).
	for child in _spin.get_children():
		if child in _groups:
			for part in child.get_children():
				if not part.has_meta(PINNED_META):
					child.remove_child(part)
					part.queue_free()
		elif not child.has_meta(PINNED_META):
			_spin.remove_child(child)
			child.queue_free()
	BoardArt.build(_spin, layout.numbers, BoardLayout.RADIUS, GLOW, NUMBER_SCALE, _groups)
	show_chaos(_shape)


## 아수라장 모양을 그림에 옮긴다(모든 화면에서 매 프레임). shape = BoardChaos.pose(...).
func show_chaos(shape: Dictionary) -> void:
	_shape = shape
	if _spin == null:
		return
	_spin.rotation.z = float(shape.get("angle", 0.0))
	var reach: float = float(shape.get("split", 0.0)) * BoardLayout.RADIUS
	for group in range(_groups.size()):
		var direction: Vector2 = BoardChaos.group_direction(group)
		_groups[group].position = Vector3(direction.x, direction.y, 0.0) * reach


## 꽂힌 다트를 맞은 조각(가운데 불이면 회전 뿌리)에 붙인다. point = 과녁 평면 정규화 좌표(MatchState.last_hit 의 x, y).
## 틈·뒤판·판 밖이면 붙이지 않고 false — 다트는 머신 몸체에 꽂힌 채 제자리에 남는다.
## 셔터가 가린 쪽도 false — 그 다트는 셔터 날개 앞면에 박혀 있다(MatchController._solve 가 자리를 당겼다).
func pin(dart: Node3D, point: Vector2) -> bool:
	var original: Vector2 = BoardChaos.locate(point, _shape)
	if not original.is_finite() or original.length() > 1.0 + BoardScorer.BOUNDARY_EPSILON or _spin == null:
		return false
	var holder: Node3D = _spin if original.length() <= BoardLayout.OUTER_BULL else _groups[BoardChaos.group_of(BoardLayout.sector_at(original))]
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
