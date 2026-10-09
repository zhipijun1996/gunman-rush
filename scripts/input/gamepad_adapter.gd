class_name GamepadAdapter
extends Node

enum AimState { WAIT_NEUTRAL, READY, ARMED, CENTER_PENDING }
@export var router: InputRouter
@export var aim_origin: Node2D
var state := AimState.WAIT_NEUTRAL
var last_valid_direction := Vector2.ZERO
var connected_device := -1
var _arm_ticks := 0
var _center_ticks := 0
var _vertical_ready := true
var _jump_held := false
var _jump_blocked := false

func _ready() -> void:
	router.cancelled.connect(_cancel)
	Input.joy_connection_changed.connect(_connection_changed)

func _physics_process(_delta: float) -> void:
	var devices := Input.get_connected_joypads()
	if connected_device < 0:
		if devices.is_empty():
			return
		connected_device = devices[0]
		_cancel("connected")
	var left := Vector2(Input.get_joy_axis(connected_device, JOY_AXIS_LEFT_X), Input.get_joy_axis(connected_device, JOY_AXIS_LEFT_Y))
	var right := Vector2(Input.get_joy_axis(connected_device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(connected_device, JOY_AXIS_RIGHT_Y))
	sample_tick(left, right, Input.is_joy_button_pressed(connected_device, int(router.profile.values.gamepad_jump_button)))

func sample_tick(raw_left: Vector2, raw_right: Vector2, jump_pressed: bool = false) -> void:
	if is_inside_tree() and get_tree().paused:
		return
	if not raw_left.is_finite() or not raw_right.is_finite():
		router.clear("invalid_gamepad_sample")
		return
	var profile := router.profile
	var left := profile.axis(raw_left, "left_sensitivity")
	var right := profile.axis(raw_right, "right_sensitivity")
	var active_left := left.length() > float(profile.values.left_deadzone)
	var active_right := right.length() >= float(profile.values.right_enter_deadzone)
	if active_left or (active_right and state != AimState.WAIT_NEUTRAL) or (jump_pressed and not _jump_held and not _jump_blocked):
		router.activate_device(&"gamepad")
	router.set_source_axis(&"gamepad", left.x if active_left else 0.0)
	if absf(left.y) < 0.35:
		_vertical_ready = true
	elif absf(left.y) >= 0.65 and _vertical_ready:
		_vertical_ready = false
		router.request_action(&"interact" if left.y < 0.0 else &"drop_through")
	if not jump_pressed:
		_jump_blocked = false
	elif not _jump_held and not _jump_blocked:
		router.request_action(&"jump")
	_jump_held = jump_pressed
	var centered := right.length() <= float(profile.values.right_exit_deadzone)
	match state:
		AimState.WAIT_NEUTRAL:
			_center_ticks = _center_ticks + 1 if centered else 0
			if _center_ticks >= int(profile.values.center_confirm_ticks):
				state = AimState.READY
				_center_ticks = 0
		AimState.READY:
			_arm_ticks = _arm_ticks + 1 if active_right else 0
			if active_right:
				last_valid_direction = _world_direction(right)
			if _arm_ticks >= int(profile.values.arm_confirm_ticks):
				state = AimState.ARMED
				_arm_ticks = 0
		AimState.ARMED:
			if active_right:
				last_valid_direction = _world_direction(right)
			if centered:
				state = AimState.CENTER_PENDING
				_center_ticks = 1
		AimState.CENTER_PENDING:
			if centered:
				_center_ticks += 1
			else:
				state = AimState.ARMED
				_center_ticks = 0
				if active_right:
					last_valid_direction = _world_direction(right)
	if state == AimState.CENTER_PENDING and _center_ticks >= int(profile.values.center_confirm_ticks):
		router.request_action(&"shoot_release", last_valid_direction)
		state = AimState.READY
		_center_ticks = 0
		last_valid_direction = Vector2.ZERO
	router.set_aim(&"gamepad", _world_direction(right) if active_right and state != AimState.WAIT_NEUTRAL else Vector2.ZERO)

func _world_direction(axis: Vector2) -> Vector2:
	if not is_instance_valid(aim_origin):
		return axis.normalized()
	var inverse := aim_origin.get_canvas_transform().affine_inverse()
	return ((inverse * axis) - (inverse * Vector2.ZERO)).normalized()

func _cancel(_reason: String) -> void:
	state = AimState.WAIT_NEUTRAL
	last_valid_direction = Vector2.ZERO
	_arm_ticks = 0
	_center_ticks = 0
	_vertical_ready = true
	_jump_blocked = _jump_blocked or _jump_held or (connected_device >= 0 and Input.is_joy_button_pressed(connected_device, int(router.profile.values.gamepad_jump_button)))
	_jump_held = false

func _connection_changed(device: int, connected: bool) -> void:
	if not connected and device == connected_device:
		connected_device = -1
		router.clear("gamepad_disconnected")
