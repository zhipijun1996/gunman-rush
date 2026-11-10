class_name DiverAttackStrategy
extends EnemyAttackStrategy

func idle_step(context: EnemyAttackBehavior, delta: float) -> bool:
	var definition := context.actor.definition
	var orbit := context.home+Vector2(sin(context.state_time*1.8)*definition.patrol_half_width,sin(context.state_time*.91+.6)*definition.patrol_half_width*.65)
	var motion := (orbit-context.actor.motor.global_position).limit_length(definition.patrol_speed*delta)
	if absf(motion.x)>0.01: context.actor.brain.direction = 1 if motion.x>0 else -1
	context.actor.motor.move_attack(motion,false,delta)
	return true

func attack_goal(context: EnemyAttackBehavior) -> Vector2:
	# Lock the actual player position when the warning begins, not a fixed
	# depth beneath the nest. The committed line remains dodgeable.
	return context.controller.motor.global_position

func attack_step(context: EnemyAttackBehavior, delta: float) -> void:
	var definition := context.actor.definition
	var speed := maxf(definition.attack_speed,context.attack_origin.distance_to(context.attack_goal)/definition.attack_duration)
	var motion := (context.attack_goal-context.actor.motor.global_position).limit_length(speed*delta)
	if not context.actor.motor.move_attack(motion,false,delta):
		context._begin_recovery()

func requires_home_return() -> bool:
	return true
