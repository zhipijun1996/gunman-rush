class_name ForestHollowUpperCandidate
extends RefCounted
## Author experiment: remove the upper walking bridge, retain a legal lower loop.
## Uses the existing module/player/runtime. Not admitted or inherited Hollow05.
const VERSION := "forest-hollow-floorless-upper-candidate-v1"
static func build() -> Dictionary:
	var data: Dictionary=ForestHollowTrunkGeometry.build()
	data.version=VERSION
	data.id="hollow_floorless_canopy"
	data.spawn=[0.0,0.0]
	data.goal=[380.0,-42.0]
	data.platforms=[
		{"id":"belly_entry","rect":[-220.0,18.0,340.0,60.0],"one_way":false},
		{"id":"belly_roof","rect":[-220.0,-520.0,430.0,410.0],"one_way":false},
		{"id":"trunk_above_window","rect":[210.0,-520.0,120.0,426.0],"one_way":false},
		{"id":"outer_crown","rect":[300.0,-24.0,300.0,24.0],"one_way":true},
		{"id":"inner_root","rect":[-310.0,220.0,1100.0,40.0],"one_way":false},
		{"id":"inner_recovery_step","rect":[-305.0,118.0,65.0,20.0],"one_way":true},
		{"id":"outer_low_step","rect":[650.0,118.0,140.0,20.0],"one_way":true},
		{"id":"outer_high_step","rect":[650.0,18.0,140.0,20.0],"one_way":true}
	]
	data.hook_anchors=[{"id":"upper_window_ring","position":[330.0,-40.0]}]
	data.dangers=[]
	data.world_bounds=[-340.0,-550.0,1160.0,850.0]
	data.windows=[{"id":"upper_lip","clear_rect":[210.0,-94.0,120.0,70.0],"anchor_id":"upper_window_ring","from":"M","to":"E"}]
	data.nodes={
		"M":{"position":[0.0,0.0],"support_id":"belly_entry","role":"observe_canopy_and_lower_loop"},
		"E":{"position":[380.0,-42.0],"support_id":"outer_crown","role":"crown_receive"},
		"F":{"position":[720.0,202.0],"support_id":"inner_root","role":"wide_recovery_floor"},
		"L":{"position":[720.0,100.0],"support_id":"outer_low_step","role":"ordinary_lower_loop"},
		"U":{"position":[720.0,0.0],"support_id":"outer_high_step","role":"ordinary_upper_loop"}
	}
	data.candidate_itinerary=[{"id":"floorless_upper","from":"M","to":"E","anchor_id":"upper_window_ring","intent":"side_pull_coming_side_kick_then_natural_zero_shot_reception"},{"id":"lower_loop","from":"F","to":"E","via":["L","U"],"intent":"normal_jumps_then_leftward_crown_reception"}]
	data.recovery={"miss_support":"inner_root","safe_retry":"F","ordinary_to_same_exit":["outer_low_step","outer_high_step","outer_crown"],"full_return":["inner_root","inner_recovery_step","belly_entry"],"native_verified":false}
	data.comparisons=["H0R","noH_zeroR","noH_oneR","wrongH"]
	data["upper_candidate_contract"]={"launch":[108.0,0.0],"intent":"horizontal_H_then_coming_side_kick_then_natural_apex_right_to_crown_without_R","cheap":"same_launch_short_jump_then_one_left_R; two_R_if_one_fails","fallback":"wide_floor_then_external_two_normal_jumps_and_leftward_crown_jump","return":"drop_then_original_left_two_jump_recovery","native_verified":false}
	data.evidence_scope="New floorless horizontal relationship, no inherited H value; no enemies/hazards/formal generation/viewport admission."
	return data
static func build_shared_upper() -> Dictionary:
	# Preserve every original lower body/anchor/port; the isolated wide floor is
	# deliberately NOT reused. These are new seams, not inherited approvals.
	var data: Dictionary=ForestHollowTrunkGeometry.build("deep_zeroR")
	data.version=VERSION+"-shared-upper-v1"
	data.id="shared_hollow_floorless_upper"
	for row: Dictionary in data.platforms:
		if row.id=="belly_entry":row.rect=[-220.0,18.0,340.0,60.0]
		elif row.id=="outer_crown":row.rect=[300.0,-24.0,300.0,24.0]
		elif row.id=="trunk_between_windows":row.rect=[210.0,100.0,120.0,40.0]
	for row: Dictionary in data.hook_anchors:
		if row.id=="upper_window_ring":row.position=[330.0,-40.0]
	data.platforms.append_array([
		{"id":"outer_loop_base","rect":[650.0,218.0,140.0,20.0],"one_way":true},
		{"id":"outer_low_step","rect":[650.0,118.0,140.0,20.0],"one_way":true},
		{"id":"outer_high_step","rect":[650.0,18.0,140.0,20.0],"one_way":true}
	])
	data.world_bounds=[-340.0,-550.0,1160.0,1100.0]
	data["upper_candidate_contract"]={"launch":[108.0,0.0],"intent":"horizontal_H_zero_R","ordinary_bay":{"position":[270.0,82.0],"support_id":"trunk_between_windows"},"preserved_lower_ports":["D","R"],"preserved_lower_anchor":[120.0,155.0],"new_seams_native_verified":false}
	data.candidate_itinerary[0].intent="side_pull_coming_side_kick_then_natural_zero_shot_reception"
	data.evidence_scope="New upper local relation with original lower D/R/anchor/body preserved; all new bay and lower seams must actually pass. No isolated wide-floor inheritance."
	return data

static func build_cavity() -> Dictionary:
	# Compatibility entry for the frozen author experiment; one geometry authority.
	return ForestHollowTrunkGeometry.build_cavity()
