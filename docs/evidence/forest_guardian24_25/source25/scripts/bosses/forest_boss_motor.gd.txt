class_name ForestBossMotor
extends BossMotor
## One physical sweep per accepted game step. No predicted-position teleport.
signal physical_contact(collider: Node)
var motion_steps := 0
var motion_safe_margin := 0.08
func advance_duel(velocity_value: Vector2, delta: float) -> KinematicCollision2D:
	if not velocity_value.is_finite() or not is_finite(delta) or delta <= 0: return null
	velocity = velocity_value
	motion_steps += 1
	var collision := move_and_collide(velocity*delta,false,motion_safe_margin,false)
	if collision != null and collision.get_collider() is Node:
		physical_contact.emit(collision.get_collider() as Node)
	return collision
