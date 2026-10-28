class_name GameView
extends Node3D
## 공간, 로컬 시점, 방장 이동 시뮬레이션과 경기 기능을 조립한다.
## 조명·배경색은 Table/Pub(art/pub/pub_game.tscn)이 가진다. 여기서는 카메라·손·다트·칠판 점수만 연결한다.

const PLAYER_SCENE: PackedScene = preload("res://game/player/player.tscn")
const DART_SCENE: PackedScene = preload("res://game/dart/dart.tscn")
## 1인칭 손 모양(디자인 담당 생성 코드). class_name 이 없는 도구라 preload 로 부른다.
const CharacterFactory = preload("res://art/characters/character_factory.gd")
## 봇의 차례 행동 계산(방장 전용). class_name 이 없는 도구라 preload 로 부른다.
const BotDriver = preload("res://game/player/bot_driver.gd")
## 카드 그림과 1인칭 손 부채는 카드 라운드 시연 것을 그대로 쓴다 — 카드 모양은 한 곳만 유지한다.
const CardFaces = preload("res://game/card_round/cards/card_faces.gd")
const HandFan = preload("res://game/card_round/cards/hand_fan.gd")
## 칠판 점수판에 쓰는 이름 최대 글자 수(칠판 폭 약 0.95m에 맞춘 값).
const CHALK_NAME_LENGTH: int = 6
const MOTION_INTERVAL: float = 0.05
const INPUT_TIMEOUT: float = 0.35
const MOUSE_SENSITIVITY: float = 0.0025

@onready var controller: MatchController = $MatchController
@onready var throw_input: DartThrowController = $ThrowController
@onready var camera: Camera3D = $Camera
@onready var table: TableView = $Table
@onready var _players_root: Node3D = $Players
@onready var _darts: Node3D = $Darts

var session: NetworkSession
var actors: Dictionary = {}
var developer_enabled: bool = false
var _controls: Dictionary = {}
var _sequence: int = 0
var _motion_sequence: int = 0
var _last_motion_sequence: int = -1
var _send_elapsed: float = 0
var _yaw: float = 0
var _pitch: float = 0
var _jump: bool = false
var _shown_turn: int = -1
var _was_finished: bool = false
var _last_seat_request: Dictionary = {}
## 지금 차례인 봇이 다음 발을 던질 수 있는 시각. 투척선에 선 뒤부터 센다.
var _bot_ready_at: float = 0.0
## 1인칭 왼손 카드 부채와 거기에 지금 올려둔 손패(같으면 다시 만들지 않는다).
var _fan: HandFan
var _shown_hand: Array[int] = []


func _ready() -> void:
	controller.changed.connect(_apply_state)
	controller.dart_thrown.connect(_show_throw)
	throw_input.throw_requested.connect(controller.submit_throw)
	throw_input.camera = camera
	throw_input.board = table.board
	$TrajectoryPreview.hide()
	$Camera/Hand.hide()
	_prepare_hand_fan()


func configure(room: RoomState, local_peer_id: int, connection: NetworkSession = null) -> void:
	session = connection
	controller.configure(room, local_peer_id, session)
	if session != null:
		session.movement_input.connect(_receive_controls)
		session.movement_snapshot.connect(_receive_motion)
		session.game_action.connect(_receive_action)
	controller.solve_throw = solve_dart
	controller.check_seated = is_seated
	controller.force_seat = force_seat
	controller.in_throw_zone = can_throw_from
	for player in controller.state.players:
		var view := PLAYER_SCENE.instantiate() as PlayerView
		view.name = "Player_%d" % player.peer_id
		_players_root.add_child(view)
		view.configure(player)
		actors[player.peer_id] = view
		if player.peer_id == local_peer_id:
			camera.cull_mask = 0xfffff & ~(1 << (player.seat + 1))
			_equip_hand(player.seat)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_apply_state()


## 1인칭 왼손 카드 부채를 카메라에 붙인다. 화면이 없는 서버·검사에서는 만들지 않는다.
func _prepare_hand_fan() -> void:
	if DisplayServer.get_name() == "headless":
		return
	await CardFaces.bake(self)
	if not is_inside_tree():
		return
	_fan = HandFan.new()
	_fan.name = "HandFan"
	_fan.show_keys = true
	_fan.card_scale = 0.75
	_fan.radius = 0.2
	_fan.spread_degrees = 64.0
	_fan.cast_shadows = false
	camera.add_child(_fan)
	# 카드 라운드 시연의 1인칭 부채와 같은 자리(화면 왼쪽 아래).
	_fan.transform = Transform3D(Vector3(0.995, -0.0998, 0), Vector3(0.0998, 0.995, 0), Vector3(0, 0, 1), Vector3(-0.22, -0.4, -0.42))
	_sync_hand_fan()


## 내 손패를 부채에 맞춘다. 스냅샷마다 부르지만 카드가 그대로면 아무것도 안 한다.
func _sync_hand_fan() -> void:
	if _fan == null:
		return
	var me := controller.state.find_player(controller.local_peer_id)
	var hand: Array[int] = me.hand if me != null else []
	if hand == _shown_hand:
		return
	_shown_hand = hand.duplicate()
	for slot in range(CardHandRules.HAND_LIMIT):
		if slot < hand.size():
			_fan.set_card(slot, hand[slot])
		else:
			_fan.remove_card(slot)


## 1인칭 손을 자기 자리 색 소매로 바꾸고, 손에 든 다트 깃도 자리 색으로 칠한다.
func _equip_hand(seat: int) -> void:
	var hand := $Camera/Hand as Node3D
	var old := hand.get_node_or_null("FirstPersonHand")
	if old != null:
		hand.remove_child(old)
		old.queue_free()
	hand.add_child(CharacterFactory.create_hand(seat))
	($Camera/Hand/HeldDart as DartView).paint(PlayerLook.COLORS[seat])


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_jump = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and controller.state.phase != MatchState.Phase.FINISHED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		if event.keycode == KEY_E and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			request_seat()
		if event.keycode == KEY_SPACE and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_jump = true
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * MOUSE_SENSITIVITY
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENSITIVITY, -1.25, 1.25)


func _physics_process(delta: float) -> void:
	if actors.is_empty():
		return
	_send_elapsed += delta
	if _send_elapsed >= MOTION_INTERVAL:
		_send_elapsed = 0
		var axis := Vector2.ZERO
		var crouch: bool = false
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			axis = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
				float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))).limit_length()
			crouch = Input.is_physical_key_pressed(KEY_CTRL)
		if is_processing_unhandled_input():
			send_controls(axis, _yaw, _pitch, _jump, crouch)
		_jump = false
		if multiplayer.is_server():
			_motion_sequence += 1
			var poses: Array[Dictionary] = []
			for actor: PlayerView in actors.values():
				poses.append(actor.to_motion())
			if session != null:
				session.receive_movement.rpc(controller.state.match_id, _motion_sequence, poses)
	if multiplayer.is_server():
		for id: int in actors:
			var actor := actors[id] as PlayerView
			if actor.identity.is_bot:
				_drive_bot(actor, delta)
				continue
			var controls: Dictionary = _controls.get(id, {})
			if controller._now() - float(controls.get("at", 0)) > INPUT_TIMEOUT:
				controls = {}
			actor.simulate(delta, controls)
			if _controls.has(id):
				_controls[id]["jump"] = false


## 봇의 차례 행동(방장만). 자리에서 일어나 투척선까지 걸어가 던지고, 차례가 끝나면 자리로 돌아가 앉는다.
## 사람과 같은 PlayerView.simulate 를 거치므로 이동·충돌·속도 규칙이 같다.
func _drive_bot(actor: PlayerView, delta: float) -> void:
	var state := controller.state
	var active := state.active_player()
	var mine: bool = active != null and active.peer_id == actor.identity.peer_id
	var playing: bool = mine and state.phase in [MatchState.Phase.AIMING, MatchState.Phase.FLIGHT, MatchState.Phase.SETTLING]
	if not playing:
		_walk_bot_home(actor, delta)
		return
	if actor.seated:
		actor.seated = false
		actor.update_posture()
	var spot: Vector3 = BotDriver.throw_spot()
	if not BotDriver.arrived(actor.position, spot):
		# 걸어가는 동안에는 조준 시간을 계속 미룬다 — 선에 선 뒤부터 센다.
		actor.simulate(delta, BotDriver.walk_controls(actor.position, spot))
		_bot_ready_at = controller._now() + BotDriver.AIM_SECONDS
		return
	actor.simulate(delta, BotDriver.aim_controls(actor.position))
	if state.phase == MatchState.Phase.AIMING and controller._now() >= _bot_ready_at:
		controller.bot_throw(BotDriver.random_aim(), BotDriver.random_charge())
		_bot_ready_at = controller._now() + BotDriver.AIM_SECONDS


## 차례가 아닌 봇은 자기 자리로 걸어가 앉는다. 이미 앉아 있으면 건드리지 않는다.
func _walk_bot_home(actor: PlayerView, delta: float) -> void:
	if actor.seated:
		return
	var seat: Vector3 = TableView.SEATS[actor.identity.seat]
	if BotDriver.arrived(actor.position, seat):
		_sit(actor)
		actor.rotation.y = BotDriver.facing_board(actor.position)
		return
	actor.simulate(delta, BotDriver.walk_controls(actor.position, seat))


func send_controls(axis: Vector2, yaw: float, pitch: float, jump: bool, crouch: bool) -> void:
	_sequence += 1
	if multiplayer.is_server():
		_accept_controls(controller.local_peer_id, _sequence, axis, yaw, pitch, jump, crouch)
	else:
		session.request_movement.rpc_id(1, controller.state.match_id, _sequence, {"move": axis, "yaw": yaw, "pitch": pitch, "jump": jump, "crouch": crouch})


func _receive_controls(sender: int, match_id: int, sequence: int, controls: Dictionary) -> void:
	if match_id != controller.state.match_id:
		return
	if not (controls.get("move") is Vector2 and controls.get("yaw") is float and controls.get("pitch") is float and controls.get("jump") is bool and controls.get("crouch") is bool):
		return
	_accept_controls(sender, sequence, controls.move, controls.yaw, controls.pitch, controls.jump, controls.crouch)


func _accept_controls(sender: int, sequence: int, axis: Vector2, yaw: float, pitch: float, jump: bool, crouch: bool) -> void:
	var actor := actors.get(sender) as PlayerView
	if actor == null or actor.identity.is_bot or not axis.is_finite() or not is_finite(yaw) or not is_finite(pitch):
		return
	var previous: Dictionary = _controls.get(sender, {})
	if sequence <= int(previous.get("sequence", -1)):
		return
	_controls[sender] = {"sequence": sequence, "move": axis.limit_length(), "yaw": wrapf(yaw, -PI, PI),
		"pitch": clampf(pitch, -1.25, 1.25), "jump": jump or bool(previous.get("jump", false)),
		"crouch": crouch, "at": controller._now()}


func _receive_motion(match_id: int, sequence: int, poses: Array) -> void:
	if match_id != controller.state.match_id or sequence <= _last_motion_sequence:
		return
	_last_motion_sequence = sequence
	for pose: Dictionary in poses:
		if actors.has(int(pose.id)):
			(actors[int(pose.id)] as PlayerView).apply_motion(pose)


func request_seat() -> void:
	if multiplayer.is_server():
		_accept_seat(controller.local_peer_id)
	else:
		session.request_game_action.rpc_id(1, "seat", [controller.state.match_id])


func _receive_action(sender: int, action: String, payload: Array) -> void:
	if action == "seat" and payload.size() == 1 and payload[0] == controller.state.match_id:
		_accept_seat(sender)


func _accept_seat(sender: int) -> void:
	var actor := actors.get(sender) as PlayerView
	if actor == null or actor.identity.is_bot:
		return
	var now: float = controller._now()
	if now - float(_last_seat_request.get(sender, -1.0)) < 0.2:
		return
	_last_seat_request[sender] = now
	if actor.seated:
		actor.seated = false
		actor.position = TableView.clamp_floor(actor.position + Vector3(0, 0.05, 0.7))
		actor.update_posture()
	elif can_sit(sender):
		_sit(actor)


## 테이블 집합 제한시간이 끝났을 때 방장이 거리와 관계없이 자리로 옮긴다(MatchController._close_table).
func force_seat(id: int) -> void:
	var actor := actors.get(id) as PlayerView
	if actor != null and not actor.seated:
		_sit(actor)


func _sit(actor: PlayerView) -> void:
	actor.seated = true
	actor.crouched = false
	actor.position = TableView.SEATS[actor.identity.seat]
	actor.velocity = Vector3.ZERO
	actor.update_posture()


func can_sit(id: int) -> bool:
	var actor := actors.get(id) as PlayerView
	if actor == null:
		return false
	return actor.position.distance_to(TableView.SEATS[actor.identity.seat]) <= TableView.SEAT_DISTANCE and absf(actor.velocity.y) < 0.5


func is_seated(id: int) -> bool:
	var actor := actors.get(id) as PlayerView
	return actor != null and actor.seated


## 지금 서 있는 자리에서 던질 수 있는지. 라운지(테이블 쪽)에서는 못 던진다.
func can_throw_from(id: int) -> bool:
	var actor := actors.get(id) as PlayerView
	return actor != null and TableView.in_throw_zone(actor.position)


func _process(_delta: float) -> void:
	var local := actors.get(controller.local_peer_id) as PlayerView
	if local == null:
		return
	var state := controller.state
	var own_turn: bool = state.active_player() != null and state.active_player().peer_id == controller.local_peer_id
	camera.position = local.eye_position()
	camera.rotation = Vector3(_pitch, _yaw, 0)
	# 다트 홀 밖(라운지)에서는 조준·충전 자체를 잠근다 — 방장도 같은 조건으로 거부한다.
	var can_aim: bool = own_turn and state.phase == MatchState.Phase.AIMING and can_throw_from(controller.local_peer_id)
	throw_input.enabled = can_aim and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	$Camera/Hand.visible = throw_input.enabled
	# 지금 차례인 사람이 조준 중이면 그 캐릭터가 오른팔을 든다(다른 사람 화면에도 보인다).
	var active := state.active_player()
	for actor: PlayerView in actors.values():
		var turn: bool = active != null and actor.identity.peer_id == active.peer_id and state.phase == MatchState.Phase.AIMING
		# 봇은 투척선까지 걸어가는 동안에는 아직 팔을 들지 않는다.
		actor.aiming = turn and (not actor.identity.is_bot or BotDriver.arrived(actor.position, BotDriver.throw_spot()))
	if throw_input.enabled:
		throw_input.aim = throw_input.aim_at(get_viewport().get_visible_rect().size * 0.5)
	if state.phase == MatchState.Phase.FINISHED and not _was_finished:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_was_finished = state.phase == MatchState.Phase.FINISHED


func _apply_state() -> void:
	for id: int in actors.keys():
		var player := controller.state.find_player(id)
		if player == null:
			var actor := actors[id] as PlayerView
			_players_root.remove_child(actor)
			actor.queue_free()
			actors.erase(id)
			_controls.erase(id)
		else:
			(actors[id] as PlayerView).show_state(player)
	_sync_hand_fan()
	table.set_chalk_scores(_chalk_text())
	if _shown_turn != controller.state.turn_id:
		_shown_turn = controller.state.turn_id
		_clear_darts()


func _show_throw(data: Dictionary) -> void:
	var dart := DART_SCENE.instantiate() as DartView
	_darts.add_child(dart)
	# 모든 화면은 방장의 시작점/종점/시간으로 같은 포물선을 재현한다.
	dart.fly(data.start, data.target, data.duration, true, $Camera/Hand.position)
	# 깃 = 던진 사람 자리 색, 그 캐릭터는 던지기 몸짓을 한다.
	var thrower := actors.get(int(data.get("peer_id", 0))) as PlayerView
	if thrower != null:
		dart.paint(thrower.color)
		thrower.play_throw()


## 과녁 왼쪽 칠판 글자: 자리 순서대로 "● 이름  점수".
func _chalk_text() -> String:
	var lines := PackedStringArray(["점 수", ""])
	var players := controller.state.players.duplicate()
	players.sort_custom(func(a: MatchPlayer, b: MatchPlayer) -> bool: return a.seat < b.seat)
	for player: MatchPlayer in players:
		lines.append("%s  %d" % [PlayerLook.tag(player.seat, player.display_name.left(CHALK_NAME_LENGTH)), player.score])
	return "\n".join(lines)


func _clear_darts() -> void:
	for child in _darts.get_children():
		_darts.remove_child(child)
		child.queue_free()


func solve_dart(aim: Vector2, charge: float, peer_id: int = 0) -> Dictionary:
	var config := throw_input.config
	var actor: PlayerView = actors[peer_id if peer_id != 0 else controller.local_peer_id] as PlayerView
	var start: Vector3 = actor.eye_position()
	var radius: float = BoardLayout.RADIUS * TableView.BOARD_SCALE
	var aim_target := TableView.BOARD_CENTER + Vector3(aim.x * radius, aim.y * radius, 0)
	var speed: float = lerpf(config.minimum_speed, config.maximum_speed, charge)
	var direction: Vector3 = (aim_target - start).normalized()
	var nominal_time: float = start.distance_to(aim_target) / config.maximum_speed
	var initial: Vector3 = direction * speed + Vector3.UP * config.gravity * nominal_time * 0.5
	var board_time: float = (TableView.BOARD_CENTER.z - start.z) / initial.z
	var previous: Vector3 = start
	var previous_time: float = 0
	var step: float = 1.0 / 120.0
	while previous_time < config.flight_limit:
		var time: float = minf(previous_time + step, config.flight_limit)
		var crosses_board: bool = board_time > previous_time and board_time <= time
		if crosses_board:
			time = board_time
		var point: Vector3 = config.position_at(start, initial, time)
		var query := PhysicsRayQueryParameters3D.create(previous, point, 1)
		var collision: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if not collision.is_empty():
			var ratio: float = previous.distance_to(collision.position) / maxf(previous.distance_to(point), 0.0001)
			var hit_time: float = lerpf(previous_time, time, ratio)
			var reason: String = "바닥 · 실패" if collision.normal.y > 0.5 else "벽 · 실패"
			return _flight_result(start, collision.position, maxf(hit_time, 0.01), Vector2.INF, 0, reason)
		if crosses_board:
			var hit := Vector2(point.x - TableView.BOARD_CENTER.x, point.y - TableView.BOARD_CENTER.y) / radius
			if hit.length() <= 1.0 + BoardScorer.BOUNDARY_EPSILON:
				var points: int = BoardScorer.score(hit, BoardLayout.new())
				return _flight_result(start, point, time, hit, points, "%d점 적중" % points)
		previous = point
		previous_time = time
	return _flight_result(start, previous, config.flight_limit, Vector2.INF, 0, "비행 제한시간 · 실패")


func _flight_result(start: Vector3, target: Vector3, duration: float, hit: Vector2, points: int, reason: String) -> Dictionary:
	# 실패의 무한 좌표는 네트워크/JSON에 넣지 않는다.
	return {"start": start, "target": target, "duration": duration, "x": hit.x if hit.is_finite() else 99.0,
		"y": hit.y if hit.is_finite() else 99.0, "points": points, "base": points, "reason": reason}
