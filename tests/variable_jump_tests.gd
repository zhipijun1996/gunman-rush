extends RefCounted

const SUITE := preload("res://tests/combat_tests.gd")
const DT := 1.0 / 60.0
var tree: SceneTree
var check: Callable
var fixture: RefCounted

func ticks(count: int) -> void:
	await fixture.ticks(count)

func edges(types: Array[StringName]) -> void:
	for type: StringName in types:
		fixture.controller.router.request_action(type)

func peak(held_ticks: int) -> float:
	await fixture.fixture()
	await ticks(30)
	var start: float = fixture.motor.position.y
	var minimum := start
	edges([&"jump"])
	if held_ticks == 0:
		edges([&"jump_release"])
	for tick: int in 65:
		if tick == held_ticks and held_ticks > 0:
			edges([&"jump_release"])
		await ticks(1)
		minimum = minf(minimum, fixture.motor.position.y)
	return start - minimum

func run(p_tree: SceneTree, p_check: Callable) -> void:
	tree = p_tree
	check = p_check
	fixture = SUITE.new()
	fixture.tree = tree
	var short_height := await peak(0)
	var medium_height := await peak(7)
	var long_height := await peak(12)
	var maximum_height := await peak(30)
	var unreleased_height := await peak(60)
	print("VARIABLE JUMP PEAKS: tap=%.3f medium=%.3f long=%.3f overhold=%.3f" % [short_height, medium_height, long_height, maximum_height])
	check.call(short_height > 0.0 and medium_height > short_height + 15.0 and long_height > medium_height + 15.0, "real short/medium/long jump peaks increase with held duration")
	check.call(absf(unreleased_height - maximum_height) < 0.01, "holding beyond maximum duration cannot gain unlimited height")
	for held_ticks: int in [6, 9, 12]:
		await fixture.fixture()
		await ticks(30)
		edges([&"jump"])
		await ticks(held_ticks)
		edges([&"jump_release"])
		await ticks(1)
		check.call(fixture.motor.normal_velocity.y >= 0.0, "release cuts owned ascent at %d ticks, including after sustain timeout" % held_ticks)
	await fixture.fixture()
	await ticks(30)
	edges([&"jump", &"jump_release", &"jump"])
	await ticks(1)
	check.call(fixture.controller.jump_ability.used_jumps == 1 and fixture.motor.normal_velocity.y < -500.0, "same-tick press release repress leaves fresh hold active")
	edges([&"jump_release"])
	await ticks(4)
	check.call(fixture.motor.normal_velocity.y >= -250.0, "release cuts only ordinary upward velocity")
	edges([&"jump"])
	await ticks(1)
	check.call(fixture.controller.jump_ability.used_jumps == 2 and fixture.motor.normal_velocity.y < -500.0, "second jump starts independent hold and uses second speed")
	for maximum: int in [0, 1, 3, 5]:
		await fixture.fixture()
		fixture.motor.tuning.max_jumps = maximum
		await ticks(30)
		for index: int in maximum:
			edges([&"jump", &"jump_release"])
			await ticks(1)
		check.call(fixture.controller.jump_ability.used_jumps == maximum, "variable jump supports configured %d jumps" % maximum)
		edges([&"jump"])
		await ticks(1)
		check.call(fixture.controller.jump_ability.used_jumps == maximum, "variable jump does not exceed %d charges" % maximum)
	await fixture.fixture(Vector2(80, 170))
	fixture.motor.tuning.max_jumps = 1
	edges([&"jump", &"jump_release"])
	await ticks(7)
	check.call(fixture.controller.jump_ability.used_jumps == 1 and fixture.motor.normal_velocity.y < 0.0, "released buffered tap lands then launches its minimum ascent")
	await ticks(5)
	check.call(fixture.motor.normal_velocity.y >= 0.0, "released buffered tap cuts ascent after minimum hold")
	await ticks(60)
	check.call(fixture.motor.is_on_floor() and fixture.controller.jump_ability.used_jumps == 0, "buffered released tap never repeats on next landing")
	await fixture.fixture()
	fixture.body(Rect2(0, 120, 200, 15))
	await ticks(30)
	edges([&"jump"])
	await ticks(5)
	check.call(fixture.motor.position.y >= 152.9 and fixture.motor.normal_velocity.y >= 0.0, "ceiling collision ends held ascent")
	await ticks(3)
	check.call(fixture.motor.normal_velocity.y >= 0.0, "held key cannot revive ascent after ceiling projection")
	await fixture.fixture()
	await ticks(30)
	edges([&"jump"])
	await ticks(1)
	fixture.shoot.try_fire(Vector2.DOWN, false)
	edges([&"jump_release"])
	await ticks(1)
	check.call(fixture.motor.recoil_velocity.y == -1100.0 and fixture.motor.velocity.y == -1100.0, "jump release leaves shoot burst magnitude unchanged")
	edges([&"jump"])
	await ticks(1)
	check.call(fixture.motor.recoil_burst_remaining == 0.0 and fixture.motor.recoil_velocity == Vector2.ZERO and fixture.motor.normal_velocity.y < -500.0, "fresh jump interrupts burst and begins jump immediately")
	await fixture.fixture()
	await ticks(30)
	edges([&"jump"])
	await ticks(1)
	var prior: float = fixture.motor.normal_velocity.y
	fixture.controller.router.clear("focus_loss")
	await ticks(1)
	check.call(is_equal_approx(fixture.motor.normal_velocity.y, prior + fixture.motor.tuning.gravity * DT), "cancel ends hold without resuming old key state")
	fixture.controller.die()
	fixture.controller.reset_at(Vector2(80, 150))
	await ticks(30)
	check.call(fixture.motor.is_on_floor() and fixture.controller.jump_ability.used_jumps == 0, "death and respawn clear hold without old jump revival")
	edges([&"jump"])
	await ticks(1)
	fixture.controller.jump_ability.enabled = false
	prior = fixture.motor.normal_velocity.y
	await ticks(1)
	check.call(is_equal_approx(fixture.motor.normal_velocity.y, prior + fixture.motor.tuning.gravity * DT), "ability disable ends active hold")
	await fixture.fixture()
	await ticks(30)
	edges([&"jump"])
	await ticks(1)
	fixture.motor.tuning.recoil_mode = "legacy_impulse"
	fixture.shoot.try_fire(Vector2.DOWN, false)
	prior = fixture.motor.normal_velocity.y
	edges([&"jump_release"])
	await ticks(1)
	check.call(is_equal_approx(fixture.motor.normal_velocity.y, prior + fixture.motor.tuning.gravity * DT), "successful legacy shot cancels jump ownership so release does not cut old ascent")
	fixture.world.free()
