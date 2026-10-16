extends RefCounted
## 흐름도 검토용 로컬 진행 모델. 실제 경기 권한·물리·카드 규칙과는 연결하지 않는다.

enum Step {
	START, ROOM, SETTINGS, TABLE, INITIAL_CARDS, ORDER, ROUND_START,
	TURN_START, MOVE, CARD_CHOICE, CARD_APPLY, PREPARE, AIM, RESULT,
	TURN_CHECK, PLAYER_CHECK, RETURN_TABLE, END_CHECK, ROUND_CARDS, EXCHANGE, FINISHED,
}

const TITLES: Array[String] = [
	"시작", "방 생성 · 플레이어 입장", "방장 모드 · 기본 설정 선택",
	"원형 테이블에 모임", "카드 획득", "플레이 순서 결정", "라운드 시작",
	"현재 플레이어 차례 · 투척 기회 3회", "자유 이동 · 투척 위치 선택",
	"이번 투척에 카드를 사용할까?", "카드 선택 · 효과 적용", "투척 준비",
	"조준 · 충전 · 타이밍 판단", "다트 투척 · 결과와 점수 처리",
	"이번 차례에 3회 투척 완료?", "모든 플레이어의 차례 완료?",
	"라운드 종료 · 전원 테이블로 자동 복귀", "경기 종료 조건 충족?",
	"카드 획득 · 손패 정비", "카드 교환 가능 · 2장 버리고 새 카드 1장", "게임 종료",
]

var step: Step = Step.START
var player_count: int = 2
var round_limit: int = 2
var target_score: int = 100
var round_number: int = 1
var turn_index: int = 0
var throws_done: int = 0
var scores: Array[int] = []
var hands: Array[int] = []
var exchanged: bool = false
var history: Array[String] = []


func _init() -> void:
	reset()


func reset() -> void:
	step = Step.START
	round_number = 1
	turn_index = 0
	throws_done = 0
	exchanged = false
	scores.clear()
	hands.clear()
	history.assign(["흐름도 시연 시작"])


func actions() -> Dictionary:
	match step:
		Step.START: return {"next": "시작"}
		Step.ROOM: return {"next": "입장 완료 (가상 참가자)"}
		Step.SETTINGS: return {"next": "설정 확정"}
		Step.MOVE: return {"next": "위치 선택 완료"}
		Step.CARD_CHOICE:
			if hands[turn_index] > 0:
				return {"use": "카드 사용", "skip": "미사용"}
			return {"skip": "카드 없음 · 미사용"}
		Step.AIM: return {"throw": "발사", "cancel": "페이크 · 취소"}
		Step.EXCHANGE:
			if not exchanged and hands[turn_index] >= 2:
				return {"exchange": "2장 → 1장 교환", "next": "정비 완료"}
			return {"next": "정비 완료"}
		Step.FINISHED: return {}
		_: return {"next": "다음 단계"}


func act(action: String, hit_score: int = 20) -> bool:
	if not actions().has(action):
		return false
	if step == Step.SETTINGS and (player_count < 2 or player_count > 4 or round_limit < 1 or target_score < 0):
		return false
	if step == Step.AIM and action == "throw" and (hit_score < 0 or hit_score > 60):
		return false
	match step:
		Step.START: step = Step.ROOM
		Step.ROOM: step = Step.SETTINGS
		Step.SETTINGS:
			scores.resize(player_count)
			scores.fill(0)
			hands.resize(player_count)
			hands.fill(0)
			step = Step.TABLE
		Step.TABLE: step = Step.INITIAL_CARDS
		Step.INITIAL_CARDS:
			hands.fill(3)
			step = Step.ORDER
		Step.ORDER: step = Step.ROUND_START
		Step.ROUND_START:
			turn_index = 0
			step = Step.TURN_START
		Step.TURN_START:
			throws_done = 0
			step = Step.MOVE
		Step.MOVE: step = Step.CARD_CHOICE
		Step.CARD_CHOICE: step = Step.CARD_APPLY if action == "use" else Step.PREPARE
		Step.CARD_APPLY:
			hands[turn_index] -= 1
			step = Step.PREPARE
		Step.PREPARE: step = Step.AIM
		Step.AIM:
			if action == "cancel":
				history.append("P%d: 페이크 · 취소 (발수 유지)" % (turn_index + 1))
				return true
			scores[turn_index] += hit_score
			throws_done += 1
			history.append("P%d: %d번째 투척, +%d점" % [turn_index + 1, throws_done, hit_score])
			step = Step.RESULT
		Step.RESULT: step = Step.TURN_CHECK
		Step.TURN_CHECK: step = Step.PLAYER_CHECK if throws_done == 3 else Step.MOVE
		Step.PLAYER_CHECK:
			if turn_index + 1 < player_count:
				turn_index += 1
				step = Step.TURN_START
			else:
				step = Step.RETURN_TABLE
		Step.RETURN_TABLE: step = Step.END_CHECK
		Step.END_CHECK: step = Step.FINISHED if round_number >= round_limit else Step.ROUND_CARDS
		Step.ROUND_CARDS:
			for index in range(player_count):
				hands[index] += 1
			turn_index = 0
			exchanged = false
			step = Step.EXCHANGE
		Step.EXCHANGE:
			if action == "exchange":
				hands[turn_index] -= 1
				exchanged = true
				history.append("P%d: 카드 2장 폐기 → 새 카드 1장" % (turn_index + 1))
				return true
			turn_index += 1
			exchanged = false
			if turn_index == player_count:
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
