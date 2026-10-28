extends RefCounted
## 다트 한 발: 카드 효과(힘·무거운 다트·바람·졸림·특수 다트 3갈래·가림판·숫자 섞기)를 조준·채점에 반영해 던지고,
## 날아가는 다트를 만들고, 과녁 점수 → 카드 연산(rules.resolve_dart) → 점수 반영까지 한다.
## 벌칙 원판에 던지는 한 발도 여기 있다. 사람 몸에 맞으면 body_hit 신호만 보내고, 그 결과(스턴·보상·맞힌 벌)는 disruption.gd 가 처리한다.

## 다트가 사람 몸(캡슐)에 맞았다.
signal body_hit(thrower: int, victim: int)
## 벌칙 원판에 묶인 사람 몸에 꽂혔다(점수와 상관없음).
signal wheel_body_hit
## 점수가 바뀌었다 → 머리 위 점수 글자를 다시 쓴다.
signal score_changed
## 다트 한 발이 끝났다(base = 과녁 기본 점수, 카드 연산 전) — 봇 감정표현이 듣는다(gestures.gd).
signal dart_landed(seat: int, base: int)

const Context = preload("res://game/card_round/flow/round_context.gd")
const TurnEffects = preload("res://game/card_round/flow/turn_effects.gd")
const Rules = preload("res://game/card_round/rules/round_rules.gd")
const DartSolver = preload("res://game/card_round/rules/dart_solver.gd")
const StunStars = preload("res://game/card_round/fx/stun_stars.gd")
const PunishmentWheel = preload("res://game/card_round/fx/punishment_wheel.gd")
const DART_SCENE: PackedScene = preload("res://game/dart/dart.tscn")

## 벌칙 때 한 사람이 던지는 발 수(시연값).
const PUNISH_DARTS: int = 2
## 내 1인칭 다트가 출발하는 곳(카메라 기준, 손에 든 다트 자리).
const LOCAL_RELEASE := Vector3(0.2, -0.14, -0.55)

## 다트가 날아가는 중(다음 발·차례 끝을 기다리게 한다).
var busy: bool = false
## 벌칙 원판에 지금 던지는 자리와 남은 발 수.
var punish_seat: int = -1
var punish_left: int = 0
## 벌칙 원판(벌칙 시간에만 있다).
var wheel: PunishmentWheel

var _ctx: Context
var _effects: TurnEffects
## 사람 몸에 꽂혀 따라다니는 다트(차례가 끝나면 치운다).
var _stuck_darts: Array[Node3D] = []


## 감독이 시작할 때 한 번: 함께 쓰는 상자와 차례 효과 부품(점수 계산용 과녁 배치)을 받는다.
func setup(ctx: Context, effects: TurnEffects) -> void:
	_ctx = ctx
	_effects = effects


## 내 투척 입력(DartThrowController.throw_requested). 다트 차례면 과녁, 벌칙 차례면 화면 가운데가 가리키는 원판 지점.
func on_local_throw(aim: Vector2, timing: float) -> void:
	if busy:
		return
	if _ctx.phase == "darts" and _ctx.rules.is_turn_of(Context.LOCAL_SEAT):
		await throw(Context.LOCAL_SEAT, aim, timing)
	elif _ctx.phase == "punish" and punish_seat == Context.LOCAL_SEAT and punish_left > 0:
		var center: Vector2 = _ctx.root.get_viewport().get_visible_rect().size * 0.5
		var origin: Vector3 = _ctx.camera.project_ray_origin(center)
		var direction: Vector3 = _ctx.camera.project_ray_normal(center)
		if absf(direction.z) < 0.01:
			return
		var plane_z: float = Context.WHEEL_POSITION.z + 0.04
		await punish_throw(Context.LOCAL_SEAT, origin + direction * ((plane_z - origin.z) / direction.z), timing)


## 다트 한 발(카드 효과 반영). aim = 과녁 반지름 1 기준 조준점, charge = 0~1.
func throw(seat: int, aim: Vector2, charge: float) -> void:
	busy = true
	var rules: Rules = _ctx.rules
	var mods: Dictionary = rules.dart_modifiers(seat)
	# 카드 효과가 조준을 바꾼다: 힘 증가 = 최대 충전, 무거운 다트 = 아래로, 바람 = 옆으로, 졸림 = 흔들림, 특수 다트 = 3갈래.
	if bool(mods.power):
		charge = 1.0
	aim += Vector2(float(mods.push), -float(mods.drop))
	if bool(mods.drowsy):
		aim += Vector2(_ctx.random.randf_range(-0.3, 0.3), _ctx.random.randf_range(-0.3, 0.3))
	var aims: Array[Vector2] = [aim]
	if bool(mods.triple):
		aims.append(aim + Vector2(-0.14, 0.06))
		aims.append(aim + Vector2(0.14, 0.06))
	var actor: PlayerView = _ctx.actors[seat]
	var start: Vector3 = actor.eye_position()
	var radius: float = BoardLayout.RADIUS * TableView.BOARD_SCALE
	var bodies: Array = _bodies(seat)
	actor.play_throw()
	_ctx.audio.cue("throw")
	# 여러 갈래면 가장 높은 과녁 점수 한 개만 친다. 사람 몸에 먼저 맞으면 그 사람이 "막은" 것.
	var base: int = 0
	var reason: String = "빗나감"
	var victim: int = -1
	var longest: float = 0.0
	for one in aims:
		var aim_point: Vector3 = TableView.BOARD_CENTER + Vector3(one.x * radius, one.y * radius, 0)
		var flight: Dictionary = DartSolver.solve(_ctx.root.get_world_3d().direct_space_state, start, aim_point, charge, TableView.BOARD_CENTER.z, bodies)
		_spawn_dart(seat, flight)
		longest = maxf(longest, float(flight.time))
		match str(flight.kind):
			"board":
				var point: Vector3 = flight.point
				var hit := Vector2(point.x - TableView.BOARD_CENTER.x, point.y - TableView.BOARD_CENTER.y) / radius
				if hit.length() <= 1.0 + BoardScorer.BOUNDARY_EPSILON:
					var points: int = BoardScorer.score(hit, _effects.layout)
					if bool(mods.cover) and hit.x < 0.0:
						points = 0
						reason = "가림판에 막힘"
					elif points >= base:
						reason = "%d점" % points
					base = maxi(base, points)
			"body":
				if victim < 0:
					victim = int(flight.seat)
					reason = "%s 몸에 맞음!" % _ctx.name_of(victim)
			"wall":
				reason = "테이블·벽에 맞음" if base == 0 else reason
	await _ctx.wait(minf(longest, 1.3))
	# 과녁 점수 → 이 다트에 걸린 카드 연산(+10, ×2, ÷2 …) → 점수판.
	var result: Dictionary = rules.resolve_dart(seat, base)
	var outcome: Dictionary = rules.apply_points(seat, int(result.points))
	_ctx.stats.darts = int(_ctx.stats.darts) + 1
	if base > 0:
		_ctx.audio.cue("bull" if base >= 25 else "hit")
	var formula: String = str(result.formula)
	_ctx.hud.toast("%s: %s%s" % [_ctx.name_of(seat), reason, "" if formula == str(base) else "  →  " + formula], PlayerLook.COLORS[seat].lightened(0.4))
	if bool(outcome.bust):
		_ctx.hud.toast("버스트! 0 아래로 내려가 이번 차례 점수를 되돌린다", Color("ff9a8a"))
	if bool(outcome.win):
		_ctx.hud.banner("%s 승리!" % _ctx.name_of(seat), rules.win_text(), 1.6)
	score_changed.emit()
	dart_landed.emit(seat, base)
	if victim >= 0:
		body_hit.emit(seat, victim)
	busy = false


## 벌칙 원판에 한 발. 원판에 꽂히면 같이 돈다. 묶인 사람 몸에 꽂히면 스턴 별(점수와는 상관없음).
func punish_throw(seat: int, aim_point: Vector3, charge: float) -> void:
	busy = true
	punish_left -= 1
	var actor: PlayerView = _ctx.actors[seat]
	actor.play_throw()
	_ctx.audio.cue("throw")
	var flight: Dictionary = DartSolver.solve(_ctx.root.get_world_3d().direct_space_state, actor.eye_position(), aim_point, charge,
		Context.WHEEL_POSITION.z + 0.04, _bodies(seat))
	var point: Vector3 = flight.point
	var on_wheel: bool = str(flight.kind) == "board" and Vector2(point.x - Context.WHEEL_POSITION.x, point.y - Context.WHEEL_POSITION.y).length() <= PunishmentWheel.RADIUS
	if on_wheel:
		flight.kind = "wheel"
	var dart: DartView = _spawn_dart(seat, flight)
	await _ctx.wait(float(flight.time))
	_ctx.stats.darts = int(_ctx.stats.darts) + 1
	if on_wheel and is_instance_valid(dart):
		wheel.stick(dart)
		_ctx.audio.cue("hit")
		if wheel.hits_body(point):
			var stars := StunStars.new()
			wheel.add_child(stars)
			stars.position = Vector3(0, 0.62, 0.2)
			_ctx.voice.say(_ctx.rules.loser(), "ouch")
			_ctx.hud.toast("아야! %s 몸에 맞았다" % _ctx.name_of(_ctx.rules.loser()), Color("ff9a8a"))
			wheel_body_hit.emit()
		else:
			_ctx.hud.toast("%s: 원판에 꽂힘" % _ctx.name_of(seat))
	elif str(flight.kind) == "body":
		body_hit.emit(seat, int(flight.seat))
	else:
		_ctx.hud.toast("%s: 빗나감" % _ctx.name_of(seat))
	busy = false


## 차례가 끝나면 날아간 다트·몸에 꽂힌 다트를 치운다.
func clear_darts() -> void:
	for child in _ctx.darts_root.get_children():
		child.queue_free()
	for dart in _stuck_darts:
		if is_instance_valid(dart):
			dart.queue_free()
	_stuck_darts.clear()


## 보이는 다트를 만들어 날린다. 사람 몸에 맞으면 그 사람 몸에 꽂힌 채 따라다닌다.
func _spawn_dart(seat: int, flight: Dictionary) -> DartView:
	var dart := DART_SCENE.instantiate() as DartView
	_ctx.darts_root.add_child(dart)
	dart.paint(PlayerLook.COLORS[seat])
	var release: Vector3 = LOCAL_RELEASE if seat == Context.LOCAL_SEAT and not _ctx.autoplay else Vector3.ZERO
	var kind: String = str(flight.kind)
	dart.fly(flight.start, flight.point, float(flight.time), kind != "none", release)
	if kind == "body":
		var victim: PlayerView = _ctx.actors[int(flight.seat)]
		_ctx.root.get_tree().create_timer(float(flight.time) + 0.05).timeout.connect(func() -> void:
			if is_instance_valid(dart) and is_instance_valid(victim):
				dart.reparent(victim, true)
				(dart.get_node("Visual") as Node3D).scale = Vector3.ONE * 1.3
				_stuck_darts.append(dart))
	return dart


## 다트가 맞을 수 있는 사람 몸(던지는 사람 빼고 보이는 사람 전부) — DartSolver 의 캡슐 판정에 넘긴다.
func _bodies(thrower: int) -> Array:
	var bodies: Array = []
	for seat in range(Context.SEAT_COUNT):
		if seat != thrower and _ctx.actors[seat].visible:
			bodies.append({"seat": seat, "position": _ctx.actors[seat].global_position})
	return bodies
