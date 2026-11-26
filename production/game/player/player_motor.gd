class_name PlayerMotor
extends CharacterBody2D

var weapon_motion: WeaponMotionDefinition = preload("res://resources/weapons/motion.tres")
var weapon_pause_remaining := 0.0
var weapon_apex_remaining := 0.0
var _weapon_drive_end_pending := false
var tuning: PlayerTuning
var normal_velocity := Vector2.ZERO
var recoil_velocity := Vector2.ZERO
var recoil_burst_remaining := 0.0
var _local_velocity := Vector2.ZERO
var _local_duration := 0.0
var _drop_body: PhysicsBody2D
var _drop_remaining := 0.0
var wall_slide_limit := -1.0
var _ability_requested := false
var _ability_velocity := Vector2.ZERO
var _horizontal_lock := 0.0
var _horizontal_value := 0.0
var motion_steps := 0
var damage_feedback: DamageFeedbackDefinition = preload("res://game/combat/damage/feedback.tres")
var damage_velocity := Vector2.ZERO
var damage_remaining := 0.0
var _blink_motion := Vector2.ZERO
var _blink_requested := false
var _sustained_recoil := false
var wind_velocity := Vector2.ZERO
var wind_acceleration := Vector2.ZERO
var wind_cap := 0.0
var bubble_carrier: Node
var contacts_current := true
var last_portal_step := -1
var last_action_step := -1
var wall_transport := false
signal repositioned
signal weapon_blinked(start: Vector2, finish: Vector2)

func grounded_contact() -> bool:
	return contacts_current and is_on_floor()

func wall_contact() -> bool:
	return contacts_current and is_on_wall()

func step(move_axis: float, delta: float) -> void:
	# Accepted hurt owns its short motion window. Firing remains legal, but a
	# burst requested inside it cannot freeze gravity or resume after hurt ends.
	if damage_remaining > 0:
		cancel_ability_motion()
		clear_recoil()
		cancel_weapon_apex()
	var ability_takes_step := _ability_requested
	var blink_committing := _blink_requested
	_advance_drop(delta)
	var acceleration := tuning.ground_acceleration if grounded_contact() else tuning.air_acceleration
	if is_zero_approx(move_axis) and grounded_contact():
		acceleration = tuning.ground_deceleration
	var support: Node = null
	var conveyor := Vector2.ZERO
	var best_depth := -INF
	var best_id := ""
	for index: int in (get_slide_collision_count() if contacts_current else 0):
		var contact := get_slide_collision(index)
		var body := contact.get_collider() as Node
		if body == null: continue
		var normal := contact.get_normal()
		if grounded_contact() and normal.y < -.7 and normal_velocity.y >= 0:
			var id := str(body.get_meta("editor_entity_id",body.name))
			var depth := contact.get_depth()
			if depth > best_depth or (is_equal_approx(depth,best_depth) and id < best_id):
				support = body
				best_depth = depth
				best_id = id
		if wall_transport and body.has_meta("conveyor"):
			conveyor = body.get_meta("conveyor").transport(normal,true)
	if support != null and support.has_meta("motion_surface"):
		normal_velocity.x = support.get_meta("motion_surface").walk_velocity(normal_velocity.x,move_axis,tuning.ground_speed,acceleration,delta)
	else:
		normal_velocity.x = move_toward(normal_velocity.x, move_axis * tuning.ground_speed, acceleration * delta)
	if support != null and support.has_meta("conveyor"):
		conveyor = support.get_meta("conveyor").transport(Vector2.UP,false)
	if _horizontal_lock > 0:
		normal_velocity.x = _horizontal_value
		_horizontal_lock = maxf(0,_horizontal_lock-delta)
	var bursting := recoil_burst_remaining > 0.0
	if bursting:
		# Fractional last tick preserves speed * duration distance at any fixed Hz.
		velocity = recoil_velocity * minf(1.0, recoil_burst_remaining / delta)
	else:
		normal_velocity.y = minf(normal_velocity.y + tuning.gravity * _weapon_gravity_time(delta), tuning.max_normal_fall_speed)
		if not _sustained_recoil: recoil_velocity *= exp(-delta / tuning.recoil_tau)
		velocity = normal_velocity + recoil_velocity
	if _local_duration > 0.0:
		velocity += _local_velocity
		_local_duration = maxf(0, _local_duration - delta)
	if wall_slide_limit >= 0: normal_velocity.y = minf(normal_velocity.y,wall_slide_limit); velocity.y = minf(velocity.y,wall_slide_limit)
	if _ability_requested:
		velocity = _ability_velocity
		normal_velocity = Vector2.ZERO
		_ability_requested = false
	if _blink_requested:
		var start := global_position
		var transform := global_transform
		var remaining := _blink_motion
		for slide: int in max_slides:
			var contact := KinematicCollision2D.new()
			if not test_move(transform,remaining,contact):
				transform.origin+=remaining;break
			transform.origin+=contact.get_travel()
			remaining=contact.get_remainder()
			remaining=remaining.slide(contact.get_normal())
			if remaining.is_zero_approx():break
		global_position=transform.origin
		normal_velocity=Vector2.ZERO;clear_recoil();velocity=Vector2.ZERO
		_blink_requested=false;_blink_motion=Vector2.ZERO
		weapon_pause_remaining=weapon_motion.blink_pause_seconds
		_start_weapon_apex()
		weapon_blinked.emit(start,global_position)
	_sustained_recoil=false
	if weapon_pause_remaining>0:
		if not blink_committing:weapon_pause_remaining=maxf(0,weapon_pause_remaining-delta)
		normal_velocity=Vector2.ZERO;clear_recoil();velocity=Vector2.ZERO
	if damage_remaining > 0:
		var fraction := minf(1.0, damage_remaining / delta)
		velocity = Vector2(lerpf(normal_velocity.x,damage_velocity.x,fraction),normal_velocity.y+damage_velocity.y*fraction)
		damage_remaining = maxf(0.0, damage_remaining - delta)
		if damage_remaining <= 0: damage_velocity = Vector2.ZERO
	if grounded_contact() or wall_transport or ability_takes_step or is_instance_valid(bubble_carrier):
		wind_velocity = Vector2.ZERO
	elif wind_cap > 0:
		wind_velocity = (wind_velocity + wind_acceleration*delta).limit_length(wind_cap)
	else:
		wind_velocity *= exp(-delta/maxf(tuning.recoil_tau,0.001))
	wind_acceleration = Vector2.ZERO
	wind_cap = 0
	velocity += wind_velocity + conveyor
	if is_instance_valid(bubble_carrier):
		velocity = bubble_carrier.passenger_velocity(self,delta)
		if is_instance_valid(bubble_carrier): normal_velocity = Vector2.ZERO
	motion_steps += 1
	move_and_slide()
	contacts_current = true
	for index: int in get_slide_collision_count():
		var normal := get_slide_collision(index).get_normal()
		if wind_velocity.dot(normal) < 0.0:
			wind_velocity = wind_velocity.slide(normal)
		if damage_velocity.dot(normal) < 0.0:
			damage_velocity = damage_velocity.slide(normal)
		if normal_velocity.dot(normal) < 0.0:
			normal_velocity -= normal * normal_velocity.dot(normal)
		if recoil_velocity.dot(normal) < 0.0:
			recoil_velocity -= normal * recoil_velocity.dot(normal)

	if bursting:
		recoil_burst_remaining = maxf(0.0, recoil_burst_remaining - delta)
		if recoil_burst_remaining <= 1.0e-9:
			if recoil_velocity.y<0:_start_weapon_apex()
			clear_recoil()

	if _weapon_drive_end_pending:
		_weapon_drive_end_pending=false;clear_recoil();_start_weapon_apex()

func reset_at(location: Vector2) -> void:
	_clear_drop()
	position = location
	contacts_current = false
	reset_motion()
	repositioned.emit()

func reset_motion() -> void:
	exit_bubble()
	wind_velocity = Vector2.ZERO
	wind_acceleration = Vector2.ZERO
	wind_cap = 0
	damage_velocity = Vector2.ZERO
	damage_remaining = 0.0
	cancel_ability_motion()
	clear_local_velocity()
	_clear_drop()
	normal_velocity = Vector2.ZERO
	clear_recoil()
	velocity = Vector2.ZERO
	weapon_pause_remaining=0;weapon_apex_remaining=0;_weapon_drive_end_pending=false

func apply_impulse(impulse: Vector2) -> void:
	if recoil_burst_remaining > 0.0:
		clear_recoil()
	recoil_velocity += impulse

static func ground_shot_motion(motion: Vector2, grounded: bool) -> Vector2:
	return Vector2(motion.x, 0.0) if grounded else motion

func start_shot_burst(direction: Vector2, strength: float = 1.0, grounded: bool = false) -> void:
	if not direction.is_finite() or direction.is_zero_approx():
		return
	cancel_weapon_apex()
	var unit := ground_shot_motion(direction.normalized(), grounded)
	if unit.is_zero_approx(): return
	var axis := unit.normalized()
	var opposing := normal_velocity.dot(axis)
	if opposing < 0.0:
		normal_velocity -= axis * opposing
	normal_velocity.y = 0.0
	recoil_velocity = unit * tuning.shot_burst_speed * clampf(strength, 0.0, 1.0)
	recoil_burst_remaining = tuning.shot_burst_duration

func clear_recoil() -> void:
	recoil_velocity = Vector2.ZERO
	recoil_burst_remaining = 0.0

func request_drop_through() -> bool:
	if not grounded_contact() or is_instance_valid(_drop_body):
		return false
	for index: int in get_slide_collision_count():
		var collision := get_slide_collision(index)
		var body := collision.get_collider() as PhysicsBody2D
		if collision.get_normal().dot(up_direction) > 0.7 and body != null and body.is_in_group("one_way_platform"):
			var platform_shape := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
			if platform_shape == null or not platform_shape.one_way_collision or not platform_shape.shape is RectangleShape2D:
				continue
			_drop_body = body
			_drop_remaining = tuning.drop_through_duration
			add_collision_exception_with(body)
			normal_velocity.y = maxf(normal_velocity.y, tuning.drop_through_speed)
			return true
	return false

func _advance_drop(delta: float) -> void:
	if not is_instance_valid(_drop_body):
		_drop_body = null
		return
	_drop_remaining -= delta
	# Only restore once the player's entire collision volume is below the
	# platform: never close the exception while still intersecting its top.
	var platform_shape := _drop_body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var player_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if _drop_remaining <= 0.0 and platform_shape != null and player_shape != null:
		var platform_bottom := platform_shape.global_position.y + platform_shape.shape.get_rect().end.y
		var player_top := player_shape.global_position.y + player_shape.shape.get_rect().position.y
		if player_top > platform_bottom:
			_clear_drop()

func _clear_drop() -> void:
	if is_instance_valid(_drop_body):
		remove_collision_exception_with(_drop_body)
	_drop_body = null
	_drop_remaining = 0.0

# Local arena forces have bounded duration and enter the sole movement step.
func queue_local_velocity(value: Vector2, duration: float) -> void:
	if value.is_finite() and is_finite(duration) and duration > 0:
		_local_velocity = value.limit_length(80)
		_local_duration = minf(duration, 0.1)

func clear_local_velocity() -> void:
	_local_velocity = Vector2.ZERO
	_local_duration = 0.0

func request_ability_velocity(value: Vector2) -> void:
	if value.is_finite():
		_ability_velocity = value
		_ability_requested = true

func lock_horizontal(value: float, duration: float) -> void:
	_horizontal_value = value
	_horizontal_lock = duration

func cancel_ability_motion() -> void:
	_ability_requested = false
	_horizontal_lock = 0
	wall_slide_limit = -1
	_blink_requested=false;_blink_motion=Vector2.ZERO;_sustained_recoil=false
	weapon_pause_remaining=0;_weapon_drive_end_pending=false

func start_weapon_burst(unit: Vector2, speed: float, duration: float, grounded: bool = false) -> void:
	if not unit.is_finite() or unit.is_zero_approx() or not is_finite(speed) or speed<=0 or not is_finite(duration) or duration<=0:return
	var motion := ground_shot_motion(unit.normalized()*speed, grounded)
	if motion.is_zero_approx(): return
	cancel_weapon_apex()
	normal_velocity=Vector2.ZERO
	recoil_velocity=motion
	recoil_burst_remaining=duration

# A collision-checked instant displacement is committed inside the sole Motor step.
func request_weapon_blink(motion: Vector2, grounded: bool = false) -> void:
	motion = ground_shot_motion(motion, grounded)
	if not motion.is_finite() or motion.is_zero_approx():return
	reset_motion()
	_blink_motion=motion;_blink_requested=true

func accumulate_weapon_impulse(impulse: Vector2) -> void:
	apply_impulse(impulse)
	_sustained_recoil=true

func cancel_weapon_requests() -> void:
	_blink_requested=false;_blink_motion=Vector2.ZERO;_sustained_recoil=false
	weapon_pause_remaining=0;_weapon_drive_end_pending=false

func _start_weapon_apex() -> void:
	normal_velocity.y=0
	weapon_apex_remaining=weapon_motion.apex_hold_seconds+weapon_motion.apex_blend_seconds
func cancel_weapon_apex() -> void:
	weapon_apex_remaining=0
func _apex_integral(time: float) -> float:
	var age := maxf(0,time-weapon_motion.apex_hold_seconds)
	var blend := weapon_motion.apex_blend_seconds
	if age>=blend:return blend*.5+age-blend
	var x := age/blend
	return blend*(x*x*x-.5*x*x*x*x)
func _weapon_gravity_time(delta: float) -> float:
	if weapon_apex_remaining<=0:return delta
	var total := weapon_motion.apex_hold_seconds+weapon_motion.apex_blend_seconds
	var age := total-weapon_apex_remaining
	weapon_apex_remaining=maxf(0,weapon_apex_remaining-delta)
	return _apex_integral(age+delta)-_apex_integral(age)
func request_weapon_drive(mean_velocity: Vector2, end_velocity: Vector2, grounded: bool = false) -> void:
	mean_velocity = ground_shot_motion(mean_velocity, grounded)
	end_velocity = ground_shot_motion(end_velocity, grounded)
	clear_local_velocity()
	recoil_burst_remaining=0;recoil_velocity=end_velocity;_sustained_recoil=true
	request_ability_velocity(mean_velocity)
func finish_weapon_drive() -> void:
	_weapon_drive_end_pending=true
func stop_weapon_drive() -> void:
	cancel_ability_motion();clear_recoil();_start_weapon_apex()

# A committed damage transaction queues force; only step() moves the body.
func accept_damage_knockback(incoming: Vector2) -> void:
	if not incoming.is_finite(): return
	var side := signf(incoming.x) if absf(incoming.x) > .05 else -signf(normal_velocity.x) if absf(normal_velocity.x) > 1 else -1.0
	cancel_ability_motion()
	clear_recoil()
	cancel_weapon_apex()
	normal_velocity = Vector2.ZERO
	damage_velocity = Vector2(side * damage_feedback.player_knockback.x, damage_feedback.player_knockback.y)
	damage_remaining = damage_feedback.player_knockback_seconds

func exit_bubble() -> bool:
	if not is_instance_valid(bubble_carrier): return false
	var old := bubble_carrier
	bubble_carrier = null
	old.release_passenger(self)
	return true

func world_launch(speed: Vector2) -> void:
	exit_bubble()
	cancel_ability_motion()
	clear_recoil()
	normal_velocity = speed
	velocity = speed

func portal_move(at: Vector2, rotation_delta: float) -> bool:
	var frame := Engine.get_physics_frames()
	if last_portal_step == frame: return false
	last_portal_step = frame
	wind_acceleration = Vector2.ZERO
	wind_cap = 0
	var actual := get_real_velocity().rotated(rotation_delta)
	exit_bubble()
	normal_velocity = normal_velocity.rotated(rotation_delta)
	recoil_velocity = recoil_velocity.rotated(rotation_delta)
	damage_velocity = damage_velocity.rotated(rotation_delta)
	wind_velocity = wind_velocity.rotated(rotation_delta)
	_local_velocity = _local_velocity.rotated(rotation_delta)
	_ability_velocity = _ability_velocity.rotated(rotation_delta)
	_horizontal_lock = 0
	velocity = actual
	# Transport velocity is folded in exactly once, including a moving support.
	if damage_remaining <= 0 and recoil_burst_remaining <= 0:
		normal_velocity = actual - recoil_velocity - wind_velocity
		if _local_duration > 0: normal_velocity -= _local_velocity
	global_position = at
	contacts_current = false
	wall_transport = false
	_clear_drop()
	repositioned.emit()
	return true
