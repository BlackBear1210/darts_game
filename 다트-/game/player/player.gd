class_name PlayerView
extends CharacterBody3D
## 입력 소유권은 Game에 있고 이 노드는 방장 시뮬레이션과 캐릭터 표현을 소유한다.
## 겉모습(디자인 담당): 리깅 캐릭터(art/player_look.gd) + 모션 재생(art/characters/character_motion.gd).
## 충돌 캡슐·눈높이·속도는 예전 그대로다 → 겉모습을 바꿔도 이동·판정은 바뀌지 않는다.

## 자리 색. 디자인 약속표(PlayerLook) 하나만 보도록 그대로 가져온다.
const COLORS: Array[Color] = PlayerLook.COLORS
const SPEED: float = 3.8
const JUMP_SPEED: float = 4.8
## 올라갈 때 중력. JUMP_SPEED 와 함께 높이 약 1.0m · 오르기 0.40초를 만든다(60Hz 실측).
const GRAVITY: float = 12.0
## 꼭대기를 지나 내려올 때 중력(2026-11-26 사용자 요청 — 둥둥 뜨는 느낌을 뺀다).
## 오르기는 그대로라 머리 위 다트를 막는 꼭대기 구간이 거의 줄지 않고, 내려오기만 0.42 → 0.30초로 빨라진다(공중 0.80 → 0.68초).
const FALL_GRAVITY: float = 26.0
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
## 앉아 있을 때 몸(모델)이 의자 정면에서 돌 수 있는 한계(라디안, 약 55도). 2026-11-08 사용자 지적
## "의자에 등받이가 있는데 왜 등받이를 뚫고 캐릭터들이 뒤를 돌아보는가": 앉은 사람의 몸이 시선(yaw)을 360도 따라 돌았다.
## → 보이는 몸만 이 각도까지 돌고, 1인칭 시선(rotation.y)·엿보기 계산은 그대로다(다른 화면에서만 몸이 덜 돈다).
const SEATED_TURN_LIMIT: float = 0.96
## 마시는 중 고개를 젖히는 각도(라디안, 약 17도). 1인칭 카메라(GameView)와 병 위치(LoungeWorld)가 같이 쓴다.
const DRINK_LOOK_UP: float = 0.3
## 머리 위 이름표 높이(m). 캐릭터 키(약 1.6~1.75m) 바로 위. 앉거나 숙이면 LOW_LABEL_RATIO 만큼 내린다.
const LABEL_HEIGHT: float = 2.0
const LOW_LABEL_RATIO: float = 0.72
## 머리 위 이름표 글자 크기(2026-11-15 "머리 위에 작게 닉네임과 마이크 표시"): 예전 32 → 작게. 점수는 왼쪽 위 점수판에 있어 뺐다.
const LABEL_FONT: int = 22
const LABEL_PIXEL: float = 0.0026
## 마이크 그림: 이름표 바로 왼쪽(같은 높이). 크기(m/px) · 이름표와의 틈(m) · 말할 때 커지는 비율.
const SPEAKER_HEIGHT: float = LABEL_HEIGHT
const MIC_PIXEL: float = 0.00075
const MIC_GAP: float = 0.06
const SPEAKER_PULSE: float = 0.3
## 이름표 글자 폭의 절반(m). 글자가 바뀔 때 다시 재서 마이크를 그 왼쪽에 붙인다.
var _label_half: float = 0.2

var identity: MatchPlayer
var seated: bool = false
var crouched: bool = false
var pitch: float = 0.0
var color: Color
## 지금 이 사람이 조준 중인지. GameView 가 매 프레임 넣고, 몸짓이 오른팔을 든다(모든 화면에서 보인다).
var aiming: bool = false
var ready_pose: bool = false
var waiting_at_attention := false
## 봇이 사람을 약 올리는 중(두 팔 번쩍). 싱글 플레이 봇 행동(game/player/bot_social.gd)이 넣는다 — 보이기만.
var taunting: bool = false
## 앉아서 A·D 로 기울인 양(-1 = 왼쪽 끝, +1 = 오른쪽 끝). 방장이 정하고 위치와 함께 모두에게 보낸다.
var seat_lean: float = 0.0
## 화면에 쓰는 기울기. seat_lean 은 초당 20번 오므로 그대로 쓰면 카메라가 계단처럼 튄다 → 매 프레임 부드럽게 따라간다.
var _shown_lean: float = 0.0
## [손님 화면 보간 — 2026-11-26 사용자 "사람들이 막 덜덜덜 떨려"] 자리·각도도 seat_lean 과 같은 문제가 있었다.
## 방장만 simulate 를 돌리고 손님 화면은 스냅샷(GameView.MOTION_INTERVAL = 초당 20번)으로만 사람을 옮긴다 →
## 그대로 꽂으면 144Hz 화면에서 일곱 프레임 멈췄다 한 번 순간이동하기를 되풀이해 모두가 덜덜 떨렸다.
## 받은 자리를 목표로 두고 매 프레임 그쪽으로 좁혀 간다. 방장 화면은 이 경로를 타지 않아(call_remote) 그대로다.
const MOTION_FOLLOW: float = 18.0
## 이보다 멀리 떨어진 스냅샷은 보간하지 않고 바로 붙인다(자리 앉기·쓰러진 뒤 복귀 같은 순간이동).
const MOTION_SNAP: float = 1.5
## 방장이 보내온 자리·좌우 각도. INF = 아직 스냅샷을 받은 적 없음(방장 화면).
var _motion_to: Vector3 = Vector3.INF
var _motion_yaw: float = 0.0
## 이름표에 "엿보는 중"을 붙였는지(SeatCards.PEEK_REVEAL 만큼 기울면 켠다).
var _peek_tagged: bool = false
## 마시는 몸짓 진행(0 = 안 마심, 0~1 = 병을 입에 대고 기울이는 중). LoungeWorld 가 매 프레임 넣는다(보이기만).
var drink_pose: float = 0.0
## 맞아서 밀려나는 속도(방장 시뮬레이션에서만 쓰고 위치로 모두에게 반영된다). 매 프레임 줄어든다.
var knockback: Vector3 = Vector3.ZERO
## 가챠 "왕머리" 같은 장난 효과(보이기만). LoungeWorld 가 매 프레임 넣는다.
var head_scale: float = 1.0
## 카드 키 변화(2026-11-21): 지금 보이는 몸 배율(경기 상태 card_effects.body_scale 로 부드럽게 따라간다).
## 겉모습·눈높이·이름표만 바뀐다. 충돌 캡슐·몸으로 막기 판정은 그대로(작아져도 막는 판정이 쉬워지지 않게).
var body_scale: float = 1.0
## [쓰러지기 — 2026-11-15] 다트 두 번 · NPC 반격 · 싸대기에 맞으면 애니메이터를 끄고 래그돌(줄 끊긴 인형)을 켠다.
## 모든 화면이 GameView 의 "player_fall" 이벤트를 받고 각자 물리로 쓰러뜨린다(보이기만 — 위치는 방장 몸이 정한다).
const Ragdoll = preload("res://art/characters/ragdoll.gd")
## 쓰러져 있는 시간(초). 이 시간이 지나면 일어난다(애니메이션으로 섞여 돌아온다). 방장은 그동안 조작을 막는다.
const FALL_SECONDS: float = 3.2
var fallen: bool = false
var _fall_left: float = 0.0
var _ragdoll: Node
## [꾸미기 — 2026-11-15] 모자·안경·콧수염·시가·시계·옷 색(art/characters/player_outfit.gd). 보이기만 한다.
## 값은 방장이 모두에게 보낸다(GameView "looks" 이벤트). dressing = 꾸미기 방에 들어가 있는 중(이름표에 표시).
const PlayerOutfit = preload("res://art/characters/player_outfit.gd")
var look: Dictionary = {}
var dressing: bool = false
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
	_label.font_size = LABEL_FONT
	_label.pixel_size = LABEL_PIXEL
	_label.outline_size = 6
	_label.outline_modulate = Color("122b27")
	add_child(_label)
	_collision = CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.28
	shape.height = 1.7
	_collision.shape = shape
	_collision.position.y = 0.85
	add_child(_collision)


func configure(player: MatchPlayer, _angle: float = 0.0, _is_local: bool = false, lobby_wait: bool = false) -> void:
	identity = player
	# 자리 뒤에 선 채로 시작한다. 뒷벽에 붙은 자리도 있어 방 안으로 당긴다.
	position = TableView.standing_spot(player.seat)
	color = COLORS[player.seat]
	_dress(player.seat)
	# 캐릭터마다 고유 렌더 레이어. 각 카메라에서 자기 몸만 제외한다(모델의 모든 조각 + 이름표).
	_set_layers(self, 1 << (player.seat + 1))
	if player.is_bot:
		waiting_at_attention = lobby_wait
		seated = not lobby_wait
		if seated:
			position = TableView.seat_spot(player.seat)
		var target := TableView.TABLE_CENTER if lobby_wait else TableView.BOARD_CENTER
		look_at(Vector3(target.x, position.y, target.z))
	show_state(player)


func show_state(player: MatchPlayer) -> void:
	identity = player
	_refresh_label()


## 이름표: 자리 표식(●▲■◆)을 붙이고 자리 색으로 칠한다(색약이어도 모양으로 구분 — 기획 2-4).
## 엿보는 중이면 "엿보는 중"을 붙인다 → 들여다보이는 옆 사람도 눈치채고 견제할 수 있다(모든 화면).
func _refresh_label() -> void:
	var tags: String = (" · 슬로우" if identity.speed_scale < 1.0 else "") + (" · 엿보는 중" if _peek_tagged else "") + (" · 꾸미는 중" if dressing else "")
	_label.text = "%s%s" % [PlayerLook.tag(identity.seat, identity.display_name), tags]
	_label.modulate = COLORS[identity.seat].lightened(0.35)
	var font: Font = _label.font if _label.font != null else ThemeDB.fallback_font
	_label_half = font.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT).x * LABEL_PIXEL * 0.5


## 기본 몸짓은 위치·자세·속도로 만들고, 선택 모션은 방장이 승인한 감정표현 이벤트로 시작한다.
func _process(delta: float) -> void:
	_follow_motion(delta)
	if _rig == null:
		return
	if fallen:
		_process_fallen(delta)
		return
	var posture := CharacterMotion.Posture.SEAT if seated else (CharacterMotion.Posture.CROUCH if crouched else CharacterMotion.Posture.STAND)
	var ground_speed := Vector2(velocity.x, velocity.z).length() / SPEED
	var airborne := not seated and position.y > 0.05
	_rig.standing_at_attention = waiting_at_attention
	_rig.cheering = (ready_pose or taunting) and not waiting_at_attention
	_rig.drinking = drink_pose
	if _rig._layer.prop_grip != null and identity != null:
		_rig._layer.prop_grip.large = bool(identity.card_effects.get("large",false))
	_shown_lean = lerpf(_shown_lean, seat_lean if seated else 0.0, 1.0 - exp(-18.0 * delta))
	# 왕머리·엿보기는 시각 표현만 바꾼다. 충돌 캡슐은 움직이지 않는다.
	# 오락실 캡슐 왕머리(head_scale)와 왕머리 카드(card_effects.head_scale) 중 큰 쪽.
	_rig.head_scale = maxf(head_scale, _card_value("head_scale"))
	var want_body: float = _card_value("body_scale")
	if not is_equal_approx(body_scale, want_body):
		body_scale = move_toward(body_scale, want_body, delta * 1.6)
		_model.scale = Vector3.ONE * body_scale
		_label.position.y = LABEL_HEIGHT * (LOW_LABEL_RATIO if crouched else 1.0) * body_scale
	# 엿보기: 윗몸·팔·머리가 함께 기운다(eye_position 과 같은 각도).
	var peek: float = peek_amount()
	_rig.lean = peek * PEEK_ANGLE
	_rig.head_tilt = peek * PEEK_HEAD_TILT
	_turn_body_in_chair(delta)
	_rig.animate(delta, ground_speed, posture, airborne, pitch, aiming)
	# 옆자리 카드가 뒤집힐 만큼 기울었을 때만 이름표에 표시한다(SeatCards 와 같은 기준).
	var tagged: bool = absf(peek) >= PEEK_TAG
	if tagged != _peek_tagged and identity != null:
		_peek_tagged = tagged
		_refresh_label()


## 쓰러져 있는 동안: 애니메이터는 꺼져 있고 래그돌 물리가 뼈를 움직인다. 이름표·스피커는 쓰러진 몸을 따라간다.
func _process_fallen(delta: float) -> void:
	_fall_left -= delta
	var center: Vector3 = fallen_center()
	_label.global_position = center + Vector3.UP * 0.75
	if _speaker != null: _speaker.global_position = center + Vector3.UP * 0.75
	if _fall_left <= 0.0:
		get_up()


## 쓰러진다. push = 날아가는 방향과 세기(m/s). 이미 쓰러져 있으면 무시한다(겹쳐 맞아도 한 번만).
func fall(push: Vector3) -> void:
	if fallen or _model == null:
		return
	if _ragdoll == null or not is_instance_valid(_ragdoll):
		_ragdoll = Ragdoll.attach(_model)
	if _ragdoll == null:
		return
	fallen = true
	_fall_left = FALL_SECONDS
	knockback = Vector3.ZERO
	velocity = Vector3.ZERO
	aiming = false
	# 쓰러진 동안 충돌 캡슐을 끈다: 바닥에 누운 몸 대신 빈 자리에 서 있는 캡슐에 사람·소품이 걸리지 않게.
	_collision.set_deferred("disabled", true)
	# 1) 애니메이터 끄기 → 2) 래그돌 켜기(순서가 반대면 첫 프레임에 애니메이션이 물리 자세를 덮는다).
	_rig.set_animator_enabled(false)
	if _rig._layer.prop_grip != null: _rig._layer.prop_grip.projectile.hide()
	_ragdoll.start(push, global_position + Vector3.UP * 1.1)


## 일어난다. 방장은 몸(캡슐)을 쓰러진 자리(골반)로 옮긴다 → 다른 화면은 위치 동기화로 따라온다.
func get_up() -> void:
	if not fallen:
		return
	fallen = false
	var center: Vector3 = fallen_center()
	if multiplayer.is_server() and not seated:
		position = TableView.clamp_floor(Vector3(center.x, position.y, center.z))
	if _ragdoll != null and is_instance_valid(_ragdoll):
		_ragdoll.stop()
	_rig.set_animator_enabled(true)
	_collision.set_deferred("disabled", false)
	_label.position = Vector3(0, LABEL_HEIGHT * (LOW_LABEL_RATIO if crouched else 1.0), 0)
	if _speaker != null: _speaker.position = Vector3(0, SPEAKER_HEIGHT, 0)


## 쓰러진 몸 가운데(골반). 안 쓰러졌으면 허리 높이. 1인칭 카메라가 쓰러진 동안 이곳을 내려다본다.
func fallen_center() -> Vector3:
	if fallen and _ragdoll != null and is_instance_valid(_ragdoll):
		return _ragdoll.center()
	return global_position + Vector3.UP * 0.9


## 앉아 있으면 보이는 몸(Model)을 의자 정면(테이블 쪽) ± SEATED_TURN_LIMIT 안으로 되돌린다. 서 있으면 0(시선 그대로).
func _turn_body_in_chair(delta: float) -> void:
	if _model == null:
		return
	var turn: float = 0.0
	var chair_yaw: float = 0.0
	var in_chair: bool = seated and identity != null
	if in_chair:
		var to_table: Vector3 = TableView.TABLE_CENTER - TableView.seat_spot(identity.seat)
		# 모델 정면 = -Z. -Z 가 테이블을 보는 yaw.
		chair_yaw = atan2(-to_table.x, -to_table.z)
		var offset: float = wrapf(rotation.y - chair_yaw, -PI, PI)
		turn = clampf(offset, -SEATED_TURN_LIMIT, SEATED_TURN_LIMIT) - offset
	var model_turn: float = lerp_angle(_model.rotation.y, turn, 1.0 - exp(-12.0 * delta))
	# 시선이 한 번에 크게 돌면(마우스를 휙) 부드럽게 따라가는 사이에 몸이 잠깐 등받이 쪽으로 넘어간다
	# (실측 최대 68도). → 따라가는 중에도 몸 방향은 매 프레임 한계 안으로 자른다.
	if in_chair:
		var body_offset: float = wrapf(rotation.y + model_turn - chair_yaw, -PI, PI)
		model_turn += clampf(body_offset, -SEATED_TURN_LIMIT, SEATED_TURN_LIMIT) - body_offset
	_model.rotation.y = model_turn


## 이름표 왼쪽 마이크 표시(2026-11-15). GameView 가 매 프레임 넣는다.
## state: -1 숨김(봇 — 목소리가 없다) · 0 조용 · 1 말하는 중(level 0~1 = 목소리 크기만큼 커진다) · 2 내가 음소거한 사람.
## 캐릭터와 같은 레이어라 내 마이크는 내 화면에 안 보인다(내 상태는 Tab 목록·HUD).
func set_mic(state: int, level: float = 0.0) -> void:
	if state < 0:
		if _speaker != null: _speaker.visible = false
		return
	if _speaker == null:
		_speaker = Sprite3D.new()
		_speaker.name = "Mic"
		_speaker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_speaker.pixel_size = MIC_PIXEL
		_speaker.shaded = false
		_speaker.render_priority = 2
		_speaker.layers = 1 << (identity.seat + 1) if identity != null else 1
		add_child(_speaker)
	_speaker.texture = preload("res://ui/ui_icon.gd").mic_texture(state)
	_speaker.visible = true
	# offset 은 그림 면 기준 픽셀이라 빌보드면 늘 화면 가로 방향 = 어디서 봐도 이름표 바로 왼쪽.
	_speaker.offset.x = -(_label_half + MIC_GAP) / MIC_PIXEL
	if not fallen:
		_speaker.position.y = _label.position.y
	_speaker.scale = Vector3.ONE * (1.0 + (clampf(level, 0.0, 1.0) * SPEAKER_PULSE if state == 1 else 0.0))


## 던지기 몸짓을 한 번 재생한다(GameView._show_throw 가 부른다).
func play_throw() -> void:
	if _rig != null:
		_rig.play_throw()


## 모션(춤)을 틀 수 있는가. 앉아 있어도 된다(2026-11-08 — 엉덩이·다리는 의자에 두고 윗몸만 춘다, CharacterMotion).
func can_emote() -> bool:
	return _rig != null and not fallen and not crouched and not aiming and drink_pose <= 0.0 \
		and (seated or position.y <= 0.05)


func play_emote(index: int) -> bool:
	return _rig != null and _rig.play_emote(index)


func emote_clip() -> String:
	return _rig.emote_clip if _rig != null else ""


## 자리 캐릭터를 입힌다. 캐릭터 정면과 이 노드 정면이 둘 다 -Z 라 돌리지 않는다.
func _dress(seat: int) -> void:
	if _model != null:
		remove_child(_model)
		_model.queue_free()
	# 래그돌은 모델의 뼈대 아래에 붙어 있어 모델과 함께 사라진다 → 다음에 쓰러질 때 새 모델에 다시 붙인다.
	_ragdoll = null
	fallen = false
	_model = PlayerLook.character(seat)
	_model.name = "Model"
	add_child(_model)
	_model.scale = Vector3.ONE * body_scale
	# 네 명이 같은 박자로 움직이지 않게 자리마다 시작 시각을 다르게 준다.
	_rig = CharacterMotion.new(_model, seat * 0.9)
	if _rig._layer.prop_grip != null:
		_rig._layer.prop_grip.enable_dart(_model,color)
	PlayerOutfit.dress(_model, look)


## 차림을 바꾼다(꾸미기 방에서 나올 때 · 방장 "looks" 이벤트). 캐릭터는 그대로 두고 옷 부품만 갈아 끼운다
## → 쓰러져 있어도·카드를 들고 있어도 바로 바뀐다. 같은 차림이면 아무것도 하지 않는다.
func wear(new_look: Dictionary) -> void:
	var clean: Dictionary = PlayerOutfit.sanitize(new_look)
	if clean == look:
		return
	look = clean
	if _model == null:
		return
	PlayerOutfit.undress(_model)
	PlayerOutfit.dress(_model, look)
	if identity != null:
		_set_layers(_model, 1 << (identity.seat + 1))


## 꾸미기 방에 들어갔는지(이름표에 "꾸미는 중"). 모든 화면이 방장 이벤트로 같이 바꾼다.
func set_dressing(on: bool) -> void:
	if dressing == on:
		return
	dressing = on
	if identity != null:
		_refresh_label()


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
		return global_position + Vector3.UP * (CharacterRig.HIP_HEIGHT + cos(tilt) * torso) * body_scale 			+ basis.x * (sin(tilt) * torso + peek * PEEK_SLIDE) * body_scale
	return global_position + Vector3.UP * (0.95 if crouched else EYE_HEIGHT) * body_scale


## 경기 카드가 건 배율(이동·몸·머리). 경기 밖이거나 카드가 없으면 1.
func _card_value(key: String) -> float:
	if identity == null:
		return 1.0
	return float(identity.card_effects.get(key, 1.0))


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
	if fallen:
		# 쓰러진 동안은 몸(캡슐)이 움직이지 않는다. 일어날 때 get_up 이 쓰러진 자리로 옮긴다.
		velocity = Vector3.ZERO
		knockback = Vector3.ZERO
		seat_lean = 0.0
	elif seated:
		velocity = Vector3.ZERO
		knockback = Vector3.ZERO
		position = TableView.seat_spot(identity.seat)
	else:
		var axis: Vector2 = controls.get("move", Vector2.ZERO)
		var direction := Basis(Vector3.UP, rotation.y) * Vector3(axis.x, 0, axis.y)
		# speed_scale: 테이블 집합 지각 페널티(슬로우). 방장 시뮬레이션에만 적용되고 위치로 모든 화면에 반영된다.
		# move_scale: 이속 증가·감소 카드(2026-11-21). 방장만 돌리는 계산이라 위치로 모든 화면에 반영된다.
		var speed := SPEED * (0.5 if crouched else 1.0) * identity.speed_scale * _card_value("move_scale")
		velocity.x = direction.x * speed + knockback.x
		velocity.z = direction.z * speed + knockback.z
		knockback = knockback.move_toward(Vector3.ZERO, delta * 9.0)
		if not is_on_floor():
			velocity.y -= (GRAVITY if velocity.y > 0.0 else FALL_GRAVITY) * delta
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
	_label.position.y = LABEL_HEIGHT * (LOW_LABEL_RATIO if crouched else 1.0) * body_scale
	var shape := _collision.shape as CapsuleShape3D
	shape.height = 1.7 * height_scale
	_collision.position.y = shape.height * 0.5


func to_motion() -> Dictionary:
	return {"id": identity.peer_id, "position": position, "yaw": rotation.y, "pitch": pitch,
		"seat_lean": seat_lean, "seated": seated, "crouched": crouched, "velocity": velocity}


func apply_motion(data: Dictionary) -> void:
	var to: Vector3 = data.position
	# 처음 받은 스냅샷 · 멀리 건너뛴 자리 · 앉고 서기는 보간하지 않고 바로 옮긴다.
	var jump: bool = not _motion_to.is_finite() or position.distance_to(to) > MOTION_SNAP or bool(data.seated) != seated
	_motion_to = to
	_motion_yaw = float(data.yaw)
	if jump:
		position = to
		rotation.y = _motion_yaw
	pitch = data.pitch
	seated = data.seated
	seat_lean = float(data.get("seat_lean", 0))
	crouched = data.crouched
	velocity = data.velocity
	update_posture()


## 스냅샷으로 받은 자리·좌우 각도로 매 프레임 조금씩 다가간다. 방장 화면에서는 _motion_to 가 비어 있어 아무 일도 없다.
## 보이기만 하는 보정이다 — 점수·몸 맞기 판정은 방장이 자기 시뮬레이션으로 하므로 영향받지 않는다.
func _follow_motion(delta: float) -> void:
	if fallen or not _motion_to.is_finite():
		return
	var weight: float = 1.0 - exp(-MOTION_FOLLOW * delta)
	position = position.lerp(_motion_to, weight)
	rotation.y = lerp_angle(rotation.y, _motion_yaw, weight)
