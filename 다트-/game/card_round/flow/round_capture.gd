extends RefCounted
## 화면 캡처(자동 검사 tests/test_card_round.gd -- --render 전용). 게임 규칙·진행에는 아무 영향이 없다.
## 캡처 폴더가 비어 있거나 화면 없는 실행(--headless)이면 아무것도 하지 않는다.
## 어떤 장면을 언제 찍을지(파일 이름 01~12)가 전부 이 파일에 모여 있다 → 캡처를 빼도 다른 코드는 그대로다.

const Context = preload("res://game/card_round/flow/round_context.gd")
const RoundCamera = preload("res://game/card_round/flow/round_camera.gd")
const CardView = preload("res://game/card_round/cards/card_view.gd")

## 이 폴더에 PNG 로 저장한다(비어 있으면 끔).
var folder: String = ""

var _ctx: Context
var _view: RoundCamera
## 한 번만 찍는 장면(같은 이름을 두 번 찍지 않는다).
var _taken: Dictionary = {}
var _switched_to_burn: bool = false


## 감독이 시작할 때 한 번: 캡처 폴더를 정하고(없으면 만든다) 시선 부품을 받는다.
func setup(ctx: Context, view: RoundCamera, capture_folder: String) -> void:
	_ctx = ctx
	_view = view
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
## 내가 맞혔으면 흐려진 내 화면.
func on_body_hit(thrower: int, victim: int) -> void:
	if victim != Context.LOCAL_SEAT:
		shot_once_looking("08_stun_stars", _ctx.actors[victim].global_position + Vector3.UP * 1.7, 1.4, 0.9)
	if thrower == Context.LOCAL_SEAT:
		shot_after("09_blurred_view", 0.55)


## 벌칙 원판에서 친구 몸을 맞혔다 → 바로 찍는다.
func on_wheel_body_hit() -> void:
	shot("10_wheel_stun")
