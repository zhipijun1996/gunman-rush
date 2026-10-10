class_name PlainsBlueprintSchedule
extends RefCounted
## Pure seeded schedule: no hidden cross-run history, no consumption of map/loot RNG.
const VERSION := "plains_blueprint_schedule_v1"
const BLUEPRINTS := ["bridge_crossing", "windmill_ascent"]

static func plan(run_seed: String, stage_index: int, stage_type: StringName) -> Dictionary:
	var stream := RunRandomStream.new(run_seed, "blueprint", "plains_schedule", VERSION)
	var id: String = BLUEPRINTS[(stage_index - 1 + stream.next_int(2)) % BLUEPRINTS.size()]
	var phase := "introduction"
	if stage_type == &"boss":
		id = "fixed_boss_core"
		phase = "boss"
	elif stage_type in [&"shop", &"health_reward"]:
		id = "sanctuary"
		phase = "respite"
	elif stage_index >= 4:
		phase = "combination"
	return {"version": VERSION, "slot": stage_index, "blueprint_id": id, "phase": phase}
