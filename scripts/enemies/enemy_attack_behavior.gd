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
var attack_origin := Vector2.ZERO
var attack_goal := Vector2.ZERO
var _actor_epoch := -1
var _serial := 0
var _projectiles: Array[EnemyAttackProjectile] = []
var _strategy: EnemyAttackStrategy
var _strategy_behavior: StringName = &""

func configure(owner_actor: EnemyActor, target: PlayerController, damage_policy: FrameDamagePolicy, scope: DemoLifetime, id: StringName, safe_points: Array[Vector2]) -> void:
	actor = owner_actor
	controller = target
	policy = damage_policy
	lifetime = scope
	source_id = id
	protected_points = safe_points.duplicate()
	home = actor.motor.global_position
	_actor_epoch = lifetime.actor_epoch
	_attack_strategy()

func advance(delta: float) -> bool:
	if not _active():
		cancel()
		return true
	var strategy := _attack_strategy()
	if strategy == null:
		push_error("Unregistered enemy attack strategy")
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
			attack_goal = strategy.attack_goal(self)
			_set_state(&"telegraph")
			return true
		return strategy.idle_step(self,delta)
	if state == &"telegraph":
		if not _can_engage():
			_begin_recovery()
		elif state_time >= definition.telegraph_duration:
			_set_state(&"attack")
			attack_origin=actor.motor.global_position
			strategy.entered_attack(self)
		return true
	if state == &"attack":
		strategy.attack_step(self,delta)
		if state_time >= definition.attack_duration: _begin_recovery()
		return true
	if state == &"recovery":
		strategy.recovery_step(self,delta)
		if state_time > definition.recovery_duration + 2.0 and strategy.requires_home_return() and actor.motor.global_position.distance_to(home) >= 1:
			# Malformed/changed terrain fails bounded: remain stationary instead of
			# retrying an unreachable home or teleporting through collision.
			_set_state(&"blocked")
		elif state_time >= definition.recovery_duration and (not strategy.requires_home_return() or actor.motor.global_position.distance_to(home) < 1):
			_set_state(&"idle")
		return true
	return true

# Old real fixtures may call _fire() after assigning Actor fields directly.
# Resolve from the current definition on demand; unknown IDs never fall back.
func _attack_strategy() -> EnemyAttackStrategy:
	if not is_instance_valid(actor) or actor.definition == null: return null
	var identity: StringName = actor.definition.behavior_id
	if _strategy == null or _strategy_behavior != identity:
		_strategy = EnemyBehaviorRegistry.create_attack_strategy(identity)
		_strategy_behavior = identity
	return _strategy

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
	var strategy := _attack_strategy()
	if strategy == null:
		push_error("Unregistered enemy projectile strategy")
		return
	GameAudio.cue(self, &"enemy_shot")
	for i: int in range(_projectiles.size()-1,-1,-1):
		if not is_instance_valid(_projectiles[i]) or _projectiles[i].spent: _projectiles.remove_at(i)
	var angles: Array = strategy.projectile_angles()
	var origin := actor.motor.global_position
	var pivot := actor.definition.projectile_muzzle_pivot
	var muzzle := origin+Vector2(pivot.x*actor.brain.direction,pivot.y)+locked_direction.normalized()*actor.definition.projectile_muzzle_reach
	for angle: float in angles:
		_serial += 1
		var shot := EnemyAttackProjectile.new()
		shot.configure(self, StringName("%s:seed:%s" % [source_id, _serial]), locked_direction.rotated(angle))
		actor.motor.get_parent().add_child(shot)
		shot.global_position = origin
		# Clearance from the body to the configured mouth uses the real seed
		# volume. A wall or close player cannot be skipped by spawning beyond it.
		if not muzzle.is_equal_approx(origin): shot.launch_to_muzzle(muzzle)
		_projectiles.append(shot)

func _begin_recovery() -> void:
	cooldown = actor.definition.recovery_duration
	_set_state(&"recovery")

func _set_state(next: StringName) -> void:
	if state == next: return
	state = next
	state_time = 0
	state_changed.emit(state)
	if next == &"telegraph": GameAudio.cue(self, &"warning")

func cancel() -> void:
	if is_instance_valid(actor): cooldown = maxf(cooldown, actor.definition.recovery_duration)
	for i: int in _projectiles.size():
		if is_instance_valid(_projectiles[i]): _projectiles[i].dispose()
	_projectiles.clear()
	_set_state(&"recovery")

func _exit_tree() -> void:
	cancel()
