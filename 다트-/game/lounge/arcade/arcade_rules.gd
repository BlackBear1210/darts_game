extends RefCounted
## 네온 오락실(테마 1) 기계 3종의 규칙: 인형뽑기 · 가챠(캡슐뽑기) · 농구 오락기.
## 방장만 계산한다. 결과(상태 사전)는 LoungeWorld 가 0.1초마다 소품과 함께 모두에게 보낸다.
##
## [놀이 설계 — 참고한 게임]
##   갱비스트 · 휴먼 폴 플랫 : 서로 밀치고 흔들어 방해한다 → 다른 사람이 기계를 "흔들면" 집게가 미끄러지고 골대가 흔들린다.
##   R.E.P.O              : 물건을 들고 던지는 몸 개그 → 뽑은 인형·캡슐·농구공은 전부 던질 수 있는 소품이 된다.
##   라이어스 바           : 운에 거는 한 판 → 가챠 캡슐은 열기 전까지 무엇이 나올지 모른다(왕머리·먹물·빙글빙글·폭죽·꽝).
## 기계 놀이는 다트 점수와 섞지 않는다(밸런스는 팀 확정 전). 오락실 순위·킬로그·장난 효과만 만든다.

# ───── 인형뽑기(라운지 뒷벽 오른쪽) ─────
const CLAW_AT := Vector3(8.6, 0.0, 6.75)
const CLAW_SIZE := Vector3(1.1, 2.4, 1.0)
## 집게가 움직이는 유리 안 반폭(x, z). 집게 높이: 위(대기) ~ 아래(인형 높이).
const CLAW_PIT := Vector2(0.38, 0.32)
const CLAW_TOP: float = 1.95
const CLAW_LOW: float = 1.16
## 인형이 떨어지는 구멍(앞 왼쪽 구석)과 상품 문.
const CLAW_CHUTE := Vector2(-0.36, -0.3)
const CLAW_PANEL := Vector3(8.6, 1.08, 6.2)
const CLAW_DOOR := Vector3(8.24, 0.14, 6.02)
const CLAW_SWEEP: float = 0.42
const CLAW_PLAY_TIME: float = 20.0
## 유리 안 인형 자리(기계 기준 x, 높이, z).
const PLUSH_SPOTS: Array[Vector3] = [Vector3(0.1, 1.07, 0.12), Vector3(0.24, 1.07, -0.12), Vector3(-0.12, 1.07, 0.18)]
const PLUSH_RETURN: float = 40.0

# ───── 가챠(NPC 테이블 자리 위 두 대, 앞면 = -X) ─────
const GACHA_AT: Array[Vector3] = [Vector3(5.78, 0.85, 3.68), Vector3(5.78, 0.85, 4.42)]
const GACHA_CRANK := Vector3(-0.29, 0.3, 0.0)
const GACHA_TRAY := Vector3(-0.36, 0.06, 0.12)
const GACHA_GLOBE_Y: float = 0.78
const GACHA_COOLDOWN: float = 3.0
const CAPSULE_RETURN: float = 40.0
## 캡슐 안에 든 것과 나올 확률(가중치). "꽝"도 있어야 라이어스 바 같은 긴장감이 생긴다.
const CAPSULE_EFFECTS: Array = [["bighead", 3], ["ink", 3], ["dizzy", 2], ["confetti", 2], ["blank", 1]]
const EFFECT_TEXT := {"bighead": "왕머리!", "ink": "먹물 뿜!", "dizzy": "빙글빙글", "confetti": "축하 폭죽", "blank": "꽝!"}

# ───── 농구 오락기(당구대 자리, 앞 = -Z · 골대는 안쪽 +Z) ─────
const HOOP_AT := Vector3(11.15, 0.0, 4.07)
const HOOP_RING := Vector3(11.15, 2.05, 4.92)
const HOOP_RADIUS: float = 0.21
const HOOP_BUTTON := Vector3(11.15, 1.0, 2.76)
const HOOP_TIME: float = 30.0
const HOOP_FOOTPRINT := Rect2(10.4, 2.8, 1.5, 2.55)
const BALL_HOMES: Array[Vector3] = [Vector3(10.85, 0.93, 3.02), Vector3(11.15, 0.93, 3.02), Vector3(11.45, 0.93, 3.02)]
const THREE_POINT: float = 3.0

## 다른 사람이 기계를 흔들 수 있는 간격(초).
const BUMP_GAP: float = 2.0

var lounge: Node3D
var claw: Dictionary = {}
var gacha: Array = []
var hoop: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _init(owner: Node3D) -> void:
	lounge = owner
	_rng.randomize()
	reset()


func reset() -> void:
	claw = {"phase": "idle", "operator": 0, "t": 0.0, "x": CLAW_CHUTE.x, "z": CLAW_CHUTE.y, "drop": 0.0, "grab": -1, "shake": 0.0, "until": 0.0, "bump": 0.0}
	gacha = [{"ready": 0.0, "crank": -10.0}, {"ready": 0.0, "crank": -10.0}]
	hoop = {"until": 0.0, "running": false, "scores": {}, "shake": 0.0, "offset": 0.0, "bump": 0.0}


# ─────────────────────────────── 위치 도우미 ───────────────────────────────

static func claw_world(x: float, z: float, drop: float) -> Vector3:
	return CLAW_AT + Vector3(x, lerpf(CLAW_TOP, CLAW_LOW, drop), z)


static func plush_spot(slot: int) -> Vector3:
	var local: Vector3 = PLUSH_SPOTS[slot % PLUSH_SPOTS.size()]
	return CLAW_AT + local


static func gacha_crank(machine: int) -> Vector3:
	return GACHA_AT[machine] + GACHA_CRANK


static func gacha_tray(machine: int) -> Vector3:
	return GACHA_AT[machine] + GACHA_TRAY


## 유리구슬 안 캡슐 자리. 번호마다 조금씩 다른 곳에 쌓인다.
static func globe_spot(machine: int, slot: int) -> Vector3:
	var angle: float = slot * 2.4
	return GACHA_AT[machine] + Vector3(cos(angle) * 0.12, GACHA_GLOBE_Y - 0.1 + (slot % 3) * 0.07, sin(angle) * 0.12)


func hoop_center() -> Vector3:
	return HOOP_RING + Vector3(float(hoop.offset), 0.0, 0.0)


## 상호작용 지점(LoungeWorld.focus 후보).
static func focus_points() -> Array[Dictionary]:
	return [{"kind": "claw", "at": CLAW_PANEL}, {"kind": "gacha", "index": 0, "at": gacha_crank(0)},
		{"kind": "gacha", "index": 1, "at": gacha_crank(1)}, {"kind": "hoop", "at": HOOP_BUTTON}]


# ─────────────────────────────── 입력(방장) ───────────────────────────────

## 기계 버튼(상호작용 키, 기본 F). 같은 키가 상황에 따라 "시작 → 멈춤 → 내리기" 또는 "흔들어 방해"가 된다. 처리했으면 true.
func accept(sender: int, kind: String, value: Variant) -> bool:
	var actor: PlayerView = lounge.game.actors.get(sender)
	if actor == null: return false
	var now: float = lounge.now()
	match kind:
		"claw":
			var phase: String = claw.phase
			if phase == "idle":
				claw.phase = "x"
				claw.operator = sender
				claw.t = now
				claw.until = now + CLAW_PLAY_TIME
				claw.x = -CLAW_PIT.x
				claw.z = -CLAW_PIT.y
				claw.grab = -1
				lounge.feed("claw", actor, "인형뽑기 도전!")
				lounge.fx("sound", CLAW_PANEL, Vector3.ZERO, Color.WHITE, "coin")
				return true
			if sender == int(claw.operator) and phase == "x":
				claw.phase = "z"
				claw.t = now
				lounge.fx("sound", CLAW_PANEL, Vector3.ZERO, Color.WHITE, "squeak")
				return true
			if sender == int(claw.operator) and phase == "z":
				_claw_drop(now)
				return true
			if sender != int(claw.operator) and now >= float(claw.bump):
				# 남이 기계를 쾅! 흔들면 집게 힘이 빠진다(휴먼 폴 플랫식 방해).
				claw.shake = now + 1.4
				claw.bump = now + BUMP_GAP
				lounge.feed("claw", actor, "기계를 쾅! 흔들었다", lounge.game.actors.get(int(claw.operator)))
				lounge.fx("sound", CLAW_PANEL, Vector3.ZERO, Color.WHITE, "thunk")
				return true
		"gacha":
			var machine: int = clampi(int(value) if value is int else 0, 0, GACHA_AT.size() - 1)
			var state: Dictionary = gacha[machine]
			if now < float(state.ready): return false
			var capsule: int = _capsule_in(machine)
			if capsule < 0:
				capsule = _capsule_in(1 - machine)
			if capsule < 0:
				lounge.feed("capsule", actor, "가챠가 텅 비었어요")
				state.ready = now + 1.0
				return true
			state.ready = now + GACHA_COOLDOWN
			state.crank = now
			var object: Dictionary = lounge.objects[capsule]
			object.locked = false
			object.machine = machine
			object.effect = _pick_effect()
			object.position = gacha_tray(machine)
			object.available = now + 0.8
			object.rest_at = now
			lounge.feed("capsule", actor, "가챠 드르륵…")
			lounge.fx("sound", gacha_crank(machine), Vector3.ZERO, Color.WHITE, "crank")
			return true
		"hoop":
			if not bool(hoop.running):
				hoop.running = true
				hoop.until = now + HOOP_TIME
				hoop.scores = {}
				lounge.feed("hoop", actor, "HOOP FEVER 시작! 30초")
				lounge.fx("sound", HOOP_BUTTON, Vector3.ZERO, Color.WHITE, "buzzer")
				return true
			if now >= float(hoop.bump):
				hoop.shake = now + 2.2
				hoop.bump = now + BUMP_GAP
				lounge.feed("hoop", actor, "골대를 흔들었다")
				lounge.fx("sound", HOOP_RING, Vector3.ZERO, Color.WHITE, "thunk")
				return true
	return false


## E 키 안내 글자(HUD).
func prompt(peer_id: int, kind: String) -> String:
	var now: float = lounge.now()
	match kind:
		"claw":
			match str(claw.phase):
				"idle": return "인형뽑기 시작  (E 가로 멈춤 → E 세로 멈춤)"
				"x": return "가로 멈추기" if peer_id == int(claw.operator) else "기계 흔들어 방해하기"
				"z": return "세로 멈추고 집게 내리기" if peer_id == int(claw.operator) else "기계 흔들어 방해하기"
			return "집게 움직이는 중… (흔들어 방해 가능)" if peer_id != int(claw.operator) else "두근두근…"
		"gacha":
			return "가챠 돌리기 · 캡슐은 던지거나 직접 열어요"
		"hoop":
			if bool(hoop.running): return "골대 흔들어 방해하기 · %.0f초 남음" % maxf(0.0, float(hoop.until) - now)
			return "HOOP FEVER 시작 · 30초 동안 골 넣기"
	return ""


# ─────────────────────────────── 매 프레임(방장) ───────────────────────────────

func step(delta: float) -> void:
	var now: float = lounge.now()
	_step_claw(delta, now)
	_step_hoop(now)
	# 밖에 오래 굴러다닌 인형·캡슐은 기계로 돌아간다(다시 뽑을 수 있게).
	for index in range(lounge.objects.size()):
		var object: Dictionary = lounge.objects[index]
		if int(object.holder) != 0 or bool(object.get("locked", false)) or lounge.is_flying(index): continue
		var kind: String = object.kind
		if kind == "plush" and now - float(object.get("rest_at", now)) > PLUSH_RETURN: return_plush(index)
		elif kind == "capsule" and now - float(object.get("rest_at", now)) > CAPSULE_RETURN: return_capsule(index)


func _step_claw(delta: float, now: float) -> void:
	var phase: String = claw.phase
	if phase == "idle": return
	var operator: PlayerView = lounge.game.actors.get(int(claw.operator))
	# 조종하던 사람이 나가거나 시간이 다 되면 그 자리에서 내린다. 맞아서 스턴되면 집게가 덜컥 떨어진다.
	if phase in ["x", "z"] and (operator == null or now >= float(claw.until)):
		_claw_drop(now)
		return
	if phase in ["x", "z"] and operator != null and lounge.is_stunned(int(claw.operator)):
		lounge.feed("claw", operator.identity, "맞아서 집게가 덜컥!")
		_claw_drop(now)
		return
	var age: float = now - float(claw.t)
	match phase:
		"x":
			claw.x = -CLAW_PIT.x + pingpong(age * CLAW_SWEEP, CLAW_PIT.x * 2.0)
		"z":
			claw.z = -CLAW_PIT.y + pingpong(age * CLAW_SWEEP, CLAW_PIT.y * 2.0)
		"drop":
			claw.drop = clampf(age / 1.0, 0.0, 1.0)
			if age >= 1.0:
				_claw_grab(now)
		"lift":
			claw.drop = 1.0 - clampf(age / 0.8, 0.0, 1.0)
			var grabbed: int = int(claw.grab)
			if grabbed >= 0:
				# 흔들리는 중이면 매 순간 미끄러질 수 있다.
				if now < float(claw.shake) and _rng.randf() < delta * 1.6:
					_claw_slip(grabbed, now)
			if age >= 0.8:
				# 진짜 인형뽑기처럼 꼭대기에서 힘이 한 번 빠진다(기본 15%).
				if int(claw.grab) >= 0 and _rng.randf() < 0.15:
					_claw_slip(int(claw.grab), now)
				claw.phase = "carry"
				claw.t = now
		"carry":
			var target := Vector2(CLAW_CHUTE.x, CLAW_CHUTE.y)
			var at := Vector2(float(claw.x), float(claw.z)).move_toward(target, delta * 0.5)
			claw.x = at.x
			claw.z = at.y
			if at.distance_to(target) < 0.01:
				_claw_release(now)
		"release":
			if age >= 0.7:
				claw.phase = "idle"
				claw.operator = 0
	var grabbed_now: int = int(claw.grab)
	if grabbed_now >= 0:
		lounge.objects[grabbed_now].position = claw_world(float(claw.x), float(claw.z), float(claw.drop)) + Vector3.DOWN * 0.17


func _claw_drop(now: float) -> void:
	claw.phase = "drop"
	claw.t = now
	lounge.fx("sound", CLAW_PANEL, Vector3.ZERO, Color.WHITE, "motor")


func _claw_grab(now: float) -> void:
	claw.phase = "lift"
	claw.t = now
	var best: int = -1
	var best_distance: float = INF
	for index in range(lounge.objects.size()):
		var object: Dictionary = lounge.objects[index]
		if object.kind != "plush" or not bool(object.get("locked", false)): continue
		var position: Vector3 = object.position
		var distance: float = Vector2(position.x - CLAW_AT.x - float(claw.x), position.z - CLAW_AT.z - float(claw.z)).length()
		if distance < best_distance:
			best_distance = distance
			best = index
	var chance: float = 0.8 if best_distance < 0.07 else (0.45 if best_distance < 0.15 else 0.0)
	if now < float(claw.shake): chance *= 0.35
	if best >= 0 and _rng.randf() < chance:
		claw.grab = best
		lounge.fx("sound", CLAW_PANEL, Vector3.ZERO, Color.WHITE, "squeak")
	else:
		claw.grab = -1


func _claw_slip(index: int, now: float) -> void:
	claw.grab = -1
	var slot: int = int(lounge.objects[index].get("slot", 0))
	lounge.objects[index].position = plush_spot(slot)
	var operator: PlayerView = lounge.game.actors.get(int(claw.operator))
	lounge.feed("claw", operator.identity if operator != null else null, "아깝다! 인형이 미끄러졌다")
	lounge.fx("sound", CLAW_PANEL, Vector3.ZERO, Color.WHITE, "bounce")
	claw.t = minf(float(claw.t), now)


func _claw_release(now: float) -> void:
	claw.phase = "release"
	claw.t = now
	var grabbed: int = int(claw.grab)
	claw.grab = -1
	var operator: PlayerView = lounge.game.actors.get(int(claw.operator))
	if grabbed < 0:
		lounge.feed("claw", operator.identity if operator != null else null, "빈 집게… 다음 기회에")
		return
	var object: Dictionary = lounge.objects[grabbed]
	object.locked = false
	object.position = CLAW_DOOR
	object.available = now + 0.4
	object.rest_at = now
	lounge.feed("plush", operator.identity if operator != null else null, "인형 획득! 던지면 얼굴을 가려요")
	lounge.fx("confetti", CLAW_DOOR + Vector3.UP * 0.4, Vector3.BACK, Color.WHITE, "fanfare")


func return_plush(index: int) -> void:
	var object: Dictionary = lounge.objects[index]
	object.locked = true
	object.holder = 0
	object.position = plush_spot(int(object.get("slot", 0)))
	object.lying = false


func return_capsule(index: int) -> void:
	var object: Dictionary = lounge.objects[index]
	var machine: int = 0 if _count_in(0) <= _count_in(1) else 1
	object.locked = true
	object.holder = 0
	object.machine = machine
	object.effect = ""
	object.position = globe_spot(machine, int(object.get("slot", 0)))
	object.lying = false


func _capsule_in(machine: int) -> int:
	for index in range(lounge.objects.size()):
		var object: Dictionary = lounge.objects[index]
		if object.kind == "capsule" and bool(object.get("locked", false)) and int(object.get("machine", 0)) == machine: return index
	return -1


func _count_in(machine: int) -> int:
	var count: int = 0
	for object in lounge.objects:
		if object.kind == "capsule" and bool(object.get("locked", false)) and int(object.get("machine", 0)) == machine: count += 1
	return count


func _pick_effect() -> String:
	var total: int = 0
	for entry in CAPSULE_EFFECTS: total += int(entry[1])
	var roll: int = _rng.randi_range(1, total)
	for entry in CAPSULE_EFFECTS:
		roll -= int(entry[1])
		if roll <= 0: return str(entry[0])
	return "blank"


func _step_hoop(now: float) -> void:
	var running: bool = bool(hoop.running)
	var left: float = float(hoop.until) - now
	# 마지막 12초는 골대가 좌우로 움직인다(실제 오락기 2단계처럼). 흔들기 방해는 빠르게 떨린다.
	var offset: float = 0.0
	if running and left < 12.0: offset += sin(now * 2.4) * 0.26
	if now < float(hoop.shake): offset += sin(now * 21.0) * 0.12
	hoop.offset = offset
	if running and left <= 0.0:
		hoop.running = false
		var best_peer: int = 0
		var best: int = -1
		for peer in hoop.scores:
			if int(hoop.scores[peer]) > best:
				best = int(hoop.scores[peer])
				best_peer = int(peer)
		var winner: PlayerView = lounge.game.actors.get(best_peer)
		if winner != null and best > 0:
			lounge.feed("trophy", winner.identity, "HOOP FEVER 1등 · %d점" % best)
		else:
			lounge.feed("hoop", null, "HOOP FEVER 끝 · 골이 없었어요")
		lounge.fx("confetti", HOOP_RING, Vector3.BACK, Color.WHITE, "fanfare")


## 농구공이 한 걸음 움직일 때 부른다. 링 높이를 위에서 아래로 지나며 링 안이면 골.
func ball_moved(projectile: Dictionary, from: Vector3, to: Vector3) -> void:
	if bool(projectile.get("scored", false)) or from.y < HOOP_RING.y or to.y >= HOOP_RING.y: return
	var ratio: float = (from.y - HOOP_RING.y) / maxf(0.0001, from.y - to.y)
	var cross: Vector3 = from.lerp(to, ratio)
	var center: Vector3 = hoop_center()
	if Vector2(cross.x - center.x, cross.z - center.z).length() > HOOP_RADIUS: return
	projectile.scored = true
	var owner: int = int(projectile.owner)
	var origin: Vector3 = projectile.origin
	var points: int = 3 if Vector2(origin.x - center.x, origin.z - center.z).length() > THREE_POINT else 2
	var actor: PlayerView = lounge.game.actors.get(owner)
	if bool(hoop.running):
		hoop.scores[owner] = int(hoop.scores.get(owner, 0)) + points
		lounge.feed("hoop", actor.identity if actor != null else null, "골! +%d  (합계 %d)" % [points, int(hoop.scores[owner])])
	else:
		lounge.feed("hoop", actor.identity if actor != null else null, "골! (버튼을 눌러 HOOP FEVER)")
	lounge.fx("stars", center, Vector3.DOWN, Color.WHITE, "swish")


## 공이 기계 안(경사판)에 떨어지면 앞쪽 공 받침으로 굴러 내려온다.
static func in_hoop_machine(point: Vector3) -> bool:
	return HOOP_FOOTPRINT.has_point(Vector2(point.x, point.z))


# ─────────────────────────────── 네트워크 ───────────────────────────────

## 절대 시각 → 남은 초(컴퓨터마다 시계가 달라 남은 시간으로 보낸다).
func to_public() -> Dictionary:
	var now: float = lounge.now()
	var public_claw := claw.duplicate()
	for key in ["until", "shake", "bump"]: public_claw[key] = maxf(0.0, float(claw[key]) - now)
	public_claw.t = now - float(claw.t)
	var public_gacha: Array = []
	for state in gacha:
		public_gacha.append({"ready": maxf(0.0, float(state.ready) - now), "crank": now - float(state.crank)})
	var public_hoop := hoop.duplicate(true)
	for key in ["until", "shake", "bump"]: public_hoop[key] = maxf(0.0, float(hoop[key]) - now)
	return {"claw": public_claw, "gacha": public_gacha, "hoop": public_hoop}


func from_public(data: Dictionary) -> void:
	var now: float = lounge.now()
	if data.has("claw"):
		claw = data.claw.duplicate()
		for key in ["until", "shake", "bump"]: claw[key] = now + float(claw.get(key, 0.0))
		claw.t = now - float(claw.get("t", 0.0))
	if data.has("gacha"):
		gacha.clear()
		for state in data.gacha:
			gacha.append({"ready": now + float(state.ready), "crank": now - float(state.crank)})
	if data.has("hoop"):
		hoop = data.hoop.duplicate(true)
		for key in ["until", "shake", "bump"]: hoop[key] = now + float(hoop.get(key, 0.0))
