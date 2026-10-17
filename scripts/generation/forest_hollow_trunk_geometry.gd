class_name ForestHollowTrunkGeometry
extends RefCounted
## NEW unverified geometry. Old directional/narrow golden bytes remain intact.
## This is a module-shaped candidate consumed by the existing PlatformingModule;
## not a second region generator and not an admitted production module.
const VERSION := "forest-hollow-trunk-double-window-candidate-v4"
static func build(return_style: String = "deep_zeroR") -> Dictionary:
	return {
		"version":VERSION,"id":"hollow_trunk_double_window","production_pool":false,
		"native_verified":false,"return_style":return_style,"spawn":[0.0,0.0],"goal":[380.0,-42.0],
		"world_bounds":[-340.0,-550.0,1100.0,1040.0],
		"platforms":[
			{"id":"belly_entry","rect":[-220.0,18.0,300.0,60.0],"one_way":false},
			{"id":"belly_roof","rect":[-220.0,-520.0,430.0,410.0],"one_way":false},
			{"id":"trunk_above_window","rect":[210.0,-520.0,120.0,426.0],"one_way":false},
			{"id":"trunk_between_windows","rect":[210.0,-24.0,120.0,164.0],"one_way":false},
			{"id":"trunk_below_window","rect":[210.0,420.0,120.0,70.0],"one_way":false},
			{"id":"outer_crown","rect":[330.0,-24.0,270.0,24.0],"one_way":true},
			{"id":"inner_root","rect":[-310.0,220.0,500.0,40.0],"one_way":false},
			{"id":"outer_root","rect":[350.0,300.0,350.0,40.0],"one_way":false},
			{"id":"outer_sump","rect":[330.0,460.0,370.0,30.0],"one_way":false},
			{"id":"outer_recovery_step","rect":[270.0,350.0,60.0,16.0],"one_way":true},
			{"id":"inner_recovery_step","rect":[-305.0,118.0,65.0,20.0],"one_way":true}
		],
		"hook_anchors":[
			{"id":"upper_window_ring","position":[200.0,-40.0]},
			{"id":"lower_window_ring","position":([120.0,155.0] if return_style=="deep_zeroR" else [170.0,170.0])}
		],
		"dangers":[],
		"nodes":{
			"M":{"position":[0.0,0.0],"support_id":"belly_entry","role":"belly_observe"},
			"E":{"position":[380.0,-42.0],"support_id":"outer_crown","role":"outer_crown_observe"},
			"D":{"position":[120.0,202.0],"support_id":"inner_root","role":"inner_recovery"},
			"R":{"position":[420.0,282.0],"support_id":"outer_root","role":"outer_recovery"}
		},
		"windows":[
			{"id":"upper_window","clear_rect":[210.0,-94.0,120.0,70.0],"anchor_id":"upper_window_ring","from":"M","to":"E"},
			{"id":"lower_window","clear_rect":[210.0,140.0,120.0,280.0],"anchor_id":"lower_window_ring","from":"R","to":"D"}
		],
		"candidate_itinerary":[
			{"id":"belly_to_crown","from":"M","to":"E","anchor_id":"upper_window_ring","intent":"horizontal_hook_then_shoot_left_recoil_right"},
			{"id":"crown_to_outer_root","from":"E","to":"R","intent":"walk_past_outer_edge_then_observe_lower_window","drop_x":620.0},
			{"id":"outer_to_inner_root","from":"R","to":"D","anchor_id":"lower_window_ring","intent":"jump_or_descent_side_hook_then_shoot_right_recoil_left"},
			{"id":"inner_to_belly","from":"D","to":"M","intent":"two_short_recovery_jumps","via":"inner_recovery_step"}
		],
		"recovery":{"outer_miss_support":"outer_root","inner_miss_support":"inner_root","bottom_miss_support":"outer_sump","sump_retry_via":["trunk_below_window","outer_recovery_step","outer_root"],"bottom_retry_via":["outer_recovery_step","outer_root"],"safe_retry":"R","native_verified":false},
		"comparisons":["ordinary_jump_no_hook_no_shoot","normal_shots_without_hook","hook_without_shoot","intentional_miss_then_local_retry"],
		"evidence_scope":"New solid trunk and lower-window return: NO inherited directional/narrow native approval. No enemies/rewards/seed variation/Boss integration yet."
	}
static func as_module(data: Dictionary) -> PlatformingModuleDefinition:
	# Existing module schema and physical consumer, no alternate movement code.
	var definition := ForestDirectionalGeometry.as_module(data)
	definition.module_id=&"forest_hollow_trunk_candidate"
	return definition

static func build_cavity() -> Dictionary:
	# New local roof excavation, NOT an admitted replacement of the shared tree.
	# The original lower window, M/E/D/R and eight lower bodies remain exact.
	var data: Dictionary=build("deep_zeroR")
	data.version="forest-hollow-horizontal-cavity-v1"
	data.id="hollow_horizontal_borer_cavity"
	data.spawn=[-245.0,-318.0]
	data.goal=[430.0,-318.0]
	var bodies: Array=[]
	for row: Dictionary in data.platforms:
		if row.id=="belly_roof":
			bodies.append({"id":"belly_roof_upper","rect":[-220.0,-520.0,430.0,90.0],"one_way":false})
			bodies.append({"id":"belly_roof","rect":[-220.0,-276.0,430.0,166.0],"one_way":false})
		elif row.id=="trunk_above_window":
			bodies.append({"id":"trunk_upper_cap","rect":[210.0,-520.0,120.0,90.0],"one_way":false})
			bodies.append({"id":"trunk_above_window","rect":[210.0,-276.0,120.0,182.0],"one_way":false})
		else:bodies.append(row)
	bodies.append_array([
		{"id":"cavity_observe","rect":[-350.0,-300.0,130.0,24.0],"one_way":true},
		{"id":"cavity_bay","rect":[40.0,-300.0,130.0,24.0],"one_way":true},
		{"id":"cavity_exit","rect":[330.0,-300.0,270.0,24.0],"one_way":true},
		{"id":"cavity_right_step","rect":[610.0,-400.0,90.0,20.0],"one_way":true},
		{"id":"cavity_right_upper","rect":[460.0,-490.0,110.0,20.0],"one_way":true},
		{"id":"cavity_roof_step","rect":[350.0,-500.0,100.0,20.0],"one_way":true},
		{"id":"cavity_left_step","rect":[-470.0,-400.0,120.0,20.0],"one_way":true},
		{"id":"cavity_left_upper","rect":[-360.0,-490.0,120.0,20.0],"one_way":true}
	])
	data.platforms=bodies
	data.hook_anchors.append_array([{"id":"cavity_ring_a","position":[-35.0,-350.0]},{"id":"cavity_ring_b","position":[330.0,-350.0]}])
	data.dangers=[[-220.0,-430.0,550.0,20.0],[-220.0,-300.0,260.0,24.0],[170.0,-300.0,160.0,24.0]]
	data.world_bounds=[-510.0,-570.0,1220.0,1100.0]
	data.windows.append({"id":"cavity","clear_rect":[-220.0,-410.0,550.0,110.0],"anchor_id":"cavity_ring_a","from":"S","to":"C"})
	data.nodes.S={"position":data.spawn,"support_id":"cavity_observe","role":"observe_entire_borer_hole"}
	data.nodes.B={"position":[110.0,-318.0],"support_id":"cavity_bay","role":"observe_second_side_hook"}
	data.nodes.C={"position":data.goal,"support_id":"cavity_exit","role":"wide_exit_above_original_E"}
	data["cavity_contract"]={"body":[24,36],"clear_height":110,"centres_y":[-392,-318],"successful_contact_restores_hook":true,"bay_is_real_landing":true,"variant":"two_horizontal_cells_with_safe_observation_bay","preserved_ports":["M","E","D","R"],"not_yet_verified":["S_access_from_M","C_return_to_E","formal_generation","viewport","strong_cheap"]}
	return data

static func build_cavity_elbow() -> Dictionary:
	# Opt-in G0 candidate. Existing factories/ports remain exact; no admission.
	var data: Dictionary=build_cavity().duplicate(true)
	data.version="forest-hollow-horizontal-elbow-candidate-v2"
	data.id="hollow_airborne_descending_elbow"
	data.goal=[430.0,-228.0]
	var bodies: Array=[]
	for row: Dictionary in data.platforms:
		match String(row.id):
			"belly_roof_upper":
				bodies.append({"id":"belly_roof_upper","rect":[-220.0,-520.0,390.0,90.0],"one_way":false})
				bodies.append({"id":"elbow_upper_lip","rect":[170.0,-520.0,40.0,130.0],"one_way":false})
			"trunk_upper_cap":row.rect=[210.0,-520.0,120.0,130.0];bodies.append(row)
			"belly_roof":
				bodies.append({"id":"belly_roof","rect":[-220.0,-276.0,390.0,166.0],"one_way":false})
				bodies.append({"id":"elbow_lower_lip","rect":[170.0,-186.0,40.0,76.0],"one_way":false})
			"trunk_above_window":row.rect=[210.0,-186.0,120.0,92.0];bodies.append(row)
			"cavity_exit":row.rect=[330.0,-210.0,270.0,24.0];bodies.append(row)
			_:bodies.append(row)
	bodies.append({"id":"elbow_return_relay","rect":[500.0,-310.0,160.0,20.0],"one_way":true})
	data.platforms=bodies
	for row: Dictionary in data.hook_anchors:
		if row.id=="cavity_ring_b":row.position=[310.0,-260.0]
	# Spikes protrude from real solids: top solid ends -390, danger ends -370;
	# bottom danger starts -210, real bottom support starts -186. Clear stays160.
	data.dangers=[[-220.0,-430.0,390.0,20.0],[-220.0,-300.0,260.0,24.0],[170.0,-210.0,160.0,24.0],[170.0,-390.0,160.0,20.0]]
	data["danger_presentations"]=[{"facing":"down"},{"facing":"up"},{"facing":"up"},{"facing":"down"}]
	for row: Dictionary in data.windows:
		if row.id=="cavity":row.clear_rect=[-220.0,-410.0,390.0,110.0];row.to="B"
	data.windows.append({"id":"cavity_elbow","clear_rect":[170.0,-370.0,160.0,160.0],"anchor_id":"cavity_ring_b","from":"B","to":"C"})
	data.nodes.C={"position":data.goal,"support_id":"cavity_exit","role":"lower_wide_receiver_after_downward_hook"}
	data.cavity_contract.merge({"variant":"horizontal_then_airborne_descending_elbow","second_clear_height":160,"ceiling_solid_bottom":-390,"ceiling_danger_bottom":-370,"floor_danger_top":-210,"floor_solid_top":-186,"seam_overlap_height":70,"airborne_after_bay_required":true,"exit_top":-210,"return_relay_id":"elbow_return_relay","preserved_ports":["M","E","D","R","S","B"],"native_verified":false,"not_yet_verified":["second_HR_full_return","second_H0R_full_return","adapted_strong_ordinary","regional_seams","viewport"]},true)
	return data

static func build_aircatch() -> Dictionary:
	# Local continuous-air capture hypothesis; original factories stay unchanged.
	var data: Dictionary=build("deep_zeroR")
	data.version="forest-hollow-lower-aircatch-candidate-v1"
	data.id="hollow_lower_aircatch"
	for row: Dictionary in data.platforms:
		if row.id=="outer_root":row.rect=[366.0,300.0,334.0,40.0]
		elif row.id=="inner_root":row.rect=[-310.0,220.0,460.0,40.0]
	data["aircatch_contract"]={"version":"lower-aircatch-v1","native_verified":false,"scope":"continuous descending H0R versus earliest legal R; not region/randomness approval","from":"E","to":"D","anchor_id":"lower_window_ring","no_ground_cast_to_contact":true,"full_support_frames":12,"preserved_ports":["M","E","D","R"]}
	return data
