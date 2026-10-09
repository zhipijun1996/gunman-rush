class_name BossEncounter
extends Node

signal defeated(encounter: BossEncounter)
signal projectile_created(projectile: BossProjectile)
signal phase_changed(phase: int)
@export var definition: BossDefinition
@export var motor: BossMotor
@export var damageable: Damageable
var health := HealthState.new()
var arena := BossArena.new()
var phases := BossPhaseController.new()
var pattern := BossAttackPattern.new()
var active := false
var direction := -1
var defeat_id: StringName
var _target: Node2D
var _attack_serial := 0
var _projectiles: Array[BossProjectile] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if definition == null or not definition.is_valid() or motor == null or damageable == null:
		push_error("Boss encounter requires valid local definition/motor/damageable")
		return
	motor.configure(definition)
	health.configure(definition.health_definition)
	damageable.faction = &"enemy"
	damageable.actor_id = motor.get_instance_id()
	damageable.bind_health(health)
	damageable.died.connect(_on_defeat)
	phases.configure(definition)
	pattern.configure(definition, phases.phase)
	defeat_id = StringName("boss-defeat-%s" % motor.get_instance_id())

func configure_arena(left: float, right: float, target: Node2D) -> bool:
	if definition == null or not definition.is_valid() or not arena.configure(left, right, definition.collision_size.x / 2.0):
		return false
	_target = target
	return true

func activate() -> bool:
	if health.terminal or not is_instance_valid(_target) or arena.right_x <= arena.left_x:
		return false
	active = true
	return true

func _physics_process(delta: float) -> void:
	physics_tick(delta)

func physics_tick(delta: float) -> void:
	if not active or health.terminal or not is_finite(delta) or delta <= 0.0:
		return
	if phases.update(health.current, health.capacity):
		_cancel_projectiles()
		pattern.configure(definition, phases.phase)
		phase_changed.emit(phases.phase)
	var limit := arena.travel_limit(motor.global_position.x, direction)
	if limit < 0.01:
		direction *= -1
		limit = arena.travel_limit(motor.global_position.x, direction)
	if motor.step(direction, limit, delta):
		direction *= -1
	if pattern.advance(delta) and is_instance_valid(_target):
		_fire()

func _fire() -> void:
	_projectiles = _projectiles.filter(func(projectile: BossProjectile) -> bool: return is_instance_valid(projectile) and not projectile.spent)
	var aim := (_target.global_position - motor.global_position).normalized()
	var offsets: Array[float] = [0.0]
	if phases.phase == 2:
		offsets.assign([-definition.phase_two_spread, 0.0, definition.phase_two_spread])
	for offset: float in offsets:
		_attack_serial += 1
		var projectile := BossProjectile.new()
		projectile.configure(definition, StringName("%s-attack-%s" % [defeat_id, _attack_serial]), aim.rotated(offset), _target, motor)
		_projectiles.append(projectile)
		projectile_created.emit(projectile)
		motor.get_parent().add_child(projectile)
		projectile.global_position = motor.global_position + aim.rotated(offset) * (definition.collision_size.x * 0.6)

func _cancel_projectiles() -> void:
	for projectile: BossProjectile in _projectiles:
		if is_instance_valid(projectile):
			projectile.dispose()
	_projectiles.clear()

func cancel() -> void:
	active = false
	pattern.cancel()
	_cancel_projectiles()
	if is_instance_valid(motor):
		motor.stop()

func _on_defeat() -> void:
	cancel()
	motor.collision_layer = 0
	motor.collision_mask = 0
	# Coordinator resolves all Health results before choosing win/failure/rewards.
	defeated.emit(self)

func _exit_tree() -> void:
	cancel()
