extends SceneTree
## Macro geometry proof plus actual input-only full branch traces.
var assertions := 0
var failures := 0
var fixtures: Array[Dictionary] = []
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("BLUEPRINT FAIL: " + label)
func _run() -> void:
	var tuning := PlayerTuning.load_default()
	var g := RandomStageGenerator.new()
	var layout := PlainsBranchLayout.new()
	var common_rises: Dictionary = {}
	var timed_variants: Dictionary = {}
	for blueprint: String in ["bridge_crossing", "windmill_ascent"]:
		var rises: Array[float] = []
		for seed_index: int in 20:
			var result := layout.generate(17000 + seed_index, tuning, 5, &"combat", "plains_run_mid", g, blueprint)
			check(result.ok, "explicit macro request succeeds")
			if not result.ok: continue
			var m: Dictionary = result.manifest
			check(m.blueprint_id == blueprint and m.branch_fallback_reason.is_empty(), "requested blueprint remains actual geometry without silent fallback")
			check(g.validate_manifest(JSON.parse_string(JSON.stringify(m)), tuning).ok, "JSON manifest replays exact macro geometry and roles")
			check(g._same_data(m, layout.generate(17000 + seed_index, tuning, 5, &"combat", "plains_run_mid", g, blueprint).manifest), "same explicit macro input has exact deterministic replay")
			var fork: Dictionary = m.nodes[m.fork_node]
			var fork_def := g.definition_for(fork.module_id)
			var rise: float = 282.0 - (float(fork.offset[1]) + fork_def.entry_port.position.y)
			rises.append(rise)
			var recoil_step := g.definition_for("plains_recoil_step")
			var authored_recoil_rise := recoil_step.entry_port.position.y - recoil_step.exit_port.position.y
			check(rise == 0 if blueprint == "bridge_crossing" else rise >= 400 + authored_recoil_rise, "horizontal return-to-height differs from sustained stair/ferry plus recoil ascent")
			var timed_key: String = blueprint + ":" + m.nodes[6].module_id
			if not timed_variants.has(timed_key): timed_variants[timed_key] = m
			check(m.common_path.size() == (10 if blueprint == "bridge_crossing" else 12) and m.nodes[6].module_id in PlainsBranchLayout.TIMED_GEARS, "both mid-stage blueprints introduce actual timed gear")
			check(m.nodes[5].module_id in PlainsBranchLayout.SAFE and m.nodes[7].module_id in PlainsBranchLayout.SAFE, "timed encounter has safe observation and receiving floors")
			check(m.nodes[m.common_path[-2]].module_id == "plains_patrol_meadow", "common patrol encounter keeps challenge/recovery sequence intact")
			for terminal_path: Array in m.terminal_paths:
				check(m.nodes[terminal_path[-2]].module_id == "plains_patrol_meadow" and m.nodes[terminal_path[-3]].module_id in PlainsBranchLayout.SAFE, "each terminal offers a patrol floor after a separate recovery landing")
			check(m.branch_profiles[0].risk == "challenge" and m.branch_profiles[1].risk == "steady", "terminal choices have distinct actual risk")
			for node_index: int in m.terminal_paths[1]:
				var n: Dictionary = m.nodes[node_index]
				var d := g.definition_for(n.module_id, n.mirrored, n.reverse_traversal)
				check(not d.requires_burst and not g._hazardous(d), "steady terminal keeps both shots available for player recovery")
			if seed_index < 2: fixtures.append(m)
			if seed_index == 0:
				for field: String in ["blueprint_id", "blueprint_version", "old_blueprint_version", "old_branch_version", "branch_profiles", "bridge_rhythm"]:
					var forged := m.duplicate(true)
					if field == "blueprint_id": forged[field] = "windmill_ascent" if blueprint == "bridge_crossing" else "bridge_crossing"
					elif field == "blueprint_version": forged[field] += 1
					elif field == "old_blueprint_version": forged.blueprint_version -= 1
					elif field == "old_branch_version": forged.branch_version -= 1
					elif field == "bridge_rhythm":
						if blueprint != "bridge_crossing": continue
						forged.branch_stage_index = 1
						forged.profile_id = "plains_run_early"
					else: forged[field][1].bonus_notes = 999
					forged.manifest_hash = g._manifest_hash(forged)
					check(not g.validate_manifest(forged, tuning).ok, "signed forged macro/bonus metadata is rejected: " + field)
		common_rises[blueprint] = rises
	for blueprint: String in ["bridge_crossing", "windmill_ascent"]:
		var early := layout.generate(17100, tuning, 1, &"combat", "plains_run_early", g, blueprint)
		check(early.ok and early.manifest.blueprint_id == blueprint and early.manifest.branch_fallback_reason.is_empty(), "early room has requested true macro")
		if early.ok:
			fixtures.append(early.manifest)
			if blueprint == "bridge_crossing": check(early.manifest.common_path.size() == 8, "early bridge teaches static crossings before timed gear introduction")
			for node_index: int in early.manifest.common_path:
				var n: Dictionary = early.manifest.nodes[node_index]
				var d := g.definition_for(n.module_id, n.mirrored, n.reverse_traversal)
				check(d.platform_pressure <= 1 and d.ferries.is_empty() and not d.requires_burst, "early introduction keeps no-ferry/no-recoil common learning route")
	for blueprint: String in ["bridge_crossing", "windmill_ascent"]:
		for slot: int in [1, 2, 3, 4]:
			var boundary := layout.generate(17200, tuning, slot, &"combat", PlainsStageGenerator.new().profile_for(slot, &"combat"), g, blueprint)
			check(boundary.ok and boundary.manifest.blueprint_id == blueprint and boundary.manifest.branch_fallback_reason.is_empty(), "timed introduction keeps requested blueprint %s stage%d" % [blueprint, slot])
			if not boundary.ok: continue
			var gear_nodes: Array = boundary.manifest.nodes.filter(func(node: Dictionary): return node.module_id in PlainsBranchLayout.TIMED_GEARS)
			check(gear_nodes.is_empty() if slot == 1 else not gear_nodes.is_empty(), "first stage static; timed teaching begins exactly at stage two")
			if slot < 4:
				check(gear_nodes.all(func(node: Dictionary): return node.module_id == "plains_gear_brook"), "small gear only before stage four")
			if slot == 2: fixtures.append(boundary.manifest)
	for stage_index: int in [2, 4]:
		for service: StringName in [&"shop", &"health_reward"]:
			var quiet := layout.generate(17300, tuning, stage_index, service, PlainsStageGenerator.new().profile_for(stage_index, service), g, "sanctuary")
			check(quiet.ok and quiet.manifest.blueprint_id == "sanctuary", "service retains respite blueprint after gear introduction")
			if quiet.ok:
				check(quiet.manifest.nodes.all(func(n: Dictionary): return n.module_id not in PlainsBranchLayout.TIMED_GEARS and n.module_id != "plains_patrol_meadow"), "service has no timed gear or inserted combat patrol floor")
	var weak := PlayerTuning.load_default()
	weak.max_jumps = 0
	weak.max_air_shots = 0
	for blueprint: String in ["bridge_crossing", "windmill_ascent"]:
		check(layout.gear_pool(2, weak, g).is_empty(), "missing jump capability filters teaching gears")
		var reduced := PlainsStageGenerator.new().generate("weak-gear-" + blueprint, 2, &"coin_reward", weak)
		check(reduced.ok and reduced.manifest.stage_type == "coin_reward", "weak-action bounded fallback preserves requested content type")
		if reduced.ok:
			check(reduced.manifest.nodes.all(func(n: Dictionary): return n.module_id not in PlainsBranchLayout.TIMED_GEARS), "weak fallback never silently inserts incompatible timed gears")
	check(timed_variants.size() == 4, "both blueprint samples include both gear sizes")
	# Exercise all authored quarter phases in the whole assembled stage, not
	# just a detached obstacle. Existing base fixtures still traverse both doors.
	for id: String in timed_variants:
		for quarter: int in 4:
			var phased: Dictionary = timed_variants[id].duplicate(true)
			phased.nodes[6].initial_phases[0].phase = quarter * 0.25
			phased.manifest_hash = g._manifest_hash(phased)
			check(g.validate_manifest(phased, tuning).ok, "explicit timed phase remains a valid recorded manifest")
			fixtures.append(phased)
	print("MACRO GEOMETRY common rise: ", common_rises)
	if "--contracts-only" not in OS.get_cmdline_user_args():
		var trace = load("res://tests/plains_run_trace.gd").new()
		trace.tree = self
		trace.check = check
		for m: Dictionary in fixtures:
			for branch_index: int in 2:
				await trace.branch_route(m, tuning, "%s seed=%s" % [m.blueprint_id, m.seed], branch_index)
		if is_instance_valid(trace.world): trace.world.free()
	if "--verify-failure" in OS.get_cmdline_user_args(): check(false, "intentional failure probe")
	print("PLAINS BLUEPRINT: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
