class_name DartConfig
extends Resource
## 투척 입력과 비행·미리보기가 공유하는 설정 및 좌표 계산.

@export_range(0.01, 10.0) var charge_seconds: float = 0.8
@export var minimum_speed: float = 7.0
@export var maximum_speed: float = 16.0
@export var flight_limit: float = 2.0
@export_range(0.0, 30.0) var gravity: float = 9.8
@export var timing_offset: Vector2 = Vector2(0.14, 0.15)
@export_range(0.01, 10.0) var miss_lifetime: float = 0.25


func impact_position(aim: Vector2, timing: float) -> Vector2:
	var error: float = timing - 0.5
	return aim + Vector2(error * timing_offset.x, absf(error) * timing_offset.y)


func initial_velocity(start: Vector3, target: Vector3, duration: float) -> Vector3:
	# 방장이 확정한 도착 시각과 착탄점을 만족하는 등가속도 운동의 초기 속도다.
	return (target - start) / duration + Vector3.UP * gravity * duration * 0.5


func position_at(start: Vector3, velocity: Vector3, seconds: float) -> Vector3:
	return start + velocity * seconds + Vector3.DOWN * gravity * seconds * seconds * 0.5
