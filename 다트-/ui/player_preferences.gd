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
static var loaded: bool = false
const KEYS: Array[String] = ["master", "music", "sfx", "ui_scale", "sensitivity", "visual_effects", "reduced_motion", "fullscreen", "quality", "interact_key"]

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
	apply()

static func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master, 0.0001)))
	AudioServer.set_bus_mute(0, master <= 0)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

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
	file.save("user://player_preferences.cfg")
	apply()
