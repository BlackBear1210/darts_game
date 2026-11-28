class_name ScoreWall
extends Node3D
## 왼쪽 벽의 영사막. 이름·점수·차례가 같은 스냅샷은 화면을 다시 그리지 않는다.
const Kit = preload("res://art/mesh_kit.gd")
const Display = preload("res://art/dart_machine/score_display.gd")
const SIZE := Vector2(1.46, 2.11)
var wall_z := 0.0
var face := Display.new()


func _ready() -> void:
	position = Vector3(-2.14, 2.55, wall_z + 0.19)
	var metal := Kit.material("ScreenBronze", "987854", 0.45)
	var housing := Kit.material("ProjectorCase", "383b36", 0.22)
	Kit.rounded_box(self, "ScreenBacking", Vector3(SIZE.x + 0.05, SIZE.y + 0.04, 0.05), Vector3.ZERO, housing, 0.018, 2)
	for side: float in [-1.0, 1.0]:
		Kit.rounded_box(self, "ScreenRoll", Vector3(SIZE.x + 0.13, 0.065, 0.08),
			Vector3(0, side * (SIZE.y * 0.5 + 0.02), 0.021), metal, 0.026, 2)
	# 짧은 벽걸이 암과 뒤를 보는 렌즈. 별도 광원이나 그림자 패스를 쓰지 않는다.
	Kit.box(self, "ProjectorArm", Vector3(0.055, 0.07, 0.63), Vector3(0, 1.36, 0.18), metal)
	var head := Kit.rounded_box(self, "Projector", Vector3(0.34, 0.14, 0.25), Vector3(0, 1.29, 0.51), housing, 0.025, 2)
	head.rotation.x = -0.62
	var lens := Kit.cylinder(head, "Lens", 0.055, 0.04, Vector3(0.075, 0, -0.13),
		Kit.material("ProjectorLens", "c5f3b4", 0.15, 0.5), 12)
	lens.rotation.x = PI / 2.0
	face.mount(self, Vector3(0, 0, 0.033), SIZE, true)


func show_players(players: Array, active_id: int, punish_id: int) -> void:
	var rows: Array[Dictionary] = []
	for player: MatchPlayer in players:
		var tag := ""
		if player.peer_id == punish_id: tag = "벌칙"
		elif player.peer_id == active_id: tag = "차례"
		rows.append({"seat": player.seat, "label": player.display_name, "score": Display.score_text(player.score),
			"tag": tag, "color": PlayerLook.COLORS[posmod(player.seat, PlayerLook.COLORS.size())]})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.seat < b.seat)
	face.present(rows)
