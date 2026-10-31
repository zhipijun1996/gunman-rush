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
var _context_held := false
var _skill_held := false
var _context_blocked := false
var _skill_blocked := false
var _item_skill_held := false
var _item_skill_blocked := false
var _hook_held := false
var _hook_blocked := false
var _hook_direction := Vector2.ZERO

func _ready() -> void:
	router.cancelled.connect(_cancel)
	router.device_changed.connect(_device_changed)
	Input.joy_connection_changed.connect(_connection_changed)

func _physics_process(_delta: float) -> void:
	if not router.has_application_focus:
		return
	var devices := Input.get_connected_joypads()
	if connected_device < 0:
		if devices.is_empty():
			return
		connected_device = devices[0]
		_cancel("connected")
	var left := Vector2(Input.get_joy_axis(connected_device, JOY_AXIS_LEFT_X), Input.get_joy_axis(connected_device, JOY_AXIS_LEFT_Y))
	var right := Vector2(Input.get_joy_axis(connected_device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(connected_device, JOY_AXIS_RIGHT_Y))
	sample_tick(left, right, Input.is_joy_button_pressed(connected_device, int(router.profile.values.gamepad_jump_button)),Input.is_joy_button_pressed(connected_device,JOY_BUTTON_LEFT_SHOULDER),Input.is_joy_button_pressed(connected_device,JOY_BUTTON_X),Input.is_joy_button_pressed(connected_device,JOY_BUTTON_Y),Input.is_joy_button_pressed(connected_device,JOY_BUTTON_RIGHT_SHOULDER))

func sample_tick(raw_left: Vector2, raw_right: Vector2, jump_pressed: bool = false, hook_pressed: bool = false, context_pressed: bool = false, skill_pressed: bool = false, item_skill_pressed: bool = false) -> void:
	if not router.has_application_focus or (is_inside_tree() and get_tree().paused):
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
	router.set_look_axis(&"gamepad", left.y if active_left else 0.0)
	if absf(left.y) < 0.35:
		_vertical_ready = true
	elif absf(left.y) >= 0.65 and _vertical_ready:
		_vertical_ready = false
		router.request_action(&"interact" if left.y < 0.0 else &"drop_through")
	if not jump_pressed:
		if _jump_held and not _jump_blocked:
			router.set_jump_held(&"gamepad", false)
		_jump_blocked = false
	elif not _jump_held and not _jump_blocked:
		router.set_jump_held(&"gamepad", true)
	_jump_held = jump_pressed
	if not context_pressed:_context_blocked=false
	if not skill_pressed:_skill_blocked=false
	if not item_skill_pressed:_item_skill_blocked=false
	if context_pressed and not _context_held and not _context_blocked:
		router.activate_device(&"gamepad");router.request_action(&"weapon_context")
	if skill_pressed and not _skill_held and not _skill_blocked:
		router.activate_device(&"gamepad");router.request_action(&"weapon_skill",_world_direction(right) if active_right else router.skill_direction())
		state=AimState.WAIT_NEUTRAL
	if item_skill_pressed and not _item_skill_held and not _item_skill_blocked and router.item_skill_available:
		router.activate_device(&"gamepad")
		router.request_action(&"item_skill",_world_direction(right) if active_right else router.skill_direction())
		state = AimState.WAIT_NEUTRAL
		_arm_ticks = 0
		_center_ticks = 0
		last_valid_direction = Vector2.ZERO
	_context_held=context_pressed;_skill_held=skill_pressed
	_item_skill_held = item_skill_pressed
	if _hook_blocked:
		if hook_pressed: return
		_hook_blocked = false
		state = AimState.WAIT_NEUTRAL
		_center_ticks = 0
	if hook_pressed and not _hook_held and not _hook_blocked and router.grapple_available:
		router.activate_device(&"gamepad")
		_hook_direction = _world_direction(right) if active_right else Vector2.ZERO
		router.cancel_actions_for(&"shoot_release")
		state = AimState.WAIT_NEUTRAL
		_arm_ticks = 0
		_center_ticks = 0
		last_valid_direction = Vector2.ZERO
	if hook_pressed and not _hook_blocked and router.grapple_available:
		_hook_held = true
		if active_right: _hook_direction = _world_direction(right)
		router.aim_mode = &"grapple"
		router.set_aim(&"gamepad", _hook_direction, true)
		return
	if not hook_pressed and _hook_held:
		_hook_held = false
		if not _hook_blocked and router.grapple_available:
			if active_right: _hook_direction = _world_direction(right)
			router.request_action(&"grapple", _hook_direction)
		_hook_direction = Vector2.ZERO
		router.aim_mode = &"attack"
		router.set_aim(&"gamepad", Vector2.ZERO, false)
		# Require a fresh neutral stick after H; centering its aim must not shoot.
		state = AimState.WAIT_NEUTRAL
		_center_ticks = 0
	if not hook_pressed: _hook_blocked = false
	if _hook_held and not router.grapple_available:
		_hook_blocked = hook_pressed
		_hook_held = false
		_hook_direction = Vector2.ZERO
		router.aim_mode = &"attack"
		router.set_aim(&"gamepad", Vector2.ZERO, false)
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
		router.primary_release(last_valid_direction)
		state = AimState.READY
		_center_ticks = 0
		last_valid_direction = Vector2.ZERO
	router.set_aim(&"gamepad", _world_direction(right) if active_right else Vector2.ZERO, state == AimState.ARMED and active_right)

func _world_direction(axis: Vector2) -> Vector2:
	if not is_instance_valid(aim_origin):
		return axis.normalized()
	var inverse := aim_origin.get_canvas_transform().affine_inverse()
	return ((inverse * axis) - (inverse * Vector2.ZERO)).normalized()

func _cancel(_reason: String) -> void:
	_context_blocked=_context_blocked or _context_held
	_skill_blocked=_skill_blocked or _skill_held
	_item_skill_blocked = _item_skill_blocked or _item_skill_held or (connected_device >= 0 and Input.is_joy_button_pressed(connected_device,JOY_BUTTON_RIGHT_SHOULDER))
	_hook_blocked = _hook_blocked or _hook_held
	_hook_held = false
	_hook_direction = Vector2.ZERO
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

func _device_changed(source: StringName) -> void:
	if source == &"gamepad": return
	# Device ownership cancels aiming but leaves independent jump holds intact.
	_hook_blocked = _hook_blocked or _hook_held
	_hook_held = false
	_hook_direction = Vector2.ZERO
	state = AimState.WAIT_NEUTRAL
	last_valid_direction = Vector2.ZERO
	_arm_ticks = 0
	_center_ticks = 0
	router.cancel_actions_for(&"shoot_release")
	router.cancel_actions_for(&"grapple")
	router.aim_mode = &"attack"
