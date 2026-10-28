extends RefCounted
## 감정표현(T) 8가지: 그림(코드로 그리는 얼굴·기호)과 짧은 효과음(수학식 합성, 녹음 파일 없음 → 저작권 걱정 없음).
## 그림은 피자판(ui/emote_wheel.gd)과 머리 위 말풍선(fx/emote_bubble.gd)이 같은 함수로 그린다.
## 2026-10-28 사용자 기획: "소리가 나는 이모티콘, 간단한 효과음만". 종류·순서·소리는 시연값(팀 확정 전).

const CardFaces = preload("res://game/card_round/cards/card_faces.gd")

## 피자판 순서(0 = 맨 위, 시계 방향). name = 피자판·알림 글.
const EMOTES: Array[Dictionary] = [
	{"name": "ㅋㅋㅋ"},
	{"name": "최고!"},
	{"name": "으악!"},
	{"name": "흑흑"},
	{"name": "헉!"},
	{"name": "메롱~"},
	{"name": "좋아해"},
	{"name": "GG"},
]
const COUNT: int = 8

## 효과음 조각: [시작 Hz, 끝 Hz(0 = 쉼), 초, 파형(0 사인·1 네모·2 톱니), 떨림 Hz]. 이어 붙여 한 소리가 된다.
const SOUNDS: Array = [
	[[520, 560, 0.08, 1, 0], [0, 0, 0.03, 0, 0], [600, 640, 0.08, 1, 0], [0, 0, 0.03, 0, 0], [690, 740, 0.11, 1, 0]],
	[[784, 784, 0.08, 0, 0], [1047, 1047, 0.2, 0, 0]],
	[[150, 105, 0.34, 2, 14]],
	[[620, 330, 0.5, 0, 7]],
	[[380, 1250, 0.18, 0, 0]],
	[[440, 440, 0.07, 1, 0], [330, 330, 0.07, 1, 0], [440, 440, 0.07, 1, 0], [330, 330, 0.12, 1, 0]],
	[[523, 523, 0.09, 0, 0], [659, 659, 0.09, 0, 0], [784, 784, 0.24, 0, 5]],
	[[392, 392, 0.09, 1, 0], [523, 523, 0.09, 1, 0], [784, 784, 0.28, 1, 0]],
]
const SAMPLE_RATE: int = 22050

const FACE := Color("ffd34d")
const INK := Color("3a2418")
const BLUSH := Color("ff8f7a")

static var _sounds: Dictionary = {}


## 감정 이름(피자판·알림).
static func emote_name(index: int) -> String:
	return str(EMOTES[index].name)


## index 감정을 canvas 에 그린다. center = 가운데, radius = 얼굴 반지름(장식은 1.3배까지 나간다).
## Control 의 draw 신호(그리는 순간)에서만 부른다.
static func draw(canvas: CanvasItem, index: int, center: Vector2, radius: float) -> void:
	var u: float = radius
	match index:
		0:
			_face(canvas, center, u, FACE)
			for side in [-1.0, 1.0]:
				canvas.draw_arc(center + Vector2(side * 0.35 * u, -0.12 * u), 0.16 * u, PI * 1.1, PI * 1.9, 12, INK, 0.09 * u, true)
			_half_disc(canvas, center + Vector2(0, 0.12 * u), 0.45 * u, Color("7a2a2a"))
			canvas.draw_circle(center + Vector2(0, 0.42 * u), 0.14 * u, Color("ff8a9a"))
			_cheeks(canvas, center, u)
		1:
			_face(canvas, center, u, Color("5cc46a"))
			canvas.draw_rect(Rect2(center + Vector2(-0.52 * u, -0.02 * u), Vector2(0.18 * u, 0.52 * u)), Color("3b6fb6"))
			canvas.draw_rect(Rect2(center + Vector2(-0.34 * u, -0.05 * u), Vector2(0.62 * u, 0.52 * u)), Color.WHITE)
			canvas.draw_rect(Rect2(center + Vector2(-0.12 * u, -0.56 * u), Vector2(0.24 * u, 0.56 * u)), Color.WHITE)
			canvas.draw_circle(center + Vector2(0, -0.56 * u), 0.12 * u, Color.WHITE)
			for i in range(3):
				var y: float = (0.1 + 0.13 * i) * u
				canvas.draw_line(center + Vector2(-0.05 * u, y), center + Vector2(0.27 * u, y), Color("c9d3cf"), 0.04 * u)
		2:
			_face(canvas, center, u, Color("ff6b4a"))
			for side in [-1.0, 1.0]:
				canvas.draw_line(center + Vector2(side * 0.58 * u, -0.44 * u), center + Vector2(side * 0.14 * u, -0.22 * u), INK, 0.12 * u)
				canvas.draw_circle(center + Vector2(side * 0.3 * u, -0.06 * u), 0.09 * u, INK)
				canvas.draw_circle(center + Vector2(side * 0.82 * u, -0.86 * u), 0.13 * u, Color(1, 1, 1, 0.85))
				canvas.draw_circle(center + Vector2(side * 1.02 * u, -0.66 * u), 0.08 * u, Color(1, 1, 1, 0.7))
			canvas.draw_arc(center + Vector2(0, 0.56 * u), 0.3 * u, PI * 1.15, PI * 1.85, 12, INK, 0.1 * u, true)
		3:
			_face(canvas, center, u, Color("ffd96b"))
			for side in [-1.0, 1.0]:
				canvas.draw_line(center + Vector2(side * 0.52 * u, -0.34 * u), center + Vector2(side * 0.18 * u, -0.46 * u), INK, 0.08 * u)
				canvas.draw_arc(center + Vector2(side * 0.33 * u, -0.14 * u), 0.14 * u, PI * 0.1, PI * 0.9, 10, INK, 0.08 * u, true)
				canvas.draw_rect(Rect2(center + Vector2(side * 0.33 * u - 0.07 * u, -0.02 * u), Vector2(0.14 * u, 0.82 * u)), Color(0.43, 0.78, 1.0, 0.9))
			canvas.draw_arc(center + Vector2(0, 0.6 * u), 0.22 * u, PI * 1.15, PI * 1.85, 12, INK, 0.08 * u, true)
		4:
			_face(canvas, center, u, FACE)
			for side in [-1.0, 1.0]:
				canvas.draw_circle(center + Vector2(side * 0.33 * u, -0.15 * u), 0.18 * u, Color.WHITE)
				canvas.draw_circle(center + Vector2(side * 0.33 * u, -0.13 * u), 0.08 * u, INK)
				canvas.draw_arc(center + Vector2(side * 0.33 * u, -0.38 * u), 0.16 * u, PI * 1.2, PI * 1.8, 8, INK, 0.06 * u, true)
			canvas.draw_circle(center + Vector2(0, 0.4 * u), 0.17 * u, Color("7a2a2a"))
			canvas.draw_rect(Rect2(center + Vector2(0.86 * u, -1.12 * u), Vector2(0.15 * u, 0.42 * u)), Color("ff5a3c"))
			canvas.draw_circle(center + Vector2(0.935 * u, -0.56 * u), 0.08 * u, Color("ff5a3c"))
		5:
			_face(canvas, center, u, FACE)
			canvas.draw_line(center + Vector2(-0.5 * u, -0.14 * u), center + Vector2(-0.18 * u, -0.14 * u), INK, 0.09 * u)
			canvas.draw_circle(center + Vector2(0.33 * u, -0.14 * u), 0.1 * u, INK)
			canvas.draw_line(center + Vector2(-0.34 * u, 0.24 * u), center + Vector2(0.36 * u, 0.24 * u), INK, 0.08 * u)
			canvas.draw_rect(Rect2(center + Vector2(-0.02 * u, 0.24 * u), Vector2(0.3 * u, 0.2 * u)), Color("ff7a8c"))
			canvas.draw_circle(center + Vector2(0.13 * u, 0.44 * u), 0.15 * u, Color("ff7a8c"))
			canvas.draw_line(center + Vector2(0.13 * u, 0.28 * u), center + Vector2(0.13 * u, 0.46 * u), Color("d94f66"), 0.04 * u)
			_cheeks(canvas, center, u)
		6:
			var red := Color("ff4d6a")
			for side in [-1.0, 1.0]:
				canvas.draw_circle(center + Vector2(side * 0.32 * u, -0.2 * u), 0.4 * u, red)
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-0.7 * u, -0.07 * u), center + Vector2(0.7 * u, -0.07 * u), center + Vector2(0, 0.82 * u)]), red)
			canvas.draw_circle(center + Vector2(-0.42 * u, -0.34 * u), 0.1 * u, Color(1, 1, 1, 0.75))
		7:
			_face(canvas, center, u, Color("e2c477"))
			canvas.draw_arc(center, 0.8 * u, 0.0, TAU, 40, Color("b18a3c"), 0.06 * u, true)
			var font: Font = CardFaces.bold_font()
			var size: int = int(0.78 * u)
			var width: float = font.get_string_size("GG", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			canvas.draw_string(font, center + Vector2(-width * 0.5, 0.28 * u), "GG", HORIZONTAL_ALIGNMENT_LEFT, -1, size, INK)


## index 감정의 효과음(처음 한 번 만들고 다시 쓴다).
static func sound(index: int) -> AudioStreamWAV:
	if _sounds.has(index):
		return _sounds[index]
	var samples := PackedFloat32Array()
	for part: Array in SOUNDS[index]:
		var count: int = int(SAMPLE_RATE * float(part[2]))
		var phase: float = 0.0
		for i in range(count):
			var ratio: float = float(i) / count
			var value: float = 0.0
			if float(part[0]) > 0.0:
				var hz: float = lerpf(float(part[0]), float(part[1]), ratio) * (1.0 + 0.04 * sin(TAU * float(part[4]) * i / SAMPLE_RATE))
				phase = fmod(phase + hz / SAMPLE_RATE, 1.0)
				match int(part[3]):
					1:
						value = 0.55 if phase < 0.5 else -0.55
					2:
						value = (phase * 2.0 - 1.0) * 0.7
					_:
						value = sin(TAU * phase)
				# 조각마다 짧게 커졌다가 끝에서 줄어드는 소리 모양(딸깍 소리 방지).
				value *= minf(1.0, i / (SAMPLE_RATE * 0.006)) * pow(1.0 - ratio, 0.6)
			samples.append(value * 0.3)
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.data = data
	_sounds[index] = wav
	return wav


## 동그란 얼굴 바탕 + 테두리.
static func _face(canvas: CanvasItem, center: Vector2, u: float, color: Color) -> void:
	canvas.draw_circle(center, u, color)
	canvas.draw_arc(center, u, 0.0, TAU, 48, color.darkened(0.35), 0.07 * u, true)


## 아래쪽 반원(웃는 입).
static func _half_disc(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(17):
		var angle: float = PI * i / 16.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	canvas.draw_colored_polygon(points, color)


## 볼 터치(발그레).
static func _cheeks(canvas: CanvasItem, center: Vector2, u: float) -> void:
	for side in [-1.0, 1.0]:
		canvas.draw_circle(center + Vector2(side * 0.6 * u, 0.18 * u), 0.12 * u, Color(BLUSH, 0.55))
