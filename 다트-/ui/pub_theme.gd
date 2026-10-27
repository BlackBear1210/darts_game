class_name PubTheme
extends RefCounted
## 화면 UI(경기 HUD·대기실) 공용 색과 모양. 디자인 담당 소유. 3D 펍과 같은 팔레트(기획 2-6)를 쓴다.
## 글자 크기·배치는 각 화면 스크립트가 정하고, 여기서는 색·테두리·막대 모양만 정한다.
## 나중에 폰트(.ttf)나 버튼 이미지(9-slice)가 생기면 여기만 바꾸면 HUD·대기실이 같이 바뀐다.

## 판넬 바탕(짙은 초록) · 테두리·강조(놋쇠) · 기본 글자(크림) · 대기실 배경.
const INK := Color("122b27")
const GOLD := Color("d7bb7f")
const PAPER := Color("f0e6cf")
const BACKGROUND := Color("0d1c19")

static var _theme: Theme


## 테마 하나를 만들어 재사용한다. Control.theme 에 넣으면 그 아래 모든 Label·Button·ProgressBar 에 적용된다.
static func build() -> Theme:
	if _theme != null:
		return _theme
	var theme := Theme.new()
	theme.set_color("font_color", "Label", PAPER)
	for state in ["font_color", "font_focus_color", "font_hover_color"]:
		theme.set_color(state, "Button", PAPER)
	theme.set_color("font_pressed_color", "Button", GOLD)
	theme.set_stylebox("normal", "Button", box(INK, GOLD.darkened(0.35)))
	theme.set_stylebox("hover", "Button", box(INK.lightened(0.12), GOLD))
	theme.set_stylebox("pressed", "Button", box(INK.darkened(0.25), GOLD))
	theme.set_stylebox("disabled", "Button", box(INK.darkened(0.35), GOLD.darkened(0.6)))
	theme.set_stylebox("focus", "Button", box(Color.TRANSPARENT, GOLD, 2))
	theme.set_stylebox("normal", "LineEdit", box(INK.darkened(0.25), GOLD.darkened(0.45)))
	theme.set_stylebox("focus", "LineEdit", box(Color.TRANSPARENT, GOLD, 2))
	theme.set_color("font_color", "LineEdit", PAPER)
	# 충전 막대: 짙은 바탕 + 놋쇠색 채움. 퍼센트 글자는 바탕색으로(채움 위에서 읽히게).
	theme.set_stylebox("background", "ProgressBar", box(Color(INK, 0.85), GOLD.darkened(0.3), 2, 6, 0))
	theme.set_stylebox("fill", "ProgressBar", box(GOLD, GOLD, 0, 6, 0))
	theme.set_color("font_color", "ProgressBar", PAPER)
	theme.set_color("font_outline_color", "ProgressBar", INK)
	theme.set_constant("outline_size", "ProgressBar", 4)
	# 점수 판넬(반투명 초록 + 놋쇠 테두리).
	theme.set_stylebox("panel", "Panel", box(Color(INK, 0.78), Color(GOLD, 0.7), 2, 10))
	_theme = theme
	return theme


## 둥근 모서리 단색 상자. border_width = 테두리 두께(px), radius = 모서리 둥글기, margin = 안쪽 여백.
static func box(fill: Color, border: Color, border_width := 1, radius := 6, margin := 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style
