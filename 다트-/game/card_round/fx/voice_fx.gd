extends Node
## 목소리 변조 시연. 아직 음성 채팅이 없어서 캐릭터마다 합성 "웅얼웅얼" 목소리를 들려준다(녹음 파일 없음).
## 다른 사람을 다트로 맞힌 사람은 차례가 끝날 때까지 목소리가 낮고 찌그러지게 변조된다(사용자 기획 2026-10-28).
## 실제 음성 채팅이 생기면 그 사람 음성 재생 버스를 WARP_BUS 로 바꾸기만 하면 같은 효과가 난다.

const CLEAN_BUS := "CardRoundVoice"
const WARP_BUS := "CardRoundVoiceWarp"
const SAMPLE_RATE: int = 11025
## 자리마다 기본 목소리 높이(Hz).
const BASE_PITCH: Array[float] = [190.0, 135.0, 235.0, 165.0]
## 모음 두 공명(F1, F2) — 아·이·우·에·오 비슷하게.
const VOWELS: Array[Vector2] = [Vector2(730, 1090), Vector2(300, 2250), Vector2(320, 870), Vector2(530, 1840), Vector2(570, 840)]

var muted: bool = false
var _players: Dictionary = {}
var _streams: Dictionary = {}
var _warped: Dictionary = {}


## actors[seat] 머리 높이에 3D 소리 나는 곳을 붙인다.
func setup(actors: Array) -> void:
	_make_buses()
	for seat in range(actors.size()):
		var player := AudioStreamPlayer3D.new()
		player.name = "Voice"
		player.position = Vector3.UP * 1.45
		player.unit_size = 5.0
		player.bus = CLEAN_BUS
		(actors[seat] as Node3D).add_child(player)
		_players[seat] = player
		_streams[seat] = {"talk": _babble(seat, 1.2, 6, 11), "ouch": _babble(seat, 0.4, 2, 23)}


## 자리 seat 캐릭터가 말한다(kind = 소리 종류). 음소거면 조용히 넘어간다.
func say(seat: int, kind: String) -> void:
	var player := _players.get(seat) as AudioStreamPlayer3D
	if player == null or muted:
		return
	player.stream = _streams[seat][kind]
	player.bus = WARP_BUS if is_warped(seat) else CLEAN_BUS
	player.play()


## 목소리 변조를 켜고 끈다(변조 버스로 보내기). 맞힌 사람의 벌(취기·마우스·난시)과 함께 쓴다.
func set_warped(seat: int, warped: bool) -> void:
	_warped[seat] = warped
	var player := _players.get(seat) as AudioStreamPlayer3D
	if player != null:
		player.bus = WARP_BUS if warped else CLEAN_BUS


## 지금 목소리가 변조 중인가.
func is_warped(seat: int) -> bool:
	return bool(_warped.get(seat, false))


func _exit_tree() -> void:
	for bus_name in [WARP_BUS, CLEAN_BUS]:
		var index: int = AudioServer.get_bus_index(bus_name)
		if index > 0:
			AudioServer.remove_bus(index)


## 실행 중에만 버스 두 개를 만든다(프로젝트 버스 설정 파일은 바꾸지 않는다).
func _make_buses() -> void:
	if AudioServer.get_bus_index(CLEAN_BUS) < 0:
		AudioServer.add_bus()
		var clean: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(clean, CLEAN_BUS)
		AudioServer.set_bus_send(clean, "Master")
	if AudioServer.get_bus_index(WARP_BUS) < 0:
		AudioServer.add_bus()
		var warp: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(warp, WARP_BUS)
		AudioServer.set_bus_send(warp, "Master")
		var pitch := AudioEffectPitchShift.new()
		pitch.pitch_scale = 0.62
		AudioServer.add_bus_effect(warp, pitch)
		var phaser := AudioEffectPhaser.new()
		phaser.rate_hz = 6.0
		phaser.depth = 0.8
		AudioServer.add_bus_effect(warp, phaser)
		var distortion := AudioEffectDistortion.new()
		distortion.mode = AudioEffectDistortion.MODE_OVERDRIVE
		distortion.drive = 0.55
		AudioServer.add_bus_effect(warp, distortion)


## 음절 몇 개짜리 합성 목소리: 기본 높이의 배음을 모음 공명 근처에서 키운다.
static func _babble(seat: int, seconds: float, syllables: int, seed_value: int) -> AudioStreamWAV:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value + seat * 101
	var count: int = int(SAMPLE_RATE * seconds)
	var per: int = count / syllables
	var samples := PackedFloat32Array()
	samples.resize(count)
	var peak: float = 0.001
	for s in range(syllables):
		var pitch: float = BASE_PITCH[seat % BASE_PITCH.size()] * random.randf_range(0.85, 1.2)
		var vowel: Vector2 = VOWELS[random.randi_range(0, VOWELS.size() - 1)]
		var amplitudes := PackedFloat32Array()
		for harmonic in range(1, 9):
			var frequency: float = pitch * harmonic
			var first: float = exp(-pow(frequency - vowel.x, 2) / (2.0 * 130.0 * 130.0))
			var second: float = exp(-pow(frequency - vowel.y, 2) / (2.0 * 220.0 * 220.0)) * 0.7
			amplitudes.append(first + second + 0.06 / harmonic)
		for i in range(per):
			var index: int = s * per + i
			var t: float = float(i) / SAMPLE_RATE
			var envelope: float = pow(sin(PI * float(i) / per), 0.6)
			var glide: float = 1.0 + 0.08 * float(i) / per
			var value: float = 0.0
			for harmonic in range(amplitudes.size()):
				value += amplitudes[harmonic] * sin(TAU * pitch * glide * (harmonic + 1) * t)
			samples[index] = value * envelope
			peak = maxf(peak, absf(samples[index]))
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in range(count):
		data.encode_s16(i * 2, int(samples[i] / peak * 0.7 * 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.data = data
	return wav
