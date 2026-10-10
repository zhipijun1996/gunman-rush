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
	var arrangements: Dictionary = {}
	var mechanisms: Dictionary = {}
	var type_distribution: Dictionary = {}
	var formal := PlainsStageGenerator.new()
	for seed: int in 30:
		for type: StringName in [&"combat", &"coin_reward", &"item_reward"]:
			var room_index := 1 + seed % 7
			var generated := formal.generate("spatial-proof-%d" % seed, room_index, type, tuning)
			check(generated.ok, "formal branch request completes within bounded port-graph assembly: " + str(generated.get("error", "")))
			if not generated.ok:
				continue
			var manifest: Dictionary = generated.manifest
			check(generator.validate_manifest(JSON.parse_string(JSON.stringify(manifest)), tuning).ok, "full terminal graph replays after JSON without reseeding")
			check(generator._same_data(manifest, formal.generate("spatial-proof-%d" % seed, room_index, type, tuning).manifest), "same independent map stream reproduces graph and terrain")
			check(manifest.manifest_version == 9 and generated.stage_generator_version == "plains-run-v6-grounded-comfort", "formal branch content records current incompatible map and stage versions")
			check(manifest.fallback_id.is_empty() and manifest.branch_fallback_reason.is_empty() and manifest.layout_id == "branched_terminal_paths", "default action rooms use assembled disjoint branches without safe fallback")
			check(manifest.common_path.size() >= 3 and manifest.terminal_paths.size() == 2 and manifest.fork_node == manifest.common_path[-1], "shared approach reaches one real fork and two separate terminal routes")
			for branch: int in 2:
				var path: Array = manifest.terminal_paths[branch]
				var exit_data: Dictionary = manifest.terminal_exits[branch]
				check(path.size() >= 2 and exit_data.node == path[-1] and manifest.nodes[path[-1]].module_id == "plains_door_landing" and exit_data.node not in manifest.common_path, "each door belongs only to the end of its nonempty branch")
				var first_seam: Dictionary = manifest.seams[int(path[0]) - 1]
				check(first_seam.from == manifest.fork_node and first_seam.from_port_id == ("fork_up" if branch == 0 else "fork_right"), "upper and right branches connect independent actual fork ports")
			families[manifest.spatial_family] = true
			var distribution: Dictionary = type_distribution.get(str(type), {})
			distribution[manifest.spatial_family] = int(distribution.get(manifest.spatial_family, 0)) + 1
			type_distribution[str(type)] = distribution
			footprints[JSON.stringify(manifest.world_bounds)] = true
			var placement: Array = []
			for node: Dictionary in manifest.nodes:
				placement.append([node.module_id, node.offset, node.initial_phases])
				var definition := generator.definition_for(node.module_id, node.mirrored, node.reverse_traversal)
				if not definition.saws.is_empty(): mechanisms["gear"] = true
				if not definition.ferries.is_empty(): mechanisms["moving_platform"] = true
				if not definition.danger_bounds.is_empty(): mechanisms["bramble"] = true
				if node.module_id.begins_with("plains_recoil_"): mechanisms["recoil"] = true
			arrangements[JSON.stringify(placement)] = true
			var altered := manifest.duplicate(true)
			altered.route_graph.edges[0].to = "missing_anchor"
			_reject_signed(altered, tuning, generator, "recorded route graph tampering")
			altered = manifest.duplicate(true)
			altered.terminal_paths[1][0] = altered.terminal_paths[0][0]
			_reject_signed(altered, tuning, generator, "overlapping branch ownership")
			altered = manifest.duplicate(true)
			altered.fork_node = 0
			_reject_signed(altered, tuning, generator, "fork moved into spawn")
			altered = manifest.duplicate(true)
			altered.seams[int(altered.terminal_paths[0][0]) - 1].from_port_id = "fork_right"
			_reject_signed(altered, tuning, generator, "upper branch falsely attached to right port")
			altered = manifest.duplicate(true)
			altered.seams[0].point[0] += 1
			_reject_signed(altered, tuning, generator, "noncoincident seam")
			altered = manifest.duplicate(true)
			altered.terminal_exits[0].node = altered.fork_node
			_reject_signed(altered, tuning, generator, "door placed along common approach")
			altered = manifest.duplicate(true)
			altered.terminal_exits[0].position[0] += 10
			_reject_signed(altered, tuning, generator, "door position detached from terminal port")
	check(families.size() >= 2 and footprints.size() > 10 and arrangements.size() > 60, "seed sample spans both meadow/recoil branches, eleven actual AABBs and sixty-one module/phase arrangements")
	check(mechanisms.has("gear") and mechanisms.has("moving_platform") and mechanisms.has("bramble") and mechanisms.has("recoil"), "formal type/index sample actually draws all four challenge mechanisms")
	print("SPATIAL SAMPLE: requests=90 families=%d footprints=%d arrangements=%d mechanisms=%s types=%s" % [families.size(), footprints.size(), arrangements.size(), JSON.stringify(mechanisms), JSON.stringify(type_distribution)])
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

func _reject_signed(altered: Dictionary, tuning: PlayerTuning, generator: RandomStageGenerator, reason: String) -> void:
	altered.manifest_hash = generator._manifest_hash(altered)
	check(not generator.validate_manifest(altered, tuning).ok, "signed manifest must reject " + reason)
