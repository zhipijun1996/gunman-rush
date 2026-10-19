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
var weapon_epoch := 0
var packet_id := 0
var last_muzzle := Vector2.ZERO
var rounds_remaining := 0
var packet_direction := Vector2.RIGHT
var _round_timer := 0.0
var _packet_session := 0
var _packet_grounded := false
var runtime: WeaponActionRuntime

func behavior() -> WeaponActionRuntime:
	if runtime == null:
		runtime=WeaponActionRuntime.new();runtime.ability=self;add_child(runtime)
	return runtime

signal packet_changed(state: StringName, packet: int)

func equip(definition: WeaponDefinition) -> bool:
	if definition == null or not definition.is_valid(): return false
	controller.router.clear("weapon_changed")
	cancel_packet(&"equipment")
	clear_projectiles()
	weapon_epoch+=1
	weapon = definition
	var visual := controller.motor.get_node_or_null("CourierVisual") as CourierVisual
	if visual:
		visual.weapon_tier = definition.tier
		visual.weapon_mode = definition.mode
	return true

func cancel_packet(reason: StringName) -> void:
	if runtime != null: runtime.cancel(reason)
	if rounds_remaining > 0: packet_changed.emit(reason,packet_id)
	rounds_remaining = 0
	_round_timer = 0

func advance(delta: float) -> void:
	behavior().advance(delta)
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
	if weapon.mode >= WeaponDefinition.Mode.LASER: return behavior().begin(direction,grounded)
	if behavior().occupied():shot_rejected.emit(&"weapon_busy");return false
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
	_packet_grounded=grounded
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
	last_muzzle = muzzle
	_shot_serial += 1
	if weapon.rounds == 1:
		recoil.execute(aim,grounded)
	elif recoil.enabled:
		var motion := controller.motor.weapon_motion
		var distance := motion.base_distance(tuning,_packet_grounded)*motion.lv2_total_ratio/weapon.rounds
		controller.motor.start_weapon_burst(-aim,distance/weapon.burst_duration,weapon.burst_duration)
	var projectile := PlayerProjectile.new()
	projectile.impacted.connect(func(point: Vector2, hit_direction: Vector2) -> void: projectile_impacted.emit(point,hit_direction))
	projectile.shot_id = _shot_serial
	projectile.energy_receipt_id = packet_id
	projectile.owner_id = controller.motor.get_instance_id()
	projectile.session_id = controller.session_id
	projectile.fired_airborne = not grounded
	projectile.weapon_epoch=weapon_epoch
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

func reserve_packet(direction: Vector2, grounded: bool) -> bool:
	if not enabled or not controller.active or cooldown_remaining>0 or rounds_remaining>0:return false
	if controller.shot_energy!=null and not controller.shot_energy.can_fire():shot_rejected.emit(&"energy");return false
	if not resources.try_consume_shot(grounded):shot_rejected.emit(&"empty");return false
	_shot_serial+=1;packet_id=_shot_serial;_packet_session=controller.session_id;packet_direction=direction
	if controller.shot_energy!=null and not controller.shot_energy.consume(packet_id):return false
	cooldown_remaining=tuning.shot_cooldown
	packet_changed.emit(&"started",packet_id)
	return true
func emit_special_projectile(aim: Vector2, skill: bool, art_kind: StringName) -> void:
	_shot_serial+=1
	var projectile := PlayerProjectile.new()
	projectile.impacted.connect(func(point: Vector2, unit: Vector2)->void:projectile_impacted.emit(point,unit))
	projectile.shot_id=_shot_serial;projectile.energy_receipt_id=packet_id;projectile.owner_id=controller.motor.get_instance_id();projectile.session_id=controller.session_id
	projectile.weapon_epoch=weapon_epoch
	projectile.owner_controller=controller;projectile.owner_body=controller.motor;projectile.fired_airborne=not controller.motor.is_on_floor()
	projectile.direction=aim;projectile.speed=weapon.projectile_speed;projectile.damage=(weapon.skill_damage if skill else weapon.damage)*tuning.projectile_damage;projectile.lifetime=weapon.range_limit/weapon.projectile_speed
	projectile.art_kind=art_kind;projectile.skill_attack=skill;projectile.radius=5 if art_kind==&"blade" else tuning.projectile_radius
	controller.motor.get_parent().add_child(projectile);var origin := controller.motor.global_position
	projectile.global_position=origin
	var visual := controller.motor.get_node("CourierVisual") as CourierVisual
	if art_kind==&"blade":
		visual.set_state(&"blade_throw");visual.elapsed=maxf(visual.elapsed,1.0/float(visual._action_catalog.states.blade_throw.fps))
	elif weapon.mode==WeaponDefinition.Mode.MACHINE:visual.set_state(&"machine_recoil")
	projectile.launch_motion=visual.muzzle_position(aim)-origin
	_projectiles.append(projectile);last_muzzle=origin+projectile.launch_motion;shot_fired.emit(aim,_shot_serial)
