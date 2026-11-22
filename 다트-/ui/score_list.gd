extends VBoxContainer
## 왼쪽 위 점수판 모듈(2026-11-22 lounge_hud.gd 에서 떼어 냄). 디자인 담당 소유.
## 사용자 요청: "플레이어 목록은 첫 로비에서만 띄우고 점수랑 플레이어 이름만", "뒤 검정 배경을 없애 심플하게".
##
##   라운지(경기 전)  머리글 "DARTY 라운지" + 줄마다 [자리 기호 · 이름 · 점수]
##   경기 중          줄만 [▶(지금 차례) · 자리 기호 · 이름 · 점수] — 라운드·남은 시간은 위 가운데 배너(round_banner.gd)가 맡는다.
## 판넬·줄 바탕이 없다. 글자마다 잉크 외곽선(Style.outline)을 둘러 크림색 벽·어두운 바닥 어디서나 읽힌다.
##
## [붙이는 법] 씬이 필요 없다. 아무 Control 아래에 `ScoreList.new()` 를 add_child 하고 매 프레임 show_players() 를 부른다.
##   const ScoreList = preload("res://ui/score_list.gd")
## 경기 결과 창처럼 한 줄만 필요하면 ScoreList.row() 를 바로 쓴다.

const Style = preload("res://ui/lounge_style.gd")

## 자리 표식(색약이어도 모양으로 구분 — 기획 2-4). 3D 이름표·바닥 깔개·칠판과 같은 기호.
const SEAT_GLYPHS: Array[String] = ["●", "▲", "■", "◆"]
## 이름 칸 너비(px). 길면 "…" 으로 줄인다. 점수 칸은 오른쪽 맞춤.
const NAME_WIDTH: float = 210.0
const SCORE_WIDTH: float = 64.0
const MARKER_WIDTH: float = 18.0

var _header: HBoxContainer
var _title: Label
var _rows: VBoxContainer
## 같은 내용이면 줄을 다시 만들지 않는다(매 프레임 부르므로).
var _key: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 4)
	_header = HBoxContainer.new()
	_header.add_theme_constant_override("separation", 12)
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_header)
	var logo := Style.heading(_header, "DARTY", 26, Style.GOLD)
	logo.add_theme_font_override("font", Style.font("logo"))
	_title = Style.hud_label(_header, "", 18, Style.MINT)
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rows)


## players = 보일 사람(자리 순서), active = 지금 던지는 사람(없으면 null), me = 내 peer ID,
## title = 머리글 글자. 빈 글이면 로고와 머리글을 숨긴다(경기 중).
func show_players(players: Array[MatchPlayer], active: MatchPlayer, me: int, title: String) -> void:
	_header.visible = not title.is_empty()
	_title.text = title
	var parts := PackedStringArray()
	for player in players:
		parts.append("%d|%s|%.1f|%s|%s" % [player.seat, player.display_name, player.score, player == active, player.peer_id == me])
	var joined := ",".join(parts)
	if joined == _key:
		return
	_key = joined
	for child in _rows.get_children():
		child.queue_free()
	for player in players:
		_rows.add_child(row(player, player == active, player.peer_id == me, "▶" if player == active else ""))


## 한 줄: [표시 · 자리 기호 · 이름 · 점수]. highlight 면 이름·점수가 금색이다.
## marker = 맨 앞 칸 글자(경기 중 "▶" · 결과 창 "1위"), marker_width = 그 칸 너비.
static func row(player: MatchPlayer, highlight: bool, me: bool, marker: String = "", marker_width: float = MARKER_WIDTH) -> HBoxContainer:
	var tint: Color = PlayerLook.COLORS[player.seat % PlayerLook.COLORS.size()]
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mark := Style.hud_label(line, marker, 16, Style.GOLD)
	mark.custom_minimum_size.x = marker_width
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var glyph := Style.hud_label(line, SEAT_GLYPHS[player.seat % SEAT_GLYPHS.size()], 20, tint.lightened(0.25))
	glyph.custom_minimum_size.x = 22
	var name_label := Style.hud_label(line, player.display_name + ("  (나)" if me else ""), 20, Style.GOLD if highlight else Style.CREAM)
	name_label.custom_minimum_size.x = NAME_WIDTH
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var score := Style.heading(line, "%.1f" % player.score, 24, Style.GOLD if highlight else Style.CREAM)
	score.add_theme_font_override("font", Style.font("logo"))
	score.custom_minimum_size.x = SCORE_WIDTH
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return line
