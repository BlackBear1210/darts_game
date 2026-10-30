extends SceneTree
## 실행 장면에서 사용하지 않는 이전 모듈도 함께 파싱해 에디터 오류를 찾는다.
var count: int = 0
var failed: bool = false

func _initialize() -> void:
	_scan("res://")
	print("PASS: all ", count, " project scripts load" if not failed else "FAIL: script load")
	quit(1 if failed else 0)

func _scan(path: String) -> void:
	for folder in DirAccess.get_directories_at(path):
		if folder.begins_with(".") or folder in ["output", "backend"]: continue
		_scan(path.path_join(folder))
	for file in DirAccess.get_files_at(path):
		if not file.ends_with(".gd"): continue
		var location: String = path.path_join(file)
		if location == "res://tests/test_script_load.gd": continue
		var script := load(location) as Script
		if script == null or not script.can_instantiate():
			printerr("FAIL: ", location)
			failed = true
		count += 1
