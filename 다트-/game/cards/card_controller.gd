class_name CardController
extends RefCounted
## 이전 3종 카드 시연의 후보·사용 계획. 현재 F5는 MatchCards를 사용한다.
## 예전 CardDefinition 손패는 종류 번호 배열인 MatchPlayer.hand와 섞지 않는다.

var _candidates: Dictionary = {}
var _picked: Dictionary = {}
var _planned: Dictionary = {}
var _hands: Dictionary = {}
var _next_uid: int = 1
var _random := RandomNumberGenerator.new()


func _init() -> void:
	_random.randomize()


func begin(players: Array[MatchPlayer]) -> void:
	_candidates.clear()
	_picked.clear()
	_planned.clear()
	for player in players:
		var kinds: Array[int] = [0, 1, 2]
		for index in range(2, 0, -1):
			var other := _random.randi_range(0, index)
			var kind := kinds[index]
			kinds[index] = kinds[other]
			kinds[other] = kind
		var cards: Array[CardDefinition] = []
		for kind in kinds:
			cards.append(CardDefinition.new(_next_uid, kind))
			_next_uid += 1
		_candidates[player.peer_id] = cards


func choose(player: MatchPlayer, index: int, hand_limit: int) -> bool:
	if player == null or _picked.has(player.peer_id) or index < 0 or index >= 3:
		return false
	if not _candidates.has(player.peer_id): return false
	var hand: Array[CardDefinition] = []
	hand.assign(_hands.get(player.peer_id, []))
	if hand.size() >= maxi(hand_limit, 1): hand.pop_front()
	hand.append(_candidates[player.peer_id][index])
	_hands[player.peer_id] = hand
	_picked[player.peer_id] = index
	return true


func plan_use(player: MatchPlayer, uid: int, target: int, state: MatchState) -> bool:
	if player == null or not _picked.has(player.peer_id): return false
	if uid == 0:
		_planned.erase(player.peer_id)
		return true
	var card: CardDefinition = _find_card(player.peer_id, uid)
	if card == null or state.find_player(target) == null: return false
	if card.kind == CardDefinition.Kind.SHUFFLE:
		if target == player.peer_id: return false
	elif target != player.peer_id:
		return false
	_planned[player.peer_id] = {"uid": uid, "target": target}
	return true


func finish(state: MatchState, hand_limit: int) -> void:
	for player in state.players:
		if not _picked.has(player.peer_id): choose(player, 0, hand_limit)
	for player in state.players:
		if not _planned.has(player.peer_id): continue
		var choice: Dictionary = _planned[player.peer_id]
		var card: CardDefinition = _find_card(player.peer_id, choice.uid)
		var target := state.find_player(choice.target)
		if card == null or target == null: continue
		(_hands[player.peer_id] as Array).erase(card)
		match card.kind:
			CardDefinition.Kind.BONUS: target.bonus += 10
			CardDefinition.Kind.DOUBLE: target.multiplier *= 2
			CardDefinition.Kind.SHUFFLE: target.layout.shuffle_with(_random)


func private_snapshot(peer_id: int) -> Dictionary:
	var cards: Array[Dictionary] = []
	for card: CardDefinition in _candidates.get(peer_id, []): cards.append(card.to_snapshot())
	var hand: Array[Dictionary] = []
	for card: CardDefinition in _hands.get(peer_id, []): hand.append(card.to_snapshot())
	return {"candidates": cards, "picked": _picked.get(peer_id, -1),
		"hand": hand, "planned": _planned.get(peer_id, {"uid": 0, "target": 0})}


func _find_card(peer_id: int, uid: int) -> CardDefinition:
	for card: CardDefinition in _hands.get(peer_id, []):
		if card.uid == uid: return card
	return null
