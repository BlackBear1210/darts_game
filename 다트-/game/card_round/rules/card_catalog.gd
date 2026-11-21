extends RefCounted
## F5 경기·F6 시연 공용 카드 목록. CARD_PLAN 승인 규칙과 제안 기본값(2026-11-12).
## 종류(연산·다트·과녁·물리)는 손패 규칙 CardHandRules.Category 5종을 그대로 쓴다.
## art 가 있는 5장은 팀 카드 그림(2026-10-28, art/cards/)을 쓰고, 나머지는 같은 틀을 코드가 그린다(card_faces.gd).

## 누구에게 거는가: 자신 / 상대 한 명 / 상대가 꺼내 든(대기 중인) 카드 / 모두 / 카드 쓴 사람 / Tab 으로 고른 사람(PICK, 2026-11-21).
## F5 경기에서는 SELF·OPPONENT 가 모두 "지금 던지는 사람"이다(CARD_PLAN §0-1, MatchCards.MatchRules).
enum Target { SELF, OPPONENT, COUNTER, ALL, CASTER, PICK }
## 언제까지 걸리는가: 다음 다트 한 발 / 대상의 차례 하나 동안 / 이번 라운드 / 쓰는 순간 한 번(INSTANT, 2026-11-21).
enum Timing { NEXT_DART, TURN, ROUND, INSTANT }
## 졸림의 발사 오차. 과녁 반지름 기준 각 축 최대값(F5 경기·F6 시연 공용).
const DROWSY_AIM_SPREAD: float = 0.3
const POWER_SPEED_MULTIPLIER: float = 1.3
const SYNERGY_MAX_PLAYERS: int = 3


## 서로 다른 사용자의 같은 방해카드만 협동 강화한다. 수치는 밸런스 기본안이다.
## 2026-11-21 새 카드("solo")는 협동 강화가 없다 — 같은 카드가 이미 걸려 있으면 "이미 적용 중"으로 막는다.
static func supports_synergy(type: int) -> bool:
	# 쓰는 순간 끝나는 카드(INSTANT — 타이머 감소 등)는 쌓을 효과가 없어서 협동 강화도 없다.
	return is_available(type) and int(CARDS[type].target) == Target.OPPONENT and not bool(CARDS[type].get("solo", false)) and int(CARDS[type].timing) != Timing.INSTANT


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
	# 2026-11-21: CARD_PLAN 에서 "속도 카드"는 없앴다. 이 카드는 이동 속도가 아니라 던지는 힘(비행 빠르기)만 바꾼다 —
	# 이름·글에서 "속도"를 빼서 지운 카드가 살아난 것처럼 보이지 않게 했다. 이동 속도는 새 카드 이속 증가·감소다.
	{"id": "power_up", "name": "투척 힘 증가", "category": CardHandRules.Category.DART,
		"target": Target.SELF, "timing": Timing.TURN, "effect": "power", "weight": 1.0,
		"art": "res://art/cards/card_power_up.webp", "big": "↑",
		"text": "차례 동안 같은 충전으로도 다트가 1.3배 힘차게 날아가 덜 처진다."},
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
	{"id": "board_spin", "name": "과녁 회전", "category": CardHandRules.Category.BOARD,
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
	{"id": "sector_bid", "name": "구역 지목", "category": CardHandRules.Category.OPERATION, "target": Target.SELF, "timing": Timing.NEXT_DART, "effect": "sector_bid", "weight": 1.0, "art": "", "big": "지목", "text": "쓰는 순간 무작위 숫자 구역 하나가 지목된다(과녁에 표시). 맞히면 +15점, 못 맞히면 그 구역 싱글 점수만큼 감점."},
	{"id": "double_or_nothing", "name": "더블 오어 낫싱", "category": CardHandRules.Category.OPERATION, "target": Target.SELF, "timing": Timing.NEXT_DART, "effect": "double_target", "weight": 1.0, "art": "", "big": "2/0", "text": "선택 구역을 맞히면 2배, 실패하면 0점.", "choice": "sector"},
	{"id": "retry", "name": "재도전", "category": CardHandRules.Category.SPECIAL, "target": Target.CASTER, "timing": Timing.ROUND, "effect": "retry", "weight": 1.0, "art": "", "big": "한 번 더", "text": "경기당 1회. 자기 차례에 쓰면 바로 다음에 3발 차례를 추가한다."},
	{"id": "hand_shuffle", "name": "손패 랜덤 섞기", "category": CardHandRules.Category.SPECIAL, "target": Target.ALL, "timing": Timing.NEXT_DART, "effect": "hand_shuffle", "weight": 1.0, "art": "", "big": "섞기", "text": "모두의 남은 손패를 섞는다. 각자 장수는 유지된다."},
	{"id": "body_reward", "name": "몸으로 받기 보상", "category": CardHandRules.Category.SPECIAL, "target": Target.CASTER, "timing": Timing.ROUND, "effect": "body_reward", "weight": 1.0, "art": "", "big": "+30", "text": "사용한 뒤 다른 사람의 다트를 몸으로 받으면 +30점."},
	{"id": "all_dizzy", "name": "전체 어지러움", "category": CardHandRules.Category.SPECIAL, "target": Target.ALL, "timing": Timing.ROUND, "effect": "all_dizzy", "weight": 1.0, "art": "", "big": "모두 빙글", "text": "사용자 포함 모두가 현재 라운드 동안 어지럽다."},
	# ── 2026-11-21 새 카드 28장(사용자 13 + 추천 15). 손패는 종류 번호로 오가므로 반드시 맨 뒤에 붙인다. ──
	# 읽는 곳: 점수 = RoundRules.resolve_dart, 조준·몸·화면 = RoundRules.dart_modifiers 의 "mod" 이름,
	#          쓰는 순간 처리(차례 바꾸기·속박 같은 INSTANT) = game/match/match_card_actions.gd.
	# "mod": dart_modifiers 에 그대로 실리는 이름. "value" 한 값 또는 "values" 중 무작위 하나(Effect.value)가 실린다.
	# "solo": 협동 강화 없음 — 같은 효과가 이미 걸려 있으면 "이미 적용 중"으로 막는다.
	# "aim": 쓰는 사람이 바라보는 쪽의 첫 사람에게 건다(빗나가면 카드만 사라진다).
	# "live": F5 펍 경기 전용(사람 몸·목소리·차례가 필요하다). F6 단독 시연은 나눠 주지 않는다.
	# 연산
	{"id": "steal", "name": "가로채기", "category": CardHandRules.Category.OPERATION, "target": Target.OPPONENT, "timing": Timing.NEXT_DART, "effect": "steal", "solo": true, "live": true, "weight": 0.8, "art": "", "big": "뺏기", "text": "던지는 사람의 다음 다트 점수를 내가 가져간다. 내 차례에는 못 쓴다."},
	{"id": "half", "name": "반띵", "category": CardHandRules.Category.OPERATION, "target": Target.OPPONENT, "timing": Timing.NEXT_DART, "effect": "half", "solo": true, "live": true, "weight": 1.0, "art": "", "big": "½", "text": "던지는 사람의 다음 다트 점수를 반으로 나눠 절반을 내가 가져간다. 내 차례에는 못 쓴다."},
	{"id": "parity", "name": "홀짝", "category": CardHandRules.Category.OPERATION, "target": Target.SELF, "timing": Timing.NEXT_DART, "effect": "parity", "live": true, "weight": 1.0, "art": "", "big": "홀짝", "text": "홀 또는 짝을 고른다(Z·X). 다음 다트 점수가 맞으면 ×2, 틀리면 ÷2. 0점은 짝.", "choice": "parity"},
	# 다트
	{"id": "repeat_spot", "name": "좌표 고정", "category": CardHandRules.Category.DART, "target": Target.SELF, "timing": Timing.NEXT_DART, "effect": "repeat_spot", "mod": "repeat", "solo": true, "live": true, "weight": 0.8, "art": "", "big": "고정", "text": "다음 다트가 이번 라운드에 마지막으로 꽂힌 자리로 똑같이 날아간다. 꽂힌 다트가 없으면 못 쓴다."},
	{"id": "pierce", "name": "관통 다트", "category": CardHandRules.Category.DART, "target": Target.SELF, "timing": Timing.NEXT_DART, "effect": "pierce", "mod": "pierce", "solo": true, "live": true, "weight": 1.0, "art": "", "big": "관통", "text": "다음 다트가 몸으로 막는 사람과 셔터를 뚫고 과녁에 꽂힌다."},
	{"id": "rubber", "name": "고무 다트", "category": CardHandRules.Category.DART, "target": Target.OPPONENT, "timing": Timing.NEXT_DART, "effect": "rubber", "mod": "rubber", "solo": true, "live": true, "weight": 1.0, "art": "", "big": "통", "text": "다음 다트가 과녁에 맞고 한 번 튕겨 근처 무작위 자리에 꽂힌다."},
	{"id": "card_throw", "name": "카드 던지기", "category": CardHandRules.Category.DART, "target": Target.CASTER, "timing": Timing.ROUND, "effect": "card_throw", "mod": "card_throw", "solo": true, "live": true, "weight": 1.0, "art": "", "big": "슝", "text": "다음 투척은 다트 대신 카드가 먼저 날아간다(다트는 그대로). 사람을 맞히면 1.5초 기절, 병·잔은 깨진다."},
	# 과녁
	{"id": "board_zoom", "name": "과녁 크기 변화", "category": CardHandRules.Category.BOARD, "target": Target.OPPONENT, "timing": Timing.TURN, "effect": "board_zoom", "mod": "board_scale", "values": [0.7, 1.35], "value_names": ["과녁 작게", "과녁 크게"], "solo": true, "live": true, "weight": 1.0, "art": "", "big": "줌", "text": "차례 동안 과녁이 무작위로 작아지거나(×0.7) 커진다(×1.35). 숫자·링이 같이 커진다."},
	{"id": "ring_wide", "name": "링 확장", "category": CardHandRules.Category.BOARD, "target": Target.SELF, "timing": Timing.TURN, "effect": "ring_wide", "mod": "ring_scale", "value": 2.5, "solo": true, "live": true, "weight": 1.0, "art": "", "big": "링", "text": "차례 동안 트리플·더블 링이 2.5배 두꺼워진다."},
	{"id": "mine", "name": "지뢰 심기", "category": CardHandRules.Category.BOARD, "target": Target.CASTER, "timing": Timing.INSTANT, "effect": "mine", "live": true, "weight": 0.8, "art": "", "big": "지뢰", "text": "보이지 않는 지뢰를 무작위 숫자 구역에 심는다. 경기 끝까지 그 구역을 맞히면 누구든 −15점."},
	# 물리
	{"id": "speed_up", "name": "이속 증가", "category": CardHandRules.Category.PHYSICAL, "target": Target.CASTER, "timing": Timing.ROUND, "effect": "speed_up", "mod": "move_scale", "value": 1.5, "solo": true, "live": true, "weight": 1.0, "art": "", "big": "빠름", "text": "이번 라운드 동안 내 이동 속도가 1.5배."},
	{"id": "speed_down", "name": "이속 감소", "category": CardHandRules.Category.PHYSICAL, "target": Target.PICK, "timing": Timing.ROUND, "effect": "speed_down", "mod": "move_scale", "value": 0.5, "solo": true, "live": true, "weight": 1.0, "art": "", "big": "느림", "text": "Tab 으로 고른 사람의 이동 속도가 이번 라운드 동안 절반."},
	{"id": "bind", "name": "속박", "category": CardHandRules.Category.PHYSICAL, "target": Target.CASTER, "timing": Timing.INSTANT, "effect": "bind", "aim": true, "live": true, "weight": 1.0, "art": "", "big": "속박", "text": "조준점 방향으로 속박 구슬을 날린다. 처음 맞은 사람은 2.5초 동안 못 움직인다."},
	{"id": "pull", "name": "끌어당기기", "category": CardHandRules.Category.PHYSICAL, "target": Target.CASTER, "timing": Timing.INSTANT, "effect": "pull", "aim": true, "live": true, "weight": 1.0, "art": "", "big": "당김", "text": "조준점 방향의 첫 사람을 내 앞으로 끌어당긴다(앉은 사람은 안 끌려온다)."},
	{"id": "body_size", "name": "키 변화", "category": CardHandRules.Category.PHYSICAL, "target": Target.PICK, "timing": Timing.ROUND, "effect": "body_size", "mod": "body_scale", "values": [1.4, 0.6], "value_names": ["거인", "꼬마"], "solo": true, "live": true, "weight": 1.0, "art": "", "big": "키", "text": "Tab 으로 고른 사람의 키가 이번 라운드 동안 무작위로 커지거나 작아진다(눈높이도 바뀐다)."},
	{"id": "blackout", "name": "정전", "category": CardHandRules.Category.PHYSICAL, "target": Target.OPPONENT, "timing": Timing.TURN, "effect": "blackout", "mod": "blackout", "solo": true, "live": true, "weight": 1.0, "art": "", "big": "정전", "text": "던지는 사람의 차례 동안 펍 불이 꺼진다. 과녁만 희미하게 보인다."},
	{"id": "hiccup", "name": "딸꾹질", "category": CardHandRules.Category.PHYSICAL, "target": Target.OPPONENT, "timing": Timing.TURN, "effect": "hiccup", "mod": "hiccup", "solo": true, "live": true, "weight": 1.0, "art": "", "big": "딸꾹", "text": "차례 동안 가끔 딸꾹질로 조준이 위로 툭 튄다."},
	{"id": "outbody", "name": "유체이탈", "category": CardHandRules.Category.PHYSICAL, "target": Target.OPPONENT, "timing": Timing.TURN, "effect": "outbody", "mod": "outbody", "solo": true, "live": true, "weight": 1.0, "art": "", "big": "유체", "text": "차례 동안 화면이 내 몸 뒤 위쪽(3인칭)에서 보인다. 조준점은 그대로 화면 가운데."},
	{"id": "telescope", "name": "망원경", "category": CardHandRules.Category.PHYSICAL, "target": Target.OPPONENT, "timing": Timing.TURN, "effect": "telescope", "mod": "telescope", "solo": true, "live": true, "weight": 1.0, "art": "", "big": "망원", "text": "차례 동안 크게 확대된 동그란 망원경 화면으로만 본다. 시야가 천천히 흔들린다."},
	{"id": "oneshot", "name": "원샷", "category": CardHandRules.Category.PHYSICAL, "target": Target.OPPONENT, "timing": Timing.TURN, "effect": "oneshot", "mod": "oneshot", "solo": true, "live": true, "weight": 1.0, "art": "", "big": "원샷", "text": "던지는 사람이 독한 술을 원샷한 것처럼 차례 동안 화면이 크게 출렁인다."},
	# 특수
	{"id": "swap_turn", "name": "차례 바꾸기", "category": CardHandRules.Category.SPECIAL, "target": Target.CASTER, "timing": Timing.INSTANT, "effect": "swap_turn", "live": true, "weight": 1.0, "art": "", "big": "교대", "text": "아직 안 던진 내가 지금 던지는 사람과 차례를 바꾼다. 내 차례에 쓰면 다음 사람과 바꾼다(던지기 전만)."},
	{"id": "skip_turn", "name": "점프", "category": CardHandRules.Category.SPECIAL, "target": Target.CASTER, "timing": Timing.INSTANT, "effect": "skip_turn", "live": true, "weight": 1.0, "art": "", "big": "점프", "text": "다음 차례 사람을 한 번 건너뛴다(UNO 점프)."},
	{"id": "timer_cut", "name": "타이머 감소", "category": CardHandRules.Category.SPECIAL, "target": Target.OPPONENT, "timing": Timing.INSTANT, "effect": "timer_cut", "live": true, "weight": 1.0, "art": "", "big": "½초", "text": "던지는 사람의 남은 투척 시간이 절반이 된다(최소 3초)."},
	{"id": "voice_warp", "name": "목소리 변조", "category": CardHandRules.Category.SPECIAL, "target": Target.PICK, "timing": Timing.ROUND, "effect": "voice_warp", "mod": "voice_pitch", "values": [1.55, 0.68], "value_names": ["헬륨 목소리", "괴물 목소리"], "solo": true, "live": true, "weight": 1.0, "art": "", "big": "변조", "text": "Tab 으로 고른 사람의 목소리가 이번 라운드 동안 헬륨(높게) 또는 괴물(낮게) 목소리가 된다."},
	{"id": "voice_mute", "name": "강제 음소거", "category": CardHandRules.Category.SPECIAL, "target": Target.PICK, "timing": Timing.ROUND, "effect": "voice_mute", "mod": "mute", "solo": true, "live": true, "weight": 1.0, "art": "", "big": "쉿", "text": "Tab 으로 고른 사람의 마이크가 이번 라운드 동안 꺼진다."},
	{"id": "pickpocket", "name": "소매치기", "category": CardHandRules.Category.SPECIAL, "target": Target.PICK, "timing": Timing.INSTANT, "effect": "pickpocket", "live": true, "weight": 1.0, "art": "", "big": "슬쩍", "text": "Tab 으로 고른 사람의 손패에서 무작위 한 장을 훔쳐 내 빈 칸에 넣는다."},
	{"id": "big_head", "name": "왕머리", "category": CardHandRules.Category.SPECIAL, "target": Target.PICK, "timing": Timing.ROUND, "effect": "big_head", "mod": "head_scale", "value": 2.4, "solo": true, "live": true, "weight": 1.0, "art": "", "big": "왕", "text": "Tab 으로 고른 사람의 머리가 이번 라운드 동안 2.4배로 커진다."},
	{"id": "random_card", "name": "랜덤 카드", "category": CardHandRules.Category.SPECIAL, "target": Target.CASTER, "timing": Timing.INSTANT, "effect": "random_card", "live": true, "weight": 1.0, "art": "", "big": "?!", "text": "게임 안의 카드 중 지금 쓸 수 있는 무작위 한 장이 바로 발동한다."},
]

## 카드 종류 번호 → 카드 정보(이름·분류·대상·시점·효과값).
static func card(type: int) -> Dictionary:
	return CARDS[type]


## 카드 종류 수.
static func count() -> int:
	return CARDS.size()


## 종류는 손패 규칙의 가중치로, 같은 종류 안에서는 카드 weight 로 고른다.
## F6 단독 시연(RoundRules.fill_deck)이 부른다 — "live"(펍 경기 전용) 카드는 뺀다. F5 는 RoomSettings.draw_card 를 쓴다.
static func random_type(random: RandomNumberGenerator) -> int:
	var category: int = CardHandRules.draw_category(random)
	var types: Array[int] = []
	var weights := PackedFloat32Array()
	for type in range(CARDS.size()):
		if is_available(type) and not is_live(type) and int(CARDS[type].category) == category:
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
	if bool(CARDS[type].get("aim", false)): return "대상: 조준점 방향의 첫 사람"
	match int(CARDS[type].target):
		Target.SELF: return "대상: 나"
		Target.OPPONENT: return "대상: 상대 1명"
		Target.ALL: return "대상: 모든 플레이어"
		Target.CASTER: return "대상: 카드 사용자"
		Target.PICK: return "대상: Tab 으로 고른 사람"
	return "대상: 카드를 꺼내 든 상대"


## 카드 효과 시점 설명 글(다음 다트 한 발 / 대상의 차례 동안).
static func timing_text(type: int) -> String:
	if str(CARDS[type].effect) == "retry": return "경기당 1회 · 추가 3발 차례"
	if int(CARDS[type].timing) == Timing.ROUND: return "이번 라운드 동안"
	if int(CARDS[type].timing) == Timing.INSTANT: return "쓰는 순간 한 번"
	return "다음 다트 한 발" if int(CARDS[type].timing) == Timing.NEXT_DART else "대상의 차례 동안"


## 펍 경기(F5) 전용 카드인가 — 사람 몸·목소리·차례 순서가 있어야 하는 카드(2026-11-21 새 카드).
static func is_live(type: int) -> bool:
	return bool(CARDS[type].get("live", false))


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
