class_name KeyboardMouseAdapter
extends Node

@export var router: InputRouter
@export var aim_origin: Node2D
var _held: Dictionary = {}
var _blocked_until_release: Dictionary = {}
var _mouse_armed := false
var _mouse_blocked := false
var _last_direction := Vector2.ZERO
var _vertical_ready := true

func _ready() -> void:
	router.cancelled.connect(_cancel)
	if aim_origin == null and get_parent() is Node2D:
		aim_origin = get_parent()

func world_direction(viewport_position: Vector2) -> Vector2:
	if not is_instance_valid(aim_origin):
		return Vector2.ZERO
	var world := aim_origin.get_canvas_transform().affine_inverse() * viewport_position
	return (world - aim_origin.global_position).normalized()

func _unhandled_input(event: InputEvent) -> void:
	if not router.has_application_focus or (is_inside_tree() and get_tree().paused):
		return
	if event is InputEventKey:
		if event.echo:
			return
		var code: Key = event.physical_keycode
		if _blocked_until_release.has(code):
			if not event.pressed:
				_blocked_until_release.erase(code)
			return
		if bool(_held.get(code, false)) == event.pressed:
			return
		_held[code] = event.pressed
		var mapping: Dictionary = router.profile.values.keyboard
		var recognized := false
		for action: String in mapping:
			if code in mapping[action]:
				recognized = true
		if not recognized:
			return
		router.activate_device(&"keyboard_mouse")
		router.set_source_axis(&"keyboard_mouse", float(_action_held("right")) - float(_action_held("left")))
		var vertical := int(_action_held("down")) - int(_action_held("up"))
		if vertical == 0:
			_vertical_ready = true
		elif _vertical_ready:
			_vertical_ready = false
			router.request_action(&"interact" if vertical < 0 else &"drop_through")
		if code in mapping.jump:
			router.set_jump_held(&"keyboard_mouse", _action_held("jump"))
		if code in mapping.shoot:
			_shoot_edge(event.pressed, world_direction(get_viewport().get_mouse_position()))
	elif event is InputEventMouse:
		if router.touch_enabled and event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if event is InputEventMouseMotion:
			if event.relative.is_zero_approx():
				return
			router.activate_device(&"keyboard_mouse")
			_last_direction = world_direction(event.position)
			router.set_aim(&"keyboard_mouse", _last_direction, _mouse_armed)
		elif event is InputEventMouseButton and event.button_index == int(router.profile.values.mouse_shoot_button):
			if _mouse_blocked:
				if not event.pressed:
					_mouse_blocked = false
				return
			router.activate_device(&"keyboard_mouse")
			_shoot_edge(event.pressed, world_direction(event.position))

func _action_held(action: String) -> bool:
	for code: Variant in router.profile.values.keyboard[action]:
		if _held.get(int(code), false):
			return true
	return false

func _shoot_edge(pressed: bool, direction: Vector2) -> void:
	_last_direction = direction
	router.set_aim(&"keyboard_mouse", direction, pressed)
	if pressed:
		_mouse_armed = true
	elif _mouse_armed:
		_mouse_armed = false
		if not direction.is_zero_approx():
			router.request_action(&"shoot_release", direction)

func _cancel(_reason: String) -> void:
	for code: Key in _held:
		if _held[code]:
			_blocked_until_release[code] = true
	_held.clear()
	_mouse_blocked = _mouse_blocked or _mouse_armed
	_mouse_armed = false
	_last_direction = Vector2.ZERO
	_vertical_ready = true

func observe_current_key_neutral() -> void:
	# Covered UI can consume release events while the adapter is suspended.
	# Only observed physical neutrality clears a block; held keys stay blocked.
	for code: Key in _blocked_until_release.keys():
		if not Input.is_physical_key_pressed(code):
			_blocked_until_release.erase(code)
	if not Input.is_mouse_button_pressed(int(router.profile.values.mouse_shoot_button)):
		_mouse_blocked = false
