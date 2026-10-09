class_name JumpAbility
extends Node

signal deactivated

@export var enabled := true:
	set(value):
		enabled = value
		if not enabled:
			_buffer_remaining = 0.0
			_immediate_request = false
			deactivated.emit()
var tuning: PlayerTuning
var used_jumps := 0
var _air_max := -1
var _coyote_remaining := 0.0
var _buffer_remaining := 0.0
var _immediate_request := false

func advance(delta: float, grounded: bool) -> void:
	_immediate_request = false
	if _air_max < 0:
		_air_max = tuning.max_jumps
	_air_max = tuning.max_jumps if grounded else mini(_air_max, tuning.max_jumps)
	_buffer_remaining = _decrease_window(_buffer_remaining, delta)
	if grounded:
		_coyote_remaining = tuning.coyote_time
	else:
		_coyote_remaining = _decrease_window(_coyote_remaining, delta)
		if _coyote_remaining <= 0.0 and used_jumps == 0:
			used_jumps = 1

func request_jump() -> void:
	if enabled and tuning.max_jumps > 0:
		_immediate_request = true
		_buffer_remaining = tuning.jump_buffer

func try_jump(motor: PlayerMotor) -> bool:
	if not enabled or (not _immediate_request and _buffer_remaining <= 0.0) or used_jumps >= mini(tuning.max_jumps, _air_max):
		return false
	motor.normal_velocity.y = tuning.jump_speeds[mini(used_jumps, tuning.jump_speeds.size() - 1)]
	used_jumps += 1
	_coyote_remaining = 0.0
	_buffer_remaining = 0.0
	_immediate_request = false
	return true

func on_landed() -> void:
	_air_max = tuning.max_jumps
	used_jumps = 0
	_coyote_remaining = tuning.coyote_time

func cancel_requests() -> void:
	_buffer_remaining = 0.0
	_immediate_request = false

func reset() -> void:
	_air_max = -1
	used_jumps = 0
	_coyote_remaining = 0.0
	_buffer_remaining = 0.0
	_immediate_request = false

# Windows are valid strictly before their duration; equality expires.
# Tolerance only removes floating-point residue at exact fixed-tick boundaries.
func _decrease_window(remaining: float, delta: float) -> float:
	return 0.0 if remaining <= delta + 1.0e-9 else remaining - delta
