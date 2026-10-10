class_name EnemyMotor
extends CharacterBody2D

var patrol_speed := 0.0

func configure(definition: EnemyDefinition) -> void:
	patrol_speed = definition.patrol_speed
	var shape := RectangleShape2D.new()
	shape.size = definition.collision_size
	($CollisionShape2D as CollisionShape2D).shape = shape

func step(intent: EnemyIntent, delta: float) -> bool:
	velocity = Vector2.ZERO
	if intent == null or not is_finite(delta) or delta <= 0.0 or intent.move_axis not in [-1, 0, 1] or not is_finite(intent.travel_limit) or intent.travel_limit < 0.0:
		return false
	# This first enemy is a hovering patrol fixture, not a ground/gravity policy.
	var distance := minf(patrol_speed * delta, intent.travel_limit)
	velocity.x = float(intent.move_axis) * distance / delta
	return move_and_collide(Vector2(float(intent.move_axis) * distance, 0.0)) != null if distance > 0.0 and intent.move_axis != 0 else false

func stop() -> void:
	velocity = Vector2.ZERO

func reset_at(location: Vector2) -> void:
	stop()
	global_position = location

func move_attack(motion: Vector2, require_floor: bool, delta: float) -> bool:
	if not motion.is_finite() or not is_finite(delta) or delta <= 0: return false
	if require_floor:
		var feet := global_position + Vector2(signf(motion.x) * 15, 18)
		var ray := PhysicsRayQueryParameters2D.create(feet + motion + Vector2(0, -2), feet + motion + Vector2(0, 8), 1, [get_rid()])
		if get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			velocity = Vector2.ZERO
			return false
	velocity = motion / delta
	return move_and_collide(motion) == null
