class_name ForestSeedSentryBehavior
extends EnemyAttackBehavior
## Locks the currently supported branch, including one-way/high branches.
## Unlike RootBell, a seed travels through real space and can be occluded.
var _first_advance := true
func advance(delta: float) -> bool:
	if not _active():
		cancel()
		return true
	if _actor_epoch != lifetime.actor_epoch or _first_advance:
		_first_advance = false
		_actor_epoch = lifetime.actor_epoch
		if state in [&"telegraph", &"attack"]: cancel()
	state_time += delta
	cooldown = maxf(0, cooldown - delta)
	if state == &"idle" and cooldown <= 0 and _can_engage() and controller.motor.is_on_floor():
		var origin := controller.motor.global_position
		var ray := PhysicsRayQueryParameters2D.create(origin, origin + Vector2(0, 42), 1, [controller.motor.get_rid(), actor.motor.get_rid()])
		var support := actor.motor.get_world_2d().direct_space_state.intersect_ray(ray)
		if not support.is_empty() and (support.normal as Vector2).y < -0.5:
			attack_goal = support.position
			attack_origin = actor.motor.global_position
			locked_direction = (attack_goal - attack_origin).normalized()
			_set_state(&"telegraph")
	elif state == &"telegraph" and state_time >= actor.definition.telegraph_duration:
		for index: int in range(_projectiles.size()-1,-1,-1):
			if not is_instance_valid(_projectiles[index]) or _projectiles[index].spent: _projectiles.remove_at(index)
		_serial += 1
		var seed := ForestSeedProjectile.new()
		seed.configure(self, StringName("%s:forest_seed:%s" % [source_id, _serial]), locked_direction)
		seed.goal = attack_goal
		seed.origin = actor.motor.global_position
		seed.flight_seconds = maxf(actor.definition.attack_duration, seed.origin.distance_to(seed.goal) / actor.definition.projectile_speed)
		seed.arc_height = actor.definition.forest_arc_height
		seed.zone_seconds = actor.definition.forest_zone_seconds
		actor.motor.get_parent().add_child(seed)
		seed.global_position = seed.origin
		_projectiles.append(seed)
		GameAudio.cue(self, &"enemy_shot")
		_set_state(&"attack")
	elif state == &"attack" and state_time >= actor.definition.attack_duration:
		_begin_recovery()
	elif state == &"recovery" and state_time >= actor.definition.recovery_duration:
		_set_state(&"idle")
	return true
func zone_bounds() -> Rect2:
	return Rect2(attack_goal - Vector2(actor.definition.pulse_size.x * 0.5, actor.definition.pulse_size.y), actor.definition.pulse_size)
