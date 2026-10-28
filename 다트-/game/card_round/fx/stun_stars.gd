extends Node3D
## 만화 스턴: 머리 위에서 별 다섯 개가 빙글빙글 돈다. seconds 가 지나면 스스로 사라진다.
## 캐릭터(PlayerView) 자식으로 붙인다 → 캐릭터가 움직여도 따라다닌다.

const CardFaces = preload("res://game/card_round/cards/card_faces.gd")

const STAR_COUNT: int = 5
const ORBIT_RADIUS: float = 0.3
const SPIN_SPEED: float = 4.5

var seconds: float = 3.0
var _time: float = 0.0
var _stars: Array[Label3D] = []


func _ready() -> void:
	position = Vector3.UP * 1.95
	for i in range(STAR_COUNT):
		var star := Label3D.new()
		star.text = "★"
		star.font = CardFaces.bold_font()
		star.font_size = 110
		star.pixel_size = 0.0016
		star.modulate = Color("ffd84a") if i % 2 == 0 else Color("fff3b0")
		star.outline_size = 16
		star.outline_modulate = Color("5a3a10")
		star.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(star)
		_stars.append(star)


func _process(delta: float) -> void:
	_time += delta
	var fade: float = clampf((seconds - _time) / 0.4, 0.0, 1.0)
	for i in range(_stars.size()):
		var angle: float = _time * SPIN_SPEED + TAU * i / STAR_COUNT
		_stars[i].position = Vector3(cos(angle) * ORBIT_RADIUS, sin(_time * 7.0 + i) * 0.035, sin(angle) * ORBIT_RADIUS * 0.8)
		_stars[i].scale = Vector3.ONE * (0.85 + 0.25 * sin(_time * 9.0 + i * 1.7)) * fade
	if _time >= seconds:
		queue_free()
