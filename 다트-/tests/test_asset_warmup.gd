extends SceneTree
## 미리 읽기(app/asset_warmup.gd) 검사 — 2026-11-17 밤 사용자 "실행·플레이 도중에 나가면 렉".
##   & $godot --headless --path . --script res://tests/test_asset_warmup.gd
## 1. 미리 읽을 목록이 실제로 경기 중 load 하는 목록과 같다(소품 prop_looks.gd · 오락기 arcade_room.gd). 파일이 다 있다.
## 2. 뒤에서 다 읽고 붙잡는다 · 경기 장면을 같은 것으로 돌려준다.
## 3. 경기에 들어갔다 나와도 붙잡아 둔 모델이 풀리지 않는다(다시 들어갈 때 파일을 또 읽지 않는다).
## 4. 섞기 연출 중에 나가도 "get_tree() 가 비었다"·"이미 지워진" 오류가 나지 않는다(deck_show.gd · shuffle_motions.gd).
##    예전엔 경기 중 나가면 이 오류가 한꺼번에 35개 났다(편집기 실행이면 디버거로 보내느라 더 멈춘다).

const AssetWarmup = preload("res://app/asset_warmup.gd")
const PropLooks = preload("res://game/lounge/prop_looks.gd")
const ArcadeRoom = preload("res://game/lounge/arcade/arcade_room.gd")
const DeckShow = preload("res://game/table/deck_show.gd")
const ShuffleMotions = preload("res://game/card_round/cards/shuffle_motions.gd")

var _failed: bool = false


## 엔진 오류를 센다(시험 안에서 "SCRIPT ERROR" 를 직접 잡는다).
class ErrorCounter extends Logger:
	var count: int = 0
	var first: String = ""

	func _log_error(function: String, file: String, line: int, _code: String, rationale: String, _editor_notify: bool,
			_error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		count += 1
		if first.is_empty():
			first = "%s (%s:%d %s)" % [rationale, file, line, function]

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		print("FAIL ", message)


func _run() -> void:
	# 1. 목록이 경기 코드와 같다.
	var kinds: Array = PropLooks.REST.keys()
	kinds.sort()
	var warm_kinds: Array = AssetWarmup.PROP_KINDS.duplicate()
	warm_kinds.sort()
	_check(kinds == warm_kinds, "소품 목록이 prop_looks.gd 와 다르다: %s / %s" % [kinds, warm_kinds])
	_check(AssetWarmup.ARCADE_DIR == ArcadeRoom.ROUNDHOUSE_ARCADE, "오락기 경로 틀이 arcade_room.gd 와 다르다")
	var arcade: Array[String] = []
	arcade.append_array(ArcadeRoom.CABINET_MODELS)
	arcade.append_array(ArcadeRoom.DECO_PLUSHES)
	arcade.append_array(["arcade_bench", "prize_showcase"])
	for key in arcade:
		_check(AssetWarmup.ARCADE_MODELS.has(key), "오락기 모델 %s 가 미리 읽기 목록에 없다" % key)
	for path in AssetWarmup.paths():
		_check(ResourceLoader.exists(path), "파일이 없다: " + path)

	# 2. 실제 앱처럼 main 을 띄우면 뒤에서 읽기 시작한다 → 다 읽힌다.
	var main: Node = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	var until: float = Time.get_ticks_msec() + 60000.0
	while AssetWarmup.poll() and Time.get_ticks_msec() < until:
		await process_frame
	_check(AssetWarmup.held_count() == AssetWarmup.paths().size(), "다 못 읽었다(%d / %d)" % [AssetWarmup.held_count(), AssetWarmup.paths().size()])
	_check(AssetWarmup.scene(AssetWarmup.GAME_SCENE) == load(AssetWarmup.GAME_SCENE), "경기 장면이 붙잡아 둔 것과 다르다")

	# 3. 싱글 방에 들어갔다 나와도 붙잡아 둔 모델이 풀리지 않는다.
	var options := RoomSettings.new()
	options.social_lobby = true
	options.solo = true
	options.bot_count = 3
	main.session.host_room("테스터", 17663, options)
	await create_timer(0.6).timeout
	_check(main._game != null, "경기 화면이 안 생겼다")
	main.session.leave_room()
	await create_timer(1.0).timeout
	var cached: int = 0
	for path in AssetWarmup.paths():
		if ResourceLoader.has_cached(path): cached += 1
	_check(cached == AssetWarmup.paths().size(), "나온 뒤 붙잡아 둔 모델이 풀렸다(%d / %d)" % [cached, AssetWarmup.paths().size()])

	# 4. 섞기 모양마다: 섞는 도중에 화면에서 빼기(경기에서 나갈 때 main._remove_game 과 같은 순서) / 바로 지우기 → 오류 0.
	#    화면 없는 시험에서는 게임이 덱 연출을 만들지 않으므로(카드 그림 굽기 뒤에 만든다) 여기서 직접 만든다.
	var errors := ErrorCounter.new()
	OS.add_logger(errors)
	var holder := Node3D.new()
	root.add_child(holder)
	var shows: Array[Node] = []
	for style in range(ShuffleMotions.STYLE_NAMES.size() * 2):
		var show: Node = DeckShow.new()
		holder.add_child(show)
		show.sync(MatchState.new())
		var state := MatchState.new()
		state.match_id = style
		var deals: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
		show._play(state, deals)
		shows.append(show)
	await create_timer(0.9).timeout
	for index in range(shows.size()):
		holder.remove_child(shows[index])
		if index % 2 == 0:
			shows[index].queue_free()
	await create_timer(0.1).timeout
	for index in range(1, shows.size(), 2):
		shows[index].queue_free()
	await create_timer(4.0).timeout
	OS.remove_logger(errors)
	_check(errors.count == 0, "섞는 도중 빠지거나 지워진 덱 연출에서 오류 %d개 (%s)" % [errors.count, errors.first])
	print("ASSET WARMUP %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)
