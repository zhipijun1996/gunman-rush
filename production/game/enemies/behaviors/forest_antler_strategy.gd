extends EnemyAttackStrategy
## Both patterns commit their destination before the player's dodge. A raised
## target marks the late-phase pounce in the normal persisted attack goal.
func attack_goal(context: EnemyAttackBehavior) -> Vector2:
	var center := context.home
	if context.actor.health.current > context.actor.health.capacity * .5:
		return center
	var target_x := clampf(context.controller.motor.position.x, center.x - 335, center.x + 325)
	return Vector2(target_x, center.y - 1)

func entered_attack(context: EnemyAttackBehavior) -> void:
	if context.attack_goal.y == context.home.y:
		context.locked_direction = Vector2(context.actor.brain.direction, 0)
		context._fire()

func attack_step(context: EnemyAttackBehavior, delta: float) -> void:
	if context.attack_goal.y == context.home.y: return
	var t := clampf(context.state_time / context.actor.definition.attack_duration, 0, 1)
	var end := Vector2(context.attack_goal.x, context.home.y)
	var arc := context.attack_origin.lerp(end,t) + Vector2.UP * sin(PI*t) * 119
	context.actor.motor.move_attack(arc-context.actor.motor.position,false,delta)
	if t >= 1:
		context.locked_direction = Vector2(-context.actor.brain.direction,0)
		context._fire()
