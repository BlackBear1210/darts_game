extends RefCounted
## 네 자리 캐릭터 만들기: 참가자 정보(MatchPlayer) + 캐릭터(PlayerView, F5 와 같은 player.tscn) + 왼손 카드 부채 + 카드 드는 팔 자세 + 머리 위 글자.
## 내 화면 왼쪽 아래 1인칭 부채(card_round.tscn 의 Camera/Fan)도 여기서 모양을 맞춘다.

const Context = preload("res://game/card_round/flow/round_context.gd")
const SeatMover = preload("res://game/card_round/flow/seat_mover.gd")
const HudPresenter = preload("res://game/card_round/flow/hud_presenter.gd")
const HandFan = preload("res://game/card_round/cards/hand_fan.gd")
const PLAYER_SCENE: PackedScene = preload("res://game/player/player.tscn")

## 캐릭터 왼손 부채 위치와 그 캐릭터 눈 위치(몸 Body 기준).
## art/characters/character_factory.gd 치수 + 카드 든 팔 각도(character_rig.gd HOLD_ARM_*)로 계산한 값이다. 팔 각도를 바꾸면 같이 맞춘다.
const FAN_POSITION := Vector3(0.11, 0.33, 0.43)
const FAN_EYE := Vector3(0, 0.75, 0.17)


## 자리 0~3 캐릭터를 만들어 앉히고 ctx.players · ctx.actors · ctx.fans 를 채운다.
static func build(ctx: Context, players_root: Node3D, mover: SeatMover, presenter: HudPresenter) -> void:
	for seat in range(Context.SEAT_COUNT):
		var player := MatchPlayer.new()
		player.peer_id = seat + 1
		player.seat = seat
		player.display_name = "%d번 %s" % [seat + 1, ctx.rules.seats[seat].name]
		player.is_bot = seat != Context.LOCAL_SEAT
		ctx.players.append(player)
		var view := PLAYER_SCENE.instantiate() as PlayerView
		view.name = "Player_%d" % (seat + 1)
		players_root.add_child(view)
		view.configure(player)
		ctx.actors.append(view)
		mover.sit(seat)
		ctx.fans.append(_left_hand_fan(view, seat))
		# 팔 자세는 캐릭터 몸짓(CharacterRig)이 정한다. PlayerView 의 _rig 를 이름으로 꺼내 player.gd 는 고치지 않았다.
		var rig: CharacterRig = view.get("_rig")
		if rig != null:
			rig.holding_cards = true
		presenter.attach_status(view)
	_setup_local_fan(ctx.local_fan)


## 왼손 카드 부채: 몸(Body) 자식이라 걷고 앉아도 손을 따라간다.
## 레이어 = 그 캐릭터 레이어(자리 + 1) → 내 화면에는 내 몸·부채가 안 보이고 1인칭 부채만 보인다.
static func _left_hand_fan(view: PlayerView, seat: int) -> HandFan:
	var fan := HandFan.new()
	fan.name = "LeftHandCards"
	# 2026-10-28 피드백: 상대 왼손 부채가 너무 작아 안 보인다 → 카드 크기·반지름·들어 올림을 약 1.55배(0.55 → 0.85).
	fan.card_scale = 0.85
	fan.radius = 0.115
	fan.spread_degrees = 60.0
	fan.lift_height = 0.07
	fan.lift_scale = 1.3
	fan.lift_forward = 0.03
	fan.layer_mask = 1 << (seat + 1)
	var body := view.get_node("Model/Body") as Node3D
	body.add_child(fan)
	fan.position = FAN_POSITION
	# 카드 앞면이 든 사람 눈 쪽을 본다 → 뒤로 돌아가 보면 상대 카드가 보인다(기획: "걸어가서 상대 왼손 카드 보기").
	fan.basis = Basis.looking_at(FAN_POSITION - FAN_EYE, Vector3.UP)
	return fan


## 1인칭 부채: 꼭지를 화면 아래로 내리고 넓게 펼쳐 카드끼리 덜 겹치게(숫자 키가 보이게) 한다.
static func _setup_local_fan(fan: HandFan) -> void:
	fan.show_keys = true
	fan.card_scale = 0.75
	fan.radius = 0.2
	fan.spread_degrees = 64.0
	fan.cast_shadows = false
