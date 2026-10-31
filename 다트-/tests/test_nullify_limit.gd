extends SceneTree
## 무효(×0)는 한 경기에 딱 한 장(2026-10-31 사용자 요청 — MatchController.NULLIFY_ID).
## 첫 나눠 주기에서 한 사람에게만 한 장 들어가고, 라운드마다 손패를 다시 채워도 새 무효는 나오지 않는다.
## 방 설정에서 무효를 꺼 두면 한 장도 없다.
const Catalog = preload("res://game/card_round/rules/card_catalog.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var nullify: int = Catalog.type_of("times_0")
	# 뽑기는 무작위라 여러 판을 돌려 본다(예전 규칙이면 첫 판부터 거의 항상 2장 이상).
	for trial in range(40):
		var controller := _controller(false)
		controller._begin_cards()
		assert(_count(controller, nullify) == 1, "첫 나눠 주기에 무효는 딱 한 장")
		for round_index in range(6):
			# 라운드 동안 쓴 셈 치고 뒤쪽 카드를 몇 장씩 버린 뒤 다시 채운다.
			for player in controller.state.players:
				player.hand.resize(maxi(0, player.hand.size() - 3 - round_index % 3))
			var before: int = _count(controller, nullify)
			controller._begin_cards()
			assert(_count(controller, nullify) == before, "다시 채울 때 새 무효가 나오면 안 된다")
			for player in controller.state.players:
				assert(player.hand.size() == CardHandRules.HAND_LIMIT, "무효를 빼고 다시 뽑아도 7장은 채운다")
		controller.queue_free()
	var off := _controller(true)
	off._begin_cards()
	assert(_count(off, nullify) == 0, "방 설정에서 무효를 끄면 한 장도 없다")
	off.queue_free()
	await process_frame
	print("PASS: nullify x0 dealt exactly once per match, never refilled, none when disabled")
	quit()


## 네 명(사람 1 + 봇 3 자리) 경기 진행기. 화면·네트워크 없이 카드 나눠 주기만 돌린다.
func _controller(disable_nullify: bool) -> MatchController:
	var room := RoomState.new()
	room.settings.social_lobby = true
	if disable_nullify:
		room.settings.disabled_cards.append("times_0")
	for id in range(1, 5):
		room.add_player(id, "자리 %d" % id)
	var controller := MatchController.new()
	root.add_child(controller)
	controller.configure(room, 1)
	return controller


func _count(controller: MatchController, type: int) -> int:
	var total: int = 0
	for player in controller.state.players:
		total += player.hand.count(type)
	return total
