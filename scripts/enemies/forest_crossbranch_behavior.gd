class_name ForestCrossbranchBehavior
extends EnemyAttackBehavior
## Candidate only until actual body/support and complete objective controls pass.
var shores: Array[Dictionary] = []
var current_shore := 0
var committed_shore := -1
var flight_velocity := Vector2.ZERO
var supported_frames := 0
var transit_serial := 0
var ledger: Array[Dictionary] = []
var obstruction: Dictionary = {}
var recovery_support: Dictionary = {}
var recovery_budget_failed := false
var obstruction_body: Node

func configure_shores(rows: Array[Dictionary], require_initial_position: bool = true) -> bool:
	if rows.size()!=2 or not is_instance_valid(actor):return false
	var checked: Array[Dictionary]=[]
	for row: Dictionary in rows:
		if not row.get("id") is String or not row.get("rect") is Rect2 or not row.get("position") is Vector2:return false
		var rect: Rect2=row.rect
		var at: Vector2=row.position
		var half:=actor.definition.collision_size*.5
		if String(row.id).is_empty() or not rect.position.is_finite() or not rect.size.is_finite() or rect.size.y<=0 or not at.is_finite() or rect.size.x<=half.x*2 or absf(at.y+half.y-rect.position.y)>.001 or at.x-half.x<rect.position.x or at.x+half.x>rect.end.x:return false
		checked.append(row.duplicate(true))
	if checked[0].id==checked[1].id:return false
	if require_initial_position and actor.motor.global_position.distance_to(checked[0].position)>1:return false
	shores=checked;current_shore=0;_set_state(&"rest")
	return true

func advance(delta: float) -> bool:
	if not _active():cancel();return true
	if _actor_epoch!=lifetime.actor_epoch:
		_actor_epoch=lifetime.actor_epoch;cancel();return true
	if shores.size()!=2:return true
	state_time+=delta
	var def:=actor.definition as ForestEnemyDefinition
	if state==&"rest" and state_time>=def.crossbranch_rest_seconds:
		committed_shore=1-current_shore
		transit_serial+=1
		recovery_support={}
		_set_state(&"telegraph")
		ledger.append({"event":"commit","serial":transit_serial,"from":current_shore,"to":committed_shore,"position":[actor.motor.global_position.x,actor.motor.global_position.y]})
	elif state==&"telegraph" and state_time>=def.telegraph_duration:
		var goal: Vector2=shores[committed_shore].position
		var start:=actor.motor.global_position
		var vy: float=def.crossbranch_rise_velocity if goal.y<start.y else def.crossbranch_fall_velocity
		var discriminant:=vy*vy+2*def.crossbranch_gravity*(goal.y-start.y)
		if discriminant<=0:_blocked("unreachable_height");return true
		var seconds:=(-vy+sqrt(discriminant))/def.crossbranch_gravity
		if seconds<=0:_blocked("invalid_flight_time");return true
		flight_velocity=Vector2((goal.x-start.x)/seconds,vy)
		_set_state(&"flight")
	elif state==&"flight":
		# Trapezoidal integration of acceleration; collisions own the endpoint.
		var motion:=flight_velocity*delta+Vector2(0,.5*def.crossbranch_gravity*delta*delta)
		flight_velocity.y+=def.crossbranch_gravity*delta
		var moved:=_actual_move(motion,delta)
		if not moved:
			if flight_velocity.y>0 and _on_shore(committed_shore):
				current_shore=committed_shore;flight_velocity=Vector2.ZERO;actor.motor.stop();supported_frames=0
				ledger.append({"event":"land","serial":transit_serial,"shore":current_shore,"position":[actor.motor.global_position.x,actor.motor.global_position.y]})
				_set_state(&"settle")
			else:_blocked("physical_obstruction")
		elif state_time>def.crossbranch_max_flight_seconds:_blocked("flight_budget")
	elif state==&"cancelled_fall":
		# A cancelled commitment cannot teleport or become a hovering anchor.
		var motion:=flight_velocity*delta+Vector2(0,.5*def.crossbranch_gravity*delta*delta)
		flight_velocity.y+=def.crossbranch_gravity*delta
		if not _actual_move(motion,delta):
			var landed := -1
			for i: int in shores.size():
				if _on_shore(i):landed=i
			if landed>=0:
				current_shore=landed;flight_velocity=Vector2.ZERO;actor.motor.stop();supported_frames=0;_set_state(&"settle")
			else:_blocked("cancelled_motion_obstruction")
		elif state_time>def.crossbranch_max_flight_seconds:_blocked("cancelled_fall_budget")
	elif state==&"recovery_fall":
		var motion:=Vector2(0,flight_velocity.y*delta+.5*def.crossbranch_gravity*delta*delta)
		flight_velocity.y+=def.crossbranch_gravity*delta
		_recovery_move(motion,delta,"gravity")
		recovery_support=_static_full_support()
		# A real narrow edge may physically hold one foot. Walk inward on that
		# actual static surface, then re-query all three feet; never snap to it.
		if recovery_support.is_empty() and not recovery_budget_failed and is_instance_valid(obstruction_body) and obstruction_body is StaticBody2D and obstruction.get("normal",[0,0])[1]<-.5:
			var surface: Variant=obstruction_body.get_meta("support_world_rect",null)
			if surface is Rect2:
				var rect: Rect2=surface
				var half:=actor.definition.collision_size*.5
				var lo:=rect.position.x+half.x+actor.motor.safe_margin
				var hi:=rect.end.x-half.x-actor.motor.safe_margin
				if lo<=hi and absf(actor.motor.global_position.y+half.y-rect.position.y)<1:
					var goal:=clampf(actor.motor.global_position.x,lo,hi)
					var step:=clampf(goal-actor.motor.global_position.x,-def.return_speed*delta,def.return_speed*delta)
					_recovery_move(Vector2(step,0),delta,"supported_inward_step")
					recovery_support=_static_full_support()
		if not recovery_support.is_empty():
			ledger.append({"event":"recovered_static_support","position":[actor.motor.global_position.x,actor.motor.global_position.y],"elapsed":state_time,"physics_frame":Engine.get_physics_frames(),"support":recovery_support.duplicate(true)})
			flight_velocity=Vector2.ZERO;actor.motor.stop();committed_shore=-1
			var authored_shore := -1
			for i: int in shores.size():
				if _on_shore(i):authored_shore=i
			if authored_shore>=0:
				current_shore=authored_shore;supported_frames=0;_set_state(&"settle")
			else:_set_state(&"grounded_recovery")
		elif state_time>def.crossbranch_max_flight_seconds and not recovery_budget_failed:
			recovery_budget_failed=true
			ledger.append({"event":"recovery_budget_failed","position":[actor.motor.global_position.x,actor.motor.global_position.y]})
	elif state==&"grounded_recovery":
		recovery_support=_static_full_support()
		if recovery_support.is_empty():_blocked("recovery_support_lost")
		else:actor.motor.stop()
	elif state==&"settle":
		if not _on_shore(current_shore):_blocked("support_lost");return true
		supported_frames+=1
		if state_time>=def.crossbranch_settle_seconds and supported_frames>=2:_set_state(&"rest")
	return true

func _on_shore(index: int) -> bool:
	if index<0 or index>=shores.size():return false
	var rect: Rect2=shores[index].rect
	var at:=actor.motor.global_position
	var half:=actor.definition.collision_size*.5
	if at.x-half.x<rect.position.x or at.x+half.x>rect.end.x or absf(at.y+half.y-rect.position.y)>1:return false
	var world:=actor.motor.get_world_2d().direct_space_state
	var rid:=RID()
	for dx: float in [-half.x+.5,0.,half.x-.5]:
		var foot:=at+Vector2(dx,half.y)
		var ray:=PhysicsRayQueryParameters2D.create(foot+Vector2(0,-1),foot+Vector2(0,2),1,[actor.motor.get_rid()])
		var hit:=world.intersect_ray(ray)
		if hit.is_empty() or (hit.normal as Vector2).y>-.5:return false
		if rid.is_valid() and hit.rid!=rid:return false
		rid=hit.rid
	return true

func _blocked(reason: String) -> void:
	ledger.append({"event":"blocked","reason":reason,"position":[actor.motor.global_position.x,actor.motor.global_position.y],"collision":obstruction.duplicate(true)})
	flight_velocity=Vector2(0,maxf(flight_velocity.y,0));committed_shore=-1;recovery_support={};recovery_budget_failed=false
	_set_state(&"recovery_fall")

func _actual_move(motion: Vector2,delta: float) -> bool:
	# The read-only test records the collider; the original Motor still owns
	# collision recovery and the actual move, including collisions with Player.
	obstruction={}
	obstruction_body=null
	var collision:=KinematicCollision2D.new()
	if actor.motor.test_move(actor.motor.global_transform,motion,collision):
		var body:=collision.get_collider() as Node
		obstruction_body=body
		obstruction={"collider":str(body.get_path()) if is_instance_valid(body) else "","player":body==controller.motor,"normal":[collision.get_normal().x,collision.get_normal().y]}
	return actor.motor.move_attack(motion,false,delta)

func _recovery_move(motion: Vector2,delta: float,part: String) -> void:
	var before:=actor.motor.global_position
	var moved:=_actual_move(motion,delta)
	ledger.append({"event":"recovery_move","part":part,"elapsed":state_time,"physics_frame":Engine.get_physics_frames(),"requested":[motion.x,motion.y],"from":[before.x,before.y],"to":[actor.motor.global_position.x,actor.motor.global_position.y],"unblocked":moved,"collision":obstruction.duplicate(true)})

func _static_full_support() -> Dictionary:
	var half:=actor.definition.collision_size*.5
	var body: StaticBody2D
	var feet: Array=[]
	for dx: float in [-half.x+.5,0.,half.x-.5]:
		var foot:=actor.motor.global_position+Vector2(dx,half.y)
		var ray:=PhysicsRayQueryParameters2D.create(foot+Vector2(0,-1),foot+Vector2(0,2),1,[actor.motor.get_rid(),controller.motor.get_rid()])
		var hit:=actor.motor.get_world_2d().direct_space_state.intersect_ray(ray)
		if hit.is_empty() or not hit.collider is StaticBody2D or (hit.normal as Vector2).y>-.5:return {}
		if body!=null and body!=hit.collider:return {}
		body=hit.collider
		feet.append([hit.position.x,hit.position.y])
	var value: Variant=body.get_meta("support_world_rect",null)
	if not value is Rect2:return {}
	var rect: Rect2=value
	var at:=actor.motor.global_position
	if at.x-half.x<rect.position.x-.01 or at.x+half.x>rect.end.x+.01 or absf(at.y+half.y-rect.position.y)>1:return {}
	return {"path":str(body.get_path()),"support_ids":body.get_meta("support_ids",[]),"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"feet":feet,"static":true,"not_player":body.get_instance_id()!=controller.motor.get_instance_id()}

func cancel() -> void:
	if not is_instance_valid(actor) or not is_instance_valid(actor.motor):return
	if actor.health.terminal:
		flight_velocity=Vector2.ZERO;actor.motor.stop();_set_state(&"blocked");return
	if state in [&"rest",&"settle"]:
		# No live attack commitment: modal/pause retains the actual phase debt.
		return
	if state==&"telegraph":
		committed_shore=-1;_set_state(&"rest");return
	if state==&"flight":
		committed_shore=-1;_set_state(&"cancelled_fall");return
	# An inactive/cancelled fall retains velocity, without advancing while paused.

func _shore_snapshot() -> Array:
	var rows: Array=[]
	for row: Dictionary in shores:
		var rect: Rect2=row.rect
		var at: Vector2=row.position
		rows.append({"id":String(row.id),"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"position":[at.x,at.y]})
	return rows

func depth_snapshot() -> Dictionary:
	return {"version":1,"shores":_shore_snapshot(),"state":str(state),"time":state_time,"shore":current_shore,"committed":committed_shore,"velocity":[flight_velocity.x,flight_velocity.y],"motor_velocity":[actor.motor.velocity.x,actor.motor.velocity.y],"serial":transit_serial,"supported_frames":supported_frames,"obstruction":obstruction.duplicate(true),"recovery_support":recovery_support.duplicate(true),"recovery_budget_failed":recovery_budget_failed}

func restore_region_state(saved: Dictionary) -> bool:
	# Migration has one validated physical transit record. The App historically
	# skipped the generic attack fields, including home and facing, for this actor.
	return _restore_region_depth(saved)

func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func _whole_number(value: Variant) -> bool:
	return _finite_number(value) and float(value)==floorf(float(value))

func _number_array(value: Variant, count: int) -> bool:
	if not value is Array or value.size()!=count:return false
	for item: Variant in value:
		if not _finite_number(item):return false
	return true

func restore_depth_state(saved: Dictionary) -> bool:
	# Validate the complete record before applying anything. Actor/Stage retain
	# ownership of health and position; authored geometry is never loaded from save.
	if not _whole_number(saved.get("version")) or saved.version!=1 or shores.size()!=2:return false
	var recorded: Variant=saved.get("shores")
	if not recorded is Array or recorded.size()!=2:return false
	var authored:=_shore_snapshot()
	for i: int in 2:
		if not recorded[i] is Dictionary:return false
		var row: Dictionary=recorded[i]
		if not row.get("id") is String or row.id!=authored[i].id or not _number_array(row.get("rect"),4) or not _number_array(row.get("position"),2):return false
		for j: int in 4:
			if float(row.rect[j])!=float(authored[i].rect[j]):return false
		for j: int in 2:
			if float(row.position[j])!=float(authored[i].position[j]):return false
	if not saved.get("state") is String or saved.state not in ["rest","telegraph","flight","cancelled_fall","recovery_fall","grounded_recovery","settle","blocked"]:return false
	if not _finite_number(saved.get("time")) or saved.time<0:return false
	for key: String in ["shore","committed","serial","supported_frames"]:
		if not _whole_number(saved.get(key)):return false
	if saved.shore not in [0,1] or saved.committed not in [-1,0,1] or saved.serial<0 or saved.serial>2147483647 or saved.supported_frames<0 or saved.supported_frames>2147483647:return false
	if not _number_array(saved.get("velocity"),2) or not _number_array(saved.get("motor_velocity"),2):return false
	if not saved.get("recovery_budget_failed") is bool:return false
	if not saved.get("obstruction") is Dictionary or not saved.get("recovery_support") is Dictionary:return false
	var collision: Dictionary=saved.obstruction
	if not collision.is_empty() and (not collision.get("collider") is String or not collision.get("player") is bool or not _number_array(collision.get("normal"),2)):return false
	var support: Dictionary=saved.recovery_support
	if not support.is_empty():
		if not support.get("path") is String or not support.get("support_ids") is Array or not _number_array(support.get("rect"),4) or not support.get("static") is bool or not support.get("not_player") is bool or not support["static"] or not support.not_player:return false
		if support.rect[2]<=0 or support.rect[3]<=0 or not support.get("feet") is Array or support.feet.size()!=3:return false
		for id: Variant in support.support_ids:
			if not id is String:return false
		for foot: Variant in support.feet:
			if not _number_array(foot,2):return false
	var moving: bool=saved.state in ["flight","cancelled_fall","recovery_fall"]
	if saved.state in ["telegraph","flight"]:
		if saved.committed!=1-int(saved.shore):return false
	elif saved.state in ["cancelled_fall","recovery_fall","grounded_recovery"] and saved.committed!=-1:return false
	if not moving and (saved.velocity[0]!=0 or saved.velocity[1]!=0):return false
	if saved.state=="blocked" and not actor.health.terminal:return false
	if saved.state=="grounded_recovery" and support.is_empty():return false
	# This reference is deliberately re-acquired by the next actual gravity
	# collision; saved paths/rays never authorize a physical inward step.
	obstruction_body=null
	state=StringName(saved.state);state_time=float(saved.time)
	current_shore=int(saved.shore);committed_shore=int(saved.committed)
	flight_velocity=Vector2(saved.velocity[0],saved.velocity[1])
	actor.motor.velocity=Vector2(saved.motor_velocity[0],saved.motor_velocity[1])
	transit_serial=int(saved.serial);supported_frames=int(saved.supported_frames)
	obstruction=collision.duplicate(true);recovery_support=support.duplicate(true)
	recovery_budget_failed=saved.recovery_budget_failed
	_actor_epoch=lifetime.actor_epoch
	return true
