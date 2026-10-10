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
	var families: Dictionary = {}
	var footprints: Dictionary = {}
	var type_distribution: Dictionary = {}
	var formal := PlainsStageGenerator.new()
	for seed: int in 30:
		for type: StringName in [&"combat", &"coin_reward", &"item_reward"]:
			var generated := formal.generate("spatial-proof-%d" % seed, 5, type, tuning)
			check(generated.ok, "formal spatial request completes within one bounded template assembly: " + str(generated.get("error", "")))
			if not generated.ok:
				continue
			var manifest: Dictionary = generated.manifest
			check(generator.validate_manifest(JSON.parse_string(JSON.stringify(manifest)), tuning).ok, "full spatial graph replays after JSON without reseeding")
			check(generator._same_data(manifest, formal.generate("spatial-proof-%d" % seed, 5, type, tuning).manifest), "same independent map stream reproduces graph and terrain")
			check(manifest.fallback_id.is_empty() and manifest.spatial_family != "corridor", "default action rooms really use spatial geometry rather than flat fallback")
			var ratio := float(manifest.world_bounds[2]) / float(manifest.world_bounds[3])
			check(ratio < 1.0 if manifest.spatial_family == "plains_wind_spire" else (ratio < 1.6 if manifest.spatial_family == "plains_switchback" else ratio > 3.0), "whole-room actual geometry follows vertical, near-square or horizontal family contract")
			families[manifest.spatial_family] = true
			var distribution: Dictionary = type_distribution.get(str(type), {})
			distribution[manifest.spatial_family] = int(distribution.get(manifest.spatial_family, 0)) + 1
			type_distribution[str(type)] = distribution
			footprints[JSON.stringify(manifest.world_bounds)] = true
			var altered := manifest.duplicate(true)
			altered.route_graph.edges[0].to = "missing_anchor"
			altered.manifest_hash = generator._manifest_hash(altered)
			check(not generator.validate_manifest(altered, tuning).ok, "even signed graph edge tampering is rejected against actual module paths")
	check(families.size() == 3 and footprints.size() > 10, "seed sample spans three real shapes and at least eleven distinct bounds")
	print("SPATIAL SAMPLE: requests=90 families=%d footprints=%d types=%s" % [families.size(), footprints.size(), JSON.stringify(type_distribution)])
	var driver = load("res://tests/plains_run_trace.gd").new()
	driver.tree = self
	driver.check = check
	for id: String in ["plains_braided_meadow", "plains_switchback", "plains_wind_spire"]:
		var generated := generator.generate_spatial(4, tuning, "plains_run_coin", id)
		check(generated.ok, "all spatial families use complete strictly validated recordings")
		if not generated.ok:
			continue
		var graph: Dictionary = generated.manifest.route_graph
		print("SPATIAL FAMILY: id=%s bounds=%s nodes=%d main_edges=%d optional_edges=%d" % [id, str(generated.manifest.world_bounds), generated.manifest.nodes.size(), graph.edges.filter(func(edge: Dictionary): return edge.kind != "optional_branch").size(), graph.edges.filter(func(edge: Dictionary): return edge.kind == "optional_branch").size()])
		if "--contracts-only" in OS.get_cmdline_user_args():
			continue
		await driver.route(generated.manifest, tuning, "spatial family %s" % id)
		if id == "plains_braided_meadow":
			var meadow: PlatformingModule = driver.stage.modules[2]
			check(await driver.fixture(generated.manifest, tuning), "optional upper path begins in a fresh identical recording")
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
