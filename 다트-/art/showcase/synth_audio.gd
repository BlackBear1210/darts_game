extends AudioStreamPlayer
## 쇼케이스용 짧은 효과음을 수학식으로 즉석 합성한다(녹음·샘플 파일 없음 → 저작권 걱정 없음).
## cue("throw") 바람 소리 / cue("hit") 꽂히는 소리 / cue("bull") 불 명중 차임.

var muted := false


func cue(kind: String) -> void:
	if muted:
		return
	var sample_rate := 22050
	var seconds := 0.16 if kind == "throw" else 0.23
	var count := int(sample_rate * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	# 시드를 고정해 매번 같은 소리가 나게 한다.
	rng.seed = 419
	for i in range(count):
		var t := float(i) / sample_rate
		# 처음에 크고 빠르게 줄어드는 소리 모양(envelope).
		var envelope := pow(1.0 - float(i) / count, 3)
		var value := 0.0
		if kind == "throw":
			value = rng.randf_range(-1, 1) * envelope * 0.18
		elif kind == "bull":
			value = (sin(TAU * 660 * t) + sin(TAU * 880 * t) * 0.5) * envelope * 0.22
		else:
			value = (sin(TAU * 155 * t) * 0.55 + rng.randf_range(-1, 1) * exp(-t * 60)) * envelope * 0.28
		data.encode_s16(i * 2, int(clampf(value, -1, 1) * 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	stream = wav
	volume_db = -9
	play()
