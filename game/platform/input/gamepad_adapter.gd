class_name GamepadAdapter
extends Node
## Stick deflection requests AirFocus; shoulders submit immediate action edges.
@export var router: InputRouter
@export var aim_origin: Node2D
var connected_device := -1
var _right_active := false
var _preview_blocked := false
var _facing := 1.0
var _vertical_ready := true
var _camera_held := false
var _camera_blocked := false
var _jump_held := false
var _jump_trigger_held := false
var _jump_blocked := false
var _context_held := false
var _skill_held := false
var _context_blocked := false
var _skill_blocked := false
var _item_skill_held := false
var _item_skill_blocked := false
var _shoot_held := false
var _aim_direction := Vector2.ZERO
var _shoot_blocked := false
var _hook_held := false
var _hook_blocked := false

func _ready() -> void:
	router.cancelled.connect(_cancel)
	router.device_changed.connect(_device_changed)
	Input.joy_connection_changed.connect(_connection_changed)

func _physics_process(_delta: float) -> void:
	if not router.has_application_focus: return
	var devices := Input.get_connected_joypads()
	if connected_device < 0:
		if devices.is_empty(): return
		connected_device = devices[0]
		_cancel("connected")
	_sample_physical()

func _unhandled_input(event: InputEvent) -> void:
	if not router.has_application_focus or (is_inside_tree() and get_tree().paused): return
	if event is InputEventJoypadButton:
		if event.button_index not in [int(router.profile.values.gamepad_jump_button), JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_X, JOY_BUTTON_Y]: return
	elif event is InputEventJoypadMotion:
		if event.axis != JOY_AXIS_TRIGGER_LEFT: return
	else: return
	if connected_device < 0: connected_device = event.device
	if event.device == connected_device: _sample_physical(event)

func _button(button: int, edge: InputEvent) -> bool:
	return edge.pressed if edge is InputEventJoypadButton and edge.button_index == button else Input.is_joy_button_pressed(connected_device, button)

func _sample_physical(edge: InputEvent = null) -> void:
	var left := Vector2(Input.get_joy_axis(connected_device, JOY_AXIS_LEFT_X), Input.get_joy_axis(connected_device, JOY_AXIS_LEFT_Y))
	var right := Vector2(Input.get_joy_axis(connected_device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(connected_device, JOY_AXIS_RIGHT_Y))
	var jump_trigger: float = edge.axis_value if edge is InputEventJoypadMotion and edge.axis == JOY_AXIS_TRIGGER_LEFT else Input.get_joy_axis(connected_device, JOY_AXIS_TRIGGER_LEFT)
	var item := Input.get_joy_axis(connected_device, JOY_AXIS_TRIGGER_RIGHT) >= float(router.profile.values.gamepad_trigger_threshold)
	sample_tick(left, right, _button(int(router.profile.values.gamepad_jump_button), edge), _button(JOY_BUTTON_LEFT_SHOULDER, edge), _button(JOY_BUTTON_X, edge), _button(JOY_BUTTON_Y, edge), item, _button(JOY_BUTTON_RIGHT_SHOULDER, edge), jump_trigger)

func sample_tick(raw_left: Vector2, raw_right: Vector2, jump_pressed: bool = false, hook_pressed: bool = false, context_pressed: bool = false, skill_pressed: bool = false, item_skill_pressed: bool = false, shoot_pressed: bool = false, jump_trigger: float = 0.0) -> void:
	if not router.has_application_focus or (is_inside_tree() and get_tree().paused): return
	if not raw_left.is_finite() or not raw_right.is_finite() or not is_finite(jump_trigger):
		router.clear("invalid_gamepad_sample")
		return
	var profile := router.profile
	var trigger_threshold := float(profile.values.gamepad_jump_trigger_release_threshold if _jump_trigger_held else profile.values.gamepad_trigger_threshold)
	_jump_trigger_held = jump_trigger > trigger_threshold if _jump_trigger_held else jump_trigger >= trigger_threshold
	jump_pressed = jump_pressed or _jump_trigger_held
	var left := profile.axis(raw_left, "left_sensitivity")
	var right := profile.axis(raw_right, "right_sensitivity")
	var active_left := left.length() > float(profile.values.left_deadzone)
	_right_active = right.length() > float(profile.values.right_exit_deadzone) if _right_active else right.length() >= float(profile.values.right_enter_deadzone)
	if right.length() <= float(profile.values.right_exit_deadzone): _preview_blocked = false
	if active_left or (_right_active and not _preview_blocked) or (jump_pressed and not _jump_held and not _jump_blocked) or (shoot_pressed and not _shoot_held and not _shoot_blocked) or (hook_pressed and not _hook_held and not _hook_blocked):
		router.activate_device(&"gamepad")
	if active_left and absf(left.x) > float(profile.values.left_deadzone): _facing = signf(left.x)
	var preview := _world_direction(right) if _right_active and not _preview_blocked else Vector2.ZERO
	if absf(preview.x) > .05: _facing = signf(preview.x)
	router.set_source_axis(&"gamepad", left.x if active_left else 0.0)
	router.set_look_axis(&"gamepad", left.y if active_left else 0.0)
	if absf(left.y) < .35: _camera_blocked = false
	_camera_held = absf(left.y) >= .35
	router.set_camera_look(&"gamepad", signf(left.y) if absf(left.y) >= .65 and not _camera_blocked else 0.0)
	if absf(left.y) < .35:
		_vertical_ready = true
	elif absf(left.y) >= .65 and _vertical_ready and router.current_device == &"gamepad":
		_vertical_ready = false
		if left.y < 0: router.request_action(&"interact")
	if not jump_pressed:
		if _jump_held and not _jump_blocked: router.set_jump_held(&"gamepad", false)
		_jump_blocked = false
	elif not _jump_held and not _jump_blocked:
		router.set_jump_held(&"gamepad", true)
	_jump_held = jump_pressed
	if not context_pressed: _context_blocked = false
	if not skill_pressed: _skill_blocked = false
	if not item_skill_pressed: _item_skill_blocked = false
	if context_pressed and not _context_held and not _context_blocked:
		router.activate_device(&"gamepad")
		router.request_action(&"weapon_context")
	var secondary_fired := false
	var skill_direction := preview if not preview.is_zero_approx() else _forward_direction()
	if skill_pressed and not _skill_held and not _skill_blocked:
		router.activate_device(&"gamepad")
		secondary_fired = router.request_action(&"weapon_skill", skill_direction)
	if item_skill_pressed and not _item_skill_held and not _item_skill_blocked and router.item_skill_available:
		router.activate_device(&"gamepad")
		secondary_fired = router.request_action(&"item_skill", skill_direction) or secondary_fired
	_context_held = context_pressed
	_skill_held = skill_pressed
	_item_skill_held = item_skill_pressed
	if not shoot_pressed: _shoot_blocked = false
	if not hook_pressed: _hook_blocked = false
	# Direction survives stick centering, but slow aim requires actual deflection.
	# Clearing/cancelling ownership erases it; no stale gesture can auto-fire.
	if not preview.is_zero_approx(): _aim_direction = preview
	var direction := _aim_direction if not _aim_direction.is_zero_approx() else _forward_direction()
	var hook_edge := hook_pressed and not _hook_held and not _hook_blocked and router.grapple_available
	var gun_edge := shoot_pressed and not _shoot_held and not _shoot_blocked
	_hook_held = hook_pressed
	_shoot_held = shoot_pressed
	router.aim_mode = &"grapple" if hook_edge else &"attack"
	router.set_aim(&"gamepad", direction if _right_active or not _aim_direction.is_zero_approx() else Vector2.ZERO, _right_active and not _preview_blocked)
	if hook_edge:
		router.cancel_actions_for(&"shoot_release")
		_shoot_blocked = shoot_pressed
		router.gamepad_primary_held = false
		router.request_action(&"grapple", direction)
	else:
		if secondary_fired: _shoot_blocked = shoot_pressed
		router.gamepad_primary_held = shoot_pressed and not _shoot_blocked
		if gun_edge and not secondary_fired: router.request_action(&"shoot_release", direction)

func _forward_direction() -> Vector2:
	if is_instance_valid(aim_origin):
		var visual := aim_origin.get_node_or_null("CourierVisual") as CourierVisual
		if visual != null: return Vector2(-1 if visual.facing < 0 else 1, 0)
	return Vector2(_facing, 0)

func _world_direction(axis: Vector2) -> Vector2:
	if not is_instance_valid(aim_origin): return axis.normalized()
	var inverse := aim_origin.get_canvas_transform().affine_inverse()
	return ((inverse * axis) - (inverse * Vector2.ZERO)).normalized()

func _cancel(reason: String) -> void:
	_camera_blocked = _camera_blocked or _camera_held
	_camera_held = false
	_context_blocked = _context_blocked or _context_held
	_skill_blocked = _skill_blocked or _skill_held
	_item_skill_blocked = _item_skill_blocked or _item_skill_held or (connected_device >= 0 and Input.get_joy_axis(connected_device, JOY_AXIS_TRIGGER_RIGHT) >= float(router.profile.values.gamepad_trigger_threshold))
	_shoot_blocked = _shoot_blocked or _shoot_held or (connected_device >= 0 and Input.is_joy_button_pressed(connected_device, JOY_BUTTON_RIGHT_SHOULDER))
	_hook_blocked = _hook_blocked or _hook_held or (connected_device >= 0 and Input.is_joy_button_pressed(connected_device, JOY_BUTTON_LEFT_SHOULDER))
	_shoot_held = false
	_aim_direction = Vector2.ZERO
	router.gamepad_primary_held = false
	_hook_held = false
	_preview_blocked = _preview_blocked or _right_active
	_right_active = false
	_vertical_ready = true
	if reason != "device_changed":
		_jump_blocked = _jump_blocked or _jump_held or (connected_device >= 0 and Input.is_joy_button_pressed(connected_device, int(router.profile.values.gamepad_jump_button)))
		_jump_blocked = _jump_blocked or (connected_device >= 0 and Input.get_joy_axis(connected_device, JOY_AXIS_TRIGGER_LEFT) > float(router.profile.values.gamepad_jump_trigger_release_threshold))
		_jump_held = false
		_jump_trigger_held = false

func _connection_changed(device: int, connected: bool) -> void:
	if not connected and device == connected_device:
		connected_device = -1
		router.clear("gamepad_disconnected")

func _device_changed(source: StringName) -> void:
	if source == &"gamepad": return
	_cancel("device_changed")
	# Device ownership cancels aiming but leaves independent jump holds intact.
	router.cancel_actions_for(&"shoot_release")
	router.cancel_actions_for(&"grapple")
	router.aim_mode = &"attack"
