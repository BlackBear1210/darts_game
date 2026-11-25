extends SceneTree
## 구역을 고르는 카드와 지뢰 겹쳐 심기(2026-11-24 사용자 요청).
## 팝업 그림은 눈으로 확인했고, 여기서는 규칙과 칸 번호 약속만 본다.

const Catalog = preload("res://game/card_round/rules/card_catalog.gd")
const SectorPicker = preload("res://ui/sector_picker.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_cards_with_choice()
	_picker_angles()
	_picker_open_close()
	await _mine_stacking()
	print("PASS: 구역 고르기 카드 · 지뢰 겹쳐 심기")
	quit()


## 구역을 고르는 카드는 팝업을 띄우는 쪽이 "sector" 로 알아본다.
func _cards_with_choice() -> void:
	var mine: Dictionary = Catalog.card(Catalog.type_of("mine"))
	assert(str(mine.get("choice", "")) == "sector", "지뢰 심기는 칸을 고르는 카드여야 한다")
	for id: String in ["sector_block", "double_or_nothing"]:
		assert(str(Catalog.card(Catalog.type_of(id)).get("choice", "")) == "sector", "%s 도 칸 카드" % id)
	# 홀짝·정밀 조정은 판이 필요 없다 — Z·X 로 고른다.
	for id: String in ["parity", "precision"]:
		assert(str(Catalog.card(Catalog.type_of(id)).get("choice", "")) != "sector", "%s 는 판 팝업이 아니다" % id)


## 팝업이 쓰는 칸 번호는 BoardLayout 과 같은 약속이다: 0번이 12시, 시계 방향.
## 화면 y 는 아래로 자라므로 팝업은 뒤집어서 넘긴다 — 그 규칙이 맞는지만 본다.
func _picker_angles() -> void:
	var cases: Array = [[Vector2(0, -1), 0], [Vector2(1, 0), 5], [Vector2(0, 1), 10], [Vector2(-1, 0), 15]]
	for case: Array in cases:
		var screen: Vector2 = case[0]
		var sector: int = BoardLayout.sector_at(Vector2(screen.x, -screen.y))
		assert(sector == int(case[1]), "화면 %s → %d번 칸이어야 한다(실제 %d)" % [str(screen), int(case[1]), sector])
	assert(SectorPicker.RADIUS > 0.0, "팝업 판 반지름")


## 팝업은 고르거나 닫은 뒤 다시 열리지 않아야 한다(2026-11-25 "닫히지도 않아").
func _picker_open_close() -> void:
	var card: int = 7
	var other: int = 9
	# 아무것도 안 띄운 상태에서 구역 카드를 꺼내 들면 띄운다.
	assert(SectorPicker.should_open(card, -1, -1), "처음 꺼내 들면 띄운다")
	# 띄워 둔 동안에는 다시 띄우지 않는다(매 프레임 묻는다).
	assert(not SectorPicker.should_open(card, card, -1), "이미 띄워 둔 카드")
	# 고르거나 닫은 뒤(opened 는 비고 done 에 적힌다) 다시 열리면 안 된다 — 이게 버그였다.
	assert(not SectorPicker.should_open(card, -1, card), "닫은 카드는 다시 안 띄운다")
	# 다른 구역 카드를 꺼내 들면 띄운다.
	assert(SectorPicker.should_open(other, -1, card), "다른 카드는 띄운다")
	# 구역 카드가 아니면 띄우지 않는다.
	assert(not SectorPicker.should_open(-1, -1, -1), "구역 카드가 아니면 안 띄운다")


## 같은 칸에 겹쳐 심으면 그 칸을 맞혔을 때 겹친 수만큼 터진다.
func _mine_stacking() -> void:
	var controller := _controller()
	controller._begin_cards()
	var cards = controller.cards
	assert(cards.mines.is_empty(), "처음엔 지뢰가 없다")
	# 7번 칸에 두 번, 12번 칸에 한 번 심는다.
	var Rules = load("res://game/card_round/rules/round_rules.gd")
	for spot: int in [7, 7, 12]:
		var effect = Rules.Effect.new()
		effect.kind = "mine"
		effect.choice = spot
		var note: String = cards.actions.apply(effect, 1, 1)
		assert(not note.is_empty(), "지뢰를 심지 못했다")
	assert(cards.mines.size() == 3, "심은 지뢰 3개 · 실제 %d" % cards.mines.size())
	assert(cards.mines.count(7) == 2, "7번 칸에 2겹이어야 한다")
	assert(cards.mines.count(12) == 1, "12번 칸은 1겹")
	assert(cards.mines.count(3) == 0, "안 심은 칸은 0")
	controller.queue_free()
	await process_frame


func _controller() -> MatchController:
	var room := RoomState.new()
	room.settings.social_lobby = true
	for id in range(1, 5):
		room.add_player(id, "자리 %d" % id)
	var controller := MatchController.new()
	root.add_child(controller)
	controller.configure(room, 1)
	controller.start()
	return controller
