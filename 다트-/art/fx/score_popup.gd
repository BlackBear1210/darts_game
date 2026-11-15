extends Node3D
## 다트가 과녁에 꽂힌 자리에서 점수가 3D 글자로 "퐁" 튀어나오는 효과(2026-11-15 사용자 요청 — How to Fish 처럼 손맛 나는 점수).
## 화면마다 각자 재생하는 "보이기만 하는 것"이다. 점수 판정은 방장(MatchController)이 하고, 여기서는 그 결과(MatchState.last_hit)를 보여 주기만 한다.
##
## 움직임(1.3초):
##   0.00~0.28초  0 → 1.35배로 튀어나왔다가 1배로 돌아온다(탄성 — 고무공처럼 출렁).
##   0.00~1.30초  위로 0.55m 떠오른다(처음엔 빠르게, 끝에선 느리게).
##   처음 0.5초   가로·세로가 번갈아 눌렸다 늘어난다(말랑한 젤리 느낌, 점점 잦아든다).
##   마지막 0.35초 투명해지며 사라진다.
## 점수가 클수록 글자가 크고 색이 뜨거워진다(회색 → 크림 → 노랑 → 주황 → 분홍). 40점 이상이면 별가루도 튄다.
## 과녁·다트에 가려지지 않게 깊이 검사를 끄고(no_depth_test) 늘 카메라를 본다(billboard).
##
## 쓰는 법: const ScorePopup = preload("res://art/fx/score_popup.gd") 후 ScorePopup.spawn(부모, 꽂힌 자리, 점수, 과녁 앞 방향)

const BurstFx = preload("res://art/fx/burst_fx.gd")
const LoungeStyle = preload("res://ui/lounge_style.gd")

const LIFE: float = 1.3
const POP_TIME: float = 0.28
const RISE: float = 0.55
const FADE_TIME: float = 0.35
const WOBBLE_TIME: float = 0.5
## 과녁 면에서 글자를 띄우는 거리(m) · 꽂힌 자리보다 조금 위에서 시작한다.
const LIFT_FROM_BOARD: float = 0.14
const START_UP: float = 0.12
## 글자 크기: 큰 숫자 = font_size × pixel_size ≈ 0.5m — 투척선(과녁에서 7m)에서도 한눈에 읽힌다. 점수가 크면 최대 1.35배.
const NUMBER_FONT_SIZE: int = 150
const WORD_FONT_SIZE: int = 70
const PIXEL_SIZE: float = 0.0034

## [최소 점수, 숫자 색, 한마디]. 위에서부터 처음 맞는 줄을 쓴다.
const TIERS: Array = [
	[60, "ff5fa2", "AMAZING!"],
	[40, "ff8a3d", "GREAT!"],
	[20, "ffd34d", "NICE"],
	[1, "fff3dc", ""],
	[-9999, "9a9a9a", "MISS"],
]

var _number: Label3D
var _word: Label3D
var _age: float = 0.0
var _peak: float = 1.0
## 지난 프레임까지 떠오른 높이(이번 프레임에 더 오를 만큼만 옮긴다).
var _last_rise: float = 0.0


## 꽂힌 자리(at)에 점수 하나를 띄운다. normal = 과녁 앞쪽(던진 사람 쪽) 방향. bust = 버스트(점수가 차례 시작으로 돌아감).
static func spawn(parent: Node, at: Vector3, points: int, normal: Vector3, bust := false) -> Node3D:
	var popup := (load("res://art/fx/score_popup.gd") as GDScript).new() as Node3D
	popup.name = "ScorePopup"
	parent.add_child(popup)
	popup.global_position = at + normal.normalized() * LIFT_FROM_BOARD + Vector3.UP * START_UP
	popup.call("_build", points, bust)
	if points >= 40 and not bust and DisplayServer.get_name() != "headless":
		BurstFx.spawn(parent, "stars", at + normal.normalized() * 0.05, normal)
	return popup


func _build(points: int, bust: bool) -> void:
	var tier: Array = TIERS[TIERS.size() - 1]
	for row: Array in TIERS:
		if points >= int(row[0]):
			tier = row
			break
	var color := Color(str(tier[1]))
	var word: String = str(tier[2])
	var text: String = ("+%d" % points) if points > 0 else str(points)
	if bust:
		color = Color("ff4d4d")
		word = "BUST"
		text = "0"
	# 점수가 클수록 크게(0점 = 0.8배 · 60점 이상 = 1.35배).
	_peak = clampf(0.8 + float(points) / 60.0 * 0.55, 0.8, 1.35)
	_number = _label("Number", text, NUMBER_FONT_SIZE, color, 26)
	if not word.is_empty():
		_word = _label("Word", word, WORD_FONT_SIZE, color.lightened(0.15), 18)
		_word.position = Vector3(0, -0.33, 0)
	scale = Vector3.ONE * 0.001


## 글자 한 줄: 영문·숫자 로고 글꼴 + 굵은 어두운 테두리(밝은 크림 벽 앞에서도 읽히게). 깊이 검사 끔 · 늘 카메라를 본다.
func _label(node_name: String, text: String, size: int, color: Color, outline: int) -> Label3D:
	var label := Label3D.new()
	label.name = node_name
	label.text = text
	label.font = LoungeStyle.font("logo")
	label.font_size = size
	label.pixel_size = PIXEL_SIZE
	label.modulate = color
	label.outline_size = outline
	label.outline_modulate = Color("1a1410")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.double_sided = true
	label.shaded = false
	label.render_priority = 20
	label.outline_render_priority = 19
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(label)
	return label


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	# 튀어나오기: 탄성 곡선(넘쳤다가 돌아온다) — Tween.TRANS_ELASTIC 과 같은 모양을 직접 계산한다(노드 하나에 트윈을 안 만든다).
	# (ease-out elastic: t = 0 에서 0, 0.1 쯤 1.3배 넘침, 1 에서 1.)
	var pop: float = 1.0
	if _age < POP_TIME:
		var t: float = _age / POP_TIME
		pop = maxf(0.001, 1.0 + pow(2.0, -10.0 * t) * sin((t * 10.0 - 0.75) * TAU / 3.0))
	# 젤리: 가로·세로가 반대로 출렁(부피는 그대로 보이게), 점점 잦아든다.
	var squash := Vector2.ONE
	if _age < WOBBLE_TIME:
		var fade: float = 1.0 - _age / WOBBLE_TIME
		var wave: float = sin(_age * 30.0) * 0.12 * fade
		squash = Vector2(1.0 + wave, 1.0 - wave)
	scale = Vector3(squash.x, squash.y, 1.0) * pop * _peak
	# 떠오르기: 처음 빠르게, 끝에 느리게(ease-out).
	var rise_t: float = _age / LIFE
	var rise: float = RISE * (1.0 - pow(1.0 - rise_t, 3.0))
	position.y += rise - _last_rise
	_last_rise = rise
	# 사라지기.
	var alpha: float = clampf((LIFE - _age) / FADE_TIME, 0.0, 1.0)
	for label: Label3D in [_number, _word]:
		if label == null:
			continue
		label.modulate.a = alpha
		label.outline_modulate.a = alpha
