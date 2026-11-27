class_name ScoreWall
extends Node3D
## 과녁 벽 왼쪽(예전 분필 점수판 자리)에 세우는 사람별 점수판. 사람 수만큼(2~4장) 판이 생긴다.
## [2026-11-27 사용자 요청] 점수를 화면 UI 로 겹쳐 그리지 않고 맵에 세운다 ·
## 누구 차례인지 · 누가 벌칙을 받는지 한눈에 알 수 있게 한다.
##
## [좌표] 과녁 벽 앞면을 바라보는 XY 평면(글자 앞면 법선 +Z). 투척선에서 보면 다트 머신 왼쪽 어깨 바깥이다.
## [누가 부르나] 방장·손님 구분 없이 GameView 가 스냅샷을 받을 때마다 show_players 를 부른다 — 모든 화면이 같은 값을 본다.

const MeshKit = preload("res://art/mesh_kit.gd")

## 판이 놓이는 벽 위 가운데(x·y)와 판이 차지하는 칸 크기(m). art/pub/room/room_board.gd 의 왼쪽 칠판과 같은 자리다.
## 2026-11-27 "판을 좀 크게": 칠판 한 장(0.98 × 1.62) 안에 맞추던 것을 벽 칸 전체로 넓혔다 —
## 가로는 머신 어깨(x −1.35)와 특징 판넬 끝(x −2.7) 사이, 세로는 아치 틀 아래까지 쓴다.
const CENTER := Vector2(-2.02, 2.52)
const AREA := Vector2(1.26, 2.0)
## 벽 안쪽 면에서 판까지(m). 칠판면(+0.116)보다 앞이라 겹쳐 깜빡이지 않는다.
const DEPTH: float = 0.14

## 과녁 벽 안쪽 면의 z. 세우는 쪽(TableView)이 넣는다 — 여기서 TableView 를 보지 않아 서로 참조하지 않는다.
var wall_z: float = 0.0
## 판 한 장의 높이 한계(m). 사람이 적으면 크게, 많으면 칸에 맞춰 줄인다.
const PLATE_MIN: float = 0.34
const PLATE_MAX: float = 0.58
## 지금 차례·벌칙인 판은 앞으로 나오고 조금 커진다(색만으로는 색약인 사람이 구분하지 못한다 — 기획 2-4).
const TURN_LIFT: float = 0.04
const TURN_SCALE: float = 1.07
## 이름 칸에 넣는 글자 수. 길면 잘라 점수 칸을 침범하지 않게 한다.
const NAME_LENGTH: int = 6

## 판마다 [뿌리 Node3D, 판 메시, 자리 색 띠, 이름 Label3D, 차례·벌칙 꼬리표 Label3D, 점수 Label3D].
var _plates: Array = []
## 마지막으로 그린 내용. 같으면 다시 쓰지 않는다(스냅샷마다 부른다).
var _key: String = ""


## players = 경기 참가자(순서는 상관없다 — 자리 번호로 정렬한다), active_id = 지금 던지는 사람,
## punish_id = 벌칙으로 과녁판에 묶인 사람(0 = 벌칙 아님).
func show_players(players: Array, active_id: int, punish_id: int) -> void:
	var sorted: Array = players.duplicate()
	sorted.sort_custom(func(a: MatchPlayer, b: MatchPlayer) -> bool: return a.seat < b.seat)
	if sorted.size() != _plates.size():
		_rebuild(sorted.size())
	var key: String = "%d|%d" % [active_id, punish_id]
	for player: MatchPlayer in sorted:
		key += "|%d:%s:%.0f" % [player.seat, player.display_name, player.score]
	if key == _key:
		return
	_key = key
	for index in range(sorted.size()):
		_paint(index, sorted[index], active_id, punish_id)


## 사람 수가 바뀌면 판을 다시 만든다(입장·퇴장·다음 경기).
func _rebuild(count: int) -> void:
	for plate: Array in _plates:
		(plate[0] as Node3D).queue_free()
	_plates.clear()
	_key = ""
	if count <= 0:
		return
	var step: float = AREA.y / float(count)
	var height: float = clampf(step - 0.05, PLATE_MIN, PLATE_MAX)
	var slate: StandardMaterial3D = MeshKit.material("ScorePlateRest", "16211f")
	for index in range(count):
		var root := Node3D.new()
		root.name = "Plate_%d" % (index + 1)
		# 위에서부터 자리 순서대로 쌓는다.
		root.position = Vector3(CENTER.x, CENTER.y + AREA.y / 2.0 - step * (index + 0.5), _plate_z(false))
		add_child(root)
		var panel: MeshInstance3D = MeshKit.rounded_box(root, "Panel", Vector3(AREA.x, height, 0.03), Vector3.ZERO, slate, 0.03)
		# 자리 색 띠: 판이 어두울 때도 누구 칸인지 바로 보인다(색은 _paint 가 자리 번호에 맞춘다).
		var stripe: MeshInstance3D = MeshKit.box(root, "Stripe", Vector3(0.05, height - 0.09, 0.012),
			Vector3(-AREA.x / 2.0 + 0.045, 0, 0.022), slate)
		# 윗줄 = 이름(칸 전체를 쓴다), 아랫줄 = 왼쪽에 차례·벌칙 꼬리표 · 오른쪽에 큰 점수.
		# 이름과 꼬리표를 한 줄에 두면 이름이 긴 사람에게서 서로 밀어낸다 → 줄을 나눴다.
		var name_label: Label3D = _text(root, "Name", Vector3(-AREA.x / 2.0 + 0.08, height * 0.29, 0.024), 40, HORIZONTAL_ALIGNMENT_LEFT)
		var tag: Label3D = _text(root, "Tag", Vector3(-AREA.x / 2.0 + 0.08, -height * 0.22, 0.024), 34, HORIZONTAL_ALIGNMENT_LEFT)
		var score: Label3D = _text(root, "Score", Vector3(AREA.x / 2.0 - 0.06, -height * 0.2, 0.024), 76, HORIZONTAL_ALIGNMENT_RIGHT)
		_plates.append([root, panel, stripe, name_label, tag, score])


## 판 앞면의 z. 차례·벌칙인 판만 앞으로 나온다.
func _plate_z(lifted: bool) -> float:
	return wall_z + DEPTH + (TURN_LIFT if lifted else 0.0)


## 벽에 붙는 글자 한 줄. 빌보드를 끄고(판에 쓴 글씨다) 외곽선을 둘러 밝은 판 위에서도 읽히게 한다.
func _text(parent: Node3D, name_: String, at: Vector3, size: int, align: int) -> Label3D:
	var label: Label3D = MeshKit.label(parent, name_, "", at, size, Color.WHITE, 0.0036)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.outline_size = 10
	return label


## 판 한 장의 색과 글자. 벌칙으로 묶인 사람에게는 차례가 돌아오지 않으므로(MatchController._begin_turn)
## 꼬리표 칸에 "차례"와 "벌칙"이 같이 들어가는 일은 없다.
func _paint(index: int, player: MatchPlayer, active_id: int, punish_id: int) -> void:
	var plate: Array = _plates[index]
	var throwing: bool = player.peer_id == active_id
	var punished: bool = punish_id != 0 and player.peer_id == punish_id
	var seat_hex: String = PlayerLook.hex(player.seat)
	(plate[2] as MeshInstance3D).material_override = MeshKit.material("ScoreStripe_%d" % player.seat, seat_hex, 0.0, 1.2)
	if punished:
		(plate[1] as MeshInstance3D).material_override = MeshKit.material("ScorePlatePunish", "b8392f", 0.0, 1.0)
	elif throwing:
		(plate[1] as MeshInstance3D).material_override = MeshKit.material("ScorePlateTurn_%d" % player.seat, seat_hex, 0.0, 1.4)
	else:
		(plate[1] as MeshInstance3D).material_override = MeshKit.material("ScorePlateRest", "16211f")
	# 판이 밝아지면 글자를 어둡게 바꿔야 읽힌다(벌칙 빨강은 어두워서 밝은 글자 그대로).
	var dark_text: bool = throwing and not punished
	var ink: Color = Color("10201d") if dark_text else Color("f6efdd")
	var outline: Color = Color("f2e8d2") if dark_text else Color("0c1513")
	for slot: int in [3, 4, 5]:
		var label := plate[slot] as Label3D
		label.modulate = ink
		label.outline_modulate = outline
	(plate[3] as Label3D).text = PlayerLook.tag(player.seat, player.display_name.left(NAME_LENGTH))
	(plate[4] as Label3D).text = "☠ 벌칙" if punished else ("▶ 차례" if throwing else "")
	(plate[5] as Label3D).text = "%.0f" % player.score
	var root := plate[0] as Node3D
	root.position.z = _plate_z(throwing or punished)
	root.scale = Vector3.ONE * (TURN_SCALE if throwing or punished else 1.0)
