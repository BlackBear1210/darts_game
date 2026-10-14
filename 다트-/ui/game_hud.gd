class_name GameHUD
extends CanvasLayer

signal leave_requested
signal lobby_requested
signal card_chosen(index: int)
signal card_planned(uid: int, target: int)
signal emote_requested

@onready var _status: Label = %Status
@onready var _roster: Label = %Roster
@onready var _lobby_button: Button = %LobbyButton
@onready var _leave_button: Button = %LeaveButton
@onready var _clock: Label = %Clock
@onready var _preview: BoardPreview = %BoardPreview
@onready var _preview_title: Label = %PreviewTitle
@onready var _hint: Label = %Hint
@onready var _timing: ProgressBar = %Timing
@onready var _cards_panel: PanelContainer = %CardsPanel
@onready var _candidates: HBoxContainer = %Candidates
@onready var _hand: HBoxContainer = %Hand
@onready var _target: OptionButton = %Target
@onready var _confirm: Button = %Confirm
@onready var _skip: Button = %Skip
@onready var _card_info: Label = %CardInfo
@onready var _emote: Button = %EmoteButton
@onready var _overlay: EmoteOverlay = %EmoteOverlay
@onready var _results: PanelContainer = %Results
@onready var _ranking: Label = %Ranking
@onready var _reticle: Control = %Reticle
@onready var _preview_player: OptionButton = %PreviewPlayer
@onready var _preview_background: ColorRect = %PreviewBackground
@onready var _roster_background: ColorRect = %RosterBackground

var _controller: MatchController
var _input: ThrowController
var _selected_uid: int = 0
var _selected_target: int = 0
var _previous_phase: MatchState.Phase = MatchState.Phase.WAITING
var _preview_peer_id: int = 0


func _ready() -> void:
	_lobby_button.pressed.connect(lobby_requested.emit)
	_leave_button.pressed.connect(leave_requested.emit)
	_confirm.pressed.connect(func() -> void: card_planned.emit(_selected_uid, _selected_target))
	_skip.pressed.connect(func() -> void: card_planned.emit(0, 0))
	_target.item_selected.connect(func(index: int) -> void:
		_selected_target = _target.get_item_id(index)
		_show_card_info())
	_emote.pressed.connect(emote_requested.emit)
	_preview_player.item_selected.connect(func(index: int) -> void:
		_preview_peer_id = _preview_player.get_item_id(index)
		_refresh())


func configure(controller: MatchController, input: ThrowController) -> void:
	_controller = controller
	_input = input
	card_chosen.connect(controller.choose_card)
	card_planned.connect(controller.plan_card)
	emote_requested.connect(controller.request_emote)
	controller.changed.connect(_refresh)
	controller.private_changed.connect(_refresh)
	controller.emote_received.connect(_show_emote)
	_refresh()


func render(room: RoomState, local_peer_id: int, message: String) -> void:
	_status.text = message
	_lobby_button.visible = local_peer_id == NetworkSession.HOST_ID
	var lines := PackedStringArray()
	for player in room.players:
		var suffix := " (나)" if player.peer_id == local_peer_id else ""
		var loaded := "입장 완료" if player.is_loaded else "입장 중"
		lines.append("%s%s · %s" % [player.display_name, suffix, loaded])
	_roster.text = "\n".join(lines)
	if _controller != null and _controller.state.phase != MatchState.Phase.WAITING: _refresh()


func _process(_delta: float) -> void:
	if _controller == null: return
	_clock.text = "남은 시간 %.1f초" % _controller.remaining_seconds()
	_roster_background.size.y = _roster.get_minimum_size().y + 12.0
	_timing.value = _input.timing * 100.0
	_timing.visible = _input.enabled
	_reticle.visible = _input.enabled
	_reticle.position = get_viewport().get_mouse_position() - Vector2(12, 12)
	if _input.enabled:
		_hint.text = "마우스로 조준 · 버튼을 눌렀다 게이지 중앙에서 놓기"
		_timing.tooltip_text = "50에서 놓으면 정확하게 던집니다."


func _refresh() -> void:
	var state := _controller.state
	if state.phase == MatchState.Phase.WAITING: return
	var active := state.active_player()
	var phase_names := ["입장 중", "과녁 준비", "조준", "다트 비행", "점수 정산", "카드 선택", "경기 종료"]
	_status.text = "%d/%d 라운드 · %s 차례 · %s · 남은 다트 %d발" % [
		state.round_number, _controller.config.rounds, active.display_name, phase_names[state.phase], state.darts_left]
	if state.phase == MatchState.Phase.CARDS:
		_status.text = "%d/%d 라운드 준비 · 전원 카드 선택 · 마감 시 적용" % [state.round_number, _controller.config.rounds]
	elif state.phase == MatchState.Phase.FINISHED:
		_status.text = "%d라운드 완료 · 최종 순위 · 동점은 공동 순위" % _controller.config.rounds
	var lines := PackedStringArray()
	for player in state.players:
		var cards := PackedStringArray()
		for card in player.hand: cards.append(card.title())
		var name := player.display_name + (" (나)" if player.peer_id == _controller.local_peer_id else "")
		lines.append("%s  %d점\n%s | %s" % [name, player.score, player.effects_text(), " · ".join(cards) if not cards.is_empty() else "카드 없음"])
	_roster.text = "\n".join(lines)
	var cards_open := state.phase == MatchState.Phase.CARDS
	if cards_open and _previous_phase != state.phase:
		_preview_peer_id = _controller.local_peer_id
		_preview_player.clear()
		for player in state.players: _preview_player.add_item(player.display_name, player.peer_id)
		_preview_player.select(_preview_player.get_item_index(_preview_peer_id))
	var previewed := state.find_player(_preview_peer_id) if cards_open else active
	_preview.show_layout(previewed.layout)
	_preview.show_impact(state.last_hit if int(state.last_hit.get("peer_id", 0)) == previewed.peer_id and not cards_open else {})
	_preview_title.text = "%s의 공개 과녁" % previewed.display_name
	_hint.text = "차례를 기다리는 중입니다."
	if state.phase == MatchState.Phase.PREPARING: _hint.text = "과녁이 멈추면 조준이 열립니다."
	if not state.last_hit.is_empty():
		_hint.text = "직전 다트: %d점 → 효과 적용 %d점" % [state.last_hit.base, state.last_hit.points]
	_cards_panel.visible = cards_open
	_preview_player.visible = cards_open
	_emote.visible = state.phase == MatchState.Phase.AIMING and active.peer_id != _controller.local_peer_id
	if state.phase != MatchState.Phase.AIMING: _overlay.clear()
	_results.visible = state.phase == MatchState.Phase.FINISHED
	_clock.visible = state.phase != MatchState.Phase.FINISHED
	_preview.visible = not _results.visible
	_preview_title.visible = not _results.visible
	_preview_background.visible = not _results.visible
	_hint.visible = not cards_open and not _results.visible
	if cards_open:
		if _previous_phase != state.phase:
			_selected_uid = 0
			_selected_target = 0
		_rebuild_cards()
	if _results.visible: _show_ranking()
	_previous_phase = state.phase


func _rebuild_cards() -> void:
	_clear_buttons(_candidates)
	_clear_buttons(_hand)
	var data := _controller.private_cards
	for index in range(data.candidates.size()):
		var card := CardDefinition.from_snapshot(data.candidates[index])
		var button := Button.new()
		button.text = card.title()
		button.tooltip_text = card.description()
		button.disabled = int(data.picked) >= 0
		button.pressed.connect(card_chosen.emit.bind(index))
		_candidates.add_child(button)
	var player := _controller.state.find_player(_controller.local_peer_id)
	for card in player.hand:
		var button := Button.new()
		button.text = card.title()
		button.tooltip_text = card.description()
		button.disabled = int(data.picked) < 0
		button.pressed.connect(_select_card.bind(card.uid))
		_hand.add_child(button)
	_skip.disabled = int(data.picked) < 0
	if player.find_card(_selected_uid) == null: _selected_uid = 0
	_show_card_info()


func _select_card(uid: int) -> void:
	_selected_uid = uid
	_target.clear()
	var state := _controller.state
	var card := state.find_player(_controller.local_peer_id).find_card(uid)
	for player in state.players:
		var self_target := player.peer_id == _controller.local_peer_id
		if (card.kind == CardDefinition.Kind.SHUFFLE and not self_target) or (card.kind != CardDefinition.Kind.SHUFFLE and self_target):
			_target.add_item(player.display_name, player.peer_id)
	_selected_target = _target.get_item_id(0)
	_target.select(0)
	_show_card_info()


func _show_card_info() -> void:
	var player := _controller.state.find_player(_controller.local_peer_id)
	var card := player.find_card(_selected_uid)
	_confirm.disabled = card == null
	_target.disabled = card == null
	var text := "후보 1장 선택 → 보유 카드 선택 → 대상 확인 → 사용 예약"
	if card != null: text = card.description() + " · 대상: " + _controller.state.find_player(_selected_target).display_name
	var planned: Dictionary = _controller.private_cards.planned
	if int(planned.uid) != 0:
		var pending := player.find_card(planned.uid)
		if pending != null: text += "\n예약 완료: %s → %s · 단계 종료 시 적용" % [pending.title(), _controller.state.find_player(planned.target).display_name]
	_card_info.text = text


func _show_ranking() -> void:
	var sorted := _controller.state.players.duplicate()
	sorted.sort_custom(func(a: MatchPlayer, b: MatchPlayer) -> bool: return a.score > b.score)
	var lines := PackedStringArray(["경기 종료", ""])
	var rank: int = 1
	for index in range(sorted.size()):
		if index > 0 and sorted[index].score != sorted[index - 1].score: rank = index + 1
		lines.append("%d위  %s  ·  %d점" % [rank, sorted[index].display_name, sorted[index].score])
	lines.append("\n방장이 로비로 돌아가면 다시 준비할 수 있습니다.")
	_ranking.text = "\n".join(lines)


func _show_emote(data: Dictionary) -> void:
	if _controller.state.phase == MatchState.Phase.AIMING and _controller.state.active_player().peer_id == _controller.local_peer_id:
		_overlay.show_event(_controller.state.find_player(data.peer_id), data.warning, data.duration)


func _clear_buttons(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
