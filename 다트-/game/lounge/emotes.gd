extends Node
## F5 감정표현(2026-10-31 저녁 사용자 요청: "이모티콘이 사라졌다 — T 로 골라서 마이크 없이도 쓰게").
## 카드 라운드 시연(F6)에만 있던 감정표현을 F5 경기·대기실에 연결한다. 그림·소리·피자판은 시연 것을 그대로 쓴다.
##   T 누른 채 마우스 방향으로 고르고 떼면 보낸다 · 왼클릭으로 바로 보낸다 · T 를 톡 누르면 열린 채로 남는다 · Esc = 닫기.
##   보낸 감정은 그 사람 머리 위 말풍선 + 효과음(fx/emote_bubble.gd). 내 것은 내 화면 아래에 크게(ui/emote_wheel.gd show_mine).
## 네트워크: 손님 → 방장 "emote" 요청 → 방장이 간격(EMOTE_GAP)을 확인하고 모두에게 "emote" 이벤트. 방장은 자기 화면에도 바로 띄운다.
## 봇도 킬로그를 보고 반응한다(방장만): 카드를 맞으면 으악/흑흑, 카드를 쓰면 메롱, 다트 고득점이면 최고/ㅋㅋㅋ, 0점이면 흑흑.

const EmoteWheel = preload("res://game/card_round/ui/emote_wheel.gd")
const EmoteBubble = preload("res://game/card_round/fx/emote_bubble.gd")
const EmoteArt = preload("res://game/card_round/fx/emote_art.gd")

## 한 사람이 감정을 다시 보낼 수 있는 간격(초). 도배 방지.
const EMOTE_GAP: float = 1.0
## 감정 번호(fx/emote_art.gd 순서: ㅋㅋㅋ · 최고! · 으악! · 흑흑 · 헉! · 메롱~ · 좋아해 · GG).
const LAUGH: int = 0
const THUMBS: int = 1
const ANGRY: int = 2
const CRY: int = 3
const WOW: int = 4
const TEASE: int = 5
## 봇이 반응할 확률과 봇마다 다시 반응하기까지의 시간(초) — 너무 시끄럽지 않게.
const BOT_CHANCE: float = 0.45
const BOT_COOLDOWN: float = 6.0
## 말풍선 자리(m, 캐릭터 발 기준): 앉은 머리 오른쪽 옆, 이름표 PlayerView.LABEL_HEIGHT(2.0) 보다 아래.
## 머리 위(2.4 m)에 두면 테이블 건너편 봇의 말풍선이 위 가운데 라운드 표시에 가려졌다(render_match_ui 06 화면).
const BUBBLE_HEIGHT: float = 1.72
const BUBBLE_SIDE: float = 0.48
## 다트 한 발 점수가 이 이상이면 봇이 좋아한다.
const BOT_HAPPY_POINTS: int = 40

var game: GameView
var wheel: EmoteWheel
## peer_id → 마지막으로 감정을 보낸 시각(방장 기준).
var _last_sent: Dictionary = {}
## 봇 반응: 이미 본 킬로그 줄 · 봇마다 다음 반응 가능 시각.
var _seen_feed: Dictionary = {}
var _bot_ready: Dictionary = {}
var _random := RandomNumberGenerator.new()


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
	if game.session == null or game.session.is_host():
		_accept(game.controller.local_peer_id, index)
	else:
		game.session.request_game_action.rpc_id(1, "emote", [game.controller.state.match_id, index])


func _receive_action(sender: int, action: String, payload: Array) -> void:
	if action == "emote" and payload.size() == 2 and payload[0] == game.controller.state.match_id and payload[1] is int:
		_accept(sender, int(payload[1]))


## 방장: 간격·번호를 확인하고 모두에게 알린다.
func _accept(sender: int, index: int) -> void:
	if index < 0 or index >= EmoteArt.COUNT or not game.actors.has(sender):
		return
	var now: float = game.controller._now()
	if now - float(_last_sent.get(sender, -10.0)) < EMOTE_GAP:
		return
	_last_sent[sender] = now
	var data := {"match_id": game.controller.state.match_id, "peer": sender, "index": index}
	if game.session != null and game.session.is_host() and game.multiplayer.has_multiplayer_peer():
		game.session.receive_game_event.rpc("emote", data)
	show_emote(sender, index)


func _receive_event(kind: String, data: Dictionary) -> void:
	if kind == "emote" and int(data.get("match_id", -1)) == game.controller.state.match_id:
		show_emote(int(data.get("peer", 0)), int(data.get("index", 0)))


## peer 의 머리 위에 말풍선을 띄운다. 내 것이면 내 화면 아래에 크게 보이고 소리는 화면 소리로 낸다.
func show_emote(peer: int, index: int) -> void:
	var actor: PlayerView = game.actors.get(peer)
	if actor == null or wheel == null:
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
	if game == null or game.session == null or not game.session.is_host():
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
