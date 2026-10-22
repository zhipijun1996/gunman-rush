class_name ForestExplorationPlaces
extends RefCounted
## Joint space/terrain candidates. All visible mass is real collision union;
## no local actor, resource or movement authority is provided by this factory.
const VERSION := "forest-exploration-places-v18.5"
const Z_VERSION := "forest-z-descending-return-v18.8"
const BIBLE_SHA := "a7bad8323af64a7be0577132e5d988a6e1b781d9e1ac1639d37f9d65935194e3"
const SOURCE := "res://scripts/generation/forest_exploration_places.gd"

static func catalogue() -> Array[Dictionary]:
	return [
		{"id":"seven_bough_reveal","identity":"cross the crown, look behind a hanging root, enter the inward-facing cache, and leave through a different lower mouth","difficulty":"normal_with_optional_reward","implementation":"candidate_not_admitted"},
		{"id":"z_descending_return","identity":"an open right pocket offers an outer drop or a leftward inward crossing, thorn-cache excursion and a second rightward lower crossing","difficulty":"normal_with_harder_inner_cache","implementation":"candidate_not_admitted"},
		{"id":"l_backside_nook","identity":"an outward elbow conceals a side-facing root nook and an inward return","difficulty":"normal_optional","implementation":"proposed_only"},
		{"id":"fallen_trunk_two_faces","identity":"the fallen trunk's open crown and sheltered inside lead to different encounters and a shared root junction","difficulty":"normal_and_hard_alternatives","implementation":"proposed_only"},
	]

static func build(id: String, variant: int = 0) -> Dictionary:
	# Each realized place is still a candidate. Catalogue cards alone are
	# not a world-installable module or evidence of another fun mechanic.
	if variant not in [0, 1]: return {}
	match id:
		"seven_bough_reveal": return _seven_bough_reveal(variant)
		"z_descending_return": return _z_descending_return(variant)
		_: return {}

static func _seven_bough_reveal(variant: int) -> Dictionary:
	var deep := variant == 1
	var transfer_y := 32.0 if deep else -48.0
	var transfer_width := 224.0 if deep else 320.0
	var crown_x := 448.0 if deep else 544.0
	var crown_y := -16.0
	var cover_x := crown_x - 160.0
	var cover_y := 192.0
	var cover_width := 448.0
	var back_x := cover_x + cover_width + 32.0
	var back_y := 304.0 if deep else 240.0
	var cache_y := 512.0 if deep else 448.0
	# The complete cache-root profile reaches cache_y+128. A recovery jump
	# below it needs full ascent/body clearance, not just standing clearance.
	# The previous 48wu gap caused a real ceiling strike and failed return.
	var lower_y := cache_y + 352.0
	var right_foot_x := cover_x+256.0
	var left_foot_end := right_foot_x-128.0
	var near_point := [cover_x+288.0,lower_y-18.0]
	var window_lip_rect := [-224.0,lower_y-48.0,176.0,32.0]
	var m := {
		"id":"seven_bough_reveal", "version":VERSION, "variant":variant,
		"bible_sha256":BIBLE_SHA, "requires":["grapple"],
		"spawn":[-240.0,-18.0], "goal":[crown_x+128.0,crown_y-18.0],
		"entry_support_id":"entry", "exit_support_id":"crown",
		"platforms":[], "hook_anchors":[], "dangers":[],
		"danger_surfaces":[], "danger_presentations":[], "scene_language":{},
		"routes":{}, "ports":{}, "action_program":[], "windows":[],
		"geometry_intent":{
			"source":"a broken crown forks around a real hanging root and an inward-facing hollow",
			"upper_outline":"two separated thick boughs; no repeated platform column",
			"inner_void":"the cache has a real roof; a fall from the first branch lands on outer bark instead of in the reward",
			"lower_outline":"rooted feet have a real gap; near/far east-foot ports are separated by the physical descending root",
			"profile":"a curved crown rib and asymmetric hollow back wall connect the roof and cache; the western root has a real return window above one broad sill",
			"contour_grid_wu":2.0,"maximum_endpoint_snap_wu":1.0,
			"visual_acceptance":"unverified; shared renderer is a consumer, not an art verdict"},
		"source_factory":{"path":SOURCE,"version":VERSION,"sha256":FileAccess.get_sha256(SOURCE)},
		"admission":{"geometry":"candidate","motor":"unverified","visual":"unverified","production_pool":false},
		"resource_contract":{"new_abilities":false,"physics_override":false,"health_override":false,"shot_refill_override":false},
		"chain_contract":{"continuous_airborne":false,"midair_floor_allowed":true,"native_verified":false,"production_pool":false},
		"tile_contract":{"family":"shared_underworld_with_forest_bible_material","source_tile_px":16,"world_tile_wu":32,"solid":"exact_union","one_way":"separate_bough_family","moving":false,"port_halo_wu":32,"standalone_spike_blocks":false},
	}
	# One authored side-open hollow: crown, curved arch, back wall, floor
	# and descending root are physically connected. No symmetric skirts.
	_bough(m,"entry",[-320.0,0.0,320.0,32.0],"root_earth",[72.0,112.0,96.0,48.0])
	_bough(m,"crossing_bough",[112.0,transfer_y,transfer_width,32.0],"living_bough",[40.0,80.0,128.0,112.0])
	_bough(m,"crown",[crown_x,crown_y,256.0,32.0],"living_bough",[112.0,128.0,80.0,40.0])
	# Two curved ribs grow into the SAME tree. They stay below the real
	# jump surfaces, never substituting a staircase for the upper gaps.
	_ribbon(m,"inner_bough_joint",[
		[transfer_y+32.0,transfer_end_for_shape(transfer_width)-96.0,transfer_end_for_shape(transfer_width)-16.0],
		[128.0,cover_x-64.0,cover_x+32.0],
		[240.0,cover_x-80.0,cover_x+32.0]],"hollow_bark")
	_ribbon(m,"crown_arch_joint",[
		[crown_y+32.0,crown_x+64.0,crown_x+176.0],
		[80.0,crown_x+16.0,crown_x+144.0],
		[160.0,cover_x+128.0,cover_x+288.0],
		[208.0,cover_x+64.0,cover_x+256.0]],"hollow_bark")
	_arch(m,"inward_hollow_roof",[
		[cover_x,208.0,304.0],
		[cover_x+64.0,176.0,264.0],
		[cover_x+160.0,144.0,224.0],
		[cover_x+256.0,152.0,232.0],
		[cover_x+352.0,184.0,256.0],
		[cover_x+448.0,208.0,256.0]],"hollow_bark")
	_ribbon(m,"hollow_back_wall",[
		[208.0,cover_x-96.0,cover_x+32.0],
		[304.0,cover_x-144.0,cover_x+16.0],
		[cache_y-64.0,cover_x-128.0,cover_x+16.0],
		[cache_y+48.0,cover_x-64.0,cover_x+64.0]],"hollow_bark")
	# The cache is a concave shelf in that trunk, attached to its back wall;
	# the open right face is the real entry, not a painted window.
	_bough(m,"cache_root",[cover_x,cache_y,cover_width,32.0],"root_earth",[128.0,112.0,80.0,40.0])
	_ribbon(m,"descending_outer_root",[
		[cache_y+32.0,cover_x+320.0,cover_x+416.0],
		[cache_y+144.0,cover_x+336.0,cover_x+432.0],
		[lower_y-80.0,cover_x+320.0,cover_x+400.0],
		[lower_y+32.0,cover_x+304.0,cover_x+416.0]],"root_earth")
	# The west departure is also a rooted form, with its foot west of the
	# lower walking lane. Its outer walk-off remains truly open at x48.
	_ribbon(m,"western_root",[
		[32.0,-304.0,-208.0],
		[192.0,-336.0,-240.0],
		[lower_y*0.55,-272.0,-176.0],
		[lower_y-96.0,-192.0,-96.0],
		[lower_y+32.0,-128.0,-48.0]],"root_earth",[lower_y-144.0,lower_y-48.0],window_lip_rect)
	# A real side window in the western root. This single broad lip is its
	# actual sill; the clear opening is 96wu tall, not a decorative mark.
	_body(m,"western_window_lip",window_lip_rect,"root_earth")
	_bough(m,"lower_return_root",[-128.0,lower_y,left_foot_end+128.0,32.0],"root_earth",[96.0,128.0,96.0,48.0])
	_bough(m,"outer_failure_root",[right_foot_x,lower_y,448.0,32.0],"root_earth",[48.0,80.0,128.0,96.0])
	_body(m,"back_bay",[back_x,back_y,192.0,32.0],"living_bough",true)
	# Fruit roots are authored on their actual solid hosts. These are optional
	# assistance/correction targets, not a mandatory input password.
	_fruit(m,"first_bough_fruit",[112.0,transfer_y-80.0],"crossing_bough",[112.0,transfer_y],"main")
	_fruit(m,"crown_fruit",[crown_x,crown_y-80.0],"crown",[crown_x,crown_y],"main")
	_fruit(m,"inward_fruit",[cover_x+cover_width,cover_y+128.0],"inward_hollow_roof",[cover_x+cover_width,cover_y+64.0],"optional")
	# A short rooted patch makes cache entry a voluntary crossing. Safe
	# approaches and a full-height jump remain visible on both sides.
	var thorn_x := cover_x+192.0
	_hazard(m,"cache_root","up",[thorn_x,cache_y-24.0,48.0,24.0])
	var cache_point := [cover_x+64.0,cache_y-18.0]
	var lower_point := [back_x+96.0,lower_y-18.0]
	var failure_point := [32.0,lower_y-18.0]
	m.reward_position = cache_point.duplicate()
	m.reward_support_id = "cache_root"
	m.ports = {
		"entry":_port(m.spawn,"entry","observed_departure"),
		"crown":_port(m.goal,"crown","upper_onward"),
		"onward":_port(m.goal,"crown","upper_onward"),
		"cache":_port(cache_point,"cache_root","inward_reward"),
		"reward":_port(cache_point,"cache_root","inward_reward"),
		"lower_return":_port(near_point,"outer_failure_root","near_side_lower_world_destination"),
		"return":_port(lower_point,"outer_failure_root","far_side_lower_world_destination"),
		"back_return":_port(lower_point,"outer_failure_root","far_side_lower_world_destination"),
		"failure":_port(failure_point,"lower_return_root","west_root_recovery"),
		"west_return":_port([-200.0,lower_y-66.0],"western_window_lip","actual_window_to_earlier_world_root"),
	}
	var transfer_end := 112.0+transfer_width
	var main_steps := [
		_walk("entry",[-24.0,-18.0]),
		_jump("entry","crossing_bough",[-24.0,-18.0],[144.0,transfer_y-18.0]),
		_walk("crossing_bough",[transfer_end-32.0,transfer_y-18.0]),
		_jump("crossing_bough","crown",[transfer_end-32.0,transfer_y-18.0],[crown_x+32.0,crown_y-18.0]),
		_walk("crown",m.goal),
	]
	var back_landing := [back_x+48.0,back_y-18.0]
	var inner_landing := [cover_x+cover_width-32.0,cache_y-18.0]
	var reward_steps: Array = main_steps.duplicate(true)
	reward_steps.append_array([
		_walk("crown",[crown_x+224.0,crown_y-18.0]),
		_drop("crown","back_bay",[crown_x+224.0,crown_y-18.0],back_landing,[[back_x+32.0,crown_y-18.0]]),
		_walk("back_bay",[back_x+32.0,back_y-18.0]),
		# Leave the left edge and slide past the real root nose. The driver
		# must wait for actual fall/clearance, never place the body inside it.
		_drop("back_bay","cache_root",[back_x+32.0,back_y-18.0],inner_landing,[[cover_x+cover_width-16.0,back_y-18.0]]),
		_walk("cache_root",[thorn_x+80.0,cache_y-18.0]),
		_jump("cache_root","cache_root",[thorn_x+80.0,cache_y-18.0],[thorn_x-64.0,cache_y-18.0]),
		_walk("cache_root",cache_point),
	])
	# A real descending root divides the lower east foot into two sides.
	# Both sides get explicit world ports; no route walks through that root.
	var returning_steps := [
		_walk("cache_root",[thorn_x-64.0,cache_y-18.0]),
		_jump("cache_root","cache_root",[thorn_x-64.0,cache_y-18.0],[thorn_x+80.0,cache_y-18.0]),
		_walk("cache_root",[cover_x+cover_width-32.0,cache_y-18.0]),
		_drop("cache_root","outer_failure_root",[cover_x+cover_width-32.0,cache_y-18.0],lower_point,[[cover_x+cover_width+48.0,cache_y-18.0]]),
	]
	var near_steps := [
		_walk("lower_return_root",[left_foot_end-24.0,lower_y-18.0]),
		_jump("lower_return_root","outer_failure_root",[left_foot_end-24.0,lower_y-18.0],[right_foot_x+24.0,lower_y-18.0]),
		_walk("outer_failure_root",near_point),
	]
	var west_steps := [
		_walk("lower_return_root",[16.0,lower_y-18.0]),
		_jump("lower_return_root","western_window_lip",[16.0,lower_y-18.0],[-80.0,lower_y-66.0]),
		_walk("western_window_lip",[-200.0,lower_y-66.0]),
	]
	var near_west_steps := [
		_walk("outer_failure_root",[right_foot_x+24.0,lower_y-18.0]),
		_jump("outer_failure_root","lower_return_root",[right_foot_x+24.0,lower_y-18.0],[left_foot_end-24.0,lower_y-18.0]),
	]
	near_west_steps.append_array(west_steps)
	var entry_descent := [
		_walk("entry",[-24.0,-18.0]),
		_drop("entry","lower_return_root",[-24.0,-18.0],failure_point,[[48.0,-18.0]]),
	]
	var lower_steps: Array = entry_descent.duplicate(true)
	lower_steps.append_array(near_steps)
	var outer_west_steps: Array = entry_descent.duplicate(true)
	outer_west_steps.append_array(west_steps)
	m.routes.main = _route("entry","crown",main_steps)
	m.routes.outer = _route("entry","lower_return",lower_steps)
	m.routes.reward = _route("entry","cache",reward_steps)
	m.routes.returning = _route("cache","return",returning_steps)
	var full_reward: Array = reward_steps.duplicate(true)
	full_reward.append_array(returning_steps)
	m.routes.reward_return = _route("entry","return",full_reward)
	m.routes.failure_to_return = _route("failure","lower_return",near_steps)
	m.routes.failure_west_return = _route("failure","west_return",west_steps)
	m.routes.near_west_return = _route("lower_return","west_return",near_west_steps)
	m.routes.outer_west_return = _route("entry","west_return",outer_west_steps)
	# The ordinary onward descent stays on the outside of the real hollow.
	# It uses the actual one-way drop action on the outer bough, never falls
	# through the solid cache floor or the descending root.
	m.routes.main_to_far = _route("crown","return",[
		_walk("crown",[crown_x+224.0,crown_y-18.0]),
		_drop("crown","back_bay",[crown_x+224.0,crown_y-18.0],back_landing,[[back_x+32.0,crown_y-18.0]]),
		_walk("back_bay",[back_x+96.0,back_y-18.0]),
		_drop("back_bay","outer_failure_root",[back_x+96.0,back_y-18.0],lower_point,[]),
	])
	m.windows = [
		{"id":"inward_reward_hollow","clear_rect":[cover_x+48.0,304.0,cover_width-48.0,cache_y-304.0-24.0]},
		{"id":"western_root_return_window","clear_rect":[-256.0,lower_y-144.0,240.0,96.0]},
	]
	m.play_contract = {
		"observe":"The crown's outer root hides the cache from an entry-side fall. Crossing above reveals the outside descent and an inward-facing opening.",
		"decision":"Continue from the crown, descend around its back for the cache, or leave early through the lower root into a different world branch.",
		"new_information":"After the outer fall, the hollow faces back toward the tree just crossed; its lower mouth later reveals the departure from below.",
		"reward":"Optional thorn crossing into an inward cache; reward and onward are different ports. The world owns the real OR transaction.",
		"alternative":"Landing on the outer bark roof and finding its far edge early is a legitimate discovery; do not enforce a crown-visited counter.",
		"counterexample":"Try an immediate entry walk-off toward the cache, a first-bough fall, zero-H ordinary jumps, missed second jump, and the right-root recovery.",
		"world_requirement":"Crown descends by main_to_far to return/back_return on the east side of the descending root and onward toward Boss. Failure and lower_return escape through the real western window to west_return, which the world must connect to an earlier root. Same support does not make the two sides mutually walkable.",
	}
	m.recovery = {"mode":"different_lower_world_ports","safe_ports":["lower_return","return","failure","west_return"],"routes":["outer","failure_to_return","failure_west_return","near_west_return","outer_west_return"],"native_verified":false,"return_to_high_entry_not_claimed":true}
	m.risk_reward = {"tier":"normal_optional","coins":4,"notes":1,"selection":"OR","world_reward_required":true,"return_required":true}
	m.variant_contract = {
		"role":"same_place_structural_variant_not_a_new_mechanic",
		"change":"first branch descends before the crown climb; inward hollow and outer bay are deeper" if deep else "first branch rises before the lower crown; shallow outer descent reveals the inward hollow",
		"actual_fields":["platforms","ports","routes","reward_position","world_bounds"],
		"not_diversity_proof":true,
	}
	m.danger_hosts = ["cache_root"]
	m.danger_faces = ["up"]
	m.ecology_slots = [{"id":"outer_observation","support_id":"crown","position":m.goal.duplicate(),"role":"optional_world_encounter_only; never silently spawn an enemy on the only receiver"}]
	m.world_bounds = _bounds(m)
	m.width = m.world_bounds[2]
	m.height = m.world_bounds[3]
	return m

static func _z_descending_return(variant: int) -> Dictionary:
	# This is a second movement/choice family, not a longer seven-shaped
	# reward room. Read right, turn left into a hollow, then turn right out.
	var deep := variant==1
	var upper_y := -32.0 if deep else 32.0
	# The shallower pocket sat only 96wu below the underside of the upper
	# bough. Its inward jump accidentally depended on a ceiling bump and
	# early release. Move this entire lower phrase down, preserving its
	# internal gaps, so a full held jump/body fits beneath the real bough.
	var pocket_y := 464.0 if deep else 400.0
	var inner_y := pocket_y+192.0
	var exit_y := inner_y+160.0
	var failure_y := exit_y+224.0
	var exit_surface := [544.0,exit_y,416.0,32.0]
	var onward_point := [896.0,exit_y-18.0]
	var m := {
		"id":"z_descending_return","version":Z_VERSION,"variant":variant,
		"bible_sha256":BIBLE_SHA,"requires":["grapple"],
		"spawn":[-240.0,-18.0],"goal":[672.0,exit_y-18.0],
		"entry_support_id":"entry","exit_support_id":"crown",
		"platforms":[],"hook_anchors":[],"dangers":[],"danger_surfaces":[],
		"danger_presentations":[],"scene_language":{},"routes":{},"ports":{},
		"action_program":[],"windows":[],
		"source_factory":{"path":SOURCE,"version":Z_VERSION,"sha256":FileAccess.get_sha256(SOURCE)},
		"admission":{"geometry":"candidate","motor":"unverified","visual":"unverified","production_pool":false},
		"resource_contract":{"new_abilities":false,"physics_override":false,"health_override":false,"shot_refill_override":false},
		"chain_contract":{"continuous_airborne":false,"midair_floor_allowed":true,"native_verified":false,"production_pool":false},
		"tile_contract":{"family":"shared_underworld_with_forest_bible_material","source_tile_px":16,"world_tile_wu":32,"solid":"exact_union","one_way":"separate_bough_family","moving":false,"port_halo_wu":32,"standalone_spike_blocks":false},
		"geometry_intent":{
			"source":"a hollow western root bends under an outward bough, facing a thin living pocket on an eastern root",
			"outline":"two rooted asymmetric bodies with an open middle, not three parallel shelves or a rectangular thorn frame",
			"choice":"the pocket allows a real outer drop; the inner direction reverses left across a gap, then right over a lower gap",
			"pocket_floor_below_upper_bough_envelope_wu":pocket_y-(upper_y+128.0),
			"headroom_status":"authored_for_full_held_jump_and_36wu_body; actual_swept_Motor_revalidation_required",
			"cache":"the left hollow contains a voluntary floor-thorn crossing under a separately rooted thorn ceiling",
			"failure":"a lower root catches the final gap; its outward low port must reconnect to the world",
			"contour_grid_wu":2.0,"maximum_endpoint_snap_wu":1.0,
			"visual_acceptance":"unverified; the actual shared-renderer composition must be reviewed"},
	}
	# Standing faces stay uninterrupted. The curved mass and hollow below
	# them come from this same source, using the already pixel-aligned helper.
	_bough(m,"entry",[-320.0,0.0,320.0,32.0],"root_earth",[64.0,112.0,96.0,48.0])
	_bough(m,"outward_bough",[112.0,upper_y,320.0,32.0],"living_bough",[48.0,80.0,128.0,112.0])
	_arch(m,"z_root_cover",[
		[-192.0,96.0,192.0],[-96.0,80.0,176.0],
		[32.0,112.0,192.0],[144.0,144.0,224.0],[256.0,208.0,256.0]],"hollow_bark")
	_ribbon(m,"western_hollow_back",[
		[32.0,-304.0,-192.0],[160.0,-352.0,-224.0],
		[inner_y-80.0,-288.0,-176.0],[inner_y+32.0,-224.0,-112.0]],"hollow_bark")
	_ribbon(m,"outward_bough_joint",[
		[upper_y+32.0,144.0,240.0],[112.0,112.0,224.0],[224.0,96.0,208.0]],"hollow_bark")
	_bough(m,"inner_root",[-192.0,inner_y,448.0,32.0],"root_earth",[112.0,128.0,80.0,40.0])
	_ribbon(m,"western_fold_root",[
		[inner_y+32.0,-112.0,-16.0],[inner_y+80.0,-64.0,32.0],
		[exit_y-48.0,48.0,144.0],[exit_y+32.0,112.0,224.0]],"root_earth")
	_bough(m,"lower_fold",[112.0,exit_y,320.0,32.0],"root_earth",[112.0,128.0,80.0,48.0])
	# The observation pocket is intentionally one-way. Its right end grows
	# into the eastern root; the open underside is a real drop choice.
	_body(m,"pocket_branch",[384.0,pocket_y,384.0,24.0],"living_bough",true)
	_ribbon(m,"eastern_living_root",[
		[pocket_y,704.0,800.0],[pocket_y+128.0,736.0,832.0],
		[exit_y+32.0,704.0,800.0],[failure_y+32.0,672.0,768.0]],"root_earth",[exit_y-96.0,exit_y],exit_surface)
	# The receiving root's two sides are distinct until this actual side
	# window is crossed. Keep the floor and lower root; omit only the root
	# bands proven completely covered by that same named standing surface.
	_bough(m,"crown",exit_surface,"root_earth",[48.0,96.0,128.0,80.0])
	_bough(m,"failure_root",[384.0,failure_y,320.0,32.0],"root_earth",[64.0,112.0,96.0,48.0])
	# This small overhanging root belongs to the actual hollow cover. Its
	# exposed underside carries the ceiling thorns, independently of the
	# floor patch. Ordinary full-height movement retains a broad clear band.
	_body(m,"z_ceiling_thorn_host",[32.0,176.0,64.0,32.0],"hollow_bark")
	_hazard(m,"z_ceiling_thorn_host","down",[32.0,208.0,64.0,16.0])
	_hazard(m,"inner_root","up",[80.0,inner_y-24.0,48.0,24.0])
	_fruit(m,"z_entry_fruit",[112.0,upper_y-80.0],"outward_bough",[112.0,upper_y],"main")
	_fruit(m,"z_inward_fruit",[192.0,inner_y-96.0],"inner_root",[192.0,inner_y],"optional")
	_fruit(m,"z_exit_fruit",[544.0,exit_y-96.0],"crown",[544.0,exit_y],"optional")
	var pocket := [512.0,pocket_y-18.0]
	var inner := [224.0,inner_y-18.0]
	var cache := [0.0,inner_y-18.0]
	var low := [320.0,exit_y-18.0]
	var failure := [496.0,failure_y-18.0]
	var failure_out := [416.0,failure_y-18.0]
	m.reward_position = cache.duplicate()
	m.reward_support_id = "inner_root"
	m.ports = {
		"entry":_port(m.spawn,"entry","upper_departure"),
		"pocket":_port(pocket,"pocket_branch","safe_observation_and_drop_choice"),
		"inner":_port(inner,"inner_root","inward_fold_receiving_root"),
		"cache":_port(cache,"inner_root","optional_high_risk_cache"),
		"reward":_port(cache,"inner_root","optional_high_risk_cache"),
		"low_root":_port(low,"lower_fold","lower_second_turn"),
		"crown":_port(m.goal,"crown","west_side_receiver_before_root_window"),
		"onward":_port(onward_point,"crown","east_world_onward_after_real_root_window"),
		"exit":_port(onward_point,"crown","east_world_onward_after_real_root_window"),
		"return":_port(m.goal,"crown","reward_rejoins_receiver_before_root_window"),
		"failure":_port(failure,"failure_root","caught_final_gap"),
		"failure_out":_port(failure_out,"failure_root","lower_world_recovery_required"),
	}
	var approach := [
		_walk("entry",[-24.0,-18.0]),
		_jump("entry","outward_bough",[-24.0,-18.0],[144.0,upper_y-18.0]),
		_walk("outward_bough",[400.0,upper_y-18.0]),
		_drop("outward_bough","pocket_branch",[400.0,upper_y-18.0],pocket,[[480.0,upper_y-18.0]]),
	]
	var inward := [
		_walk("pocket_branch",[416.0,pocket_y-18.0]),
		_jump("pocket_branch","inner_root",[416.0,pocket_y-18.0],inner),
	]
	var cache_outbound := [
		_walk("inner_root",[160.0,inner_y-18.0]),
		_jump("inner_root","inner_root",[160.0,inner_y-18.0],[16.0,inner_y-18.0]),
		_walk("inner_root",cache),
	]
	var cache_return := [
		_walk("inner_root",[16.0,inner_y-18.0]),
		_jump("inner_root","inner_root",[16.0,inner_y-18.0],[160.0,inner_y-18.0]),
		_walk("inner_root",inner),
	]
	var lower_onward := [
		_drop("inner_root","lower_fold",inner,low,[[288.0,inner_y-18.0]]),
		_walk("lower_fold",[400.0,exit_y-18.0]),
		_jump("lower_fold","crown",[400.0,exit_y-18.0],[576.0,exit_y-18.0]),
		_walk("crown",m.goal),
	]
	var main_steps: Array = approach.duplicate(true)
	main_steps.append_array(inward)
	main_steps.append_array(lower_onward)
	var outer_steps: Array = approach.duplicate(true)
	outer_steps.append_array([
		_drop("pocket_branch","crown",pocket,[608.0,exit_y-18.0],[]),
		_walk("crown",m.goal),
	])
	var reward_steps: Array = approach.duplicate(true)
	reward_steps.append_array(inward)
	reward_steps.append_array(cache_outbound)
	var returning: Array = cache_return.duplicate(true)
	returning.append_array(lower_onward)
	var reward_full: Array = reward_steps.duplicate(true)
	reward_full.append_array(returning)
	m.routes.approach = _route("entry","pocket",approach)
	m.routes.main = _route("entry","crown",main_steps)
	m.routes.outer = _route("entry","crown",outer_steps)
	m.routes.reward = _route("entry","cache",reward_steps)
	m.routes.returning = _route("cache","crown",returning)
	m.routes.reward_return = _route("entry","crown",reward_full)
	m.routes.inner_onward = _route("inner","crown",lower_onward)
	m.routes.low_onward = _route("low_root","crown",lower_onward.slice(1))
	m.routes.failure_outbound = _route("failure","failure_out",[_walk("failure_root",failure_out)])
	m.routes.crown_onward = _route("crown","onward",[_walk("crown",onward_point)])
	m.windows = [
		{"id":"inner_hollow","clear_rect":[-128.0,256.0,384.0,inner_y-256.0-24.0]},
		{"id":"eastern_root_onward_window","clear_rect":[688.0,exit_y-96.0,144.0,96.0]},
	]
	m.play_contract = {
		"observe":"The thin eastern branch is a safe read point: the outer descent, inward fruit, left hollow and next lower root can be compared.",
		"decision":"Drop directly through the pocket for easier onward travel, or reverse left into the hollow and then right across the lower gap.",
		"new_behavior":"The second direction reversal follows real stable reception; the Z is a route through open root bodies, not a command sequence password.",
		"reward":"The left cache requires an additional outward-and-back thorn crossing. The world must execute a real richer OR reward; the factory awards nothing.",
		"alternative":"Ordinary held jumps remain legal; the actual rooted fruits also remain available to normal player input. This candidate declares no unconsumed hook choreography.",
		"failure":"The final gap has a visible lower root and an explicit lower world escape. Recovery is incomplete until that actual port joins the world.",
		"counterexample":"Try an immediate entry fall, a first-branch fall, direct pocket drop, no-H inward jump and a missed final jump; an early outer-bark approach is legal and must not receive a free cache.",
		"world_requirement":"Connect entry to its actual neighbour; after every local arrival at crown, execute crown_onward through the real eastern root window before the world continuation from onward. Connect failure_out to a real lower loop or separately verified recovery. Neither a full platform rectangle nor a local catch proves those world connections.",
	}
	m.recovery = {"mode":"lower_root_and_world_port","safe_ports":["low_root","failure","failure_out"],"routes":["low_onward","failure_outbound"],"native_verified":false,"world_connection_required":true}
	m.risk_reward = {"tier":"hard_optional","coins":6,"notes":2,"selection":"OR","world_reward_required":true,"return_required":true}
	m.variant_contract = {"role":"same_Z_place_structural_difficulty_variant_not_a_new_mechanic","change":"higher first bough and deeper open pocket/inner fold" if deep else "lower first bough and shallower inner fold","actual_fields":["platforms","ports","routes","reward_position","world_bounds"],"not_diversity_proof":true}
	m.danger_hosts = ["z_ceiling_thorn_host","inner_root"]
	m.danger_faces = ["down","up"]
	m.ecology_slots = []
	m.world_bounds = _bounds(m)
	m.width = m.world_bounds[2]
	m.height = m.world_bounds[3]
	return m

static func _body(m: Dictionary,id: String,rect: Array,kind: String,one_way := false) -> void:
	# This NEW contour is authored on the shared 2wu/source-pixel grid.
	# Snap both endpoints, then derive size: rounding a width separately
	# would separate adjoining source bands. Each endpoint moves <=1wu;
	# named standing faces and 16wu slice boundaries already lie on-grid.
	var start := Vector2(float(rect[0]),float(rect[1])).snapped(Vector2(2.0,2.0))
	var finish := Vector2(float(rect[0])+float(rect[2]),float(rect[1])+float(rect[3])).snapped(Vector2(2.0,2.0))
	var size := finish-start
	m.platforms.append({"id":id,"rect":[start.x,start.y,size.x,size.y],"one_way":one_way,"scene_kind":kind})
	m.scene_language[id] = kind

static func transfer_end_for_shape(width: float) -> float:
	return 112.0+width

static func _sample(knots: Array,at: float) -> Vector2:
	for index: int in range(1,knots.size()):
		var a: Array = knots[index-1]
		var b: Array = knots[index]
		if at<=float(b[0]):
			var blend := clampf((at-float(a[0]))/(float(b[0])-float(a[0])),0.0,1.0)
			return Vector2(lerpf(float(a[1]),float(b[1]),blend),lerpf(float(a[2]),float(b[2]),blend))
	var last: Array = knots[-1]
	return Vector2(float(last[1]),float(last[2]))

static func _ribbon(m: Dictionary,id: String,knots: Array,kind: String,opening: Array = [],covered_by: Array = []) -> void:
	var start := float(knots[0][0])
	var finish := float(knots[-1][0])
	var count := int(ceil((finish-start)/16.0))
	for index: int in count:
		var y := start+float(index)*16.0
		var height := minf(16.0,finish-y)
		if opening.is_empty():
			var edges := _sample(knots,y+height*0.5)
			_body(m,id+"__curve_%s"%index,[edges.x,y,edges.y-edges.x,height],kind)
			continue
		# Clip the actual collision bands at both window boundaries; do not
		# merely label an unchanged solid as a hole. Partial end bands retain
		# their exact source extent and receive their own stable suffix.
		var band_end := y+height
		var window_top := float(opening[0])
		var window_bottom := float(opening[1])
		var spans: Array = []
		if y<window_top: spans.append([y,minf(band_end,window_top)])
		if band_end>window_bottom: spans.append([maxf(y,window_bottom),band_end])
		for part: int in spans.size():
			var span: Array = spans[part]
			if float(span[1])<=float(span[0]): continue
			var edges := _sample(knots,(float(span[0])+float(span[1]))*0.5)
			var candidate := [edges.x,float(span[0]),edges.y-edges.x,float(span[1])-float(span[0])]
			# The actual window sill owns its surface. Remove a redundant root
			# band only after proving the whole snapped collision rectangle is
			# contained by that same solid sill. This changes support ownership,
			# not the physical union, and preserves every uncovered source band.
			if not covered_by.is_empty() and _fully_covered(candidate,covered_by): continue
			_body(m,id+"__curve_%s_%s"%[index,part],candidate,kind)

static func _fully_covered(rect: Array,cover: Array) -> bool:
	var start := Vector2(float(rect[0]),float(rect[1])).snapped(Vector2(2.0,2.0))
	var finish := Vector2(float(rect[0])+float(rect[2]),float(rect[1])+float(rect[3])).snapped(Vector2(2.0,2.0))
	var cover_start := Vector2(float(cover[0]),float(cover[1])).snapped(Vector2(2.0,2.0))
	var cover_end := Vector2(float(cover[0])+float(cover[2]),float(cover[1])+float(cover[3])).snapped(Vector2(2.0,2.0))
	return start.x>=cover_start.x and start.y>=cover_start.y and finish.x<=cover_end.x and finish.y<=cover_end.y

static func _arch(m: Dictionary,id: String,knots: Array,kind: String) -> void:
	var start := float(knots[0][0])
	var finish := float(knots[-1][0])
	var count := int(ceil((finish-start)/16.0))
	for index: int in count:
		var x := start+float(index)*16.0
		var width := minf(16.0,finish-x)
		var edges := _sample(knots,x+width*0.5)
		# Keep the real fruit's terminal host exact and named. The preceding
		# connected arch columns carry the rest of the curved roof.
		if index==count-1:
			_body(m,id,[x,208.0,width,48.0],kind)
		else:
			_body(m,id+"__arc_%s"%index,[x,edges.x,width,edges.y-edges.x],kind)

static func _bough(m: Dictionary,id: String,rect: Array,kind: String,depths: Array) -> void:
	_body(m,id,rect,kind)
	var x := float(rect[0])
	var y := float(rect[1])
	var width := float(rect[2])
	var count := int(ceil(width/16.0))
	var knots: Array = []
	for index: int in depths.size():
		knots.append([x+width*float(index)/float(depths.size()-1),y+float(rect[3]),y+float(depths[index])])
	for index: int in count:
		var at := x+float(index)*16.0
		var span := minf(16.0,x+width-at)
		var edges := _sample(knots,at+span*0.5)
		if edges.y>edges.x:
			_body(m,id+"__wood_%s"%index,[at,edges.x,span,edges.y-edges.x],kind)

static func _fruit(m: Dictionary,id: String,position: Array,host: String,stem: Array,role: String) -> void:
	m.hook_anchors.append({"id":id,"position":position.duplicate(),"host_support_id":host,"stem_root":stem.duplicate(),"fruit_presentation":"rooted_fruit","fruit_role":role})

static func _hazard(m: Dictionary,host: String,face: String,rect: Array) -> void:
	m.danger_surfaces.append({"danger_index":m.dangers.size(),"host_support_id":host,"face":face})
	m.danger_presentations.append({"facing":face,"host_support_id":host})
	m.dangers.append(rect.duplicate())

static func _port(position: Array,support: String,role: String) -> Dictionary:
	return {"position":position.duplicate(),"support_id":support,"role":role,"native_verified":false}

static func _walk(support: String,landing: Array) -> Dictionary:
	return {"kind":"walk","support_id":support,"landing":landing.duplicate()}

static func _jump(from: String,to: String,takeoff: Array,landing: Array) -> Dictionary:
	return {"kind":"jump_gap","from_support_id":from,"support_id":to,"takeoff":takeoff.duplicate(),"landing":landing.duplicate(),"hold_to_receiver":true}

static func _drop(from: String,to: String,takeoff: Array,landing: Array,mouths: Array) -> Dictionary:
	var path: Array = [takeoff.duplicate()]
	for point: Array in mouths: path.append(point.duplicate())
	path.append(landing.duplicate())
	return {"kind":"drop_through","from_support_id":from,"support_id":to,"takeoff":takeoff.duplicate(),"landing":landing.duplicate(),"path":path}

static func _route(from: String,to: String,steps: Array) -> Dictionary:
	var path: Array = []
	for step: Dictionary in steps:
		if path.is_empty() and step.has("takeoff"): path.append(step.takeoff.duplicate())
		path.append(step.landing.duplicate())
	return {"kind":"ordinary_sequence","from_port":from,"to_port":to,"steps":steps.duplicate(true),"path":path}

static func _bounds(m: Dictionary) -> Array:
	var bounds := Rect2(Vector2(float(m.spawn[0]),float(m.spawn[1])),Vector2.ONE)
	for body: Dictionary in m.platforms:
		var r: Array = body.rect
		bounds = bounds.merge(Rect2(float(r[0]),float(r[1]),float(r[2]),float(r[3])))
	for fruit: Dictionary in m.hook_anchors:
		bounds = bounds.expand(Vector2(float(fruit.position[0]),float(fruit.position[1])))
	bounds = bounds.grow(32.0)
	return [bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y]
