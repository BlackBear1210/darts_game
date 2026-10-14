class_name DartView
extends Node3D


func fly(start: Vector3, target: Vector3, duration: float, hit_board: bool = true) -> void:
	global_position = start
	look_at(target, Vector3.UP)
	var flight := create_tween()
	flight.tween_method(func(progress: float) -> void:
		global_position = start.lerp(target, progress) + Vector3.UP * sin(progress * PI) * 0.06,
		0.0, 1.0, duration)
	if not hit_board:
		flight.tween_property(self, "position:y", 0.78, 0.25)
		flight.tween_callback(queue_free)
