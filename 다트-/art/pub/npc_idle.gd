extends Node3D
## 펍 손님 NPC 의 제자리 동작(2026-11-02 요청: 구석 테이블 둘은 마시기, 벽 쪽 하나는 잔 닦다가 마시기).
##
## 손님 몸은 선수와 같은 캐릭터 씬(art/characters/chr_guest_*.tscn)을 그대로 쓰고,
## 여기서는 오른팔 피벗만 천천히 돌린다. 걷지도, 부딪히지도, 경기에 끼어들지도 않는다.
## 캐릭터 씬은 정적 메시 묶기(art/static_batch.gd `collect`)에서 빠지므로 실행 중에 움직여도 된다.
##
## 이 노드가 손님을 감싸는 부모다(자식 하나 = 캐릭터 씬). 부모에 스크립트를 두면
## 생성물(pub_game.tscn)에 그대로 저장되고, 캐릭터 씬 자체는 손대지 않는다.

## 0 = 한 모금씩 마시기 · 1 = 잔을 닦다가 가끔 한 모금.
@export var style: int = 0
## 사람마다 박자를 다르게 준다(같이 움직이면 기계처럼 보인다).
@export var phase_seconds: float = 0.0
## 한 바퀴 도는 시간(초).
@export var period: float = 6.0

## 팔을 내렸을 때와 입으로 가져갔을 때의 각도(라디안).
const REST_ANGLE: float = -0.35
const SIP_ANGLE: float = -1.9
const WIPE_ANGLE: float = -0.75

var _arm: Node3D
var _time: float = 0.0


func _ready() -> void:
	var model := get_child(0) as Node3D if get_child_count() > 0 else null
	if model != null:
		_arm = model.get_node_or_null("Body/ArmR") as Node3D
	_time = phase_seconds
	set_process(_arm != null)


func _process(delta: float) -> void:
	_time += delta
	var ratio: float = fmod(_time, period) / period
	if style == 1:
		# 잔 닦기: 팔을 작게 흔들다가 한 바퀴에 한 번 입으로 가져간다.
		if ratio < 0.7:
			_arm.rotation.x = WIPE_ANGLE + sin(_time * 6.0) * 0.12
			_arm.rotation.z = sin(_time * 6.0) * 0.18
		else:
			_arm.rotation.x = lerpf(WIPE_ANGLE, SIP_ANGLE, _bell((ratio - 0.7) / 0.3))
			_arm.rotation.z = 0.0
	else:
		# 마시기: 천천히 들었다가 내린다.
		_arm.rotation.x = lerpf(REST_ANGLE, SIP_ANGLE, _bell(ratio))


## 0 → 1 → 0 으로 한 번 부풀었다 가라앉는 값.
func _bell(ratio: float) -> float:
	return sin(clampf(ratio, 0.0, 1.0) * PI)
