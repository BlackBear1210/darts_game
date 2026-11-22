extends SceneTree
## 펍 투척선에서 실제 개발자 카드 시험 턴을 여는 검토 진입점.
## --script res://art/dart_machine/oche_preview.gd 로 실행한다. 일반 방은 이 파일을 로드하지 않는다.
const Catalog = preload("res://game/card_round/rules/card_catalog.gd")
const IDS := ["", "cover", "cover", "vertical_split", "vertical_split", "horizontal_split", "horizontal_split", "board_zoom", "board_zoom", "board_split"]
const NAMES := ["기본", "왼쪽 가림", "오른쪽 가림", "세로 A", "세로 B", "가로 A", "가로 B", "확대", "축소", "다섯 조각 분리"]

var main: Node
var game: GameView
var selected := 0

func _initialize() -> void:
	_open.call_deferred()

func _open() -> void:
	main = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var options := RoomSettings.new()
	options.social_lobby = true
	options.solo = true
	options.private_room = true
	options.bot_count = 1
	options.theme_id = 0
	# 동시에 켜 둔 검토 창과 포트가 겹치면 다음 포트를 사용한다.
	for port in range(18741, 18751):
		main.session.host_room("플레이어", port, options)
		if main.session.is_host(): break
	if not main.session.is_host():
		push_error("로컬 펍 시험 방을 열 수 없습니다.")
		quit(1)
		return
	main.set_developer_mode(true)
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		game = main._game
		if game != null and game.can_start_card_test() and game.controller.state.players.size() >= 2: break
		await process_frame
	if game == null or not game.can_start_card_test() or game.controller.state.players.size() < 2:
		push_error("펍의 투척 시험을 준비하지 못했습니다.")
		quit(1)
		return
	root.window_input.connect(_keys)
	_select(1)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _keys(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode >= KEY_0 and event.keycode <= KEY_9:
		root.set_input_as_handled()
		_select(event.keycode - KEY_0)
	elif event.keycode == KEY_R:
		root.set_input_as_handled()
		_select(selected)

func _select(index: int) -> void:
	if not game.can_start_card_test(): return
	selected = index
	game.card_test_selection.clear()
	if not IDS[index].is_empty():
		var opponent: int = game.controller.state.players[1].peer_id
		game.card_test_selection[opponent] = Catalog.type_of(IDS[index])
	game.start_card_test()
	# 시험대가 실제로 사용한 카드의 추첨 결과만 고정한다. 착탄·스냅샷·손패는 정상 경기 코드를 탄다.
	var cards = game.controller.cards
	match index:
		1, 2: cards._cover_side = -1 if index == 1 else 1
		3, 4: cards._seams.x = -1 if index == 3 else 1
		5, 6: cards._seams.y = -1 if index == 5 else 1
		7, 8:
			var data: Dictionary = Catalog.card(Catalog.type_of("board_zoom"))
			var pick := 1 if index == 7 else 0
			for effect in cards.rules.effects:
				if effect.kind == "board_zoom":
					effect.value = float(data.values[pick])
					effect.label = str(data.value_names[pick])
			cards._sync()
	game.controller._publish()
	root.title = "DARTY 펍 투척선  ·  %s  |  1·2 가림   3·4 세로   5·6 가로   7·8 크기   9 분리   0 기본   R 다시" % NAMES[index]
