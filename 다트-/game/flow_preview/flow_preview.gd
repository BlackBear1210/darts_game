extends Control
## F6으로 실행하는 팀 검토용 청사진. 한 화면에서 모든 참가자의 행동을 대신한다.
## 진행 규칙은 game_flow.gd(모델)에 있고, 이 파일은 설정 입력·버튼·현황 표시만 맡는다.

const Flow = preload("res://game/flow_preview/game_flow.gd")

var flow := Flow.new()
var _stage: Label
var _description: Label
var _roster: Label
var _history: Label
var _actions: HFlowContainer
var _players: SpinBox
var _rounds: SpinBox
var _target: SpinBox
var _joint: SpinBox
var _hit: SpinBox


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var background := ColorRect.new()
	background.color = Color("101a2b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.name = "Content"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	add_child(margin)
	var scroll := ScrollContainer.new()
	margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 14)
	scroll.add_child(column)
	_label(column, "다트 파티 / 게임 진행 청사진", 36)
	_label(column, "로컬 버튼 시연 · 가상 참가자 · 미정 규칙은 임시 처리", 22)
	var settings := HBoxContainer.new()
	settings.add_theme_constant_override("separation", 16)
	column.add_child(settings)
	_players = _number(settings, "인원", 2, 4, 2)
	_rounds = _number(settings, "라운드 (임시 종료 조건)", 1, 10, 2)
	_target = _number(settings, "목표 점수", 0, 9999, 100)
	_joint = _number(settings, "합동 라운드 (0=없음)", 0, 10, 2)
	_stage = _label(column, "", 32)
	_stage.add_theme_color_override("font_color", Color("79cfff"))
	_description = _label(column, "", 24)
	_roster = _label(column, "", 24)
	var hit_row := HBoxContainer.new()
	column.add_child(hit_row)
	_hit = _number(hit_row, "시연용 이번 발 점수 (물리 판정 대체)", 0, 60, 20)
	# 방해 버튼까지 최대 5개가 한 줄에 안 들어가는 작은 창에서는 다음 줄로 넘긴다.
	_actions = HFlowContainer.new()
	_actions.add_theme_constant_override("h_separation", 16)
	_actions.add_theme_constant_override("v_separation", 12)
	column.add_child(_actions)
	_history = _label(column, "", 20)
	_history.add_theme_color_override("font_color", Color("a3b5cc"))
	var reset_button := Button.new()
	reset_button.text = "처음부터 다시 보기"
	reset_button.custom_minimum_size.y = 48
	reset_button.pressed.connect(_reset)
	column.add_child(reset_button)
	_refresh()


func _label(parent: Node, value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _number(parent: Node, title: String, minimum: int, maximum: int, initial: int) -> SpinBox:
	var box := VBoxContainer.new()
	parent.add_child(box)
	var caption := _label(box, title, 20)
	caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	var input := SpinBox.new()
	input.min_value = minimum
	input.max_value = maximum
	input.value = initial
	input.custom_minimum_size = Vector2(170, 44)
	box.add_child(input)
	return input


func _reset() -> void:
	flow.reset()
	_refresh()


func _act(action: String) -> void:
	if flow.step == Flow.Step.SETTINGS:
		flow.player_count = int(_players.value)
		flow.round_limit = int(_rounds.value)
		flow.target_score = int(_target.value)
		flow.joint_round = int(_joint.value)
	flow.act(action, int(_hit.value))
	_refresh()


func _refresh() -> void:
	_stage.text = "%02d / %s" % [flow.step + 1, Flow.TITLES[flow.step]]
	_description.text = _step_description()
	var lines: PackedStringArray = []
	if not flow.scores.is_empty():
		lines.append("라운드 %d / %d    |    P%d 차례    |    이번 차례 %d / 3발" % [flow.round_number, flow.round_limit, flow.turn_index + 1, flow.throws_done])
		for index in range(flow.player_count):
			var hand: Array[int] = flow.hands[index]
			lines.append("P%d    %d점    |    손패 %d/%d  (%s)    |    취기 %d" % [index + 1, flow.scores[index],
				hand.size(), CardHandRules.HAND_LIMIT, CardHandRules.summary(hand), flow.drunk[index]])
	if flow.step == Flow.Step.FINISHED:
		lines.clear()
		for row: Dictionary in flow.standings():
			lines.append("%d위  P%d    %d점    |    목표와 차이 %d" % [row.rank, row.player, row.score, row.gap])
	_roster.text = "\n".join(lines)
	for child in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()
	var available: Dictionary = flow.actions()
	for action: String in available:
		var button := Button.new()
		button.text = available[action]
		button.custom_minimum_size = Vector2(240, 56)
		button.add_theme_font_size_override("font_size", 22)
		button.pressed.connect(_act.bind(action))
		_actions.add_child(button)
	var recent: PackedStringArray = []
	for index in range(maxi(0, flow.history.size() - 6), flow.history.size()):
		recent.append("· " + flow.history[index])
	_history.text = "최근 진행\n" + "\n".join(recent)
	var editable: bool = flow.step <= Flow.Step.SETTINGS
	for input: SpinBox in [_players, _rounds, _target, _joint]:
		input.editable = editable
	_hit.editable = flow.step == Flow.Step.AIM


func _step_description() -> String:
	match flow.step:
		Flow.Step.START, Flow.Step.ROOM:
			return "버튼으로 방 생성과 가상 플레이어 입장을 확인합니다. 인원은 2~4명입니다."
		Flow.Step.SETTINGS:
			return "모드는 목표 점수 근접 비교 1종입니다. 라운드 수·목표 점수·합동 라운드 번호는 시연용으로 설정합니다."
		Flow.Step.TABLE:
			return "모두 원형 테이블에 모이는 단계입니다. 3D 이동은 F5 실제 경기에서 확인합니다."
		Flow.Step.RETURN_TABLE:
			return "라운드가 끝나면 제한시간(기본 10초) 안에 자기 자리에 앉아야 합니다. 늦은 사람은 자동 착석되고 다음 라운드 동안 이동 속도 50% 슬로우가 걸립니다(F5 실제 경기에 구현)."
		Flow.Step.INITIAL_CARDS, Flow.Step.ROUND_CARDS:
			return "확정 규칙: 손패는 7장까지 무작위로 채웁니다. 안 쓴 카드는 남으므로, 한 장도 안 쓴 사람은 한 장도 받지 못합니다. 새로고침·임의 버리기는 없습니다. 종류: 연산 · 다트 · 과녁 · 물리 (지급 확률은 미정, 시연은 균등)."
		Flow.Step.JOINT_ROUND:
			return "특수 합동 라운드: 바텐더와 다 같이 한잔합니다. 시연에서는 전원 취기 +1만 기록합니다. 열리는 주기·바텐더 동선·취기 화면 효과는 미정입니다."
		Flow.Step.ORDER:
			return "결정 방식 미정: 시연에서는 P1 → P2 → P3 → P4 순서로 진행합니다."
		Flow.Step.MOVE:
			return "매 투척 전 이동·위치 선택 단계입니다. 현재 씬에서는 완료 버튼으로 대신합니다."
		Flow.Step.CARD_CHOICE, Flow.Step.CARD_APPLY:
			return "투척자가 이번 발에 자기 카드 1장을 쓸 수 있습니다(종류별 버튼). 카드를 쓰면 손패에 빈자리가 생겨 다음 라운드에 그만큼 받습니다. 세부 카드와 수치 효과는 미정입니다."
		Flow.Step.AIM:
			return "발사하면 입력한 점수를 반영합니다. 페이크·취소는 조준에 머물며 발수를 소비하지 않습니다. 다른 참가자는 방해 카드를 1장씩 쓸 수 있습니다(시연: 손패 맨 앞 카드, 한 발에 한 사람당 1장, 효과 수치 미적용)."
		Flow.Step.END_CHECK:
			return "종료 조건 미정: 설정한 라운드를 마치면 종료합니다. 아니라면 전원 손패를 7장까지 보충한 뒤 다음 라운드입니다."
		Flow.Step.FINISHED:
			return "목표 점수와의 절댓값 차이가 작을수록 높은 순위입니다. 동점 처리 미정: 시연은 공동 순위입니다."
		_:
			return "다음 단계 버튼으로 차례·라운드의 반복과 분기를 확인합니다."
