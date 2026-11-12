class_name BoardLayout
extends Resource
## 과녁 앞면의 로컬 XY 좌표를 반지름으로 나눠 -1~1로 판정한다.

const DEFAULT_NUMBERS: Array[int] = [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5]
const INNER_BULL: float = 0.037
const OUTER_BULL: float = 0.093
const TRIPLE_INNER: float = 0.582
const TRIPLE_OUTER: float = 0.629
const DOUBLE_INNER: float = 0.953
const RADIUS: float = 0.30

@export var numbers: Array[int] = DEFAULT_NUMBERS.duplicate()
@export var ring_multipliers: Array[int] = [1, 2, 3]
@export var inner_bull_score: int = 50
@export var outer_bull_score: int = 25
var blocked_sectors: Array[int] = []
var hidden_sectors: Array[int] = []
var overrides: Dictionary = {}


func reset() -> void:
	numbers = DEFAULT_NUMBERS.duplicate()
	ring_multipliers = [1, 2, 3]
	inner_bull_score = 50
	outer_bull_score = 25
	blocked_sectors.clear()
	hidden_sectors.clear()
	overrides.clear()


func shuffle_with(random: RandomNumberGenerator) -> void:
	for index in range(numbers.size() - 1, 0, -1):
		var other := random.randi_range(0, index)
		var number := numbers[index]
		numbers[index] = numbers[other]
		numbers[other] = number


## 값 계열 방해카드의 실제 변화. F5와 F6의 강화 범위가 달라지지 않게 공유한다.
func apply_card_change(kind: String, choice: int, players: int, random: RandomNumberGenerator) -> void:
	var catalog = preload("res://game/card_round/rules/card_catalog.gd")
	var factor: float = catalog.synergy_factor(players)
	match kind:
		"shuffle":
			shuffle_with(random)
			if players >= 2:
				for index in range(20): numbers[index] = random.randi_range(1, 20)
			if players >= 3: apply_card_change("ink_board", -1, 1, random)
		"random_scores":
			for index in range(20): numbers[index] = random.randi_range(1, roundi(20 * factor))
			for index in range(3): ring_multipliers[index] = random.randi_range(1, 3)
			inner_bull_score = random.randi_range(25, roundi(60 * factor))
			outer_bull_score = random.randi_range(10, roundi(40 * factor))
		"lock_scores":
			var regions: Array[int] = []
			for region in range(82):
				if not overrides.has(region): regions.append(region)
			var value: int = random.randi_range(1, 20)
			for index in range(mini(regions.size(), roundi(random.randi_range(5, 20) * factor))):
				var selected: int = random.randi_range(0, regions.size() - 1)
				overrides[regions[selected]] = value
				regions.remove_at(selected)
		"block_sector":
			for offset in range(clampi(players, 1, 3)):
				var selected: int = posmod(choice + (offset if offset < 2 else -1), 20)
				if selected not in blocked_sectors: blocked_sectors.append(selected)
		"ink_board":
			var sectors: Array[int] = []
			for index in range(20):
				if index not in hidden_sectors: sectors.append(index)
			while hidden_sectors.size() < roundi(5 * factor) and not sectors.is_empty():
				var selected: int = random.randi_range(0, sectors.size() - 1)
				hidden_sectors.append(sectors[selected])
				sectors.remove_at(selected)


static func sector_at(point: Vector2) -> int:
	# 20 구역은 위쪽을 중심으로 하고, 각도는 시계 방향으로 증가한다.
	var angle := fposmod(atan2(point.x, point.y) + PI / 20.0, TAU)
	return int(floor((angle + 0.0000001) / (TAU / 20.0))) % 20


## 20섹터 × 4개 물리 링 + 내불·외불의 점수 표.
func region_score(region: int) -> int:
	if region < 0: return 0
	if overrides.has(region): return int(overrides[region])
	if region == 80: return inner_bull_score
	if region == 81: return outer_bull_score
	var sector: int = region / 4
	if sector in blocked_sectors: return 0
	var ring: int = region % 4
	var multiplier: int = ring_multipliers[2] if ring == 1 else (ring_multipliers[1] if ring == 3 else ring_multipliers[0])
	return numbers[sector] * multiplier


func to_snapshot() -> Dictionary:
	return {"numbers": numbers.duplicate(), "multipliers": ring_multipliers.duplicate(), "inner": inner_bull_score,
		"outer": outer_bull_score, "blocked": blocked_sectors.duplicate(), "hidden": hidden_sectors.duplicate(), "overrides": overrides.duplicate()}


func apply_snapshot(data: Dictionary) -> void:
	if data.get("numbers", []).size() == 20: numbers.assign(data.numbers)
	if data.get("multipliers", []).size() == 3: ring_multipliers.assign(data.multipliers)
	inner_bull_score = int(data.get("inner", 50))
	outer_bull_score = int(data.get("outer", 25))
	blocked_sectors.assign(data.get("blocked", []))
	hidden_sectors.assign(data.get("hidden", []))
	overrides.clear()
	for key in data.get("overrides", {}): overrides[int(key)] = int(data.overrides[key])
