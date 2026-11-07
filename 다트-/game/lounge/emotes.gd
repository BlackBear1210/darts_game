extends Node
## F5 감정표현(2026-10-31 저녁 사용자 요청: "이모티콘이 사라졌다 — T 로 골라서 마이크 없이도 쓰게").
## T 원형 메뉴: 마우스 휠로 이모티콘 8개 / 수신 모션 7개+중지 페이지 전환.
##   T 를 누른 채 방향 선택 후 떼기/왼클릭 = 실행 · 짧게 톡 누르기 = 메뉴 유지 · Esc = 취소.
##   보낸 감정은 그 사람 머리 위 말풍선 + 효과음(fx/emote_bubble.gd). 내 것은 내 화면 아래에 크게(ui/emote_wheel.gd show_mine).
## 네트워크: 손님 → 방장 "emote" 요청 → 방장이 간격(EMOTE_GAP)을 확인하고 모두에게 "emote" 이벤트. 방장은 자기 화면에도 바로 띄운다.
## 봇도 킬로그를 보고 반응한다(방장만): 카드를 맞으면 으악/흑흑, 카드를 쓰면 메롱, 다트 고득점이면 최고/ㅋㅋㅋ, 0점이면 흑흑.

const EmoteWheel = preload("res://game/card_round/ui/emote_wheel.gd")
const EmoteBubble = preload("res://game/card_round/fx/emote_bubble.gd")
const EmoteArt = preload("res://game/card_round/fx/emote_art.gd")
const MotionEmotes = preload("res://art/characters/motion_emotes.gd")

## 한 사람이 감정을 다시 보낼 수 있는 간격(초). 도배 방지.
const EMOTE_GAP: float = 1.0
## 감정 번호(fx/emote_art.gd 순서: ㅋㅋㅋ · 최고! · 으악! · 흑흑 · 헉! · 메롱~ · 좋아해 · GG).
const LAUGH: int = 0
const THUMBS: int = 1
const ANGRY: int = 2
const CRY: int = 3
const WOW: int = 4
const TEASE: int = 5
const LOVE: int = 6
const GG: int = 7
## 봇이 반응할 확률과 봇마다 다시 반응하기까지의 시간(초) — 너무 시끄럽지 않게.
const BOT_CHANCE: float = 0.45
const BOT_COOLDOWN: float = 6.0
## 말풍선 자리(m, 캐릭터 발 기준): 앉은 머리 오른쪽 옆, 이름표 PlayerView.LABEL_HEIGHT(2.0) 보다 아래.
## 머리 위(2.4 m)에 두면 테이블 건너편 봇의 말풍선이 위 가운데 라운드 표시에 가려졌다(render_match_ui 06 화면).
const BUBBLE_HEIGHT: float = 1.72
const BUBBLE_SIDE: float = 0.48
## 다트 한 발 점수가 이 이상이면 봇이 좋아한다.
const BOT_HAPPY_POINTS: int = 40
## 모션 재생 중 자기 모습을 보여 주는 카메라 거리(m).
const MOTION_CAMERA_OFFSET := Vector3(1.0, 1.45, -3.0)

var game: GameView
var wheel: EmoteWheel
## peer_id → 마지막으로 감정을 보낸 시각(방장 기준).
var _last_sent: Dictionary = {}
## 봇 반응: 이미 본 킬로그 줄 · 봇마다 다음 반응 가능 시각.
var _seen_feed: Dictionary = {}
var _bot_ready: Dictionary = {}
var _random := RandomNumberGenerator.new()
var _motion_camera: Camera3D


func setup(view: GameView) -> void:
	game = view
	_random.randomize()
	if game.session != null:
		game.session.game_action.connect(_receive_action)
		game.session.game_event.connect(_receive_event)
	if DisplayServer.get_name() == "headless":
		return
	wheel = EmoteWheel.new()
	wheel.name = "EmoteWheel"
	add_child(wheel)
	wheel.chosen.connect(request)
	wheel.closed.connect(func() -> void:
		if is_inside_tree(): Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)


## T 키·피자판 입력. GameView._unhandled_input 보다 먼저 받도록 GameView 가 넘겨준다. 처리했으면 true.
func handle(event: InputEvent) -> bool:
	if wheel == null:
		return false
	if event is InputEventKey and (event as InputEventKey).keycode == KEY_T and not event.echo:
		if event.pressed and not wheel.is_open and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			# 열려 있는 동안만 마우스 포인터를 보이고 화면 가운데로 옮긴다(시연 local_input.gd 와 같게).
			wheel.open()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_viewport().warp_mouse(get_viewport().get_visible_rect().size * 0.5)
			return true
		if not event.pressed:
			wheel.release_key()
			return true
	if not wheel.is_open:
		return false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		wheel.pick()
		return true
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		wheel.close()
		return true
	return false


## 내가 index 감정을 보낸다.
func request(index: int) -> void:
	if index >= EmoteArt.COUNT and index < EmoteArt.COUNT + MotionEmotes.STOP and not _can_motion(game.controller.local_peer_id):
		if wheel != null:
			wheel.show_notice("일어나서 사용하세요 · 조준/소품은 내려놓기")
		return
	if game.session == null or game.session.is_host():
		_accept(game.controller.local_peer_id, index)
	else:
		game.session.request_game_action.rpc_id(1, "emote", [game.controller.state.match_id, index])


func _receive_action(sender: int, action: String, payload: Array) -> void:
	if action == "emote" and payload.size() == 2 and payload[0] == game.controller.state.match_id and payload[1] is int:
		_accept(sender, int(payload[1]))


## 방장: 간격·번호를 확인하고 모두에게 알린다.
func _accept(sender: int, index: int) -> void:
	if index < 0 or index >= EmoteArt.COUNT + MotionEmotes.COUNT or not game.actors.has(sender):
		return
	var motion: bool = index >= EmoteArt.COUNT
	var stop: bool = index == EmoteArt.COUNT + MotionEmotes.STOP
	var actor: PlayerView = game.actors[sender]
	if motion and not stop and not _can_motion(sender):
		return
	if stop and actor.emote_clip().is_empty():
		return
	var now: float = game.controller._now()
	if not stop and now - float(_last_sent.get(sender, -10.0)) < EMOTE_GAP:
		return
	if not stop:
		_last_sent[sender] = now
	var data := {"match_id": game.controller.state.match_id, "peer": sender, "index": index}
	if game.session != null and game.session.is_host() and game.multiplayer.has_multiplayer_peer():
		game.session.receive_game_event.rpc("emote", data)
	show_emote(sender, index)
	# 싱글 플레이: 사람이 보낸 감정에 봇이 답한다(game/player/bot_social.gd, 2026-11-01).
	if not motion and game.bot_social != null and not actor.identity.is_bot:
		game.bot_social.heard(sender, index)


## 방장: 봇이 감정을 보낸다(싱글 플레이 봇 행동 bot_social.gd). 사람과 같은 간격 확인을 지난다.
func bot_say(peer: int, index: int) -> void:
	_accept(peer, index)


func _receive_event(kind: String, data: Dictionary) -> void:
	if kind == "emote" and int(data.get("match_id", -1)) == game.controller.state.match_id:
		show_emote(int(data.get("peer", 0)), int(data.get("index", 0)))


## 이모티콘은 말풍선/소리, 모션은 실제 캐릭터에서 재생한다. 화면 없는 서버에도 모션 상태를 반영한다.
func show_emote(peer: int, index: int) -> void:
	var actor: PlayerView = game.actors.get(peer)
	if actor == null or index < 0 or index >= EmoteArt.COUNT + MotionEmotes.COUNT:
		return
	if index >= EmoteArt.COUNT:
		var motion_index: int = index - EmoteArt.COUNT
		actor.play_emote(motion_index)
		if wheel != null and peer == game.controller.local_peer_id:
			wheel.show_notice(MotionEmotes.label(motion_index))
		return
	if wheel == null:
		return
	if peer == game.controller.local_peer_id:
		wheel.show_mine(index)
		var sound := AudioStreamPlayer.new()
		sound.stream = EmoteArt.sound(index)
		sound.volume_db = -6.0
		add_child(sound)
		sound.finished.connect(sound.queue_free)
		sound.play()
		return
	var bubble := EmoteBubble.new()
	bubble.index = index
	bubble.side = BUBBLE_SIDE
	# 캐릭터와 같은 레이어 → 그 사람 본인 화면에서는 안 보인다(본인 것은 화면 아래에 크게 보인다).
	bubble.layer_mask = 1 << (actor.identity.seat + 1)
	actor.add_child(bubble)
	# 시연(F6) 높이 2.78 m·머리 위 2.4 m 는 F5 화면에서 위 가운데 라운드 표시에 가려졌다 → 머리 옆으로 내린다.
	bubble.position.y = BUBBLE_HEIGHT


## 방장 매 프레임: 새 킬로그 줄을 보고 봇이 감정으로 반응한다.
func _process(_delta: float) -> void:
	# 서버와 화면 모두 같은 자세/턴 조건으로 중단한다. 전용 서버에는 로컬 카메라가 없다.
	if game != null:
		for actor: PlayerView in game.actors.values():
			if not actor.emote_clip().is_empty() and not _can_motion(actor.identity.peer_id):
				actor.play_emote(MotionEmotes.STOP)
	_sync_motion_camera()
	# 싱글 플레이는 bot_social.gd 가 봇 반응(놀리기·수다 포함)을 모두 맡는다.
	if game == null or game.session == null or not game.session.is_host() or game.bot_social != null:
		return
	var state: MatchState = game.controller.state
	for entry: String in state.feed:
		if _seen_feed.has(entry):
			continue
		_seen_feed[entry] = true
		_bot_react(state, entry.split(MatchController.FEED_SEPARATOR))
	if _seen_feed.size() > 200:
		_seen_feed.clear()
		for entry: String in state.feed: _seen_feed[entry] = true


func _can_motion(peer: int) -> bool:
	var actor: PlayerView = game.actors.get(peer)
	var active: MatchPlayer = game.controller.state.active_player()
	if active != null and active.peer_id == peer and game.controller.state.phase == MatchState.Phase.AIMING:
		return false
	return actor != null and actor.can_emote() and not game._frozen(peer) \
		and (game.lounge == null or game.lounge.held(peer) < 0)


func _sync_motion_camera() -> void:
	if game == null or DisplayServer.get_name() == "headless":
		return
	var actor: PlayerView = game.actors.get(game.controller.local_peer_id)
	var playing: bool = actor != null and not actor.emote_clip().is_empty()
	if playing:
		if _motion_camera == null:
			_motion_camera = Camera3D.new()
			_motion_camera.name = "MotionCamera"
			_motion_camera.fov = 55.0
			add_child(_motion_camera)
		var target: Vector3 = actor.global_position + Vector3.UP * 0.95
		var destination: Vector3 = actor.global_position + actor.global_basis * MOTION_CAMERA_OFFSET
		var query := PhysicsRayQueryParameters3D.create(target, destination, 1)
		var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
		_motion_camera.global_position = destination if hit.is_empty() else hit.position + hit.normal * 0.15
		_motion_camera.look_at(target)
		# 1인칭 부채·손은 기존 카메라 자식이므로 함께 숨긴다.
		game.camera.visible = false
		_motion_camera.make_current()
	elif _motion_camera != null and _motion_camera.current:
		game.camera.visible = true
		game.camera.make_current()


## 킬로그 한 줄(아이콘 · 주체 자리 · 주체 · 내용 · 대상 자리 · 대상)에 봇이 반응한다.
func _bot_react(state: MatchState, parts: PackedStringArray) -> void:
	if parts.size() < 6:
		return
	var actor: MatchPlayer = _player_at(state, int(parts[1]))
	var target: MatchPlayer = _player_at(state, int(parts[4]))
	match parts[0]:
		"card":
			# 카드를 맞은 봇은 화내거나 울고, 쓴 봇은 놀린다.
			_bot_emote(target, [ANGRY, CRY, WOW])
			_bot_emote(actor, [TEASE, LAUGH])
		"dart":
			var points: int = _points(parts[3])
			if points >= BOT_HAPPY_POINTS: _bot_emote(actor, [THUMBS, LAUGH])
			elif points == 0: _bot_emote(actor, [CRY, WOW])


func _bot_emote(player: MatchPlayer, choices: Array[int]) -> void:
	if player == null or not player.is_bot or _random.randf() > BOT_CHANCE:
		return
	var now: float = game.controller._now()
	if now < float(_bot_ready.get(player.peer_id, 0.0)):
		return
	_bot_ready[player.peer_id] = now + BOT_COOLDOWN
	_accept(player.peer_id, choices[_random.randi_range(0, choices.size() - 1)])


## 다트 킬로그 내용에서 최종 점수만 읽는다: "12점" → 12, "9 −20 ×2 = 0점" → 0, 점수가 없으면(빗나감 등) -1.
static func _points(text: String) -> int:
	if not text.ends_with("점"):
		return -1
	var words: PackedStringArray = text.trim_suffix("점").split(" ", false)
	return words[words.size() - 1].to_int() if not words.is_empty() else -1


static func _player_at(state: MatchState, seat: int) -> MatchPlayer:
	for player in state.players:
		if player.seat == seat: return player
	return null
