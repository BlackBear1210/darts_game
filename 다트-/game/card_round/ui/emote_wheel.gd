extends CanvasLayer
## 감정표현 피자판(T). 화면 가운데에 8칸 원판이 뜨고, 마우스가 가는 방향의 칸이 밝아진다.
##   T 를 누른 채 방향 선택 후 떼기/왼클릭 = 실행 · 짧게 톡 누르기 = 메뉴 유지 · Esc = 취소.
## 열려 있는 동안만 마우스 포인터가 보인다(2026-10-28 사용자 기획: 포인터는 T·Esc 때만). 마우스 모드는 local_input.gd 가 바꾼다.
## 내가 보낸 감정은 화면 아래쪽에 잠깐 크게 보여 준다(내 머리 위 말풍선은 내 화면에서 안 보이므로).

## 칸을 골랐다: 0~7 이모티콘, 8~14 수신 모션, 15 중지.
signal chosen(index: int)
## 피자판이 닫혔다(골랐든 안 골랐든) → 마우스를 다시 잡는다.
signal closed

const EmoteArt = preload("res://game/card_round/fx/emote_art.gd")
const CardFaces = preload("res://game/card_round/cards/card_faces.gd")
const MotionEmotes = preload("res://art/characters/motion_emotes.gd")

enum Page { EMOJI, MOTION }

## 원판 크기(px, 1920×1080 기준), 가운데 빈 곳(이 안이면 아무것도 안 고른 것), 고른 칸이 튀어나오는 정도.
const OUTER: float = 300.0
const INNER: float = 88.0
const LIFT: float = 20.0
## 선택 없이 이 시간 안에 T 를 떼면 메뉴를 유지해 클릭으로 고를 수 있다(초).
const TAP_SECONDS: float = 0.25
## 내 감정을 화면 아래에 보여 주는 시간(초).
const MINE_SECONDS: float = 1.8
## 내 감정 그림의 세로 자리(화면 높이 비율)와 크기(px).
## 2026-11-08 사용자 지적 "감정표현 이모지가 아래 UI 를 가린다": 예전 자리(바닥에서 210px)는 F5 라운지의
## 준비 칩 줄(바닥 ~140px)·키 안내와 겹쳤다 → 조준점(0.5)과 아래 UI 사이 빈 띠(0.64)로 올리고 조금 줄였다.
## 경기 중에도 이 띠는 비어 있다(손 카드 부채 = 왼쪽 아래, 안내 띠 = 바닥 ~130px).
const MINE_HEIGHT_RATIO: float = 0.64
const MINE_SIZE: float = 44.0

## 열려 있는가.
var is_open: bool = false
## 지금 밝게 고른 칸(-1 = 없음).
var highlighted: int = -1
var page: Page = Page.EMOJI

var _pad: Control
var _opened_at: float = 0.0
var _time: float = 0.0
var _mine: int = -1
var _mine_at: float = -INF
var _notice: String = ""
var _notice_at: float = -INF
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
	if is_open and _fixed >= 0:
		highlighted = _fixed
	if is_open or _time - _mine_at < MINE_SECONDS + 0.1 or _time - _notice_at < MINE_SECONDS + 0.1:
		_pad.queue_redraw()


func _input(event: InputEvent) -> void:
	if is_open and event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		page = Page.MOTION if page == Page.EMOJI else Page.EMOJI
		_fixed = -1
		_pad.queue_redraw()
		get_viewport().set_input_as_handled()
		return
	# 앱의 전역 Esc 설정 창보다 열린 메뉴 취소를 먼저 처리한다.
	if is_open and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
		return
	# 움직임과 키 떼기가 같은 프레임에 와도 마지막 마우스 이벤트를 즉시 반영한다.
	# 열릴 때의 포인터 중앙 이동이 OS에 반영되기 전에는 선택 없음(-1)을 유지한다.
	if is_open and _fixed < 0 and event is InputEventMouseMotion:
		highlighted = slice_at((event as InputEventMouseMotion).position - _center())


## 연다(마우스는 부르는 쪽이 보이게 하고 가운데로 옮긴다).
func open() -> void:
	is_open = true
	highlighted = -1
	_fixed = -1
	page = Page.EMOJI
	_opened_at = _time
	_pad.queue_redraw()


## 짧게 톡 누르고 선택하지 않았으면 열린 채로 둔다. 나머지는 선택 후 닫거나 취소한다.
func release_key() -> void:
	if not is_open:
		return
	if _time - _opened_at < TAP_SECONDS and highlighted < 0:
		return
	pick()


## 지금 밝은 칸을 보내고 닫는다(왼클릭 · T 떼기).
func pick() -> void:
	if not is_open:
		return
	var index: int = _fixed if _fixed >= 0 else highlighted
	close()
	if index >= 0:
		chosen.emit(index + (EmoteArt.COUNT if page == Page.MOTION else 0))


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


func show_notice(text: String) -> void:
	_notice = text
	_notice_at = _time


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
		var size: float = MINE_SIZE * (lerpf(0.3, 1.15, pop) if pop < 1.0 else lerpf(1.15, 1.0, clampf((age - 0.18) / 0.1, 0.0, 1.0)))
		var at := Vector2(_pad.size.x * 0.5, _pad.size.y * MINE_HEIGHT_RATIO - sin(age * 5.0) * 4.0)
		_pad.draw_circle(at, size * 1.35, Color(1.0, 0.97, 0.92, 0.92 * clampf((MINE_SECONDS - age) / 0.35, 0.0, 1.0)))
		EmoteArt.draw(_pad, _mine, at, size)
	if not is_open and _time - _notice_at < MINE_SECONDS:
		_text(_notice, Vector2(_pad.size.x * 0.5, _pad.size.y * 0.25), 24, PubTheme.PAPER)


func _text(text: String, at: Vector2, size: int, color: Color) -> void:
	var font: Font = CardFaces.bold_font()
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var origin := at - Vector2(width * 0.5, 0)
	_pad.draw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, PubTheme.INK)
	_pad.draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


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
		if page == Page.EMOJI:
			EmoteArt.draw(_pad, i, icon_at, 44.0 if lit else 36.0)
		else:
			_draw_motion(i, icon_at, 38.0 if lit else 32.0, PubTheme.INK if lit else PubTheme.PAPER)
		var label: String = EmoteArt.emote_name(i) if page == Page.EMOJI else MotionEmotes.label(i)
		var font_size: int = 26 if lit else 22
		var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		_pad.draw_string(font, icon_at + Vector2(-width * 0.5, 72), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
			PubTheme.INK if lit else PubTheme.PAPER)
	_pad.draw_circle(center, INNER - 6.0, Color(PubTheme.INK, 0.9))
	var hint: String = "이모티콘" if page == Page.EMOJI else "모션"
	if highlighted >= 0:
		hint = EmoteArt.emote_name(highlighted) if page == Page.EMOJI else MotionEmotes.label(highlighted)
	var hint_size: int = 22
	var hint_width: float = font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_size).x
	_pad.draw_string(font, center + Vector2(-hint_width * 0.5, 9), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_size, PubTheme.GOLD)
	_text("이모티콘  1 / 2" if page == Page.EMOJI else "모션  2 / 2", center + Vector2(0, -OUTER - 35), 28, PubTheme.GOLD)
	_text("마우스 휠: 페이지 전환  ·  T 떼기 / 클릭: 선택  ·  Esc: 닫기", center + Vector2(0, OUTER + 46), 20, PubTheme.PAPER)
	if page == Page.MOTION:
		_text("WASD 이동 가능  ·  점프 / 조준하면 중지", center + Vector2(0, -OUTER - 10), 18, PubTheme.PAPER)


## 작은 몸짓 그림. 원본 애니메이션을 새로 해석하지 않고 메뉴에서 구별하기 위한 표식이다.
func _draw_motion(index: int, at: Vector2, size: float, color: Color) -> void:
	if index == MotionEmotes.STOP:
		_pad.draw_rect(Rect2(at - Vector2.ONE * size * 0.55, Vector2.ONE * size * 1.1), color)
		return
	_pad.draw_circle(at + Vector2(0, -size * 0.75), size * 0.23, color)
	var raised: bool = index in [0, 1, 3, 4]
	var arm_y: float = -0.9 if raised else 0.15
	var points := PackedVector2Array([at + Vector2(-0.7, arm_y) * size,
		at + Vector2(0, -0.3) * size, at + Vector2(0.7, -0.6 if index == 2 else arm_y) * size])
	_pad.draw_polyline(points, color, 5.0, true)
	_pad.draw_line(at + Vector2(0, -0.4) * size, at + Vector2(0, 0.35) * size, color, 5.0, true)
	_pad.draw_polyline(PackedVector2Array([at + Vector2(-0.55, 0.9) * size,
		at + Vector2(0, 0.35) * size, at + Vector2(0.6, 0.55 if index == 6 else 0.9) * size]), color, 5.0, true)
