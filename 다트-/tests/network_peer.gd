extends SceneTree
## 에디터 CLI와 내보낸 테스트 Scene이 같은 검증 로직을 사용한다.


func _initialize() -> void:
	var probe: Node = load("res://tests/network_probe.gd").new()
	root.add_child.call_deferred(probe)
