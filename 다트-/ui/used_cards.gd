extends Control
## 이번 라운드에 누가 어떤 카드를 썼는지(2026-11-28 사용자 결정 "다트 카드 HUD 초안 A 보완안으로 진행").
##
##   오른쪽 위  상대마다 한 묶음: 겹쳐 놓은 카드 + 그 아래 자리 기호·이름. 카드를 쓴 상대만 보인다.
##   왼쪽 아래  내가 쓴 카드(손패 줄 바로 위, 작게). 카드를 꺼내 든 동안은 숨긴다 — 꺼낸 카드가 이 자리로 올라온다.
##   쓴 순간    상대가 새로 쓴 카드는 과녁 옆까지 날아왔다가 제자리로 돌아간다(조준하는 동안에도 눈에 띄게).
##              '움직임 줄이기' 설정이면 날리지 않고 제자리에서 빛나기만 한다.
## 카드 상태: 걸려 있음 = 밝게 · 끝남 = 어둡게 · 무효(×0)에 막힘 = 회색 + 빨간 사선.
## 예전 오른쪽 위 '적용 중' 카드 줄(ui/active_cards.gd)을 이 표시로 합쳤다 — 걸려 있는 카드가 밝게 남는다.
## 데이터: 방장 MatchCards._used_cards → MatchPlayer.card_effects["used_cards"] (Vector2i(카드 번호, MatchCards.UsedCard)).
##
## [붙이는 법] 화면 전체 크기 Control 로 add_child 하고 매 프레임 place() → show_round() 순서로 부른다(ui/lounge_hud.gd).

const Style = preload("res://ui/lounge_style.gd")
const ScoreList = preload("res://ui/score_list.gd")
const CardFaces = preload("res://game/card_round/cards/card_faces.gd")
const MatchCards = preload("res://game/match/match_cards.gd")
const Preferences = preload("res://ui/player_preferences.gd")

## 상대 묶음: 카드 크기 · 겹쳐 놓는 간격 · 보일 최대 장수(넘치면 최근 것만, 앞에 "+N") · 묶음 사이 간격 · 최소 너비(이름 칸).
const OTHER_CARD := Vector2(48, 72)
const OTHER_STEP: float = 16.0
const OTHER_MAX: int = 4
const GROUP_GAP: float = 16.0
const GROUP_MIN_WIDTH: float = 104.0
## 이름 칸(카드 아래): 위 간격 · 글자 크기 · 높이. 그 아래 설명 한 줄.
const NAME_GAP: float = 4.0
const NAME_SIZE: int = 14
const NAME_HEIGHT: float = 22.0
const CAPTION_SIZE: int = 13
const CAPTION_WIDTH: float = 260.0
## 내 줄: 제목 글자 크기·높이 · 카드 크기 · 간격 · 보일 최대 장수.
const MINE_TITLE_SIZE: int = 15
const MINE_TITLE_HEIGHT: float = 24.0
const MY_CARD := Vector2(56, 84)
const MY_GAP: float = 8.0
const MY_MAX: int = 6
## "+N" 칸 너비.
const MORE_WIDTH: float = 30.0
## 카드 그림 색: 끝난 카드는 어둡게, 무효로 막힌 카드는 더 어두운 회색 + 빨간 사선.
const SPENT_TINT := Color(0.55, 0.55, 0.55)
const NULLIFIED_TINT := Color(0.38, 0.38, 0.38)
const SLASH_COLOR := Color("ff5f52")
const SLASH_WIDTH: float = 4.0
## 새로 쓴 카드가 금색 테로 빛나는 시간(초).
const FRESH_SECONDS: float = 1.6
## 날아오기: 커지는 배율 · 가는 시간 · 머무는 시간 · 돌아오는 시간(초).
const FLY_SCALE: float = 1.7
const FLY_OUT_SECONDS: float = 0.3
const FLY_HOLD_SECONDS: float = 0.8
const FLY_BACK_SECONDS: float = 0.35

## 상대 카드가 날아갈 곳(이 Control 좌표, 날아간 카드의 가운데). lounge_hud 가 매 프레임 넣는다.
var flight_target: Vector2 = Vector2.ZERO

var _others: Control
var _caption: Label
var _mine: Control
## 배치 기준: 상대 묶음 오른쪽 끝 · 위 · 내 줄 왼쪽 아래(손패 줄 바로 위).
var _right: float = 0.0
var _top: float = 0.0
var _mine_origin: Vector2 = Vector2.ZERO
var _hide_mine: bool = false
## peer_id → 마지막으로 그린 used_cards. 바뀐 사람이 있을 때만 다시 만든다(매 프레임 부르므로).
var _seen: Dictionary = {}
var _me: int = 0
## "peer:번호" → 그 카드 Control(빛나기·날아오기 출발점을 찾는다).
var _cards: Dictionary = {}
## "peer:번호" → 남은 빛나는 시간(초). 비면 _process 를 끈다.
var _fresh: Dictionary = {}
## 이번에 새로 쓴 상대 카드("peer:번호") — 다시 만든 직후 날린다.
var _arrivals: Array[String] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_others = _holder()
	_caption = Style.hud_label(self, "상대가 쓴 카드 · 이번 라운드", CAPTION_SIZE, Style.MUTED)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_caption.size = Vector2(CAPTION_WIDTH, 0)
	_mine = _holder()
	set_process(false)


## 자리를 정한다. right·top = 상대 묶음의 오른쪽 위 구석, mine_origin = 내 줄의 왼쪽 아래.
func place(right: float, top: float, mine_origin: Vector2) -> void:
	_right = right
	_top = top
	_mine_origin = mine_origin
	_arrange()


## players = 경기 참가자(차례 순서), me = 내 peer ID, hide_mine = 내 줄을 숨길 때(카드를 꺼내 들었을 때).
func show_round(players: Array[MatchPlayer], me: int, hide_mine: bool) -> void:
	_hide_mine = hide_mine
	var changed: bool = me != _me or players.size() != _seen.size()
	for player in players:
		var used: Array = player.card_effects.get("used_cards", [])
		var before: Variant = _seen.get(player.peer_id)
		if before is Array and before == used:
			continue
		changed = true
		# 같은 라운드에 장수가 늘었다 = 방금 쓴 카드. 처음 보는 사람·라운드가 바뀌어 줄어든 경우는 알리지 않는다.
		if before is Array and used.size() > (before as Array).size():
			var key: String = _key(player.peer_id, used.size() - 1)
			_fresh[key] = FRESH_SECONDS
			if player.peer_id != me:
				_arrivals.append(key)
	if changed:
		_me = me
		_rebuild(players)
	_arrange()
	_launch_arrivals()


## 상대 카드 묶음이 하나라도 보이는가(킬로그를 그 아래로 내릴지 정한다).
func has_opponent_cards() -> bool:
	return _others.get_child_count() > 0


## 상대 묶음 + 설명 줄의 아래 끝(이 Control 좌표).
func opponents_bottom() -> float:
	return _caption.position.y + _caption.size.y


func _process(delta: float) -> void:
	for key: String in _fresh.keys():
		_fresh[key] = float(_fresh[key]) - delta
		if float(_fresh[key]) > 0.0:
			continue
		_fresh.erase(key)
		var card: Control = _cards.get(key)
		if card != null:
			card.get_node("Glow").visible = false
	set_process(not _fresh.is_empty())


# ─────────────────────────────── 만들기 ───────────────────────────────

func _holder() -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	return holder


func _rebuild(players: Array[MatchPlayer]) -> void:
	_seen.clear()
	_cards.clear()
	# 바로 떼어 낸다 — queue_free 만 하면 이번 프레임의 get_child_count()·배치에 옛 카드가 남는다.
	for holder: Control in [_others, _mine]:
		for child in holder.get_children():
			holder.remove_child(child)
			child.queue_free()
	var x: float = 0.0
	var mine: Array = []
	for player in players:
		var used: Array = player.card_effects.get("used_cards", [])
		_seen[player.peer_id] = used.duplicate()
		if player.peer_id == _me:
			mine = used
		elif not used.is_empty():
			var group: Control = _opponent_group(player, used)
			group.position.x = x
			_others.add_child(group)
			x += group.size.x + GROUP_GAP
	_others.size = Vector2(maxf(0.0, x - GROUP_GAP), OTHER_CARD.y + NAME_GAP + NAME_HEIGHT)
	_mine.size = Vector2.ZERO
	if not mine.is_empty():
		_build_mine(mine)
	set_process(not _fresh.is_empty())


## 상대 한 사람 묶음: 최근 OTHER_MAX 장을 OTHER_STEP 간격으로 겹치고, 아래에 자리 기호·이름.
func _opponent_group(player: MatchPlayer, used: Array) -> Control:
	var group := Control.new()
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var first: int = maxi(0, used.size() - OTHER_MAX)
	var more: float = MORE_WIDTH if first > 0 else 0.0
	var fan_width: float = more + OTHER_STEP * (used.size() - first - 1) + OTHER_CARD.x
	var width: float = maxf(fan_width, GROUP_MIN_WIDTH)
	var x: float = (width - fan_width) * 0.5
	if first > 0:
		_more_label(group, first, Vector2(x, OTHER_CARD.y * 0.5 - 12))
		x += more
	for index in range(first, used.size()):
		var card: Control = _card(used[index], OTHER_CARD)
		card.position = Vector2(x, 0)
		group.add_child(card)
		_remember(card, player.peer_id, index)
		x += OTHER_STEP
	var tint: Color = PlayerLook.COLORS[player.seat % PlayerLook.COLORS.size()].lightened(0.3)
	var glyph: String = ScoreList.SEAT_GLYPHS[player.seat % ScoreList.SEAT_GLYPHS.size()]
	var name_label := Style.hud_label(group, "%s %s" % [glyph, player.display_name], NAME_SIZE, tint)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.clip_text = true
	name_label.position = Vector2(0, OTHER_CARD.y + NAME_GAP)
	name_label.size = Vector2(width, NAME_HEIGHT)
	group.size = Vector2(width, OTHER_CARD.y + NAME_GAP + NAME_HEIGHT)
	return group


## 내 줄: 제목 + 최근 MY_MAX 장을 나란히(겹치지 않는다).
func _build_mine(used: Array) -> void:
	Style.hud_label(_mine, "내가 쓴 카드", MINE_TITLE_SIZE, Style.CREAM)
	var first: int = maxi(0, used.size() - MY_MAX)
	var x: float = 0.0
	if first > 0:
		_more_label(_mine, first, Vector2(0, MINE_TITLE_HEIGHT + MY_CARD.y * 0.5 - 12))
		x += MORE_WIDTH
	for index in range(first, used.size()):
		var card: Control = _card(used[index], MY_CARD)
		card.position = Vector2(x, MINE_TITLE_HEIGHT)
		_mine.add_child(card)
		_remember(card, _me, index)
		x += MY_CARD.x + MY_GAP
	_mine.size = Vector2(x - MY_GAP, MINE_TITLE_HEIGHT + MY_CARD.y)


## 카드 한 장: 그림 + 얇은 잉크 테 + (새 카드면) 금색 빛 테 + (무효면) 빨간 사선.
func _card(entry: Vector2i, card_size: Vector2) -> Control:
	var holder := Control.new()
	holder.size = card_size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glow := Panel.new()
	glow.name = "Glow"
	glow.position = -Vector2.ONE * 4.0
	glow.size = card_size + Vector2.ONE * 8.0
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.add_theme_stylebox_override("panel", Style.flat(Color(Style.GOLD, 0.25), Style.GOLD, 3, 9, 0))
	glow.visible = false
	holder.add_child(glow)
	var art := TextureRect.new()
	art.name = "Art"
	art.texture = CardFaces.face(entry.x)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.size = card_size
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(art)
	var edge := Panel.new()
	edge.size = card_size
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.add_theme_stylebox_override("panel", Style.flat(Color(0, 0, 0, 0), Color(Style.INK, 0.85), 2, 5, 0))
	holder.add_child(edge)
	if entry.y == MatchCards.UsedCard.SPENT:
		art.self_modulate = SPENT_TINT
	elif entry.y == MatchCards.UsedCard.NULLIFIED:
		art.self_modulate = NULLIFIED_TINT
		var slash := Line2D.new()
		slash.points = PackedVector2Array([Vector2(card_size.x * 0.12, card_size.y * 0.88), Vector2(card_size.x * 0.88, card_size.y * 0.12)])
		slash.width = SLASH_WIDTH
		slash.default_color = SLASH_COLOR
		slash.begin_cap_mode = Line2D.LINE_CAP_ROUND
		slash.end_cap_mode = Line2D.LINE_CAP_ROUND
		holder.add_child(slash)
	return holder


func _more_label(parent: Control, count: int, at: Vector2) -> void:
	var more := Style.hud_label(parent, "+%d" % count, 16, Style.CREAM)
	more.position = at


func _remember(card: Control, peer_id: int, index: int) -> void:
	var key: String = _key(peer_id, index)
	_cards[key] = card
	card.get_node("Glow").visible = _fresh.has(key)


static func _key(peer_id: int, index: int) -> String:
	return "%d:%d" % [peer_id, index]


# ─────────────────────────────── 배치·날아오기 ───────────────────────────────

func _arrange() -> void:
	_others.position = Vector2(_right - _others.size.x, _top)
	_caption.visible = has_opponent_cards()
	_caption.position = Vector2(_right - CAPTION_WIDTH, _top + _others.size.y)
	_mine.visible = not _hide_mine and _mine.get_child_count() > 0
	_mine.position = _mine_origin - Vector2(0, _mine.size.y)


## 방금 쓴 상대 카드를 제자리에서 과녁 옆까지 날렸다가 돌려보낸다. 날아간 것은 그림 사본이고 제자리 카드는 그대로 있다.
func _launch_arrivals() -> void:
	if _arrivals.is_empty():
		return
	var keys: Array[String] = _arrivals.duplicate()
	_arrivals.clear()
	if Preferences.reduced_motion or not visible:
		return
	for key in keys:
		var card: Control = _cards.get(key)
		if card == null:
			continue
		var start: Vector2 = _local_position(card)
		var flyer := TextureRect.new()
		flyer.texture = (card.get_node("Art") as TextureRect).texture
		flyer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		flyer.stretch_mode = TextureRect.STRETCH_SCALE
		flyer.size = card.size
		flyer.pivot_offset = card.size * 0.5
		flyer.position = start
		flyer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(flyer)
		var tween := flyer.create_tween()
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(flyer, "position", flight_target - card.size * 0.5, FLY_OUT_SECONDS)
		tween.parallel().tween_property(flyer, "scale", Vector2.ONE * FLY_SCALE, FLY_OUT_SECONDS)
		tween.tween_interval(FLY_HOLD_SECONDS)
		tween.tween_property(flyer, "position", start, FLY_BACK_SECONDS).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(flyer, "scale", Vector2.ONE, FLY_BACK_SECONDS).set_ease(Tween.EASE_IN)
		tween.tween_callback(flyer.queue_free)


## 이 Control 좌표로 본 카드 위치. global_position 을 빼면 HUD 배율(ui_scale)이 섞이므로 부모 위치를 더해 올라간다.
func _local_position(node: Control) -> Vector2:
	var at := Vector2.ZERO
	var item: Control = node
	while item != self:
		at += item.position
		item = item.get_parent() as Control
	return at
