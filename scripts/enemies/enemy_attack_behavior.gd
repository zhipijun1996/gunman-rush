class_name EnemyAttackBehavior
extends Node
## Local telegraph/commit/recover controller. Never reads input or writes player motion.
signal state_changed(state: StringName)
var actor: EnemyActor
var controller: PlayerController
var policy: FrameDamagePolicy
var lifetime: DemoLifetime
var source_id: StringName
var protected_points: Array[Vector2] = []
var state: StringName = &"idle"
var state_time := 0.0
var cooldown := 0.6
var max_concurrent_attacks := 2
var home := Vector2.ZERO
var locked_direction := Vector2.RIGHT
var attack_goal := Vector2.ZERO
var _actor_epoch := -1
var _serial := 0
var _projectiles: Array[EnemyAttackProjectile] = []

func configure(owner_actor: EnemyActor, target: PlayerController, damage_policy: FrameDamagePolicy, scope: DemoLifetime, id: StringName, safe_points: Array[Vector2]) -> void:
	actor = owner_actor
	controller = target
	policy = damage_policy
	lifetime = scope
	source_id = id
	protected_points = safe_points.duplicate()
	home = actor.motor.global_position
	_actor_epoch = lifetime.actor_epoch

func advance(delta: float) -> bool:
	if not _active():
		cancel()
		return true
	if _actor_epoch != lifetime.actor_epoch:
		# Cancel an obsolete target/shot, retain health, position and recovery debt.
		_actor_epoch = lifetime.actor_epoch
		cancel()
		cooldown = maxf(cooldown, actor.definition.recovery_duration)
	cooldown = maxf(0, cooldown - delta)
	state_time += delta
	var definition := actor.definition
	if state == &"idle":
		if cooldown <= 0 and _can_engage():
			var offset := controller.motor.global_position - actor.motor.global_position
			locked_direction = offset.normalized() if offset.length_squared() > 0.01 else Vector2.RIGHT
			actor.brain.direction = 1 if locked_direction.x >= 0 else -1
			attack_goal = Vector2(clampf(controller.motor.global_position.x, home.x - definition.patrol_half_width, home.x + definition.patrol_half_width), home.y + definition.dive_depth)
			_set_state(&"telegraph")
			return true
		if definition.behavior_id == &"diver":
			var orbit := home + Vector2(sin(state_time * 1.8) * definition.patrol_half_width, cos(state_time * 1.8) * 8.0)
			var motion := (orbit - actor.motor.global_position).limit_length(definition.patrol_speed * delta)
			if absf(motion.x) > 0.01: actor.brain.direction = 1 if motion.x > 0 else -1
			actor.motor.move_attack(motion, false, delta)
			return true
		return definition.behavior_id == &"sentry"
	if state == &"telegraph":
		if not _can_engage():
			_begin_recovery()
		elif state_time >= definition.telegraph_duration:
			_set_state(&"attack")
			if definition.behavior_id == &"sentry": _fire()
		return true
	if state == &"attack":
		if definition.behavior_id == &"charger":
			var destination := Vector2(home.x + float(actor.brain.direction) * definition.patrol_half_width, home.y)
			actor.motor.move_attack((destination - actor.motor.global_position).limit_length(definition.attack_speed * delta), true, delta)
		elif definition.behavior_id == &"diver":
			actor.motor.move_attack((attack_goal - actor.motor.global_position).limit_length(definition.attack_speed * delta), false, delta)
		if state_time >= definition.attack_duration: _begin_recovery()
		return true
	if state == &"recovery":
		if definition.behavior_id == &"diver":
			actor.motor.move_attack((home - actor.motor.global_position).limit_length(definition.return_speed * delta), false, delta)
		if state_time > definition.recovery_duration + 2.0 and definition.behavior_id == &"diver" and actor.motor.global_position.distance_to(home) >= 1:
			# Malformed/changed terrain fails bounded: remain stationary instead of
			# retrying an unreachable home or teleporting through collision.
			_set_state(&"blocked")
		elif state_time >= definition.recovery_duration and (definition.behavior_id != &"diver" or actor.motor.global_position.distance_to(home) < 1):
			_set_state(&"idle")
		return true
	return true

func _active() -> bool:
	return is_instance_valid(actor) and not actor.health.terminal and is_instance_valid(controller) and controller.active and not controller.actor_resources.health.terminal and lifetime != null and lifetime.active

func _can_engage() -> bool:
	if state == &"idle":
		var concurrent := 0
		for sibling: Node in actor.motor.get_parent().get_children():
			if sibling is EnemyMotor and sibling != actor.motor:
				var peer := sibling.get_node_or_null("Actor") as EnemyActor
				if peer and peer.attack_behavior and peer.attack_behavior.state in [&"telegraph", &"attack"] and peer.attack_behavior._active(): concurrent += 1
		if concurrent >= max_concurrent_attacks: return false
	var target := controller.motor.global_position
	if target.distance_to(home) > actor.definition.activation_range: return false
	for point: Vector2 in protected_points:
		if target.distance_to(point) < actor.definition.protected_radius: return false
	var ray := PhysicsRayQueryParameters2D.create(actor.motor.global_position, target, 1, [actor.motor.get_rid()])
	var hit := actor.motor.get_world_2d().direct_space_state.intersect_ray(ray)
	return hit.is_empty() or hit.get("collider") == controller.motor

func _fire() -> void:
	if not _active(): return
	_projectiles = _projectiles.filter(func(shot: EnemyAttackProjectile): return is_instance_valid(shot) and not shot.spent)
	_serial += 1
	var shot := EnemyAttackProjectile.new()
	shot.configure(self, StringName("%s:seed:%s" % [source_id, _serial]), locked_direction)
	actor.motor.get_parent().add_child(shot)
	shot.global_position = actor.motor.global_position
	_projectiles.append(shot)

func _begin_recovery() -> void:
	cooldown = actor.definition.recovery_duration
	_set_state(&"recovery")

func _set_state(next: StringName) -> void:
	if state == next: return
	state = next
	state_time = 0
	state_changed.emit(state)

func cancel() -> void:
	if is_instance_valid(actor): cooldown = maxf(cooldown, actor.definition.recovery_duration)
	for projectile: EnemyAttackProjectile in _projectiles:
		if is_instance_valid(projectile): projectile.dispose()
	_projectiles.clear()
	_set_state(&"recovery")

func _exit_tree() -> void:
	cancel()
