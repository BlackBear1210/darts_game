class_name TableView
extends Node3D

const RAISED_HEIGHT: float = 1.35
const LOWERED_HEIGHT: float = 0.35

@onready var board: BoardView = $BoardPivot/Board
@onready var _pivot: Node3D = $BoardPivot

var is_ready: bool = false
var _motion: Tween


func prepare(angle: float, layout: BoardLayout, duration: float) -> void:
	if _motion != null: _motion.kill()
	is_ready = false
	board.visible = true
	board.show_layout(layout)
	_motion = create_tween()
	_motion.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_motion.tween_property(_pivot, "position:y", LOWERED_HEIGHT, duration * 0.3)
	_motion.tween_property(_pivot, "rotation:y", angle, duration * 0.2)
	_motion.tween_property(_pivot, "position:y", RAISED_HEIGHT, duration * 0.5)
	_motion.tween_callback(func() -> void: is_ready = true)


func lower() -> void:
	if _motion != null: _motion.kill()
	is_ready = false
	_motion = create_tween()
	_motion.tween_property(_pivot, "position:y", LOWERED_HEIGHT, 0.25)
	_motion.tween_callback(func() -> void: board.visible = false)
