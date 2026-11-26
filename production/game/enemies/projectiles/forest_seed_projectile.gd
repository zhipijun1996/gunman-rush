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
		var previous_t := clampf((age-delta)/flight_seconds,0,1)
		var velocity := ((goal-origin)*(t-previous_t) + Vector2.UP*(sin(PI*t)-sin(PI*previous_t))*arc_height)/maxf(delta,0.000001)
		if flight.reflections>0: velocity = velocity.bounce(flight.reflection_normal)
		direction = velocity.normalized()
		flight.advance(self,behavior.controller,"enemy",velocity,delta,_move_ballistic)
		if spent: return
		if t >= 1:
			landed = true
			remove_from_group(&"ordinary_flight_enemy")
			goal = global_position
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
		var gear := behavior.controller.item_runtime
		if gear != null and gear.fx.guard_hp > 0 and not gear.scene.drones.is_empty() and bounds.grow(9).has_point(gear.scene.drones[0]):
			gear.scene.guard_hit(str(event_id),1)
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
func _move_ballistic(motion: Vector2) -> void:
	var excluded: Array[RID] = flight.grate_excludes.duplicate()
	excluded.append(behavior.actor.motor.get_rid())
	excluded.append(behavior.controller.motor.get_rid())
	var next := global_position+motion
	var ray := PhysicsRayQueryParameters2D.create(global_position,next,1,excluded)
	var hit := get_world_2d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty() and (hit.position as Vector2).distance_to(goal)>radius*2:
		dispose()
		return
	global_position = next

# This ballistic seed is dangerous only after landing in the original rules.
# Frozen flight must not acquire a new midair damage behavior.
func advance_frozen_contact() -> void:
	if spent or not is_inside_tree(): return
	if not is_instance_valid(behavior) or not behavior._active() or not behavior.lifetime.accepts(token):
		dispose()
		return
	if not landed: return
	var bounds := Rect2(goal - Vector2(behavior.actor.definition.pulse_size.x * .5, behavior.actor.definition.pulse_size.y), behavior.actor.definition.pulse_size)
	for safe: Vector2 in behavior.protected_points:
		if bounds.grow(behavior.actor.definition.protected_radius).has_point(safe):
			dispose()
			return
	var target_shape := behavior.controller.motor.get_node("CollisionShape2D") as CollisionShape2D
	var target_bounds := target_shape.shape.get_rect()
	target_bounds.position += target_shape.global_position
	var gear := behavior.controller.item_runtime
	if gear != null and gear.fx.guard_hp > 0 and not gear.scene.drones.is_empty() and bounds.grow(9).has_point(gear.scene.drones[0]):
		gear.scene.guard_hit(str(event_id),1)
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

func _draw() -> void:
	if landed:
		var size:=behavior.actor.definition.pulse_size
		PixelVfx.hazard_patch(self,Rect2(Vector2(-size.x*.5,-size.y),size),age)
	else:
		draw_circle(Vector2.ZERO,radius+2,Color("392c2a"))
		PixelVfx.shard(self,Vector2.ZERO,Vector2(1,-.3),radius*2, radius*.6,Color("d8a065"))
