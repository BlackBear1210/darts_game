extends RefCounted
## 개인 표시 설정은 방 규칙과 분리한다. 화면 효과를 꺼도 점수·스턴 판정은 바뀌지 않는다.
static var master: float = 0.8
static var music: float = 0.5
static var sfx: float = 0.7
static var ui_scale: float = 1.0
static var sensitivity: float = 1.0
static var visual_effects: bool = true
static var reduced_motion: bool = false
static var fullscreen: bool = false
static var quality: int = 1
## 상호작용·착석 키(F 또는 R). 2026-10-31: Q·E 는 카드 넘기기 전용이라 E 에서 F 로 옮기고 마시기는 좌클릭이 됐다.
static var interact_key: int = KEY_F
## 음성 채팅(2026-11-01). network/voice_chat.gd 가 읽는다.
## 말하기 방식: 눌러서 말하기(기본 — 실수로 소리가 새지 않게) / 음성 감지(소리가 감도를 넘으면 자동으로 보냄).
const PUSH_TO_TALK: int = 0
const VOICE_DETECT: int = 1
## 눌러서 말하기 키 id 와 화면 이름(같은 순서). V 는 F5 에서 비어 있고 F6 시연의 "V 말하기"와도 같다.
const VOICE_KEYS: Array[String] = ["v", "caps", "mouse4", "mouse5"]
const VOICE_KEY_NAMES: Array[String] = ["V", "Caps Lock", "마우스 뒤로 버튼", "마우스 앞으로 버튼"]
static var voice_enabled: bool = true
static var voice_mode: int = PUSH_TO_TALK
static var voice_key: String = "v"
## 마이크 증폭(1 = 그대로, 0~2)과 음성 감지 감도(0 = 큰 소리만, 1 = 작은 소리도).
static var voice_gain: float = 1.0
static var voice_sensitivity: float = 0.55
## 다른 사람 목소리 전체 볼륨(0~1.5).
static var voice_volume: float = 1.0
## 소리 장치 이름(AudioServer 목록의 글자). 목록에 없으면 "Default".
static var input_device: String = "Default"
static var output_device: String = "Default"
## 사람마다 목소리 볼륨·음소거. 표시 이름 → [볼륨(0~2), 음소거]. 다음 판에도 같은 이름이면 그대로 쓴다.
static var voice_people: Dictionary = {}
static var loaded: bool = false
const KEYS: Array[String] = ["master", "music", "sfx", "ui_scale", "sensitivity", "visual_effects", "reduced_motion", "fullscreen", "quality", "interact_key",
	"voice_enabled", "voice_mode", "voice_key", "voice_gain", "voice_sensitivity", "voice_volume", "input_device", "output_device"]

static func load_saved() -> void:
	if loaded: return
	loaded = true
	var file := ConfigFile.new()
	if file.load("user://player_preferences.cfg") == OK:
		master = clampf(float(file.get_value("audio", "master", 0.8)), 0, 1)
		music = clampf(float(file.get_value("audio", "music", 0.5)), 0, 1)
		sfx = clampf(float(file.get_value("audio", "sfx", 0.7)), 0, 1)
		ui_scale = clampf(float(file.get_value("display", "ui_scale", 1.0)), 0.8, 1.3)
		sensitivity = clampf(float(file.get_value("display", "sensitivity", 1.0)), 0.3, 2.0)
		visual_effects = bool(file.get_value("display", "visual_effects", true))
		reduced_motion = bool(file.get_value("display", "reduced_motion", false))
		fullscreen = bool(file.get_value("display", "fullscreen", false))
		quality = clampi(int(file.get_value("display", "quality", 1)), 0, 2)
		# 예전에 저장한 E(이제 카드 키)는 F 로 옮긴다.
		interact_key = KEY_R if int(file.get_value("keys", "interact", KEY_F)) == KEY_R else KEY_F
		voice_enabled = bool(file.get_value("voice", "enabled", true))
		voice_mode = clampi(int(file.get_value("voice", "mode", PUSH_TO_TALK)), PUSH_TO_TALK, VOICE_DETECT)
		voice_key = str(file.get_value("voice", "key", "v"))
		if not VOICE_KEYS.has(voice_key): voice_key = "v"
		voice_gain = clampf(float(file.get_value("voice", "gain", 1.0)), 0, 2)
		voice_sensitivity = clampf(float(file.get_value("voice", "sensitivity", 0.55)), 0, 1)
		voice_volume = clampf(float(file.get_value("voice", "volume", 1.0)), 0, 1.5)
		input_device = str(file.get_value("voice", "input_device", "Default"))
		output_device = str(file.get_value("voice", "output_device", "Default"))
		var people: Variant = file.get_value("voice", "people", {})
		if people is Dictionary: voice_people = people
	apply()

static func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master, 0.0001)))
	AudioServer.set_bus_mute(0, master <= 0)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	apply_devices()

## 마이크·스피커 장치. 저장한 장치가 빠져 있으면(헤드셋을 뺐을 때) 기본 장치로 돌아간다.
static func apply_devices() -> void:
	AudioServer.input_device = input_device if AudioServer.get_input_device_list().has(input_device) else "Default"
	AudioServer.output_device = output_device if AudioServer.get_output_device_list().has(output_device) else "Default"

## 이 사람 목소리 볼륨(0~2, 기본 1)과 음소거.
static func person_volume(person: String) -> float:
	return float((voice_people.get(person, [1.0, false]) as Array)[0])

static func person_muted(person: String) -> bool:
	return bool((voice_people.get(person, [1.0, false]) as Array)[1])

static func set_person(person: String, volume: float, muted: bool) -> void:
	voice_people[person] = [clampf(volume, 0.0, 2.0), muted]

static func save() -> void:
	var file := ConfigFile.new()
	file.set_value("audio", "master", master)
	file.set_value("audio", "music", music)
	file.set_value("audio", "sfx", sfx)
	file.set_value("display", "ui_scale", ui_scale)
	file.set_value("display", "sensitivity", sensitivity)
	file.set_value("display", "visual_effects", visual_effects)
	file.set_value("display", "reduced_motion", reduced_motion)
	file.set_value("display", "fullscreen", fullscreen)
	file.set_value("display", "quality", quality)
	file.set_value("keys", "interact", interact_key)
	file.set_value("voice", "enabled", voice_enabled)
	file.set_value("voice", "mode", voice_mode)
	file.set_value("voice", "key", voice_key)
	file.set_value("voice", "gain", voice_gain)
	file.set_value("voice", "sensitivity", voice_sensitivity)
	file.set_value("voice", "volume", voice_volume)
	file.set_value("voice", "input_device", input_device)
	file.set_value("voice", "output_device", output_device)
	file.set_value("voice", "people", voice_people)
	file.save("user://player_preferences.cfg")
	apply()
