extends SceneTree
## 다트 충전 확대(2026-11-28): 당기기 시작하면 3% 확대에서 출발해 꽉 당기면 10%, 놓으면 원래 화각으로 돌아온다.
## '움직임 줄이기' 설정이면 확대하지 않는다. 확대율 = tan(기준 화각/2) / tan(지금 화각/2) - 1.
##   godot --headless --path . --script res://tests/test_charge_zoom.gd
## 헤드리스에서는 마우스를 잡을 수 없어 충전이 매 프레임 취소된다 → 한 프레임 안에서 GameView._apply_charge_zoom 을 직접 돌린다.
const Preferences = preload("res://ui/player_preferences.gd")
## 1초 동안 60번(목표를 따라가기에 넉넉하다 — CHARGE_ZOOM_RATE 12 면 0.25초에 95%).
const STEPS: int = 60
const STEP: float = 1.0 / 60.0

var main: Node
var game: GameView


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	if not value:
		printerr("FAIL: ", message)
		quit(1)
		assert(value, message)


func _run() -> void:
	await _start()
	var motion_before: bool = Preferences.reduced_motion
	Preferences.reduced_motion = false
	check(is_equal_approx(game.camera.fov, game._view_fov), "충전 전에는 기준 화각")
	check(is_equal_approx(_settle(true, 0.0), GameView.CHARGE_ZOOM_START), "당기기 시작 = 3%% 확대: %.4f" % _zoom())
	check(is_equal_approx(_settle(true, 0.5), lerpf(GameView.CHARGE_ZOOM_START, GameView.CHARGE_ZOOM_FULL, 0.5)), "반쯤 당김 = 6.5%% 확대: %.4f" % _zoom())
	check(is_equal_approx(_settle(true, 1.0), GameView.CHARGE_ZOOM_FULL), "꽉 당김 = 10%% 확대: %.4f" % _zoom())
	check(_settle(false, 0.0) == 0.0 and game.camera.fov == game._view_fov, "놓으면 원래 화각으로 돌아온다: %.4f" % _zoom())
	# 들어가는 중간: 한 프레임 만에 3% 로 툭 튀지 않는다(부드러운 줌인).
	game.throw_input.charging = true
	game.throw_input.timing = 0.0
	game.camera.fov = game._view_fov
	game._apply_charge_zoom(STEP)
	check(_zoom() > 0.0 and _zoom() < GameView.CHARGE_ZOOM_START * 0.5, "첫 프레임은 3%% 의 절반도 안 된다: %.4f" % _zoom())
	_settle(false, 0.0)
	Preferences.reduced_motion = true
	check(_settle(true, 1.0) == 0.0, "움직임 줄이기 설정이면 확대하지 않는다: %.4f" % _zoom())
	Preferences.reduced_motion = motion_before
	main.queue_free()
	await process_frame
	print("PASS: charge zoom — 3% at start, 10% at full charge, back to base on release, none with reduced motion")
	quit()


## 충전 상태를 정하고 1초 동안 확대를 따라가게 한 뒤 지금 확대율을 돌려준다(GameView._process 처럼 매번 기준 화각에서 시작).
func _settle(charging: bool, timing: float) -> float:
	game.throw_input.charging = charging
	game.throw_input.timing = timing
	for i in range(STEPS):
		game.camera.fov = game._view_fov
		game._apply_charge_zoom(STEP)
	# 목표에 거의 닿았으면 목표값으로 본다(지수 감쇠라 정확히 닿지는 않는다).
	return snappedf(_zoom(), 0.0001)


func _zoom() -> float:
	return tan(deg_to_rad(game._view_fov) * 0.5) / tan(deg_to_rad(game.camera.fov) * 0.5) - 1.0


func _start() -> void:
	main = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	var options := RoomSettings.new()
	options.social_lobby = true
	options.solo = true
	options.bot_count = 1
	main.session.host_room("테스터", 17951, options)
	var until: float = Time.get_ticks_msec() / 1000.0 + 10.0
	while Time.get_ticks_msec() / 1000.0 < until and main._game == null:
		await process_frame
	game = main._game
	check(game != null, "경기 화면이 열리지 않았다")
	await process_frame
	await process_frame
