extends RefCounted
## 사람(내 자리) 조작: 키보드·마우스 → 카드 행동·걷기·앉기·시선·설정 창·빨리 감기, 그리고 지금 던질 수 있는지(투척 입력 켜기).
## autoplay(자동 검사·캡처) 때는 카드·이동 키를 받지 않는다(Esc·C 는 받는다).
##
## 키: Q·E 카드 넘기기 · 1~7(넘패드 포함) 꺼내 들기 · 8·9 보상 카드 · F 쓰기 · Tab 대상 바꾸기 · WASD 이동 · Space 점프 · Ctrl 숙이기
##     R 앉기/일어나기 · V 말하기 · C 전체 보기 · Esc 설정 · Shift(누르는 동안) 3배 빨리
##     T 감정표현 피자판(ui/emote_wheel.gd) · 왼클릭 = 손가락으로 가리키기(flow/gestures.gd)
##     내 던질 차례: 왼클릭 길게 → 놓기 = 던지기(DartThrowController 가 먼저 가져간다), 오른클릭 = 충전 취소
## 2026-10-28 피드백: E 는 카드 넘기기로 쓰고 앉기는 R 로 옮겼다. Alt 마우스 꺼내기는 없앴다 → 마우스 포인터는 T(피자판)·Esc(설정) 때만 보인다.

const Context = preload("res://game/card_round/flow/round_context.gd")
const CardActions = preload("res://game/card_round/flow/card_actions.gd")
const SeatMover = preload("res://game/card_round/flow/seat_mover.gd")
const RoundCamera = preload("res://game/card_round/flow/round_camera.gd")
const DartActions = preload("res://game/card_round/flow/dart_actions.gd")
const Hud = preload("res://game/card_round/ui/card_round_hud.gd")
const ThrowZone = preload("res://game/card_round/flow/throw_zone.gd")
const Gestures = preload("res://game/card_round/flow/gestures.gd")
const EmoteWheel = preload("res://game/card_round/ui/emote_wheel.gd")

## 빨리 감기 배수(Shift).
const FAST_FORWARD: float = 3.0
## 자기 자리에서 이만큼 가까워야 R 로 앉을 수 있다(m).
const SIT_DISTANCE: float = 1.0

var _ctx: Context
var _cards: CardActions
var _mover: SeatMover
var _view: RoundCamera
var _darts: DartActions
var _throw_input: DartThrowController
var _hand: Node3D
var _gestures: Gestures
var _wheel: EmoteWheel
var _jump: bool = false


## 감독이 시작할 때 한 번: 키 입력이 움직일 부품과 투척 입력·손 노드·몸짓·피자판을 받는다.
func setup(ctx: Context, cards: CardActions, mover: SeatMover, view: RoundCamera, darts: DartActions, throw_input: DartThrowController, hand: Node3D,
		gestures: Gestures, wheel: EmoteWheel) -> void:
	_ctx = ctx
	_cards = cards
	_mover = mover
	_view = view
	_darts = darts
	_throw_input = throw_input
	_hand = hand
	_gestures = gestures
	_wheel = wheel
	_wheel.closed.connect(_capture_mouse)


## 감독의 _unhandled_input 에서 그대로 넘겨받는다.
func handle(event: InputEvent) -> void:
	# 화면 캡처 검사(--render) 중에는 키·마우스를 전부 무시한다(2026-10-28).
	# 창이 뜨며 포커스를 가져가 Esc → Enter 같은 키가 들어가면 설정 창 "새 게임"이 눌려 장면이 다시 시작되던 문제.
	if _ctx.capturing:
		return
	var hud: Hud = _ctx.hud
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _wheel.is_open:
			# 피자판이 열려 있으면 왼클릭 = 밝은 칸 보내기.
			_wheel.pick()
		elif Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			# 창 밖에 나갔다 돌아와 클릭하면 마우스를 다시 잡는다(시선 조작).
			_capture_mouse()
		elif not hud.settings_open and not _ctx.autoplay:
			# 왼클릭 = 손가락으로 가리키기. 내 던질 차례에 던질 수 있으면 투척 입력이 먼저 가져가서 여기 오지 않는다.
			_gestures.point(Context.LOCAL_SEAT)
		_ctx.root.get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _ctx.autoplay:
		_view.turn(event.relative)
		return
	if event is InputEventKey and not event.pressed and (event as InputEventKey).keycode == KEY_T:
		_wheel.release_key()
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: Key = (event as InputEventKey).keycode
	if key == KEY_ESCAPE and _wheel.is_open:
		_wheel.close()
		return
	if key == KEY_T:
		_open_wheel()
		return
	if key == KEY_ESCAPE:
		hud.toggle_settings(not hud.settings_open)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if hud.settings_open else Input.MOUSE_MODE_CAPTURED
		return
	if key == KEY_C:
		_view.overview = not _view.overview
		return
	if _ctx.autoplay or hud.settings_open:
		return
	var slot: int = slot_for_key(key)
	if slot >= 0:
		_cards.press_slot(Context.LOCAL_SEAT, slot)
	match key:
		KEY_F:
			_cards.use(Context.LOCAL_SEAT, int(_cards.target_choice.get(Context.LOCAL_SEAT, -1)))
		KEY_TAB:
			_cards.cycle_target()
		KEY_Q:
			_cards.browse(Context.LOCAL_SEAT, -1)
		KEY_E:
			_cards.browse(Context.LOCAL_SEAT, 1)
		KEY_V:
			_ctx.voice.say(Context.LOCAL_SEAT, "talk")
		KEY_R:
			_toggle_sit()
		KEY_SPACE:
			_jump = true


## 숫자 키 → 칸 번호(1 = 0번 칸). 1~7 = 테이블 7칸, 8·9 = 방해 보상 칸. 아니면 -1.
static func slot_for_key(key: Key) -> int:
	if key >= KEY_1 and key <= KEY_9:
		return key - KEY_1
	if key >= KEY_KP_1 and key <= KEY_KP_9:
		return key - KEY_KP_1
	return -1


## 물리 프레임마다: WASD 로 내 캐릭터를 움직인다(카드 단계에는 앉은 채, 다트 단계에 움직이면 자동으로 일어난다).
func drive_local(delta: float) -> void:
	var actor: PlayerView = _ctx.actors[Context.LOCAL_SEAT]
	var axis := Vector2.ZERO
	var crouch: bool = false
	# 피자판이 열려 있어도(마우스가 보여도) 걸을 수는 있다.
	if (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or _wheel.is_open) and not _ctx.hud.settings_open and not _mover.stunned(Context.LOCAL_SEAT):
		axis = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))).limit_length()
		crouch = Input.is_physical_key_pressed(KEY_CTRL)
	if actor.seated and axis != Vector2.ZERO and _ctx.phase != "cards":
		_mover.stand(Context.LOCAL_SEAT)
	actor.simulate(delta, {"move": axis, "yaw": _view.yaw if not actor.seated else actor.rotation.y, "pitch": _view.pitch, "jump": _jump, "crouch": crouch})
	_jump = false


## 매 프레임: Shift(누르는 동안) 빨리 감기.
func update() -> void:
	if _ctx.autoplay:
		return
	Engine.time_scale = _ctx.settings.base_speed(false, _ctx.capturing) * (FAST_FORWARD if Input.is_key_pressed(KEY_SHIFT) and not _ctx.hud.settings_open else 1.0)


## 지금 내가 던질 차례인가(다트 차례, 또는 벌칙 원판 차례).
func my_throw() -> bool:
	if _ctx.autoplay:
		return false
	if _ctx.phase == "darts":
		return _ctx.rules.is_turn_of(Context.LOCAL_SEAT)
	return _ctx.phase == "punish" and _darts.punish_seat == Context.LOCAL_SEAT and _darts.punish_left > 0


## 내가 던지는 칸(throw_zone.gd, 바닥 금색 칸) 안에 서 있는가.
func in_throw_box() -> bool:
	return ThrowZone.in_throw_box(_ctx.actors[Context.LOCAL_SEAT].position)


## 지금 던지려고 충전 중인가(왼클릭을 누르고 있다) — 막는 봇이 보고 점프한다(disruption.gd).
func charging() -> bool:
	return _throw_input.enabled and _throw_input.charging


## 매 프레임: 던질 수 있을 때만 투척 입력·손에 든 다트·조준 자세·조준 표시를 켠다
## (서 있어야 하고, 던지는 칸 안이어야 하고, 날아가는 다트가 없어야 한다).
func update_throw_state() -> void:
	var enabled: bool = my_throw() and not _darts.busy and not _ctx.actors[Context.LOCAL_SEAT].seated and in_throw_box() \
		and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _view.overview
	_throw_input.enabled = enabled
	_hand.visible = enabled
	var actor: PlayerView = _ctx.actors[Context.LOCAL_SEAT]
	actor.aiming = enabled or actor.aiming and _ctx.autoplay
	_ctx.hud.set_aim(enabled, _throw_input.timing)


## T: 감정표현 피자판을 연다 — 이때만 마우스 포인터가 보이고 화면 가운데로 옮겨진다(방향으로 고르기 쉽게).
func _open_wheel() -> void:
	if _wheel.is_open or _ctx.autoplay or _ctx.hud.settings_open or _ctx.phase == "results":
		return
	_wheel.open()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var viewport: Viewport = _ctx.root.get_viewport()
	viewport.warp_mouse(viewport.get_visible_rect().size * 0.5)


## 마우스를 다시 잡는다(포인터 숨김 + 시선 조작). 설정 창·결과 화면·자동 진행 중에는 그대로 둔다.
func _capture_mouse() -> void:
	if _ctx.hud.settings_open or _ctx.phase == "results" or _ctx.autoplay or _wheel.is_open:
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## R: 앉아 있으면 일어나고(카드 단계에는 못 일어난다), 자리 가까이 서 있으면 앉는다.
func _toggle_sit() -> void:
	var actor: PlayerView = _ctx.actors[Context.LOCAL_SEAT]
	if actor.seated:
		if _ctx.phase != "cards":
			_mover.stand(Context.LOCAL_SEAT)
			_view.yaw = actor.rotation.y
	elif actor.position.distance_to(TableView.SEATS[Context.LOCAL_SEAT]) < SIT_DISTANCE:
		_mover.sit(Context.LOCAL_SEAT)
	else:
		_ctx.hud.toast("자기 자리(테이블 뒤쪽 ▲) 가까이에서 앉을 수 있다", PubTheme.PAPER, 1.6)
