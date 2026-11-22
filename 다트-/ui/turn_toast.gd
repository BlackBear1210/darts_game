extends CanvasLayer
## "내 차례가 아니에요!" 알림(2026-11-17). 디자인 담당 소유. class_name 없이 preload 로 부른다(열린 편집기 파스 오류 함정).
## 사용자 요청 "다트 점수 카운트 중 다른 플레이어가 자기 차례가 아닐 때 던지면 자기 차례가 아니라는 문구를 UI 로 팝업".
##
## [언제 뜨나] GameView._on_throw_requested 가 정한다: 경기 중(다트 단계)인데 지금 차례가 남의 것일 때 던지면
##   그 다트는 예전처럼 "그냥 던진 다트"로 날아가고(점수 없음), 던진 사람 화면에만 이 알림이 뜬다.
## [모양] 화면 가운데 위쪽 분홍 글자(2026-11-22 판 없앰): 큰 글씨 "내 차례가 아니에요!" + 작은 글씨 "지금은 ● 이름 차례 · 이 다트는 점수에 안 들어가요".
##   톡 튀어나왔다가(커졌다 제자리) 잠깐 머문 뒤 흐려지며 사라진다. 다시 던지면 처음부터 다시 뜨고 좌우로 살짝 흔들린다.
## 마우스·키 입력을 막지 않는다(MOUSE_FILTER_IGNORE) — 경기 조작에 지장이 없다.

const Style = preload("res://ui/lounge_style.gd")

## 머무는 시간 · 사라지는 시간 · 튀어나오는 시간(초).
const HOLD_SECONDS: float = 1.7
const FADE_SECONDS: float = 0.45
const POP_SECONDS: float = 0.22
## 화면 높이에서 카드 가운데가 오는 비율(위에서 0.28 — 조준점·과녁을 가리지 않는다).
const SCREEN_Y: float = 0.28

var _card: PanelContainer
var _title: Label
var _detail: Label
var _age: float = -1.0
var _shake: float = 0.0


func _ready() -> void:
	layer = 26
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_card = PanelContainer.new()
	_card.name = "TurnToastCard"
	_card.theme = Style.theme()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 2026-11-22: 분홍 판(기울어진 테두리)을 없애고 분홍 글자 + 잉크 외곽선만 남겼다(경기 HUD 공통 — 배경을 가리지 않는다).
	_card.add_theme_stylebox_override("panel", Style.clear())
	holder.add_child(_card)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(column)
	_title = Style.heading(column, "내 차례가 아니에요!", 40, Style.PINK)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail = Style.hud_label(column, "", 20, Style.CREAM)
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.visible = false


## 알림을 띄운다. who = 지금 차례인 사람 표시("● 이름"), color = 그 사람 자리 색(작은 글씨에만 쓴다).
func show_not_your_turn(who: String, color: Color = Style.CREAM) -> void:
	if who.is_empty():
		_detail.text = "이 다트는 점수에 안 들어가요"
	else:
		_detail.text = "지금은 %s 차례 · 이 다트는 점수에 안 들어가요" % who
	_detail.add_theme_color_override("font_color", color.lerp(Style.CREAM, 0.6))
	# 떠 있는 중에 또 던지면 흔들어서 "또 던졌다"를 알린다.
	_shake = 1.0 if _age >= 0.0 else 0.0
	_age = 0.0
	_card.visible = true


func is_showing() -> bool:
	return _age >= 0.0


func _process(delta: float) -> void:
	if _age < 0.0:
		return
	_age += delta
	if _age >= HOLD_SECONDS + FADE_SECONDS:
		_age = -1.0
		_card.visible = false
		return
	# 크기: 튀어나오기(0.75 → 1.08 → 1.0). 투명도: 머문 뒤 흐려진다.
	var pop: float = clampf(_age / POP_SECONDS, 0.0, 1.0)
	var size: float = lerpf(0.75, 1.0, pop) + sin(pop * PI) * 0.08
	_card.modulate.a = 1.0 - clampf((_age - HOLD_SECONDS) / FADE_SECONDS, 0.0, 1.0)
	_shake = maxf(_shake - delta * 3.0, 0.0)
	var screen: Vector2 = _card.get_viewport_rect().size
	_card.reset_size()
	_card.pivot_offset = _card.size / 2.0
	_card.scale = Vector2.ONE * size
	_card.position = Vector2(screen.x / 2.0, screen.y * SCREEN_Y) - _card.size / 2.0 + Vector2(sin(_age * 60.0) * 14.0 * _shake, 0.0)
