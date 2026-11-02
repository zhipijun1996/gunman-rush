class_name ForestSwingPodBehavior
extends EnemyAttackBehavior
## A rooted suspension point owns a broad, predictable curved live-anchor orbit.
## Terrain owns obstruction: this actor never snaps through a trunk or teleports.
var swing_clock := 0.0
var blocked := false
var ledger: Array[Dictionary] = []

func advance(delta: float) -> bool:
	if not _active():return true
	if _actor_epoch!=lifetime.actor_epoch:
		_actor_epoch=lifetime.actor_epoch
		# No projectile/target commitment to cancel: retain pendulum phase.
	if blocked:
		actor.motor.stop()
		return true
	var d:=actor.definition as ForestEnemyDefinition
	swing_clock=fposmod(swing_clock+delta,d.swing_period_seconds)
	var phase:=TAU*swing_clock/d.swing_period_seconds
	var amount:=sin(phase)
	var target:=home+Vector2(d.patrol_half_width*amount,-d.swing_rise*amount*amount)
	var motion:=target-actor.motor.global_position
	if not actor.motor.move_attack(motion,false,delta):
		blocked=true
		_set_state(&"blocked")
		ledger.append({"event":"physical_obstruction","clock":swing_clock,"position":[actor.motor.global_position.x,actor.motor.global_position.y]})
		return true
	var next: StringName=&"turn" if absf(amount)>.88 else &"swing"
	if next!=state:_set_state(next)
	state_time+=delta
	if absf(motion.x)>.001:actor.brain.direction=1 if motion.x>0 else -1
	return true

func cancel() -> void:
	# Pause/unload must retain the safe phase, not reset a moving anchor to home.
	if is_instance_valid(actor) and actor.health.terminal:actor.motor.stop()

func depth_snapshot() -> Dictionary:
	return {"version":1,"clock":swing_clock,"blocked":blocked}

func restore_depth_state(saved: Dictionary) -> bool:
	if not saved.get("version") is int or saved.version!=1 or not saved.get("blocked") is bool:return false
	var value: Variant=saved.get("clock")
	if not (value is int or value is float) or not is_finite(float(value)):return false
	var d:=actor.definition as ForestEnemyDefinition
	if float(value)<0 or float(value)>=d.swing_period_seconds:return false
	if state not in [&"idle",&"swing",&"turn",&"blocked"] or (state==&"blocked")!=saved.blocked:return false
	if not is_finite(state_time) or state_time<0:return false
	swing_clock=float(value);blocked=saved.blocked
	return true
