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
	var tuning := PlayerTuning.load_default()
	var generator := RandomStageGenerator.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var ids: Array[String] = ["micro_board", "micro_board", "plains_split_terrace", "plains_long_meadow", "micro_board", "micro_board", "micro_board", "route_junction"]
	if "--verify-invalid-fixture" in OS.get_cmdline_user_args():
		ids[3] = "micro_board"
	var manifest := generator._assemble_manifest(ids, 2, tuning, 0, "", rng, "plains_run_service", true)
	var validated := generator.validate_manifest(manifest, tuning)
	check(validated.ok, "exit route fixture retains full manifest geometry validation: " + str(validated.error))
	if not validated.ok:
		print("PLAINS EXIT ROUTES: %d assertions, %d failures" % [assertions, failures])
		quit(1)
		return
	var driver = load("res://tests/plains_run_trace.gd").new()
	driver.tree = self
	driver.check = check
	await driver.route(manifest, tuning, "separate-exit route main floor")
	if driver.stage == null or driver.stage.modules.size() != ids.size():
		check(false, "invalid assembled fixture stops before dereferencing its route nodes")
		if is_instance_valid(driver.world):
			driver.world.free()
		print("PLAINS EXIT ROUTES: %d assertions, %d failures" % [assertions, failures])
		quit(1)
		return
	var terminal: PlatformingModule = driver.stage.modules.back()
	check(await driver.move_to(terminal.position.x + 480), "upper exit reaches safe floor takeoff outside middle ledge")
	check(await driver.jump_to(terminal.position.x + 320), "upper exit first jump reaches middle ledge")
	check(absf(driver.motor.global_position.y - terminal.position.y - 512) < 1, "upper exit middle step is grounded at expected height")
	check(await driver.jump_to(terminal.position.x + 160), "upper exit second jump reaches high-left route choice")
	check(driver.motor.is_on_floor() and driver.motor.global_position.distance_to(terminal.position + Vector2(160, 462)) < 1, "separated upper exit has actual full-body Motor reachability")
	# Walk back on the floor, then prove the optional coin exploration shelf.
	check(await driver.move_to(terminal.position.x + 480), "upper exit returns outward beyond intermediate ledge before descending")
	await driver.tick(30)
	var terrace: PlatformingModule = driver.stage.modules[2]
	check(await driver.move_to(terrace.position.x + 230, 600), "optional exploration returns over a continuous safe floor")
	check(await driver.jump_to(terrace.position.x + 380), "optional exploration climbs the first 75px shelf")
	check(await driver.move_to(terrace.position.x + 430), "optional exploration reaches second takeoff")
	check(await driver.jump_to(terrace.position.x + 610), "optional exploration climbs second shelf by a real held jump")
	check(driver.motor.is_on_floor() and absf(driver.motor.global_position.y - terrace.position.y - 132) < 1, "upper coin shelf is actually reachable without recoil or extra resources")
	check(driver.safe_trace and driver.continuous_trace, "optional branches preserve full-body swept safety and never teleport")
	if is_instance_valid(driver.world):
		driver.world.free()
	print("PLAINS EXIT ROUTES: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures > 0 else 0)
