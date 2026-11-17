extends Node3D
## 펍 창 밖 움직임(2026-11-16). 디자인 담당 소유. 붙는 곳 = pub_game.tscn 의 Outside 노드(art/pub/street_outside.gd 가 붙인다).
## 창 밖이 "그림"이 아니라 살아 있는 거리로 느껴지게: 관람차가 돌고, 열기구가 떠 있고, 차가 지나가고, 구름이 흐른다.
##
## [어떻게 움직일 노드를 고르나]
##   생성기가 움직일 노드에 메타 "motion"(사전)을 붙여 둔다. 여기서는 그 메타만 읽는다 — 노드 이름·구조를 몰라도 된다.
##     {"kind": "spin",  "axis": Vector3, "speed": 라디안/초}           — 제 자리에서 돈다(관람차 바퀴·칸은 반대로 돌아 늘 똑바로).
##     {"kind": "bob",   "amp": m, "speed": 라디안/초, "phase": 라디안} — 위아래로 둥실(열기구).
##     {"kind": "drive", "from": Vector3, "to": Vector3, "speed": m/초, "offset": 0~1} — 길을 따라 가다 끝에서 처음으로(차).
##     {"kind": "drift", "speed": m/초, "span": m}                       — 로컬 X(세계 X)로 흐르다 span 을 넘으면 반대편에서 다시(구름).
## 경기와 상관없는 그림이라 네트워크로 맞추지 않는다(사람마다 차 위치가 달라도 된다).
## 편집기에서는 돌지 않는다(@tool 아님) — 장면을 열면 생성기가 둔 자리 그대로 보인다.

var _movers: Array[Dictionary] = []
var _time: float = 0.0


func _ready() -> void:
	_collect(self)
	set_process(not _movers.is_empty())


func _collect(node: Node) -> void:
	for child in node.get_children():
		if child is Node3D and child.has_meta("motion"):
			var spot := child as Node3D
			_movers.append({"node": spot, "motion": spot.get_meta("motion"), "base": spot.transform})
		_collect(child)


func _process(delta: float) -> void:
	_time += delta
	for mover: Dictionary in _movers:
		var node: Node3D = mover.node
		var motion: Dictionary = mover.motion
		var base: Transform3D = mover.base
		match str(motion.get("kind", "")):
			"spin":
				var axis: Vector3 = motion.get("axis", Vector3.UP)
				node.transform.basis = base.basis * Basis(axis.normalized(), float(motion.get("speed", 0.1)) * _time)
			"bob":
				var lift: float = float(motion.get("amp", 0.5)) * sin(_time * float(motion.get("speed", 0.5)) + float(motion.get("phase", 0.0)))
				node.position = base.origin + Vector3.UP * lift
			"drive":
				var from: Vector3 = motion.get("from", Vector3.ZERO)
				var to: Vector3 = motion.get("to", Vector3.ZERO)
				var length: float = maxf(from.distance_to(to), 0.01)
				var share: float = fposmod(float(motion.get("offset", 0.0)) + _time * float(motion.get("speed", 8.0)) / length, 1.0)
				node.position = from.lerp(to, share)
			"drift":
				var span: float = float(motion.get("span", 400.0))
				var shift: float = fposmod(base.origin.x + span / 2.0 + _time * float(motion.get("speed", 1.0)), span) - span / 2.0
				node.position = Vector3(shift, base.origin.y, base.origin.z)
