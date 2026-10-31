extends PanelContainer
## 화면 위 가운데 라운드·남은 시간 표시(2026-10-31 저녁 사용자 요청).
##   맨 위   라운드 칸: 라운드마다 ◆ 카드 충전 + ● 다트 두 칸(롤 아레나 라운드 표시 참고). 지난 칸은 채움, 지금 칸은 금빛 맥박, 앞 칸은 테두리.
##   가운데  지금 단계 이름(크게) → 다음 단계 이름(작게). 예: "다트 라운드  →  다음 카드 충전 라운드"
##   아래    남은 시간(큰 숫자) + 줄어드는 막대. 5초 이하면 분홍으로 바뀌어 커졌다 작아지고, 3초부터 째깍 소리가 난다.
## 카드 라운드 시연(F6)의 game/card_round/ui/round_tracker.gd 와 같은 칸 모양을 F5 경기 상태(MatchState)로 그린다.
## 예전 F5 HUD 는 왼쪽 위 단계 카드에 초만 적어서 "다음에 무엇이 오는지"가 안 보였다.
## 나중에 설정에서 UI 위치를 옮기게 할 때를 위해 이 표시는 노드 하나로 묶어 둔다(자리는 LoungeHUD 가 정한다).

const Style = preload("res://ui/lounge_style.gd")
const Sfx = preload("res://art/audio/sfx.gd")

enum Stage { CARDS, DARTS }

## 라운드 칸 하나의 지름(px)·칸 사이·라운드 사이 간격.
const PIP: float = 20.0
const PAIR_GAP: float = 10.0
const ROUND_GAP: float = 22.0
## 이 초 이하면 시간이 급하다(분홍 · 맥박), 이 초부터 째깍 소리.
const URGENT_SECONDS: float = 5.0
const TICK_SECONDS: int = 3
const DIM := Color("6f6a5c")

var _pips: Control
var _stage_label: Label
var _next_label: Label
var _sub_label: Label
var _seconds_label: Label
var _bar: ProgressBar
var _round: int = 1
var _total: int = 5
var _stage: Stage = Stage.CARDS
var _time: float = 0.0
var _last_tick: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", Style.card(Color(Style.PANEL, 0.9), Style.INK, Style.SHADOW, 3, 16, 12))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	_pips = Control.new()
	_pips.custom_minimum_size = Vector2(0, PIP + 10)
	_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pips.draw.connect(_draw_pips)
	column.add_child(_pips)
	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation", 12)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(line)
	_stage_label = Style.heading(line, "", 26, Style.GOLD)
	_next_label = Style.label(line, "", 16, Style.MUTED)
	_sub_label = Style.label(column, "", 16, Style.CREAM)
	_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seconds_label = Style.heading(column, "", 44, Style.CREAM)
	_seconds_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seconds_label.pivot_offset = Vector2(60, 28)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 8)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_theme_stylebox_override("background", Style.flat(Color(Style.INK, 0.8), Color(0, 0, 0, 0), 0, 4, 0, 0))
	_bar.add_theme_stylebox_override("fill", Style.flat(Style.MINT, Color(0, 0, 0, 0), 0, 4, 0, 0))
	column.add_child(_bar)
	custom_minimum_size = Vector2(_pips_width() + 40, 0)


## 매 프레임 LoungeHUD 가 부른다.
## round_number·total_rounds = 지금/전체 라운드(전체를 모르면 0), stage = 카드 충전/다트,
## sub = 단계 아래 한 줄(누구 차례 · 몇 발), seconds·limit = 남은 초·그 단계 전체 초.
func show_state(round_number: int, total_rounds: int, stage: Stage, sub: String, seconds: float, limit: float, delta: float) -> void:
	_time += delta
	if round_number != _round or total_rounds != _total or stage != _stage:
		_round = round_number
		_total = total_rounds
		_stage = stage
		_last_tick = -1
		custom_minimum_size.x = _pips_width() + 40
		reset_size()
	_stage_label.text = stage_name(stage, round_number)
	_stage_label.add_theme_color_override("font_color", Style.GOLD if stage == Stage.CARDS else Style.MINT)
	_next_label.text = "→  다음 " + next_name(stage, round_number, total_rounds)
	_sub_label.text = sub
	_sub_label.visible = not sub.is_empty()
	var left: float = maxf(0.0, seconds)
	var urgent: bool = left <= URGENT_SECONDS
	_seconds_label.text = "%d" % ceili(left)
	_seconds_label.add_theme_color_override("font_color", Style.PINK if urgent else Style.CREAM)
	# 급할 때 숫자가 초마다 톡 커졌다 돌아온다(초가 바뀌는 순간 1.25배).
	var beat: float = 1.0 - (left - floorf(left))
	_seconds_label.pivot_offset = _seconds_label.size * 0.5
	_seconds_label.scale = Vector2.ONE * (1.0 + 0.25 * exp(-beat * 8.0) if urgent and left > 0.0 else 1.0)
	_bar.max_value = maxf(1.0, limit)
	_bar.value = clampf(left, 0.0, _bar.max_value)
	(_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = Style.PINK if urgent else Style.MINT
	# 마지막 3초는 초가 바뀔 때마다 째깍.
	var whole: int = ceili(left)
	if whole <= TICK_SECONDS and whole > 0 and whole != _last_tick:
		_last_tick = whole
		Sfx.play(self, "tick", -10.0, 1.0 + (TICK_SECONDS - whole) * 0.08)
	_pips.queue_redraw()


## 단계 이름. 1라운드 카드 단계는 처음 7장을 받는 것이라 "카드 나눠 주기"라 부른다.
static func stage_name(stage: Stage, round_number: int) -> String:
	if stage == Stage.DARTS: return "다트 라운드"
	return "카드 나눠 주기" if round_number <= 1 else "카드 충전 라운드"


## 다음 단계 이름. 마지막 라운드의 다트가 끝나면 결과다.
static func next_name(stage: Stage, round_number: int, total_rounds: int) -> String:
	if stage == Stage.CARDS: return "다트 라운드"
	if total_rounds > 0 and round_number >= total_rounds: return "경기 결과"
	return "카드 충전 라운드"


func _shown_rounds() -> int:
	return _total if _total > 0 else maxi(_round + 2, 5)


func _pips_width() -> float:
	return 120.0 + _shown_rounds() * (PIP * 2 + PAIR_GAP + ROUND_GAP)


## 맨 위 라운드 칸 줄: "ROUND 2/5" + 라운드마다 ◆(카드 충전)─●(다트).
func _draw_pips() -> void:
	var font: Font = Style.font("heading")
	var width: float = _pips_width()
	var left: float = (_pips.size.x - width) * 0.5
	var middle: float = (PIP + 10) * 0.5
	var title: String = "R %d/%d" % [_round, _total] if _total > 0 else "R %d" % _round
	_pips.draw_string(font, Vector2(left, middle + 7), title, HORIZONTAL_ALIGNMENT_LEFT, 110, 20, Style.CREAM)
	for round_value in range(1, _shown_rounds() + 1):
		var x: float = left + 120.0 + (round_value - 1) * (PIP * 2 + PAIR_GAP + ROUND_GAP)
		var cards := Vector2(x + PIP * 0.5, middle)
		var darts := Vector2(x + PIP * 1.5 + PAIR_GAP, middle)
		_pips.draw_line(cards, darts, DIM, 2.0)
		_draw_pip(cards, round_value, Stage.CARDS)
		_draw_pip(darts, round_value, Stage.DARTS)


## 칸 하나. 0 = 지난 칸(어두운 색으로 채움), 1 = 지금(밝게 채움 + 맥박 + 후광), 2 = 앞으로(테두리만).
func _draw_pip(center: Vector2, round_value: int, stage_value: Stage) -> void:
	var state: int = 2
	if round_value < _round or (round_value == _round and stage_value < _stage): state = 0
	elif round_value == _round and stage_value == _stage: state = 1
	var base: Color = Style.GOLD if stage_value == Stage.CARDS else Style.MINT
	var color: Color = [base.darkened(0.45), base, DIM][state]
	var radius: float = PIP * 0.5
	if state == 1:
		radius *= 1.0 + 0.14 * sin(_time * 5.0)
		_pips.draw_circle(center, radius * 1.7, Color(base, 0.2))
	if stage_value == Stage.CARDS:
		var diamond := PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)])
		if state == 2:
			diamond.append(diamond[0])
			_pips.draw_polyline(diamond, color, 2.0, true)
		else:
			_pips.draw_colored_polygon(diamond, color)
	elif state == 2:
		_pips.draw_arc(center, radius * 0.85, 0, TAU, 24, color, 2.0, true)
	else:
		_pips.draw_circle(center, radius * 0.85, color)
		_pips.draw_circle(center, radius * 0.3, Style.INK)
