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
## [2026-11-21 새 카드] 사람·물건에 닿는 카드(속박·끌어당기기·카드 던지기)와 화면 카드(정전·망원경·딸꾹질·유체이탈·원샷).
## 카드별 코드는 이 두 파일에만 있다 — 게임 화면(GameView)은 붙이고 불러 주기만 한다.
const CardWorld = preload("res://game/match/card_world.gd")
const CardScreenEffects = preload("res://game/match/card_screen_effects.gd")
var card_world: Node3D
var _card_screen: CanvasLayer
var _last_quality: int = -1
## 아수라장 다트 머신(2026-11-07): 과녁 회전·피자 분리·셔터의 모양 계산(판정과 화면이 같은 함수).
## 예전 "가림판" 카드의 파란 상자(_cover)는 머신 셔터가 대신한다.
const BoardChaos = preload("res://game/board/board_chaos.gd")
## 화면에 지금 보이는 머신 모양. 효과가 끝나면 제자리로 부드럽게 돌아가게 따로 들고 있다.
var _shown_chaos: Dictionary = {}
## 제자리로 돌아가는 빠르기(1/초). 효과가 걸려 있는 동안은 방장 모양을 그대로 따른다(판정과 같아야 하므로).
const CHAOS_SETTLE_RATE: float = 4.0

const PLAYER_SCENE: PackedScene = preload("res://game/player/player.tscn")
const DART_SCENE: PackedScene = preload("res://game/dart/dart.tscn")
const CardCatalog = preload("res://game/card_round/rules/card_catalog.gd")
const FIRST_PERSON_HAND_3D: bool = true
const HandView = preload("res://art/characters/first_person_hand_view.gd")
const DartHand = preload("res://art/characters/dart_hand/dart_hand.gd")
## 1인칭 당기기·던지기·팔로 스루 곡선(미리보기 tests/render_fp_arm.gd 도 같은 함수를 쓴다).
const FirstPersonThrow = preload("res://art/characters/first_person_throw.gd")
## 봇의 차례 행동 계산(방장 전용). class_name 이 없는 도구라 preload 로 부른다.
const BotDriver = preload("res://game/player/bot_driver.gd")
## 카드 그림과 1인칭 손 부채는 카드 라운드 시연 것을 그대로 쓴다 — 카드 모양은 한 곳만 유지한다.
const CardFaces = preload("res://game/card_round/cards/card_faces.gd")
const HandFan = preload("res://game/card_round/cards/hand_fan.gd")
## 몸으로 막기(2026-11-02): 몸 캡슐 판정과 머리 위 스턴 별은 카드 라운드 시연과 같은 것을 쓴다.
const BodyHit = preload("res://game/dart/body_hit.gd")
const StunStars = preload("res://game/card_round/fx/stun_stars.gd")
const PlayerWallet = preload("res://app/player_wallet.gd")
## 벌칙으로 묶였을 때 보는 자리(2026-11-25). 레인 왼쪽 옆, 과녁보다 조금 앞·위에서 판을 본다 —
## 던지는 사람과 날아오는 다트가 함께 보이고, 방이 돌지 않아 어지럽지 않다.
const PUNISH_VIEW := Vector3(-2.9, 2.6, TableView.BOARD_CENTER.z + 3.2)
## 경기 끝 벌칙(2026-11-23): 지금 과녁판에 묶여 있는 사람의 peer id(0 = 없음) · 토큰을 이미 정산한 경기 번호.
## 마지막 경기에서 내 토큰이 얼마나 바뀌었는지(결과 화면이 읽는다).
var strapped_id: int = 0
var token_change: int = 0
var _tokens_claimed_match: int = 0
## 묶인 동안 방장에게 마지막으로 보낸 회전 방향(0 = 아직 안 보냄). 같은 방향을 거듭 보내지 않는다.
var _punish_turn_sent: int = 0
## 몸으로 막은 사람이 옆으로 튕기는 세기(m/s). 감속 9 m/s² 라 약 0.9m 밀려난다 —
## 다트가 지나는 한가운데에서 벗어나므로 다음 발은 다시 들어와 서야 막을 수 있다(계속 서서 막는 것 방지).
const BODY_KNOCKBACK: float = 4.0
const MOTION_INTERVAL: float = 0.05
## 손님이 자기 예측을 믿을 최대 어긋남(m). 걷는 동안 스냅샷은 왕복 지연만큼 과거라 늘 뒤처져 온다
## (걷기 PlayerView.SPEED 3.8m/s × 왕복 0.2초 ≈ 0.76m). 이보다 벌어지면 예측이 틀린 것이다.
const PREDICT_TRUST: float = 0.9
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
## Tab 플레이어 목록(누가 있는지 + 사람마다 목소리 볼륨)과 싱글 플레이 봇의 같이 노는 행동(2026-11-01).
const PlayerList = preload("res://ui/player_list.gd")
const BotSocial = preload("res://game/player/bot_social.gd")
const VoiceChat = preload("res://network/voice_chat.gd")
## 꾸미기 방(2026-11-15): 당구대 옆 문에서 F → 따로 떨어진 3D 탈의실 화면(game/lounge/wardrobe.gd).
## 고른 차림(art/characters/player_outfit.gd)은 방장이 검사해 "looks" 이벤트로 모두에게 보낸다(보이기만 — 판정 무관).
const PlayerOutfit = preload("res://art/characters/player_outfit.gd")
const Wardrobe = preload("res://game/lounge/wardrobe.gd")
var wardrobe: CanvasLayer
## 방장: 꾸미기 방에 들어가 있는 사람(peer ID → true). 이름표 "꾸미는 중"으로 모두에게 보인다.
var _dressing: Dictionary = {}

@onready var controller: MatchController = $MatchController
@onready var throw_input: DartThrowController = $ThrowController
@onready var camera: Camera3D = $Camera
@onready var table: TableView = $Table
@onready var _players_root: Node3D = $Players
@onready var _darts: Node3D = $Darts

var session: NetworkSession
var actors: Dictionary = {}
var developer_enabled: bool = false
var card_test_selection: Dictionary = {}
var _controls: Dictionary = {}
## 몸으로 막기 스턴(방장만 센다). peer ID → 풀리는 시각.
var _stun_until: Dictionary = {}
## 머리 위 별을 이미 띄운 한 발("차례:요청" 글자). 같은 스냅샷이 다시 와도 두 번 띄우지 않는다.
var _shown_block: String = ""
## 3D 점수 팝업(2026-11-15, art/fx/score_popup.gd): 이미 띄운 한 발("경기:요청:던진 사람"). 같은 스냅샷이 다시 와도 한 번만.
const ScorePopup = preload("res://art/fx/score_popup.gd")
## "내 차례가 아니에요!" 알림(2026-11-17, ui/turn_toast.gd): 경기 중 남의 차례에 던지면 던진 사람 화면에 뜬다. 처음 쓸 때 만든다.
const TurnToast = preload("res://ui/turn_toast.gd")
## 알림이 뜨는 단계(다트를 겨누고·날리고·점수를 세는 동안). 대기실·카드 라운드·준비 중에는 그냥 던지기가 놀이라 안 띄운다.
const TURN_TOAST_PHASES: Array[MatchState.Phase] = [MatchState.Phase.AIMING, MatchState.Phase.FLIGHT, MatchState.Phase.SETTLING]
var turn_toast: CanvasLayer
var _shown_score: String = ""
## 처음 받은 스냅샷(경기 중간에 들어온 사람)에 남아 있던 지난 한 발은 띄우지 않는다.
var _score_popups_ready: bool = false
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
@onready var _hand: HandView = $Camera/Hand
## 로컬 입력과 방장의 투척 통지가 같은 프레임에 오지 않을 수 있다.
var _score_starts: Array[Vector3] = []
var _stray_starts: Array[Vector3] = []
@onready var _dart_hand: DartHand = $DartHand
var _throw_kick: float = 0.0
## 손에 보이는 당긴 정도. 충전 중엔 충전값, 그 밖엔 천천히 0 으로 돌아간다
## — 놓은 뒤 서버 응답(_throw_kick 시작)을 기다리는 사이 손이 겨누기 자세로 툭 튀지 않는다.
var _held_pull: float = 0.0
## 놓을 때 당겨 있던 정도. 던지기 몸짓이 이 자세에서 출발한다.
var _released_pull: float = 0.0
var _board_shake: float = 0.0
## 지금 날아가는 다트(궤적 카드로 꽂히는 자리가 바뀌면 이 다트를 휘게 한다).
var _flying_dart: DartView
var _flying_darts: Array[DartView] = []
## 테이블 자리 매트 위 카드(각자 손패를 앞면으로 깐다 — 2026-10-31 저녁 결정, 엿보면 옆자리 카드가 내 화면에서 크게 펼쳐진다). 화면이 없으면 만들지 않는다.
var seat_cards: Node3D
var held_cards: Node
var emotes: Node
var deck_show: Node3D
var player_list: CanvasLayer
## 싱글 방에서만 있다(방장 = 혼자 하는 사람). 없으면 봇은 예전처럼 차례 행동·자기 반응만 한다.
var bot_social: Node
## 지난 프레임에 내가 앉아 있었는지. 앉는 순간만 시선을 테이블로 돌린다(_face_table_on_sit).
var _was_seated: bool = false


func _ready() -> void:
	# 테이블은 언제나 원점이다. 자리·카드 매트·손 카드·다트 판정이 모두 TableView 상수(원점 기준)로 놓인다.
	# 2026-11-08 사용자 지적 "왜 공중에 카드가 떠 있지?": 에디터에서 game.tscn 의 Table 이 실수로 17cm 아래로
	# 끌려 저장돼 테이블만 내려가고 카드는 제자리에 떠 있었다 → 씬에서 끌려도 실행 때 제자리로 되돌린다.
	table.transform = Transform3D.IDENTITY
	controller.changed.connect(_apply_state)
	controller.dart_thrown.connect(_show_throw)
	controller.dart_redirected.connect(_redirect_throw)
	# 왼쪽 버튼을 놓으면: 내 차례 + 던지는 칸 + 과녁 조준이면 점수 투척, 아니면 "그냥 던지기"(_on_throw_requested).
	throw_input.throw_requested.connect(_on_throw_requested)
	throw_input.camera = camera
	throw_input.board = table.board
	$TrajectoryPreview.hide()
	_hand.hide()
	_prepare_hand_fan()


func configure(room: RoomState, local_peer_id: int, connection: NetworkSession = null) -> void:
	session = connection
	controller.configure(room, local_peer_id, session)
	if session != null:
		session.movement_input.connect(_receive_controls)
		session.movement_snapshot.connect(_receive_motion)
		session.game_action.connect(_receive_action)
		session.game_event.connect(_receive_game_event)
	controller.solve_throw = solve_dart
	controller.rebound_contact = _rebound_contact
	controller.check_seated = is_seated
	controller.force_seat = force_seat
	controller.in_throw_zone = can_throw_from
	controller.stun_player = stun_player
	controller.throw_stray = throw_stray
	controller.knock_down = knock_down
	_setup_card_world()
	emotes = Emotes.new()
	emotes.name = "Emotes"
	add_child(emotes)
	emotes.setup(self)
	_make_bot_social(room)
	if DisplayServer.get_name() != "headless":
		player_list = PlayerList.new()
		player_list.name = "PlayerList"
		player_list.game = self
		add_child(player_list)
	for player in controller.state.players:
		var view := PLAYER_SCENE.instantiate() as PlayerView
		view.name = "Player_%d" % player.peer_id
		_players_root.add_child(view)
		# 차림: 방 정보(봇 무작위 차림 · 방장이 받은 사람 차림). 나는 저장해 둔 내 차림을 바로 입는다(방장에게도 곧 보낸다).
		var room_player: RoomPlayer = room.find_player(player.peer_id)
		view.look = PlayerOutfit.sanitize(room_player.look if room_player != null else {})
		if player.peer_id == local_peer_id and not player.is_bot:
			view.look = PlayerOutfit.sanitize(Preferences.look)
		view.configure(player, 0.0, false, _bots_waiting_in_lobby())
		actors[player.peer_id] = view
		if player.peer_id == local_peer_id:
			camera.cull_mask = 0xfffff & ~(1 << (player.seat + 1))
			if FIRST_PERSON_HAND_3D and DisplayServer.get_name() != "headless":
				_hand.equip(player.seat, int(view.look.shirt), int(view.look.character))
			else:
				_dart_hand.set_seat(player.seat)
	if room.settings.social_lobby:
		lounge = LoungeWorld.new()
		lounge.name = "LoungeWorld"
		add_child(lounge)
		lounge.configure(self)
		if DisplayServer.get_name() != "headless":
			_screen_fx = preload("res://game/card_round/fx/screen_debuff.gd").new()
			add_child(_screen_fx)
			_card_screen = CardScreenEffects.new()
			_card_screen.name = "CardScreenEffects"
			add_child(_card_screen)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_apply_state()
	# 내 차림을 방장에게 알린다 → 방장이 모두의 차림을 다시 보낸다(늦게 들어온 사람도 남의 차림을 받는다).
	var me := actors.get(local_peer_id) as PlayerView
	if me != null and not me.identity.is_bot:
		_send_look.call_deferred(me.look, false)


## 싱글 플레이(연습 방) 방장만: 봇 수다·헤클링 담당을 붙인다.
func _make_bot_social(room: RoomState) -> void:
	if room.settings.solo and (session == null or session.is_host()):
		bot_social = BotSocial.new()
		bot_social.name = "BotSocial"
		bot_social.game = self
		add_child(bot_social)


## [2026-11-18 "방 만든 뒤 대기 없애기"] 화면(펍·오락실·사람·소품)은 그대로 두고 새 경기를 맞는다.
## app/main.gd 가 경기 번호가 바뀔 때(경기 시작)와 로비로 돌아올 때 부른다.
## 예전엔 그때마다 경기 화면을 지우고 새로 만들어 펍 1.2초 · 오락실 1.9초 멈췄다.
## 지난 경기 흔적(꽂힌 다트·과녁 배치·손패·쓰러짐·봇 헤클링)만 치운다. 라운지 소품·음악·취기는 그대로 이어진다.
func begin_match(room: RoomState) -> void:
	controller.reset_match(room)
	_clear_darts()
	_flying_dart = null
	_shown_turn = controller.state.turn_id
	_shown_block = ""
	_was_finished = false
	_bot_ready_at = 0.0
	_stun_until.clear()
	_controls.clear()
	# 움직임 번호는 받는 쪽만 처음으로 돌린다(보내는 쪽 번호는 계속 오른다).
	# 방장 화면을 새로 만든 경우(전용 서버)에도 1번부터 다시 받는다.
	_last_motion_sequence = -1
	_throw_kick = 0.0
	_score_starts.clear()
	_stray_starts.clear()
	_held_pull = 0.0
	_released_pull = 0.0
	_board_shake = 0.0
	table.board.show_layout(BoardLayout.new())
	table.board.show_choice(-1)
	for actor: PlayerView in actors.values():
		actor.get_up()
		actor.knockback = Vector3.ZERO
	# 킬로그 반응·카드 받을 때 한 잔: 지난 경기에서 본 줄·라운드를 잊는다(새 경기 1라운드에도 반응하게).
	if emotes != null: emotes._seen_feed.clear()
	if lounge != null: lounge._last_deal = -1
	if bot_social != null:
		remove_child(bot_social)
		bot_social.queue_free()
		bot_social = null
	_make_bot_social(room)
	if room.phase != RoomState.Phase.LOBBY:
		# 경기가 시작되면 모두 테이블에 앉아 카드 턴을 맞는다(예전 새로 만들 때와 같다).
		for player in room.players:
			force_seat(player.peer_id)
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
	camera.add_child(_fan)
	_fan.configure_screen_row(camera)
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
	# 2026-11-08: 덱에서 카드가 닿을 때마다 손 부채(내 것·남의 것)에 그 한 장을 넣는다.
	deck_show.dealt.connect(_on_card_dealt)
	held_cards = HeldCards.new()
	held_cards.name = "HeldCards"
	held_cards.deck_show = deck_show
	add_child(held_cards)
	held_cards.sync(actors, controller.state.players, controller.local_peer_id)


## 내 손패를 부채에 맞추고 꺼내 든 카드를 위로 올린다. 스냅샷마다 부르지만 카드가 그대로면 다시 만들지 않는다.
func _sync_hand_fan() -> void:
	if _fan == null:
		return
	var me := controller.state.find_player(controller.local_peer_id)
	var hand: Array[int] = []
	if me != null: hand.assign(me.hand)
	# 카드 충전 라운드: 덱에서 아직 안 날아온 카드(-1)는 부채에 넣지 않는다 → 섞기 뒤 한 장씩 손에 들어온다.
	if me != null and deck_show != null:
		hand = deck_show.visible_hand(me.seat, hand)
	if hand != _shown_hand:
		_shown_hand = hand.duplicate()
		for slot in range(CardHandRules.HAND_LIMIT):
			if slot < hand.size() and hand[slot] >= 0:
				# 바뀐 칸만 새로 놓는다(예전에는 매번 7장을 다 새로 만들어 한꺼번에 튀어 들어왔다).
				if not _fan.has_card(slot) or _fan.cards[slot].type != hand[slot]:
					_fan.set_card(slot, hand[slot])
			else:
				_fan.remove_card(slot)
	var pending_slot: int = me.pending_slot if me != null else -1
	if pending_slot != _fan.lifted_slot:
		if pending_slot >= 0: _fan.lift(pending_slot)
		else: _fan.lower()


## 덱에서 카드 한 장이 닿았다 → 내 손 부채와 남이 든 부채를 다시 맞춘다(바뀐 칸만 새로 들어온다).
func _on_card_dealt(_seat: int, _index: int) -> void:
	_sync_hand_fan()
	if held_cards != null:
		held_cards.sync(actors, controller.state.players, controller.local_peer_id)


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


## 화면을 클릭했을 때 마우스를 다시 잡아야 하는가.
## [2026-11-26 사용자 "클릭 빼고는 아무 키도 안 먹는다"] 예전에는 '보이는' 상태에서만 다시 잡았다.
## 이동·시점·Space 는 모두 '잡힘'일 때만 듣는데, 포인터 연출(ui/dart_cursor.gd)이 쓰는 '숨김'으로
## 남으면 클릭으로도 빠져나올 수 없어 조작이 통째로 잠겼다 → 잡혀 있지만 않으면 언제든 다시 잡는다.
## 경기 결과 화면에서는 버튼을 눌러야 하므로 포인터를 그대로 둔다.
static func wants_capture(mode: int, phase: int) -> bool:
	return mode != Input.MOUSE_MODE_CAPTURED and phase != MatchState.Phase.FINISHED


func _unhandled_input(event: InputEvent) -> void:
	# 꾸미기 방이 열려 있으면 펍 조작(F·T·Tab·Enter·클릭)은 모두 쉰다 — 방 화면이 자기 입력을 받는다.
	if wardrobe_open():
		return
	# T 감정표현 피자판이 먼저 받는다(열려 있으면 마우스 클릭·Esc 도 피자판 것).
	if emotes != null and emotes.handle(event):
		get_viewport().set_input_as_handled()
		return
	if player_list != null and player_list.handle(event):
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
			# 2026-11-15: 소품 잡기도 F(상호작용 키). 좌클릭은 다트 던지기 전용이 됐다(라운드당 다트 — 아무 때나 던질 수 있다).
			if event.keycode == Preferences.interact_key and hit.get("kind") == "prop" and lounge.held(id) < 0:
				lounge.request("take")
				get_viewport().set_input_as_handled()
				return
			if event.keycode == KEY_ENTER and session.room.phase == RoomState.Phase.LOBBY:
				if controller.card_test_active:
					return
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
					# 2026-11-15: 당구대 옆 문 = 꾸미기 방.
					"wardrobe": open_wardrobe()
				get_viewport().set_input_as_handled()
				return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if wants_capture(Input.mouse_mode, controller.state.phase):
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
		var actor: PlayerView = actors.get(controller.local_peer_id)
		var axes: Vector2 = actor.identity.card_effects.get("reverse_axes", Vector2.ONE) if actor != null else Vector2.ONE
		if _screen_fx != null: axes *= _screen_fx.mouse_factor
		_yaw -= event.relative.x * MOUSE_SENSITIVITY * Preferences.sensitivity * axes.x
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENSITIVITY * Preferences.sensitivity * axes.y, -1.25, 1.25)


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
		# 벌칙으로 과녁판에 묶였으면 A·D 가 판을 돌리는 방향이 된다(2026-11-23 사용자 요청).
		# D = 시계 방향(각도가 줄어든다) · A = 반시계. 방향이 바뀔 때만 방장에게 보낸다.
		if strapped_id == controller.local_peer_id:
			var turn: int = -signi(roundi(axis.x))
			if turn != 0 and turn != _punish_turn_sent:
				_punish_turn_sent = turn
				controller.request_punish_spin(turn)
			axis = Vector2.ZERO
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
				if _frozen(id) or (controller.card_test_active and controller.state.active_player().peer_id != id):
					actor.simulate(delta, {})
				else: _drive_bot(actor, delta)
				continue
			var controls: Dictionary = _controls.get(id, {})
			if controller._now() - float(controls.get("at", 0)) > INPUT_TIMEOUT:
				controls = {}
			if _frozen(id): controls = {}
			# 2026-11-07 오락실: 인형뽑기를 조종 중이면 WASD 가 집게 조이스틱이 된다 → 몸은 제자리(고개는 그대로 돌릴 수 있다).
			if lounge != null and lounge.steer_machine(id, controls, delta):
				controls = controls.duplicate()
				controls.move = Vector2.ZERO
				controls.jump = false
			actor.simulate(delta, controls)
			if _controls.has(id):
				_controls[id]["jump"] = false
	else:
		_predict_local(delta)


## [손님 화면 예측 — 2026-11-26 사용자 "방장 빼면 다 렉 걸린다"] 손님은 자기 몸조차 방장이 보내 줄 때까지
## 움직이지 못했다(조작 전송 0.05초 + 왕복 지연 + 스냅샷 0.05초). 방장과 똑같은 PlayerView.simulate 를
## 자기 화면에서 먼저 돌려 키를 누른 프레임에 바로 걷게 한다. 방장 자리와 크게 어긋나면 _receive_motion 이
## 되돌린다 — 점수·몸 맞기 같은 판정은 여전히 방장 계산 그대로다.
func _predict_local(delta: float) -> void:
	var mine := actors.get(controller.local_peer_id) as PlayerView
	if mine == null or mine.identity.is_bot:
		return
	mine.predicted = true
	var controls: Dictionary = {} if _frozen(controller.local_peer_id) else _controls.get(controller.local_peer_id, {})
	mine.simulate(delta, controls)
	if _controls.has(controller.local_peer_id):
		_controls[controller.local_peer_id]["jump"] = false


## 봇의 차례 행동(방장만). 자리에서 일어나 투척선까지 걸어가 던지고, 차례가 끝나면 자리로 돌아가 앉는다.
## 사람과 같은 PlayerView.simulate 를 거치므로 이동·충돌·속도 규칙이 같다.
func _drive_bot(actor: PlayerView, delta: float) -> void:
	var state := controller.state
	if _bots_waiting_in_lobby():
		if actor.seated:
			actor.seated = false
			actor.position = TableView.standing_spot(actor.identity.seat)
			actor.look_at(Vector3(TableView.TABLE_CENTER.x, actor.position.y, TableView.TABLE_CENTER.z))
			actor.update_posture()
		actor.simulate(delta, {})
		return
	var active := state.active_player()
	var mine: bool = active != null and active.peer_id == actor.identity.peer_id
	var playing: bool = mine and state.phase in [MatchState.Phase.AIMING, MatchState.Phase.FLIGHT, MatchState.Phase.SETTLING]
	if not playing:
		# 싱글 플레이: 헤클링하러 나간 봇은 bot_social 이 움직인다(앉은 봇은 말 거는 쪽으로 몸만 돌린다).
		if bot_social != null and bot_social.drive(actor, delta):
			return
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
	var seat: Vector3 = TableView.seat_spot(actor.identity.seat)
	if BotDriver.arrived(actor.position, seat):
		_sit(actor)
		actor.rotation.y = BotDriver.facing_board(actor.position)
		return
	actor.simulate(delta, BotDriver.walk_controls(actor.position, seat))


func send_controls(axis: Vector2, yaw: float, pitch: float, jump: bool, crouch: bool) -> void:
	_sequence += 1
	# 손님도 자기 조작을 바로 들고 있는다 — 방장 응답을 기다리지 않고 _predict_local 이 먼저 걷게 한다.
	_accept_controls(controller.local_peer_id, _sequence, axis, yaw, pitch, jump, crouch)
	if not multiplayer.is_server():
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
		var id: int = int(pose.id)
		if not actors.has(id):
			continue
		var actor := actors[id] as PlayerView
		if id == controller.local_peer_id and not multiplayer.is_server() and _trusts_prediction(actor, pose):
			actor.keep_predicted_motion(pose)
		else:
			actor.apply_motion(pose)


## 내가 예측한 자리를 그대로 믿어도 되는가. 걷는 동안 스냅샷은 늘 왕복 지연만큼 뒤처져 오므로
## 그 정도 차이는 정상이다. 가만히 서 있는데 어긋났거나 그보다 크게 벌어졌으면 내가 모르는 일이
## 벌어진 것이다(피격으로 밀림·스턴·자리 앉기·쓰러짐) → 방장 자리를 따른다.
func _trusts_prediction(actor: PlayerView, pose: Dictionary) -> bool:
	if actor.fallen or actor.seated or bool(pose.get("seated", false)):
		return false
	return actor.position.distance_to(pose.position as Vector3) <= PREDICT_TRUST


func request_seat() -> void:
	if multiplayer.is_server():
		_accept_seat(controller.local_peer_id)
	else:
		session.request_game_action.rpc_id(1, "seat", [controller.state.match_id])


func _receive_action(sender: int, action: String, payload: Array) -> void:
	if action == "seat" and payload.size() == 1 and payload[0] == controller.state.match_id:
		_accept_seat(sender)
	elif action == "look":
		_accept_look(sender, payload)


# ─────────────────────────────── 꾸미기 방(2026-11-15) ───────────────────────────────

## 꾸미기 방에 들어갈 수 없는(또는 있으면 바로 나와야 하는) 때: 쓰러짐 · 앉음 · 내 조준 차례 · 테이블 집합 · 경기 끝.
## → 방에 있느라 차례·집합을 놓치는 일이 없다(게임에 지장 없게).
func _wardrobe_blocked(local: PlayerView) -> bool:
	var state := controller.state
	var own_turn: bool = state.active_player() != null and state.active_player().peer_id == controller.local_peer_id
	return local.fallen or local.seated or state.phase in [MatchState.Phase.TABLE, MatchState.Phase.FINISHED] \
		or (own_turn and state.phase == MatchState.Phase.AIMING)


## 문에서 F: 화면이 검게 바뀌며 탈의실로 들어간다. 몸은 문 앞에 남고(마우스가 풀려 이동 입력 0) 이름표에 "꾸미는 중".
func open_wardrobe() -> void:
	var local := actors.get(controller.local_peer_id) as PlayerView
	if wardrobe_open() or local == null or _wardrobe_blocked(local):
		return
	wardrobe = Wardrobe.new()
	wardrobe.name = "Wardrobe"
	wardrobe.seat = local.identity.seat
	wardrobe.look = local.look.duplicate()
	wardrobe.closed.connect(_on_wardrobe_closed)
	# 페이드가 끝나 closed 가 오는 길 말고도, 어떤 이유로든 노드가 트리에서 빠지면 참조를 놓는다.
	wardrobe.tree_exited.connect(_forget_wardrobe)
	add_child(wardrobe)
	_prop_charge_from = -1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_send_look(local.look, true)


## 탈의실에서 나왔다: 내 화면에 바로 입히고 · 다음 판을 위해 저장하고 · 방장에게 보낸다.
## 꾸미기 방이 지금 정말로 열려 있는가. 지워진 노드는 GDScript 에서 null 이 아니므로 꼭 이걸로 본다.
## [2026-11-26 사용자 "앉아서 엔터 누르는 순간 다트 던지기 빼고 아무 키도 안 먹는다"]
## 방이 닫히는 길은 _process 페이드가 끝나며 보내는 closed 신호 하나뿐이었다(close_now 는 부르는 데가 없다).
## 그 신호 없이 노드가 지워지면 wardrobe 가 지워진 객체를 가리킨 채 남아 _unhandled_input 이 통째로 쉬었다
## → 시점·이동·Space·F·Enter 가 전부 죽고, _input 으로 받는 다트 던지기만 살아남는다.
func wardrobe_open() -> bool:
	if wardrobe != null and not is_instance_valid(wardrobe):
		wardrobe = null
	return wardrobe != null


## 꾸미기 방 노드가 트리에서 빠지면 참조를 놓는다(페이드가 끝나지 못한 경우까지).
func _forget_wardrobe() -> void:
	wardrobe = null


func _on_wardrobe_closed(look: Dictionary) -> void:
	wardrobe = null
	var clean: Dictionary = PlayerOutfit.sanitize(look)
	Preferences.look = clean
	Preferences.save()
	var local := actors.get(controller.local_peer_id) as PlayerView
	if local != null:
		local.wear(clean)
		# 1인칭 팔도 같은 차림(옷 색 소매 · 캐릭터 피부).
		_hand.set_look(int(clean.shirt), int(clean.character))
	_send_look(clean, false)
	if is_inside_tree() and DisplayServer.get_name() != "headless" and controller.state.phase != MatchState.Phase.FINISHED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _send_look(look: Dictionary, in_wardrobe: bool) -> void:
	var payload: Array = [controller.state.match_id, PlayerOutfit.sanitize(look), in_wardrobe]
	if multiplayer.is_server():
		_accept_look(controller.local_peer_id, payload)
	elif session != null:
		session.request_game_action.rpc_id(1, "look", payload)


## 방장: 차림 하나를 받아 검사(칸 번호를 목록 안으로)하고 모두의 차림 + 꾸미는 중 명단을 다시 보낸다.
func _accept_look(sender: int, payload: Array) -> void:
	if payload.size() != 3 or int(payload[0]) != controller.state.match_id or not (payload[1] is Dictionary):
		return
	var actor := actors.get(sender) as PlayerView
	if actor == null or actor.identity.is_bot:
		return
	var clean: Dictionary = PlayerOutfit.sanitize(payload[1])
	if bool(payload[2]): _dressing[sender] = true
	else: _dressing.erase(sender)
	var looks: Dictionary = {}
	for id: int in actors:
		looks[id] = clean if id == sender else (actors[id] as PlayerView).look
	var data := {"match_id": controller.state.match_id, "looks": looks, "dressing": _dressing.keys()}
	_apply_looks(data)
	if session != null:
		session.receive_game_event.rpc("looks", data)


## 모든 화면: 방장이 보낸 차림을 입히고(바뀐 사람만 부품을 갈아 끼운다) "꾸미는 중" 표시를 맞춘다.
func _apply_looks(data: Dictionary) -> void:
	var looks: Variant = data.get("looks", {})
	var dressing: Variant = data.get("dressing", [])
	if not (looks is Dictionary) or not (dressing is Array):
		return
	for key: Variant in looks:
		var id: int = int(key)
		var actor := actors.get(id) as PlayerView
		if actor == null:
			continue
		var clean: Dictionary = PlayerOutfit.sanitize(looks[key])
		actor.wear(clean)
		if id == controller.local_peer_id:
			_hand.set_look(int(clean.shirt), int(clean.character))
		var room_player: RoomPlayer = session.room.find_player(id) if session != null else null
		if room_player != null:
			room_player.look = clean
	for id: int in actors:
		(actors[id] as PlayerView).set_dressing((dressing as Array).has(id))


func _accept_seat(sender: int) -> void:
	var actor := actors.get(sender) as PlayerView
	if actor == null or actor.identity.is_bot or actor.fallen:
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
func _bots_waiting_in_lobby() -> bool:
	return session != null and session.room.phase == RoomState.Phase.LOBBY and controller.state.phase == MatchState.Phase.WAITING and not controller.card_test_active


func force_seat(id: int) -> void:
	var actor := actors.get(id) as PlayerView
	if actor != null and not actor.seated:
		_sit(actor)


func _sit(actor: PlayerView) -> void:
	actor.seated = true
	actor.crouched = false
	actor.position = TableView.seat_spot(actor.identity.seat)
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
	return actor.position.distance_to(TableView.seat_spot(actor.identity.seat)) <= TableView.SEAT_DISTANCE and absf(actor.velocity.y) < 0.5


func is_seated(id: int) -> bool:
	var actor := actors.get(id) as PlayerView
	return actor != null and actor.seated


## 지금 서 있는 자리에서 던질 수 있는지. 라운지(테이블 쪽)에서는 못 던진다.
func can_throw_from(id: int) -> bool:
	var actor := actors.get(id) as PlayerView
	return actor != null and TableView.in_throw_zone(actor.position) and (lounge == null or not lounge.is_stunned(id))


## 1인칭 손: 충전하면 팔꿈치를 축으로 얼굴 쪽으로 당겨 촉이 들리고(최대 충전이면 살짝 떨림),
## 놓으면 아래팔을 뻗으며 손목을 꺾고 손가락을 편 뒤 아래로 떨어진다(곡선 = art/characters/first_person_throw.gd).
## 다음 다트가 있으면 그 다트를 쥐고 다시 올라온다.
## 과녁도 다트가 꽂히면 잠깐 움찔한다. 둘 다 내 화면 연출이고 판정 좌표는 그대로다.
func _animate_hand(delta: float) -> void:
	_throw_kick = maxf(0.0, _throw_kick - delta / FirstPersonThrow.KICK_SECONDS)
	# 거절되거나 경기 전환 중 사라진 발의 촉을 다음 투척에 쓰지 않는다.
	if _throw_kick <= 0.0:
		_score_starts.clear()
		_stray_starts.clear()
	_board_shake = maxf(0.0, _board_shake - delta * 4.0)
	var reload: bool = throw_input.enabled
	if throw_input.charging:
		_held_pull = throw_input.timing
		# 팔로 스루 중에 다음 다트를 당기기 시작하면 바로 다시 쥐고 올라오는 구간으로 넘긴다.
		_throw_kick = minf(_throw_kick, 1.0 - FirstPersonThrow.RISE_START)
	elif _throw_kick <= 0.0:
		_held_pull = move_toward(_held_pull, 0.0, delta * 4.0)
	var pull: float = throw_input.timing if throw_input.charging else 0.0
	var motion: float = 0.3 if Preferences.reduced_motion else 1.0
	var me: MatchPlayer = controller.state.find_player(controller.local_peer_id)
	var large: bool = me != null and bool(me.card_effects.get("large", false))
	var first_person: bool = me != null and camera.is_current() and not camera.get_cull_mask_value(me.seat + 2)
	var show_hand: bool = is_visible_in_tree() and first_person and (reload or _throw_kick > 0.0)
	_hand.visible = FIRST_PERSON_HAND_3D and _hand.arm != null and show_hand
	_dart_hand.visible = not FIRST_PERSON_HAND_3D and show_hand
	var now: float = Time.get_ticks_msec() / 1000.0
	var tremble := Vector2.ZERO
	if throw_input.charging and not Preferences.reduced_motion:
		tremble = Vector2(sin(now * 36.0), cos(now * 41.0)) * pull * pull
	var shown_pull: float = _held_pull if _throw_kick <= 0.0 else pull
	if _hand.visible:
		# 비행 중에는 입력이 잠겨도 여분이 있으면 0.52초부터 다음 다트를 들어 올린다.
		var next_dart: bool = me.darts > 0 if _throw_kick > 0.0 else reload
		_hand.animate(delta, shown_pull, _throw_kick, _released_pull, next_dart, large, motion, tremble)
	elif _dart_hand.visible:
		_dart_hand.pose(shown_pull, _throw_kick, _released_pull, reload, large, motion)
		_dart_hand.position += tremble * _dart_hand.scale.x * 3.0
	camera.rotation.x += FirstPersonThrow.recoil(_throw_kick) * 0.02 * motion
	table.board.position = Vector3.UP * TableView.BOARD_CENTER.y + Vector3.FORWARD * 0.003 * _board_shake


## 내가 던졌다는 응답이 오면 1인칭 던지기 몸짓을 시작한다(놓을 때 당긴 자세에서 출발).
## 1인칭 시선 각도(x = 좌우, y = 위아래). 마우스가 움직이는 대로 매 프레임 갱신되며 카메라가 쓰는 값 그대로다.
## 몸 각도(PlayerView.rotation.y·pitch)는 조작 전송 주기(MOTION_INTERVAL)에만 갱신되므로, 눈앞에 크게 보이는 것은
## 몸이 아니라 이 값을 따라야 화면과 같이 돈다.
func look_angles() -> Vector2:
	return Vector2(_yaw, _pitch)


func _start_throw_kick() -> void:
	_released_pull = _held_pull
	_throw_kick = 1.0


func _process(delta: float) -> void:
	var local := actors.get(controller.local_peer_id) as PlayerView
	if local == null:
		return
	var state := controller.state
	var own_turn: bool = state.active_player() != null and state.active_player().peer_id == controller.local_peer_id
	# 꾸미기 방에 있는데 내 차례·테이블 집합·쓰러짐이 오면 바로 나온다(고른 것은 입고 나온다).
	if wardrobe_open() and _wardrobe_blocked(local):
		wardrobe.close()
	_face_table_on_sit(local)
	camera.position = local.eye_position()
	# 엿보기(앉아서 A·D): 몸이 기운 쪽으로 화면도 기운다(레식 기울이기). 마시는 중이면 고개가 뒤로 젖혀진다.
	camera.h_offset = 0.0
	camera.rotation = Vector3(_pitch + local.drink_pose_tilt() * PlayerView.DRINK_LOOK_UP, _yaw, local.peek_roll())
	# 쓰러진 동안: 1인칭을 잠깐 3인칭으로 — 쓰러진 내 몸을 뒤에서 내려다본다(내 몸 레이어도 보이게).
	camera.cull_mask = 0xfffff if local.fallen else 0xfffff & ~(1 << (local.identity.seat + 1))
	if local.fallen:
		var center: Vector3 = local.fallen_center()
		var want: Vector3 = center + Basis(Vector3.UP, _yaw) * Vector3.BACK * FALL_CAMERA_BACK + Vector3.UP * FALL_CAMERA_UP
		# 벽·바 카운터에 막히면 그 앞까지만 물러난다(카메라가 벽 속에 들어가 화면이 한 색으로 덮이지 않게).
		var from: Vector3 = center + Vector3.UP * 0.4
		var wall := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, want, 1))
		if not wall.is_empty():
			want = wall.position + (from - (wall.position as Vector3)).normalized() * 0.25
		camera.position = want
		camera.look_at(center, Vector3.UP)
	var dizzy: float = float(local.identity.card_effects.get("dizzy", 0.0))
	if Preferences.visual_effects and dizzy > 0:
		var strength: float = dizzy * (0.15 if Preferences.reduced_motion else 1.0)
		var time: float = Time.get_ticks_msec() / 1000.0
		camera.rotation.z += sin(time * 1.7) * deg_to_rad(15.0) * strength
		camera.h_offset = sin(time * 1.13) * 0.12 * strength
	# 화면 카드(정전·딸꾹질·유체이탈·망원경·원샷). 조준(아래 aim_at)보다 먼저 — 카메라가 흔들리면 조준도 흔들린다.
	if _card_screen != null:
		_card_screen.apply(camera, local, state.active_player(), delta)
	_punish_camera()
	if seat_cards != null:
		seat_cards.show_peek(local, delta)
	if lounge != null:
		var amount: float = lounge.intoxication_amount(controller.local_peer_id)
		if Preferences.visual_effects and not Preferences.reduced_motion:
			camera.rotation.z += sin(Time.get_ticks_msec() / 780.0) * amount * 0.025
		if _screen_fx != null:
			_screen_fx.drowsy = Preferences.visual_effects and bool(local.identity.card_effects.get("drowsy", false))
			_screen_fx.penalty = (3 if amount > 1.4 else int(local.identity.card_effects.get("hit_penalty", 0))) if Preferences.visual_effects else 0
			if Preferences.visual_effects and not Preferences.reduced_motion: camera.rotation.z += sin(Time.get_ticks_msec() / 800.0) * _screen_fx.sway * 0.035
		if _last_quality != Preferences.quality:
			_last_quality = Preferences.quality
			get_viewport().scaling_3d_scale = [0.65, 0.85, 1.0][_last_quality]
			get_viewport().msaa_3d = Viewport.MSAA_2X if _last_quality == 2 else Viewport.MSAA_DISABLED
		for actor: PlayerView in actors.values():
			var identity: RoomPlayer = session.room.find_player(actor.identity.peer_id)
			actor.ready_pose = session.room.phase == RoomState.Phase.LOBBY and identity != null and identity.is_ready and not identity.is_bot
		var current: MatchPlayer = state.active_player()
		if current != null:
			table.board.show_layout(current.layout)
	_show_chaos(delta)
	var marked_sector: int = -1
	if local.identity.pending_card >= 0:
		var card: Dictionary = CardCatalog.card(local.identity.pending_card)
		if str(card.get("choice", "")) == "sector": marked_sector = int(local.identity.card_effects.get("choice", -1))
	# 이미 쓴 지목 카드(구역 지목 = 무작위 · 더블 오어 낫싱)가 노리는 칸 — 모두의 화면에 보인다.
	if marked_sector < 0 and state.active_player() != null:
		marked_sector = int(state.active_player().card_effects.get("marked_sector", -1))
	table.board.show_choice(marked_sector)
	# 다트 홀 밖(라운지)에서는 조준·충전 자체를 잠근다 — 방장도 같은 조건으로 거부한다.
	var can_aim: bool = own_turn and state.phase == MatchState.Phase.AIMING and can_throw_from(controller.local_peer_id)
	# 라운드당 다트(2026-11-15): 다트 단계에 다트가 남아 있으면 차례가 아니어도 아무 데나 던질 수 있다(점수 없음 · 사람이 맞으면 2번에 쓰러짐).
	# 내 다트가 날아가는 중(비행·정산)에는 막는다 — 방장도 같은 조건으로 거부한다(MatchController._accept_stray).
	var dart_phase: bool = state.phase in MatchController.DART_PHASES and not (own_turn and state.phase != MatchState.Phase.AIMING)
	# 카드 던지기 카드가 걸려 있으면 다트가 없어도 던질 수 있다(카드가 날아간다).
	var can_stray: bool = dart_phase and (local.identity.darts > 0 or bool(local.identity.card_effects.get("card_throw", false)))
	var hands_free: bool = lounge == null or (lounge.held(controller.local_peer_id) < 0 and not lounge.is_stunned(controller.local_peer_id))
	throw_input.enabled = (can_aim or can_stray) and not local.fallen and hands_free and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	throw_input.free_aim = true
	_animate_hand(delta)
	if _card_screen != null: _card_screen.light_board(camera, table.board)
	# 머리 위 이름표 왼쪽 마이크(보이기만, 화면마다 따로): 조용 · 말하는 중 · 내가 음소거한 사람. 봇은 목소리가 없어 숨긴다.
	var voice: VoiceChat = session.voice if session != null else null
	for id: int in actors:
		var actor := actors[id] as PlayerView
		var effects: Dictionary = actor.identity.card_effects
		actor.waiting_at_attention = actor.identity.is_bot and _bots_waiting_in_lobby()
		# 목소리 변조·강제 음소거 카드(2026-11-21) → 재생 높낮이·중계 차단. 마이크 그림도 꺼진 모양.
		if voice != null: voice.set_card_voice(id, float(effects.get("voice_pitch", 1.0)), bool(effects.get("mute", false)))
		var mic: int = -1
		if not actor.identity.is_bot:
			mic = 2 if Preferences.person_muted(actor.identity.display_name) or bool(effects.get("mute", false)) else (1 if voice != null and voice.is_speaking(id) else 0)
		actor.set_mic(mic, voice.level(id) if mic == 1 else 0.0)
		if voice != null: voice.set_warped(id, int(effects.get("hit_penalty", 0)) > 0)
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
	var turn_id: int = controller.state.active_player().peer_id if controller.state.active_player() != null else 0
	for id: int in actors.keys():
		var player := controller.state.find_player(id)
		if player == null:
			var actor := actors[id] as PlayerView
			_players_root.remove_child(actor)
			actor.queue_free()
			actors.erase(id)
			_controls.erase(id)
		else:
			(actors[id] as PlayerView).show_state(player, id == turn_id and controller.state.phase in MatchController.DART_PHASES)
	if seat_cards != null:
		seat_cards.show_hands(controller.state.players)
	# 카드 충전 라운드로 들어오면 덱 섞기·나눠 주기를 각 화면에서 재생한다(새 카드는 닿을 때까지 매트에서 숨김).
	if deck_show != null:
		deck_show.sync(controller.state)
	# 손 부채는 덱 연출이 "아직 안 닿은 칸"을 정한 뒤에 맞춘다(2026-11-08 — 순서가 반대면 7장이 한꺼번에 보인다).
	_sync_hand_fan()
	if held_cards != null:
		held_cards.sync(actors, controller.state.players, controller.local_peer_id)
	var shooter := controller.state.active_player()
	# 점수·차례·벌칙은 과녁 벽 점수판(game/table/score_wall.gd)이 보여 준다 — 화면 UI 로 겹쳐 그리지 않는다.
	table.show_scores(controller.state.players, shooter.peer_id if shooter != null else 0, controller.state.punish_target)
	if table.machine != null and shooter != null:
		table.machine.set_readout(shooter.display_name, shooter.score)
	if _shown_turn != controller.state.turn_id:
		_shown_turn = controller.state.turn_id
		_clear_darts()
	_sync_punishment()
	_claim_tokens()
	# 몸으로 막힌 한 발: 모든 화면이 같은 스냅샷을 보고 맞은 사람 머리 위에 별을 띄운다.
	var hit: Dictionary = controller.state.last_hit
	var victim_id: int = int(hit.get("victim", 0))
	var key := "%s:%s" % [hit.get("request_id", 0), victim_id]
	if victim_id != 0 and key != _shown_block:
		_shown_block = key
		_show_body_hit(victim_id, hit.get("target", Vector3.ZERO))
	_show_score_popup(hit)


## 벌칙(2026-11-23 사용자 요청): 꼴찌를 돌아가는 점수 과녁판에 묶는다.
## 모든 화면이 같은 스냅샷(state.punish_target)을 보고 같은 그림을 만든다 — 묶는 것은 방장이 정한다.
## 묶인 사람의 실제 몸은 숨긴다: 판 위의 복사본만 남아 다트가 두 번 맞지 않는다.
func _sync_punishment() -> void:
	var state := controller.state
	var target: int = state.punish_target if state.phase in MatchController.DART_PHASES else 0
	if target == strapped_id:
		return
	if strapped_id != 0:
		if table != null and table.board != null:
			table.board.release_victim()
		var freed := actors.get(strapped_id) as PlayerView
		if freed != null:
			freed.visible = true
	strapped_id = target
	_punish_turn_sent = 0
	if target == 0:
		return
	var victim := actors.get(target) as PlayerView
	if victim == null or victim.identity == null or table == null or table.board == null:
		strapped_id = 0
		return
	victim.visible = false
	var model: Node3D = PlayerLook.character(victim.identity.seat)
	PlayerOutfit.dress(model, victim.look)
	table.board.strap_victim(model)
	# 팔다리를 벌린 자세로 굳힌다(트리에 붙인 뒤에 불러야 한다 — character_motion.gd freeze).
	CharacterMotion.freeze(model, "Wheel_Spread")


## Esc 로 닫을 수 있는 화면 위 팝업을 닫는다(2026-11-25). 닫은 게 있으면 true —
## 그러면 Main 은 설정 창을 열지 않는다(app/main.gd _input).
func close_popups() -> bool:
	if lounge_hud != null and lounge_hud.has_method("close_sector_picker"):
		return bool(lounge_hud.close_sector_picker())
	return false


## 벌칙으로 묶였으면 내 시점을 과녁판 위로 옮긴다 — 판이 돌면 펍이 통째로 돈다(2026-11-23).
## 내 몸은 숨겨져 있고 판 위의 복사본이 돌고 있으므로, 그 복사본의 눈에서 던지는 쪽을 본다.
func _punish_camera() -> void:
	if strapped_id != controller.local_peer_id or table == null or table.board == null:
		return
	# 2026-11-25 사용자 요청: 예전에는 묶인 사람 눈에서 봐서 화면이 통째로 빙글빙글 돌아 어지러웠다.
	# 이제 레인 옆에 고정한 자리에서 3인칭으로 본다 — 방은 가만히 있고 판 위의 내 몸만 돈다.
	camera.global_position = PUNISH_VIEW
	camera.look_at(TableView.BOARD_CENTER, Vector3.UP)
	# 3인칭이므로 내 몸 레이어도 보이게 둔다(판 위 복사본은 보통 레이어다).
	camera.cull_mask = 0xfffff


## 경기가 끝나면 내 토큰을 한 번만 정산한다(app/player_wallet.gd).
## 순위·벌칙 맞은 횟수는 방장이 보낸 같은 값이므로 모든 화면이 같은 결과를 낸다.
func _claim_tokens() -> void:
	var state := controller.state
	if state.phase != MatchState.Phase.FINISHED or state.match_id == _tokens_claimed_match:
		return
	if controller.local_peer_id == 0:
		return
	_tokens_claimed_match = state.match_id
	for row: Dictionary in state.ranking():
		var player: MatchPlayer = row.player
		if player.peer_id != controller.local_peer_id:
			continue
		token_change = PlayerWallet.match_reward(int(row.rank), player.peer_id == state.punish_target, player.punish_hits)
		PlayerWallet.grant(token_change)
		return


## 과녁(또는 벽)에 꽂힌 한 발의 점수를 그 자리에 3D 글자로 띄운다. 판정은 방장이 이미 끝냈다(MatchState.last_hit = 결과).
## 몸에 막힌 발(별이 뜬다)·다트 없음/시간 초과 기록(request_id ≤ 0, 꽂힌 자리 없음)은 띄우지 않는다.
func _show_score_popup(hit: Dictionary) -> void:
	var key := "%s:%s:%s" % [controller.state.match_id, hit.get("request_id", 0), hit.get("peer_id", 0)]
	if not _score_popups_ready:
		_score_popups_ready = true
		_shown_score = key
		return
	if key == _shown_score:
		return
	_shown_score = key
	if hit.is_empty() or int(hit.get("request_id", 0)) <= 0 or not (hit.get("target") is Vector3):
		return
	for flight: Dictionary in hit.get("flights", [hit]):
		if int(flight.get("victim", 0)) != 0:
			return
	if DisplayServer.get_name() == "headless" or table == null or table.board == null:
		return
	var bust: bool = str(hit.get("reason", "")).begins_with("버스트")
	# 지뢰를 밟았거나(지뢰 심기) 점수를 뺏겼으면(가로채기·반띵) 한마디를 바꿔 "MISS"로 보이지 않게 한다(2026-11-21).
	var note: String = ""
	if int(hit.get("mine_hits", 0)) > 0: note = "MINE!"
	elif float(hit.get("taken", 0.0)) > 0.0: note = "%s TAKEN" % ScorePopup.number_text(-float(hit.taken))
	ScorePopup.spawn(self, hit.target, float(hit.get("points", 0)), table.board.global_basis.z, bust, note, TableView.CEILING_HEIGHT)


## [개발자 모드] 나를 투척선 뒤로 옮긴다. 방장이 자리를 소유하므로 방장 화면에서만 뜻이 있다.
func developer_teleport(peer_id: int) -> bool:
	if not multiplayer.is_server() or not developer_enabled:
		return false
	var actor := actors.get(peer_id) as PlayerView
	if actor == null:
		return false
	actor.seated = false
	actor.update_posture()
	actor.position = Vector3(0, 0, TableView.THROW_LINE_Z + 0.4)
	return true


func can_start_card_test() -> bool:
	return developer_enabled and session != null and session.is_host() and session.room.settings.solo \
		and session.room.phase == RoomState.Phase.LOBBY and is_instance_valid(actors.get(controller.local_peer_id)) \
		and session.room.players.all(func(player: RoomPlayer) -> bool: return player.is_bot or player.peer_id == controller.local_peer_id) \
		and (controller.state.phase == MatchState.Phase.WAITING or controller.card_test_active)


func start_card_test() -> void:
	if not can_start_card_test():
		return
	_reset_card_test()
	var thrower := actors[controller.local_peer_id] as PlayerView
	if lounge != null:
		lounge._drop_held(controller.local_peer_id)
	thrower.crouched = false
	developer_teleport(controller.local_peer_id)
	thrower.velocity = Vector3.ZERO
	var to_board: Vector3 = TableView.BOARD_CENTER - thrower.eye_position()
	_yaw = atan2(-to_board.x, -to_board.z)
	_pitch = atan2(to_board.y, Vector2(to_board.x, to_board.z).length())
	_was_seated = false
	# 조준형 방해 카드도 같은 위치에서 비교할 수 있게 투척선 바깥쪽에 세운다.
	var first_bot: PlayerView
	var sides: Array[float] = [-1.8, 1.8, 3.6]
	var bot_index: int = 0
	for player: MatchPlayer in controller.state.players:
		if not player.is_bot:
			continue
		var bot := actors.get(player.peer_id) as PlayerView
		if bot == null:
			continue
		if first_bot == null:
			first_bot = bot
		bot.seated = false
		bot.crouched = false
		bot.velocity = Vector3.ZERO
		bot.position = thrower.position + Vector3(sides[bot_index], 0, -0.8)
		bot.update_posture()
		_aim_test_actor(bot, thrower)
		bot_index += 1
	var type: int = int(card_test_selection.get(controller.local_peer_id, -1))
	if first_bot != null and CardCatalog.is_available(type) and bool(CardCatalog.card(type).get("aim", false)):
		_aim_test_actor(thrower, first_bot)
	controller.start_card_test(card_test_selection)
	thrower.rotation.y = _yaw
	thrower.pitch = _pitch


static func _aim_test_actor(actor: PlayerView, target: PlayerView) -> void:
	var direction: Vector3 = target.global_position + Vector3.UP * 0.9 - actor.eye_position()
	actor.rotation.y = atan2(-direction.x, -direction.z)
	actor.pitch = atan2(direction.y, Vector2(direction.x, direction.z).length())


func stop_card_test() -> void:
	if controller.card_test_active:
		_reset_card_test()


func _reset_card_test() -> void:
	# 이전에 날린 카드의 지연 판정도 다음 테스트 턴에 들어오지 않게 한다.
	var mouse_mode := Input.mouse_mode
	remove_child(card_world)
	card_world.free()
	_setup_card_world()
	throw_input.enabled = false
	begin_match(session.room)
	Input.mouse_mode = mouse_mode


func _setup_card_world() -> void:
	card_world = CardWorld.new()
	card_world.name = "CardWorld"
	add_child(card_world)
	card_world.setup(self)
	controller.card_world = card_world.host_action


## 못 움직이는 상태인가: 소품에 맞은 스턴(LoungeWorld)과 몸으로 막은 스턴을 함께 본다.
## [방장] 넉백 없이 잠깐 못 움직이게 한다(속박·끌어당기기·카드 맞음 — CardWorld). 이미 더 길게 묶여 있으면 그대로.
func freeze_player(peer_id: int, seconds: float) -> void:
	if multiplayer.is_server():
		_stun_until[peer_id] = maxf(float(_stun_until.get(peer_id, 0.0)), controller._now() + seconds)


func _frozen(peer_id: int) -> bool:
	# 벌칙으로 과녁판에 묶인 사람은 움직일 수 없다(2026-11-23).
	if peer_id == strapped_id:
		return true
	if controller._now() < float(_stun_until.get(peer_id, 0.0)):
		return true
	return lounge != null and lounge.is_stunned(peer_id)


## 몸으로 막혔다(MatchController 가 방장에서 부른다): 맞은 사람이 seconds 동안 못 움직이고
## 레인 옆으로 튕겨 난다. 머리 위 별은 각 화면이 스냅샷을 보고 띄운다(_apply_state).
func stun_player(peer_id: int, seconds: float) -> void:
	if not multiplayer.is_server():
		return
	_stun_until[peer_id] = controller._now() + seconds
	var actor := actors.get(peer_id) as PlayerView
	if actor == null or actor.seated:
		return
	# 다음 발을 연속으로 막지 않도록 궤적 옆으로 튕긴다.
	var away: float = signf(actor.global_position.x)
	actor.knockback = Vector3(away if away != 0.0 else 1.0, 0, 0) * BODY_KNOCKBACK


## 쓰러진 동안 3인칭 카메라: 쓰러진 몸에서 뒤로 · 위로 떨어진 거리(m).
const FALL_CAMERA_BACK: float = 1.9
const FALL_CAMERA_UP: float = 1.5
## 따로 세기를 안 받으면(다트 두 번) 쓰러지는 세기: 뒤로 FALL_PUSH m/s + 위로 조금.
const FALL_PUSH: float = 2.6
## 그냥 던진 다트: 힘(0~1)에 따른 빠르기(m/s)와 떨어지는 정도. 과녁 투척(DartConfig)보다 단순한 직선 + 가벼운 중력.
const STRAY_MIN_SPEED: float = 7.0
const STRAY_MAX_SPEED: float = 17.0
const STRAY_GRAVITY: float = 4.5
const STRAY_MAX_TIME: float = 1.6
## 그냥 던진 다트에 맞은 사람이 밀려나는 세기(m/s).
const STRAY_PUSH: float = 2.4


## 왼쪽 버튼을 놓았다: 내 차례에 던지는 칸에서 과녁을 겨눴으면 점수 투척, 아니면 그냥 던지기(다트만 쓴다).
func _on_throw_requested(aim: Vector2, timing: float) -> void:
	var id: int = controller.local_peer_id
	var state := controller.state
	var active := state.active_player()
	var own: bool = active != null and active.peer_id == id and state.phase == MatchState.Phase.AIMING
	var scoring: bool = own and aim.is_finite() and can_throw_from(id)
	var me: MatchPlayer = state.find_player(id)
	if _hand.visible and me != null and not bool(me.card_effects.get("card_throw", false)):
		var starts: Array[Vector3] = _score_starts if scoring else _stray_starts
		# 점수 투척은 한 발씩, 연속 자유 투척은 보유한 발수까지 입력 순서로 대응한다.
		var available: int = 1 if scoring else me.darts
		if starts.size() < available:
			starts.append(_hand.release_start(camera))
			_start_throw_kick()
	if scoring:
		controller.submit_throw(aim, timing)
	else:
		controller.submit_stray(timing)
		_warn_not_your_turn(state, active, id)
	# 방장은 같은 호출에서 승인 통지를 받는다. 남아 있으면 거절된 요청이다.
	if multiplayer.is_server():
		_score_starts.clear()
		_stray_starts.clear()


## 경기 중(다트 단계)에 남의 차례인데 던졌으면 내 화면에 "내 차례가 아니에요!"를 띄운다(다트는 그냥 던진 다트로 날아간다 — 점수 없음).
func _warn_not_your_turn(state: MatchState, active: MatchPlayer, id: int) -> void:
	if active == null or active.peer_id == id or not state.phase in TURN_TOAST_PHASES:
		return
	if turn_toast == null:
		turn_toast = TurnToast.new()
		turn_toast.name = "TurnToast"
		add_child(turn_toast)
	var color: Color = PlayerLook.COLORS[active.seat % PlayerLook.COLORS.size()].lightened(0.3)
	turn_toast.show_not_your_turn(PlayerLook.tag(active.seat, active.display_name), color)


## [방장] 그냥 던진 다트를 날린다: 던진 사람 눈에서 보는 방향으로 날아가 처음 닿는 곳(벽·바닥·사람)에 꽂힌다.
## 모든 화면에 "stray_dart" 로 보이고, 사람이 맞았으면 꽂히는 시각에 MatchController.stray_hit 가 횟수를 센다.
func throw_stray(peer_id: int, charge: float) -> bool:
	var actor := actors.get(peer_id) as PlayerView
	if actor == null or actor.fallen or _frozen(peer_id):
		return false
	var aim_basis := Basis(Vector3.UP, actor.rotation.y) * Basis(Vector3.RIGHT, actor.pitch)
	var direction: Vector3 = aim_basis * Vector3.FORWARD
	var start: Vector3 = actor.eye_position() + direction * 0.35 + aim_basis * Vector3(0.12, -0.1, 0.0)
	var velocity: Vector3 = direction * lerpf(STRAY_MIN_SPEED, STRAY_MAX_SPEED, clampf(charge, 0.0, 1.0))
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = [actor.get_rid()]
	var at: Vector3 = start
	var time: float = 0.0
	var victim_id: int = 0
	var step: float = 1.0 / 60.0
	while time < STRAY_MAX_TIME:
		var next: Vector3 = at + velocity * step
		velocity.y -= STRAY_GRAVITY * step
		time += step
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at, next, 1 | 2, exclude))
		if not hit.is_empty():
			at = hit.position
			if hit.collider is PlayerView:
				victim_id = (hit.collider as PlayerView).identity.peer_id
			break
		at = next
		if at.y <= 0.0:
			at.y = 0.0
			break
	var data := {"match_id": controller.state.match_id, "peer_id": peer_id, "start": start, "target": at,
		"duration": maxf(time, 0.08), "victim": victim_id}
	_show_stray(data)
	if session != null:
		session.receive_game_event.rpc("stray_dart", data)
	if victim_id != 0:
		var push: Vector3 = Vector3(direction.x, 0.0, direction.z).normalized() * STRAY_PUSH + Vector3.UP * 0.6
		get_tree().create_timer(float(data.duration)).timeout.connect(controller.stray_hit.bind(victim_id, push))
	return true


## 그냥 던진 다트를 보인다(모든 화면). 던진 사람은 던지기 몸짓, 다트는 꽂힌 곳에 남는다(차례가 바뀌면 치운다).
## 사람에게 꽂힌 다트는 "툭" 소리와 함께 사라진다(움직이는 몸에 붙여 두지 않는다).
func _show_stray(data: Dictionary) -> void:
	var thrower := actors.get(int(data.get("peer_id", 0))) as PlayerView
	var visual_start: Vector3 = _local_throw_start(thrower, _stray_starts)
	if thrower != null:
		thrower.play_throw()
	if DisplayServer.get_name() == "headless":
		return
	var dart := DART_SCENE.instantiate() as DartView
	_darts.add_child(dart)
	dart.fly(data.start, data.target, float(data.duration))
	if visual_start.is_finite():
		dart.set_visual_start(visual_start)
	if thrower != null:
		dart.paint(thrower.color)
	dart.landed.connect(_on_stray_landed.bind(dart, int(data.get("victim", 0))))
	Sfx.play_at(self, "whoosh", data.start, -8.0)


func _on_stray_landed(at: Vector3, _hit_board: bool, dart: Node3D, victim_id: int) -> void:
	if victim_id != 0:
		Sfx.play_at(self, "thunk", at, -1.0, 1.15)
		BurstFx.spawn(self, "sparks", at, Vector3.UP, Color.WHITE)
		if is_instance_valid(dart): dart.queue_free()
	else:
		Sfx.play_at(self, "bounce", at, -6.0)


## [방장] 쓰러뜨린다(다트 두 번 · NPC 반격 · 싸대기). 그동안 조작을 막고, 모든 화면에 "player_fall" 을 보낸다.
## push = 날아가는 방향과 세기. 0 이면 바라보는 반대쪽(뒤)으로 넘어진다.
func knock_down(peer_id: int, push: Vector3 = Vector3.ZERO) -> void:
	if not multiplayer.is_server():
		return
	var actor := actors.get(peer_id) as PlayerView
	if actor == null or actor.fallen:
		return
	if push == Vector3.ZERO:
		push = Basis(Vector3.UP, actor.rotation.y) * Vector3.BACK * FALL_PUSH + Vector3.UP * 0.8
	_stun_until[peer_id] = maxf(float(_stun_until.get(peer_id, 0.0)), controller._now() + PlayerView.FALL_SECONDS)
	# 들고 있던 소품은 손에서 떨어진다.
	if lounge != null:
		lounge._drop_held(peer_id)
	var data := {"match_id": controller.state.match_id, "peer_id": peer_id, "push": push}
	_play_fall(data)
	if session != null:
		session.receive_game_event.rpc("player_fall", data)


func _play_fall(data: Dictionary) -> void:
	var actor := actors.get(int(data.get("peer_id", 0))) as PlayerView
	if actor == null:
		return
	actor.fall(data.get("push", Vector3.ZERO))
	if DisplayServer.get_name() != "headless":
		Sfx.play_at(self, "thunk", actor.global_position + Vector3.UP * 0.8, 0.0, 0.7)


## 방장이 모두에게 보낸 GameView 이벤트(그냥 던진 다트 · 쓰러짐). 다른 판의 이벤트는 버린다.
func _receive_game_event(kind: String, data: Dictionary) -> void:
	if int(data.get("match_id", -1)) != controller.state.match_id:
		return
	match kind:
		"stray_dart": _show_stray(data)
		"player_fall": _play_fall(data)
		"card_fx": card_world.play(data)
		"looks": _apply_looks(data)


## 몸에 맞은 사람 머리 위의 스턴 별과 소리. 판정은 방장이 했고 여기서는 보이기만 한다.
func _show_body_hit(victim_id: int, at: Vector3) -> void:
	var actor := actors.get(victim_id) as PlayerView
	if actor == null or DisplayServer.get_name() == "headless":
		return
	var stars := StunStars.new()
	stars.seconds = MatchController.BODY_STUN_SECONDS
	actor.add_child(stars)
	Sfx.play_at(self, "thunk", at, -2.0, 0.82)


func _local_throw_start(actor: PlayerView, starts: Array[Vector3]) -> Vector3:
	if actor == null or actor.identity.peer_id != controller.local_peer_id:
		return Vector3.INF
	if not starts.is_empty():
		return starts.pop_front()
	_start_throw_kick()
	if _hand.visible: return _hand.release_start(camera)
	if _dart_hand.visible: return camera.project_position(_dart_hand.tip_on_screen(), HandView.RELEASE_DEPTH)
	return Vector3.INF


func _show_throw(data: Dictionary) -> void:
	_flying_darts.clear()
	var color: Color = PlayerLook.COLORS[0]
	var actor := actors.get(int(data.get("peer_id", 0))) as PlayerView
	if actor != null: color = actor.color
	var visual_start: Vector3 = _local_throw_start(actor, _score_starts)
	for flight: Dictionary in data.get("flights", [data]):
		var dart := DART_SCENE.instantiate() as DartView
		_darts.add_child(dart)
		dart.size_multiplier = DartView.LARGE_SIZE if bool(flight.get("large", false)) else 1.0
		# 힘 증가 카드: 다트 뒤로 바람 줄기가 빨려 들어가듯 흐른다(겉모습 — 빠르기는 방장 계산 그대로).
		dart.powered = bool(flight.get("power", false))
		dart.pierced = bool(flight.get("pierce", false))
		dart.victim_id = int(flight.get("victim", 0))
		if flight.has("bounce_at"):
			# 고무 다트: 처음 닿는 곳까지 날아가 판에서 튕겨 나왔다가 새 자리에 꽂힌다(방장 계산 그대로 보이기만).
			var bounce_at: Vector3 = flight.bounce_at
			dart.fly(flight.start, bounce_at, float(flight.bounce_time), true, $Camera/Hand.position)
			dart.queue_hops(flight.hops)
		else:
			dart.fly(flight.start, flight.target, flight.duration, true, $Camera/Hand.position)
		if visual_start.is_finite():
			dart.set_visual_start(visual_start)
		dart.paint(color)
		dart.landed.connect(_on_dart_landed.bind(dart))
		_flying_darts.append(dart)
	_flying_dart = _flying_darts[0]

	# 깃 = 던진 사람 자리 색, 그 캐릭터는 던지기 몸짓을 한다.
	var thrower := actors.get(int(data.get("peer_id", 0))) as PlayerView
	if thrower != null:
		thrower.play_throw()
	# 힘 증가면 바람 소리도 더 크고 높게(빠르게 가르는 느낌).
	if bool(data.get("power", false)):
		Sfx.play_at(self, "whoosh", data.start, -2.0, 1.35)
	else:
		Sfx.play_at(self, "whoosh", data.start, -8.0)


func _redirect_throw(data: Dictionary) -> void:
	var flights: Array = data.get("flights", [])
	if flights.is_empty():
		if is_instance_valid(_flying_dart): _flying_dart.redirect(data.target, float(data.remaining))
		return
	for index in range(flights.size()):
		var flight: Dictionary = flights[index]
		if index >= _flying_darts.size():
			var dart := DART_SCENE.instantiate() as DartView
			_darts.add_child(dart)
			var from: Vector3 = _flying_dart.global_position if is_instance_valid(_flying_dart) else flight.start
			dart.powered = bool(flight.get("power", false))
			dart.fly(from, flight.target, float(data.remaining))
			var actor := actors.get(int(data.get("peer_id", 0))) as PlayerView
			if actor != null: dart.paint(actor.color)
			dart.landed.connect(_on_dart_landed.bind(dart))
			_flying_darts.append(dart)
		var dart: DartView = _flying_darts[index]
		if is_instance_valid(dart):
			dart.size_multiplier = DartView.LARGE_SIZE if bool(flight.get("large", false)) else 1.0
			dart.pierced = bool(flight.get("pierce", false))
			dart.victim_id = int(flight.get("victim", 0))
			var remaining := float(data.remaining)
			if flight.has("hops"):
				var elapsed := maxf(float(flight.duration) - remaining, 0.0)
				var segments: Array = [[flight.bounce_at, flight.bounce_time]]
				segments.append_array(flight.hops)
				while segments.size() > 1 and elapsed >= float(segments[0][1]):
					elapsed -= float(segments.pop_front()[1])
				var next: Array = segments.pop_front()
				dart.redirect(next[0], maxf(0.01, float(next[1]) - elapsed))
				dart.queue_hops(segments)
			else:
				dart.redirect(flight.target, remaining)
	while _flying_darts.size() > flights.size():
		var extra: DartView = _flying_darts.pop_back()
		if is_instance_valid(extra): extra.queue_free()



## 다트가 멈춘 순간의 손맛: 과녁이 움찔하고 코르크 가루가 튀며 "턱" 소리가 난다. 판정과 무관하다.
## 2026-11-07: 과녁 면에 꽂힌 다트는 맞은 조각에 붙인다(BoardView.pin) — 판이 돌거나 벌어지면 다트도 같이 움직인다.
## 셔터 앞면·머신 몸체·벽에 박힌 다트는 과녁 면(z)에서 떨어져 있으므로 붙이지 않는다.
func _on_dart_landed(at: Vector3, hit_board: bool, dart: DartView = null) -> void:
	# 몸에 맞은 다트는 과녁이 아니라 사람 자리(허공)에서 멈춘다 → 움직이는 몸에 붙여 두지 않고
	# "툭" 소리·불꽃과 함께 없앤다(그냥 던진 다트의 _on_stray_landed 와 같은 처리).
	if dart != null and is_instance_valid(dart) and dart.victim_id != 0:
		Sfx.play_at(self, "thunk", at, -1.0, 1.15)
		BurstFx.spawn(self, "sparks", at, Vector3.UP, Color.WHITE)
		dart.queue_free()
		return
	if dart != null and is_instance_valid(dart) and absf(at.z - TableView.BOARD_CENTER.z) < 0.03:
		var radius: float = BoardLayout.RADIUS * TableView.BOARD_SCALE
		table.board.pin(dart, Vector2(at.x - TableView.BOARD_CENTER.x, at.y - TableView.BOARD_CENTER.y) / radius, dart.pierced)
	if hit_board:
		_board_shake = 1.0
		BurstFx.spawn(self, "cork", at, table.board.global_basis.z)
		Sfx.play_at(self, "thunk", at, 0.0, randf_range(0.92, 1.08))
	else:
		Sfx.play_at(self, "bounce", at, -4.0)


func _clear_darts() -> void:
	_flying_darts.clear()
	for child in _darts.get_children():
		_darts.remove_child(child)
		child.queue_free()
	# 과녁 조각에 붙여 둔 다트(BoardView.pin)도 함께 지운다.
	table.board.clear_pins()


## 다트 머신 모양(회전·분리·셔터)을 과녁과 머신 그림에 옮긴다. 모든 화면에서 매 프레임.
## 효과가 걸린 동안은 방장 모양(MatchController.chaos_shape)을 그대로 쓰고 — 꽂힌 자리 판정과 같아야 한다 —
## 효과가 끝나면 제자리로 부드럽게 돌아간다(차례가 바뀔 때 판이 덜컥 튀지 않게).
func _show_chaos(delta: float) -> void:
	var target: Dictionary = controller.chaos_shape()
	var active: bool = absf(float(target.angle)) > 0.0 or float(target.split) > 0.0 or float(target.shutter) > 0.0 or float(target.get("vertical", 0)) > 0 or float(target.get("horizontal", 0)) > 0 or Vector2(target.get("move", Vector2.ZERO)).length() > 0 or not is_equal_approx(float(target.get("scale", 1.0)), 1.0)
	if active or _shown_chaos.is_empty() or controller.state.phase in [MatchState.Phase.AIMING, MatchState.Phase.FLIGHT]:
		_shown_chaos = target.duplicate()
	else:
		var weight: float = 1.0 - exp(-CHAOS_SETTLE_RATE * delta)
		_shown_chaos.angle = lerp_angle(float(_shown_chaos.angle), 0.0, weight)
		_shown_chaos.split = lerpf(float(_shown_chaos.split), 0.0, weight)
		_shown_chaos.shutter = lerpf(float(_shown_chaos.shutter), 0.0, weight)
		_shown_chaos.cover = false
		_shown_chaos.vertical = lerpf(float(_shown_chaos.get("vertical", 0)), 0, weight)
		_shown_chaos.horizontal = lerpf(float(_shown_chaos.get("horizontal", 0)), 0, weight)
		_shown_chaos.move = Vector2(_shown_chaos.get("move", Vector2.ZERO)).lerp(Vector2.ZERO, weight)
		_shown_chaos.scale = lerpf(float(_shown_chaos.get("scale", 1.0)), 1.0, weight)
		# 턴 종료 때 타일 사이 간격과 후면 보조판도 같은 속도로 접는다.
		_shown_chaos["petal"] = lerpf(float(_shown_chaos.get("petal", 0.0)), 0.0, weight)
		_shown_chaos["insert"] = lerpf(float(_shown_chaos.get("insert", 0.0)), 0.0, weight)
	table.board.show_chaos(_shown_chaos)
	if table.machine != null:
		table.machine.show_chaos(_shown_chaos, delta)


## 방장이 한 발을 확정한다. 과녁까지 가는 길에 사람 몸이 있으면 거기서 멈춘다(몸으로 막기 — 0점 + 맞은 사람 스턴).
## pierce = 관통 다트 카드(2026-11-21): 몸을 뚫고 지나간다(막는 사람을 세지 않는다).
func solve_dart(aim: Vector2, charge: float, peer_id: int = 0, speed_multiplier: float = 1.0, pierce: bool = false) -> Dictionary:
	var config := throw_input.config
	var thrower_id: int = peer_id if peer_id != 0 else controller.local_peer_id
	var actor: PlayerView = actors[thrower_id] as PlayerView
	var start: Vector3 = actor.eye_position()
	var bodies: Array = [] if pierce else _dart_bodies(thrower_id)
	var radius: float = BoardLayout.RADIUS * TableView.BOARD_SCALE
	var aim_target := TableView.BOARD_CENTER + Vector3(aim.x * radius, aim.y * radius, 0)
	var speed: float = lerpf(config.minimum_speed, config.maximum_speed, charge) * speed_multiplier
	var direction: Vector3 = (aim_target - start).normalized()
	var nominal_time: float = start.distance_to(aim_target) / config.maximum_speed
	if controller.cards != null and bool(controller.cards.modifiers(thrower_id).get("repeat", false)) and controller.cards.last_landing.is_finite():
		nominal_time = start.distance_to(aim_target) / speed
	var initial: Vector3 = direction * speed + Vector3.UP * config.gravity * nominal_time * 0.5
	var board_time: float = (TableView.BOARD_CENTER.z - start.z) / initial.z
	var infill_time: float = board_time + BoardChaos.INFILL_FRONT / initial.z
	var previous: Vector3 = start
	var previous_time: float = 0
	var step: float = 1.0 / 120.0
	while previous_time < config.flight_limit:
		var time: float = minf(previous_time + step, config.flight_limit)
		var crosses_board: bool = board_time > previous_time and board_time <= time
		var crosses_infill := not crosses_board and infill_time > previous_time and infill_time <= time
		if crosses_board:
			time = board_time
		elif crosses_infill:
			time = infill_time
		var point: Vector3 = config.position_at(start, initial, time)
		# 몸이 먼저다: 벽보다 앞에 있는 사람에게 맞으면 거기서 끝난다.
		var body: Dictionary = BodyHit.first(previous, point, bodies)
		if not body.is_empty():
			var victim: MatchPlayer = bodies[int(body.index)].player
			return _flight_result(start, body.point, maxf(lerpf(previous_time, time, float(body.ratio)), 0.02),
				Vector2.INF, 0, "%s 몸에 맞음!" % victim.display_name, victim.peer_id)
		var query := PhysicsRayQueryParameters3D.create(previous, point, 1)
		var collision: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if not collision.is_empty():
			var ratio: float = previous.distance_to(collision.position) / maxf(previous.distance_to(point), 0.0001)
			var hit_time: float = lerpf(previous_time, time, ratio)
			var reason: String = "바닥 · 실패" if collision.normal.y > 0.5 else "벽 · 실패"
			return _flight_result(start, collision.position, maxf(hit_time, 0.01), Vector2.INF, 0, reason)
		if crosses_board or crosses_infill:
			var hit := Vector2(point.x - TableView.BOARD_CENTER.x, point.y - TableView.BOARD_CENTER.y) / radius
			var shape: Dictionary = controller.cards.shape_now(time) if controller.cards != null and controller.state.active_player() != null else BoardChaos.rest()
			if crosses_board:
				var guarded := not pierce and BoardChaos.covered(hit, shape)
				shape.cover = false
				var on_tile := BoardChaos.locate(hit, shape, BoardView.BoardArt.BACKING_RATIO).is_finite()
				if guarded or on_tile:
					var points: int = 0 if guarded else BoardChaos.score(hit, shape, actor.identity.layout)
					return _flight_result(start, point, time, hit, points, "%d점 적중" % points)
			elif BoardChaos.on_infill(hit, shape):
				var stop := _flight_result(start, point, time, hit, 0, "보조판 · 0점")
				stop["infill_hit"] = true
				return stop
		previous = point
		previous_time = time
	return _flight_result(start, previous, config.flight_limit, Vector2.INF, 0, "비행 제한시간 · 실패")


## 튕겨 나온 두 구간을 실제 그리는 포물선 위에서 검사한다. 관통 카드도 벽·바닥에는 막힌다.
func _rebound_contact(start: Vector3, end: Vector3, duration: float, peer: int, pierce: bool) -> Dictionary:
	var config := throw_input.config
	var velocity := config.initial_velocity(start, end, duration)
	var bodies: Array = [] if pierce else _dart_bodies(peer)
	var previous := start
	var time := 0.0
	while time < duration:
		var next := minf(time + 1.0 / 120.0, duration)
		var point := config.position_at(start, velocity, next)
		var body := BodyHit.first(previous, point, bodies)
		var ray := PhysicsRayQueryParameters3D.create(previous, point, 1)
		var wall := get_world_3d().direct_space_state.intersect_ray(ray)
		var wall_ratio := INF
		if not wall.is_empty(): wall_ratio = previous.distance_to(wall.position) / maxf(previous.distance_to(point), 0.00001)
		if not body.is_empty() and float(body.ratio) <= wall_ratio:
			var victim: MatchPlayer = bodies[int(body.index)].player
			return _flight_result(start, body.point, maxf(0.001, lerpf(time, next, body.ratio)), Vector2.INF, 0, "몸에 맞음", victim.peer_id)
		if not wall.is_empty():
			return _flight_result(start, wall.position, maxf(0.001, lerpf(time, next, wall_ratio)), Vector2.INF, 0, "벽에 맞음")
		time = next
		previous = point
	return {}


## 투척선 앞 다트 홀에 선 사람들. 펜스 제거 후 앞 공간 전체에서 실제 몸과 교차하면 막힌다.
## 투척선 뒤 던지는 칸에는 여럿이 몰려 서기 때문에(차례를 기다리거나 구경하거나) 거기까지 세면
## 대기 인원이 발사를 막지 않도록 투척선 뒤는 제외한다.
func _dart_bodies(thrower_id: int) -> Array:
	var bodies: Array = []
	for id: int in actors:
		var other := actors[id] as PlayerView
		if id == thrower_id or not other.visible or other.identity == null or other.seated:
			continue
		if TableView.in_block_zone(other.global_position):
			bodies.append({"player": other.identity, "position": other.global_position})
	return bodies


## victim = 몸에 맞은 사람의 peer ID(0 = 사람에게 안 맞음). 스냅샷으로 모든 화면이 같은 값을 본다.
func _flight_result(start: Vector3, target: Vector3, duration: float, hit: Vector2, points: int, reason: String,
		victim: int = 0) -> Dictionary:
	# 실패의 무한 좌표는 네트워크/JSON에 넣지 않는다.
	return {"start": start, "target": target, "duration": duration, "x": hit.x if hit.is_finite() else 99.0,
		"y": hit.y if hit.is_finite() else 99.0, "points": points, "base": points, "reason": reason, "victim": victim}


func sync_room(room: RoomState) -> void:
	if controller.card_test_active and not can_start_card_test():
		stop_card_test()
	controller.room_settings = room.settings
	if room.settings.social_lobby:
		controller.config.rounds = room.settings.rounds
		controller.config.turn_seconds = room.settings.dart_seconds
	controller.sync_roster(room)
	# 방 인원수만큼만 의자·매트를 깐다(2인 방 = 마주 보는 두 자리). 사람이 들고 나도 빈자리는 남는다.
	# 2026-11-08: 깔린 자리 수만큼 원형 테이블을 똑같이 나눈 자리로 옮긴다(3인 = 120도씩). 앉기·봇 자리·카드 매트가 모두 이 배치를 본다.
	# 배우(PlayerView)를 만들기 전에 정해야 봇이 처음부터 새 자리에 앉는다.
	var seats: Array[int] = room.shown_seats()
	TableView.arrange_seats(seats)
	table.show_seats(seats)
	# 대기실에서 인원수가 바뀌면 이미 앉아 있던 사람·봇도 옮겨진 의자로 같이 옮겨 앉는다.
	for view: PlayerView in actors.values():
		if view.seated and view.identity != null:
			view.position = TableView.seat_spot(view.identity.seat)
	if room.phase == RoomState.Phase.LOBBY:
		for player in controller.state.players:
			if actors.has(player.peer_id): continue
			var view := PLAYER_SCENE.instantiate() as PlayerView
			_players_root.add_child(view)
			view.configure(player, 0.0, false, _bots_waiting_in_lobby())
			actors[player.peer_id] = view
	_apply_state()
	if lounge != null: lounge.apply_theme()
