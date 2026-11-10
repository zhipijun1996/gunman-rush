class_name ChargerAttackStrategy
extends EnemyAttackStrategy

func attack_step(context: EnemyAttackBehavior, delta: float) -> void:
	var definition := context.actor.definition
	# Commit along the telegraphed direction. Patrol extent must not stop a
	# charging creature short of its target; real wall/ledge probes still do.
	var motion := Vector2(float(context.actor.brain.direction)*definition.attack_speed*delta,0)
	if not context.actor.motor.move_attack(motion,true,delta):context._begin_recovery()
