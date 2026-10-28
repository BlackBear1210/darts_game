extends RefCounted
## 카드 앞면·뒷면 텍스처. 팀 그림이 있는 카드(art/cards/)는 그 그림을 쓰고, 없는 카드는 같은 틀
## (크림 테두리 · 종류 색 바탕 · 왼쪽 위/오른쪽 아래 종류 원 · 가운데 큰 글자 · 아래 이름판)을
## 실행 중에 Control 로 그려 한 번만 텍스처로 굽는다. 글자는 코드에 있어 이미지 파일에 굽지 않는다는 디자인 규칙과 맞다.
## 화면이 없는 시험(headless)에서는 종류 색 단색으로 대신한다.

const CardCatalog = preload("res://game/card_round/rules/card_catalog.gd")

## 카드 그림 크기(px). 카드 비율 2:3(0.096 × 0.144m)과 같다.
const SIZE := Vector2i(400, 600)
const CREAM := Color("f3e9d2")
const BACK_RED := Color("7d2a26")
const BRASS := Color("d7bb7f")

static var _faces: Dictionary = {}
static var _back: Texture2D
static var _bold: SystemFont


## 굵은 한글 글꼴(윈도우 맑은 고딕 → 없으면 시스템 기본). HUD 제목도 같이 쓴다.
static func bold_font() -> Font:
	if _bold == null:
		_bold = SystemFont.new()
		_bold.font_names = PackedStringArray(["Malgun Gothic", "Apple SD Gothic Neo", "Noto Sans CJK KR", "sans-serif"])
		_bold.font_weight = 800
	return _bold


## 카드 종류의 앞면 그림. 굽기(bake) 전이면 분류 색 단색 그림을 임시로 돌려준다.
static func face(type: int) -> Texture2D:
	if not _faces.has(type):
		_faces[type] = _solid(CardCatalog.color(type))
	return _faces[type]


## 카드 뒷면 그림. 굽기(bake) 전이면 뒷면 빨강 단색 그림을 임시로 돌려준다.
static func back() -> Texture2D:
	if _back == null:
		_back = _solid(BACK_RED)
	return _back


## host 아래에 SubViewport 를 잠깐 만들어 그린 뒤 텍스처로 바꾼다. 이미 구웠으면 바로 끝난다.
static func bake(host: Node) -> void:
	if _back != null:
		return
	var jobs: Dictionary = {}
	for type in range(CardCatalog.count()):
		var art: String = CardCatalog.card(type).art
		if not art.is_empty():
			_faces[type] = load(art)
		else:
			jobs[type] = _viewport(host, _draw_face(type))
	jobs[-1] = _viewport(host, _draw_back())
	var headless: bool = DisplayServer.get_name() == "headless"
	if not headless:
		# 추가한 프레임에 그려지고, 그다음 프레임에 읽는다.
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
	for key: int in jobs:
		var viewport: SubViewport = jobs[key]
		var texture: Texture2D = null
		if not headless:
			var image: Image = viewport.get_texture().get_image()
			if image != null and not image.is_empty():
				image.generate_mipmaps()
				texture = ImageTexture.create_from_image(image)
		if texture == null:
			texture = _solid(BACK_RED if key < 0 else CardCatalog.color(key))
		if key < 0:
			_back = texture
		else:
			_faces[key] = texture
		viewport.queue_free()


## 그림 한 장을 굽는 화면 밖 캔버스(SubViewport). content 를 담아 host 아래에 잠깐 붙인다.
static func _viewport(host: Node, content: Control) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.add_child(content)
	host.add_child(viewport)
	return viewport


## 팀 카드 그림과 같은 틀. 가운데 큰 글자(+10, ×0 …)가 그림 대신이다.
static func _draw_face(type: int) -> Control:
	var data: Dictionary = CardCatalog.card(type)
	var tint: Color = CardCatalog.color(type)
	var root := _panel(Vector2.ZERO, Vector2(SIZE), CREAM, 24)
	var inner := _panel(Vector2(20, 20), Vector2(360, 560), tint, 16, tint.darkened(0.35), 4)
	root.add_child(inner)
	# 바탕 무늬: 비스듬한 옅은 줄(종이 질감 대신).
	var stripes := Pattern.new()
	stripes.color = Color(1, 1, 1, 0.05)
	stripes.gap = 34.0
	stripes.size = inner.size
	inner.add_child(stripes)
	inner.clip_contents = true
	root.add_child(_badge(Vector2(14, 14), 124, tint, CardCatalog.category_name(type), 30))
	root.add_child(_badge(Vector2(270, 414), 104, tint, CardCatalog.category_name(type), 26))
	var big := _text(str(data.big), 150 if str(data.big).length() <= 3 else 120, CREAM, tint.darkened(0.55), 14)
	big.position = Vector2(20, 150)
	big.size = Vector2(360, 260)
	root.add_child(big)
	var plate := _panel(Vector2(62, 498), Vector2(276, 78), CREAM, 39, tint.darkened(0.2), 3)
	root.add_child(plate)
	var title := _text(str(data.name), 40, tint.darkened(0.35))
	title.size = plate.size
	plate.add_child(title)
	return root


## 트럼프 카드 같은 뒷면: 크림 테두리 · 짙은 빨강 · 놋쇠 격자 · 가운데 D 메달.
static func _draw_back() -> Control:
	var root := _panel(Vector2.ZERO, Vector2(SIZE), CREAM, 24)
	var inner := _panel(Vector2(22, 22), Vector2(356, 556), BACK_RED, 14, BRASS, 5)
	inner.clip_contents = true
	root.add_child(inner)
	var lattice := Pattern.new()
	lattice.color = Color(BRASS, 0.32)
	lattice.gap = 28.0
	lattice.crossed = true
	lattice.size = inner.size
	inner.add_child(lattice)
	var medal := _panel(Vector2(110, 210), Vector2(180, 180), CREAM, 90, BRASS, 6)
	root.add_child(medal)
	var letter := _text("D", 120, BACK_RED)
	letter.size = medal.size
	medal.add_child(letter)
	var brand := _text("DARTY", 34, BRASS, BACK_RED, 8)
	brand.position = Vector2(20, 470)
	brand.size = Vector2(360, 60)
	root.add_child(brand)
	return root


## 둥근 배지(크림색 테두리 + 색 원 + 가운데 글자). 카드 앞면의 분류·숫자 표시에 쓴다.
static func _badge(at: Vector2, diameter: float, tint: Color, text: String, font_size: int) -> Panel:
	var ring := _panel(at, Vector2(diameter, diameter), CREAM, int(diameter / 2))
	var inset: float = diameter * 0.1
	var core := _panel(Vector2(inset, inset), Vector2(diameter - inset * 2, diameter - inset * 2), tint, int(diameter / 2 - inset))
	ring.add_child(core)
	var label := _text(text, font_size, CREAM)
	label.size = core.size
	core.add_child(label)
	return ring


## 둥근 모서리 사각형(채움 색·테두리). 카드 그림의 바탕 조각.
static func _panel(at: Vector2, size: Vector2, fill: Color, radius: int, border := Color.TRANSPARENT, border_width := 0) -> Panel:
	var panel := Panel.new()
	panel.position = at
	panel.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(radius)
	style.corner_detail = 12
	style.anti_aliasing = true
	if border_width > 0:
		style.border_color = border
		style.set_border_width_all(border_width)
	panel.add_theme_stylebox_override("panel", style)
	return panel


## 가운데 정렬 글자(굵은 글꼴, 외곽선 선택).
static func _text(text: String, font_size: int, color: Color, outline := Color.TRANSPARENT, outline_size := 0) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var settings := LabelSettings.new()
	settings.font = bold_font()
	settings.font_size = font_size
	settings.font_color = color
	settings.outline_color = outline
	settings.outline_size = outline_size
	label.label_settings = settings
	return label


## 한 가지 색으로 채운 작은 그림(굽기 전 임시 그림).
static func _solid(color: Color) -> Texture2D:
	var image := Image.create(SIZE.x / 25, SIZE.y / 25, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


## 비스듬한 줄무늬(crossed 면 격자). 카드 바탕 질감과 뒷면 무늬.
class Pattern extends Control:
	var color := Color.WHITE
	var gap := 30.0
	var crossed := false

	func _draw() -> void:
		var x: float = -size.y
		while x < size.x:
			draw_line(Vector2(x, 0), Vector2(x + size.y, size.y), color, 3.0, true)
			if crossed:
				draw_line(Vector2(x + size.y, 0), Vector2(x, size.y), color, 3.0, true)
			x += gap
