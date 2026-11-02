class_name ForestThreadSpiderBehavior
extends EnemyAttackBehavior
## Authored finite line only; never tracks/blocks a hook or touches Player physics.
var line_start := Vector2.ZERO
var line_end := Vector2.ZERO
var line_configured := false
var line_active := false
var _hit_this_cycle := false
var _previous_player := Vector2.ZERO
var _token: DemoToken

func configure_line(start: Vector2, finish: Vector2) -> bool:
	line_configured = false
	line_active = false
	if not is_instance_valid(actor): return false
	var d := actor.definition as ForestEnemyDefinition
	if not start.is_finite() or not finish.is_finite() or start.distance_to(finish) < 8 or start.distance_to(finish)>d.line_max_length: return false
	line_start=start
	line_end=finish
	line_configured=true
	return true

func advance(delta: float) -> bool:
	if not _active():
		cancel()
		return true
	if _actor_epoch != lifetime.actor_epoch:
		_actor_epoch=lifetime.actor_epoch
		cancel()
		return true
	var d := actor.definition as ForestEnemyDefinition
	state_time+=delta
	cooldown=maxf(0,cooldown-delta)
	match state:
		&"idle":
			if line_configured and cooldown <= 0 and _can_engage() and _clear_line() and _safe_line():
				_serial+=1
				_token=lifetime.token()
				_hit_this_cycle=false
				_set_state(&"telegraph")
		&"telegraph":
			if not _clear_line() or not _safe_line(): cancel()
			elif state_time >= d.telegraph_duration: _set_state(&"extend")
		&"extend":
			if state_time >= d.line_extend_seconds:
				_previous_player=controller.motor.global_position
				line_active=true
				_set_state(&"hold")
		&"hold":
			if not _clear_line() or not _safe_line(): cancel()
			elif state_time >= d.line_hold_seconds:
				line_active=false
				_set_state(&"retract")
			else: _damage_line()
		&"retract":
			if state_time >= d.line_retract_seconds: _set_state(&"recovery")
		&"recovery":
			if state_time >= d.recovery_duration:
				cooldown=d.rest_cooldown
				_set_state(&"idle")
	return true

func _clear_line() -> bool:
	var ray:=PhysicsRayQueryParameters2D.create(line_start,line_end,1,[actor.motor.get_rid(),controller.motor.get_rid()])
	return actor.motor.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func _safe_line() -> bool:
	var radius := (actor.definition as ForestEnemyDefinition).line_radius + actor.definition.protected_radius
	for point: Vector2 in protected_points:
		if Geometry2D.get_closest_point_to_segment(point,line_start,line_end).distance_to(point) < radius: return false
	return true

func _damage_line() -> void:
	var current := controller.motor.global_position
	if not _hit_this_cycle and lifetime.accepts(_token):
		var d := actor.definition as ForestEnemyDefinition
		# Swept center vs oriented expanded player rectangle. Projecting both axes
		# gives a conservative Minkowski capsule, including fast grapple crossing.
		var direction := (line_end-line_start).normalized()
		var normal := Vector2(-direction.y,direction.x)
		var half := (controller.motor.get_node("CollisionShape2D") as CollisionShape2D).shape.get_rect().size*0.5
		var along := absf(direction.x)*half.x+absf(direction.y)*half.y+d.line_radius
		var across := absf(normal.x)*half.x+absf(normal.y)*half.y+d.line_radius
		var from := _previous_player-line_start
		var to := current-line_start
		var bounds := Rect2(Vector2(-along,-across),Vector2(line_start.distance_to(line_end)+along*2,across*2))
		if DemoContactEmitter.segment_intersects_bounds(Vector2(from.dot(direction),from.dot(normal)),Vector2(to.dot(direction),to.dot(normal)),bounds):
			var request := DamageRequest.new()
			request.token=_token
			request.event_id=StringName("%s:thread:%s" % [source_id,_serial])
			request.source_id=source_id
			request.target_id=&"player"
			request.amount=d.line_damage
			request.actor_epoch=_token.actor_epoch
			request.health_epoch=controller.actor_resources.health.epoch
			policy.submit(request)
			_hit_this_cycle=true
	_previous_player=current

func cancel() -> void:
	line_active=false
	_token=null
	super.cancel()

func depth_snapshot() -> Dictionary:
	return {"version":1,"configured":line_configured,"start":[line_start.x,line_start.y],"end":[line_end.x,line_end.y],"hit_this_cycle":_hit_this_cycle}

func restore_depth_state(saved: Dictionary) -> bool:
	if saved.get("version") != 1: return false
	var start: Array=saved.get("start",[])
	var finish: Array=saved.get("end",[])
	if start.size()!=2 or finish.size()!=2: return false
	if bool(saved.get("configured",false)):
		if not configure_line(Vector2(start[0],start[1]),Vector2(finish[0],finish[1])): return false
	else:
		line_configured=false
	_hit_this_cycle=bool(saved.get("hit_this_cycle",false))
	line_active=line_configured and state==&"hold"
	_previous_player=controller.motor.global_position
	_token=lifetime.token()
	return true
