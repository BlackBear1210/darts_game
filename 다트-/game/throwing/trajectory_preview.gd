class_name TrajectoryPreview
extends MeshInstance3D
## 소유하는 Game이 전달한 월드 좌표로 예상 비행선만 그린다.

const SEGMENTS: int = 32

var _trajectory: ImmediateMesh = ImmediateMesh.new()


func _ready() -> void:
	mesh = _trajectory
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.3, 0.9, 1.0)
	material_override = material
	visible = false


func show_trajectory(start: Vector3, target: Vector3, duration: float, config: DartConfig) -> void:
	var velocity: Vector3 = config.initial_velocity(start, target, duration)
	_trajectory.clear_surfaces()
	_trajectory.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for index: int in range(SEGMENTS + 1):
		var seconds: float = duration * float(index) / SEGMENTS
		_trajectory.surface_add_vertex(to_local(config.position_at(start, velocity, seconds)))
	_trajectory.surface_end()
	visible = true
