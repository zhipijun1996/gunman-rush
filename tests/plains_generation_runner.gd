extends SceneTree
var assertions := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
func _run() -> void:
	var driver_script: Script = load("res://tests/random_stage_tests.gd")
	if driver_script == null or not driver_script.can_instantiate():
		quit(1)
		return
	var driver = driver_script.new()
	driver.tree = self
	driver.check = check
	var generator := RandomStageGenerator.new()
	driver.plains_contracts(generator)
	var tuning := PlayerTuning.load_default()
	for profile: String in ["plains_intro", "plains_standard"]:
		var generated := generator.generate(3, tuning, 14, profile)
		check(generated.ok and generated.manifest.fallback_id.is_empty(), "plains actual route starts from nonfallback recording")
		if generated.ok:
			await driver.route(generated.manifest, tuning, profile + " complete real Motor route")
	if is_instance_valid(driver.world):
		driver.world.free()
	print("PLAINS GENERATION: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures > 0 else 0)
