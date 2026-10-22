class_name ForestVariedBibleLayout
extends RefCounted
## The old v15 tree remains intact. New places join its real eastern root.
## No interpolated stair connector, actor motion or resource authority lives here.
const VERSION := "forest-varied-bible-v17"
const BIBLE_PATH := "res://docs/creative_direction/bibles/2-thorn_forest_region_bible_v2.md"
const BIBLE_SHA := "a7bad8323af64a7be0577132e5d988a6e1b781d9e1ac1639d37f9d65935194e3"
const FACTORY := preload("res://scripts/generation/forest_playful_module_variants.gd")
const API := preload("res://scripts/generation/forest_expedition_layout.gd")
const OLD := preload("res://scripts/generation/thorn_forest_region_v2_v10.gd")
const LANGUAGE := preload("res://scripts/generation/forest_scene_language.gd")
const ENTRY_REST := preload("res://scripts/generation/forest_entry_rest_bay.gd")

static func install(m: Dictionary) -> void:
	var old_spawn: Array = m.spawn.duplicate()
	var old_routes: Dictionary = m.routes.duplicate(true)
	var kept: Dictionary = {}
	for category: String in ["platforms","hook_anchors","enemies","rewards","geometry_instances","dangers"]:
		kept[category] = m[category].duplicate(true)
	for route_name: String in old_routes:
		m.routes["legacy_"+route_name] = old_routes[route_name].duplicate()
	var rng := RunRandomStream.new(str(m.seed),"forest_varied_bible","map_%s" % m.map_index,VERSION)
	var branch_variant := rng.next_int(2)
	# HH and RH are useful connection families, not two newly proven puzzles.
	# The complete upper/lower-window tree supplies the actual decision place.
	var continuation := "forked_bough_hh" if branch_variant == 0 else "side_root_rh"
	var origin_y := 1474.0
	var loop := _piece(m,"varied_outer_bough","side_root_rh",Vector2(2700.0,origin_y+130.0),false,{},true)
	var window := _piece(m,"varied_double_window","rooted_double_window",Vector2(3400.0,origin_y),true,loop.crown,false)
	var onward := _piece(m,"varied_return_bough",continuation,_point(window.crown.point),true,window.crown,false)
	# Standalone catch slabs would cap the lower window. This regional piece
	# instead returns onto the already-real window roots and outer-bough basin.
	_omit_standalone_recovery(m,onward)
	# The incoming RH naturally lands on the neighbouring upper-window lip.
	# Keep both real bodies; the actual receiving support is the window crown.
	var incoming: Dictionary = _edge_by_id(m,str(loop.main))
	incoming.b = str(window.crown.area)
	incoming.landing = [3000.0,origin_y-42.0]
	incoming.landing_support_id = str(window.crown.support)
	incoming.support_id = str(window.crown.support)
	incoming.path[-1] = incoming.landing.duplicate()
	# A horizontal RH approached underneath the neighbouring window sill and
	# hit its real underside. Rise diagonally before the side cast instead.
	incoming.action_program[0].direction = [-sqrt(0.5),sqrt(0.5)]
	for instance: Dictionary in m.geometry_instances:
		if str(instance.id) != str(loop.instance): continue
		instance.local_geometry.action_program = incoming.action_program.duplicate(true)
		instance.local_geometry.routes.main.action_program = incoming.action_program.duplicate(true)
		instance.regional_derivation.approach = "diagonal_upward_recoil_clears_neighbour_window_sill_before_H; local_horizontal_RH_proof_does_not_cover_this"
	incoming.receiver_derivation = "neighbour_upper_window_lip_is_first_real_floor; old_isolated_goal_not_reused"
	incoming.continuous_airborne = true
	# The old forest remains the normal departure. Local golden routes start
	# at this explicit observation port and need a fixture spawn override;
	# formal exploration enters it physically from the old F05 recovery root.
	API._area(m,"varied_observation",_point(window.entry.point),"OUTER ROOT / TWO WINDOWS AND THE OLD TREE","junction")
	_edge(m,"varied_arrival","varied_observation",str(window.entry.area),[{"kind":"walk","landing":window.entry.point.duplicate(),"support_id":str(window.entry.support)}])
	_edge(m,"varied_shared_receiver",str(window.crown.area),str(onward.entry.area),[{"kind":"walk","landing":onward.entry.point.duplicate(),"support_id":str(window.crown.support)}])
	var prefix: Array = ["varied_arrival",str(window.main),"varied_shared_receiver",str(onward.main)]
	# Finish outside the old F05 recovery root. This is one normal full jump
	# across a real gap, never a column of generated platforms.
	var receiver: Dictionary = _port("varied_old_root",Vector2(2220.0,1302.0),"bible_backbranch__recovery")
	API._area(m,str(receiver.area),_point(receiver.point),"KNOWN ROOT / WEAVER HOLLOW OR OLD CANOPY?","junction")
	var crown_rect := _rect(_platform(m,str(onward.crown.support)).rect)
	# This is one continuous broad root. The first physical trial missed the
	# old receiver: a 24wu inset launch could not cover its 170wu air gap.
	# Extend the root shoulder, rather than inserting a floating stepping tile.
	crown_rect.position.x -= 32.0
	crown_rect.size.x += 32.0
	_platform(m,str(onward.crown.support)).rect = [crown_rect.position.x,crown_rect.position.y,crown_rect.size.x,crown_rect.size.y]
	for instance: Dictionary in m.geometry_instances:
		if str(instance.id) != str(onward.instance): continue
		instance.regional_derivation.receiver_west_extension = 32.0
		for local: Dictionary in instance.local_geometry.platforms:
			if str(local.id) != "crown": continue
			local.rect[0] = float(local.rect[0])-32.0
			local.rect[2] = float(local.rect[2])+32.0
	var departure := Vector2(crown_rect.position.x+24.0,float(onward.crown.point[1]))
	_edge(m,"varied_old_root_return",str(onward.crown.area),str(receiver.area),[
		{"kind":"walk","landing":_pair(departure),"support_id":str(onward.crown.support)},
		API._step("jump_gap",departure,_point(receiver.point),str(onward.crown.support),str(receiver.support)).merged({"hold_to_receiver":true})])
	_edge(m,"varied_reenter_outer_forest",str(receiver.area),str(onward.crown.area),[
		API._step("jump_gap",Vector2(2220.0,1302.0),departure,str(receiver.support),str(onward.crown.support)).merged({"hold_to_receiver":true}),
		{"kind":"walk","landing":onward.crown.point.duplicate(),"support_id":str(onward.crown.support)}])
	_edge(m,"varied_weaver_lower",str(receiver.area),"bible_web_lower",[
		{"kind":"walk","landing":[1660.0,1302.0],"support_id":"bible_backbranch__recovery"},
		API._step("jump_rise",Vector2(1660.0,1302.0),Vector2(1630.0,1182.0),"bible_backbranch__recovery","bible_weaver_lower")])
	prefix.append_array(["varied_old_root_return","varied_weaver_lower","bible_web_lower_cross","bible_root_mouth_exit"])
	var old_join := "R" if m.choices.bible_root_connection == "outer_root_east_mouth" else "D"
	# A real downward loop reaches the other root, then uses the familiar RH
	# family to return through the upper window. Its choice is not a new ID.
	var lower: Dictionary = window.ports.outer_root
	var lower_route: String = str(window.route_ids.outer_descent)
	# The neighbouring real root receives the first descent before the lower
	# window. Walk off its actual east lip for the second descent; do not
	# pretend a solid intermediate receiver is transparent.
	var descending: Dictionary = _edge_by_id(m,lower_route)
	var crown_y := float(window.crown.point[1])
	var root_y := float(loop.entry.point[1])
	var low_y := float(lower.point[1])
	descending.kind = "ordinary_sequence"
	descending.steps = [
		{"kind":"drop_through","from_support_id":str(window.crown.support),"support_id":str(loop.entry.support),"takeoff":[2832.0,crown_y],"landing":[2760.0,root_y],"path":[[2832.0,crown_y],[2760.0,crown_y],[2760.0,root_y]]},
		{"kind":"drop_through","from_support_id":str(loop.entry.support),"support_id":str(lower.support),"takeoff":[2760.0,root_y],"landing":[2820.0,low_y],"path":[[2760.0,root_y],[2820.0,root_y],[2820.0,low_y]]},
		{"kind":"walk","landing":lower.point.duplicate(),"support_id":str(lower.support)}]
	descending.regional_derivation = "actual_outer_root_is_intermediate_receiver; leave_its_east_lip_before_lower_window"
	var catch_id := str(loop.supports.recovery)
	var catch_rect := _rect(_platform(m,catch_id).rect)
	var floor_point := Vector2(2630.0,catch_rect.position.y-18.0)
	API._area(m,"varied_lower_basin",floor_point,"OUTER BASIN / RETURN BY THE SIDE FRUIT","junction")
	_edge(m,"varied_lower_basin_drop",str(lower.area),"varied_lower_basin",[
		{"kind":"drop_through","from_support_id":str(lower.support),"support_id":catch_id,"landing":_pair(floor_point),"path":[lower.point.duplicate(),[2630.0,float(lower.point[1])],_pair(floor_point)]}])
	var retry: Array = Array(FACTORY.build("side_root_rh").routes.retry.steps).duplicate(true)
	var mapped_retry := _steps(retry,_point(loop.origin),false,loop.supports)
	_edge(m,"varied_basin_side_root","varied_lower_basin",str(loop.entry.area),mapped_retry)
	_edge(m,"varied_rh_receiving_lip",str(window.crown.area),str(window.crown.area),[{"kind":"walk","landing":window.crown.point.duplicate(),"support_id":str(window.crown.support)}])
	m.routes.varied_outer_loop = [lower_route,"varied_lower_basin_drop","varied_basin_side_root",str(loop.main),"varied_rh_receiving_lip"]
	m.routes.varied_outer_trial = ["varied_arrival",str(window.main)]+Array(m.routes.varied_outer_loop)
	m.route_goals = m.get("route_goals",{})
	m.route_goals.varied_outer_trial = str(window.crown.area)
	m.routes.varied_main_trial = prefix.duplicate()
	m.route_goals.varied_main_trial = old_join
	var reward_port: Dictionary = window.ports.inner_root if branch_variant == 0 else window.ports.outer_root
	var reward_id := "varied_window_root_cache"
	m.rewards.append({"id":reward_id,"position":reward_port.point.duplicate(),"area":str(reward_port.area),"tier":"medium","claimed":false,"reward_mode":"resources","items":[],"coins":4,"resources":[{"kind":"coin","amount":4},{"kind":"note","amount":1}],"requires":[],"approach_route":"varied_window_cache_approach","return_route":"varied_window_cache_return"})
	if branch_variant == 0:
		m.routes.varied_window_cache_approach = [lower_route,str(window.route_ids.lower_inward_return)]
		var inner: Dictionary = window.ports.inner_root
		_edge(m,"varied_inner_basin_drop",str(inner.area),"varied_lower_basin",_inner_basin_steps(inner,catch_id,floor_point))
		m.routes.varied_window_cache_return = ["varied_inner_basin_drop","varied_basin_side_root",str(loop.main),"varied_rh_receiving_lip"]
	else:
		m.routes.varied_window_cache_approach = [lower_route]
		m.routes.varied_window_cache_return = ["varied_lower_basin_drop","varied_basin_side_root",str(loop.main),"varied_rh_receiving_lip"]
	m.routes.varied_reward_trial = ["varied_arrival",str(window.main)]+Array(m.routes.varied_window_cache_approach)+Array(m.routes.varied_window_cache_return)
	m.route_goals.varied_reward_trial = str(window.crown.area)
	_install_annex_access(m,old_routes,window,loop,onward,receiver)
	var hollow := _install_l_loop(m,window)
	m.varied_bible_contract = {"version":VERSION,"baseline_layout":"forest-bible-world-v15","bible_path":BIBLE_PATH,"bible_sha256":BIBLE_SHA,"status":"installed_candidate","candidate_valid":true,
		"old_core_preserved":true,"legacy_spawn":old_spawn,"legacy_routes":old_routes.keys(),"retained_bodies":kept,
		"ordinary_places":[str(window.instance),str(hollow.instance)],"connection_families":[str(loop.instance),str(onward.instance)],
		"golden_scope":"local_double_window_plus_connection; old_spawn_annex_and_L_reward_routes_installed_but_native_unverified",
		"not_complete_region":true,"automatic_stair_connectors":false,"seed_changes":{"continuation_module":continuation,"root_reward_port":"inner_root" if branch_variant == 0 else "outer_root"},"unavailable_candidates":{"z_hollow_inner_cache":"world_bottom_recovery_unverified; not_installed"},
		"unverified":["full_world_Motor","world_lower_window_return","L_entry_gap_and_full_body","L_lower_root_fixed_hang_return","L_reward_OR_transaction_and_far_exit","neighbour_body_clearance","visual_composition","original_v15_full_routes_with_new_neighbours","larger_library_integration"],"native_verified":false,"production_pool":false,"player_acceptance":"unverified"}
	m.choices.varied_bible = {"branch":branch_variant,"continuation_module":continuation,"reward_port":"inner_root" if branch_variant == 0 else "outer_root","normal_spawn":m.spawn.duplicate(),"local_golden_spawn":window.entry.point.duplicate(),"optional_hollow":"l_hollow_reward_loop"}
	m.streams.varied_bible = "forest_varied_bible"
	m.stream_positions.varied_bible = rng.position()
	ENTRY_REST.install(m)
	var displays: Array = m.danger_presentations.duplicate(true)
	LANGUAGE.annotate(m)
	# Nearest-body fallback does not replace an authored true hazard host.
	for index: int in displays.size():
		if not displays[index].is_empty(): m.danger_presentations[index] = displays[index]
	var bounds := Rect2(_point(m.spawn),Vector2.ONE)
	for row: Dictionary in m.platforms: bounds = bounds.merge(_rect(row.rect))
	for row: Dictionary in m.hook_anchors: bounds = bounds.expand(_point(row.position))
	bounds = bounds.grow(200.0)
	m.world_bounds = [bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y]
	m.topology_signature = OLD.topology_signature(m)+"/varied/"+str(branch_variant)+"/"+continuation

static func _install_annex_access(m: Dictionary,old_routes: Dictionary,window: Dictionary,loop: Dictionary,onward: Dictionary,receiver: Dictionary) -> void:
	# This is the existing F05 approach's first real drop, stopped at its
	# actual recovery root. No new collision is placed over that old floor.
	_edge(m,"varied_old_recovery_drop","bible_web_lower",str(receiver.area),[
		{"kind":"drop_through","landing":[1980.0,1302.0],"support_id":str(receiver.support),"path":[[1630.0,1182.0],[1750.0,1182.0],[1980.0,1302.0]]},
		{"kind":"walk","landing":receiver.point.duplicate(),"support_id":str(receiver.support)}])
	_edge(m,"varied_annex_entry_drop",str(onward.crown.area),str(loop.entry.area),[
		{"kind":"drop_through","from_support_id":str(onward.crown.support),"support_id":str(loop.entry.support),"takeoff":onward.crown.point.duplicate(),"landing":[2760.0,1604.0],"path":[onward.crown.point.duplicate(),[2770.0,1302.0],[2760.0,1604.0]]},
		{"kind":"walk","landing":loop.entry.point.duplicate(),"support_id":str(loop.entry.support)}])
	# The upper aperture is tall enough to walk through in reverse. The
	# eastern sill is 42wu lower; acknowledge the actual solid intermediary.
	_edge(m,"varied_upper_window_reverse",str(window.crown.area),str(window.entry.area),[
		{"kind":"walk","landing":[3130.0,1432.0],"support_id":str(window.supports.trunk_between_windows)},
		{"kind":"walk","landing":[3240.0,1474.0],"support_id":str(loop.crown.support)},
		{"kind":"walk","landing":window.entry.point.duplicate(),"support_id":str(loop.crown.support)}])
	_edge(m,"varied_observation_alias",str(window.entry.area),"varied_observation",[{"kind":"walk","landing":window.entry.point.duplicate(),"support_id":str(loop.crown.support)}])
	var approach: Array = []
	for id: String in old_routes.bible_backbranch_journey:
		if id == "bible_web_to_backbranch": break
		approach.append(id)
	approach.append_array(["varied_old_recovery_drop","varied_reenter_outer_forest","varied_annex_entry_drop",str(loop.main),"varied_rh_receiving_lip","varied_upper_window_reverse","varied_observation_alias"])
	m.routes.varied_annex_approach = approach
	m.route_goals.varied_annex_approach = "varied_observation"
	m.routes.varied_annex_journey = approach+["varied_arrival",str(window.main),"varied_shared_receiver",str(onward.main),"varied_old_root_return","varied_weaver_lower","bible_web_lower_cross","bible_root_mouth_exit"]+OLD._route(m,"R" if m.choices.bible_root_connection == "outer_root_east_mouth" else "D","camp")
	m.route_goals.varied_annex_journey = "camp"

static func _install_l_loop(m: Dictionary,window: Dictionary) -> Dictionary:
	var inner: Dictionary = window.ports.inner_root
	var hollow := _piece(m,"varied_l_hollow","l_hollow_reward_loop",Vector2(3890.0,1676.0),false,{},false)
	_edge(m,"varied_l_entry",str(inner.area),str(hollow.entry.area),[
		{"kind":"walk","landing":[3690.0,1676.0],"support_id":str(inner.support)},
		API._step("jump_gap",Vector2(3690.0,1676.0),Vector2(3870.0,1676.0),str(inner.support),str(hollow.entry.support)).merged({"hold_to_receiver":true}),
		{"kind":"walk","landing":hollow.entry.point.duplicate(),"support_id":str(hollow.entry.support)}])
	# This lower port reconnects to the real earlier root with the existing
	# fixed-fruit hang jump. It is not a copied platform recovery ladder.
	var fruit_id := "varied_l_return_fruit"
	m.hook_anchors.append({"id":fruit_id,"position":[3780.0,1754.0],"hang_enabled":true,"scene_kind":"copper_growth_ring","structure_id":str(hollow.instance),"fruit_role":"return","fruit_presentation":"rooted_fruit","fruit_host_support_id":str(inner.support),"fruit_stem_root":[3710.0,1694.0],"fruit_route_bindings":["available:varied_l_fixed_return:H"]})
	API._area(m,"varied_l_return_departure",Vector2(3802.0,1996.0),"LOWER ROOT / KNOWN FIXED FRUIT","junction")
	_edge(m,"varied_l_return_align",str(hollow.ports.lower_rejoin.area),"varied_l_return_departure",[{"kind":"walk","landing":[3802.0,1996.0],"support_id":str(hollow.ports.lower_rejoin.support)}])
	API._area(m,"varied_l_return_shoulder",Vector2(3690.0,1676.0),"KNOWN INNER ROOT / LOWER MOUTH REJOIN","junction")
	API._edge(m,"varied_l_fixed_return","varied_l_return_departure","varied_l_return_shoulder","short_hook_crossing",[[3802.0,1996.0],[3780.0,1754.0],[3690.0,1676.0]])
	m.connections[-1].merge({"anchor_id":fruit_id,"release_mode":"hang_jump","target_kind":"fixed_fruit","geometry_instance":str(hollow.instance),"from_support_id":str(hollow.ports.lower_rejoin.support),"entry_support_id":str(hollow.ports.lower_rejoin.support),"landing_support_id":str(inner.support),"support_id":str(inner.support),"landing":[3690.0,1676.0],"native_verified":false})
	_edge(m,"varied_l_inner_rejoin","varied_l_return_shoulder",str(inner.area),[{"kind":"walk","landing":inner.point.duplicate(),"support_id":str(inner.support)}])
	if _edge_by_id(m,"varied_inner_basin_drop").is_empty():
		_edge(m,"varied_inner_basin_drop",str(inner.area),"varied_lower_basin",_inner_basin_steps(inner,"varied_outer_bough__recovery",Vector2(2630,1806)))
	m.routes.varied_l_approach = [str(window.route_ids.outer_descent),str(window.route_ids.lower_inward_return),"varied_l_entry",str(hollow.route_ids.reward)]
	m.routes.varied_l_return = [str(hollow.route_ids.reward_other_exit),"varied_l_return_align","varied_l_fixed_return","varied_l_inner_rejoin","varied_inner_basin_drop","varied_basin_side_root","varied_outer_bough__main","varied_rh_receiving_lip"]
	# The far exit returns across the same actual 144wu root gap, so neither
	# the voluntary onward choice nor its broad failure basin strands a run.
	_edge(m,"varied_l_far_return",str(hollow.crown.area),str(hollow.ports.cache.area),[
		{"kind":"walk","landing":[4842.0,1836.0],"support_id":str(hollow.crown.support)},
		API._step("jump_gap",Vector2(4842.0,1836.0),Vector2(4722.0,1836.0),str(hollow.crown.support),str(hollow.ports.cache.support)).merged({"hold_to_receiver":true}),
		{"kind":"walk","landing":hollow.ports.cache.point.duplicate(),"support_id":str(hollow.ports.cache.support)}])
	var reward_id := "varied_l_elbow_cache"
	for route_name: String in ["reward_other_exit","reward_onward"]:
		_edge_by_id(m,str(hollow.route_ids[route_name])).merge({"claim_before_edge":true,"claim_id":reward_id,"claim_area":str(hollow.ports.cache.area)})
	m.rewards.append({"id":reward_id,"position":hollow.ports.cache.point.duplicate(),"area":str(hollow.ports.cache.area),"tier":"medium","claimed":false,"reward_mode":"resources","items":[],"coins":4,"resources":[{"kind":"coin","amount":4},{"kind":"note","amount":1}],"requires":[],"approach_route":"varied_l_approach","return_route":"varied_l_return","regional_reward_budget":"4coin_OR_1note; no_double_award"})
	m.routes.varied_l_trial = ["varied_arrival",str(window.main)]+Array(m.routes.varied_l_approach)+Array(m.routes.varied_l_return)
	m.route_goals.varied_l_trial = str(window.crown.area)
	m.routes.varied_l_onward_trial = ["varied_arrival",str(window.main)]+Array(m.routes.varied_l_approach)+[str(hollow.route_ids.reward_onward),"varied_l_far_return"]+Array(m.routes.varied_l_return)
	m.route_goals.varied_l_onward_trial = str(window.crown.area)
	m.routes.varied_l_journey = Array(m.routes.varied_annex_approach)+Array(m.routes.varied_l_trial)+["varied_shared_receiver","varied_return_bough__main","varied_old_root_return","varied_weaver_lower","bible_web_lower_cross","bible_root_mouth_exit"]+OLD._route(m,"R" if m.choices.bible_root_connection == "outer_root_east_mouth" else "D","camp")
	m.route_goals.varied_l_journey = "camp"
	return hollow

static func _inner_basin_steps(inner: Dictionary,catch_id: String,floor_point: Vector2) -> Array:
	# The outer root leaves only 10wu over the basin. A real body cannot
	# walk beneath it: jump onto it, then walk out of its western mouth.
	return [
		{"kind":"drop_through","from_support_id":str(inner.support),"support_id":catch_id,"landing":[3180.0,floor_point.y],"path":[inner.point.duplicate(),[3180.0,float(inner.point[1])],[3180.0,floor_point.y]]},
		{"kind":"walk","landing":[3160.0,floor_point.y],"support_id":catch_id},
		API._step("jump_gap",Vector2(3160,floor_point.y),Vector2(3000,1756),catch_id,"varied_double_window__outer_root").merged({"hold_to_receiver":true}),
		{"kind":"walk","landing":[2760.0,1756.0],"support_id":"varied_double_window__outer_root"},
		{"kind":"drop_through","from_support_id":"varied_double_window__outer_root","support_id":catch_id,"landing":_pair(floor_point),"path":[[2760.0,1756.0],[floor_point.x,1756.0],_pair(floor_point)]}]

static func _piece(m: Dictionary,id: String,module_id: String,origin: Vector2,mirrored: bool,shared_entry: Dictionary,extend_receiver: bool) -> Dictionary:
	var raw: Dictionary = FACTORY.build(module_id).duplicate(true)
	if mirrored: _mirror_raw(raw)
	if module_id == "rooted_double_window":
		# Keep the real aperture/ceiling, rather than copy the standalone
		# prototype's 410wu rectangular back mass into the playable view.
		for body: Dictionary in raw.platforms:
			if str(body.id) == "belly_roof":
				body.rect[1] = float(body.rect[1])+float(body.rect[3])-64.0
				body.rect[3] = 64.0
	var supports: Dictionary = {}
	var anchors: Dictionary = {}
	var skip: Array[String] = []
	if not shared_entry.is_empty(): skip.append(str(raw.entry_support_id))
	for row: Dictionary in raw.platforms:
		var local_id := str(row.id)
		if local_id in skip:
			supports[local_id] = str(shared_entry.support)
			continue
		var rect := _rect(row.rect)
		if extend_receiver and local_id == str(raw.exit_support_id):
			rect.size.x += 320.0
			# The thick isolated receiver buried the neighbour's lower fruit.
			# A continuous branch carries the observation bank above that window.
			rect.size.y = 40.0
			row.rect = [rect.position.x,rect.position.y,rect.size.x,rect.size.y]
		var mapped := id+"__"+local_id
		supports[local_id] = mapped
		rect.position += origin
		var kind := str(raw.get("scene_language",{}).get(local_id,""))
		if kind not in LANGUAGE.KINDS: kind = "living_bough" if bool(row.one_way) else "hollow_bark" if rect.size.y>80.0 else "root_earth"
		API._platform(m,mapped,rect,bool(row.one_way),kind,id,local_id)
	for row: Dictionary in raw.hook_anchors:
		var mapped := id+"__"+str(row.id)
		anchors[str(row.id)] = mapped
		m.hook_anchors.append({"id":mapped,"position":_pair(_point(row.position)+origin),"scene_kind":"copper_growth_ring","structure_id":id,"fruit_role":str(row.get("fruit_role","optional")),"fruit_presentation":"rooted_fruit","fruit_host_support_id":str(supports[row.host_support_id]),"fruit_stem_root":_pair(_point(row.stem_root)+origin),"fruit_route_bindings":["available:"+id+"__main:H"]})
	var danger_indices: Array[int] = []
	for local: Array in raw.dangers:
		var rect := _rect(local)
		rect.position += origin
		danger_indices.append(m.dangers.size())
		m.dangers.append([rect.position.x,rect.position.y,rect.size.x,rect.size.y])
		m.danger_presentations.append({})
	for surface: Dictionary in raw.get("danger_surfaces",[]):
		var index: int = danger_indices[int(surface.danger_index)]
		var host := str(supports[surface.host_support_id])
		var face := str(surface.face)
		m.danger_presentations[index] = {"scene_kind":"thorn_growth","facing":face,"host_structure_id":id,"host_support_id":host}
		m.thorn_surfaces.append(_thorn_surface(m,index,host,face))
	var instance := {"id":id,"factory":"res://scripts/generation/forest_playful_module_variants.gd","geometry_version":FACTORY.VERSION,"module_id":module_id,"local_geometry":raw,"translation":_pair(origin),"platform_id_map":supports,"anchor_id_map":anchors,"danger_indices":danger_indices,"regional_derivation":{"mirror_x":mirrored,"shared_entry_support":str(shared_entry.get("support","")),"receiver_east_extension":320.0 if extend_receiver else 0.0},"native_verified":false}
	if extend_receiver: instance.regional_derivation.receiver_thickness = 40.0
	if module_id == "rooted_double_window": instance.regional_derivation.ceiling = "64wu_real_roof_preserves_aperture_ceiling; standalone_rectangular_back_mass_removed; old_v15_untouched"
	m.geometry_instances.append(instance)
	m.scene_structure_kinds[id] = "hollow_tree" if module_id == "rooted_double_window" else "bough_relay"
	var ports: Dictionary = {}
	for name: String in raw.ports:
		var p: Dictionary = raw.ports[name]
		var point := _point(p.position)+origin
		var area := id+"__"+name
		API._area(m,area,point,str(raw.get("identity",module_id))+" / "+name,"junction")
		ports[name] = _port(area,point,str(supports[p.support_id]))
	var route_ids: Dictionary = {}
	for name: String in raw.routes:
		var route: Dictionary = raw.routes[name]
		var a: Dictionary = ports[route.from_port]
		var b: Dictionary = ports[route.to_port]
		var edge_id := id+"__"+name
		var kind := "ordinary_sequence" if route.has("steps") else str(route.kind)
		API._edge(m,edge_id,str(a.area),str(b.area),kind,_path(route.get("path",[raw.ports[route.from_port].position,raw.ports[route.to_port].position]),origin),_steps(route.get("steps",[]),origin,false,supports))
		var edge: Dictionary = m.connections[-1]
		edge.geometry_instance = id
		edge.entry_support_id = str(a.support)
		edge.from_support_id = str(a.support)
		edge.landing = b.point.duplicate()
		edge.landing_support_id = str(b.support)
		edge.support_id = str(b.support)
		if route.has("action_program"):
			edge.action_program = route.action_program.duplicate(true)
			edge.continuous_airborne = bool(raw.get("chain_contract",{}).get("continuous_airborne",false))
		if route.has("takeoff"): edge.action_start = _pair(_point(route.takeoff)+origin)
		if module_id == "rooted_double_window" and name == "lower_inward_return":
			edge.kind = "hollow_outer_recovery"
			edge.from_port = "R"
			edge.to_port = "D"
			edge.regional_derivation = "consume_actual_old_lower_window_jump_approach_and_HR; mirror_geometry_not_actor"
		if name == "main" and raw.has("consumer_contract") and raw.consumer_contract.get("kind") == "hollow_cavity":
			edge.merge(raw.consumer_contract.duplicate(true),true)
		route_ids[name] = edge_id
	return {"instance":id,"entry":ports.entry,"crown":ports.crown,"ports":ports,"supports":supports,"anchors":anchors,"main":str(route_ids.main),"route_ids":route_ids,"origin":_pair(origin)}

static func _omit_standalone_recovery(m: Dictionary,piece: Dictionary) -> void:
	var instance: Dictionary = {}
	for candidate: Dictionary in m.geometry_instances:
		if str(candidate.id) == str(piece.instance): instance = candidate; break
	var removed: Array[String] = []
	for local: String in ["recovery","recovery_step"]:
		if piece.supports.has(local): removed.append(str(piece.supports[local]))
	var kept: Array = []
	for platform: Dictionary in m.platforms:
		if str(platform.id) not in removed: kept.append(platform)
	m.platforms = kept
	var routes: Array[String] = []
	for name: String in ["miss_to_basin","retry"]:
		if piece.route_ids.has(name): routes.append(str(piece.route_ids[name]))
	var edges: Array = []
	for edge: Dictionary in m.connections:
		if str(edge.id) not in routes: edges.append(edge)
	m.connections = edges
	var omitted_areas: Array[String] = []
	for key: String in piece.ports:
		if str(piece.ports[key].support) in removed: omitted_areas.append(str(piece.ports[key].area))
	var area_rows: Array = []
	for area: Dictionary in m.areas:
		if str(area.id) not in omitted_areas: area_rows.append(area)
	m.areas = area_rows
	instance.source_geometry_before_regional_recovery = instance.local_geometry.duplicate(true)
	var raw_rows: Array = []
	for row: Dictionary in instance.local_geometry.platforms:
		if str(row.id) not in ["recovery","recovery_step"]: raw_rows.append(row)
	instance.local_geometry.platforms = raw_rows
	for key: String in ["recovery","recovery_step"]: instance.platform_id_map.erase(key)
	for key: String in ["miss_to_basin","retry"]: instance.local_geometry.routes.erase(key)
	instance.local_geometry.ports.erase("basin")
	instance.regional_derivation.recovery = "whole_isolated_catch_omitted; real_window_roots_and_outer_RH_basin_receive_failures"
	instance.regional_derivation.omitted_supports = removed
	# Keep the exact source raw for provenance, but clearly record that its
	# standalone retry ports are not actual regional recommendations.
	instance.regional_recovery = {"kind":"shared_world_roots","support_ids":["varied_outer_bough__entry","varied_outer_bough__recovery","varied_double_window__inner_root","varied_double_window__outer_root"],"native_verified":false}

static func _mirror_raw(raw: Dictionary) -> void:
	for key: String in ["spawn","goal"]: raw[key][0] = -float(raw[key][0])
	for row: Dictionary in raw.platforms: row.rect[0] = -float(row.rect[0])-float(row.rect[2])
	for row: Dictionary in raw.hook_anchors:
		row.position[0] = -float(row.position[0])
		if row.has("stem_root"): row.stem_root[0] = -float(row.stem_root[0])
	for rect: Array in raw.dangers: rect[0] = -float(rect[0])-float(rect[2])
	for row: Dictionary in raw.get("windows",[]): row.clear_rect[0] = -float(row.clear_rect[0])-float(row.clear_rect[2])
	for key: String in raw.get("nodes",{}): raw.nodes[key].position[0] = -float(raw.nodes[key].position[0])
	for key: String in raw.ports: raw.ports[key].position[0] = -float(raw.ports[key].position[0])
	for action: Dictionary in raw.get("action_program",[]):
		if action.has("direction"): action.direction[0] = -float(action.direction[0])
	for name: String in raw.routes:
		var route: Dictionary = raw.routes[name]
		for point_key: String in ["takeoff","landing"]:
			if route.has(point_key): route[point_key][0] = -float(route[point_key][0])
		for point: Array in route.get("path",[]): point[0] = -float(point[0])
		for action: Dictionary in route.get("action_program",[]):
			if action.has("direction"): action.direction[0] = -float(action.direction[0])
		for step: Dictionary in route.get("steps",[]):
			for point_key: String in ["takeoff","landing"]:
				if step.has(point_key): step[point_key][0] = -float(step[point_key][0])
			for point: Array in step.get("path",[]): point[0] = -float(point[0])
	for surface: Dictionary in raw.get("danger_surfaces",[]):
		if surface.face == "left": surface.face = "right"
		elif surface.face == "right": surface.face = "left"
	var bounds: Array = raw.world_bounds
	bounds[0] = -float(bounds[0])-float(bounds[2])

static func _steps(rows: Array,origin: Vector2,mirrored: bool,supports: Dictionary) -> Array:
	var output: Array = []
	for row: Dictionary in rows:
		var step := row.duplicate(true)
		for key: String in ["takeoff","landing"]:
			if step.has(key): step[key] = _pair(_point(step[key])*Vector2(-1.0 if mirrored else 1.0,1.0)+origin)
		for key: String in ["from_support_id","support_id"]:
			if step.has(key): step[key] = str(supports.get(str(step[key]),str(step[key])))
		if step.has("path"):
			for index: int in step.path.size(): step.path[index] = _pair(_point(step.path[index])*Vector2(-1.0 if mirrored else 1.0,1.0)+origin)
		if step.get("kind") == "jump_gap": step.hold_to_receiver = true
		output.append(step)
	return output

static func _path(points: Array,origin: Vector2) -> Array:
	var output: Array = []
	for point: Array in points: output.append(_pair(_point(point)+origin))
	return output

static func _edge(m: Dictionary,id: String,a: String,b: String,steps: Array) -> void:
	var path: Array = []
	for row: Dictionary in steps:
		if row.has("takeoff") and path.is_empty(): path.append(row.takeoff.duplicate())
		if row.has("landing"): path.append(row.landing.duplicate())
	API._edge(m,id,a,b,"ordinary_sequence",path,steps)

static func _thorn_surface(m: Dictionary,index: int,host_id: String,face: String) -> Dictionary:
	var hazard := _rect(m.dangers[index])
	var host := _rect(_platform(m,host_id).rect)
	var start: Vector2
	var finish: Vector2
	if face in ["up","down"]:
		var y := host.position.y if face == "up" else host.end.y
		start = Vector2(hazard.position.x,y); finish = Vector2(hazard.end.x,y)
	else:
		var x := host.position.x if face == "left" else host.end.x
		start = Vector2(x,hazard.position.y); finish = Vector2(x,hazard.end.y)
	return {"danger_index":index,"face":face,"hazard_rect":m.dangers[index].duplicate(),"segments":[{"support_id":host_id,"start":_pair(start),"end":_pair(finish)}]}

static func validate(m: Dictionary) -> bool:
	var contract: Variant = m.get("varied_bible_contract")
	if not contract is Dictionary or contract.get("version") != VERSION or contract.get("candidate_valid") != true: return false
	if contract.get("bible_sha256") != BIBLE_SHA or contract.get("automatic_stair_connectors") != false: return false
	if m.get("requires") != ["grapple"] or m.get("production_pool") != false: return false
	for category: String in ["platforms","hook_anchors","areas","connections","enemies","rewards","geometry_instances"]:
		var ids: Dictionary = {}
		for row: Dictionary in m[category]:
			if ids.has(str(row.id)): return false
			ids[str(row.id)] = true
	for category: String in ["platforms","hook_anchors","enemies","rewards","geometry_instances"]:
		for old_row: Dictionary in contract.retained_bodies[category]:
			var found := false
			for row: Dictionary in m[category]:
				if str(row.id) == str(old_row.id) and RandomStageGenerator.new()._same_data(row,old_row): found = true; break
			if not found: return false
	for old_danger: Array in contract.retained_bodies.dangers:
		if not m.dangers.has(old_danger): return false
	var supports: Dictionary = {}
	for row: Dictionary in m.platforms: supports[str(row.id)] = row
	for name: String in m.routes:
		var at := ""
		for edge_id: String in m.routes[name]:
			var edge := _edge_by_id(m,edge_id)
			if edge.is_empty() or (not at.is_empty() and str(edge.a) != at): return false
			at = str(edge.b)
	for edge: Dictionary in m.connections:
		for key: String in ["from_support_id","entry_support_id","landing_support_id","support_id"]:
			if edge.has(key) and not supports.has(str(edge[key])): return false
	return LANGUAGE.validate(m)

static func _edge_by_id(m: Dictionary,id: String) -> Dictionary:
	return OLD._edge_by_id(m,id)

static func _platform(m: Dictionary,id: String) -> Dictionary:
	return API._platform_by_id(m,id)

static func _port(area: String,point: Vector2,support: String) -> Dictionary:
	return {"area":area,"point":_pair(point),"support":support}

static func _point(value: Array) -> Vector2:
	return Vector2(float(value[0]),float(value[1]))

static func _pair(point: Vector2) -> Array:
	return [point.x,point.y]

static func _rect(value: Array) -> Rect2:
	return Rect2(float(value[0]),float(value[1]),float(value[2]),float(value[3]))
