class_name ChargerAttackStrategy
extends EnemyAttackStrategy

func attack_step(context: EnemyAttackBehavior, delta: float) -> void:
	var definition := context.actor.definition
	var destination := Vector2(context.home.x+float(context.actor.brain.direction)*definition.patrol_half_width,context.home.y)
	context.actor.motor.move_attack((destination-context.actor.motor.global_position).limit_length(definition.attack_speed*delta),true,delta)
