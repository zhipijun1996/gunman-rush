class_name PlayerController
extends Node

signal landed
@export var motor: PlayerMotor
@export var router: InputRouter
@export var jump_ability: JumpAbility
var active := true
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
	router.cancelled.connect(_cancel)
	jump_ability.deactivated.connect(_on_jump_disabled)

func _physics_process(delta: float) -> void:
	physics_tick(delta)

func physics_tick(delta: float) -> void:
	_tick += 1
	var actions := router.consume_actions(_tick)
	if not active:
		return
	jump_ability.advance(delta, _was_grounded)
	for action: Dictionary in actions:
		if action.type == &"jump":
			jump_ability.request_jump()
	var jumped := jump_ability.try_jump(motor)
	motor.step(router.sample_axes(), delta)
	var grounded := motor.is_on_floor() and not jumped
	if grounded and not _was_grounded:
		jump_ability.on_landed()
		landed.emit()
		if jump_ability.try_jump(motor):
			grounded = false
	_was_grounded = grounded

func die() -> void:
	active = false
	router.clear("death")
	motor.reset_motion()
	jump_ability.reset()
	_was_grounded = false

func reset_at(location: Vector2) -> void:
	router.clear("respawn")
	motor.reset_at(location)
	jump_ability.reset()
	_was_grounded = false
	active = true

func _cancel(_reason: String) -> void:
	jump_ability.cancel_requests()

func _on_jump_disabled() -> void:
	router.cancel_actions_for(&"jump")
