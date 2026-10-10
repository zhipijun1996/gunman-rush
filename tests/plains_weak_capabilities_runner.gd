extends SceneTree
var assertions := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func _initialize() -> void:
	var generator := RandomStageGenerator.new()
	var formal := PlainsStageGenerator.new()
	for mode: String in ["zero_actions", "weak_jump", "weak_burst"]:
		var tuning := PlayerTuning.load_default()
		if mode == "zero_actions":
			tuning.max_jumps = 0
			tuning.max_air_shots = 0
		elif mode == "weak_jump":
			tuning.jump_speeds.assign([330.0, 330.0])
		else:
			tuning.shot_burst_duration = 0.01
		for id: String in ["plains_micro_rise", "plains_meadow_gap", "plains_terraces", "plains_valley"]:
			check(generator.definition_for(id).supports(tuning) == (mode == "weak_burst"), "new jumps screen real height/charge requirements independently of shot burst")
		for stage_index: int in range(1, 9):
			var type: StringName = &"boss" if stage_index == 8 else &"combat"
			var generated := formal.generate("weak-profile-proof", stage_index, type, tuning)
			check(generated.ok, "bounded formal generation has compatible weak-ability route")
			if not generated.ok:
				continue
			check(generator.validate_manifest(generated.manifest, tuning).ok, "weak-ability manifest passes full strict validation")
			check(generated.exit_points.size() == 2 and generated.exit_points[0].distance_to(generated.exit_points[1]) > 500, "reduced capabilities retain two separated compatible exit positions")
			if mode == "zero_actions":
				check(generated.placement_points.all(func(point: Vector2): return absf(point.y - 282) < 0.001), "zero-jump mandatory pickups stay on reachable floor, not optional upper shelves")
			for node: Dictionary in generated.manifest.nodes:
				check(generator.definition_for(node.module_id).supports(tuning), "every selected module supports the actual reduced ability configuration")
			var tampered: Dictionary = generated.manifest.duplicate(true)
			tampered.development_only = true
			tampered.manifest_hash = generator._manifest_hash(tampered)
			check(not generator.validate_manifest(tampered, tuning).ok, "resigned scope downgrade cannot turn formal layout into preview")
	print("PLAINS WEAK CAPABILITIES: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures > 0 else 0)
