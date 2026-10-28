extends RefCounted
## 설정 창(Esc) 값: 파일 저장·불러오기와 "이 번호면 게임에서 무엇인가" 해석만 한다.
## 설정 이름·선택지 글자는 HUD(ui/card_round_hud.gd SETTINGS)에 있고, 여기는 선택지 번호(0, 1, 2…)만 다룬다.
## 새 설정을 더하려면: HUD SETTINGS 에 한 줄 + 아래 values 에 기본값 + 필요하면 해석 함수 하나.

const Rules = preload("res://game/card_round/rules/round_rules.gd")
const ShuffleMotions = preload("res://game/card_round/cards/shuffle_motions.gd")

const PATH := "user://card_round_settings.cfg"
const SECTION := "card_round"

## 기본값 = 각 설정의 첫 번째 선택지.
## mark 쓴 카드 표시 · shuffle 섞기 모션 · reward 방해 보상 · win 승리 조건 · speed 속도 · voice 합성 목소리
## ("draw" 뽑는 곳은 2026-10-28 피드백으로 없앴다 — 한 장마다 무작위. 예전 저장 파일에 남아 있어도 읽지 않는다.)
var values: Dictionary = {"mark": 0, "shuffle": 0, "reward": 0, "win": 0, "speed": 0, "voice": 0}
## false 면 파일에 읽고 쓰지 않는다(자동 검사가 사용자의 저장을 덮어쓰지 않게).
var persist: bool = true


## 설정 파일(user://)을 읽는다. persist = false(자동 검사)면 읽지 않고 기본값을 쓴다.
func load_file() -> void:
	if not persist:
		return
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		return
	for key: String in values:
		values[key] = int(file.get_value(SECTION, key, values[key]))


## 설정 파일(user://)에 쓴다. persist = false(자동 검사)면 쓰지 않는다(사용자 저장 보호).
func save_file() -> void:
	if not persist:
		return
	var file := ConfigFile.new()
	for key: String in values:
		file.set_value(SECTION, key, values[key])
	file.save(PATH)


## 쓴 카드 표시 방식(CardView.Mark: 0 = 빨간 페인트 X, 1 = 그을림).
func mark() -> int:
	return int(values.mark)



## 방해 보상 방식(설정 'reward').
func reward_mode() -> Rules.RewardMode:
	return int(values.reward) as Rules.RewardMode


## 승리 조건(설정 'win'). 새 게임부터 적용된다.
func win_mode() -> Rules.WinMode:
	match int(values.win):
		1:
			return Rules.WinMode.TARGET_SCORE
		2:
			return Rules.WinMode.COUNTDOWN
	return Rules.WinMode.ROUND_LIMIT


## 목소리 끄기(설정 'voice').
func voice_muted() -> bool:
	return int(values.voice) == 1


## 기본 게임 속도(Engine.time_scale). 자동 진행은 빠르게, 캡처할 때는 장면이 보이게 조금만 빠르게.
func base_speed(autoplay: bool, capturing: bool) -> float:
	if autoplay:
		return 1.6 if capturing else 4.0
	return [1.0, 1.5, 2.0][clampi(int(values.speed), 0, 2)]


## 이번 라운드 섞기 모션 번호(ShuffleMotions.Style). 0 = 무작위, 1~ = 고른 모션.
## 캡처 때 무작위면 라운드마다 다른 모션을 찍는다.
func shuffle_style(round_number: int, random: RandomNumberGenerator, capturing: bool) -> int:
	var choice: int = int(values.shuffle)
	if choice == 0:
		if capturing:
			return (round_number - 1) % ShuffleMotions.STYLE_NAMES.size()
		return random.randi_range(0, ShuffleMotions.STYLE_NAMES.size() - 1)
	return choice - 1
