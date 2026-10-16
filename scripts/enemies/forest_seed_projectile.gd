class_name ForestSeedProjectile
extends EnemyAttackProjectile
## Fixed ballistic path, collision-occluded flight, short old-branch danger.
var origin := Vector2.ZERO
var goal := Vector2.ZERO
var flight_seconds := 1.0
var arc_height := 70.0
var zone_seconds := 0.4
var age := 0.0
var landed := false
func _physics_process(delta: float) -> void:
	if spent: return
	if not is_instance_valid(behavior) or not behavior._active() or not behavior.lifetime.accepts(token):
		dispose()
		return
	age += delta
	if not landed:
		var t := clampf(age / flight_seconds, 0, 1)
		var next := origin.lerp(goal, t) + Vector2(0, -sin(PI * t) * arc_height)
		var ray := PhysicsRayQueryParameters2D.create(global_position, next, 1, [behavior.actor.motor.get_rid(), behavior.controller.motor.get_rid()])
		var hit := get_world_2d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and (hit.position as Vector2).distance_to(goal) > radius * 2:
			dispose()
			return
		global_position = next
		if t >= 1:
			landed = true
			age = 0
			GameAudio.cue(self, &"bell")
	if landed:
		if age >= zone_seconds:
			dispose()
			return
		var bounds := Rect2(goal - Vector2(behavior.actor.definition.pulse_size.x * .5, behavior.actor.definition.pulse_size.y), behavior.actor.definition.pulse_size)
		for safe: Vector2 in behavior.protected_points:
			if bounds.grow(behavior.actor.definition.protected_radius).has_point(safe):
				dispose()
				return
		var target_shape := behavior.controller.motor.get_node("CollisionShape2D") as CollisionShape2D
		var target_bounds := target_shape.shape.get_rect()
		target_bounds.position += target_shape.global_position
		if bounds.intersects(target_bounds):
			var request := DamageRequest.new()
			request.token = token
			request.event_id = event_id
			request.source_id = behavior.source_id
			request.target_id = &"player"
			request.amount = 1
			request.actor_epoch = token.actor_epoch
			request.health_epoch = behavior.controller.actor_resources.health.epoch
			behavior.policy.submit(request)
	queue_redraw()
func _draw() -> void:
	if landed:
		var size := behavior.actor.definition.pulse_size
		draw_rect(Rect2(Vector2(-size.x * .5, -size.y), size), Color(0.8, 0.24, 0.35, .7))
		for x: int in range(-int(size.x * .5), int(size.x * .5), 12):
			draw_line(Vector2(x, 0), Vector2(x + 6, -size.y), Color(1, .7, .45), 3)
	else:
		draw_circle(Vector2.ZERO, radius + 2, Color(.95, .68, .32))
		draw_line(Vector2(-6, 2), Vector2(5, -3), Color(.3, .15, .12), 2)
