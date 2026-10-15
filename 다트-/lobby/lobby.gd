class_name LobbyView
extends Control
## 입력을 요청으로 전달하고, 방 상태를 표시한다. 경기 상태를 수정하지 않는다.

signal host_requested(display_name: String, port: int)
signal join_requested(display_name: String, address: String, port: int)
signal ready_requested(value: bool)
signal start_requested
signal leave_requested
signal login_requested(display_name: String, password: String)
signal profile_requested

@onready var _name_input: LineEdit = %NameInput
@onready var _address_input: LineEdit = %AddressInput
@onready var _port_input: SpinBox = %PortInput
@onready var _host_button: Button = %HostButton
@onready var _join_button: Button = %JoinButton
@onready var _ready_button: CheckButton = %ReadyButton
@onready var _start_button: Button = %StartButton
@onready var _leave_button: Button = %LeaveButton
@onready var _players_label: Label = %PlayersLabel
@onready var _status_label: Label = %StatusLabel
@onready var _account_controls: VBoxContainer = %AccountControls
@onready var _password: LineEdit = %PasswordInput
@onready var _login_button: Button = %LoginButton
@onready var _profile_label: Label = %ProfileLabel
var _accounts_enabled: bool = false


func _ready() -> void:
	_host_button.pressed.connect(_request_host)
	_join_button.pressed.connect(_request_join)
	_ready_button.toggled.connect(ready_requested.emit)
	_start_button.pressed.connect(start_requested.emit)
	_leave_button.pressed.connect(leave_requested.emit)
	_login_button.pressed.connect(func() -> void:
		login_requested.emit(_name_input.text, _password.text)
		_password.clear())
	%RefreshProfile.pressed.connect(profile_requested.emit)


func render(room: RoomState, local_peer_id: int, connecting: bool, message: String) -> void:
	var local_player := room.find_player(local_peer_id)
	var in_room := local_player != null
	_name_input.editable = not in_room and not connecting
	_address_input.editable = not in_room and not connecting
	_port_input.editable = not in_room and not connecting
	_host_button.disabled = in_room or connecting or _accounts_enabled
	_login_button.disabled = in_room or connecting
	_join_button.disabled = in_room or connecting
	_ready_button.visible = in_room
	_ready_button.set_pressed_no_signal(in_room and local_player.is_ready)
	_start_button.visible = in_room and local_peer_id == room.host_peer_id
	_start_button.disabled = not room.can_start()
	_leave_button.visible = in_room or connecting
	_status_label.text = message
	var lines := PackedStringArray()
	for player in room.players:
		var role := "방장" if player.peer_id == room.host_peer_id else "참가자"
		var ready_text := "준비 완료" if player.is_ready else "준비 전"
		var suffix := " · 나" if player.peer_id == local_peer_id else ""
		lines.append("%d. %s (%s%s) — %s" % [player.seat + 1, player.display_name, role, suffix, ready_text])
	_players_label.text = "참가자 %d/%d\n\n%s" % [room.players.size(), RoomState.MAX_PLAYERS, "\n".join(lines)]


func _request_host() -> void:
	host_requested.emit(_name_input.text, int(_port_input.value))


func _request_join() -> void:
	join_requested.emit(_name_input.text, _address_input.text, int(_port_input.value))


func enable_accounts() -> void:
	_accounts_enabled = true
	_account_controls.show()
	_host_button.disabled = true


func render_account(status: String, profile: Dictionary, busy: bool) -> void:
	_login_button.disabled = busy or _leave_button.visible
	_profile_label.text = status
	if not profile.is_empty():
		_profile_label.text += " · %s · %d경기 / %d승 / 누적 %d점" % [profile.name, profile.matches, profile.wins, profile.total_score]
