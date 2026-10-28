extends Node3D
## 원형 테이블 위의 카드 전부: 가운데 덱 더미, 자리마다 7칸(왼손과 같은 카드), 방해 보상 예약 2칸.
## 칸 위치는 펍 생성물의 자리 매트(art/pub/game_room_builder.gd: 카드 7칸 x = -0.36 + 0.12c, z = 0.66 / 예약 칸 z = 0.49)와 같다.
## 좌표는 월드 기준(이 노드는 원점에 둔다). 규칙(누가 무슨 카드)은 round_rules.gd 가 정하고 여기서는 보여 주기만 한다.

const CardView = preload("res://game/card_round/cards/card_view.gd")
const ShuffleMotions = preload("res://game/card_round/cards/shuffle_motions.gd")
const CardFaces = preload("res://game/card_round/cards/card_faces.gd")

## 덱 더미 중심(테이블 펠트 위)과 방향.
const DECK_YAW: float = 0.35
## 펠트 윗면 높이 = 테이블 높이 + 펠트(0.011). 자리 매트는 그보다 조금 높다.
const FELT_TOP: float = 0.011
const MAT_TOP: float = 0.017
const SLOT_X0: float = -0.36
const SLOT_GAP: float = 0.12
const SLOT_Z: float = 0.66
const RESERVE_X: Array[float] = [-0.08, 0.08]
const RESERVE_Z: float = 0.49
## 한 장 나눠 주는 비행 시간과 포물선 높이.
const DEAL_FLIGHT: float = 0.34
const DEAL_ARC: float = 0.12
## 가운데·밑장에서 뺄 때: 옆으로 빼내는 거리(m)·시간(초), 위 카드들을 들추는 높이(m).
const PULL_OUT: float = 0.16
const PULL_SECONDS: float = 0.22
const PULL_LIFT: float = 0.018

## 덱 더미(아래 → 위). round_rules.deck 과 같은 장수·같은 순서 번호를 쓴다.
var pile: Array = []
## 자리별 칸: seat → Array(9) = 7칸 + 예약 2칸. 빈 칸은 null.
var slots: Array = []
## 사용 표시가 남은 카드(다음 충전 라운드에 치운다).
var used: Array = []
var _random := RandomNumberGenerator.new()


## 자리 수만큼 빈 칸 표(카드 7칸 + 보상 2칸)를 만든다. 카드를 놓기 전에 한 번.
func setup(seat_count: int) -> void:
	slots.clear()
	for seat in range(seat_count):
		var row: Array = []
		row.resize(CardHandRules.HAND_LIMIT + RESERVE_X.size())
		slots.append(row)


## 테이블 가운데 덱 자리(펠트 위).
func deck_center() -> Vector3:
	return TableView.TABLE_CENTER + Vector3.UP * (TableView.TABLE_HEIGHT + FELT_TOP)


## 자리 seat 의 slot 번째 칸(0~6 = 카드 7칸, 7~8 = 예약 칸). 카드 +Z 가 자리 쪽 → 앉은 사람이 똑바로 읽는다.
func slot_transform(seat: int, slot: int) -> Transform3D:
	var seat_position: Vector3 = TableView.SEATS[seat]
	var toward := Vector3(seat_position.x - TableView.TABLE_CENTER.x, 0, seat_position.z - TableView.TABLE_CENTER.z).normalized()
	var basis := Basis(Vector3.UP, atan2(toward.x, toward.z))
	var local := Vector3(SLOT_X0 + slot * SLOT_GAP, 0, SLOT_Z)
	if slot >= CardHandRules.HAND_LIMIT:
		local = Vector3(RESERVE_X[slot - CardHandRules.HAND_LIMIT], 0, RESERVE_Z)
	var height: float = TableView.TABLE_HEIGHT + MAT_TOP + seat * 0.0006 + CardView.THICKNESS
	return Transform3D(basis, TableView.TABLE_CENTER + basis * local + Vector3.UP * height)


## 처음 상태: 테이블 가운데에 덱이 흐트러져 있다.
func scatter(count: int) -> void:
	for i in range(count):
		var card := CardView.new()
		add_child(card)
		card.transform = _scattered_transform(i + pile.size())
		pile.append(card)


## 충전 라운드: 덱에 새 카드가 더해진다(위에서 툭툭 떨어져 흩어진다).
func drop_in(count: int) -> void:
	for i in range(count):
		var card := CardView.new()
		add_child(card)
		var rest: Transform3D = _scattered_transform(pile.size())
		card.transform = Transform3D(rest.basis, rest.origin + Vector3.UP * 0.5)
		card.scale = Vector3.ONE * 0.001
		pile.append(card)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(card, "scale", Vector3.ONE, 0.25).set_delay(i * 0.02)
		tween.tween_property(card, "position", rest.origin, 0.4).set_delay(i * 0.02).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await ShuffleMotions.wait(self, count * 0.02 + 0.45)


## 덱 섞기 연출(style = 정석 리플·마술사·딜러, shuffle_motions.gd). face_types = 섞는 동안 살짝 보이는 앞면 종류.
func shuffle(style: int, face_types: Array[int]) -> void:
	await ShuffleMotions.play(style, self, pile, deck_center(), DECK_YAW, face_types)


## 덱의 index 번째 카드를 빼서 자리 칸으로 날린다.
## 맨 위가 아니면(가운데·밑장) 위 카드들을 살짝 들춘 채 옆으로 빼낸 뒤 날아가고, 위 카드들이 다시 내려앉는다.
## 2026-10-28 사용자 피드백: 뽑는 곳이 한 장마다 무작위가 되어, 밑장·가운데 빼기는 천천히 보이게 하고 덱 위에 글자를 띄운다.
func deal_card(index: int, card_type: int, seat: int, slot: int) -> void:
	var card: Node3D = pile[index]
	pile.remove_at(index)
	card.set_type(card_type)
	slots[seat][slot] = card
	var to: Transform3D = slot_transform(seat, slot)
	if index < pile.size():
		_pop_label("밑장!" if index == 0 else "가운데!", Color("ff8a6a") if index == 0 else PubTheme.GOLD)
		for i in range(index, pile.size()):
			var above: Node3D = pile[i]
			create_tween().tween_property(above, "position", above.position + Vector3.UP * PULL_LIFT, PULL_SECONDS * 0.5)
		var out: Vector3 = card.transform.basis * Vector3(PULL_OUT, 0, 0)
		var pull := create_tween()
		pull.tween_property(card, "position", card.position + out, PULL_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await pull.finished
		for i in range(index, pile.size()):
			ShuffleMotions.move(self, pile[i], ShuffleMotions.stack_transform(deck_center(), DECK_YAW, i), 0.12)
	ShuffleMotions.move(self, card, to, DEAL_FLIGHT, 0.0, DEAL_ARC)


## 덱 위로 잠깐 떠올랐다 사라지는 글자("밑장!" · "가운데!").
func _pop_label(text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = CardFaces.bold_font()
	label.font_size = 72
	label.pixel_size = 0.0022
	label.outline_size = 16
	label.outline_modulate = Color("122b27")
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)
	label.position = deck_center() + Vector3.UP * 0.22
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position", label.position + Vector3.UP * 0.16, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tween.chain().tween_callback(label.queue_free)


## 이번에 나눠 준(아직 뒷면인) 카드를 자리별로 물결치듯 앞면으로 뒤집는다.
func reveal() -> void:
	var order: int = 0
	for seat in range(slots.size()):
		for slot in range(slots[seat].size()):
			var card: Node3D = slots[seat][slot]
			if card != null and not card.face_up:
				ShuffleMotions.flip(self, card, true, 0.26, order * 0.045)
				order += 1
	await ShuffleMotions.wait(self, order * 0.045 + 0.35)


## 자리 seat 의 slot 칸에 놓인 카드 노드(없으면 null).
func card_at(seat: int, slot: int) -> Node3D:
	return slots[seat][slot]


## 꺼내 든 카드는 테이블에서도 살짝 떠오르고 테두리가 빛난다(다른 사람이 보고 대응할 수 있게).
func set_pending(seat: int, slot: int, ratio: float) -> void:
	for index in range(slots[seat].size()):
		var card: Node3D = slots[seat][index]
		if card == null or not card.face_up or card.mark_style >= 0:
			continue
		var lifted: bool = index == slot
		card.body.position.y = lerpf(card.body.position.y, 0.025 if lifted else 0.0, 0.25)
		card.set_glow(0.35 + 0.55 * ratio if lifted else 0.0, Color("8cf0a0") if lifted and ratio >= 1.0 else CardView.GLOW_COLOR)


## 쓴 카드: 칸에 그대로 남아 사용 표시(페인트 X / 그을림). 칸은 비워 다음 충전 때 새 카드가 온다.
func mark_used(seat: int, slot: int, style: int) -> void:
	var card: Node3D = slots[seat][slot]
	if card == null:
		return
	slots[seat][slot] = null
	card.set_glow(0.0)
	card.body.position.y = 0.0
	used.append(card)
	card.mark_used(style)


## 충전 라운드 시작: 사용 표시가 남은 카드는 테이블 밖으로 사라진다(소멸).
func clear_used() -> void:
	if used.is_empty():
		return
	for i in range(used.size()):
		var card: Node3D = used[i]
		var tween := create_tween()
		tween.tween_interval(i * 0.03)
		tween.tween_property(card, "position", card.position + Vector3.UP * 0.06, 0.18)
		tween.tween_property(card, "scale", Vector3.ONE * 0.001, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_callback(card.queue_free)
	await ShuffleMotions.wait(self, used.size() * 0.03 + 0.45)
	used.clear()


## 방해 성공 보상 카드: 예약 칸에 금빛으로 떨어진다(이번 라운드 한정).
func give_reward(seat: int, reserve_index: int, card_type: int) -> void:
	var slot: int = CardHandRules.HAND_LIMIT + reserve_index
	var card := CardView.new()
	add_child(card)
	card.set_type(card_type)
	card.show_face(true)
	var rest: Transform3D = slot_transform(seat, slot)
	card.transform = Transform3D(rest.basis, rest.origin + Vector3.UP * 0.45)
	card.set_glow(0.8, Color("ffcf4a"))
	slots[seat][slot] = card
	var tween := create_tween()
	tween.tween_property(card, "position", rest.origin, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## 라운드 끝: 예약 칸의 라운드 한정 카드가 사라진다. 다른 보상 카드는 앞 칸으로 당긴다.
func clear_rewards() -> void:
	for seat in range(slots.size()):
		for reserve in range(RESERVE_X.size()):
			var slot: int = CardHandRules.HAND_LIMIT + reserve
			var card: Node3D = slots[seat][slot]
			if card != null:
				slots[seat][slot] = null
				card.vanish(0.4)


## 보상 칸 앞쪽(8번)이 비었으면 뒤쪽(9번) 카드를 당겨 채운다.
func compact_rewards(seat: int) -> void:
	var first: int = CardHandRules.HAND_LIMIT
	if slots[seat][first] == null and slots[seat][first + 1] != null:
		var card: Node3D = slots[seat][first + 1]
		slots[seat][first] = card
		slots[seat][first + 1] = null
		ShuffleMotions.move(self, card, slot_transform(seat, first), 0.2)


## 칸에서 카드를 지운다(무효로 사라진 보상 카드처럼 표시를 남기지 않는 경우).
func remove(seat: int, slot: int) -> void:
	var card: Node3D = slots[seat][slot]
	if card != null:
		slots[seat][slot] = null
		card.vanish(0.35)


## 자리 seat 의 카드 7칸 중 카드가 있는 칸 수.
func filled(seat: int) -> int:
	var count: int = 0
	for slot in range(CardHandRules.HAND_LIMIT):
		count += 1 if slots[seat][slot] != null else 0
	return count


## 흐트러진 덱 상태의 카드 한 장 위치(덱 둘레에 무작위로 겹쳐 놓기).
func _scattered_transform(index: int) -> Transform3D:
	var angle: float = _random.randf() * TAU
	var radius: float = sqrt(_random.randf()) * 0.4
	var spot: Vector3 = deck_center() + Vector3(cos(angle) * radius, index * 0.0012, sin(angle) * radius)
	return Transform3D(Basis(Vector3.UP, _random.randf() * TAU), spot)
