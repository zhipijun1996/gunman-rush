extends "review029_ambush_v1-68f00446aac9.gd"
## Native 28x32 sentry feet are y438. The original attack floor probe uses
## an 18px half-height, so apply bounded horizontal motion through its
## native collision method on this continuous already-verified floor.
func _physics_process(delta: float) -> void:
	for actor: EnemyActor in actors:
		if actor.health.terminal or actor._damage_stun_remaining>0 or actor._stagger_remaining>0:continue
		var offset: float=host.to_global(Vector2(float(data.review029_wave.targetX),0)).x-actor.motor.global_position.x
		if absf(offset)>1:actor.motor.move_attack(Vector2(signf(offset)*minf(absf(offset),float(data.review029_wave.speed)*delta),0),false,delta)
