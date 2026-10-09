class_name PlayerMotor
extends CharacterBody2D

var tuning: PlayerTuning
var normal_velocity := Vector2.ZERO
var recoil_velocity := Vector2.ZERO

func step(move_axis: float, delta: float) -> void:
	var acceleration := tuning.ground_acceleration if is_on_floor() else tuning.air_acceleration
	if is_zero_approx(move_axis) and is_on_floor():
		acceleration = tuning.ground_deceleration
	normal_velocity.x = move_toward(normal_velocity.x, move_axis * tuning.ground_speed, acceleration * delta)
	normal_velocity.y = minf(normal_velocity.y + tuning.gravity * delta, tuning.max_normal_fall_speed)
	velocity = normal_velocity + recoil_velocity
	move_and_slide()
	for index: int in get_slide_collision_count():
		var normal := get_slide_collision(index).get_normal()
		if normal_velocity.dot(normal) < 0.0:
			normal_velocity -= normal * normal_velocity.dot(normal)
		if recoil_velocity.dot(normal) < 0.0:
			recoil_velocity -= normal * recoil_velocity.dot(normal)

func reset_at(location: Vector2) -> void:
	position = location
	reset_motion()

func reset_motion() -> void:
	normal_velocity = Vector2.ZERO
	recoil_velocity = Vector2.ZERO
	velocity = Vector2.ZERO
