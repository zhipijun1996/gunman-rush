extends SceneTree
## New recipes must survive production assembly and continuous real Motor traces.
var assertions := 0
var failures := 0
var fixtures: Array[Dictionary] = []
var selected := ""
var report := {"engine": Engine.get_version_info().string, "templates": [], "fixed_stage_distribution": {}, "fallbacks": 0}
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("ROOM GRAMMAR: " + label)
func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--template="): selected = arg.trim_prefix("--template=")
	var tuning := PlayerTuning.load_default()
	var g := RandomStageGenerator.new()
	var layout := PlainsBranchLayout.new()
	for entry: Dictionary in PlainsRoomGrammar.catalog().templates:
		if not selected.is_empty() and entry.id != selected: continue
		var recorded := {"id": entry.id, "variants": []}
		for variant: int in entry.variants.size():
			var result := layout.generate(90100 + variant, tuning, 5, &"combat", "plains_run_mid", g, "bridge_crossing", entry.id, variant)
			check(result.ok, "authored connection request generates")
			if not result.ok: continue
			var m: Dictionary = result.manifest
			check(m.room_grammar.template_id == entry.id and m.room_grammar.variant == variant and m.branch_fallback_reason.is_empty(), "requested action sequence remains actual geometry without fallback")
			if m.room_grammar.template_id != entry.id: continue
			check(g.validate_manifest(JSON.parse_string(JSON.stringify(m)), tuning).ok, "JSON recorded template is valid")
			check(g._same_data(m, layout.generate(90100 + variant, tuning, 5, &"combat", "plains_run_mid", g, "bridge_crossing", entry.id, variant).manifest), "same template/seed has identical actual geometry")
			var copy := m.duplicate(true)
			copy.room_grammar.segments[0].beats[0].role = "challenge"
			copy.manifest_hash = g._manifest_hash(copy)
			check(not g.validate_manifest(copy, tuning).ok, "signed fake action roles rejected")
			copy = m.duplicate(true)
			copy.room_grammar.variant = (variant + 1) % entry.variants.size()
			copy.manifest_hash = g._manifest_hash(copy)
			check(not g.validate_manifest(copy, tuning).ok, "signed substitute local variant without actual geometry rejected")
			for path: Array in m.terminal_paths:
				check(m.nodes[path[-1]].module_id == "plains_door_landing", "both doors remain at terminal endpoints")
			for node_index: int in m.terminal_paths[1]:
				var node: Dictionary = m.nodes[node_index]
				var d := g.definition_for(node.module_id, node.mirrored, node.reverse_traversal)
				check(not d.requires_burst and not g._hazardous(d), "steady route has no recoil or hazard requirement")
			for node: Dictionary in m.nodes:
				for phase: Dictionary in node.initial_phases: phase.phase = variant * 0.5
			m.manifest_hash = g._manifest_hash(m)
			check(g.validate_manifest(m, tuning).ok, "explicit composition phase is supported")
			fixtures.append(m)
			recorded.variants.append({"variant": variant, "modules": entry.variants[variant], "seed": m.seed, "nodes": m.nodes.size(), "phase": variant * 0.5})
		report.templates.append(recorded)
	if selected.is_empty():
		for sample: int in 200:
			var result := PlainsStageGenerator.new().generate("grammar-distribution-%d" % sample, 5, &"combat", tuning)
			check(result.ok, "fixed stage/type seed sample generates within bounds")
			if not result.ok: continue
			var m: Dictionary = result.manifest
			var id: String = m.room_grammar.template_id
			report.fixed_stage_distribution[id] = int(report.fixed_stage_distribution.get(id, 0)) + 1
			if not m.branch_fallback_reason.is_empty(): report.fallbacks += 1
			check(g.validate_manifest(JSON.parse_string(JSON.stringify(m)), tuning).ok, "formal consumer records strict grammar and phases")
			check(g._same_data(m, PlainsStageGenerator.new().generate("grammar-distribution-%d" % sample, 5, &"combat", tuning).manifest), "formal same-seed replay exact")
		check(report.fallbacks == 0, "200 fixed-condition seeds retain authored challenges")
		check(report.fixed_stage_distribution.size() == PlainsRoomGrammar.catalog().templates.size(), "every authored template appears in actual formal maps")
		for id: String in report.fixed_stage_distribution:
			check(id != "none" and int(report.fixed_stage_distribution[id]) >= 3, "template is actual recurring content: " + id)
		for sample: int in 40:
			var used: Array[String] = []
			for index: int in range(3, 7):
				var plan := PlainsRoomGrammar.plan("grammar-bag-%d" % sample, index, &"combat")
				check(plan.template_id != "none" and plan.template_id not in used, "seeded request bag avoids repeated action phrases within a run")
				used.append(plan.template_id)
		for shots: int in [0, 1]:
			var weak := PlayerTuning.load_default()
			weak.max_air_shots = shots
			for index: int in [3, 5, 7]:
				var result := PlainsStageGenerator.new().generate("grammar-weak", index, &"combat", weak)
				check(result.ok and g.validate_manifest(result.manifest, weak).ok, "weaker actions keep valid bounded routes")
	if "--contracts-only" not in OS.get_cmdline_user_args():
		var trace = load("res://tests/plains_run_trace.gd").new()
		trace.tree = self
		trace.check = check
		for m: Dictionary in fixtures:
			for branch: int in 2:
				await trace.branch_route(m, tuning, "%s variant%d" % [m.room_grammar.template_id, m.room_grammar.variant], branch)
		if is_instance_valid(trace.world): trace.world.free()
	report.assertions = assertions
	report.failures = failures
	DirAccess.make_dir_recursive_absolute("res://build/verification/room-grammar")
	var file := FileAccess.open("res://build/verification/room-grammar/%s.json" % (selected if not selected.is_empty() else "corpus"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	if "--verify-failure" in OS.get_cmdline_user_args(): check(false, "intentional exit-code proof")
	print("ROOM GRAMMAR DISTRIBUTION: ", report.fixed_stage_distribution)
	print("PLAINS ROOM GRAMMAR: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures else 0)
