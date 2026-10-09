extends SceneTree

const PLAYER := preload("res://scenes/player/player.tscn")
const DT := 1.0 / 60.0
var failures := 0
var assertions := 0
var world: Node2D
var motor: PlayerMotor
var controller: PlayerController
var router: InputRouter
var jump: JumpAbility

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func platform(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)

func fixture(location := Vector2(80, 150), floor_width := 500.0) -> void:
	if is_instance_valid(world):
		world.free()
	world = Node2D.new()
	root.add_child(world)
	platform(Rect2(0, 200, floor_width, 40))
	motor = PLAYER.instantiate()
	motor.position = location
	world.add_child(motor)
	controller = motor.get_node("Controller")
	router = motor.get_node("InputRouter")
	jump = motor.get_node("JumpAbility")
	controller.set_physics_process(false)
	await physics_frame

func ticks(count: int) -> void:
	for index: int in count:
		await physics_frame
		controller.physics_tick(DT)

func press_jump() -> void:
	router.request_action(&"jump")
	await ticks(1)

func key_event(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	(motor.get_node("KeyboardMouseAdapter") as KeyboardMouseAdapter)._unhandled_input(event)

func _run() -> void:
	if "--verify-failure-exit" in OS.get_cmdline_user_args():
		check(false, "intentional exit-code verification")
		quit(1)
		return
	for maximum: int in [0, 1, 2, 3, 5]:
		await fixture()
		await ticks(30)
		check(motor.is_on_floor(), "fixture has actual floor contact")
		jump.tuning.max_jumps = maximum
		await ticks(1)
		for index: int in maximum:
			await press_jump()
			check(jump.used_jumps == index + 1 and motor.normal_velocity.y < 0.0, "%d-jump configuration accepts jump %d" % [maximum, index + 1])
		var used := jump.used_jumps
		await press_jump()
		check(jump.used_jumps == used, "%d-jump configuration rejects exhausted jump" % maximum)
		await ticks(100)
		check(motor.is_on_floor() and jump.used_jumps == 0, "landing restores %d-jump configuration" % maximum)
	print("PASS GROUP: jump-count matrix and real landing")

	await fixture()
	await ticks(30)
	jump.enabled = false
	await press_jump()
	check(jump.used_jumps == 0 and motor.is_on_floor(), "disabled ability refuses jump")
	jump.enabled = true
	await press_jump()
	check(jump.used_jumps == 1, "ability reenabled")
	jump.tuning.max_jumps = 0
	await press_jump()
	check(jump.used_jumps == 1, "airborne lowered limit rejects")
	jump.tuning.max_jumps = 3
	await press_jump()
	check(jump.used_jumps == 1, "airborne increased limit grants no current-flight charges")
	await ticks(100)
	for index: int in 3:
		await press_jump()
	check(jump.used_jumps == 3, "new limit applies on next landing")

	await fixture(Vector2(80, 150), 160.0)
	await ticks(30)
	router.set_move_axis(1.0)
	while motor.is_on_floor():
		await ticks(1)
	router.set_move_axis(0.0)
	await press_jump()
	check(jump.used_jumps == 1 and motor.normal_velocity.y < -350.0, "walkoff inside coyote gets first jump")
	await fixture(Vector2(80, 150), 160.0)
	await ticks(30)
	router.set_move_axis(1.0)
	while motor.is_on_floor():
		await ticks(1)
	await ticks(8)
	check(jump.used_jumps == 1, "walkoff outside coyote consumes first eligibility")
	await press_jump()
	check(jump.used_jumps == 2 and motor.normal_velocity.y < 0.0, "outside coyote uses remaining air jump")
	print("PASS GROUP: enabled state, airborne count change, coyote inside/outside")

	await fixture(Vector2(80, 80))
	jump.tuning.max_jumps = 1
	while motor.position.y < 165.0:
		await ticks(1)
	await press_jump()
	check(jump.used_jumps == 1, "falling player has no first jump after coyote expiry")
	await ticks(4)
	check(motor.normal_velocity.y < 0.0 and not motor.is_on_floor(), "buffered request launches after landing")
	await ticks(100)
	check(motor.is_on_floor() and jump.used_jumps == 0, "buffer triggers once, no repeat after next landing")

	await fixture()
	await ticks(30)
	router.set_move_axis(1.0)
	var start := motor.position.x
	await ticks(15)
	check(is_equal_approx(motor.normal_velocity.x, motor.tuning.ground_speed) and motor.position.x > start, "ground acceleration reaches configured speed")
	router.set_move_axis(0.0)
	await ticks(8)
	check(is_zero_approx(motor.normal_velocity.x), "ground release decelerates to zero")
	await press_jump()
	router.set_move_axis(-1.0)
	await ticks(1)
	check(is_equal_approx(motor.normal_velocity.x, -motor.tuning.air_acceleration * DT), "air control uses configured acceleration")
	await ticks(10)
	check(motor.normal_velocity.x < -100.0, "air control changes trajectory")
	print("PASS GROUP: landing buffer, ground motion, air control")

	await fixture()
	platform(Rect2(120, 0, 20, 200))
	await ticks(30)
	router.set_move_axis(1.0)
	await ticks(25)
	check(motor.position.x <= 108.1 and is_zero_approx(motor.normal_velocity.x), "actual wall blocks and projects normal velocity")
	await ticks(2)
	check(motor.position.x <= 108.1, "wall stays blocked on following frames")
	await fixture()
	platform(Rect2(0, 120, 200, 15))
	await ticks(30)
	await press_jump()
	await ticks(5)
	check(motor.position.y >= 152.9 and motor.normal_velocity.y >= 0.0, "actual low ceiling blocks jump and clears upward velocity")
	print("PASS GROUP: real wall and low-ceiling collisions")

	await fixture()
	await ticks(30)
	router.request_action(&"jump")
	router.set_move_axis(1.0)
	var previous_epoch := router.epoch
	router.clear("test_pause")
	await ticks(1)
	check(router.epoch == previous_epoch + 1 and router.axis == 0.0 and jump.used_jumps == 0, "cancel clears pending input and axis")
	jump.request_jump()
	router.clear("test_focus_loss")
	await ticks(1)
	check(jump.used_jumps == 0, "cancel clears ability buffer")
	router.request_action(&"jump")
	router.request_action(&"jump")
	await ticks(1)
	check(jump.used_jumps == 1, "same-tick duplicate jump merged")
	var count := 0
	for index: int in 17:
		if router.request_action(&"jump"):
			count += 1
	check(count == 16, "queue cap refuses seventeenth request")
	router.clear("queue_test")
	check(not router.request_action(&"shoot_release", Vector2.ZERO), "invalid shoot direction refused at boundary")
	var expiry_router := InputRouter.new()
	world.add_child(expiry_router)
	expiry_router.request_action(&"jump")
	await create_timer(0.12).timeout
	check(expiry_router.consume_actions(1).is_empty(), "stale requests expire")
	check(expiry_router.consume_actions(1).is_empty(), "duplicate tick cannot reconsume")
	print("PASS GROUP: cancellation, deduplication, bounded queue, expiry")
	controller.die()
	router.request_action(&"jump")
	await ticks(2)
	check(not controller.active and motor.normal_velocity == Vector2.ZERO and jump.used_jumps == 0, "dead controller refuses actions and clears motion")
	controller.reset_at(Vector2(80, 150))
	await ticks(30)
	await press_jump()
	check(controller.active and jump.used_jumps == 1, "respawn restores controllable default jump state")
	await fixture()
	await ticks(30)
	router.clear("empty_hand_focus_loss")
	key_event(KEY_SPACE, true)
	await ticks(1)
	check(jump.used_jumps == 1, "empty-handed cancel accepts first new Space press")
	key_event(KEY_SPACE, false)
	controller.reset_at(Vector2(80, 150))
	await ticks(30)
	key_event(KEY_SPACE, true)
	router.clear("held_space_focus_loss")
	key_event(KEY_SPACE, false)
	await ticks(1)
	check(jump.used_jumps == 0, "held Space cancellation and release do not jump")
	key_event(KEY_SPACE, true)
	await ticks(1)
	check(jump.used_jumps == 1, "fresh Space press works after blocked key release")
	key_event(KEY_SPACE, false)
	key_event(KEY_D, true)
	router.clear("held_movement_cancel")
	key_event(KEY_D, true)
	check(router.axis == 0.0, "old held movement key stays suppressed")
	key_event(KEY_A, true)
	check(router.axis == -1.0, "fresh other key is accepted while old key awaits release")
	key_event(KEY_A, false)
	key_event(KEY_D, false)
	key_event(KEY_D, true)
	check(router.axis == 1.0, "movement key rearms after real release")
	key_event(KEY_D, false)
	print("PASS GROUP: injected keyboard cancel and rearming")
	await fixture()
	await ticks(30)
	jump.tuning.jump_buffer = 0.0
	await press_jump()
	check(jump.used_jumps == 1 and motor.normal_velocity.y < 0.0, "zero buffer permits immediate grounded jump")
	await fixture(Vector2(80, 175))
	jump.tuning.max_jumps = 1
	jump.tuning.jump_buffer = 0.0
	await press_jump()
	await ticks(8)
	check(motor.is_on_floor() and jump.used_jumps == 0, "zero buffer does not retain rejected airborne request")
	for elapsed_ticks: int in [5, 6, 7]:
		await fixture(Vector2(80, 150), 160.0)
		await ticks(30)
		router.set_move_axis(1.0)
		while motor.is_on_floor():
			await ticks(1)
		await ticks(elapsed_ticks - 1)
		await press_jump()
		check(jump.used_jumps == (1 if elapsed_ticks < 6 else 2), "100ms coyote boundary at %d ticks" % elapsed_ticks)
	for landing_ticks: int in [6, 7, 8]:
		# Place halfway between consecutive free-fall distances, so changing
		# gravity does not change the real landing tick used to test expiry.
		var gravity := PlayerTuning.load_default().gravity
		var prior_fall := gravity * DT * DT * (landing_ticks - 1) * landing_ticks / 2.0
		var next_fall := gravity * DT * DT * landing_ticks * (landing_ticks + 1) / 2.0
		var start_y := 182.0 - (prior_fall + next_fall) / 2.0
		await fixture(Vector2(80, start_y))
		jump.tuning.max_jumps = 1
		await press_jump()
		await ticks(landing_ticks - 1)
		var before_expiry := landing_ticks < 7
		check((jump.used_jumps == 1 and motor.normal_velocity.y < 0.0) if before_expiry else (jump.used_jumps == 0 and motor.is_on_floor()), "100ms buffer real-landing boundary at age %d ticks" % (landing_ticks - 1))
	print("PASS GROUP: zero-buffer immediate intent and exact 100ms boundaries")
	await fixture()
	await ticks(30)
	router.request_action(&"jump")
	jump.enabled = false
	jump.enabled = true
	await ticks(1)
	check(jump.used_jumps == 0, "disable and reenable cancels old queued jump in same tick")
	await press_jump()
	check(jump.used_jumps == 1, "fresh jump works after capability reenabled")
	var isolated_router := InputRouter.new()
	world.add_child(isolated_router)
	isolated_router.request_action(&"jump")
	isolated_router.request_action(&"shoot_release", Vector2.RIGHT)
	isolated_router.cancel_actions_for(&"jump")
	var retained := isolated_router.consume_actions(1)
	check(retained.size() == 1 and retained[0].type == &"shoot_release", "targeted capability cancellation preserves independent shoot intent")
	print("PASS GROUP: capability removal clears only its queued actions")
	world.free()
	await preload("res://tests/combat_tests.gd").new().run(self, check)
	await preload("res://tests/input_tests.gd").new().run(self, check)
	await preload("res://tests/world_tests.gd").new().run(self, check)
	await preload("res://tests/gamefeel_tests.gd").new().run(self, check)
	await preload("res://tests/variable_jump_tests.gd").new().run(self, check)
	await preload("res://tests/air_focus_tests.gd").new().run(self, check)
	print("ALL TESTS: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures > 0 else 0)
