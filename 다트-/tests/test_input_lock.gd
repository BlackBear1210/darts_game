extends SceneTree
## 마우스가 '숨김'으로 남아 조작이 잠기지 않는지(2026-11-26 사용자 "클릭 빼고는 아무 키도 안 먹어").
## 이동·시점·Space·F 는 모두 마우스가 '잡힘'일 때만 듣는다. 포인터 연출(ui/dart_cursor.gd)이 쓰는
## '숨김' 상태로 남으면 예전 코드는 클릭으로도 다시 잡지 않아 화면이 통째로 잠겼다.
## 헤드리스에서는 Input.mouse_mode 가 유지되지 않으므로 판단 자체(GameView.wants_capture)를 본다.


func _initialize() -> void:
	assert(GameView.wants_capture(Input.MOUSE_MODE_HIDDEN, MatchState.Phase.CARDS), "숨김으로 남아도 클릭으로 다시 잡는다")
	assert(GameView.wants_capture(Input.MOUSE_MODE_VISIBLE, MatchState.Phase.CARDS), "보임이면 예전처럼 다시 잡는다")
	assert(GameView.wants_capture(Input.MOUSE_MODE_CONFINED, MatchState.Phase.AIMING), "잡힘이 아닌 어떤 상태에서도 다시 잡는다")
	assert(not GameView.wants_capture(Input.MOUSE_MODE_CAPTURED, MatchState.Phase.CARDS), "이미 잡혀 있으면 그대로 둔다")
	assert(not GameView.wants_capture(Input.MOUSE_MODE_VISIBLE, MatchState.Phase.FINISHED), "결과 화면에서는 포인터를 그대로 둔다")
	print("PASS: the game regains mouse capture from any uncaptured state except the result screen")
	quit()
