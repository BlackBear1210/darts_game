extends RefCounted
## 카드 라운드 부품(flow/*.gd)이 함께 쓰는 상자: 장면 참조 · 규칙 · 설정 · 시계 · 난수 · 진행 상태.
## 감독(card_round.gd)이 _ready 에서 한 번 채우고 모든 부품에 같은 상자를 넘긴다.
## 부품끼리 필요한 것은 감독이 각 부품의 setup() 인자로 직접 꽂아 준다.
## 이 상자에는 부품을 넣지 않는다 → 부품 스크립트끼리 preload 가 돌고 돌지 않는다.

const Rules = preload("res://game/card_round/rules/round_rules.gd")
const TableCards = preload("res://game/card_round/cards/table_cards.gd")
const HandFan = preload("res://game/card_round/cards/hand_fan.gd")
const Hud = preload("res://game/card_round/ui/card_round_hud.gd")
const ScreenDebuff = preload("res://game/card_round/fx/screen_debuff.gd")
const VoiceFx = preload("res://game/card_round/fx/voice_fx.gd")
const RoundSettings = preload("res://game/card_round/flow/round_settings.gd")
const SynthAudio = preload("res://art/showcase/synth_audio.gd")

const SEAT_COUNT: int = 4
## 내 자리 = 2번(바가지). 테이블 뒤쪽이라 과녁이 정면이다.
const LOCAL_SEAT: int = 1
## 벌칙 원판이 서는 곳(과녁 바로 앞 레인).
const WHEEL_POSITION := Vector3(0, 1.25, -4.6)

## 진행 단계: intro(시작) · cards(카드) · darts(다트) · punish(벌칙 원판) · ending(경기 끝) · results(결과 화면).
var phase: String = "intro"
## 카드를 다 나눠 주고 공개한 뒤 = 꺼내 들기·쓰기가 가능하다.
var cards_open: bool = false
var game_over: bool = false
## true 면 내 자리도 봇처럼 움직인다(자동 검사·화면 캡처용).
var autoplay: bool = false
## 화면 캡처 중(캡처 폴더가 정해짐). 속도·섞기 모션 선택이 캡처에 맞게 바뀐다.
var capturing: bool = false
## 장면 시계(초). Engine.time_scale(빨리 감기)이 반영된 시간이다.
var now: float = 0.0
var random := RandomNumberGenerator.new()
## 자동 검사(tests/test_card_round.gd)가 읽는 통계.
var stats: Dictionary = {"dealt": 0, "used": 0, "darts": 0, "refilled_to_7": false, "body_hits": 0, "nullified": 0, "rounds": 0}

var root: Node3D
var camera: Camera3D
## 날아간 다트가 붙는 노드(차례가 끝나면 비운다).
var darts_root: Node3D
var table: TableView
var table_cards: TableCards
var hud: Hud
var debuff: ScreenDebuff
var voice: VoiceFx
var audio: SynthAudio
var rules: Rules
var settings: RoundSettings
## 자리 번호(0~3) 순서의 캐릭터와 참가자 정보.
var actors: Array[PlayerView] = []
var players: Array[MatchPlayer] = []
## 캐릭터 왼손 부채(자리별)와 내 화면 왼쪽 아래 1인칭 부채.
var fans: Array[HandFan] = []
var local_fan: HandFan


## 이 자리를 봇이 움직이는가(내 자리는 autoplay 일 때만).
func bot_driven(seat: int) -> bool:
	return autoplay or seat != LOCAL_SEAT


## 화면에 쓰는 이름: "▲2번 바가지".
func name_of(seat: int) -> String:
	return "%s%d번 %s" % [PlayerLook.SYMBOLS[seat], seat + 1, rules.seats[seat].name]


## 한국어 조사: 끝 글자에 받침이 있으면 with_final(이·을), 없으면 without_final(가·를). attach 면 낱말 뒤에 붙여 돌려준다.
static func josa(word: String, with_final: String, without_final: String, attach: bool = true) -> String:
	var code: int = word.unicode_at(word.length() - 1) if not word.is_empty() else 0
	var has_final: bool = code >= 0xAC00 and code <= 0xD7A3 and (code - 0xAC00) % 28 != 0
	var particle: String = with_final if has_final else without_final
	return word + particle if attach else particle


## 바닥 방향 → 캐릭터 몸 회전(y). 캐릭터 정면 = -Z.
static func facing(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)


## seconds 초 기다린다(빨리 감기가 반영된다).
func wait(seconds: float) -> void:
	await root.get_tree().create_timer(seconds).timeout


## condition 이 참이 되거나 timeout 초가 지날 때까지 매 프레임 기다린다.
func wait_until(condition: Callable, timeout: float) -> void:
	var limit: float = now + timeout
	while not bool(condition.call()) and now < limit:
		await root.get_tree().process_frame
