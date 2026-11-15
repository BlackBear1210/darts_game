class_name RoomPlayer
extends RefCounted
## 접속한 플레이어의 공개 로비 상태. Node와 화면에 의존하지 않는다.

var peer_id: int
var display_name: String
var seat: int
var is_ready: bool = false
var is_loaded: bool = false
var is_bot: bool = false
## 꾸미기 차림(2026-11-15 — art/characters/player_outfit.gd 의 칸 번호). 보이기만 한다. 방장이 정하고 방 정보와 같이 간다.
var look: Dictionary = {}


func _init(id: int = 0, player_name: String = "", seat_index: int = 0) -> void:
	peer_id = id
	display_name = player_name
	seat = seat_index


func to_snapshot() -> Dictionary:
	return {
		"peer_id": peer_id,
		"name": display_name,
		"seat": seat,
		"ready": is_ready,
		"loaded": is_loaded,
		"bot": is_bot,
		"look": look,
	}


static func from_snapshot(data: Dictionary) -> RoomPlayer:
	var player := RoomPlayer.new(data.peer_id, data.name, data.seat)
	player.is_ready = data.ready
	player.is_loaded = data.loaded
	player.is_bot = data.get("bot", false)
	var saved_look: Variant = data.get("look", {})
	player.look = saved_look if saved_look is Dictionary else {}
	return player
