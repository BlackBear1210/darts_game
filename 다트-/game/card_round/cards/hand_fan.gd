extends Node3D
## 왼손에 든 카드 부채. 테이블 7칸과 같은 카드를 같은 번호 순서로 든다(칸 번호 = 부채 왼쪽부터).
## 하스스톤 손패처럼 부채꼴로 펼치고, 꺼내 든(대기) 카드는 위로 빠져나와 커지며 똑바로 선다. 이웃 카드는 옆으로 비킨다.
## 로컬 좌표: 부채 면이 +Z(보는 사람 쪽), 위 = +Y, 원점 = 손(부채 꼭지).
## 1인칭(카메라 자식)과 캐릭터 왼손(몸 자식)에 같은 코드를 쓰고 크기·각도만 다르게 준다.
## 카드는 목표 자세를 매 프레임 따라간다 → 넣기·빼기·꺼내기가 따로 애니메이션 없이 부드럽게 이어진다.

const CardView = preload("res://game/card_round/cards/card_view.gd")

## 목표 자세를 따라가는 빠르기(클수록 빠르다).
const FOLLOW: float = 14.0
## 꺼내 든 카드 양옆이 비켜나는 각도.
const MAKE_ROOM_DEGREES: float = 6.0
const REWARD_GLOW := Color("ffcf4a")
const READY_GLOW := Color("8cf0a0")

var spread_degrees: float = 44.0
var radius: float = 0.12
var card_scale: float = 1.0
var lift_height: float = 0.065
var lift_scale: float = 1.25
var lift_forward: float = 0.03
var show_keys: bool = false
var layer_mask: int = 1
var cast_shadows: bool = true
## slot(0~6 = 7칸, 7~8 = 보상 카드) → CardView
var cards: Dictionary = {}
var lifted_slot: int = -1
## 꺼내 든 카드가 쓸 수 있게 될 때까지의 진행(0~1). 1 이면 테두리가 초록빛.
var ready_ratio: float = 0.0


## slot 칸에 카드를 놓는다(있던 카드는 바꾼다). reward = 방해 보상 카드(8·9번 칸).
func set_card(slot: int, card_type: int, reward: bool = false) -> void:
	remove_card(slot)
	var card := CardView.new()
	card.name = "Card_%d" % slot
	add_child(card)
	card.set_type(card_type)
	card.show_face(true)
	card.set_layers(layer_mask)
	card.set_shadow(cast_shadows)
	card.set_meta("reward", reward)
	if show_keys:
		card.show_key(str(slot + 1))
	card.position = Vector3(0, radius * 0.4, 0)
	card.scale = Vector3.ONE * 0.001
	cards[slot] = card
	if reward:
		card.set_glow(0.75, REWARD_GLOW)


## slot 칸 카드를 치운다(없으면 아무것도 안 한다).
func remove_card(slot: int) -> void:
	var card: Node3D = cards.get(slot)
	if card == null:
		return
	cards.erase(slot)
	if lifted_slot == slot:
		lifted_slot = -1
	card.vanish(0.35)


## slot 칸에 카드가 있는가.
func has_card(slot: int) -> bool:
	return cards.has(slot)


## slot 카드를 꺼내 든다(준비 막대는 0부터 다시).
func lift(slot: int) -> void:
	lifted_slot = slot if cards.has(slot) else -1
	ready_ratio = 0.0


## 꺼내 든 카드를 내려놓는다.
func lower() -> void:
	lifted_slot = -1
	ready_ratio = 0.0


func _process(delta: float) -> void:
	var order: Array = cards.keys()
	order.sort()
	var count: int = order.size()
	var weight: float = 1.0 - exp(-FOLLOW * delta)
	var lifted_index: int = order.find(lifted_slot)
	for i in range(count):
		var card: Node3D = cards[order[i]]
		var lifted: bool = i == lifted_index
		var t: float = 0.5 if count == 1 else float(i) / (count - 1)
		var angle: float = deg_to_rad(lerpf(spread_degrees * 0.5, -spread_degrees * 0.5, t))
		if lifted_index >= 0 and not lifted:
			angle += deg_to_rad(MAKE_ROOM_DEGREES) * signf(lifted_index - i)
		if lifted:
			angle *= 0.2
		var turn := Basis(Vector3.BACK, angle)
		var spot: Vector3 = turn * Vector3(0, radius, 0) + Vector3(0, 0, i * 0.0016)
		var size: float = card_scale
		if lifted:
			spot += turn * Vector3(0, lift_height, 0) + Vector3(0, 0, lift_forward)
			size *= lift_scale
		card.position = card.position.lerp(spot, weight)
		card.quaternion = card.quaternion.slerp((turn * Basis(Vector3.RIGHT, PI / 2)).get_rotation_quaternion(), weight)
		card.scale = card.scale.lerp(Vector3.ONE * size, weight)
		if lifted:
			card.set_glow(0.4 + 0.5 * ready_ratio, READY_GLOW if ready_ratio >= 1.0 else CardView.GLOW_COLOR)
		elif bool(card.get_meta("reward", false)):
			card.set_glow(0.75, REWARD_GLOW)
		else:
			card.set_glow(0.0)
