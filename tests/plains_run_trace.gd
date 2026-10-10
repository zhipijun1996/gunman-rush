extends "res://tests/random_stage_tests.gd"

func route(manifest: Dictionary, tuning: PlayerTuning, label: String) -> void:
	if manifest.get("layout_id", "") == "branched_terminal_paths":
		await branch_route(manifest, tuning, label + " upper", 0)
		await branch_route(manifest, tuning, label + " lower", 1)
	else:
		await super.route(manifest, tuning, label)

func branch_route(manifest: Dictionary, tuning: PlayerTuning, label: String, branch_index: int) -> void:
	check.call(branch_index in [0, 1] and manifest.get("layout_id") == "branched_terminal_paths", "branch driver receives a real terminal-path recording")
	if branch_index not in [0, 1] or not await fixture(manifest, tuning): return
	var visited: Array = manifest.common_path.duplicate()
	visited.append_array(manifest.terminal_paths[branch_index])
	var expected_shots := 0
	for node_index: Variant in visited:
		var index := int(node_index)
		var module: PlatformingModule = stage.modules[index]
		check.call(module.port_accepts(module.definition.entry_port, motor), label + " actual entry resource contract %d" % index)
		if index == int(manifest.fork_node) and branch_index == 0:
			var route: Array[int] = [module.definition.main_route[0]]
			route.append_array(Array(module.definition.branch_routes[0]))
			check.call(await load("res://tests/branch_module_driver.gd").new().follow_path(module, motor, tick, check, route), label + " shared fork climbs actual upper route without teleport")
		else:
			await traverse(module)
		controller.router.set_move_axis(0)
		await tick(3)
		var exit_port := module.definition.exit_port
		if index == int(manifest.fork_node) and branch_index == 0:
			for port: PlatformingModulePort in module.definition.get_exit_ports():
				if port.port_id == &"fork_up": exit_port = port
		var expected_position := module.to_global(exit_port.position)
		check.call(motor.is_on_floor() and motor.global_position.distance_to(expected_position) < 1, label + " grounded selected module exit %d" % index)
		check.call(module.port_accepts(exit_port, motor), label + " real selected exit contract %d" % index)
		check.call(controller.action_resources.shot_charges == tuning.max_air_shots and controller.jump_ability.used_jumps == 0, label + " real floor resets action resources %d" % index)
		if motor.global_position.distance_to(expected_position) >= 1: break
		var id := str(module.definition.module_id)
		expected_shots += 1 if id == "plains_recoil_step" else (2 if id in ["plains_recoil_double", "plains_recoil_chasm", "plains_recoil_chasm_wide", "challenge_long_gap"] else 0)
	var terminal: Dictionary = manifest.terminal_exits[branch_index]
	check.call(motor.is_on_floor() and motor.global_position.distance_to(Vector2(terminal.position[0], terminal.position[1])) < 1, label + " reaches selected door at end of its branch")
	check.call(shots == expected_shots, label + " exact actual released projectile count")
	check.call(safe_trace and continuous_trace, label + " full swept body avoids all static and moving hazards without teleport")
	check.call(trace_ticks > 100 and stage.modules.size() == manifest.nodes.size(), label + " traverses a whole generated branch in the actual assembled world")
	print("PLAINS BRANCH TRACE: seed=%s branch=%d nodes=%s ticks=%d shots=%d safe=%s" % [manifest.seed, branch_index, visited, trace_ticks, shots, safe_trace])

func traverse(module: PlatformingModule) -> void:
	if str(module.definition.module_id) in ["plains_recoil_step", "plains_recoil_double", "plains_recoil_chasm", "plains_recoil_chasm_wide", "plains_ferry_one", "plains_ferry_two", "plains_perch_rise", "plains_perch_double", "plains_skip_stones", "plains_thorn_bridge", "plains_thorn_steps", "plains_gear_brook", "plains_gear_glade", "plains_fork_paths", "plains_fork_rest", "plains_door_landing"]:
		check.call(await load("res://tests/branch_module_driver.gd").new().traverse(module, motor, tick, check), "new branch module has an actual bounded input-only driver")
		return
	# Formal local reflections traverse reflected static geometry left-to-right,
	# rather than reusing the legacy whole-stage right-to-left action sequence.
	if module.definition.mirrored_horizontal and module.definition.entry_port.direction.x > 0:
		var platforms: Array[Rect2] = module.definition.platforms.duplicate()
		platforms.sort_custom(func(a: Rect2, b: Rect2): return a.position.x < b.position.x)
		for index: int in platforms.size() - 1:
			var takeoff := module.to_global(Vector2(platforms[index].end.x - 35, 0)).x
			var receiver := module.to_global(Vector2(platforms[index + 1].position.x + minf(80, platforms[index + 1].size.x * 0.5), 0)).x
			check.call(await move_to(takeoff), "local reflection reaches actual takeoff")
			check.call(await jump_to(receiver), "local reflection traverses reflected geometry with real Motor")
		check.call(await move_to(module.world_exit().x), "local reflection returns to grounded forward dock")
		return
	if not module.definition.main_route.is_empty():
		await spatial_path(module, module.definition.main_route)
		return
	var pairs: Array[Vector2] = []
	match str(module.definition.module_id):
		"plains_micro_rise": pairs = [Vector2(100, 235)]
		"plains_meadow_gap": pairs = [Vector2(130, 335)]
		"plains_terraces": pairs = [Vector2(165, 350), Vector2(460, 650)]
		"plains_valley": pairs = [Vector2(165, 360), Vector2(460, 650)]
		"plains_micro_stool", "plains_micro_landing", "plains_long_meadow", "plains_split_terrace":
			check.call(await move_to(module.world_exit().x), "open meadow/optional terrace has continuous reachable main floor")
			return
		"plains_thorn_hop", "plains_gear_hop":
			check.call(await move_to(module.position.x + 25), "compact danger module reaches an actual clear takeoff")
			check.call(await jump_to(module.position.x + 140), "compact danger module uses a real jump over thorn or moving gear")
			check.call(await move_to(module.world_exit().x), "compact danger module reaches its clear grounded dock")
			return
		"plains_boss_arena":
			check.call(await move_to(module.world_exit().x), "fixed Boss core physically traverses a full-width floor")
			return
		_:
			await super.traverse(module)
			return
	for pair: Vector2 in pairs:
		check.call(await move_to(local_x(module, pair.x)), "new plains module reaches authored takeoff using real Motor")
		check.call(await jump_to(local_x(module, pair.y)), "new plains module held single jump lands on receiver")
	check.call(await move_to(module.world_exit().x), "new plains module reaches coincident docking floor")

func spatial_path(module: PlatformingModule, path: Variant) -> void:
	check.call(await load("res://tests/branch_module_driver.gd").new().follow_path(module, motor, tick, check, path), "spatial path distinguishes walkable floor from equal-height gaps and uses real jumps")
