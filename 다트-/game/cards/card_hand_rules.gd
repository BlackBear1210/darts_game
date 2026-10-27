class_name CardHandRules
extends RefCounted
## 손패 지급 규칙(2026-10-25 사용자 확정). 노드·UI·네트워크와 무관한 순수 계산이라 서버/시연 어디서든 쓴다.
##
## 1. 손패 한도는 7장. 매 라운드 시작 전에 7장이 될 때까지 무작위로 채운다.
## 2. 안 쓴 카드는 그대로 남는다 → 한 장도 안 썼으면 한 장도 못 받는다. (새로고침·임의 버리기 없음)
## 3. 카드는 등급이 아니라 방해 종류 4가지로 나눈다: 연산 · 다트 · 과녁 · 물리.
##
## 손패는 Array[int] 이고 원소는 Category 값이다. 종류별 세부 카드(+15, ×2, 바람 …)와 효과는 미확정이다.

enum Category { OPERATION, DART, BOARD, PHYSICAL }

## 화면 표시 이름. Category 순서와 같아야 한다.
const CATEGORY_NAMES: Array[String] = ["연산", "다트", "과녁", "물리"]
## 회의록 예시: 연산 +15/−10/×2/÷2 · 다트 속도/폭/무게 · 과녁 분리/숫자 변경/가림 · 물리 바람/어지러운 시야.
const CATEGORY_HINTS: Array[String] = ["점수 연산", "다트 성질 변화", "과녁 변형·가림", "바람·시야 방해"]
const HAND_LIMIT: int = 7
## 종류별 지급 가중치(밸런스 조정 지점). 지금은 네 종류가 같은 확률이다 — 미확정 값.
const DRAW_WEIGHTS: Array[float] = [1.0, 1.0, 1.0, 1.0]


## 손패를 7장까지 채우고 새로 받은 장수를 돌려준다. 이미 7장이면 0장(안 쓰면 못 받는다).
static func refill(hand: Array[int], random: RandomNumberGenerator) -> int:
	var drawn: int = 0
	while hand.size() < HAND_LIMIT:
		hand.append(draw_category(random))
		drawn += 1
	return drawn


static func draw_category(random: RandomNumberGenerator) -> int:
	return random.rand_weighted(PackedFloat32Array(DRAW_WEIGHTS))


## category 카드 한 장을 손패에서 뺀다. 없으면 false — 호출한 쪽은 사용을 거부해야 한다.
static func take(hand: Array[int], category: int) -> bool:
	var index: int = hand.find(category)
	if index < 0:
		return false
	hand.remove_at(index)
	return true


static func count(hand: Array[int], category: int) -> int:
	return hand.count(category)


## 예: "연산2 다트1 과녁0 물리3"
static func summary(hand: Array[int]) -> String:
	var parts: PackedStringArray = []
	for category in range(CATEGORY_NAMES.size()):
		parts.append("%s%d" % [CATEGORY_NAMES[category], hand.count(category)])
	return " ".join(parts)
