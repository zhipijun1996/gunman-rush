class_name EnemyAttackStrategy
extends RefCounted
## Mechanics-only hooks for the existing common attack state machine. No clocks,
## signals, RNG, policy submission or ownership are duplicated in these leaves.
func attack_goal(context: EnemyAttackBehavior) -> Vector2:
	var definition := context.actor.definition
	return Vector2(clampf(context.controller.motor.global_position.x,context.home.x-definition.patrol_half_width,context.home.x+definition.patrol_half_width),context.home.y+definition.dive_depth)

func idle_step(_context: EnemyAttackBehavior, _delta: float) -> bool:
	return false

func entered_attack(_context: EnemyAttackBehavior) -> void:
	pass

func attack_step(_context: EnemyAttackBehavior, _delta: float) -> void:
	pass

func requires_home_return() -> bool:
	return false

func recovery_step(context: EnemyAttackBehavior, delta: float) -> void:
	if requires_home_return():
		context.actor.motor.move_attack((context.home-context.actor.motor.global_position).limit_length(context.actor.definition.return_speed*delta),false,delta)

func projectile_angles() -> Array:
	return [0.0]
