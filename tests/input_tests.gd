extends RefCounted

var _tick := 10000
var _router: InputRouter
var _keyboard: KeyboardMouseAdapter
var _gamepad: GamepadAdapter
var _touch: TouchOverlay

func actions() -> Array[Dictionary]:
	_tick += 1
	return _router.consume_actions(_tick)

func touch(index: int, point: Vector2, pressed: bool) -> bool:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	return _touch.handle_touch(event)

func drag(index: int, point: Vector2) -> bool:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	return _touch.handle_touch(event)

func key(code: Key, pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	_keyboard._unhandled_input(event)

func mouse(point: Vector2, pressed: bool, device: int = 0) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.device = device
	_keyboard._unhandled_input(event)

func pad(left: Vector2, right: Vector2, count: int = 1, jump: bool = false) -> void:
	for _index: int in count:
		_gamepad.sample_tick(left, right, jump)

func run(tree: SceneTree, check: Callable) -> void:
	var world := Node2D.new()
	tree.root.add_child(world)
	_router = InputRouter.new()
	world.add_child(_router)
	var origin := Node2D.new()
	origin.position = Vector2(100, 200)
	world.add_child(origin)
	_touch = InputSetup.attach(origin, _router)
	_keyboard = origin.get_node("KeyboardMouseAdapter")
	_gamepad = origin.get_node("GamepadAdapter")
	_gamepad.set_physics_process(false)
	check.call(not _touch.enabled, "desktop hides touch overlay")
	_touch.set_enabled(true)
	check.call(not touch(8, Vector2(600, 300), true), "touch outside controls remains available to other UI")
	check.call(touch(0, _touch.left_center + Vector2(_touch.radius, 0), true), "left touch captures")
	check.call(touch(1, _touch.right_center + Vector2(0, -_touch.radius), true), "right touch captures independently")
	check.call(touch(2, _touch.jump_center, true), "third finger jumps independently")
	var intents := actions()
	check.call(_router.axis > 0.99 and intents.size() == 1 and intents[0].type == &"jump", "three-finger movement aiming jump coexist")
	touch(2, _touch.jump_center, false)
	check.call(_router.axis > 0.99 and _touch._captures.size() == 2, "jump release preserves both sticks")
	drag(0, _touch.left_center + Vector2(-_touch.radius * 4, 0))
	check.call(_router.axis < -0.99, "captured left finger works outside original region")
	touch(1, _touch.right_center + Vector2(0, -_touch.radius), false)
	intents = actions()
	check.call(intents.size() == 1 and intents[0].direction.is_equal_approx(Vector2.UP), "effective touch release shoots upward once")
	touch(1, _touch.right_center + Vector2(0, -_touch.radius), false)
	check.call(actions().is_empty(), "duplicate release cannot shoot")
	check.call(_router.axis < -0.99, "aim release preserves movement finger")
	touch(0, _touch.left_center, false)
	check.call(_router.axis == 0.0, "left release clears its movement")
	touch(3, _touch.right_center, true)
	drag(3, _touch.right_center + Vector2(_touch.radius, 0))
	drag(3, _touch.right_center)
	touch(3, _touch.right_center, false)
	check.call(actions().is_empty() and _router.aim_direction == Vector2.ZERO, "touch back in deadzone then release cancels instead of gamepad shooting")
	touch(3, _touch.right_center + Vector2(_touch.radius, 0), true)
	_router.clear("death")
	touch(3, _touch.right_center + Vector2(_touch.radius, 0), false)
	check.call(actions().is_empty() and _touch._captures.is_empty(), "death clears finger capture without release shot")
	touch(4, _touch.right_center + Vector2(_touch.radius, 0), true)
	var cancelled := InputEventScreenTouch.new()
	cancelled.index = 4
	cancelled.canceled = true
	_touch.handle_touch(cancelled)
	check.call(actions().is_empty() and _touch._captures.is_empty(), "system touch cancellation cannot shoot")
	mouse(Vector2(400, 200), true, InputEvent.DEVICE_ID_EMULATION)
	mouse(Vector2(400, 200), false, InputEvent.DEVICE_ID_EMULATION)
	check.call(actions().is_empty(), "touch enabled filters emulated mouse")
	_touch.set_enabled(false)
	var previous_transform := tree.root.canvas_transform
	tree.root.canvas_transform = Transform2D(0, Vector2(2, 2), 0, Vector2(300, 80))
	var world_target := Vector2(150, 150)
	var screen_point := tree.root.canvas_transform * world_target
	check.call(_keyboard.world_direction(screen_point).is_equal_approx(Vector2(1, -1).normalized()), "mouse aim uses viewport camera transform instead of screen delta")
	mouse(screen_point, false)
	check.call(actions().is_empty(), "mouse release without press cannot shoot")
	mouse(screen_point, true)
	mouse(screen_point, false)
	intents = actions()
	check.call(intents.size() == 1 and intents[0].direction.is_equal_approx(Vector2(1, -1).normalized()), "mouse release copies world aim")
	mouse(screen_point, true)
	_router.clear("focus_lost")
	mouse(screen_point, false)
	check.call(actions().is_empty(), "cancelled mouse release cannot shoot")
	mouse(screen_point, true)
	mouse(screen_point, false)
	check.call(actions().size() == 1, "mouse rearms only after old held button releases")
	key(KEY_SPACE, true, true)
	check.call(actions().is_empty(), "keyboard echo filtered")
	key(KEY_SPACE, true)
	check.call(actions().size() == 1, "fresh Space press jumps")
	_router.clear("pause")
	key(KEY_SPACE, true)
	key(KEY_SPACE, false)
	check.call(actions().is_empty(), "cancelled held key suppressed through release")
	key(KEY_SPACE, true)
	check.call(actions().size() == 1, "key rearms after release")
	key(KEY_SPACE, false)
	key(KEY_D, true)
	pad(Vector2.ZERO, Vector2.ZERO, 4)
	check.call(_router.axis == 1.0 and _router.current_device == &"keyboard_mouse", "idle gamepad cannot overwrite keyboard movement or prompt")
	pad(Vector2.LEFT, Vector2.ZERO)
	check.call(_router.axis == -1.0 and _router.current_device == &"gamepad", "meaningful gamepad switches input and clears old source axes")
	key(KEY_D, false)
	tree.root.canvas_transform = previous_transform
	_router.clear("new_pad_session")
	pad(Vector2.ZERO, Vector2.RIGHT, 4)
	check.call(_gamepad.state == GamepadAdapter.AimState.WAIT_NEUTRAL and actions().is_empty(), "initial deflected stick cannot arm")
	pad(Vector2.ZERO, Vector2.ZERO)
	check.call(_gamepad.state == GamepadAdapter.AimState.WAIT_NEUTRAL, "one neutral tick does not satisfy configured confirmation")
	pad(Vector2.ZERO, Vector2.ZERO)
	check.call(_gamepad.state == GamepadAdapter.AimState.READY, "second neutral tick readies pad")
	pad(Vector2.ZERO, Vector2.RIGHT)
	pad(Vector2.ZERO, Vector2(0.18, 0))
	pad(Vector2.ZERO, Vector2.ZERO, 3)
	check.call(actions().is_empty() and _gamepad.state == GamepadAdapter.AimState.READY, "one-tick offset then hysteresis noise cannot arm")
	pad(Vector2.ZERO, Vector2.RIGHT, 2)
	pad(Vector2.ZERO, Vector2.UP)
	pad(Vector2.ZERO, Vector2.ZERO)
	check.call(actions().is_empty() and _gamepad.state == GamepadAdapter.AimState.CENTER_PENDING, "first center tick freezes direction and waits")
	pad(Vector2.ZERO, Vector2(0.18, 0))
	check.call(_gamepad.state == GamepadAdapter.AimState.ARMED and _gamepad.last_valid_direction == Vector2.UP, "hysteresis noise cancels center confirmation without replacing last direction")
	pad(Vector2.ZERO, Vector2.ZERO, 2)
	intents = actions()
	check.call(intents.size() == 1 and intents[0].direction == Vector2.UP, "confirmed center fires exactly once with pre-center effective direction")
	pad(Vector2.ZERO, Vector2.ZERO, 5)
	check.call(actions().is_empty(), "held center never retries shot")
	pad(Vector2.ZERO, Vector2.DOWN, 2)
	_gamepad.connected_device = 5
	_gamepad._connection_changed(5, false)
	pad(Vector2.ZERO, Vector2.ZERO, 2)
	check.call(actions().is_empty() and _gamepad.last_valid_direction == Vector2.ZERO, "disconnect cancels armed shot")
	pad(Vector2.ZERO, Vector2.RIGHT, 2)
	var previous_epoch := _router.epoch
	tree.paused = true
	check.call(_router.epoch > previous_epoch and _gamepad.state == GamepadAdapter.AimState.WAIT_NEUTRAL, "actual SceneTree pause clears adapter and router")
	_touch.set_enabled(true)
	check.call(not touch(6, _touch.right_center + Vector2(_touch.radius, 0), true), "paused gameplay touch cannot capture or arm")
	pad(Vector2.ZERO, Vector2.ZERO, 2)
	pad(Vector2.ZERO, Vector2.RIGHT, 2)
	pad(Vector2.ZERO, Vector2.ZERO, 2)
	check.call(_gamepad.state == GamepadAdapter.AimState.WAIT_NEUTRAL and actions().is_empty(), "paused injected gamepad samples cannot rearm or queue shooting")
	var menu_seen := [false]
	_touch.pause_requested.connect(func(): menu_seen[0] = true)
	touch(7, _touch._pause_rect.get_center(), true)
	touch(7, _touch._pause_rect.get_center(), false)
	check.call(menu_seen[0], "touch pause menu remains usable while paused")
	_touch.set_enabled(false)
	tree.paused = false
	pad(Vector2.ZERO, Vector2.ZERO, 3)
	check.call(actions().is_empty(), "pause resume cannot emit cancelled shot")
	_router.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check.call(_gamepad.state == GamepadAdapter.AimState.WAIT_NEUTRAL, "application focus-out notification cancels")
	check.call(not _router.reconfigure({"right_exit_deadzone": 0.5}), "invalid deadzone order rejected")
	check.call(not _router.reconfigure({"arm_confirm_ticks": 0}), "zero debounce ticks rejected")
	check.call(not _router.reconfigure({"center_confirm_ticks": INF}), "infinite debounce ticks rejected")
	check.call(not _router.reconfigure({"mouse_shoot_button": 1.5}), "fractional mouse button rejected")
	check.call(not _router.reconfigure({"gamepad_jump_button": -1}), "invalid gamepad button rejected")
	check.call(not _router.reconfigure({"touch_radius": 0}), "zero touch radius rejected")
	check.call(not _router.reconfigure({"right_sensitivity": INF}), "nonfinite sensitivity rejected")
	check.call(not _router.reconfigure({"keyboard": {"left": [65], "right": [65], "up": [87], "down": [83], "jump": [32], "shoot": []}}), "conflicting key mappings rejected")
	pad(Vector2.ZERO, Vector2.ZERO, 2)
	pad(Vector2.ZERO, Vector2.RIGHT, 2)
	check.call(_router.reconfigure({"arm_confirm_ticks": 3, "center_confirm_ticks": 1}), "valid configuration applied")
	check.call(_gamepad.state == GamepadAdapter.AimState.WAIT_NEUTRAL and actions().is_empty(), "mapping change cancels old armed gesture")
	pad(Vector2.ZERO, Vector2.ZERO)
	pad(Vector2.ZERO, Vector2.RIGHT, 2)
	check.call(_gamepad.state == GamepadAdapter.AimState.READY, "custom arm confirmation uses configured three ticks")
	pad(Vector2.ZERO, Vector2.RIGHT)
	pad(Vector2.ZERO, Vector2.ZERO)
	check.call(actions().size() == 1, "custom one-tick center confirmation fires once")
	check.call(_router.load_profile("res://config/input_profile.json"), "profile can reload defaults and cancels old input")
	check.call(_router.profile.values.arm_confirm_ticks == 2, "reload restores single config source defaults")
	world.free()
	await tree.process_frame
