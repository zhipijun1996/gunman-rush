class_name RootBellBehavior
extends EnemyAttackBehavior
## A fixed ground mark and one short pulse. Health results, never art or shot
## requests, can interrupt the warning. All persistent fields are inherited.
signal pulse_committed(event_id: StringName, position: Vector2)
signal warning_interrupted
var _first_advance := true

func configure(owner_actor: EnemyActor, target: PlayerController, damage_policy: FrameDamagePolicy, scope: DemoLifetime, id: StringName, safe_points: Array[Vector2]) -> void:
	super.configure(owner_actor, target, damage_policy, scope, id, safe_points)
	actor.health.changed.connect(_on_health_changed)

func advance(delta: float) -> bool:
	if not is_finite(delta) or delta <= 0: return true
	if not _active():
		cancel()
		return true
	if _actor_epoch != lifetime.actor_epoch:
		_actor_epoch = lifetime.actor_epoch
		cancel()
	# DemoApp restores inherited phase fields after bind_encounter. An old
	# targeted warning/pulse belongs to the old actor epoch: retain serial and
	# recovery debt, never recreate its damage in the new target's lifetime.
	if _first_advance:
		_first_advance = false
		if state in [&"telegraph", &"attack"]: cancel()
	cooldown = maxf(0, cooldown - delta)
	state_time += delta
	if state == &"idle":
		if cooldown <= 0 and _can_engage() and controller.motor.is_on_floor():
			var mark := _ground_target()
			if not mark.is_empty():
				attack_goal = mark.position
				attack_origin = actor.motor.global_position
				locked_direction = (attack_goal - attack_origin).normalized()
				actor.brain.direction = 1 if locked_direction.x >= 0 else -1
				_set_state(&"telegraph")
	elif state == &"telegraph":
		if not _mark_allowed(): _begin_recovery()
		elif state_time >= actor.definition.telegraph_duration:
			_serial += 1
			_set_state(&"attack")
			GameAudio.cue(self, &"bell")
			pulse_committed.emit(_pulse_id(), attack_goal)
			_pulse()
	elif state == &"attack":
		if state_time >= actor.definition.attack_duration: _begin_recovery()
		else: _pulse()
	elif state == &"recovery" and state_time >= actor.definition.recovery_duration:
		_set_state(&"idle")
	return true

func _ground_target() -> Dictionary:
	var target := controller.motor.global_position
	if absf(target.y - home.y) > actor.definition.collision_size.y: return {}
	var ray := PhysicsRayQueryParameters2D.create(target, target + Vector2(0, 40), 1, [controller.motor.get_rid(), actor.motor.get_rid()])
	var hit := actor.motor.get_world_2d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or not hit.collider is StaticBody2D or hit.collider.is_in_group(&"one_way_platform"): return {}
	var point: Vector2 = hit.position
	for side: int in [-1, 1]:
		var edge := point + Vector2(float(side) * actor.definition.pulse_size.x * 1.5, 0)
		var support_ray := PhysicsRayQueryParameters2D.create(edge + Vector2(0, -4), edge + Vector2(0, 4), 1, [controller.motor.get_rid(), actor.motor.get_rid()])
		var support := actor.motor.get_world_2d().direct_space_state.intersect_ray(support_ray)
		if support.is_empty() or support.collider != hit.collider: return {}
	for safe: Vector2 in protected_points:
		if point.distance_to(safe) < actor.definition.protected_radius + actor.definition.pulse_size.x * .5: return {}
	return {"position": point}

func _mark_allowed() -> bool:
	for safe: Vector2 in protected_points:
		if attack_goal.distance_to(safe) < actor.definition.protected_radius + actor.definition.pulse_size.x * .5: return false
	return true

func pulse_bounds() -> Rect2:
	return Rect2(attack_goal - Vector2(actor.definition.pulse_size.x * .5, actor.definition.pulse_size.y), actor.definition.pulse_size)

func _pulse_id() -> StringName:
	return StringName("%s:root_pulse:%s" % [source_id, _serial])

func _pulse() -> void:
	if not _active() or not _mark_allowed(): return
	var shape := RectangleShape2D.new()
	shape.size = actor.definition.pulse_size
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0, pulse_bounds().get_center())
	query.collision_mask = 1
	query.exclude = [actor.motor.get_rid()]
	for hit: Dictionary in actor.motor.get_world_2d().direct_space_state.intersect_shape(query, 16):
		if hit.collider != controller.motor: continue
		var request := DamageRequest.new()
		request.token = lifetime.token()
		request.event_id = _pulse_id()
		request.source_id = source_id
		request.target_id = &"player"
		request.amount = 1
		request.actor_epoch = request.token.actor_epoch
		request.health_epoch = controller.actor_resources.health.epoch
		policy.submit(request)

func _on_health_changed(result: ActorResourceResult) -> void:
	if result == null or result.status != ActorResourceResult.Status.APPLIED or result.amount_applied >= 0: return
	if state != &"telegraph" or actor.health.terminal: return
	_begin_recovery()
	GameAudio.cue(self, &"armour")
	warning_interrupted.emit()
