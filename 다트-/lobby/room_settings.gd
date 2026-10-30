class_name RoomSettings
extends Resource
## 방장이 정하는 공개 규칙. 비밀번호·개발자 권한은 이 스냅샷에 넣지 않는다.

const Catalog = preload("res://game/card_round/rules/card_catalog.gd")
const PRESETS: Array[String] = ["캐주얼 · 함께 배우기", "파티 · 변수가 가득", "클래식 · 다트에 집중"]
const DESCRIPTIONS: Array[String] = [
	"네온 오락실에서 사칙연산 카드로 놀아요. 음주와 취기 연출은 꺼져 있어요.",
	"펍에서 모든 카드와 소품으로 서로 방해해요. 취기는 약하게 시작하며 조절할 수 있어요.",
	"카드 없이 다트 실력을 겨뤄요. 정해진 라운드의 누적 점수로 승부해요."]

@export var social_lobby: bool = false
@export var solo: bool = false
@export var capacity: int = 4
@export var bot_count: int = 0
@export var room_name: String = "우리들의 DARTY"
@export var private_room: bool = false
@export var theme_id: int = 1
@export var preset: int = 0
@export var win_mode: int = 0 # 0 누적, 1 목표 도달, 2 카운트다운
@export var target_score: int = 300
@export var rounds: int = 5
@export var dart_seconds: float = 30.0
@export var cards_enabled: bool = true
@export var special_cards: bool = false
@export var special_chance: float = 30.0
@export var alcohol: bool = false
@export var intoxication: float = 0.0
@export var drink_on_deal: bool = false
@export var props_enabled: bool = true
@export var hit_stun: float = 1.0
@export var miss_cooldown: float = 2.0
@export var object_volume: float = 0.6
@export var card_weights: Dictionary = {}
@export var disabled_cards: Array[String] = []

const FIELDS: Array[String] = ["social_lobby", "solo", "capacity", "bot_count", "room_name", "private_room", "theme_id", "preset", "win_mode", "target_score", "rounds", "dart_seconds", "cards_enabled", "special_cards", "special_chance", "alcohol", "intoxication", "drink_on_deal", "props_enabled", "hit_stun", "miss_cooldown", "object_volume", "card_weights", "disabled_cards"]

func _init() -> void:
	for entry: Dictionary in Catalog.CARDS: card_weights[str(entry.id)] = 1.0

func apply_preset(index: int) -> void:
	preset = clampi(index, 0, 2)
	theme_id = 0 if preset == 1 else 1
	cards_enabled = preset != 2
	special_cards = preset == 1
	alcohol = preset == 1
	intoxication = 1.0 if alcohol else 0.0
	drink_on_deal = alcohol
	win_mode = 0
	rounds = 5
	card_weights.clear()
	disabled_cards.clear()

func sanitize() -> void:
	capacity = clampi(capacity, 1 if solo else 2, 4)
	bot_count = clampi(bot_count, 0, capacity - 1) if solo else 0
	room_name = room_name.strip_escapes().strip_edges().left(32)
	if room_name.is_empty(): room_name = "우리들의 DARTY"
	theme_id = clampi(theme_id, 0, 1)
	preset = clampi(preset, 0, 2)
	win_mode = clampi(win_mode, 0, 2)
	target_score = clampi(target_score, 50, 1000)
	rounds = clampi(rounds, 1, 20)
	dart_seconds = clampf(dart_seconds, 5, 120) if is_finite(dart_seconds) else 30.0
	special_chance = clampf(special_chance, 0, 100) if is_finite(special_chance) else 30.0
	intoxication = clampf(intoxication, 0, 3) if alcohol and is_finite(intoxication) else 0.0
	drink_on_deal = drink_on_deal and alcohol
	hit_stun = clampf(hit_stun, 0, 3) if is_finite(hit_stun) else 1.0
	miss_cooldown = clampf(miss_cooldown, 0.5, 10) if is_finite(miss_cooldown) else 2.0
	object_volume = clampf(object_volume, 0, 1) if is_finite(object_volume) else 0.6
	var weights: Dictionary = {}
	var disabled: Array[String] = []
	for entry: Dictionary in Catalog.CARDS:
		var id: String = entry.id
		var raw: Variant = card_weights.get(id, 1.0)
		var value: float = float(raw) if raw is float or raw is int else 1.0
		weights[id] = clampf(value, 0.01, 100) if is_finite(value) else 1.0
		if disabled_cards.has(id): disabled.append(id)
	card_weights = weights
	disabled_cards = disabled
	# 모든 카드를 제거해도 무한 추첨이 생기지 않도록 카드를 끈다.
	if allowed_types(false).is_empty() and (not special_cards or allowed_types(true).is_empty()): cards_enabled = false

func allowed_types(special: bool) -> Array[int]:
	var result: Array[int] = []
	for index in range(Catalog.count()):
		var entry: Dictionary = Catalog.card(index)
		if disabled_cards.has(str(entry.id)): continue
		if (int(entry.category) != 0) == special: result.append(index)
	return result

func draw_card(random: RandomNumberGenerator) -> int:
	var special: bool = special_cards and random.randf() * 100.0 < special_chance
	var types: Array[int] = allowed_types(special)
	if types.is_empty(): types = allowed_types(false)
	if types.is_empty() and special_cards: types = allowed_types(true)
	if types.is_empty(): return -1
	var weights := PackedFloat32Array()
	for type in types:
		var entry: Dictionary = Catalog.card(type)
		weights.append(float(entry.get("weight", 1.0)) * float(card_weights.get(str(entry.id), 1.0)))
	return types[random.rand_weighted(weights)]

func to_snapshot() -> Dictionary:
	var data: Dictionary = {}
	for key in FIELDS: data[key] = get(key)
	return data.duplicate(true)

static func from_snapshot(data: Dictionary) -> RoomSettings:
	var settings := RoomSettings.new()
	for key in FIELDS:
		if not data.has(key): continue
		if key == "disabled_cards":
			if data[key] is Array:
				for item in data[key].slice(0, Catalog.count()):
					if item is String: settings.disabled_cards.append(item)
		elif (settings.get(key) is int or settings.get(key) is float) and (data[key] is int or data[key] is float):
			if is_finite(float(data[key])):
				settings.set(key, int(data[key]) if settings.get(key) is int else float(data[key]))
		elif typeof(data[key]) == typeof(settings.get(key)):
			settings.set(key, data[key])
	settings.sanitize()
	return settings
