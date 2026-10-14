extends Node
## 지속되는 연결 노드와 교체되는 화면을 조립한다.

const GAME_SCENE: PackedScene = preload("res://game/game.tscn")
const HUD_SCENE: PackedScene = preload("res://ui/game_hud.tscn")

@onready var session: NetworkSession = $NetworkSession
@onready var lobby: LobbyView = $Lobby

var _game: GameView
var _hud: GameHUD
var _loaded_match_id: int = 0


func _ready() -> void:
	lobby.host_requested.connect(session.host_room)
	lobby.join_requested.connect(session.join_room)
	lobby.ready_requested.connect(session.set_ready)
	lobby.start_requested.connect(session.start_match)
	lobby.leave_requested.connect(session.leave_room)
	session.changed.connect(_refresh_screen)
	_refresh_screen()


func _refresh_screen() -> void:
	var in_game := session.room.phase != RoomState.Phase.LOBBY
	lobby.visible = not in_game
	lobby.render(session.room, session.local_peer_id, session.is_connecting, session.message)
	if not in_game:
		_remove_game()
		return
	if _game == null:
		_game = GAME_SCENE.instantiate() as GameView
		_game.name = "Game"
		add_child(_game)
		_game.configure(session.room, session.local_peer_id)
		_hud = HUD_SCENE.instantiate() as GameHUD
		_hud.name = "GameHUD"
		add_child(_hud)
		_hud.leave_requested.connect(session.leave_room)
		_hud.lobby_requested.connect(session.return_to_lobby)
		_hud.configure(_game.controller, _game.throw_input)
	_hud.render(session.room, session.local_peer_id, session.message)
	if session.room.phase == RoomState.Phase.PLAYING:
		_game.controller.start()
	if session.room.phase == RoomState.Phase.LOADING and _loaded_match_id != session.room.match_id:
		_loaded_match_id = session.room.match_id
		# 화면 생성과 signal 처리를 끝낸 뒤 로딩 완료를 알린다.
		session.confirm_loaded.call_deferred(_loaded_match_id)


func _remove_game() -> void:
	if _game != null:
		remove_child(_game)
		_game.queue_free()
		_game = null
		remove_child(_hud)
		_hud.queue_free()
		_hud = null
	_loaded_match_id = 0
