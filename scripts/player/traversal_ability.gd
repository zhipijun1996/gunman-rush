class_name TraversalAbility
extends Node
## All displacement is requested from the sole Motor step. Visuals read this state.
signal action_changed(action: StringName)
signal hook_contact(point: Vector2)
var controller: PlayerController
var definition: TraversalDefinition = preload("res://resources/player/traversal.tres")
var wall_enabled := false
var hook_enabled := false
var double_enabled := false
var hook_used := false
var state: StringName = &"free"
var state_age := 0.0
var hook_tip := Vector2.ZERO
var hook_direction := Vector2.RIGHT
var hook_forward := 1.0
var hook_start := Vector2.ZERO
var hook_target: Node2D
var hook_local := Vector2.ZERO
var wall_normal := 0.0
var wall_point := Vector2.ZERO
var wall_ready := true
var _kick_x := 0.0
var _separated := true
var _serial := 0
var _session := 0
var _pull_step_requested := false
var _pull_distance_before := 0.0
var _hang_offset := Vector2.ZERO
var _released_hang_target: Node2D
var _anchor_jump_departure := false
var _contact_target: Node2D
var _contact_remaining := 0.0
var kick_side := -1.0
var guide_active := false
var guide_point := Vector2.ZERO
var guide_target_valid := false
var _hook_probe: ShapeCast2D
var _pending_hook: Dictionary = {}

func configure(actor: PlayerController) -> void:
	controller = actor
	_session = actor.session_id

func grant(id: StringName, enabled: bool = true) -> bool:
	if id == &"wall_climb": wall_enabled = enabled
	elif id == &"grapple": hook_enabled = enabled
	elif id == &"double_jump":
		double_enabled = enabled
		controller.jump_ability.capacity_floor = 2 if enabled else 0
	else: return false
	if not enabled: cancel()
	return true

func busy() -> bool:
	return state in [&"hook_cast", &"hook_fly", &"hook_pull", &"hook_miss", &"hook_retract", &"hook_contact_kick"]

func request_hook(direction: Vector2, intent: Dictionary = {}) -> bool:
	# A real contact has restored H before the short kick pose finishes. Keep
	# one release for that tail only; accepting input does not interrupt motion.
	if state == &"hook_kick" and not _anchor_jump_departure and hook_enabled and not hook_used and controller.active and direction.is_finite():
		if not _pending_hook.is_empty(): return false
		# Carry the original Router envelope across the pose, not a fresh TTL.
		# Direct ability callers have no queued envelope and begin their bound now.
		var now := Time.get_ticks_usec()/1000000.0
		var issued_at := float(intent.get("timestamp", now))
		var epoch := int(intent.get("epoch", controller.router.epoch))
		var sequence := int(intent.get("sequence", controller.router.sequence))
		if not is_finite(issued_at) or issued_at > now or now-issued_at > InputRouter.MAX_AGE_SECONDS or epoch != controller.router.epoch or sequence != controller.router.sequence: return false
		_pending_hook = {"direction":direction,"epoch":epoch,"sequence":sequence,"device":controller.router.current_device,"session":controller.session_id,"deadline":int((issued_at+InputRouter.MAX_AGE_SECONDS)*1000000.0)}
		return true
	# A manual held-anchor jump follows normal gravity, so there is no burst
	# to finish before another cast. Sample the new direction at its real input
	# time; only automatic contact kicks retain the bounded tail queue above.
	var jumping_from_anchor := state == &"hook_kick" and _anchor_jump_departure
	if not hook_enabled or (state not in [&"free", &"hook_hang"] and not jumping_from_anchor) or not controller.active or not direction.is_finite(): return false
	if hook_used and not controller.motor.is_on_floor(): return false
	if jumping_from_anchor and not intent.is_empty():
		var jump_now := Time.get_ticks_usec()/1000000.0
		var jump_issued_at := float(intent.get("timestamp",jump_now))
		if not is_finite(jump_issued_at) or jump_issued_at>jump_now or jump_now-jump_issued_at>InputRouter.MAX_AGE_SECONDS or int(intent.get("epoch",controller.router.epoch))!=controller.router.epoch or int(intent.get("sequence",controller.router.sequence))!=controller.router.sequence: return false
	_pending_hook.clear()
	_released_hang_target=hook_target if state == &"hook_hang" or jumping_from_anchor else null
	if state == &"hook_hang":
		controller.motor.cancel_ability_motion()
		_set_state(&"free")
	hook_used = true
	var face := signf(direction.x)
	if is_zero_approx(direction.x):
		face = (controller.motor.get_node("CourierVisual") as CourierVisual).facing
	hook_forward = face
	hook_direction = direction.normalized() if not direction.is_zero_approx() else Vector2(face,0)
	hook_start = controller.motor.global_position + Vector2(0,-6)
	hook_tip = hook_start
	_session = controller.session_id
	_serial += 1
	controller.shoot_ability.cancel_packet(&"grapple")
	controller.jump_ability.cancel_requests()
	_set_state(&"hook_cast")
	return true

func wall_jump() -> bool:
	if not wall_enabled or state != &"wall_attach" or not wall_ready: return false
	var motor := controller.motor
	motor.clear_recoil()
	motor.cancel_weapon_apex()
	controller.jump_ability.cancel_ascent()
	motor.normal_velocity = Vector2(wall_normal * definition.wall_kick.x,definition.wall_kick.y)
	motor.lock_horizontal(motor.normal_velocity.x,definition.wall_detach_seconds)
	wall_ready = false
	_separated = false
	_kick_x = motor.global_position.x
	restore_air_actions()
	_set_state(&"wall_kick")
	return true

func advance(delta: float) -> void:
	_contact_remaining = maxf(0.0,_contact_remaining-delta)
	var motor := controller.motor
	_update_guide()
	_pull_step_requested = false
	motor.wall_slide_limit = -1
	if _session != controller.session_id:
		cancel()
	if motor.is_on_floor(): wall_ready = true; _separated = true
	state_age += delta
	if not controller.active: cancel(); return
	if not _separated and absf(motor.global_position.x-_kick_x) >= definition.wall_separation:
		_separated = true
	if state == &"wall_kick" and state_age >= definition.wall_detach_seconds: _set_state(&"free")
	if state == &"hook_kick":
		hook_tip = hook_tip.move_toward(motor.global_position+Vector2(0,-6),definition.hook_return_speed*delta)
		if state_age >= definition.hook_launch_seconds: _set_state(&"free")
	if not _pending_hook.is_empty():
		var valid: bool = hook_enabled and not hook_used and controller.active and controller.router.has_application_focus and not get_tree().paused and _pending_hook.epoch == controller.router.epoch and _pending_hook.sequence == controller.router.sequence and _pending_hook.device == controller.router.current_device and _pending_hook.session == controller.session_id and Time.get_ticks_usec() <= int(_pending_hook.deadline) and state in [&"hook_kick", &"free"]
		if not valid: _pending_hook.clear()
		elif state == &"free":
			var direction: Vector2 = _pending_hook.direction
			_pending_hook.clear()
			request_hook(direction)
	if state == &"hook_contact_kick":
		if state_age < definition.hook_contact_seconds:
			motor.request_ability_velocity(Vector2.ZERO)
		else:
			var kick := Vector2(kick_side*definition.hook_kick.x,definition.hook_kick.y)
			motor.start_weapon_burst(kick,kick.length(),definition.hook_launch_seconds)
			restore_air_actions()
			_set_state(&"hook_kick")
		return
	if state == &"hook_miss":
		if state_age >= definition.hook_miss_hold: _set_state(&"hook_retract")
		return
	if state == &"hook_retract":
		var origin := motor.global_position + Vector2(0,-6)
		hook_tip = hook_tip.move_toward(origin, definition.hook_return_speed * delta)
		if hook_tip.distance_to(origin) <= 1.0: _set_state(&"free")
		return
	if state == &"hook_cast":
		if state_age >= definition.hook_windup: _set_state(&"hook_fly")
		return
	if state == &"hook_fly":
		var finish := hook_tip + hook_direction * definition.hook_flight_speed * delta
		if hook_start.distance_to(finish) > definition.hook_range:
			finish = hook_start + hook_direction * definition.hook_range
		var hit := _probe_segment(hook_tip,finish)
		if not hit.is_empty():
			hook_tip = hit.position
			kick_side=signf(hook_start.x-hook_tip.x)
			# A practically vertical approach has no meaningful incoming side.
			# Small aim/capture jitter must not randomly choose a 24px side hop.
			if absf(hook_direction.x) <= definition.hook_vertical_kick_deadzone: kick_side=0.0
			var node := hit.collider as Node2D
			if node != null and node.is_in_group(&"grapple_target"):
				hook_target = node
				_contact_target = node
				_contact_remaining = definition.hook_contact_grace
				hook_local = node.to_local(hook_tip)
				controller.jump_ability.cancel_ascent()
				motor.clear_recoil()
				hook_contact.emit(hook_tip)
				_set_state(&"hook_pull")
			else: _set_state(&"hook_miss")
		else:
			hook_tip = finish
			if hook_start.distance_to(hook_tip) >= definition.hook_range-0.01: _set_state(&"hook_miss")
		return
	if state == &"hook_hang":
		if not is_instance_valid(hook_target) or not hook_target.is_inside_tree():
			cancel(); return
		hook_tip=hook_target.to_global(hook_local)
		var hold_delta := hook_tip+_hang_offset-motor.global_position
		motor.request_ability_velocity(hold_delta.limit_length(definition.hook_pull_speed*delta)/delta)
		return
	if state == &"hook_pull":
		if not is_instance_valid(hook_target) or not hook_target.is_inside_tree() or state_age > 0.8:
			_set_state(&"hook_miss"); return
		var receiver := hook_target.get_node_or_null("Damageable") as Damageable
		if receiver != null and not receiver.active: _set_state(&"hook_miss"); return
		hook_tip = hook_target.to_global(hook_local)
		var offset := hook_tip-motor.global_position
		_pull_distance_before = offset.length()
		_pull_step_requested = true
		motor.request_ability_velocity(offset.normalized()*minf(definition.hook_pull_speed,maxf(0,offset.length()-definition.hook_stop_distance)/delta))
		return
	if state == &"free" or state == &"wall_attach":
		var touching := wall_enabled and not motor.is_on_floor() and motor.is_on_wall() and motor.recoil_burst_remaining <= 0
		var normal := 0.0
		if touching:
			for index: int in motor.get_slide_collision_count():
				var hit := motor.get_slide_collision(index)
				var surface := hit.get_collider() as Node
				if absf(hit.get_normal().x) > .7 and surface != null and surface.is_in_group(&"wall_climbable"):
					normal = hit.get_normal().x
					wall_point = hit.get_position()
			if normal * controller.router.axis >= -0.1: touching = false
			if is_zero_approx(normal): touching = false
		if touching and (_separated or wall_ready):
			wall_normal = normal
			wall_ready = true
			motor.wall_slide_limit = definition.wall_fall_speed
			_set_state(&"wall_attach")
		elif state == &"wall_attach": _set_state(&"free")

func after_move() -> void:
	if state == &"hook_hang":
		# A moved/obstructed ring cannot drag the body through solid geometry.
		if motor_hang_blocked(): cancel()
		return
	if state != &"hook_pull" or not _pull_step_requested: return
	var motor := controller.motor
	var distance := motor.global_position.distance_to(hook_tip)
	# Commit arrival against the anchor sampled for this Motor step. Waiting for
	# advance lets an escaping target move the stop ring away again every tick.
	if distance <= definition.hook_stop_distance + 0.05:
		if not is_instance_valid(hook_target) or not hook_target.is_inside_tree():
			_set_state(&"hook_miss"); return
		var receiver := hook_target.get_node_or_null("Damageable") as Damageable
		if receiver != null and not receiver.active: _set_state(&"hook_miss"); return
		motor.clear_recoil()
		controller.jump_ability.cancel_requests()
		motor.normal_velocity = Vector2.ZERO
		if receiver != null:
			receiver.receive_damage({"session_id":controller.session_id,"event_id":"hook/%s/%s/%s" % [motor.get_instance_id(),_session,_serial],"source_actor_id":motor.get_instance_id(),"target_actor_id":receiver.actor_id,"target_epoch":receiver.damage_epoch,"attack_id":_serial,"amount":definition.hook_damage,"damage_type":&"grapple","source_faction":&"player","hit_direction":hook_direction,"on_committed":controller.on_grapple_damage.bind(_session,_serial,(receiver.actor_id if receiver.actor_id!=0 else receiver.get_instance_id()) if receiver.faction==&"enemy" else 0)})
		if hook_target is GrappleAnchor and (hook_target as GrappleAnchor).hang_enabled:
			_hang_offset=motor.global_position-hook_tip
			restore_air_actions()
			_set_state(&"hook_hang")
		else: _set_state(&"hook_contact_kick")
	elif motor.get_slide_collision_count() > 0 and distance > definition.hook_stop_distance+2 and _pull_distance_before-distance < 0.05:
		# Stop only when collision actually prevents approach. A floor may
		# clip downward velocity while the real body slides toward its edge.
		_set_state(&"hook_miss")

func motor_hang_blocked() -> bool:
	return controller.motor.get_slide_collision_count()>0 and controller.motor.global_position.distance_to(hook_tip+_hang_offset)>2.0

func release_hang_for_jump() -> bool:
	if state != &"hook_hang": return false
	if not controller.active or not hook_enabled or not is_instance_valid(hook_target) or not hook_target is GrappleAnchor: return false
	if not controller.jump_ability.enabled or controller.jump_ability.maximum_jumps()<=0: return false
	controller.motor.cancel_ability_motion()
	if not controller.jump_ability.jump_from_anchor(controller.motor): return false
	controller.motor.lock_horizontal(kick_side*definition.hook_kick.x,definition.hook_launch_seconds)
	# Retain the short release pose/rope tail, interruptible by a new H input.
	# Vertical motion follows the real jump instead of a 24wu burst.
	_set_state(&"hook_kick")
	_anchor_jump_departure = true
	return true

func cancel() -> void:
	_pending_hook.clear()
	guide_active=false;guide_target_valid=false
	_contact_target = null
	_contact_remaining = 0.0
	if is_instance_valid(controller):
		controller.motor.wall_slide_limit = -1
		controller.motor.cancel_ability_motion()
	hook_target = null
	_released_hang_target = null
	if is_instance_valid(controller) and controller.session_id != _session:
		_session = controller.session_id
		wall_ready = true
		_separated = true
		hook_used = false
	_set_state(&"free")

func _set_state(next: StringName) -> void:
	if state == next: return
	state = next
	if next != &"hook_kick": _anchor_jump_departure = false
	if next == &"hook_kick": _contact_remaining = definition.hook_launch_seconds + definition.hook_contact_grace
	elif next in [&"hook_miss",&"hook_retract"]:
		_contact_target = null
		_contact_remaining = 0.0
	state_age = 0
	action_changed.emit(state)

func protects_contact(source: Node) -> bool:
	if _session != controller.session_id or not controller.active or not is_instance_valid(_contact_target): return false
	if state not in [&"hook_pull",&"hook_contact_kick",&"hook_kick"] and _contact_remaining <= 0.0: return false
	return source == _contact_target or _contact_target.is_ancestor_of(source)

func on_weapon_fired() -> void:
	_pending_hook.clear()
	# The accepted recoil takes over from wall adhesion/kick recovery. Keep the
	# detach token; cancelling a pose must never grant another wall kick.
	controller.motor.wall_slide_limit = -1
	if state == &"hook_hang": controller.motor.cancel_ability_motion()
	if state in [&"wall_attach",&"wall_kick",&"hook_kick",&"hook_hang"]: _set_state(&"free")

func on_jump_executed() -> void:
	_pending_hook.clear()
	if state in [&"wall_kick",&"hook_kick"]: _set_state(&"free")

func restore_air_actions() -> void:
	if double_enabled: controller.jump_ability.restore_air_jump()
	if hook_enabled: hook_used = false

func on_landed() -> void:
	hook_used = false

func _probe_segment(start: Vector2, finish: Vector2) -> Dictionary:
	if _hook_probe==null:
		_hook_probe=ShapeCast2D.new()
		var shape := CircleShape2D.new();shape.radius=definition.hook_capture_radius
		_hook_probe.shape=shape;_hook_probe.enabled=false;_hook_probe.exclude_parent=false
		_hook_probe.collision_mask=0xFFFFFFFF;_hook_probe.collide_with_areas=true
		add_child(_hook_probe);_hook_probe.add_exception(controller.motor)
	# Exclude the departed ring before sweeping: skipping result entries alone
	# cannot reveal a farther target behind an initial overlap.
	_hook_probe.clear_exceptions()
	_hook_probe.add_exception(controller.motor)
	if state==&"hook_hang" and is_instance_valid(hook_target): _hook_probe.add_exception(hook_target)
	if state in [&"hook_cast",&"hook_fly"] and is_instance_valid(_released_hang_target): _hook_probe.add_exception(_released_hang_target)
	_hook_probe.global_position=start
	_hook_probe.target_position=_hook_probe.to_local(finish)
	_hook_probe.force_shapecast_update()
	var chosen: Dictionary={};var nearest := INF
	for i: int in _hook_probe.get_collision_count():
		var point := _hook_probe.get_collision_point(i)
		if point.distance_to(hook_start)>definition.hook_range+.01:continue
		var node := _hook_probe.get_collider(i) as Node2D
		if node==null:continue
		if node==_released_hang_target and state in [&"hook_cast",&"hook_fly"]:continue
		if node==hook_target and state==&"hook_hang":continue
		var distance := start.distance_squared_to(point)
		if distance<nearest:
			nearest=distance;chosen={"position":point,"collider":node}
	if not chosen.is_empty():
		var ray := PhysicsRayQueryParameters2D.create(start,chosen.position,1,[controller.motor.get_rid()])
		var obstruction := controller.motor.get_world_2d().direct_space_state.intersect_ray(ray)
		if not obstruction.is_empty() and obstruction.collider!=chosen.collider:return {"position":obstruction.position,"collider":obstruction.collider}
	return chosen
func _update_guide() -> void:
	guide_active=hook_enabled and state in [&"free",&"hook_hang",&"hook_kick"] and controller.active and not hook_used and (controller.router.aim_engaged or controller.router.aim_mode==&"grapple") and not controller.router.aim_direction.is_zero_approx()
	guide_target_valid=false
	if not guide_active:return
	var origin := controller.motor.global_position+Vector2(0,-6)
	var end := origin+controller.router.aim_direction.normalized()*definition.hook_range
	var previous_start := hook_start
	hook_start=origin
	var contact := _probe_segment(origin,end)
	hook_start=previous_start
	guide_point=end if contact.is_empty() else contact.position
	guide_target_valid=not contact.is_empty() and (contact.collider as Node).is_in_group(&"grapple_target")
