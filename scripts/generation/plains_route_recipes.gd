class_name PlainsRouteRecipes
extends RefCounted
## Count operation sequences, not skin/module names. Used by the formal region.
const RECIPES := [
 {"id":"thorn_cells","modules":["plains_thorn_cells"],"actions":"read_safe_cells>jump_past_thorn_surface>land_green","pressure":"landing_footprint","decision":"choose_safe_landing"},
 {"id":"thorn_wall","modules":["plains_thorn_wall"],"actions":"stand_back>high_jump>clear_wall_face>land_cap","pressure":"height_and_wall_clearance","decision":"jump_from_outside_face"},
 {"id":"remote_bell","modules":["plains_remote_bell"],"actions":"match_sigil>aim_remote_control>choose_upper_or_ground_route","pressure":"navigation_and_line_of_sight","decision":"open_before_departure"},
 {"id":"controlled_ferry","modules":["plains_bell_ferry_control"],"actions":"shoot_start>board>shoot_brake_or_ride>restart>exit","pressure":"motion_control_and_energy","decision":"park_or_continue"},
 {"id":"gear_timing","modules":["plains_gear_glade"],"actions":"observe_phase>held_hop>land","pressure":"moving_contact","decision":"wait_or_jump"},
 {"id":"bell_order","modules":["plains_windchime_sequence"],"actions":"aim_first>advance>aim_second>cross","pressure":"order_and_aim","decision":"shoot_order"},
 {"id":"bell_deadline","modules":["plains_windchime_rush"],"actions":"aim>timed_gap_jump>reach_end_gate","pressure":"clock_and_landing","decision":"commit_or_reopen"},
 {"id":"recoil_crossing","modules":["plains_recoil_span"],"actions":"held_jump>aim_back_down>recoil>land","pressure":"air_energy_and_distance","decision":"aim_before_release"},
 {"id":"thorn_gap","modules":["plains_thorn_cells","plains_gear_brook"],"actions":"safe_cell_hop>land>observe_gear>second_hop","pressure":"safe_footprint","decision":"choose_takeoff"},
 {"id":"rescue_bank","modules":["plains_recovery_bridge"],"actions":"late_jump_or_early_jump>optional_recoil_rescue","pressure":"undershoot","decision":"spend_energy_or_save"},
 {"id":"ferry_dock","modules":["plains_ferry_channel"],"actions":"wait_dock>board>ride>leave_bank","pressure":"relative_motion","decision":"board_this_cycle_or_next"},
 {"id":"low_arch","modules":["plains_low_arch"],"actions":"observe_clearance>tap_jump>release>land","pressure":"headroom_and_contact","decision":"release_before_ceiling"},
 {"id":"double_gear","modules":["plains_twin_gears"],"actions":"observe_two_phases>hop>recover>second_hop","pressure":"rhythm_and_recovery","decision":"reset_between_hops"},
 {"id":"bell_pit","modules":["plains_windchime_well"],"actions":"jump>aim_down>recoil_and_open>land","pressure":"aim_and_void","decision":"open_before_crossing"}
]
static func choose(rng: RunRandomStream, history: Array, intro: bool) -> Dictionary:
	var pool: Array=[]
	var least:=2147483647
	for recipe: Dictionary in RECIPES:
		if intro and recipe.id in ["double_gear","bell_order"]: continue
		var used: int=history.count(recipe.id)
		if used<least: least=used;pool.clear()
		if used==least: pool.append(recipe)
	if pool.is_empty(): pool=RECIPES.duplicate()
	if not history.is_empty():
		var different:=pool.filter(func(r: Dictionary): return r.id!=history[-1])
		if not different.is_empty(): pool=different
	var picked: Dictionary=pool[rng.next_int(pool.size())].duplicate(true)
	history.append(picked.id)
	return picked
