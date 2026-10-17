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
