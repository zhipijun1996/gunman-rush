class_name GroundFanSentryAttackStrategy
extends FanSentryAttackStrategy
## The same three projectiles/commit policy; ordinary patrol owns ground steps.
func idle_step(_context: EnemyAttackBehavior, _delta: float) -> bool:
	return false

func attack_goal(context: EnemyAttackBehavior) -> Vector2:
	context.actor.motor.velocity = Vector2.ZERO
	return super.attack_goal(context)

func recovery_step(context: EnemyAttackBehavior, delta: float) -> void:
	# Finish the authored recovery before locomotion resumes in idle.
	context.actor.motor.step(EnemyIntent.new(), delta)
	# Reserve a visible walking interval instead of attacking every idle frame.
	context.cooldown = context.actor.definition.recovery_duration
