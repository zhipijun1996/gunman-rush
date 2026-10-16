class_name PlainsRootBellEncounterV3
extends RefCounted
## V11 remains byte reproducible. New physical classes never edit its admission.
const VERSION := "root-bell-encounter-v3"
const CONTENT_VERSION := "plains-region-v12-root-bell-spaces"
const PRODUCTION_ADMITTED := true

static func inspect(m: Dictionary, node: Dictionary, lookup: Callable) -> Dictionary:
	var facts := PlainsRootBellEncounterV2.inspect(m, node, lookup)
	if not facts.has("floor_xywh"): return facts
	var rescue: bool = facts.recipe == "rescue_bank" and facts.floor_xywh[2] == 560
	var gear: bool = facts.recipe == "double_gear" and facts.floor_xywh[2] == 620
	if not rescue and not gear:
		facts["space_class"] = "unreviewed_geometry"
		return facts
	if rescue: facts.reasons.erase("unreviewed_geometry_class")
	facts["space_class"] = "recovery_bridge_tight_bank" if rescue else "double_gear_wide_bank"
	facts["joint_space"] = {
		"neighbor_action": "late_jump_or_early_jump>optional_recoil_rescue" if rescue else "observe_two_phases>hop>recover>second_hop",
		"arrival_decision": "land_then_bait_without_spending_remaining_shot" if rescue else "finish_gear_recovery_then_read_ground_mark",
		"alive_solution": "fixed_mark_walk_retreat>jump_body>observe_old_mark_before_return",
		"shot_solution": "stable_bank>actual_projectile_interrupt>grounded_recoil_retreat",
		"return_decision": "old_ground_mark_is_not_a_tracking_projectile",
		"visual_identity": "rooted_riverbank_below_natural_rock" if rescue else "rock_bank_after_twin_gears",
		"visual_keep_clear_xywh": [facts.floor_xywh[0]+40, facts.floor_xywh[1]-190, facts.floor_xywh[2]-80, 190],
		"asset_support": "solid_floor_only; rooted_plants_behind_play; no_false_landing_silhouette",
		"weapon": "formal_single_pulse_lv1; no_H_W_D_required",
		"scope": "design_contract; native_route_and_pixels_required_for_admission"
	}
	return facts

static func apply(m: Dictionary, lookup: Callable) -> Dictionary:
	var nodes: Array = m.nodes.duplicate()
	nodes.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return str(a.id)<str(b.id))
	for node: Dictionary in nodes:
		var facts := inspect(m,node,lookup)
		if not facts.reasons.is_empty():continue
		for enemy: Dictionary in m.enemies:
			if enemy.get("area","")!=node.id or not str(enemy.id).begins_with("plains/enemy/lane/"):continue
			enemy.behavior_id="root_bell"
			enemy.patrol_radius=0
			enemy.aerial=false
			enemy.position=facts.home
			enemy.pattern="ground_mark_interrupt"
			enemy.escape="walk_out_of_fixed_mark_or_jump_over_live_body; real_hp_hit_interrupts"
			return {"version":VERSION,"status":"one_candidate","replaced":1,"id":enemy.id,"module":node.id,"physical_facts":facts}
	return {"version":VERSION,"status":"no_physically_qualified_lane","replaced":0}
