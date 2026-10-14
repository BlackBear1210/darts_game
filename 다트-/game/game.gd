class_name GameView
extends Node3D
## 경기 상태를 공간·입력·다트 표현에 연결한다. 규칙을 직접 계산하지 않는다.

const PLAYER_SCENE: PackedScene = preload("res://game/player/player.tscn")
const DART_SCENE: PackedScene = preload("res://game/dart/dart.tscn")

@onready var controller: MatchController = $MatchController
@onready var throw_input: ThrowController = $ThrowController
@onready var camera: Camera3D = $Camera
@onready var table: TableView = $Table
@onready var _players_root: Node3D = $Players
@onready var _darts: Node3D = $Darts
@onready var _hand: Node3D = $Camera/Hand

var _players: Dictionary = {}
var _shown_turn: int = 0
var _last_phase: MatchState.Phase = MatchState.Phase.WAITING
var _last_hit: String = ""


func _ready() -> void:
	controller.changed.connect(_apply_state)
	controller.dart_thrown.connect(_show_throw)
	controller.emote_received.connect(_show_reaction)
	throw_input.throw_requested.connect(controller.submit_throw)
	throw_input.camera = camera
	throw_input.board = table.board


func configure(room: RoomState, local_peer_id: int) -> void:
	controller.configure(room, local_peer_id)
	for player in controller.state.players:
		var angle := _seat_angle(player.peer_id)
		var view := PLAYER_SCENE.instantiate() as PlayerView
		view.name = "Player_%d" % player.peer_id
		_players_root.add_child(view)
		view.configure(player, angle, player.peer_id == local_peer_id)
		_players[player.peer_id] = view
		if player.peer_id == local_peer_id:
			camera.position = view.position + Vector3.UP * TableView.RAISED_HEIGHT
			camera.look_at(Vector3.UP * TableView.RAISED_HEIGHT, Vector3.UP)
			var material := StandardMaterial3D.new()
			material.albedo_color = view.color
			($Camera/Hand/Shape as MeshInstance3D).material_override = material
	_apply_state()


func _process(_delta: float) -> void:
	var state := controller.state
	var own_turn := state.active_player() != null and state.active_player().peer_id == controller.local_peer_id
	throw_input.enabled = own_turn and state.phase == MatchState.Phase.AIMING and table.is_ready
	_hand.visible = own_turn and state.phase in [MatchState.Phase.PREPARING, MatchState.Phase.AIMING]
	for view: PlayerView in _players.values():
		if not view.visible: continue
		var status := view.get_node("StatusBoard") as Node3D
		status.look_at(camera.global_position, Vector3.UP, true)


func _apply_state() -> void:
	var state := controller.state
	for player in state.players:
		if _players.has(player.peer_id): (_players[player.peer_id] as PlayerView).show_state(player)
	if state.phase == MatchState.Phase.PREPARING and _shown_turn != state.turn_id:
		_shown_turn = state.turn_id
		_clear_darts()
		table.prepare(_seat_angle(state.active_player().peer_id), state.active_player().layout, controller.config.transition_seconds)
		camera.look_at(Vector3.UP * TableView.RAISED_HEIGHT, Vector3.UP)
	if state.phase != _last_phase and state.phase in [MatchState.Phase.CARDS, MatchState.Phase.FINISHED]:
		_clear_darts()
		table.lower()
		camera.look_at(Vector3(0, 0.95, 0), Vector3.UP)
	_last_phase = state.phase
	if not state.last_hit.is_empty():
		var key := "%d:%d" % [state.turn_id, state.last_hit.request_id]
		if key != _last_hit:
			_last_hit = key
			(_players[state.last_hit.peer_id] as PlayerView).react()


func _show_throw(data: Dictionary) -> void:
	var angle := _seat_angle(data.peer_id)
	var actor := _players[data.peer_id] as PlayerView
	var start := actor.global_position + Vector3.UP * TableView.RAISED_HEIGHT + Basis(Vector3.UP, angle) * _hand.position
	var impact := Vector3(float(data.x) * BoardLayout.RADIUS, float(data.y) * BoardLayout.RADIUS, 0)
	var target := Basis(Vector3.UP, angle) * impact + Vector3.UP * TableView.RAISED_HEIGHT
	var dart := DART_SCENE.instantiate() as DartView
	_darts.add_child(dart)
	dart.fly(start, target, data.duration, Vector2(data.x, data.y).length() <= 1.0)


func _show_reaction(data: Dictionary) -> void:
	if _players.has(data.peer_id): (_players[data.peer_id] as PlayerView).react()


func _seat_angle(peer_id: int) -> float:
	for index in range(controller.state.players.size()):
		if controller.state.players[index].peer_id == peer_id:
			return index * TAU / controller.state.players.size()
	return 0.0


func _clear_darts() -> void:
	for child in _darts.get_children():
		_darts.remove_child(child)
		child.queue_free()
