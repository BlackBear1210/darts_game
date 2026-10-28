extends RefCounted
## 캐릭터가 어디에 있고 어디로 걷는가: 자리에 앉기·일어나기, 걸어가기, 던지는 사람 앞을 따라가며 막기,
## 스턴(잠깐 못 움직임), 맞으면 옆으로 튕겨 나가기, 충전 라운드의 자동 착석.
## 봇 걸음은 F5 봇과 같은 조향 계산(BotDriver)을 쓴다. 사람(내 자리) 조작은 local_input.gd 가 한다.

## 내가 자리에 앉았다 → 카메라가 테이블 쪽을 보게 한다(round_camera.gd).
signal local_seated

const Context = preload("res://game/card_round/flow/round_context.gd")
const BotDriver = preload("res://game/player/bot_driver.gd")

## 던지는 자리(투척선보다 1.2m 뒤). 투척선을 넘지 않으므로 규칙상 문제없다.
const THROW_Z: float = -1.9
## 막는 사람은 던지는 사람보다 이만큼 과녁 쪽에 선다.
const BLOCK_GAP: float = 0.85
## 사람이 갈 수 있는 가장 앞(투척선 바로 뒤).
const MIN_STAND_Z: float = -2.85
## 자동 착석: 이 시간 안에 못 앉으면 바로 앉힌다.
const GATHER_SECONDS: float = 6.0

## 충전 라운드에 모두 자리로 가는 중(이때는 내 자리도 자동으로 걷는다).
var gathering: bool = false

var _ctx: Context
## 자리별 걷기 목표: {to(바닥 위치), sit(도착하면 앉기), face(도착해서 볼 곳), follow(따라가며 막을 사람 자리, 없으면 -1)}
var _walk: Dictionary = {}
var _stunned_until: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _ouch_until: Array[float] = [0.0, 0.0, 0.0, 0.0]


## 감독이 시작할 때 한 번: 함께 쓰는 상자를 받는다.
func setup(ctx: Context) -> void:
	_ctx = ctx


# --- 앉기·일어나기·걷기 ---

## 자기 자리에 바로 앉힌다(걷기 목표는 지운다).
func sit(seat: int) -> void:
	var actor: PlayerView = _ctx.actors[seat]
	actor.seated = true
	actor.velocity = Vector3.ZERO
	actor.position = TableView.SEATS[seat]
	actor.rotation.y = Context.facing(TableView.TABLE_CENTER - TableView.SEATS[seat])
	actor.update_posture()
	_walk.erase(seat)
	if seat == Context.LOCAL_SEAT:
		local_seated.emit()


## 자리 seat 를 의자에서 일으킨다(이미 서 있으면 그대로).
func stand(seat: int) -> void:
	_ctx.actors[seat].seated = false


## to 로 걸어가 face 쪽을 보고 선다. follow 를 주면 그 사람이 던지는 동안 앞을 따라가며 막는다.
func walk_to(seat: int, to: Vector3, face: Vector3, follow: int = -1) -> void:
	_walk[seat] = {"to": to, "sit": false, "face": face, "follow": follow}


## 자기 자리로 걸어가 앉는다(이미 앉아 있으면 그대로).
func send_home(seat: int) -> void:
	if _ctx.actors[seat].seated:
		return
	_walk[seat] = {"to": TableView.SEATS[seat], "sit": true, "face": TableView.TABLE_CENTER, "follow": -1}


## 던지는 자리에서 옆으로 비켜 선다(막는 사람을 피할 때). 레인 밖으로는 안 나간다.
func sidestep(seat: int) -> void:
	if not _walk.has(seat):
		return
	var to: Vector3 = _walk[seat].to
	to.x = clampf(to.x + (0.9 if to.x <= 0.0 else -0.9), -1.6, 1.6)
	_walk[seat].to = to


## 걷기 목표에 도착했는가(목표가 없으면 도착한 것으로 본다).
func arrived(seat: int) -> bool:
	if not _walk.has(seat):
		return true
	return BotDriver.arrived(_ctx.actors[seat].position, _walk[seat].to)


## 충전 라운드 = 자동 착석: 모두 자기 자리로 걸어가 앉는다. 늦으면 바로 앉힌다.
func gather() -> void:
	gathering = true
	for seat in range(Context.SEAT_COUNT):
		if _ctx.actors[seat].visible:
			send_home(seat)
	await _ctx.wait_until(func() -> bool: return all_seated(), GATHER_SECONDS)
	for seat in range(Context.SEAT_COUNT):
		if not _ctx.actors[seat].seated and _ctx.actors[seat].visible:
			sit(seat)
	gathering = false


## 모두 의자에 앉았는가(모이기 끝 판정).
func all_seated() -> bool:
	for seat in range(Context.SEAT_COUNT):
		if _ctx.actors[seat].visible and not _ctx.actors[seat].seated:
			return false
	return true


# --- 몸으로 막기 ---

## thrower 를 따라가며 막는 중인가.
func is_following(seat: int, thrower: int) -> bool:
	return _walk.has(seat) and int(_walk[seat].get("follow", -1)) == thrower


## thrower 의 차례가 끝났다 → 막던 사람들은 자리로 돌아간다.
func release_followers(thrower: int) -> void:
	for seat in range(Context.SEAT_COUNT):
		if is_following(seat, thrower):
			send_home(seat)


## 막는 사람이 설 곳: 던지는 사람 바로 앞(과녁 쪽). 아직 자리에 있으면 던지는 자리 앞.
func block_spot(thrower: int) -> Vector3:
	var at: Vector3 = _ctx.actors[thrower].global_position
	var z: float = maxf(at.z - BLOCK_GAP, MIN_STAND_Z) if at.z < 0.5 else THROW_Z - BLOCK_GAP
	return Vector3(at.x if at.z < 0.5 else 0.0, 0, z)


## 누군가 이 사람 앞에 도착해 막고 있는가.
func blocked(seat: int) -> bool:
	for other in range(Context.SEAT_COUNT):
		if other != seat and is_following(other, seat) and arrived(other):
			return true
	return false


# --- 스턴·튕김 ---

## 스턴: seconds 동안 못 움직인다(머리 위 별은 fx/stun_stars.gd). "아야!" 표시는 1.4초.
func stun(seat: int, seconds: float) -> void:
	_stunned_until[seat] = _ctx.now + seconds
	_ouch_until[seat] = _ctx.now + 1.4


## 자리 seat 가 지금 스턴(못 움직임) 중인가.
func stunned(seat: int) -> bool:
	return _ctx.now < _stunned_until[seat]


## 머리 위에 "아야!"를 띄우는 중인가.
func ouch(seat: int) -> bool:
	return _ctx.now < _ouch_until[seat]


## 맞은 사람은 만화처럼 옆으로 튕겨 나간다 → 스턴된 채 길목을 막아 연달아 맞는 일이 없다.
func knock_aside(thrower: int, victim: int) -> void:
	var actor: PlayerView = _ctx.actors[victim]
	var away: Vector3 = actor.global_position - _ctx.actors[thrower].global_position
	away.y = 0.0
	var side := Vector3(-away.z, 0, away.x).normalized()
	if side.length() < 0.5:
		side = Vector3.RIGHT
	if side.x * actor.position.x < 0.0:
		side = -side
	var to: Vector3 = actor.position + side * 0.8 + away.normalized() * 0.2
	to.z = maxf(to.z, MIN_STAND_Z)
	to.x = clampf(to.x, -5.5, 5.5)
	if actor.seated:
		return
	var tween := _ctx.root.create_tween()
	tween.tween_property(actor, "position", to, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# --- 매 물리 프레임 ---

## 이 자리를 지금 자동으로 걷게 하는가(봇, 또는 자동 착석 중인 나).
func auto_driven(seat: int) -> bool:
	return _ctx.bot_driven(seat) or (gathering and _walk.has(seat))


## 자동으로 움직이는 캐릭터를 한 걸음 옮긴다. 사람이 조작하는 내 자리는 건너뛴다(local_input.gd).
func physics_step(delta: float) -> void:
	for seat in range(Context.SEAT_COUNT):
		var actor: PlayerView = _ctx.actors[seat]
		if not actor.visible or not auto_driven(seat):
			continue
		if stunned(seat) or not _walk.has(seat):
			actor.simulate(delta, {"yaw": actor.rotation.y})
			continue
		var walk: Dictionary = _walk[seat]
		var follow: int = int(walk.get("follow", -1))
		if follow >= 0 and _ctx.rules.is_turn_of(follow):
			# 막는 사람: 던지는 사람이 움직이면 따라간다.
			walk.to = block_spot(follow)
			walk.face = _ctx.actors[follow].global_position
		if BotDriver.arrived(actor.position, walk.to):
			if bool(walk.sit):
				sit(seat)
			else:
				actor.simulate(delta, {"yaw": Context.facing(walk.face - actor.position)})
		else:
			actor.simulate(delta, BotDriver.walk_controls(actor.position, walk.to))
