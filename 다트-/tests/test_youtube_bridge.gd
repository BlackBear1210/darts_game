extends SceneTree
## 브라우저를 열지 않고 실제 loopback HTTP 요청으로 브리지의 경로/상태 응답을 확인한다.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var bridge: Node = preload("res://game/lounge/youtube_bridge.gd").new()
	root.add_child(bridge)
	assert(bridge.port > 0)
	bridge.state = {"video": "dQw4w9WgXcQ", "playing": true, "volume": 0.3}
	var request := HTTPRequest.new()
	root.add_child(request)
	assert(request.request("http://127.0.0.1:%d/state" % bridge.port) == OK)
	var response: Array = await request.request_completed
	assert(response[1] == 200)
	var data: Dictionary = JSON.parse_string(response[3].get_string_from_utf8())
	assert(data.video == bridge.state.video and is_equal_approx(data.volume, 0.3))
	request.request("http://127.0.0.1:%d/player" % bridge.port)
	response = await request.request_completed
	assert(response[1] == 200 and response[3].get_string_from_utf8().contains("youtube.com/iframe_api"))
	request.request("http://127.0.0.1:%d/../../project.godot" % bridge.port)
	response = await request.request_completed
	assert(response[1] == 404)
	bridge.queue_free()
	request.queue_free()
	await process_frame
	print("PASS: YouTube loopback bridge HTTP state/player/unknown routes")
	quit()
