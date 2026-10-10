class_name PlainsStageGenerator
extends RefCounted

const VERSION := "plains-run-v4-branch-challenges"
const TYPES := ["combat", "shop", "coin_reward", "health_reward", "item_reward", "boss"]

# Layout draws cannot perturb routes, rewards, or merchant inventory. Each room
# uses its stable index rather than an advancing global map RNG.
func generate(run_seed: String, stage_index: int, stage_type: StringName, tuning: PlayerTuning) -> Dictionary:
	if stage_index < 1 or stage_index > 8 or str(stage_type) not in TYPES or (stage_index == 8) != (stage_type == &"boss"):
		return {"ok": false, "error": "Formal plains requires rooms 1–7 and Boss 8"}
	var rng := RunRandomStream.new(run_seed, "map", "stage_%d" % stage_index, VERSION)
	var profile_id := profile_for(stage_index, stage_type)
	var count := 8 if stage_type in [&"shop", &"health_reward", &"boss"] else (16 + mini(4, stage_index / 3) if stage_type == &"coin_reward" else (12 + mini(4, stage_index / 2) if stage_type == &"item_reward" else 10 + mini(6, stage_index / 2)))
	var generator := RandomStageGenerator.new()
	var map_seed := rng.next_int(2147483647)
	var generated: Dictionary
	if stage_type != &"boss" and tuning.max_jumps >= 1 and float(MovementCapabilityEnvelope.snapshot(tuning).held_jump_height) >= 120.0:
		generated = PlainsBranchLayout.new().generate(map_seed, tuning, stage_index, stage_type, profile_id, generator)
	else:
		generated = generator.generate(map_seed, tuning, count, profile_id, true)
	if not generated.ok:
		return generated
	var manifest: Dictionary = generated.manifest
	manifest["branch_eligibility"] = "branched_terminal_paths" if manifest.layout_id == "branched_terminal_paths" else "fixed_boss_core" if stage_type == &"boss" else "insufficient_jump_envelope_same_type_compatibility_route"
	manifest["stage_type"] = str(stage_type)
	manifest["stage_index"] = stage_index
	manifest["layout_variant"] = "open_meadow_exploration" if stage_type == &"coin_reward" else ("short_respite" if stage_type in [&"shop", &"health_reward"] else ("challenge_gauntlet" if stage_type == &"item_reward" else ("fixed_core_random_approach" if stage_type == &"boss" else "ascending_combat_ridge")))
	manifest["manifest_hash"] = generator._manifest_hash(manifest)
	var points: Array[Vector2] = []
	var envelope := MovementCapabilityEnvelope.snapshot(tuning)
	var arena := Rect2()
	for node: Dictionary in manifest.nodes:
		var definition := generator.definition_for(node.module_id, node.mirrored, node.reverse_traversal)
		var offset := Vector2(node.offset[0], node.offset[1])
		for point: Vector2 in definition.anchors:
			# Optional shelves never become mandatory pickups for reduced jump builds.
			if node.module_id == "plains_split_terrace" and point.y < definition.entry_port.position.y and (tuning.max_jumps < 1 or float(envelope.held_jump_height) < 85.0 or float(envelope.held_jump_range) < 200.0):
				continue
			if node.module_id == "route_junction" and point.y < definition.entry_port.position.y and (tuning.max_jumps < 1 or float(envelope.held_jump_height) < 80.0 or float(envelope.held_jump_range) < 210.0):
				continue
			var world_point := point + offset
			if not points.has(world_point):
				points.append(world_point)
		if node.module_id == "plains_boss_arena":
			# Core attack space stays fixed; only its entrance module chain varies.
			arena = Rect2(offset + Vector2(100, 250), Vector2(920, 350))
	if stage_type == &"boss" and arena.size == Vector2.ZERO:
		return {"ok": false, "error": "Boss layout lacks its validated fixed core"}
	var exit_points: Array[Vector2] = []
	for exit_data: Dictionary in manifest.terminal_exits:
		exit_points.append(Vector2(exit_data.position[0], exit_data.position[1]))
	return {"ok": true, "error": "", "manifest": manifest, "placement_points": points, "exit_points": exit_points, "enemy_points": points.filter(func(point: Vector2): return point.distance_to(Vector2(20, 282)) > 400), "content_profile": str(stage_type), "boss_arena": arena, "stage_generator_version": VERSION}

func profile_for(stage_index: int, stage_type: StringName) -> String:
	if stage_type == &"boss":
		return "plains_run_boss"
	if stage_type in [&"shop", &"health_reward"]:
		return "plains_run_service"
	if stage_type == &"coin_reward":
		return "plains_run_coin"
	if stage_type == &"item_reward" and stage_index >= 4:
		return "plains_run_item"
	# Coin rooms emphasize traversing the pickups, rather than combat pressure.
	var effective_index := maxi(1, stage_index - 2) if stage_type == &"coin_reward" else stage_index
	return "plains_run_early" if effective_index <= 2 else ("plains_run_mid" if effective_index <= 5 else "plains_run_late")
