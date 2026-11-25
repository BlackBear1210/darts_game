extends VBoxContainer
## 지금 차례에 걸려 있는 카드를 **그림으로** 보여 주는 화면 오른쪽 위 줄
## (2026-11-25 사용자 요청 "지금은 본인이 무슨카드가 적용됐는지도 몰라").
##
## 글로 적는 줄(ui/lounge_hud.gd `_effects`)은 "무슨 효과가 얼마나 남았나"를 말하고,
## 이쪽은 "어떤 카드가 걸렸나"를 한눈에 보인다. 카드 번호는 방장이 보낸 것을 그대로 쓴다
## (MatchCards._effect_cards → MatchPlayer.card_effects["active_cards"]).
## 같은 카드가 여러 번 걸리면 한 장만 그리고 ×2 를 붙인다.

const Style = preload("res://ui/lounge_style.gd")
const CardFaces = preload("res://game/card_round/cards/card_faces.gd")
const Catalog = preload("res://game/card_round/rules/card_catalog.gd")

## 카드 한 장 크기(화면 픽셀). 원본 그림은 400×600 이라 같은 비율로 줄인다.
const CARD_SIZE := Vector2(62, 93)
const CARD_GAP: int = 6
## 한 줄에 이만큼까지만 보이고 넘치면 "+N" 으로 줄인다.
const MAX_CARDS: int = 5

var _title: Label
var _row: HBoxContainer
## 지금 그려 둔 카드 구성(바뀌었을 때만 다시 만든다).
var _shown: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override("separation", 4)
	_title = Style.hud_label(self, "", 16, Style.PINK)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_END
	_row.add_theme_constant_override("separation", CARD_GAP)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)


## types = 걸려 있는 카드 번호들(겹치면 여러 번). owner_name 은 효과를 받는 사람 이름.
func show_cards(types: Array, owner_name: String) -> void:
	var key: String = "%s|%s" % [owner_name, str(types)]
	if key == _shown:
		return
	_shown = key
	for child in _row.get_children():
		child.queue_free()
	if types.is_empty():
		_title.text = ""
		visible = false
		return
	visible = true
	_title.text = "적용 중 · %s" % owner_name
	# 같은 카드는 한 장으로 모으고 횟수를 센다. 걸린 순서는 유지한다.
	var order: Array[int] = []
	var counts: Dictionary = {}
	for value in types:
		var type: int = int(value)
		if not counts.has(type):
			order.append(type)
		counts[type] = int(counts.get(type, 0)) + 1
	var shown: Array[int] = order.slice(0, MAX_CARDS)
	for type: int in shown:
		_row.add_child(_card(type, int(counts[type])))
	if order.size() > shown.size():
		var more := Style.hud_label(_row, "+%d" % (order.size() - shown.size()), 18, Style.CREAM)
		more.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


## 카드 한 장. 그림 위에 겹친 횟수(×2)를 작게 얹는다.
func _card(type: int, count: int) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = CARD_SIZE
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := TextureRect.new()
	art.texture = CardFaces.face(type)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.size = CARD_SIZE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(art)
	# 어두운 펍 위에서도 카드 테두리가 보이게 얇은 테를 두른다.
	var edge := Panel.new()
	edge.size = CARD_SIZE
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.add_theme_stylebox_override("panel", Style.flat(Color(0, 0, 0, 0), Color(Style.INK, 0.85), 2, 6, 0))
	holder.add_child(edge)
	if count > 1:
		var badge := Style.hud_label(holder, "×%d" % count, 17, Style.GOLD)
		badge.position = Vector2(CARD_SIZE.x - 26, CARD_SIZE.y - 24)
	holder.tooltip_text = str(Catalog.card(type).name)
	return holder
