extends Node3D
## 고정 월넛 캐비닛, 움직이는 득점 타일과 보조판, 좌우 포켓식 가림 모듈.
const Kit = preload("res://art/mesh_kit.gd")
const BoardChaos = preload("res://game/board/board_chaos.gd")
const Pedestal = preload("res://art/dart_machine/dart_pedestal.gd")
const Display = preload("res://art/dart_machine/score_display.gd")
const Drive = preload("res://art/dart_machine/dart_drive.gd")
const FlipGuard = preload("res://art/dart_machine/flip_guard.gd")
## 과녁 중심 높이(m). 2026-11-24 사용자 요청으로 2.9 → 2.6 으로 내렸다 — 눈높이 1.65m 에서 너무 올려다봐야 했다.
const BOARD_Y := 2.6
const BOARD_SCALE := 2.5
const SCORE_RADIUS := BoardLayout.RADIUS * BOARD_SCALE
const WINDOW := BoardChaos.WINDOW_RADIUS * SCORE_RADIUS
const HALF_WIDTH := Pedestal.HALF_WIDTH
const HEIGHT := Pedestal.TOP
const FACE_Z := BoardChaos.INFILL_FRONT

@export var arcade_skin := false
@onready var board: BoardView = get_node_or_null("Board")
var arcade := false
var _parts: Node3D
var _cabinet: Pedestal
var _drive: Drive
var _gate: FlipGuard
var _auto_closed := false
var _auto_age := 0.0
var _close := 0.0
var _shown: Dictionary = {}
var _turn_name := ""
var _score := 0.0
var _seat_color := Color.WHITE
var _turn := Vector2i(-1, -1)
var _turn_caption := ""
var _caption_timer: Timer


func _ready() -> void:
	set_process(false)
	if board != null:
		board.position.y = BOARD_Y
		board.scale = Vector3.ONE * BOARD_SCALE
	_caption_timer = Timer.new()
	_caption_timer.one_shot = true
	_caption_timer.timeout.connect(func() -> void:
		_turn_caption = ""
		_update_readout())
	add_child(_caption_timer)
	build(arcade_skin)


func build(arcade_finish: bool) -> void:
	arcade = arcade_finish
	if _parts != null:
		remove_child(_parts)
		_parts.queue_free()
	_parts = Node3D.new()
	_parts.name = "Chassis"
	add_child(_parts)
	var wood := Pedestal.walnut()
	var coal := Kit.material("BoardMachineCoal", "191714")
	var bronze := Kit.material("BoardMachineBronze", "a78056", 0.38)
	var frame := Kit.material("BoardMachineFrame", "353029", 0.16)
	var steel := Kit.material("BoardMachineSteel", "737874", 0.65)
	var lamp := Kit.material("BoardMachineLamp%d" % int(arcade), "caf3e6" if arcade else "ffce81", 0.1, 1.05)
	var armor := Kit.material("FoldedBluedSteel", "414342", 0.51)
	armor.roughness = 0.52
	var armor_edge := Kit.material("FoldedGunmetal", "202629", 0.47)
	_cabinet = Pedestal.new()
	_cabinet.name = "FixedPedestal"
	_parts.add_child(_cabinet)
	_cabinet.build(wood, coal, frame, bronze, lamp)
	_drive = Drive.new()
	_drive.name = "TargetDrive"
	_drive.position.y = BOARD_Y
	_parts.add_child(_drive)
	_drive.build(steel, frame, coal, bronze)
	_gate = FlipGuard.new()
	_gate.name = "FlipPanels"
	_gate.position.y = BOARD_Y
	_parts.add_child(_gate)
	_gate.build(wood, armor, armor_edge, bronze)
	_update_readout()
	show_chaos(_shown if not _shown.is_empty() else BoardChaos.rest(), 0.0)


func show_chaos(shape: Dictionary, _delta: float) -> void:
	if _drive == null: return
	_shown = shape.duplicate()
	_drive.show_pose(shape)
	var move: Vector2 = shape.get("move", Vector2.ZERO)
	_cabinet.set_travel(move.x * SCORE_RADIUS)
	_gate.show_pose(shape)
	_close = float(shape.get("shutter", 0))


func set_readout(display_name: String, total: float, seat_color: Color = Color.WHITE,
		turn: Vector2i = Vector2i(-1, -1), mine: bool = false) -> void:
	if display_name == _turn_name and is_equal_approx(total, _score) and turn == _turn and seat_color == _seat_color:
		return
	if turn != _turn:
		_turn = turn
		_turn_caption = ""
		_caption_timer.stop()
		if not display_name.is_empty():
			_turn_caption = "내 차례!" if mine else "이번 차례"
			_caption_timer.start(2.8)
	_seat_color = seat_color
	_turn_name = display_name
	_score = total
	_update_readout()


func _update_readout() -> void:
	if _cabinet == null:
		return
	_cabinet.turn_text.text = "READY" if _turn_name.is_empty() else _turn_name.left(9)
	var number := Display.score_text(_score)
	_cabinet.score_text.text = "—" if _turn_name.is_empty() else number
	var rows: Array[Dictionary] = []
	if not _turn_name.is_empty():
		rows.append({"label": _turn_name, "score": number, "color": _seat_color})
	_cabinet.header.present(rows, _turn_caption)


func slide_shutter(closed: bool) -> void:
	_auto_closed = closed
	_auto_age = 0.0
	set_process(true)


func _process(delta: float) -> void:
	_auto_age += delta
	var amount := BoardChaos.shutter_amount(_auto_age) if _auto_closed else move_toward(_close, 0, delta * 4.0)
	_gate.show_pose({"shutter": amount, "cover_side": -1})
	_close = amount
	if amount <= 0.0 or amount >= 1.0:
		set_process(false)
