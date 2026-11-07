extends RefCounted
## 네온 오락실(테마 1) 기계 3종의 규칙: 인형뽑기 · 가챠(캡슐뽑기) · 농구 오락기.
## 방장만 계산한다. 결과(상태 사전)는 LoungeWorld 가 0.1초마다 소품과 함께 모두에게 보낸다.
##
## [놀이 설계 — 참고한 게임]
##   갱비스트 · 휴먼 폴 플랫 : 서로 밀치고 흔들어 방해한다 → 다른 사람이 기계를 "흔들면" 집게가 미끄러지고 골대가 흔들린다.
##   R.E.P.O              : 물건을 들고 던지는 몸 개그 → 뽑은 인형·캡슐·농구공은 전부 던질 수 있는 소품이 된다.
##   라이어스 바           : 운에 거는 한 판 → 가챠 캡슐은 열기 전까지 무엇이 나올지 모른다(왕머리·먹물·빙글빙글·폭죽·꽝).
## 기계 놀이는 다트 점수와 섞지 않는다(밸런스는 팀 확정 전). 오락실 순위·킬로그·장난 효과만 만든다.
##
## [2026-11-07 조작감 개편 — 사용자 "디자인과 상호작용 느낌이 이상해"]
##   인형뽑기: 예전엔 집게가 혼자 왔다 갔다 하고 F 로 "가로 멈춤 → 세로 멈춤"을 맞히는 타이밍 놀이였다(진짜 기계와 다름).
##            → 조작판 앞에서 F 로 시작하면 WASD 가 몸 대신 집게를 직접 움직이고(steer), F 를 다시 누르면 내린다.
##            제한 시간(CLAW_PLAY_TIME)이 끝나면 그 자리에서 저절로 내린다. 집게 바로 아래 바닥에 조준 표시가 뜬다(그림).
##   가챠    : 예전엔 손잡이를 돌리는 순간 캡슐이 받침에 "순간이동"했다.
##            → 손잡이가 한 바퀴 도는 동안 캡슐이 유리구슬 → 배출구 → 받침으로 굴러 나온다(GACHA_DROP 초).
##            기계는 식탁 위에서 옆을 보던 것을 진열대 앞쪽에 나란히 세워 통로 쪽(-Z)을 보게 했다(디자인 요청서 3.3).
##   농구    : 예전엔 던지는 힘·방향만으로 넣어야 해 거의 안 들어갔다.
##            → 골대 쪽으로 던지면 오락기처럼 포물선을 보정(assist_throw)해 준다 — 힘 조절이 맞을수록 깨끗이 들어간다.
##            림에 걸리면 "탕" 튕겨 나오고(ball_moved 림 판정), 골이 들어가면 그물이 출렁인다(그림).

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
## 조종 시간(초)과 집게 이동 속도(m/s). 유리 안 끝에서 끝(0.76m)까지 약 2초.
const CLAW_PLAY_TIME: float = 15.0
const CLAW_SPEED: float = 0.38
## 유리 안 인형 자리(기계 기준 x, 높이, z).
const PLUSH_SPOTS: Array[Vector3] = [Vector3(0.1, 1.07, 0.12), Vector3(0.24, 1.07, -0.12), Vector3(-0.12, 1.07, 0.18)]
const PLUSH_RETURN: float = 40.0

# ───── 가챠(NPC 테이블 자리의 진열대 위 두 대, 앞면 = -Z) ─────
## 2026-11-07 디자인 요청서 3.3: "가챠 2대 + 독립 받침대, 전면 -Z". 진열대(충돌 = TableView.NPC_TABLE_BOX, 높이 0.85m)
## 앞쪽 가장자리에 나란히 세워 다트 홀 쪽 통로(z ≈ 3)에서 바로 손잡이를 돌린다. 예전엔 식탁 위에서 옆(-X)을 봤다.
const GACHA_AT: Array[Vector3] = [Vector3(5.4, 0.85, 3.68), Vector3(6.15, 0.85, 3.68)]
## 기계 기준(앞 = -Z): 손잡이(앞면 가운데 왼쪽) · 받침(앞면 오른쪽 아래) · 배출구(받침 위 몸통 속).
const GACHA_CRANK := Vector3(-0.08, 0.3, -0.3)
const GACHA_TRAY := Vector3(0.13, 0.07, -0.37)
const GACHA_EXIT := Vector3(0.13, 0.2, -0.24)
const GACHA_GLOBE_Y: float = 0.78
const GACHA_COOLDOWN: float = 3.0
## 손잡이를 돌리고 캡슐이 받침에 닿기까지(초). 구슬 속에서 덜컹 → 목으로 빠짐 → 배출구에서 데굴.
const GACHA_DROP: float = 1.1
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
## 던지기 보정: 골대 쪽(수평 각도 ASSIST_ANGLE 라디안 안, 거리 ASSIST_RANGE 안)으로 던지면 링을 지나는 포물선으로 고쳐 준다.
## 힘(0~1)이 그 거리에 맞는 힘(ideal)과 ASSIST_TOLERANCE 넘게 다르면 그만큼 짧게/길게 날아가 림·백보드에 맞는다.
const ASSIST_ANGLE: float = 0.3
const ASSIST_RANGE := Vector2(0.8, 6.5)
const ASSIST_APEX: float = 0.7
const ASSIST_TOLERANCE: float = 0.12
## 림 두께: 링 안쪽 가장자리 RIM_INSIDE ~ 바깥 RIM_BAND 사이를 지나면 "탕" 튕긴다(공 반지름 때문에 안쪽 가장자리도 걸린다).
const RIM_INSIDE: float = 0.08
const RIM_BAND: float = 0.07
## 공 하나가 림에 튕길 수 있는 최대 횟수(무한히 림 위에서 춤추지 않게).
const RIM_LIMIT: int = 3

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


## stick_x/stick_z = 조이스틱 기울기(-1~1, 그림용). pending = 받침으로 굴러 나오는 중인 캡슐 번호(-1 = 없음).
## goal/rim = 마지막 골·림 튕김 시각(그물 출렁임·링 떨림 그림용).
func reset() -> void:
	claw = {"phase": "idle", "operator": 0, "t": 0.0, "x": CLAW_CHUTE.x, "z": CLAW_CHUTE.y, "drop": 0.0, "grab": -1, "shake": 0.0, "until": 0.0, "bump": 0.0,
		"stick_x": 0.0, "stick_z": 0.0}
	gacha = [{"ready": 0.0, "crank": -10.0, "pending": -1}, {"ready": 0.0, "crank": -10.0, "pending": -1}]
	hoop = {"until": 0.0, "running": false, "scores": {}, "shake": 0.0, "offset": 0.0, "bump": 0.0, "goal": -10.0, "rim": -10.0}


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


## 굴러 나오는 캡슐의 자리(t = 0 손잡이 돌린 순간 ~ 1 받침 도착). 구슬 속 → 목 → 배출구 → 받침(작게 통통).
static func gacha_path(machine: int, start: Vector3, t: float) -> Vector3:
	var neck: Vector3 = GACHA_AT[machine] + Vector3(0, GACHA_GLOBE_Y - 0.24, 0)
	var exit: Vector3 = GACHA_AT[machine] + GACHA_EXIT
	if t < 0.4:
		# 구슬 속에서 덜컹거리며 목 쪽으로 내려간다.
		var k: float = t / 0.4
		return start.lerp(neck, k * k) + Vector3(sin(k * 19.0) * 0.015, 0, 0)
	if t < 0.75:
		return neck.lerp(exit, smoothstep(0.0, 1.0, (t - 0.4) / 0.35))
	var roll: float = clampf((t - 0.75) / 0.25, 0.0, 1.0)
	return exit.lerp(gacha_tray(machine), roll) + Vector3.UP * absf(sin(roll * PI * 2.0)) * 0.05 * (1.0 - roll)


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


# ─────────────────────────────── 조종(방장) ───────────────────────────────

## 이 사람이 지금 인형뽑기를 조종 중인가(집게 이동 단계의 조종자).
## LoungeWorld.focus 는 조종자에게 늘 조작판을 돌려준다 — 고개를 돌려 유리 속을 봐도 F 가 "내리기"로 남게.
func operating(peer_id: int) -> bool:
	return str(claw.phase) == "move" and int(claw.operator) == peer_id


## 방장: 조종자의 WASD(이동 입력)로 집게를 움직인다. 처리했으면 true → GameView 가 그 사람 몸 이동을 막는다.
## 방향은 "걷는 방향" 그대로다(바라보는 쪽 기준 W = 앞) — 기계를 보고 서 있으면 W = 안쪽, D = 오른쪽.
func steer(peer_id: int, controls: Dictionary, delta: float) -> bool:
	if not operating(peer_id): return false
	var move: Vector2 = controls.get("move") if controls.get("move") is Vector2 else Vector2.ZERO
	var actor: PlayerView = lounge.game.actors.get(peer_id)
	var yaw: float = float(controls.get("yaw")) if controls.get("yaw") is float else (actor.rotation.y if actor != null else PI)
	var world: Vector3 = Basis(Vector3.UP, yaw) * Vector3(move.x, 0.0, move.y)
	claw.x = clampf(float(claw.x) + world.x * CLAW_SPEED * delta, -CLAW_PIT.x, CLAW_PIT.x)
	claw.z = clampf(float(claw.z) + world.z * CLAW_SPEED * delta, -CLAW_PIT.y, CLAW_PIT.y)
	claw.stick_x = world.x
	claw.stick_z = world.z
	return true


## 방장: 농구공을 골대 쪽으로 던졌으면 오락기처럼 포물선을 보정한다. 아니면 velocity 그대로 돌려준다.
## from = 던지는 자리, charge = 우클릭을 누른 힘(0~1).
func assist_throw(from: Vector3, velocity: Vector3, charge: float) -> Vector3:
	var center: Vector3 = hoop_center()
	var flat := Vector2(center.x - from.x, center.z - from.z)
	var distance: float = flat.length()
	var throw_flat := Vector2(velocity.x, velocity.z)
	if distance < ASSIST_RANGE.x or distance > ASSIST_RANGE.y or throw_flat.length() < 0.5: return velocity
	var turn: float = throw_flat.angle_to(flat)
	if absf(turn) > ASSIST_ANGLE: return velocity
	# 링 위 ASSIST_APEX 까지 올라갔다가 링 가운데로 떨어지는 포물선(중력 9.8 = LoungeWorld.GRAVITY).
	var gravity: float = 9.8
	var apex: float = maxf(from.y, center.y) + ASSIST_APEX
	var rise: float = sqrt(2.0 * gravity * (apex - from.y))
	var flight: float = rise / gravity + sqrt(2.0 * (apex - center.y) / gravity)
	# 힘 조절: 이 거리에 맞는 힘(가까우면 약하게, 멀면 세게)과의 차이만큼 길게/짧게 → 많이 틀리면 림·백보드.
	var ideal: float = clampf(remap(distance, ASSIST_RANGE.x, ASSIST_RANGE.y, 0.2, 0.9), 0.15, 0.95)
	var error: float = charge - ideal
	var reach: float = 1.0 if absf(error) <= ASSIST_TOLERANCE else 1.0 + (error - signf(error) * ASSIST_TOLERANCE) * 0.55
	# 좌우는 던진 방향을 반쯤 남긴다(대충 던지면 옆으로 빗나간다).
	var horizontal: Vector2 = flat.rotated(-turn * 0.5) / flight * reach
	return Vector3(horizontal.x, rise, horizontal.y)


# ─────────────────────────────── 입력(방장) ───────────────────────────────

## 기계 버튼(상호작용 키, 기본 F). 같은 키가 상황에 따라 "시작 → 내리기" 또는 "흔들어 방해"가 된다. 처리했으면 true.
func accept(sender: int, kind: String, value: Variant) -> bool:
	var actor: PlayerView = lounge.game.actors.get(sender)
	if actor == null: return false
	var now: float = lounge.now()
	match kind:
		"claw":
			var phase: String = claw.phase
			if phase == "idle":
				# 시작: 집게는 상품 구멍 위(앞 왼쪽)에서 출발한다. 이제부터 이 사람의 WASD 는 집게 조이스틱이다(steer).
				claw.phase = "move"
				claw.operator = sender
				claw.t = now
				claw.until = now + CLAW_PLAY_TIME
				claw.x = CLAW_CHUTE.x
				claw.z = CLAW_CHUTE.y
				claw.grab = -1
				lounge.feed("claw", actor, "인형뽑기 도전!")
				lounge.fx("sound", CLAW_PANEL, Vector3.ZERO, Color.WHITE, "coin")
				return true
			if sender == int(claw.operator) and phase == "move":
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
			# 캡슐은 바로 받침에 나타나지 않고 굴러 나온다(_step_gacha). 굴러가는 동안은 잠긴 채라 아무도 못 집는다.
			state.pending = capsule
			var object: Dictionary = lounge.objects[capsule]
			object.machine = machine
			object.effect = _pick_effect()
			object.dropping = true
			object.drop_from = object.position
			object.available = now + GACHA_DROP + 0.1
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


## 상호작용 키 안내 글자(HUD 가 [키, 이 글자] 로 보여 준다 — 키 이름은 설정에서 바뀌므로 여기 적지 않는다).
## 2026-11-07: 예전 글자에 남아 있던 "E" 를 뺐다(상호작용 키는 2026-10-31 부터 F, 설정에서 바꿀 수 있다).
func prompt(peer_id: int, kind: String) -> String:
	var now: float = lounge.now()
	match kind:
		"claw":
			match str(claw.phase):
				"idle": return "인형뽑기 시작 (WASD 로 집게 이동 → 한 번 더 누르면 내리기)"
				"move":
					if peer_id == int(claw.operator):
						return "집게 내리기 · WASD 이동 · %d초" % ceili(maxf(0.0, float(claw.until) - now))
					return "기계 쾅! 흔들어 방해하기"
			return "집게 움직이는 중… (흔들어 방해 가능)" if peer_id != int(claw.operator) else "두근두근…"
		"gacha":
			return "가챠 손잡이 돌리기 · 캡슐은 던져 맞히거나 직접 열어요"
		"hoop":
			if bool(hoop.running): return "골대 흔들어 방해하기 · %.0f초 남음" % maxf(0.0, float(hoop.until) - now)
			return "HOOP FEVER 시작 · 30초 동안 골 넣기"
	return ""


# ─────────────────────────────── 매 프레임(방장) ───────────────────────────────

func step(delta: float) -> void:
	var now: float = lounge.now()
	_step_claw(delta, now)
	_step_gacha(now)
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
	if phase == "move" and (operator == null or now >= float(claw.until)):
		_claw_drop(now)
		return
	if phase == "move" and operator != null and lounge.is_stunned(int(claw.operator)):
		lounge.feed("claw", operator.identity, "맞아서 집게가 덜컥!")
		_claw_drop(now)
		return
	var age: float = now - float(claw.t)
	match phase:
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
	# 조이스틱은 가운데로(내리는 동안에는 못 움직인다).
	claw.stick_x = 0.0
	claw.stick_z = 0.0
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
	object.dropping = false
	object.locked = true
	object.holder = 0
	object.machine = machine
	object.effect = ""
	object.position = globe_spot(machine, int(object.get("slot", 0)))
	object.lying = false


## 이 기계 구슬 속에 남은 캡슐 하나(굴러 나오는 중인 것은 뺀다).
func _capsule_in(machine: int) -> int:
	for index in range(lounge.objects.size()):
		var object: Dictionary = lounge.objects[index]
		if object.kind != "capsule" or not bool(object.get("locked", false)) or bool(object.get("dropping", false)): continue
		if int(object.get("machine", 0)) == machine: return index
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


## 굴러 나오는 캡슐(방장): 손잡이를 돌린 뒤 GACHA_DROP 초 동안 길을 따라 옮기고, 받침에 닿으면 풀어 준다.
func _step_gacha(now: float) -> void:
	for machine in range(gacha.size()):
		var state: Dictionary = gacha[machine]
		var capsule: int = int(state.get("pending", -1))
		if capsule < 0 or capsule >= lounge.objects.size(): continue
		var object: Dictionary = lounge.objects[capsule]
		var t: float = (now - float(state.crank)) / GACHA_DROP
		if t < 1.0:
			object.position = gacha_path(machine, object.get("drop_from", globe_spot(machine, int(object.get("slot", 0)))), t)
			continue
		state.pending = -1
		object.dropping = false
		object.locked = false
		object.position = gacha_tray(machine)
		object.rest_at = now
		lounge.fx("sound", gacha_tray(machine), Vector3.ZERO, Color.WHITE, "pop")
		lounge.feed("capsule", null, "캡슐 데굴! 직접 열거나 던져서 맞혀요")


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
## 링 가장자리(림)를 지나면 튕겨 낸다 → true 를 돌려주면 LoungeWorld 가 공을 림 위(projectile.rim_at)로 옮긴다.
func ball_moved(projectile: Dictionary, from: Vector3, to: Vector3) -> bool:
	if bool(projectile.get("scored", false)) or from.y < HOOP_RING.y or to.y >= HOOP_RING.y: return false
	var ratio: float = (from.y - HOOP_RING.y) / maxf(0.0001, from.y - to.y)
	var cross: Vector3 = from.lerp(to, ratio)
	var center: Vector3 = hoop_center()
	var off := Vector2(cross.x - center.x, cross.z - center.z)
	var radius: float = off.length()
	# 공 반지름(0.12) 때문에 링 안쪽이라도 가장자리에 가까우면 림에 걸린다 — 진짜 농구처럼 "탕".
	if radius > HOOP_RADIUS - RIM_INSIDE and radius < HOOP_RADIUS + RIM_BAND and int(projectile.get("rims", 0)) < RIM_LIMIT:
		var outward := Vector3(off.x, 0.0, off.y).normalized() if radius > 0.001 else Vector3.BACK
		var velocity: Vector3 = projectile.velocity
		# 위로 힘 빠지게 튀고 보통은 링 바깥으로 밀린다. 안쪽 가장자리를 맞은 공은 가끔 안으로 굴러 들어간다.
		var inward: bool = radius < HOOP_RADIUS - 0.02 and _rng.randf() < 0.45
		projectile.velocity = Vector3(0, absf(velocity.y) * 0.45 + 0.6, 0) + (-outward if inward else outward) * (0.9 + _rng.randf() * 0.5)
		projectile.rims = int(projectile.get("rims", 0)) + 1
		projectile.rim_at = Vector3(cross.x, HOOP_RING.y + 0.03, cross.z)
		hoop.rim = lounge.now()
		lounge.fx("sound", cross, Vector3.ZERO, Color.WHITE, "bounce")
		return true
	if radius > HOOP_RADIUS: return false
	projectile.scored = true
	hoop.goal = lounge.now()
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
	return false


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
		public_gacha.append({"ready": maxf(0.0, float(state.ready) - now), "crank": now - float(state.crank), "pending": int(state.get("pending", -1))})
	var public_hoop := hoop.duplicate(true)
	for key in ["until", "shake", "bump"]: public_hoop[key] = maxf(0.0, float(hoop[key]) - now)
	# 마지막 골·림 시각은 "몇 초 전"으로 보낸다(그물 출렁임 그림).
	for key in ["goal", "rim"]: public_hoop[key] = now - float(hoop.get(key, -10.0))
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
			gacha.append({"ready": now + float(state.ready), "crank": now - float(state.crank), "pending": int(state.get("pending", -1))})
	if data.has("hoop"):
		hoop = data.hoop.duplicate(true)
		for key in ["until", "shake", "bump"]: hoop[key] = now + float(hoop.get(key, 0.0))
		for key in ["goal", "rim"]: hoop[key] = now - float(hoop.get(key, 10.0))
