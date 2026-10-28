extends RefCounted
## 테이블 가운데 덱이 스스로 섞이는 모션(딜러 손 없이 카드만 움직인다). 2026-10-28 사용자 기획:
## "정석으로 섞는 모습, 마술사들이 섞는 모습, 딜러들이 섞는 모습 등 다양하게" → 지금 3가지, STYLES 에 더하면 늘어난다.
## 모든 모션은 흩어진 카드를 모으는 데서 시작해 가운데에 반듯하게 쌓인 덱(stack_transform)으로 끝난다.
## 보이는 순서만 바뀌고 실제 카드 순서는 round_rules.gd 가 따로 섞는다(뒷면이 다 같아서 화면과 어긋나 보이지 않는다).

enum Style { RIFFLE, MAGICIAN, DEALER }

## 설정 화면 이름. Style 순서.
const STYLE_NAMES: Array[String] = ["정석 리플", "마술사", "딜러"]
## 덱에서 카드 한 장의 높이(m). 실제 두께(1.6mm)보다 조금 띄워 깜빡임을 막는다.
const STACK_STEP: float = 0.0019


## 쌓인 덱의 i 번째 카드 자리(0 = 맨 아래). 카드는 뒷면이 위(Body 가 뒤집혀 있음).
static func stack_transform(center: Vector3, yaw: float, index: int, offset := Vector3.ZERO) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), center + offset + Vector3.UP * (index * STACK_STEP))


## cards = 덱 카드(아래 → 위). 모션이 끝나면 cards 순서가 화면에 쌓인 순서와 같아진다.
static func play(style: int, host: Node, cards: Array, center: Vector3, yaw: float, face_types: Array[int]) -> void:
	match style:
		Style.RIFFLE: await _riffle(host, cards, center, yaw)
		Style.MAGICIAN: await _magician(host, cards, center, yaw, face_types)
		_: await _dealer(host, cards, center, yaw)


## 정석: 모으기 → 반으로 갈라 양옆 → 안쪽 모서리를 들어 번갈아 떨어뜨림(리플) ×2 → 탁탁 정리.
static func _riffle(host: Node, cards: Array, center: Vector3, yaw: float) -> void:
	var random := RandomNumberGenerator.new()
	var side: Vector3 = Basis(Vector3.UP, yaw) * Vector3.RIGHT
	await _gather(host, cards, center, yaw)
	for pass_index in range(2):
		var half: int = cards.size() / 2
		var left: Array = cards.slice(0, half)
		var right: Array = cards.slice(half)
		for i in range(left.size()):
			move(host, left[i], _tilted(center - side * 0.085, yaw + 0.2, i, 0.22), 0.22, 0.0, 0.02)
		for i in range(right.size()):
			move(host, right[i], _tilted(center + side * 0.085, yaw - 0.2, i, -0.22), 0.22, 0.0, 0.02)
		await wait(host, 0.32)
		# 아래부터 1~3장씩 번갈아 떨어진다.
		var merged: Array = []
		var a: int = 0
		var b: int = 0
		while a < left.size() or b < right.size():
			for k in range(random.randi_range(1, 3)):
				if a < left.size():
					merged.append(left[a])
					a += 1
			for k in range(random.randi_range(1, 3)):
				if b < right.size():
					merged.append(right[b])
					b += 1
		for i in range(merged.size()):
			move(host, merged[i], stack_transform(center, yaw, i), 0.13, i * 0.016, 0.035)
		await wait(host, merged.size() * 0.016 + 0.2)
		cards.assign(merged)
	await _square(host, cards, center, yaw)


## 마술사: 왼쪽 더미에서 오른쪽 더미로 카드가 공중을 날아가는 스프링 → 테이블에 리본처럼 펼침 →
## 도미노처럼 앞면으로 뒤집혔다 돌아옴 → 쓸어 모으기.
static func _magician(host: Node, cards: Array, center: Vector3, yaw: float, face_types: Array[int]) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var side: Vector3 = basis * Vector3.RIGHT
	var count: int = cards.size()
	await _gather(host, cards, center - side * 0.2, yaw)
	for i in range(count):
		var card: Node3D = cards[count - 1 - i]
		move(host, card, stack_transform(center + side * 0.2, yaw + 0.15, i), 0.34, i * 0.03, 0.2 + 0.05 * sin(i * 0.7))
	await wait(host, count * 0.03 + 0.4)
	cards.reverse()
	# 리본 펼침: 가운데를 둘러싼 넓은 호. 카드끼리 겹쳐 띠처럼 보인다.
	for i in range(count):
		var t: float = float(i) / maxf(count - 1, 1)
		var angle: float = lerpf(-1.25, 1.25, t)
		var spot: Vector3 = center + basis * Vector3(sin(angle) * 0.34, i * 0.0006, -cos(angle) * 0.2 + 0.08)
		move(host, cards[i], Transform3D(Basis(Vector3.UP, yaw - angle * 0.8), spot), 0.28, i * 0.012, 0.03)
	await wait(host, count * 0.012 + 0.35)
	for i in range(count):
		cards[i].set_type(face_types[i % face_types.size()] if not face_types.is_empty() else 0)
		flip(host, cards[i], true, 0.2, i * 0.022)
	await wait(host, count * 0.022 + 0.75)
	for i in range(count):
		flip(host, cards[i], false, 0.2, (count - 1 - i) * 0.022)
	await wait(host, count * 0.022 + 0.3)
	for i in range(count):
		move(host, cards[i], stack_transform(center, yaw, i), 0.3, i * 0.01, 0.02)
	await wait(host, count * 0.01 + 0.35)
	await _square(host, cards, center, yaw)


## 딜러: 테이블 위에 펼쳐 휘젓는 워시 → 모으기 → 위에서부터 덩어리를 옆으로 옮겨 쌓는 박스 셔플 → 정리.
static func _dealer(host: Node, cards: Array, center: Vector3, yaw: float) -> void:
	var random := RandomNumberGenerator.new()
	var side: Vector3 = Basis(Vector3.UP, yaw) * Vector3.RIGHT
	var count: int = cards.size()
	var radii: Array[float] = []
	var angles: Array[float] = []
	var speeds: Array[float] = []
	for i in range(count):
		radii.append(random.randf_range(0.06, 0.36))
		angles.append(random.randf() * TAU)
		speeds.append(random.randf_range(1.6, 3.2) * (1.0 if i % 2 == 0 else -1.0))
	for i in range(count):
		move(host, cards[i], _wash_transform(center, angles[i], radii[i], i), 0.3, i * 0.006, 0.02)
	await wait(host, count * 0.006 + 0.35)
	var wash := host.create_tween()
	wash.tween_method(func(t: float) -> void:
		for i in range(count):
			var card: Node3D = cards[i]
			card.transform = _wash_transform(center, angles[i] + speeds[i] * t, radii[i] * (1.0 + 0.25 * sin(t * 3.0 + i)), i)
	, 0.0, 1.7, 1.7)
	await wash.finished
	await _gather(host, cards, center, yaw)
	var packets: int = 4
	var per: int = ceili(count / float(packets))
	var stacked: Array = []
	for p in range(packets):
		var top: int = count - p * per
		var packet: Array = cards.slice(maxi(top - per, 0), top)
		for k in range(packet.size()):
			move(host, packet[k], stack_transform(center + side * 0.17, yaw, stacked.size() + k), 0.2, k * 0.002, 0.05)
		stacked.append_array(packet)
		await wait(host, 0.26)
	cards.assign(stacked)
	for i in range(count):
		move(host, cards[i], stack_transform(center, yaw, i), 0.24, 0.0)
	await wait(host, 0.3)
	await _square(host, cards, center, yaw)


## 흩어진 카드를 대충 한 더미로 모은다(조금씩 어긋난 채).
static func _gather(host: Node, cards: Array, center: Vector3, yaw: float) -> void:
	var random := RandomNumberGenerator.new()
	for i in range(cards.size()):
		var jitter := Vector3(random.randf_range(-0.01, 0.01), 0, random.randf_range(-0.01, 0.01))
		var target: Transform3D = stack_transform(center, yaw + random.randf_range(-0.12, 0.12), i, jitter)
		move(host, cards[i], target, 0.32, i * 0.008, 0.03)
	await wait(host, cards.size() * 0.008 + 0.38)


## 반듯하게 맞추고 "탁" 한 번 친다.
static func _square(host: Node, cards: Array, center: Vector3, yaw: float) -> void:
	for i in range(cards.size()):
		move(host, cards[i], stack_transform(center, yaw, i, Vector3.UP * 0.006), 0.1, 0.0)
	await wait(host, 0.12)
	for i in range(cards.size()):
		move(host, cards[i], stack_transform(center, yaw, i), 0.08, 0.0)
	await wait(host, 0.1)


## 리플 직전: 안쪽 모서리를 들어 살짝 기울인 반쪽 더미.
static func _tilted(center: Vector3, yaw: float, index: int, roll: float) -> Transform3D:
	var spot: Transform3D = stack_transform(center, yaw, index, Vector3.UP * 0.012)
	spot.basis = spot.basis * Basis(Vector3.BACK, roll)
	return spot


## 흩뜨려 섞기(워시) 중 카드 한 장의 위치·방향. angle·radius 로 덱 둘레를 돈다.
static func _wash_transform(center: Vector3, angle: float, radius: float, index: int) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, angle * 1.7), center + Vector3(cos(angle) * radius, index * 0.0011, sin(angle) * radius))


## 카드를 to 로 옮긴다. arc 만큼 위로 포물선을 그리고 가는 동안 방향이 따라 돈다.
static func move(host: Node, card: Node3D, to: Transform3D, duration: float, delay: float = 0.0, arc: float = 0.0) -> Tween:
	var tween := host.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	var from_holder: Array[Transform3D] = []
	tween.tween_callback(func() -> void: from_holder.append(card.transform))
	tween.tween_method(func(t: float) -> void:
		var from: Transform3D = from_holder[0]
		var spot: Vector3 = from.origin.lerp(to.origin, t) + Vector3.UP * arc * sin(PI * t)
		var turn: Quaternion = from.basis.get_rotation_quaternion().slerp(to.basis.get_rotation_quaternion(), t)
		card.transform = Transform3D(Basis(turn), spot)
	, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween


## 카드를 제자리에서 뒤집는다(Body 만 돈다). 도는 동안 살짝 떠오른다.
static func flip(host: Node, card: Node3D, up: bool, duration: float, delay: float = 0.0) -> Tween:
	var tween := host.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	var body: Node3D = card.get("body")
	var start: float = PI if up else 0.0
	var end: float = 0.0 if up else PI
	tween.tween_method(func(t: float) -> void:
		body.rotation.z = lerpf(start, end, t)
		body.position.y = sin(PI * t) * 0.03
	, 0.0, 1.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: card.set("face_up", up))
	return tween


## seconds 초 기다린다(게임 일시정지 중에는 멈춘다).
static func wait(host: Node, seconds: float) -> void:
	await host.get_tree().create_timer(seconds, false).timeout
