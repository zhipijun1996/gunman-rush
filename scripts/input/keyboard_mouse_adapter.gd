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
var _hook_armed := false
var _hook_blocked := false
var _hook_sources: Dictionary = {}

func _ready() -> void:
	router.cancelled.connect(_cancel)
	router.device_changed.connect(_device_changed)
	if aim_origin == null and get_parent() is Node2D:
		aim_origin = get_parent()

func world_direction(viewport_position: Vector2) -> Vector2:
	if not is_instance_valid(aim_origin):
		return Vector2.ZERO
	var world := aim_origin.get_canvas_transform().affine_inverse() * viewport_position
	var direction := (world - aim_origin.global_position).normalized()
	var visual := aim_origin.get_node_or_null("CourierVisual") as CourierVisual
	if visual != null and visual.is_node_ready():
		# The barrel pivot and muzzle are off the body center. Iterate the real
		# muzzle transform so the released ray passes through the pointer.
		for i: int in 8:
			direction = (world - visual.muzzle_position(direction)).normalized()
	return direction

func _unhandled_input(event: InputEvent) -> void:
	if not router.has_application_focus or (is_inside_tree() and get_tree().paused):
		return
	if event is InputEventKey:
		if event.echo:
			return
		var code: Key = event.physical_keycode
		if code in [KEY_F,KEY_Q]:
			if event.pressed and not _held.get(code,false) and not _blocked_until_release.has(code):
				router.activate_device(&"keyboard_mouse")
				router.request_action(&"weapon_context" if code==KEY_F else &"weapon_skill",world_direction(get_viewport().get_mouse_position()))
			_held[code]=event.pressed
			if not event.pressed:_blocked_until_release.erase(code)
			return
		if code == KEY_E and (router.grapple_available or _hook_armed or _hook_blocked):
			_hook_edge(event.pressed,world_hook_direction(get_viewport().get_mouse_position()), KEY_E)
			return
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
		router.set_look_axis(&"keyboard_mouse", vertical)
		if vertical == 0:
			_vertical_ready = true
		elif _vertical_ready:
			_vertical_ready = false
			# Arrow keys inspect even on a one-way platform or beside an NPC.
			# W/S retain the existing interaction/drop action contract.
			if not (bool(_held.get(KEY_UP, false)) or bool(_held.get(KEY_DOWN, false))):
				router.request_action(&"interact" if vertical < 0 else &"drop_through")
		if code in mapping.jump:
			router.set_jump_held(&"keyboard_mouse", _action_held("jump"))
		if code in mapping.shoot:
			_shoot_edge(event.pressed, world_direction(get_viewport().get_mouse_position()))
	elif event is InputEventMouse:
		if router.touch_enabled and (event.device == InputEvent.DEVICE_ID_EMULATION or router.touch_owns_pointer()):
			return
		if event is InputEventMouseMotion:
			if event.relative.is_zero_approx():
				return
			router.activate_device(&"keyboard_mouse")
			_last_direction = world_direction(event.position)
			if _hook_armed:
				router.aim_mode = &"grapple"
				router.set_aim(&"keyboard_mouse", world_hook_direction(event.position), true)
			else:
				router.set_aim(&"keyboard_mouse", _last_direction, _mouse_armed)
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and (router.grapple_available or _hook_armed or _hook_blocked):
			_hook_edge(event.pressed,world_hook_direction(event.position), MOUSE_BUTTON_RIGHT)
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
	if _mouse_blocked or _hook_armed:
		_mouse_blocked = pressed
		_mouse_armed = false
		return
	_last_direction = direction
	router.aim_mode = &"attack"
	router.set_aim(&"keyboard_mouse", direction, pressed)
	if pressed:
		_mouse_armed = true
	elif _mouse_armed:
		_mouse_armed = false
		if not direction.is_zero_approx():
			router.primary_release(direction)

func _cancel(_reason: String) -> void:
	_hook_blocked = _hook_blocked or _hook_armed
	_hook_armed = false
	for code: Key in _held:
		if _held[code]:
			_blocked_until_release[code] = true
	_held.clear()
	_mouse_blocked = _mouse_blocked or _mouse_armed
	_mouse_armed = false
	_last_direction = Vector2.ZERO
	_vertical_ready = true

func observe_current_key_neutral() -> void:
	if not Input.is_physical_key_pressed(KEY_E) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_hook_blocked = false
		_hook_sources.clear()
	# Covered UI can consume release events while the adapter is suspended.
	# Only observed physical neutrality clears a block; held keys stay blocked.
	for code: Key in _blocked_until_release.keys():
		if not Input.is_physical_key_pressed(code):
			_blocked_until_release.erase(code)
	if not Input.is_mouse_button_pressed(int(router.profile.values.mouse_shoot_button)):
		_mouse_blocked = false

func _hook_edge(pressed: bool, direction: Vector2, source: int = 0) -> void:
	if _hook_blocked:
		if not pressed:
			_hook_sources.erase(source)
			if _hook_sources.is_empty(): _hook_blocked = false
		return
	if pressed:
		if _hook_sources.has(source): return
		_hook_sources[source] = true
	else:
		if not _hook_sources.has(source): return
		_hook_sources.erase(source)
		if not _hook_sources.is_empty(): return
	router.activate_device(&"keyboard_mouse")
	if pressed and not _hook_armed:
		_hook_armed = true
		_mouse_blocked = _mouse_blocked or _mouse_armed
		_mouse_armed = false
		router.cancel_actions_for(&"shoot_release")
		router.aim_mode = &"grapple"
		router.set_aim(&"keyboard_mouse", direction, true)
	elif not pressed and _hook_armed:
		_hook_armed = false
		router.set_aim(&"keyboard_mouse", direction, false)
		if router.grapple_available: router.request_action(&"grapple", direction)
		router.aim_mode = &"attack"

func _device_changed(source: StringName) -> void:
	if source == &"keyboard_mouse": return
	_hook_blocked = _hook_blocked or _hook_armed
	_hook_armed = false
	_mouse_blocked = _mouse_blocked or _mouse_armed
	_mouse_armed = false
	_last_direction = Vector2.ZERO
	router.cancel_actions_for(&"shoot_release")
	router.cancel_actions_for(&"grapple")
	router.aim_mode = &"attack"

func world_hook_direction(viewport_position: Vector2) -> Vector2:
	if not is_instance_valid(aim_origin):return Vector2.ZERO
	var world := aim_origin.get_canvas_transform().affine_inverse()*viewport_position
	return (world-aim_origin.global_position-Vector2(0,-6)).normalized()
