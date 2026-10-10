class_name PlainsStageGenerator
extends RefCounted

const VERSION := "plains-run-v1"
const TYPES := ["combat", "shop", "coin_reward", "health_reward", "item_reward", "boss"]

# Layout draws cannot perturb routes, rewards, or merchant inventory. Each room
# uses its stable index rather than an advancing global map RNG.
func generate(run_seed: String, stage_index: int, stage_type: StringName, tuning: PlayerTuning) -> Dictionary:
	if stage_index < 1 or stage_index > 10 or str(stage_type) not in TYPES or (stage_index == 10) != (stage_type == &"boss"):
		return {"ok": false, "error": "Formal plains requires rooms 1–9 and Boss 10"}
	var rng := RunRandomStream.new(run_seed, "map", "stage_%d" % stage_index, VERSION)
	var profile_id := profile_for(stage_index, stage_type)
	var count := 8 if stage_type in [&"shop", &"health_reward", &"boss"] else 10 + mini(4, stage_index / 2)
	var generator := RandomStageGenerator.new()
	var generated := generator.generate(rng.next_int(2147483647), tuning, count, profile_id)
	if not generated.ok:
		return generated
	var manifest: Dictionary = generated.manifest
	var points: Array[Vector2] = []
	var arena := Rect2()
	for node: Dictionary in manifest.nodes:
		var definition := generator.definition_for(node.module_id, node.mirrored)
		var offset := Vector2(node.offset[0], node.offset[1])
		for point: Vector2 in definition.anchors:
			var world_point := point + offset
			if not points.has(world_point):
				points.append(world_point)
		if node.module_id == "plains_boss_arena":
			# Core attack space stays fixed; only its entrance module chain varies.
			arena = Rect2(offset + Vector2(100, 250), Vector2(920, 350))
	if stage_type == &"boss" and arena.size == Vector2.ZERO:
		return {"ok": false, "error": "Boss layout lacks its validated fixed core"}
	return {"ok": true, "error": "", "manifest": manifest, "placement_points": points, "boss_arena": arena, "stage_generator_version": VERSION}

func profile_for(stage_index: int, stage_type: StringName) -> String:
	if stage_type == &"boss":
		return "plains_run_boss"
	if stage_type in [&"shop", &"health_reward"]:
		return "plains_run_service"
	# Coin rooms emphasize traversing the pickups, rather than combat pressure.
	var effective_index := maxi(1, stage_index - 2) if stage_type == &"coin_reward" else stage_index
	return "plains_run_early" if effective_index <= 3 else ("plains_run_mid" if effective_index <= 6 else "plains_run_late")
