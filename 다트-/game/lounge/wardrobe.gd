extends CanvasLayer
## 꾸미기 방(2026-11-15 사용자 요청 "당구대 근처 문을 열고 들어가면 커스터마이징 방 — 배그·덕 어몽어스처럼
## 선글라스·콧수염·시가·옷 색·시계·모자들. 대신 게임에는 지장이 생기면 안 돼"). 디자인 담당 소유.
## class_name 을 만들지 않고 preload 로 부른다(열린 편집기가 새 class_name 을 못 읽어 파스 오류가 나는 함정).
##
## [게임에 지장이 없게 만든 방법]
##   - 방은 펍 안에 짓지 않는다. 화면 전체를 덮는 SubViewport 의 **따로 떨어진 3D 세계**(own_world_3d)에 탈의실을 짓는다.
##     → 펍 벽·바닥·조명·충돌·다트 판정과 섞일 일이 없고(빛 새기·z-파이팅 없음), 방 밖 사람들의 화면도 그대로다.
##   - 들어가 있는 동안 몸은 문 앞에 서 있다(마우스가 풀려 있어 이동 입력이 0). 이름표에 "꾸미는 중"이 붙는다.
##   - 내 차례가 오거나·자리에 앉게 되거나·쓰러지면 GameView 가 이 방을 바로 닫는다(고른 것은 저장).
##   - 고른 값은 보이기만 하는 차림(art/characters/player_outfit.gd)이고, 방장이 검사해서 모두에게 보낸다.
##
## [조작] 오른쪽 패널의 그림 카드를 눌러 칸마다 고르기 · 캐릭터를 끌어서 돌려 보기 · "입고 나가기"/Esc = 저장하고 나가기
##   · "되돌리기" = 들어올 때 차림. 다 끝나면 closed(look) 신호를 한 번 보내고 스스로 사라진다.
##
## [2026-11-16 사용자 요청 "캐릭터가 빙빙 돌지 않게 · 아이템이 어떤 건지 이름만이 아니라 이미지로도 보여 줘"]
##   - 가만히 두면 저절로 돌던 것을 없앴다. 끌 때만 돌고, 손을 떼면 그 자리에 선다. 두 번 누르면 앞모습으로 돌아온다.
##   - 칸마다 ◀ 이름 ▶ 대신 **그림 카드**(그림 + 이름)를 늘어놓는다. 그림은 미리 그려 둔 파일이 아니라
##     방이 열릴 때 작은 촬영 화면(아이콘 스튜디오)에서 **실제 캐릭터에 그 물건을 입혀 찍는다**
##     → 새 물건을 SLOTS 에 더하면 그림도 저절로 생긴다. 한 번 찍은 그림은 게임이 꺼질 때까지 다시 쓴다(_icon_cache).

signal closed(look: Dictionary)

const Style = preload("res://ui/lounge_style.gd")
const PlayerOutfit = preload("res://art/characters/player_outfit.gd")
const NpcOutfit = preload("res://art/pub/npc_outfit.gd")
const MeshKit = preload("res://art/mesh_kit.gd")
const RoundKit = preload("res://art/pub/round_kit.gd")
const PubParts = preload("res://art/pub/pub_parts.gd")

## 들어갈 때·나올 때 검은 화면으로 바뀌는 시간(초) — "문을 열고 들어가는" 느낌.
const FADE_SECONDS: float = 0.35
## 캐릭터를 끌어 돌리는 빠르기(라디안/픽셀). 가만히 두면 돌지 않는다(2026-11-16 "빙빙 돌지 않게").
const DRAG_TURN: float = 0.012
## 처음·두 번 눌렀을 때 캐릭터가 보는 쪽(살짝 비스듬한 앞모습).
const FRONT_TURN: float = PI - 0.35
## 카메라: 캐릭터(원점)를 화면 왼쪽 가운데쯤 두려고 오른쪽으로 비켜 선다(오른쪽엔 패널이 있다).
const CAMERA_AT := Vector3(0.62, 1.22, 3.3)
const CAMERA_LOOK := Vector3(0.62, 0.98, 0.0)
## 오른쪽 패널 너비(px) · 그림 카드 크기 · 카드 사이 틈. 한 줄에 카드 5장이 들어가는 너비.
const PANEL_WIDTH: float = 470.0
const CARD_SIZE := Vector2(76, 94)
const CARD_GAP: int = 6
## 아이콘 스튜디오(그림 카드 사진 찍는 작은 화면) 한 변 픽셀 · 처음 몸짓이 자리 잡을 때까지 기다리는 화면 수.
const ICON_PIXELS: int = 176
const ICON_WARMUP_FRAMES: int = 8
## 칸마다 사진 구도: [뼈 이름, 겨눌 점(뼈대 공간, 앞 = −Z), 카메라가 있는 쪽, 거리(m)].
## 겨눌 점·쪽은 뼈를 따라 움직인다(숨 쉬는 몸짓이 있어도 얼굴·손목이 화면 가운데).
const ICON_SHOTS: Dictionary = {
	"hat": ["head", Vector3(-0.025, 1.76, -0.02), Vector3(0.35, 0.45, -1.0), 1.4],
	"eyes": ["head", Vector3(0.0, 1.59, -0.23), Vector3(0.25, 0.12, -1.0), 0.88],
	"mustache": ["head", Vector3(-0.012, 1.4, -0.2), Vector3(0.35, 0.05, -1.0), 0.72],
	"cigar": ["head", Vector3(0.06, 1.425, -0.25), Vector3(0.6, 0.15, -1.0), 0.55],
	"watch": ["forearm.L", Vector3.ZERO, Vector3(-1.0, 0.2, -0.45), 0.42],
	"shirt": ["", Vector3(-0.02, 1.0, 0.0), Vector3(0.3, 0.1, -1.0), 1.6],
	"pants": ["", Vector3(0.0, 0.45, 0.0), Vector3(0.15, 0.07, -1.0), 1.56],
}

## 찍은 카드 그림(칸:번호 → 그림). 게임이 꺼질 때까지 남아 다음에 방을 열면 바로 보인다.
static var _icon_cache: Dictionary = {}

var seat: int = 0
## 지금 고른 차림(칸 번호). 열기 전에 넣어 둔다.
var look: Dictionary = {}
var _entered_look: Dictionary = {}
var _viewport: SubViewport
var _world: Node3D
var _model: Node3D
var _rig: CharacterMotion
var _turn: float = 0.0
var _dragging: bool = false
## 칸마다 지금 고른 이름 글자(칸 제목 옆) · 카드 버튼들(칸 → [카드...], 번호 순서).
var _values: Dictionary = {}
var _cards: Dictionary = {}
var _fade: ColorRect
var _fade_to: float = 0.0
var _closing: bool = false
## 아이콘 스튜디오 상태: 찍을 차례 [[칸, 번호], ...] · 한 장을 세 화면에 걸쳐 찍는 단계(입히기 → 겨누고 찍기 → 받아 오기).
var _studio: SubViewport
var _studio_model: Node3D
var _studio_rig: CharacterMotion
var _studio_camera: Camera3D
var _shoot_queue: Array = []
var _shoot_step: int = 0
var _shoot_wait: int = 0


func _ready() -> void:
	layer = 30
	look = PlayerOutfit.sanitize(look)
	_entered_look = look.duplicate()
	_build_view()
	_build_room()
	_build_panel()
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	_dress_model()
	_start_icons()


## 3D 탈의실을 그리는 화면(창 크기에 맞춰 늘어난다).
func _build_view() -> void:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(_viewport)
	_world = Node3D.new()
	_world.name = "DressingRoom"
	_viewport.add_child(_world)
	# 캐릭터 끌어 돌리기는 패널 뒤 빈 곳이 받는다(SubViewport 로 입력을 넘기지 않는다).
	var drag := Control.new()
	drag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	drag.mouse_filter = Control.MOUSE_FILTER_STOP
	drag.gui_input.connect(_on_drag)
	add_child(drag)


## 탈의실: 따뜻한 조명 · 나무 바닥 · 자주 벽지 · 전신 거울 · 옷걸이(옷 색 견본) · 모자 선반 · 화분. 모두 보이기만 한다.
func _build_room() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("140d12")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("f2d2b0")
	environment.ambient_light_energy = 0.32
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.4
	var holder := WorldEnvironment.new()
	holder.environment = environment
	_world.add_child(holder)
	var camera := Camera3D.new()
	camera.fov = 42.0
	camera.position = CAMERA_AT
	_world.add_child(camera)
	camera.look_at(CAMERA_LOOK)
	camera.current = true
	# 조명: 앞 위 따뜻한 스포트(주인공) · 왼쪽 옅은 채움 · 뒤 차가운 테두리 빛.
	var key := SpotLight3D.new()
	key.light_color = Color("ffd9a8")
	key.light_energy = 3.2
	key.spot_range = 9.0
	key.spot_angle = 32.0
	key.shadow_enabled = true
	key.position = Vector3(0.8, 3.4, 2.6)
	_world.add_child(key)
	key.look_at(Vector3(0, 0.9, 0))
	var fill := OmniLight3D.new()
	fill.light_color = Color("ffc78a")
	fill.light_energy = 0.7
	fill.omni_range = 6.0
	fill.position = Vector3(-2.2, 1.6, 1.6)
	_world.add_child(fill)
	var rim := OmniLight3D.new()
	rim.light_color = Color("8fb4ff")
	rim.light_energy = 1.1
	rim.omni_range = 3.5
	rim.position = Vector3(0.4, 2.0, -1.0)
	_world.add_child(rim)
	# 바닥·벽.
	var floor_mat := RoundKit.clay("wardrobe_floor", "5a3826", 0.75)
	MeshKit.rounded_box(_world, "Floor", Vector3(9.0, 0.1, 6.0), Vector3(0, -0.05, 0.4), floor_mat, 0.02)
	var rug := RoundKit.lathe_mesh(PackedVector2Array([Vector2(0, 0), Vector2(0.95, 0), Vector2(1.0, 0.012), Vector2(0, 0.014)]), 40)
	MeshKit.mesh_node(_world, "Rug", rug, Vector3(0, 0.001, 0), RoundKit.clay("wardrobe_rug", "8c2f3c", 0.95))
	MeshKit.mesh_node(_world, "RugRing", RoundKit.ring_mesh("wardrobe_rug_ring", 0.8, RoundKit.rounded_rect_profile(Vector2(0.06, 0.004), 0.002, 2), 40),
		Vector3(0, 0.014, 0), RoundKit.clay("wardrobe_rug_ring", "e2b65a", 0.8))
	MeshKit.rounded_box(_world, "BackWall", Vector3(9.0, 4.0, 0.2), Vector3(0, 2.0, -1.7), RoundKit.clay("wardrobe_wallpaper", "4a2a44", 0.9), 0.02)
	MeshKit.rounded_box(_world, "Wainscot", Vector3(9.0, 1.0, 0.08), Vector3(0, 0.5, -1.58), RoundKit.clay("wardrobe_wainscot", "3a2219", 0.7), 0.02)
	MeshKit.rounded_box(_world, "WainscotRail", Vector3(9.0, 0.06, 0.12), Vector3(0, 1.02, -1.55), RoundKit.clay("wardrobe_rail", "c9a24f", 0.35, 0.8), 0.02)
	MeshKit.rounded_box(_world, "SideWall", Vector3(0.2, 4.0, 6.0), Vector3(-3.0, 2.0, 0.4), RoundKit.clay("wardrobe_wallpaper", "4a2a44", 0.9), 0.02)
	_mirror(Vector3(-1.75, 0, -1.48))
	_rack(Vector3(2.15, 0, -0.85))
	_hat_shelf(Vector3(0.7, 1.95, -1.5))
	PubParts.plant(_world, Vector3(-2.55, 0, -1.1))
	# 문(들어온 곳 — 왼쪽 벽, 살짝 열린 채): 나무 문짝 + 놋쇠 손잡이.
	var door := Node3D.new()
	door.name = "Door"
	door.position = Vector3(-2.88, 0, 1.2)
	door.rotation.y = 0.45
	_world.add_child(door)
	MeshKit.rounded_box(door, "DoorLeaf", Vector3(0.06, 2.1, 0.95), Vector3(0, 1.05, 0.475), RoundKit.clay("wardrobe_door", "6b4128", 0.7), 0.02)
	MeshKit.mesh_node(door, "DoorKnob", RoundKit.sphere_mesh(0.035, 12), Vector3(0.06, 1.0, 0.82), RoundKit.clay("wardrobe_brass", "c9a24f", 0.3, 0.85))


## 전신 거울: 금테 + 반짝이는 판(진짜 비추지는 않는다 — 화면이 하나 더 필요해서 비싸다).
func _mirror(at: Vector3) -> void:
	var gold := RoundKit.clay("wardrobe_brass", "c9a24f", 0.3, 0.85)
	MeshKit.rounded_box(_world, "MirrorFrame", Vector3(1.0, 2.05, 0.08), at + Vector3(0, 1.1, 0), gold, 0.04)
	var glass := StandardMaterial3D.new()
	glass.resource_name = "WardrobeMirror"
	glass.albedo_color = Color("9fb3c4")
	glass.metallic = 0.9
	glass.roughness = 0.08
	MeshKit.rounded_box(_world, "MirrorGlass", Vector3(0.86, 1.9, 0.02), at + Vector3(0, 1.1, 0.045), glass, 0.01)
	MeshKit.rounded_box(_world, "MirrorFoot", Vector3(0.7, 0.06, 0.4), at + Vector3(0, 0.03, 0.15), gold, 0.02)


## 옷걸이: 기둥 둘 + 봉 + 옷 색 견본 셔츠(옷 색 목록 그대로).
func _rack(at: Vector3) -> void:
	var metal := RoundKit.clay("wardrobe_rack", "2a2428", 0.4, 0.7)
	for side: float in [-1.0, 1.0]:
		RoundKit.rod(_world, "RackPost", at + Vector3(side * 0.75, 0, 0), at + Vector3(side * 0.75, 1.7, 0), 0.02, metal, -1.0, 10)
		MeshKit.rounded_box(_world, "RackFoot", Vector3(0.08, 0.04, 0.5), at + Vector3(side * 0.75, 0.02, 0), metal, 0.015)
	RoundKit.rod(_world, "RackBar", at + Vector3(-0.78, 1.66, 0), at + Vector3(0.78, 1.66, 0), 0.018, metal, -1.0, 10)
	var colors: Array[Color] = PlayerOutfit.SHIRT_COLORS
	for i in range(1, colors.size()):
		var x: float = lerpf(-0.62, 0.62, float(i - 1) / float(colors.size() - 2))
		var shirt := MeshKit.rounded_box(_world, "RackShirt", Vector3(0.05, 0.62, 0.42), at + Vector3(x, 1.28, 0),
			RoundKit.clay("wardrobe_shirt_%d" % i, colors[i].to_html(false), 0.9), 0.02)
		shirt.rotation.y = 0.12 * sin(i * 1.7)
		RoundKit.rod(_world, "RackHanger", at + Vector3(x, 1.6, 0), at + Vector3(x, 1.66, 0), 0.006, metal, -1.0, 6)


## 모자 선반: 벽 선반 위에 꾸미기 모자 셋(실크햇·중절모·밀짚모자) — 실제로 씌우는 모자와 같은 부품.
func _hat_shelf(at: Vector3) -> void:
	MeshKit.rounded_box(_world, "HatShelf", Vector3(1.9, 0.05, 0.36), at, RoundKit.clay("wardrobe_shelf", "6b4128", 0.7), 0.015)
	var gold := RoundKit.clay("wardrobe_brass", "c9a24f", 0.3, 0.85)
	for side: float in [-1.0, 1.0]:
		MeshKit.rounded_box(_world, "HatShelfBracket", Vector3(0.04, 0.2, 0.3), at + Vector3(side * 0.8, -0.12, 0), gold, 0.01)
	var hats: Array[int] = [4, 1, 5]
	var shrink: float = 0.85
	for i in range(hats.size()):
		# 모자 부품은 "머리 받침" 좌표(모자 밑면 = 머리 가운데 + HAT_BASE_Y)로 만들어진다
		# → 받침을 그만큼(줄인 크기로) 내려 모자 밑면이 선반 윗면에 닿게 한다.
		var stand := Node3D.new()
		stand.name = "ShelfHat"
		stand.scale = Vector3.ONE * shrink
		stand.position = at + Vector3(-0.62 + i * 0.62, 0.025 + 0.012 * shrink, 0) - (NpcOutfit.HEAD_AXIS + Vector3(0, NpcOutfit.HAT_BASE_Y, 0)) * shrink
		_world.add_child(stand)
		PlayerOutfit.hat(stand, hats[i])


## 오른쪽 패널: 제목 · (스크롤) 칸마다 [칸 이름 · 고른 것] + 그림 카드 줄 · 아래 버튼 둘.
func _build_panel() -> void:
	var panel := PanelContainer.new()
	panel.theme = Style.theme()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -PANEL_WIDTH - 28
	panel.offset_right = -28
	panel.offset_top = 24
	panel.offset_bottom = -24
	panel.add_theme_stylebox_override("panel", Style.card(Color(Style.PANEL, 0.95), Style.INK, Style.SHADOW, 3, 18, 18))
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	Style.heading(column, "꾸미기 방", 34)
	Style.label(column, "고른 차림은 모두에게 보여요 · 점수·판정은 그대로", 15, Style.MUTED)
	# 칸이 많아 창이 낮으면 넘친다 → 카드 목록만 위아래로 굴린다(제목·버튼은 늘 보인다).
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	for slot: Array in PlayerOutfit.SLOTS:
		var key: String = slot[0]
		var header := HBoxContainer.new()
		list.add_child(header)
		var caption := Style.label(header, str(slot[1]), 19)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value := Style.label(header, "", 17, Style.GOLD)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_values[key] = value
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", CARD_GAP)
		flow.add_theme_constant_override("v_separation", CARD_GAP)
		list.add_child(flow)
		var cards: Array = []
		var names: Array = slot[2]
		for index in range(names.size()):
			cards.append(_card(flow, key, index, str(names[index])))
		_cards[key] = cards
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	var wear := Style.button(buttons, "입고 나가기", close.bind(true))
	wear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var reset := Style.secondary(buttons, "되돌리기", _reset)
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Style.label(column, "캐릭터를 끌어서 돌려 보기 · 두 번 누르면 앞모습 · Esc = 입고 나가기", 14, Style.MUTED)
	_refresh_values()


## 그림 카드 하나: 위 = 물건 그림(찍기 전에는 옷 색·빈 칸), 아래 = 이름. 누르면 그 칸을 이것으로 고른다.
func _card(parent: Control, key: String, index: int, title: String) -> Button:
	var card := Button.new()
	card.name = "Card_%s_%d" % [key, index]
	card.custom_minimum_size = Vector2(CARD_SIZE.x, CARD_SIZE.y)
	card.focus_mode = Control.FOCUS_NONE
	card.tooltip_text = title
	card.pressed.connect(_pick.bind(key, index))
	parent.add_child(card)
	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.offset_left = 4
	stack.offset_right = -4
	stack.offset_top = 4
	stack.offset_bottom = -3
	stack.add_theme_constant_override("separation", 1)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(stack)
	# 그림 받침: 옷 색 칸은 찍기 전에도 그 색이 보이게 받침을 그 색으로 칠해 둔다.
	var frame := PanelContainer.new()
	frame.name = "IconFrame"
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := Color("1b141e")
	if key == "shirt":
		back = PlayerOutfit.SHIRT_COLORS[index].lerp(back, 0.35)
	elif key == "pants":
		back = PlayerOutfit.PANTS_COLORS[index].lerp(back, 0.35)
	frame.add_theme_stylebox_override("panel", Style.flat(back, Color(Style.INK, 0.0), 0, 8, 0))
	stack.add_child(frame)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = _icon_cache.get(_icon_key(key, index)) as Texture2D
	frame.add_child(icon)
	var label := Style.label(stack, title, 12)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.clip_text = true
	return card


func _pick(key: String, index: int) -> void:
	if _closing:
		return
	look[key] = index
	look = PlayerOutfit.sanitize(look)
	_refresh_values()
	_dress_model()


## 칸을 한 칸 앞뒤로 넘긴다(예전 ◀ ▶ 와 같은 동작 — 시험·키보드용으로 남겨 둔다).
func _step(key: String, direction: int) -> void:
	for slot: Array in PlayerOutfit.SLOTS:
		if slot[0] == key:
			_pick(key, posmod(int(look.get(key, 0)) + direction, (slot[2] as Array).size()))


func _reset() -> void:
	look = _entered_look.duplicate()
	_refresh_values()
	_dress_model()


## 칸 제목 옆 이름 + 고른 카드만 금테로.
func _refresh_values() -> void:
	for key: String in _values:
		var chosen: int = int(look.get(key, 0))
		(_values[key] as Label).text = PlayerOutfit.choice_name(key, chosen)
		var cards: Array = _cards.get(key, [])
		for index in range(cards.size()):
			_style_card(cards[index] as Button, index == chosen)


func _style_card(card: Button, chosen: bool) -> void:
	var edge: Color = Style.GOLD if chosen else Color(Style.MUTED, 0.35)
	var fill: Color = Color(Style.GOLD, 0.16) if chosen else Color(Style.PANEL_HI, 0.9)
	var normal := Style.flat(fill, edge, 3 if chosen else 2, 10, 0)
	var hover := Style.flat(fill.lightened(0.08), Style.CREAM if not chosen else Style.GOLD, 3, 10, 0)
	for state: String in ["normal", "pressed", "focus", "disabled"]:
		card.add_theme_stylebox_override(state, normal)
	card.add_theme_stylebox_override("hover", hover)
	card.add_theme_stylebox_override("hover_pressed", hover)


## 미리보기 캐릭터: 처음 한 번 만들고, 고를 때마다 옷 부품만 갈아 끼운다.
func _dress_model() -> void:
	if _model == null:
		_model = PlayerLook.character(seat)
		_model.name = "Preview"
		_world.add_child(_model)
		_rig = CharacterMotion.new(_model, 0.0)
		_model.rotation.y = FRONT_TURN
		_turn = _model.rotation.y
	PlayerOutfit.undress(_model)
	PlayerOutfit.dress(_model, look)


func _on_drag(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed and event.double_click and _model != null:
			# 두 번 누르면 앞모습으로(가장 가까운 쪽으로 돌아온다).
			_turn = _model.rotation.y + wrapf(FRONT_TURN - _model.rotation.y, -PI, PI)
	elif event is InputEventMouseMotion and _dragging:
		_turn += event.relative.x * DRAG_TURN


func _input(event: InputEvent) -> void:
	# 방이 열려 있는 동안 Esc 는 이 방 것(펍 화면의 마우스 잡기·설정으로 넘기지 않는다).
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close(true)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_fade.color.a = move_toward(_fade.color.a, _fade_to, delta / FADE_SECONDS)
	_fade.visible = _fade.color.a > 0.001
	if _closing and _fade.color.a >= 1.0:
		set_process(false)
		closed.emit(look.duplicate())
		queue_free()
		return
	if _model != null:
		# 저절로 돌지 않는다: 끌어서 정한 각도(_turn)로만 부드럽게 따라간다.
		_model.rotation.y = lerp_angle(_model.rotation.y, _turn, 1.0 - exp(-10.0 * delta))
		_rig.animate(delta, 0.0, CharacterMotion.Posture.STAND, false, 0.0, false)
	if _studio != null:
		_shoot_icons(delta)


# ─────────────────────────────── 아이콘 스튜디오(그림 카드 사진) ───────────────────────────────

static func _icon_key(key: String, index: int) -> String:
	return "%s:%d" % [key, index]


## 아직 안 찍은 카드가 있으면 작은 촬영 화면을 만든다. 화면이 없는 실행(헤드리스 시험)은 찍지 않는다(카드는 이름·옷 색만).
func _start_icons() -> void:
	if DisplayServer.get_name() == "headless":
		return
	for slot: Array in PlayerOutfit.SLOTS:
		for index in range((slot[2] as Array).size()):
			if not _icon_cache.has(_icon_key(slot[0], index)):
				_shoot_queue.append([slot[0], index])
	if _shoot_queue.is_empty():
		return
	_studio = SubViewport.new()
	_studio.name = "IconStudio"
	_studio.size = Vector2i(ICON_PIXELS, ICON_PIXELS)
	_studio.own_world_3d = true
	_studio.transparent_bg = true
	_studio.msaa_3d = Viewport.MSAA_4X
	_studio.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_studio)
	var stage := Node3D.new()
	stage.name = "IconSet"
	_studio.add_child(stage)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("f2d2b0")
	environment.ambient_light_energy = 0.45
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var holder := WorldEnvironment.new()
	holder.environment = environment
	stage.add_child(holder)
	# 조명: 앞 오른쪽 위 따뜻한 빛 · 앞 왼쪽 채움 · 뒤 차가운 테두리(탈의실과 같은 느낌).
	for light: Array in [[Vector3(1.0, 1.6, 2.0), Color("ffd9a8"), 1.5], [Vector3(-1.6, 0.6, 1.4), Color("ffc78a"), 0.5],
			[Vector3(0.3, 0.8, -2.0), Color("8fb4ff"), 0.9]]:
		var sun := DirectionalLight3D.new()
		sun.light_color = light[1]
		sun.light_energy = light[2]
		stage.add_child(sun)
		sun.look_at_from_position(light[0], Vector3.ZERO)
	_studio_camera = Camera3D.new()
	_studio_camera.fov = 30.0
	_studio_camera.current = true
	stage.add_child(_studio_camera)
	_studio_model = PlayerLook.character(seat)
	_studio_model.name = "IconModel"
	_studio_model.rotation.y = PI
	stage.add_child(_studio_model)
	_studio_rig = CharacterMotion.new(_studio_model, 0.0)
	_shoot_wait = ICON_WARMUP_FRAMES
	_shoot_step = 0


## 한 화면에 한 단계씩: 0 = 그 물건만 입히기 → 1 = 카메라 겨누고 한 번 찍기 → 2 = 찍힌 그림 받아 카드에 넣기.
## (입힌 부품이 뼈를 따라 자리 잡는 데 한 화면, 찍는 데 한 화면이 걸린다.)
func _shoot_icons(delta: float) -> void:
	_studio_rig.animate(delta, 0.0, CharacterMotion.Posture.STAND, false, 0.0, false)
	if _shoot_wait > 0:
		_shoot_wait -= 1
		return
	var item: Array = _shoot_queue[0]
	var key: String = item[0]
	var index: int = item[1]
	match _shoot_step:
		0:
			var only: Dictionary = PlayerOutfit.sanitize({})
			only[key] = index
			PlayerOutfit.undress(_studio_model)
			PlayerOutfit.dress(_studio_model, only)
			_shoot_step = 1
		1:
			_aim_icon(key)
			_studio.render_target_update_mode = SubViewport.UPDATE_ONCE
			_shoot_step = 2
		2:
			var image := _studio.get_texture().get_image()
			var texture := ImageTexture.create_from_image(image)
			_icon_cache[_icon_key(key, index)] = texture
			var cards: Array = _cards.get(key, [])
			if index < cards.size():
				((cards[index] as Node).find_child("Icon", true, false) as TextureRect).texture = texture
			_shoot_queue.pop_front()
			_shoot_step = 0
			if _shoot_queue.is_empty():
				_studio.queue_free()
				_studio = null


## 칸 구도(ICON_SHOTS)대로 카메라를 둔다. 겨눌 점과 카메라 쪽은 지금 몸짓의 뼈 자리로 옮겨 계산한다.
func _aim_icon(key: String) -> void:
	var shot: Array = ICON_SHOTS[key]
	var skeleton := _studio_model.find_child("Skeleton3D", true, false) as Skeleton3D
	var pose: Transform3D = skeleton.global_transform
	var target: Vector3 = shot[1]
	var bone: int = skeleton.find_bone(str(shot[0])) if str(shot[0]) != "" else -1
	if bone >= 0:
		pose = pose * skeleton.get_bone_global_pose(bone) * skeleton.get_bone_global_rest(bone).affine_inverse()
	if key == "watch":
		# 시계 자리 = 아래팔 → 손목 사이(PlayerOutfit.WATCH_ALONG). 쉬는 자세 좌표에서 구한다.
		var hand: int = skeleton.find_bone("hand.L")
		if bone >= 0 and hand >= 0:
			target = skeleton.get_bone_global_rest(bone).origin.lerp(skeleton.get_bone_global_rest(hand).origin, PlayerOutfit.WATCH_ALONG)
	var side: Vector3 = (shot[2] as Vector3).normalized()
	var aim: Vector3 = pose * target
	_studio_camera.global_position = pose * (target + side * float(shot[3]))
	_studio_camera.look_at(aim, Vector3.UP)


## 방을 닫는다(save = 고른 것을 그대로 입고 나간다. 지금은 늘 저장 — 되돌리려면 "되돌리기" 뒤 나간다).
## GameView 가 차례·착석·쓰러짐 때 바로 부르기도 한다. 화면이 검게 바뀐 뒤 closed 를 보낸다.
func close(_save: bool = true) -> void:
	if _closing:
		return
	_closing = true
	_fade_to = 1.0


## 화면 없이 바로 닫는다(경기 화면이 사라질 때·시험). closed 를 곧바로 보낸다.
func close_now() -> void:
	if not is_inside_tree():
		return
	_closing = true
	set_process(false)
	closed.emit(look.duplicate())
	queue_free()
