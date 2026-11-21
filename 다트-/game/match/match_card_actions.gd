extends RefCounted
## [카드 한 장 = 한 갈래] 쓰는 순간 끝나는 카드(Timing.INSTANT)와 "지금 이 카드를 쓸 수 있나" 조건을 한 곳에 모은다(2026-11-21).
##
## - context_problem(): 화면(LoungeHud)과 방장(MatchCards._use)이 같은 함수를 쓴다 → 화면은 "쓸 수 있음"인데
##   방장이 거절하는 일이 없다. 손님 화면에서도 돌도록 MatchState 스냅샷(차례·단계·손패·card_effects)만 본다.
## - apply(): 방장만. 지뢰·차례 바꾸기·점프·타이머·소매치기·속박·끌어당기기를 실제로 처리하고 킬로그에 붙일 글을 돌려준다.
##   사람 몸이 필요한 것(속박·끌어당기기)은 MatchController.card_world(GameView 쪽 CardWorld)에 맡긴다.
##
## 새 INSTANT 카드를 더하는 법: card_catalog.gd 맨 뒤에 한 줄 → 여기 context_problem·apply 에 한 갈래씩.
## 점수만 바꾸는 카드는 여기가 아니라 RoundRules.resolve_dart, 몸·화면 효과는 카드 목록의 "mod" 이름으로 충분하다.

const Catalog = preload("res://game/card_round/rules/card_catalog.gd")
## 지뢰는 경기 전체에 이만큼까지(과녁 20칸 중 — 너무 많으면 어디를 맞혀도 감점이라 재미가 없다). 시연값.
const MINE_LIMIT: int = 5
## 타이머 감소: 남은 시간에 곱하는 비율과 그래도 남겨 두는 최소 시간(초). 시연값.
const TIMER_RATIO: float = 0.5
const TIMER_FLOOR: float = 3.0

## MatchCards(순환 preload 를 피하려고 타입 없이 둔다).
var cards
## 다음 차례를 건너뛸 사람(peer ID). 점프 카드가 넣고 MatchController._begin_turn 이 take_skip 으로 꺼낸다.
var skips: Array[int] = []
var _random := RandomNumberGenerator.new()


func _init(owner) -> void:
	cards = owner
	_random.randomize()


## 이 카드를 지금 쓸 수 없는 이유(쓸 수 있으면 빈 글자). caster = 쓰는 사람, target = Tab 으로 고른 사람(PICK 카드만).
static func context_problem(type: int, caster: int, state: MatchState, target: int = 0) -> String:
	if type < 0 or type >= Catalog.count():
		return ""
	var data: Dictionary = Catalog.card(type)
	var active: MatchPlayer = state.active_player()
	var me: MatchPlayer = state.find_player(caster)
	if active == null or me == null:
		return ""
	var mine: bool = active.peer_id == caster
	var aiming: bool = state.phase == MatchState.Phase.AIMING
	match str(data.effect):
		"steal", "half":
			if mine: return "내 차례에는 못 쓴다"
		"timer_cut":
			if mine: return "내 차례에는 못 쓴다"
			if not aiming: return "조준 중일 때만 쓸 수 있다"
		"swap_turn":
			if not aiming: return "조준 중일 때만 쓸 수 있다"
			if mine and state.turn_index + 1 >= state.players.size(): return "바꿀 다음 사람이 없다"
			if not mine and state.players.find(me) < state.turn_index: return "이번 라운드에 이미 던졌다"
		"skip_turn":
			var next: MatchPlayer = next_player(state)
			if next == null or next.peer_id == caster: return "다음 차례가 나라서 못 쓴다"
		"repeat_spot":
			if not aiming: return "조준 중일 때만 쓸 수 있다"
			if not bool(active.card_effects.get("repeat_ready", false)): return "이번 라운드에 꽂힌 다트가 없다"
		"mine":
			if int(me.card_effects.get("mine_count", 0)) >= MINE_LIMIT: return "지뢰는 경기당 %d개까지" % MINE_LIMIT
		"pickpocket":
			var victim: MatchPlayer = state.find_player(target)
			if victim != null and victim.hand.is_empty(): return "그 사람은 카드가 없다"
	if Catalog.card(type).has("choice") and not aiming:
		return "조준 중일 때만 쓸 수 있다"
	return ""


## 다음 차례 사람(이번 라운드 마지막이면 다음 라운드 첫 사람 = 자리 번호가 가장 작은 사람). 없으면 null.
static func next_player(state: MatchState) -> MatchPlayer:
	if state.players.is_empty():
		return null
	if state.turn_index + 1 < state.players.size():
		return state.players[state.turn_index + 1]
	var first: MatchPlayer = state.players[0]
	for player in state.players:
		if player.seat < first.seat: first = player
	return first


## [방장] 쓰는 순간 끝나는 카드를 처리한다. effect = RoundRules.Effect. 킬로그 뒤에 붙일 짧은 글을 돌려준다.
func apply(effect, caster: int, target: int) -> String:
	var controller: MatchController = cards.controller
	var state: MatchState = controller.state
	match str(effect.kind):
		"mine":
			var free: Array[int] = []
			for sector in range(20):
				if sector not in cards.mines: free.append(sector)
			if free.is_empty():
				return "지뢰 자리가 없다"
			cards.mines.append(free[_random.randi_range(0, free.size() - 1)])
			effect.result = "지뢰 %d개째" % cards.mines.size()
			return "보이지 않는 지뢰를 심음"
		"swap_turn":
			return _swap_turn(caster)
		"skip_turn":
			var next: MatchPlayer = next_player(state)
			if next == null:
				return ""
			skips.append(next.peer_id)
			effect.result = "%s 건너뜀 예약" % next.display_name
			return "%s의 다음 차례를 건너뜀" % next.display_name
		"timer_cut":
			var left: float = controller.cut_timer(TIMER_RATIO, TIMER_FLOOR)
			effect.result = "남은 %.0f초" % left
			return "남은 시간 %.0f초로" % left
		"pickpocket":
			var card = cards.rules.steal_card(cards.peers.find(target), cards.peers.find(caster))
			effect.result = "1장 훔침" if card != null else "훔칠 카드 없음"
			return "카드 한 장 슬쩍!" if card != null else "훔칠 카드가 없었다"
		"bind", "pull":
			var victim: int = 0
			if controller.card_world.is_valid():
				victim = int(controller.card_world.call(str(effect.kind), {"peer_id": caster}))
			var hit: MatchPlayer = state.find_player(victim)
			effect.result = "빗나감" if hit == null else "%s 명중" % hit.display_name
			if hit == null:
				return "빗나감"
			return "%s 속박!" % hit.display_name if effect.kind == "bind" else "%s 끌어당김!" % hit.display_name
	return ""


## 사람이 점프 카드로 건너뛸 차례인가(꺼내면 지운다).
func take_skip(peer_id: int) -> bool:
	if peer_id not in skips:
		return false
	skips.erase(peer_id)
	return true


## 차례 바꾸기: 아직 안 던진 사람이 지금 던지는 사람과 자리를 바꾼다(지금 던지는 사람이 쓰면 다음 사람과).
## 차례를 넘겨준 사람의 "차례 동안" 효과는 대기로 돌리고, 같은 차례 번호(turn_index)에서 새 사람으로 다시 시작한다.
## 라운드가 끝나면 MatchController 가 자리 순서로 되돌린다.
func _swap_turn(caster: int) -> String:
	var controller: MatchController = cards.controller
	var state: MatchState = controller.state
	var me: MatchPlayer = state.find_player(caster)
	var index: int = state.players.find(me)
	var other_index: int = state.turn_index + 1 if index == state.turn_index else state.turn_index
	if me == null or other_index < 0 or other_index >= state.players.size():
		return ""
	var leaving: MatchPlayer = state.players[state.turn_index]
	var other: MatchPlayer = state.players[other_index]
	cards.rules.pause_turn(cards.peers.find(leaving.peer_id))
	state.players[other_index] = me
	state.players[index] = other
	cards.reorder()
	controller.restart_turn()
	return "%s와 차례를 바꿈" % other.display_name
