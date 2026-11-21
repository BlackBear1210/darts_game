extends Node3D
## [카드가 사람·물건에 닿는 일] 속박·끌어당기기·카드 던지기의 방장 판정과 모든 화면의 겉모습(2026-11-21 새 카드).
##
## GameView 가 자식으로 하나 붙인다(configure). 다른 작업자가 찾기 쉽게 이 카드들은 이 파일 하나에만 있다.
## - host_action(): 방장만. MatchController.card_world 로 불린다 — 조준선에 걸린 사람 찾기·기절·끌어당기기·카드 비행.
## - play(): 모든 화면. 방장이 "card_fx" 게임 이벤트로 보낸 값을 그대로 그린다(판정 근거 아님).
## 겉모습은 코드로 만든 작은 도형(구슬·고리·카드 한 장)과 발광 재질뿐이다 — 손으로 만든 애니메이션·그림 파일이 없어
## 용량이 늘지 않고, 수치(빠르기·색·시간)는 아래 상수만 고치면 된다.

const Sfx = preload("res://art/audio/sfx.gd")
const BurstFx = preload("res://art/fx/burst_fx.gd")
## 조준 카드(속박·끌어당기기)가 닿는 거리(m)와 몸통 판정 반지름(m).
const AIM_RANGE: float = 15.0
const AIM_RADIUS: float = 0.5
## 속박 구슬·끌어당기는 갈고리가 날아가는 빠르기(m/s).
const ORB_SPEED: float = 16.0
## 속박: 못 움직이는 시간(초). 끌어당기기: 끌려온 뒤 잠깐 멈추는 시간(초).
const BIND_SECONDS: float = 2.5
const PULL_STUN: float = 0.8
## 끌려온 사람이 멈추는 자리(카드 쓴 사람 앞, m)와 최고 빠르기(m/s). 넉백은 초당 KNOCKBACK_DECAY 씩 줄어든다(PlayerView.simulate).
const PULL_GAP: float = 1.0
const PULL_MAX_SPEED: float = 12.0
const KNOCKBACK_DECAY: float = 9.0
## 카드 던지기: 빠르기(m/s, 충전 0 → 1)·떨어짐·최대 비행 시간과 맞은 사람 기절(초).
const CARD_SPEED := Vector2(14.0, 24.0)
const CARD_GRAVITY: float = 1.2
const CARD_MAX_TIME: float = 1.4
const CARD_STUN: float = 1.5
const BIND_COLOR := Color("b26bff")
const PULL_COLOR := Color("ffb347")
const CARD_COLOR := Color("f4ead2")

var game: GameView


func setup(owner: GameView) -> void:
	game = owner


# ─────────────────────────────── 방장 판정 ───────────────────────────────

## [방장] MatchController.card_world 가 부른다. "bind"/"pull" → 맞은 사람 peer ID(0 = 빗나감), "card_throw" → 던졌으면 true.
func host_action(action: String, data: Dictionary) -> Variant:
	var caster := game.actors.get(int(data.get("peer_id", 0))) as PlayerView
	if caster == null or caster.fallen:
		return false if action == "card_throw" else 0
	match action:
		"bind", "pull":
			return _aim_card(action, caster)
		"card_throw":
			return _throw_card(caster, clampf(float(data.get("charge", 0.5)), 0.0, 1.0))
	return null


## 보는 방향(몸 회전 + 고개 각도). 그냥 던진 다트(GameView.throw_stray)와 같은 계산이다.
static func look_direction(actor: PlayerView) -> Vector3:
	return Basis(Vector3.UP, actor.rotation.y) * Basis(Vector3.RIGHT, actor.pitch) * Vector3.FORWARD


## 조준선(eye → direction)에 가장 먼저 걸리는 서 있는 사람(벽 뒤는 안 된다). 없으면 null.
func aimed_player(caster: PlayerView, eye: Vector3, direction: Vector3) -> PlayerView:
	var space := get_world_3d().direct_space_state
	var best: PlayerView = null
	var best_along: float = AIM_RANGE
	for actor: PlayerView in game.actors.values():
		if actor == caster or actor.seated or actor.fallen or not actor.visible:
			continue
		var chest: Vector3 = actor.global_position + Vector3.UP * 0.9 * actor.body_scale
		var along: float = (chest - eye).dot(direction)
		if along < 0.3 or along > best_along:
			continue
		var point: Vector3 = eye + direction * along
		var flat: float = Vector2(point.x - actor.global_position.x, point.z - actor.global_position.z).length()
		if flat > AIM_RADIUS or point.y < actor.global_position.y - 0.1 or point.y > actor.global_position.y + 1.9 * actor.body_scale:
			continue
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, point, 1)).is_empty():
			continue
		best = actor
		best_along = along
	return best


## 속박·끌어당기기: 구슬을 날리고 닿는 순간(비행 시간 뒤) 효과를 건다. 맞은 사람 peer ID.
func _aim_card(kind: String, caster: PlayerView) -> int:
	var eye: Vector3 = caster.eye_position()
	var direction: Vector3 = look_direction(caster)
	var victim: PlayerView = aimed_player(caster, eye, direction)
	var end: Vector3 = eye + direction * AIM_RANGE
	if victim != null:
		end = victim.global_position + Vector3.UP * 1.1 * victim.body_scale
	else:
		var wall := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye, end, 1))
		if not wall.is_empty(): end = wall.position
	var start: Vector3 = eye + direction * 0.4 + Vector3.DOWN * 0.15
	var travel: float = maxf(start.distance_to(end) / ORB_SPEED, 0.05)
	var victim_id: int = victim.identity.peer_id if victim != null else 0
	_send({"kind": kind, "from": start, "to": end, "duration": travel, "victim": victim_id, "peer_id": caster.identity.peer_id})
	if victim_id != 0:
		# 노드 트윈은 경기 화면이 지워지면 같이 사라진다(create_timer 는 지워진 뒤에도 불려 오류가 난다 — 11-17 기록).
		create_tween().tween_callback(_land.bind(kind, victim_id, caster.identity.peer_id)).set_delay(travel)
	return victim_id


## 구슬이 닿았다: 속박 = 제자리에 묶기, 끌어당기기 = 카드 쓴 사람 앞까지 미끄러져 오게(넉백) + 잠깐 멈춤.
func _land(kind: String, victim_id: int, caster_id: int) -> void:
	var victim := game.actors.get(victim_id) as PlayerView
	var caster := game.actors.get(caster_id) as PlayerView
	if victim == null or victim.fallen:
		return
	if kind == "bind":
		game.freeze_player(victim_id, BIND_SECONDS)
		return
	if caster == null or victim.seated:
		return
	var toward: Vector3 = caster.global_position - victim.global_position
	toward.y = 0.0
	var distance: float = maxf(toward.length() - PULL_GAP, 0.0)
	# 넉백이 초당 KNOCKBACK_DECAY 씩 줄면 v²/(2·감속) 만큼 간다 → 그만큼 가도록 처음 빠르기를 정한다.
	var speed: float = minf(sqrt(2.0 * KNOCKBACK_DECAY * distance), PULL_MAX_SPEED)
	victim.knockback = toward.normalized() * speed
	game.freeze_player(victim_id, speed / KNOCKBACK_DECAY + PULL_STUN)


## 카드 던지기: 그냥 던진 다트처럼 눈에서 보는 방향으로 날아가 처음 닿는 곳(벽·바닥·사람)에서 멈춘다.
## 사람이 맞으면 CARD_STUN 초 기절, 가는 길의 병·잔은 깨진다(LoungeWorld.shatter_on_path). 다트·점수와 무관하다.
func _throw_card(caster: PlayerView, charge: float) -> bool:
	if caster.seated:
		return false
	var aim_basis := Basis(Vector3.UP, caster.rotation.y) * Basis(Vector3.RIGHT, caster.pitch)
	var direction: Vector3 = aim_basis * Vector3.FORWARD
	var start: Vector3 = caster.eye_position() + direction * 0.35 + aim_basis * Vector3(0.12, -0.1, 0.0)
	var velocity: Vector3 = direction * lerpf(CARD_SPEED.x, CARD_SPEED.y, charge)
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = [caster.get_rid()]
	var at: Vector3 = start
	var time: float = 0.0
	var victim_id: int = 0
	var step: float = 1.0 / 60.0
	while time < CARD_MAX_TIME:
		var next: Vector3 = at + velocity * step
		velocity.y -= CARD_GRAVITY * step
		time += step
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at, next, 1 | 2, exclude))
		if not hit.is_empty():
			at = hit.position
			if hit.collider is PlayerView:
				victim_id = (hit.collider as PlayerView).identity.peer_id
			break
		at = next
		if at.y <= 0.0:
			at.y = 0.0
			break
	var duration: float = maxf(time, 0.08)
	_send({"kind": "card", "from": start, "to": at, "duration": duration, "victim": victim_id, "peer_id": caster.identity.peer_id})
	create_tween().tween_callback(_card_landed.bind(victim_id, start, at, caster.identity.peer_id)).set_delay(duration)
	return true


func _card_landed(victim_id: int, from: Vector3, to: Vector3, owner: int) -> void:
	var controller: MatchController = game.controller
	var broken: int = game.lounge.shatter_on_path(from, to, owner) if game.lounge != null else 0
	var victim: MatchPlayer = controller.state.find_player(victim_id)
	if victim != null:
		game.freeze_player(victim_id, CARD_STUN)
		controller.add_feed(controller.feed_entry("card", controller.state.find_player(owner), "카드 명중! 기절", victim))
	if victim != null or broken > 0:
		controller._publish()


## 모두의 화면에 보이기(방장 화면 포함).
func _send(data: Dictionary) -> void:
	data["match_id"] = game.controller.state.match_id
	play(data)
	if game.session != null:
		game.session.receive_game_event.rpc("card_fx", data)


# ─────────────────────────────── 모든 화면의 겉모습 ───────────────────────────────

## 방장이 보낸 카드 연출 하나를 그린다. kind = "bind"(보라 구슬 → 몸에 고리) · "pull"(주황 갈고리) · "card"(빙글 도는 카드).
func play(data: Dictionary) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var kind: String = str(data.get("kind", ""))
	var from: Vector3 = data.get("from", Vector3.ZERO)
	var to: Vector3 = data.get("to", Vector3.ZERO)
	var duration: float = maxf(float(data.get("duration", 0.2)), 0.05)
	var thrower := game.actors.get(int(data.get("peer_id", 0))) as PlayerView
	if thrower != null:
		thrower.play_throw()
	var piece := MeshInstance3D.new()
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if kind == "card":
		var box := BoxMesh.new()
		box.size = Vector3(0.09, 0.004, 0.13)
		piece.mesh = box
		piece.material_override = _glow(CARD_COLOR, 0.6)
	else:
		var ball := SphereMesh.new()
		ball.radius = 0.11 if kind == "bind" else 0.07
		ball.height = ball.radius * 2.0
		piece.mesh = ball
		piece.material_override = _glow(BIND_COLOR if kind == "bind" else PULL_COLOR, 3.0)
	add_child(piece)
	piece.global_position = from
	var tween := piece.create_tween()
	tween.tween_property(piece, "global_position", to, duration)
	if kind == "card":
		tween.parallel().tween_property(piece, "rotation:y", TAU * 3.0 * duration / 0.5, duration).as_relative()
	tween.tween_callback(_arrive.bind(kind, to, int(data.get("victim", 0))))
	tween.tween_callback(piece.queue_free)
	Sfx.play_at(self, "whoosh", from, -4.0, 1.4 if kind == "card" else 0.8)


func _arrive(kind: String, at: Vector3, victim_id: int) -> void:
	var tint: Color = BIND_COLOR if kind == "bind" else (PULL_COLOR if kind == "pull" else CARD_COLOR)
	BurstFx.spawn(self, "sparks", at, Vector3.UP, tint)
	Sfx.play_at(self, "pop" if victim_id != 0 else "bounce", at, -3.0, 0.8 if kind == "bind" else 1.1)
	var victim := game.actors.get(victim_id) as PlayerView
	if victim != null and kind == "bind":
		_bind_rings(victim)


## 속박된 사람 몸에 도는 보라 고리 두 개(BIND_SECONDS 동안, 끝에 사라진다).
func _bind_rings(victim: PlayerView) -> void:
	for index in range(2):
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.42
		torus.outer_radius = 0.48
		ring.mesh = torus
		ring.material_override = _glow(BIND_COLOR, 2.5)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		victim.add_child(ring)
		ring.position = Vector3.UP * (0.7 + index * 0.55) * victim.body_scale
		var tween := ring.create_tween()
		tween.tween_property(ring, "rotation:y", TAU * (2.0 if index == 0 else -2.0), BIND_SECONDS).as_relative()
		tween.parallel().tween_property(ring, "scale", Vector3.ONE * 0.2, 0.25).set_delay(BIND_SECONDS - 0.25)
		tween.tween_callback(ring.queue_free)


static func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
