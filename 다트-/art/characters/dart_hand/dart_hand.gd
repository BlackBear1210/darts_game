extends Sprite2D
## 로컬 화면 높이를 기준으로 승인된 시안의 크기를 유지한다.
const ThrowPose = preload("res://art/characters/first_person_throw.gd")
const HOLD := preload("res://art/characters/dart_hand/hold.png")
const LARGE := preload("res://art/characters/dart_hand/hold_large.png")
const RELEASE := preload("res://art/characters/dart_hand/release.png")


func set_seat(seat: int) -> void:
	var ink := material as ShaderMaterial
	ink.set_shader_parameter("seat_color", PlayerLook.COLORS[seat])
	ink.set_shader_parameter("replace_flight", seat != 0)


func pose(pull: float, kick: float, released: float, reload: bool, large: bool, motion: float) -> void:
	var u: float = 1.0 - kick
	texture = LARGE if large else HOLD
	var pivot_x: float = 680.0 if large else 930.0
	var art_scale: float = 1.27 if large else 1.0
	if not ThrowPose.dart_in_hand(kick, reload):
		texture = RELEASE
		pivot_x = 590.0
		art_scale = 1.25
	# 원화마다 아래팔이 화면 가장자리를 통과하는 지점을 회전축으로 잡는다.
	offset = Vector2(-pivot_x, -texture.get_height())
	var screen: Vector2 = get_viewport_rect().size
	var unit: float = minf(screen.y / 923.0, screen.x / 1470.0)
	var back: float = pull
	var reach: float = 0.0
	var drop: float = 0.0
	if kick > 0.0:
		var rise: float = smoothstep(ThrowPose.RISE_START, 1.0, u) if reload else 0.0
		back = released * (1.0 - smoothstep(0.0, ThrowPose.UNCOCK_END, u)) + pull * rise
		reach = smoothstep(0.0, ThrowPose.THRUST_END, u) * (1.0 - rise)
		drop = smoothstep(ThrowPose.DROP_START, ThrowPose.DROP_END, u) * (1.0 - rise)
	scale = Vector2.ONE * unit * 0.315 * art_scale
	rotation = deg_to_rad(7.0 * back - 9.0 * reach) * motion
	position = Vector2(screen.x * 0.638 + unit * 293.0, screen.y + unit * 8.0)
	position += Vector2(12.0 * back - 35.0 * reach, 24.0 * back + 365.0 * drop) * unit * motion


func tip_on_screen() -> Vector2:
	var tip := Vector2(2.0, 91.0) if texture == LARGE else Vector2(5.0, 140.0)
	return to_global(offset + tip)
