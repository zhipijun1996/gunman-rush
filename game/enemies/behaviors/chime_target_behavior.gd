class_name ChimeTargetBehavior
extends EnemyAttackBehavior
## Re-forming practice creature. Same real hit/health pipeline, no combat attack.
var reform_age := 0.0
func advance(delta: float) -> bool:
	if not _active(): return true
	state_time += delta
	var phase := state_time * 1.3
	var desired := home + Vector2(sin(phase)*actor.definition.patrol_half_width,sin(phase*.73)*4)
	actor.motor.move_attack(desired-actor.motor.global_position,false,delta)
	return true
func _physics_process(delta: float) -> void:
	if not is_instance_valid(actor) or not actor.health.terminal: return
	reform_age += delta
	if reform_age >= actor.definition.recovery_duration:
		reform_age = 0.0
		actor.reset(&"practice_reform")
		state_time = 0.0
