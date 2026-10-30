extends Control
## 마우스 포인터 = 진짜 3D 다트(2026-10-30 개편: 예전 2D 선 그림은 "스티커 붙이기" 같았다).
##
## [보이는 방식] 화면 전체를 덮는 투명 SubViewport 에 다트 모델(game/dart/dart.tscn)을 그린다.
## 포인터 다트는 화면에서 가까운 깊이(CURSOR_DEPTH)에 있고, 클릭하면 화면 안쪽 먼 깊이(WALL_DEPTH)로
## 날아가 꽂힌다 → 원근 때문에 실제로 멀어지며 작아지고, 꽂힌 뒤에는 깃이 부르르 떤다.
##
## [버튼] 일반 버튼(토글·스위치 포함)을 클릭하면 클릭을 여기서 가로채고, 다트가 꽂히는 순간(FLIGHT 초 뒤)
## 버튼을 누른다 → "다트를 던져서 고른다". 펼침 목록·입력칸·숫자칸은 기다리지 않고 바로 동작한다.
## 키보드(Enter/Space)로 누르는 버튼은 그대로다.
##
## [빈 곳] 버튼이 아닌 곳에 던지면 다트가 그 자리에 꽂혀 EMPTY_HIDE 초 동안 포인터가 사라진다(요청: 1~2초).
## 로비처럼 뒤에 3D 과녁이 있는 화면은 empty_target 으로 그 클릭을 넘겨받아 진짜 과녁에 던진다.

const DART_SCENE: PackedScene = preload("res://game/dart/dart.tscn")
const Sfx = preload("res://art/audio/sfx.gd")
const Style = preload("res://ui/lounge_style.gd")

## 다트가 손을 떠나 꽂히기까지(초). 버튼 동작은 이 시간 뒤에 실행된다.
const FLIGHT: float = 0.2
## 던지기 전에 살짝 뒤로 빼는 시간(초). 비행 시간 안에 포함된다.
const WIND_UP: float = 0.05
const EMPTY_HIDE: float = 1.5
const BUTTON_HIDE: float = 0.35
const STUCK_LIFE_BUTTON: float = 0.75
## 오버레이 카메라 기준 깊이(m). 포인터는 가깝고 꽂히는 면은 멀다.
const CURSOR_DEPTH: float = 1.1
const WALL_DEPTH: float = 2.3
const DART_SCALE: float = 0.7
## 포인터 다트 몸통 방향(촉 → 꼬리). 꼬리가 오른쪽 아래·화면 쪽을 향해 옆모습이 보인다.
const CURSOR_TAIL := Vector3(0.62, -0.5, 0.6)
## 꽂힌 다트 꼬리 방향. 거의 화면을 향해 X자 깃이 보이고 몸통이 살짝 보인다.
const STUCK_TAIL := Vector3(0.5, -0.4, 1.0)

## 빈 곳 클릭을 넘겨받을 함수(화면 좌표 → 받았으면 true). 비워 두면 포인터가 직접 꽂는다.
var empty_target: Callable
var dart_color: Color = Style.PINK

## 여러 화면(로비 위 설정 창 등)이 겹쳐도 맨 위 포인터 하나만 보이고 동작한다.
static var _stack: Array = []

var _viewport: SubViewport
var _camera: Camera3D
var _cursor: Node3D
var _flights: Array[Dictionary] = []
var _stuck: Array[Dictionary] = []
var _bursts: Array[Dictionary] = []
var _hidden_left: float = 0.0
var _swallow_release: bool = false
var _juice: Dictionary = {}
var _sway := Vector2.ZERO
var _last_mouse := Vector2.ZERO
var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(container)
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.gui_disable_input = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	container.add_child(_viewport)
	_camera = Camera3D.new()
	_camera.fov = 40.0
	_camera.near = 0.05
	_viewport.add_child(_camera)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(deg_to_rad(-50), deg_to_rad(35), 0)
	light.light_energy = 1.4
	_viewport.add_child(light)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("fff1dc")
	environment.ambient_light_energy = 0.75
	world.environment = environment
	_viewport.add_child(world)
	_cursor = _make_dart()


func _enter_tree() -> void:
	_stack.append(self)


func _exit_tree() -> void:
	_stack.erase(self)
	for control: Control in _juice:
		if is_instance_valid(control):
			control.scale = Vector2.ONE
			control.rotation = 0.0
	if Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## 맨 위 포인터이고, 시점 조작(마우스 잡기) 중이 아니며, 펼침 목록이 열려 있지 않을 때만 동작한다.
func is_active() -> bool:
	return is_visible_in_tree() and not _stack.is_empty() and _stack.back() == self \
		and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and get_viewport().get_embedded_subwindows().is_empty()


func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not event.pressed:
		if _swallow_release:
			_swallow_release = false
			get_viewport().set_input_as_handled()
		return
	if not is_active() or _hidden_left > 0.0 and not _flights.is_empty():
		return
	var point := get_local_mouse_position()
	var hovered := get_viewport().gui_get_hovered_control()
	var button := _throwable_button(hovered)
	if button != null:
		# 버튼은 다트가 꽂히는 순간 누른다. 지금 클릭은 여기서 끝낸다.
		get_viewport().set_input_as_handled()
		_swallow_release = true
		_launch(point, button, BUTTON_HIDE)
	elif hovered == null or hovered == self or _is_background(hovered):
		if empty_target.is_valid() and bool(empty_target.call(point)):
			_hidden_left = EMPTY_HIDE * 0.8
			return
		_launch(point, null, EMPTY_HIDE)
	else:
		# 입력칸·펼침 목록·숫자칸: 기본 동작은 바로 하고 다트는 짧게 꽂힌다.
		_launch(point, null, BUTTON_HIDE, 0.6)


func _process(delta: float) -> void:
	_time += delta
	var active := is_active()
	if active:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	elif Input.mouse_mode == Input.MOUSE_MODE_HIDDEN and (_stack.is_empty() or _stack.back() == self):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active or not _flights.is_empty() or not _stuck.is_empty() \
		else SubViewport.UPDATE_DISABLED
	_hidden_left = maxf(0.0, _hidden_left - delta)
	var mouse := get_local_mouse_position()
	# 마우스를 빨리 움직이면 꼬리가 뒤처지며 흔들린다(관성 느낌).
	var velocity := (mouse - _last_mouse) / maxf(delta, 0.001)
	_last_mouse = mouse
	_sway = _sway.lerp((velocity * 0.0009).limit_length(0.6), minf(1.0, delta * 10.0))
	var hovered := get_viewport().gui_get_hovered_control() if active else null
	var aiming := _throwable_button(hovered) != null or hovered is LineEdit or hovered is OptionButton
	_cursor.visible = active and _hidden_left <= 0.0 and size.x > 0.0
	if _cursor.visible:
		var tail := CURSOR_TAIL + Vector3(_sway.x, -_sway.y, 0.0) * 0.6
		if aiming:
			tail = tail.lerp(Vector3(0.35, -0.3, 1.0), 0.35)
		_place(_cursor, _at_depth(mouse, CURSOR_DEPTH - (0.08 if aiming else 0.0)), tail, 0.6 + sin(_time * 2.0) * 0.08)
	_update_juice(delta, hovered if active else null)
	_update_flights(delta)
	_update_stuck(delta)
	for burst in _bursts:
		burst.age += delta
	_bursts = _bursts.filter(func(burst: Dictionary) -> bool: return burst.age < 0.45)
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	# 바닥 그림자(화면 위 UI 에 드리운다): 포인터는 오른쪽 아래, 날아가는 다트는 과녁점으로 모인다.
	if _cursor.visible:
		var mouse := get_local_mouse_position()
		draw_circle(mouse + Vector2(26, 30), 9.0, Color(Style.INK, 0.28))
	for flight in _flights:
		var ratio: float = clampf(flight.age / FLIGHT, 0.0, 1.0)
		draw_circle(flight.target + Vector2(26, 30) * (1.0 - ratio), lerpf(9.0, 4.0, ratio), Color(Style.INK, 0.25 * ratio + 0.1))
	for stuck in _stuck:
		var fade: float = clampf(1.0 - (stuck.age - stuck.life + 0.3) / 0.3, 0.0, 1.0)
		# 꽂힌 자리 구멍(작은 금 + 점).
		draw_circle(stuck.target, 4.0, Color(Style.INK, 0.55 * fade))
		for index in range(4):
			var angle: float = TAU * index / 4.0 + 0.4
			draw_line(stuck.target + Vector2.from_angle(angle) * 5.0, stuck.target + Vector2.from_angle(angle) * 11.0, Color(Style.INK, 0.35 * fade), 2.0, true)
	for burst in _bursts:
		var t: float = burst.age / 0.45
		var color: Color = burst.color
		color.a = 1.0 - t
		draw_arc(burst.at, lerpf(8.0, 46.0, ease(t, 0.4)), 0.0, TAU, 32, color, lerpf(6.0, 1.0, t), true)
		for index in range(8):
			var angle: float = TAU * index / 8.0 + 0.2
			var start: Vector2 = burst.at + Vector2.from_angle(angle) * lerpf(10.0, 40.0, ease(t, 0.3))
			draw_line(start, start + Vector2.from_angle(angle) * lerpf(14.0, 2.0, t), color, 3.0, true)


## 다트 한 발을 띄운다. button 이 있으면 꽂히는 순간 그 버튼을 누른다.
func _launch(target: Vector2, button: BaseButton, hide_seconds: float, life_scale: float = 1.0) -> void:
	_hidden_left = maxf(_hidden_left, FLIGHT + hide_seconds)
	var dart := _make_dart()
	_flights.append({"node": dart, "target": target, "age": 0.0, "button": button,
		"start": _at_depth(target, CURSOR_DEPTH), "tail": CURSOR_TAIL,
		"life": (STUCK_LIFE_BUTTON if button != null else hide_seconds) * life_scale})
	Sfx.play(self, "whoosh", -10.0, randf_range(0.95, 1.1))


func _update_flights(delta: float) -> void:
	for flight in _flights.duplicate():
		flight.age += delta
		var dart: Node3D = flight.node
		var end := _at_depth(flight.target, WALL_DEPTH)
		if flight.age < WIND_UP:
			# 뒤로 살짝 당겼다가(손목 스냅) 던진다.
			var pull: float = flight.age / WIND_UP
			_place(dart, flight.start + Vector3(0.05, -0.04, 0.18) * pull, CURSOR_TAIL.lerp(Vector3(0.5, -0.6, 0.9), pull), 0.6)
			continue
		var ratio: float = clampf((flight.age - WIND_UP) / (FLIGHT - WIND_UP), 0.0, 1.0)
		var eased: float = ease(ratio, 0.6)
		var start: Vector3 = flight.start
		var point: Vector3 = (start + Vector3(0.05, -0.04, 0.18)).lerp(end, eased)
		# 살짝 위로 솟았다가 떨어지는 호.
		point.y += sin(ratio * PI) * 0.12
		var tail := Vector3(0.5, -0.6, 0.9).lerp(STUCK_TAIL, eased)
		_place(dart, point, tail, 0.6 + ratio * TAU * 1.5)
		if ratio >= 1.0:
			_flights.erase(flight)
			_impact(flight, end)


func _impact(flight: Dictionary, at: Vector3) -> void:
	var button: BaseButton = flight.button
	var color: Color = Style.GOLD
	if button != null and is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled:
		_juice_for(button).punch = 1.0
		color = Style.CREAM
		if button.toggle_mode:
			button.button_pressed = true if button.button_group != null else not button.button_pressed
		button.pressed.emit()
	_stuck.append({"node": flight.node, "target": flight.target, "at": at, "age": 0.0, "life": flight.life,
		"button": button, "fall": Vector3.ZERO})
	_bursts.append({"at": flight.target, "age": 0.0, "color": color})
	Sfx.play(self, "thunk", -4.0, randf_range(0.9, 1.08))


func _update_stuck(delta: float) -> void:
	for stuck in _stuck.duplicate():
		stuck.age += delta
		var dart: Node3D = stuck.node
		var button = stuck.button
		# 버튼이 사라지면(화면 전환) 꽂혀 있던 다트가 툭 떨어진다.
		var detached: bool = button != null and (not is_instance_valid(button) or not (button as Control).is_visible_in_tree())
		if detached or stuck.age > stuck.life:
			stuck.fall += Vector3.DOWN * 9.0 * delta
			stuck.at += stuck.fall * delta
			_place(dart, stuck.at, STUCK_TAIL.lerp(Vector3(0.9, 0.4, 0.4), minf(1.0, stuck.fall.length() * 0.3)), 0.6)
			if stuck.at.y < -2.5 or stuck.age > stuck.life + 0.8:
				dart.queue_free()
				_stuck.erase(stuck)
			continue
		# 꽂힌 직후 부르르 떠는 깃: 줄어드는 사인 흔들림.
		var wobble: float = sin(stuck.age * 46.0) * exp(-stuck.age * 6.0) * 0.18
		_place(dart, stuck.at, STUCK_TAIL + Vector3(wobble, wobble * 0.6, 0.0), 0.6)


## 버튼 반응: 올리면 살짝 커지고 기울고, 다트가 꽂히면 움찔하며 흔들린다.
func _update_juice(delta: float, hovered: Control) -> void:
	var hovered_button := _throwable_button(hovered)
	if hovered_button != null:
		_juice_for(hovered_button)
	# 화면 전환으로 버튼이 이미 지워졌을 수 있다 → 타입 붙인 반복 변수에 넣기 전에 먼저 확인한다.
	for key in _juice.keys():
		if not is_instance_valid(key):
			_juice.erase(key)
			continue
		var control: Control = key
		var state: Dictionary = _juice[control]
		var target: float = 1.0 if control == hovered_button else 0.0
		state.lean = move_toward(state.lean, target, delta * 7.0)
		state.punch = maxf(0.0, state.punch - delta * 2.6)
		control.pivot_offset = control.size * 0.5
		var shake: float = sin(state.punch * 34.0) * state.punch
		control.scale = Vector2.ONE * (1.0 + state.lean * 0.035 - state.punch * 0.05)
		control.rotation = -state.lean * 0.012 + shake * 0.045
		if state.lean <= 0.0 and state.punch <= 0.0:
			control.scale = Vector2.ONE
			control.rotation = 0.0
			_juice.erase(control)


func _juice_for(control: Control) -> Dictionary:
	if not _juice.has(control):
		_juice[control] = {"lean": 0.0, "punch": 0.0}
	return _juice[control]


## 다트로 누를 버튼을 찾는다(글자·아이콘을 눌러도 부모 버튼). 펼침 목록 버튼은 제외.
static func _throwable_button(control: Control) -> BaseButton:
	while control != null:
		if control is BaseButton:
			if control is OptionButton or control is MenuButton or (control as BaseButton).disabled:
				return null
			return control as BaseButton
		control = control.get_parent_control()
	return null


## 판넬 바탕·글자처럼 클릭에 반응하지 않는 곳(= 빈 곳으로 본다).
static func _is_background(control: Control) -> bool:
	return control is PanelContainer or control is Label or control is ScrollContainer or control.get_class() == "Control" \
		or control is CenterContainer or control is BoxContainer or control is ColorRect or control is TextureRect


func _make_dart() -> Node3D:
	var dart := DART_SCENE.instantiate() as Node3D
	_viewport.add_child(dart)
	dart.set_physics_process(false)
	(dart as DartView).paint(dart_color)
	dart.scale = Vector3.ONE * DART_SCALE
	# 화면 위 UI 와 같은 "스티커" 느낌: 잉크 외곽선(뒤집힌 껍질)을 두른다.
	var outline := StandardMaterial3D.new()
	outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline.albedo_color = Style.INK
	outline.cull_mode = BaseMaterial3D.CULL_FRONT
	outline.grow = true
	outline.grow_amount = 0.0022
	for part: Node in dart.get_node("Visual").get_children():
		var mesh := part as MeshInstance3D
		var base := (mesh.material_override if mesh.material_override != null else mesh.mesh.surface_get_material(0)) as StandardMaterial3D
		var look := base.duplicate() as StandardMaterial3D
		# 반사할 하늘이 없는 화면이라 금속 재질은 검게 보인다 → 색을 살린 반광택으로 바꾼다.
		look.metallic = 0.15
		look.roughness = 0.45
		look.next_pass = outline
		mesh.material_override = look
	return dart


## 촉 끝(at)을 기준으로 꼬리 방향(tail)과 깃 회전(roll)을 맞춘다.
func _place(dart: Node3D, at: Vector3, tail: Vector3, roll: float) -> void:
	var basis := Basis.looking_at(-tail.normalized(), Vector3.UP)
	dart.global_transform = Transform3D(basis.rotated(tail.normalized(), roll).scaled(Vector3.ONE * DART_SCALE), at)


## 화면 좌표 point 가 가리키는 방향으로 depth(m) 앞의 3D 점.
func _at_depth(point: Vector2, depth: float) -> Vector3:
	var normal := _camera.project_ray_normal(point)
	return _camera.global_position + normal * (depth / maxf(0.01, -normal.z))
