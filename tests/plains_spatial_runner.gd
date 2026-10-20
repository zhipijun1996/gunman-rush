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
	if "--verify-failure-exit" in OS.get_cmdline_user_args():
		check(false, "intentional spatial failure exit")
		print("PLAINS SPATIAL: %d assertions, %d failures" % [assertions, failures])
		quit(1)
		return
	var tuning := PlayerTuning.load_default()
	var generator := RandomStageGenerator.new()
	# Recalibrated authored spatial fixtures must work at the new 260 baseline
	# with only ONE jump and ZERO shots, not silently borrow the default second.
	var spatial_tuning := PlayerTuning.load_default()
	spatial_tuning.max_jumps = 1
	spatial_tuning.max_air_shots = 0
	var below_gate := PlayerTuning.load_default()
	below_gate.ground_speed = 259.0
	var driver = load("res://tests/plains_run_trace.gd").new()
	driver.tree = self
	driver.check = check
	for id: String in ["plains_braided_meadow", "plains_switchback", "plains_wind_spire"]:
		check(not generator.definition_for(id).supports(below_gate), "spatial 260-speed gate rejects lower unverified capability")
		var generated := generator.generate_spatial(4, spatial_tuning, "plains_run_coin", id)
		check(generated.ok, "all spatial families use complete strictly validated recordings")
		if not generated.ok:
			continue
		var graph: Dictionary = generated.manifest.route_graph
		print("SPATIAL FAMILY: id=%s bounds=%s nodes=%d main_edges=%d optional_edges=%d" % [id, str(generated.manifest.world_bounds), generated.manifest.nodes.size(), graph.edges.filter(func(edge: Dictionary): return edge.kind != "optional_branch").size(), graph.edges.filter(func(edge: Dictionary): return edge.kind == "optional_branch").size()])
		if "--contracts-only" in OS.get_cmdline_user_args():
			continue
		await driver.route(generated.manifest, spatial_tuning, "spatial family %s" % id)
		if id == "plains_braided_meadow":
			var meadow: PlatformingModule = driver.stage.modules[2]
			check(await driver.fixture(generated.manifest, spatial_tuning), "optional upper path begins in a fresh identical recording")
			meadow = driver.stage.modules[2]
			check(await driver.move_to(meadow.position.x + 200, 900), "upper branch reaches by physical movement through shared ground")
			await driver.spatial_path(meadow, meadow.definition.branch_routes[0])
			check(driver.safe_trace and driver.continuous_trace, "optional upper circuit also avoids every swept body hazard without teleport")
			check(driver.motor.global_position.distance_to(meadow.world_exit()) < 1, "optional path rejoins the main meadow route")
	if "--contracts-only" not in OS.get_cmdline_user_args():
		for phase: float in [0.0, 0.25, 0.5, 0.75]:
			var ids: Array[String] = ["micro_board", "micro_board", "plains_gear_hop", "plains_micro_landing", "plains_thorn_hop", "micro_board", "micro_board", "route_junction"]
			var rng := RandomNumberGenerator.new()
			rng.seed = 4
			var phase_manifest := generator._assemble_manifest(ids, 4, tuning, 0, "", rng, "plains_run_coin", true)
			phase_manifest.nodes[2].initial_phases[0].phase = phase
			phase_manifest.manifest_hash = generator._manifest_hash(phase_manifest)
			check(generator.validate_manifest(phase_manifest, tuning).ok, "quarter-phase danger proof is a fully validated serialized stage")
			await driver.route(phase_manifest, tuning, "compact danger quarter-phase %.2f" % phase)
	if is_instance_valid(driver.world):
		driver.world.free()
	print("PLAINS SPATIAL: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures > 0 else 0)
