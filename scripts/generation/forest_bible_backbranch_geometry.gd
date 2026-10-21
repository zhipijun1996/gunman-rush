class_name ForestBibleBackbranchGeometry
extends RefCounted
## F05: a genuine downward outside approach followed by a left/up return.
## A candidate action program, never an alternate motion implementation.
const VERSION := "forest-bible-backbranch-v3"

static func build() -> Dictionary:
	return {"version":VERSION,"id":"backbranch_HR","spawn":[2020.0,982.0],"goal":[1740.0,1022.0],
		"world_bounds":[1540.0,800.0,800.0,640.0],
		"platforms":[
			{"id":"entry","rect":[1840.0,1000.0,220.0,24.0],"one_way":true},
			{"id":"crown","rect":[1700.0,1040.0,90.0,100.0],"one_way":false},
			{"id":"west_upper","rect":[1660.0,900.0,40.0,100.0],"one_way":false},
			{"id":"west_lower","rect":[1660.0,1080.0,40.0,60.0],"one_way":false},
			{"id":"broken_upper","rect":[1790.0,900.0,80.0,100.0],"one_way":false},
			{"id":"broken_lower","rect":[1790.0,1080.0,80.0,140.0],"one_way":false},
			{"id":"recovery","rect":[1640.0,1320.0,610.0,40.0],"one_way":false},
			{"id":"recovery_step","rect":[2140.0,1220.0,100.0,24.0],"one_way":true},
			{"id":"retry_step","rect":[2140.0,1110.0,100.0,24.0],"one_way":true}],
		"hook_anchors":[{"id":"side_fruit","position":[1886.0,1060.0]}],"dangers":[],
		"windows":[{"id":"broken_back_gap","clear_rect":[1790.0,1000.0,80.0,80.0]},{"id":"reward_opened_west_mouth","clear_rect":[1660.0,1000.0,40.0,80.0]}],
		"action_program":[{"action":"H","anchor":"side_fruit"},{"action":"R","direction":[1,0.5]}],
		"departure":{"kind":"drop_through","path":[[2020.0,982.0],[2080.0,982.0],[2080.0,1132.0]],"landing":[2080.0,1132.0],"ground_required":false},
		"return":{"via":"recovery","goal_support":"entry"},
		"chain_contract":{"continuous_airborne":true,"midair_floor_allowed":false,"production_pool":false,"native_verified":false,"departure_before_first_hook":"outside_drop","required_recoil_quadrant":"right_down","receiver_is_behind_entry":true}}

static func as_module(data: Dictionary) -> PlatformingModuleDefinition:
	var definition := ForestDirectionalGeometry.as_module(data)
	definition.module_id = &"forest_bible_backbranch"
	return definition
