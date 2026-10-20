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
var damage_feedback: DamageFeedbackDefinition = preload("res://resources/damage/feedback.tres")
var damage_velocity := Vector2.ZERO
var damage_remaining := 0.0
var _blink_motion := Vector2.ZERO
var _blink_requested := false
var _sustained_recoil := false
signal weapon_blinked(start: Vector2, finish: Vector2)

func step(move_axis: float, delta: float) -> void:
	# Accepted hurt owns its short motion window. Firing remains legal, but a
	# burst requested inside it cannot freeze gravity or resume after hurt ends.
	if damage_remaining > 0:
		cancel_ability_motion()
		clear_recoil()
		cancel_weapon_apex()
	var blink_committing := _blink_requested
	_advance_drop(delta)
	var acceleration := tuning.ground_acceleration if is_on_floor() else tuning.air_acceleration
	if is_zero_approx(move_axis) and is_on_floor():
		acceleration = tuning.ground_deceleration
	normal_velocity.x = move_toward(normal_velocity.x, move_axis * tuning.ground_speed, acceleration * delta)
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
	motion_steps += 1
	move_and_slide()
	for index: int in get_slide_collision_count():
		var normal := get_slide_collision(index).get_normal()
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
	reset_motion()

func reset_motion() -> void:
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

func start_shot_burst(direction: Vector2, strength: float = 1.0) -> void:
	if not direction.is_finite() or direction.is_zero_approx():
		return
	cancel_weapon_apex()
	var unit := direction.normalized()
	var opposing := normal_velocity.dot(unit)
	if opposing < 0.0:
		normal_velocity -= unit * opposing
	normal_velocity.y = 0.0
	recoil_velocity = unit * tuning.shot_burst_speed * clampf(strength, 0.0, 1.0)
	recoil_burst_remaining = tuning.shot_burst_duration

func clear_recoil() -> void:
	recoil_velocity = Vector2.ZERO
	recoil_burst_remaining = 0.0

func request_drop_through() -> bool:
	if not is_on_floor() or is_instance_valid(_drop_body):
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

func start_weapon_burst(unit: Vector2, speed: float, duration: float) -> void:
	if not unit.is_finite() or unit.is_zero_approx() or not is_finite(speed) or speed<=0 or not is_finite(duration) or duration<=0:return
	cancel_weapon_apex()
	normal_velocity=Vector2.ZERO
	recoil_velocity=unit.normalized()*speed
	recoil_burst_remaining=duration

# A collision-checked instant displacement is committed inside the sole Motor step.
func request_weapon_blink(motion: Vector2) -> void:
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
func request_weapon_drive(mean_velocity: Vector2, end_velocity: Vector2) -> void:
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
