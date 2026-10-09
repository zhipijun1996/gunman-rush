class_name PlayerController
extends Node

signal landed
signal died
signal interact_requested
@export var air_focus_ability: AirFocusAbility
@export var motor: PlayerMotor
@export var router: InputRouter
@export var jump_ability: JumpAbility
@export var shoot_ability: ShootAbility
@export var action_resources: ActionResources
@export var actor_resources: ActorResources
@export var recoil_ability: RecoilAbility
var action_resource_view := PlayerActionResourceView.new()
var active := true
var session_id := 1
var received_resource_grants: Array[Dictionary] = []
var _tick := 0
var _was_grounded := false

func _ready() -> void:
	var tuning := PlayerTuning.load_default()
	if tuning == null:
		push_error("Player cannot start without valid tuning")
		get_tree().quit(1)
		return
	motor.tuning = tuning
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
	jump_ability.deactivated.connect(_on_jump_disabled)
	shoot_ability.deactivated.connect(_on_shoot_disabled)
	shoot_ability.shot_fired.connect(_on_shot_fired)

func _physics_process(delta: float) -> void:
	var real_delta := delta / Engine.time_scale
	physics_tick(delta)
	air_focus_ability.advance(real_delta, _was_grounded, router.aim_engaged, active and router.has_application_focus and not get_tree().paused)

func physics_tick(delta: float) -> void:
	_tick += 1
	var actions := router.consume_actions(_tick)
	if not active:
		return
	jump_ability.advance(delta, _was_grounded)
	shoot_ability.advance(delta)
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
			jump_ability.request_jump()
		elif action.type == &"jump_release":
			jump_ability.release_jump(motor)
		elif action.type == &"drop_through":
			dropped = motor.request_drop_through()
		elif action.type == &"interact":
			interact_requested.emit()
	var jumped := jump_ability.try_jump(motor)
	var started_grounded := _was_grounded and not jumped and not dropped
	for action: Dictionary in actions:
		if action.type == &"shoot_release":
			shoot_ability.try_fire(action.direction, started_grounded)
	jump_ability.update_hold(delta, motor)
	motor.step(router.sample_axes(), delta)
	jump_ability.after_move(motor)
	var grounded := motor.is_on_floor() and not jumped
	if grounded and not _was_grounded:
		jump_ability.on_landed()
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

func die() -> void:
	if not active:
		return
	active = false
	air_focus_ability.stop()
	session_id += 1
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

func _cancel(_reason: String) -> void:
	jump_ability.cancel_requests()
	air_focus_ability.stop()

func _on_jump_disabled() -> void:
	router.cancel_actions_for(&"jump")
	router.cancel_actions_for(&"jump_release")

func _on_shoot_disabled() -> void:
	router.cancel_actions_for(&"shoot_release")

func _on_shot_fired(_direction: Vector2, _shot_id: int) -> void:
	jump_ability.cancel_ascent()
	air_focus_ability.stop()
