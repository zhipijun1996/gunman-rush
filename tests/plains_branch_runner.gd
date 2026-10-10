extends SceneTree
## Contracts plus real Motor trajectories; fixtures never claim manual device play.
var assertions := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("BRANCH FAIL: " + message)
func reject_signed(g: RandomStageGenerator, manifest: Dictionary, tuning: PlayerTuning, label: String) -> void:
	manifest.manifest_hash = g._manifest_hash(manifest)
	check(not g.validate_manifest(manifest, tuning).ok, "Signed tampering rejected: " + label)
func _run() -> void:
	if "--verify-failure" in OS.get_cmdline_user_args():
		check(false, "Intentional branch failure probe")
		print("PLAINS BRANCH: %d assertions, %d failures" % [assertions, failures])
		quit(1)
		return
	var tuning := PlayerTuning.load_default()
	var formal := PlainsStageGenerator.new()
	var g := RandomStageGenerator.new()
	if "--routes-only" in OS.get_cmdline_user_args():
		await _physics_routes(tuning, formal)
		_finish()
		return
	var layouts: Dictionary = {}
	var modules: Dictionary = {}
	var reflections: Dictionary = {}
	var examples: Dictionary = {}
	var fallback_count := 0
	for seed_index: int in 20:
		for type: StringName in [&"combat", &"coin_reward", &"item_reward"]:
			for stage_index: int in [3, 5, 7]:
				var seed := "branch-proof-%d" % seed_index
				var generated := formal.generate(seed, stage_index, type, tuning)
				check(generated.ok, "Bounded request seed=%d index=%d type=%s: %s" % [seed_index, stage_index, type, generated.get("error", "")])
				if not generated.ok:
					continue
				var m: Dictionary = generated.manifest
				check(m.layout_id == "branched_terminal_paths" and m.branch_version == PlainsBranchLayout.VERSION, "Actual recorded branch layout and content version")
				check(m.stage_type == String(type) and m.stage_index == stage_index and generated.content_profile == String(type), "Requested stage type/index preserved")
				check(g.validate_manifest(JSON.parse_string(JSON.stringify(m)), tuning).ok, "JSON replay validates complete graph without rerolling")
				check(g._same_data(m, formal.generate(seed, stage_index, type, tuning).manifest), "Same seed/input produces identical placements, phases and branch choices")
				check(m.common_path.size() >= 3 and m.terminal_paths.size() == 2 and m.terminal_exits.size() == 2, "Shared traversal precedes exactly two terminal routes")
				var ownership: Dictionary = {}
				for value: int in m.common_path:
					ownership[value] = true
				for branch_index: int in 2:
					var path: Array = m.terminal_paths[branch_index]
					check(path.size() >= 2, "Both doors require a nonempty independent branch")
					for node_index: int in path:
						check(not ownership.has(node_index), "Branch nodes cannot share ownership with common path or other branch")
						ownership[node_index] = true
					var terminal: Dictionary = m.terminal_exits[branch_index]
					check(terminal.node == path[-1] and m.nodes[path[-1]].module_id == "plains_door_landing", "Door occurs at branch end, never in common/middle route")
					var last: Dictionary = m.nodes[path[-1]]
					var d := g.definition_for(last.module_id, last.mirrored, last.reverse_traversal)
					var point: Vector2 = d.exit_port.position + Vector2(last.offset[0], last.offset[1])
					check(terminal.position == [point.x, point.y] and generated.exit_points[branch_index] == point, "Consumer door exactly equals authored terminal port")
					var first_seam: Dictionary = m.seams[int(path[0]) - 1]
					check(first_seam.from == m.fork_node and first_seam.from_port_id == ("fork_up" if branch_index == 0 else "fork_right"), "Branches use distinct physical fork ports")
				check(ownership.size() == m.nodes.size(), "Every module belongs to exactly one real path")
				check(m.terminal_exits[0].position != m.terminal_exits[1].position, "Terminal doors are spatially distinct")
				check(generated.exit_points[0].distance_to(generated.exit_points[1]) >= float(m.branch_budget.action_min_door_separation), "Action branches preserve configured terminal approach separation")
				for node: Dictionary in m.nodes:
					modules[node.module_id] = true
					if node.module_id in g.LOCAL_REFLECTION_IDS:
						reflections[node.mirrored] = true
					check(g.definition_for(node.module_id, node.mirrored, node.reverse_traversal).supports(tuning), "No absent capability enters the main path")
				layouts[JSON.stringify(m.nodes)] = true
				if not m.branch_fallback_reason.is_empty():
					fallback_count += 1
				if examples.is_empty() and m.branch_fallback_reason.is_empty():
					examples = m.duplicate(true)
	check(layouts.size() > 100 and modules.size() >= 12 and reflections.size() == 2, "Seed sample changes actual content/placement and local mirrored geometry")
	print("BRANCH SAMPLE: requests=180 layouts=%d modules=%d fallback=%d mirrors=%d" % [layouts.size(), modules.size(), fallback_count, reflections.size()])
	if not examples.is_empty():
		var edited := examples.duplicate(true)
		edited.terminal_exits[0].node = edited.common_path[-1]
		reject_signed(g, edited, tuning, "door moved into common path")
		edited = examples.duplicate(true)
		edited.terminal_exits[1].position = edited.terminal_exits[0].position
		reject_signed(g, edited, tuning, "door moved away from own terminal")
		edited = examples.duplicate(true)
		edited.terminal_paths[1][0] = edited.terminal_paths[0][0]
		reject_signed(g, edited, tuning, "shared branch ownership")
		edited = examples.duplicate(true)
		edited.nodes[1].offset = edited.nodes[0].offset.duplicate()
		reject_signed(g, edited, tuning, "overlapping disconnected geometry")
		edited = examples.duplicate(true)
		edited.seams[int(edited.terminal_paths[0][0]) - 1].from_port_id = "fork_right"
		reject_signed(g, edited, tuning, "wrong fork port")
		edited = examples.duplicate(true)
		edited.route_graph.edges[0].to = "missing_target"
		reject_signed(g, edited, tuning, "fake route graph edge")
		edited = examples.duplicate(true)
		edited.nodes[1].content_hash = "forged"
		reject_signed(g, edited, tuning, "unrecognized content fingerprint")
		edited = examples.duplicate(true)
		edited.nodes[1].module_id = "missing_module"
		reject_signed(g, edited, tuning, "unknown authored module")
		edited = examples.duplicate(true)
		edited.branch_fallback_reason = "silent_reroll"
		reject_signed(g, edited, tuning, "unversioned fallback strategy")
		edited = examples.duplicate(true)
		edited.world_bounds[2] += 1
		reject_signed(g, edited, tuning, "false room bounds")
		edited = examples.duplicate(true)
		edited.branch_budget.max_recoil_per_route += 1
		reject_signed(g, edited, tuning, "weakened recorded route pressure budget")
		edited = examples.duplicate(true)
		edited.branch_stage_index = 1
		reject_signed(g, edited, tuning, "branch difficulty index contradicts formal room")
		edited = examples.duplicate(true)
		edited.nodes[0].initial_phases.append({"id": "missing_dynamic_object", "phase": 0.25})
		reject_signed(g, edited, tuning, "phase supplied for a nonexistent object")
	# Weak actions preserve requested reward type and visibly record fallback content.
	for shot_count: int in [0, 1]:
		var weak := PlayerTuning.load_default()
		weak.max_air_shots = shot_count
		for type: StringName in [&"combat", &"coin_reward", &"item_reward"]:
			var generated := formal.generate("branch-weak-shots", 5, type, weak)
			check(generated.ok and generated.content_profile == String(type) and generated.manifest.stage_type == String(type), "Reduced-shot fallback preserves stage type")
			if not generated.ok:
				continue
			check(g.validate_manifest(generated.manifest, weak).ok, "Reduced-shot recording validates against actual action resources")
			for node: Dictionary in generated.manifest.nodes:
				check(g.definition_for(node.module_id, node.mirrored, node.reverse_traversal).supports(weak), "Reduced-shot route excludes incompatible recoil demand")
			check(generated.manifest.layout_id == "branched_terminal_paths" and generated.manifest.terminal_paths.size() == 2, "No-shot room still has two terminal paths")
	var zero := PlayerTuning.load_default()
	zero.max_jumps = 0
	zero.max_air_shots = 0
	var easy := formal.generate("branch-zero-actions", 5, &"item_reward", zero)
	check(easy.ok and easy.content_profile == "item_reward" and easy.manifest.stage_type == "item_reward", "Zero-action bounded fallback keeps reward type")
	check(easy.ok and g.validate_manifest(easy.manifest, zero).ok and easy.manifest.branch_eligibility == "insufficient_jump_envelope_same_type_compatibility_route", "Zero-action fallback is explicitly recorded and capability-valid")
	if "--contracts-only" not in OS.get_cmdline_user_args():
		await _physics_routes(tuning, formal)
	_finish()

func _finish() -> void:
	print("PLAINS BRANCH: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)

func _physics_routes(tuning: PlayerTuning, formal: PlainsStageGenerator) -> void:
	var trace = load("res://tests/plains_run_trace.gd").new()
	trace.tree = self
	trace.check = check
	for fixture: Array in [["branch-proof-0", 3, &"combat"], ["branch-proof-4", 5, &"item_reward"]]:
		var generated := formal.generate(fixture[0], fixture[1], fixture[2], tuning)
		check(generated.ok, "Representative actual physics fixture assembles")
		if not generated.ok:
			continue
		for branch_index: int in 2:
			await trace.branch_route(generated.manifest, tuning, "seed=%s stage=%s branch=%s" % [fixture[0], fixture[1], branch_index], branch_index)
	if is_instance_valid(trace.world):
		trace.world.free()
