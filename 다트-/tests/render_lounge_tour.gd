extends SceneTree
## 실제 생성된 테이블·준비 자세·모니터·주크박스와 두 테마를 D3D12로 캡처한다.
## 2026-10-30: 네온 오락실 기계(인형뽑기·가챠·농구)·깨지는 병·새 HUD(킬로그 칩·키 안내)·장난 효과 덮개 장면 추가.
const Rules = preload("res://game/lounge/arcade/arcade_rules.gd")
const BoardChaos = preload("res://game/board/board_chaos.gd")
var main: Node
var game: GameView
var output: String = "res://.godot/lounge_render"

func _initialize() -> void:
	_run.call_deferred()

func capture(label: String, eye: Vector3, target: Vector3, wait: float = 0.25) -> void:
	game.camera.position = eye
	game.camera.look_at(target)
	await create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	assert(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK)

## 카메라를 움직이지 않고 지금 화면을 저장한다(경기 중 HUD 확인용).
func capture_now(label: String) -> void:
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK)

func _run() -> void:
	main = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	var options := RoomSettings.new()
	options.social_lobby = true
	options.solo = true
	options.bot_count = 3
	main.session.host_room("테스터", 17632, options)
	await create_timer(0.8).timeout
	game = main._game
	game.force_seat(1)
	# 봇은 준비 완료 상태다. 실제 리그의 양팔 보간이 끝날 때까지 기다린다.
	await create_timer(0.8).timeout
	assert(game.actors[-1].ready_pose and game.actors[-2].ready_pose)
	game.set_process(false)
	game.set_physics_process(false)
	game.camera.cull_mask = 0xfffff
	game.lounge_hud.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var lounge: Node3D = game.lounge
	await capture("08_arcade_table_ready", Vector3(3.5, 2.7, 1.5), Vector3(0, 1.0, 4.4))
	await capture("09_arcade_jukebox", Vector3(6.7, 1.65, 3.0), Vector3(7.8, 1.0, 1.1))
	await capture("10_arcade_monitor", Vector3(-2.5, 1.65, 3.3), Vector3(-4.35, 1.2, 2))
	await capture("13_arcade_overview", Vector3(-1.5, 3.2, 0.6), Vector3(7.5, 0.8, 5.0))
	# 2026-11-07: 인형뽑기 조종 중(조이스틱 기울기 · 조준 고리 · 남은 초 간판)을 찍는다.
	var claw: Dictionary = lounge._arcade.claw
	claw.merge({"phase": "move", "operator": 1, "until": lounge.now() + 12.0, "x": 0.1, "z": 0.12, "stick_x": 0.6, "stick_z": 0.8}, true)
	await capture("14_arcade_claw", Rules.CLAW_AT + Vector3(-0.9, 1.6, -2.2), Rules.CLAW_AT + Vector3(0, 1.2, 0), 0.5)
	claw.phase = "idle"
	# 2026-11-07: 가챠는 통로(-Z)를 본다 → 오른쪽 앞에서 찍는다(정면 드럼 의자에 펍 손님 NPC 가 서 있어 가린다).
	await capture("15_arcade_gacha", Vector3(7.0, 1.85, 2.3), Vector3(5.78, 1.1, 3.6))
	lounge._arcade.hoop.running = true
	lounge._arcade.hoop.until = lounge.now() + 21.0
	lounge._arcade.hoop.scores = {1: 6, -1: 4}
	await capture("16_arcade_hoop", Vector3(11.0, 1.75, 1.2), Rules.HOOP_RING + Vector3(0, -0.4, 0))
	# 골 직후(그물 출렁 · GOAL!) + 바닥 3점 선이 보이게 뒤에서.
	lounge._arcade.hoop.goal = lounge.now() - 0.2
	await capture("16b_arcade_hoop_goal_3pt", Vector3(11.15, 2.9, 0.45), Vector3(11.15, 0.6, 3.2), 0.05)
	await capture("17_arcade_board_lane", Vector3(2.4, 2.0, -2.4), Vector3(0, 2.0, TableView.BOARD_CENTER.z))
	# 2026-11-07 아수라장 머신: 회전 + 피자 분리 + 셔터를 한꺼번에 건 모양(그림만 — 판정은 test_board_chaos).
	var chaos: Dictionary = BoardChaos.pose(1.5, 1.0, BoardChaos.SPLIT_OPEN, 1.0)
	game.table.board.show_chaos(chaos)
	game.table.machine.show_chaos(chaos, 1.0)
	await capture("17b_machine_chaos", Vector3(0.6, 2.2, -5.0), Vector3(0, 2.0, TableView.BOARD_CENTER.z))
	game.table.board.show_chaos(BoardChaos.rest())
	game.table.machine.show_chaos(BoardChaos.rest(), 1.0)
	await capture("18_arcade_prize", Vector3(-2.2, 1.9, 1.2), Vector3(-6.5, 1.3, 4.6))
	# 깨지는 병: 세게 던져 바에 부딪히는 순간.
	var bottle: int = 1
	lounge._launch(bottle, Vector3(-3.4, 1.4, 3.6), Vector3(-9, 0.6, 0), 1, false)
	await capture("19_bottle_break", Vector3(-2.2, 1.6, 2.2), Vector3(-4.8, 1.0, 3.6), 0.3)
	# 새 HUD: 킬로그 칩 + 키 안내 + 점수판.
	game.lounge_hud.show()
	lounge.feed("broken", game.actors[1], "병 와장창!", game.actors[-1])
	lounge.feed("plush", game.actors[-2], "인형 획득! 던지면 얼굴을 가려요")
	lounge.feed("hoop", game.actors[1], "골! +3  (합계 9)")
	lounge.feed("capsule", game.actors[-3], "캡슐 → 왕머리!", game.actors[1])
	game.controller.add_feed(game.controller.feed_entry("dart", game.controller.state.find_player(1), "트리플 20 · 60점"))
	await capture("20_hud_feed", Vector3(3.5, 2.2, 1.0), Vector3(0, 1.0, 4.4), 0.4)
	lounge._set_effect(1, "ink", 3.0)
	await capture("21_hud_ink", Vector3(3.5, 2.2, 1.0), Vector3(0, 1.0, 4.4), 0.2)
	lounge.effects.clear()
	lounge._set_effect(1, "blind", 1.2)
	await capture("22_hud_plush_blind", Vector3(3.5, 2.2, 1.0), Vector3(0, 1.0, 4.4), 0.2)
	lounge.effects.clear()
	lounge._set_effect(-1, "bighead", 5.0)
	await capture("23_bighead", Vector3(0.0, 2.0, 2.4), Vector3(0, 1.3, 5.65), 0.5)
	game.lounge_hud.hide()
	main.session.room.settings.theme_id = 0
	main.session.room.settings.alcohol = true
	game.lounge.apply_theme()
	await capture("11_pub_table", Vector3(3.5, 2.7, 1.5), Vector3(0, 1.0, 4.4))
	await capture("12_pub_bar", Vector3(-2.8, 1.7, 4.9), Vector3(-5.0, 1.1, 2.7))
	# 경기 시작 후 HUD(점수판 · 단계 카드 · 시간 막대 · 카드 턴 안내).
	main.session.set_ready(true)
	var until: float = Time.get_ticks_msec() / 1000.0 + 8.0
	while Time.get_ticks_msec() / 1000.0 < until and (main._game == null or main._game.controller.state.phase != MatchState.Phase.CARDS):
		await process_frame
	game = main._game
	await create_timer(0.6).timeout
	await capture_now("24_match_cards_hud")
	# 카드 턴은 사람마다 돌아간다(봇은 3.5초씩). 다트 차례가 올 때까지 넉넉히 기다린다.
	while Time.get_ticks_msec() / 1000.0 < until + 30.0 and game.controller.state.phase != MatchState.Phase.AIMING:
		await process_frame
	await capture_now("25_match_aiming_hud")
	main.session.leave_room()
	main.queue_free()
	await process_frame
	print("PASS: actual pub/arcade, arcade machines, bottle break, HUD feed/effects, round table, ready arms, monitor, jukebox screenshots")
	quit()
