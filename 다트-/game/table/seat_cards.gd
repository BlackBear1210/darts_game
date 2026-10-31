extends Node3D
## F5 경기 테이블의 자리 매트 위 카드(2026-10-31). 각자의 손패가 **앞면으로** 깔리고, 손패가 바뀌면 바로 따라간다
## (2026-10-31 저녁 사용자 결정: 상대 카드·내 카드 전부 앞면 — 처음엔 뒷면이었다). 카드 아래 가장자리가 주인 쪽이다.
## 꺼내 든 카드(MatchPlayer.pending_slot)는 매트 위로 살짝 떠서 빛난다 → 누가 무엇을 쓰려는지 테이블에서도 보인다.
## 앉아서 A·D 로 옆자리 쪽으로 몸을 기울이면(PlayerView.peek_amount, 레식 기울이기) 그 자리 카드가
## 내 화면에서만 나를 향해 크게 펼쳐진다 — 멀어서 작게 보이는 옆 사람 카드를 가까이 들여다보고 견제하는 연출.
##
## 보이기만 하는 노드다. 손패는 원래 모든 화면 스냅샷(MatchPlayer.hand)에 있으므로 규칙·네트워크는 바꾸지 않는다.
## 칸 좌표는 카드 라운드 시연의 테이블 카드(table_cards.gd)와 같은 상수를 써서 펍 매트와 맞는다.
## 카드 그림(CardFaces)은 굽기(bake)가 끝난 뒤에 만들어야 한다 — GameView 가 굽기 뒤에 이 노드를 붙인다.

const CardView = preload("res://game/card_round/cards/card_view.gd")
const TableCards = preload("res://game/card_round/cards/table_cards.gd")
const ShuffleMotions = preload("res://game/card_round/cards/shuffle_motions.gd")
## 엿보기가 이만큼(0~1) 넘으면 옆자리 카드가 뒤집힌다. 살짝 기울인 정도로는 안 보인다.
## 이름표 "엿보는 중" 표시와 같은 기준이어야 하므로 PlayerView 값을 그대로 쓴다.
const PEEK_REVEAL: float = PlayerView.PEEK_TAG
## 기운 쪽 판정: 내 자리에서 그 자리 매트로 가는 방향과 내 옆(기운 쪽) 벡터의 내적이 이보다 커야 "옆자리"다.
## 원형 테이블 4자리 기준 옆자리 매트 ≈ 0.4, 맞은편 매트 ≈ 0 이다. 눈 위치가 아니라 자리 위치로 재야
## 기울어서 눈이 옆으로 나가도 판정이 흔들리지 않는다.
const SIDE_DOT: float = 0.25
## 뒤집히는 빠르기(초당 0→1 진행). 4 = 0.25초.
const REVEAL_SPEED: float = 4.0
## 엿본 카드가 매트 위로 떠오르는 높이(m)·카드 사이 간격(m)·나를 향해 드는 정도(0 = 누움, 1 = 정면).
const PEEK_RAISE: float = 0.11  # PEEK_SCALE 로 커진 카드 아래 가장자리가 매트에 묻히지 않는 높이
const PEEK_GAP: float = 0.072
const PEEK_FACE: float = 0.75
## 꺼내 든 카드가 매트에서 떠오르는 높이(m)와 빛 색.
const PENDING_RAISE: float = 0.035
const PENDING_GLOW := Color("ffcf4a")
## 펼친 카드끼리 부채처럼 살짝 돌아가는 각도(라디안, 한 장당).
const PEEK_FAN: float = 0.06
## 엿본 카드를 키우는 배율. 옆자리 매트는 눈에서 1m 가까이 떨어져 있어 원래 크기로는 글자가 작다(2026-10-31 화면 확인).
## 간격(PEEK_GAP)도 같은 배율로 넓혀 겹침 비율은 그대로 둔다.
const PEEK_SCALE: float = 1.35

## 자리 번호 → 그 자리 매트에 깔린 CardView 들(왼쪽부터).
var _rows: Dictionary = {}
## 자리 번호 → 펼친 정도(0 = 매트에 누움, 1 = 나를 향해 펼침).
var _reveal: Dictionary = {}
## 자리 번호 → 꺼내 든 카드 칸(-1 = 없음).
var _pending: Dictionary = {}
## 자리 번호 → 덱에서 아직 날아오지 않아 숨겨 둔 칸 번호들(game/table/deck_show.gd 나눠 주기 연출, 2026-10-31 늦은 밤).
var _held: Dictionary = {}


## 스냅샷마다 부른다: 자리마다 손패 장수·종류에 맞춰 카드를 더하거나 뺀다.
func show_hands(players: Array[MatchPlayer]) -> void:
	# 나간 사람 자리의 카드는 치운다.
	var present: Array[int] = []
	for player in players:
		present.append(player.seat)
	for seat: int in _rows.keys():
		if seat not in present:
			for card: Node in _rows[seat]:
				card.queue_free()
			_rows.erase(seat)
			_reveal.erase(seat)
			_held.erase(seat)
	for player in players:
		var row: Array = _rows.get(player.seat, [])
		while row.size() > player.hand.size():
			(row.pop_back() as Node).queue_free()
		while row.size() < player.hand.size():
			var card := CardView.new()
			card.name = "Seat%dCard%d" % [player.seat + 1, row.size() + 1]
			card.show_face(true)  # 늘 앞면. 눕히기·펼치기는 이 노드가 카드 전체를 돌려서 한다(_place_row).
			add_child(card)
			row.append(card)
		for index in range(row.size()):
			var card: CardView = row[index]
			if card.type != player.hand[index]:
				card.set_type(player.hand[index])
		_rows[player.seat] = row
		_pending[player.seat] = player.pending_slot
		for index in range(row.size()):
			(row[index] as CardView).set_glow(0.8 if index == player.pending_slot else 0.0, PENDING_GLOW)
			# 나눠 주기 연출 중인 칸은 덱 카드가 닿을 때까지 숨긴다(release).
			(row[index] as CardView).visible = not (_held.get(player.seat, []) as Array).has(index)
		if not _reveal.has(player.seat):
			_reveal[player.seat] = 0.0
	for seat: int in _rows:
		_place_row(seat, null)


## 나눠 주기 연출(deck_show.gd): 자리 seat 의 index 칸들을 덱 카드가 날아와 닿을 때까지 숨긴다.
func hold(seat: int, indices: Array) -> void:
	var held: Array = _held.get(seat, [])
	for index: int in indices:
		if not held.has(index):
			held.append(index)
	_held[seat] = held
	var row: Array = _rows.get(seat, [])
	for index: int in indices:
		if index < row.size():
			(row[index] as CardView).visible = false


## 덱 카드가 칸에 닿았다: 숨겨 둔 카드를 뒤집으며 보인다(뒷면 → 앞면). flip = false 면 그냥 보인다(연출을 끝낼 때).
func release(seat: int, index: int, flip: bool = true) -> void:
	var held: Array = _held.get(seat, [])
	held.erase(index)
	var row: Array = _rows.get(seat, [])
	if index >= row.size():
		return
	var card: CardView = row[index]
	card.visible = true
	if flip:
		card.show_face(false)
		ShuffleMotions.flip(self, card, true, 0.2)


## 숨겨 둔 칸을 모두 바로 보인다(다트 단계가 먼저 시작됐을 때).
func release_all() -> void:
	for seat: int in _held.keys():
		for index: int in (_held[seat] as Array).duplicate():
			release(seat, index, false)
	_held.clear()


## 자리 seat 의 index 칸(매트 위에 누운 자리, 월드 좌표). 덱 카드가 날아갈 곳.
func slot_transform(seat: int, index: int) -> Transform3D:
	return _slot(seat, index)


## 매 프레임: 내가(viewer) 지금 엿보는 자리를 골라 그 자리만 앞면으로 펼치고, 나머지는 뒷면으로 되돌린다.
func show_peek(viewer: PlayerView, delta: float) -> void:
	var peeked: int = peeked_seat(viewer)
	for seat: int in _rows:
		var target: float = 1.0 if seat == peeked else 0.0
		var before: float = _reveal[seat]
		_reveal[seat] = move_toward(before, target, delta * REVEAL_SPEED)
		if before != _reveal[seat] or _reveal[seat] > 0.0:
			_place_row(seat, viewer)


## viewer 가 몸을 기울여 들여다보는 옆자리 번호. 앉아 있지 않거나 덜 기울였으면 -1.
## 기운 쪽(오른쪽/왼쪽)에 있는 자리 중 가장 옆에 있는 매트를 고른다 → 맞은편 자리는 엿볼 수 없다.
func peeked_seat(viewer: PlayerView) -> int:
	if viewer == null or not viewer.seated or absf(viewer.peek_amount()) < PEEK_REVEAL:
		return -1
	var side: Vector3 = viewer.global_basis.x * signf(viewer.peek_amount())
	var best: int = -1
	var best_dot: float = SIDE_DOT
	for seat: int in _rows:
		if seat == viewer.identity.seat:
			continue
		var to_mat: Vector3 = _mat_center(seat) - TableView.SEATS[viewer.identity.seat]
		to_mat.y = 0.0
		var dot: float = to_mat.normalized().dot(side)
		if dot > best_dot:
			best_dot = dot
			best = seat
	return best


## 한 자리 카드 줄을 놓는다. 누운 자리(뒷면)와 펼친 자리(앞면, viewer 를 향함)를 _reveal 비율로 섞는다.
func _place_row(seat: int, viewer: PlayerView) -> void:
	var row: Array = _rows[seat]
	var amount: float = smoothstep(0.0, 1.0, float(_reveal.get(seat, 0.0)))
	for index in range(row.size()):
		var card: CardView = row[index]
		var lying: Transform3D = _slot(seat, index)
		if index == int(_pending.get(seat, -1)):
			lying.origin.y += PENDING_RAISE
		if amount <= 0.0 or viewer == null:
			card.transform = lying
			continue
		var shown: Transform3D = _peek_pose(seat, index, row.size(), viewer.eye_position())
		# 회전은 쿼터니언으로 섞고, 크기는 누운 1배 → 펼친 PEEK_SCALE 배로 함께 커진다.
		var turn := Basis(lying.basis.get_rotation_quaternion().slerp(shown.basis.get_rotation_quaternion(), amount))
		card.transform = Transform3D(turn.scaled(Vector3.ONE * lerpf(1.0, PEEK_SCALE, amount)),
			lying.origin.lerp(shown.origin, amount))


## 매트 칸에 앞면이 위로 누운 카드. 카드 +Z(아래 가장자리)가 자리 쪽이라 주인이 바로 읽는다(남은 거꾸로·옆으로 본다).
func _slot(seat: int, slot: int) -> Transform3D:
	var basis := _seat_basis(seat)
	var local := Vector3(TableCards.SLOT_X0 + slot * TableCards.SLOT_GAP, 0, TableCards.SLOT_Z)
	var height: float = TableView.TABLE_HEIGHT + TableCards.MAT_TOP + seat * 0.0006 + CardView.THICKNESS
	return Transform3D(basis, TableView.TABLE_CENTER + basis * local + Vector3.UP * height)


## 엿본 카드: 매트 위로 떠올라 eye 쪽을 보고 옆으로 나란히 펼친다(내 화면 기준 왼쪽 → 오른쪽 = 손패 순서).
func _peek_pose(seat: int, index: int, count: int, eye: Vector3) -> Transform3D:
	var center: Vector3 = _mat_center(seat) + Vector3.UP * PEEK_RAISE
	var toward_me: Vector3 = eye - center
	toward_me.y = 0.0
	toward_me = toward_me.normalized()
	var right: Vector3 = (-toward_me).cross(Vector3.UP).normalized()
	var offset: float = index - (count - 1) * 0.5
	var origin: Vector3 = center + right * offset * PEEK_GAP * PEEK_SCALE
	# 앞면(+Y)은 위와 눈 방향 사이, 아래 가장자리(+Z)는 나를 향한다. X = Y × Z 로 오른손 좌표를 맞춘다.
	var face: Vector3 = Vector3.UP.lerp((eye - origin).normalized(), PEEK_FACE).normalized()
	var bottom: Vector3 = (toward_me - face * toward_me.dot(face)).normalized()
	var basis := Basis(face.cross(bottom), face, bottom)
	return Transform3D(basis.rotated(face, -offset * PEEK_FAN), origin)


## 자리 매트 가운데(카드 줄 가운데 높이). 엿보기 판정과 펼치는 자리에 쓴다.
func _mat_center(seat: int) -> Vector3:
	var local := Vector3(TableCards.SLOT_X0 + 3 * TableCards.SLOT_GAP, 0, TableCards.SLOT_Z)
	return TableView.TABLE_CENTER + _seat_basis(seat) * local + Vector3.UP * (TableView.TABLE_HEIGHT + TableCards.MAT_TOP)


## 자리 쪽을 +Z 로 보는 방향(테이블 가운데 기준). 펍 생성기 game_room_builder.gd 의 자리 매트와 같은 각도다.
func _seat_basis(seat: int) -> Basis:
	var seat_position: Vector3 = TableView.SEATS[seat]
	var toward := Vector3(seat_position.x - TableView.TABLE_CENTER.x, 0, seat_position.z - TableView.TABLE_CENTER.z).normalized()
	return Basis(Vector3.UP, atan2(toward.x, toward.z))
