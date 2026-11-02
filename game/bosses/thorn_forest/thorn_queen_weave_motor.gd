class_name ThornQueenWeaveMotor
extends BossMotor
signal physical_contact(collider: Node)
signal movement_observed(data: Dictionary)
## Actual colliding motion along announced fixed nest paths, never player prediction.
func travel_to(goal: Vector2, travel_speed: float, delta: float) -> bool:
	if not goal.is_finite() or not is_finite(travel_speed) or travel_speed<=0 or not is_finite(delta) or delta<=0: return false
	var offset := goal-global_position
	var motion := offset.limit_length(travel_speed*delta)
	velocity=motion/delta
	if not motion.is_zero_approx():
		var before := global_position
		var collision := move_and_collide(motion)
		var actual := global_position-before
		var observation := {"physics_frame":Engine.get_physics_frames(),"before":[before.x,before.y],"after":[global_position.x,global_position.y],"requested":[motion.x,motion.y],"actual":[actual.x,actual.y],"collision":collision!=null}
		if collision!=null:
			var collider := collision.get_collider() as Node
			var travel := collision.get_travel();var remainder := collision.get_remainder();var normal := collision.get_normal()
			observation.merge({"travel":[travel.x,travel.y],"remainder":[remainder.x,remainder.y],"normal":[normal.x,normal.y],"collider_id":collider.get_instance_id() if is_instance_valid(collider) else 0,"collider_name":String(collider.name) if is_instance_valid(collider) else "","collider_class":collider.get_class() if is_instance_valid(collider) else ""})
			physical_contact.emit(collider)
		movement_observed.emit(observation)
	return global_position.distance_to(goal)<.001
