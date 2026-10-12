extends SceneTree
var assertions := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var driver = load("res://tests/plains_run_trace.gd").new()
	driver.tree = self
	driver.check = check
	var kinds: Array[StringName] = [&"combat",&"combat",&"item_reward",&"shop",&"combat",&"item_reward",&"health_reward"]
	for seed: String in ["polish-density-0","polish-density-1","polish-density-2"]:
		for index: int in range(1,8):
			var data := PlainsStageGenerator.new().generate(seed,index,kinds[index-1],PlayerTuning.load_default())
			check(data.ok,"three Seed route fixture succeeds")
			if data.ok: await driver.route(data.manifest,PlayerTuning.load_default(),"%s room%s terrain/bell proof" % [seed,index])
	if is_instance_valid(driver.world): driver.world.free()
	print("PLAINS POLISH ROUTES: %s assertions, %s failures" % [assertions,failures])
	quit(1 if failures else 0)
