extends RefCounted
## 사람(내 자리) 조작: 키보드·마우스 → 카드 행동·걷기·앉기·시선·설정 창·빨리 감기, 그리고 지금 던질 수 있는지(투척 입력 켜기).
## autoplay(자동 검사·캡처) 때는 카드·이동 키를 받지 않는다(Esc·C 는 받는다).
##
## 키: 1~7(넘패드 포함) 꺼내 들기 · 8·9 보상 카드 · F 쓰기 · Tab 대상 바꾸기 · WASD 이동 · Space 점프 · Ctrl 숙이기
##     E 앉기/일어나기 · V 말하기 · C 전체 보기 · Esc 설정 · Shift(누르는 동안) 3배 빨리 · Alt(누르는 동안) 마우스 꺼내기
##     왼클릭 길게 → 놓기 = 던지기(DartThrowController), 오른클릭 = 충전 취소

const Context = preload("res://game/card_round/flow/round_context.gd")
const CardActions = preload("res://game/card_round/flow/card_actions.gd")
const SeatMover = preload("res://game/card_round/flow/seat_mover.gd")
const RoundCamera = preload("res://game/card_round/flow/round_camera.gd")
const DartActions = preload("res://game/card_round/flow/dart_actions.gd")
const Hud = preload("res://game/card_round/ui/card_round_hud.gd")

## 빨리 감기 배수(Shift).
const FAST_FORWARD: float = 3.0
## 자기 자리에서 이만큼 가까워야 E 로 앉을 수 있다(m).
const SIT_DISTANCE: float = 1.0

var _ctx: Context
var _cards: CardActions
var _mover: SeatMover
var _view: RoundCamera
var _darts: DartActions
var _throw_input: DartThrowController
var _hand: Node3D
var _jump: bool = false
var _alt_freed: bool = false


## 감독이 시작할 때 한 번: 키 입력이 움직일 부품과 투척 입력·손 노드를 받는다.
func setup(ctx: Context, cards: CardActions, mover: SeatMover, view: RoundCamera, darts: DartActions, throw_input: DartThrowController, hand: Node3D) -> void:
	_ctx = ctx
	_cards = cards
	_mover = mover
	_view = view
	_darts = darts
	_throw_input = throw_input
	_hand = hand


## 감독의 _unhandled_input 에서 그대로 넘겨받는다.
func handle(event: InputEvent) -> void:
	# 화면 캡처 검사(--render) 중에는 키·마우스를 전부 무시한다(2026-10-28).
	# 창이 뜨며 포커스를 가져가 Esc → Enter 같은 키가 들어가면 설정 창 "새 게임"이 눌려 장면이 다시 시작되던 문제.
	if _ctx.capturing:
		return
	var hud: Hud = _ctx.hud
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# 창을 클릭하면 마우스를 다시 잡는다(시선 조작).
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not hud.settings_open and _ctx.phase != "results" and not _ctx.autoplay:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			_ctx.root.get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _ctx.autoplay:
		_view.turn(event.relative)
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: Key = (event as InputEventKey).keycode
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
		KEY_V:
			_ctx.voice.say(Context.LOCAL_SEAT, "talk")
		KEY_E:
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
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _ctx.hud.settings_open and not _mover.stunned(Context.LOCAL_SEAT):
		axis = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))).limit_length()
		crouch = Input.is_physical_key_pressed(KEY_CTRL)
	if actor.seated and axis != Vector2.ZERO and _ctx.phase != "cards":
		_mover.stand(Context.LOCAL_SEAT)
	actor.simulate(delta, {"move": axis, "yaw": _view.yaw if not actor.seated else actor.rotation.y, "pitch": _view.pitch, "jump": _jump, "crouch": crouch})
	_jump = false


## 매 프레임: Shift 빨리 감기와 Alt 마우스 꺼내기(라운드 표시에 마우스를 올려 설명 보기).
func update() -> void:
	if _ctx.autoplay:
		return
	Engine.time_scale = _ctx.settings.base_speed(false, _ctx.capturing) * (FAST_FORWARD if Input.is_key_pressed(KEY_SHIFT) and not _ctx.hud.settings_open else 1.0)
	if _ctx.hud.settings_open or _ctx.phase == "results":
		return
	var alt: bool = Input.is_key_pressed(KEY_ALT)
	if alt and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_alt_freed = true
	elif not alt and _alt_freed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_alt_freed = false


## 지금 내가 던질 차례인가(다트 차례, 또는 벌칙 원판 차례).
func my_throw() -> bool:
	if _ctx.autoplay:
		return false
	if _ctx.phase == "darts":
		return _ctx.rules.is_turn_of(Context.LOCAL_SEAT)
	return _ctx.phase == "punish" and _darts.punish_seat == Context.LOCAL_SEAT and _darts.punish_left > 0


## 매 프레임: 던질 수 있을 때만 투척 입력·손에 든 다트·조준 자세·조준 표시를 켠다(서 있어야 하고, 날아가는 다트가 없어야 한다).
func update_throw_state() -> void:
	var enabled: bool = my_throw() and not _darts.busy and not _ctx.actors[Context.LOCAL_SEAT].seated \
		and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _view.overview
	_throw_input.enabled = enabled
	_hand.visible = enabled
	var actor: PlayerView = _ctx.actors[Context.LOCAL_SEAT]
	actor.aiming = enabled or actor.aiming and _ctx.autoplay
	_ctx.hud.set_aim(enabled, _throw_input.timing)


## E: 앉아 있으면 일어나고(카드 단계에는 못 일어난다), 자리 가까이 서 있으면 앉는다.
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
