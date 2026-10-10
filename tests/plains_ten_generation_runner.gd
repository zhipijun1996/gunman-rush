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
	check(not stage_generator.generate("x", 10, &"combat", tuning).ok, "room ten cannot bypass Boss")
	check(not stage_generator.generate("x", 9, &"boss", tuning).ok, "Boss is terminal room ten")
	var types: Array[StringName] = [&"combat", &"coin_reward", &"shop", &"health_reward", &"item_reward", &"combat", &"coin_reward", &"item_reward", &"combat", &"boss"]
	var seen: Dictionary = {}
	for seed_index: int in 4:
		var seed_text := "plains-proof-%d" % seed_index
		var stage_seeds: Dictionary = {}
		for index: int in 10:
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
			check(not result.placement_points.is_empty(), "content placement has safe authored standing anchors")
			if types[index] in [&"shop", &"health_reward", &"boss"]:
				check(recorded.nodes.any(func(node: Dictionary): return node.module_id not in ["micro_board", "route_junction", "plains_boss_arena"]), "safe service/Boss entrance is independently varied, not only flat boards")
			for node: Dictionary in recorded.nodes:
				seen[node.module_id] = true
			if types[index] in [&"shop", &"health_reward", &"boss"]:
				for node: Dictionary in recorded.nodes:
					var definition := generator.definition_for(node.module_id)
					check(definition.danger_bounds.is_empty() and definition.saws.is_empty(), "service and Boss entrance avoid environmental pressure")
			if index == 9:
				check(result.boss_arena.size == Vector2(920, 350), "Boss attack space is fixed independently of random entrance")
	for id: String in ["plains_micro_rise", "plains_meadow_gap", "plains_terraces", "plains_valley", "plains_boss_arena"]:
		check(seen.has(id), "new module is actually drawn by formal generator: " + id)
	var driver = load("res://tests/plains_run_trace.gd").new()
	driver.tree = self
	driver.check = check
	# Prove every new authored module in both horizontal reflections; the driver
	# observes swept full-body safety and resource/velocity contracts at seams.
	for mirrored: bool in [false, true]:
		for id: String in ["plains_micro_rise", "plains_meadow_gap", "plains_terraces", "plains_valley"]:
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
	for room_index: int in [1, 5, 8]:
		var generated := stage_generator.generate("formal-motor-proof", room_index, &"combat", tuning)
		check(generated.ok and generated.manifest.fallback_id.is_empty(), "representative formal pressure profile is nonfallback")
		if generated.ok:
			await driver.route(generated.manifest, tuning, "formal generated combat room %d" % room_index)
	var boss_layout := stage_generator.generate("boss-motor-proof", 10, &"boss", tuning)
	if boss_layout.ok:
		await driver.route(boss_layout.manifest, tuning, "random Boss entrance and fixed arena")
	if is_instance_valid(driver.world):
		driver.world.free()
	print("PLAINS TEN GENERATION: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures > 0 else 0)
