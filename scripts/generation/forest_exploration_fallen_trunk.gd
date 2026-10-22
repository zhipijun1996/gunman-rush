class_name ForestExplorationFallenTrunk
extends RefCounted
## One snapped, hollow fallen tree. Its upper fractures and inner passage
## are different journeys, not a second stack of floating platforms.
const VERSION := "forest-exploration-fallen-trunk-v18.3"
const SOURCE := "res://scripts/generation/forest_exploration_fallen_trunk.gd"
const PLACES := preload("res://scripts/generation/forest_exploration_places.gd")

static func build(variant: int = 0) -> Dictionary:
	if variant not in [0,1]: return {}
	var wide := variant == 1
	var middle_x := 368.0 if wide else 352.0
	var east_x := 800.0 if wide else 768.0
	var root_x := east_x+320.0
	# Keep a full body's launch clearance on the cache side of the thorns.
	# The earlier centre atroot_x-32 left only4wu after the body half-width:
	# the first accepted return-jump frame entered the thorn before its feet
	# cleared the tip. Move the actual cache/launch port8wu, not the hazard.
	var cache_x := root_x-24.0
	var thorn_x := root_x-96.0
	var exit_point := [root_x+256.0,494.0]
	var m := {
		"id":"fallen_trunk_two_faces","identity":"fallen trunk: broken crown or sheltered heartwood",
		"version":VERSION,"variant":variant,"bible_sha256":PLACES.BIBLE_SHA,
		"requires":["grapple"],"spawn":[-240.0,-18.0],"goal":exit_point.duplicate(),
		"entry_support_id":"entry","exit_support_id":"lower_root",
		"platforms":[],"hook_anchors":[],"dangers":[],"danger_surfaces":[],
		"danger_presentations":[],"scene_language":{},"routes":{},"ports":{},
		"action_program":[],"windows":[],
		"source_factory":{"path":SOURCE,"version":VERSION,"sha256":FileAccess.get_sha256(SOURCE)},
		"admission":{"geometry":"candidate","motor":"unverified","visual":"unverified","production_pool":false},
		"resource_contract":{"new_abilities":false,"physics_override":false,"health_override":false,"shot_refill_override":false},
		"chain_contract":{"continuous_airborne":false,"midair_floor_allowed":true,"native_verified":false,"production_pool":false},
		"tile_contract":{"family":"shared_underworld_with_forest_bible_material","source_tile_px":16,"world_tile_wu":32,"solid":"exact_union","one_way":"separate_bough_family","moving":false,"port_halo_wu":32,"standalone_spike_blocks":false},
	}
	# The split butt exposes the inner route before the player commits. The
	# first jump crosses that real entrance, while walking into it is legal.
	PLACES._bough(m,"entry",[-320.0,0.0,160.0,32.0],"root_earth",[96.0,128.0,112.0,64.0])
	PLACES._bough(m,"upper_west",[-48.0,0.0,304.0,32.0],"living_bough",[80.0,128.0,112.0,80.0])
	PLACES._bough(m,"upper_middle",[middle_x,-32.0,320.0,32.0],"living_bough",[128.0,144.0,112.0,96.0])
	PLACES._bough(m,"upper_east",[east_x,16.0,320.0,32.0],"living_bough",[80.0,112.0,128.0,96.0])
	# Fractures stop at the shared heartwood. A missed upper jump meets real
	# wood instead of a death pit or a coincident reward. The exposed floor
	# in a fracture has its own recovery contract below.
	var ceiling_stems := _heartwood(m,middle_x,east_x,root_x)
	# The entire butt bows outward around the cavity. Its inner edge moves
	# away from the player through the middle, then returns to the broad
	# floor; this changes the chamber's negative shape, not just its corner.
	PLACES._ribbon(m,"western_butt",[
		[32.0,-304.0,-256.0],[144.0,-400.0,-304.0],
		[320.0,-448.0,-320.0],[544.0,-384.0,-256.0]],"root_earth")
	# One long open chamber, with two broken floor sections. Its large
	# headroom is deliberate: ordinary full-body jumps must not scrape the
	# underside of a pretty low ceiling.
	# The western floor swells into a real asymmetric root instead of a
	# second thin parallel beam. No authored low route passes beneath it:
	# failed inner jumps reach the low root atx448 and continue eastward.
	PLACES._bough(m,"inner_west",[-320.0,384.0,704.0,32.0],"hollow_bark",[112.0,160.0,128.0,48.0])
	# The actual eastward low route does pass UNDER these next two floors.
	# Keep their undersides at448wu or above, preserving64wu of clearance.
	PLACES._bough(m,"inner_middle",[512.0,384.0,288.0,32.0],"hollow_bark",[48.0,64.0,48.0,40.0])
	PLACES._bough(m,"inner_cache",[928.0,384.0,root_x-928.0,32.0],"hollow_bark",[48.0,64.0,64.0,48.0])
	# The far heel joins crown to the cache floor. The lower opening is
	# really absent collision, not an image of a door. The western butt,
	# separately, joins its entry and inner floor to the low root.
	PLACES._ribbon(m,"eastern_heel",[
		[48.0,root_x-16.0,root_x+64.0],
		[144.0,root_x+64.0,root_x+176.0],
		[256.0,root_x+96.0,root_x+192.0],
		[320.0,root_x+48.0,root_x+144.0],
		[368.0,root_x+16.0,root_x+112.0],
		[400.0,root_x,root_x+96.0],
		[448.0,root_x-16.0,root_x+96.0],
		[544.0,root_x-48.0,root_x+112.0]],"root_earth",[448.0,512.0])
	PLACES._bough(m,"lower_root",[-320.0,512.0,root_x+736.0,32.0],"root_earth",[96.0,128.0,112.0,64.0])
	# The low walking surface owns its floor contacts. Retire only root
	# slices wholly enclosed by that exact solid, retaining the same union.
	# Coincident top colliders otherwise make the support identity unstable.
	var root_rect := [-320.0,512.0,root_x+736.0,32.0]
	for index: int in range(m.platforms.size()-1,-1,-1):
		var row: Dictionary = m.platforms[index]
		var id := str(row.id)
		if (id.begins_with("western_butt__") or id.begins_with("eastern_heel__")) and PLACES._fully_covered(row.rect,root_rect):
			m.scene_language.erase(id)
			m.platforms.remove_at(index)
	PLACES._hazard(m,"inner_cache","up",[thorn_x,360.0,48.0,24.0])
	# These roots belong to the ACTUAL curved underside columns, not the
	# old straight beam's now-interior bottom. Keep the fruit80wu below it.
	var butt_stem: Dictionary = ceiling_stems.butt
	var middle_stem: Dictionary = ceiling_stems.middle
	PLACES._fruit(m,"butt_fruit",[butt_stem.point[0],float(butt_stem.point[1])+80.0],str(butt_stem.host),butt_stem.point,"recovery")
	PLACES._fruit(m,"heartwood_fruit",[middle_stem.point[0],float(middle_stem.point[1])+80.0],str(middle_stem.host),middle_stem.point,"optional")
	PLACES._fruit(m,"outer_tip_fruit",[root_x+208.0,96.0],"eastern_heel__curve_0_0",[root_x+64.0,48.0],"main")
	var upper_point := [east_x+192.0,-2.0]
	var cache_point := [cache_x,366.0]
	var inside_point := [-112.0,366.0]
	var failure_point := [448.0,494.0]
	var notch_point := [(256.0+middle_x)*0.5,46.0]
	m.ports = {
		"entry":PLACES._port(m.spawn,"entry","observe_split_butt_and_choose_above_or_inside"),
		"upper":PLACES._port(upper_point,"upper_east","exposed_outer_crown"),
		"inside":PLACES._port(inside_point,"inner_west","sheltered_hollow_entry"),
		"cache":PLACES._port(cache_point,"inner_cache","closed_end_cache_beyond_inner_fractures"),
		"reward":PLACES._port(cache_point,"inner_cache","closed_end_cache_beyond_inner_fractures"),
		"exit":PLACES._port(exit_point,"lower_root","other_mouth_below_eastern_heel"),
		"onward":PLACES._port(exit_point,"lower_root","other_mouth_below_eastern_heel"),
		"return":PLACES._port(exit_point,"lower_root","other_mouth_below_eastern_heel"),
		"failure":PLACES._port(failure_point,"lower_root","visible_low_root_below_inner_fracture"),
		"notch":PLACES._port(notch_point,"fracture_heartwood","missed_first_outer_jump_on_real_heartwood"),
	}
	var main_steps: Array = [
		PLACES._walk("entry",[-184.0,-18.0]),
		PLACES._jump("entry","upper_west",[-184.0,-18.0],[-24.0,-18.0]),
		PLACES._walk("upper_west",[232.0,-18.0]),
		PLACES._jump("upper_west","upper_middle",[232.0,-18.0],[middle_x+24.0,-50.0]),
		PLACES._walk("upper_middle",[middle_x+296.0,-50.0]),
		PLACES._jump("upper_middle","upper_east",[middle_x+296.0,-50.0],[east_x+24.0,-2.0]),
		PLACES._walk("upper_east",upper_point),
	]
	var outer_steps: Array = [
		PLACES._walk("upper_east",[root_x-24.0,-2.0]),
		PLACES._drop("upper_east","lower_root",[root_x-24.0,-2.0],exit_point,[[root_x+240.0,-2.0]]),
	]
	var enter_steps: Array = [
		PLACES._walk("entry",[-184.0,-18.0]),
		PLACES._drop("entry","inner_west",[-184.0,-18.0],inside_point,[[-112.0,-18.0]]),
	]
	var inner_steps: Array = [
		PLACES._walk("inner_west",[360.0,366.0]),
		PLACES._jump("inner_west","inner_middle",[360.0,366.0],[536.0,366.0]),
		PLACES._walk("inner_middle",[776.0,366.0]),
		PLACES._jump("inner_middle","inner_cache",[776.0,366.0],[952.0,366.0]),
		PLACES._walk("inner_cache",[thorn_x-24.0,366.0]),
		PLACES._jump("inner_cache","inner_cache",[thorn_x-24.0,366.0],cache_point),
	]
	var cache_out: Array = [
		PLACES._jump("inner_cache","inner_cache",cache_point,[thorn_x-24.0,366.0]),
		PLACES._walk("inner_cache",[952.0,366.0]),
		PLACES._drop("inner_cache","lower_root",[952.0,366.0],[864.0,494.0],[[864.0,366.0]]),
		PLACES._walk("lower_root",exit_point),
	]
	var reward_steps: Array = enter_steps.duplicate(true)
	reward_steps.append_array(inner_steps)
	var main_to_exit: Array = main_steps.duplicate(true)
	main_to_exit.append_array(outer_steps)
	var reward_to_exit: Array = reward_steps.duplicate(true)
	reward_to_exit.append_array(cache_out)
	var notch_return: Array = [
		PLACES._jump("fracture_heartwood","upper_west",notch_point,[232.0,-18.0]),
	]
	for index: int in range(3,main_steps.size()): notch_return.append(main_steps[index].duplicate(true))
	notch_return.append_array(outer_steps)
	m.routes.main = PLACES._route("entry","upper",main_steps)
	m.routes.upper_to_exit = PLACES._route("upper","exit",outer_steps)
	m.routes.main_to_exit = PLACES._route("entry","exit",main_to_exit)
	m.routes.enter_inside = PLACES._route("entry","inside",enter_steps)
	m.routes.inside_reward = PLACES._route("inside","cache",inner_steps)
	m.routes.inner_reward = PLACES._route("entry","cache",reward_steps)
	m.routes.cache_return = PLACES._route("cache","exit",cache_out)
	m.routes.reward_return = PLACES._route("entry","exit",reward_to_exit)
	m.routes.failure_to_exit = PLACES._route("failure","exit",[PLACES._walk("lower_root",exit_point)])
	m.routes.notch_to_exit = PLACES._route("notch","exit",notch_return)
	m.reward_position = cache_point.duplicate()
	m.reward_support_id = "inner_cache"
	m.windows = [
		{"id":"split_butt_entrance","clear_rect":[-160.0,0.0,112.0,384.0]},
		{"id":"sheltered_heartwood","clear_rect":[-240.0,192.0,root_x+240.0,168.0]},
		{"id":"low_eastern_mouth","clear_rect":[root_x-16.0,448.0,128.0,64.0]},
	]
	m.geometry_intent = {
		"source":"a fallen hollow trunk with a split butt, two crown fractures and an intact heel",
		"continuity":"crown fragments meet one undulating heartwood ceiling; the outward-bowed heel joins crown and cache floor; the bowed western butt and swollen western floor meet the low root",
		"inside":"one broad inner chamber; two broken floor sections reveal the recoverable low root",
		"cavity_profile":"west wall bows left across its full height, ceiling undulates128–176wu, east heel bows outward before curling into the cache, western floor swells into a thick asymmetric root",
		"exterior":"exposed crown jumps have a real shallow fracture floor, not more floating short platforms",
		"contour_grid_wu":2.0,"maximum_endpoint_snap_wu":1.0,
		"visual_acceptance":"unverified; same shared terrain consumer does not sign material or composition",
	}
	m.play_contract = {
		"observe":"The split butt shows the sheltered passage below before the first outer jump.",
		"decision":"Stay above the fallen tree for the easier exposed route, or commit to the interior fractures and guarded heartwood cache.",
		"new_information":"The inner floor breaks show the same low root that later passes beneath the intact heel and rejoins the outside route.",
		"reward":"A closed-end cache needs a full inside journey and a return over its thorn patch; the region must own an actual OR reward transaction.",
		"alternative":"A skilled reverse entry through the intact heel is legitimate if the real body's route permits it; no visited-crown or prescribed-input lock.",
		"world_requirement":"Connect exit/onward to an actual next destination. failure is already on the same low root. Returning to the high entry is not claimed.",
		"counterexample":"Immediate butt drop, missed each exterior jump, missed each inner fracture, direct crown-to-cache fall, zero-H jumping, and heel back-entry.",
	}
	m.recovery = {"mode":"visible_low_root_and_shallow_outer_fractures","safe_ports":["failure","notch","exit"],"routes":["failure_to_exit","notch_to_exit"],"native_verified":false,"return_to_high_entry_not_claimed":true}
	m.risk_reward = {"tier":"normal_and_hard_alternatives","coins":4,"notes":1,"selection":"OR","world_reward_required":true,"return_required":true}
	m.variant_contract = {"role":"same_place_structural_variant_not_a_new_mechanic","change":"outer fractures widen from96 to112wu; crown and heel move while inner floor breaks retain their placement" if wide else "closer crown fractures; the inside floor keeps a different rhythm from the outside","actual_fields":["platforms","ports","routes","reward_position","world_bounds"],"not_diversity_proof":true}
	m.danger_hosts = ["inner_cache"]
	m.danger_faces = ["up"]
	m.ecology_slots = []
	m.world_bounds = PLACES._bounds(m)
	m.width = m.world_bounds[2]
	m.height = m.world_bounds[3]
	return m

static func _heartwood(m: Dictionary,middle_x: float,east_x: float,root_x: float) -> Dictionary:
	# Derive one actual wood mass from a varying inner ceiling. A thin
	# named top owns the already-authored fracture standing face; columns
	# begin at its bottom, so they cannot duplicate that floor contact.
	# The exposed underside, rather than an overpaint, shapes the cavity.
	PLACES._body(m,"fracture_heartwood",[-48.0,64.0,root_x+48.0,32.0],"hollow_bark")
	var knots: Array = [
		[-48.0,96.0,144.0],[96.0,96.0,176.0],
		[256.0,96.0,128.0],[middle_x+160.0,96.0,128.0],
		[east_x-64.0,96.0,176.0],[east_x+128.0,96.0,144.0],
		[root_x,96.0,160.0],
	]
	var stems: Dictionary = {}
	var count := int(ceil((root_x+48.0)/16.0))
	for index: int in count:
		var x := -48.0+float(index)*16.0
		var width := minf(16.0,root_x-x)
		var bottom := snappedf(PLACES._sample(knots,x+width*0.5).y,2.0)
		var id := "heartwood_curve__column_%s" % index
		PLACES._body(m,id,[x,96.0,width,bottom-96.0],"hollow_bark")
		if index == 0: stems.butt = {"host":id,"point":[x,bottom]}
		if is_equal_approx(x,middle_x+160.0): stems.middle = {"host":id,"point":[x,bottom]}
	return stems
