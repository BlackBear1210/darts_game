extends Control
## 버튼·카드에 붙는 작은 아이콘. art/ui/icons/<name>.png(디자인 요청서로 받을 그림)가 있으면 그 그림을,
## 없으면 같은 뜻의 단순한 도형을 코드로 그린다(임시안). 클릭은 통과시킨다(부모 버튼이 받는다).
##
## 이름: single(혼자·과녁) multi(여럿) settings(톱니) exit(문) login(사람) back(화살표)
##       casual(책) party(폭죽) classic(과녁) pub(맥주잔) arcade(조이스틱) copy(겹친 종이) lock(자물쇠)
## 킬로그(경기 로그) 아이콘: dart(다트) card(카드) bottle(병) broken(깨짐) cue(큐대) plush(인형) capsule(캡슐)
##       hoop(농구공) dizzy(어질) drink(한 모금) claw(집게) trophy(트로피)

const Style = preload("res://ui/lounge_style.gd")

var icon_name: String = "single"
var tint: Color = Style.INK
var _texture: Texture2D


static func make(icon_id: String, side: float = 44.0, color: Color = Style.INK) -> Control:
	var icon: Control = (load("res://ui/ui_icon.gd") as GDScript).new()
	icon.icon_name = icon_id
	icon.tint = color
	icon.custom_minimum_size = Vector2(side, side)
	return icon


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path := "res://art/ui/icons/%s.png" % icon_name
	if ResourceLoader.exists(path):
		_texture = load(path) as Texture2D


func _draw() -> void:
	if _texture != null:
		draw_texture_rect(_texture, Rect2(Vector2.ZERO, size), false)
		return
	var s := minf(size.x, size.y)
	var c := size * 0.5
	var w := maxf(2.5, s * 0.08)
	var ink := tint
	match icon_name:
		"single", "classic":
			for ring in range(3):
				draw_arc(c, s * (0.44 - ring * 0.14), 0, TAU, 32, ink, w, true)
			draw_circle(c, s * 0.07, Style.PINK if icon_name == "single" else ink)
		"multi":
			for index in range(3):
				var x := c.x + (index - 1) * s * 0.28
				var y := c.y + (0.0 if index == 1 else s * 0.06)
				draw_circle(Vector2(x, y - s * 0.16), s * 0.12, ink)
				draw_arc(Vector2(x, y + s * 0.26), s * 0.18, PI, TAU, 16, ink, w * 1.6, true)
		"settings":
			for tooth in range(8):
				var angle := TAU * tooth / 8.0
				draw_line(c + Vector2.from_angle(angle) * s * 0.22, c + Vector2.from_angle(angle) * s * 0.44, ink, w * 2.0)
			draw_circle(c, s * 0.3, ink)
			draw_circle(c, s * 0.13, Style.CREAM if ink == Style.INK else Style.PANEL)
		"exit":
			draw_rect(Rect2(c.x - s * 0.36, c.y - s * 0.42, s * 0.42, s * 0.84), ink, false, w)
			draw_line(c + Vector2(-s * 0.05, 0), c + Vector2(s * 0.42, 0), ink, w)
			draw_line(c + Vector2(s * 0.42, 0), c + Vector2(s * 0.26, -s * 0.15), ink, w)
			draw_line(c + Vector2(s * 0.42, 0), c + Vector2(s * 0.26, s * 0.15), ink, w)
		"login":
			draw_circle(c + Vector2(0, -s * 0.14), s * 0.17, ink)
			draw_arc(c + Vector2(0, s * 0.36), s * 0.3, PI, TAU, 16, ink, w * 2.2, true)
		"back":
			draw_line(c + Vector2(s * 0.36, 0), c + Vector2(-s * 0.32, 0), ink, w * 1.4)
			draw_line(c + Vector2(-s * 0.36, 0), c + Vector2(-s * 0.08, -s * 0.26), ink, w * 1.4)
			draw_line(c + Vector2(-s * 0.36, 0), c + Vector2(-s * 0.08, s * 0.26), ink, w * 1.4)
		"casual":
			draw_rect(Rect2(c.x - s * 0.4, c.y - s * 0.3, s * 0.38, s * 0.6), ink, false, w)
			draw_rect(Rect2(c.x + s * 0.02, c.y - s * 0.3, s * 0.38, s * 0.6), ink, false, w)
			draw_string(Style.font("logo"), Vector2(c.x - s * 0.34, c.y + s * 0.14), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, int(s * 0.42), ink)
			draw_string(Style.font("logo"), Vector2(c.x + s * 0.09, c.y + s * 0.14), "×", HORIZONTAL_ALIGNMENT_LEFT, -1, int(s * 0.42), ink)
		"party":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.4, s * 0.42), c + Vector2(-s * 0.1, -s * 0.18), c + Vector2(s * 0.2, s * 0.12)]), ink)
			for spark in [Vector2(0.1, -0.4), Vector2(0.38, -0.2), Vector2(0.3, -0.42), Vector2(0.42, 0.06)]:
				draw_circle(c + spark * s, s * 0.06, [Style.PINK, Style.MINT, Style.GOLD, ink][int(spark.x * 10) % 4])
		"pub":
			draw_rect(Rect2(c.x - s * 0.32, c.y - s * 0.3, s * 0.46, s * 0.68), ink, false, w)
			draw_arc(c + Vector2(s * 0.16, s * 0.04), s * 0.16, -PI * 0.5, PI * 0.5, 12, ink, w, true)
			draw_rect(Rect2(c.x - s * 0.32, c.y - s * 0.38, s * 0.46, s * 0.14), ink)
		"arcade":
			draw_rect(Rect2(c.x - s * 0.42, c.y + s * 0.12, s * 0.84, s * 0.28), ink)
			draw_line(c + Vector2(-s * 0.12, s * 0.14), c + Vector2(-s * 0.12, -s * 0.22), ink, w)
			draw_circle(c + Vector2(-s * 0.12, -s * 0.26), s * 0.12, Style.PINK)
			draw_circle(c + Vector2(s * 0.2, s * 0.04), s * 0.08, Style.MINT)
		"copy":
			draw_rect(Rect2(c.x - s * 0.3, c.y - s * 0.38, s * 0.48, s * 0.58), ink, false, w)
			draw_rect(Rect2(c.x - s * 0.14, c.y - s * 0.2, s * 0.48, s * 0.58), ink, false, w)
		"lock":
			draw_rect(Rect2(c.x - s * 0.3, c.y - s * 0.04, s * 0.6, s * 0.44), ink)
			draw_arc(c + Vector2(0, -s * 0.06), s * 0.2, PI, TAU, 12, ink, w, true)
		"dart":
			draw_line(c + Vector2(-s * 0.42, s * 0.42), c + Vector2(s * 0.18, -s * 0.18), ink, w * 1.3)
			draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.12, -s * 0.12), c + Vector2(s * 0.44, -s * 0.2), c + Vector2(s * 0.2, -s * 0.44)]), Style.PINK)
			draw_circle(c + Vector2(-s * 0.42, s * 0.42), s * 0.05, ink)
		"card":
			draw_set_transform(c, -0.18)
			draw_rect(Rect2(-s * 0.26, -s * 0.36, s * 0.52, s * 0.72), ink, false, w)
			draw_circle(Vector2.ZERO, s * 0.1, Style.GOLD)
			draw_set_transform(Vector2.ZERO)
		"bottle":
			draw_rect(Rect2(c.x - s * 0.17, c.y - s * 0.08, s * 0.34, s * 0.5), ink)
			draw_rect(Rect2(c.x - s * 0.07, c.y - s * 0.42, s * 0.14, s * 0.36), ink)
			draw_rect(Rect2(c.x - s * 0.12, c.y + s * 0.06, s * 0.24, s * 0.14), Style.MINT)
		"broken":
			for index in range(7):
				var angle := TAU * index / 7.0 + 0.3
				var tip := c + Vector2.from_angle(angle) * s * 0.44
				draw_colored_polygon(PackedVector2Array([c + Vector2.from_angle(angle - 0.25) * s * 0.12, tip, c + Vector2.from_angle(angle + 0.25) * s * 0.12]), ink if index % 2 == 0 else Style.MINT)
		"cue":
			draw_line(c + Vector2(-s * 0.44, s * 0.36), c + Vector2(s * 0.36, -s * 0.4), ink, w * 1.2)
			draw_circle(c + Vector2(s * 0.3, s * 0.3), s * 0.12, Style.PINK)
		"plush":
			draw_circle(c + Vector2(0, s * 0.08), s * 0.3, ink)
			draw_circle(c + Vector2(-s * 0.24, -s * 0.24), s * 0.12, ink)
			draw_circle(c + Vector2(s * 0.24, -s * 0.24), s * 0.12, ink)
			draw_circle(c + Vector2(-s * 0.1, s * 0.02), s * 0.04, Style.CREAM)
			draw_circle(c + Vector2(s * 0.1, s * 0.02), s * 0.04, Style.CREAM)
		"capsule":
			draw_arc(c, s * 0.36, PI, TAU, 18, Style.PINK, s * 0.2, true)
			draw_arc(c, s * 0.36, 0, PI, 18, ink, s * 0.2, true)
			draw_line(c + Vector2(-s * 0.46, 0), c + Vector2(s * 0.46, 0), ink, w)
		"hoop":
			draw_circle(c, s * 0.4, Color("f08a3c"))
			draw_arc(c, s * 0.4, 0, TAU, 24, ink, w, true)
			draw_line(c + Vector2(-s * 0.4, 0), c + Vector2(s * 0.4, 0), ink, w * 0.7)
			draw_line(c + Vector2(0, -s * 0.4), c + Vector2(0, s * 0.4), ink, w * 0.7)
		"dizzy":
			for index in range(3):
				var at := c + Vector2.from_angle(TAU * index / 3.0 - PI / 2) * s * 0.26
				_star(at, s * 0.17, Style.GOLD)
		"drink":
			draw_rect(Rect2(c.x - s * 0.26, c.y - s * 0.26, s * 0.4, s * 0.62), ink, false, w)
			draw_rect(Rect2(c.x - s * 0.26, c.y - s * 0.02, s * 0.4, s * 0.38), Style.GOLD)
			draw_arc(c + Vector2(s * 0.14, s * 0.06), s * 0.16, -PI * 0.5, PI * 0.5, 12, ink, w, true)
		"claw":
			draw_line(c + Vector2(0, -s * 0.46), c + Vector2(0, -s * 0.1), ink, w)
			draw_rect(Rect2(c.x - s * 0.14, c.y - s * 0.14, s * 0.28, s * 0.12), ink)
			for side in [-1.0, 1.0]:
				draw_line(c + Vector2(side * s * 0.1, -s * 0.04), c + Vector2(side * s * 0.32, s * 0.2), ink, w)
				draw_line(c + Vector2(side * s * 0.32, s * 0.2), c + Vector2(side * s * 0.14, s * 0.42), ink, w)
		"trophy":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.3, -s * 0.38), c + Vector2(s * 0.3, -s * 0.38), c + Vector2(s * 0.18, s * 0.06), c + Vector2(-s * 0.18, s * 0.06)]), Style.GOLD)
			draw_rect(Rect2(c.x - s * 0.06, c.y + s * 0.04, s * 0.12, s * 0.2), Style.GOLD)
			draw_rect(Rect2(c.x - s * 0.24, c.y + s * 0.24, s * 0.48, s * 0.12), ink)
		_:
			draw_circle(c, s * 0.3, ink)


func _star(at: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(10):
		points.append(at + Vector2.from_angle(TAU * index / 10.0 - PI / 2) * (radius if index % 2 == 0 else radius * 0.45))
	draw_colored_polygon(points, color)
