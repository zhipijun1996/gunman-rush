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
		check(false, "intentional nonzero exit proof")
		quit(1)
		return
	var tuning := PlayerTuning.load_default()
	var generator := RandomStageGenerator.new()
	var stage_generator := PlainsStageGenerator.new()
	check(not stage_generator.generate("x", 8, &"combat", tuning).ok, "room eight cannot bypass Boss")
	check(not stage_generator.generate("x", 7, &"boss", tuning).ok, "Boss is terminal room eight")
	var types: Array[StringName] = [&"combat", &"coin_reward", &"shop", &"health_reward", &"item_reward", &"combat", &"coin_reward", &"boss"]
	var seen: Dictionary = {}
	for seed_index: int in 4:
		var seed_text := "plains-proof-%d" % seed_index
		var stage_seeds: Dictionary = {}
		for index: int in 8:
			var result := stage_generator.generate(seed_text, index + 1, types[index], tuning)
			check(result.ok, "formal room generation succeeds within bounded attempts")
			if not result.ok:
				continue
			var recorded: Dictionary = result.manifest
			check(generator.validate_manifest(recorded, tuning).ok, "formal manifest validates actual geometry and capability budget")
			check(not stage_seeds.has(recorded.seed), "each room owns an independent map seed")
			stage_seeds[recorded.seed] = true
			var replay := stage_generator.generate(seed_text, index + 1, types[index], tuning)
			check(generator._same_data(replay.manifest, recorded), "same seed/index/type replays full layout and phases")
			check(recorded.local_reflections and not recorded.mirrored and not recorded.nodes[0].mirrored, "formal start stays left while modules have individual reflection")
			check(result.exit_points.size() == 2 and result.exit_points[0].distance_to(result.exit_points[1]) > 200, "formal route doors have separate nonoverlapping approach radii")
			check(recorded.manifest_version == 9 and result.stage_generator_version == "plains-run-v6-grounded-comfort", "formal room records current layout/runtime compatibility versions")
			if types[index] != &"boss":
				check(recorded.layout_id == "branched_terminal_paths" and recorded.branch_fallback_reason.is_empty(), "default non-Boss formal room uses actual branch assembly without fallback")
				check(recorded.terminal_paths.size() == 2 and recorded.common_path[-1] == recorded.fork_node, "actual common approach forks into two routes")
				for branch: int in 2:
					var path: Array = recorded.terminal_paths[branch]
					check(path.size() >= 2 and recorded.terminal_exits[branch].node == path[-1] and recorded.nodes[path[-1]].module_id == "plains_door_landing", "door belongs to branch end rather than common approach")
			check(result.placement_points.all(func(point: Vector2): return point.y <= 282.001), "all standing anchors lie above lowest-left starting landing")
			check(not result.placement_points.is_empty(), "content placement has safe authored standing anchors")
			if types[index] in [&"shop", &"health_reward", &"boss"]:
				check(recorded.nodes.any(func(node: Dictionary): return node.module_id not in ["micro_board", "route_junction", "plains_boss_arena"]), "safe service/Boss entrance is independently varied, not only flat boards")
			for node: Dictionary in recorded.nodes:
				seen[node.module_id] = true
			if types[index] in [&"shop", &"health_reward", &"boss"]:
				for node: Dictionary in recorded.nodes:
					var definition := generator.definition_for(node.module_id)
					check(definition.danger_bounds.is_empty() and definition.saws.is_empty(), "service and Boss entrance avoid environmental pressure")
			if index == 7:
				check(result.boss_arena.size == Vector2(920, 350), "Boss attack space is fixed independently of random entrance")
	# Compact topology replaces some long tails; sample exploration seeds independently
	# rather than assuming every historic module must occur in four complete runs.
	for sample: int in 60:
		var exploration := stage_generator.generate("catalog-preservation-%d" % sample, 1 + sample % 7, [&"coin_reward", &"combat", &"item_reward"][sample % 3], tuning)
		check(exploration.ok, "expanded type sample preserves a bounded compatible spatial room")
		if exploration.ok:
			for node: Dictionary in exploration.manifest.nodes:
				seen[node.module_id] = true
	var upgraded := PlayerTuning.load_default()
	upgraded.max_jumps = 2 # Later unlocked ability fixture, never the plains baseline.
	var upgraded_seen: Dictionary = {}
	for sample: int in 60:
		var exploration := stage_generator.generate("upgraded-catalog-%d" % sample, 7, &"combat", upgraded)
		check(exploration.ok, "upgraded ability catalog remains generatable")
		if exploration.ok:
			for node: Dictionary in exploration.manifest.nodes:
				upgraded_seen[node.module_id] = true
			check(exploration.manifest.branch_profiles[1].risk == "steady", "upgraded player still receives a steady terminal choice")
			for node_index: int in exploration.manifest.terminal_paths[1]:
				var n: Dictionary = exploration.manifest.nodes[node_index]
				var d := generator.definition_for(n.module_id, n.mirrored, n.reverse_traversal)
				check(not d.requires_burst and not generator._hazardous(d), "upgrade does not replace safer approach with new mandatory damage/recoil")
	for locked: String in ["plains_recoil_chasm", "plains_recoil_chasm_wide"]:
		check(not seen.has(locked), "single-jump plains excludes incompatible two-jump module: " + locked)
		check(not upgraded_seen.has(locked), "new plains blueprint does not replace steady branch with a two-shot chasm after upgrade: " + locked)
		var definition := generator.definition_for(locked)
		check(definition != null and not definition.supports(tuning) and definition.supports(upgraded), "later two-jump authored module remains capability-gated in catalog and library Motor suite: " + locked)
	for id: String in ["plains_boss_arena", "plains_long_meadow", "plains_fork_paths", "plains_fork_rest", "plains_door_landing", "plains_recoil_step", "plains_recovery_bridge", "plains_perch_double", "plains_bramble_causeway", "plains_high_perches", "plains_bramble_ridge", "plains_ferry_one", "plains_ferry_two", "plains_thorn_bridge", "plains_thorn_steps", "plains_gear_brook", "plains_gear_glade", "plains_perch_rise", "plains_skip_stones"]:
		check(seen.has(id), "new module is actually drawn by formal generator: " + id)
	check(generator.definition_for("plains_recoil_double").supports(tuning), "two-transfer authored module remains in physical library despite simpler optional plains route")
	for blueprint: String in ["bridge_crossing", "windmill_ascent"]:
		var actual_blueprint_found := false
		for sample: int in 8:
			var room := stage_generator.generate("macro-pool-%d" % sample, 5, &"combat", tuning)
			if room.ok and room.manifest.blueprint_id == blueprint:
				actual_blueprint_found = true
				check(room.manifest.nodes[4].module_id == ("plains_recovery_bridge" if blueprint == "bridge_crossing" else "plains_perch_double"), "formal macro contains its defining recovery/climb action segment")
				check(room.manifest.branch_profiles[0].risk == "challenge" and room.manifest.branch_profiles[1].risk == "steady", "formal macro preserves meaningful risk choice")
		check(actual_blueprint_found, "formal generator draws actual blueprint: " + blueprint)
	for type_id: StringName in [&"combat", &"coin_reward", &"shop", &"health_reward", &"item_reward"]:
		var typed := stage_generator.generate("type-layout-proof", 5, type_id, tuning)
		check(typed.ok and typed.manifest.stage_type == str(type_id), "manifest records actual room content and spatial type")
		if typed.ok:
			check(typed.manifest.layout_id == "branched_terminal_paths", "all non-Boss types retain two actual terminal branches")
			if type_id in [&"shop", &"health_reward"]:
				check(typed.manifest.nodes.size() <= 12 and typed.manifest.nodes.all(func(node: Dictionary): return generator.definition_for(node.module_id).danger_bounds.is_empty() and generator.definition_for(node.module_id).saws.is_empty() and generator.definition_for(node.module_id).ferries.is_empty()), "service branches stay short and free from environmental pressure")
			else:
				check(typed.manifest.nodes.size() > 12 and typed.manifest.nodes.any(func(node: Dictionary): return node.module_id.begins_with("plains_recoil_")), "action branch rooms actually include expanded recoil challenges")
	var local_mirrors := 0
	for seed_value: int in 12:
		var local := stage_generator.generate("local-mirror-%d" % seed_value, 5, &"coin_reward", tuning)
		if local.ok:
			local_mirrors += local.manifest.nodes.filter(func(node: Dictionary): return node.reverse_traversal).size()
	check(local_mirrors > 0, "formal generation really reflects internal module geometry rather than only disabling reflection")
	if "--contracts-only" in OS.get_cmdline_user_args():
		print("PLAINS TEN GENERATION CONTRACTS: %d assertions, %d failures" % [assertions, failures])
		quit(1 if failures > 0 else 0)
		return
	var driver = load("res://tests/plains_run_trace.gd").new()
	driver.tree = self
	driver.check = check
	# Prove every new authored module in both horizontal reflections; the driver
	# observes swept full-body safety and resource/velocity contracts at seams.
	for mirrored: bool in [false, true]:
		for id: String in ["plains_micro_rise", "plains_meadow_gap", "plains_terraces", "plains_valley", "plains_long_meadow", "plains_split_terrace"]:
			var rng := RandomNumberGenerator.new()
			var reflection_seed := 0
			for seed_value: int in 20:
				rng.seed = seed_value
				if (rng.randi_range(0, 1) == 1) == mirrored:
					rng.seed = seed_value
					reflection_seed = seed_value
					break
			var ids: Array[String] = ["micro_board", "micro_board", id, "micro_board", "micro_board", "micro_board", "micro_board", "route_junction"]
			var recorded := generator._assemble_manifest(ids, 123, tuning, 0, "", rng, "plains_run_service" if id != "plains_terraces" else "plains_run_mid")
			# mid profile has required practice mechanics; use same strict budget but
			# add actual spike and saw modules rather than skip that requirement.
			if id == "plains_terraces":
				ids[4] = "spike_gap"
				ids[6] = "saw_gate"
				rng.seed = reflection_seed
				recorded = generator._assemble_manifest(ids, 123, tuning, 0, "", rng, "plains_run_mid")
			check(recorded.mirrored == mirrored, "new module proof uses the requested physical reflection")
			check(generator.validate_manifest(recorded, tuning).ok, "new module proof uses a valid complete manifest")
			await driver.route(recorded, tuning, "%s mirrored=%s" % [id, mirrored])
	var local_trace: Dictionary = {}
	var local_ids: Array[String] = ["micro_board", "micro_board", "plains_micro_rise", "plains_micro_rise", "plains_valley", "micro_step", "plains_meadow_gap", "spike_gap", "saw_gate", "route_junction"]
	for seed_value: int in 24:
		var local_rng := RandomNumberGenerator.new()
		local_rng.seed = seed_value
		var local_recorded := generator._assemble_manifest(local_ids.duplicate(), seed_value, tuning, 0, "", local_rng, "plains_run_mid", true)
		if generator.validate_manifest(local_recorded, tuning).ok and local_recorded.nodes.any(func(node: Dictionary): return node.reverse_traversal):
			local_trace = local_recorded
			break
	check(not local_trace.is_empty(), "bounded search finds a physical local-mirror route from left-bottom start")
	if not local_trace.is_empty():
		await driver.route(local_trace, tuning, "formal local reflections with forward coincident seams")
	for content_type: StringName in [&"coin_reward", &"shop"]:
		var typed_route := stage_generator.generate("type-motor-proof", 5, content_type, tuning)
		check(typed_route.ok and typed_route.manifest.nodes.any(func(node: Dictionary): return node.module_id in ["plains_fork_paths", "plains_fork_rest"]), "type route really draws independent-port exploration or respite branches")
		if typed_route.ok:
			await driver.route(typed_route.manifest, tuning, "typed generated %s room" % content_type)
	for room_index: int in [1, 5, 7]:
		var generated := stage_generator.generate("formal-motor-proof", room_index, &"combat", tuning)
		check(generated.ok and generated.manifest.fallback_id.is_empty(), "representative formal pressure profile is nonfallback")
		if generated.ok:
			await driver.route(generated.manifest, tuning, "formal generated combat room %d" % room_index)
	var boss_layout := stage_generator.generate("boss-motor-proof", 8, &"boss", tuning)
	if boss_layout.ok:
		await driver.route(boss_layout.manifest, tuning, "random Boss entrance and fixed arena")
	if is_instance_valid(driver.world):
		driver.world.free()
	print("PLAINS TEN GENERATION: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures > 0 else 0)
