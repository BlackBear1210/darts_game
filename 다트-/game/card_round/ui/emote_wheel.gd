extends CanvasLayer
## 감정표현 피자판(T). 화면 가운데에 8칸 원판이 뜨고, 마우스가 가는 방향의 칸이 밝아진다.
##   T 를 누른 채 방향을 고르고 떼면 보낸다 · 왼클릭으로 바로 보낸다 · T 를 짧게 톡 누르면 열린 채로 남는다 · Esc = 닫기.
## 열려 있는 동안만 마우스 포인터가 보인다(2026-10-28 사용자 기획: 포인터는 T·Esc 때만). 마우스 모드는 local_input.gd 가 바꾼다.
## 내가 보낸 감정은 화면 아래쪽에 잠깐 크게 보여 준다(내 머리 위 말풍선은 내 화면에서 안 보이므로).

## 칸을 골랐다(index = fx/emote_art.gd 순서).
signal chosen(index: int)
## 피자판이 닫혔다(골랐든 안 골랐든) → 마우스를 다시 잡는다.
signal closed

const EmoteArt = preload("res://game/card_round/fx/emote_art.gd")
const CardFaces = preload("res://game/card_round/cards/card_faces.gd")

## 원판 크기(px, 1920×1080 기준), 가운데 빈 곳(이 안이면 아무것도 안 고른 것), 고른 칸이 튀어나오는 정도.
const OUTER: float = 300.0
const INNER: float = 88.0
const LIFT: float = 20.0
## 이보다 짧게 T 를 톡 누르고 떼면 열린 채로 둔다(초).
const TAP_SECONDS: float = 0.25
## 내 감정을 화면 아래에 보여 주는 시간(초).
const MINE_SECONDS: float = 1.8

## 열려 있는가.
var is_open: bool = false
## 지금 밝게 고른 칸(-1 = 없음).
var highlighted: int = -1

var _pad: Control
var _opened_at: float = 0.0
var _time: float = 0.0
var _mine: int = -1
var _mine_at: float = -INF
## 화면 캡처 검사 전용: 마우스 대신 이 칸을 밝힌다(-1 = 마우스 방향).
var _fixed: int = -1


func _ready() -> void:
	layer = 11
	_pad = Control.new()
	_pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pad.draw.connect(_draw_pad)
	add_child(_pad)


func _process(delta: float) -> void:
	_time += delta
	if is_open:
		var offset: Vector2 = _pad.get_local_mouse_position() - _center()
		highlighted = _fixed if _fixed >= 0 else slice_at(offset)
	if is_open or _time - _mine_at < MINE_SECONDS + 0.1:
		_pad.queue_redraw()


## 연다(마우스는 부르는 쪽이 보이게 하고 가운데로 옮긴다).
func open() -> void:
	is_open = true
	highlighted = -1
	_fixed = -1
	_opened_at = _time
	_pad.queue_redraw()


## T 를 뗐다: 짧게 톡 눌렀고 아직 아무 칸도 안 골랐으면 열어 둔다. 아니면 고른 칸을 보내고 닫는다.
func release_key() -> void:
	if not is_open:
		return
	if _time - _opened_at < TAP_SECONDS and highlighted < 0:
		return
	pick()


## 지금 밝은 칸을 보내고 닫는다(왼클릭 · T 떼기).
func pick() -> void:
	var index: int = highlighted
	close()
	if index >= 0:
		chosen.emit(index)


## 아무것도 보내지 않고 닫는다.
func close() -> void:
	if not is_open:
		return
	is_open = false
	highlighted = -1
	_pad.queue_redraw()
	closed.emit()


## 화면 캡처 검사 전용(round_capture.gd): 마우스 없이 index 칸을 밝힌 채로 연다.
func preview(index: int) -> void:
	open()
	_fixed = index


## 내가 보낸 감정을 화면 아래에 잠깐 크게 보여 준다.
func show_mine(index: int) -> void:
	_mine = index
	_mine_at = _time


## 가운데에서 offset 만큼 떨어진 곳이 몇 번 칸인가(가운데 빈 곳이면 -1). 0번 = 맨 위, 시계 방향.
static func slice_at(offset: Vector2) -> int:
	if offset.length() < INNER * 0.6:
		return -1
	var angle: float = offset.angle() + PI * 0.5
	return posmod(roundi(angle / (TAU / EmoteArt.COUNT)), EmoteArt.COUNT)


func _center() -> Vector2:
	return _pad.size * 0.5


## 그리기: 열려 있으면 피자판, 내 감정을 막 보냈으면 화면 아래 큰 그림.
func _draw_pad() -> void:
	if is_open:
		_draw_wheel(_center())
	var age: float = _time - _mine_at
	if _mine >= 0 and age < MINE_SECONDS:
		var pop: float = clampf(age / 0.18, 0.0, 1.0)
		var size: float = 52.0 * (lerpf(0.3, 1.15, pop) if pop < 1.0 else lerpf(1.15, 1.0, clampf((age - 0.18) / 0.1, 0.0, 1.0)))
		var at := Vector2(_pad.size.x * 0.5, _pad.size.y - 210.0 - sin(age * 5.0) * 4.0)
		_pad.draw_circle(at, size * 1.35, Color(1.0, 0.97, 0.92, 0.92 * clampf((MINE_SECONDS - age) / 0.35, 0.0, 1.0)))
		EmoteArt.draw(_pad, _mine, at, size)


## 8칸 원판: 칸마다 어두운 바탕 + 그림 + 이름. 고른 칸은 금빛으로 밝고 바깥으로 조금 튀어나온다.
func _draw_wheel(center: Vector2) -> void:
	var step: float = TAU / EmoteArt.COUNT
	var font: Font = CardFaces.bold_font()
	for i in range(EmoteArt.COUNT):
		var lit: bool = i == highlighted
		var middle: float = -PI * 0.5 + i * step
		var outer: float = OUTER + (LIFT if lit else 0.0)
		var points := PackedVector2Array()
		for k in range(13):
			var angle: float = middle - step * 0.5 + step * k / 12.0
			points.append(center + Vector2(cos(angle), sin(angle)) * outer)
		for k in range(12, -1, -1):
			var angle: float = middle - step * 0.5 + step * k / 12.0
			points.append(center + Vector2(cos(angle), sin(angle)) * INNER)
		_pad.draw_colored_polygon(points, Color("f2cf7a", 0.92) if lit else Color(PubTheme.INK, 0.82))
		points.append(points[0])
		_pad.draw_polyline(points, Color(PubTheme.GOLD, 0.9 if lit else 0.45), 3.0 if lit else 1.5, true)
		var icon_at: Vector2 = center + Vector2(cos(middle), sin(middle)) * (INNER + outer) * 0.5 + Vector2(0, -12)
		EmoteArt.draw(_pad, i, icon_at, 44.0 if lit else 36.0)
		var label: String = EmoteArt.emote_name(i)
		var font_size: int = 26 if lit else 22
		var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		_pad.draw_string(font, icon_at + Vector2(-width * 0.5, 72), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
			PubTheme.INK if lit else PubTheme.PAPER)
	_pad.draw_circle(center, INNER - 6.0, Color(PubTheme.INK, 0.9))
	var hint: String = EmoteArt.emote_name(highlighted) if highlighted >= 0 else "감정표현"
	var hint_size: int = 26
	var hint_width: float = font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_size).x
	_pad.draw_string(font, center + Vector2(-hint_width * 0.5, 9), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_size, PubTheme.GOLD)
