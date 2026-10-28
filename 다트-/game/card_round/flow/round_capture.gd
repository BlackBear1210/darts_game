extends RefCounted
## 화면 캡처(자동 검사 tests/test_card_round.gd -- --render 전용). 게임 규칙·진행에는 아무 영향이 없다.
## 캡처 폴더가 비어 있거나 화면 없는 실행(--headless)이면 아무것도 하지 않는다.
## 어떤 장면을 언제 찍을지(파일 이름 01~16)가 전부 이 파일에 모여 있다 → 캡처를 빼도 다른 코드는 그대로다.

const Context = preload("res://game/card_round/flow/round_context.gd")
const RoundCamera = preload("res://game/card_round/flow/round_camera.gd")
const CardView = preload("res://game/card_round/cards/card_view.gd")
const Gestures = preload("res://game/card_round/flow/gestures.gd")
const EmoteWheel = preload("res://game/card_round/ui/emote_wheel.gd")
const ScreenDebuff = preload("res://game/card_round/fx/screen_debuff.gd")

## 이 폴더에 PNG 로 저장한다(비어 있으면 끔).
var folder: String = ""

var _ctx: Context
var _view: RoundCamera
var _gestures: Gestures
var _wheel: EmoteWheel
## 한 번만 찍는 장면(같은 이름을 두 번 찍지 않는다).
var _taken: Dictionary = {}
var _switched_to_burn: bool = false


## 감독이 시작할 때 한 번: 캡처 폴더를 정하고(없으면 만든다) 시선·몸짓·피자판 부품을 받는다.
func setup(ctx: Context, view: RoundCamera, capture_folder: String, gestures: Gestures, wheel: EmoteWheel) -> void:
	_ctx = ctx
	_view = view
	_gestures = gestures
	_wheel = wheel
	folder = capture_folder
	if not folder.is_empty():
		DirAccess.make_dir_recursive_absolute(folder)


## 실제로 찍는가(폴더가 있고 화면이 있는 실행).
func enabled() -> bool:
	return not folder.is_empty() and DisplayServer.get_name() != "headless"


## 지금 화면을 label.png 로 저장한다(그림이 다 그려진 뒤).
func shot(label: String) -> void:
	if not enabled():
		return
	await RenderingServer.frame_post_draw
	var image: Image = _ctx.root.get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(folder.path_join(label + ".png"))
		print("SHOT ", label)


## seconds 뒤에 찍는다(기다리지 않고 바로 돌아온다).
func shot_after(label: String, seconds: float) -> void:
	if not enabled():
		return
	await _ctx.wait(seconds)
	await shot(label)


## 한 번만: delay 뒤에 찍는다(같은 이름은 다시 안 찍는다).
func shot_once(label: String, delay: float) -> void:
	if not enabled() or _taken.has(label):
		return
	_taken[label] = true
	shot_after(label, delay)


## 한 번만: look_seconds 동안 look_point 를 보게 하고 delay 뒤에 찍는다.
func shot_once_looking(label: String, look_point: Vector3, look_seconds: float, delay: float) -> void:
	if not enabled() or _taken.has(label):
		return
	_taken[label] = true
	_view.look_at_for(look_point, look_seconds)
	shot_after(label, delay)


## 캡처 때만: 1라운드가 끝나면 쓴 카드 표시를 그을림으로 바꿔 두 방식을 모두 찍는다(게임에서는 설정으로 하나만 쓴다).
func before_next_round() -> void:
	if folder.is_empty() or _switched_to_burn:
		return
	_ctx.settings.values.mark = CardView.Mark.BURN
	_switched_to_burn = true


# --- 신호를 받아 찍는 장면 ---

## 카드 확인이 끝났다 → 맞은편(테이블 앞쪽) 사람 왼손 부채를 가까이 본다(2026-10-28: 부채 1.5배 확인용).
func on_cards_checked() -> void:
	var opponent: PlayerView = _ctx.actors[3 if Context.LOCAL_SEAT != 3 else 0]
	var fan: Node3D = opponent.get_node_or_null("Model/Body/LeftHandCards")
	if fan != null:
		shot_once_looking("14_opponent_fan", fan.global_position, 1.6, 1.2)


## 다트 단계 시작(한 번만): 바닥의 던지는 칸·방해선 → 감정표현(봇 말풍선·가리키기·피자판) → 난시 화면을 차례로 찍는다.
## 감정표현·난시는 자동 진행이라 사람이 못 누르므로 여기서 잠깐 켰다가 끈다(규칙·점수에는 영향 없음).
func on_darts_started() -> void:
	if not enabled() or _taken.has("13_throw_zone"):
		return
	_taken["13_throw_zone"] = true
	_view.look_at_for(Vector3(0, 0.1, -1.7), 2.4)
	await shot_after("13_throw_zone", 1.9)
	var emotes: Array[int] = [Gestures.LAUGH, Gestures.WOW, 6]
	var shown: int = 0
	for seat in range(Context.SEAT_COUNT):
		if seat != Context.LOCAL_SEAT and shown < emotes.size():
			_gestures.emote(seat, emotes[shown])
			shown += 1
	_gestures.point((Context.LOCAL_SEAT + 2) % Context.SEAT_COUNT)
	_wheel.preview(Gestures.ANGRY)
	_view.look_at_for(TableView.TABLE_CENTER + Vector3.UP * 1.6, 1.4)
	await shot_after("15_emotes", 0.7)
	_wheel.close()
	if _ctx.debuff.penalty != ScreenDebuff.Penalty.NONE:
		return
	_ctx.debuff.penalty = ScreenDebuff.Penalty.ASTIGMATISM
	_view.look_at_for(TableView.BOARD_CENTER, 1.6)
	await shot_after("16_astigmatism_board", 1.2)
	if _ctx.debuff.penalty == ScreenDebuff.Penalty.ASTIGMATISM:
		_ctx.debuff.penalty = ScreenDebuff.Penalty.NONE

## 내 카드에 사용 표시가 남았다 → 내 자리 매트를 내려다보고 찍는다.
## 막으러 나가 서 있으면 매트가 멀어 안 보이므로 앉아 있을 때만.
func on_card_marked(seat: int, slot: int) -> void:
	if seat != Context.LOCAL_SEAT or not _ctx.actors[Context.LOCAL_SEAT].seated:
		return
	var label: String = "07_used_mark_%s" % ("burn" if _ctx.settings.mark() == CardView.Mark.BURN else "paint")
	shot_once_looking(label, _ctx.table_cards.slot_transform(seat, slot).origin, 2.2, 1.7)


## 무효 카드가 효과를 막았다 → 0.6초 뒤 찍는다.
func on_nullified(_by: int, _target: int) -> void:
	shot_after("07_nullify", 0.6)


## 몸 맞음 → 맞은 사람 머리 위 별(내가 맞으면 내 화면엔 안 보이므로 다른 사람이 처음 맞았을 때 한 번),
## 내가 맞혔으면 맞힌 벌(취기·마우스·난시 중 하나)이 걸린 내 화면 — 파일 이름에 벌 종류를 붙인다.
## 다트가 꽂혔을 때. card_round.gd 가 darts.dart_landed 를 여기에 잇는데
## 커밋 bb27231 에 이 함수가 빠져 장면이 실행 중 멈췄다(2026-10-28 병합에서 발견).
## 무엇을 찍을지는 작성자가 채운다 — 지금은 아무것도 찍지 않는다.
func on_dart_landed(_seat: int, _base: int) -> void:
	pass


func on_body_hit(thrower: int, victim: int) -> void:
	if victim != Context.LOCAL_SEAT:
		shot_once_looking("08_stun_stars", _ctx.actors[victim].global_position + Vector3.UP * 1.7, 1.4, 0.9)
	if thrower == Context.LOCAL_SEAT:
		shot_after("09_hit_penalty_%s" % ["", "sway", "mouse", "astigmatism"][_ctx.debuff.penalty], 1.2)


## 벌칙 원판에서 친구 몸을 맞혔다 → 바로 찍는다.
func on_wheel_body_hit() -> void:
	shot("10_wheel_stun")
