extends RefCounted
## 던지는 곳과 막는 곳 나누기(2026-10-28 사용자 피드백: 던지는 사람 바로 앞에 겹쳐 서면 무조건 막히던 문제).
## 바닥에 선 두 개를 긋는다(z 는 과녁 쪽이 작다).
##   던지는 선(THROW_LINE_Z) — 차례인 사람은 이 선 뒤의 "던지는 칸"에서만 던질 수 있다.
##   방해선(BLOCK_LINE_Z)   — 막는 사람은 이 선 너머(과녁 쪽)에서만 설 수 있다.
## 방해선 ~ 던지는 칸 뒤까지의 레인(|x| < LANE_HALF)은 "차례인 사람만" 구역: 다른 사람이 들어오면 밀려나고, 봇은 옆길로 돌아간다.
## 두 선 간격 1.6m 면 다트가 대부분 머리 위로 지나간다 → 서 있기만 하면 낮게 던진 것만 막히고(약 4할), 점프하면 거의 다 막힌다.
## (rules/dart_solver.gd 의 몸 캡슐 판정으로 계산한 값 — 작업기록 2026-10-28 참고. 시연값, 팀 확정 전.)

const Context = preload("res://game/card_round/flow/round_context.gd")
const CardFaces = preload("res://game/card_round/cards/card_faces.gd")

const THROW_LINE_Z: float = -1.1
## 던지는 칸의 뒤 끝(테이블 쪽). 던지는 칸 = 던지는 선 ~ 여기.
const THROW_BOX_BACK_Z: float = -0.3
const BLOCK_LINE_Z: float = -2.7
## 레인 반폭(m). 이 밖(옆)은 누구나 다닐 수 있다.
const LANE_HALF: float = 1.6
## 다른 사람이 못 들어가는 구역의 뒤 끝 = 던지는 칸 뒤 끝 + 몸 반지름(던지는 사람과 겹쳐 서지 못하게).
const KEEP_OUT_BACK_Z: float = THROW_BOX_BACK_Z + 0.3
## 봇이 서는 곳: 던지는 사람(던지는 선 바로 뒤), 막는 사람(방해선과 앞 벽 사이).
const THROW_STAND_Z: float = -0.95
const BLOCK_STAND_Z: float = -2.8
## 봇이 구역을 돌아갈 때 지나는 옆길 x.
const DETOUR_X: float = LANE_HALF + 0.65
## 처음부터 구역 안에 있던 사람(막 차례가 끝난 사람 등)을 밀어내는 속도(m/s).
const PUSH_SPEED: float = 3.0
## 내가 구역에 막혔을 때 안내 글을 다시 띄우기까지(초).
const HINT_SECONDS: float = 3.0

const THROW_COLOR := Color("e2c477")
const BLOCK_COLOR := Color("ff7a5c")

## 지금 던지는 사람(없으면 -1). set_active 로 바꾼다.
var active: int = -1

var _ctx: Context
var _was_inside: Array[bool] = [false, false, false, false]
var _hint_at: float = -INF


## 감독이 시작할 때 한 번: 함께 쓰는 상자를 받는다.
func setup(ctx: Context) -> void:
	_ctx = ctx


## 던지는 사람이 바뀐다(차례·벌칙 시작 = 그 자리, 끝 = -1).
## 이미 구역 안에 서 있던 사람은 순간이동하지 않고 천천히 밀려나도록 표시해 둔다.
func set_active(seat: int) -> void:
	active = seat
	for other in range(Context.SEAT_COUNT):
		_was_inside[other] = in_keep_out(_ctx.actors[other].position)


## 다른 사람이 못 들어가는 구역 안인가(바닥 x·z 만 본다. 테두리 위는 밖).
static func in_keep_out(point: Vector3) -> bool:
	return absf(point.x) < LANE_HALF and point.z > BLOCK_LINE_Z and point.z < KEEP_OUT_BACK_Z


## 던지는 칸 안인가(차례인 사람은 여기서만 던진다).
static func in_throw_box(point: Vector3) -> bool:
	return absf(point.x) < LANE_HALF and point.z >= THROW_LINE_Z and point.z <= THROW_BOX_BACK_Z


## 봇 걷기 경유점: from → to 가 구역을 지나가면 옆길(DETOUR_X)로 돌아간다. 마지막 점은 언제나 to.
## from 이 구역 안이면(막 차례가 끝난 사람) 먼저 가장 가까운 테두리 밖으로 나간다.
static func route(from: Vector3, to: Vector3) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var at := from
	if in_keep_out(at):
		at = _edge_point(at, 0.15)
		points.append(at)
	if _crosses(at, to):
		var side: float = signf(at.x + to.x)
		if side == 0.0:
			side = 1.0
		var back := Vector3(side * DETOUR_X, 0, KEEP_OUT_BACK_Z + 0.25)
		var front := Vector3(side * DETOUR_X, 0, BLOCK_STAND_Z)
		# 구역 뒤쪽에서 출발하면 뒤 모퉁이 → 앞 모퉁이, 앞쪽에서 출발하면 반대 순서.
		var corners: Array[Vector3] = [back, front]
		if at.z <= (BLOCK_LINE_Z + KEEP_OUT_BACK_Z) * 0.5:
			corners.reverse()
		for corner in corners:
			points.append(corner)
			if not _crosses(corner, to):
				break
	points.append(to)
	return points


## 매 물리 프레임: 차례가 아닌 사람이 구역에 들어오면 밀어낸다.
## 밖에서 걸어 들어오면 벽처럼 가장 가까운 테두리로 되돌리고, 처음부터 안에 있었으면 천천히 밀어낸다.
func keep_out(delta: float) -> void:
	for seat in range(Context.SEAT_COUNT):
		var actor: PlayerView = _ctx.actors[seat]
		var inside: bool = active >= 0 and seat != active and actor.visible and not actor.seated and in_keep_out(actor.position)
		if inside:
			if _was_inside[seat]:
				actor.position = actor.position.move_toward(_edge_point(actor.position, 0.05), PUSH_SPEED * delta)
			else:
				actor.position = _edge_point(actor.position, 0.0)
				_ctx.stats.zone_bumps = int(_ctx.stats.zone_bumps) + 1
				if seat == Context.LOCAL_SEAT and not _ctx.autoplay and _ctx.now >= _hint_at:
					_hint_at = _ctx.now + HINT_SECONDS
					_ctx.hud.toast("던지는 칸 근처는 차례인 사람만 · 막으려면 옆으로 돌아 방해선 너머(과녁 쪽)로", BLOCK_COLOR.lightened(0.3), 1.8)
		_was_inside[seat] = inside and in_keep_out(actor.position)


## 바닥 표시를 만든다: 던지는 칸(금색)·던지는 선, 비워 두는 길(붉은 기운)·방해선, 글자.
## 펍 바닥에 원래 쓰인 "투 척 선"(실제 경기용, 앞 벽 쪽)은 이 시연과 헷갈리므로 숨긴다.
func build_marks(parent: Node3D, pub: Node) -> void:
	for node in pub.find_children("OcheText", "Label3D", true, false):
		(node as Label3D).visible = false
	var marks := Node3D.new()
	marks.name = "ThrowZoneMarks"
	parent.add_child(marks)
	var width: float = LANE_HALF * 2.0
	_floor_box(marks, Vector3(0, 0.03, THROW_LINE_Z), Vector2(width, 0.07), THROW_COLOR)
	_floor_box(marks, Vector3(0, 0.026, (THROW_LINE_Z + THROW_BOX_BACK_Z) * 0.5), Vector2(width, THROW_BOX_BACK_Z - THROW_LINE_Z), Color(THROW_COLOR, 0.13))
	_floor_box(marks, Vector3(0, 0.03, BLOCK_LINE_Z), Vector2(width, 0.07), BLOCK_COLOR)
	_floor_box(marks, Vector3(0, 0.026, (BLOCK_LINE_Z + THROW_LINE_Z) * 0.5), Vector2(width, THROW_LINE_Z - BLOCK_LINE_Z), Color(BLOCK_COLOR, 0.07))
	for side in [-1.0, 1.0]:
		_floor_box(marks, Vector3(side * LANE_HALF, 0.03, (BLOCK_LINE_Z + THROW_BOX_BACK_Z) * 0.5), Vector2(0.04, THROW_BOX_BACK_Z - BLOCK_LINE_Z), Color(BLOCK_COLOR, 0.5))
	_floor_text(marks, "던지는 칸 · 차례인 사람만", Vector3(0, 0.04, THROW_LINE_Z + 0.42), THROW_COLOR)
	_floor_text(marks, "비워 두는 길", Vector3(0, 0.04, (BLOCK_LINE_Z + THROW_LINE_Z) * 0.5), Color(BLOCK_COLOR, 0.75))
	_floor_text(marks, "방해선 · 막는 사람은 이 너머", Vector3(0, 0.04, BLOCK_LINE_Z - 0.3), BLOCK_COLOR)


## 테두리에서 가장 가까운 구역 밖 점(margin 만큼 더 바깥).
static func _edge_point(point: Vector3, margin: float) -> Vector3:
	var options: Array[Vector3] = [
		Vector3(point.x, point.y, KEEP_OUT_BACK_Z + margin),
		Vector3(point.x, point.y, BLOCK_LINE_Z - margin),
		Vector3(-LANE_HALF - margin, point.y, point.z),
		Vector3(LANE_HALF + margin, point.y, point.z)]
	var best: Vector3 = options[0]
	for option in options:
		if option.distance_to(point) < best.distance_to(point):
			best = option
	return best


## 바닥에서 a → b 로 곧장 걸으면 구역을 지나가는가(선분을 촘촘히 짚어 본다).
static func _crosses(a: Vector3, b: Vector3) -> bool:
	for i in range(1, 25):
		if in_keep_out(a.lerp(b, i / 24.0)):
			return true
	return false


## 바닥에 붙은 얇은 색 상자(그림자 없음, 빛 영향 없음).
static func _floor_box(parent: Node3D, at: Vector3, size: Vector2, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x, 0.004, size.y)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var box := MeshInstance3D.new()
	box.mesh = mesh
	box.material_override = material
	box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	box.position = at
	parent.add_child(box)


## 바닥에 눕힌 글자(테이블 쪽에서 과녁을 보며 읽힌다 — 펍의 "투 척 선" 글자와 같은 눕힘).
static func _floor_text(parent: Node3D, text: String, at: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = CardFaces.bold_font()
	label.font_size = 44
	label.pixel_size = 0.004
	label.modulate = color
	label.outline_size = 0
	label.rotation_degrees = Vector3(-90, 0, 0)
	label.position = at
	parent.add_child(label)
