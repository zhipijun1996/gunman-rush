extends SceneTree

var checks := 0
var failures := 0
var tick := 100000
var router: InputRouter
var keyboard: KeyboardMouseAdapter
var gamepad: GamepadAdapter
var overlay: TouchOverlay

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + label)
func actions() -> Array[Dictionary]:
	tick += 1
	return router.consume_actions(tick)
func mouse(button: MouseButton, down: bool, point := Vector2(300, 0)) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = down
	event.position = point
	keyboard._unhandled_input(event)
func touch(index: int, point: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index; event.position = point; event.pressed = down
	overlay.handle_touch(event)
func drag(index: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index; event.position = point
	overlay.handle_touch(event)
func run() -> void:
	await preload("res://tests/input_tests.gd").new().run(self, check)
	var fixture := preload("res://tests/combat_tests.gd").new()
	fixture.tree = self
	await fixture.fixture(Vector2(80, -1000))
	var controller: PlayerController = fixture.controller
	router = controller.router
	controller.traversal.grant(&"grapple")
	controller.physics_tick(1.0/60.0)
	overlay = InputSetup.attach(fixture.motor, router)
	keyboard = fixture.motor.get_node("KeyboardMouseAdapter")
	gamepad = fixture.motor.get_node("GamepadAdapter")
	gamepad.set_physics_process(false)
	overlay.set_enabled(false)
	var direction := Vector2.RIGHT.rotated(deg_to_rad(-30))
	var point := fixture.motor.get_canvas_transform() * (fixture.motor.global_position + Vector2(0,-6) + direction*200)
	mouse(MOUSE_BUTTON_LEFT, true, point)
	controller._physics_process(.001)
	check(controller.air_focus_ability.active and is_equal_approx(Engine.time_scale,.15), "real controller consumes gun aim at 15 percent")
	mouse(MOUSE_BUTTON_RIGHT, true, point)
	check(router.aim_mode == &"grapple" and router.aim_engaged and actions().is_empty(), "PC H held owns live aim without casting")
	controller._physics_process(.001)
	check(controller.air_focus_ability.active and is_equal_approx(Engine.time_scale,.15), "real controller consumes PC hook aiming at 15 percent")
	mouse(MOUSE_BUTTON_LEFT, false, point)
	check(router.aim_engaged and router.aim_mode == &"grapple" and actions().is_empty(), "releasing suppressed gun retains hook focus without shooting")
	var release_direction := keyboard.world_hook_direction(point)
	mouse(MOUSE_BUTTON_RIGHT, false, point)
	var found := actions()
	check(found.size()==1 and found[0].type==&"grapple" and found[0].direction.is_equal_approx(release_direction), "PC release emits one 30 degree hook")
	mouse(MOUSE_BUTTON_RIGHT, false, point)
	check(actions().is_empty(), "duplicate PC hook release cannot cast")
	var e := InputEventKey.new()
	e.physical_keycode = KEY_E
	e.pressed = true
	keyboard._unhandled_input(e)
	mouse(MOUSE_BUTTON_RIGHT, true, point)
	e.pressed = false
	keyboard._unhandled_input(e)
	check(router.aim_engaged and actions().is_empty(), "releasing E retains simultaneously held RMB grapple aim")
	mouse(MOUSE_BUTTON_RIGHT, false, point)
	found = actions()
	check(found.size()==1 and found[0].type==&"grapple", "combined E and RMB release casts once after last release")
	for reason: String in ["pause", "death", "focus_out"]:
		mouse(MOUSE_BUTTON_RIGHT, true, point)
		router.clear(reason)
		mouse(MOUSE_BUTTON_RIGHT, false, point)
		check(actions().is_empty() and not router.aim_engaged and Engine.time_scale==1.0, "cancelled PC hook never casts: "+reason)
	mouse(MOUSE_BUTTON_RIGHT, true, point)
	gamepad.sample_tick(Vector2.LEFT, Vector2.ZERO)
	mouse(MOUSE_BUTTON_RIGHT, false, point)
	check(actions().is_empty() and not keyboard._hook_armed, "switching away revokes PC hook gesture")
	gamepad.sample_tick(Vector2.ZERO, direction, false, true)
	check(router.aim_mode==&"grapple" and router.aim_engaged and actions().is_empty(), "LB held engages grapple aim without shooting")
	controller._physics_process(.001)
	check(controller.air_focus_ability.active and is_equal_approx(Engine.time_scale,.15), "real controller consumes LB hook aiming at 15 percent")
	gamepad.sample_tick(Vector2.ZERO, Vector2.ZERO, false, true)
	check(router.aim_engaged and router.aim_direction.is_equal_approx(direction), "centered held LB retains last valid hook direction")
	gamepad.sample_tick(Vector2.ZERO, Vector2.ZERO, false, false)
	found = actions()
	check(found.size()==1 and found[0].type==&"grapple" and found[0].direction.is_equal_approx(direction), "LB centered release casts remembered 30 degree direction once")
	for i: int in 4: gamepad.sample_tick(Vector2.ZERO, Vector2.ZERO)
	check(actions().is_empty(), "centering hook aim never arms a primary shot")
	gamepad.sample_tick(Vector2.ZERO, direction, false, true)
	router.clear("pause")
	for i: int in 4: gamepad.sample_tick(Vector2.ZERO, direction, false, true)
	gamepad.sample_tick(Vector2.ZERO, Vector2.ZERO, false, false)
	check(actions().is_empty() and not router.aim_engaged, "cancelled LB stays blocked until physical release")
	gamepad.sample_tick(Vector2.ZERO, Vector2.ZERO, false, true)
	check(not router.aim_engaged and actions().is_empty(), "centered LB without direction never invents an aim")
	gamepad.sample_tick(Vector2.ZERO, Vector2.ZERO, false, false)
	found = actions()
	check(found.size()==1 and found[0].type==&"grapple" and found[0].direction==Vector2.ZERO, "centered LB tap delegates existing face fallback once")
	gamepad.sample_tick(Vector2.ZERO, direction, false, true)
	mouse(MOUSE_BUTTON_LEFT, true, point)
	gamepad.sample_tick(Vector2.ZERO, Vector2.ZERO, false, false)
	mouse(MOUSE_BUTTON_LEFT, false, point)
	found=actions()
	check(found.size()==1 and found[0].type==&"shoot_release", "switch away cancels LB while allowing fresh PC gun gesture")
	mouse(MOUSE_BUTTON_RIGHT, true, point)
	paused = true
	check(not router.aim_engaged and Engine.time_scale==1.0, "actual pause synchronously clears held H focus")
	paused = false
	mouse(MOUSE_BUTTON_RIGHT, false, point)
	check(actions().is_empty(), "post-pause old H release cannot cast")
	router.grapple_available = false
	mouse(MOUSE_BUTTON_LEFT, true, point)
	mouse(MOUSE_BUTTON_RIGHT, true, point)
	check(router.aim_mode==&"attack" and router.aim_engaged, "unavailable H does not hijack active gun aim")
	mouse(MOUSE_BUTTON_RIGHT, false, point)
	mouse(MOUSE_BUTTON_LEFT, false, point)
	found=actions()
	check(found.size()==1 and found[0].type==&"shoot_release", "unavailable H leaves valid gun release intact")
	router.grapple_available = true
	overlay.set_enabled(true)
	var gun := overlay.right_center
	var hook := overlay.hook_center
	touch(1, gun, true); drag(1, gun+Vector2.RIGHT*overlay.radius)
	touch(2, hook, true); drag(2, hook+direction*overlay.hook_radius)
	check(router.aim_mode==&"grapple" and router.aim_engaged, "touch hook drag takes aim ownership from held gun")
	drag(1, gun+Vector2.LEFT*overlay.radius)
	check(router.aim_mode==&"grapple" and router.aim_direction.is_equal_approx(direction), "old gun micro-drag cannot steal captured H aim")
	controller._physics_process(.001)
	check(controller.air_focus_ability.active and is_equal_approx(Engine.time_scale,.15), "real controller consumes touch hook aim at 15 percent")
	touch(1, gun+Vector2.RIGHT*overlay.radius, false)
	check(router.aim_mode==&"grapple" and router.aim_engaged and actions().is_empty(), "touch gun release preserves held hook aim without phantom shot")
	touch(2, hook+direction*overlay.hook_radius, false)
	found=actions()
	check(found.size()==1 and found[0].type==&"grapple" and found[0].direction.is_equal_approx(direction), "touch hook release retains exact continuous direction")
	gun=overlay.right_center;hook=overlay.hook_center
	touch(1, gun, true);drag(1, gun+Vector2.LEFT*overlay.radius)
	touch(2, hook, true);drag(2, hook+Vector2.UP*overlay.hook_radius)
	touch(2, hook+Vector2.UP*overlay.hook_radius, false)
	found=actions()
	check(found.size()==1 and found[0].type==&"grapple" and router.aim_mode==&"attack" and not router.aim_engaged, "touch H release does not restore a suppressed old gun gesture")
	touch(1, gun+Vector2.LEFT*overlay.radius, false)
	check(actions().is_empty(), "pre-hook gun must neutralize before a new shot")
	hook=overlay.hook_center;gun=overlay.right_center
	touch(2, hook, true);drag(2, hook+Vector2.UP*overlay.hook_radius)
	touch(1, gun, true);drag(1, gun+Vector2.LEFT*overlay.radius)
	check(router.aim_mode==&"grapple" and router.aim_direction.is_equal_approx(Vector2.UP), "new gun finger cannot steal a captured H aim")
	touch(2, hook+Vector2.UP*overlay.hook_radius, false)
	found=actions()
	check(found.size()==1 and found[0].type==&"grapple" and router.aim_mode==&"attack" and router.aim_engaged and router.aim_direction.is_equal_approx(Vector2.LEFT), "H release restores fresh nonsuppressed gun finger stored direction")
	touch(1, gun+Vector2.LEFT*overlay.radius, false)
	found=actions()
	check(found.size()==1 and found[0].type==&"shoot_release", "fresh gun gesture after H ends emits exactly one legal shot")
	hook=overlay.hook_center;gun=overlay.right_center
	touch(2, hook, true);drag(2, hook+Vector2.UP*overlay.hook_radius)
	touch(1, gun, true);drag(1, gun+Vector2.LEFT*overlay.radius)
	touch(1, gun+Vector2.LEFT*overlay.radius, false)
	check(actions().is_empty() and router.aim_mode==&"grapple" and router.aim_engaged, "new gun released during captured H cannot fire and preserves H aim")
	touch(2, hook+Vector2.UP*overlay.hook_radius, false)
	found=actions()
	check(found.size()==1 and found[0].type==&"grapple", "H remains single cast after new gun finger released first")
	router.clear("cleanup")
	fixture.world.free()
	await process_frame
	print("GRAPPLE AIM INPUT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures==0 else 1)
