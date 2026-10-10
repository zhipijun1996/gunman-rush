class_name PlayerMotor
extends CharacterBody2D

var tuning: PlayerTuning
var normal_velocity := Vector2.ZERO
var recoil_velocity := Vector2.ZERO
var recoil_burst_remaining := 0.0
var _drop_body: PhysicsBody2D
var _drop_remaining := 0.0

func step(move_axis: float, delta: float) -> void:
	_advance_drop(delta)
	var acceleration := tuning.ground_acceleration if is_on_floor() else tuning.air_acceleration
	if is_zero_approx(move_axis) and is_on_floor():
		acceleration = tuning.ground_deceleration
	normal_velocity.x = move_toward(normal_velocity.x, move_axis * tuning.ground_speed, acceleration * delta)
	var bursting := recoil_burst_remaining > 0.0
	if bursting:
		# Fractional last tick preserves speed * duration distance at any fixed Hz.
		velocity = recoil_velocity * minf(1.0, recoil_burst_remaining / delta)
	else:
		normal_velocity.y = minf(normal_velocity.y + tuning.gravity * delta, tuning.max_normal_fall_speed)
		recoil_velocity *= exp(-delta / tuning.recoil_tau)
		velocity = normal_velocity + recoil_velocity
	move_and_slide()
	for index: int in get_slide_collision_count():
		var normal := get_slide_collision(index).get_normal()
		if normal_velocity.dot(normal) < 0.0:
			normal_velocity -= normal * normal_velocity.dot(normal)
		if recoil_velocity.dot(normal) < 0.0:
			recoil_velocity -= normal * recoil_velocity.dot(normal)

	if bursting:
		recoil_burst_remaining = maxf(0.0, recoil_burst_remaining - delta)
		if recoil_burst_remaining <= 1.0e-9:
			clear_recoil()

func reset_at(location: Vector2) -> void:
	_clear_drop()
	position = location
	reset_motion()

func reset_motion() -> void:
	_clear_drop()
	normal_velocity = Vector2.ZERO
	clear_recoil()
	velocity = Vector2.ZERO

func apply_impulse(impulse: Vector2) -> void:
	if recoil_burst_remaining > 0.0:
		clear_recoil()
	recoil_velocity += impulse

func start_shot_burst(direction: Vector2, strength: float = 1.0) -> void:
	if not direction.is_finite() or direction.is_zero_approx():
		return
	var unit := direction.normalized()
	var opposing := normal_velocity.dot(unit)
	if opposing < 0.0:
		normal_velocity -= unit * opposing
	normal_velocity.y = 0.0
	recoil_velocity = unit * tuning.shot_burst_speed * clampf(strength, 0.0, 1.0)
	recoil_burst_remaining = tuning.shot_burst_duration

func clear_recoil() -> void:
	recoil_velocity = Vector2.ZERO
	recoil_burst_remaining = 0.0

func request_drop_through() -> bool:
	if not is_on_floor() or is_instance_valid(_drop_body):
		return false
	for index: int in get_slide_collision_count():
		var collision := get_slide_collision(index)
		var body := collision.get_collider() as PhysicsBody2D
		if collision.get_normal().dot(up_direction) > 0.7 and body != null and body.is_in_group("one_way_platform"):
			var platform_shape := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
			if platform_shape == null or not platform_shape.one_way_collision or not platform_shape.shape is RectangleShape2D:
				continue
			_drop_body = body
			_drop_remaining = tuning.drop_through_duration
			add_collision_exception_with(body)
			normal_velocity.y = maxf(normal_velocity.y, tuning.drop_through_speed)
			return true
	return false

func _advance_drop(delta: float) -> void:
	if not is_instance_valid(_drop_body):
		_drop_body = null
		return
	_drop_remaining -= delta
	# Only restore once the player's entire collision volume is below the
	# platform: never close the exception while still intersecting its top.
	var platform_shape := _drop_body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var player_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if _drop_remaining <= 0.0 and platform_shape != null and player_shape != null:
		var platform_bottom := platform_shape.global_position.y + platform_shape.shape.get_rect().end.y
		var player_top := player_shape.global_position.y + player_shape.shape.get_rect().position.y
		if player_top > platform_bottom:
			_clear_drop()

func _clear_drop() -> void:
	if is_instance_valid(_drop_body):
		remove_collision_exception_with(_drop_body)
	_drop_body = null
	_drop_remaining = 0.0
