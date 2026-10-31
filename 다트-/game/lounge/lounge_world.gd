extends Node3D
## 방 안의 모니터·주크박스·소품·오락실 기계. 입력의 거리/소유권/쿨다운/적중은 방장이 확정한다.
##
## [소품 물리 — 2026-10-30]
## 모든 소품은 던질 수 있다(우클릭 꾹 = 힘 모으기 · 짧게 = 살짝 놓기). 방장이 포물선 + 광선 검사로 한 걸음씩 옮긴다.
## 병·큐대는 깨진다: 세게 부딪힘(BREAK_SPEED) · 높은 곳에서 떨어짐(BREAK_FALL) · 멀리 날아감(BREAK_DISTANCE) · 파워 카드.
## 깨진 소품은 RESPAWN 초 뒤 제자리에 새것으로 돌아온다. 공·농구공·인형·캡슐은 튕긴다.
## 맞은 사람은 잠깐 스턴 + 밀려나고(knockback), 들고 있던 소품을 떨어뜨린다(갱비스트식 몸싸움).
##
## [네온 오락실 — 테마 1]
## 펍의 바·NPC 자리·당구대·럼주통 그림을 빼고 오락실 물건을 세운다(arcade/arcade_room.gd).
## 인형뽑기·가챠·농구 오락기 규칙은 arcade/arcade_rules.gd. 뽑은 인형·캡슐·농구공은 모두 소품이다.
##
## [도면 v3 — 2026-10-31 밤, 에셋 소품]
## 맥주잔(mug): 바 위 컵받침에 놓인 나무 잔(RG Poly). 병처럼 한 모금 마신다. 세게 던지면 깨지지 않고 "쏟아진다"
##   (맥주 웅덩이 + 툭 소리) → 빈 잔은 치워지고 RESPAWN 초 뒤 새로 채운 잔이 바 컵받침에 다시 놓인다.
## 건드리기(touch): 바 종 · 럼주통 · 생맥주 통 · 연습 과녁 · 축음기에 다가가 상호작용 키(F) → 소리 + 그 물건이 흔들린다.
##   모든 화면에서 같은 소리·흔들림(방장이 fx 이벤트로 알린다). 점수·규칙에는 영향이 없는 "만지는 재미"용이다.
const Kit = preload("res://art/mesh_kit.gd")
const Preferences = preload("res://ui/player_preferences.gd")
const Bridge = preload("res://game/lounge/youtube_bridge.gd")
const Rules = preload("res://game/lounge/arcade/arcade_rules.gd")
const ArcadeRoom = preload("res://game/lounge/arcade/arcade_room.gd")
const Looks = preload("res://game/lounge/prop_looks.gd")
const BurstFx = preload("res://art/fx/burst_fx.gd")
const Sfx = preload("res://art/audio/sfx.gd")
const MONITOR := Vector3(-4.35, 1.35, 2.0)
const JUKEBOX := Vector3(7.8, 0, 1.1)
const REACH: float = 2.2
## 주크박스 볼륨 버튼 한 번에 오르는 양(0 → 25 → 50 → 75 → 100 → 0%).
const VOLUME_STEP: float = 0.25
const GRAVITY: float = 9.8
## 깨짐 기준(병·큐대). 숫자는 "세게 던지면 벽에서 깨지고, 서서 툭 놓으면 안 깨지는" 정도로 맞춘 임시값.
const BREAK_SPEED: float = 8.0
const BREAK_HIT_SPEED: float = 7.0
const BREAK_FALL: float = 1.7
const BREAK_DISTANCE: float = 5.0
const RESPAWN: float = 6.0
const CAPSULE_BURST: float = 4.0
## 마시기 몸짓(2026-10-31 사용자 요청 — 예전엔 킬로그만 뜨고 아무 동작이 없었다).
## 한 모금 = DRINK_SECONDS 동안 병을 입으로 올려(HOLD → MOUTH) 병목이 얼굴 쪽으로 DRINK_TIP 만큼 기울었다가 내려온다.
## 박자는 CharacterRig.drink_curve 하나로 맞춘다(팔·고개·1인칭 카메라·병이 같이 움직인다). 마시기 쿨다운(1.5초)보다 짧아야 한다.
const DRINK_SECONDS: float = 1.3
## 든 소품 자리(눈 기준, 몸 방향): 평소 = 오른손 앞 아래, 마실 때 = 입 앞.
const HOLD_OFFSET := Vector3(0.3, -0.25, -0.55)
const MOUTH_OFFSET := Vector3(0.05, -0.1, -0.27)
## 내 화면(1인칭)에서 마실 때 병 자리. 남이 보는 입 앞(MOUTH_OFFSET)을 그대로 쓰면 카메라에 너무 붙어
## 병이 화면 오른쪽 아래를 다 가렸다(2026-10-31 화면 확인) → 조금 더 앞·아래·오른쪽에서 병목만 화면에 들어오게 한다.
const FIRST_PERSON_MOUTH := Vector3(0.12, -0.17, -0.42)
## 병을 기울이는 최대 각도(라디안, 약 110도 — 병 바닥이 하늘로). +X 축으로 돌리면 병목이 얼굴(+Z) 쪽으로 온다.
const DRINK_TIP: float = 1.9
## 튕김 계수(1 = 그대로 튕김). 없는 종류는 튕기지 않고 바로 멈춘다.
const BOUNCE := {"ball": 0.62, "hoop_ball": 0.66, "capsule": 0.45, "plush": 0.25}
## 누운 소품의 바닥 높이(병·큐대는 떨어지면 눕는다).
const LYING_REST := {"bottle": 0.07, "cue": 0.02}
## 마실 수 있는 소품(한 모금 · 마시는 몸짓 · 취기). 맥주잔은 2026-10-31 밤에 더했다.
const DRINKS: Array[String] = ["bottle", "mug"]
## 세게 부딪히면 깨지거나(병·큐대) 쏟아지는(맥주잔) 소품.
const FRAGILE: Array[String] = ["bottle", "cue", "mug"]
## 건드리면 흔들리는 시간(초)과 흔들림 크기(라디안).
const WOBBLE_SECONDS: float = 0.7
const WOBBLE_ANGLE: float = 0.12
## 오락실 테마에서 펍 그림에서 빼는 묶음(같은 자리에 기계를 세운다).
## Windows(2026-10-31 늦은 밤): 오락실은 창 없는 방 — 창을 빼고 그 벽에 네온 간판을 단다(간판이 창에 겹쳐 잘리던 문제).
const ARCADE_SKIP: Array[String] = ["Bar", "NpcCorner", "PoolTable", "Barrels", "PubOnly", "Windows"]
## 소품 → 킬로그 아이콘.
const FEED_ICONS := {"bottle": "bottle", "mug": "bottle", "ball": "hoop", "cue": "cue", "hoop_ball": "hoop", "plush": "plush", "capsule": "capsule"}

var game: GameView
var session: NetworkSession
var objects: Array[Dictionary] = []
var visuals: Array[Node3D] = []
var intoxication: Dictionary = {}
var stun_until: Dictionary = {}
## 장난 효과: peer → {이름: 끝나는 시각}. 이름 = bighead(왕머리) · ink(먹물) · blind(인형에 얼굴 가림).
var effects: Dictionary = {}
var _last_action: Dictionary = {}
var _projectiles: Array[Dictionary] = []
var _elapsed: float = 0.0
var _last_deal: int = -1
var _theme_id: int = -1
var _theme_root: Node3D
var _arcade_room: Node3D
var _arcade: RefCounted
var _base_materials: Dictionary = {}
var _base_lights: Dictionary = {}
var _drink_labels: Array[Label3D] = []
var _feed_dirty: bool = false
var music: Dictionary = {"video": "", "playing": false, "volume": 0.5}
var bridge: Node
var _audio: AudioStreamPlayer3D
var _sfx: AudioStreamPlayer
var _jukebox_lights: Array[StandardMaterial3D] = []
var _time: float = 0.0
## 흔들리는 물건: 노드 → 흔들기 시작 시각(_time 기준). 원래 회전은 _wobble_base 에.
var _wobbles: Dictionary = {}
var _wobble_base: Dictionary = {}

func configure(owner: GameView) -> void:
	game = owner
	session = game.session
	session.game_action.connect(_receive_action)
	session.game_event.connect(_receive_event)
	_arcade = Rules.new(self)
	_build()
	if DisplayServer.get_name() != "headless":
		bridge = Bridge.new()
		add_child(bridge)
		_audio = AudioStreamPlayer3D.new()
		_audio.position = JUKEBOX + Vector3.UP
		_audio.max_distance = 25
		_audio.stream = _demo_loop()
		add_child(_audio)
		_sfx = preload("res://art/showcase/synth_audio.gd").new()
		add_child(_sfx)

func now() -> float:
	return game.controller._now()

# ─────────────────────────────── 만들기 ───────────────────────────────

func _build() -> void:
	var dark: Material = Kit.material("lounge_dark", "162039", 0.2)
	Kit.box(self, "MonitorStand", Vector3(0.14, 1.2, 0.2), MONITOR - Vector3(0, 0.55, 0), dark)
	Kit.box(self, "MonitorScreen", Vector3(1.0, 0.64, 0.12), MONITOR, dark)
	# 상호작용 키는 2026-10-31 부터 F(설정에서 바꿀 수 있다) — 예전 글자 "[E]" 가 남아 있었다.
	Kit.label(self, "MonitorText", "DARTY / ROOM\n[%s] 방장 설정" % OS.get_keycode_string(Preferences.interact_key), MONITOR + Vector3(0, 0, 0.08), 26, Color("79f2ce"), 0.004)
	_build_jukebox()
	# 2026-10-31 밤: 예전 자리(x -4.76, 높이 1.3)는 카운터 앞면(x -4.9) 밖 허공이라 병이 떠 보였다 → 바 윗면 위로.
	for index in range(TableView.BAR_BOTTLES_Z.size()):
		_add_prop("bottle", Vector3(TableView.BAR_BOX.end.x - 0.25, TableView.BAR_TOP_Y + float(Looks.REST.bottle), TableView.BAR_BOTTLES_Z[index]), -1, index)
	# 맥주잔: 바 컵받침 위(펍 테마 — 오락실에서는 바 그림이 빠진다).
	for index in range(TableView.BAR_MUGS.size()):
		_add_prop("mug", TableView.BAR_MUGS[index] + Vector3(0, float(Looks.REST.mug), 0), 0, index)
	for index in range(3):
		_add_prop("ball", Vector3(10.65, 0.91, 3.5 + index * 0.15), 0, index)
	_add_prop("cue", Vector3(10.28, 0.78, 4.7), 0, 0)
	for index in range(Rules.BALL_HOMES.size()):
		_add_prop("hoop_ball", Rules.BALL_HOMES[index], 1, index)
	for index in range(Rules.PLUSH_SPOTS.size()):
		_add_prop("plush", Rules.plush_spot(index), 1, index, true)
	for index in range(4):
		var machine: int = index % 2
		_add_prop("capsule", Rules.globe_spot(machine, index), 1, index, true)
		objects[-1].machine = machine
	_theme_root = Node3D.new()
	_theme_root.name = "ThemeRoot"
	add_child(_theme_root)
	apply_theme()

## 레트로 주크박스: 둥근 머리 · 무지개 빛 띠 · 스피커 그릴 · 버튼 3개(전원 · 볼륨 · 링크). 버튼 자리는 상호작용 좌표와 같다.
func _build_jukebox() -> void:
	var wood := Kit.material("jukebox_wood", "5a2e2a", 0.0)
	var chrome := Kit.material("jukebox_chrome", "d8d8e4", 0.8)
	var grille := Kit.material("jukebox_grille", "1a1420", 0.0)
	Kit.box(self, "JukeboxCabinet", Vector3(1.4, 1.5, 0.6), JUKEBOX + Vector3(0, 0.75, 0), wood)
	var arch := Kit.cylinder(self, "JukeboxArch", 0.7, 0.6, JUKEBOX + Vector3(0, 1.5, 0), wood, 18)
	arch.rotation.x = PI / 2
	Kit.box(self, "JukeboxWindow", Vector3(0.9, 0.36, 0.04), JUKEBOX + Vector3(0, 1.62, 0.3), Kit.material("jukebox_window", "f6e7b8", 0.0, 0.8))
	Kit.box(self, "JukeboxGrille", Vector3(1.0, 0.55, 0.04), JUKEBOX + Vector3(0, 0.55, 0.3), grille)
	for side in [-0.5, 0.5]:
		Kit.sphere(self, "Speaker", 0.2, JUKEBOX + Vector3(side * 0.9, 0.55, 0.3), chrome, Vector3(1, 1, 0.25))
	# 무지개 빛 띠(색이 천천히 돈다).
	for index in range(5):
		var material := StandardMaterial3D.new()
		material.emission_enabled = true
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_jukebox_lights.append(material)
		var angle: float = PI * (0.1 + index * 0.2)
		var at := JUKEBOX + Vector3(cos(angle) * 0.62, 1.5 + sin(angle) * 0.62, 0.31)
		Kit.sphere(self, "JukeboxBulb", 0.06, at, material)
	for side in [-1.0, 1.0]:
		Kit.box(self, "JukeboxTube", Vector3(0.07, 1.3, 0.07), JUKEBOX + Vector3(side * 0.66, 0.7, 0.3), _jukebox_lights[0 if side < 0 else 4])
	Kit.label(self, "JukeboxTitle", "DARTY / JUKEBOX", JUKEBOX + Vector3(0, 2.0, 0.32), 30, Color("ffd34d"), 0.003)
	var buttons := Kit.material("jukebox_button", "ff6b5b", 0.0, 0.6)
	for spec in [["power", "전원", -0.48], ["volume", "볼륨", 0.0], ["link", "링크", 0.48]]:
		var at: Vector3 = JUKEBOX + Vector3(float(spec[2]), 1.2, 0.42)
		Kit.cylinder(self, str(spec[0]), 0.08, 0.06, at, buttons, 14).rotation.x = PI / 2
		Kit.box(self, str(spec[0]) + "Plate", Vector3(0.3, 0.2, 0.1), at + Vector3(0, 0, -0.08), chrome)
		Kit.label(self, str(spec[0]) + "Label", str(spec[1]), at + Vector3(0, 0.17, 0), 24, Color.WHITE, 0.003)

func _add_prop(kind: String, at: Vector3, theme: int, slot: int, locked: bool = false) -> void:
	var node := Looks.make(kind, slot)
	node.name = "Prop_%s_%d" % [kind, slot]
	add_child(node)
	node.position = at
	if kind == "bottle":
		var label := Kit.label(node, "DrinkLabel", "SODA", Vector3(0, -0.02, 0.074), 20, Color("120c12"), 0.0016)
		_drink_labels.append(label)
	objects.append({"kind": kind, "position": at, "home": at, "holder": 0, "available": 0.0, "theme": theme, "slot": slot,
		"locked": locked, "broken": 0.0, "lying": false, "spin": 0.0, "effect": "", "machine": 0, "rest_at": 0.0})
	visuals.append(node)

# ─────────────────────────────── 테마 ───────────────────────────────

func apply_theme() -> void:
	for label in _drink_labels: label.text = "PUB" if session.room.settings.alcohol else "SODA"
	var next: int = session.room.settings.theme_id
	if _theme_id == next: return
	var first: bool = _theme_id == -1
	_theme_id = next
	_projectiles.clear()
	for index in range(objects.size()):
		if not _in_theme(objects[index]): _reset_object(index)
	_arcade.reset()
	# 처음 펍 그림은 이미 통째로 있다. 오락실로 가거나 오락실에서 돌아올 때만 다시 만든다.
	if not first or next == 1:
		var skip: Array[String] = []
		if next == 1: skip.assign(ARCADE_SKIP)
		game.table.rebuild_pub(skip, _trim_arcade if next == 1 else Callable())
	_base_materials.clear()
	_base_lights.clear()
	_wobbles.clear()
	_wobble_base.clear()
	var pub: Node = game.table.get_node("Pub")
	_recolor(pub, next == 1)
	_set_glow(pub, next == 1)
	for child in _theme_root.get_children():
		_theme_root.remove_child(child)
		child.queue_free()
	_arcade_room = null
	if next == 1:
		_arcade_room = ArcadeRoom.new()
		_arcade_room.name = "ArcadeRoom"
		_theme_root.add_child(_arcade_room)
		_arcade_room.build()

## 오락실: 바·NPC 자리·당구대 위에 걸린 펍 펜던트 등을 뺀다(가챠·농구 기계 앞을 가린다). 과녁 쪽 등은 둔다.
static func _trim_arcade(pub: Node) -> void:
	var lights := pub.get_node_or_null("Lights")
	if lights == null: return
	for node in lights.get_children():
		if str(node.name).begins_with("Pendant") and node is Node3D and absf((node as Node3D).position.x) > 4.0:
			lights.remove_child(node)
			node.free()

func _in_theme(object: Dictionary) -> bool:
	var theme: int = int(object.get("theme", -1))
	return theme == -1 or theme == _theme_id

## 소품을 처음 자리로(인형·캡슐은 기계 안으로) 돌려놓는다.
func _reset_object(index: int) -> void:
	var object: Dictionary = objects[index]
	object.holder = 0
	object.broken = 0.0
	object.lying = false
	object.spin = 0.0
	match str(object.kind):
		"plush": _arcade.return_plush(index)
		"capsule": _arcade.return_capsule(index)
		_: object.position = object.home

## 오락실은 네온이 번지도록 빛 번짐(glow)을 키운다. 생성물의 환경 자원은 복사해서 바꾼다(원본은 그대로).
func _set_glow(pub: Node, arcade: bool) -> void:
	var world := pub.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if world == null or world.environment == null or not arcade: return
	var environment: Environment = world.environment.duplicate()
	environment.glow_enabled = true
	environment.glow_intensity = 1.05
	environment.glow_bloom = 0.12
	environment.glow_hdr_threshold = 0.85
	environment.ambient_light_energy *= 0.75
	world.environment = environment

# ─────────────────────────────── 조준·조회 ───────────────────────────────

func focus(peer_id: int) -> Dictionary:
	var actor: PlayerView = game.actors.get(peer_id)
	if actor == null: return {}
	var origin: Vector3 = actor.eye_position()
	var forward: Vector3 = Basis(Vector3.UP, actor.rotation.y) * Basis(Vector3.RIGHT, actor.pitch) * Vector3.FORWARD
	var candidates: Array[Dictionary] = [{"kind": "monitor", "at": MONITOR},
		{"kind": "power", "at": JUKEBOX + Vector3(-0.48, 1.2, 0.42)},
		{"kind": "volume", "at": JUKEBOX + Vector3(0, 1.2, 0.42)},
		{"kind": "link", "at": JUKEBOX + Vector3(0.48, 1.2, 0.42)}]
	if _theme_id == 1:
		candidates.append_array(Rules.focus_points())
	var spots: Array[Dictionary] = touch_spots()
	for index in range(spots.size()):
		if int(spots[index].theme) == -1 or int(spots[index].theme) == _theme_id:
			candidates.append({"kind": "touch", "index": index, "at": spots[index].at})
	if session.room.settings.props_enabled:
		for index in range(objects.size()):
			if _usable(index):
				candidates.append({"kind": "prop", "index": index, "at": objects[index].position})
	var best: Dictionary = {}
	var dot: float = 0.9
	for item in candidates:
		var offset: Vector3 = item.at - origin
		var value: float = forward.dot(offset.normalized())
		if offset.length() <= REACH and value > dot:
			dot = value
			best = item
	return best

## 집을 수 있는 소품인가: 지금 테마 · 기계 밖 · 안 깨짐 · 쿨다운 끝 · 아무도 안 듦 · 날아가는 중 아님.
func _usable(index: int) -> bool:
	var object: Dictionary = objects[index]
	return int(object.holder) == 0 and _in_theme(object) and not bool(object.get("locked", false)) \
		and now() >= float(object.get("broken", 0.0)) and now() >= float(object.available) and not is_flying(index)

func held(peer_id: int) -> int:
	for index in range(objects.size()):
		if int(objects[index].holder) == peer_id: return index
	return -1

func is_flying(index: int) -> bool:
	for projectile in _projectiles:
		if int(projectile.index) == index: return true
	return false

func prop_name(index: int) -> String:
	if index < 0 or index >= objects.size(): return "소품"
	var kind: String = objects[index].kind
	if kind == "bottle" and session.room.settings.alcohol: return "술병"
	if kind == "mug": return "맥주잔" if session.room.settings.alcohol else "음료잔"
	return str(Looks.NAMES.get(kind, "소품"))

func machine_prompt(peer_id: int, kind: String) -> String:
	return _arcade.prompt(peer_id, kind)

## 장난 효과가 몇 초 남았는지(HUD 덮개·캐릭터 왕머리).
func effect_left(peer_id: int, name: String) -> float:
	var list: Dictionary = effects.get(peer_id, {})
	return maxf(0.0, float(list.get(name, 0.0)) - now())

func is_stunned(peer_id: int) -> bool:
	return now() < float(stun_until.get(peer_id, 0))

# ─────────────────────────────── 입력(방장) ───────────────────────────────

func request(action: String, value: Variant = 0) -> void:
	if session.is_host(): _accept(session.local_peer_id, action, value)
	else: session.request_game_action.rpc_id(1, "lounge", [game.controller.state.match_id, action, value])

func _receive_action(sender: int, action: String, payload: Array) -> void:
	if action == "lounge" and payload.size() == 3 and payload[0] == game.controller.state.match_id and payload[1] is String:
		_accept(sender, payload[1], payload[2])

func _accept(sender: int, action: String, value: Variant) -> void:
	var actor: PlayerView = game.actors.get(sender)
	if actor == null or actor.identity.is_bot: return
	var time: float = now()
	if time - float(_last_action.get(sender, -10.0)) < 0.15 or is_stunned(sender): return
	_last_action[sender] = time
	if action in ["take", "drink", "throw"] and not session.room.settings.props_enabled: return
	var hit: Dictionary = focus(sender)
	var index: int = held(sender)
	if action == "take" and index == -1 and hit.get("kind") == "prop":
		index = int(hit.index)
		objects[index].holder = sender
		objects[index].lying = false
	elif action == "drink" and index >= 0 and objects[index].kind in DRINKS:
		if time - float(objects[index].get("drank", -10.0)) < 1.5: return
		objects[index].drank = time
		if session.room.settings.alcohol:
			intoxication[sender] = minf(5, float(intoxication.get(sender, 0)) + 1.0)
		feed("drink", actor, "한 모금")
		# 꿀꺽 소리는 병이 입에 닿는 박자(진행 약 0.3)에 맞춰 조금 늦게 낸다.
		get_tree().create_timer(DRINK_SECONDS * 0.3).timeout.connect(_gulp.bind(sender))
	elif action == "drink" and index >= 0 and objects[index].kind == "capsule":
		# 손에 든 캡슐을 직접 연다(라이어스 바처럼 운에 맡기기). 결과는 나에게.
		_burst_capsule(index, actor.eye_position(), sender, sender)
	elif action == "throw" and index >= 0:
		_throw(actor, index, value)
	elif action in ["claw", "gacha", "hoop"]:
		if _theme_id != 1 or hit.get("kind") != action: return
		if not _arcade.accept(sender, action, hit.get("index", 0)): return
	elif action == "touch" and hit.get("kind") == "touch" and int(hit.get("index", -1)) == int(value):
		# 건드리기: 소리 + 흔들림을 모두에게(fx 이벤트). 딸깍 소리는 내지 않는다(물건 소리만).
		var spot: Dictionary = touch_spots()[int(value)]
		var data := {"match_id": game.controller.state.match_id, "kind": "sound", "at": spot.at, "push": Vector3.ZERO,
			"tint": Color.WHITE, "sound": spot.sound, "wobble": spot.node}
		_play_fx(data)
		session.receive_game_event.rpc("lounge_fx", data)
		return
	elif action == "power" and hit.get("kind") == "power": music.playing = not music.playing
	elif action == "volume" and hit.get("kind") == "volume":
		# 상호작용 키 한 번 = 한 단계 올리기, 가장 크면 0 으로 돌아간다(2026-10-31: 볼륨도 상호작용 키 하나로).
		music.volume = 0.0 if float(music.volume) >= 1.0 - 0.001 else minf(1.0, snappedf(float(music.volume), VOLUME_STEP) + VOLUME_STEP)
	elif action == "link" and hit.get("kind") == "link" and value is String:
		var id: String = Bridge.video_id(str(value).left(300))
		if id.is_empty(): return
		music.video = id
		music.playing = true
	else: return
	play_click()
	session.receive_game_event.rpc("lounge_sound", {"match_id": game.controller.state.match_id})
	_publish()
	game.controller._publish()
	_feed_dirty = false

## 꿀꺽 소리(방장이 정하고 모든 화면에서 그 사람 머리 자리에서 난다).
func _gulp(peer_id: int) -> void:
	var actor: PlayerView = game.actors.get(peer_id)
	if actor != null: fx("sound", actor.eye_position(), Vector3.ZERO, Color.WHITE, "gulp")

## 던지기. value = 힘(0~1, 우클릭을 누른 시간). 숫자가 아니면 예전 기본 던지기(시험·구버전 호환).
func _throw(actor: PlayerView, index: int, value: Variant) -> void:
	var direction: Vector3 = Basis(Vector3.UP, actor.rotation.y) * Basis(Vector3.RIGHT, actor.pitch) * Vector3.FORWARD
	var powered: bool = actor.identity.card_effects.get("power", false)
	var velocity: Vector3
	if not (value is float):
		velocity = direction * (9.0 if powered else 3.0) + Vector3.UP
	elif float(value) < 0.12:
		# 짧게 누르면 살짝 놓는다(발밑에 툭). 높은 곳에서 놓으면 그래도 깨진다.
		velocity = direction * 1.2 + Vector3.UP * 0.4
	else:
		var charge: float = clampf(float(value), 0.0, 1.0)
		velocity = direction * lerpf(4.5, 12.0, charge) * (1.35 if powered else 1.0) + Vector3.UP * (0.8 + charge)
	_launch(index, actor.eye_position() + direction * 0.4, velocity, actor.identity.peer_id, powered)
	objects[index].available = now() + session.room.settings.miss_cooldown

## 소품을 날린다(던지기 · 맞아서 떨어뜨리기 공통).
func _launch(index: int, from: Vector3, velocity: Vector3, owner: int, powered: bool) -> void:
	for projectile in _projectiles.duplicate():
		if int(projectile.index) == index: _projectiles.erase(projectile)
	var object: Dictionary = objects[index]
	object.holder = 0
	object.position = from
	object.lying = false
	object.rest_at = now()
	var exclude: Array[RID] = []
	var thrower: PlayerView = game.actors.get(owner)
	if thrower != null: exclude.append(thrower.get_rid())
	_projectiles.append({"index": index, "owner": owner, "velocity": velocity, "until": now() + 5.0, "origin": from,
		"peak": from.y, "powered": powered, "bounces": 0, "exclude": exclude, "scored": false})

# ─────────────────────────────── 물리(방장) ───────────────────────────────

func _physics_process(delta: float) -> void:
	if game == null: return
	if not session.is_host(): return
	var time: float = now()
	# 방장이 소품을 끄면 이미 들었거나 날아가던 소품도 즉시 내려놓는다.
	if not session.room.settings.props_enabled:
		for projectile in _projectiles:
			var object: Dictionary = objects[int(projectile.index)]
			object.position = TableView.clamp_floor(object.position)
			object.position.y = 0.15
		_projectiles.clear()
		for object in objects:
			var holder: PlayerView = game.actors.get(int(object.holder))
			if holder != null:
				object.position = TableView.clamp_floor(holder.position) + Vector3.UP * 0.15
				object.holder = 0
	_step_projectiles(delta)
	for index in range(objects.size()):
		var object: Dictionary = objects[index]
		if int(object.holder) != 0 and not game.actors.has(int(object.holder)): object.holder = 0
		# 깨진 소품은 잠시 뒤 제자리에 새것으로.
		if float(object.get("broken", 0.0)) > 0.0 and time >= float(object.broken):
			object.broken = 0.0
			object.position = object.home
			object.lying = false
		# 농구 기계 안에 떨어진 공은 앞 받침으로 굴러온다.
		if float(object.get("return_at", 0.0)) > 0.0 and time >= float(object.return_at):
			object.return_at = 0.0
			if int(object.holder) == 0 and not is_flying(index): object.position = object.home
	if _theme_id == 1: _arcade.step(delta)
	for peer_id in intoxication: intoxication[peer_id] = maxf(0, float(intoxication[peer_id]) - delta / 35.0)
	if game.controller.state.phase == MatchState.Phase.CARDS and _last_deal != game.controller.state.round_number:
		_last_deal = game.controller.state.round_number
		if session.room.settings.drink_on_deal:
			for peer_id in game.actors: intoxication[peer_id] = minf(5, float(intoxication.get(peer_id, 0)) + 1)
	if _feed_dirty:
		_feed_dirty = false
		game.controller._publish()
	_elapsed += delta
	if _elapsed >= 0.1:
		_elapsed = 0
		_publish()

func _step_projectiles(delta: float) -> void:
	if _projectiles.is_empty(): return
	var space := game.get_world_3d().direct_space_state
	for projectile in _projectiles.duplicate():
		var index: int = projectile.index
		var object: Dictionary = objects[index]
		var from: Vector3 = object.position
		var velocity: Vector3 = projectile.velocity
		velocity += Vector3.DOWN * GRAVITY * delta
		projectile.velocity = velocity
		var to: Vector3 = from + velocity * delta
		var exclude: Array[RID] = projectile.exclude
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 3, exclude))
		var end: Vector3 = hit.position if not hit.is_empty() else to
		if object.kind == "hoop_ball" and _theme_id == 1: _arcade.ball_moved(projectile, from, end)
		object.spin = float(object.get("spin", 0.0)) + delta * minf(velocity.length(), 14.0) * 1.6
		if hit.is_empty():
			object.position = to
			projectile.peak = maxf(float(projectile.peak), to.y)
			if to.y <= 0.0:
				_hit_world(projectile, Vector3(to.x, 0.0, to.z), Vector3.UP)
			elif now() >= float(projectile.until):
				_settle(projectile, Vector3(TableView.clamp_floor(to).x, 0.0, TableView.clamp_floor(to).z), Vector3.UP)
			continue
		var victim := hit.collider as PlayerView
		if victim != null: _hit_player(projectile, victim, hit.position)
		else: _hit_world(projectile, hit.position, hit.normal)

func _hit_world(projectile: Dictionary, at: Vector3, normal: Vector3) -> void:
	var index: int = projectile.index
	var object: Dictionary = objects[index]
	var kind: String = object.kind
	var velocity: Vector3 = projectile.velocity
	var speed: float = velocity.length()
	var fall: float = float(projectile.peak) - at.y
	var origin: Vector3 = projectile.origin
	var powered: bool = projectile.powered
	var owner: int = projectile.owner
	if kind in FRAGILE and (powered or speed > BREAK_SPEED or fall > BREAK_FALL or origin.distance_to(at) > BREAK_DISTANCE):
		var reason: String = "파워 카드" if powered else ("세게 던짐" if speed > BREAK_SPEED else ("높은 곳에서 떨어짐" if fall > BREAK_FALL else "멀리 날아감"))
		_break(index, at, velocity, owner, null, reason)
		_projectiles.erase(projectile)
		return
	if kind == "capsule" and (powered or speed > CAPSULE_BURST):
		_burst_capsule(index, at, owner, 0)
		_projectiles.erase(projectile)
		return
	# 농구 기계 경사판에 떨어진 공은 튕기지 않고 바로 앞 받침으로 굴러 내려온다(진짜 오락기처럼 빨리 다시 던지게).
	if kind == "hoop_ball" and normal.y > 0.5 and Rules.in_hoop_machine(at):
		_settle(projectile, at, normal)
		return
	var bounce: float = float(BOUNCE.get(kind, 0.0))
	# 벽에 맞은 소품은 그 자리에 붙지 않고 힘 빠지게 튕겨 바닥으로 떨어진다.
	if normal.y < 0.5: bounce = maxf(bounce, 0.25)
	if bounce > 0.0 and (speed > 1.6 or normal.y < 0.5) and int(projectile.bounces) < 6:
		projectile.velocity = velocity.bounce(normal) * bounce
		projectile.bounces = int(projectile.bounces) + 1
		object.position = at + normal * 0.03
		if normal.y > 0.5: projectile.peak = at.y
		if speed > 3.0 and kind in ["ball", "hoop_ball"]: fx("sound", at, Vector3.ZERO, Color.WHITE, "bounce")
		return
	_settle(projectile, at, normal)

## 멈춘 자리에 내려놓는다. 병·큐대는 눕는다.
func _settle(projectile: Dictionary, at: Vector3, normal: Vector3) -> void:
	var index: int = projectile.index
	var object: Dictionary = objects[index]
	var kind: String = object.kind
	if normal.y < 0.5: at = Vector3(at.x, 0.0, at.z) + Vector3(normal.x, 0, normal.z) * 0.1
	var lying: bool = LYING_REST.has(kind)
	object.lying = lying
	object.position = at + Vector3.UP * float(LYING_REST.get(kind) if lying else Looks.REST.get(kind, 0.1))
	object.rest_at = now()
	if kind == "hoop_ball" and Rules.in_hoop_machine(at): object.return_at = now() + 0.8
	_projectiles.erase(projectile)

func _hit_player(projectile: Dictionary, victim: PlayerView, at: Vector3) -> void:
	var index: int = projectile.index
	var object: Dictionary = objects[index]
	var kind: String = object.kind
	var velocity: Vector3 = projectile.velocity
	var speed: float = velocity.length()
	var owner: int = projectile.owner
	var victim_id: int = victim.identity.peer_id
	var time: float = now()
	var exclude: Array[RID] = projectile.exclude
	exclude.append(victim.get_rid())
	var stun: float = session.room.settings.hit_stun
	if kind == "plush":
		# 인형은 아프지 않다 — 대신 얼굴을 푹 덮는다(앞이 안 보임).
		stun = 0.35
		_set_effect(victim_id, "blind", 1.6)
	stun_until[victim_id] = maxf(float(stun_until.get(victim_id, 0.0)), time + stun)
	if not victim.seated:
		var push := Vector3(velocity.x, 0, velocity.z).normalized()
		victim.knockback = push * clampf(1.2 + speed * 0.32, 1.2, 5.0)
	_drop_held(victim_id)
	# 임시 밸런스: 맞히면 스턴 시간만큼 소품 회수도 더 늦어진다. 점수 벌점은 팀 확정 전이다.
	object.available = time + session.room.settings.miss_cooldown + session.room.settings.hit_stun
	fx("stars", victim.eye_position() + Vector3.UP * 0.25, Vector3.UP, Color.WHITE, "thunk")
	if kind in FRAGILE and (bool(projectile.powered) or speed > BREAK_HIT_SPEED):
		_break(index, at, velocity, owner, victim, "")
		_projectiles.erase(projectile)
		return
	if kind == "capsule":
		_burst_capsule(index, at, owner, victim_id)
		_projectiles.erase(projectile)
		return
	feed(str(FEED_ICONS.get(kind, "bottle")), game.actors.get(owner), "얼굴 덮기!" if kind == "plush" else "명중 · 스턴", victim)
	# 맞고 튕겨 나와 아래로 떨어진다.
	projectile.velocity = Vector3(-velocity.x * 0.2, minf(velocity.y, 0.0), -velocity.z * 0.2)
	object.position = at

## 들고 있던 소품을 떨어뜨린다(맞았을 때). 손 높이에서 떨어지므로 보통은 안 깨진다.
func _drop_held(peer_id: int) -> void:
	var index: int = held(peer_id)
	var actor: PlayerView = game.actors.get(peer_id)
	if index < 0 or actor == null: return
	var forward: Vector3 = Basis(Vector3.UP, actor.rotation.y) * Vector3.FORWARD
	_launch(index, actor.eye_position() + forward * 0.35 + Vector3.DOWN * 0.3, forward * 0.8 + Vector3.UP * 1.2, peer_id, false)

func _break(index: int, at: Vector3, velocity: Vector3, owner: int, victim: PlayerView, reason: String) -> void:
	var object: Dictionary = objects[index]
	var kind: String = object.kind
	var time: float = now()
	object.broken = time + RESPAWN
	object.available = time + RESPAWN
	object.holder = 0
	object.position = object.home
	object.lying = false
	var thrower: PlayerView = game.actors.get(owner)
	if kind == "bottle":
		var tint: Color = [Color("3f9e5a"), Color("8a5a2b"), Color("4fa3c7")][int(object.slot) % 3]
		fx("glass", at, velocity * 0.3, tint, "glass")
		fx("splash", at, velocity * 0.2, Color("e8b84a") if session.room.settings.alcohol else Color("7fd8ff"), "")
	elif kind == "mug":
		# 나무 맥주잔은 깨지지 않는다 — 내용물만 쏟아지고(웅덩이) 툭 소리. 빈 잔은 치워졌다가 RESPAWN 초 뒤 채워져 돌아온다(위 broken 시각).
		fx("splash", at, velocity * 0.25, Color("e8b84a") if session.room.settings.alcohol else Color("7fd8ff"), "thunk")
		if victim != null: feed("broken", thrower, "맥주 세례!", victim)
		else: feed("broken", thrower, "맥주 와르르! · %s" % reason)
		return
	else:
		fx("wood", at, velocity * 0.3, Color.WHITE, "crack")
	var name: String = "병" if kind == "bottle" else "큐대"
	if victim != null: feed("broken", thrower, "%s 와장창!" % name, victim)
	else: feed("broken", thrower, "%s 와장창! · %s" % [name, reason])

## 캡슐이 터진다: 맞은 사람(없으면 1.6m 안 가장 가까운 사람)에게 안에 든 효과.
func _burst_capsule(index: int, at: Vector3, owner: int, target_id: int) -> void:
	var object: Dictionary = objects[index]
	var effect: String = str(object.get("effect", ""))
	if effect.is_empty(): effect = _arcade._pick_effect()
	if target_id == 0:
		var best: float = 1.6
		for peer_id in game.actors:
			var distance: float = (game.actors[peer_id] as PlayerView).eye_position().distance_to(at)
			if distance < best:
				best = distance
				target_id = int(peer_id)
	var color: Color = Looks.CAPSULE_COLORS[int(object.slot) % Looks.CAPSULE_COLORS.size()]
	fx("confetti" if effect == "confetti" else "sparks", at, Vector3.UP, color, "pop")
	var thrower: PlayerView = game.actors.get(owner)
	var target: PlayerView = game.actors.get(target_id)
	var text: String = str(Rules.EFFECT_TEXT.get(effect, "꽝!"))
	if target != null:
		_apply_effect(target_id, effect)
		feed("capsule", thrower, "캡슐 → " + text, target if target_id != owner else null)
	else:
		feed("capsule", thrower, "캡슐 펑! · %s · 아무도 없음" % text)
	_arcade.return_capsule(index)

func _apply_effect(peer_id: int, effect: String) -> void:
	var actor: PlayerView = game.actors.get(peer_id)
	match effect:
		"bighead": _set_effect(peer_id, "bighead", 9.0)
		"ink": _set_effect(peer_id, "ink", 4.5)
		"dizzy":
			stun_until[peer_id] = maxf(float(stun_until.get(peer_id, 0.0)), now() + 1.6)
			if actor != null: fx("stars", actor.eye_position() + Vector3.UP * 0.25, Vector3.UP, Color.WHITE, "")
		"confetti":
			if actor != null: fx("confetti", actor.eye_position() + Vector3.UP * 0.3, Vector3.UP, Color.WHITE, "fanfare")

func _set_effect(peer_id: int, name: String, seconds: float) -> void:
	if not effects.has(peer_id): effects[peer_id] = {}
	effects[peer_id][name] = now() + seconds

# ─────────────────────────────── 로그·효과 방송 ───────────────────────────────

## 킬로그 한 줄. who/target 은 PlayerView 나 MatchPlayer(없으면 null).
func feed(icon: String, who: Variant, text: String, target: Variant = null) -> void:
	game.controller.add_feed(game.controller.feed_entry(icon, _identity(who), text, _identity(target)))
	_feed_dirty = true

static func _identity(value: Variant) -> MatchPlayer:
	if value is PlayerView: return (value as PlayerView).identity
	if value is MatchPlayer: return value
	return null

## 보이기만 하는 효과(파편·폭죽·소리). 방장이 정하고 모두의 화면에서 각자 재생한다.
func fx(kind: String, at: Vector3, push: Vector3, tint: Color, sound: String) -> void:
	var data := {"match_id": game.controller.state.match_id, "kind": kind, "at": at, "push": push, "tint": tint, "sound": sound}
	_play_fx(data)
	session.receive_game_event.rpc("lounge_fx", data)

func _play_fx(data: Dictionary) -> void:
	if DisplayServer.get_name() == "headless": return
	var at: Vector3 = data.get("at", Vector3.ZERO)
	var kind: String = str(data.get("kind", ""))
	if kind != "sound": BurstFx.spawn(self, kind, at, data.get("push", Vector3.ZERO), data.get("tint", Color.WHITE))
	# 건드리기: 이름이 같은 방 노드를 찾아 흔든다(_shake). 묶음 그리기로 숨은 도형은 못 흔든다 — static_batch.gd NO_BATCH.
	var wobble: String = str(data.get("wobble", ""))
	if not wobble.is_empty():
		var pub: Node = game.table.get_node_or_null("Pub")
		var target := pub.find_child(wobble, true, false) as Node3D if pub != null else null
		if target != null:
			if not _wobble_base.has(target): _wobble_base[target] = target.rotation
			_wobbles[target] = _time
	var sound: String = str(data.get("sound", ""))
	if not sound.is_empty() and Preferences.sfx > 0.0:
		Sfx.play_at(self, sound, at, linear_to_db(maxf(0.0001, Preferences.sfx * session.room.settings.object_volume)) - 2.0, randf_range(0.92, 1.08))

# ─────────────────────────────── 네트워크 ───────────────────────────────

func _publish() -> void:
	var time: float = now()
	var public_objects: Array = objects.duplicate(true)
	for object in public_objects:
		object.available = maxf(0, float(object.available) - time)
		object.broken = maxf(0, float(object.get("broken", 0.0)) - time)
		object.rest_at = time - float(object.get("rest_at", time))
		object.erase("return_at")
		# 마신 시각도 "몇 초 전"으로 보낸다(컴퓨터마다 시계가 달라 그대로 보내면 다른 화면에서 마시는 몸짓이 안 나온다).
		if object.has("drank"): object.drank = time - float(object.drank)
	var data := {"match_id": game.controller.state.match_id, "objects": public_objects, "music": music, "intoxication": intoxication,
		"stun": {}, "effects": {}, "arcade": _arcade.to_public()}
	# 시각/스턴 시간은 남은 초로 전달한다. 컴퓨터마다 다른 단조 시계를 공유하지 않는다.
	for id in stun_until: data.stun[id] = maxf(0, float(stun_until[id]) - time)
	for id in effects:
		var list: Dictionary = {}
		for name in effects[id]: list[name] = maxf(0.0, float(effects[id][name]) - time)
		data.effects[id] = list
	session.receive_game_event.rpc("lounge", data)

func _receive_event(kind: String, data: Dictionary) -> void:
	if int(data.get("match_id", -1)) != game.controller.state.match_id: return
	if kind == "lounge_sound":
		play_click()
		return
	if kind == "lounge_fx":
		_play_fx(data)
		return
	if kind != "lounge": return
	var time: float = now()
	objects.assign(data.objects)
	for object in objects:
		object.available = time + float(object.available)
		object.broken = time + float(object.broken) if float(object.get("broken", 0.0)) > 0.0 else 0.0
		object.rest_at = time - float(object.get("rest_at", 0.0))
		if object.has("drank"): object.drank = time - float(object.drank)
	music = data.music
	intoxication = data.intoxication
	for id in data.stun: stun_until[int(id)] = time + float(data.stun[id])
	effects.clear()
	for id in data.get("effects", {}):
		var list: Dictionary = {}
		for name in data.effects[id]: list[name] = time + float(data.effects[id][name])
		effects[int(id)] = list
	_arcade.from_public(data.get("arcade", {}))

# ─────────────────────────────── 보이기(모든 화면) ───────────────────────────────

func _process(delta: float) -> void:
	if game == null: return
	_time += delta
	var time: float = now()
	# 마시는 몸짓은 병을 든 사람에게만 아래에서 다시 넣는다.
	for view: PlayerView in game.actors.values(): view.drink_pose = 0.0
	for index in range(mini(objects.size(), visuals.size())):
		var object: Dictionary = objects[index]
		var visual: Node3D = visuals[index]
		visual.visible = _in_theme(object) and time >= float(object.get("broken", 0.0))
		if not visual.visible: continue
		var actor: PlayerView = game.actors.get(int(object.holder))
		if actor != null:
			var progress: float = drink_progress(object, time)
			actor.drink_pose = progress
			visual.transform = _held_transform(actor, progress)
			continue
		var target: Vector3 = object.position
		visual.position = target if visual.position.distance_to(target) > 1.5 else visual.position.lerp(target, minf(1.0, delta * 20.0))
		var spin: float = float(object.get("spin", 0.0))
		if bool(object.get("lying", false)):
			visual.rotation = Vector3(0, float(object.slot) * 1.3, PI / 2)
		elif object.kind == "cue" and object.position == object.home:
			visual.rotation = Vector3(0, 0, 0.12)
		else:
			visual.rotation = Vector3(spin, 0, 0) if is_flying(index) or spin > 0.0 else Vector3.ZERO
	# 장난 효과: 왕머리.
	for peer_id in game.actors:
		var view: PlayerView = game.actors[peer_id]
		view.head_scale = 1.9 if effect_left(int(peer_id), "bighead") > 0.0 else 1.0
	if _arcade_room != null: _arcade_room.show_state(_arcade, time, delta)
	_shake()
	for index in range(_jukebox_lights.size()):
		var color := Color.from_hsv(fmod(_time * 0.12 + index * 0.18, 1.0), 0.75, 1.0)
		_jukebox_lights[index].albedo_color = color
		_jukebox_lights[index].emission = color
		_jukebox_lights[index].emission_energy_multiplier = 1.6 if music.playing else 0.5
	if _audio != null:
		var audible: bool = music.playing and str(music.video).is_empty()
		if audible and not _audio.playing: _audio.play()
		if not audible and _audio.playing: _audio.stop()
		_audio.volume_db = linear_to_db(maxf(0.0001, float(music.volume) * Preferences.music))
	if bridge != null:
		bridge.state = music.duplicate()
		bridge.state.volume = float(music.volume) * Preferences.music * Preferences.master

## 건드린 물건 흔들기: 점점 줄어드는 사인(종은 딸랑, 통은 덜컹). 끝나면 원래 회전으로 돌아간다.
func _shake() -> void:
	# 테마를 바꾸면 방이 다시 만들어져 예전 노드가 지워진다 → 타입 없이 꺼내 살아 있는지 먼저 본다.
	for key: Variant in _wobbles.keys():
		if not is_instance_valid(key):
			_wobbles.erase(key)
			_wobble_base.erase(key)
			continue
		var target := key as Node3D
		var age: float = _time - float(_wobbles[target])
		var base: Vector3 = _wobble_base[target]
		if age >= WOBBLE_SECONDS:
			target.rotation = base
			_wobbles.erase(target)
			continue
		var fade: float = 1.0 - age / WOBBLE_SECONDS
		target.rotation = base + Vector3(sin(age * 31.0), 0, cos(age * 27.0)) * WOBBLE_ANGLE * fade * fade


## 건드리면 소리 나고 흔들리는 물건(도면 v3). node = 방(pub_game.tscn) 안 노드 이름(game_room_builder.gd 가 붙인 이름).
## theme: -1 = 두 테마 모두, 0 = 펍만(오락실에서는 바·럼주통 그림이 빠진다). at = 바라봐야 하는 자리(손 닿는 높이).
static func touch_spots() -> Array[Dictionary]:
	var bar: AABB = TableView.BAR_BOX
	var spots: Array[Dictionary] = [
		{"node": "Bell", "at": Vector3(bar.end.x - 0.25, 1.2, bar.position.z + 0.55), "sound": "ding", "text": "종 울리기 · 딩!", "theme": 0},
		{"node": "Keg", "at": TableView.KEG_AT + Vector3(0.5, 0.75, 0), "sound": "thunk", "text": "생맥주 통 두드리기", "theme": 0},
		{"node": "PracticeTarget", "at": TableView.PRACTICE_TARGET_AT + Vector3(0, 1.0, 0), "sound": "thunk", "text": "연습 과녁 툭 치기", "theme": -1},
		{"node": "Gramophone", "at": TableView.SIDE_TABLE_AT + Vector3(0, 0.8, 0), "sound": "pop_up", "text": "축음기 나팔 톡 건드리기", "theme": -1},
	]
	for i in range(TableView.BARRELS.size()):
		spots.append({"node": "RumBarrel_%d" % (i + 1), "at": TableView.BARRELS[i] + Vector3(0, 0.75, 0),
			"sound": "thunk", "text": "럼주통 두드리기 · 통통", "theme": 0})
	return spots


## 병 마시기 진행(0~1). 마지막 한 모금에서 DRINK_SECONDS 가 지났거나 병이 아니면 0.
func drink_progress(object: Dictionary, time: float) -> float:
	if object.kind not in DRINKS or not object.has("drank"): return 0.0
	var progress: float = (time - float(object.drank)) / DRINK_SECONDS
	return progress if progress > 0.0 and progress < 1.0 else 0.0


## 손에 든 소품 자리. 평소엔 오른손 앞(몸 방향만 따른다).
## 마시는 중엔 입 앞으로 올라오며 고개 각도를 따라가고, 병목이 얼굴 쪽으로 기울며 꿀꺽할 때 살짝 흔들린다.
func _held_transform(actor: PlayerView, progress: float) -> Transform3D:
	var curve: Vector2 = CharacterRig.drink_curve(progress)
	var look: float = (actor.pitch + curve.y * PlayerView.DRINK_LOOK_UP) * curve.x
	var frame := Basis(Vector3.UP, actor.rotation.y) * Basis(Vector3.RIGHT, look)
	var tip: float = curve.x * 0.6 + curve.y * (DRINK_TIP - 0.6) + sin(progress * 38.0) * 0.05 * curve.y
	# 내 캐릭터면 1인칭 카메라 기준 자리(FIRST_PERSON_MOUTH), 남이면 3인칭으로 보기 좋은 입 앞.
	var mine: bool = actor.identity != null and actor.identity.peer_id == game.controller.local_peer_id
	var mouth: Vector3 = FIRST_PERSON_MOUTH if mine else MOUTH_OFFSET
	return Transform3D(frame * Basis(Vector3.RIGHT, tip), actor.eye_position() + frame * HOLD_OFFSET.lerp(mouth, curve.x))


func intoxication_amount(peer_id: int) -> float:
	return minf(1, float(intoxication.get(peer_id, 0)) / 5.0) * session.room.settings.intoxication if session.room.settings.alcohol else 0.0

func play_click() -> void:
	if _sfx == null or Preferences.sfx <= 0: return
	_sfx.cue("hit")
	_sfx.volume_db = linear_to_db(maxf(0.0001, Preferences.sfx * session.room.settings.object_volume)) - 12

func _demo_loop() -> AudioStreamWAV:
	# 링크를 고르기 전 들을 수 있는 자체 생성 4초 루프. 외부 음원을 포함하지 않는다.
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = 88200
	var data := PackedByteArray()
	data.resize(176400)
	for index in range(88200):
		var time: float = float(index) / 22050
		var beat: float = fmod(time, 0.5)
		var note: float = [220.0, 261.63, 329.63, 293.66][int(time) % 4]
		var sample: float = sin(TAU * note * time) * exp(-beat * 8) * 0.12 + sin(TAU * 60 * time) * exp(-beat * 28) * 0.18
		data.encode_s16(index * 2, int(sample * 32767))
	wav.data = data
	return wav

func _recolor(node: Node, arcade: bool) -> void:
	# 배치된 런타임 메시도 인스턴스 재질로 바꾼다. 생성물과 공유 원본 재질은 수정하지 않는다.
	if node is MeshInstance3D and node.material_override is StandardMaterial3D:
		if not _base_materials.has(node): _base_materials[node] = node.material_override
		var base: StandardMaterial3D = _base_materials[node]
		var palette: Dictionary = {"PlasterCream": "1d1838", "ForestPanel": "151233", "InsetGreen": "120f2a", "WoodWalnut": "2a2148", "WoodDark": "151126", "FloorOak": "1a1530", "TableFelt": "2a1f5c"}
		if arcade and palette.has(base.resource_name):
			var tinted: StandardMaterial3D = base.duplicate()
			tinted.albedo_color = Color(palette[base.resource_name])
			node.material_override = tinted
		else: node.material_override = base
	if node is Light3D:
		if not _base_lights.has(node): _base_lights[node] = [node.light_color, node.light_energy]
		node.light_color = Color("a58cff") if arcade else _base_lights[node][0]
		node.light_energy = float(_base_lights[node][1]) * (0.55 if arcade else 1.0)
	for child in node.get_children(): _recolor(child, arcade)
