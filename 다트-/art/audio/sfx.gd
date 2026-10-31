extends RefCounted
## 로비·라운지·오락기 효과음을 수학식으로 즉석 합성한다(녹음 파일 없음 → 저작권 걱정 없음).
## 나중에 실제 녹음 효과음(.ogg/.wav)이 생기면 art/audio/<kind>.ogg 로 넣으면 그 파일을 먼저 쓴다.
##
## 쓰는 법: Sfx.play(부모 노드, "glass", -6.0) 또는 Sfx.play_at(부모 노드, "glass", 위치, -6.0)
## 소리 종류: whoosh(휙) thunk(다트 꽂힘) glass(병 깨짐) crack(나무 부러짐) bounce(통통) crank(가챠 손잡이)
##           pop(캡슐 열림) coin(동전) buzzer(종료 부저) swish(골인) squeak(고무 장난감) motor(집게 모터) fanfare(당첨)
##           gulp(꿀꺽 — 병 마시기, 2026-10-31) · tick(남은 시간 째깍 — 위 가운데 라운드 표시, 2026-10-31 저녁)
##           pop_up(감정표현 말풍선이 뜰 때 톡)
##           riffle(덱 섞기 촤라락) · deal(카드 한 장 휙 — 나눠 주기) — 2026-10-31 늦은 밤 카드 충전 라운드 연출(game/table/deck_show.gd)

const SAMPLE_RATE := 22050
static var _cache: Dictionary = {}


static func stream(kind: String) -> AudioStream:
	if _cache.has(kind):
		return _cache[kind]
	var recorded := "res://art/audio/%s.ogg" % kind
	var result: AudioStream = load(recorded) as AudioStream if ResourceLoader.exists(recorded) else _synth(kind)
	_cache[kind] = result
	return result


## 화면 소리(UI·1인칭). 다 재생하면 스스로 지운다.
static func play(parent: Node, kind: String, volume_db: float = -6.0, pitch: float = 1.0) -> void:
	if parent == null or not parent.is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream(kind)
	player.volume_db = volume_db
	player.pitch_scale = pitch
	parent.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


## 공간 소리(방 안 위치에서 난다).
static func play_at(parent: Node, kind: String, at: Vector3, volume_db: float = -4.0, pitch: float = 1.0) -> void:
	if parent == null or not parent.is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream(kind)
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.max_distance = 22.0
	parent.add_child(player)
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()


static func _synth(kind: String) -> AudioStreamWAV:
	var seconds: float = {"whoosh": 0.22, "thunk": 0.26, "glass": 0.95, "crack": 0.4, "bounce": 0.18,
		"crank": 0.5, "pop": 0.3, "coin": 0.35, "buzzer": 0.8, "swish": 0.45, "squeak": 0.3,
		"motor": 0.6, "fanfare": 0.9, "gulp": 0.8, "tick": 0.06, "pop_up": 0.14, "ding": 1.1,
		"riffle": 0.7, "deal": 0.09}.get(kind, 0.25)
	var count := int(SAMPLE_RATE * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	# 시드를 고정해 매번 같은 소리가 나게 한다.
	rng.seed = hash(kind)
	var noise_low := 0.0
	# 유리: 깨지는 순간 뒤로 파편이 바닥에 떨어지며 "짤랑"거리는 짧은 고음들(x = 시각, y = 높이). 2026-10-31 추가.
	var tinkles: Array[Vector2] = []
	if kind == "glass":
		for n in range(16):
			tinkles.append(Vector2(rng.randf_range(0.05, seconds * 0.8), rng.randf_range(2600.0, 7400.0)))
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var left := 1.0 - float(i) / count
		var noise := rng.randf_range(-1.0, 1.0)
		noise_low = lerpf(noise_low, noise, 0.08)
		var value := 0.0
		match kind:
			"whoosh":
				# 가운데가 불룩한 바람 소리. 낮은 잡음만 남겨 부드럽게.
				value = noise_low * sin(PI * t / seconds) * 0.9
			"thunk":
				# 코르크판에 박히는 "턱": 낮은 사인 + 아주 짧은 딱 소리.
				value = sin(TAU * (120.0 + 80.0 * exp(-t * 40)) * t) * exp(-t * 16) * 0.75 + noise * exp(-t * 90) * 0.5
			"glass":
				# 깨지는 유리: 높은 사인 여럿이 흩어지며 잡음과 함께 사라진다.
				for partial: float in [2350.0, 3170.0, 4410.0, 5230.0]:
					value += sin(TAU * partial * t + rng.randf() * 0.2) * exp(-t * (7.0 + partial / 900.0)) * 0.12
				value += noise * exp(-t * 9) * 0.45 * (1.0 if fmod(t, 0.045) < 0.02 else 0.4)
				for tinkle in tinkles:
					if t >= tinkle.x:
						var since: float = t - tinkle.x
						value += sin(TAU * tinkle.y * since) * exp(-since * 55.0) * 0.15
			"gulp":
				# 꿀꺽 세 번: 목에서 나는 낮은 "꿀" 소리가 짧게 아래로 꺾이고 거품 잡음이 조금 섞인다.
				var beat := fmod(t, 0.26)
				value = sin(TAU * (230.0 - 300.0 * beat) * beat) * exp(-beat * 18.0) * 0.6 + noise_low * exp(-beat * 26.0) * 0.3
			"crack":
				value = (noise * 0.8 + sin(TAU * 210 * t) * 0.4) * exp(-t * 14) * (1.0 if t < 0.05 or fmod(t, 0.07) < 0.025 else 0.35)
			"bounce":
				value = sin(TAU * (260.0 - 120.0 * t / seconds) * t) * exp(-t * 18) * 0.8
			"crank":
				# 딸깍딸깍 세 번.
				var click := fmod(t, seconds / 3.0)
				value = (noise * exp(-click * 160) * 0.8 + sin(TAU * 900 * t) * exp(-click * 90) * 0.3)
			"pop":
				value = sin(TAU * (500.0 + 900.0 * t) * t) * exp(-t * 22) * 0.6 + noise * exp(-t * 80) * 0.6
			"tick":
				# 시계 초침처럼 짧고 마른 소리: 높은 사인 + 아주 빠른 감쇠.
				value = sin(TAU * 1800 * t) * exp(-t * 90.0) * 0.35
			"pop_up":
				# 말풍선이 톡 튀어나오는 소리: 짧게 위로 미끄러지는 음.
				value = sin(TAU * (500.0 + 2200.0 * t) * t) * exp(-t * 22.0) * 0.4
			"riffle":
				# 덱 섞기: 카드 모서리가 빠르게 튕기는 마른 딸깍(초당 약 55번)이 점점 빨라졌다가 "탁" 정리 소리로 끝난다.
				var flick := fmod(t * (45.0 + 30.0 * t / seconds), 1.0)
				value = noise * exp(-flick * 40.0) * 0.45 * minf(1.0, left * 6.0) + (noise_low * exp(-(t - seconds * 0.86) * 40.0) * 0.5 if t > seconds * 0.86 else 0.0)
			"deal":
				# 카드 한 장이 공기를 가르는 짧은 "휙" + 끝의 가벼운 탁.
				value = noise * sin(PI * t / seconds) * 0.35 + noise_low * exp(-maxf(0.0, t - seconds * 0.8) * 60.0) * (0.3 if t > seconds * 0.8 else 0.0)
			"ding":
				# 바 종(2026-10-31 밤 건드리기): 맑은 기음 + 어긋난 배음 두 개가 천천히 사라진다(작은 종 "딩~").
				value = (sin(TAU * 1320 * t) * 0.5 + sin(TAU * 3170 * t) * 0.22 * exp(-t * 5.0) + sin(TAU * 2640 * t) * 0.12) * exp(-t * 3.2) * 0.5
			"coin":
				value = (sin(TAU * 988 * t) if t < 0.09 else sin(TAU * 1319 * t)) * exp(-fmod(t, 0.09) * 6) * 0.3 * left
			"buzzer":
				value = signf(sin(TAU * 140 * t)) * 0.22 * (1.0 if t < seconds - 0.05 else left * 20.0)
			"swish":
				value = noise_low * exp(-t * 6) * 0.8 + sin(TAU * 1568 * t) * exp(-maxf(0.0, t - 0.1) * 10) * (0.2 if t > 0.1 else 0.0)
			"squeak":
				value = sin(TAU * (900.0 + 500.0 * sin(t * 30.0)) * t) * sin(PI * t / seconds) * 0.35
			"motor":
				value = (sin(TAU * 95 * t) * 0.4 + sin(TAU * 190 * t) * 0.2 + noise_low * 0.4) * (0.6 + 0.4 * sin(t * 50.0)) * minf(1.0, left * 8.0)
			"fanfare":
				var note: float = [523.25, 659.25, 783.99, 1046.5][mini(3, int(t / 0.16))]
				value = (sin(TAU * note * t) + 0.4 * sin(TAU * note * 2.0 * t)) * 0.18 * minf(1.0, left * 4.0)
			_:
				value = noise * exp(-t * 30) * 0.4
		data.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.data = data
	return wav
