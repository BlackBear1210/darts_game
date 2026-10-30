extends SceneTree
## 새 규칙의 경계값. 네트워크/3D는 test_lounge와 run_lounge에서 별도로 검증한다.
const Cards = preload("res://game/card_round/rules/card_catalog.gd")
const Adapter = preload("res://game/match/match_cards.gd")
const Bridge = preload("res://game/lounge/youtube_bridge.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var settings := RoomSettings.from_snapshot({"rounds": -10, "capacity": 99, "dart_seconds": INF, "special_chance": NAN, "card_weights": {"plus_10": "bad"}, "disabled_cards": [77, "not_a_card"], "solo": false})
	assert(settings.rounds == 1 and settings.capacity == 4)
	assert(settings.dart_seconds == 30 and settings.special_chance == 30)
	assert(settings.disabled_cards.is_empty() and settings.card_weights.plus_10 == 1.0)
	var random := RandomNumberGenerator.new()
	random.seed = 129
	settings.special_cards = false
	for index in range(300): assert(int(Cards.card(settings.draw_card(random)).category) == 0)
	settings.special_cards = true
	settings.special_chance = 100
	for index in range(300): assert(int(Cards.card(settings.draw_card(random)).category) != 0)
	settings.disabled_cards.clear()
	for entry: Dictionary in Cards.CARDS:
		if entry.id != "power_up": settings.disabled_cards.append(str(entry.id))
	settings.sanitize()
	assert(settings.cards_enabled and settings.draw_card(random) == Cards.type_of("power_up"))
	settings.disabled_cards.append("power_up")
	settings.sanitize()
	assert(not settings.cards_enabled and settings.draw_card(random) == -1)
	assert(Bridge.video_id("https://youtu.be/dQw4w9WgXcQ") == "dQw4w9WgXcQ")
	assert(Bridge.video_id("https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=3") == "dQw4w9WgXcQ")
	assert(Bridge.video_id("https://youtube.com.evil.test/watch?v=dQw4w9WgXcQ").is_empty())
	assert(Bridge.video_id("javascript:alert(1)").is_empty())
	var controller := MatchController.new()
	root.add_child(controller)
	var room := RoomState.new()
	room.settings.social_lobby = true
	room.settings.solo = true
	room.settings.win_mode = 2
	room.settings.target_score = 50
	room.add_player(1, "A")
	controller.configure(room, 1)
	var adapter: RefCounted = Adapter.new(controller)
	adapter.rules.order.assign([0])
	adapter.begin_dart_turn()
	assert(controller.state.players[0].score == 50)
	var result: Dictionary = adapter.score(60)
	assert(result.bust and controller.state.players[0].score == 50)
	adapter.begin_dart_turn()
	result = adapter.score(50)
	assert(result.win and controller.state.players[0].score == 0)
	controller.queue_free()
	await process_frame
	print("PASS: settings hostile inputs, clamp boundaries, card pools, all-disabled fallback, countdown bust/exact-zero, YouTube URL allowlist")
	quit()
