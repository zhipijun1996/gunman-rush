class_name DamageBoundary
extends RefCounted
## A camera/manifest rectangle is not a hazard volume. Falling returns only
## below the lower world edge, after checking actual lower landing colliders.
static func should_return(motor: PlayerMotor, world_bounds: Rect2) -> bool:
	if not is_instance_valid(motor) or not motor.is_inside_tree() or not world_bounds.position.is_finite() or not world_bounds.size.is_finite(): return false
	var collision := motor.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or not collision.shape is RectangleShape2D: return false
	var half := (collision.shape as RectangleShape2D).size*.5
	var center := collision.global_position
	# The whole player must have left the bottom; high jumps and side detours
	# never lose HP merely because they leave a content-framing rectangle.
	if center.y-half.y <= world_bounds.end.y+100: return false
	if motor.is_on_floor(): return false
	return not has_landing_below(motor,maxf(world_bounds.size.y,2048.0))

static func has_landing_below(motor: PlayerMotor, scan: float = 4096.0) -> bool:
	if not is_instance_valid(motor) or not motor.is_inside_tree(): return false
	var collision := motor.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or not collision.shape is RectangleShape2D: return false
	var half := (collision.shape as RectangleShape2D).size*.5
	var center := collision.global_position
	var space := motor.get_world_2d().direct_space_state
	var feet := center+Vector2(0,half.y)
	for offset: float in [-half.x+1,0,half.x-1]:
		var ray := PhysicsRayQueryParameters2D.create(feet+Vector2(offset,-1),feet+Vector2(offset,scan),motor.collision_mask,[motor.get_rid()])
		var hit := space.intersect_ray(ray)
		if not hit.is_empty() and (hit.normal as Vector2).dot(Vector2.UP)>.7: return true
	return false
