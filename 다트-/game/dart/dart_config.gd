class_name DartConfig
extends Resource
## 투척 입력과 비행·미리보기가 공유하는 설정 및 좌표 계산.

@export_range(0.01, 10.0) var charge_seconds: float = 0.8
@export var minimum_speed: float = 7.0
@export var maximum_speed: float = 16.0
@export var flight_limit: float = 2.0
## 2026-11-24 사용자 요청 "좀 더 포물선으로 날라가게": 9.8 → 14.0.
## 방장이 도착 시각을 맞춰 위로 던지므로(initial_velocity) 중력이 클수록 같은 자리에 꽂히면서 더 높이 솟는다.
## 7.26m 거리에서 꽉 충전한 한 발이 직선보다 0.25m → 0.36m 위로 지난다.
## 대신 충전이 모자라면 더 떨어진다(70% 충전 −0.25m → −0.35m). 점수 원 반지름이 0.75m 라 아직 판 안이다.
@export_range(0.0, 30.0) var gravity: float = 14.0
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
