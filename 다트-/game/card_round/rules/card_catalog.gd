extends RefCounted
## 카드 라운드 시연에서 쓰는 카드 목록. 효과 수치는 전부 시연값이다(팀 확정 전).
## 종류(연산·다트·과녁·물리)는 손패 규칙 CardHandRules.Category 4종을 그대로 쓴다.
## art 가 있는 5장은 팀 카드 그림(2026-10-28, art/cards/)을 쓰고, 나머지는 같은 틀을 코드가 그린다(card_faces.gd).

## 누구에게 거는가: 자신 / 상대 한 명 / 상대가 꺼내 든(대기 중인) 카드.
enum Target { SELF, OPPONENT, COUNTER }
## 언제까지 걸리는가: 다음 다트 한 발 / 대상의 차례 하나 동안.
enum Timing { NEXT_DART, TURN }

## 종류별 바탕색. 팀 카드 그림(연산=남색, 다트=겨자색, 과녁=청록, 물리=보라)에서 골랐다. CardHandRules.Category 순서.
const CATEGORY_COLORS: Array[Color] = [Color("1f4c7e"), Color("c4901f"), Color("1d5e56"), Color("5d3a5e")]

## effect: round_rules.gd 가 읽는 효과 이름. add/mul = 점수 연산, drop/push = 조준 밀림(과녁 반지름 비율).
## big: 코드로 그리는 카드 가운데의 큰 글자. weight: 같은 종류 안에서 뽑힐 비율.
const CARDS: Array[Dictionary] = [
	{"id": "random_math", "name": "랜덤 연산", "category": CardHandRules.Category.OPERATION,
		"target": Target.SELF, "timing": Timing.NEXT_DART, "effect": "random_math", "weight": 2.0,
		"art": "res://art/cards/card_random_math.webp", "big": "?",
		"text": "+10 · +20 · ×2 · −10 · ÷2 중 하나가 무작위로 내 다음 다트에 걸린다."},
	{"id": "plus_10", "name": "더하기", "category": CardHandRules.Category.OPERATION,
		"target": Target.SELF, "timing": Timing.NEXT_DART, "effect": "math", "add": 10, "weight": 1.5,
		"art": "", "big": "+10", "text": "내 다음 다트 점수 +10."},
	{"id": "times_2", "name": "곱하기", "category": CardHandRules.Category.OPERATION,
		"target": Target.SELF, "timing": Timing.NEXT_DART, "effect": "math", "mul": 2.0, "weight": 1.0,
		"art": "", "big": "×2", "text": "내 다음 다트 점수 ×2."},
	{"id": "minus_20", "name": "빼기", "category": CardHandRules.Category.OPERATION,
		"target": Target.OPPONENT, "timing": Timing.NEXT_DART, "effect": "math", "add": -20, "weight": 1.5,
		"art": "", "big": "−20", "text": "상대의 다음 다트 점수 −20 (0점 아래로는 안 내려간다)."},
	{"id": "times_0", "name": "무효", "category": CardHandRules.Category.OPERATION,
		"target": Target.COUNTER, "timing": Timing.NEXT_DART, "effect": "nullify", "weight": 1.5,
		"art": "", "big": "×0", "text": "상대가 위로 꺼내 든 카드를 효과 없이 없앤다."},
	{"id": "special_dart", "name": "특수 다트", "category": CardHandRules.Category.DART,
		"target": Target.SELF, "timing": Timing.NEXT_DART, "effect": "triple", "weight": 1.0,
		"art": "res://art/cards/card_special_dart.webp", "big": "?",
		"text": "내 다음 한 발이 세 개로 묶여 날아간다. 셋 중 가장 높은 점수."},
	{"id": "power_up", "name": "힘 증가", "category": CardHandRules.Category.DART,
		"target": Target.SELF, "timing": Timing.TURN, "effect": "power", "weight": 1.0,
		"art": "res://art/cards/card_power_up.webp", "big": "↑",
		"text": "내 차례 동안 충전이 덜 돼도 최대 힘으로 날아간다(떨어지지 않는다)."},
	{"id": "heavy_dart", "name": "무거운 다트", "category": CardHandRules.Category.DART,
		"target": Target.OPPONENT, "timing": Timing.NEXT_DART, "effect": "heavy", "drop": 0.45, "weight": 1.0,
		"art": "", "big": "↓", "text": "상대의 다음 다트가 크게 아래로 떨어진다."},
	{"id": "number_shuffle", "name": "숫자 섞기", "category": CardHandRules.Category.BOARD,
		"target": Target.OPPONENT, "timing": Timing.TURN, "effect": "shuffle", "weight": 1.5,
		"art": "res://art/cards/card_number_shuffle.webp", "big": "?",
		"text": "상대 차례 동안 과녁 숫자 배치가 뒤섞인다."},
	{"id": "cover", "name": "가림판", "category": CardHandRules.Category.BOARD,
		"target": Target.OPPONENT, "timing": Timing.TURN, "effect": "cover", "weight": 1.0,
		"art": "", "big": "가림", "text": "상대 차례 동안 과녁 왼쪽 절반을 판자로 가린다. 가린 곳은 0점."},
	{"id": "drowsy", "name": "졸림", "category": CardHandRules.Category.PHYSICAL,
		"target": Target.OPPONENT, "timing": Timing.TURN, "effect": "drowsy", "weight": 1.5,
		"art": "res://art/cards/card_drowsy.webp", "big": "Zz",
		"text": "상대 차례 동안 눈꺼풀이 자꾸 감기고 조준이 흔들린다."},
	{"id": "wind", "name": "바람", "category": CardHandRules.Category.PHYSICAL,
		"target": Target.OPPONENT, "timing": Timing.TURN, "effect": "wind", "push": 0.32, "weight": 1.0,
		"art": "", "big": "바람", "text": "상대 차례 동안 다트가 오른쪽으로 밀린다."},
]

## 랜덤 연산 카드가 굴리는 결과(시연값).
const RANDOM_MATH: Array[Dictionary] = [
	{"label": "+10", "add": 10, "mul": 1.0}, {"label": "+20", "add": 20, "mul": 1.0},
	{"label": "×2", "add": 0, "mul": 2.0}, {"label": "−10", "add": -10, "mul": 1.0},
	{"label": "÷2", "add": 0, "mul": 0.5},
]


## 카드 종류 번호 → 카드 정보(이름·분류·대상·시점·효과값).
static func card(type: int) -> Dictionary:
	return CARDS[type]


## 카드 종류 수.
static func count() -> int:
	return CARDS.size()


## 종류는 손패 규칙의 가중치로, 같은 종류 안에서는 카드 weight 로 고른다.
static func random_type(random: RandomNumberGenerator) -> int:
	var category: int = CardHandRules.draw_category(random)
	var types: Array[int] = []
	var weights := PackedFloat32Array()
	for type in range(CARDS.size()):
		if int(CARDS[type].category) == category:
			types.append(type)
			weights.append(float(CARDS[type].get("weight", 1.0)))
	return types[random.rand_weighted(weights)]


## 카드 id 글자 → 종류 번호(없으면 -1).
static func type_of(id: String) -> int:
	for type in range(CARDS.size()):
		if CARDS[type].id == id:
			return type
	return -1


## 카드 분류 이름(연산·다트·과녁·물리, game/cards/card_hand_rules.gd).
static func category_name(type: int) -> String:
	return CardHandRules.CATEGORY_NAMES[int(CARDS[type].category)]


## 카드 분류 색(카드 앞면·HUD 표시에 쓴다).
static func color(type: int) -> Color:
	return CATEGORY_COLORS[int(CARDS[type].category)]


## 카드 대상 설명 글(나 / 상대 1명 / 카드를 꺼내 든 상대 — 무효 ×0 같은 대응 카드).
static func target_text(type: int) -> String:
	match int(CARDS[type].target):
		Target.SELF: return "대상: 나"
		Target.OPPONENT: return "대상: 상대 1명"
	return "대상: 카드를 꺼내 든 상대"


## 카드 효과 시점 설명 글(다음 다트 한 발 / 대상의 차례 동안).
static func timing_text(type: int) -> String:
	return "다음 다트 한 발" if int(CARDS[type].timing) == Timing.NEXT_DART else "대상의 차례 동안"
