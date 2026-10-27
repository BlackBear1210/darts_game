class_name EmoteOverlay
extends Control
## 이전 계획의 얼굴 방해(이모트) 연출. 현재 경기 경로에서는 활성화하지 않는다.

var _age: float = 0.0
var _warning: float = 0.3
var _duration: float = 1.0
var _color: Color
var _side: int = 0
var _name: String = ""
var _sound: AudioStreamPlayer


func _ready() -> void:
	visible = false
	set_process(false)
	_sound = AudioStreamPlayer.new()
	_sound.volume_db = -20.0
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 8000
	var samples := PackedByteArray()
	for index in range(1600):
		var seconds := index / 8000.0
		var sample := int(sin(TAU * (430.0 - seconds * 600.0) * seconds) * 18000.0 * (1.0 - index / 1600.0))
		samples.append(sample & 255)
		samples.append((sample >> 8) & 255)
	stream.data = samples
	_sound.stream = stream
	add_child(_sound)


func show_event(player: MatchPlayer, warning: float, duration: float) -> void:
	_color = PlayerView.COLORS[player.seat]
	_side = player.seat % 2
	_name = player.display_name
	_warning = warning
	_duration = duration
	_age = 0.0
	visible = true
	set_process(true)
	queue_redraw()


func clear() -> void:
	visible = false
	set_process(false)
	_sound.stop()


func _process(delta: float) -> void:
	var before := _age
	_age += delta
	if before < _warning and _age >= _warning: _sound.play()
	if _age >= _warning + _duration:
		clear()
	else:
		queue_redraw()


func _draw() -> void:
	if _age < _warning:
		var x := 12.0 if _side == 0 else size.x - 210.0
		draw_string(ThemeDB.fallback_font, Vector2(x, size.y * 0.65), "%s 장난 준비!" % _name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("eed16c"))
		return
	var progress := (_age - _warning) / _duration
	var radius := minf(size.x * 0.042, size.y * 0.10)
	var entrance := minf(progress / 0.15, (1.0 - progress) / 0.15)
	var x := lerpf(-radius, radius * 0.75, clampf(entrance, 0, 1))
	if _side == 1: x = size.x - x
	var center := Vector2(x, size.y * 0.56)
	draw_circle(center, radius, _color)
	for direction in [-1.0, 1.0]:
		var eye := center + Vector2(direction * radius * 0.35, -radius * 0.18)
		draw_circle(eye, radius * 0.24, Color.WHITE)
		draw_circle(eye + Vector2(0, sin(progress * TAU) * radius * 0.1), radius * 0.11, Color("152030"))
	draw_arc(center + Vector2(0, radius * 0.1), radius * 0.40, 0.15, PI - 0.15, 12, Color("152030"), 3.0, true)
