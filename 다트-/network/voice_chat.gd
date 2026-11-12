extends Node
## 음성 채팅(2026-11-01 사용자 요청: 설정에서 눌러서 말하기 / 음성 감지, 머리 위 스피커, Tab 에서 사람마다 볼륨).
##
## 흐름: 내 마이크(AudioServer 입력) → 16 kHz 모노로 줄이고 μ-law 8비트로 묶음(40 ms) → 방장에게 보냄
##       → 방장이 방 명단을 확인하고 같은 방의 다른 사람에게 그대로 전달 → 받은 화면이 사람마다 따로 재생한다.
## 목소리는 경기 규칙·상태와 무관하다. 방장은 보낸 사람의 실제 peer ID 가 방 명단에 있는지와 크기·속도만 본다.
## NetworkSession 의 자식이라 화면이 바뀌어도 유지되고, 모든 화면에서 경로가 같다(/root/Main/NetworkSession/VoiceChat).

const Preferences = preload("res://ui/player_preferences.gd")

## 보내는 소리의 초당 샘플 수. 목소리를 알아듣기에 충분하고 μ-law 로 말하는 사람당 약 16 KB/s 다.
const RATE: int = 16000
## 한 번에 보내는 샘플 수(40 ms). 작을수록 지연이 줄고 패킷 수가 는다.
const PACKET_SAMPLES: int = 640
## 받는 패킷 크기 상한(바이트). 정상 패킷은 PACKET_SAMPLES 바이트다.
const MAX_PACKET_BYTES: int = 1280
## 보낸 사람마다 1초에 받아 주는 바이트(정상의 2배). 넘치면 방장이 버린다(도배 방지).
const MAX_BYTES_PER_SECOND: float = RATE * 2.0
## 마지막 소리가 온 뒤 이 시간(초)까지 "말하는 중"으로 본다(머리 위 스피커).
const SPEAKING_HOLD: float = 0.3
## 음성 감지: 목소리가 작아져도 이 시간(초) 동안은 계속 보낸다(말끝이 잘리지 않게).
const VAD_HANGOVER: float = 0.4
## 재생 버퍼 길이(초)와, 말을 새로 시작할 때 먼저 깔아 두는 무음(초 — 도착 간격이 흔들려도 끊기지 않게).
const PLAYBACK_SECONDS: float = 0.6
const JITTER_PREFILL: float = 0.08
## 재생 대기열이 이보다 길면(초) 지연이 쌓이지 않게 새 패킷을 버린다.
const MAX_QUEUE: float = 0.4
## 음량 표시 범위(dBFS). 이 사이를 0~1 로 바꿔 막대·스피커 크기에 쓴다.
const METER_FLOOR_DB: float = -60.0
const METER_TOP_DB: float = -10.0
## 음성 감지 문턱(dBFS): 감도 0 = 큰 소리만(VAD_LOUD_DB), 1 = 작은 소리도(VAD_QUIET_DB).
const VAD_LOUD_DB: float = -18.0
const VAD_QUIET_DB: float = -58.0
## 마이크를 못 열었을 때 다시 시도하기까지(초). 매 프레임 장치를 두드리지 않게.
const RETRY_SECONDS: float = 2.0
const BUS_NAME := "Voice"
## "내 목소리 들어보기" 재생 칸(peer ID 는 1부터라 겹치지 않는다).
const TEST_SPEAKER: int = 0

var session: NetworkSession
## 설정 창이 열려 있으면 true → 방이 없어도 마이크를 열어 음량 막대·들어보기를 보여 준다.
var monitoring: bool = false
## 설정 창의 "내 목소리 들어보기"(이어폰 권장). 다른 사람이 듣는 것과 같은 음질로 들린다.
var loopback: bool = false
## 지금 내 목소리를 보내는 중인지(눌러서 말하기 키를 누르고 있거나 음성 감지가 열려 있고, 들을 사람이 있음).
var transmitting: bool = false
## 내 마이크 음량(0~1, 증폭 뒤)과 이번 묶음이 말하기 조건(키·감지)을 넘었는지. 설정 창 막대가 쓴다.
var mic_level: float = 0.0
var mic_open: bool = false
## 마이크 장치를 열었는지(장치가 없거나 꺼 두었으면 false).
var input_active: bool = false

var _bus: int = -1
var _retry_at: float = 0.0
## 장치 소리를 모노로 모아 둔 것과 16 kHz 로 줄이며 읽는 위치(소수).
var _mono := PackedFloat32Array()
var _read_at: float = 0.0
## 16 kHz 로 줄인 소리 중 아직 패킷이 안 된 것.
var _outgoing := PackedFloat32Array()
var _vad_until: float = 0.0
## peer_id → {"player", "playback", "capacity", "last", "level"}
var _speakers: Dictionary = {}
## (방장) 보낸 사람 → {"bytes", "at"}: 1초 예산.
var _budgets: Dictionary = {}
static var _decode_table := PackedFloat32Array()


func _ready() -> void:
	_bus = AudioServer.get_bus_index(BUS_NAME)
	if _bus < 0:
		AudioServer.add_bus()
		_bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_bus, BUS_NAME)
		AudioServer.set_bus_send(_bus, "Master")


func _process(_delta: float) -> void:
	_update_input()
	if input_active:
		var available: int = AudioServer.get_input_frames_available()
		if available > 0:
			feed(AudioServer.get_input_frames(available), AudioServer.get_input_mix_rate())
	_update_speakers()
	AudioServer.set_bus_volume_db(_bus, linear_to_db(maxf(Preferences.voice_volume, 0.0001)))


## 들을 사람이 있거나 설정 창을 열었을 때만 마이크를 연다(쓰지 않을 때 윈도우 마이크 표시가 켜지지 않게).
## 화면 없는 실행(전용 서버·시험)은 마이크가 없다 → 시험은 feed() 로 소리를 넣는다.
func _update_input() -> void:
	var want: bool = Preferences.voice_enabled and DisplayServer.get_name() != "headless" and (monitoring or has_listeners())
	if want == input_active:
		return
	if not want:
		AudioServer.set_input_device_active(false)
		input_active = false
		transmitting = false
		mic_open = false
		mic_level = 0.0
		_mono.clear()
		_outgoing.clear()
		_read_at = 0.0
		return
	if _now() < _retry_at:
		return
	input_active = AudioServer.set_input_device_active(true) == OK
	if not input_active:
		_retry_at = _now() + RETRY_SECONDS


## 나 말고 같은 방에 사람이 있는지(봇은 듣지 않는다).
func has_listeners() -> bool:
	if session == null or session.local_peer_id == 0 or session.is_connecting:
		return false
	if session.room.find_player(session.local_peer_id) == null:
		return false
	return session.human_count() > 1


## 마이크 소리 한 묶음(장치 샘플 수 rate)을 16 kHz 모노로 줄이고, 말하는 중이면 40 ms 씩 보낸다.
func feed(frames: PackedVector2Array, rate: float) -> void:
	if rate <= 0.0 or frames.is_empty():
		return
	var gain: float = Preferences.voice_gain
	for frame: Vector2 in frames:
		_mono.append((frame.x + frame.y) * 0.5 * gain)
	# 상자 평균으로 줄인다(높은 소리가 거칠게 접혀 들리지 않게 간단한 저역 통과를 겸한다).
	var step: float = rate / RATE
	while _read_at + step <= _mono.size():
		var from: int = int(_read_at)
		var to: int = maxi(from + 1, int(_read_at + step))
		var total: float = 0.0
		for index in range(from, to):
			total += _mono[index]
		_outgoing.append(clampf(total / (to - from), -1.0, 1.0))
		_read_at += step
	var used: int = int(_read_at)
	_mono = _mono.slice(used)
	_read_at -= used
	while _outgoing.size() >= PACKET_SAMPLES:
		_send_chunk(_outgoing.slice(0, PACKET_SAMPLES))
		_outgoing = _outgoing.slice(PACKET_SAMPLES)


func _send_chunk(chunk: PackedFloat32Array) -> void:
	var loudness: float = rms_db(chunk)
	mic_level = meter(loudness)
	var now: float = _now()
	if loudness >= vad_threshold_db():
		_vad_until = now + VAD_HANGOVER
	mic_open = now < _vad_until if Preferences.voice_mode == Preferences.VOICE_DETECT else push_to_talk_held()
	transmitting = mic_open and has_listeners()
	if not mic_open:
		return
	var data: PackedByteArray = encode(chunk)
	if loopback and monitoring:
		_play(TEST_SPEAKER, data)
	if not transmitting:
		return
	if session.is_host():
		_relay(session.local_peer_id, data)
	else:
		_voice_up.rpc_id(NetworkSession.HOST_ID, data)


## 눌러서 말하기 키를 누르고 있는지. 글자 입력 칸에 커서가 있으면 말하지 않는다(이름·주소를 치다가 켜지지 않게).
func push_to_talk_held() -> bool:
	var focus: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if focus is LineEdit or focus is TextEdit:
		return false
	match Preferences.voice_key:
		"mouse4": return Input.is_mouse_button_pressed(MOUSE_BUTTON_XBUTTON1)
		"mouse5": return Input.is_mouse_button_pressed(MOUSE_BUTTON_XBUTTON2)
		"caps": return Input.is_physical_key_pressed(KEY_CAPSLOCK)
	return Input.is_physical_key_pressed(KEY_V)


## 방장: 손님이 보낸 목소리. 방 명단·크기·속도를 확인하고 나머지 사람에게 전달한다.
@rpc("any_peer", "call_remote", "unreliable_ordered", 3)
func _voice_up(data: PackedByteArray) -> void:
	if session == null or not session.is_host():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var player: RoomPlayer = session.room.find_player(sender)
	if player == null or player.is_bot or data.is_empty() or data.size() > MAX_PACKET_BYTES or not _within_budget(sender, data.size()):
		return
	_relay(sender, data)


## 방장: 보낸 사람을 뺀 같은 방 사람에게 보낸다. 방장 자신이 선수면 바로 재생한다(전용 서버는 듣지 않는다).
func _relay(sender: int, data: PackedByteArray) -> void:
	var connected: PackedInt32Array = multiplayer.get_peers()
	for player in session.room.players:
		if player.is_bot or player.peer_id == sender:
			continue
		if player.peer_id == session.local_peer_id:
			_play(sender, data)
		elif connected.has(player.peer_id):
			_voice_down.rpc_id(player.peer_id, sender, data)


@rpc("authority", "call_remote", "unreliable_ordered", 3)
func _voice_down(speaker: int, data: PackedByteArray) -> void:
	if data.size() <= MAX_PACKET_BYTES and session != null and session.room.find_player(speaker) != null:
		_play(speaker, data)


## 1초 예산(토큰 통): 정상 속도의 2배까지, 한꺼번에는 0.5초 분량까지 받는다.
func _within_budget(sender: int, size: int) -> bool:
	var now: float = _now()
	var entry: Dictionary = _budgets.get(sender, {"bytes": MAX_BYTES_PER_SECOND * 0.5, "at": now})
	var bytes: float = minf(MAX_BYTES_PER_SECOND * 0.5, float(entry.bytes) + (now - float(entry.at)) * MAX_BYTES_PER_SECOND)
	var allowed: bool = bytes >= size
	_budgets[sender] = {"bytes": bytes - size if allowed else bytes, "at": now}
	return allowed


## 받은 목소리를 그 사람 재생기에 넣는다. 대기열이 비어 있으면 무음을 조금 깔고, 너무 밀렸으면 버린다.
func _play(speaker: int, data: PackedByteArray) -> void:
	if not Preferences.voice_enabled:
		return
	var samples: PackedFloat32Array = decode(data)
	var entry: Dictionary = _speaker(speaker)
	entry.last = _now()
	entry.level = maxf(float(entry.level), meter(rms_db(samples)))
	var playback := entry.playback as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var queued: int = int(entry.capacity) - playback.get_frames_available()
	if queued > MAX_QUEUE * RATE:
		return
	var frames := PackedVector2Array()
	if queued < PACKET_SAMPLES / 2:
		frames.resize(int(JITTER_PREFILL * RATE))
	var start: int = frames.size()
	frames.resize(start + samples.size())
	for index in range(samples.size()):
		frames[start + index] = Vector2(samples[index], samples[index])
	playback.push_buffer(frames)


## 확정된 경기 상태에서만 호출한다. 사람별 재생 피치를 바꿔 다른 음성에는 영향을 주지 않는다.
func set_warped(peer: int, enabled: bool) -> void:
	if _speakers.has(peer):
		(_speakers[peer].player as AudioStreamPlayer).pitch_scale = 0.72 if enabled else 1.0


func _speaker(peer: int) -> Dictionary:
	if _speakers.has(peer):
		return _speakers[peer]
	var stream := AudioStreamGenerator.new()
	stream.mix_rate_mode = AudioStreamGenerator.MIX_RATE_CUSTOM
	stream.mix_rate = RATE
	stream.buffer_length = PLAYBACK_SECONDS
	var player := AudioStreamPlayer.new()
	player.name = "Voice_%d" % peer
	player.stream = stream
	player.bus = BUS_NAME
	add_child(player)
	player.play()
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	var entry: Dictionary = {"player": player, "playback": playback, "capacity": playback.get_frames_available() if playback != null else 0,
		"last": -10.0, "level": 0.0}
	_speakers[peer] = entry
	return entry


## 사람마다 볼륨·음소거(이름으로 저장)를 적용하고, 방을 떠난 사람의 재생기를 치운다.
func _update_speakers() -> void:
	for peer: int in _speakers.keys():
		var entry: Dictionary = _speakers[peer]
		var player := entry.player as AudioStreamPlayer
		var member: RoomPlayer = session.room.find_player(peer) if session != null else null
		if member == null and not (peer == TEST_SPEAKER and monitoring):
			player.queue_free()
			_speakers.erase(peer)
			continue
		entry.level = maxf(0.0, float(entry.level) - get_process_delta_time() * 2.5)
		var volume: float = 1.0 if member == null else Preferences.person_volume(member.display_name)
		player.volume_db = linear_to_db(maxf(volume, 0.0001)) if volume > 0.0 and not (member != null and Preferences.person_muted(member.display_name)) else -80.0


## 지금 말하는 중인지(나는 보내는 중, 다른 사람은 최근에 목소리가 왔는지).
func is_speaking(peer: int) -> bool:
	if session != null and peer == session.local_peer_id:
		return transmitting
	var entry: Dictionary = _speakers.get(peer, {})
	return not entry.is_empty() and _now() - float(entry.last) <= SPEAKING_HOLD


## 말소리 크기(0~1). 말하지 않으면 0. 머리 위 스피커가 이만큼 커진다.
func level(peer: int) -> float:
	if not is_speaking(peer):
		return 0.0
	if session != null and peer == session.local_peer_id:
		return mic_level
	return float((_speakers[peer] as Dictionary).level)


## 지금 감도에서 말하는 것으로 볼 최소 크기(dBFS).
static func vad_threshold_db() -> float:
	return lerpf(VAD_LOUD_DB, VAD_QUIET_DB, Preferences.voice_sensitivity)


static func meter(loudness_db: float) -> float:
	return clampf(inverse_lerp(METER_FLOOR_DB, METER_TOP_DB, loudness_db), 0.0, 1.0)


static func rms_db(samples: PackedFloat32Array) -> float:
	if samples.is_empty():
		return METER_FLOOR_DB
	var total: float = 0.0
	for sample in samples:
		total += sample * sample
	return linear_to_db(maxf(sqrt(total / samples.size()), 0.00001))


## G.711 μ-law: 한 샘플을 8비트로(작은 소리는 촘촘히, 큰 소리는 성기게).
static func encode(samples: PackedFloat32Array) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(samples.size())
	for index in range(samples.size()):
		var value: int = clampi(int(samples[index] * 32767.0), -32767, 32767)
		var sign_bit: int = 0x80 if value < 0 else 0
		value = mini(absi(value), 32635) + 132
		var exponent: int = 7
		var mask: int = 0x4000
		while exponent > 0 and (value & mask) == 0:
			exponent -= 1
			mask >>= 1
		var mantissa: int = (value >> (exponent + 3)) & 0x0F
		data[index] = ~(sign_bit | (exponent << 4) | mantissa) & 0xFF
	return data


static func decode(data: PackedByteArray) -> PackedFloat32Array:
	if _decode_table.is_empty():
		_decode_table.resize(256)
		for byte in range(256):
			var bits: int = ~byte & 0xFF
			var exponent: int = (bits >> 4) & 0x07
			var magnitude: int = ((((bits & 0x0F) << 3) + 132) << exponent) - 132
			_decode_table[byte] = (-magnitude if bits & 0x80 else magnitude) / 32768.0
	var samples := PackedFloat32Array()
	samples.resize(data.size())
	for index in range(data.size()):
		samples[index] = _decode_table[data[index]]
	return samples


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
