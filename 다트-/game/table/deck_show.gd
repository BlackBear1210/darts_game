extends Node3D
## F5 경기 카드 충전 라운드의 덱 섞기 · 나눠 주기 연출(2026-10-31 늦은 밤 사용자 요청: "카드를 섞는 효과들이 전부 사라졌다").
## 섞기 모션(정석 리플 · 마술사 · 딜러)과 덱에서 한 장씩 날아가는 나눠 주기는 F6 카드 라운드 시연(game/card_round/)에만 있었고
## F5 경기에는 처음부터 연결된 적이 없었다 → 시연의 ShuffleMotions · CardView 를 그대로 써서 F5 테이블 가운데에 붙인다.
##
## 보이기만 하는 노드다. 규칙 · 타이머 · 네트워크는 그대로다. 스냅샷이 CARDS 단계로 들어오면 각 화면이 스스로 재생한다.
##   - 섞는 방식은 match_id · 라운드로 정한다 → 싱글 · 멀티 모든 화면에서 같은 방식이 보인다(따로 보내지 않음).
##   - 이번에 새로 받은 카드는 매트(SeatCards)에서 숨겼다가, 덱에서 날아와 닿는 순간 뒤집히며 보인다.
##   - 쓴 카드가 덱으로 돌아오는 모습(drop_in) → 섞기 → 한 바퀴에 한 사람 한 장씩 나눠 주기 순서는 시연과 같다.
##   - MatchCards.VIEW_SECONDS(5초) 안에 끝나도록 섞기는 SHUFFLE_SECONDS 에 맞춰 빠르게 돈다. 다트 단계가 먼저 오면 바로 마무리한다.
## 내 손패(왼쪽 아래 1인칭 부채)는 스냅샷이 오자마자 바로 보인다 — 연출 때문에 카드 확인이 늦어지지 않는다.

const CardView = preload("res://game/card_round/cards/card_view.gd")
const ShuffleMotions = preload("res://game/card_round/cards/shuffle_motions.gd")
const TableCards = preload("res://game/card_round/cards/table_cards.gd")
const Sfx = preload("res://art/audio/sfx.gd")

## 나눠 준 뒤 테이블 가운데에 남는 덱 장수(보이기용 — F5 는 덱이 끝없이 다시 뽑는 방식이라 실제 장수가 없다).
const DECK_REST: int = 20
## 섞기에 쓰는 시간(초). 시연 시간(_shuffle_estimate)이 이보다 길면 그만큼 빠르게 돌린다.
## 돌아옴 0.6 + 섞기 1.6 + 나눠 주기(첫 라운드 28장) 1.7 ≈ 3.9초 < 카드 확인 5초.
const SHUFFLE_SECONDS: float = 1.6
## 나눠 주기: 다음 장까지 간격(초) · 한 장 비행 시간(초) · 포물선 높이(m).
const DEAL_GAP: float = 0.05
const DEAL_FLIGHT: float = 0.28
const DEAL_ARC: float = 0.14

## 매트 카드(game/table/seat_cards.gd). 새 카드를 숨겼다가 닿을 때 보인다.
var seat_cards: Node3D
## 덱 더미(아래 → 위).
var _pile: Array = []
## 이미 재생한 라운드("match_id:round"). 같은 라운드 스냅샷이 여러 번 와도 한 번만 돈다.
var _played_key: String = ""
## 지난 스냅샷의 자리별 손패 장수. 이번에 늘어난 칸 = 새로 받은 카드.
var _last_sizes: Dictionary = {}
## 스냅샷을 한 번이라도 봤는지(늦게 들어온 화면은 첫 스냅샷에서 연출하지 않는다).
var _seen: bool = false
## 지금 도는 연출 번호. 다트 단계가 먼저 오면 번호를 올려 남은 단계를 건너뛴다.
var _run: int = 0
var _playing: bool = false
## 이 화면에서 연출을 시작한 횟수(시험용 — tests/run_deck_show_remote.py).
var played: int = 0


## 스냅샷마다 부른다(GameView._apply_state, seat_cards.show_hands 바로 뒤).
func sync(state: MatchState) -> void:
	if _pile.is_empty():
		_build_pile(DECK_REST)
	var key: String = "%d:%d" % [state.match_id, state.round_number]
	if state.phase == MatchState.Phase.CARDS and key != _played_key:
		_played_key = key
		if _seen:
			var deals: Array[Vector2i] = _new_cards(state)
			if not deals.is_empty():
				_play(state, deals)
	elif state.phase != MatchState.Phase.CARDS and _playing:
		_finish()
	for player in state.players:
		_last_sizes[player.seat] = player.hand.size()
	_seen = true


## 이번 충전에서 늘어난 칸을 나눠 주는 순서대로: 한 바퀴에 자리마다 한 장씩(Vector2i(자리, 칸)).
func _new_cards(state: MatchState) -> Array[Vector2i]:
	var per_seat: Dictionary = {}
	var seats: Array[int] = []
	for player in state.players:
		var before: int = int(_last_sizes.get(player.seat, player.hand.size()))
		if player.hand.size() > before:
			per_seat[player.seat] = range(before, player.hand.size())
			seats.append(player.seat)
	seats.sort()
	var plan: Array[Vector2i] = []
	var lap: int = 0
	var added: bool = true
	while added:
		added = false
		for seat in seats:
			var indices: Array = per_seat[seat]
			if lap < indices.size():
				plan.append(Vector2i(seat, int(indices[lap])))
				added = true
		lap += 1
	return plan


## 덱 돌아옴 → 섞기 → 나눠 주기. await 사이마다 _run 이 바뀌었으면(다트 단계 시작) 그만둔다.
func _play(state: MatchState, deals: Array[Vector2i]) -> void:
	_run += 1
	var run: int = _run
	_playing = true
	played += 1
	# 새 카드는 덱에서 닿을 때까지 매트에서 숨긴다.
	var by_seat: Dictionary = {}
	for step in deals:
		var list: Array = by_seat.get(step.x, [])
		list.append(step.y)
		by_seat[step.x] = list
	if seat_cards != null:
		for seat: int in by_seat:
			seat_cards.hold(seat, by_seat[seat])
	# 1) 쓴 만큼 카드가 덱으로 돌아온다(위에서 툭툭 떨어진다).
	_drop_in(deals.size())
	await _wait(minf(0.35 + deals.size() * 0.012, 0.6))
	if run != _run: return
	# 2) 섞기: 모든 화면에서 같은 방식(match_id + 라운드).
	var style: int = posmod(state.match_id + state.round_number, ShuffleMotions.STYLE_NAMES.size())
	set_meta("shuffle_speed", maxf(1.0, _shuffle_estimate(style, _pile.size()) / SHUFFLE_SECONDS))
	var faces: Array[int] = []
	for player in state.players:
		faces.append_array(player.hand)
	Sfx.play_at(self, "riffle", _deck_center(), -8.0)
	await ShuffleMotions.play(style, self, _pile, _deck_center(), TableCards.DECK_YAW, faces)
	if run != _run: return
	# 3) 나눠 주기: 덱 맨 위에서 한 장씩 자리 칸으로 날아간다. 닿으면 매트 카드가 뒤집히며 나타난다.
	set_meta("shuffle_speed", 1.0)
	for step in deals:
		if run != _run: return
		_deal_one(step.x, step.y)
		await _wait(DEAL_GAP)
	await _wait(DEAL_FLIGHT)
	if run == _run:
		_playing = false


## 시연 섞기 모션의 대략 시간(초, 1배속). shuffle_motions.gd 의 기다림을 카드 장수 n 으로 더한 값.
static func _shuffle_estimate(style: int, n: int) -> float:
	match style:
		ShuffleMotions.Style.RIFFLE: return 1.64 + 0.04 * n
		ShuffleMotions.Style.MAGICIAN: return 2.75 + 0.104 * n
		_: return 3.99 + 0.014 * n


## 다트 단계가 먼저 시작됐다: 남은 연출을 건너뛰고 매트 카드를 모두 보이고 덱을 반듯하게 쌓는다.
func _finish() -> void:
	_run += 1
	_playing = false
	if seat_cards != null:
		seat_cards.release_all()
	while _pile.size() > DECK_REST:
		(_pile.pop_back() as Node).queue_free()
	for i in range(_pile.size()):
		(_pile[i] as Node3D).transform = ShuffleMotions.stack_transform(_deck_center(), TableCards.DECK_YAW, i)


## 덱 맨 위 카드를 자리 seat 의 index 칸으로 날린다.
func _deal_one(seat: int, index: int) -> void:
	if _pile.is_empty():
		_build_pile(1)
	var card: Node3D = _pile.pop_back()
	var to: Transform3D = seat_cards.slot_transform(seat, index) if seat_cards != null else card.transform
	Sfx.play_at(self, "deal", card.global_position, -14.0, randf_range(0.9, 1.15))
	var tween: Tween = ShuffleMotions.move(self, card, to, DEAL_FLIGHT, 0.0, DEAL_ARC)
	tween.finished.connect(func() -> void:
		card.queue_free()
		if seat_cards != null and is_instance_valid(seat_cards):
			seat_cards.release(seat, index))


## 쓴 카드가 덱으로 돌아온다: 덱 위로 count 장이 떨어져 흩어진다(시연 TableCards.drop_in 과 같은 모양).
func _drop_in(count: int) -> void:
	var random := RandomNumberGenerator.new()
	for i in range(count):
		var card := CardView.new()
		add_child(card)
		var rest := Transform3D(Basis(Vector3.UP, random.randf() * TAU),
			_deck_center() + Vector3(random.randf_range(-0.2, 0.2), (_pile.size() + i) * 0.0012, random.randf_range(-0.14, 0.14)))
		card.transform = Transform3D(rest.basis, rest.origin + Vector3.UP * 0.45)
		card.scale = Vector3.ONE * 0.001
		_pile.append(card)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(card, "scale", Vector3.ONE, 0.2).set_delay(i * 0.012)
		tween.tween_property(card, "position", rest.origin, 0.32).set_delay(i * 0.012).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## 처음: 덱을 반듯하게 쌓아 둔다(뒷면이 위).
func _build_pile(count: int) -> void:
	for i in range(count):
		var card := CardView.new()
		card.name = "DeckCard%d" % (_pile.size() + 1)
		add_child(card)
		card.transform = ShuffleMotions.stack_transform(_deck_center(), TableCards.DECK_YAW, _pile.size())
		_pile.append(card)


## 테이블 가운데 덱 자리(펠트 위).
func _deck_center() -> Vector3:
	return TableView.TABLE_CENTER + Vector3.UP * (TableView.TABLE_HEIGHT + TableCards.FELT_TOP)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


## 시험용: 지금 연출이 도는 중인지 · 덱 장수.
func is_playing() -> bool:
	return _playing


func pile_size() -> int:
	return _pile.size()
