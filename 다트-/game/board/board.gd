class_name BoardView
extends Node3D
## 과녁 표시(3D). 점수 계산은 BoardScorer 담당.
## 그림은 art/board_art.gd(디자인 담당)가 그린다 — 아트 쇼케이스 펍의 다트판과 같은 코드라서 모양이 같다.
## 링 반지름 = BoardLayout 비율 × RADIUS, 숫자 순서 = layout.numbers 그대로 → 그림과 판정이 어긋나지 않는다.
## 카드로 숫자 순서가 바뀌면 show_layout() 이 판을 다시 그린다.

const BoardArt = preload("res://art/board_art.gd")
## 칸 색이 스스로 조금 빛나는 정도. 어두운 펍에서도 과녁이 가장 잘 보이게 한다(기획 2-6 가독성 위계).
const GLOW := 0.15
## 숫자 글자 배율. 앉은 자리(약 10m)에서도 읽히도록 실제 다트판 비율보다 키운다.
const NUMBER_SCALE := 1.6

var layout := BoardLayout.new()
var _face: Node3D
var _shown_numbers: Array[int] = []


func _ready() -> void:
	_face = Node3D.new()
	_face.name = "Face"
	add_child(_face)
	show_layout(layout)


func show_layout(data: BoardLayout) -> void:
	layout = data
	if _face == null: return
	if _shown_numbers == layout.numbers: return
	_shown_numbers = layout.numbers.duplicate()
	for child in _face.get_children():
		_face.remove_child(child)
		child.queue_free()
	BoardArt.build(_face, layout.numbers, BoardLayout.RADIUS, GLOW, NUMBER_SCALE)
