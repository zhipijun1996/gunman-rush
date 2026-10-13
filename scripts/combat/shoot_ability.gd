class_name ShootAbility
extends Node

signal shot_fired(direction: Vector2, shot_id: int)
signal projectile_impacted(point: Vector2, direction: Vector2)
signal shot_rejected(reason: StringName)
signal deactivated
@export var enabled := true:
	set(value):
		enabled = value
		if not value:
			reset()
			deactivated.emit()
var controller: PlayerController
var resources: ActionResources
var recoil: RecoilAbility
var tuning: PlayerTuning
var cooldown_remaining := 0.0
var _shot_serial := 0
var _projectiles: Array[PlayerProjectile] = []
var weapon: WeaponDefinition = preload("res://resources/weapons/pulse_gun.tres")
var packet_id := 0
var rounds_remaining := 0
var packet_direction := Vector2.RIGHT
var _round_timer := 0.0
var _packet_session := 0
signal packet_changed(state: StringName, packet: int)

func equip(definition: WeaponDefinition) -> bool:
	if definition == null or not definition.is_valid(): return false
	cancel_packet(&"equipment")
	clear_projectiles()
	weapon = definition
	var visual := controller.motor.get_node_or_null("CourierVisual") as CourierVisual
	if visual: visual.weapon_tier = definition.tier
	return true

func cancel_packet(reason: StringName) -> void:
	if rounds_remaining > 0: packet_changed.emit(reason,packet_id)
	rounds_remaining = 0
	_round_timer = 0

func advance(delta: float) -> void:
	if rounds_remaining > 0:
		if not controller.active or controller.session_id != _packet_session or not controller.router.has_application_focus:
			cancel_packet(&"cancelled")
		else:
			_round_timer -= delta
			if _round_timer <= 1.0e-9:
				var aim := controller.router.aim_direction
				if not aim.is_zero_approx(): packet_direction = aim
				_emit_round(packet_direction,controller.motor.is_on_floor())
				rounds_remaining -= 1
				_round_timer += weapon.interval
				if rounds_remaining == 0: packet_changed.emit(&"complete",packet_id)
	cooldown_remaining = 0.0 if cooldown_remaining <= delta + 1.0e-9 else cooldown_remaining - delta

func try_fire(direction: Vector2, grounded: bool) -> bool:
	if not enabled or not controller.active or not direction.is_finite() or direction.is_zero_approx():
		return false
	if cooldown_remaining > 0.0 or rounds_remaining > 0:
		shot_rejected.emit(&"cooldown")
		return false
	if controller.shot_energy!=null and not controller.shot_energy.can_fire():
		shot_rejected.emit(&"energy")
		return false
	if not resources.try_consume_shot(grounded):
		shot_rejected.emit(&"empty")
		return false
	packet_direction = direction.normalized()
	packet_id = _shot_serial + 1
	_packet_session = controller.session_id
	if controller.shot_energy != null:
		if not controller.shot_energy.consume(packet_id): return false
	cooldown_remaining = maxf(tuning.shot_cooldown,weapon.interval * (weapon.rounds-1)+weapon.burst_duration)
	rounds_remaining = weapon.rounds-1
	_round_timer = weapon.interval
	packet_changed.emit(&"started",packet_id)
	_emit_round(packet_direction,grounded)
	return true

func _emit_round(aim: Vector2, grounded: bool) -> void:
	var muzzle := controller.motor.global_position
	var visual := controller.motor.get_node_or_null("CourierVisual") as CourierVisual
	if visual: muzzle = visual.muzzle_position(aim)
	_shot_serial += 1
	if weapon.rounds == 1:
		recoil.execute(aim,grounded)
	elif recoil.enabled:
		var strength := weapon.recoil_scale * (tuning.ground_recoil_multiplier if grounded else 1.0)
		controller.motor.start_shot_burst(-aim,strength)
		controller.motor.recoil_burst_remaining = weapon.burst_duration
	var projectile := PlayerProjectile.new()
	projectile.impacted.connect(func(point: Vector2, hit_direction: Vector2) -> void: projectile_impacted.emit(point,hit_direction))
	projectile.shot_id = _shot_serial
	projectile.energy_receipt_id = packet_id
	projectile.owner_id = controller.motor.get_instance_id()
	projectile.session_id = controller.session_id
	projectile.fired_airborne = not grounded
	projectile.owner_controller = controller
	projectile.owner_body = controller.motor
	projectile.direction = aim
	projectile.speed = tuning.projectile_speed
	projectile.radius = tuning.projectile_radius
	projectile.damage = tuning.projectile_damage
	projectile.lifetime = tuning.projectile_lifetime
	controller.motor.get_parent().add_child(projectile)
	projectile.global_position = controller.motor.global_position
	get_projectiles()
	_projectiles.append(projectile)
	shot_fired.emit(aim,_shot_serial)
	if visual: projectile.launch_motion = muzzle-projectile.global_position

func get_projectiles() -> Array[PlayerProjectile]:
	var current: Array[PlayerProjectile] = []
	for projectile: PlayerProjectile in _projectiles:
		if is_instance_valid(projectile) and not projectile.spent:
			current.append(projectile)
	_projectiles = current
	return current

func reset() -> void:
	cancel_packet(&"reset")
	cooldown_remaining = 0.0
	clear_projectiles()

func clear_projectiles() -> void:
	for projectile: PlayerProjectile in get_projectiles():
		projectile.dispose()
	_projectiles.clear()
