extends SceneTree
## 꾸미기 방 참조가 남아 조작이 잠기지 않는지(2026-11-26 사용자 "앉아서 엔터 누르는 순간
## 다트 던지기 빼고 아무 키도 안 먹어"). GameView._unhandled_input 은 방이 열려 있으면 통째로 쉰다 —
## 시점·이동·Space·F·Enter 가 모두 그 길로 오고, 다트 던지기만 _input 으로 따로 온다.
## GDScript 에서 지워진 노드는 null 이 아니므로, 방이 닫히는 신호 없이 사라지면 참조가 남아 영영 잠겼다.
var main: Node
var game: GameView


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	main = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	var options := RoomSettings.new()
	options.social_lobby = true
	options.solo = true
	options.capacity = 2
	options.bot_count = 1
	main.session.host_room("테스터", 17677, options)
	await create_timer(0.8).timeout
	game = main._game
	var local := game.actors[1] as PlayerView
	local.seated = false

	assert(not game.wardrobe_open(), "처음에는 닫혀 있다")
	game.open_wardrobe()
	assert(game.wardrobe_open(), "F 로 들어가면 열린다")

	# closed 신호 없이 노드만 사라져도(페이드가 끝나지 못한 경우) 참조가 남으면 안 된다.
	var room: CanvasLayer = game.wardrobe
	game.remove_child(room)
	room.free()
	assert(not game.wardrobe_open(), "닫힘 신호 없이 사라져도 조작이 잠기지 않는다")

	# 다시 열 수 있어야 한다 — 남은 참조가 있으면 open_wardrobe 가 그냥 돌아간다.
	game.open_wardrobe()
	assert(game.wardrobe_open(), "다시 들어갈 수 있다")

	# 트리에서 빠지기만 해도 참조를 놓는다.
	var again: CanvasLayer = game.wardrobe
	game.remove_child(again)
	assert(not game.wardrobe_open(), "트리에서 빠지면 바로 참조를 놓는다")
	again.free()

	main.queue_free()
	await process_frame
	print("PASS: a freed or detached wardrobe never leaves the game with all keyboard and look input disabled")
	quit()
