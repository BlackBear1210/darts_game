extends RefCounted
## F5 경기·F6 시연 공용 카드 목록. CARD_PLAN 승인 규칙과 제안 기본값(2026-11-12).
## 종류(연산·다트·과녁·물리)는 손패 규칙 CardHandRules.Category 5종을 그대로 쓴다.
## art 가 있는 5장은 팀 카드 그림(2026-10-28, art/cards/)을 쓰고, 나머지는 같은 틀을 코드가 그린다(card_faces.gd).

## 누구에게 거는가: 자신 / 상대 한 명 / 상대가 꺼내 든(대기 중인) 카드.
enum Target { SELF, OPPONENT, COUNTER, ALL, CASTER }
## 언제까지 걸리는가: 다음 다트 한 발 / 대상의 차례 하나 동안.
enum Timing { NEXT_DART, TURN, ROUND }
## 졸림의 발사 오차. 과녁 반지름 기준 각 축 최대값(F5 경기·F6 시연 공용).
const DROWSY_AIM_SPREAD: float = 0.3
const POWER_SPEED_MULTIPLIER: float = 1.3
const SYNERGY_MAX_PLAYERS: int = 3


## 서로 다른 사용자의 같은 방해카드만 협동 강화한다. 수치는 밸런스 기본안이다.
static func supports_synergy(type: int) -> bool:
	return is_available(type) and int(CARDS[type].target) == Target.OPPONENT


static func synergy_factor(players: int) -> float:
	return 1.0 + 0.5 * (clampi(players, 1, SYNERGY_MAX_PLAYERS) - 1)

## 종류별 바탕색. 팀 카드 그림(연산=남색, 다트=겨자색, 과녁=청록, 물리=보라)에서 골랐다. CardHandRules.Category 순서.
const CATEGORY_COLORS: Array[Color] = [Color("1f4c7e"), Color("c4901f"), Color("1d5e56"), Color("5d3a5e"), Color("9b463d")]

## effect: round_rules.gd 가 읽는 효과 이름. add/mul = 점수 연산, drop/push = 조준 밀림(과녁 반지름 비율).
## big: 코드로 그리는 카드 가운데의 큰 글자. weight: 같은 종류 안에서 뽑힐 비율.
const CARDS: Array[Dictionary] = [
	{"id": "random_math", "name": "랜덤 연산", "category": CardHandRules.Category.OPERATION,
		"target": Target.SELF, "timing": Timing.NEXT_DART, "effect": "random_math", "weight": 2.0,
		"art": "res://art/cards/card_random_math.webp", "big": "?",
		"text": "더하기 1~20 · 빼기 1~20 · 곱하기 1~3 · 나누기 2~3 중 무작위. 사용 순서대로 계산한다."},
	{"id": "plus_10", "legacy": true, "name": "더하기", "category": CardHandRules.Category.OPERATION,
		"target": Target.SELF, "timing": Timing.NEXT_DART, "effect": "math", "add": 10, "weight": 1.5,
		"art": "", "big": "+10", "text": "내 다음 다트 점수 +10."},
	{"id": "times_2", "legacy": true, "name": "곱하기", "category": CardHandRules.Category.OPERATION,
		"target": Target.SELF, "timing": Timing.NEXT_DART, "effect": "math", "mul": 2.0, "weight": 1.0,
		"art": "", "big": "×2", "text": "내 다음 다트 점수 ×2."},
	{"id": "minus_20", "legacy": true, "name": "빼기", "category": CardHandRules.Category.OPERATION,
		"target": Target.OPPONENT, "timing": Timing.NEXT_DART, "effect": "math", "add": -20, "weight": 1.5,
		"art": "", "big": "−20", "text": "상대의 다음 다트 점수 −20 (0점 아래로는 안 내려간다)."},
	{"id": "times_0", "name": "무효", "category": CardHandRules.Category.SPECIAL,
		"target": Target.COUNTER, "timing": Timing.NEXT_DART, "effect": "nullify", "weight": 1.5,
		"art": "", "big": "×0", "text": "상대가 위로 꺼내 든 카드를 효과 없이 없앤다."},
	{"id": "special_dart", "name": "특수 다트", "category": CardHandRules.Category.SPECIAL,
		"target": Target.SELF, "timing": Timing.NEXT_DART, "effect": "triple", "weight": 1.0,
		"art": "res://art/cards/card_special_dart.webp", "big": "?",
		"text": "발사 순간 무작위 방식으로 여러 발이 나간다. 명중한 점수를 모두 합산한다."},
	{"id": "power_up", "name": "힘 증가", "category": CardHandRules.Category.DART,
		"target": Target.SELF, "timing": Timing.TURN, "effect": "power", "weight": 1.0,
		"art": "res://art/cards/card_power_up.webp", "big": "↑",
		"text": "차례 동안 같은 충전량에서도 투척 속도가 1.3배가 된다."},
	{"id": "heavy_dart", "name": "무게 증가", "category": CardHandRules.Category.DART,
		"target": Target.OPPONENT, "timing": Timing.TURN, "effect": "heavy", "drop": 0.45, "weight": 1.0,
		"art": "", "big": "↓", "text": "차례 동안 다트가 아래로 떨어진다. 위로 조준해 보정할 수 있다."},
	{"id": "number_shuffle", "name": "숫자 섞기", "category": CardHandRules.Category.BOARD,
		"target": Target.OPPONENT, "timing": Timing.TURN, "effect": "shuffle", "weight": 1.5,
		"art": "res://art/cards/card_number_shuffle.webp", "big": "?",
		"text": "상대 차례 동안 과녁 숫자 배치가 뒤섞인다."},
	{"id": "cover", "name": "셔터", "category": CardHandRules.Category.BOARD,
		"target": Target.OPPONENT, "timing": Timing.TURN, "effect": "cover", "weight": 1.0,
		"art": "", "big": "가림", "text": "상대 차례 동안 다트 머신 셔터가 무작위로 정해진 좌우 한쪽 절반을 가린다. 가린 곳은 0점."},
	{"id": "drowsy", "name": "졸림", "category": CardHandRules.Category.PHYSICAL,
		"target": Target.OPPONENT, "timing": Timing.TURN, "effect": "drowsy", "weight": 1.5,
		"art": "res://art/cards/card_drowsy.webp", "big": "Zz",
		"text": "상대 차례 동안 눈꺼풀이 자꾸 감기고 조준이 흔들린다."},
	{"id": "wind", "name": "바람", "category": CardHandRules.Category.PHYSICAL,
		"target": Target.OPPONENT, "timing": Timing.TURN, "effect": "wind", "push": 0.32, "weight": 1.0,
		"art": "", "big": "바람", "text": "차례 동안 다트가 무작위로 정해진 좌우 한쪽으로 밀린다."},
	# 아수라장 다트 머신 카드(2026-11-07). 기존 카드 번호(손패에 든 종류 번호)가 밀리지 않게 맨 뒤에 붙인다.
	# 판정은 game/board/board_chaos.gd 가 화면에 보이는 모양 그대로 센다(숫자는 자기 조각을 따라 돈다).
	# 셔터·숫자 섞기와 겹치면 효과가 함께 걸린다(셔터 → 회전 → 분리 순서로 판정) — 여러 장을 몰아 쓰는 "시너지 방해".
	{"id": "board_spin", "name": "회전판", "category": CardHandRules.Category.BOARD,
		"target": Target.OPPONENT, "timing": Timing.TURN, "effect": "spin", "weight": 1.0,
		"art": "", "big": "회전", "text": "상대 차례 동안 다트 머신 과녁이 빙글빙글 돈다. 숫자도 자기 칸을 따라 돈다."},
	{"id": "board_split", "name": "피자 분리", "category": CardHandRules.Category.BOARD,
		"target": Target.OPPONENT, "timing": Timing.TURN, "effect": "split", "weight": 1.0,
		"art": "", "big": "분리", "text": "상대 차례 동안 과녁이 피자 다섯 조각으로 벌어졌다 모였다 한다. 벌어진 틈은 0점."},
	{"id": "dart_size", "name": "다트 크기 증가", "category": CardHandRules.Category.DART, "target": Target.SELF, "timing": Timing.NEXT_DART, "effect": "large", "weight": 1.0, "art": "", "big": "크기", "text": "다트가 커진다. 겹친 면적이 가장 큰 구역으로 채점한다."},
	{"id": "vertical_split", "name": "세로 분리", "category": CardHandRules.Category.BOARD, "target": Target.OPPONENT, "timing": Timing.TURN, "effect": "vertical", "weight": 1.0, "art": "", "big": "좌우", "text": "과녁이 좌우로 갈라진다. 벌어진 틈은 0점."},
	{"id": "horizontal_split", "name": "가로 분리", "category": CardHandRules.Category.BOARD, "target": Target.OPPONENT, "timing": Timing.TURN, "effect": "horizontal", "weight": 1.0, "art": "", "big": "상하", "text": "과녁이 위아래로 갈라진다. 벌어진 틈은 0점."},
	{"id": "board_move", "name": "과녁 이동", "category": CardHandRules.Category.BOARD, "target": Target.OPPONENT, "timing": Timing.TURN, "effect": "move", "weight": 1.0, "art": "", "big": "이동", "text": "과녁이 무작위 방향으로 왕복한다."},
	{"id": "score_random", "name": "점수 랜덤 변경", "category": CardHandRules.Category.BOARD, "target": Target.OPPONENT, "timing": Timing.TURN, "effect": "random_scores", "weight": 1.0, "art": "", "big": "랜덤", "text": "숫자·링 배수·불 점수를 무작위로 바꾼다."},
	{"id": "score_lock", "name": "점수 고정", "category": CardHandRules.Category.BOARD, "target": Target.OPPONENT, "timing": Timing.ROUND, "effect": "lock_scores", "weight": 1.0, "art": "", "big": "고정", "text": "무작위 5~20구역을 1~20점 중 하나로 고정한다. 이번 라운드까지 유지."},
	{"id": "sector_block", "name": "봉쇄 구역", "category": CardHandRules.Category.BOARD, "target": Target.OPPONENT, "timing": Timing.TURN, "effect": "block_sector", "weight": 1.0, "art": "", "big": "봉쇄", "text": "선택한 숫자 구역 전체가 0점이 된다.", "choice": "sector"},
	{"id": "board_ink", "name": "먹물 얼룩", "category": CardHandRules.Category.BOARD, "target": Target.OPPONENT, "timing": Timing.TURN, "effect": "ink_board", "weight": 1.0, "art": "", "big": "먹물", "text": "무작위 숫자를 가린다. 실제 점수는 유지된다."},
	{"id": "dizzy", "name": "어지러움", "category": CardHandRules.Category.PHYSICAL, "target": Target.OPPONENT, "timing": Timing.TURN, "effect": "dizzy", "weight": 1.0, "art": "", "big": "빙글", "text": "차례 동안 화면이 크게 기울고 흔들린다."},
	{"id": "reverse", "name": "조작 반전", "category": CardHandRules.Category.PHYSICAL, "target": Target.OPPONENT, "timing": Timing.TURN, "effect": "reverse", "weight": 1.0, "art": "", "big": "반전", "text": "좌우·상하·전체 중 무작위로 조준 조작이 반전된다."},
	{"id": "precision", "name": "정밀 조정", "category": CardHandRules.Category.OPERATION, "target": Target.SELF, "timing": Timing.NEXT_DART, "effect": "precision", "weight": 1.0, "art": "", "big": "±5", "text": "투척 전에 +5 또는 −5를 선택한다.", "choice": "adjust"},
	{"id": "sector_bid", "name": "구역 지목", "category": CardHandRules.Category.OPERATION, "target": Target.SELF, "timing": Timing.NEXT_DART, "effect": "sector_bid", "weight": 1.0, "art": "", "big": "지목", "text": "선택 구역 명중 +15점, 실패하면 선택 구역의 싱글 점수만큼 감점.", "choice": "sector"},
	{"id": "double_or_nothing", "name": "더블 오어 낫싱", "category": CardHandRules.Category.OPERATION, "target": Target.SELF, "timing": Timing.NEXT_DART, "effect": "double_target", "weight": 1.0, "art": "", "big": "2/0", "text": "선택 구역을 맞히면 2배, 실패하면 0점.", "choice": "sector"},
	{"id": "retry", "name": "재도전", "category": CardHandRules.Category.SPECIAL, "target": Target.CASTER, "timing": Timing.ROUND, "effect": "retry", "weight": 1.0, "art": "", "big": "한 번 더", "text": "경기당 1회. 자기 차례에 쓰면 바로 다음에 3발 차례를 추가한다."},
	{"id": "hand_shuffle", "name": "손패 랜덤 섞기", "category": CardHandRules.Category.SPECIAL, "target": Target.ALL, "timing": Timing.NEXT_DART, "effect": "hand_shuffle", "weight": 1.0, "art": "", "big": "섞기", "text": "모두의 남은 손패를 섞는다. 각자 장수는 유지된다."},
	{"id": "body_reward", "name": "몸으로 받기 보상", "category": CardHandRules.Category.SPECIAL, "target": Target.CASTER, "timing": Timing.ROUND, "effect": "body_reward", "weight": 1.0, "art": "", "big": "+30", "text": "사용한 뒤 다른 사람의 다트를 몸으로 받으면 +30점."},
	{"id": "all_dizzy", "name": "전체 어지러움", "category": CardHandRules.Category.SPECIAL, "target": Target.ALL, "timing": Timing.ROUND, "effect": "all_dizzy", "weight": 1.0, "art": "", "big": "모두 빙글", "text": "사용자 포함 모두가 현재 라운드 동안 어지럽다."},
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
		if is_available(type) and int(CARDS[type].category) == category:
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
	if int(CARDS[type].target) == Target.ALL: return "대상: 모든 플레이어"
	if int(CARDS[type].target) == Target.CASTER: return "대상: 카드 사용자"
	return "대상: 카드를 꺼내 든 상대"


## 카드 효과 시점 설명 글(다음 다트 한 발 / 대상의 차례 동안).
static func timing_text(type: int) -> String:
	if str(CARDS[type].effect) == "retry": return "경기당 1회 · 추가 3발 차례"
	if int(CARDS[type].timing) == Timing.ROUND: return "이번 라운드 동안"
	return "다음 다트 한 발" if int(CARDS[type].timing) == Timing.NEXT_DART else "대상의 차례 동안"


## 이전 카드 번호는 보존하되 삭제·미확정 카드는 지급하지 않는다.
static func is_available(type: int) -> bool:
	return type >= 0 and type < CARDS.size() and not bool(CARDS[type].get("legacy", false)) and bool(CARDS[type].get("available", true))


## 결과는 발사 순간에만 뽑는다. 앞서 꺼내 들었을 때는 공개하지 않는다.
static func special_offsets(random: RandomNumberGenerator) -> Array[Vector2]:
	var pattern: int = random.rand_weighted(PackedFloat32Array([0.3, 0.3, 0.3, 0.1]))
	match pattern:
		0: return [Vector2.ZERO, Vector2(-0.09, 0.03), Vector2(0.09, 0.03)]
		1: return [Vector2(-0.09, 0), Vector2(0.09, 0)]
		2: return [Vector2(0, -0.09), Vector2(0, 0.09)]
	return [Vector2.ZERO, Vector2(random.randf_range(-0.35, 0.35), random.randf_range(-0.35, 0.35))]
