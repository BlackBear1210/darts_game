extends Node
## Godot 기본 배포에는 웹뷰가 없다. 로컬 브라우저의 공식 YouTube 플레이어와 주크박스 상태를 연결한다.
## loopback 전용 읽기 서버이며 외부 명령·파일 경로·게임 변경 요청은 받지 않는다.
var server := TCPServer.new()
var port: int = 0
var state: Dictionary = {"video": "", "playing": false, "volume": 0.5}
var _clients: Array[Dictionary] = []

func _ready() -> void:
	for candidate in range(18740, 18780):
		if server.listen(candidate, "127.0.0.1") == OK:
			port = candidate
			break

func open_player() -> void:
	if port != 0: OS.shell_open("http://127.0.0.1:%d/player" % port)

func _process(_delta: float) -> void:
	while server.is_connection_available() and _clients.size() < 8:
		_clients.append({"peer": server.take_connection(), "text": "", "at": Time.get_ticks_msec()})
	for client in _clients.duplicate():
		var peer: StreamPeerTCP = client.peer
		peer.poll()
		if Time.get_ticks_msec() - int(client.at) > 2000 or peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			peer.disconnect_from_host()
			_clients.erase(client)
			continue
		var count: int = peer.get_available_bytes()
		if count > 0:
			client.text += peer.get_utf8_string(mini(count, 4096))
		if str(client.text).length() > 4096:
			peer.disconnect_from_host()
			_clients.erase(client)
			continue
		if not str(client.text).contains("\r\n\r\n"): continue
		var first: String = str(client.text).get_slice("\r\n", 0)
		var body: String = "Not found"
		var mime: String = "text/plain"
		var code: String = "404 Not Found"
		if first == "GET /state HTTP/1.1":
			body = JSON.stringify(state)
			mime = "application/json"
			code = "200 OK"
		elif first == "GET /player HTTP/1.1":
			body = FileAccess.get_file_as_string("res://game/lounge/youtube_player.html")
			mime = "text/html; charset=utf-8"
			code = "200 OK"
		var header: String = "HTTP/1.1 %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n" % [code, mime, body.to_utf8_buffer().size()]
		peer.put_data((header + body).to_utf8_buffer())
		_clients.erase(client)

func _exit_tree() -> void:
	server.stop()
	for client in _clients: (client.peer as StreamPeerTCP).disconnect_from_host()

static func video_id(url: String) -> String:
	var expression := RegEx.new()
	expression.compile("^https://(?:www\\.)?(?:youtube\\.com/(?:watch\\?v=|shorts/|embed/)|youtu\\.be/)([A-Za-z0-9_-]{11})(?:[?&#].*)?$")
	var found := expression.search(url.strip_edges())
	return found.get_string(1) if found != null else ""
