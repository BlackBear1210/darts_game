extends Node
## F5 경기에서 다른 사람(봇·원격 플레이어) 캐릭터의 왼손 카드 부채(2026-10-31 저녁 사용자 요청: "봇 손에 카드가 안 들려 있다").
## 카드 라운드 시연(F6)의 상대 왼손 부채(game/card_round/flow/player_builder.gd)와 같은 HandFan·크기·자리를 쓴다.
##   - 손패가 한 장이라도 있으면 왼팔을 들어(CharacterRig.holding_cards) 부채를 든다. 걷거나 투척선에 서 있어도 손을 따라간다.
##   - 꺼내 든 카드(MatchPlayer.pending_slot)는 부채 위로 빠져나와 커진다 → 누가 카드를 쓰려는지 눈으로 보고 무효(×0)로 막을 수 있다.
##   - 카드 앞면은 든 사람 눈 쪽을 본다(실제 카드처럼). 뒤로 돌아가 들여다보면 보인다.
## 보이기만 하는 노드다. 손패는 원래 모든 스냅샷에 있으므로 규칙·네트워크는 바꾸지 않는다.
## 카드 그림(CardFaces)은 굽기가 끝난 뒤에 만들어야 한다 → GameView._prepare_hand_fan 이 굽기 뒤에 이 노드를 붙인다.

const HandFan = preload("res://game/card_round/cards/hand_fan.gd")
## 부채 자리(몸 기준)와 부채 면이 바라볼 눈 자리. 카드 라운드 시연 player_builder.gd 와 같은 값.
const FAN_POSITION := Vector3(0.11, 0.33, 0.43)
const FAN_EYE := Vector3(0, 0.75, 0.17)

## peer_id → 그 캐릭터 왼손 HandFan
var _fans: Dictionary = {}
## peer_id → 지금 부채에 꽂힌 손패(같으면 다시 만들지 않는다)
var _shown: Dictionary = {}


## 스냅샷마다 부른다. actors = GameView.actors(peer_id → PlayerView), local_id = 내 peer_id(내 것은 1인칭 부채가 따로 있다).
func sync(actors: Dictionary, players: Array[MatchPlayer], local_id: int) -> void:
	var present: Array[int] = []
	for player in players:
		var view: PlayerView = actors.get(player.peer_id)
		if view == null or player.peer_id == local_id:
			continue
		present.append(player.peer_id)
		var fan: HandFan = _fan_for(view, player)
		if fan == null:
			continue
		var hand: Array[int] = []
		hand.assign(player.hand)
		if hand != _shown.get(player.peer_id, []):
			_shown[player.peer_id] = hand.duplicate()
			for slot in range(CardHandRules.HAND_LIMIT):
				if slot < hand.size():
					if not fan.has_card(slot) or fan.cards[slot].type != hand[slot]:
						fan.set_card(slot, hand[slot])
				else:
					fan.remove_card(slot)
		if player.pending_slot != fan.lifted_slot:
			if player.pending_slot >= 0 and player.pending_slot < hand.size(): fan.lift(player.pending_slot)
			else: fan.lower()
		# 카드가 있으면 왼팔을 들어 부채를 든다. 마시는 중(오른팔)·던지는 중(오른팔)과는 팔이 달라 겹치지 않는다.
		var rig: CharacterRig = view.get("_rig")
		if rig != null:
			rig.holding_cards = not hand.is_empty()
	# 나간 사람 부채는 치운다(캐릭터가 지워지면 부채도 같이 지워지므로 기록만 정리).
	for peer_id: int in _fans.keys():
		if peer_id not in present:
			var stale: Node = _fans[peer_id]
			if is_instance_valid(stale): stale.queue_free()
			_fans.erase(peer_id)
			_shown.erase(peer_id)


## 캐릭터 몸(Model/Body)에 붙은 부채. 없으면 만든다. 레이어는 그 캐릭터와 같게 → 내 화면엔 내 몸·부채가 안 보인다.
func _fan_for(view: PlayerView, player: MatchPlayer) -> HandFan:
	var fan: HandFan = _fans.get(player.peer_id)
	if fan != null and is_instance_valid(fan):
		return fan
	var body := view.get_node_or_null("Model/Body") as Node3D
	if body == null:
		return null
	fan = HandFan.new()
	fan.name = "LeftHandCards"
	# 시연 2026-10-28 피드백 값: 상대 부채가 너무 작으면 안 보인다 → 0.85배·반지름 0.115·60도.
	fan.card_scale = 0.85
	fan.radius = 0.115
	fan.spread_degrees = 60.0
	fan.lift_height = 0.07
	fan.lift_scale = 1.3
	fan.lift_forward = 0.03
	fan.layer_mask = 1 << (player.seat + 1)
	body.add_child(fan)
	fan.position = FAN_POSITION
	fan.basis = Basis.looking_at(FAN_POSITION - FAN_EYE, Vector3.UP)
	_fans[player.peer_id] = fan
	return fan
