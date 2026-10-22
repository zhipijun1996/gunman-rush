class_name ForestExplorationFruitCrossing
extends RefCounted
## A fixed-fruit backbranch candidate. It does NOT instantiate a living host.
## The useful decision is forward progress versus catching a forward fruit
## to reverse toward the high branch which was behind the observation root.
const VERSION := "forest-backbranch-reversal-v18.5"
const SOURCE := "res://scripts/generation/forest_exploration_fruit_crossing.gd"
const SHAPE := preload("res://scripts/generation/forest_exploration_places.gd")

static func build(variant: int = 0) -> Dictionary:
	if variant not in [0,1]: return {}
	var cache_y := -192.0 if variant == 1 else -176.0
	var fruit_x := 240.0 if variant == 1 else 256.0
	var fruit_y := -144.0 if variant == 1 else -128.0
	var roof_y := fruit_y-112.0
	var m := {
		"id":"backbranch_fruit_reversal","identity":"look behind the forward fruit: its contact kick and one backward diagonal recoil reach the earlier high branch; the ordinary outward route goes elsewhere",
		"version":VERSION,"variant":variant,"bible_sha256":SHAPE.BIBLE_SHA,
		"requires":["grapple"],"difficulty":"optional_hook_reversal_with_resource_free_outer_route",
		"spawn":[128.0,0.0],"goal":[-64.0,cache_y-18.0],
		"entry_support_id":"entry","exit_support_id":"crown",
		"platforms":[],"hook_anchors":[],"dangers":[],"danger_surfaces":[],"danger_presentations":[],"scene_language":{},"routes":{},"ports":{},
		"source_factory":{"path":SOURCE,"version":VERSION,"sha256":FileAccess.get_sha256(SOURCE)},
		"admission":{"geometry":"candidate","motor":"unverified","visual":"unverified","production_pool":false},
		"resource_contract":{"new_abilities":false,"physics_override":false,"health_override":false,"shot_refill_override":false,"intended_optional_air_shots":1,"normal_onward_air_shots":0,"normal_onward_hooks":0},
		"chain_contract":{"continuous_airborne":true,"midair_floor_allowed":false,"hook_restoration":"actual_contact_kick_completion","fixed_anchor_does_not_refill_shots":true,"native_verified":false,"production_pool":false},
		"tile_contract":{"family":"shared_underworld_with_forest_bible_material","source_tile_px":16,"world_tile_wu":32,"solid":"exact_union","one_way":"separate_bough_family","moving":false,"port_halo_wu":32,"standalone_spike_blocks":false},
		"geometry_intent":{"source":"a split old tree: a low forward observation root, a high rear bough, and an overhead fruit branch grown from the far root","contour_grid_wu":2.0,"visible_solid":"actual_union_only","false_live_host":false,"visual_acceptance":"unverified"},
	}
	# All walking faces are broad. The underside depths make asymmetric wood
	# rather than a stack of short walkable rectangles.
	SHAPE._bough(m,"entry",[-336.0,18.0,560.0,32.0],"root_earth",[144.0,112.0,96.0,48.0])
	SHAPE._bough(m,"crown",[-384.0,cache_y,464.0,32.0],"living_bough",[72.0,112.0,80.0,40.0])
	SHAPE._bough(m,"outer_bough",[336.0,0.0,320.0,32.0],"living_bough",[48.0,96.0,128.0,80.0])
	SHAPE._bough(m,"recovery",[-512.0,224.0,1328.0,32.0],"root_earth",[96.0,144.0,80.0,112.0])
	SHAPE._bough(m,"western_retry",[-464.0,112.0,128.0,24.0],"root_earth",[40.0,64.0,48.0,32.0])
	# A real open-sided root bay runs down to the catch floor. The old
	# closed lower west bands trapped the first recovery jump beneath the
	# thick departure branch; clearing only the receiver was insufficient.
	SHAPE._ribbon(m,"western_tree",[
		[cache_y+32.0,-416.0,-352.0],
		[-80.0,-432.0,-336.0],
		[144.0,-416.0,-320.0],
		[256.0,-400.0,-304.0]],"hollow_bark",[-80.0,224.0])
	# A forward overhanging bough owns the fruit. The clear space under it is
	# the real capture ray and the useful diagonal recoil corridor.
	SHAPE._body(m,"fruit_host",[176.0,roof_y,224.0,32.0],"living_bough")
	SHAPE._bough(m,"fruit_host_shoulder",[400.0,roof_y,160.0,32.0],"living_bough",[48.0,80.0,96.0,64.0])
	SHAPE._ribbon(m,"far_bough_root",[
		[roof_y+32.0,480.0,560.0],
		[-112.0,544.0,640.0],
		[32.0,560.0,656.0],
		[160.0,624.0,736.0],
		[256.0,656.0,784.0]],"hollow_bark",[128.0,224.0])
	# The low root owns floor contacts. Final trunk bands on either side
	# are redundant only when their entire snapped rectangle is
	# enclosed by the existing solid recovery face. Removing that exact
	# overlap retains the physical union and every uncovered trunk band.
	var recovery_rect := [-512.0,224.0,1328.0,32.0]
	for index: int in range(m.platforms.size()-1,-1,-1):
		var row: Dictionary = m.platforms[index]
		var id := str(row.id)
		if (id.begins_with("western_tree__") or id.begins_with("far_bough_root__")) and SHAPE._fully_covered(row.rect,recovery_rect):
			m.scene_language.erase(id)
			m.platforms.remove_at(index)
	SHAPE._fruit(m,"forward_reversal_fruit",[fruit_x,fruit_y],"fruit_host",[fruit_x,roof_y+32.0],"optional")
	# Actual roof thorns stay away from the fruit's approach and the normal
	# jump envelope; there is no invisible spike between the two route choices.
	SHAPE._hazard(m,"fruit_host","down",[304.0,roof_y+32.0,96.0,20.0])
	m.action_program = [{"action":"H","anchor":"forward_reversal_fruit"},{"action":"R","direction":[0.8,0.6]}]
	m.ports = {
		"entry":SHAPE._port(m.spawn,"entry","forward_observation"),
		"west_entry":SHAPE._port([-424.0,94.0],"western_retry","actual_western_window_arrival"),
		"crown":SHAPE._port(m.goal,"crown","rear_high_reward_branch"),
		"cache":SHAPE._port(m.goal,"crown","rear_high_reward_branch"),
		"reward":SHAPE._port(m.goal,"crown","rear_high_reward_branch"),
		"normal_onward":SHAPE._port([416.0,-18.0],"outer_bough","safe_forward_world_destination"),
		"outer":SHAPE._port([416.0,-18.0],"outer_bough","safe_forward_world_destination"),
		"return":SHAPE._port(m.spawn,"entry","backbranch_drop_to_observation"),
		"lower_return":SHAPE._port([576.0,206.0],"recovery","near_side_lower_observation"),
		"east_onward":SHAPE._port([784.0,206.0],"recovery","actual_east_root_window_exit"),
		"failure":SHAPE._port([0.0,206.0],"recovery","wide_root_recovery"),
	}
	m.routes.main = {"kind":"airborne_chain","from_port":"entry","to_port":"crown","action_program":m.action_program.duplicate(true),"path":[m.spawn.duplicate(),[fruit_x,fruit_y],m.goal.duplicate()],"native_verified":false}
	m.routes.reward = m.routes.main.duplicate(true)
	var outer_steps := [
		SHAPE._walk("entry",[200.0,0.0]),
		SHAPE._jump("entry","outer_bough",[200.0,0.0],[368.0,-18.0]),
		SHAPE._walk("outer_bough",[416.0,-18.0])]
	m.routes.outer = SHAPE._route("entry","normal_onward",outer_steps)
	# Return has its own actual mouth on the right of the rear bough. It
	# reaches the observed root rather than replaying an inverse H/R chain.
	m.routes.returning = SHAPE._route("crown","return",[
		SHAPE._walk("crown",[48.0,cache_y-18.0]),
		SHAPE._drop("crown","entry",[48.0,cache_y-18.0],m.spawn,[[112.0,cache_y-18.0]])])
	m.routes.outer_descent = SHAPE._route("normal_onward","lower_return",[
		SHAPE._walk("outer_bough",[360.0,-18.0]),
		SHAPE._drop("outer_bough","recovery",[360.0,-18.0],[304.0,206.0],[[304.0,-18.0],[304.0,206.0]]),
		SHAPE._walk("recovery",[576.0,206.0])])
	# A shared rectangular support does not make the body route through
	# its crossing trunk free. The real96wu side opening above that floor
	# is the only authored passage from the near side to the east world lip.
	m.routes.east_onward = SHAPE._route("lower_return","east_onward",[
		SHAPE._walk("recovery",[784.0,206.0])])
	# Recover around the real outside of the western outcrop. Jumping from
	# under the entry's thick wood struck its underside before clearing the
	# old closed root. This path uses the now-open bay and the existing lip.
	var retry_steps := [
		SHAPE._walk("recovery",[-488.0,206.0]),
		SHAPE._jump("recovery","western_retry",[-488.0,206.0],[-424.0,94.0]),
		SHAPE._walk("western_retry",[-360.0,94.0]),
		SHAPE._jump("western_retry","entry",[-360.0,94.0],[-312.0,0.0]),
		SHAPE._walk("entry",m.spawn)]
	# The world approaches the actual western window on its existing wide
	# root lip. It does not jump into the cache's side from an invented shore.
	m.routes.west_to_entry = SHAPE._route("west_entry","entry",[
		SHAPE._walk("western_retry",[-360.0,94.0]),
		SHAPE._jump("western_retry","entry",[-360.0,94.0],[-312.0,0.0]),
		SHAPE._walk("entry",m.spawn)])
	m.routes.retry = SHAPE._route("failure","entry",retry_steps)
	m.routes.lower_retry = SHAPE._route("lower_return","entry",retry_steps)
	m.reward_position = m.goal.duplicate()
	m.reward_support_id = "crown"
	m.branch_reward_contract = {"world_reward_required":true,"no_exit_coin_override":true,"reward_route":"reward","return_route":"returning","ordinary_outer_route_skips_cache":true,"native_verified":false}
	m.play_contract = {
		"observe":"The ordinary onward bough is ahead; the higher cache remains visible behind the departure. The forward fruit belongs to the real overhanging branch.",
		"decision":"Jump outward for the lower world route, or catch the forward fruit and use the reversed kick plus one diagonal shot to return to the high branch behind.",
		"alternative":"Strong recoil or other legal H strategies remain allowed. The action program is one candidate, never an input password.",
		"recovery":"Every miss reaches the broad low root. Walk through the open root bay to the outside of the western outcrop, then use the112wu and94wu normal rises; no resource refill is supplied.",
		"counterexample":"Compare noH and full-held ordinary jumps, and verify fixed-fruit contact does not replenish shots. Reaching the branch is not actual OR reward settlement."}
	m.recovery = {"support":"recovery","safe_port":"failure","retry_route":"retry","world_must_connect_lower_port":true,"native_verified":false}
	m.return = {"route":"returning","different_exit_port":"return","native_verified":false}
	m.world_bounds = SHAPE._bounds(m)
	m.width = m.world_bounds[2]
	m.height = m.world_bounds[3]
	return m
