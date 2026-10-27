extends Node3D
## 아트 쇼케이스 — 아스트라 AI 로 만든 펍·캐릭터 디자인을 직접 둘러보고 다트를 던져 보는 혼자용 예시.
## 실행: Godot 에서 art/showcase/showcase.tscn 을 열고 F6 (또는 저장소 최상위 "실행_디자인예시.cmd").
## F5(app/main.tscn, 실제 멀티플레이 경기)와는 별개이며 네트워크·경기 규칙(MatchController)에 연결하지 않는다.
##
## 흐름: _ready 에서 정적 메시 묶기·HUD·효과음·손 다트 생성 → 1~4 키로 카메라 시점 전환
##       → 2번(투척) 시점: 마우스로 시선을 돌리고(1인칭) A/D 로 투척선 위를 좌우로 걷는다. 조준은 화면 가운데.
##       → 왼쪽 버튼을 누르고 있으면 충전, 놓으면 발사, 충전 중 오른쪽 버튼은 취소.
##       → 팀 판정 코드(BoardScorer)로 점수 계산 → HUD 갱신. 한 차례 3발, Space 로 다음 차례.
##
## 연습용 규칙(확정 규칙 아님): 누적 점수, 무제한 차례, 차례마다 연산 카드 ×2 한 번(Q).
## 충전 → 착탄은 실제 경기(game/game.gd solve_dart)와 같은 식이다: 충전량으로 속도(7~16m/s)를 정하고,
## 최대 충전일 때 조준점에 꽂히게 중력을 보정한다 → 덜 충전하면 그만큼 아래로 떨어진다. 수치는 game/dart/default_dart.tres.
## 자동 검사: tests/test_art_showcase.gd

const BoardSpec = preload("res://art/board_spec.gd")
const MeshKit = preload("res://art/mesh_kit.gd")
const StaticBatch = preload("res://art/static_batch.gd")
const ShowcaseHud = preload("res://art/showcase/showcase_hud.gd")
const SynthAudio = preload("res://art/showcase/synth_audio.gd")

const BOARD_CENTER := BoardSpec.PUB_BOARD_CENTER
## 실제 경기와 같은 투척 수치(충전 시간·최소/최대 속도·중력)를 쓴다.
const DART_CONFIG: DartConfig = preload("res://game/dart/default_dart.tres")
## 카메라 시점 4개: [카메라 위치, 바라보는 점, 화각(FOV)].
## 0 펍 전경 / 1 투척(투척선 위 눈높이 1.6m) / 2 캐릭터 라인업 / 3 카드 테이블
const VIEWS := [
	[Vector3(4.9, 3.5, 8.3), Vector3(-0.6, 1.35, -0.7), 62.0],
	[Vector3(0, 1.60, BoardSpec.PUB_BOARD_CENTER.z + BoardSpec.THROW_DISTANCE), BoardSpec.PUB_BOARD_CENTER, 22.0],
	[Vector3(-2.5, 1.85, 3.15), Vector3(-3.58, 0.92, -0.35), 48.0],
	[Vector3(1.9, 3.45, 6.65), Vector3(-0.5, 0.65, 3.2), 48.0],
]
const THROW_VIEW := 1
const DARTS_PER_VISIT := 3
## 조준 가능 범위 = 다트판 캐비닛(나무 판) 크기. 점수 링에 숨은 보정(에임 어시스트)은 없다.
const AIM_LIMIT_X := 0.55
const AIM_MIN_Y := 1.12
const AIM_MAX_Y := 2.42
## 투척 시점 1인칭 시선: 마우스 감도(라디안/픽셀)와 정면 기준 좌우(yaw)·위아래(pitch) 한계.
const LOOK_SENSITIVITY := 0.0022
const LOOK_YAW_LIMIT := 0.30
const LOOK_PITCH_LIMIT := 0.30
## A/D 좌우 이동 속도(m/s)와 투척선 중심에서의 한계(투척선 폭 1.48m 안).
const STRAFE_SPEED := 1.2
const STRAFE_LIMIT := 0.6
## 손 다트 위치(카메라 기준). 충전할수록 몸 쪽으로 당긴다.
const HELD_DART_POSITION := Vector3(0.095, -0.055, -0.55)
const HELD_DART_PULL := 0.08

@onready var camera: Camera3D = $Camera
## 꽂힌 다트들을 담는 부모. 다음 차례·초기화 때 비운다.
@onready var darts: Node3D = $Darts

var hud: CanvasLayer
var sound: AudioStreamPlayer
var current_view := 0
var visit := 1
var total := 0
## 이번 차례에 던진 다트별 점수(최대 3개).
var hits: Array[int] = []
## card_armed: 다음 한 발에 ×2 가 걸려 있음 / card_used: 이번 차례에 카드를 이미 씀.
var card_armed := false
var card_used := false
## 다트가 날아가는 중이면 true — 그동안 입력을 잠근다.
var busy := false
var transition: Tween
var flight: Tween
var held_dart: Node3D
## 투척 시점 시선(x=yaw, y=pitch, 라디안)과 좌우 이동량(m). 다른 시점에서 투척 시점으로 들어오면 0 으로 돌아간다.
var look := Vector2.ZERO
var strafe := 0.0
## 왼쪽 버튼을 누르고 있는 동안 true. charge 는 0~1(DART_CONFIG.charge_seconds 에 1 이 된다).
var charging := false
var charge := 0.0
var _charge_held := 0.0
var elapsed := 0.0
## 스크린샷 촬영 중에는 조준점을 숨긴다(tests/test_art_showcase.gd -- --render).
var capture_mode := false
## 점수 판정은 팀 코드(game/board)를 그대로 쓴다. 과녁 숫자 섞기 카드가 생기면 이 layout 만 바꾸면 된다.
var _layout := BoardLayout.new()


func _ready() -> void:
	# 원래 설계(Compatibility 렌더러)와 같은 2배 MSAA. 프로젝트 설정은 건드리지 않고 이 화면에만 건다.
	get_viewport().msaa_3d = Viewport.MSAA_2X
	print("STATIC BATCHES ", StaticBatch.optimize($Pub))
	for character in $Pub.get_children():
		if character.scene_file_path.contains("/characters/"):
			StaticBatch.optimize(character)
	hud = ShowcaseHud.new()
	add_child(hud)
	hud.build()
	hud.view_requested.connect(set_view)
	hud.card_requested.connect(arm_card)
	hud.next_requested.connect(next_visit)
	hud.reset_requested.connect(reset_session)
	hud.sound_requested.connect(toggle_sound)
	hud.credits_requested.connect(func() -> void: hud.credits.visible = not hud.credits.visible)
	sound = SynthAudio.new()
	add_child(sound)
	# 투척 시점에서 화면 오른쪽 아래에 보이는 "손에 든 다트". 카메라 자식이라 시점을 따라다닌다.
	held_dart = make_dart()
	camera.add_child(held_dart)
	held_dart.position = HELD_DART_POSITION
	held_dart.rotation = Vector3(-0.15, -0.2, 0.15)
	set_view(0, true)


func _exit_tree() -> void:
	# 재생 중인 합성음이 종료 시점까지 남으면 "ObjectDB instances leaked"(AudioStreamPlaybackWAV) 경고가 뜬다.
	sound.stop()
	release_mouse()


## 카메라 시점 전환. instant=false 면 0.65초 동안 부드럽게 이동한다.
func set_view(index: int, instant := false) -> void:
	var entering_throw := index == THROW_VIEW and current_view != THROW_VIEW
	current_view = clampi(index, 0, VIEWS.size() - 1)
	cancel_charge()
	if transition and transition.is_running():
		transition.kill()
	if entering_throw:
		look = Vector2.ZERO
		strafe = 0.0
	if current_view != THROW_VIEW:
		release_mouse()
	var spec: Array = VIEWS[current_view]
	var target := throw_transform() if current_view == THROW_VIEW else Transform3D(Basis.IDENTITY, spec[0]).looking_at(spec[1], Vector3.UP)
	if instant:
		camera.transform = target
		camera.fov = spec[2]
	else:
		transition = create_tween().set_parallel(true)
		transition.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		transition.tween_property(camera, "transform", target, 0.65)
		transition.tween_property(camera, "fov", spec[2], 0.65)
	hud.set_view(current_view)
	held_dart.visible = current_view == THROW_VIEW and hits.size() < DARTS_PER_VISIT and not busy
	refresh()


func _process(delta: float) -> void:
	elapsed += delta
	if current_view == THROW_VIEW:
		var moving := transition != null and transition.is_running()
		if not moving and not hud.credits.visible:
			# A/D: 투척선 위 좌우 이동. 충전 중에도 움직일 수 있다.
			var axis := float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
			strafe = clampf(strafe + axis * STRAFE_SPEED * delta, -STRAFE_LIMIT, STRAFE_LIMIT)
			camera.transform = throw_transform()
		if charging:
			_charge_held += delta
			charge = minf(_charge_held / DART_CONFIG.charge_seconds, 1.0)
		var point := aim_point()
		hud.set_reticle(camera.unproject_position(point), not capture_mode and not busy and not moving and hits.size() < DARTS_PER_VISIT)
		hud.set_charge(charge, charging and not capture_mode)
		# 손 다트: 충전할수록 몸 쪽으로 당기고, 평소엔 살짝 떠 있는 느낌(호흡). 판정과 무관한 연출.
		held_dart.position = HELD_DART_POSITION + Vector3(0, sin(elapsed * 1.6) * 0.002, charge * HELD_DART_PULL)


## 투척 시점 카메라 = 투척선 위 눈높이에서 다트판을 정면으로 본 자세 → A/D 만큼 옆으로 → 마우스 시선만큼 회전.
func throw_transform() -> Transform3D:
	var spec: Array = VIEWS[THROW_VIEW]
	var front := Transform3D(Basis.IDENTITY, spec[0]).looking_at(spec[1], Vector3.UP).basis
	return Transform3D(front * Basis.from_euler(Vector3(look.y, look.x, 0)), spec[0] + Vector3(strafe, 0, 0))


## 조준점 = 화면 가운데(카메라 정면) 광선이 다트판 평면(z = BOARD_CENTER.z)과 만나는 점. 캐비닛 밖으로는 못 나간다.
func aim_point() -> Vector3:
	var origin := camera.global_position
	var direction := -camera.global_basis.z
	if absf(direction.z) < 0.0001:
		return BOARD_CENTER
	var t := (BOARD_CENTER.z - origin.z) / direction.z
	var point := origin + direction * t
	point.x = clampf(point.x, -AIM_LIMIT_X, AIM_LIMIT_X)
	point.y = clampf(point.y, AIM_MIN_Y, AIM_MAX_Y)
	return point


## 키보드 단축키. GUI 버튼이 포커스를 잡고 있어도 동작하도록 _input 에서 먼저 받는다.
## 마우스: 잡힌(captured) 상태의 시선 회전·왼쪽 누르기, 그리고 언제나 왼쪽 떼기(발사)·충전 중 오른쪽(취소)도
## 여기서 받는다 → 커서 아래 패널이 클릭을 먹어 충전이 멈추지 않게 한다.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if current_view == THROW_VIEW and mouse_captured() and not hud.credits.visible:
			look.x = clampf(look.x - event.relative.x * LOOK_SENSITIVITY, -LOOK_YAW_LIMIT, LOOK_YAW_LIMIT)
			look.y = clampf(look.y - event.relative.y * LOOK_SENSITIVITY, -LOOK_PITCH_LIMIT, LOOK_PITCH_LIMIT)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and charging:
			cancel_charge()
			hud.result_label.text = "충전 취소."
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and charging:
			release_charge()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed and mouse_captured() and current_view == THROW_VIEW:
			start_charge()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			# Esc: 크레딧이 열려 있으면 닫고, 아니면 마우스를 풀어 HUD 버튼을 쓸 수 있게 한다(충전 중이면 취소).
			if hud.credits.visible:
				hud.credits.hide()
			else:
				cancel_charge()
				release_mouse()
			return
		if hud.credits.visible:
			return
		match event.keycode:
			KEY_1: set_view(0)
			KEY_2: set_view(1)
			KEY_3: set_view(2)
			KEY_4: set_view(3)
			KEY_Q: arm_card()
			KEY_SPACE: next_visit()
			KEY_R: reset_session()
			KEY_M: toggle_sound()
			_: return
		get_viewport().set_input_as_handled()


## 커서가 보일 때의 왼쪽 누르기는 _unhandled_input 에서 받는다 → HUD 버튼을 누른 클릭은 GUI 가 먼저 먹어서
## 다트가 나가지 않는다. 3D 화면을 누르면 마우스를 잡고(1인칭 시선 시작) 바로 충전을 시작한다.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if start_charge():
			capture_mouse()


func _notification(what: int) -> void:
	# 창이 포커스를 잃으면 떼기 이벤트를 못 받을 수 있다 → 충전을 버린다(실제 경기 입력과 같은 규칙).
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel_charge()


## 충전 시작. 투척 시점·다트 남음·비행/시점 전환/크레딧 아님일 때만. 시작했으면 true.
func start_charge() -> bool:
	if current_view != THROW_VIEW or busy or charging or hud.credits.visible or hits.size() >= DARTS_PER_VISIT:
		return false
	if transition and transition.is_running():
		return false
	charging = true
	_charge_held = 0.0
	charge = 0.0
	return true


## 왼쪽 버튼을 놓음: 지금 충전량으로 화면 가운데 조준점에 던진다.
func release_charge() -> void:
	if not charging:
		return
	var power := charge
	cancel_charge()
	throw_at(aim_point(), power)


## 충전을 버린다(오른쪽 버튼·Esc·시점 전환·포커스 잃음). 다트는 손에 남는다.
func cancel_charge() -> void:
	charging = false
	_charge_held = 0.0
	charge = 0.0


func mouse_captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


## headless(자동 검사)에는 마우스가 없으므로 잡지 않는다.
func capture_mouse() -> void:
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func release_mouse() -> void:
	if mouse_captured():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## 다트 모델(촉·몸통·샤프트·빨간 날개). 로컬 -Z 가 다트판 쪽, 원점이 촉 끝이다.
func make_dart() -> Node3D:
	var dart := Node3D.new()
	dart.name = "Dart"
	var metal := MeshKit.material("DartMetal", "b7bbab", 0.8)
	var red := MeshKit.material("DartFlight", "cb6253")
	MeshKit.rod(dart, "Point", Vector3.ZERO, Vector3(0, 0, 0.035), 0.0015, metal)
	MeshKit.rod(dart, "Barrel", Vector3(0, 0, 0.035), Vector3(0, 0, 0.085), 0.005, metal)
	MeshKit.rod(dart, "Shaft", Vector3(0, 0, 0.085), Vector3(0, 0, 0.15), 0.0025, metal)
	MeshKit.box(dart, "FlightX", Vector3(0.038, 0.001, 0.045), Vector3(0, 0, 0.132), red)
	MeshKit.box(dart, "FlightY", Vector3(0.001, 0.038, 0.045), Vector3(0, 0, 0.132), red)
	return dart


## aim(다트판 평면 위 조준점)을 향해 power(0~1 충전량)로 던진다. 최대 충전이면 조준점에 정확히 꽂힌다.
func throw_at(aim: Vector3, power := 1.0) -> void:
	if busy or hits.size() >= DARTS_PER_VISIT:
		return
	busy = true
	held_dart.hide()
	var dart := make_dart()
	darts.add_child(dart)
	# 손 위치(카메라 오른쪽 아래 앞)에서 출발해 실제 포물선으로 날아간다.
	var origin := camera.global_position + camera.global_basis * Vector3(0.10, -0.12, -0.30)
	var launch := launch_velocity(origin, aim, power)
	var seconds := (BOARD_CENTER.z - origin.z) / launch.z
	var landing := DART_CONFIG.position_at(origin, launch, seconds)
	# 캐비닛 밖으로 떨어지면 캐비닛 가장자리에 꽂힌 것으로 둔다(점수는 어차피 0).
	landing.x = clampf(landing.x, -AIM_LIMIT_X, AIM_LIMIT_X)
	landing.y = clampf(landing.y, AIM_MIN_Y, AIM_MAX_Y)
	dart.global_position = origin
	dart.look_at(aim)
	sound.cue("throw")
	flight = create_tween()
	flight.tween_method(func(t: float) -> void:
		dart.global_position = DART_CONFIG.position_at(origin, launch, t)
		var heading := launch + Vector3.DOWN * DART_CONFIG.gravity * t
		dart.look_at(dart.global_position + heading)
	, 0.0, seconds, seconds)
	flight.tween_callback(func() -> void:
		dart.global_position = landing
		finish_throw(landing))
	refresh()


## 실제 경기(game/game.gd solve_dart)와 같은 발사 속도: 속도 = lerp(최소, 최대, 충전량),
## 위쪽 보정은 최대 속도로 날아갈 때의 시간 기준 → 최대 충전이면 조준점, 약하면 아래로 떨어진다.
func launch_velocity(origin: Vector3, aim: Vector3, power: float) -> Vector3:
	var speed := lerpf(DART_CONFIG.minimum_speed, DART_CONFIG.maximum_speed, clampf(power, 0.0, 1.0))
	var nominal_time := origin.distance_to(aim) / DART_CONFIG.maximum_speed
	return (aim - origin).normalized() * speed + Vector3.UP * DART_CONFIG.gravity * nominal_time * 0.5


## 착탄 처리: 팀 BoardScorer 로 점수 → 카드 배수 → 누적.
func finish_throw(point: Vector3) -> void:
	var board_point := BoardSpec.to_board_point(Vector2(point.x - BOARD_CENTER.x, point.y - BOARD_CENTER.y))
	var base_score := BoardScorer.score(board_point, _layout)
	var value: int = base_score * (2 if card_armed else 1)
	hits.append(value)
	total += value
	hud.result_label.text = "%s%s  /  +%d" % [score_label(board_point, base_score), " ×2" if card_armed else "", value]
	card_armed = false
	busy = false
	held_dart.visible = current_view == THROW_VIEW and hits.size() < DARTS_PER_VISIT
	sound.cue("bull" if base_score >= 50 else "hit")
	refresh()


## HUD 표시용 이름(불, 트리플 20, 더블 16, 싱글 5, 빗나감). 링 경계를 다시 계산하지 않고 점수 ÷ 구역 숫자로 배수를 알아낸다.
func score_label(board_point: Vector2, base_score: int) -> String:
	if base_score == 0:
		return "빗나감"
	if base_score == 50:
		return "불"
	if base_score == 25:
		return "아우터 불"
	var number: int = _layout.numbers[BoardLayout.sector_at(board_point)]
	var multiplier := base_score / number
	return ("트리플 " if multiplier == 3 else ("더블 " if multiplier == 2 else "싱글 ")) + str(number)


## Q: 연산 카드(×2) 예시. 다음 한 발 점수 2배, 차례당 1회, 빗나가도 소비된다.
func arm_card() -> void:
	if current_view != THROW_VIEW or busy or card_used or hits.size() >= DARTS_PER_VISIT:
		return
	card_armed = true
	card_used = true
	hud.result_label.text = "다음 한 발은 점수 ×2."
	refresh()


## Space: 3발을 다 던졌을 때만 다음 차례로 넘어가며 꽂힌 다트를 회수한다.
func next_visit() -> void:
	if busy:
		return
	if hits.size() < DARTS_PER_VISIT:
		set_view(THROW_VIEW)
		return
	visit += 1
	hits.clear()
	card_armed = false
	card_used = false
	clear_darts()
	hud.result_label.text = "새 다트 세 발."
	set_view(THROW_VIEW)


func clear_darts() -> void:
	for child in darts.get_children():
		child.queue_free()


## R: 점수·차례·카드·다트 전부 처음으로. 날아가는 중인 다트(Tween)도 취소한다.
func reset_session() -> void:
	if flight and flight.is_running():
		flight.kill()
	cancel_charge()
	busy = false
	hits.clear()
	total = 0
	visit = 1
	card_armed = false
	card_used = false
	clear_darts()
	hud.result_label.text = "처음부터 다시. 이번엔 제대로!"
	held_dart.visible = current_view == THROW_VIEW
	refresh()


func refresh() -> void:
	hud.update_state(visit, total, hits, card_armed, card_used, busy)


func toggle_sound() -> void:
	sound.muted = not sound.muted
	if sound.muted:
		sound.stop()
	hud.sound_button.text = "소리 끔" if sound.muted else "소리 켬"
