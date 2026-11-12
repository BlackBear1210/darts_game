extends RefCounted
## 차례 동안 눈에 보이는 효과: 과녁 숫자 섞기 · 가림판(왼쪽 절반 — 다트 머신 롤 셔터) · 바람 표시 · 졸림(내 화면 눈꺼풀),
## 그리고 사람을 맞힌 벌(그 사람의 차례가 끝날 때까지: 취기·마우스·난시 중 무작위 하나 + 목소리 변조).
## 무엇이 걸렸는지는 규칙(rules.dart_modifiers)이 정하고, 여기는 보이게만 한다.

const Context = preload("res://game/card_round/flow/round_context.gd")
const CardFaces = preload("res://game/card_round/cards/card_faces.gd")
const Chaos = preload("res://game/board/board_chaos.gd")
const Catalog = preload("res://game/card_round/rules/card_catalog.gd")
const ScreenDebuff = preload("res://game/card_round/fx/screen_debuff.gd")

## 맞힌 사람이 변조된 목소리로 투덜대는 간격(초).
const WARP_TALK_SECONDS: float = 2.4

## 지금 차례의 과녁 숫자 배치. "숫자 섞기"가 걸리면 섞인 배치 — 채점(dart_actions.gd)도 이 배치를 쓴다.
var layout := BoardLayout.new()
## 사람을 맞혀 벌 받는 중인 자리(-1 = 없음)와 그 벌 종류(취기·마우스·난시).
var penalty_seat: int = -1
var penalty_kind: ScreenDebuff.Penalty = ScreenDebuff.Penalty.NONE

var _ctx: Context
var _cover: MeshInstance3D
var _wind: Label3D
var _warp_talk_at: float = 0.0
var _motion_started: Dictionary = {}
var _applied: Dictionary = {}
var _cover_side: int = -1
var _move_dir := Vector2.RIGHT
var _round_overrides: Dictionary = {}
var _lock_applied: Dictionary = {}
var _round_number: int = -1


## 감독이 시작할 때 한 번: 함께 쓰는 상자를 받는다.
func setup(ctx: Context) -> void:
	_ctx = ctx


## 과녁 소품을 한 번 만든다: 가림판(다트 머신이 없을 때만 쓰는 예비 판자)과 바람 표시. 평소에는 숨겨 둔다.
## 2026-11-08 사용자 요청 "판때기로 가리지 말고 가게 셔터처럼 옆에서 촤라락" → 가림판은 다트 머신의 롤 셔터
## (art/dart_machine/roll_shutter.gd, F5 본 게임과 같은 그림)로 닫는다. 판자는 머신이 없는 장면을 위한 예비다.
func build_props() -> void:
	var radius: float = BoardLayout.RADIUS * TableView.BOARD_SCALE
	_cover = MeshInstance3D.new()
	_cover.name = "CoverPlank"
	var plank := BoxMesh.new()
	plank.size = Vector3(radius + 0.06, radius * 2.2, 0.05)
	_cover.mesh = plank
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("6b4a2e")
	wood.roughness = 0.9
	_cover.material_override = wood
	_cover.position = TableView.BOARD_CENTER + Vector3(-(radius + 0.06) * 0.5, 0, 0.12)
	_cover.visible = false
	_ctx.root.add_child(_cover)
	var sign := Label3D.new()
	sign.text = "가림판"
	sign.font = CardFaces.bold_font()
	sign.font_size = 96
	sign.pixel_size = 0.004
	sign.modulate = Color("f0e6cf")
	sign.position = Vector3(0, 0, 0.03)
	_cover.add_child(sign)
	_wind = Label3D.new()
	_wind.name = "WindSign"
	_wind.text = "바람 →→→"
	_wind.font = CardFaces.bold_font()
	_wind.font_size = 110
	_wind.pixel_size = 0.005
	_wind.outline_size = 18
	_wind.modulate = Color("bfe8ff")
	_wind.position = TableView.BOARD_CENTER + Vector3(0, radius + 0.35, 0.2)
	_wind.visible = false
	_ctx.root.add_child(_wind)


## seat 차례에 걸린 효과를 보이게 한다(차례 시작 때, 그리고 차례 중에 새 카드가 걸렸을 때).
func apply(seat: int) -> void:
	if _round_number != _ctx.rules.round_number:
		_round_number = _ctx.rules.round_number
		_round_overrides.clear()
		_lock_applied.clear()
	for effect in _ctx.rules.effects:
		if effect.kind != "lock_scores" or effect.state != _ctx.rules.EffectState.ACTIVE or _lock_applied.has(effect.uid): continue
		_lock_applied[effect.uid] = true
		layout.overrides = _round_overrides.duplicate()
		layout.apply_card_change("lock_scores", -1, effect.contributors.size(), _ctx.random)
		_round_overrides = layout.overrides.duplicate()
	layout.overrides = _round_overrides.duplicate()
	var mods: Dictionary = _ctx.rules.dart_modifiers(seat)
	for effect in _ctx.rules.effects:
		if effect.target != seat or effect.state != _ctx.rules.EffectState.ACTIVE or _applied.has(effect.uid): continue
		_applied[effect.uid] = true
		if effect.kind != "lock_scores": layout.apply_card_change(effect.kind, effect.choice, effect.contributors.size(), _ctx.random)
		if effect.kind in ["spin", "split", "vertical", "horizontal", "move", "cover"] and not _motion_started.has(effect.kind):
			_motion_started[effect.kind] = _ctx.now
			if effect.kind == "cover": _cover_side = -1 if _ctx.random.randf() < 0.5 else 1
			if effect.kind == "move": _move_dir = Vector2.from_angle(_ctx.random.randf_range(0, TAU))
	_ctx.table.board.show_layout(layout)
	_cover.visible = false
	_wind.visible = absf(float(mods.push)) > 0
	_wind.text = "바람 ←←←" if float(mods.push) < 0 else "바람 →→→"
	if seat == Context.LOCAL_SEAT: _ctx.debuff.drowsy = bool(mods.drowsy)



## 차례가 끝나면 과녁·소품·졸림을 원래대로.
func restore() -> void:
	_motion_started.clear()
	_applied.clear()
	layout = BoardLayout.new()
	_ctx.table.board.show_layout(layout)
	_cover.hide()
	_ctx.table.board.show_chaos(Chaos.rest())
	if _ctx.table.machine != null: _ctx.table.machine.show_chaos(Chaos.rest(), 0.0)
	_wind.visible = false
	_ctx.debuff.drowsy = false


## 가림판 켜기/끄기: 다트 머신이 있으면 롤 셔터를 옆에서 밀어 닫고(촤라락), 없으면 예비 판자를 보인다.
func _show_cover(closed: bool) -> void:
	var machine: Node = _ctx.table.machine if _ctx.table != null else null
	if machine != null:
		machine.call("slide_shutter", closed)
		_cover.visible = false
	else:
		_cover.visible = closed


## 사람을 맞힌 벌: thrower 의 차례가 끝날 때까지 취기·마우스·난시 중 하나(같은 확률, 내 화면일 때 보인다) + 목소리 변조.
## 2026-10-28 피드백: 예전 "화면 흐림"은 너무 뿌옇다 → 셋 중 무작위. 고른 벌 이름을 돌려준다(알림 글에 쓴다).
func penalize(thrower: int) -> String:
	penalty_seat = thrower
	penalty_kind = _ctx.random.randi_range(ScreenDebuff.Penalty.SWAY, ScreenDebuff.Penalty.ASTIGMATISM) as ScreenDebuff.Penalty
	_ctx.voice.set_warped(thrower, true)
	if thrower == Context.LOCAL_SEAT:
		_ctx.debuff.penalty = penalty_kind
	_warp_talk_at = _ctx.now + 0.6
	return ScreenDebuff.PENALTY_NAMES[penalty_kind]


## 벌 받는 사람 머리 위·점수판에 쓸 짧은 이름(없으면 빈 글).
func penalty_name(seat: int) -> String:
	return ScreenDebuff.PENALTY_NAMES[penalty_kind] if seat == penalty_seat else ""


## seat 의 차례 끝: 맞힌 벌을 푼다.
func end_turn(seat: int) -> void:
	if penalty_seat == seat:
		penalty_seat = -1
		penalty_kind = ScreenDebuff.Penalty.NONE
		_ctx.voice.set_warped(seat, false)
		_ctx.debuff.penalty = ScreenDebuff.Penalty.NONE


## 매 프레임: 벌 받는 사람이 변조된 목소리로 투덜대게 한다(목소리 변조가 들리도록).
func process() -> void:
	var shape: Dictionary = shape_now()
	_ctx.table.board.show_chaos(shape)
	if _ctx.table.machine != null: _ctx.table.machine.show_chaos(shape, 0.016)
	if penalty_seat >= 0 and _ctx.now >= _warp_talk_at:
		_ctx.voice.say(penalty_seat, "talk")
		_warp_talk_at = _ctx.now + WARP_TALK_SECONDS


func shape_now() -> Dictionary:
	var age := func(kind: String) -> float:
		return _ctx.now - float(_motion_started[kind]) if _motion_started.has(kind) else -1.0
	return Chaos.boost(Chaos.pose(age.call("spin"), 1, age.call("split"), age.call("cover"), age.call("vertical"), age.call("horizontal"), age.call("move"), _move_dir, _cover_side), _ctx.rules.dart_modifiers(_ctx.rules.active_seat()).get("synergy_levels", {}))
