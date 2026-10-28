extends RefCounted
## 몸짓·감정표현(2026-10-28 사용자 기획): 왼클릭 = 손가락으로 가리키기, T = 감정표현 피자판(ui/emote_wheel.gd).
## 가리키기: 캐릭터 오른팔을 앞으로 뻗고 손가락(PointFinger)이 나온다(art/characters/character_rig.gd pointing).
##           내 화면에는 오른쪽 아래에 가리키는 1인칭 손이 잠깐 올라온다.
## 감정표현: 머리 위 말풍선 + 효과음(fx/emote_bubble.gd). 내 것은 피자판 쪽이 화면 아래에 크게 보여 준다.
## 봇도 일이 생기면 가끔 감정표현을 한다(맞음·무효·높은 점수) — 시연을 살리는 정도(확률·쿨타임은 시연값).

const Context = preload("res://game/card_round/flow/round_context.gd")
const EmoteBubble = preload("res://game/card_round/fx/emote_bubble.gd")
const EmoteArt = preload("res://game/card_round/fx/emote_art.gd")
const EmoteWheel = preload("res://game/card_round/ui/emote_wheel.gd")
const CharacterFactory = preload("res://art/characters/character_factory.gd")
const MeshKit = preload("res://art/mesh_kit.gd")

## 가리키는 시간(초).
const POINT_SECONDS: float = 1.3
## 봇 감정표현: 일이 생겼을 때 할 확률, 한 사람이 다시 하기까지 쉬는 시간(초).
const BOT_EMOTE_CHANCE: float = 0.5
const BOT_EMOTE_COOLDOWN: float = 5.0
## 감정 번호(fx/emote_art.gd 순서).
const LAUGH: int = 0
const THUMBS: int = 1
const ANGRY: int = 2
const CRY: int = 3
const WOW: int = 4
const TEASE: int = 5
const GG: int = 7
## 1인칭 가리키는 손: 카메라 기준 자리와 숨었을 때 내려가는 거리.
const FP_POSITION := Vector3(0.17, -0.15, -0.42)
const FP_HIDDEN_DROP: float = 0.25

var _ctx: Context
var _wheel: EmoteWheel
var _point_until: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _bot_emote_ready: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _fp_hand: Node3D


## 감독이 시작할 때 한 번: 함께 쓰는 상자와 피자판을 받는다.
func setup(ctx: Context, wheel: EmoteWheel) -> void:
	_ctx = ctx
	_wheel = wheel
	_wheel.chosen.connect(func(index: int) -> void: emote(Context.LOCAL_SEAT, index))


## 캐릭터가 다 만들어진 뒤 한 번: 캐릭터마다 오른손 가리키는 손가락(숨김), 내 카메라에 1인칭 가리키는 손.
func build() -> void:
	for actor in _ctx.actors:
		var arm := actor.get_node_or_null("Model/Body/ArmR") as Node3D
		var hand: MeshInstance3D = arm.get_node_or_null("Hand") as MeshInstance3D if arm != null else null
		if hand == null:
			continue
		# 어깨(팔 원점) → 손 방향으로 손끝 너머까지 뻗은 막대 = 집게손가락. 팔을 앞으로 들면 앞을 가리킨다.
		var along: Vector3 = hand.position.normalized()
		var finger := MeshKit.rod(arm, "PointFinger", hand.position + along * 0.04, hand.position + along * 0.13, 0.02, hand.material_override)
		finger.layers = hand.layers
		finger.visible = false
	_fp_hand = CharacterFactory.create_hand(Context.LOCAL_SEAT)
	_fp_hand.name = "PointingHand"
	var mitten := _fp_hand.get_node("Mitten") as MeshInstance3D
	var finger := MeshKit.rod(_fp_hand, "Finger", Vector3(0.002, -0.02, 0.04), Vector3(0.004, -0.01, -0.05), 0.012, mitten.material_override)
	finger.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fp_hand.position = FP_POSITION + Vector3.DOWN * FP_HIDDEN_DROP
	_fp_hand.rotation_degrees = Vector3(6, 14, 0)
	_fp_hand.visible = false
	_ctx.camera.add_child(_fp_hand)


## seat 가 손가락으로 앞을 가리킨다(POINT_SECONDS 동안).
func point(seat: int) -> void:
	_point_until[seat] = _ctx.now + POINT_SECONDS


## seat 가 index 감정을 보낸다: 머리 위 말풍선 + 소리. 내 것이면 화면 아래에도 크게.
func emote(seat: int, index: int) -> void:
	var actor: PlayerView = _ctx.actors[seat]
	if not actor.visible:
		return
	var bubble := EmoteBubble.new()
	bubble.index = index
	bubble.layer_mask = 1 << (seat + 1)
	actor.add_child(bubble)
	if seat == Context.LOCAL_SEAT and not _ctx.autoplay:
		_wheel.show_mine(index)


## 매 프레임: 가리키는 팔 자세와 1인칭 가리키는 손.
func process(delta: float) -> void:
	for seat in range(Context.SEAT_COUNT):
		var rig: CharacterRig = _ctx.actors[seat].get("_rig")
		if rig != null:
			rig.pointing = _ctx.now < _point_until[seat]
	if _fp_hand == null:
		return
	var showing: bool = _ctx.now < _point_until[Context.LOCAL_SEAT] and _ctx.actors[Context.LOCAL_SEAT].visible
	var target: Vector3 = FP_POSITION + (Vector3.ZERO if showing else Vector3.DOWN * FP_HIDDEN_DROP)
	_fp_hand.position = _fp_hand.position.lerp(target, 1.0 - exp(-16.0 * delta))
	_fp_hand.visible = showing or _fp_hand.position.distance_to(target) > 0.01


# --- 봇 반응(신호를 받아 가끔 감정표현) ---

## 몸에 맞았다: 맞은 봇은 화남·울음, 지켜보던 다른 봇은 가끔 웃음.
func on_body_hit(thrower: int, victim: int) -> void:
	_bot_emote(victim, [ANGRY, CRY])
	for seat in range(Context.SEAT_COUNT):
		if seat != thrower and seat != victim and _ctx.random.randf() < 0.35:
			_bot_emote(seat, [LAUGH])


## 무효(×0)로 막았다: 막은 봇은 메롱, 막힌 봇은 화남·놀람.
func on_nullified(by: int, target: int) -> void:
	_bot_emote(by, [TEASE])
	_bot_emote(target, [ANGRY, WOW])


## 카드를 남에게 썼다: 쓴 봇은 그 사람 쪽을 손가락으로 가리킨다.
func on_card_used(seat: int, target: int) -> void:
	if target != seat and _ctx.bot_driven(seat):
		point(seat)


## 다트 한 발 점수(과녁 기본 점수): 높으면 던진 봇이 자랑, 0점이면 가끔 울음.
func on_dart_landed(seat: int, base: int) -> void:
	if base >= 50:
		_bot_emote(seat, [GG, THUMBS, LAUGH])
	elif base >= 40:
		_bot_emote(seat, [THUMBS, LAUGH])
	elif base == 0 and _ctx.random.randf() < 0.5:
		_bot_emote(seat, [CRY])


## 봇 한 명이 choices 중 하나로 감정표현(확률·쿨타임). 사람(내 자리)은 건드리지 않는다.
func _bot_emote(seat: int, choices: Array) -> void:
	if not _ctx.bot_driven(seat) or _ctx.now < _bot_emote_ready[seat] or _ctx.random.randf() > BOT_EMOTE_CHANCE:
		return
	_bot_emote_ready[seat] = _ctx.now + BOT_EMOTE_COOLDOWN
	emote(seat, int(choices[_ctx.random.randi_range(0, choices.size() - 1)]))
