extends SceneTree
## Actual near-apex jump-chain samples; not a proof of a global reachable set.
const FIXTURE := preload("res://tests/combat_tests.gd")
var failures := 0
var assertions := 0
func _initialize() -> void:
	_run.call_deferred()
func check(value: bool, description: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("FAIL: " + description)
func sample(count: int) -> Dictionary:
	var f := FIXTURE.new()
	f.tree = self
	await f.fixture()
	f.motor.tuning.max_jumps = count
	await f.ticks(30)
	var start: float = f.motor.position.y
	var peak := start
	var requested := 1
	var shots := [0]
	f.shoot.shot_fired.connect(func(_direction: Vector2, _id: int): shots[0] += 1)
	f.controller.router.request_action(&"jump")
	for tick: int in 180:
		if tick > 2 and requested < count and f.motor.normal_velocity.y >= 0.0 and not f.motor.is_on_floor():
			f.controller.router.request_action(&"jump")
			requested += 1
		await f.ticks(1)
		peak = minf(peak, f.motor.position.y)
		if tick > 2 and f.motor.is_on_floor():
			break
	var row := {"jump_count": count, "height_px": start - peak, "shots": shots[0], "landed": f.motor.is_on_floor()}
	f.world.free()
	return row
func _run() -> void:
	var one := await sample(1)
	var two := await sample(2)
	check(one.landed and two.landed, "both measured chains return to real floor")
	check(one.shots == 0 and two.shots == 0, "jump-only measurements emit no projectiles")
	check(float(one.height_px) < 260.0 and float(two.height_px) > 260.0, "260px rise is above one jump but below measured double-jump height")
	check(float(two.height_px) > float(one.height_px), "second jump changes reachable vertical height")
	if "--verify-failure-exit" in OS.get_cmdline_user_args():
		check(false, "intentional measurement failure")
	print("JUMP CHAIN SAMPLES: " + JSON.stringify([one, two]))
	print("JUMP CHAIN: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
