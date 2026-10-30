extends Control
## DARTY 제목 로고(코드로 그리는 임시안). 디자인 요청서의 로고 이미지가 art/ui/logo_darty.png 로 들어오면 그 그림을 쓴다.
##
## [모양] 글자마다 다른 자리 색(빨강·금색·청록·파랑·보라 = 네 명이 함께 노는 파티) + 굵은 잉크 외곽선 +
## 아래로 두께가 보이는 "스티커" 입체. 처음 뜰 때 글자가 하나씩 튀어 오르고, 마지막에 다트 한 발이 Y 에 꽂힌다.
## 아래 띠에는 게임 문구를 적는다.

const Style = preload("res://ui/lounge_style.gd")
const LOGO_IMAGE := "res://art/ui/logo_darty.png"
const LETTERS := "DARTY"
const COLORS: Array[Color] = [Color("ff6b5b"), Color("ffc845"), Color("37d9bf"), Color("5aa9e6"), Color("b48be0")]
## 글자마다 살짝 다른 기울기(라디안). 손으로 붙인 스티커처럼 들쭉날쭉하게.
const TILTS: Array[float] = [-0.07, 0.05, -0.03, 0.06, -0.05]
const FONT_SIZE: int = 168
## 아래로 보이는 두께(px).
const DEPTH: int = 12

var tagline: String = "다트를 던져라. 판을 뒤집어라."
var _age: float = 0.0
var _image: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(760, 300)
	if ResourceLoader.exists(LOGO_IMAGE):
		_image = load(LOGO_IMAGE) as Texture2D


## 처음부터 다시 튀어 오르게 한다(로비로 돌아올 때).
func replay() -> void:
	_age = 0.0


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()


func _draw() -> void:
	var center_x := size.x * 0.5
	if _image != null:
		var fit := minf(size.x / _image.get_width(), (size.y - 70.0) / _image.get_height())
		var extent := Vector2(_image.get_size()) * fit
		draw_texture_rect(_image, Rect2(Vector2(center_x - extent.x * 0.5, 0.0), extent), false)
	else:
		_draw_letters(center_x)
	_draw_ribbon(Vector2(center_x, size.y - 42.0))


func _draw_letters(center_x: float) -> void:
	var font: Font = Style.font("logo")
	var widths: Array[float] = []
	var total: float = 0.0
	for letter in LETTERS:
		var width := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x + 8.0
		widths.append(width)
		total += width
	var x := center_x - total * 0.5
	var baseline: float = FONT_SIZE * 0.95
	for index in range(LETTERS.length()):
		# 등장: 글자마다 0.07초씩 늦게 튀어 오른다(1.15배까지 갔다가 1배로).
		var t: float = clampf((_age - index * 0.07) / 0.35, 0.0, 1.0)
		var pop: float = 1.0 + sin(t * PI) * 0.18 if t < 1.0 else 1.0
		var grow: float = ease(t, 0.4) * pop
		var bob: float = sin(_age * 2.2 + index * 0.9) * 3.0
		var origin := Vector2(x + widths[index] * 0.5, baseline + bob)
		draw_set_transform(origin, TILTS[index], Vector2.ONE * grow)
		var offset := Vector2(-widths[index] * 0.5 + 4.0, 0.0)
		var letter: String = LETTERS[index]
		# 두께: 잉크색 글자를 아래로 여러 번 겹쳐 입체처럼 보이게 한다.
		for depth in range(DEPTH, 0, -2):
			draw_string_outline(font, offset + Vector2(0, depth), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 22, Style.INK)
		draw_string_outline(font, offset, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 22, Style.INK)
		draw_string(font, offset, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, COLORS[index])
		# 윗부분 하이라이트(크림색 얇은 띠): 글자 위쪽만 잘라 그리기 어려워 작은 사선 광택 두 줄로 대신한다.
		draw_line(offset + Vector2(widths[index] * 0.22, -FONT_SIZE * 0.62), offset + Vector2(widths[index] * 0.36, -FONT_SIZE * 0.62), Color(Style.CREAM, 0.55), 5.0, true)
		x += widths[index]
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 마지막 글자(Y)에 다트 한 발이 꽂힌다. 꽂힌 순간 꼬리가 떨린다.
	var hit_time: float = 0.75
	if _age > hit_time - 0.12:
		var flight: float = clampf((_age - (hit_time - 0.12)) / 0.12, 0.0, 1.0)
		var tip := Vector2(center_x + total * 0.5 - widths[4] * 0.32, baseline - FONT_SIZE * 0.55)
		var wobble: float = sin((_age - hit_time) * 40.0) * exp(-(_age - hit_time) * 5.0) * 0.12 if _age > hit_time else 0.0
		# 꼬리가 오른쪽 위를 향한다 → 화면 오른쪽 위에서 날아와 Y 에 꽂힌다.
		var angle: float = -0.75 + wobble
		var start := tip + Vector2.from_angle(angle) * 260.0
		_draw_dart(start.lerp(tip, flight), angle)


## 2D 다트 한 개(촉 끝 = at, angle = 촉이 향하는 반대쪽, 즉 꼬리 방향). 로고와 같은 스티커 화법.
func _draw_dart(at: Vector2, angle: float) -> void:
	draw_set_transform(at, angle, Vector2.ONE)
	var ink := Style.INK
	# 촉
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(28, -4), Vector2(28, 4)]), Color("d8dde3"))
	draw_polyline(PackedVector2Array([Vector2(0, 0), Vector2(28, -4), Vector2(28, 4), Vector2(0, 0)]), ink, 3.0, true)
	# 배럴(금색)
	draw_rect(Rect2(26, -8, 48, 16), Style.GOLD)
	draw_rect(Rect2(26, -8, 48, 16), ink, false, 3.0)
	for groove in range(4):
		draw_line(Vector2(34 + groove * 10, -7), Vector2(34 + groove * 10, 7), Color(ink, 0.6), 2.0)
	# 샤프트
	draw_rect(Rect2(72, -4, 46, 8), Color("2b2430"))
	# 깃(빨강 + 크림 줄)
	var flight := PackedVector2Array([Vector2(110, 0), Vector2(150, -30), Vector2(168, -30), Vector2(150, 0), Vector2(168, 30), Vector2(150, 30)])
	draw_colored_polygon(flight, Style.PINK)
	draw_polyline(PackedVector2Array([Vector2(110, 0), Vector2(150, -30), Vector2(168, -30), Vector2(150, 0), Vector2(168, 30), Vector2(150, 30), Vector2(110, 0)]), ink, 3.0, true)
	draw_line(Vector2(128, -12), Vector2(152, -22), Style.CREAM, 3.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 게임 문구 띠: 기울어진 토마토색 띠 + 잉크 테두리 + 단단한 그림자.
func _draw_ribbon(center: Vector2) -> void:
	var font: Font = Style.font("heading")
	var font_size := 30
	var text_width: float = font.get_string_size(tagline, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var half := Vector2(text_width * 0.5 + 34.0, 26.0)
	var appear: float = ease(clampf((_age - 0.45) / 0.3, 0.0, 1.0), 0.4)
	draw_set_transform(center, -0.025, Vector2(appear, 1.0))
	var slant := 14.0
	var body := PackedVector2Array([Vector2(-half.x - slant, -half.y), Vector2(half.x + slant, -half.y), Vector2(half.x - slant, half.y), Vector2(-half.x - slant * 2.0, half.y)])
	var shadow := PackedVector2Array()
	for point in body:
		shadow.append(point + Vector2(0, 7))
	draw_colored_polygon(shadow, Style.INK)
	draw_colored_polygon(body, Style.PINK)
	body.append(body[0])
	draw_polyline(body, Style.INK, 4.0, true)
	if appear > 0.6:
		draw_string_outline(font, Vector2(-text_width * 0.5, 11), tagline, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Style.INK)
		draw_string(font, Vector2(-text_width * 0.5, 11), tagline, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Style.CREAM)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
