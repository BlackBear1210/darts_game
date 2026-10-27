extends RefCounted
## 흐름도 검토용 로컬 진행 모델. 실제 경기 권한·물리·카드 효과와는 연결하지 않는다.
## UI(flow_preview.gd)는 actions() 로 지금 누를 수 있는 버튼을 받고, act() 로 하나를 실행한다.
##
## 2026-10-25 반영(사용자 확정): 손패 7장 채우기 · 안 쓰면 못 받음 · 방해 4종(연산/다트/과녁/물리)
## · 특수 합동 라운드(바텐더와 한잔). 손패 규칙 자체는 game/cards/card_hand_rules.gd 가 소유한다.
## 흐름도의 "2장 버리고 1장 교환"은 10.23 회의(새로고침·임의 버리기 없음)와 위 규칙으로 대체했다.

enum Step {
	START, ROOM, SETTINGS, TABLE, INITIAL_CARDS, ORDER, ROUND_START, JOINT_ROUND,
	TURN_START, MOVE, CARD_CHOICE, CARD_APPLY, PREPARE, AIM, RESULT,
	TURN_CHECK, PLAYER_CHECK, RETURN_TABLE, END_CHECK, ROUND_CARDS, FINISHED,
}

const TITLES: Array[String] = [
	"시작", "방 생성 · 플레이어 입장", "방장 모드 · 기본 설정 선택",
	"원형 테이블에 모임", "카드 획득 · 손패 7장", "플레이 순서 결정", "라운드 시작",
	"특수 합동 라운드 · 바텐더와 한잔",
	"현재 플레이어 차례 · 투척 기회 3회", "자유 이동 · 투척 위치 선택",
	"이번 투척에 카드를 사용할까?", "카드 선택 · 효과 적용", "투척 준비",
	"조준 · 충전 · 타이밍 판단 · 다른 플레이어 방해", "다트 투척 · 결과와 점수 처리",
	"이번 차례에 3회 투척 완료?", "모든 플레이어의 차례 완료?",
	"라운드 종료 · 제한시간 안에 테이블 착석", "경기 종료 조건 충족?",
	"카드 보충 · 7장까지 (안 쓴 만큼은 못 받음)", "게임 종료",
]
const DARTS_PER_TURN: int = 3
const MAX_HIT_SCORE: int = 60
## actions() 의 키 접두어. "use_0" = 연산 카드 사용, "jam_2" = P3 이 방해 카드 사용.
const USE_PREFIX := "use_"
const JAM_PREFIX := "jam_"

var step: Step = Step.START
var player_count: int = 2
var round_limit: int = 2
var target_score: int = 100
## 특수 합동 라운드가 열리는 라운드 번호. 0 이면 없음. 주기·내용은 미확정이라 시연에서 고르게 한다.
var joint_round: int = 2
var round_number: int = 1
var turn_index: int = 0
var throws_done: int = 0
var scores: Array[int] = []
## 참가자별 손패. 원소는 Array[int](CardHandRules.Category 값들).
var hands: Array[Array] = []
## 참가자별 취기 단계. 합동 라운드에서 오른다. 화면 효과(기울어짐·노이즈)는 후속 구현.
var drunk: Array[int] = []
## 직전 카드 보충에서 각자 받은 장수(화면 표시용).
var last_drawn: Array[int] = []
## 이번 한 발에 이미 방해한 참가자. 한 발에 한 사람당 1장으로 제한(중첩 규칙 미확정 — 시연값).
var jammed_by: Array[int] = []
var history: Array[String] = []
var random := RandomNumberGenerator.new()
var _pending_category: int = -1


func _init() -> void:
	random.randomize()
	reset()


func reset() -> void:
	step = Step.START
	round_number = 1
	turn_index = 0
	throws_done = 0
	_pending_category = -1
	scores.clear()
	hands.clear()
	drunk.clear()
	last_drawn.clear()
	jammed_by.clear()
	history.assign(["흐름도 시연 시작"])


func actions() -> Dictionary:
	match step:
		Step.START: return {"next": "시작"}
		Step.ROOM: return {"next": "입장 완료 (가상 참가자)"}
		Step.SETTINGS: return {"next": "설정 확정"}
		Step.JOINT_ROUND: return {"next": "다 같이 한잔 (전원 취기 +1)"}
		Step.MOVE: return {"next": "위치 선택 완료"}
		Step.CARD_CHOICE: return _card_choice_actions()
		Step.AIM: return _aim_actions()
		Step.FINISHED: return {}
		_: return {"next": "다음 단계"}


func act(action: String, hit_score: int = 20) -> bool:
	if not actions().has(action):
		return false
	if step == Step.SETTINGS and (player_count < 2 or player_count > 4 or round_limit < 1 or target_score < 0 or joint_round < 0):
		return false
	if step == Step.AIM and action == "throw" and (hit_score < 0 or hit_score > MAX_HIT_SCORE):
		return false
	match step:
		Step.START: step = Step.ROOM
		Step.ROOM: step = Step.SETTINGS
		Step.SETTINGS:
			scores.resize(player_count)
			scores.fill(0)
			drunk.resize(player_count)
			drunk.fill(0)
			hands.clear()
			for index in range(player_count):
				var hand: Array[int] = []
				hands.append(hand)
			step = Step.TABLE
		Step.TABLE: step = Step.INITIAL_CARDS
		Step.INITIAL_CARDS:
			_refill_all()
			step = Step.ORDER
		Step.ORDER: step = Step.ROUND_START
		Step.ROUND_START:
			turn_index = 0
			step = Step.JOINT_ROUND if round_number == joint_round else Step.TURN_START
		Step.JOINT_ROUND:
			for index in range(player_count):
				drunk[index] += 1
			history.append("합동 라운드: 바텐더와 다 같이 한잔 → 전원 취기 +1")
			step = Step.TURN_START
		Step.TURN_START:
			throws_done = 0
			step = Step.MOVE
		Step.MOVE: step = Step.CARD_CHOICE
		Step.CARD_CHOICE:
			if action.begins_with(USE_PREFIX):
				_pending_category = int(action.trim_prefix(USE_PREFIX))
				step = Step.CARD_APPLY
			else:
				step = Step.PREPARE
		Step.CARD_APPLY:
			CardHandRules.take(hands[turn_index], _pending_category)
			history.append("P%d: %s 카드 사용 (손패 %d/%d)" % [turn_index + 1,
				CardHandRules.CATEGORY_NAMES[_pending_category], hands[turn_index].size(), CardHandRules.HAND_LIMIT])
			_pending_category = -1
			step = Step.PREPARE
		Step.PREPARE: step = Step.AIM
		Step.AIM:
			if action == "cancel":
				history.append("P%d: 페이크 · 취소 (발수 유지)" % (turn_index + 1))
				return true
			if action.begins_with(JAM_PREFIX):
				_jam(int(action.trim_prefix(JAM_PREFIX)))
				return true
			scores[turn_index] += hit_score
			throws_done += 1
			jammed_by.clear()
			history.append("P%d: %d번째 투척, +%d점" % [turn_index + 1, throws_done, hit_score])
			step = Step.RESULT
		Step.RESULT: step = Step.TURN_CHECK
		Step.TURN_CHECK: step = Step.PLAYER_CHECK if throws_done == DARTS_PER_TURN else Step.MOVE
		Step.PLAYER_CHECK:
			if turn_index + 1 < player_count:
				turn_index += 1
				step = Step.TURN_START
			else:
				step = Step.RETURN_TABLE
		Step.RETURN_TABLE: step = Step.END_CHECK
		Step.END_CHECK: step = Step.FINISHED if round_number >= round_limit else Step.ROUND_CARDS
		Step.ROUND_CARDS:
			_refill_all()
			turn_index = 0
			round_number += 1
			step = Step.ROUND_START
	history.append(TITLES[step])
	return true


func standings() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for index in range(scores.size()):
		rows.append({"player": index + 1, "score": scores[index], "gap": absi(target_score - scores[index])})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.gap < b.gap)
	for index in range(rows.size()):
		rows[index]["rank"] = rows[index - 1].rank if index > 0 and rows[index].gap == rows[index - 1].gap else index + 1
	return rows


## 투척자 본인의 카드 사용: 손에 있는 종류마다 버튼 하나.
func _card_choice_actions() -> Dictionary:
	var hand: Array[int] = hands[turn_index]
	var result: Dictionary = {}
	for category in range(CardHandRules.CATEGORY_NAMES.size()):
		var amount: int = CardHandRules.count(hand, category)
		if amount > 0:
			result[USE_PREFIX + str(category)] = "%s 카드 사용 (%d장)" % [CardHandRules.CATEGORY_NAMES[category], amount]
	result["skip"] = "미사용" if not hand.is_empty() else "카드 없음 · 미사용"
	return result


## 조준 중: 발사·페이크 + 다른 참가자의 방해(카드가 있고 이번 발에 아직 방해하지 않은 사람).
func _aim_actions() -> Dictionary:
	var result: Dictionary = {"throw": "발사", "cancel": "페이크 · 취소"}
	for index in range(player_count):
		if index != turn_index and not hands[index].is_empty() and not jammed_by.has(index):
			result[JAM_PREFIX + str(index)] = "P%d 방해 (%s)" % [index + 1, CardHandRules.CATEGORY_NAMES[hands[index][0]]]
	return result


## 방해자는 손패 맨 앞 카드를 쓴다(시연 단순화 — 실제 경기에서는 종류를 고른다). 효과 수치는 미적용.
func _jam(jammer: int) -> void:
	var category: int = hands[jammer][0]
	CardHandRules.take(hands[jammer], category)
	jammed_by.append(jammer)
	history.append("P%d → P%d 방해: %s 카드 (P%d 손패 %d/%d)" % [jammer + 1, turn_index + 1,
		CardHandRules.CATEGORY_NAMES[category], jammer + 1, hands[jammer].size(), CardHandRules.HAND_LIMIT])


func _refill_all() -> void:
	last_drawn.resize(player_count)
	for index in range(player_count):
		last_drawn[index] = CardHandRules.refill(hands[index], random)
		if last_drawn[index] == 0:
			history.append("P%d: 0장 — 쓴 카드가 없어 못 받음 (손패 %d/%d)" % [index + 1, hands[index].size(), CardHandRules.HAND_LIMIT])
		else:
			history.append("P%d: +%d장 → 손패 %d/%d" % [index + 1, last_drawn[index], hands[index].size(), CardHandRules.HAND_LIMIT])
