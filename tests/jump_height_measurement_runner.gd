extends SceneTree
const FIXTURE := preload("res://tests/combat_tests.gd")
const DT := 1.0 / 60.0
var samples: Array[Dictionary] = []
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func measure(hold: float, release_ticks: int) -> Dictionary:
	var fixture := FIXTURE.new()
	fixture.tree = self
	await fixture.fixture()
	fixture.motor.tuning.jump_hold_duration = hold
	await fixture.ticks(30)
	var start: float = fixture.motor.position.y
	var minimum := start
	fixture.controller.router.request_action(&"jump")
	if release_ticks == 0:
		fixture.controller.router.request_action(&"jump_release")
	var apex_tick := 0
	var landed_tick := 0
	for tick: int in 90:
		if tick == release_ticks and release_ticks > 0:
			fixture.controller.router.request_action(&"jump_release")
		await fixture.ticks(1)
		if fixture.motor.position.y < minimum:
			minimum = fixture.motor.position.y
			apex_tick = tick + 1
		if tick > 1 and fixture.motor.is_on_floor():
			landed_tick = tick + 1
			break
	var row := {"hold_seconds": hold, "release_ticks": release_ticks, "height_world_px": start - minimum, "apex_seconds": apex_tick * DT, "air_seconds": landed_tick * DT, "body_size": [24, 36], "hz": 60}
	fixture.world.free()
	return row
func run() -> void:
	for hold: float in [0.15, 0.13]:
		for release_ticks: int in [0, 7, 30]:
			samples.append(await measure(hold, release_ticks))
	var old_big: float = samples[2].height_world_px
	var new_big: float = samples[5].height_world_px
	for passed: bool in [absf(float(samples[0].height_world_px) - float(samples[3].height_world_px)) < 0.01, new_big < old_big, new_big >= 100.0]:
		if not passed:
			failures += 1
	if "--prove-failure" in OS.get_cmdline_user_args():
		failures += 1
	print("JUMP MEASUREMENT JSON: " + JSON.stringify(samples))
	print("JUMP MEASUREMENT: 3 assertions, %d failures" % failures)
	quit(1 if failures else 0)
