extends Node3D
## 머리 위 감정표현 말풍선: 톡 튀어나와(커졌다 작아짐) 위아래로 살짝 흔들리다가 사라진다. 효과음은 그 사람 위치에서 난다.
## 그림은 fx/emote_art.gd 를 작은 화면(SubViewport)에 그려 빌보드(Sprite3D)로 붙인다.
## 캐릭터 자식으로 붙이고, 그 캐릭터와 같은 레이어로 그린다 → 내 말풍선은 내 화면에서 안 보인다(내 것은 피자판 쪽 2D 로 보여 준다).

const EmoteArt = preload("res://game/card_round/fx/emote_art.gd")

## 말풍선 높이(m, 머리 위 상태 글자보다 위), 떠 있는 시간(초), 그림 해상도(px).
const HEIGHT: float = 2.78
const SECONDS: float = 2.4
const PIXELS: int = 256

## 어떤 감정인지(emote_art.gd 순서). 트리에 넣기 전에 정한다.
var index: int = 0
## 그릴 레이어(캐릭터와 같게).
var layer_mask: int = 1

var _sprite: Sprite3D
var _age: float = 0.0


func _ready() -> void:
	position = Vector3.UP * HEIGHT
	var viewport := SubViewport.new()
	viewport.size = Vector2i(PIXELS, PIXELS)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	var canvas := Control.new()
	canvas.size = Vector2(PIXELS, PIXELS)
	canvas.draw.connect(func() -> void:
		var center := Vector2(PIXELS, PIXELS) * 0.5
		# 흰 말풍선(동그라미 + 아래 꼬리) 위에 감정 그림.
		canvas.draw_circle(center, PIXELS * 0.43, Color("fff8ea"))
		canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-22, PIXELS * 0.38), center + Vector2(22, PIXELS * 0.38), center + Vector2(0, PIXELS * 0.5)]), Color("fff8ea"))
		EmoteArt.draw(canvas, index, center + Vector2(0, -4), PIXELS * 0.27))
	viewport.add_child(canvas)
	_sprite = Sprite3D.new()
	_sprite.texture = viewport.get_texture()
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.pixel_size = 0.0021
	_sprite.shaded = false
	_sprite.no_depth_test = true
	_sprite.render_priority = 2
	_sprite.layers = layer_mask
	_sprite.scale = Vector3.ONE * 0.01
	add_child(_sprite)
	var sound := AudioStreamPlayer3D.new()
	sound.stream = EmoteArt.sound(index)
	sound.unit_size = 6.0
	add_child(sound)
	sound.play()


func _process(delta: float) -> void:
	_age += delta
	# 0~0.22초: 0 → 1.15 → 1 로 톡 튀어나온다. 그 뒤 살짝 위아래로 흔들리고, 마지막 0.4초에 사라진다.
	var pop: float = _age / 0.22
	var size: float = lerpf(0.01, 1.15, pop) if pop < 1.0 else lerpf(1.15, 1.0, clampf((_age - 0.22) / 0.12, 0.0, 1.0))
	_sprite.scale = Vector3.ONE * size
	_sprite.position.y = sin(_age * 5.0) * 0.03
	_sprite.modulate.a = clampf((SECONDS - _age) / 0.4, 0.0, 1.0)
	if _age >= SECONDS:
		queue_free()
