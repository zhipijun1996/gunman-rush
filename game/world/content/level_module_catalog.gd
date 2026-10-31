class_name LevelModuleCatalog
extends RefCounted
## The existing module authority, moved out of the old selection algorithm.
## There is one admission list; legacy Generator APIs delegate here.
const CATALOG := ["micro_board", "micro_step", "micro_drop", "spike_gap", "saw_gate", "macro_chain", "challenge_recoil_climb", "challenge_long_gap", "challenge_ferry_ascent", "route_junction"]
const PLAINS_CATALOG := ["plains_micro_rise", "plains_meadow_gap", "plains_terraces", "plains_valley", "plains_boss_arena", "plains_long_meadow", "plains_split_terrace", "plains_braided_meadow", "plains_switchback", "plains_wind_spire", "plains_micro_landing", "plains_micro_stool", "plains_thorn_hop", "plains_gear_hop"]
const BRANCH_CATALOG := ["plains_recoil_span", "plains_ferry_gears", "plains_windchime_sequence", "plains_windchime_timed", "plains_windchime_ferry", "plains_windchime_lesson", "plains_windchime_well", "plains_patrol_meadow", "plains_recovery_bridge", "plains_bramble_causeway", "plains_high_perches", "plains_bramble_ridge", "plains_recoil_step", "plains_recoil_double", "plains_ferry_one", "plains_ferry_two", "plains_recoil_chasm", "plains_recoil_chasm_wide", "plains_thorn_bridge", "plains_thorn_steps", "plains_gear_brook", "plains_gear_glade", "plains_perch_rise", "plains_perch_double", "plains_skip_stones", "plains_fork_paths", "plains_door_landing", "plains_fork_rest"]
const EXPLORATION_CATALOG := ["plains_thorn_slalom","plains_remote_sequence","plains_thorn_cells","plains_thorn_wall","plains_remote_bell","plains_bell_ferry_control","plains_bellstrider_arena","plains_ferry_channel","plains_low_arch","plains_twin_gears","plains_windchime_rush"]
const LOCAL_REFLECTION_IDS := ["micro_step", "plains_micro_rise", "plains_meadow_gap", "plains_terraces", "plains_valley"]
const CONTENT_RUNTIME_VERSION := "platforming-module-runtime-6"

static func definition_for(module_id: String, mirrored: bool = false, reverse_traversal: bool = false) -> PlatformingModuleDefinition:
	if module_id not in CATALOG and module_id not in PLAINS_CATALOG and module_id not in BRANCH_CATALOG and module_id not in EXPLORATION_CATALOG:
		return null
	var definition := load("res://resources/generation/modules/%s.tres" % module_id) as PlatformingModuleDefinition
	if not mirrored:
		return definition
	var reflected := ModuleReflection.reflected_definition(definition)
	if reverse_traversal:
		if module_id not in LOCAL_REFLECTION_IDS:
			return null
		var old_entry := reflected.entry_port
		reflected.entry_port = reflected.exit_port
		reflected.exit_port = old_entry
		reflected.entry_port.direction = Vector2.RIGHT
		reflected.exit_port.direction = Vector2.RIGHT
		reflected.anchors.reverse()
	return reflected

static func scene_for(module_id: String) -> PackedScene:
	if module_id not in CATALOG and module_id not in PLAINS_CATALOG and module_id not in BRANCH_CATALOG and module_id not in EXPLORATION_CATALOG:
		return null
	return load("res://scenes/generation/modules/%s.tscn" % module_id) as PackedScene

