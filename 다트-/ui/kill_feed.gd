extends VBoxContainer
## 오른쪽 위 킬로그 모듈(2026-11-22 lounge_hud.gd 에서 떼어 냄). 배틀그라운드처럼 "누가 [아이콘] 누구를" 한 줄씩.
## 새 줄이 들어오면 위에 쌓이고 FEED_LIFE 초 뒤 흐려져 사라진다. 최근 FEED_ROWS 줄만 보인다.
## 2026-11-22 사용자 요청 "검정 배경을 없애 게임할 때 안 거슬리게": 줄 바탕을 없애고 글자에 잉크 외곽선을 둘렀다.
## 아이콘만 작은 동그란 잉크 받침(ICON_PLATE)을 둔다 — 선으로 그린 크림색 아이콘은 크림색 벽 앞에서 사라지기 때문이다.
##
## [붙이는 법] 씬이 필요 없다. `KillFeed.new()` 를 add_child 하고 매 프레임 show_feed(state.feed, delta) 를 부른다.
## 한 줄 글자 형식은 MatchController.feed_entry / FEED_SEPARATOR 가 정한다(아이콘|행동 자리|행동 이름|설명|대상 자리|대상 이름).

const Style = preload("res://ui/lounge_style.gd")
const UiIcon = preload("res://ui/ui_icon.gd")

## 한 줄이 떠 있는 시간(초) · 보일 줄 수 · 사라지는 시간(초).
const FEED_LIFE: float = 5.0
const FEED_ROWS := 2
const FEED_FADE: float = 0.8
const ICON_SIDE: float = 26.0
const ICON_PLATE := Color(0.07, 0.05, 0.07, 0.55)

## 줄 글자 → 처음 본 시각.
var _seen: Dictionary = {}
var _key: String = ""
var _time: float = 0.0


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_BEGIN
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## entries = 경기 상태의 킬로그(MatchState.feed, 오래된 것 → 새것).
func show_feed(entries: Array[String], delta: float) -> void:
	_time += delta
	for entry in entries:
		if not _seen.has(entry): _seen[entry] = _time
	for entry: String in _seen.keys():
		if entry not in entries and _time - float(_seen[entry]) > FEED_LIFE: _seen.erase(entry)
	var shown := PackedStringArray()
	for entry in entries:
		if _time - float(_seen[entry]) < FEED_LIFE: shown.append(entry)
	if shown.size() > FEED_ROWS:
		shown = shown.slice(shown.size() - FEED_ROWS)
	var joined := "\n".join(shown)
	if joined != _key:
		_key = joined
		for child in get_children():
			child.queue_free()
		for entry in shown:
			var line := chip(entry)
			line.set_meta("entry", entry)
			add_child(line)
	for line in get_children():
		if not line.has_meta("entry"): continue
		var age: float = _time - float(_seen.get(line.get_meta("entry"), _time))
		# 들어올 때 0.15초 동안 나타나고, 끝날 때 흐려진다.
		line.modulate.a = clampf((FEED_LIFE - age) / FEED_FADE, 0.0, 1.0) * clampf(age / 0.15, 0.0, 1.0)


## 킬로그 한 줄. 예전 글자 한 줄(구분 글자 없음)도 그대로 보여 준다.
static func chip(entry: String) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	line.alignment = BoxContainer.ALIGNMENT_END
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var parts := entry.split(MatchController.FEED_SEPARATOR)
	if parts.size() < 6:
		Style.hud_label(line, entry, 16, Style.CREAM)
		return line
	if not parts[2].is_empty():
		Style.hud_label(line, parts[2], 17, seat_color(int(parts[1])))
	line.add_child(_icon(parts[0]))
	if not parts[5].is_empty():
		Style.hud_label(line, parts[5], 17, seat_color(int(parts[4])))
	if not parts[3].is_empty():
		Style.hud_label(line, parts[3], 15, Style.MUTED)
	return line


## 자리 색(밝게). 자리가 없으면(-1) 크림색.
static func seat_color(seat: int) -> Color:
	if seat < 0: return Style.CREAM
	return PlayerLook.COLORS[seat % PlayerLook.COLORS.size()].lightened(0.3)


static func _icon(icon_id: String) -> Control:
	var plate := PanelContainer.new()
	var round_plate := StyleBoxFlat.new()
	round_plate.bg_color = ICON_PLATE
	round_plate.set_corner_radius_all(int(ICON_SIDE))
	round_plate.set_content_margin_all(3)
	plate.add_theme_stylebox_override("panel", round_plate)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(UiIcon.make(icon_id, ICON_SIDE, Style.CREAM))
	return plate
