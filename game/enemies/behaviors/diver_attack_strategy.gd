class_name DiverAttackStrategy
extends EnemyAttackStrategy

func idle_step(context: EnemyAttackBehavior, delta: float) -> bool:
	var definition := context.actor.definition
	var orbit := context.home+Vector2(sin(context.state_time*1.8)*definition.patrol_half_width,cos(context.state_time*1.8)*8.0)
	var motion := (orbit-context.actor.motor.global_position).limit_length(definition.patrol_speed*delta)
	if absf(motion.x)>0.01: context.actor.brain.direction = 1 if motion.x>0 else -1
	context.actor.motor.move_attack(motion,false,delta)
	return true

func attack_step(context: EnemyAttackBehavior, delta: float) -> void:
	context.actor.motor.move_attack((context.attack_goal-context.actor.motor.global_position).limit_length(context.actor.definition.attack_speed*delta),false,delta)

func requires_home_return() -> bool:
	return true
