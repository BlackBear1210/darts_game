extends Node3D
## 다트 머신의 롤 셔터 한쪽(2026-11-08, 디자인 담당 소유).
## 사용자 요청: "가림막 카드 효과를 줬을 때 그냥 판때기로 가리는 게 아니라, 차고 문이나 가게 셔터처럼
##   옆에서 슬라이드로 촤라락 하면서 가려지는 효과가 더 좋다."
##
## [모양] 어깨 앞 세로 셔터 통(Housing) + 위·아래 레일(Rail) + 맨 앞 손잡이 바(LeadBar) + 좁은 세로 날개(Slat) 여러 장.
##   날개들은 경첩으로 이어진 커튼 한 장처럼 움직인다: 앞 바가 통에서 가운데(x = 0)로 달려 나가고,
##   그 뒤로 날개가 한 장씩 통의 틈(Slit)에서 빠져나온다 → "촤라락".
##   다 닫힐 무렵 가운데 멈춤 자리에 부딪혀 살짝 되튀었다 돌아온다(쾅). 움직이는 동안은 날개가 레일 안에서 덜컹거린다.
##   다 열리면 날개·앞 바는 모두 통 안에 들어가 안 보인다(예전처럼 판자 더미가 어깨 앞에 남지 않는다).
## [좌표] 원점 = 과녁 중심 높이, 날개 두께 가운데. 부모(다트 머신)가 놓는다.
##   side −1 = 왼쪽 셔터(통이 x −span 바깥에 있고 x 0 까지 닫힌다), +1 = 오른쪽(대칭).
## [쓰는 법] build(...) 한 번 → show_amount(닫힘 0~1, delta) 를 매 프레임. 닫힘 값은 판정 쪽(BoardChaos.shutter_amount)과 같은 값을 받는다.
## 보이기만 한다. 가린 쪽 0점 판정은 규칙(BoardChaos.locate · MatchCards)이 따로 한다.

const Kit = preload("res://art/mesh_kit.gd")
const Sfx = preload("res://art/audio/sfx.gd")

## 날개 수(앞 바 제외). 좁고 많을수록 "촤라락" 느낌이 산다(예전 판자형은 넓은 판 8장).
const SLATS: int = 13
## 앞 바(손잡이가 달린 맨 앞 막대) 폭·두께, 날개 두께, 셔터 통 폭·깊이(m).
const LEAD_WIDTH: float = 0.07
const LEAD_THICK: float = 0.05
const SLAT_THICK: float = 0.03
const HOUSING_WIDTH: float = 0.2
const HOUSING_DEPTH: float = 0.22
## 이웃 날개와 겹치는 폭 — 겹친 둥근 모서리가 날개 사이 홈으로 보인다.
const SLAT_OVERLAP: float = 0.012
## 닫힘 값이 이 비율에 이르면 앞 바가 가운데에 닿는다. 나머지 구간에서 BOUNCE 만큼 되튀었다 돌아온다.
const SLAM_AT: float = 0.8
const BOUNCE: float = 0.09

var side: float = -1.0
var span: float = 1.1
var height: float = 2.2
var pitch: float = 0.08

var _lead: Node3D
var _slats: Array[Node3D] = []
var _amount: float = 0.0
var _edge: float = 0.0
var _time: float = 0.0
var _shake: float = 0.0


## 셔터를 만든다. side_ = −1(왼쪽)/+1(오른쪽), span_ = 닫혔을 때 덮는 폭(가운데 ~ 통 안쪽 끝), height_ = 날개 높이.
## 재질: slat = 날개, lead = 앞 바·손잡이, frame = 셔터 통, rail = 레일, slit = 통의 틈(어두운 색).
func build(side_: float, span_: float, height_: float, slat: Material, lead: Material, frame: Material, rail: Material, slit: Material) -> void:
	side = signf(side_) if side_ != 0.0 else -1.0
	span = span_
	height = height_
	pitch = (span - LEAD_WIDTH) / float(SLATS - 1)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_slats.clear()
	# ── 셔터 통: 날개가 감겨 들어가는 세로 상자. 날개보다 앞뒤로 두꺼워 안에 든 날개를 감춘다.
	var housing_x: float = side * (span + HOUSING_WIDTH / 2.0)
	Kit.rounded_box(self, "Housing", Vector3(HOUSING_WIDTH, height + 0.22, HOUSING_DEPTH), Vector3(housing_x, 0, -0.05), frame, 0.07)
	# 통 안쪽 면의 틈(날개가 나오는 입구)과 위·아래 마개 띠.
	Kit.rounded_box(self, "Slit", Vector3(0.008, height - 0.02, 0.05), Vector3(side * (span - 0.001), 0, 0.0), slit, 0.003)
	for y: float in [-1.0, 1.0]:
		Kit.rounded_box(self, "HousingBand", Vector3(HOUSING_WIDTH + 0.02, 0.05, HOUSING_DEPTH + 0.02), Vector3(housing_x, y * (height / 2.0 + 0.06), -0.05), rail, 0.02)
	# ── 위·아래 레일: 통에서 가운데까지. 날개 끝이 이 홈 안에서 달린다(앞뒤로 날개보다 두껍게).
	for y: float in [-1.0, 1.0]:
		Kit.rounded_box(self, "Rail", Vector3(span, 0.045, 0.075), Vector3(side * span / 2.0, y * (height / 2.0 + 0.012), 0.0), rail, 0.018)
	# ── 커튼: 앞 바 + 날개. 모두 "Curtain" 아래(시험이 날개 수를 센다).
	var curtain := Node3D.new()
	curtain.name = "Curtain"
	add_child(curtain)
	_lead = Kit.rounded_box(curtain, "LeadBar", Vector3(LEAD_WIDTH, height + 0.01, LEAD_THICK), Vector3.ZERO, lead, 0.02)
	# 손잡이(앞 바 아래쪽, 앞으로 튀어나온 둥근 막대).
	Kit.rounded_box(_lead, "Handle", Vector3(0.03, 0.22, 0.05), Vector3(0, -0.35, LEAD_THICK / 2.0 + 0.02), lead, 0.014)
	# 날개는 한 장 걸러 조금 어둡게 — 멀리서 보면 홈이 안 보여 "판자 한 장"처럼 읽히던 것을 줄무늬 셔터로 읽히게 한다.
	var slat_dark := _shaded(slat, 0.14)
	for index in range(SLATS):
		var piece := Kit.rounded_box(curtain, "Slat_%d" % index, Vector3(pitch + SLAT_OVERLAP, height - 0.02, SLAT_THICK), Vector3.ZERO,
			slat if index % 2 == 0 else slat_dark, 0.013)
		_slats.append(piece)
	_edge = side * span
	_place()


## 같은 재질을 조금 어둡게 복사한다(점토 단색 재질만. 다른 재질은 그대로 쓴다).
static func _shaded(material: Material, amount: float) -> Material:
	var base := material as StandardMaterial3D
	if base == null:
		return material
	var copy := base.duplicate() as StandardMaterial3D
	copy.albedo_color = base.albedo_color.darkened(amount)
	return copy


## 날개 수(앞 바 제외).
func slat_count() -> int:
	return _slats.size()


## 닫힘 값(0 = 다 열림, 1 = 다 닫힘)을 그림에 옮긴다. 매 프레임 불러야 덜컹임·소리가 맞는다.
func show_amount(close: float, delta: float) -> void:
	_time += delta
	var before: float = _amount
	_amount = clampf(close, 0.0, 1.0)
	# 소리: 열려 있다가 닫히기 시작하면 "촤라락…쾅", 다 닫혀 있다가 열리기 시작하면 조금 높고 작게.
	if before <= 0.001 and _amount > 0.001:
		_sound(-3.0, 1.0)
	elif before >= 0.999 and _amount < 0.999:
		_sound(-10.0, 1.25)
	var edge: float = side * span * (1.0 - travel(_amount))
	# 덜컹임 세기: 앞 바가 빠를수록 크게(멈추면 0). 한 프레임에 확 사라지지 않게 부드럽게 따라간다.
	var speed: float = absf(edge - _edge) / maxf(delta, 0.001)
	var goal: float = clampf(speed / 3.0, 0.0, 1.0)
	_shake = lerpf(_shake, goal, 1.0 - exp(-maxf(delta, 0.0) * 18.0)) if delta > 0.0 else goal
	_edge = edge
	_place()


## 셔터 소리(art/audio/sfx.gd "shutter" — 날개 덜컹임 촤라락 + 끝의 쾅). 트리 밖(시험 중 만들기만 한 경우)이면 조용히 넘어간다.
func _sound(volume_db: float, pitch_scale: float) -> void:
	if is_inside_tree():
		Sfx.play_at(self, "shutter", global_position + Vector3(side * span * 0.5, 0, 0), volume_db, pitch_scale)


## 닫힘 값 → 앞 바가 간 비율. SLAM_AT 까지는 곧게 달려가 가운데에 부딪히고(감속하지 않아야 "쾅"),
## 그 뒤로는 한 번 되튀었다가 제자리(1)로 돌아온다. 1 을 넘지 않는다 — 가리는 자리가 반대쪽 절반으로 넘어가 보이지 않게.
static func travel(close: float) -> float:
	if close <= 0.0:
		return 0.0
	if close < SLAM_AT:
		return close / SLAM_AT
	var q: float = clampf((close - SLAM_AT) / (1.0 - SLAM_AT), 0.0, 1.0)
	return 1.0 - BOUNCE * sin(q * PI) * (1.0 - q)


## 앞 바와 날개 자리. 날개 i 는 앞 바 뒤로 pitch 씩 이어진다. 통 안으로 깊이 들어간 날개는 숨긴다.
func _place() -> void:
	if _lead == null:
		return
	var outward: float = side
	_lead.position = Vector3(_edge + outward * LEAD_WIDTH / 2.0, 0, 0)
	_lead.rotation.y = sin(_time * 49.0) * 0.05 * _shake
	for index in range(_slats.size()):
		var piece: Node3D = _slats[index]
		var x: float = _edge + outward * (LEAD_WIDTH + (float(index) + 0.5) * pitch)
		# 통 안(|x| > span)으로 반 이상 들어간 날개는 숨긴다 — 통 바깥 끝으로 비죽 나오지 않게.
		piece.visible = absf(x) < span + HOUSING_WIDTH * 0.5
		# 덜컹임: 날개마다 박자가 다른 작은 앞뒤 흔들림 + 비틀림.
		piece.position = Vector3(x, 0, sin(_time * 41.0 + index * 2.7) * 0.008 * _shake)
		piece.rotation.y = sin(_time * 57.0 + index * 1.9) * 0.08 * _shake
