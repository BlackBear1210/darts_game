extends Node
## 싱글 플레이 봇이 "같이 노는 느낌"을 주는 행동(2026-11-01 사용자 요청). 싱글 방의 방장(= 혼자 하는 사람의 화면)에서만 만든다.
##  1) 헤클링: 사람 차례에 봇 하나가 레인 옆(투척선 앞, 출입 금지 벽 바깥 — 도면이 "구경·방해"로 열어 둔 자리)까지 나와
##     던지는 사람을 보고 두 팔을 흔들며 뛰고 놀린다. 점수·카드·시간 규칙은 그대로다.
##     2026-11-02부터 BLOCK_CHANCE 로 옆 대신 레인 안 "몸막 구역"에 들어가 다트 앞을 몸으로 가로막는다
##     (맞으면 그 봇이 스턴 + 방해 성공 보상, 다트는 0점 — 판정은 GameView.solve_dart).
##     사람 차례가 끝나면 자리로 돌아간다.
##  2) 수다: 카드 충전 라운드·테이블 집합 때 봇끼리, 또는 사람에게 감정표현을 주고받는다(앉은 채 몸을 상대 쪽으로 돌린다).
##  3) 비틱·반응: 사람이 빗나가거나(0점) 카드·병·캡슐에 맞으면 봇들이 놀린다(ㅋㅋㅋ·메롱 + 팔 번쩍·뛰기).
##     사람이 잘 던지면 가끔 칭찬하고, 봇이 맞거나 잘해도 저마다 반응한다(싱글에서는 lounge/emotes.gd 의 봇 반응 대신 여기서).
##  4) 사람이 감정표현을 보내면 봇 하나가 답한다. 경기가 끝나면 GG.
## 감정표현은 lounge/emotes.gd 의 보통 경로(사람마다 간격 확인 → 화면 표시)를 그대로 지난다. 몸짓(PlayerView.taunting)은 보이기만.

const Emotes = preload("res://game/lounge/emotes.gd")
const BotDriver = preload("res://game/player/bot_driver.gd")

## 사람 차례마다 봇 하나가 헤클링하러 나올 확률. 시연값 — 팀 확정 필요.
const HECKLE_CHANCE: float = 0.6
## 헤클링 자리: 레인 벽(LANE_HALF) 바깥 0.65 m, 출입 금지선보다 1.15 m 앞(던지는 사람 화면 옆에 보이는 곳).
const HECKLE_SIDE: float = TableView.LANE_HALF + 0.65
const HECKLE_DEPTH: float = TableView.NO_ENTRY_Z - 1.15
## 헤클링하러 나온 봇이 옆에서 놀리는 대신 다트 앞을 몸으로 막을 확률(2026-11-02 F6 이식). 시연값.
const BLOCK_CHANCE: float = 0.35
## 헤클링 중 뛰는 간격과 놀리는 감정 간격(초, 매번 조금씩 흔든다).
const HECKLE_JUMP_EVERY: float = 1.5
const HECKLE_TEASE_EVERY: float = 3.4
## 놀릴 때 두 팔 번쩍 드는 시간(초).
const TAUNT_SECONDS: float = 1.8
## 말 거는 상대 쪽으로 몸을 돌리고 있는 시간(초)과 돌리는 빠르기.
const LOOK_SECONDS: float = 3.0
const TURN_RATE: float = 6.0
## 카드 충전 라운드·테이블 집합에 들어갈 때 봇 수다가 시작될 확률.
const CHAT_CHANCE_CARDS: float = 0.85
const CHAT_CHANCE_TABLE: float = 0.5
## 봇 수다가 사람에게 말 거는 확률(아니면 봇끼리).
const CHAT_TO_HUMAN: float = 0.35
## 사람이 감정표현을 보냈을 때 봇이 답할 확률.
const REPLY_CHANCE: float = 0.75
## 사람이 빗나갔을 때 놀릴 확률, 잘 던졌을 때 칭찬할 확률, 봇이 자기 일에 반응할 확률.
const GLOAT_CHANCE: float = 0.85
const PRAISE_CHANCE: float = 0.45
const SELF_CHANCE: float = 0.5

## 봇끼리 수다: [먼저 하는 말, 대답]. 감정 번호는 lounge/emotes.gd 순서.
const CHAT_LINES: Array = [[Emotes.TEASE, Emotes.ANGRY], [Emotes.TEASE, Emotes.LAUGH], [Emotes.LAUGH, Emotes.LAUGH],
	[Emotes.THUMBS, Emotes.LOVE], [Emotes.WOW, Emotes.TEASE], [Emotes.CRY, Emotes.LAUGH], [Emotes.LOVE, Emotes.LOVE], [Emotes.ANGRY, Emotes.LAUGH]]
## 사람에게 거는 말(대답은 사람 몫).
const TO_HUMAN: Array[int] = [Emotes.TEASE, Emotes.LAUGH, Emotes.THUMBS, Emotes.LOVE, Emotes.GG]
## 사람이 보낸 감정 → 봇 대답 후보(번호 순서대로: ㅋㅋㅋ · 최고! · 으악! · 흑흑 · 헉! · 메롱~ · 좋아해 · GG).
const REPLIES: Array = [[Emotes.LAUGH, Emotes.TEASE], [Emotes.THUMBS, Emotes.LOVE], [Emotes.LAUGH, Emotes.TEASE], [Emotes.LAUGH, Emotes.TEASE, Emotes.LOVE],
	[Emotes.WOW, Emotes.LAUGH], [Emotes.ANGRY, Emotes.TEASE], [Emotes.LOVE, Emotes.THUMBS], [Emotes.GG, Emotes.THUMBS]]

var game: GameView
var _random := RandomNumberGenerator.new()
## 지금 헤클링하는 봇(0 = 없음)과 정한 차례 번호, 나온 쪽(-1 왼쪽 / +1 오른쪽), 자리에 닿았는지.
var _heckler: int = 0
var _heckle_turn: int = -1
var _heckle_side: float = 1.0
var _heckle_arrived: bool = false
## 이번 헤클링이 "몸으로 막기"인지와, 레인 옆벽의 틈 앞까지 갔는지(거기서 안쪽으로 들어간다).
var _heckle_block: bool = false
var _heckle_at_gate: bool = false
var _next_jump: float = 0.0
var _next_tease: float = 0.0
## 예약된 감정: {"at", "peer", "index", "look", "gloat"}.
var _queue: Array[Dictionary] = []
## 봇 → {"at": 바라볼 곳, "until": 시각}.
var _look: Dictionary = {}
## 봇 → 팔 번쩍이 끝나는 시각.
var _taunt_until: Dictionary = {}
var _seen_feed: Dictionary = {}
var _last_phase: int = -1


func _ready() -> void:
	_random.randomize()


## GameView._drive_bot 이 "차례가 아닌 봇"마다 부른다. 이 봇을 이번 프레임에 직접 움직였으면 true(자리로 걷기를 건너뛴다).
## 앉아 있는 봇은 말 거는 상대 쪽으로 몸만 돌리고 false 를 돌려준다(앉은 자리는 그대로).
func drive(actor: PlayerView, delta: float) -> bool:
	if actor.identity.peer_id == _heckler:
		_heckle(actor, delta)
		return true
	if actor.seated:
		var look: Dictionary = _look.get(actor.identity.peer_id, {})
		var yaw: float = BotDriver.facing_board(actor.position)
		if not look.is_empty() and _now() < float(look.until):
			yaw = _facing((look.at as Vector3) - actor.position)
		actor.rotation.y = lerp_angle(actor.rotation.y, yaw, 1.0 - exp(-TURN_RATE * delta))
	return false


func _process(_delta: float) -> void:
	if game == null or not game.multiplayer.is_server():
		return
	var state: MatchState = game.controller.state
	var now: float = _now()
	_watch_phase(state, now)
	_watch_heckle(state, now)
	_read_feed(state, now)
	for entry: Dictionary in _queue.duplicate():
		if now >= float(entry.at):
			_queue.erase(entry)
			_say(int(entry.peer), int(entry.index), int(entry.look), bool(entry.gloat))
	for id: int in game.actors:
		var actor := game.actors[id] as PlayerView
		if actor.identity.is_bot:
			actor.taunting = now < float(_taunt_until.get(id, 0.0)) or (id == _heckler and _heckle_arrived)


## 사람이 감정표현을 보냈다(lounge/emotes.gd 가 알린다) → 봇 하나가 그 사람을 보고 답한다.
func heard(sender: int, index: int) -> void:
	var bots: Array[int] = _bot_ids()
	if bots.is_empty() or index < 0 or index >= REPLIES.size() or _random.randf() > REPLY_CHANCE:
		return
	var reply: int = _pick(REPLIES[index])
	# 사람이 화내거나 울 때 웃으면 비틱(팔 번쩍).
	_queue_say(_pick(bots), reply, _now() + _random.randf_range(0.7, 1.4), sender, index in [Emotes.ANGRY, Emotes.CRY] and reply in [Emotes.LAUGH, Emotes.TEASE])


# ─────────────────────────────── 헤클링 ───────────────────────────────

## 사람 차례가 새로 시작되면 확률로 봇 하나를 내보내고, 사람 차례가 끝나면 거둬들인다.
func _watch_heckle(state: MatchState, now: float) -> void:
	var active: MatchPlayer = state.active_player()
	var human_turn: bool = active != null and not active.is_bot and state.phase in [MatchState.Phase.AIMING, MatchState.Phase.FLIGHT, MatchState.Phase.SETTLING]
	if not human_turn:
		_heckler = 0
		_heckle_arrived = false
		_heckle_at_gate = false
		return
	if state.turn_id == _heckle_turn:
		return
	_heckle_turn = state.turn_id
	_heckler = 0
	_heckle_arrived = false
	_heckle_at_gate = false
	var bots: Array[int] = _bot_ids()
	if bots.is_empty() or _random.randf() > HECKLE_CHANCE:
		return
	_heckler = _pick(bots)
	# 자기 자리 쪽 레인 옆으로 나온다(가운데 자리는 아무 쪽이나).
	var seat_x: float = TableView.seat_spot((game.actors[_heckler] as PlayerView).identity.seat).x
	_heckle_side = signf(seat_x) if absf(seat_x) > 0.1 else (1.0 if _random.randf() < 0.5 else -1.0)
	# 가끔은 옆에서 놀리는 대신 레인 안(몸막 구역)으로 들어가 다트 앞을 몸으로 막는다.
	_heckle_block = _random.randf() < BLOCK_CHANCE
	_next_jump = now
	_next_tease = now


func _heckle(actor: PlayerView, delta: float) -> void:
	if actor.seated:
		actor.seated = false
		actor.position = TableView.standing_spot(actor.identity.seat)
		actor.update_posture()
	# 몸으로 막으러 가는 길은 두 걸음이다: 레인 옆벽의 틈 앞까지 간 뒤 안쪽(다트가 지나는 한가운데)으로 들어간다.
	var stand: Vector3 = TableView.block_spot()
	var gate := Vector3(_heckle_side * HECKLE_SIDE, 0, stand.z if _heckle_block else HECKLE_DEPTH)
	if not _heckle_at_gate:
		if not BotDriver.arrived(actor.position, gate):
			actor.simulate(delta, BotDriver.walk_controls(actor.position, gate))
			return
		_heckle_at_gate = true
	var spot := stand if _heckle_block else gate
	if not BotDriver.arrived(actor.position, spot):
		actor.simulate(delta, BotDriver.walk_controls(actor.position, spot))
		return
	var now: float = _now()
	if not _heckle_arrived:
		_heckle_arrived = true
		_next_tease = now + 0.3
	var active: MatchPlayer = game.controller.state.active_player()
	var thrower := game.actors.get(active.peer_id if active != null else 0) as PlayerView
	var toward: Vector3 = (thrower.position if thrower != null else Vector3(0, 0, TableView.THROW_LINE_Z)) - actor.position
	var jump: bool = now >= _next_jump
	if jump:
		_next_jump = now + HECKLE_JUMP_EVERY * _random.randf_range(0.7, 1.3)
	actor.simulate(delta, {"move": Vector2.ZERO, "yaw": _facing(toward), "pitch": 0.0, "jump": jump, "crouch": false})
	if now >= _next_tease:
		_next_tease = now + HECKLE_TEASE_EVERY * _random.randf_range(0.8, 1.3)
		_say(actor.identity.peer_id, _pick([Emotes.TEASE, Emotes.LAUGH, Emotes.TEASE, Emotes.WOW]), 0, false)


# ─────────────────────────────── 수다 ───────────────────────────────

## 단계가 바뀌는 순간: 카드 충전 라운드·테이블 집합이면 수다, 경기가 끝나면 GG.
func _watch_phase(state: MatchState, now: float) -> void:
	if state.phase == _last_phase:
		return
	_last_phase = state.phase
	match state.phase:
		MatchState.Phase.CARDS:
			if _random.randf() < CHAT_CHANCE_CARDS: _start_chat(now + 0.6)
		MatchState.Phase.TABLE:
			if _random.randf() < CHAT_CHANCE_TABLE: _start_chat(now + 2.0)
		MatchState.Phase.FINISHED:
			_finish_reaction(state, now)


## 봇 하나가 다른 봇(또는 사람)을 보며 말을 걸고, 봇끼리면 상대가 답한다.
func _start_chat(at: float) -> void:
	var bots: Array[int] = _bot_ids()
	if bots.is_empty():
		return
	var speaker: int = _pick(bots)
	var others: Array = bots.filter(func(id: int) -> bool: return id != speaker)
	var human: int = _human_id()
	if human != 0 and (others.is_empty() or _random.randf() < CHAT_TO_HUMAN):
		_queue_say(speaker, _pick(TO_HUMAN), at, human, false)
		# 다른 봇이 옆에서 거든다.
		if not others.is_empty() and _random.randf() < 0.5:
			_queue_say(_pick(others), Emotes.LAUGH, at + _random.randf_range(1.0, 1.6), human, false)
		return
	if others.is_empty():
		return
	var listener: int = _pick(others)
	var line: Array = _pick(CHAT_LINES)
	_queue_say(speaker, int(line[0]), at, listener, false)
	_queue_say(listener, int(line[1]), at + _random.randf_range(1.0, 1.6), speaker, false)


## 경기 끝: 봇이 이겼으면 그 봇은 메롱, 나머지는 GG.
func _finish_reaction(state: MatchState, now: float) -> void:
	var best: MatchPlayer = null
	for player in state.players:
		if best == null or player.score > best.score: best = player
	var delay: float = 0.6
	for id: int in _bot_ids():
		var won: bool = best != null and best.peer_id == id
		_queue_say(id, Emotes.TEASE if won else _pick([Emotes.GG, Emotes.THUMBS, Emotes.GG]), now + delay, _human_id(), won)
		delay += _random.randf_range(0.5, 0.9)


# ─────────────────────────────── 킬로그 반응 ───────────────────────────────

func _read_feed(state: MatchState, now: float) -> void:
	for entry: String in state.feed:
		if _seen_feed.has(entry):
			continue
		_seen_feed[entry] = true
		_react(state, entry.split(MatchController.FEED_SEPARATOR), now)
	if _seen_feed.size() > 200:
		_seen_feed.clear()
		for entry: String in state.feed: _seen_feed[entry] = true


## 킬로그 한 줄(아이콘 · 주체 자리 · 주체 · 내용 · 대상 자리 · 대상)에 반응한다.
func _react(state: MatchState, parts: PackedStringArray, now: float) -> void:
	if parts.size() < 6:
		return
	var actor: MatchPlayer = _player_at(state, int(parts[1]))
	var target: MatchPlayer = _player_at(state, int(parts[4]))
	match parts[0]:
		"dart":
			if actor == null: return
			var points: int = Emotes._points(parts[3])
			if not actor.is_bot:
				if points == 0: _gloat(actor.peer_id, now)
				elif points >= Emotes.BOT_HAPPY_POINTS and not _bot_ids().is_empty() and _random.randf() < PRAISE_CHANCE:
					_queue_say(_pick(_bot_ids()), _pick([Emotes.WOW, Emotes.THUMBS]), now + 0.5, actor.peer_id, false)
			elif points >= Emotes.BOT_HAPPY_POINTS and _random.randf() < SELF_CHANCE:
				_queue_say(actor.peer_id, _pick([Emotes.THUMBS, Emotes.LAUGH]), now + 0.4, _human_id(), true)
			elif points == 0 and _random.randf() < SELF_CHANCE:
				_queue_say(actor.peer_id, _pick([Emotes.CRY, Emotes.WOW]), now + 0.4, 0, false)
		"card", "broken", "capsule":
			if target == null: return
			if not target.is_bot:
				_gloat(target.peer_id, now, actor.peer_id if actor != null and actor.is_bot else 0)
			elif _random.randf() < SELF_CHANCE:
				_queue_say(target.peer_id, _pick([Emotes.ANGRY, Emotes.CRY, Emotes.WOW]), now + 0.4, actor.peer_id if actor != null else 0, false)


## 사람이 빗나가거나 당했다 → 봇 한둘이 그 사람을 보며 놀린다(카드를 쓴 봇이 있으면 그 봇이 먼저). 헤클러는 바로 뛴다.
func _gloat(human: int, now: float, first: int = 0) -> void:
	var bots: Array[int] = _bot_ids()
	if bots.is_empty() or _random.randf() > GLOAT_CHANCE:
		return
	var speaker: int = first if bots.has(first) else (_heckler if bots.has(_heckler) else _pick(bots))
	_queue_say(speaker, _pick([Emotes.LAUGH, Emotes.TEASE]), now + 0.35, human, true)
	var others: Array = bots.filter(func(id: int) -> bool: return id != speaker)
	if not others.is_empty() and _random.randf() < 0.6:
		_queue_say(_pick(others), _pick([Emotes.TEASE, Emotes.LAUGH]), now + _random.randf_range(1.0, 1.5), human, true)
	_next_jump = now


# ─────────────────────────────── 공통 ───────────────────────────────

func _queue_say(peer: int, index: int, at: float, look: int, gloat: bool) -> void:
	if peer != 0:
		_queue.append({"at": at, "peer": peer, "index": index, "look": look, "gloat": gloat})


## 감정을 보내고(보통 경로), 상대를 바라보게 하고, 놀리는 말이면 팔을 번쩍 든다.
func _say(peer: int, index: int, look: int, gloat: bool) -> void:
	if not game.actors.has(peer) or game.emotes == null:
		return
	game.emotes.bot_say(peer, index)
	var now: float = _now()
	if look != 0 and game.actors.has(look):
		_look[peer] = {"at": (game.actors[look] as PlayerView).position, "until": now + LOOK_SECONDS}
	if gloat:
		_taunt_until[peer] = now + TAUNT_SECONDS


func _bot_ids() -> Array[int]:
	var ids: Array[int] = []
	for player in game.controller.state.players:
		if player.is_bot and game.actors.has(player.peer_id): ids.append(player.peer_id)
	return ids


func _human_id() -> int:
	for player in game.controller.state.players:
		if not player.is_bot: return player.peer_id
	return 0


func _pick(items: Array) -> Variant:
	return items[_random.randi_range(0, items.size() - 1)]


static func _player_at(state: MatchState, seat: int) -> MatchPlayer:
	for player in state.players:
		if player.seat == seat: return player
	return null


## 캐릭터의 정면은 -Z 다(bot_driver.gd 와 같은 식).
static func _facing(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
