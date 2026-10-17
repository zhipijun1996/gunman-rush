class_name ThornQueenWeaveMotor
extends BossMotor
signal physical_contact(collider: Node)
## Actual colliding motion along announced fixed nest paths, never player prediction.
func travel_to(goal: Vector2, travel_speed: float, delta: float) -> bool:
	if not goal.is_finite() or not is_finite(travel_speed) or travel_speed<=0 or not is_finite(delta) or delta<=0: return false
	var offset := goal-global_position
	var motion := offset.limit_length(travel_speed*delta)
	velocity=motion/delta
	if not motion.is_zero_approx():
		var collision := move_and_collide(motion)
		if collision!=null: physical_contact.emit(collision.get_collider() as Node)
	return global_position.distance_to(goal)<.001
