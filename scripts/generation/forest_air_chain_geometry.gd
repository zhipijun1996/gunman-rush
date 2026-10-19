class_name ForestAirChainGeometry
extends RefCounted
## Same real Module/Motor consumer; programs describe accepted actions, never move actors.
const VERSION := "forest-air-chain-golden-v1"
const REGIONAL_OMITTED_SUPPORTS := ["recovery", "recovery_step"]
const REGIONAL_RECOVERY := "shared-regional-roots-v1"
const BASE := preload("res://scripts/generation/forest_directional_geometry.gd")
static func build(layout: String = "arch_four") -> Dictionary:
	if layout == "bridge_five": return _build_bridge_five()
	var data: Dictionary
	if layout == "arch_four":
		data = BASE.build().duplicate(true)
		data["action_program"] = [{"action":"H","anchor":"side_ring"},{"action":"R","direction":[-1,0]},{"action":"H","anchor":"arch_exit_ring"},{"action":"H","anchor":"crown_ring"}]
	else:
		data = {"spawn":[0.0,0.0],"goal":[355.0,-42.0],"world_bounds":[-320.0,-450.0,1250.0,800.0],"platforms":[{"id":"entry","rect":[-220.0,18.0,300.0,60.0],"one_way":false},{"id":"crown","rect":[250.0,-24.0,320.0,24.0],"one_way":true},{"id":"recovery","rect":[-310.0,220.0,1190.0,40.0],"one_way":false},{"id":"recovery_step","rect":[-305.0,118.0,65.0,20.0],"one_way":true}],"hook_anchors":[{"id":"relay_a","position":[300.0,-70.0]}],"dangers":[],"return":{"via":"recovery","goal_support":"entry"},"recovery":{"support":"recovery","walk_x":-275.0,"via":"recovery_step","exit":"entry"}}
		if layout == "recoil_hook":
			data.action_program = [{"action":"R","direction":[-1,0]},{"action":"H","anchor":"relay_a"}]
		elif layout == "recoil_hook_recoil":
			data.action_program = [{"action":"R","direction":[-1,0]},{"action":"H","anchor":"relay_a"},{"action":"R","direction":[0,1]}]
		elif layout == "hook_hook":
			data.spawn = [0.0,0.0]
			data.goal = [355.0,-42.0]
			data.platforms[1] = {"id":"crown","rect":[280.0,-24.0,320.0,24.0],"one_way":true}
			data.hook_anchors = [{"id":"relay_a","position":[200.0,-40.0]},{"id":"relay_b","position":[330.0,-170.0]}]
			data.action_program = [{"action":"H","anchor":"relay_a"},{"action":"H","anchor":"relay_b"}]
		else:
			return {}
	data["version"] = VERSION
	data["id"] = layout
	data["scene_language"] = {"entry":"root_ground","crown":"living_bough","recovery":"root_catch","recovery_step":"root_step","root_arch":"hollow_trunk"}
	data["chain_contract"] = {"continuous_airborne":true,"midair_floor_allowed":false,"hook_restoration":"actual_contact_kick_completion","fixed_anchor_does_not_refill_shots":true,"production_pool":false,"native_verified":false}
	return data

static func for_region(layout: String = "arch_four") -> Dictionary:
	# Standalone two-chain goldens own a wide test recovery floor. In a shared
	# region this floor would overlap the real roots; only the regional roots
	# supply recovery. Core entry/receiver/anchors/action program stay exact.
	var data := build(layout)
	if data.is_empty() or layout == "arch_four": return data
	if layout not in ["hook_hook", "recoil_hook", "recoil_hook_recoil", "bridge_five"]: return {}
	var supports: Array = []
	for row: Dictionary in data.platforms:
		if str(row.id) not in REGIONAL_OMITTED_SUPPORTS: supports.append(row)
	data.platforms = supports
	data["regional_recovery"] = REGIONAL_RECOVERY
	return data

static func _build_bridge_five() -> Dictionary:
	return {"version":VERSION,"id":"bridge_five","spawn":[0.0,0.0],"goal":[1020.0,-158.0],"world_bounds":[-320.0,-550.0,2000.0,900.0],
		"platforms":[{"id":"entry","rect":[-50.0,18.0,270.0,24.0],"one_way":true},{"id":"root_arch","rect":[-220.0,-520.0,570.0,410.0],"one_way":false},{"id":"crown","rect":[800.0,-140.0,300.0,60.0],"one_way":false},{"id":"recovery","rect":[-310.0,220.0,1900.0,40.0],"one_way":false},{"id":"recovery_step","rect":[-305.0,118.0,65.0,20.0],"one_way":true}],
		"hook_anchors":[{"id":"side_ring","position":[200.0,-40.0]},{"id":"bridge_ring_b","position":[470.0,-130.0]},{"id":"bridge_ring_c","position":[760.0,-240.0]}],
		"dangers":[[82.0,100.0,790.0,18.0]],
		"action_program":[{"action":"H","anchor":"side_ring"},{"action":"R","direction":[-1,0]},{"action":"H","anchor":"bridge_ring_b"},{"action":"R","direction":[-1,0]},{"action":"H","anchor":"bridge_ring_c"}],
		"return":{"drop_outside_x":1250.0,"via":"recovery","goal_support":"entry"},
		"recovery":{"support":"recovery","walk_x":-275.0,"via":"recovery_step","exit":"entry"},
		"scene_language":{"entry":"root_ground","root_arch":"hollow_trunk","crown":"living_bough","recovery":"root_catch","recovery_step":"root_step"},
		"chain_contract":{"continuous_airborne":true,"midair_floor_allowed":false,"hook_restoration":"actual_contact_kick_completion","fixed_anchor_does_not_refill_shots":true,"production_pool":false,"native_verified":false}}
