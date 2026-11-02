class_name ForestBarkBeetleBehavior
extends EnemyAttackBehavior
## Root-floor patrol with a readable, committed facing. No instant target-facing.
var ledger: Array[Dictionary] = []

func advance(delta: float) -> bool:
	if not _active():
		cancel()
		return true
	if _actor_epoch != lifetime.actor_epoch:
		_actor_epoch=lifetime.actor_epoch
		cancel()
	state_time+=delta
	cooldown=maxf(0,cooldown-delta)
	var d:=actor.definition as ForestEnemyDefinition
	if state==&"idle":
		var offset:=controller.motor.global_position-actor.motor.global_position
		if cooldown<=0 and offset.x*actor.brain.direction>0 and absf(offset.y)<60 and _can_engage():
			locked_direction=Vector2(actor.brain.direction,0)
			attack_origin=actor.motor.global_position
			attack_goal=Vector2(clampf(attack_origin.x+locked_direction.x*d.attack_speed*d.attack_duration,home.x-d.patrol_half_width,home.x+d.patrol_half_width),home.y)
			_serial+=1
			_set_state(&"telegraph")
			ledger.append({"event":"commit","serial":_serial,"direction":actor.brain.direction,"goal":[attack_goal.x,attack_goal.y]})
		else:
			var limit:=home.x+d.patrol_half_width*actor.brain.direction
			var motion:=Vector2(actor.brain.direction*minf(d.patrol_speed*delta,absf(limit-actor.motor.global_position.x)),0)
			if absf(limit-actor.motor.global_position.x)<0.5 or not _move_ground(motion,delta):actor.brain.direction*=-1
	elif state==&"telegraph":
		if not _can_engage():_begin_recovery()
		elif state_time>=d.telegraph_duration:_set_state(&"attack")
	elif state==&"attack":
		# Facing/goal remain the preannounced direction even if player crosses over.
		var motion:=(attack_goal-actor.motor.global_position).limit_length(d.attack_speed*delta)
		if state_time>=d.attack_duration or not _move_ground(motion,delta):_begin_recovery()
	elif state==&"recovery":
		actor.motor.stop()
		if state_time>=d.recovery_duration:
			cooldown=d.bark_rest_seconds
			_set_state(&"idle")
	return true

func _move_ground(motion: Vector2,delta: float) -> bool:
	# EnemyMotor's legacy floor probe assumes an 18 px half-height; this
	# short root dweller probes its actual authored feet before Motor collision.
	var half:=actor.definition.collision_size*.5
	var edge:=actor.motor.global_position+Vector2(signf(motion.x)*half.x,half.y)+motion
	var query:=PhysicsRayQueryParameters2D.create(edge+Vector2(0,-2),edge+Vector2(0,8),1,[actor.motor.get_rid()])
	if actor.motor.get_world_2d().direct_space_state.intersect_ray(query).is_empty():
		actor.motor.stop()
		return false
	return actor.motor.move_attack(motion,false,delta)

func depth_snapshot() -> Dictionary:
	return {"version":1,"locked_direction":[locked_direction.x,locked_direction.y],"attack_origin":[attack_origin.x,attack_origin.y],"attack_goal":[attack_goal.x,attack_goal.y]}

func restore_depth_state(saved: Dictionary) -> bool:
	if not saved.get("version") is int or saved.version!=1:return false
	var vectors: Array[Vector2]=[]
	for key: String in ["locked_direction","attack_origin","attack_goal"]:
		var row: Variant=saved.get(key)
		if not row is Array or row.size()!=2:return false
		for value: Variant in row:
			if not (value is int or value is float) or not is_finite(float(value)):return false
		vectors.append(Vector2(row[0],row[1]))
	if vectors[0].y!=0 or absf(vectors[0].x)!=1:return false
	if state not in [&"idle",&"telegraph",&"attack",&"recovery"]:return false
	if not is_finite(state_time) or state_time<0 or not is_finite(cooldown) or cooldown<0:return false
	if actor.brain.direction not in [-1,1]:return false
	locked_direction=vectors[0];attack_origin=vectors[1];attack_goal=vectors[2]
	return true
