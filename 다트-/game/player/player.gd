class_name PlayerView
extends Node3D

const COLORS: Array[Color] = [Color("f08475"), Color("79ceb5"), Color("eed16c"), Color("b897e5")]

@onready var _head: Node3D = $Head
@onready var _name_label: Label3D = $NameLabel
@onready var _status: BoardView = $StatusBoard

var color: Color
var _reaction: Tween


func configure(player: MatchPlayer, angle: float, is_local: bool) -> void:
	position = Vector3(sin(angle) * 1.8, 0, cos(angle) * 1.8)
	rotation.y = angle + PI
	color = COLORS[player.seat]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	($Body as MeshInstance3D).material_override = material
	($Head/Shape as MeshInstance3D).material_override = material
	_name_label.text = player.display_name
	visible = not is_local
	show_state(player)


func show_state(player: MatchPlayer) -> void:
	_status.show_layout(player.layout)
	_name_label.text = "%s · %d점" % [player.display_name, player.score]


func react() -> void:
	if _reaction != null: _reaction.kill()
	_reaction = create_tween()
	_reaction.tween_property(_head, "scale:y", 0.75, 0.12)
	_reaction.tween_property(_head, "scale:y", 1.1, 0.15)
	_reaction.tween_property(_head, "scale:y", 1.0, 0.15)
