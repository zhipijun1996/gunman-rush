class_name ForestExplorationNetwork
extends RefCounted
## V18 joint exploration candidate. Old producers remain immutable; this version
## relocates the real Boss beyond actual new places, rather than growing an annex.
const VERSION := "forest-exploration-places-v18"
const BIBLE_SHA := "a7bad8323af64a7be0577132e5d988a6e1b781d9e1ac1639d37f9d65935194e3"
const API := preload("res://scripts/generation/forest_expedition_layout.gd")
const OLD := preload("res://scripts/generation/thorn_forest_region_v2_v10.gd")
const PLACES := preload("res://scripts/generation/forest_exploration_places.gd")
const EMBED := preload("res://scripts/generation/forest_exploration_place_embedding.gd")
const FALLEN := preload("res://scripts/generation/forest_exploration_fallen_trunk.gd")
const FRUIT := preload("res://scripts/generation/forest_exploration_fruit_crossing.gd")
const WINDOW := preload("res://scripts/generation/forest_playful_module_variants.gd")
const LANGUAGE := preload("res://scripts/generation/forest_scene_language.gd")
const ENTRY := preload("res://scripts/generation/forest_entry_rest_bay.gd")
const ARENA := preload("res://scripts/generation/forest_boss_arena_factory.gd")

static func install(m: Dictionary) -> void:
	var original_routes: Dictionary = m.routes.duplicate(true)
	m.route_goals = m.get("route_goals",{})
	var normal_prefix: Array = original_routes.bible_connection_journey.duplicate()
	var camp_to_c := _old_camp_to_c(m)
	var old_sector: Dictionary = m.boss_geometry.duplicate(true)
	_remove_old_boss(m)
	var rng := RunRandomStream.new(str(m.seed),"forest_exploration_places","map_%s" % m.map_index,VERSION)
	var variant := rng.next_int(2)
	var at_c := _area_point(m,"C")
	# C has two actual heights. Consume the physical exit, never one seed's Y.
	var window_origin := Vector2(1500.0,at_c.y)
	var window := EMBED.install(m,"places_double_window",_window_geometry(),window_origin)
	var seven_origin := Vector2(2460.0,at_c.y-24.0)
	var seven := EMBED.install(m,"places_seven",PLACES.build("seven_bough_reveal",variant),seven_origin)
	_install_window_edges(m,window,at_c)
	var entry: Dictionary = seven.ports.entry
	var crown: Dictionary = window.ports.crown
	_edge(m,"places_window_to_seven",str(crown.area),str(entry.area),[
		API._step("jump_gap",Vector2(2068,at_c.y-42),Vector2(2172,at_c.y-42),str(crown.support),str(entry.support)),
		_walk(str(entry.support),entry.point)])
	var old_return_edges := _install_lower_return(m,seven)
	# Each authored place has an ordinary onward route and an optional
	# different destination. These actual stage orders are part of the graph.
	var expansion := _install_onward_places(m,rng,seven.ports["return"])
	var onward_edges: Array = expansion.normal
	var before_places: Array = ["places_cavity_exit",str(window.route_ids.main),"places_window_to_seven",str(seven.route_ids.main),str(seven.route_ids.main_to_far)]
	var final_edge := _install_boss(m,expansion.onward)
	var main: Array = before_places+onward_edges+[final_edge]
	# Replace each actual old final approach with real edge records. Old body,
	# route and save reconstruction remains in v15, not fake old coordinates.
	var from_e: Array = ["outer_drop","outer_to_inner","inner_recovery","belly_borer_access","borer_crossing"]
	for route_name: String in m.routes:
		var rewritten: Array = []
		for edge_id: String in m.routes[route_name]:
			if edge_id == "crown_prep": rewritten.append_array(from_e+main)
			elif edge_id == "cavity_prep": rewritten.append_array(main)
			elif edge_id == "reward_to_prep": rewritten.append_array(["reward_other_exit","outer_to_inner","inner_recovery","belly_borer_access","borer_crossing"]+main)
			else: rewritten.append(edge_id)
		m.routes[route_name] = rewritten
	m.routes.places_main_trial = main+["crown_approach"]
	m.route_goals.places_main_trial = "gate_ready"
	m.routes.places_normal_journey = normal_prefix+camp_to_c+main+["crown_approach"]
	m.route_goals.places_normal_journey = "gate_ready"
	m.routes.places_boss_entry = Array(m.routes.places_normal_journey)+["arena_entry"]
	m.route_goals.places_boss_entry = "boss"
	m.routes.places_reward_trial = ["places_cavity_exit",str(window.route_ids.main),"places_window_to_seven",str(seven.route_ids.reward),str(seven.route_ids.returning)]+onward_edges+[final_edge,"crown_approach"]
	m.route_goals.places_reward_trial = "gate_ready"
	m.routes.places_reward_journey = normal_prefix+camp_to_c+Array(m.routes.places_reward_trial)
	m.route_goals.places_reward_journey = "gate_ready"
	m.routes.places_outer_trial = ["places_cavity_exit",str(window.route_ids.main),"places_window_to_seven",str(seven.route_ids.outer),str(seven.route_ids.near_west_return)]+old_return_edges
	m.route_goals.places_outer_trial = "camp"
	m.routes.places_failure_return_trial = [str(seven.route_ids.failure_west_return)]+old_return_edges
	m.route_goals.places_failure_return_trial = "camp"
	m.routes.places_window_loop = ["places_cavity_exit",str(window.route_ids.main),str(window.route_ids.outer_descent),str(window.route_ids.lower_inward_return),"places_window_inner_old_crown"]
	m.route_goals.places_window_loop = "E"
	var cache: Dictionary = seven.ports.cache
	m.rewards.append({"id":"places_seven_backside_cache","position":cache.point.duplicate(),"area":str(cache.area),"tier":"medium","claimed":false,"reward_mode":"resources","items":[],"coins":4,"resources":[{"kind":"coin","amount":4},{"kind":"note","amount":1}],"requires":[],"approach_route":"places_reward_trial","return_route":"places_seven_cache_return","return_destination":"new_far_root_and_Boss_approach; not_old_camp","reward_budget":"4coin_OR_1note; actual_accepted_transaction_required"})
	m.routes.places_seven_cache_return = [str(seven.route_ids.returning)]+onward_edges+[final_edge,"crown_approach"]
	m.route_goals.places_seven_cache_return = "gate_ready"
	var claim_edge := OLD._edge_by_id(m,str(seven.route_ids.returning))
	claim_edge.merge({"claim_before_edge":true,"claim_area":str(cache.area),"claim_id":"places_seven_backside_cache"},true)
	_install_stage_routes_and_rewards(m,expansion,before_places,normal_prefix+camp_to_c,final_edge)
	# The complete formal prefix uses the same one-piece rest discovery as v17.
	ENTRY.install(m)
	var displays: Array = m.danger_presentations.duplicate(true)
	LANGUAGE.annotate(m)
	for index: int in displays.size():
		if not displays[index].is_empty(): m.danger_presentations[index] = displays[index]
	_refresh_bounds(m)
	m.choices.exploration_places = {"variant":variant,"order":expansion.order.duplicate(),"window_entry":"C","lower_return":"western_root_window_to_old_backbranch_retry","far_return":"actual_ordered_places_then_Boss_court","map_identity":"root_hollow_loop" if int(m.map_index) == 1 else "crown_crossing","implemented_scope":"candidate_ordered_places_pending_full_world_input_and_visual_review"}
	m.streams.exploration_places = "forest_exploration_places"
	m.stream_positions.exploration_places = rng.position()
	m.exploration_places_contract = {"version":VERSION,"bible_sha256":BIBLE_SHA,"baseline_layout":"forest-bible-world-v15","previous_boss_sector":old_sector,"boss_rebuilt_from_actual_factory":true,"normal_route":"places_normal_journey","old_camp_to_c":camp_to_c.duplicate(),"reward_route":"places_reward_journey","true_lower_destinations":["places_old_retry","prep"],"actual_exit_roles":{"near":"old_tree_through_real_western_root_window","far":"ordered_places_without_crossing_descending_root","failure":"old_tree_through_real_western_root_window"},"automatic_stair_connectors":false,"implemented_places":["old_cavity","places_double_window","places_seven"]+expansion.order,"new_mechanisms":3 if int(m.map_index)==1 else 4,"z_failure_recovery":"actual_existing_exit_fruit_world_hang_behavior_pending_input","topology_signature_scope":"actual_directed_area_relations_including_inherited_core; not_graph_isomorphism_or_FUN","new_macro_topology_variety":"actual_Z_fallen_order_inversion_across_maps_and_seed_choice; map2_backbranch_loop; chained_choice_places_not_full_web","normal_minutes_target":[8,12],"thorough_minutes_target":[15,20],"human_timing":"unverified","map_identities":"map1_hollow_Z_and_fallen_choices; map2_adds_H_R_backlook_canopy_loop; full_region_unfinished","native_verified":false,"production_pool":false,"not_complete_region":true}
	m.topology_signature = _actual_connection_signature(m)
	m.production_pool = false

static func _install_onward_places(m: Dictionary,rng: RunRandomStream,previous: Dictionary) -> Dictionary:
	# Derive a joint-map stream from the actual root seed format. The second
	# map inverts the same draw, so a run gets two real different sequences.
	var root_seed := str(m.seed).trim_suffix("/thorn_forest/map_%s" % m.map_index)
	var order_rng := RunRandomStream.new(root_seed,"forest_exploration_macro_order","joint_maps",VERSION)
	var order_choice := order_rng.next_int(2)
	if int(m.map_index)==2: order_choice = 1-order_choice
	var order: Array = ["places_fallen","places_z"] if order_choice==0 else ["places_z","places_fallen"]
	if int(m.map_index)==2: order.push_front("places_backbranch")
	var stages: Array = []
	var normal: Array = []
	var at: Dictionary = previous
	for id: String in order:
		var raw: Dictionary
		var ordinary_names: Array
		var reward_names: Array
		var return_names: Array
		var exit_name := "onward"
		var entry_name := "entry"
		var coins := 6
		var notes := 2
		match id:
			"places_z":
				raw = PLACES.build("z_descending_return",rng.next_int(2))
				ordinary_names = ["outer","crown_onward"]
				reward_names = ["reward"]
				return_names = ["returning","crown_onward"]
			"places_fallen":
				raw = FALLEN.build(rng.next_int(2))
				ordinary_names = ["main_to_exit"]
				coins = 4
				notes = 1
				reward_names = ["inner_reward"]
				return_names = ["cache_return"]
			"places_backbranch":
				raw = FRUIT.build(rng.next_int(2))
				entry_name = "west_entry"
				exit_name = "east_onward"
				ordinary_names = ["west_to_entry","outer","outer_descent","east_onward"]
				reward_names = ["west_to_entry","reward"]
				return_names = ["returning","outer","outer_descent","east_onward"]
				coins = 5
				notes = 2
		var connector := id+"_arrival"
		var placed := _install_next_place(m,id,raw,at,connector,entry_name)
		var onward: Array = [connector]+_placed_routes(placed,ordinary_names)
		stages.append({"id":id,"placed":placed,"normal":onward,"reward":_placed_routes(placed,reward_names),"returning":_placed_routes(placed,return_names),"connector":connector,"coins":coins,"notes":notes})
		normal.append_array(onward)
		at = placed.ports[exit_name]
	m.streams.exploration_macro_order = "forest_exploration_macro_order"
	m.stream_positions.exploration_macro_order = order_rng.position()
	return {"stages":stages,"normal":normal,"onward":at,"order":order}

static func _placed_routes(placed: Dictionary,names: Array) -> Array:
	var ids: Array = []
	for name: String in names: ids.append(str(placed.route_ids[name]))
	return ids

static func _install_stage_routes_and_rewards(m: Dictionary,expansion: Dictionary,before_places: Array,formal_prefix: Array,final_edge: String) -> void:
	var before: Array = []
	var after: Array = expansion.normal.duplicate()
	for stage: Dictionary in expansion.stages:
		for _edge_id: String in stage.normal: after.pop_front()
		var placed: Dictionary = stage.placed
		var id := str(stage.id)
		var trial := id+"_reward_trial"
		var returning := id+"_cache_return"
		var tail: Array = after+[final_edge,"crown_approach"]
		m.routes[trial] = before_places+before+[stage.connector]+stage.reward+stage.returning+tail
		m.route_goals[trial] = "gate_ready"
		m.routes[id+"_reward_journey"] = formal_prefix+Array(m.routes[trial])
		m.route_goals[id+"_reward_journey"] = "gate_ready"
		m.routes[returning] = stage.returning+tail
		m.route_goals[returning] = "gate_ready"
		var cache: Dictionary = placed.ports.cache
		var claim_id := id+"_cache"
		m.rewards.append({"id":claim_id,"position":cache.point.duplicate(),"area":str(cache.area),"tier":"hard_optional","claimed":false,"reward_mode":"resources","items":[],"coins":int(stage.coins),"resources":[{"kind":"coin","amount":int(stage.coins)},{"kind":"note","amount":int(stage.notes)}],"requires":[],"approach_route":trial,"return_route":returning,"return_destination":"actual_next_place_or_Boss_court","reward_budget":"%scoin_OR_%snote; actual_accepted_transaction_required" % [stage.coins,stage.notes]})
		OLD._edge_by_id(m,str(stage.returning[0])).merge({"claim_before_edge":true,"claim_area":str(cache.area),"claim_id":claim_id},true)
		if id=="places_z":
			m.routes.places_z_inner_trial = before_places+before+[stage.connector,str(placed.route_ids.main),str(placed.route_ids.crown_onward)]+tail
			m.route_goals.places_z_inner_trial = "gate_ready"
			_install_z_recovery(m,placed,[str(placed.route_ids.crown_onward)]+tail)
		elif id=="places_fallen":
			m.routes.places_fallen_failure_trial = [str(placed.route_ids.failure_to_exit)]+tail
			m.route_goals.places_fallen_failure_trial = "gate_ready"
			m.routes.places_fallen_notch_trial = [str(placed.route_ids.notch_to_exit)]+tail
			m.route_goals.places_fallen_notch_trial = "gate_ready"
		elif id=="places_backbranch":
			m.routes.places_backbranch_failure_trial = [str(placed.route_ids.retry),str(placed.route_ids.outer),str(placed.route_ids.outer_descent),str(placed.route_ids.east_onward)]+tail
			m.route_goals.places_backbranch_failure_trial = "gate_ready"
			m.routes.places_backbranch_loop = [str(placed.route_ids.outer),str(placed.route_ids.outer_descent),str(placed.route_ids.lower_retry)]
			m.route_goals.places_backbranch_loop = str(placed.ports.entry.area)
		before.append_array(stage.normal)

static func _install_z_recovery(m: Dictionary,z: Dictionary,tail: Array) -> void:
	# World-specific behavior of an existing, actually rooted exit fruit.
	# No recovery stair or extra floor is generated. The pilot must J until
	# the real231wu range is reached, H, observe actual hang, then J again.
	var fruit_id := str(z.anchors.z_exit_fruit)
	var fruit: Dictionary = {}
	for anchor: Dictionary in m.hook_anchors:
		if str(anchor.id)==fruit_id:
			anchor.hang_enabled = true
			anchor.world_behavior = "Z_low_catch_fixed_hang_escape"
			anchor.fruit_route_bindings.append("available:places_z_fixed_hang_recovery:J_H_J")
			fruit = anchor
	var failure: Dictionary = z.ports.failure
	var low: Dictionary = z.ports.failure_out
	var crown: Dictionary = z.ports.crown
	_edge(m,"places_z_failure_align",str(low.area),str(failure.area),[_walk(str(low.support),failure.point)])
	API._edge(m,"places_z_fixed_hang_recovery",str(failure.area),str(crown.area),"airborne_chain",[failure.point.duplicate(),fruit.position.duplicate(),crown.point.duplicate()])
	m.connections[-1].merge({"places_fixed_hang_recovery":true,"anchor_id":fruit_id,"release_mode":"hang_jump","target_kind":"fixed_fruit","geometry_instance":str(z.id),"from_support_id":str(failure.support),"entry_support_id":str(failure.support),"landing_support_id":str(crown.support),"support_id":str(crown.support),"landing":crown.point.duplicate(),"hook_wait":"actual_distance_within_definition_range_while_held_jump","world_behavior":"existing_z_exit_fruit_hang_enabled_for_low_catch_recovery","native_verified":false},true)
	m.routes.places_z_failure_recovery_trial = [str(z.route_ids.failure_outbound),"places_z_failure_align","places_z_fixed_hang_recovery"]+tail
	m.route_goals.places_z_failure_recovery_trial = "gate_ready"

static func _install_next_place(m: Dictionary,id: String,raw: Dictionary,previous: Dictionary,edge_id: String,entry_name := "entry") -> Dictionary:
	# Author the entrance from actual source support bounds. No fixed map Y,
	# empty-space teleport or automatically generated stepping stones.
	var source := _rect(API._platform_by_id(m,str(previous.support)).rect)
	var raw_entry: Dictionary = raw.ports[entry_name]
	var raw_support: Dictionary = {}
	for row: Dictionary in raw.platforms:
		if str(row.id) == str(raw_entry.support_id): raw_support = row; break
	assert(not raw_support.is_empty())
	var entrance := _rect(raw_support.rect)
	var origin := Vector2(source.end.x+80.0-entrance.position.x,float(previous.point[1])-float(raw_entry.position[1]))
	var placed := EMBED.install(m,id,raw,origin)
	var entry: Dictionary = placed.ports[entry_name]
	var receiver := _rect(API._platform_by_id(m,str(entry.support)).rect)
	var takeoff := Vector2(source.end.x-24.0,source.position.y-18.0)
	var landing := Vector2(receiver.position.x+40.0,receiver.position.y-18.0)
	_edge(m,edge_id,str(previous.area),str(entry.area),[
		_walk(str(previous.support),_pair(takeoff)),
		API._step("jump_gap",takeoff,landing,str(previous.support),str(entry.support)),
		_walk(str(entry.support),entry.point)])
	return placed

static func _actual_connection_signature(m: Dictionary) -> String:
	# The labels of a structural variant are not a topology measurement.
	# Record actual directed landmark relations, including the retained core.
	var links: Dictionary = {}
	for edge: Dictionary in m.connections:
		links[JSON.stringify([str(edge.a),str(edge.b),str(edge.get("condition","open"))])] = true
	var rows: Array = links.keys()
	rows.sort()
	return JSON.stringify(rows).sha256_text()

static func _old_camp_to_c(m: Dictionary) -> Array:
	# Resolve only the three actual old camp families BEFORE adding any new
	# edges. No all-graph shortest path may promote an experimental live lift.
	var candidates: Array = [
		["camp_recovery","belly_borer_access","borer_crossing"],
		["camp_outer_back","outer_to_inner","inner_recovery","belly_borer_access","borer_crossing"],
		["camp_north_back","north_borer_access","borer_crossing"]]
	for route: Array in candidates:
		var at := "camp"
		var valid := true
		for id: String in route:
			var edge := OLD._edge_by_id(m,id)
			if edge.is_empty() or str(edge.a) != at:
				valid = false
				break
			at = str(edge.b)
		if valid and at == "C": return route.duplicate()
	return []

static func _window_geometry() -> Dictionary:
	var raw: Dictionary = WINDOW.build("rooted_double_window").duplicate(true)
	var source := raw.duplicate(true)
	var bodies: Array = []
	for row: Dictionary in raw.platforms:
		var id := str(row.id)
		match id:
			"belly_roof":
				# A hollow's curved outer crown and arched inner ceiling share
				# one source. No rectangular beam plus cosmetic stepped cap.
				_window_arch(bodies,id,[
					[-220.0,-174.0,-110.0],[-156.0,-246.0,-148.0],
					[-60.0,-294.0,-198.0],[48.0,-278.0,-184.0],
					[144.0,-210.0,-132.0],[226.0,-174.0,-110.0]])
			"trunk_above_window":
				# Keep the actual upper-fruit host/lower contact face. A curved
				# narrowing trunk grows above it, not a stack of square tips.
				_window_body(bodies,id,[210.0,-126.0,120.0,32.0],"hollow_bark")
				_window_trunk(bodies,"upper_trunk",[
					[-430.0,308.0,360.0],[-350.0,282.0,362.0],
					[-254.0,238.0,352.0],[-174.0,220.0,348.0],
					[-126.0,210.0,330.0]])
			"trunk_between_windows":
				# Preserve the upper window's true receiving lip; the one
				# curved mid-root then swells and narrows to the lower opening.
				_window_body(bodies,id,[210.0,-24.0,120.0,16.0],"hollow_bark")
				_window_trunk(bodies,"middle_trunk",[
					[-8.0,210.0,330.0],[32.0,184.0,354.0],
					[80.0,174.0,374.0],[124.0,202.0,346.0],
					[140.0,210.0,330.0]])
			"trunk_below_window":
				_window_body(bodies,id,[210.0,420.0,120.0,16.0],"hollow_bark")
				_window_trunk(bodies,"lower_trunk_root",[
					[436.0,210.0,330.0],[476.0,186.0,370.0],
					[512.0,160.0,432.0],[544.0,178.0,462.0]])
			"entry":
				_window_root(bodies,id,[-220.0,18.0,300.0,24.0],[
					[-220.0,64.0],[-140.0,104.0],[-40.0,128.0],[80.0,64.0]])
			"inner_root":
				_window_root(bodies,id,[-310.0,220.0,500.0,24.0],[
					[-310.0,260.0],[-230.0,304.0],[-90.0,332.0],
					[60.0,294.0],[190.0,260.0]])
			"outer_root":
				_window_root(bodies,id,[350.0,300.0,350.0,24.0],[
					[350.0,344.0],[430.0,382.0],[542.0,396.0],
					[638.0,368.0],[700.0,340.0]])
			"outer_sump":
				_window_root(bodies,id,[330.0,460.0,370.0,24.0],[
					[330.0,504.0],[410.0,540.0],[522.0,556.0],
					[620.0,528.0],[700.0,492.0]])
			_:
				row.scene_kind = "living_bough" if bool(row.one_way) else "root_earth"
				bodies.append(row)
	raw.platforms = bodies
	raw.version = "forest-exploration-double-window-v18.2"
	raw.source_geometry_before_derivation = source
	raw.regional_derivation = {"kind":"one_arched_belly_and_curved_trunk_with_two_through_openings","outer_source":"piecewise_curved_crown_trunk_and_asymmetric_root_profiles","sampling_wu":16,"boundary_snap_wu":2,"upper_window":[210,-94,120,70],"lower_window":[210,140,120,280],"preserved_functional_contacts":["entry_top18","upper_lip_top_minus24","upper_fruit_host_210_minus126_120_32","lower_window_ceiling140","lower_window_floor420","inner_root_top220","outer_root_top300"],"new_western_approach_mass":false,"original_factory_untouched":true,"fresh_motor_and_art_required":true}
	raw.source_factory = {"path":"res://scripts/generation/forest_exploration_network.gd","version":raw.version,"sha256":FileAccess.get_sha256("res://scripts/generation/forest_exploration_network.gd")}
	var bounds := Rect2(_point(raw.spawn),Vector2.ONE)
	for row: Dictionary in bodies:
		raw.scene_language[str(row.id)] = str(row.scene_kind)
		bounds = bounds.merge(_rect(row.rect))
	for row: Dictionary in raw.hook_anchors: bounds = bounds.expand(_point(row.position))
	bounds = bounds.grow(32)
	raw.world_bounds = [bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y]
	return raw

static func _window_sample(knots: Array,at: float) -> Vector2:
	for index: int in range(1,knots.size()):
		var a: Array = knots[index-1]
		var b: Array = knots[index]
		if at <= float(b[0]):
			var blend := clampf((at-float(a[0]))/(float(b[0])-float(a[0])),0.0,1.0)
			return Vector2(snappedf(lerpf(float(a[1]),float(b[1]),blend),2.0),snappedf(lerpf(float(a[2]),float(b[2]),blend),2.0))
	var last: Array = knots[-1]
	return Vector2(float(last[1]),float(last[2]))

static func _window_body(rows: Array,id: String,rect: Array,kind: String) -> void:
	rows.append({"id":id,"rect":rect,"one_way":false,"scene_kind":kind})

static func _window_arch(rows: Array,id: String,knots: Array) -> void:
	var start := float(knots[0][0])
	var finish := float(knots[-1][0])
	var count := int(ceil((finish-start)/16.0))
	for index: int in count:
		var x := start+float(index)*16.0
		var width := minf(16.0,finish-x)
		var edge := _window_sample(knots,x+width*0.5)
		_window_body(rows,id if index == count-1 else id+"__arch_%s"%index,[x,edge.x,width,edge.y-edge.x],"hollow_bark")

static func _window_trunk(rows: Array,id: String,knots: Array) -> void:
	var start := float(knots[0][0])
	var finish := float(knots[-1][0])
	var count := int(ceil((finish-start)/16.0))
	for index: int in count:
		var y := start+float(index)*16.0
		var height := minf(16.0,finish-y)
		var edge := _window_sample(knots,y+height*0.5)
		_window_body(rows,id+"__curve_%s"%index,[edge.x,y,edge.y-edge.x,height],"hollow_bark")

static func _window_root(rows: Array,id: String,top: Array,outline: Array) -> void:
	_window_body(rows,id,top.duplicate(),"root_earth")
	var knots: Array = []
	for point: Array in outline: knots.append([point[0],float(top[1])+float(top[3]),point[1]])
	var start := float(top[0])
	var finish := start+float(top[2])
	var count := int(ceil((finish-start)/16.0))
	for index: int in count:
		var x := start+float(index)*16.0
		var width := minf(16.0,finish-x)
		var edge := _window_sample(knots,x+width*0.5)
		_window_body(rows,id+"__wood_%s"%index,[x,edge.x,width,edge.y-edge.x],"root_earth")

static func _install_window_edges(m: Dictionary,window: Dictionary,at_c: Vector2) -> void:
	var entry: Dictionary = window.ports.entry
	var c_body := _rect(API._platform_by_id(m,"hollow__cavity_exit").rect)
	var right_id := "hollow__cavity_right_step"
	var right_body := _rect(API._platform_by_id(m,right_id).rect)
	var entry_body := _rect(API._platform_by_id(m,str(entry.support)).rect)
	var launch := Vector2(c_body.end.x-30,c_body.position.y-18)
	# Stay west of the new roof's left face. Its underside overlaps the
	# standing head at the old step; dropping through that real one-way
	# support clears the underside before ordinary movement enters the belly.
	var right_point := Vector2(minf(right_body.get_center().x,entry_body.position.x-24),right_body.position.y-18)
	var access: Array = []
	var relay := API._platform_by_id(m,"hollow__elbow_return_relay")
	if not relay.is_empty():
		var relay_body := _rect(relay.rect)
		var relay_point := Vector2(minf(relay_body.end.x-24,right_point.x),relay_body.position.y-18)
		access.append(API._step("jump_rise",launch,relay_point,"hollow__cavity_exit","hollow__elbow_return_relay"))
		access.append(API._step("jump_rise",relay_point,right_point,"hollow__elbow_return_relay",right_id))
	else:
		access.append(API._step("jump_rise",launch,right_point,"hollow__cavity_exit",right_id))
	access.append(_drop(right_id,str(entry.support),_pair(right_point),entry.point,[_pair(right_point)]))
	_edge(m,"places_cavity_exit","C",str(entry.area),access)
	OLD._edge_by_id(m,"places_cavity_exit").regional_derivation = {"kind":"actual_old_right_step_and_optional_elbow_relay_before_drop_through_to_new_belly","right_step":right_id,"relay":"hollow__elbow_return_relay" if not relay.is_empty() else "none","new_roof_requires_initial_vertical_drop":true,"midair_standing_waypoints":false,"native_verified":false}
	var outer: Dictionary = window.ports.outer_root
	var descent := OLD._edge_by_id(m,str(window.route_ids.outer_descent))
	descent.kind = "ordinary_sequence"
	descent.steps = [
		_walk(str(window.ports.crown.support),[1980.0,at_c.y-42.0]),
		_drop(str(window.ports.crown.support),str(outer.support),[1980.0,at_c.y-42.0],outer.point,[[1980.0,float(outer.point[1])]])]
	descent.regional_derivation = "drop_through_actual_one_way_crown_west_of_seven_entry; old_east_walkoff_would_land_on_new_entry"
	var lower := OLD._edge_by_id(m,str(window.route_ids.lower_inward_return))
	lower.kind = "hollow_outer_recovery"
	lower.from_port = "R"
	lower.to_port = "D"
	lower.geometry_instance = str(window.id)
	var inner: Dictionary = window.ports.inner_root
	var old_e := _area_point(m,"E")
	_edge(m,"places_window_inner_old_crown",str(inner.area),"E",[
		API._step("jump_gap",Vector2(1218,float(inner.point[1])),Vector2(1168,old_e.y),str(inner.support),"hollow__outer_crown"),
		_walk("hollow__outer_crown",_pair(old_e))])

static func _install_lower_return(m: Dictionary,seven: Dictionary) -> Array:
	# The place owns a real window through its west root. Near/failure reach
	# that exit; the far side instead continues to the new Boss court.
	var west: Dictionary = seven.ports.west_return
	var lip := _rect(API._platform_by_id(m,str(west.support)).rect)
	var source := Vector2(lip.position.x+24,float(west.point[1]))
	var target := Vector2(2210,1092)
	API._area(m,"places_old_retry",Vector2(2180,1092),"KNOWN BROKEN ROOT / UPPER RETRY BRANCH","junction")
	API._area(m,"places_old_recovery",Vector2(2220,1302),"KNOWN BROKEN ROOT / RETURN TO CAMP","junction")
	var steps: Array = [_walk(str(west.support),_pair(source))]
	if source.y > target.y:
		steps.append(API._step("jump_gap",source,target,str(west.support),"bible_backbranch__retry_step"))
	else:
		steps.append(_drop(str(west.support),"bible_backbranch__retry_step",_pair(source),_pair(target),[[2220.0,source.y]]))
	steps.append(_walk("bible_backbranch__retry_step",[2180.0,1092.0]))
	_edge(m,"places_west_window_old_retry",str(west.area),"places_old_retry",steps)
	_edge(m,"places_old_retry_lower_drop","places_old_retry","places_old_recovery",[
		_drop("bible_backbranch__retry_step","bible_backbranch__recovery",[2180.0,1092.0],[2120.0,1302.0],[[2120.0,1092.0]]),
		_walk("bible_backbranch__recovery",[2220.0,1302.0])])
	_edge(m,"places_recovery_weaver","places_old_recovery","bible_web_lower",[
		_walk("bible_backbranch__recovery",[1660.0,1302.0]),
		API._step("jump_rise",Vector2(1660,1302),Vector2(1630,1182),"bible_backbranch__recovery","bible_weaver_lower")])
	var result: Array = ["places_west_window_old_retry","places_old_retry_lower_drop","places_recovery_weaver","bible_web_lower_cross","bible_root_mouth_exit"]
	result.append_array(OLD._route(m,"R" if m.choices.bible_root_connection == "outer_root_east_mouth" else "D","camp"))
	return result

static func _remove_old_boss(m: Dictionary) -> void:
	var body_ids: Array[String] = ["boss_approach"]
	var anchor_ids: Array[String] = ["crown_approach_ring_0"]
	for row: Dictionary in m.boss_geometry.platforms: body_ids.append(str(row.id))
	for row: Dictionary in m.boss_geometry.hook_anchors: anchor_ids.append(str(row.id))
	m.platforms = _without_ids(m.platforms,body_ids)
	m.hook_anchors = _without_ids(m.hook_anchors,anchor_ids)
	m.areas = _without_ids(m.areas,["prep","gate_ready","boss"])
	m.connections = _without_ids(m.connections,["crown_prep","cavity_prep","reward_to_prep","crown_approach","arena_entry"])
	var boughs: Array = []
	for row: Dictionary in m.get("fruit_boughs",[]):
		if str(row.host_support_id) not in body_ids: boughs.append(row)
	m.fruit_boughs = boughs
	m.training_bells = []
	m.erase("practice_bell_contract")

static func _install_boss(m: Dictionary,onward: Dictionary) -> String:
	var shore := _point(onward.point)
	var prep := shore+Vector2(128,0)
	var gate_ready := shore+Vector2(228,0)
	var external := shore+Vector2(288,0)
	API._platform(m,"boss_approach",Rect2(shore.x-96,shore.y+18,384,48),false,"root_earth","places_final_court","wide_boss_observation")
	API._area(m,"prep",prep,"FINAL ROOT / BOSS AHEAD","prep")
	API._area(m,"gate_ready",gate_ready,"FINAL ROOT / LIVING VINE","prep")
	_edge(m,"places_final_prep",str(onward.area),"prep",[_walk("boss_approach",_pair(prep))])
	API._edge(m,"crown_approach","prep","gate_ready","gate_hook",[_pair(prep),_pair(gate_ready)])
	m.connections[-1].anchor_id = "crown_approach_ring_0"
	m.connections[-1].support_id = "boss_approach"
	var fruit := gate_ready+Vector2(-20,-90)
	var stem := fruit+Vector2(0,-26)
	m.hook_anchors.append({"id":"crown_approach_ring_0","position":_pair(fruit),"scene_kind":"copper_growth_ring","structure_id":"places_final_court","fruit_role":"gate","fruit_presentation":"rooted_fruit","fruit_host_support_id":"boss_approach","fruit_stem_root":_pair(stem),"fruit_bough_id":"places_final_gate_bough","fruit_route_bindings":["available:crown_approach:explicit_target"]})
	var root_point := Vector2(gate_ready.x-60,shore.y+18)
	m.fruit_boughs.append({"id":"places_final_gate_bough","host_support_id":"boss_approach","root":_pair(root_point),"points":[_pair(root_point),_pair(root_point+Vector2(10,-64)),_pair(stem)],"attachments":{"crown_approach_ring_0":_pair(stem)},"standing_edge":false,"base_width":10.0})
	var factory := ARENA.new()
	var boss: Dictionary = factory.from_prep(external,1) if int(m.map_index) == 1 else factory.queen_canopy_from_prep(external)
	m.boss_contract = boss.duplicate(true)
	m.boss_geometry = boss.duplicate(true)
	m.boss_arena = boss.boss_arena.duplicate()
	m.boss_approach_origin = _pair(external)
	m.boss_root_supports = boss.get("root_supports",[]).duplicate(true)
	m.platforms.append_array(boss.platforms.duplicate(true))
	m.hook_anchors.append_array(boss.hook_anchors.duplicate(true))
	API._area(m,"boss",_point(boss.safe_return),"FOREST BOSS","boss")
	API._edge(m,"arena_entry","gate_ready","boss","walk",[_pair(gate_ready),boss.safe_return.duplicate()])
	m.vine_gate = {"id":"crown_vine","key_anchor":"crown_approach_ring_0","rect":[external.x-4,shore.y-502,16.0,556.0]}
	m.boss_approach_contract = {"entry_port":str(onward.area),"progression":"old_cavity_then_double_window_then_seven_far_root_then_actual_ordered_choice_places","ordinary_roof_bypass_retained":false,"native_verified":false}
	m.scene_structure_kinds.places_final_court = "bough_group"
	if int(m.map_index) == 1: _practice_bell(m,prep)
	return "places_final_prep"

static func _practice_bell(m: Dictionary,prep: Vector2) -> void:
	var bell := prep+Vector2(-10,-150)
	var tether := bell+Vector2(0,-48)
	m.training_bells.append({"id":"bible_guardian_practice_bell","position":_pair(bell),"motion":{"kind":"pendulum","center":_pair(bell),"radius":[30.0,12.0],"period":3.2},"host_support_id":"boss_approach","structure_id":"places_final_court","tether_root":_pair(tether),"observation_position":_pair(prep),"return_position":_pair(prep),"route_id":"places_final_prep","damage":false,"reward":false,"enemy_clear_required_for_unpressured_practice":true})
	m.practice_bell_contract = {"bell_radius":12.0,"complete_motion_sweep":[bell.x-42,bell.y-24,84.0,48.0],"gate_cast_segment":[_pair(prep),_pair(prep+Vector2(80,-90))],"gate_cast_vertical_clearance_lower_bound":36.0,"standing_player_top":prep.y-18,"standing_body_vertical_clearance_lower_bound":108.0,"observation_to_extreme_center_distance_upper_bound":167.0,"hook_range_source":"resources/player/traversal.tres","existing_enemies_preserved":true,"bell_is_non_damaging_not_an_enemy_free_guarantee":true,"native_verified":false}
	var root_point := prep+Vector2(-80,18)
	m.fruit_boughs.append({"id":"bible_practice_bell_frame","host_support_id":"boss_approach","root":_pair(root_point),"points":[_pair(root_point),_pair(root_point+Vector2(0,-90)),_pair(tether)],"attachments":{},"standing_edge":false,"base_width":10.0})

static func _refresh_bounds(m: Dictionary) -> void:
	var bounds := Rect2(_point(m.spawn),Vector2.ONE)
	for row: Dictionary in m.platforms: bounds = bounds.merge(_rect(row.rect))
	for row: Dictionary in m.hook_anchors: bounds = bounds.expand(_point(row.position))
	bounds = bounds.grow(200)
	m.world_bounds = [bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y]

static func validate(m: Dictionary) -> bool:
	var contract: Variant = m.get("exploration_places_contract")
	if not contract is Dictionary or contract.get("version") != VERSION or contract.get("bible_sha256") != BIBLE_SHA: return false
	if m.get("requires") != ["grapple"] or m.get("production_pool") != false or contract.get("automatic_stair_connectors") != false: return false
	if not m.get("boss_geometry",{}).get("ok",false) or not LANGUAGE.validate(m): return false
	if contract.get("old_camp_to_c",[]).is_empty(): return false
	var supports: Dictionary = {}
	for row: Dictionary in m.platforms: supports[str(row.id)] = row
	for category: String in ["platforms","hook_anchors","areas","connections","enemies","rewards","geometry_instances"]:
		var ids: Dictionary = {}
		for row: Dictionary in m[category]:
			if ids.has(str(row.id)): return false
			ids[str(row.id)] = true
	for name: String in m.routes:
		var at := ""
		for edge_id: String in m.routes[name]:
			var edge := OLD._edge_by_id(m,edge_id)
			if edge.is_empty() or (not at.is_empty() and str(edge.a) != at): return false
			at = str(edge.b)
	for edge: Dictionary in m.connections:
		for key: String in ["from_support_id","entry_support_id","landing_support_id","support_id"]:
			if edge.has(key) and not supports.has(str(edge[key])): return false
	return true

static func _edge(m: Dictionary,id: String,a: String,b: String,steps: Array) -> void:
	var path: Array = []
	for step: Dictionary in steps:
		if path.is_empty() and step.has("takeoff"): path.append(step.takeoff.duplicate())
		path.append(step.landing.duplicate())
	for step: Dictionary in steps:
		if step.get("kind") == "jump_gap": step.hold_to_receiver = true
	API._edge(m,id,a,b,"ordinary_sequence",path,steps)

static func _walk(support: String,landing: Array) -> Dictionary:
	return {"kind":"walk","support_id":support,"landing":landing.duplicate()}

static func _drop(from: String,to: String,takeoff: Array,landing: Array,mouths: Array) -> Dictionary:
	var path: Array = [takeoff.duplicate()]
	for point: Array in mouths: path.append(point.duplicate())
	path.append(landing.duplicate())
	return {"kind":"drop_through","from_support_id":from,"support_id":to,"takeoff":takeoff.duplicate(),"landing":landing.duplicate(),"path":path}

static func _without_ids(rows: Array,ids: Array) -> Array:
	var kept: Array = []
	for row: Dictionary in rows:
		if str(row.id) not in ids: kept.append(row)
	return kept

static func _area_point(m: Dictionary,id: String) -> Vector2:
	for row: Dictionary in m.areas:
		if str(row.id) == id: return _point(row.position)
	return Vector2.ZERO

static func _point(pair: Array) -> Vector2: return Vector2(float(pair[0]),float(pair[1]))
static func _pair(point: Vector2) -> Array: return [point.x,point.y]
static func _rect(row: Array) -> Rect2: return Rect2(float(row[0]),float(row[1]),float(row[2]),float(row[3]))
