extends SubViewportContainer
## 로비(첫 화면) 뒤에 깔리는 실제 3D 펍. 예전 로비는 2D 선으로 그린 과녁뿐이라 "PPT 같다"는 피드백을 받았다.
##
## [장면] 경기와 같은 방(game/table/table.tscn = 펍 + 과녁)을 따로 된 3D 세계(SubViewport)에 띄우고,
## 투척선 뒤에서 어깨 너머로 과녁을 본다. 캐릭터 한 명이 주기적으로 다트를 던져 과녁에 꽂는다(게임 소개 화면).
## [클릭] 화면에서 과녁을 클릭하면(다트 포인터가 empty_target 으로 넘김) 내 다트가 진짜로 날아가 꽂히고 점수가 뜬다.
## 판정은 경기와 같은 BoardScorer 를 쓰지만 로비 장식일 뿐 어떤 기록에도 남지 않는다.

signal scored(text: String, screen: Vector2)

const TABLE_SCENE: PackedScene = preload("res://game/table/table.tscn")
const DART_SCENE: PackedScene = preload("res://game/dart/dart.tscn")
const Sfx = preload("res://art/audio/sfx.gd")

## 카메라: 투척선 뒤 오른쪽 어깨 높이에서 과녁 왼쪽을 본다 → 과녁이 화면 오른쪽 1/3 에 크게 걸린다.
const CAMERA_AT := Vector3(1.0, 2.25, -3.4)
const LOOK_AT := Vector3(-2.0, 2.5, -7.0)
## 던지는 캐릭터(등을 보이며 과녁을 겨눈다).
const THROWER_SEAT: int = 1
const THROWER_AT := Vector3(-1.5, 0.0, -2.5)
## 소개용 다트 간격(초)과 과녁에 남는 최대 개수.
const ATTRACT_EVERY: float = 3.2
const MAX_DARTS: int = 3

var _viewport: SubViewport
var _camera: Camera3D
var _table: TableView
var _darts_root: Node3D
var _thrower: Node3D
var _rig: CharacterRig
var _next_attract: float = 1.4
var _time: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.gui_disable_input = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	add_child(_viewport)
	_table = TABLE_SCENE.instantiate() as TableView
	_viewport.add_child(_table)
	_darts_root = Node3D.new()
	_viewport.add_child(_darts_root)
	_camera = Camera3D.new()
	_camera.fov = 52.0
	_viewport.add_child(_camera)
	_camera.position = CAMERA_AT
	_camera.look_at(LOOK_AT)
	_thrower = PlayerLook.character(THROWER_SEAT)
	_viewport.add_child(_thrower)
	_thrower.position = THROWER_AT
	# 던지는 사람은 카메라 뒤쪽에 서 있다 → 다트만 화면 왼쪽에서 날아 들어온다(얼굴이 카메라를 보는 어색한 구도 방지).
	# 캐릭터 정면은 +Z → 과녁 쪽을 보도록 돌린다.
	var to_board := Vector3(0.0, 0.0, -7.2) - THROWER_AT
	_thrower.rotation.y = atan2(to_board.x, to_board.z)
	_rig = CharacterRig.new(_thrower, 0.4)
	_rng.seed = 2026


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_time += delta
	# 손으로 든 카메라처럼 아주 천천히 흔들린다.
	_camera.position = CAMERA_AT + Vector3(sin(_time * 0.31) * 0.06, sin(_time * 0.47) * 0.03, 0.0)
	_camera.look_at(LOOK_AT + Vector3(sin(_time * 0.23) * 0.05, 0.0, 0.0))
	var aiming: bool = _next_attract - _time < 1.1
	_rig.animate(delta, 0.0, CharacterRig.Posture.STAND, false, 0.12, aiming)
	if _time >= _next_attract:
		_next_attract = _time + ATTRACT_EVERY + _rng.randf_range(-0.4, 0.6)
		_rig.play_throw()
		var hand := _thrower.global_position + Vector3(0.0, 1.72, 0.0) + _thrower.global_basis.z * 0.35
		var aim := Vector2(_rng.randf_range(-0.55, 0.55), _rng.randf_range(-0.55, 0.55))
		_throw(hand, aim, 0.5)


## 과녁 한가운데가 화면 어디에 보이는지(시험·안내 표시용).
func board_screen_point() -> Vector2:
	if _viewport.size.x == 0:
		return Vector2.ZERO
	var scale_ratio := Vector2(_viewport.size) / size
	return _camera.unproject_position(_table.board.global_position) / scale_ratio


## 화면 좌표가 과녁 위면 내 다트를 던지고 true. 다트 포인터가 빈 곳 클릭을 넘길 때 부른다.
func throw_at(screen: Vector2) -> bool:
	if not is_visible_in_tree() or _viewport.size.x == 0:
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
		if not is_inside_tree():
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
