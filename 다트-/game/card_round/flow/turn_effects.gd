extends RefCounted
## 차례 동안 눈에 보이는 효과: 과녁 숫자 섞기 · 가림판(왼쪽 절반) · 바람 표시 · 졸림(내 화면 눈꺼풀),
## 그리고 사람을 맞힌 벌(그 사람의 차례가 끝날 때까지 화면 흐림 + 목소리 변조).
## 무엇이 걸렸는지는 규칙(rules.dart_modifiers)이 정하고, 여기는 보이게만 한다.

const Context = preload("res://game/card_round/flow/round_context.gd")
const CardFaces = preload("res://game/card_round/cards/card_faces.gd")

## 맞힌 사람이 변조된 목소리로 투덜대는 간격(초).
const WARP_TALK_SECONDS: float = 2.4

## 지금 차례의 과녁 숫자 배치. "숫자 섞기"가 걸리면 섞인 배치 — 채점(dart_actions.gd)도 이 배치를 쓴다.
var layout := BoardLayout.new()
## 사람을 맞혀 화면 흐림 + 목소리 변조 중인 자리(-1 = 없음).
var blurred_seat: int = -1

var _ctx: Context
var _cover: MeshInstance3D
var _wind: Label3D
var _warp_talk_at: float = 0.0


## 감독이 시작할 때 한 번: 함께 쓰는 상자를 받는다.
func setup(ctx: Context) -> void:
	_ctx = ctx


## 과녁 소품을 한 번 만든다: 가림판(왼쪽 절반을 가리는 판자)과 바람 표시. 평소에는 숨겨 둔다.
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
	var mods: Dictionary = _ctx.rules.dart_modifiers(seat)
	if bool(mods.shuffle) and layout.numbers == BoardLayout.DEFAULT_NUMBERS:
		layout = BoardLayout.new()
		layout.shuffle_with(_ctx.random)
		_ctx.table.board.show_layout(layout)
	_cover.visible = bool(mods.cover)
	_wind.visible = float(mods.push) > 0.0
	if seat == Context.LOCAL_SEAT:
		_ctx.debuff.drowsy = bool(mods.drowsy)


## 차례가 끝나면 과녁·소품·졸림을 원래대로.
func restore() -> void:
	layout = BoardLayout.new()
	_ctx.table.board.show_layout(layout)
	_cover.visible = false
	_wind.visible = false
	_ctx.debuff.drowsy = false


## 사람을 맞힌 벌: thrower 의 차례가 끝날 때까지 화면 흐림(내 화면일 때) + 목소리 변조.
func blur(thrower: int) -> void:
	blurred_seat = thrower
	_ctx.voice.set_warped(thrower, true)
	if thrower == Context.LOCAL_SEAT:
		_ctx.debuff.blurred = true
	_warp_talk_at = _ctx.now + 0.6


## seat 의 차례 끝: 맞힌 벌을 푼다.
func end_turn(seat: int) -> void:
	if blurred_seat == seat:
		blurred_seat = -1
		_ctx.voice.set_warped(seat, false)
		_ctx.debuff.blurred = false


## 매 프레임: 벌 받는 사람이 변조된 목소리로 투덜대게 한다(목소리 변조가 들리도록).
func process() -> void:
	if blurred_seat >= 0 and _ctx.now >= _warp_talk_at:
		_ctx.voice.say(blurred_seat, "talk")
		_warp_talk_at = _ctx.now + WARP_TALK_SECONDS
