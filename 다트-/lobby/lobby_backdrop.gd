extends SubViewportContainer
## 로비(첫 화면) 뒤에 깔리는 실제 3D 펍. 예전 로비는 2D 선으로 그린 과녁뿐이라 "PPT 같다"는 피드백을 받았다.
##
## [장면] 경기와 같은 방(game/table/table.tscn = 펍 + 과녁)을 따로 된 3D 세계(SubViewport)에 띄우고,
## 투척선 뒤에서 어깨 너머로 과녁을 본다. 캐릭터 한 명이 주기적으로 다트를 던져 과녁에 꽂는다(게임 소개 화면).
## [클릭] 화면에서 과녁을 클릭하면(다트 포인터가 empty_target 으로 넘김) 내 다트가 진짜로 날아가 꽂히고 점수가 뜬다.
## 판정은 경기와 같은 BoardScorer 를 쓰지만 로비 장식일 뿐 어떤 기록에도 남지 않는다.

signal scored(text: String, screen: Vector2)
## 펍을 다 지었을 때(그 전에는 검은 화면이고 과녁 클릭도 안 받는다).
signal built
## 펍 파일을 다 읽었을 때(짓기 직전). 다른 무거운 읽기는 이때부터 시작하면 펍 읽기를 늦추지 않는다(app/main.gd).
signal loaded

## [2026-11-17 밤 "실행할 때 렉"] 펍(table.tscn → art/pub/pub_game.tscn)은 읽는 데 2.2~2.4초 걸린다.
## 예전엔 preload 라 게임 창이 뜨기 전에 그만큼 더 기다렸다(창이 약 7초 만에 떴다) → 이제 뒤에서(백그라운드 스레드) 읽고,
## 다 읽히면 그때 짓고 검은 화면에서 서서히 밝힌다(창은 약 2.8초, 펍은 그 뒤 1.4~2초).
## 짓기 0.2초 + 처음 그리기 0.5~0.7초는 그때 한 번 멈춘다(검은 채로 넘긴다). 메시 묶기는 여러 프레임에 나눈다(spread_batching).
const TABLE_PATH := "res://game/table/table.tscn"
const DART_SCENE: PackedScene = preload("res://game/dart/dart.tscn")
## 펍이 나타나며 밝아지는 시간(초).
const FADE_IN: float = 0.6
const Sfx = preload("res://art/audio/sfx.gd")

## 카메라: 투척선 뒤 오른쪽 어깨 높이에서 과녁 왼쪽을 본다 → 과녁이 화면 오른쪽 1/3 에 크게 걸린다.
const CAMERA_AT := Vector3(1.0, 2.25, -3.4)
## 보는 곳은 과녁 면 위의 한 점으로 둔다(과녁이 옮겨 가면 구도가 따라온다).
const LOOK_OFFSET := Vector3(-2.0, -0.4, 0.2)
## 구도 기준: 과녁이 3.8m 앞에 있을 때 시야각 52°. 2026-11-02 과녁이 7.2m 뒤로 가면서 멀어졌으므로
## "거리 × tan(시야각/2)" 를 이 값과 같게 두어 과녁이 화면에서 차지하는 크기를 지킨다(멀리서 당겨 찍기).
const FRAME_DISTANCE: float = 3.8
const FRAME_FOV: float = 52.0
## 던지는 캐릭터(등을 보이며 과녁을 겨눈다).
const THROWER_SEAT: int = 1
const THROWER_AT := Vector3(-1.5, 0.0, -2.5)
## 던지는 캐릭터 기준 다트가 손을 떠나는 자리(Dart_Throw 39프레임의 오른손).
const THROW_HAND := Vector3(0.18, 1.43, -0.5)
## 소개용 다트 간격(초)과 과녁에 남는 최대 개수.
const ATTRACT_EVERY: float = 3.2
const MAX_DARTS: int = 3
## [2026-11-23 최적화] 경기 중에도 이 펍이 노드 약 2,800개·메시 2,200개로 살아 있었다(그리기만 멈춰 있었다).
## 타이틀이 이만큼 가려져 있으면 놓아주고, 돌아오면 붙잡아 둔 장면으로 다시 짓는다(파일은 다시 읽지 않는다).
## 계정 화면처럼 잠깐 가려질 때 짓고 놓기를 반복하지 않도록 둔 여유(초)다.
const RELEASE_AFTER: float = 1.0

const Preferences = preload("res://ui/player_preferences.gd")
var _last_quality := -1
var _viewport: SubViewport
var _camera: Camera3D
var _table: TableView
var _darts_root: Node3D
var _thrower: Node3D
var _rig: CharacterMotion
var _next_attract: float = 1.4
## 밝히기 시작까지 남은 프레임(0 = 시작함 · −1 = 아직 안 지음).
var _fade_frames: int = -1
var _time: float = 0.0
var _rng := RandomNumberGenerator.new()
## 다시 지을 때 펍 파일을 또 읽지 않도록 붙잡아 둔 장면.
var _packed: PackedScene
## 타이틀이 가려져 있던 시간(초). RELEASE_AFTER 를 넘으면 놓아준다.
var _hidden_seconds: float = 0.0
## 밝히기 tween — 놓아줄 때 멈춰야 검게 둔 화면을 다시 밝히지 않는다.
var _fade: Tween


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport = _make_viewport()
	# 펍이 오기 전 빈 3D 화면은 회색이다 → 검게 덮어 두었다가 지은 뒤 밝힌다.
	modulate = Color.BLACK
	# 화면 없는 실행(시험·전용 서버)은 바로 읽어 짓는다 — 엔진의 가짜 그리기 장치는 여러 스레드 읽기에 깨진다(app/asset_warmup.gd start).
	if DisplayServer.get_name() == "headless":
		var table_scene := load(TABLE_PATH) as PackedScene
		loaded.emit()
		_build(table_scene)
		return
	# 하위 자원도 여러 스레드로 나눠 읽는다(한 스레드 2.5초 → 1.1초).
	if ResourceLoader.load_threaded_request(TABLE_PATH, "", true) != OK:
		_build(load(TABLE_PATH) as PackedScene)


## 펍을 담을 따로 된 3D 세계. 놓아줄 때 통째로 지우므로 다시 지을 때 새로 만든다.
func _make_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.gui_disable_input = true
	Preferences.apply_3d_quality(viewport)
	_last_quality = Preferences.quality
	add_child(viewport)
	return viewport


## 뒤에서 읽은 펍으로 방·카메라·던지는 캐릭터를 짓는다.
func _build(table_scene: PackedScene) -> void:
	_packed = table_scene
	_table = table_scene.instantiate() as TableView
	# 메시 묶기를 여러 프레임에 나눠 나타나는 순간의 멈춤을 줄인다(한 번에 묶으면 0.45초).
	_table.spread_batching = true
	_viewport.add_child(_table)
	_darts_root = Node3D.new()
	_viewport.add_child(_darts_root)
	_camera = Camera3D.new()
	_camera.fov = _framed_fov()
	_viewport.add_child(_camera)
	_camera.position = CAMERA_AT
	_camera.look_at(_look_at())
	_thrower = PlayerLook.character(THROWER_SEAT)
	_viewport.add_child(_thrower)
	_thrower.position = THROWER_AT
	# 던지는 사람은 카메라 뒤쪽에 서 있다 → 다트만 화면 왼쪽에서 날아 들어온다(얼굴이 카메라를 보는 어색한 구도 방지).
	# 캐릭터 정면은 -Z → 과녁 쪽을 보도록 돌린다.
	var to_board := Vector3(0.0, 0.0, TableView.BOARD_CENTER.z) - THROWER_AT
	_thrower.rotation.y = atan2(-to_board.x, -to_board.z)
	_rig = CharacterMotion.new(_thrower, 0.4)
	_rng.seed = 2026
	# 펍을 처음 그리는 프레임은 재질·셰이더 준비로 0.5~0.7초 걸린다(예전엔 시작 화면 뒤에 숨어 있던 시간).
	# 검은 채로 그 프레임을 넘긴 다음 밝힌다(_process) — 멈춘 사이에 밝히기가 다 지나가 펍이 툭 튀어나오지 않게.
	_fade_frames = 2
	built.emit()


## 펍을 다 지었는지(시험·화면 찍기에서 기다릴 때 쓴다).
func is_built() -> bool:
	return _table != null


## 가려진 펍을 놓아준다. 3D 세계를 통째로 지우므로 방·소품·조명·캐릭터·다트가 함께 빠진다.
## 타이틀로 돌아오면 _process 가 붙잡아 둔 장면으로 다시 짓고 검은 화면에서 다시 밝힌다.
func _release() -> void:
	if _fade != null:
		_fade.kill()
		_fade = null
	_viewport.queue_free()
	_viewport = null
	_table = null
	_darts_root = null
	_camera = null
	_thrower = null
	_rig = null
	_fade_frames = -1
	_time = 0.0
	_next_attract = 1.4
	modulate = Color.BLACK


## 뒤에서 읽던 펍이 다 왔으면 짓는다. 아직이면 false.
func _try_build() -> bool:
	var status := ResourceLoader.load_threaded_get_status(TABLE_PATH)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return false
	var table_scene: PackedScene = null
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		table_scene = ResourceLoader.load_threaded_get(TABLE_PATH) as PackedScene
	if table_scene == null:
		table_scene = load(TABLE_PATH) as PackedScene
	loaded.emit()
	_build(table_scene)
	return true


func _process(delta: float) -> void:
	# 타이틀이 가려진 동안(경기 중)에는 짓지 않는다 — 짓는 순간의 멈춤이 경기 중에 오지 않게.
	if not is_visible_in_tree():
		if _table == null:
			return
		_hidden_seconds += delta
		if _hidden_seconds >= RELEASE_AFTER:
			_release()
		else:
			_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	_hidden_seconds = 0.0
	# 지은 다음다음 프레임에 밝히기 시작한다(첫 그리기 멈춤이 지난 뒤 — _build).
	if _fade_frames > 0:
		_fade_frames -= 1
		if _fade_frames == 0:
			_fade = create_tween()
			_fade.tween_property(self, "modulate", Color.WHITE, FADE_IN)
	if _table == null:
		if _packed != null:
			# 타이틀로 돌아왔다 — 붙잡아 둔 장면으로 다시 짓는다(파일 읽기 없이 약 0.2초).
			_viewport = _make_viewport()
			_build(_packed)
		elif not _try_build():
			return
	if _last_quality != Preferences.quality:
		Preferences.apply_3d_quality(_viewport)
		_last_quality = Preferences.quality
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_time += delta
	# 손으로 든 카메라처럼 아주 천천히 흔들린다.
	_camera.position = CAMERA_AT + Vector3(sin(_time * 0.31) * 0.06, sin(_time * 0.47) * 0.03, 0.0)
	_camera.look_at(_look_at() + Vector3(sin(_time * 0.23) * 0.05, 0.0, 0.0))
	var aiming: bool = _next_attract - _time < 1.1
	_rig.animate(delta, 0.0, CharacterMotion.Posture.STAND, false, 0.12, aiming)
	if _time >= _next_attract:
		_next_attract = _time + ATTRACT_EVERY + _rng.randf_range(-0.4, 0.6)
		_rig.play_throw()
		var hand := _thrower.to_global(THROW_HAND)
		var aim := Vector2(_rng.randf_range(-0.55, 0.55), _rng.randf_range(-0.55, 0.55))
		_throw(hand, aim, 0.5)


## 카메라가 보는 곳(과녁 면 위의 한 점).
static func _look_at() -> Vector3:
	return TableView.BOARD_CENTER + LOOK_OFFSET


## 과녁이 멀어진 만큼 좁힌 시야각.
static func _framed_fov() -> float:
	var distance: float = maxf(CAMERA_AT.z - TableView.BOARD_CENTER.z, 0.5)
	return rad_to_deg(atan(tan(deg_to_rad(FRAME_FOV) / 2.0) * FRAME_DISTANCE / distance)) * 2.0


## 과녁 한가운데가 화면 어디에 보이는지(시험·안내 표시용).
func board_screen_point() -> Vector2:
	if _table == null or _viewport.size.x == 0:
		return Vector2.ZERO
	var scale_ratio := Vector2(_viewport.size) / size
	return _camera.unproject_position(_table.board.global_position) / scale_ratio


## 화면 좌표가 과녁 위면 내 다트를 던지고 true. 다트 포인터가 빈 곳 클릭을 넘길 때 부른다.
func throw_at(screen: Vector2) -> bool:
	if _table == null or not is_visible_in_tree() or _viewport.size.x == 0:
		return false
	var scale_ratio := Vector2(_viewport.size) / size
	var point := screen * scale_ratio
	var origin := _camera.project_ray_origin(point)
	var direction := _camera.project_ray_normal(point)
	var board: BoardView = _table.board
	var normal: Vector3 = board.global_basis.z.normalized()
	var divisor: float = normal.dot(direction)
	if absf(divisor) < 0.001:
		return false
	var distance: float = normal.dot(board.global_position - origin) / divisor
	var local: Vector3 = board.to_local(origin + direction * distance)
	var aim := Vector2(local.x, local.y) / BoardLayout.RADIUS
	if distance <= 0.0 or aim.length() > 1.25:
		return false
	# 내 손 = 화면 오른쪽 아래(1인칭).
	var hand := _camera.global_position + _camera.global_basis * Vector3(0.28, -0.3, -0.4)
	_throw(hand, aim, 0.38, screen)
	return true


func _throw(from: Vector3, aim: Vector2, duration: float, screen := Vector2.INF) -> void:
	if _darts_root.get_child_count() >= MAX_DARTS:
		for child in _darts_root.get_children():
			child.queue_free()
	var board: BoardView = _table.board
	var target: Vector3 = board.to_global(Vector3(aim.x, aim.y, 0.0) * BoardLayout.RADIUS)
	var dart := DART_SCENE.instantiate() as DartView
	_darts_root.add_child(dart)
	dart.paint(PlayerLook.COLORS[THROWER_SEAT] if screen == Vector2.INF else PlayerLook.COLORS[0])
	dart.fly(from, target, duration)
	Sfx.play(self, "whoosh", -14.0)
	get_tree().create_timer(duration).timeout.connect(func() -> void:
		# 날아가는 중에 펍을 놓아주면(_release) 과녁이 없다.
		if not is_inside_tree() or _table == null:
			return
		Sfx.play(self, "thunk", -9.0 if screen == Vector2.INF else -3.0)
		if screen != Vector2.INF:
			scored.emit(describe(aim, board.layout), screen))


## 맞힌 자리를 말로 바꾼다(불·트리플·더블·숫자). 정규화 좌표 = 과녁 반지름 1.
static func describe(aim: Vector2, layout: BoardLayout) -> String:
	var points := BoardScorer.score(aim, layout)
	var radius := aim.length()
	if points == 0:
		return "빗나감!"
	if radius <= BoardLayout.INNER_BULL:
		return "불스아이! 50"
	if radius <= BoardLayout.OUTER_BULL:
		return "불! 25"
	var number: int = layout.numbers[BoardLayout.sector_at(aim)]
	if radius >= BoardLayout.DOUBLE_INNER:
		return "더블 %d · %d점" % [number, points]
	if points == number * 3:
		return "트리플 %d · %d점" % [number, points]
	return "%d점" % points
