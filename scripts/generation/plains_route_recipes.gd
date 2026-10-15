class_name PlainsRouteRecipes
extends RefCounted
## Count operation sequences, not skin/module names. Used by the formal region.
const RECIPES := [
 {"id":"well_arch_phrase","modules":["plains_windchime_well","plains_low_arch"],"actions":"observe_bell>jump>shoot_down_open_and_recoil>correct>land_recover>read_headroom>tap_release>land","pressure":"dual_use_shot_then_headroom","decision":"change_air_control_after_real_landing"},
 {"id":"thorn_slalom","modules":["plains_thorn_slalom"],"actions":"hop_thorn>read_gear>hop>land_island>hop_second_thorn","pressure":"alternating_footprint_and_motion","decision":"reset_on_safe_island"},
 {"id":"remote_sequence","modules":["plains_remote_sequence"],"actions":"shoot_ring1>enter_open_path>pass_baffle>climb>shoot_remote_ring2>reach_far_gate","pressure":"occluded_aim_and_navigation","decision":"move_for_new_sightline"},
 {"id":"thorn_cells","modules":["plains_thorn_cells"],"actions":"read_safe_cells>jump_past_thorn_surface>land_green","pressure":"landing_footprint","decision":"choose_safe_landing"},
 {"id":"thorn_wall","modules":["plains_thorn_wall","plains_gear_brook"],"actions":"stand_back>high_jump>clear_wall_face>land_cap>observe_gear>hop","pressure":"height_and_wall_clearance","decision":"jump_from_outside_face"},
 {"id":"remote_bell","modules":["plains_remote_bell"],"actions":"match_sigil>aim_remote_control>choose_upper_or_ground_route","pressure":"navigation_and_line_of_sight","decision":"open_before_departure"},
 {"id":"controlled_ferry","modules":["plains_bell_ferry_control"],"actions":"shoot_start>board>shoot_brake_or_ride>restart>exit","pressure":"motion_control_and_energy","decision":"park_or_continue"},
 {"id":"gear_timing","modules":["plains_twin_gears"],"actions":"observe_phase>held_hop>land","pressure":"moving_contact","decision":"wait_or_jump"},
 {"id":"bell_order","modules":["plains_windchime_sequence"],"actions":"aim_first>advance>aim_second>cross","pressure":"order_and_aim","decision":"shoot_order"},
 {"id":"bell_deadline","modules":["plains_windchime_rush"],"actions":"aim>timed_gap_jump>reach_end_gate","pressure":"clock_and_landing","decision":"commit_or_reopen"},
 {"id":"recoil_crossing","modules":["plains_recoil_span"],"actions":"held_jump>aim_back_down>recoil>land","pressure":"air_energy_and_distance","decision":"aim_before_release"},
 {"id":"thorn_gap","modules":["plains_thorn_bridge","plains_low_arch"],"actions":"held_gap_jump>land_recover>read_low_ceiling>tap_jump>release>land","pressure":"gap_commitment_then_headroom","decision":"change_jump_hold_after_landing"},
 {"id":"rescue_bank","modules":["plains_recovery_bridge"],"actions":"late_jump_or_early_jump>optional_recoil_rescue","pressure":"undershoot","decision":"spend_energy_or_save"},
 {"id":"ferry_dock","modules":["plains_ferry_channel"],"actions":"wait_dock>board>ride>leave_bank","pressure":"relative_motion","decision":"board_this_cycle_or_next"},
 {"id":"low_arch","modules":["plains_low_arch","plains_gear_brook"],"actions":"observe_clearance>tap_jump>release>land>read_second_gear","pressure":"headroom_and_contact","decision":"release_before_ceiling"},
 {"id":"double_gear","modules":["plains_twin_gears"],"actions":"observe_two_phases>hop>recover>second_hop","pressure":"rhythm_and_recovery","decision":"reset_between_hops"},
 {"id":"bell_pit","modules":["plains_windchime_well","plains_gear_brook"],"actions":"jump>aim_down>recoil_and_open>land>gear_hop","pressure":"aim_and_void","decision":"open_before_crossing"}
]
static func choose(rng: RunRandomStream, history: Array, intro: bool, intent: String="", identity: String="") -> Dictionary:
	var pool: Array=[]
	var least:=2147483647
	var eligible:Array=RECIPES.filter(func(r:Dictionary):return not intro or r.id not in ["double_gear","bell_order"])
	# Spatial intent selects an appropriate first lesson; subsequent choices retain
	# broad pressure coverage without forcing hazards onto every quiet approach.
	if intent=="legacy_sample":
		eligible=eligible.filter(func(r: Dictionary):return r.id!="well_arch_phrase")
		if history.size()>=4:
			var saw_ids: Array=["thorn_slalom","thorn_wall","gear_timing","thorn_gap","low_arch","double_gear","bell_pit"]
			var thorn_ids: Array=["thorn_slalom","thorn_cells","thorn_wall","thorn_gap","low_arch","bell_pit"]
			var saw_count: int=history.filter(func(id):return id in saw_ids).size()
			var thorn_count: int=history.filter(func(id):return id in thorn_ids).size()
			var target: int=2 if intro else 3
			var legacy_wanted: Array=saw_ids if saw_count<target and saw_count<=thorn_count else thorn_ids if thorn_count<target else []
			if not legacy_wanted.is_empty(): eligible=eligible.filter(func(r: Dictionary):return r.id in legacy_wanted)
	var identity_pool: Array=[]
	if identity=="clock_court": identity_pool=["remote_sequence","remote_bell","bell_order","bell_deadline","bell_pit","gear_timing"]
	elif identity=="creek_well": identity_pool=["ferry_dock","controlled_ferry","thorn_cells","thorn_slalom","double_gear","rescue_bank"]
	elif identity=="windmill_plateau": identity_pool=["well_arch_phrase","thorn_gap","low_arch","recoil_crossing","thorn_wall","gear_timing","bell_pit"]
	if not identity_pool.is_empty() and intent not in ["first_short_chain","creek_discovery"]: eligible=eligible.filter(func(r: Dictionary):return r.id in identity_pool)
	var wanted: Array=[]
	if intent=="outer_return": wanted=["ferry_dock"]
	elif intent=="first_short_chain": wanted=["well_arch_phrase"] if intro else ["remote_sequence"]
	elif intent=="rejoin_repair_camp":wanted=["gear_timing","recoil_crossing","thorn_wall"] if intro else ["gear_timing","recoil_crossing","low_arch"]
	elif intent=="creek_discovery":wanted=["controlled_ferry"]
	elif identity=="creek_well" and not history.has("ferry_dock"): wanted=["ferry_dock"]
	elif identity=="clock_court" and not history.has("remote_bell"): wanted=["remote_bell"]
	if not wanted.is_empty(): eligible=eligible.filter(func(r:Dictionary):return r.id in wanted)
	for recipe: Dictionary in eligible:
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
