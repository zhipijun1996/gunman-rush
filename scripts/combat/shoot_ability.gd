class_name ShootAbility
extends Node

signal shot_fired(direction: Vector2, shot_id: int)
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

func advance(delta: float) -> void:
	cooldown_remaining = 0.0 if cooldown_remaining <= delta + 1.0e-9 else cooldown_remaining - delta

func try_fire(direction: Vector2, grounded: bool) -> bool:
	if not enabled or not controller.active or not direction.is_finite() or direction.is_zero_approx() or cooldown_remaining > 0.0:
		return false
	if not resources.try_consume_shot(grounded):
		return false
	var aim := direction.normalized()
	cooldown_remaining = tuning.shot_cooldown
	_shot_serial += 1
	recoil.execute(aim)
	var projectile := PlayerProjectile.new()
	projectile.shot_id = _shot_serial
	projectile.owner_id = controller.motor.get_instance_id()
	projectile.session_id = controller.session_id
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
	shot_fired.emit(aim, _shot_serial)
	return true

func get_projectiles() -> Array[PlayerProjectile]:
	var current: Array[PlayerProjectile] = []
	for projectile: PlayerProjectile in _projectiles:
		if is_instance_valid(projectile) and not projectile.spent:
			current.append(projectile)
	_projectiles = current
	return current

func reset() -> void:
	cooldown_remaining = 0.0
	for projectile: PlayerProjectile in get_projectiles():
		projectile.dispose()
	_projectiles.clear()
