class_name PlayerView
extends CharacterBody3D
## 입력 소유권은 Game에 있고 이 노드는 방장 시뮬레이션과 캐릭터 표현을 소유한다.
## 겉모습(디자인 담당): 리깅 캐릭터(art/player_look.gd) + 모션 재생(art/characters/character_motion.gd).
## 충돌 캡슐·눈높이·속도는 예전 그대로다 → 겉모습을 바꿔도 이동·판정은 바뀌지 않는다.

## 자리 색. 디자인 약속표(PlayerLook) 하나만 보도록 그대로 가져온다.
const COLORS: Array[Color] = PlayerLook.COLORS
const SPEED: float = 3.8
const JUMP_SPEED: float = 4.8
const GRAVITY: float = 12.0
const EYE_HEIGHT: float = 1.55
## 앉은 눈높이(m). 스툴 위에 앉은 캐릭터의 눈(character_factory.gd 의 눈 높이 1.34m)과 같게 맞춘다.
## 2026-10-31: 예전 0.95m 는 테이블 윗면(0.85m)보다 10cm 높을 뿐이라 매트 위 카드가 거의 안 보였다(사용자 피드백).
const SEATED_EYE_HEIGHT: float = 1.34
## 엿보기(레인보우 식스 시즈의 Q·E 기울이기처럼, 앉아서 A·D — 2026-10-31 사용자 요청).
## 스툴 위 골반(CharacterRig.HIP_HEIGHT)을 축으로 윗몸을 옆으로 기울이고 엉덩이도 조금 미끄러진다.
## PEEK_ANGLE = 최대 기울기(라디안, 약 24도), PEEK_SLIDE = 엉덩이가 옆으로 가는 거리(m).
## 둘을 합치면 눈이 옆으로 약 0.4m 나가 옆자리 매트의 카드 쪽으로 머리가 들어간다.
const PEEK_ANGLE: float = 0.42
const PEEK_SLIDE: float = 0.1
## 기울이는 빠르기(초당 seat_lean 변화량). 5 = 0.2초 만에 끝까지 기운다.
const PEEK_SPEED: float = 5.0
## 화면이 몸을 따라 기우는 비율(1 = 몸과 같은 각도). 끝까지 같이 기울면 어지러워서 절반 정도만.
const PEEK_ROLL_RATIO: float = 0.55
## 엿볼 때 머리를 몸보다 조금 더 꺾는 각도(라디안). 다른 사람 화면에서 "훔쳐보는" 몸짓이 잘 보이게.
const PEEK_HEAD_TILT: float = 0.2
## 이 정도(0~1) 넘게 기울면 이름표에 "엿보는 중"이 붙는다. game/table/seat_cards.gd 의 PEEK_REVEAL 과 같은 값.
const PEEK_TAG: float = 0.6
## 마시는 중 고개를 젖히는 각도(라디안, 약 17도). 1인칭 카메라(GameView)와 병 위치(LoungeWorld)가 같이 쓴다.
const DRINK_LOOK_UP: float = 0.3
## 머리 위 이름표 높이(m). 캐릭터 키(약 1.6~1.75m) 바로 위. 앉거나 숙이면 LOW_LABEL_RATIO 만큼 내린다.
const LABEL_HEIGHT: float = 2.0
const LOW_LABEL_RATIO: float = 0.72
## 음성 채팅 스피커(말하는 중) 자리: 머리 왼쪽 옆. 감정 말풍선(lounge/emotes.gd, 머리 오른쪽 1.72 m)과 마주 보게 둔다.
## 머리 위에 두면 테이블 건너편 사람 것이 위 가운데 라운드 표시에 가려진다(말풍선과 같은 이유).
const SPEAKER_HEIGHT: float = 1.72
const SPEAKER_SIDE: float = 0.46
## 스피커 그림 크기(m/px)와 목소리가 클 때 커지는 비율.
const SPEAKER_PIXEL: float = 0.0019
const SPEAKER_PULSE: float = 0.35

var identity: MatchPlayer
var seated: bool = false
var crouched: bool = false
var pitch: float = 0.0
var color: Color
## 지금 이 사람이 조준 중인지. GameView 가 매 프레임 넣고, 몸짓이 오른팔을 든다(모든 화면에서 보인다).
var aiming: bool = false
var ready_pose: bool = false
## 봇이 사람을 약 올리는 중(두 팔 번쩍). 싱글 플레이 봇 행동(game/player/bot_social.gd)이 넣는다 — 보이기만.
var taunting: bool = false
## 앉아서 A·D 로 기울인 양(-1 = 왼쪽 끝, +1 = 오른쪽 끝). 방장이 정하고 위치와 함께 모두에게 보낸다.
var seat_lean: float = 0.0
## 화면에 쓰는 기울기. seat_lean 은 초당 20번 오므로 그대로 쓰면 카메라가 계단처럼 튄다 → 매 프레임 부드럽게 따라간다.
var _shown_lean: float = 0.0
## 이름표에 "엿보는 중"을 붙였는지(SeatCards.PEEK_REVEAL 만큼 기울면 켠다).
var _peek_tagged: bool = false
## 마시는 몸짓 진행(0 = 안 마심, 0~1 = 병을 입에 대고 기울이는 중). LoungeWorld 가 매 프레임 넣는다(보이기만).
var drink_pose: float = 0.0
## 맞아서 밀려나는 속도(방장 시뮬레이션에서만 쓰고 위치로 모두에게 반영된다). 매 프레임 줄어든다.
var knockback: Vector3 = Vector3.ZERO
## 가챠 "왕머리" 같은 장난 효과(보이기만). LoungeWorld 가 매 프레임 넣는다.
var head_scale: float = 1.0
var _model: Node3D
var _rig: CharacterMotion
var _label: Label3D
var _collision: CollisionShape3D
var _speaker: Sprite3D


func _ready() -> void:
	collision_layer = 2
	collision_mask = 5
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = LABEL_HEIGHT
	_label.font_size = 32
	_label.pixel_size = 0.003
	_label.outline_size = 8
	_label.outline_modulate = Color("122b27")
	add_child(_label)
	_collision = CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.28
	shape.height = 1.7
	_collision.shape = shape
	_collision.position.y = 0.85
	add_child(_collision)


func configure(player: MatchPlayer, _angle: float = 0.0, _is_local: bool = false) -> void:
	identity = player
	# 자리 뒤에 선 채로 시작한다. 뒷벽에 붙은 자리도 있어 방 안으로 당긴다.
	position = TableView.standing_spot(player.seat)
	color = COLORS[player.seat]
	_dress(player.seat)
	# 캐릭터마다 고유 렌더 레이어. 각 카메라에서 자기 몸만 제외한다(모델의 모든 조각 + 이름표).
	_set_layers(self, 1 << (player.seat + 1))
	if player.is_bot:
		position = TableView.SEATS[player.seat]
		seated = true
		look_at(Vector3(TableView.BOARD_CENTER.x, position.y, TableView.BOARD_CENTER.z))
	show_state(player)


func show_state(player: MatchPlayer) -> void:
	identity = player
	_refresh_label()


## 이름표: 자리 표식(●▲■◆)을 붙이고 자리 색으로 칠한다(색약이어도 모양으로 구분 — 기획 2-4).
## 엿보는 중이면 "엿보는 중"을 붙인다 → 들여다보이는 옆 사람도 눈치채고 견제할 수 있다(모든 화면).
func _refresh_label() -> void:
	var tags: String = (" · 슬로우" if identity.speed_scale < 1.0 else "") + (" · 엿보는 중" if _peek_tagged else "")
	_label.text = "%s · %d%s" % [PlayerLook.tag(identity.seat, identity.display_name), identity.score, tags]
	_label.modulate = COLORS[identity.seat].lightened(0.35)


## 기본 몸짓은 위치·자세·속도로 만들고, 선택 모션은 방장이 승인한 감정표현 이벤트로 시작한다.
func _process(delta: float) -> void:
	if _rig == null:
		return
	var posture := CharacterMotion.Posture.SEAT if seated else (CharacterMotion.Posture.CROUCH if crouched else CharacterMotion.Posture.STAND)
	var ground_speed := Vector2(velocity.x, velocity.z).length() / SPEED
	var airborne := not seated and position.y > 0.05
	_rig.cheering = ready_pose or taunting
	_rig.drinking = drink_pose
	_shown_lean = lerpf(_shown_lean, seat_lean if seated else 0.0, 1.0 - exp(-18.0 * delta))
	# 왕머리·엿보기는 시각 표현만 바꾼다. 충돌 캡슐은 움직이지 않는다.
	_rig.head_scale = head_scale
	# 엿보기: 윗몸·팔·머리가 함께 기운다(eye_position 과 같은 각도).
	var peek: float = peek_amount()
	_rig.lean = peek * PEEK_ANGLE
	_rig.head_tilt = peek * PEEK_HEAD_TILT
	_rig.animate(delta, ground_speed, posture, airborne, pitch, aiming)
	# 옆자리 카드가 뒤집힐 만큼 기울었을 때만 이름표에 표시한다(SeatCards 와 같은 기준).
	var tagged: bool = absf(peek) >= PEEK_TAG
	if tagged != _peek_tagged and identity != null:
		_peek_tagged = tagged
		_refresh_label()


## 음성 채팅으로 말하는 중이면 머리 옆에 스피커를 띄운다(level 0~1 = 목소리 크기, 음수 = 숨김).
## GameView 가 매 프레임 넣는다. 캐릭터와 같은 레이어라 내 스피커는 내 화면에 안 보인다(내 상태는 Tab 목록·HUD).
func set_speaking(level: float) -> void:
	if level < 0.0:
		if _speaker != null: _speaker.visible = false
		return
	if _speaker == null:
		_speaker = Sprite3D.new()
		_speaker.name = "Speaking"
		_speaker.texture = preload("res://ui/ui_icon.gd").speaker_texture()
		_speaker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_speaker.pixel_size = SPEAKER_PIXEL
		_speaker.shaded = false
		_speaker.no_depth_test = true
		_speaker.render_priority = 2
		# offset 은 그림 면 기준 픽셀이라 빌보드면 늘 화면 가로 방향 = 어디서 봐도 머리 왼쪽 옆.
		_speaker.offset.x = -SPEAKER_SIDE / SPEAKER_PIXEL
		_speaker.layers = 1 << (identity.seat + 1) if identity != null else 1
		add_child(_speaker)
	_speaker.visible = true
	_speaker.position.y = SPEAKER_HEIGHT * (LOW_LABEL_RATIO if crouched else 1.0)
	_speaker.scale = Vector3.ONE * (1.0 + clampf(level, 0.0, 1.0) * SPEAKER_PULSE)


## 던지기 몸짓을 한 번 재생한다(GameView._show_throw 가 부른다).
func play_throw() -> void:
	if _rig != null:
		_rig.play_throw()


func can_emote() -> bool:
	return _rig != null and not seated and not crouched and not aiming and drink_pose <= 0.0 \
		and position.y <= 0.05


func play_emote(index: int) -> bool:
	return _rig != null and _rig.play_emote(index)


func emote_clip() -> String:
	return _rig.emote_clip if _rig != null else ""


## 자리 캐릭터를 입힌다. 캐릭터 정면과 이 노드 정면이 둘 다 -Z 라 돌리지 않는다.
func _dress(seat: int) -> void:
	if _model != null:
		remove_child(_model)
		_model.queue_free()
	_model = PlayerLook.character(seat)
	_model.name = "Model"
	add_child(_model)
	# 네 명이 같은 박자로 움직이지 않게 자리마다 시작 시각을 다르게 준다.
	_rig = CharacterMotion.new(_model, seat * 0.9)


func _set_layers(node: Node, layer: int) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = layer
	for child in node.get_children():
		_set_layers(child, layer)


func eye_position() -> Vector3:
	if seated:
		# 골반을 축으로 윗몸이 기운다 → 눈은 원을 그리며 옆으로 나가고 살짝 내려간다(그냥 옆으로 미끄러지지 않는다).
		var peek: float = peek_amount()
		var tilt: float = peek * PEEK_ANGLE
		var torso: float = SEATED_EYE_HEIGHT - CharacterRig.HIP_HEIGHT
		return global_position + Vector3.UP * (CharacterRig.HIP_HEIGHT + cos(tilt) * torso) \
			+ basis.x * (sin(tilt) * torso + peek * PEEK_SLIDE)
	return global_position + Vector3.UP * (0.95 if crouched else EYE_HEIGHT)


## 엿보기 정도(-1~1). 끝에서 천천히 멈추도록 부드럽게 꺾은 값이다(smoothstep).
func peek_amount() -> float:
	return signf(_shown_lean) * smoothstep(0.0, 1.0, absf(_shown_lean))


## 엿볼 때 1인칭 화면이 기우는 각도(카메라 rotation.z). 오른쪽(+)으로 기울면 화면 오른쪽이 내려간다(음수).
func peek_roll() -> float:
	return -peek_amount() * PEEK_ANGLE * PEEK_ROLL_RATIO


## 마시는 중 고개가 뒤로 젖혀진 정도(0~1). 1인칭 카메라(GameView)가 같은 값만큼 위를 본다.
func drink_pose_tilt() -> float:
	return CharacterRig.drink_curve(drink_pose).y


## 조작은 방장만 넣는다. 사람은 자기 입력(GameView._accept_controls), 봇은 GameView._drive_bot 이 만든 값이다.
func simulate(delta: float, controls: Dictionary) -> void:
	rotation.y = float(controls.get("yaw", rotation.y))
	pitch = float(controls.get("pitch", pitch))
	crouched = bool(controls.get("crouch", false)) and not seated
	seat_lean = move_toward(seat_lean, float((controls.get("move", Vector2.ZERO) as Vector2).x) if seated else 0.0, delta * PEEK_SPEED)
	if seated:
		velocity = Vector3.ZERO
		knockback = Vector3.ZERO
		position = TableView.SEATS[identity.seat]
	else:
		var axis: Vector2 = controls.get("move", Vector2.ZERO)
		var direction := Basis(Vector3.UP, rotation.y) * Vector3(axis.x, 0, axis.y)
		# speed_scale: 테이블 집합 지각 페널티(슬로우). 방장 시뮬레이션에만 적용되고 위치로 모든 화면에 반영된다.
		var speed := SPEED * (0.5 if crouched else 1.0) * identity.speed_scale
		velocity.x = direction.x * speed + knockback.x
		velocity.z = direction.z * speed + knockback.z
		knockback = knockback.move_toward(Vector3.ZERO, delta * 9.0)
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		elif bool(controls.get("jump", false)):
			velocity.y = JUMP_SPEED
		else:
			velocity.y = 0
		move_and_slide()
		# 추가 좌표 경계는 네트워크 입력과 접촉 오차에도 경기장을 벗어나지 않게 한다(ㄱ자 방 두 칸).
		position = TableView.clamp_floor(position)
		position.y = maxf(position.y, 0)
	update_posture()


func update_posture() -> void:
	# 충돌 캡슐은 예전처럼 0.58배로 줄인다. 보이는 몸은 _process 의 몸짓이 따로 낮춘다.
	var height_scale: float = 0.58 if crouched or seated else 1.0
	# 앉아도 스툴 위라 머리 높이가 그대로다 → 숙일 때만 이름표를 내린다.
	_label.position.y = LABEL_HEIGHT * (LOW_LABEL_RATIO if crouched else 1.0)
	var shape := _collision.shape as CapsuleShape3D
	shape.height = 1.7 * height_scale
	_collision.position.y = shape.height * 0.5


func to_motion() -> Dictionary:
	return {"id": identity.peer_id, "position": position, "yaw": rotation.y, "pitch": pitch,
		"seat_lean": seat_lean, "seated": seated, "crouched": crouched, "velocity": velocity}


func apply_motion(data: Dictionary) -> void:
	position = data.position
	rotation.y = data.yaw
	pitch = data.pitch
	seated = data.seated
	seat_lean = float(data.get("seat_lean", 0))
	crouched = data.crouched
	velocity = data.velocity
	update_posture()
