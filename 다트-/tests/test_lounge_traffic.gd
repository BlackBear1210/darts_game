extends SceneTree
## 라운지 스냅샷 줄이기(2026-11-26 "멀티 렉"). 가만히 있는 소품 23개를 초당 10번 내보내느라
## 사람당 91KB/s(전체의 83%)가 나갔고, 이 길은 reliable 이라 중계에서 꾸러미 하나가 늦으면
## 뒤가 전부 밀렸다. 바뀐 게 없으면 보내지 않고, 바뀌지 않는 항목은 아예 빼고 보낸다.
## 빼고 보내는 만큼 받는 쪽이 제대로 합치는지(왕복)가 핵심이다.
var main: Node
var game: GameView
var lounge: Node3D


func _initialize() -> void:
	_run.call_deferred()


func index_of(kind: String) -> int:
	for index in range(lounge.objects.size()):
		if lounge.objects[index].kind == kind: return index
	return -1


func _run() -> void:
	main = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	var options := RoomSettings.new()
	options.social_lobby = true
	options.solo = true
	options.capacity = 2
	options.bot_count = 1
	main.session.host_room("테스터", 17683, options)
	await create_timer(0.8).timeout
	game = main._game
	lounge = game.lounge

	# 1) 보내는 내용에서 바뀌지 않는 항목은 빠진다(소품 한 개당 3분의 1쯤 줄어든다).
	var payload: Dictionary = lounge.public_state()
	var sample: Dictionary = payload.objects[0]
	for field: String in lounge.FIXED_FIELDS:
		assert(not sample.has(field), "바뀌지 않는 '%s' 는 보내지 않는다" % field)
	assert(sample.has("position") and sample.has("holder"), "바뀌는 값은 보낸다")
	assert(var_to_bytes(payload.objects).size() < var_to_bytes(lounge.objects).size() * 0.8, "눈에 띄게 작아진다")

	# 2) 바뀐 게 없으면 다시 보내지 않는다.
	lounge._publish()
	var sent_at: float = lounge._sent_at
	await create_timer(0.4).timeout
	lounge._publish()
	assert(is_equal_approx(lounge._sent_at, sent_at), "그대로면 안 보낸다")

	# 3) 하나라도 바뀌면 바로 보낸다.
	var bottle: int = index_of("bottle")
	lounge.objects[bottle].holder = 1
	lounge._publish()
	assert(lounge._sent_at > sent_at, "바뀌면 보낸다")

	# 4) 왕복: 보낸 그대로 받으면 상태가 되살아난다(바뀌지 않는 항목은 내 쪽 것이 남는다).
	lounge.objects[bottle].drank = lounge.now()
	lounge.objects[bottle].position = Vector3(1.5, 1.2, 2.5)
	var wire: Dictionary = lounge.public_state()
	var want_home: Vector3 = lounge.objects[bottle].home
	var want_kind: String = lounge.objects[bottle].kind
	# 받는 쪽이 엉뚱한 값을 들고 있다고 치고, 지워져야 할 값도 미리 넣어 둔다.
	lounge.objects[bottle].holder = 0
	lounge.objects[bottle].position = Vector3.ZERO
	lounge.objects[index_of("cue")].drank = lounge.now()
	lounge._receive_event("lounge", wire)
	assert(int(lounge.objects[bottle].holder) == 1, "들고 있는 사람이 되살아난다")
	assert(lounge.objects[bottle].position.is_equal_approx(Vector3(1.5, 1.2, 2.5)), "자리가 되살아난다: %s" % lounge.objects[bottle].position)
	assert(lounge.objects[bottle].has("drank"), "마시는 중도 전해진다")
	assert(lounge.objects[bottle].home.is_equal_approx(want_home), "보내지 않은 제자리는 내 쪽 값이 남는다")
	assert(str(lounge.objects[bottle].kind) == want_kind, "보내지 않은 종류도 그대로다")
	assert(not lounge.objects[index_of("cue")].has("drank"), "방장이 지운 값은 받는 쪽에서도 지워진다")

	main.queue_free()
	await process_frame
	print("PASS: the lounge snapshot drops fixed fields, is skipped while unchanged, and still round-trips holder/position/drank exactly")
	quit()
