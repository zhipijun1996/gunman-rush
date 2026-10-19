class_name ForestVerticalChainGeometry
extends RefCounted
## A hollow's continuous rising phrase. Data only; no player/RNG authority.
const VERSION := "forest-vertical-chain-golden-v1"
static func build() -> Dictionary:
	return {"version":VERSION,"id":"hollow_spiral","spawn":[0.0,0.0],"goal":[150.0,-560.0],"world_bounds":[-340.0,-850.0,1300.0,1200.0],
		"platforms":[{"id":"entry","rect":[-220.0,18.0,300.0,60.0],"one_way":false},{"id":"crown","rect":[100.0,-542.0,300.0,24.0],"one_way":true},{"id":"recovery","rect":[-310.0,220.0,1190.0,40.0],"one_way":false},{"id":"recovery_step","rect":[-305.0,118.0,65.0,20.0],"one_way":true},{"id":"left_bark","rect":[-290.0,-760.0,60.0,650.0],"one_way":false},{"id":"right_bark","rect":[470.0,-440.0,60.0,330.0],"one_way":false}],
		"hook_anchors":[{"id":"spiral_lower","position":[110.0,-170.0]},{"id":"spiral_middle","position":[-30.0,-340.0]},{"id":"spiral_crown","position":[90.0,-670.0]}],"dangers":[],
		"action_program":[{"action":"H","anchor":"spiral_lower"},{"action":"H","anchor":"spiral_middle"},{"action":"R","direction":[0,1]},{"action":"H","anchor":"spiral_crown"}],
		"rest_program":[{"action":"HANG","anchor":"rest_ring"},{"action":"H","anchor":"spiral_middle"},{"action":"R","direction":[0,1]},{"action":"H","anchor":"spiral_crown"}],
		"return":{"via":"recovery","goal_support":"entry"},"recovery":{"support":"recovery","walk_x":-275.0,"via":"recovery_step","exit":"entry"},
		"scene_language":{"entry":"root_ground","crown":"living_bough","recovery":"root_catch","recovery_step":"root_step"},
		"chain_contract":{"continuous_airborne":true,"midair_floor_allowed":false,"hook_restoration":"actual_contact_kick_completion","fixed_anchor_does_not_refill_shots":true,"production_pool":false,"native_verified":false}}
