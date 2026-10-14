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


func reset() -> void:
	numbers = DEFAULT_NUMBERS.duplicate()


func shuffle_with(random: RandomNumberGenerator) -> void:
	for index in range(numbers.size() - 1, 0, -1):
		var other := random.randi_range(0, index)
		var number := numbers[index]
		numbers[index] = numbers[other]
		numbers[other] = number


static func sector_at(point: Vector2) -> int:
	# 20 구역은 위쪽을 중심으로 하고, 각도는 시계 방향으로 증가한다.
	var angle := fposmod(atan2(point.x, point.y) + PI / 20.0, TAU)
	return int(floor(angle / (TAU / 20.0))) % 20
