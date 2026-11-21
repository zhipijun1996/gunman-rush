class_name SentryAttackStrategy
extends EnemyAttackStrategy

func idle_step(_context: EnemyAttackBehavior, _delta: float) -> bool:
	return true

func entered_attack(context: EnemyAttackBehavior) -> void:
	context._fire()
