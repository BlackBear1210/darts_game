extends Node3D
## 벽에서 떨어져 서 있는 독립 다트 머신(2026-11-07 디자인 요청서 5장 · 바탕화면 디자인_2026-11-07/03_dart_machine_concept.png).
## 과녁 그림 자체는 여기 없다 — game/board/board.gd(BoardView)가 그리고 회전·조각 분리를 맡는다.
## 이 노드는 그 둘레의 캐비닛 몸체·셔터·테두리 조명·상태 화면만 그린다(보이기만 한다. 충돌은 TableView 가 만든다).
##
## [좌표] 원점 = 과녁 앞면 바로 아래 바닥(세계 (BOARD_CENTER.x, 0, BOARD_CENTER.z)). 앞면은 +Z, 캐비닛은 −Z 로 뻗는다.
##   과녁 중심 = 로컬 (0, BOARD_CENTER.y, 0). 크기 약 폭 2.6 × 높이 4.2 × 깊이 0.9m(요청서 제안값).
## [스킨] build(arcade): false = 펍(월넛·청록 가죽·무광 황동·전구색 테두리), true = 오락실(크림 에나멜·남색·시안/마젠타 테두리).
##   모양은 같고 재질만 다르다 → 테마를 바꿀 때 build() 를 다시 부르면 된다(LoungeWorld.apply_theme).
## [움직이는 부품] 롤 셔터 양쪽(ShutterLeft/ShutterRight = art/dart_machine/roll_shutter.gd) — 어깨 앞 셔터 통에서
##   좁은 날개가 한 장씩 빠져나와 옆으로 "촤라락" 미끄러지며 과녁 절반을 덮는다(2026-11-08 — 예전 넓은 판 8장 → 롤 셔터).
##   show_chaos(BoardChaos.pose) 가 매 프레임 닫힘 정도·상태 글자·조명 맥박을 옮긴다.
##   F6 카드 라운드처럼 매 프레임 모양을 넘겨주는 쪽이 없으면 slide_shutter(닫기?) 로 셔터만 스스로 여닫는다.
## 실존 상업용 기계의 실루엣·로고를 본뜨지 않은 자체 형태다(요청서 7.2).

const Kit = preload("res://art/mesh_kit.gd")
const BoardChaos = preload("res://game/board/board_chaos.gd")
const RollShutter = preload("res://art/dart_machine/roll_shutter.gd")

## 몸체 치수(m). FACE_Z = 몸체 앞면이 과녁 면보다 뒤로 들어간 위치(과녁 뒤판 두께만큼).
const BODY_WIDTH: float = 2.2
const DEPTH: float = 0.78
const FACE_Z: float = -0.12
const PLINTH_HEIGHT: float = 0.25
## 아치(둥근 머리) 반지름과 중심 높이. 꼭대기 = ARCH_Y + BODY_WIDTH/2 = 4.2m.
const ARCH_Y: float = 3.1
## 과녁 둘레 테두리 조명 반지름(숫자 띠 바깥 약 1.0m 보다 조금 크게).
const RING_RADIUS: float = 1.11
## 셔터: 날개 높이·날개 앞면이 과녁 면보다 앞으로 나온 거리. 닫히면 과녁 한쪽 절반(x 0 ~ ±1.1)을 덮는다.
const SHUTTER_HEIGHT: float = 2.2
const SHUTTER_Z: float = BoardChaos.SHUTTER_FRONT
const SHUTTER_HALF: float = 1.1
## 스스로 여닫을 때(slide_shutter) 열리는 빠르기 — game.gd CHAOS_SETTLE_RATE 와 같은 값(F5 와 같은 속도로 열린다).
const OPEN_RATE: float = 4.0

## 스킨별 색: [몸체, 어깨, 받침, 테두리(장식선), 왼쪽 빛, 오른쪽 빛, 셔터, 뒤판]
const SKINS := {
	false: ["553a2a", "28584f", "2b1d16", "b58a4a", "ffc37a", "ffc37a", "6b5233", "141a18"],
	true: ["eee8dc", "20283e", "171a2b", "c9ccd6", "3be5db", "ef65cb", "d9d3c7", "10131f"],
}

var arcade: bool = false
var _parts: Node3D
var _left: RollShutter
var _right: RollShutter
var _status: Label3D
var _glows: Array[StandardMaterial3D] = []
var _time: float = 0.0
var _close_left: float = 0.0
var _close_right: float = 0.0
## slide_shutter 로 스스로 여닫을 때: 닫으라는 지시인지 · 닫기 시작한 뒤 지난 시간(초).
var _auto_closed: bool = false
var _auto_age: float = 0.0


func _ready() -> void:
	set_process(false)


## 머신을 (다시) 만든다. 테마를 바꿀 때마다 부른다.
func build(arcade_skin: bool) -> void:
	arcade = arcade_skin
	if _parts != null:
		remove_child(_parts)
		_parts.queue_free()
	_left = null
	_right = null
	_glows.clear()
	_parts = Node3D.new()
	_parts.name = "Parts"
	add_child(_parts)
	var skin: Array = SKINS[arcade]
	var body_mat := _surface(skin[0], 0.05, 0.42 if arcade else 0.5)
	var shoulder_mat := _surface(skin[1], 0.0, 0.62)
	var plinth_mat := _surface(skin[2], 0.0, 0.6)
	var trim_mat := _surface(skin[3], 0.85, 0.32)
	var back_mat := _surface(skin[7], 0.0, 0.9)
	var center_z: float = FACE_Z - DEPTH / 2.0
	var board_y: float = TableView.BOARD_CENTER.y
	# ── 몸체: 아래 둥근 상자 + 위 반원 아치(둥근 머리). 앞면 모서리는 장식선이 덮는다.
	var lower_height: float = ARCH_Y + 0.1 - PLINTH_HEIGHT
	Kit.rounded_box(_parts, "CabinetStatic", Vector3(BODY_WIDTH, lower_height, DEPTH), Vector3(0, PLINTH_HEIGHT + lower_height / 2.0, center_z), body_mat, 0.07)
	var arch := CylinderMesh.new()
	arch.top_radius = BODY_WIDTH / 2.0
	arch.bottom_radius = BODY_WIDTH / 2.0
	arch.height = DEPTH
	arch.radial_segments = 64
	arch.rings = 1
	var arch_node := Kit.mesh_node(_parts, "CabinetArch", arch, Vector3(0, ARCH_Y, center_z), body_mat)
	arch_node.rotation.x = PI / 2
	# 아치 앞 가장자리 장식선(펍 = 황동, 오락실 = 크림 몸체에 얇은 시안/마젠타 빛 — 요청서 "네온은 얇은 테두리에만").
	var left_line := _glow(skin[4], 1.6) if arcade else trim_mat
	var right_line := _glow(skin[5], 1.6) if arcade else trim_mat
	for spec: Array in [[left_line, PI / 2, PI], [right_line, 0.0, PI / 2]]:
		var edge := Kit.mesh_node(_parts, "ArchTrim", Kit.arc_tube_mesh(BODY_WIDTH / 2.0 - 0.02, 0.025, spec[1], spec[2], 32, 8), Vector3(0, ARCH_Y, FACE_Z + 0.005), spec[0])
		edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for side: float in [-1.0, 1.0]:
		Kit.rounded_box(_parts, "SideTrim", Vector3(0.05, ARCH_Y - PLINTH_HEIGHT - 0.1, 0.05),
			Vector3(side * (BODY_WIDTH / 2.0 - 0.02), (ARCH_Y + PLINTH_HEIGHT) / 2.0, FACE_Z + 0.005), left_line if side < 0 else right_line, 0.02)
	# ── 어깨(셔터 수납 포켓): 양옆 둥근 기둥. 그 앞에 롤 셔터 통이 붙는다(아래 셔터 단계).
	# 2026-11-08: 예전 통풍 슬릿 5줄은 셔터 통에 가려져 뺐다.
	for side: float in [-1.0, 1.0]:
		var shoulder_x: float = side * (BODY_WIDTH / 2.0 + 0.06)
		Kit.rounded_box(_parts, "ShoulderPocket", Vector3(0.36, 2.55, 0.66), Vector3(shoulder_x, board_y - 0.05, FACE_Z - 0.26), shoulder_mat, 0.14)
	# ── 받침(넓고 낮은 판 — 요청서 "받침 발 없음").
	Kit.rounded_box(_parts, "Plinth", Vector3(BODY_WIDTH + 0.4, PLINTH_HEIGHT, DEPTH + 0.2), Vector3(0, PLINTH_HEIGHT / 2.0, center_z + 0.06), plinth_mat, 0.06)
	Kit.rounded_box(_parts, "PlinthLight", Vector3(BODY_WIDTH, 0.03, 0.02), Vector3(0, PLINTH_HEIGHT - 0.04, center_z + 0.06 + (DEPTH + 0.2) / 2.0), _glow(skin[4], 1.2), 0.01)
	# ── 과녁 뒤 어두운 무득점 받침(조각이 벌어지면 이것이 보인다 — 빛나는 가짜 득점면을 남기지 않는다).
	var plate := CylinderMesh.new()
	plate.top_radius = RING_RADIUS - 0.03
	plate.bottom_radius = RING_RADIUS - 0.03
	plate.height = 0.04
	plate.radial_segments = 64
	plate.rings = 1
	Kit.mesh_node(_parts, "Backplate", plate, Vector3(0, board_y, -0.11), back_mat).rotation.x = PI / 2
	# ── 과녁 둘레 테두리 조명(왼쪽 반 / 오른쪽 반). 상태가 바뀌면 맥박이 빨라진다.
	for spec: Array in [[_glow(skin[4], 2.2), PI / 2, PI * 1.5], [_glow(skin[5], 2.2), -PI / 2, PI / 2]]:
		var ring := Kit.mesh_node(_parts, "LightRing", Kit.arc_tube_mesh(RING_RADIUS, 0.022, spec[1], spec[2], 48, 8), Vector3(0, board_y, -0.07), spec[0])
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# ── 아래 상태 화면(StatusAnchor): 평소 DARTY, 머신 효과가 걸리면 무엇이 걸렸는지.
	Kit.rounded_box(_parts, "StatusFrame", Vector3(1.34, 0.64, 0.06), Vector3(0, 1.2, FACE_Z + 0.02), trim_mat, 0.05)
	Kit.rounded_box(_parts, "StatusScreen", Vector3(1.24, 0.54, 0.04), Vector3(0, 1.2, FACE_Z + 0.045), _surface("0b0d14", 0.0, 0.25), 0.03)
	_status = Kit.label(_parts, "StatusText", "DARTY", Vector3(0, 1.2, FACE_Z + 0.07), 96, Color(skin[4]), 0.0042)
	_status.shaded = false
	_status.outline_size = 0
	# 동전 문(장식).
	Kit.rounded_box(_parts, "CoinDoor", Vector3(0.52, 0.34, 0.03), Vector3(0, 0.58, FACE_Z + 0.015), shoulder_mat, 0.04)
	Kit.rounded_box(_parts, "CoinSlot", Vector3(0.16, 0.025, 0.02), Vector3(0, 0.62, FACE_Z + 0.035), _glow(skin[5], 1.4), 0.01)
	# ── 롤 셔터(왼쪽 = 가림판 카드, 오른쪽 = 대칭 부품. 지금 규칙은 왼쪽만 쓴다).
	# 날개 앞면 = 과녁 면 + SHUTTER_Z(가린 쪽 다트가 박히는 면, BoardChaos.SHUTTER_FRONT) → 노드는 날개 두께 절반만큼 뒤에 둔다.
	# 앞 바: 펍 = 황동, 오락실 = 그쪽 테두리 빛 색(요청서 "네온은 얇은 테두리에만").
	var shutter_mat := _surface(skin[6], 0.35 if not arcade else 0.1, 0.45)
	for side: float in [-1.0, 1.0]:
		var shutter := RollShutter.new()
		shutter.name = "ShutterLeft" if side < 0 else "ShutterRight"
		shutter.position = Vector3(0, board_y, SHUTTER_Z - RollShutter.SLAT_THICK / 2.0)
		_parts.add_child(shutter)
		var lead_mat: Material = trim_mat if not arcade else (left_line if side < 0 else right_line)
		shutter.build(side, SHUTTER_HALF, SHUTTER_HEIGHT, shutter_mat, lead_mat, shoulder_mat, trim_mat, plinth_mat)
		if side < 0:
			_left = shutter
		else:
			_right = shutter
	show_chaos({}, 0.0)


## 아수라장 모양을 옮긴다(셔터 펼침·상태 글자·조명 맥박). shape = BoardChaos.pose(...). 판정은 하지 않는다.
func show_chaos(shape: Dictionary, delta: float) -> void:
	_time += delta
	_close_left = float(shape.get("shutter", 0.0))
	if _left != null:
		_left.show_amount(_close_left, delta)
		_right.show_amount(_close_right, delta)
	var words := PackedStringArray()
	if absf(float(shape.get("angle", 0.0))) > 0.001:
		words.append("회전!")
	if float(shape.get("split", 0.0)) > 0.001:
		words.append("분리!")
	if _close_left > 0.01:
		words.append("셔터!")
	if _status != null:
		_status.text = "DARTY" if words.is_empty() else " ".join(words)
		_status.font_size = 96 if words.is_empty() else 64
	# 효과가 걸리면 테두리 빛이 빨리 깜박인다(과녁 숫자와 겨루지 않도록 밝기 폭은 작게).
	var speed: float = 1.4 if words.is_empty() else 7.0
	var pulse: float = 1.0 + sin(_time * speed) * (0.08 if words.is_empty() else 0.3)
	for material in _glows:
		material.emission_energy_multiplier = float(material.get_meta("energy", 2.0)) * pulse


## 왼쪽 셔터를 스스로 여닫는다(2026-11-08). F5 본 게임은 game.gd 가 매 프레임 show_chaos 로 방장 모양을 넘기므로 쓰지 않는다.
## F6 카드 라운드(game/card_round/flow/turn_effects.gd)처럼 "가림판이 걸렸다/풀렸다"만 아는 쪽이 부른다.
## 닫힐 때는 판정과 같은 곡선(BoardChaos.shutter_amount), 열릴 때는 F5 와 같은 속도로 0 에 다가간다.
func slide_shutter(closed: bool) -> void:
	if closed and not _auto_closed:
		_auto_age = 0.0
	_auto_closed = closed
	set_process(true)


func _process(delta: float) -> void:
	var close: float
	if _auto_closed:
		_auto_age += delta
		close = BoardChaos.shutter_amount(_auto_age)
	else:
		close = lerpf(_close_left, 0.0, 1.0 - exp(-OPEN_RATE * delta))
		if close < 0.001:
			close = 0.0
			set_process(false)
	show_chaos({"shutter": close}, delta)


func _surface(color: String, metal: float, rough: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.metallic = metal
	material.roughness = rough
	return material


## 스스로 빛나는 얇은 선(머신마다 따로 만든다 — 맥박이 다른 물건에 번지지 않게).
func _glow(color: String, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.emission_enabled = true
	material.emission = Color(color)
	material.emission_energy_multiplier = energy
	material.set_meta("energy", energy)
	_glows.append(material)
	return material
