class_name ForestLanternBehavior
extends EnemyAttackBehavior
## Safe, bounded live anchor: dwell -> visible turn -> traverse -> dwell.
var destination := Vector2.ZERO
var travel_side := 1
func configure(owner_actor: EnemyActor, target: PlayerController, damage_policy: FrameDamagePolicy, scope: DemoLifetime, id: StringName, safe_points: Array[Vector2]) -> void:
	super.configure(owner_actor, target, damage_policy, scope, id, safe_points)
	destination = home
	_set_state(&"dwell")
func advance(delta: float) -> bool:
	if not _active():
		cancel()
		return true
	if _actor_epoch != lifetime.actor_epoch:
		_actor_epoch = lifetime.actor_epoch
		cancel()
	state_time += delta
	if state in [&"recovery", &"dwell"] and state_time >= actor.definition.forest_dwell_seconds:
		travel_side *= -1
		destination = home + Vector2(travel_side * actor.definition.patrol_half_width, 0)
		actor.brain.direction = travel_side
		_set_state(&"telegraph")
	elif state == &"telegraph" and state_time >= actor.definition.telegraph_duration:
		_set_state(&"travel")
	elif state == &"travel":
		var offset := destination - actor.motor.global_position
		var motion := offset.limit_length(actor.definition.patrol_speed * delta)
		if offset.length() <= 1 or not actor.motor.move_attack(motion, false, delta):
			_set_state(&"dwell")
	return true
