extends RefCounted

const SUITE := preload("res://tests/combat_tests.gd")
const DT := 1.0 / 60.0
var tree: SceneTree
var check: Callable
var fixture: RefCounted

func ticks(count: int) -> void:
	for index: int in count:
		await tree.physics_frame
		fixture.controller.physics_tick(DT)

func run(p_tree: SceneTree, p_check: Callable) -> void:
	tree = p_tree
	check = p_check
	fixture = SUITE.new()
	fixture.tree = tree
	await fixture.fixture(Vector2(80, -300))
	var motor: PlayerMotor = fixture.motor
	motor.normal_velocity.y = motor.tuning.max_normal_fall_speed
	var y := motor.position.y
	check.call(fixture.shoot.try_fire(Vector2.DOWN, false), "downward shot accepted at terminal fall")
	await ticks(1)
	check.call(motor.position.y < y and motor.velocity.y < -1000.0 and motor.normal_velocity.y == 0.0, "downward shot immediately reverses terminal fall and freezes gravity")
	await ticks(8)
	var burst_distance := y - motor.position.y
	check.call(absf(burst_distance - 154.0) < 0.1, "complete unobstructed burst travels configured 154 units: %.3f" % burst_distance)
	check.call(motor.recoil_burst_remaining == 0.0 and motor.recoil_velocity == Vector2.ZERO, "burst ends without residual impulse")
	await ticks(1)
	check.call(motor.normal_velocity.y > 0.0 and motor.position.y > y - burst_distance, "ordinary gravity resumes after burst")
	await fixture.fixture(Vector2(80, -300))
	motor = fixture.motor
	fixture.shoot.try_fire(Vector2.LEFT, false)
	await ticks(1)
	fixture.shoot.cooldown_remaining = 0.0
	check.call(fixture.shoot.try_fire(Vector2.LEFT, false) and is_equal_approx(motor.recoil_velocity.length(), 1100.0), "two successful shots restart burst without stacking")
	await ticks(1)
	check.call(is_equal_approx(motor.velocity.x, 1100.0), "second shot speed remains configured constant")
	fixture.controller.router.set_move_axis(-1.0)
	var x := motor.position.x
	await ticks(1)
	check.call(motor.position.x > x and motor.normal_velocity.x == -330.0, "opposite steering updates takeover velocity without cancelling burst")
	await ticks(7)
	check.call(motor.recoil_burst_remaining == 0.0 and motor.normal_velocity.x == -330.0, "steering prepared during burst is retained")
	await fixture.fixture(Vector2(80, 80))
	motor = fixture.motor
	fixture.body(Rect2(105, 0, 1, 200))
	await tree.physics_frame
	fixture.shoot.try_fire(Vector2.LEFT, false)
	await ticks(2)
	check.call(motor.position.x <= 93.1 and motor.recoil_velocity.x == 0.0, "burst wall projects persistent velocity")
	await ticks(5)
	check.call(motor.position.x <= 93.1 and motor.recoil_velocity.x == 0.0, "wall-blocked burst never revives next frame")
	await fixture.fixture(Vector2(80, 80))
	motor = fixture.motor
	fixture.body(Rect2(0, 40, 200, 1))
	await tree.physics_frame
	fixture.shoot.try_fire(Vector2.DOWN, false)
	await ticks(2)
	check.call(motor.position.y >= 58.9 and motor.recoil_velocity.y == 0.0, "burst ceiling projects persistent upward velocity")
	await ticks(5)
	check.call(motor.position.y >= 58.9 and motor.recoil_velocity.y == 0.0, "ceiling-blocked burst never revives")
	await fixture.fixture(Vector2(80, -300))
	motor = fixture.motor
	fixture.shoot.try_fire(Vector2.DOWN, false)
	fixture.controller.recoil_ability.enabled = false
	check.call(motor.recoil_burst_remaining == 0.0 and motor.recoil_velocity == Vector2.ZERO, "disabling recoil immediately cancels burst")
	fixture.controller.recoil_ability.enabled = true
	fixture.shoot.cooldown_remaining = 0.0
	fixture.shoot.try_fire(Vector2.DOWN, false)
	fixture.controller.die()
	check.call(motor.recoil_burst_remaining == 0.0 and motor.velocity == Vector2.ZERO, "death clears burst timer and velocity")
	fixture.controller.reset_at(Vector2(80, -300))
	check.call(motor.recoil_burst_remaining == 0.0 and motor.normal_velocity == Vector2.ZERO, "respawn has no old burst")
	motor.tuning.recoil_mode = "legacy_impulse"
	fixture.shoot.try_fire(Vector2.DOWN, false)
	await ticks(1)
	check.call(is_equal_approx(motor.recoil_velocity.y, -520.0 * exp(-DT / 0.16)) and motor.recoil_burst_remaining == 0.0, "legacy impulse mode retains exponential trajectory")
	var distances: Array[float] = []
	for initial_fall: float in [-840.0, 1000.0]:
		await fixture.fixture(Vector2(80, -300))
		motor = fixture.motor
		motor.normal_velocity.y = initial_fall
		var start_x := motor.position.x
		fixture.shoot.try_fire(Vector2.LEFT, false)
		await ticks(9)
		distances.append(motor.position.x - start_x)
		check.call(motor.normal_velocity.y == 0.0 and absf(distances.back() - 154.0) < 0.1, "horizontal burst freezes and clears prior jump/fall: %s" % initial_fall)
	check.call(absf(distances[0] - distances[1]) < 0.1, "jumping/falling start gives identical burst distance")
	var peaks: Array[float] = []
	for mode: String in ["legacy_impulse", "shot_burst"]:
		await fixture.fixture(Vector2(80, -300))
		motor = fixture.motor
		motor.tuning.recoil_mode = mode
		if mode == "legacy_impulse":
			motor.tuning.gravity = 1250.0
			motor.tuning.max_normal_fall_speed = 900.0
		var initial_y := motor.position.y
		var peak := initial_y
		fixture.shoot.try_fire(Vector2.DOWN, false)
		for index: int in 70:
			await ticks(1)
			peak = minf(peak, motor.position.y)
		peaks.append(initial_y - peak)
	check.call(peaks[1] > peaks[0] * 2.0 and absf(peaks[1] - 154.0) < 0.1, "actual shot peak increases from legacy %.3f to burst %.3f" % [peaks[0], peaks[1]])
	await fixture.fixture(Vector2(80, -300))
	motor = fixture.motor
	motor.normal_velocity.x = motor.tuning.ground_speed
	fixture.controller.router.set_move_axis(-1.0)
	var reversal_ticks := 0
	while motor.normal_velocity.x > -motor.tuning.ground_speed and reversal_ticks < 30:
		await ticks(1)
		reversal_ticks += 1
	check.call(reversal_ticks == 2 and motor.position.x <= 80.0, "actual full air reversal takes 2 ticks with 330 speed")
	print("GAMEFEEL MEASUREMENTS: legacy peak=%.3f burst peak=%.3f; rising/falling horizontal burst=%s; air reversal=%d ticks" % [peaks[0], peaks[1], str(distances), reversal_ticks])
	fixture.world.free()
	print("PASS GROUP: shot burst movement, legacy comparison, collisions and cancellation")
