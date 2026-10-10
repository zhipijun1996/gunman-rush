class_name JumpAbility
extends Node

signal jumped
signal deactivated

@export var enabled := true:
	set(value):
		enabled = value
		if not enabled:
			cancel_requests()
			deactivated.emit()
var tuning: PlayerTuning
var used_jumps := 0
var _air_max := -1
var _coyote_remaining := 0.0
var _buffer_remaining := 0.0
var _immediate_request := false
var _pressed := false
var _hold_remaining := 0.0
var _hold_speed := 0.0
var _hold_elapsed := 0.0
var _release_pending := false
var _owns_ascent := false

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
		_pressed = true
		_immediate_request = true
		_buffer_remaining = tuning.jump_buffer

func try_jump(motor: PlayerMotor) -> bool:
	if not enabled or (not _immediate_request and _buffer_remaining <= 0.0) or used_jumps >= mini(tuning.max_jumps, _air_max):
		return false
	if motor.recoil_burst_remaining > 0.0:
		motor.clear_recoil()
	_hold_speed = tuning.jump_speeds[mini(used_jumps, tuning.jump_speeds.size() - 1)]
	motor.normal_velocity.y = _hold_speed
	_hold_elapsed = 0.0
	_owns_ascent = true
	_release_pending = not _pressed
	_hold_remaining = tuning.jump_hold_duration if tuning.variable_jump_enabled else 0.0
	if tuning.variable_jump_enabled and _release_pending and tuning.jump_min_hold_duration <= 0.0:
		motor.normal_velocity.y = maxf(motor.normal_velocity.y, tuning.jump_release_speed)
		_hold_remaining = 0.0
	used_jumps += 1
	_coyote_remaining = 0.0
	_buffer_remaining = 0.0
	_immediate_request = false
	jumped.emit()
	return true

func on_landed() -> void:
	_owns_ascent = false
	_hold_remaining = 0.0
	_air_max = tuning.max_jumps
	used_jumps = 0
	_coyote_remaining = tuning.coyote_time

func cancel_requests() -> void:
	_owns_ascent = false
	_release_pending = false
	_hold_elapsed = 0.0
	_pressed = false
	_hold_remaining = 0.0
	_buffer_remaining = 0.0
	_immediate_request = false

func reset() -> void:
	_owns_ascent = false
	_release_pending = false
	_hold_elapsed = 0.0
	_pressed = false
	_hold_remaining = 0.0
	_air_max = -1
	used_jumps = 0
	_coyote_remaining = 0.0
	_buffer_remaining = 0.0
	_immediate_request = false

# Windows are valid strictly before their duration; equality expires.
# Tolerance only removes floating-point residue at exact fixed-tick boundaries.
func _decrease_window(remaining: float, delta: float) -> float:
	return 0.0 if remaining <= delta + 1.0e-9 else remaining - delta

func release_jump(motor: PlayerMotor) -> void:
	_pressed = false
	_release_pending = _owns_ascent
	if not _release_pending:
		return
	if tuning.variable_jump_enabled and motor.recoil_burst_remaining <= 0.0 and motor.normal_velocity.y < 0.0:
		if _hold_elapsed + 1.0e-9 >= tuning.jump_min_hold_duration or _hold_remaining <= 0.0:
			motor.normal_velocity.y = maxf(motor.normal_velocity.y, tuning.jump_release_speed)
			_hold_remaining = 0.0

func update_hold(delta: float, motor: PlayerMotor) -> void:
	if not enabled or not tuning.variable_jump_enabled or motor.recoil_burst_remaining > 0.0 or motor.normal_velocity.y >= 0.0:
		_owns_ascent = false
		_hold_remaining = 0.0
		return
	if _release_pending and _hold_elapsed + 1.0e-9 >= tuning.jump_min_hold_duration:
		motor.normal_velocity.y = maxf(motor.normal_velocity.y, tuning.jump_release_speed)
		_hold_remaining = 0.0
		return
	if (_pressed or _release_pending) and _hold_remaining > 0.0:
		var held_delta := minf(delta, _hold_remaining)
		motor.normal_velocity.y = lerpf(motor.normal_velocity.y, _hold_speed, held_delta / delta)
		_hold_elapsed += held_delta
		_hold_remaining = maxf(0.0, _hold_remaining - delta)

func after_move(motor: PlayerMotor) -> void:
	if motor.is_on_ceiling() or motor.normal_velocity.y >= 0.0:
		_owns_ascent = false
		_hold_remaining = 0.0

func cancel_ascent() -> void:
	_owns_ascent = false
	_hold_remaining = 0.0
	_release_pending = false
