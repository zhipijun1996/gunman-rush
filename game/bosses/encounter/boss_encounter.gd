class_name BossEncounter
extends Node

signal defeated(encounter: BossEncounter)
signal projectile_created(projectile: BossProjectile)
signal phase_changed(phase: int)
signal presentation_event(event: Dictionary)
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

func body_contact_enabled() -> bool:
	return active and not health.terminal

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
	for index: int in range(_projectiles.size()-1,-1,-1):
		if not is_instance_valid(_projectiles[index]) or _projectiles[index].spent: _projectiles.remove_at(index)
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

func _presentation_values() -> Dictionary:
	# Fresh values only: presenters receive no live combat objects.
	return {"active":active,"terminal":health.terminal,"health_epoch":health.epoch,"position":motor.global_position if is_instance_valid(motor) else Vector2.ZERO,"direction":float(direction),"phase":phases.phase,"phase_axes":{"combat":phases.phase},"damage_model":&"body","body_contact_enabled":body_contact_enabled()}

func _presentation_countdown(values: Dictionary, state: StringName, remaining: float, warning_duration: float, is_warning: bool, releases: bool, sustains: bool, recovers: bool, domain: StringName = &"encounter") -> BossPresentationState:
	# Raw time is unchanged, including negative boundary samples. Only progress
	# is normalized. The owning family supplies state and semantic flags.
	values.merge({"state_id":state,"raw_mode":state,"state_source":domain,"raw_clock":remaining,"clock_kind":&"countdown","clock_domain":domain,"telegraph_duration":warning_duration,"telegraphing":is_warning,"warning_progress":clampf(1.0-remaining/maxf(.01,warning_duration),0.0,1.0) if is_warning else 0.0,"release_action":releases,"sustained_action":sustains,"recovery_active":recovers},true)
	return BossPresentationState.new(values)

func presentation_state() -> BossPresentationState:
	var values := _presentation_values()
	var attack := pattern.presentation_clock()
	# Clockwork has no raw mode: the ID names its actual pattern branch and
	# state_source explicitly identifies that distinction for every consumer.
	values.merge({"state_id":&"projectile_warning" if attack.telegraphing else &"patrol","raw_mode":&"","state_source":&"attack_pattern","raw_clock":attack.elapsed,"clock_kind":&"elapsed","clock_domain":&"attack_pattern","telegraph_duration":attack.warning_duration,"telegraphing":attack.telegraphing,"warning_progress":attack.warning_progress},true)
	return BossPresentationState.new(values)

func presentation_capabilities() -> PackedStringArray:
	return PackedStringArray(["attack_pattern"])

func presentation_bell() -> Dictionary:
	return {}

func presentation_bell_warning() -> Dictionary:
	return {}

func presentation_pursuit_warning() -> Dictionary:
	return {}

func presentation_motion_preview() -> Dictionary:
	return {}

func presentation_knots() -> Array[Dictionary]:
	return []
