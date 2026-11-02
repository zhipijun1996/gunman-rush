class_name PrototypeMothBehavior
extends EnemyAttackBehavior
## Two committed, temporally separated lanes. Aim never tracks after warning.
var second_volley:=false
var orbit_time:=0.0
func advance(delta:float)->bool:
	var handled:=super.advance(delta)
	if not _active():return handled
	if state==&"idle":
		second_volley=false
		orbit_time+=delta
		var goal:=home+Vector2(sin(orbit_time)*35,cos(orbit_time)*12)
		actor.motor.move_attack((goal-actor.motor.global_position).limit_length(actor.definition.patrol_speed*delta),false,delta)
	elif state==&"attack" and state_time>=.5 and not second_volley:
		second_volley=true
		_fire()
	return handled
func _fire()->void:
	var locked:=locked_direction
	locked_direction=locked.rotated(-.35 if second_volley else .35)
	super._fire()
	locked_direction=locked
