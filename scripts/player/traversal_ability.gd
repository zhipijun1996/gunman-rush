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

func request_hook(direction: Vector2) -> bool:
	if not hook_enabled or state != &"free" or not controller.active or not direction.is_finite(): return false
	if hook_used and not controller.motor.is_on_floor(): return false
	hook_used = true
	var face := signf(direction.x)
	if is_zero_approx(face):
		face = (controller.motor.get_node("CourierVisual") as CourierVisual).facing
	hook_forward = face
	hook_direction = Vector2(face,0)
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
	var motor := controller.motor
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
	if state == &"hook_contact_kick":
		if state_age < definition.hook_contact_seconds:
			motor.request_ability_velocity(Vector2.ZERO)
		else:
			motor.normal_velocity = Vector2(hook_forward*definition.hook_kick.x,definition.hook_kick.y)
			motor.lock_horizontal(motor.normal_velocity.x,definition.hook_launch_seconds)
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
		var ray := PhysicsRayQueryParameters2D.create(hook_tip,finish,0xFFFFFFFF,[motor.get_rid()])
		ray.collide_with_areas = true
		var hit := motor.get_world_2d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty():
			hook_tip = hit.position
			var node := hit.collider as Node2D
			if node != null and node.is_in_group(&"grapple_target"):
				hook_target = node
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
	if state == &"hook_pull":
		if not is_instance_valid(hook_target) or not hook_target.is_inside_tree() or state_age > 0.8:
			_set_state(&"hook_miss"); return
		var receiver := hook_target.get_node_or_null("Damageable") as Damageable
		if receiver != null and not receiver.active: _set_state(&"hook_miss"); return
		hook_tip = hook_target.to_global(hook_local)
		var offset := hook_tip-motor.global_position
		if offset.length() <= definition.hook_stop_distance + 0.05:
			motor.clear_recoil()
			controller.jump_ability.cancel_requests()
			motor.normal_velocity = Vector2.ZERO
			motor.request_ability_velocity(Vector2.ZERO)
			if receiver != null:
				receiver.receive_damage({"session_id":controller.session_id,"event_id":"hook/%s/%s/%s" % [motor.get_instance_id(),_session,_serial],"source_actor_id":motor.get_instance_id(),"target_actor_id":receiver.actor_id,"target_epoch":receiver.damage_epoch,"attack_id":_serial,"amount":definition.hook_damage,"damage_type":&"grapple","source_faction":&"player","hit_direction":hook_direction})
			_set_state(&"hook_contact_kick")
		else:
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
	if state == &"hook_pull" and _pull_step_requested and controller.motor.get_slide_collision_count() > 0:
		# A collision that prevents approach terminates the pull, never tunnels.
		if controller.motor.global_position.distance_to(hook_tip) > definition.hook_stop_distance+2:
			_set_state(&"hook_miss")

func cancel() -> void:
	if is_instance_valid(controller):
		controller.motor.wall_slide_limit = -1
		controller.motor.cancel_ability_motion()
	hook_target = null
	if is_instance_valid(controller) and controller.session_id != _session:
		_session = controller.session_id
		wall_ready = true
		_separated = true
		hook_used = false
	_set_state(&"free")

func _set_state(next: StringName) -> void:
	if state == next: return
	state = next
	state_age = 0
	action_changed.emit(state)

func on_weapon_fired() -> void:
	# The accepted recoil takes over from wall adhesion/kick recovery. Keep the
	# detach token; cancelling a pose must never grant another wall kick.
	controller.motor.wall_slide_limit = -1
	if state in [&"wall_attach",&"wall_kick",&"hook_kick"]: _set_state(&"free")

func on_jump_executed() -> void:
	if state in [&"wall_kick",&"hook_kick"]: _set_state(&"free")

func restore_air_actions() -> void:
	if double_enabled: controller.jump_ability.restore_air_jump()
	if hook_enabled: hook_used = false

func on_landed() -> void:
	hook_used = false
