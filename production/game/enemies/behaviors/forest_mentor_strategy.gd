extends EnemyAttackStrategy
## The low-health instructor crosses sides along a fixed arc before releasing
## the next star. Its aim and the student's escape line stay committed.
func attack_goal(context: EnemyAttackBehavior) -> Vector2:
	if context.actor.health.current > context.actor.health.capacity*.5:
		return Vector2(context.actor.motor.position.x,context.home.y)
	var sign_x := -1 if context.actor.motor.position.x >= context.home.x else 1
	return Vector2(context.home.x + sign_x*252,context.home.y-1)

func entered_attack(context: EnemyAttackBehavior) -> void:
	if context.attack_goal.y == context.home.y: context._fire()

func attack_step(context: EnemyAttackBehavior, delta: float) -> void:
	if context.attack_goal.y == context.home.y: return
	var t := clampf(context.state_time / context.actor.definition.attack_duration,0,1)
	var landing := Vector2(context.attack_goal.x,context.home.y)
	var movement := clampf(t/.78,0,1)
	var target := context.attack_origin.lerp(landing,movement) + Vector2.UP*sin(PI*movement)*82
	context.actor.motor.move_attack(target-context.actor.motor.position,false,delta)
	if t >= 1:
		context.locked_direction = Vector2(-signf(landing.x-context.attack_origin.x),0)
		context.actor.brain.direction = int(context.locked_direction.x)
		context._fire()
