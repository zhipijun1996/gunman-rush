extends SceneTree
## New recipes must survive production assembly and continuous real Motor traces.
var assertions := 0
var failures := 0
var fixtures: Array[Dictionary] = []
var phase_fixtures: Array[Dictionary] = []
var selected := ""
var baseline_only := false
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
	baseline_only = "--baseline-only" in OS.get_cmdline_user_args()
	if baseline_only and not selected.is_empty():
		check(false, "baseline-only and template selection are mutually exclusive")
		quit(1)
		return
	if not selected.is_empty() and PlainsRoomGrammar.template_for(selected).is_empty():
		check(false, "selected template exists in authoritative catalog")
		quit(1)
		return
	var tuning := PlayerTuning.load_default()
	var g := RandomStageGenerator.new()
	var layout := PlainsBranchLayout.new()
	for entry: Dictionary in PlainsRoomGrammar.catalog().templates:
		if baseline_only: continue
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
			copy.room_grammar = PlainsRoomGrammar.recording(copy, {})
			copy.manifest_hash = g._manifest_hash(copy)
			check(not g.validate_manifest(copy, tuning).ok, "signed removal of authored phrase cannot pose as introduction")
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
			for quarter: float in [0.25, 0.75]:
				var phased := m.duplicate(true)
				for node: Dictionary in phased.nodes:
					for phase: Dictionary in node.initial_phases: phase.phase = quarter
				phased.manifest_hash = g._manifest_hash(phased)
				check(g.validate_manifest(phased, tuning).ok, "all four quarter phases retain actual composition")
				phase_fixtures.append(phased)
			recorded.variants.append({"variant": variant, "modules": entry.variants[variant], "seed": m.seed, "nodes": m.nodes.size(), "phase": variant * 0.5})
		if not entry.variants.any(func(ids: Array): return ids.any(func(id: String): return id.begins_with("plains_recoil_"))):
			for variant: int in entry.variants.size():
				var ascent := layout.generate(90300 + variant, tuning, 5, &"combat", "plains_run_mid", g, "windmill_ascent", entry.id, variant)
				check(ascent.ok and ascent.manifest.room_grammar.template_id == entry.id and ascent.manifest.branch_fallback_reason.is_empty(), "non-recoil phrase also retains its actual sustained ascent skeleton")
				if ascent.ok: fixtures.append(ascent.manifest)
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
			if sample < 10:
				var stage := GeneratedDemoStage.new()
				stage.configure(5, &"combat", [])
				stage.configure_generated(result, tuning)
				root.add_child(stage)
				check(g._same_data(stage.encounter_plan, PlainsEncounterPlanner.recorded_plan(JSON.parse_string(JSON.stringify(m)))), "JSON float node indices preserve actual enemy and recovery plans")
				var protected_nodes: Array = []
				for segment: Dictionary in m.room_grammar.segments:
					for beat: Dictionary in segment.beats:
						if beat.role in ["observation", "recovery"]: protected_nodes.append(beat.node)
				for actor: Dictionary in stage.encounter_plan.enemies:
					check(actor.module_index not in protected_nodes, "actual enemy consumer keeps grammar recovery floors clear")
				check(stage.encounter_plan.enemies.size() > 0, "actual template room still has real enemy encounters")
				stage.free()
			check(g._same_data(m, PlainsStageGenerator.new().generate("grammar-distribution-%d" % sample, 5, &"combat", tuning).manifest), "formal same-seed replay exact")
		check(report.fallbacks == 0, "200 fixed-condition seeds retain authored challenges")
		check(report.fixed_stage_distribution.size() == PlainsRoomGrammar.catalog().templates.size(), "every authored template appears in actual formal maps")
		for id: String in report.fixed_stage_distribution:
			check(id != "none" and int(report.fixed_stage_distribution[id]) >= 3 and int(report.fixed_stage_distribution[id]) <= 70, "template is actual recurring content: " + id)
		for sample: int in 40:
			var used: Array[String] = []
			for index: int in range(3, 7):
				var plan := PlainsRoomGrammar.plan("grammar-bag-%d" % sample, index, &"combat")
				check(plan.template_id != "none" and plan.template_id not in used, "seeded request bag avoids repeated action phrases within a run")
				used.append(plan.template_id)
				var actual := PlainsStageGenerator.new().generate("grammar-bag-%d" % sample, index, &"combat", tuning)
				check(actual.ok and actual.manifest.room_grammar.template_id == plan.template_id and actual.manifest.branch_fallback_reason.is_empty(), "default real geometry honors the unique seeded request")
		for sample: int in 2:
			var coins := PlainsStageGenerator.new().generate("grammar-coin-%d" % sample, 5, &"coin_reward", tuning)
			check(coins.ok and coins.manifest.room_grammar.segments[1].nodes.size() == 7, "coin room retains a longer actual steady exploration phrase")
			if coins.ok: fixtures.append(coins.manifest)
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
		if "--phase-sweep" in OS.get_cmdline_user_args():
			for m: Dictionary in phase_fixtures:
				await trace.branch_route(m, tuning, "%s quarter-phase sweep" % m.room_grammar.template_id, 0)
		if is_instance_valid(trace.world): trace.world.free()
	if "--verify-failure" in OS.get_cmdline_user_args(): check(false, "intentional exit-code proof")
	report.actual_routes = (fixtures.size() * 2 + (phase_fixtures.size() if "--phase-sweep" in OS.get_cmdline_user_args() else 0)) if "--contracts-only" not in OS.get_cmdline_user_args() else 0
	report.assertions = assertions
	report.failures = failures
	DirAccess.make_dir_recursive_absolute("res://build/verification/room-grammar")
	var file := FileAccess.open("res://build/verification/room-grammar/%s.json" % ("baseline" if baseline_only else selected if not selected.is_empty() else "corpus"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	print("ROOM GRAMMAR DISTRIBUTION: ", report.fixed_stage_distribution)
	print("PLAINS ROOM GRAMMAR: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures else 0)
