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
## 1인칭 한 줄 손패에서 꺼내 든 카드와 왼쪽·오른쪽 이웃 카드 중심 사이 거리(카드 폭 배수).
## 앞에 선 꺼내 든 카드는 이웃을 덮는다. 오른쪽 이웃은 왼쪽 끝에 제목이 있어 한 장 폭을 다 비우고,
## 왼쪽 이웃은 오른쪽 끝(그림 가장자리)만 조금 덮인다.
const ROW_GAP_LEFT: float = 0.85
const ROW_GAP_RIGHT: float = 1.04
const REWARD_GLOW := Color("ffcf4a")
const READY_GLOW := Color("8cf0a0")

## 1인칭 손패가 차지하는 화면 영역(왼쪽, 위, 너비, 높이).
const HAND_RECT := Rect2(0.023, 0.725, 0.43, 0.272)
const ROW_DEPTH := 0.42
## 1인칭 손패에서 오른쪽 카드가 왼쪽 카드보다 카메라에 가까운 거리(m).
const ROW_STACK_STEP: float = 0.003
## 꺼내 든 카드가 줄보다 카메라 쪽으로 나오는 거리(m).
const ROW_LIFT_DEPTH: float = 0.034
## 1인칭 손패 입체감(2026-11-26 시안): 손에 쥔 것처럼 카드마다 조금씩 돌려 완만한 부채꼴로,
## 위쪽은 뒤로 눕히고, 바깥 카드일수록 조금 내린다(카드 높이 배수).
const ROW_ARC_STEP_DEGREES: float = 2.0
const ROW_TILT_DEGREES: float = 7.0
const ROW_ARC_DROP: float = 0.04
## 돌린 카드는 위아래로 길어져 아래 가장자리(체크 띠·두께 띠)가 화면 밖으로 나간다 → 줄 전체를 이만큼 올린다.
const ROW_ARC_RAISE: float = 0.09
## 꺼내 든 카드의 그림자는 뒤 카드들 위로 넓게 떨어진다(크기 배율).
const LIFTED_SHADOW_GROW: float = 1.6
var row_camera: Camera3D

## 1인칭 한 줄 손패에서 카드 한 장의 화면 크기(px). 줄 배치(_process)와 HUD 의 손패 위 '내가 쓴 카드' 줄(ui/used_cards.gd)이 같이 쓴다.
static func row_card_size(viewport_size: Vector2) -> Vector2:
	var area := HAND_RECT.size * viewport_size
	var width := minf(area.y * CardView.SIZE.x / CardView.SIZE.y, area.x * 0.36)
	return Vector2(width, width * CardView.SIZE.y / CardView.SIZE.x)


## 1인칭 손패 줄의 윗가장자리(화면 y, px). ROW_ARC_RAISE 로 올린 것까지 넣는다. 꺼내 든 카드는 이보다 더 올라온다.
static func row_top(viewport_size: Vector2) -> float:
	return HAND_RECT.end.y * viewport_size.y - row_card_size(viewport_size).y * (1.0 + ROW_ARC_RAISE)


func configure_screen_row(camera: Camera3D) -> void:
	row_camera = camera
	transform = Transform3D.IDENTITY
	cast_shadows = false
	lit = false
	depth_cues = true


var spread_degrees: float = 44.0
var radius: float = 0.12
var card_scale: float = 1.0
var lift_height: float = 0.065
var lift_scale: float = 1.25
var lift_forward: float = 0.03
var layer_mask: int = 1
var cast_shadows: bool = true
## false = 조명을 받지 않는다(1인칭 부채 — 방이 어두워도 글자가 읽힌다).
var lit: bool = true
## true = 카드마다 두께 띠·그림자 판을 붙인다(1인칭 부채 — 조명을 안 받아 진짜 그림자가 없다).
var depth_cues: bool = false
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
	if depth_cues:
		card.add_depth_cues()
	card.set_layers(layer_mask)
	card.set_shadow(cast_shadows)
	card.set_lit(lit)
	card.set_meta("reward", reward)
	card.position = row_camera.to_local(row_camera.project_position(row_camera.get_viewport().get_visible_rect().size * Vector2(HAND_RECT.position.x, HAND_RECT.end.y), ROW_DEPTH)) if row_camera != null else Vector3(0, radius * 0.4, 0)
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
		var turn := Basis.IDENTITY
		var spot: Vector3
		var size := card_scale
		if row_camera != null:
			var viewport_size := row_camera.get_viewport().get_visible_rect().size
			var rect := Rect2(HAND_RECT.position * viewport_size, HAND_RECT.size * viewport_size)
			var card_size := row_card_size(viewport_size)
			var width := card_size.x
			var height := card_size.y
			var step := (rect.size.x - width) / maxi(6, count - 1)
			step -= maxf(width - step, 0.0) * 0.21
			var offset := _row_offset(i, count, lifted_index, step, width, rect.size.x - width)
			var center := Vector2(rect.position.x + width * 0.5 + offset, rect.end.y - height * 0.5)
			var depth := ROW_DEPTH - ROW_STACK_STEP * i
			# 가운데에서 몇 장 떨어졌는가(-1 = 왼쪽 끝, 1 = 오른쪽 끝).
			var from_middle: float = 0.0 if count < 2 else (i - (count - 1) * 0.5) / ((count - 1) * 0.5)
			var arc: float = -deg_to_rad(ROW_ARC_STEP_DEGREES) * (i - (count - 1) * 0.5)
			var tilt: float = deg_to_rad(ROW_TILT_DEGREES)
			center.y += height * (ROW_ARC_DROP * from_middle * from_middle - ROW_ARC_RAISE)
			if lifted:
				center.y -= height * 0.17
				depth -= ROW_LIFT_DEPTH
				arc = 0.0
				tilt *= 0.4
			# 화면 면 안에서 돌리고(부채꼴), 위쪽을 카메라 반대쪽으로 눕힌다.
			turn = Basis(Vector3.BACK, arc) * Basis(Vector3.RIGHT, -tilt)
			spot = row_camera.to_local(row_camera.project_position(center, depth))
			var right := row_camera.to_local(row_camera.project_position(center + Vector2.RIGHT * width, depth))
			size = right.distance_to(spot) / CardView.SIZE.x
			_follow_contact_shadow(card, lifted, size, weight)
		else:
			var t: float = 0.5 if count == 1 else float(i) / (count - 1)
			var angle: float = deg_to_rad(lerpf(spread_degrees * 0.5, -spread_degrees * 0.5, t))
			if lifted_index >= 0 and not lifted:
				angle += deg_to_rad(MAKE_ROOM_DEGREES) * signf(lifted_index - i)
			if lifted:
				angle *= 0.2
			turn = Basis(Vector3.BACK, angle)
			spot = turn * Vector3(0, radius, 0) + Vector3(0, 0, i * 0.0016)
			if lifted:
				spot += turn * Vector3(0, lift_height, lift_forward)
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


## 그림자 판을 바로 뒤 카드 앞면 위에 놓는다. 꺼내 들면 줄에서 떨어진 만큼 뒤로, 넓게 옮겨 간다.
## 카드 크기 배율(size)이 판까지 거리에도 곱해지므로 나눠서 세상 거리로 맞춘다.
func _follow_contact_shadow(card: Node3D, lifted: bool, size: float, weight: float) -> void:
	var raised: float = lerpf(float(card.get_meta("shadow_raised", 0.0)), 1.0 if lifted else 0.0, weight)
	card.set_meta("shadow_raised", raised)
	var behind: float = lerpf(ROW_STACK_STEP * 0.6, ROW_LIFT_DEPTH - ROW_STACK_STEP, raised)
	card.place_contact_shadow(behind / maxf(size, 0.001), lerpf(1.0, LIFTED_SHADOW_GROW, raised))


## 1인칭 한 줄 손패에서 i번째 카드 중심의 가로 위치(첫 카드 중심 기준, 픽셀).
## 꺼내 든 카드가 있으면 그 카드를 사이에 두고 왼쪽 무리와 오른쪽 무리가 갈라진다.
## 갈라진 만큼 양쪽 무리는 손패 영역(max_span) 안에서 더 촘촘히 겹친다(원래 간격 step 보다 넓어지지는 않는다).
func _row_offset(i: int, count: int, lifted_index: int, step: float, width: float, max_span: float) -> float:
	if lifted_index < 0 or count < 2:
		return step * i
	var left_count: int = lifted_index
	var right_count: int = count - 1 - lifted_index
	var gap_left: float = ROW_GAP_LEFT * width if left_count > 0 else 0.0
	var gap_right: float = ROW_GAP_RIGHT * width if right_count > 0 else 0.0
	var packed: int = maxi(left_count - 1, 0) + maxi(right_count - 1, 0)
	var tight: float = step
	if packed > 0:
		tight = clampf((max_span - gap_left - gap_right) / packed, 0.0, step)
	var lifted_at: float = maxi(left_count - 1, 0) * tight + gap_left
	var total: float = lifted_at + gap_right + maxi(right_count - 1, 0) * tight
	# 꺼내 든 카드는 원래 자리에 가깝게 두되, 줄 전체가 손패 영역을 벗어나지 않게 민다.
	var start: float = clampf(step * lifted_index - lifted_at, 0.0, maxf(max_span - total, 0.0))
	if i < lifted_index:
		return start + i * tight
	if i == lifted_index:
		return start + lifted_at
	return start + lifted_at + gap_right + (i - lifted_index - 1) * tight
