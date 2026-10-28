extends Node3D
## 카드 라운드 시연(F6 단독 실행) — 감독. 사용자 기획(2026-10-28) 흐름을 실제 펍에서 끝까지 돌려 보고 어색한지 확인하는 장면이다.
## 네트워크·F5 경기(MatchController)와는 따로다.
##
## 이 파일은 "무엇을 어떤 순서로 하나"(단계 순서)만 갖고, 실제 일은 부품이 한다(한 파일 = 한 가지 일).
##   rules/  규칙 계산(노드 없음)  round_rules · card_catalog · bot_brain · dart_solver
##   cards/  카드 보이기          card_faces · card_view · table_cards · hand_fan · shuffle_motions
##   fx/     연출                 screen_debuff · voice_fx · stun_stars · punishment_wheel
##   ui/     화면 UI              card_round_hud · round_tracker
##   flow/   진행 부품            round_context(함께 쓰는 상자) · round_settings · seat_mover · card_actions · dart_actions
##                                turn_effects · disruption · round_camera · local_input · hud_presenter · round_capture · player_builder
##
## 흐름: 흐트러진 덱 → 자동 섞기(정석 리플·마술사·딜러) → 가지런한 덱 → 한 사람에 한 장씩 7장까지 → 앞면 공개 →
##       왼손 7장 = 테이블 7칸 → 1~7 꺼내 들기(대기) → 다른 사람이 보고 대응(무효 ×0·방해) → 다트 라운드 →
##       충전 라운드(자동 착석·점수 발표·쓴 만큼만 7장까지) → … → 끝: 꼴찌는 돌아가는 원판, 나머지는 던지기 → 골드.
## 내 자리 = 2번(바가지, 테이블 뒤쪽 · 과녁이 정면). autoplay 면 내 자리도 봇이 움직인다(자동 검사·화면 캡처용).
##
## 에디터에서 이 장면을 열면 펍·테이블(Table 노드)만 보인다. 카드·캐릭터·HUD 는 실행(F6)하면 코드가 만든다.

const Context = preload("res://game/card_round/flow/round_context.gd")
const RoundSettings = preload("res://game/card_round/flow/round_settings.gd")
const SeatMover = preload("res://game/card_round/flow/seat_mover.gd")
const CardActions = preload("res://game/card_round/flow/card_actions.gd")
const DartActions = preload("res://game/card_round/flow/dart_actions.gd")
const TurnEffects = preload("res://game/card_round/flow/turn_effects.gd")
const Disruption = preload("res://game/card_round/flow/disruption.gd")
const RoundCamera = preload("res://game/card_round/flow/round_camera.gd")
const LocalInput = preload("res://game/card_round/flow/local_input.gd")
const HudPresenter = preload("res://game/card_round/flow/hud_presenter.gd")
const RoundCapture = preload("res://game/card_round/flow/round_capture.gd")
const PlayerBuilder = preload("res://game/card_round/flow/player_builder.gd")
const Rules = preload("res://game/card_round/rules/round_rules.gd")
const CardFaces = preload("res://game/card_round/cards/card_faces.gd")
const ShuffleMotions = preload("res://game/card_round/cards/shuffle_motions.gd")
const TableCards = preload("res://game/card_round/cards/table_cards.gd")
const ScreenDebuff = preload("res://game/card_round/fx/screen_debuff.gd")
const VoiceFx = preload("res://game/card_round/fx/voice_fx.gd")
const PunishmentWheel = preload("res://game/card_round/fx/punishment_wheel.gd")
const Hud = preload("res://game/card_round/ui/card_round_hud.gd")
const RoundTracker = preload("res://game/card_round/ui/round_tracker.gd")
const BotDriver = preload("res://game/player/bot_driver.gd")
const CharacterFactory = preload("res://art/characters/character_factory.gd")
const SynthAudio = preload("res://art/showcase/synth_audio.gd")

## 아래 값은 전부 시연값(팀 확정 전).
## 딜링 한 장 간격(초), 카드 확인 시간(초), 사람 차례 제한 시간(초).
const DEAL_GAP: float = 0.14
const CHECK_SECONDS: float = 4.0
const TURN_SECONDS: float = 30.0
## 봇이 막는 사람이 있어도 비키지 않고 그냥 던질 확률.
const THROW_THROUGH_CHANCE: float = 0.6
## 끝 라운드가 없는 모드(목표 점수·500→0)도 시연은 이 라운드에서 점수 순으로 끝낸다.
const MAX_ROUNDS: int = 10
## 설정 "뽑는 곳" 이름(Rules.DrawFrom 순서).
const DRAW_NAMES: Array[String] = ["맨 위", "가운데", "맨 아래", "무작위 위치"]

## true = 내 자리도 봇처럼 자동(검사·캡처). F6 으로 직접 할 때는 false.
@export var autoplay: bool = false
## false = 설정 파일(user://)에 읽고 쓰지 않는다(검사가 사용자 저장을 덮어쓰지 않게).
@export var persist_settings: bool = true
## 비어 있지 않으면 주요 장면을 이 폴더에 PNG 로 저장한다(화면이 있을 때만, round_capture.gd).
@export var capture_folder: String = ""
## autoplay 때 몇 라운드까지 할지(검사 시간을 줄인다).
@export var autoplay_rounds: int = 2

## 이번 실행 동안 모은 골드(자리별). "한 판 더"로 다시 시작해도 유지된다(상점은 아직 없다).
static var session_gold: Array[int] = [0, 0, 0, 0]

## 자동 검사가 읽는 값 — 함께 쓰는 상자(ctx)의 것을 그대로 보여 준다.
var game_over: bool:
	get:
		return ctx.game_over
var stats: Dictionary:
	get:
		return ctx.stats

var ctx := Context.new()
var settings := RoundSettings.new()
var mover := SeatMover.new()
var cards := CardActions.new()
var darts := DartActions.new()
var effects := TurnEffects.new()
var disruption := Disruption.new()
var view := RoundCamera.new()
var input := LocalInput.new()
var presenter := HudPresenter.new()
var capture := RoundCapture.new()

@onready var _throw_input: DartThrowController = $ThrowController
@onready var _hand: Node3D = $Camera/Hand


## 장면이 만들어진 직후(트리에 들어가기 전): 펍 생성물의 "카드 뒷면 자리표시"를 지운다.
## TableView._ready 가 메시를 하나로 묶기(StaticBatch) 전에 지워야 하므로 _ready 보다 먼저인 이 알림에서 한다.
## 에디터에서 장면을 열 때는 스크립트가 돌지 않으므로 자리표시가 보인다(미리보기로 충분).
func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_strip_placeholder_cards(get_node("Table"))


func _ready() -> void:
	settings.persist = persist_settings
	settings.load_file()
	_fill_context()
	_setup_parts()
	_throw_input.camera = ctx.camera
	_throw_input.board = ctx.table.board
	_throw_input.throw_requested.connect(darts.on_local_throw)
	_hand.add_child(CharacterFactory.create_hand(Context.LOCAL_SEAT))
	($Camera/Hand/HeldDart as DartView).paint(PlayerLook.COLORS[Context.LOCAL_SEAT])
	_hand.visible = false
	effects.build_props()
	Engine.time_scale = settings.base_speed(autoplay, ctx.capturing)
	if DisplayServer.get_name() != "headless" and not autoplay:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_run()


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## 함께 쓰는 상자(ctx)를 채운다: 장면 노드·규칙·HUD·연출 노드.
func _fill_context() -> void:
	ctx.root = self
	ctx.autoplay = autoplay
	ctx.capturing = not capture_folder.is_empty()
	ctx.settings = settings
	ctx.random.randomize()
	ctx.camera = $Camera
	ctx.darts_root = $Darts
	ctx.table = $Table
	ctx.local_fan = $Camera/Fan
	var names: Array[String] = []
	var bots: Array[bool] = []
	for seat in range(Context.SEAT_COUNT):
		names.append(PlayerLook.CHARACTER_NAMES[seat])
		bots.append(ctx.bot_driven(seat))
	ctx.rules = Rules.new(names, bots, settings.win_mode())
	ctx.rules.reward_mode = settings.reward_mode()
	if autoplay:
		ctx.rules.round_limit = autoplay_rounds
	ctx.hud = Hud.new()
	add_child(ctx.hud)
	ctx.hud.set_settings(settings.values)
	ctx.hud.setting_changed.connect(_on_setting_changed)
	ctx.hud.restart_requested.connect(_restart)
	ctx.debuff = ScreenDebuff.new()
	add_child(ctx.debuff)
	ctx.voice = VoiceFx.new()
	add_child(ctx.voice)
	ctx.voice.muted = settings.voice_muted()
	ctx.audio = SynthAudio.new()
	ctx.audio.volume_db = -8.0
	add_child(ctx.audio)


## 부품을 준비하고 서로 잇는다. 부품끼리는 신호로만 알린다(누가 듣는지는 여기 한 곳에서 보인다).
func _setup_parts() -> void:
	mover.setup(ctx)
	effects.setup(ctx)
	cards.setup(ctx, mover)
	darts.setup(ctx, effects)
	disruption.setup(ctx, mover, cards, effects)
	view.setup(ctx)
	input.setup(ctx, cards, mover, view, darts, _throw_input, _hand)
	presenter.setup(ctx, mover, cards, effects, darts, input)
	capture.setup(ctx, view, capture_folder)
	mover.local_seated.connect(view.face_table)
	cards.turn_effect_added.connect(effects.apply)
	cards.card_marked.connect(capture.on_card_marked)
	cards.nullified.connect(capture.on_nullified)
	darts.score_changed.connect(presenter.refresh_labels)
	darts.body_hit.connect(disruption.on_body_hit)
	darts.wheel_body_hit.connect(capture.on_wheel_body_hit)
	disruption.hit_resolved.connect(func(thrower: int, victim: int) -> void:
		presenter.refresh_labels()
		capture.on_body_hit(thrower, victim))


# --- 전체 진행 ---

## 처음부터 끝까지: 준비 → (카드 단계 → 다트 단계 → 라운드 정리) 반복 → 엔딩.
func _run() -> void:
	# 카드 그림을 먼저 굽는다(카드를 하나라도 만들기 전에 — CardView 가 뒷면 그림을 처음 만들 때 캐시한다).
	await CardFaces.bake(self)
	ctx.table_cards = TableCards.new()
	ctx.table_cards.name = "TableCards"
	add_child(ctx.table_cards)
	ctx.table_cards.setup(Context.SEAT_COUNT)
	ctx.rules.fill_deck()
	ctx.table_cards.scatter(ctx.rules.deck.size())
	PlayerBuilder.build(ctx, $Players, mover, presenter)
	ctx.voice.setup(ctx.actors)
	view.face_table()
	ctx.hud.set_round(1, RoundTracker.Stage.CARDS, _total_rounds())
	ctx.hud.set_turn("테이블 가운데 흐트러진 덱")
	await ctx.wait(0.6)
	await capture.shot("01_scattered_deck")
	await ctx.hud.banner("DARTY 카드 라운드 시연", "흐트러진 덱 → 섞기 → 한 장씩 7장 → 다트. 수치는 전부 시연값이다.", 2.0)
	while true:
		await _card_stage()
		await _dart_stage()
		_finish_round()
		ctx.stats.rounds = ctx.rules.round_number
		if ctx.rules.finished:
			break
		if ctx.rules.round_number >= MAX_ROUNDS:
			var best: Array[int] = [ctx.rules.ranking()[0]]
			ctx.rules.finished = true
			ctx.rules.winners = best
			ctx.hud.toast("시연 제한 %d라운드 → 점수 순으로 끝" % MAX_ROUNDS, PubTheme.GOLD)
			break
		ctx.rules.next_round()
		capture.before_next_round()
	await _ending()


## 카드 단계(1라운드 = 처음 나눠 주기, 그 뒤 = 충전 라운드):
## 모이기(자동 착석) → 점수 발표 → 덱 보충·섞기 → 한 장씩 → 공개 → 왼손 맞추기 → 7장 확인 → 카드 확인 시간.
func _card_stage() -> void:
	var rules: Rules = ctx.rules
	ctx.phase = "cards"
	ctx.cards_open = false
	var first: bool = rules.round_number == 1
	ctx.hud.set_round(rules.round_number, RoundTracker.Stage.CARDS, _total_rounds())
	ctx.hud.set_turn("모두 테이블로")
	await mover.gather()
	if not first:
		await ctx.hud.announce_scores("%d라운드 끝 · 점수 발표" % (rules.round_number - 1), presenter.ranking_rows())
	var missing: int = 0
	for seat in range(Context.SEAT_COUNT):
		missing += rules.empty_slots(seat).size()
	ctx.hud.set_turn("%d라운드 · %s" % [rules.round_number, "카드 나눠 주기" if first else "카드 충전 라운드"])
	await ctx.hud.banner("%d라운드 · %s" % [rules.round_number, "카드 나눠 주기" if first else "카드 충전 라운드!"],
		"덱을 섞고 한 사람에 한 장씩, 7장이 될 때까지" if first else "쓴 카드 %d장만큼만 다시 받는다 · 모두 7장인지 확인" % missing, 1.8)
	# 쓴 카드(사용 표시)를 테이블에서 걷고, 쓴 만큼 덱에 새 카드를 넣는다(바꾸기·버리기는 없다).
	await ctx.table_cards.clear_used()
	if not first:
		var added: int = rules.fill_deck()
		await ctx.table_cards.drop_in(added)
	rules.shuffle_deck()
	var style: int = settings.shuffle_style(rules.round_number, ctx.random, ctx.capturing)
	ctx.hud.toast("섞기: %s" % ShuffleMotions.STYLE_NAMES[style], PubTheme.GOLD)
	var face_types: Array[int] = []
	for card: Rules.Card in rules.deck:
		face_types.append(card.type)
	capture.shot_after("02_shuffle_%s" % ["riffle", "magician", "dealer"][style], 1.4)
	await ctx.table_cards.shuffle(style, face_types)
	await capture.shot("03_squared_deck")
	await _deal()
	await ctx.wait(0.35)
	await ctx.table_cards.reveal()
	cards.sync_fans()
	await capture.shot("05_revealed")
	var all_seven: bool = true
	for seat in range(Context.SEAT_COUNT):
		all_seven = all_seven and rules.hand_count(seat) >= Rules.HAND_SLOTS
	if not first and all_seven:
		ctx.stats.refilled_to_7 = true
	ctx.hud.toast("모두 7장 확인 ✓ (왼손 7장 = 테이블 7칸)" if all_seven else "7장이 안 되는 사람이 있다!", Color("8cf0a0") if all_seven else Color("ff9a8a"))
	ctx.cards_open = true
	ctx.hud.set_turn("카드 확인 · 1~7 로 꺼내 들기")
	ctx.hud.banner("카드 확인!", "왼손 카드 = 테이블 카드. 꺼내 든 카드는 모두가 본다.", 1.3)
	await ctx.wait(CHECK_SECONDS * 0.5)
	await capture.shot("06_hand_fan")
	await ctx.wait(CHECK_SECONDS * 0.5)


## 딜링: 정해진 순서로 한 바퀴에 한 사람 한 장씩, 빈 칸이 다 찰 때까지(rules.deal_plan). 덱의 위·가운데·아래(설정)에서 뽑는다.
func _deal() -> void:
	var rules: Rules = ctx.rules
	var plan: Array[Vector2i] = rules.deal_plan()
	var from: int = settings.draw_from()
	var order_text := PackedStringArray()
	for seat in rules.order:
		order_text.append(PlayerLook.SYMBOLS[seat])
	ctx.hud.toast("나눠 주기: 덱 %s에서 · 순서 %s (정하는 방법은 미정)" % [DRAW_NAMES[from], " → ".join(order_text)])
	for i in range(plan.size()):
		var step: Vector2i = plan[i]
		var index: int = rules.draw_index(from as Rules.DrawFrom)
		var card: Rules.Card = rules.take_from_deck(index)
		rules.place(step.x, step.y, card)
		ctx.table_cards.deal_card(index, card.type, step.x, step.y)
		ctx.stats.dealt = int(ctx.stats.dealt) + 1
		if i == plan.size() / 2:
			capture.shot_after("04_dealing", 0.05)
		await ctx.wait(DEAL_GAP)
	await ctx.wait(0.5)


## 다트 단계: 자리 순서대로 한 사람 3발. 카드는 이 동안에도 언제든 꺼내 들고 쓸 수 있다.
func _dart_stage() -> void:
	ctx.phase = "darts"
	ctx.hud.set_round(ctx.rules.round_number, RoundTracker.Stage.DARTS, _total_rounds())
	await ctx.hud.banner("%d라운드 · 다트!" % ctx.rules.round_number, "한 사람 3발 · 카드는 언제든 꺼내 들고 쓸 수 있다", 1.3)
	for position in range(ctx.rules.order.size()):
		if ctx.rules.finished:
			break
		await _turn(position)


## 한 사람의 차례: 일어나 던지는 자리로 → (봇) 막는 사람이 있으면 비키거나 그냥 던짐 / (나) 30초 안에 3발 → 차례 정리.
func _turn(position: int) -> void:
	var rules: Rules = ctx.rules
	rules.begin_turn(position)
	var seat: int = rules.active_seat()
	var actor: PlayerView = ctx.actors[seat]
	effects.apply(seat)
	ctx.hud.toast("%s 차례" % ctx.name_of(seat), PlayerLook.COLORS[seat].lightened(0.35))
	mover.stand(seat)
	disruption.plan(seat)
	if ctx.bot_driven(seat):
		mover.walk_to(seat, Vector3(ctx.random.randf_range(-0.5, 0.5), 0, SeatMover.THROW_Z), TableView.BOARD_CENTER)
		await ctx.wait_until(func() -> bool: return mover.arrived(seat), 7.0)
		while rules.is_turn_of(seat) and not rules.finished:
			await ctx.wait(ctx.random.randf_range(0.9, 1.4))
			await ctx.wait_until(func() -> bool: return not mover.stunned(seat), Disruption.STUN_SECONDS)
			if mover.blocked(seat) and ctx.random.randf() > THROW_THROUGH_CHANCE:
				# 막는 사람을 피해 옆으로 비킨다.
				mover.sidestep(seat)
				ctx.hud.toast("%s: 옆으로 비켜 선다" % ctx.name_of(seat))
				await ctx.wait_until(func() -> bool: return mover.arrived(seat), 1.6)
			actor.aiming = true
			await ctx.wait(0.35)
			await darts.throw(seat, BotDriver.random_aim(), BotDriver.random_charge())
	else:
		ctx.hud.banner("내 차례!", "투척선 쪽으로 걸어가 왼클릭을 길게 눌렀다 떼면 던진다 · 3발", 1.5)
		var deadline: float = ctx.now + TURN_SECONDS
		await ctx.wait_until(func() -> bool: return not rules.is_turn_of(seat) or rules.finished, TURN_SECONDS)
		if rules.is_turn_of(seat) and ctx.now >= deadline - 0.05:
			ctx.hud.toast("시간 초과 · 남은 다트는 0점", Color("ff9a8a"))
	await ctx.wait_until(func() -> bool: return not darts.busy, 3.0)
	await ctx.wait(0.7)
	actor.aiming = false
	rules.end_turn()
	effects.end_turn(seat)
	effects.restore()
	darts.clear_darts()
	mover.send_home(seat)
	mover.release_followers(seat)


## 라운드 정리: 라운드 한정 카드는 사라지고, 꺼내 든 카드는 손으로 돌아간다.
func _finish_round() -> void:
	ctx.rules.end_round()
	ctx.table_cards.clear_rewards()
	for seat in range(Context.SEAT_COUNT):
		cards.lower(seat)
	cards.sync_fans()


## 경기 끝: 우승 발표 → 벌칙 원판 → 골드 → 결과 화면.
func _ending() -> void:
	ctx.phase = "ending"
	ctx.cards_open = false
	for seat in range(Context.SEAT_COUNT):
		cards.lower(seat)
	var names := PackedStringArray()
	for seat in ctx.rules.winners:
		names.append(ctx.name_of(seat))
	ctx.hud.set_turn("경기 끝")
	await ctx.hud.banner("경기 끝!", "우승: %s" % ", ".join(names), 2.0)
	await _punishment()
	ctx.rules.award_gold()
	for seat in range(Context.SEAT_COUNT):
		session_gold[seat] += ctx.rules.seats[seat].gold
	ctx.phase = "results"
	ctx.hud.show_results(presenter.results_text(session_gold))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await ctx.wait(0.4)
	await capture.shot("12_results")
	ctx.game_over = true


## 벌칙: 꼴찌는 돌아가는 원판(서커스 칼 던지기)에 묶이고 나머지가 2발씩 던진다. 몸에 맞으면 스턴 별(점수와는 상관없음).
func _punishment() -> void:
	ctx.phase = "punish"
	var loser: int = ctx.rules.loser()
	await mover.gather()
	darts.wheel = PunishmentWheel.new()
	darts.wheel.position = Context.WHEEL_POSITION
	add_child(darts.wheel)
	darts.wheel.attach(loser)
	ctx.actors[loser].visible = false
	ctx.hud.set_turn("벌칙 · 꼴찌 %s" % ctx.name_of(loser))
	await ctx.hud.banner("벌칙 시간!", "꼴찌 %s 돌아가는 원판에 묶였다. 나머지가 %d발씩 던진다" % [Context.josa(ctx.name_of(loser), "이", "가"), DartActions.PUNISH_DARTS], 2.0)
	for seat in ctx.rules.order:
		if seat == loser:
			continue
		darts.punish_seat = seat
		darts.punish_left = DartActions.PUNISH_DARTS
		mover.stand(seat)
		ctx.hud.toast("%s 던질 차례" % ctx.name_of(seat), PlayerLook.COLORS[seat].lightened(0.35))
		if ctx.bot_driven(seat):
			mover.walk_to(seat, Vector3(ctx.random.randf_range(-0.4, 0.4), 0, SeatMover.THROW_Z), Context.WHEEL_POSITION)
			await ctx.wait_until(func() -> bool: return mover.arrived(seat), 7.0)
			while darts.punish_left > 0:
				ctx.actors[seat].aiming = true
				await ctx.wait(ctx.random.randf_range(0.8, 1.3))
				var angle: float = ctx.random.randf() * TAU
				var radius: float = ctx.random.randf_range(0.1, 0.85)
				await darts.punish_throw(seat, Context.WHEEL_POSITION + Vector3(cos(angle) * radius, sin(angle) * radius, 0), BotDriver.random_charge())
		else:
			ctx.hud.banner("내 차례!", "원판에 던진다 · 친구 몸은 피해서", 1.4)
			await ctx.wait_until(func() -> bool: return darts.punish_left <= 0, TURN_SECONDS)
		await ctx.wait_until(func() -> bool: return not darts.busy, 3.0)
		ctx.actors[seat].aiming = false
		await ctx.wait(0.6)
		mover.send_home(seat)
	darts.punish_seat = -1
	darts.wheel.stop()
	await capture.shot("11_wheel_after")
	await ctx.wait(1.2)


# --- 매 프레임 ---

func _process(delta: float) -> void:
	ctx.now += delta
	if ctx.actors.is_empty() or ctx.table_cards == null:
		return
	input.update()
	cards.think_bots()
	cards.update_pending()
	view.update(delta)
	presenter.update_status()
	input.update_throw_state()
	presenter.update_hud()
	effects.process()


func _physics_process(delta: float) -> void:
	if ctx.actors.is_empty():
		return
	mover.physics_step(delta)
	var me: PlayerView = ctx.actors[Context.LOCAL_SEAT]
	if me.visible and not mover.auto_driven(Context.LOCAL_SEAT):
		input.drive_local(delta)


func _unhandled_input(event: InputEvent) -> void:
	input.handle(event)


# --- 설정 ---

## 설정 창에서 값을 바꿨다 → 저장하고 지금 바로 바꿀 수 있는 것은 바로 반영한다(승리 조건은 새 게임부터).
func _on_setting_changed(key: String, value: int) -> void:
	settings.values[key] = value
	settings.save_file()
	match key:
		"reward":
			ctx.rules.reward_mode = settings.reward_mode()
		"speed":
			Engine.time_scale = settings.base_speed(autoplay, ctx.capturing)
		"voice":
			ctx.voice.muted = settings.voice_muted()
		"win":
			ctx.hud.toast("승리 조건은 '새 게임'부터 적용된다", PubTheme.GOLD)


## 결과 화면 "한 판 더".
func _restart() -> void:
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


## 위 라운드 표시에 보일 전체 라운드 수(끝 라운드가 없는 모드면 0 = 모름).
func _total_rounds() -> int:
	return ctx.rules.round_limit if ctx.rules.win_mode == Rules.WinMode.ROUND_LIMIT else 0


## 펍 생성물의 자리 매트에 그려 둔 "카드 뒷면 자리표시"를 지운다(진짜 카드가 그 자리에 놓인다).
static func _strip_placeholder_cards(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.material_override != null and mesh.material_override.resource_name == "CardBack":
			mesh.get_parent().remove_child(mesh)
			mesh.free()
