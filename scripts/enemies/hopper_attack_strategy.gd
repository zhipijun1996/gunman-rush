class_name HopperAttackStrategy
extends EnemyAttackStrategy

func attack_goal(context: EnemyAttackBehavior) -> Vector2:
	var definition := context.actor.definition
	return Vector2(clampf(context.controller.motor.global_position.x,context.home.x-definition.patrol_half_width,context.home.x+definition.patrol_half_width),context.home.y)

func attack_step(context: EnemyAttackBehavior, delta: float) -> void:
	var t := clampf(context.state_time/context.actor.definition.attack_duration,0,1)
	var target := context.attack_origin.lerp(context.attack_goal,t)+Vector2(0,-sin(PI*t)*90)
	context.actor.motor.move_attack(target-context.actor.motor.global_position,false,delta)

func requires_home_return() -> bool:
	return true
