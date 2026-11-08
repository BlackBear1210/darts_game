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

## 0 = 가끔 한 모금 마시기 · 1 = 바텐더(가끔 손님 쪽을 가리킴) · 2 = 가만히.
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

var _motion: CharacterMotion
var _time: float = 0.0


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
	var posture := CharacterMotion.Posture.SEAT if seated else CharacterMotion.Posture.STAND
	# 시선은 아주 천천히 위아래로(살아 있는 느낌만).
	_motion.animate(delta, 0.0, posture, false, sin(_time * 0.37) * 0.06, false)
