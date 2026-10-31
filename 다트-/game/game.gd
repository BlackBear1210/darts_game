class_name GameView
extends Node3D
## 공간, 로컬 시점, 방장 이동 시뮬레이션과 경기 기능을 조립한다.
## 조명·배경색은 Table/Pub(art/pub/pub_game.tscn)이 가진다. 여기서는 카메라·손·다트·칠판 점수만 연결한다.

signal settings_requested(mode: String)
const Preferences = preload("res://ui/player_preferences.gd")
const LoungeWorld = preload("res://game/lounge/lounge_world.gd")
const Sfx = preload("res://art/audio/sfx.gd")
const BurstFx = preload("res://art/fx/burst_fx.gd")
var lounge: Node3D
var lounge_hud: CanvasLayer
var _screen_fx: CanvasLayer
var _cover: MeshInstance3D
var _last_quality: int = -1

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
## 자리에 앉는 순간 시선을 테이블 가운데로 돌리고 이만큼 내려다본다(라디안, 약 -27도).
## 2026-10-31: 앉으면 테이블이 아래로 보여 내 매트·옆자리 매트 카드가 한눈에 들어오게(사용자 요청). 그 뒤로는 마우스로 자유롭게 본다.
const SEATED_LOOK_PITCH: float = -0.47
const SeatCards = preload("res://game/table/seat_cards.gd")
## 다른 사람 캐릭터의 왼손 카드 부채(2026-10-31 저녁). 굽기 뒤에 seat_cards 와 같이 만든다.
const HeldCards = preload("res://game/table/held_cards.gd")
## T 감정표현(2026-10-31 저녁 — F6 시연에만 있던 것을 F5 에 연결).
const Emotes = preload("res://game/lounge/emotes.gd")
## 카드 충전 라운드의 덱 섞기·나눠 주기 연출(2026-10-31 늦은 밤 — F6 시연에만 있던 것을 F5 에 연결). 보이기만 한다.
const DeckShow = preload("res://game/table/deck_show.gd")

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
## 소품 던지기 힘 모으기: 우클릭을 누른 시각(초). -1 = 안 누름. 꽉 차는 데 PROP_CHARGE_TIME 초.
var _prop_charge_from: float = -1.0
const PROP_CHARGE_TIME: float = 1.0
var _shown_hand: Array[int] = []
## 손맛 연출(보이기만): 1인칭 손 기본 자세, 내가 던진 직후 1→0 으로 줄어드는 반동, 과녁 흔들림.
var _hand_base: Transform3D
var _throw_kick: float = 0.0
var _board_shake: float = 0.0
## 지금 날아가는 다트(궤적 카드로 꽂히는 자리가 바뀌면 이 다트를 휘게 한다).
var _flying_dart: DartView
## 테이블 자리 매트 위 카드(각자 손패를 앞면으로 깐다 — 2026-10-31 저녁 결정, 엿보면 옆자리 카드가 내 화면에서 크게 펼쳐진다). 화면이 없으면 만들지 않는다.
var seat_cards: Node3D
var held_cards: Node
var emotes: Node
var deck_show: Node3D
## 지난 프레임에 내가 앉아 있었는지. 앉는 순간만 시선을 테이블로 돌린다(_face_table_on_sit).
var _was_seated: bool = false


func _ready() -> void:
	controller.changed.connect(_apply_state)
	controller.dart_thrown.connect(_show_throw)
	controller.dart_redirected.connect(_redirect_throw)
	throw_input.throw_requested.connect(controller.submit_throw)
	throw_input.camera = camera
	throw_input.board = table.board
	$TrajectoryPreview.hide()
	$Camera/Hand.hide()
	_hand_base = ($Camera/Hand as Node3D).transform
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
	emotes = Emotes.new()
	emotes.name = "Emotes"
	add_child(emotes)
	emotes.setup(self)
	for player in controller.state.players:
		var view := PLAYER_SCENE.instantiate() as PlayerView
		view.name = "Player_%d" % player.peer_id
		_players_root.add_child(view)
		view.configure(player)
		actors[player.peer_id] = view
		if player.peer_id == local_peer_id:
			camera.cull_mask = 0xfffff & ~(1 << (player.seat + 1))
			_equip_hand(player.seat)
	if room.settings.social_lobby:
		lounge = LoungeWorld.new()
		lounge.name = "LoungeWorld"
		add_child(lounge)
		lounge.configure(self)
		if DisplayServer.get_name() != "headless":
			_screen_fx = preload("res://game/card_round/fx/screen_debuff.gd").new()
			add_child(_screen_fx)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(BoardLayout.RADIUS * TableView.BOARD_SCALE, BoardLayout.RADIUS * TableView.BOARD_SCALE * 2, 0.05)
		_cover = MeshInstance3D.new()
		_cover.mesh = mesh
		_cover.material_override = preload("res://art/mesh_kit.gd").material("card_cover", "243b49")
		_cover.position = TableView.BOARD_CENTER + Vector3(-mesh.size.x / 2, 0, 0.08)
		_cover.hide()
		add_child(_cover)
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
	# 테이블 매트 카드도 카드 그림을 쓰므로 굽기 뒤에 만든다(굽기 전에 그림을 부르면 단색 그림으로 굳는다).
	seat_cards = SeatCards.new()
	seat_cards.name = "SeatCards"
	add_child(seat_cards)
	seat_cards.show_hands(controller.state.players)
	deck_show = DeckShow.new()
	deck_show.name = "DeckShow"
	deck_show.seat_cards = seat_cards
	add_child(deck_show)
	deck_show.sync(controller.state)
	held_cards = HeldCards.new()
	held_cards.name = "HeldCards"
	add_child(held_cards)
	held_cards.sync(actors, controller.state.players, controller.local_peer_id)


## 내 손패를 부채에 맞추고 꺼내 든 카드를 위로 올린다. 스냅샷마다 부르지만 카드가 그대로면 다시 만들지 않는다.
func _sync_hand_fan() -> void:
	if _fan == null:
		return
	var me := controller.state.find_player(controller.local_peer_id)
	var hand: Array[int] = []
	if me != null: hand.assign(me.hand)
	if hand != _shown_hand:
		_shown_hand = hand.duplicate()
		for slot in range(CardHandRules.HAND_LIMIT):
			if slot < hand.size():
				_fan.set_card(slot, hand[slot])
			else:
				_fan.remove_card(slot)
	var pending_slot: int = me.pending_slot if me != null else -1
	if pending_slot != _fan.lifted_slot:
		if pending_slot >= 0: _fan.lift(pending_slot)
		else: _fan.lower()


## 1인칭 손을 자기 자리 색 소매로 바꾸고, 손에 든 다트 깃도 자리 색으로 칠한다.
func _equip_hand(seat: int) -> void:
	var hand := $Camera/Hand as Node3D
	var old := hand.get_node_or_null("FirstPersonHand")
	if old != null:
		hand.remove_child(old)
		old.queue_free()
	hand.add_child(CharacterFactory.create_hand(seat))
	($Camera/Hand/HeldDart as DartView).paint(PlayerLook.COLORS[seat])


## 소품 던질 힘(0~1). 우클릭을 안 누르고 있으면 -1. HUD 충전 막대도 이 값을 쓴다.
func prop_charge() -> float:
	if _prop_charge_from < 0.0: return -1.0
	return clampf((Time.get_ticks_msec() / 1000.0 - _prop_charge_from) / PROP_CHARGE_TIME, 0.0, 1.0)


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_jump = false
		_prop_charge_from = -1.0


func _unhandled_input(event: InputEvent) -> void:
	# T 감정표현 피자판이 먼저 받는다(열려 있으면 마우스 클릭·Esc 도 피자판 것).
	if emotes != null and emotes.handle(event):
		get_viewport().set_input_as_handled()
		return
	if lounge != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var id: int = controller.local_peer_id
		var hit: Dictionary = lounge.focus(id)
		if event is InputEventMouseButton and event.pressed:
			# 병·캡슐을 든 채 좌클릭 = 한 모금 / 내가 열기(2026-10-31: 상호작용을 F 로 옮기며 마시기 키를 없앴다).
			# 들고 있으면 다트 투척 입력이 꺼져 있어 겹치지 않는다 → 다트를 던지려면 먼저 내려놓는다.
			if event.button_index == MOUSE_BUTTON_LEFT and lounge.held(id) >= 0:
				lounge.request("drink")
				get_viewport().set_input_as_handled()
				return
			if event.button_index == MOUSE_BUTTON_LEFT and hit.get("kind") == "prop":
				lounge.request("take")
				get_viewport().set_input_as_handled()
				return
			if event.button_index == MOUSE_BUTTON_RIGHT and lounge.held(id) >= 0:
				# 우클릭을 누르는 동안 힘을 모은다(놓을 때 던진다). 짧게 누르면 살짝 놓기.
				_prop_charge_from = Time.get_ticks_msec() / 1000.0
				get_viewport().set_input_as_handled()
				return
		if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and _prop_charge_from >= 0.0:
			lounge.request("throw", prop_charge())
			_prop_charge_from = -1.0
			get_viewport().set_input_as_handled()
			return
		if event is InputEventKey and event.pressed and not event.echo:
			# F(상호작용 키) = 꺼내 든 카드 쓰기가 먼저다(2026-10-31 저녁 사용자 요청: Enter 대신 F 한 키로 빠르게).
			# 카드를 꺼내 들지 않았을 때만 아래의 기계·착석으로 넘어간다 → 카드는 Q·E(1~7)로 들고 F 로 쓴다.
			if event.keycode == Preferences.interact_key and lounge_hud != null and lounge_hud.use_lifted_card():
				get_viewport().set_input_as_handled()
				return
			if event.keycode == KEY_ENTER and session.room.phase == RoomState.Phase.LOBBY:
				var player: RoomPlayer = session.room.find_player(id)
				if player != null and is_seated(id): session.set_ready(not player.is_ready)
				get_viewport().set_input_as_handled()
				return
			if event.keycode == Preferences.interact_key and not hit.is_empty() and hit.get("kind") != "prop":
				match str(hit.kind):
					"monitor":
						if session.is_room_host(): settings_requested.emit("room")
					"power": lounge.request("power")
					"volume": lounge.request("volume")
					"link":
						if lounge_hud != null: lounge_hud.open_link()
					"claw", "gacha", "hoop": lounge.request(str(hit.kind), int(hit.get("index", 0)))
					# 도면 v3: 종·럼주통·생맥주 통·연습 과녁·축음기 건드리기(소리 + 흔들림).
					"touch": lounge.request("touch", int(hit.get("index", 0)))
				get_viewport().set_input_as_handled()
				return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and controller.state.phase != MatchState.Phase.FINISHED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		if event.keycode == Preferences.interact_key and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			request_seat()
		if event.keycode == KEY_SPACE and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			# 앉아 있으면 Space = 일어서기(점프 대신). F 가 카드 쓰기로 바쁠 때도 언제든 일어날 수 있다.
			if is_seated(controller.local_peer_id): request_seat()
			else: _jump = true
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * MOUSE_SENSITIVITY * Preferences.sensitivity
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENSITIVITY * Preferences.sensitivity, -1.25, 1.25)


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
		var local: PlayerView = actors.get(controller.local_peer_id)
		if local != null and local.seated and axis.y > 0:
			_yaw -= MOTION_INTERVAL * 0.65
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
				if lounge != null and lounge.is_stunned(id): actor.simulate(delta, {})
				else: _drive_bot(actor, delta)
				continue
			var controls: Dictionary = _controls.get(id, {})
			if controller._now() - float(controls.get("at", 0)) > INPUT_TIMEOUT:
				controls = {}
			if lounge != null and lounge.is_stunned(id): controls = {}
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
		actor.position = TableView.standing_spot(actor.identity.seat)
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
		if session != null and session.room.phase == RoomState.Phase.LOBBY:
			session._accept_ready(sender, false)
		actor.position = TableView.standing_spot(actor.identity.seat)
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


## 내가 앉는 순간 한 번: 테이블 가운데를 보고 SEATED_LOOK_PITCH 만큼 내려다본다(매트 카드가 화면에 들어온다).
## 앉아 있는 동안에는 건드리지 않는다 — 고개는 마우스로 자유롭게 돌린다.
func _face_table_on_sit(local: PlayerView) -> void:
	if local.seated and not _was_seated:
		var toward: Vector3 = TableView.TABLE_CENTER - local.global_position
		# 이 노드들의 정면은 -Z 다 → 정면이 toward 를 보게 하는 yaw = atan2(-x, -z).
		_yaw = atan2(-toward.x, -toward.z)
		_pitch = SEATED_LOOK_PITCH
	_was_seated = local.seated


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
	return actor != null and TableView.in_throw_zone(actor.position) and (lounge == null or not lounge.is_stunned(id))


## 1인칭 손: 충전할수록 뒤로 빠지고(최대 충전이면 살짝 떨림), 놓으면 앞으로 튕겼다 사라진다.
## 과녁도 다트가 꽂히면 잠깐 움찔한다. 둘 다 내 화면 연출이고 판정 좌표는 그대로다.
func _animate_hand(delta: float) -> void:
	_throw_kick = maxf(0.0, _throw_kick - delta * 3.2)
	_board_shake = maxf(0.0, _board_shake - delta * 4.0)
	var hand := $Camera/Hand as Node3D
	var pull: float = throw_input.timing if throw_input.charging else 0.0
	var now: float = Time.get_ticks_msec() / 1000.0
	var tremble := Vector3(sin(now * 47.0), cos(now * 39.0), 0.0) * 0.0025 * pull * pull
	var snap: float = sin(_throw_kick * PI)
	hand.transform = _hand_base.translated_local(Vector3(0.025, -0.03, 0.11) * pull + tremble + Vector3(-0.01, 0.035, -0.17) * snap)
	hand.visible = throw_input.enabled or _throw_kick > 0.0
	($Camera/Hand/HeldDart as Node3D).visible = _throw_kick <= 0.0
	camera.rotation.x += snap * 0.02
	table.board.position = TableView.BOARD_CENTER + Vector3(sin(now * 70.0) * 0.006, 0.0, -0.012) * _board_shake


func _process(delta: float) -> void:
	var local := actors.get(controller.local_peer_id) as PlayerView
	if local == null:
		return
	var state := controller.state
	var own_turn: bool = state.active_player() != null and state.active_player().peer_id == controller.local_peer_id
	_face_table_on_sit(local)
	camera.position = local.eye_position()
	# 엿보기(앉아서 A·D): 몸이 기운 쪽으로 화면도 기운다(레식 기울이기). 마시는 중이면 고개가 뒤로 젖혀진다.
	camera.rotation = Vector3(_pitch + local.drink_pose_tilt() * PlayerView.DRINK_LOOK_UP, _yaw, local.peek_roll())
	if seat_cards != null:
		seat_cards.show_peek(local, delta)
	if lounge != null:
		var amount: float = lounge.intoxication_amount(controller.local_peer_id)
		if Preferences.visual_effects and not Preferences.reduced_motion:
			camera.rotation.z += sin(Time.get_ticks_msec() / 780.0) * amount * 0.025
		if _screen_fx != null:
			_screen_fx.drowsy = Preferences.visual_effects and bool(local.identity.card_effects.get("drowsy", false))
			_screen_fx.penalty = 3 if Preferences.visual_effects and amount > 1.4 else 0
		if _last_quality != Preferences.quality:
			_last_quality = Preferences.quality
			get_viewport().scaling_3d_scale = [0.65, 0.85, 1.0][_last_quality]
			get_viewport().msaa_3d = Viewport.MSAA_2X if _last_quality == 2 else Viewport.MSAA_DISABLED
		for actor: PlayerView in actors.values():
			var identity: RoomPlayer = session.room.find_player(actor.identity.peer_id)
			actor.ready_pose = session.room.phase == RoomState.Phase.LOBBY and identity != null and identity.is_ready
		var current: MatchPlayer = state.active_player()
		if current != null:
			table.board.show_layout(current.layout)
			_cover.visible = bool(current.card_effects.get("cover", false)) and state.phase in [MatchState.Phase.AIMING, MatchState.Phase.FLIGHT]
	# 다트 홀 밖(라운지)에서는 조준·충전 자체를 잠근다 — 방장도 같은 조건으로 거부한다.
	var can_aim: bool = own_turn and state.phase == MatchState.Phase.AIMING and can_throw_from(controller.local_peer_id)
	throw_input.enabled = can_aim and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and (lounge == null or (lounge.held(controller.local_peer_id) < 0 and lounge.focus(controller.local_peer_id).is_empty()))
	_animate_hand(delta)
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
	if seat_cards != null:
		seat_cards.show_hands(controller.state.players)
	# 카드 충전 라운드로 들어오면 덱 섞기·나눠 주기를 각 화면에서 재생한다(새 카드는 닿을 때까지 매트에서 숨김).
	if deck_show != null:
		deck_show.sync(controller.state)
	if held_cards != null:
		held_cards.sync(actors, controller.state.players, controller.local_peer_id)
	table.set_chalk_scores(_chalk_text())
	if _shown_turn != controller.state.turn_id:
		_shown_turn = controller.state.turn_id
		_clear_darts()


func _show_throw(data: Dictionary) -> void:
	var dart := DART_SCENE.instantiate() as DartView
	_darts.add_child(dart)
	# 모든 화면은 방장의 시작점/종점/시간으로 같은 포물선을 재현한다.
	dart.fly(data.start, data.target, data.duration, true, $Camera/Hand.position)
	_flying_dart = dart
	# 깃 = 던진 사람 자리 색, 그 캐릭터는 던지기 몸짓을 한다.
	var thrower := actors.get(int(data.get("peer_id", 0))) as PlayerView
	if thrower != null:
		dart.paint(thrower.color)
		thrower.play_throw()
		if thrower.identity.peer_id == controller.local_peer_id:
			_throw_kick = 1.0
	dart.landed.connect(_on_dart_landed)
	Sfx.play_at(self, "whoosh", data.start, -8.0)


func _redirect_throw(data: Dictionary) -> void:
	if is_instance_valid(_flying_dart):
		_flying_dart.redirect(data.target, float(data.remaining))


## 다트가 멈춘 순간의 손맛: 과녁이 움찔하고 코르크 가루가 튀며 "턱" 소리가 난다. 판정과 무관하다.
func _on_dart_landed(at: Vector3, hit_board: bool) -> void:
	if hit_board:
		_board_shake = 1.0
		BurstFx.spawn(self, "cork", at, table.board.global_basis.z)
		Sfx.play_at(self, "thunk", at, 0.0, randf_range(0.92, 1.08))
	else:
		Sfx.play_at(self, "bounce", at, -4.0)


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
				var points: int = BoardScorer.score(hit, actor.identity.layout)
				return _flight_result(start, point, time, hit, points, "%d점 적중" % points)
		previous = point
		previous_time = time
	return _flight_result(start, previous, config.flight_limit, Vector2.INF, 0, "비행 제한시간 · 실패")


func _flight_result(start: Vector3, target: Vector3, duration: float, hit: Vector2, points: int, reason: String) -> Dictionary:
	# 실패의 무한 좌표는 네트워크/JSON에 넣지 않는다.
	return {"start": start, "target": target, "duration": duration, "x": hit.x if hit.is_finite() else 99.0,
		"y": hit.y if hit.is_finite() else 99.0, "points": points, "base": points, "reason": reason}


func sync_room(room: RoomState) -> void:
	controller.room_settings = room.settings
	if room.settings.social_lobby:
		controller.config.rounds = room.settings.rounds
		controller.config.turn_seconds = room.settings.dart_seconds
	controller.sync_roster(room)
	if room.phase == RoomState.Phase.LOBBY:
		for player in controller.state.players:
			if actors.has(player.peer_id): continue
			var view := PLAYER_SCENE.instantiate() as PlayerView
			_players_root.add_child(view)
			view.configure(player)
			actors[player.peer_id] = view
	_apply_state()
	if lounge != null: lounge.apply_theme()
