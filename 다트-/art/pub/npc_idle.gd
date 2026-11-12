extends Node3D
## 펍 손님·바텐더·오락실 직원 NPC 의 제자리 동작. 이 노드가 캐릭터를 감싸는 부모다(자식 "Character" = 캐릭터 씬).
##
## 2026-11-08 사용자 지적 "바에 사람이 디자인이 다르고 의자에 앉아 있지도 않아":
##   예전 손님은 옛 상자 캐릭터(art/characters/chr_guest_*.tscn)라 선수(리깅 캐릭터)와 생김새가 달랐고,
##   앉는 자세는 옛 모델의 다리 노드 이름에만 맞아서 바 스툴(앉는 면 0.8m) 위에서는 선 채로 스툴을 뚫었다.
##   → 선수와 같은 리깅 캐릭터(art/characters/rigged/player_character.tscn)를 쓰고, 선수와 같은 몸짓 도구
##     CharacterMotion 으로 앉기(Seated_Stool)·서기(Idle)·마시기(Drink_R)·가리키기(Point_R)를 튼다.
##     높은 바 스툴은 앉는 면 높이 차이만큼 몸을 올려 앉힌다(spawn 의 seat_top).
## 2026-11-08(오후) 캐릭터가 Tripo 모델로 바뀌어 셔츠 색 바꾸기·안경 부품이 없어졌다 → 옷은 art/pub/npc_outfit.gd 가
##   뼈에 점토 부품을 붙여 입힌다(바텐더 = 중절모·콧수염·나비넥타이·조끼·소매 밴드·어깨 수건·앞치마, 손님 = 모자·안경).
## 걷지도, 부딪히지도, 경기에 끼어들지도 않는다(충돌 없음). 캐릭터 씬은 정적 메시 묶기(art/static_batch.gd)에서 빠진다.
## 만드는 곳: art/pub/game_room_builder.gd(펍 손님·바텐더 → pub_game.tscn 에 저장), game/lounge/arcade/arcade_room.gd(주스 가게 직원).

const CHARACTER_SCENE := "res://art/characters/rigged/player_character.tscn"
const SCRIPT_PATH := "res://art/pub/npc_idle.gd"
## 의상 부품(class_name 대신 preload — 열린 편집기가 새 class_name 을 못 읽는 함정).
const NpcOutfit = preload("res://art/pub/npc_outfit.gd")
## Seated_Stool 모션이 맞춰진 앉는 면 높이(m) = 선수 의자(TableView.STOOL_HEIGHT).
const SEAT_TOP := 0.6

## 0 = 가끔 한 모금 마시기 · 1 = 바텐더(가끔 손님 쪽을 가리킴) · 2 = 가만히
## · 3 = 서빙(art/pub/pub_service.gd 가 걷기·손 뻗기를 넣는다) · 4 = 시가 피우기(재떨이에서 들어 물고 "후" 내뿜기).
@export var style: int = 0
## 사람마다 박자를 다르게 준다(같이 움직이면 기계처럼 보인다).
@export var phase_seconds: float = 0.0
## 한 바퀴 도는 시간(초).
@export var period: float = 7.0
@export var seated: bool = false
## 모자·가게 앞치마 색(손님 모자, 주스 직원 앞치마). 예전 이름 shirt 는 셔츠 색이었다.
@export var shirt: Color = Color("6b8f7a")
@export var glasses: bool = false
## NpcOutfit.Outfit: 0 손님(맨머리) · 1 바텐더 · 2 주스 가게 직원 · 3 손님(비니) · 4 손님(야구 모자).
@export var outfit: int = 0
## 서빙(style 3): PubService 가 넣는다. walk_ratio = 걷는 빠르기 비율(0 = 서 있음), reaching = 오른팔을 앞으로 뻗는다.
var walk_ratio: float = 0.0
var reaching: bool = false

var _motion: CharacterMotion
var _time: float = 0.0
## 시가 피우기 부품(style 4).
const CigarSmoke = preload("res://art/pub/cigar_smoke.gd")
const PubParts = preload("res://art/pub/pub_parts.gd")
## 시가 한 대 주기(비율): 들어 올림 → 입에 물고 빨기 → 내림 → "후" 내뿜기 → 손을 내리고 쉰다(불씨 연기만 오른다).
const SMOKE_LIFT := Vector2(0.18, 0.3)
const SMOKE_HOLD_END := 0.46
const SMOKE_LOWER_END := 0.56
const SMOKE_EXHALE := Vector2(0.5, 0.66)
var _skeleton: Skeleton3D
var _hand: int = -1
var _head: int = -1
var _cigar: Node3D
var _ember: MeshInstance3D
var _wisp: CPUParticles3D
var _puff: CPUParticles3D
## 시가 몸통 길이 절반(0.7배 = 0.15m 의 반). 불 붙은 끝(모델 +Z, 빨간 끝 — 4면 렌더로 확인)이 +CIGAR_HALF 다.
const CIGAR_HALF := 0.075


## NPC 한 명을 만든다. at = 서 있는(앉은 의자) 바닥 자리, look = 바라볼 곳.
## seat_top = 앉을 의자 윗면 높이(높은 바 스툴이면 그 차이만큼 몸을 올린다).
static func spawn(parent: Node, node_name: String, at: Vector3, look: Vector3, shirt_color: Color, sit: bool,
		act := 0, phase := 0.0, seat_top := SEAT_TOP, wear_glasses := false, dress_as := 0) -> Node3D:
	var holder := Node3D.new()
	holder.name = node_name
	holder.set_script(load(SCRIPT_PATH))
	holder.set("style", act)
	holder.set("phase_seconds", phase)
	holder.set("seated", sit)
	holder.set("shirt", shirt_color)
	holder.set("glasses", wear_glasses)
	holder.set("outfit", dress_as)
	# 캐릭터를 먼저 넣고 나서 부모에 붙인다: 부모가 이미 화면 트리 안이면(오락실 주스 직원) 붙이는 순간 _ready 가 도는데,
	# 그때 "Character" 가 없으면 몸짓·옷이 꺼진 채 T자 자세로 서 있었다(2026-11-08 미리보기에서 발견).
	var model := (load(CHARACTER_SCENE) as PackedScene).instantiate() as Node3D
	model.name = "Character"
	holder.add_child(model)
	parent.add_child(holder)
	holder.position = at + Vector3(0, (seat_top - SEAT_TOP) if sit else 0.0, 0)
	# 리깅 캐릭터 정면 = -Z → -Z 가 look 을 보도록 돌린다.
	holder.rotation.y = atan2(at.x - look.x, at.z - look.z)
	return holder


func _ready() -> void:
	var model := get_node_or_null("Character") as Node3D
	if model == null or model.find_children("*", "AnimationPlayer", true, false).is_empty():
		set_process(false)
		return
	_dress(model)
	_motion = CharacterMotion.new(model, phase_seconds)
	_time = phase_seconds
	if style == 4:
		_setup_cigar(model)


## 옷 입히기(art/pub/npc_outfit.gd). 캐릭터 GLB·재질은 건드리지 않고 뼈에 부품만 붙인다.
func _dress(model: Node3D) -> void:
	NpcOutfit.dress(model, outfit, shirt, glasses)


func _process(delta: float) -> void:
	_time += delta
	var ratio: float = fmod(_time, period) / period
	match style:
		0:
			# 한 바퀴 끝 무렵에 한 모금(0 → 1 진행 후 0 으로).
			_motion.drinking = clampf((ratio - 0.7) / 0.3, 0.0, 1.0) if ratio > 0.7 else 0.0
		1:
			_motion.pointing = ratio > 0.78 and ratio < 0.9
		3:
			_motion.pointing = reaching
			_motion.drinking = 0.0
		4:
			_motion.drinking = _smoke_lift(ratio)
	var posture := CharacterMotion.Posture.SEAT if seated else CharacterMotion.Posture.STAND
	# 시선은 아주 천천히 위아래로(살아 있는 느낌만).
	_motion.animate(delta, walk_ratio, posture, false, sin(_time * 0.37) * 0.06, false)
	if style == 4:
		_smoke_step(ratio)


## 시가 피우기 팔 높이(CharacterMotion.drinking 0~1 = 손이 입까지).
func _smoke_lift(ratio: float) -> float:
	if ratio < SMOKE_LIFT.x or ratio > SMOKE_LOWER_END:
		return 0.0
	if ratio < SMOKE_LIFT.y:
		return (ratio - SMOKE_LIFT.x) / (SMOKE_LIFT.y - SMOKE_LIFT.x)
	if ratio < SMOKE_HOLD_END:
		return 1.0
	return 1.0 - (ratio - SMOKE_HOLD_END) / (SMOKE_LOWER_END - SMOKE_HOLD_END)


## 시가·불씨·연기 두 가지를 만든다. 시가는 늘 오른손 손가락 사이에 끼워 두고(손을 내리면 허리께, 올리면 입),
## 재떨이는 생성기가 손님 앞에 둔다(art/pub/game_room_builder.gd _ashtray).
## 시가·연기는 안쪽(internal) 자식 "SmokeFx" 아래 → 정적 묶기에서 빠지고, 방 생성기가 장면을 저장할 때 같이 저장되지 않는다.
func _setup_cigar(model: Node3D) -> void:
	var found := model.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return
	_skeleton = found[0] as Skeleton3D
	_hand = _skeleton.find_bone("hand.R")
	_head = _skeleton.find_bone("head")
	var fx := Node3D.new()
	fx.name = "SmokeFx"
	add_child(fx, false, Node.INTERNAL_MODE_BACK)
	fx.top_level = true
	_cigar = Node3D.new()
	_cigar.name = "Cigar"
	fx.add_child(_cigar)
	# RG Poly 시가(원래 0.21m, 원점 = 꽁무니, 불 붙은 빨간 끝 = +Z) → 0.7배 = 0.15m. 가운데를 들어 잡는다.
	var body := PubParts.asset(_cigar, "cigar", Vector3(0, 0, -CIGAR_HALF), 0.0, Vector3.ONE * 0.7, "CigarBody", false)
	if body == null:
		var stick := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.009
		cylinder.bottom_radius = 0.009
		cylinder.height = 0.15
		stick.mesh = cylinder
		stick.rotation.x = PI / 2
		_cigar.add_child(stick)
	_ember = MeshInstance3D.new()
	_ember.name = "Ember"
	var ember_mesh := SphereMesh.new()
	ember_mesh.radius = 0.011
	ember_mesh.height = 0.018
	_ember.mesh = ember_mesh
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.6, 0.55, 0.18)
	_ember.material_override = glow
	_ember.position = Vector3(0, 0, CIGAR_HALF)
	_cigar.add_child(_ember)
	_wisp = CigarSmoke.wisp()
	_wisp.position = _ember.position
	_cigar.add_child(_wisp)
	_puff = CigarSmoke.puff()
	fx.add_child(_puff)
	# 손을 입으로 올리는 몸짓은 뼈 수정기(CharacterPoseLayer)가 넣는다 → _process 에서 읽은 손뼈는 수정 전 자세(허리께)다.
	# 수정이 끝난 뒤 알려 주는 신호에서 시가·연기 자리를 잡아야 올린 손을 따라간다(BoneAttachment3D 와 같은 방식).
	_skeleton.skeleton_updated.connect(_place_cigar)


## 매 프레임: 시가 자리(오른손 손가락 사이), 불씨 밝기(빨아들일 때 밝게), "후" 내뿜기.
func _smoke_step(ratio: float) -> void:
	if _cigar == null or _hand < 0:
		return
	var drawing: bool = ratio > SMOKE_LIFT.y and ratio < SMOKE_HOLD_END
	var glow := _ember.material_override as StandardMaterial3D
	var bright: float = 2.6 if drawing else 1.2 + 0.25 * sin(_time * 3.1)
	glow.albedo_color = Color(bright, bright * 0.34, bright * 0.1)
	# 시가 끝 연기는 손이 멈춰 있을 때만 피운다 — 손을 올리고 내리는 동안 뿜으면 알갱이가 손 지나간 길을 따라
	# 점점이 흩어져 보인다(2026-11-08 렌더). 이미 나온 연기는 그 자리(전역 좌표)에서 계속 피어오른다.
	_wisp.emitting = ratio < SMOKE_LIFT.x or ratio > SMOKE_LOWER_END + 0.02
	_puff.emitting = ratio > SMOKE_EXHALE.x and ratio < SMOKE_EXHALE.y


## 뼈 수정이 끝난 자세로 시가(오른손 손가락 사이)와 "후" 연기 자리(입 앞)를 잡는다(Skeleton3D.skeleton_updated).
func _place_cigar() -> void:
	# 장면 제거 중에도 마지막 skeleton_updated가 올 수 있다.
	if not is_inside_tree() or not is_instance_valid(_skeleton) or not _skeleton.is_inside_tree():
		return
	if not is_instance_valid(_cigar) or not _cigar.is_inside_tree() or _hand < 0:
		return
	if not is_instance_valid(_puff) or not _puff.is_inside_tree():
		return
	var lift: float = _motion.drinking
	var hand: Transform3D = _skeleton.global_transform * _skeleton.get_bone_global_pose(_hand)
	var forward: Vector3 = -global_basis.z
	var right: Vector3 = global_basis.x
	# 불 붙은 끝이 몸 바깥 앞쪽(앞 + 오른쪽)을 보고, 입에 물 때는 꽁무니가 입 쪽으로 오게 손 앞에 반 길이만큼 내민다.
	var out: Vector3 = (forward * (0.55 + 0.45 * lift) + right * (0.75 - 0.45 * lift) + Vector3(0, 0.15, 0)).normalized()
	_cigar.global_transform = Transform3D(Basis.looking_at(-out, Vector3.UP), hand.origin + out * (CIGAR_HALF * 0.6) + Vector3(0, 0.015, 0))
	if _head >= 0:
		var head: Transform3D = _skeleton.global_transform * _skeleton.get_bone_global_pose(_head)
		_puff.global_position = head.origin + forward * 0.1 + Vector3(0, 0.02, 0)
		_puff.direction = (_puff.global_basis.inverse() * (forward + Vector3(0, 0.25, 0))).normalized()
