class_name PlayerController
extends Node

signal landed
signal died
signal interact_requested
signal segment_returned
signal energy_recovered(amount: float, airborne: bool)
## Presentation receipt: emitted only by the existing successful damage callback.
signal weapon_damage_committed(packet: int, shot: int, receiver: Damageable, source_session: int, source_weapon_epoch: int)
@export var air_focus_ability: AirFocusAbility
@export var motor: PlayerMotor
@export var router: InputRouter
@export var jump_ability: JumpAbility
@export var shoot_ability: ShootAbility
@export var action_resources: ActionResources
@export var actor_resources: ActorResources
@export var recoil_ability: RecoilAbility
var action_resource_view := PlayerActionResourceView.new()
var combat_energy := CombatEnergyState.new()
var traversal: TraversalAbility
var shot_energy: ShotEnergyPolicy
var active := true
var session_id := 1
var received_resource_grants: Array[Dictionary] = []
var _tick := 0
var _was_grounded := false
var _air_hit_receipts: Dictionary = {}

func _ready() -> void:
	var tuning := PlayerTuning.load_default()
	if tuning == null:
		push_error("Player cannot start without valid tuning")
		get_tree().quit(1)
		return
	motor.tuning = tuning
	traversal = TraversalAbility.new()
	traversal.name = "TraversalAbility"
	add_child(traversal)
	traversal.configure(self)
	actor_resources.health.changed.connect(func(result: ActorResourceResult) -> void:
		if result.operation == &"damage" and result.status == ActorResourceResult.Status.APPLIED and result.amount_applied < 0:
			shoot_ability.cancel_packet(&"hurt")
			traversal.cancel())
	jump_ability.tuning = tuning
	action_resources.tuning = tuning
	action_resources.reset()
	if actor_resources == null or not actor_resources.configure(StaminaDefinition.from_focus_prototype(tuning)):
		push_error("Player cannot start without valid actor resource definitions")
		get_tree().quit(1)
		return
	action_resource_view.bind(jump_ability, action_resources)
	air_focus_ability.configure(tuning, actor_resources.stamina)
	recoil_ability.motor = motor
	shoot_ability.controller = self
	shoot_ability.resources = action_resources
	shoot_ability.recoil = recoil_ability
	shoot_ability.tuning = tuning
	router.cancelled.connect(_cancel)
	jump_ability.jumped.connect(traversal.on_jump_executed)
	jump_ability.deactivated.connect(_on_jump_disabled)
	shoot_ability.deactivated.connect(_on_shoot_disabled)
	shoot_ability.shot_fired.connect(_on_shot_fired)

func _physics_process(delta: float) -> void:
	var real_delta := delta / Engine.time_scale
	physics_tick(delta)
	var blade_focus := shoot_ability.behavior().steering_focus()
	air_focus_ability.advance(real_delta, _was_grounded, router.aim_engaged, active and router.has_application_focus and not get_tree().paused and not traversal.busy(), blade_focus, shoot_ability.weapon.steering_focus_drain_ratio if blade_focus else 1.0)

func physics_tick(delta: float) -> void:
	_tick += 1
	var actions := router.consume_actions(_tick)
	if not active:
		return
	traversal.advance(delta)
	router.grapple_available = traversal.hook_enabled
	router.weapon_skill_available=shoot_ability.weapon.tier==3
	var items := shoot_ability.behavior().current_entities()
	router.weapon_context_available=not items.is_empty() and ((items[0].kind==&"boomerang" and items[0].phase in [&"outbound",&"auto_return"]) or (items[0].kind==&"mine" and items[0].phase==&"attached"))
	router.weapon_context_label="RECALL" if not items.is_empty() and items[0].kind==&"boomerang" else "DETONATE"
	jump_ability.advance(delta, _was_grounded)
	shoot_ability.advance(delta)
	if shot_energy!=null and router.has_application_focus and not get_tree().paused:
		shot_energy.advance(delta,_was_grounded)
	action_resources.advance(_was_grounded)
	for grant: Dictionary in received_resource_grants:
		var source_guard: Callable = grant.get("source_valid", Callable())
		var source_available: bool = source_guard.is_null() or (source_guard.is_valid() and source_guard.call() == true)
		if grant.session_id == session_id and source_available:
			var actual := action_resources.grant_shot(grant.amount)
			if grant.get("on_resolved", Callable()).is_valid():
				grant.on_resolved.call(actual)
		elif grant.get("on_resolved", Callable()).is_valid():
			grant.on_resolved.call(0)
	received_resource_grants.clear()
	var dropped := false
	for action: Dictionary in actions:
		if action.type == &"jump":
			if not shoot_ability.behavior().locks_movement():
				if not traversal.release_hang_for_jump() and not traversal.busy():
					jump_ability.request_jump()
		elif action.type == &"jump_release":
			jump_ability.release_jump(motor)
		elif action.type == &"drop_through":
			dropped = motor.request_drop_through()
		elif action.type == &"interact":
			interact_requested.emit()
	for action: Dictionary in actions:
		if action.type == &"grapple" and not shoot_ability.behavior().locks_movement(): traversal.request_hook(action.direction, action)
	var wall_jumped := false
	for action: Dictionary in actions:
		if action.type == &"jump" and traversal.wall_jump():
			wall_jumped = true
			jump_ability.cancel_requests()
	var weapon_locked := shoot_ability.behavior().locks_movement()
	var jumped := wall_jumped or (not weapon_locked and not traversal.busy() and motor.weapon_pause_remaining<=0 and jump_ability.try_jump(motor))
	var started_grounded := _was_grounded and not jumped and not dropped
	for action: Dictionary in actions:
		if action.type == &"shoot_release" and shoot_ability.weapon.mode != WeaponDefinition.Mode.LASER and not weapon_locked and not traversal.busy():
			shoot_ability.try_fire(action.direction, started_grounded)
	for action: Dictionary in actions:
		if action.type == &"weapon_context": shoot_ability.behavior().context()
		elif action.type == &"weapon_skill" and not traversal.busy() and not weapon_locked:
			shoot_ability.behavior().begin(action.direction if not action.direction.is_zero_approx() else Vector2.UP,started_grounded,true)
	if shoot_ability.weapon.mode==WeaponDefinition.Mode.LASER and router.aim_mode==&"attack" and router.aim_engaged and not traversal.busy() and not weapon_locked and not shoot_ability.behavior().occupied() and not shoot_ability.behavior()._beam_require_release and shoot_ability.cooldown_remaining<=0:
		shoot_ability.try_fire(router.aim_direction,started_grounded)
	jump_ability.update_hold(delta, motor)
	var requested_recoil := motor.recoil_velocity
	motor.step(router.sample_axes(), delta)
	traversal.after_move()
	if motor.get_slide_collision_count() > 0 and shoot_ability.rounds_remaining > 0:
		for index: int in motor.get_slide_collision_count():
			if (absf(motor.get_slide_collision(index).get_normal().x) > .7 or motor.get_slide_collision(index).get_normal().y > .7) and motor.get_slide_collision(index).get_normal().dot(requested_recoil) < -.1:
				shoot_ability.cancel_packet(&"blocked")
	jump_ability.after_move(motor)
	var grounded := motor.is_on_floor() and not jumped
	if grounded and not _was_grounded:
		jump_ability.on_landed()
		traversal.on_landed()
		landed.emit()
		if jump_ability.try_jump(motor):
			grounded = false
	# A buffered landing launches immediately, so restore before the new flight.
	if not _was_grounded and motor.is_on_floor() and not jumped:
		action_resources.reset()
	action_resources.finish_frame(grounded, started_grounded)
	_was_grounded = grounded

func queue_grant(amount: int, expected_session: int = -1, on_resolved: Callable = Callable(), source_valid: Callable = Callable()) -> void:
	if active:
		received_resource_grants.append({"amount": amount, "session_id": session_id if expected_session < 0 else expected_session, "on_resolved": on_resolved, "source_valid": source_valid})
	elif on_resolved.is_valid():
		on_resolved.call(0)

func enable_shot_energy(config: ShotEnergyDefinition = null) -> bool:
	if shot_energy!=null: return true
	var value:=ShotEnergyPolicy.new()
	var definition := config if config != null else preload("res://resources/player/demo_ui_01/time_energy_v2.tres")
	if not definition.is_valid(): return false
	# Only an explicit historical fixture retains the old split shot economy.
	if definition.shooting_consumes_energy:
		air_focus_ability.configure(motor.tuning,StaminaState.new())
	if not value.configure(self,definition): return false
	shot_energy=value
	shot_energy.recovered.connect(func(amount: float,airborne: bool): energy_recovered.emit(amount,airborne))
	return true

func on_projectile_hit(expected_session: int, shot_id: int, airborne: bool, movement_shot_id: int = 0, enemy_hit: bool = true) -> void:
	if not active or actor_resources.health.terminal or expected_session != session_id: return
	if shot_energy!=null: shot_energy.on_hit(expected_session,shot_id,airborne)
	if not airborne or not enemy_hit or motor.is_on_floor(): return
	var receipt := movement_shot_id if movement_shot_id > 0 else shot_id
	if _air_hit_receipts.has(receipt): return
	_air_hit_receipts[receipt] = true
	traversal.restore_air_actions()

func on_weapon_damage(expected_session: int, packet: int, shot: int, airborne: bool, target: int, skill: bool = false, receiver: Damageable = null, weapon_epoch: int = -1) -> void:
	if not active or actor_resources.health.terminal or expected_session!=session_id or (weapon_epoch>=0 and weapon_epoch!=shoot_ability.weapon_epoch):return
	on_projectile_hit(expected_session,packet,airborne,shot,target!=0)
	if target!=0:combat_energy.committed_hit("%s/%s" % [expected_session,packet],target,skill)
	if skill and is_instance_valid(receiver):
		var enemy := receiver.get_parent().get_node_or_null("Actor") as EnemyActor
		if enemy!=null:
			var def := shoot_ability.weapon
			enemy.apply_skill_impact((enemy.motor.global_position-motor.global_position).normalized(),def.skill_stagger_seconds,def.skill_stagger_cooldown,def.skill_knockback_speed if def.mode==WeaponDefinition.Mode.FAN else 0,def.skill_knockback_seconds)
	if target!=0 and is_instance_valid(receiver): weapon_damage_committed.emit(packet,shot,receiver,expected_session,weapon_epoch)

func die() -> void:
	combat_energy.reset()
	if not active:
		return
	active = false
	air_focus_ability.stop()
	session_id += 1
	_air_hit_receipts.clear()
	router.clear("death")
	motor.reset_motion()
	jump_ability.reset()
	shoot_ability.reset()
	action_resources.reset()
	action_resources.shot_charges = 0
	for grant: Dictionary in received_resource_grants:
		if grant.get("on_resolved", Callable()).is_valid():
			grant.on_resolved.call(0)
	received_resource_grants.clear()
	_was_grounded = false
	died.emit()

func reset_at(location: Vector2) -> void:
	# Historical graybox restart only; future SegmentRespawn must not call this.
	actor_resources.reset_legacy_health()
	air_focus_ability.reset()
	session_id += 1
	_air_hit_receipts.clear()
	router.clear("respawn")
	motor.reset_at(location)
	jump_ability.reset()
	shoot_ability.reset()
	action_resources.reset()
	for grant: Dictionary in received_resource_grants:
		if grant.get("on_resolved", Callable()).is_valid():
			grant.on_resolved.call(0)
	received_resource_grants.clear()
	_was_grounded = false
	active = true

func return_to_segment(location: Vector2) -> bool:
	if not active or actor_resources.health.terminal or not location.is_finite():
		return false
	# Selective reset: HP, stamina, cooldown and stage services survive.
	air_focus_ability.stop()
	session_id += 1
	_air_hit_receipts.clear()
	router.clear("segment_return")
	motor.reset_at(location)
	jump_ability.reset()
	shoot_ability.clear_projectiles()
	action_resources.reset()
	for grant: Dictionary in received_resource_grants:
		if grant.get("on_resolved", Callable()).is_valid():
			grant.on_resolved.call(0)
	received_resource_grants.clear()
	_was_grounded = false
	segment_returned.emit()
	return true

func _cancel(_reason: String) -> void:
	shoot_ability.cancel_packet(StringName(_reason))
	if traversal != null: traversal.cancel()
	jump_ability.cancel_requests()
	air_focus_ability.stop()

func _on_jump_disabled() -> void:
	router.cancel_actions_for(&"jump")
	router.cancel_actions_for(&"jump_release")

func _on_shoot_disabled() -> void:
	router.cancel_actions_for(&"shoot_release")

func _on_shot_fired(_direction: Vector2, _shot_id: int) -> void:
	traversal.on_weapon_fired()
	jump_ability.cancel_ascent()
	air_focus_ability.stop()

func on_grapple_damage(expected_session: int, packet: int, target: int) -> void:
	if not active or actor_resources.health.terminal or expected_session!=session_id:return
	combat_energy.committed_hit("%s/hook/%s" % [expected_session,packet],target)
