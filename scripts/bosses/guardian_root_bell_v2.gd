class_name GuardianRootBellV2
extends ForestBossMotor
## A solid, indestructible metal weapon; bullets hit real geometry, never armour.
signal bell_event(event: Dictionary)
signal recovered(caught: bool)
signal counter_impact(data: Dictionary)
var owner_motor: ForestBossMotor
var config: BossDuelDefinition
var controller: PlayerController
var lifetime: DemoLifetime
var contact: DemoContactEmitter
var state: StringName = &"held"
var facing := -1.0
var age := 0.0
var travel_age := 0.0
var bounces := 0
var attack_epoch := 0
var token: DemoToken
var _finished := false
var _circle: CircleShape2D
var _escape_active := false
var _escape_goal := Vector2.ZERO
var _contact_rebound_velocity := Vector2.ZERO
var _contact_rebound_remaining := 0.0
var _arrival_confirmed := false
var _counter_active := false
var _counter_age := 0.0
var _counter_velocity := Vector2.ZERO
var _counter_event: StringName
var _counter_submitted := false
var _actor_session := -1
func setup(owner_body: ForestBossMotor, data: BossDuelDefinition, actor: PlayerController, policy: FrameDamagePolicy, life: DemoLifetime, source: StringName, epoch: int) -> void:
	owner_motor = owner_body
	config = data
	motion_safe_margin = data.bell_motion_safe_margin
	controller = actor
	_actor_session = actor.session_id
	actor.traversal.action_changed.connect(_traversal_action)
	lifetime = life
	token = life.token()
	attack_epoch = epoch
	facing = signf(actor.motor.global_position.x-owner_body.global_position.x)
	if is_zero_approx(facing): facing = -1
	collision_layer = 8
	collision_mask = 1|4
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group(&"grapple_target")
	var shape := CollisionShape2D.new()
	_circle = CircleShape2D.new()
	_circle.radius = config.bell_radius
	shape.shape = _circle
	add_child(shape)
	add_collision_exception_with(owner_motor)
	global_position = owner_motor.global_position+Vector2(config.bell_hold_offset.x*facing,config.bell_hold_offset.y)
	contact = DemoContactEmitter.new()
	contact.policy = policy
	contact.controller = actor
	contact.source_id = source
	contact.amount = config.projectile_damage
	contact.half_size = Vector2.ONE*(config.bell_radius/sqrt(2.0)) # Inscribed square; actual collision signal covers the circular rim.
	contact.enabled = false
	add_child(contact)
func launch(goal: Vector2) -> void:
	if state != &"held" or not goal.is_finite(): return
	state = &"outbound"
	age = 0
	var duration := config.bell_outbound_seconds
	velocity = (goal-global_position)/duration-Vector2(0,config.bell_gravity*duration*.5)
	contact.enabled = true
	_emit("bell_launch",{"goal":[goal.x,goal.y],"velocity":[velocity.x,velocity.y]})
func _physics_process(delta: float) -> void:
	if _finished: return
	if not is_instance_valid(owner_motor) or not is_instance_valid(controller) or not lifetime.accepts(token) or not controller.active or controller.actor_resources.health.terminal:
		finish(false)
		return
	if state == &"held":
		var goal := owner_motor.global_position+Vector2(config.bell_hold_offset.x*facing,config.bell_hold_offset.y)
		advance_duel((goal-global_position)/delta,delta)
		queue_redraw()
		return
	age += delta
	travel_age += delta
	if travel_age >= config.bell_lifetime:
		_emit("bell_lost",{"reason":"bounded_lifetime_without_physical_catch"})
		finish(false)
		return
	if state == &"outbound":
		velocity.y += config.bell_gravity*delta
		if age >= config.bell_outbound_seconds:
			_begin_return("outbound_flight_complete")
			if _finished: return
	if state == &"returning":
		if _try_owner_overlap(): return
		if _counter_active:
			_counter_age += delta
			if _counter_age >= config.bell_counter_max_flight:
				_counter_active = false
				_emit("bell_counter_dissipated",{"reason":"missed_physical_intercept"})
			else:
				_counter_velocity.y += config.bell_gravity*delta
				velocity = _counter_velocity
		if not _counter_active:
			_steer_return(delta)
	var requested_velocity := velocity
	var collision := advance_duel(velocity,delta)
	if collision != null:
		var collider := collision.get_collider()
		_emit("bell_collision",{"kind":"owner" if collider==owner_motor else "player" if collider==controller.motor else "terrain","collider":collider.get_instance_id() if is_instance_valid(collider) else 0,"contact_kind":"kinematic_sweep","counter_active":_counter_active,"requested_velocity":[requested_velocity.x,requested_velocity.y],"collider_velocity":[collision.get_collider_velocity().x,collision.get_collider_velocity().y],"travel":[collision.get_travel().x,collision.get_travel().y],"remainder":[collision.get_remainder().x,collision.get_remainder().y],"depth":collision.get_depth(),"motion_safe_margin":motion_safe_margin,"normal":[collision.get_normal().x,collision.get_normal().y],"point":[collision.get_position().x,collision.get_position().y]})
		if state == &"returning" and collider == owner_motor:
			_counter_at_owner("kinematic_sweep",collision.get_position())
			finish(true)
			return
		if _counter_active:
			_counter_active = false
			_emit("bell_counter_dissipated",{"reason":"actual_obstacle_impact","collider":collider.get_instance_id() if is_instance_valid(collider) else 0})
		velocity = velocity.bounce(collision.get_normal())*config.bell_restitution
		if state == &"returning": _escape_from(collision,requested_velocity)
		bounces += 1
		if state == &"outbound" and bounces >= config.bell_max_bounces:
			_begin_return("actual_bounce_limit")
			if _finished: return
			_escape_from(collision,requested_velocity)
	queue_redraw()
func _steer_return(delta: float) -> void:
	if _contact_rebound_remaining > 0:
		_contact_rebound_remaining = maxf(0,_contact_rebound_remaining-delta)
		velocity = _contact_rebound_velocity
		return
	if _escape_active and global_position.distance_to(_escape_goal) <= config.bell_return_speed*delta:
		_escape_active = false
		_emit("bell_escape_clear",{"goal":[_escape_goal.x,_escape_goal.y]})
	var destination := _escape_goal if _escape_active else owner_motor.global_position
	velocity = global_position.direction_to(destination)*minf(config.bell_return_speed,global_position.distance_to(destination)/delta)
func _begin_return(reason: String) -> void:
	state = &"returning"
	_emit("bell_return",{"reason":reason})
	# Owner was excluded during the throw. Enabling a collider while already
	# inside it can depenetrate the bell through an adjacent wall. Query this
	# exact live circle/body overlap before re-enabling their physical pair.
	if _try_owner_overlap(): return
	remove_collision_exception_with(owner_motor)
func _try_owner_overlap() -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _circle
	query.transform = global_transform
	query.collision_mask = owner_motor.collision_layer
	query.exclude = [get_rid()]
	for hit: Dictionary in get_world_2d().direct_space_state.intersect_shape(query):
		if hit.get("collider") == owner_motor:
			_emit("bell_collision",{"kind":"owner","contact_kind":"actual_shape_overlap","collider":owner_motor.get_instance_id(),"shape_index":hit.get("shape",-1),"point":[global_position.x,global_position.y],"radius":_circle.radius,"owner_position":[owner_motor.global_position.x,owner_motor.global_position.y]})
			_counter_at_owner("actual_shape_overlap",global_position)
			finish(true)
			return true
	return false
func _traversal_action(action: StringName) -> void:
	if _finished or not is_instance_valid(controller) or controller.session_id != _actor_session or not controller.active or not lifetime.accepts(token): return
	if controller.traversal.hook_target != self or state not in [&"outbound",&"returning"]: return
	if action == &"hook_contact_kick":
		_arrival_confirmed = true
		_emit("bell_player_arrived",{"accepted_action":String(action),"player_position":[controller.motor.global_position.x,controller.motor.global_position.y],"hook_tip":[controller.traversal.hook_tip.x,controller.traversal.hook_tip.y]})
	if action != &"hook_kick" or not _arrival_confirmed or not config.bell_counter_enabled or _counter_active or _counter_submitted: return
	_counter_active = true
	_counter_age = 0
	_contact_rebound_remaining = 0
	_escape_active = false
	_counter_event = StringName("bell-counter:%s:%s:%s" % [get_instance_id(),attack_epoch,lifetime.stage_epoch])
	var goal := owner_motor.global_position
	var time := maxf(global_position.distance_to(goal)/config.bell_counter_speed,0.01)
	_counter_velocity = (goal-global_position)/time-Vector2(0,.5*config.bell_gravity*time)
	_emit("bell_counter_armed",{"accepted_action":String(action),"event_id":String(_counter_event),"locked_owner":[goal.x,goal.y],"velocity":[_counter_velocity.x,_counter_velocity.y],"player_session":_actor_session})
	_begin_return("actual_player_arrival_and_kick")
func _counter_at_owner(contact_kind: String, point: Vector2) -> void:
	if not _counter_active or _counter_submitted or not lifetime.accepts(token): return
	_counter_submitted = true
	var data := {"event_id":String(_counter_event),"bell_id":get_instance_id(),"owner_id":owner_motor.get_instance_id(),"contact_kind":contact_kind,"point":[point.x,point.y],"physics_frame":Engine.get_physics_frames(),"attack_epoch":attack_epoch,"player_session":_actor_session}
	_emit("bell_counter_owner_contact",data)
	counter_impact.emit(data)
func _escape_from(collision: KinematicCollision2D, incoming_velocity: Vector2) -> void:
	var normal := collision.get_normal()
	var toward := owner_motor.global_position-global_position
	var bounds := _actual_rect(collision)
	if collision.get_collider() == controller.motor:
		# A moving collider can overlap us before this body's accepted step.
		# Recomputing a return goal each collision merely lets it push the bell.
		# Commit once to a finite physical rebound relative to its actual speed.
		if _contact_rebound_remaining > 0: return
		var collider_velocity := collision.get_collider_velocity()
		var relative := incoming_velocity-collider_velocity
		var outward_speed := maxf(absf(relative.dot(normal))*config.bell_restitution,config.bell_return_speed)
		_contact_rebound_velocity = collider_velocity+normal*outward_speed+relative.slide(normal)*config.bell_restitution
		_contact_rebound_remaining = config.bell_contact_rebound_seconds
		_escape_active = false
		_escape_goal = global_position+_contact_rebound_velocity*_contact_rebound_remaining
		_emit("bell_contact_rebound",{"duration":_contact_rebound_remaining,"velocity":[_contact_rebound_velocity.x,_contact_rebound_velocity.y],"normal":[normal.x,normal.y],"collider_velocity":[collider_velocity.x,collider_velocity.y],"incoming_velocity":[incoming_velocity.x,incoming_velocity.y],"goal":[_escape_goal.x,_escape_goal.y]})
		return
	_contact_rebound_remaining = 0
	if absf(normal.y) >= absf(normal.x):
		var side := signf(toward.x)
		if is_zero_approx(side): side = -1 if bounds.has_area() and global_position.x < bounds.get_center().x else 1
		var distance := config.branch_size.x*.5+config.bell_radius+config.bell_escape_clearance
		var target_x := global_position.x+side*distance
		# A local root/branch has a visible edge. Floors span the whole arena;
		# leave them tangentially instead of attempting to go around the world.
		if bounds.has_area() and bounds.size.x < config.arena_size.x*.5:
			target_x = bounds.position.x-config.bell_radius-config.bell_escape_clearance if side < 0 else bounds.end.x+config.bell_radius+config.bell_escape_clearance
		_escape_goal = Vector2(target_x,global_position.y)
	else:
		var side := signf(toward.y)
		if is_zero_approx(side): side = -1
		_escape_goal = global_position+normal*(config.bell_radius+config.bell_escape_clearance)+Vector2(0,side*config.branch_size.y*2)
	_escape_active = true
	_emit("bell_escape_commit",{"goal":[_escape_goal.x,_escape_goal.y],"normal":[normal.x,normal.y],"obstacle_rect":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y]})
func _actual_rect(collision: KinematicCollision2D) -> Rect2:
	var collider_shape := collision.get_collider_shape() as CollisionShape2D
	if collider_shape == null: return Rect2()
	var shape := collider_shape.shape as RectangleShape2D
	if shape == null: return Rect2()
	var shape_transform := collider_shape.global_transform
	var half := shape.size*.5
	var bounds := Rect2(shape_transform*(-half),Vector2.ZERO)
	for corner: Vector2 in [Vector2(half.x,-half.y),half,Vector2(-half.x,half.y)]: bounds = bounds.expand(shape_transform*corner)
	return bounds
func finish(caught: bool) -> void:
	if _finished: return
	_finished = true
	if is_instance_valid(contact): contact.enabled = false
	_emit("bell_caught" if caught else "bell_cancelled",{})
	recovered.emit(caught)
	queue_free()
func _emit(kind: String, data: Dictionary) -> void:
	var row := data.duplicate(true)
	row["event"] = kind
	row["bell_id"] = get_instance_id()
	row["owner_id"] = owner_motor.get_instance_id() if is_instance_valid(owner_motor) else 0
	row["bell_state"] = String(state)
	row["position"] = [global_position.x,global_position.y]
	row["physics_frame"] = Engine.get_physics_frames()
	row["attack_epoch"] = attack_epoch
	bell_event.emit(row)
func _draw() -> void:
	if config == null: return
	if not ForestBibleActors.draw_mobile_bell(self, config.bell_radius, _counter_active):
		draw_circle(Vector2.ZERO,config.bell_radius,Color("e4a05e") if _counter_active else Color("8f865f"))
		draw_arc(Vector2.ZERO,config.bell_radius-4,0,TAU,24,Color("f4dfa0"),3)
		draw_line(Vector2(-config.bell_radius*.6,7),Vector2(config.bell_radius*.6,7),Color("332f28"),4)
		draw_circle(Vector2(0,-config.bell_radius+3),5,Color("f4dfa0"))
	if state != &"held": draw_line(Vector2.ZERO,-velocity.normalized()*40,Color("db9f60"),3)
	if _escape_active: draw_line(Vector2.ZERO,to_local(_escape_goal),Color("ffc276"),2)

func _exit_tree() -> void:
	if is_instance_valid(controller) and is_instance_valid(controller.traversal) and controller.traversal.action_changed.is_connected(_traversal_action):
		controller.traversal.action_changed.disconnect(_traversal_action)
