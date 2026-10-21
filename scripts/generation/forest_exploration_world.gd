class_name ForestExplorationWorld
extends RefCounted
## A world built from real challenge pieces and joined support surfaces.
## Route dictionaries describe these bodies; they never move a player.
const VERSION := "forest-branching-expedition-v16"
const MODULES := preload("res://scripts/generation/forest_exploration_modules.gd")
const LANGUAGE := preload("res://scripts/generation/forest_scene_language.gd")
const ARENA := preload("res://scripts/generation/forest_boss_arena_factory.gd")
const ECOLOGY := preload("res://scripts/generation/forest_exploration_ecology.gd")
const EASY: Array[String] = ["root_meadow", "mushroom_fork", "root_basin_return"]
const NORMAL: Array[String] = ["side_fruit_crossing", "double_fruit_s", "double_window", "canopy_detour"]
const HARD: Array[String] = ["thorn_side_passage", "backbranch_turn", "crown_hook_relay", "deep_root_switchback"]
const BIBLE_PATH := "res://docs/creative_direction/bibles/2-thorn_forest_region_bible_v2.md"
const BIBLE_SHA := "a7bad8323af64a7be0577132e5d988a6e1b781d9e1ac1639d37f9d65935194e3"

static func build(seed_value: String, map_index: int) -> Dictionary:
	var topology := RunRandomStream.new(seed_value, "forest_branching_topology", "map_%s" % map_index, VERSION)
	var ecology := RunRandomStream.new(seed_value, "forest_branching_ecology", "map_%s" % map_index, VERSION)
	var m := _empty(seed_value, map_index)
	var envelope := MovementCapabilityEnvelope.snapshot(PlayerTuning.load_default())
	var jump_headroom := float(envelope.get("held_jump_height",0.0))+18.0+64.0
	var normal_rotation := topology.next_int(NORMAL.size())
	var hard_rotation := topology.next_int(HARD.size()) if map_index == 1 else 0
	var levels: Array = [700.0,700.0,652.0,700.0,636.0] if map_index == 1 else [1100.0,1100.0,1100.0,908.0,524.0]
	var labels: Array = ["FOREST EDGE / WIDE ROOTS", "BELL ROOT BASIN", "FORKED TREE / INNER AND OUTER", "BROKEN BELL COURT", "GUARDIAN REST"] if map_index == 1 else ["ROOT BAY / TWO TRUNKS", "LOW WINDOWS / OUTER CROWN", "NORTH COURT / DOUBLE LOOP", "DEEP ROOT / LOOK BACK", "CROWN SANCTUARY REST"]
	var hubs: Array[Dictionary] = []
	var main_routes: Array[Array] = []
	var exploration_routes: Array[Array] = []
	var normal_ports: Array[Dictionary] = []
	var hard_ports: Array[Dictionary] = []
	var x := 120.0
	hubs.append(_hub(m, "arrival", Vector2(x,levels[0]), labels[0]))
	m.spawn = hubs[0].point.duplicate()
	m.choices = {"normal_rotation":normal_rotation,"hard_rotation":hard_rotation,"district_modules":[],"branch_heights":[],"crosslink":"lower_root_return" if map_index == 1 else "overlapping_root_and_crown_loops"}
	for district: int in 4:
		var start: Dictionary = hubs[district]
		var next_level: float = levels[district+1]
		var primary: Array[String] = [EASY[district%EASY.size()] if map_index == 1 else EASY[(district+3)%EASY.size()], EASY[(district+2+topology.next_int(2))%EASY.size()]]
		if district == 0: primary[0] = "root_meadow" if map_index == 1 else "root_basin_return"
		if primary[1] == primary[0]: primary[1] = EASY[(district+1)%EASY.size()]
		var shared_choice: bool = district == 1
		var pod_camp: bool = shared_choice and map_index == 2
		if shared_choice: primary[1] = "backlook_fruit_cache" if map_index == 1 else "borrow_pod_crossing"
		elif map_index == 2 and district == 2: primary[1] = "double_window"
		var first_raw := MODULES.build(primary[0])
		var first_origin := Vector2(x+240.0, levels[district])
		var first := _module(m, first_raw, first_origin, "district_%s_main_a" % district)
		var second_origin := Vector2(first_origin.x+float(first_raw.width)+96.0, levels[district])
		var second_raw := MODULES.build(primary[1])
		var second := _module(m, second_raw, second_origin, "district_%s_main_b" % district)
		x = float(second.exit.point[0])+460.0
		var finish: Dictionary
		if pod_camp:
			var observation: Dictionary = second.local_routes.pod_approach.to
			finish = observation.duplicate(true)
			finish.area = "hub_2"
			_area(m,"hub_2",_point(finish.point),labels[2],"merchant")
			# The camp is the actual observing root. Placement still clears the
			# complete module, including the exit east of that root.
			x = second_origin.x+float(second_raw.width)+64.0-240.0
		else:
			finish = _hub(m,"hub_%s" % (district+1),Vector2(x,next_level),labels[district+1])
		hubs.append(finish)
		var main: Array = [_connect(m,"district_%s_main_enter" % district,start,first.entry),str(first.edge),_connect(m,"district_%s_main_join" % district,first.exit,second.entry)]
		if pod_camp:
			main.append(str(second.local_routes.pod_approach.edge))
			main.append(_connect(m,"district_%s_main_leave" % district,second.local_routes.pod_approach.to,finish))
			_edge(m,"pod_east_root_back_to_camp",str(second.exit.area),str(finish.area),"ordinary_sequence",[second.exit.point,finish.point],[{"kind":"walk","takeoff":second.exit.point.duplicate(),"landing":finish.point.duplicate(),"from_support_id":str(second.exit.support),"support_id":str(finish.support)}])
			_reverse_edge(m,m.connections[-1])
		else:
			main.append(str(second.edge))
			main.append(_connect(m,"district_%s_main_leave" % district,second.exit,finish))
		if district == 0:
			var hook_id := "entry_side_fruit"
			var pull_from := _point(first.exit.point)
			var pull_to := _point(second.entry.point)
			_anchor(m,hook_id,(pull_from+pull_to)*0.5+Vector2(0.0,-96.0),str(first.exit.support),pull_from+Vector2(16.0,18.0),"main",false)
			_edge(m,"first_safe_side_hook",str(first.exit.area),str(second.entry.area),"short_hook_crossing",[first.exit.point,second.entry.point])
			m.connections[-1].merge({"anchor_id":hook_id,"from_support_id":str(first.exit.support),"entry_support_id":str(first.exit.support),"landing":second.entry.point.duplicate(),"landing_support_id":str(second.entry.support),"support_id":str(second.entry.support),"ordinary_alternative":"district_0_main_join","native_verified":false})
			main[2] = "first_safe_side_hook"
			m.expedition_hints.append({"position":[pull_from.x-80.0,pull_from.y-118.0],"radius":220.0,"text":"One short side hook, then a broad receiving root.\nLower roots remain an ordinary way across."})
		main_routes.append(main)
		# Upper bank is a different physical branch. Its return mouth lies east
		# of the departure, so both decisions reunite at a recognisable hub.
		var normal_id: String = str(second_raw.id) if shared_choice else NORMAL[(district+normal_rotation)%NORMAL.size()]
		var normal_raw: Dictionary = second_raw if shared_choice else MODULES.build(normal_id)
		var main_highest := minf(_route_highest(first_raw)+first_origin.y,_route_highest(second_raw)+second_origin.y)
		var normal_origin: Vector2 = second_origin if shared_choice else Vector2(first_origin.x+192.0,main_highest-jump_headroom-_solid_bottom(normal_raw)-float(topology.next_int(2))*32.0)
		m.choices.branch_heights.append(float(levels[district])-normal_origin.y)
		var branch: Dictionary = second if shared_choice else _module(m,normal_raw,normal_origin,"district_%s_explore" % district)
		var enter: String
		var leave: String
		var outward: Array
		var onward: Array
		var reward_port: Dictionary = branch.reward if shared_choice else branch.exit
		if shared_choice:
			enter = _alias_route(m,"district_%s_explore_enter" % district,start,branch.entry,main.slice(0,3))
			outward = [enter]+Array(branch.reward_fallback if pod_camp else branch.reward_out)
			if pod_camp:
				var drop: Dictionary = _edge_by_id(m,str(branch.reward_return[0])).steps[0].duplicate(true)
				var camp_steps: Array = [drop,{"kind":"walk","takeoff":drop.landing.duplicate(),"landing":finish.point.duplicate(),"from_support_id":str(finish.support),"support_id":str(finish.support)}]
				leave = "district_%s_explore_other_mouth" % district
				_edge(m,leave,str(reward_port.area),str(finish.area),"ordinary_sequence",[reward_port.point,finish.point],camp_steps)
				onward = [leave]
				m.routes.borrow_pod_fixed_out = [enter]+Array(branch.reward_fallback)
				m.routes.borrow_pod_live_out = [enter]+Array(branch.reward_out)
				m.routes.borrow_pod_to_camp = onward.duplicate()
				m.borrow_pod_camp = {"area_id":"hub_2","support_id":str(finish.support),"instance_id":str(branch.instance),"ordinary_approach":str(second.local_routes.pod_approach.edge),"reward_area":str(reward_port.area),"return_route":"borrow_pod_to_camp","separate_camp_slab":false,"live_exchange_native":"unverified"}
			else:
				leave = "district_%s_explore_other_mouth" % district
				var cache_back: Dictionary = _edge_by_id(m,str(branch.reward_return[0]))
				_edge(m,leave,str(cache_back.a),str(cache_back.b),"ordinary_sequence",cache_back.path.duplicate(true),cache_back.steps.duplicate(true))
				onward = [leave,str(branch.edge),str(main[-1])]
		else:
			enter = _connect(m,"district_%s_explore_enter" % district,start,branch.entry)
			leave = _drop_return(m,"district_%s_explore_other_mouth" % district,branch.exit,finish)
			outward = [enter,str(branch.edge)]
			onward = [leave]+_ordinary_route(m,str(_edge_by_id(m,leave).b),str(finish.area))
		var explore: Array = outward+onward
		exploration_routes.append(explore)
		normal_ports.append(branch)
		_reward(m,"district_%s_explore_cache" % district,reward_port,"medium",int(normal_raw.risk_reward.coins) if shared_choice else 4,maxi(1,int(normal_raw.risk_reward.notes)) if shared_choice else 1)
		m.routes["explore_%s_out" % district] = outward
		m.routes["explore_%s_return" % district] = onward
		m.macro_loops["district_%s" % district] = {"departure":str(start.area),"ordinary":main.duplicate(),"exploration":explore.duplicate(),"rejoin":str(finish.area),"return_to_departure":_reverse_route(main)}
		if shared_choice:
			m.macro_loops["district_%s" % district].merge({"choice_kind":"live_reward_to_observation_camp" if pod_camp else "cache_loop_to_same_entry_then_lower_onward","decision_node":str(branch.local_routes.pod_approach.to.area) if pod_camp else str(branch.entry.area),"reward_area":str(reward_port.area),"actual_reward_return":str(finish.area) if pod_camp else str(branch.entry.area),"shares_main_geometry":true},true)
			if pod_camp:
				m.macro_loops["district_%s" % district].return_to_departure = []
				m.macro_loops["district_%s" % district].return_status = "no_inverse_of_160wu_drop_authored; use_the_real_reward_to_camp_loop"
		# The high reward is on the actual hard receiver, never at the public
		# rejoin. Its descent has no ladder up from the ordinary path.
		var hard_id: String = HARD[(district+hard_rotation)%HARD.size()] if map_index == 1 else ["thorn_side_passage","backbranch_turn","deep_root_switchback","crown_hook_relay"][district]
		var hard_raw := MODULES.build(hard_id)
		var hard_origin := Vector2(normal_origin.x+96.0,normal_origin.y+(_all_route_highest(normal_raw) if shared_choice else _route_highest(normal_raw))-jump_headroom-_solid_bottom(hard_raw)-64.0)
		var challenge := _module(m,hard_raw,hard_origin,"district_%s_master" % district)
		# A right-facing entry is approached from the real other bank of its
		# lower module; crossing that module's trunk at entry height is not a path.
		var hard_approach: Dictionary = branch.reward if shared_choice else branch.entry
		var hard_prefix: Array = outward.duplicate() if shared_choice else [enter]
		if not shared_choice and _entry_side(m.geometry_instances[-1]) < 0.0:
			hard_approach = branch.exit
			hard_prefix.append(str(branch.edge))
		var hard_enter := _connect(m,"district_%s_master_climb" % district,hard_approach,challenge.entry)
		challenge.exit.return_floor_y = maxf(levels[district],next_level)+320.0
		var hard_return := _drop_return(m,"district_%s_master_other_exit" % district,challenge.exit,finish)
		hard_ports.append(challenge)
		if not (map_index == 2 and district == 2):
			_reward(m,"district_%s_master_cache" % district,challenge.exit,"high",18,2)
		m.routes["master_%s_out" % district] = hard_prefix+[hard_enter,str(challenge.edge)]
		m.routes["master_%s_return" % district] = [hard_return]+_ordinary_route(m,str(_edge_by_id(m,hard_return).b),str(finish.area))
		m.macro_loops["master_%s" % district] = {"departure":str(start.area),"reward_area":str(challenge.exit.area),"onward":str(finish.area),"entry_route":"master_%s_out" % district,"return_route":"master_%s_return" % district,"risk_reward":{"coins":18,"notes":2,"public_path_has_reward":false}}
		m.choices.district_modules.append({"main":primary,"explore":normal_id,"master":hard_id})
		m.expedition_hints.append({"position":[float(start.point[0])-96.0,float(start.point[1])-104.0],"radius":240.0,"text":"Roots: gentle onward route.\nUpper bough: supplies. Highest branch: rare cache."})
		if district == 0:
			# A genuine, supported first fruit is safe to pause on. It is the
			# only tutorial attachment opting into fixed-anchor jump release.
			var at := _point(start.point)+Vector2(128.0,-96.0)
			_anchor(m,"entry_observation_fruit",at,str(start.support),_point(start.point)+Vector2(128.0,18.0),"tutorial",true)
			m.expedition_hints.append({"position":[float(start.point[0])-96.0,float(start.point[1])-168.0],"radius":210.0,"text":"Hook the first fruit and pause.\nPress jump to leave; broad roots catch you."})
	# The returns belong to different pieces of the world: a downward L-root
	# hollow in map1, and a live canopy loop returning onto the actual camp root
	# in map2. Retire the former long, empty generic underpass.
	if map_index == 1:
		var hollow := _install_l_hollow(m,hubs[2],main_routes[2])
		m.routes.root_loop = hollow.loop
		exploration_routes[2] = hollow.exploration
	else:
		var pod: Dictionary = normal_ports[1]
		var observation: Dictionary = pod.local_routes.pod_approach.to
		var from_camp := _connect(m,"camp_observation_window",hubs[2],observation)
		m.routes.borrow_pod_live_loop = [from_camp,str(pod.reward_out[-1])]+Array(m.routes.borrow_pod_to_camp)
		var fixed_observation: Dictionary = pod.local_routes.fixed_fruit_approach.to
		var to_fixed := _connect(m,"camp_fixed_fruit_walk",observation,fixed_observation)
		_edge(m,"borrow_pod_actual_defeat",str(observation.area),str(observation.area),"live_pod_defeat",[observation.point,observation.point])
		m.connections[-1].merge({"geometry_instance":str(pod.instance),"authored_slot_id":"borrow_pod","encounter_id":"exploration__"+str(pod.instance)+"__forest_swing_pod","target_kind":"live_enemy","from_support_id":str(observation.support),"support_id":str(observation.support),"landing":observation.point.duplicate(),"landing_support_id":str(observation.support),"native_verified":false,"optional":true})
		m.routes.borrow_pod_fixed_loop = [from_camp,to_fixed,str(pod.reward_fallback[-1])]+Array(m.routes.borrow_pod_to_camp)
		m.routes.root_loop = m.routes.borrow_pod_fixed_loop.duplicate()
		m.macro_loops.lower_root = {"departure":"hub_2","onward":"hub_2","edges":m.routes.root_loop.duplicate(),"height":192.0,"map_identity":"canopy_reward_to_real_camp_root","live_alternative":"borrow_pod_live_loop","native":"unverified"}
	if map_index == 2:
		var folds := _install_crown_folds(m,hubs[2],normal_ports[1],main_routes[2],topology.next_int(2))
		exploration_routes[2] = folds.exploration
		m.routes.crown_return_loop = folds.short_return.duplicate()
		m.macro_loops.overlapping_crown = {"from":str(folds.seven_reward),"to":str(hubs[2].area),"edges":folds.short_return.duplicate(),"crosses_district":1,"same_as_map1":false,"known_receiver":"crown_z_catch_window","shape":"Z_then_7_outer_loop","native":"unverified"}
	m.camp_area = str(hubs[2].area)
	m.merchant_position = hubs[2].point.duplicate()
	for area: Dictionary in m.areas:
		if str(area.id) == m.camp_area: area.role = "merchant"
	m.forest_landmarks = [{"id":"forked_root_tree","support_id":str(hubs[1].support),"position":hubs[1].point.duplicate()},{"id":"split_crown_tree" if map_index == 2 else "old_bell_court_tree","support_id":str(hubs[3].support),"position":hubs[3].point.duplicate()}]
	var fast: Array = []
	var growth: Array = []
	for district: int in 4:
		fast.append_array(main_routes[district])
		growth.append_array(exploration_routes[district])
	var final := _install_boss(m,hubs[4])
	fast.append_array(final)
	growth.append_array(final)
	m.routes.fast = fast
	m.routes.growth = growth
	m.routes.high_return = Array(m.routes.master_0_out)+Array(m.routes.master_0_return)+main_routes[1]
	m.routes.change_mind = main_routes[0]+exploration_routes[1]
	m.route_goals = {}
	if map_index == 1:
		m.routes.backlook_trial = m.routes.change_mind.duplicate()
		m.routes.l_hollow_trial = main_routes[0]+main_routes[1]+Array(m.routes.root_loop)
		m.route_goals = {"backlook_trial":"hub_2","l_hollow_trial":"hub_2"}
	else:
		m.routes.borrow_pod_fixed_trial = main_routes[0]+Array(m.routes.borrow_pod_fixed_out)+Array(m.routes.borrow_pod_to_camp)
		m.routes.borrow_pod_live_trial = main_routes[0]+Array(m.routes.borrow_pod_live_out)+Array(m.routes.borrow_pod_to_camp)
		var kill_prefix: Array = Array(m.routes.borrow_pod_live_out).slice(0,Array(m.routes.borrow_pod_live_out).size()-1)
		m.routes.borrow_pod_kill_trial = main_routes[0]+kill_prefix+["borrow_pod_actual_defeat","camp_fixed_fruit_walk",str(normal_ports[1].reward_fallback[-1])]+Array(m.routes.borrow_pod_to_camp)
		m.route_goals = {"borrow_pod_fixed_trial":"hub_2","borrow_pod_live_trial":"hub_2","borrow_pod_kill_trial":"hub_2"}
		var prefix: Array = main_routes[0]+main_routes[1]
		m.routes.crown_z_trial = prefix+Array(m.routes.crown_z_loop)
		m.routes.crown_7_trial = prefix+Array(m.routes.crown_7_out)+Array(m.routes.crown_7_short_return)
		m.routes.crown_7_long_trial = prefix+Array(m.routes.crown_7_out)+Array(m.routes.crown_7_long_return)
		for trial: String in ["crown_z_trial","crown_7_trial","crown_7_long_trial"]: m.route_goals[trial] = "hub_2"
	m.routes.borer = fast.duplicate()
	m.change_mind_contract = {"decision_node":str(m.macro_loops.district_1.decision_node),"planned_goal":"gate_ready","chosen_goal":str(hubs[2].area),"actual_input":"unverified"}
	_install_discoveries(m,normal_ports,hard_ports,map_index)
	ECOLOGY.install(m)
	LANGUAGE.annotate(m)
	_install_thorn_surfaces(m)
	var bounds := Rect2(_point(m.spawn),Vector2.ONE)
	for platform: Dictionary in m.platforms: bounds = bounds.merge(_rect(platform.rect))
	for anchor: Dictionary in m.hook_anchors: bounds = bounds.expand(_point(anchor.position))
	bounds = bounds.grow(240.0)
	m.world_bounds = [bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y]
	m.stream_positions = m.get("stream_positions",{})
	m.stream_positions.merge({"topology":topology.position(),"ecology":ecology.position()})
	m.exploration_contract = {"version":VERSION,"bible_path":BIBLE_PATH,"bible_sha256":BIBLE_SHA,
		"map_identity":"horizontal_roots_and_returning_hollows" if map_index == 1 else "overlapping_inner_outer_crown_loops",
		"main_route":"broad supported easy pieces; long H/R chains optional","master_reward_is_separate":true,
		"districts":4,"ordinary_rise_max":64.0,"module_library":MODULES.VERSION,
		"native_verified":false,"player_acceptance":"unverified","production_pool":false}
	m.topology_signature = topology_signature(m)
	return m

static func _empty(seed_value: String,index: int) -> Dictionary:
	return {"version":"thorn-forest-region-v2","layout_version":VERSION,"region":"thorn_forest","map_index":index,"seed":seed_value,
		"family":"branching_root_labyrinth" if index == 1 else "split_crown_double_loop","layout_id":"root_network" if index == 1 else "crown_network","fallback_id":"","requires":["grapple"],"production_pool":false,
		"player_tuning_hash":FileAccess.get_sha256("res://config/player_tuning.json"),"traversal_hash":FileAccess.get_sha256("res://resources/player/traversal.tres"),
		"platforms":[],"hook_anchors":[],"areas":[],"connections":[],"rewards":[],"pickups":[],"enemies":[],"enemy_drops":{},"dangers":[],"geometry_instances":[],"nodes":[{"id":"forest_v16","mirrored":false}],
		"merchant_id":"root_camp","shop":{"item":"health_blue","price":5,"stock":1},"shot_latch_plan":{"version":1,"latches":[]},"terminal_exits":[],
		"streams":{"topology":"forest_branching_topology","ecology":"forest_branching_ecology","version":VERSION},"routes":{},"macro_loops":{},
		"fruit_boughs":[],"forest_shortcuts":[],"forest_discoveries":[],"training_bells":[],"expedition_hints":[],"danger_presentations":[],"scene_structure_kinds":{},
		"admission":{"geometry":"independent_branching_candidate","motor":"unverified","seams":"unverified","visual":"unverified"}}

static func _hub(m: Dictionary,id: String,point: Vector2,label: String) -> Dictionary:
	var support := id+"__wide_root"
	_platform(m,support,Rect2(point+Vector2(-160.0,18.0),Vector2(320.0,64.0)),false,id)
	_area(m,id,point,label,"tutorial" if id == "arrival" else "junction")
	m.scene_structure_kinds[id] = "rootland"
	return {"area":id,"point":_pair(point),"support":support}

static func _module(m: Dictionary,raw: Dictionary,origin: Vector2,id: String) -> Dictionary:
	var support_map: Dictionary = {}
	var anchor_map: Dictionary = {}
	for row: Dictionary in raw.platforms:
		var mapped := id+"__"+str(row.id)
		support_map[str(row.id)] = mapped
		var rect := _rect(row.rect)
		rect.position += origin
		_platform(m,mapped,rect,bool(row.one_way),id)
	for row: Dictionary in raw.hook_anchors:
		var mapped := id+"__"+str(row.id)
		anchor_map[str(row.id)] = mapped
		_anchor(m,mapped,_point(row.position)+origin,str(support_map[row.host_support_id]),_point(row.stem_root)+origin,"optional",bool(row.get("hang_enabled",false)))
	var danger_indices: Array[int] = []
	for local: Array in raw.dangers:
		var rect := _rect(local)
		rect.position += origin
		danger_indices.append(m.dangers.size())
		m.dangers.append([rect.position.x,rect.position.y,rect.size.x,rect.size.y])
	var entry_id := id+"_in"
	var exit_id := id+"_out"
	var start := _point(raw.spawn)+origin
	var goal := _point(raw.goal)+origin
	_area(m,entry_id,start,str(raw.identity),"junction")
	_area(m,exit_id,goal,"RECEIVING BOUGH / "+str(raw.difficulty).to_upper(),"challenge_reward" if raw.difficulty == "hard" else "junction")
	var entry := {"area":entry_id,"point":_pair(start),"support":str(support_map[raw.entry_support_id]),"instance":id}
	var exit := {"area":exit_id,"point":_pair(goal),"support":str(support_map[raw.exit_support_id]),"instance":id}
	var instance := {"id":id,"factory":"res://scripts/generation/forest_exploration_modules.gd","geometry_version":str(raw.version),"module_id":str(raw.id),"difficulty":str(raw.difficulty),"local_geometry":raw.duplicate(true),"translation":_pair(origin),"platform_id_map":support_map,"anchor_id_map":anchor_map,"danger_indices":danger_indices,"admission":"actual_Motor_unverified"}
	m.geometry_instances.append(instance)
	m.scene_structure_kinds[id] = "root_hollow" if "tunnel" in str(raw.id) or "window" in str(raw.id) else "bough_relay" if raw.difficulty == "hard" else "rootland"
	var edge_id := id+"_cross"
	var steps := _steps(raw.steps,origin,support_map)
	if raw.difficulty == "hard":
		_edge(m,edge_id,entry_id,exit_id,"airborne_chain",[_pair(start),_pair(goal)])
		m.connections[-1].merge({"geometry_instance":id,"landing":_pair(goal),"landing_support_id":exit.support,"from_support_id":entry.support,"action_program":raw.action_program.duplicate(true),"continuous_airborne":false,"optional_lower_alternative":true,"post_landing_steps":steps,"entry_support_id":entry.support})
		if not steps.is_empty():
			var receiver: Dictionary = steps[0]
			m.connections[-1].landing = receiver.get("takeoff",receiver.landing).duplicate()
			m.connections[-1].landing_support_id = str(receiver.get("from_support_id",receiver.get("support_id",exit.support)))
		if raw.has("departure"):
			m.connections[-1].departure = _translated_step(raw.departure,origin,support_map)
		if raw.has("approach_steps"):
			m.connections[-1].approach_steps = _steps(raw.approach_steps,origin,support_map)
			m.connections[-1].action_start = _pair(_point(raw.action_start)+origin)
			m.connections[-1].entry_support_id = str(support_map[raw.approach_steps[-1].support_id])
	else:
		_edge(m,edge_id,entry_id,exit_id,"ordinary_sequence",[_pair(start),_pair(goal)],steps)
		# The new pod/L pieces descend 160wu and provide authored recovery.
		# A mechanically reversed drop would invent an unavailable 160wu jump.
		if not raw.has("interaction_contract") and not raw.has("corridor_contract"):
			_reverse_edge(m,m.connections[-1])
		if raw.has("reward_position") and not raw.has("choice_contract") and not raw.has("interaction_contract") and not raw.has("branch_reward_contract"):
			m.pickups.append({"id":id+"_root_coin","kind":"coin","amount":int(raw.risk_reward.coins),"position":_pair(_point(raw.reward_position)+origin),"claimed":false,"support_id":str(support_map[raw.reward_support_id])})
			if int(raw.risk_reward.notes)>0:
				m.pickups.append({"id":id+"_root_note","kind":"note","amount":int(raw.risk_reward.notes),"position":_pair(_point(raw.reward_position)+origin+Vector2(20,0)),"claimed":false,"support_id":str(support_map[raw.reward_support_id])})
	for surface: Dictionary in raw.get("danger_surfaces",[]):
		var hazard_index: int = danger_indices[int(surface.danger_index)]
		while m.danger_presentations.size() <= hazard_index: m.danger_presentations.append({})
		m.danger_presentations[hazard_index] = {"scene_kind":"thorn_growth","facing":str(surface.face),"host_support_id":str(support_map[surface.host_support_id]),"host_structure_id":id}
	var result := {"entry":entry,"exit":exit,"edge":edge_id,"instance":id,"origin":_pair(origin),"local_routes":{}}
	if raw.has("branch_reward_contract"):
		var branch_contract: Dictionary = raw.branch_reward_contract
		var reward_port := _local_port(m,id,"reward",_point(raw.reward_position)+origin,str(support_map[raw.reward_support_id]),[entry,exit])
		result.reward = reward_port
		var out_id := id+"__reward_route"
		var back_id := id+"__reward_return"
		_edge(m,out_id,entry_id,str(reward_port.area),"ordinary_sequence",[entry.point,reward_port.point],_steps(raw.routes[branch_contract.reward_route],origin,support_map))
		_edge(m,back_id,str(reward_port.area),entry_id,"ordinary_sequence",[reward_port.point,entry.point],_steps(raw.routes[branch_contract.return_route],origin,support_map))
		result.reward_out = [out_id]
		result.reward_return = [back_id]
	if raw.has("choice_contract") or raw.has("interaction_contract"):
		var contract: Dictionary = raw.get("choice_contract",raw.get("interaction_contract",{}))
		var reward_port := _local_port(m,id,"reward",_point(raw.reward_position)+origin,str(support_map[raw.reward_support_id]),[entry,exit])
		result.reward = reward_port
		var known: Array = [entry,exit,reward_port]
		for name: String in contract.route_ports:
			var port: Dictionary = contract.route_ports[name]
			var a := _local_port(m,id,name+"_from",_point(port.start)+origin,str(support_map[port.start_support]),known)
			known.append(a)
			var b := _local_port(m,id,name+"_to",_point(port.goal)+origin,str(support_map[port.goal_support]),known)
			known.append(b)
			var route_id := id+"__"+name
			_edge(m,route_id,str(a.area),str(b.area),"ordinary_sequence",[a.point,b.point],_steps(raw.routes[name],origin,support_map))
			result.local_routes[name] = {"edge":route_id,"from":a,"to":b}
		if raw.has("choice_contract"):
			result.reward_out = [str(result.local_routes[contract.reward_route].edge)]
			result.reward_return = [str(result.local_routes[contract.return_route].edge)]
		else:
			var observation: Dictionary = result.local_routes[contract.approach_route].to
			var fixed_observation: Dictionary = result.local_routes[contract.fallback_approach_route].to
			var live_id := id+"__borrow_live_pod"
			_hook_exchange(m,live_id,observation,reward_port,"live_hook_crossing")
			m.connections[-1].merge({"geometry_instance":id,"authored_slot_id":str(contract.enemy_slot),"encounter_id":"exploration__"+id+"__forest_swing_pod","target_kind":"live_enemy","fallback_edge_id":id+"__fixed_fruit_exchange"})
			_hook_exchange(m,id+"__fixed_fruit_exchange",fixed_observation,reward_port,"short_hook_crossing")
			m.connections[-1].merge({"anchor_id":str(anchor_map.fallback_fruit),"release_mode":"hang_jump","target_kind":"fixed_fruit","geometry_instance":id})
			result.reward_out = [str(result.local_routes[contract.approach_route].edge),live_id]
			result.reward_fallback = [str(result.local_routes[contract.fallback_approach_route].edge),id+"__fixed_fruit_exchange"]
			result.reward_return = [str(result.local_routes[contract.return_route].edge)]
	return result

static func _local_port(m: Dictionary,instance: String,key: String,point: Vector2,support: String,known: Array) -> Dictionary:
	for port: Dictionary in known:
		if str(port.support) == support and _point(port.point).is_equal_approx(point): return port
	var area := instance+"__"+key
	_area(m,area,point,"ROOT WINDOW / "+key.to_upper(),"junction")
	return {"area":area,"point":_pair(point),"support":support,"instance":instance}

static func _hook_exchange(m: Dictionary,id: String,from: Dictionary,to: Dictionary,kind: String) -> void:
	_edge(m,id,str(from.area),str(to.area),kind,[from.point,to.point])
	m.connections[-1].merge({"from_support_id":str(from.support),"entry_support_id":str(from.support),"landing":to.point.duplicate(),"landing_support_id":str(to.support),"support_id":str(to.support),"native_verified":false,"optional":true})

static func _steps(rows: Array,origin: Vector2,supports: Dictionary) -> Array:
	var result: Array = []
	for row: Dictionary in rows:
		var translated := _translated_step(row,origin,supports)
		# Existing pilot contract: an open crossing retains held input until
		# its real receiving footprint is reached. Ceiling release still applies.
		if str(translated.get("kind","")) == "jump_gap": translated.hold_to_receiver = true
		result.append(translated)
	return result

static func _standing_support(m: Dictionary,point: Vector2) -> String:
	# Reuse the actual continuous receiving body before creating another slab
	# on top of it. The collision consumer may otherwise report the original
	# solid while the route incorrectly names a redundant one-way duplicate.
	for one_way: bool in [false,true]:
		for platform: Dictionary in m.platforms:
			if bool(platform.one_way) != one_way: continue
			var rect := _rect(platform.rect)
			if absf(rect.position.y-point.y-18.0)<0.01 and point.x-12.0>=rect.position.x and point.x+12.0<=rect.end.x:
				return str(platform.id)
	return ""

static func _solid_floor_point(m: Dictionary,point: Vector2) -> Vector2:
	var nearest := point
	var distance := 24.01
	for bank: Dictionary in m.platforms:
		if bool(bank.one_way): continue
		var solid := _rect(bank.rect)
		if solid.size.x<24.0 or absf(solid.position.y-point.y-18.0)>0.01: continue
		var x := clampf(point.x,solid.position.x+12.0,solid.end.x-12.0)
		if absf(x-point.x)<distance:
			distance = absf(x-point.x)
			nearest.x = x
	return nearest

static func _receiving_bough(m: Dictionary,id: String,point: Vector2,width: float = 128.0) -> String:
	var existing := _standing_support(m,point)
	if not existing.is_empty(): return existing
	var bough := Rect2(point+Vector2(-width*0.5,18.0),Vector2(width,16.0))
	# A same-height one-way laid over a solid can win the floor contact because
	# of its margin. Keep the connector in the actual gap, with full-body
	# support at its authored waypoint, rather than duplicating either bank.
	for bank: Dictionary in m.platforms:
		if bool(bank.one_way): continue
		var solid := _rect(bank.rect)
		if absf(solid.position.y-bough.position.y)>0.01: continue
		if solid.end.x<=point.x-12.0 and solid.end.x>bough.position.x:
			var right := bough.end.x
			bough.position.x = solid.end.x
			bough.size.x = right-bough.position.x
		elif solid.position.x>=point.x+12.0 and solid.position.x<bough.end.x:
			bough.size.x = solid.position.x-bough.position.x
	_platform(m,id,bough,true,id)
	return id

static func _translated_step(row: Dictionary,origin: Vector2,supports: Dictionary) -> Dictionary:
	var output := row.duplicate(true)
	for key: String in ["takeoff","landing"]:
		if output.has(key): output[key] = _pair(_point(output[key])+origin)
	for key: String in ["support_id","from_support_id"]:
		if output.has(key): output[key] = str(supports.get(str(output[key]),str(output[key])))
	if output.has("path"):
		for index: int in output.path.size(): output.path[index] = _pair(_point(output.path[index])+origin)
	return output

static func _connect(m: Dictionary,id: String,from: Dictionary,to: Dictionary) -> String:
	var original_start := _point(from.point)
	var start := original_start
	var finish := _point(to.point)
	var source_rect := _rect(_support(m,str(from.support)).rect)
	var target_rect := _rect(_support(m,str(to.support)).rect)
	var steps: Array = []
	var support := str(from.support)
	# A descending connector must leave the solid's actual side first. A
	# diagonal interpolation from its centre would place the first body inside.
	if finish.y > start.y+64.0 and not bool(_support(m,support).one_way):
		var outward := source_rect.end.x+40.0 if finish.x >= start.x else source_rect.position.x-40.0
		var lip := Vector2(outward,start.y)
		var lip_id := id+"__departure_lip"
		lip_id = _receiving_bough(m,lip_id,lip,160.0)
		steps.append({"kind":"walk","takeoff":_pair(start),"landing":_pair(lip),"from_support_id":support,"support_id":lip_id})
		start = lip
		support = lip_id
	var rise: bool = finish.y < start.y-0.1
	var direction := 1.0 if finish.x >= start.x else -1.0
	var landing := finish
	var approach := finish
	var footprint_entry := false
	var fruit_shaft := false
	if rise and start.y-finish.y > 96.0 and to.has("instance"):
		for instance: Dictionary in m.geometry_instances:
			if str(instance.id) != str(to.instance): continue
			var footprint := _rect(instance.local_geometry.world_bounds)
			footprint.position += _point(instance.translation)
			direction = _entry_side(instance)
			landing.x = footprint.position.x-64.0 if direction > 0.0 else footprint.end.x+64.0
			# A junction's ordinary route leaves east along the ground before
			# jumping. Put its optional ascent over the resting junction itself,
			# not beside the first ordinary landing where it intercepts the arc.
			if not from.has("instance"): landing.x = original_start.x
			else:
				for source_instance: Dictionary in m.geometry_instances:
					if str(source_instance.id) != str(from.instance) or not source_instance.local_geometry.has("interaction_contract") or not str(from.area).ends_with("__reward"): continue
					var source_bounds := _rect(source_instance.local_geometry.world_bounds)
					source_bounds.position += _point(source_instance.translation)
					# Manual fruit release and the live pod share this complete
					# receiving canopy. A higher optional staircase must stay outside
					# its hook/jump arc rather than above the reward itself.
					landing.x = maxf(landing.x,source_bounds.end.x+64.0) if direction < 0.0 else minf(landing.x,source_bounds.position.x-64.0)
					fruit_shaft = landing.x>original_start.x
			approach = Vector2(landing.x,minf(start.y,finish.y+64.0))
			footprint_entry = true
			break
	elif rise and not bool(_support(m,str(to.support)).one_way):
		landing.x = target_rect.position.x+32.0 if direction > 0.0 else target_rect.end.x-32.0
		approach = Vector2(target_rect.position.x-40.0 if direction > 0.0 else target_rect.end.x+40.0,minf(start.y,finish.y+64.0))
	var count := maxi(1,maxi(ceili(absf(approach.x-start.x)/144.0),ceili(absf(approach.y-start.y)/64.0)))
	if fruit_shaft:
		# The fruit is just beyond the receiver's right edge. A continuous
		# reward-height bridge would block the real upward hook ray. Leave a
		# 64wu shaft, and make the optional hard departure a genuine held jump.
		var takeoff := Vector2(source_rect.end.x-32.0,start.y)
		steps.append({"kind":"walk","takeoff":_pair(start),"landing":_pair(takeoff),"from_support_id":support,"support_id":support})
		var receiving := Vector2(source_rect.end.x+144.0,start.y)
		var receiving_id := _receiving_bough(m,id+"__fruit_shaft_receiver",receiving,160.0)
		steps.append({"kind":"jump_gap","takeoff":_pair(takeoff),"landing":_pair(receiving),"from_support_id":support,"support_id":receiving_id,"hold_to_receiver":true})
		start = receiving
		support = receiving_id
	if footprint_entry and not is_equal_approx(start.x,approach.x):
		# First get outside the entire upper module while still below its
		# lowest solid. A diagonal staircase otherwise cuts through its catch.
		var side_count := maxi(1,ceili(absf(approach.x-start.x)/144.0))
		var side_start := start
		for index: int in range(1,side_count+1):
			var point := Vector2(lerpf(side_start.x,approach.x,float(index)/float(side_count)),side_start.y)
			var target := id+"__outside_approach_%s" % index
			target = _receiving_bough(m,target,point,160.0)
			steps.append({"kind":"walk","takeoff":_pair(start),"landing":_pair(point),"from_support_id":support,"support_id":target})
			start = point
			support = target
		count = maxi(1,ceili(absf(approach.y-start.y)/64.0))
	var previous := start
	for index: int in range(1,count+1):
		var point := start.lerp(approach,float(index)/float(count))
		if index<count or approach!=finish: point = _solid_floor_point(m,point)
		if footprint_entry and count > 1 and approach.y < start.y:
			# Keep the first bough completely above the resting player's head,
			# including its underside. Equal divisions could make it only 57wu
			# high and overlap the respawn body despite a clear standing endpoint.
			point.y = start.y-64.0-(start.y-approach.y-64.0)*float(index-1)/float(count-1)
		var target := str(to.support)
		if index < count or approach != finish:
			target = id+"__step_%s" % index
			target = _receiving_bough(m,target,point)
		# A shallow descending root is traversed on foot. Jumping for a 4.5wu
		# step launched the player into the next hub's optional ascent column.
		var kind := "jump_rise" if point.y < previous.y-0.1 else "walk" if point.y-previous.y<=64.0 else "jump_gap"
		steps.append({"kind":kind,"takeoff":_pair(previous),"landing":_pair(point),"from_support_id":support,"support_id":target,"hold_to_receiver":kind == "jump_gap"})
		previous = point
		support = target
	if approach != finish:
		var first_target := str(to.support)
		if footprint_entry:
			first_target = id+"__outside_lip"
			first_target = _receiving_bough(m,first_target,landing,160.0)
		steps.append({"kind":"jump_rise","takeoff":_pair(previous),"landing":_pair(landing),"from_support_id":support,"support_id":first_target})
		if footprint_entry:
			var bridge_count := maxi(1,ceili(absf(finish.x-landing.x)/144.0))
			previous = landing
			support = first_target
			for index: int in range(1,bridge_count+1):
				var point := landing.lerp(finish,float(index)/float(bridge_count))
				if index<bridge_count: point = _solid_floor_point(m,point)
				var target := str(to.support)
				if index < bridge_count:
					target = id+"__entry_bough_%s" % index
					target = _receiving_bough(m,target,point,160.0)
				steps.append({"kind":"walk","takeoff":_pair(previous),"landing":_pair(point),"from_support_id":support,"support_id":target})
				previous = point
				support = target
		else:
			steps.append({"kind":"walk","takeoff":_pair(landing),"landing":_pair(finish),"from_support_id":str(to.support),"support_id":str(to.support)})
	_edge(m,id,str(from.area),str(to.area),"ordinary_sequence",[_pair(original_start),_pair(finish)],steps)
	_reverse_edge(m,m.connections[-1])
	return id

static func _entry_side(instance: Dictionary) -> float:
	var raw: Dictionary = instance.local_geometry
	var start := _point(raw.spawn)
	var bounds := _rect(raw.world_bounds)
	for direction: float in [1.0,-1.0]:
		var x := bounds.position.x-40.0 if direction > 0.0 else bounds.end.x+40.0
		var sweep := Rect2(Vector2(minf(x,start.x)-12.0,start.y-18.0),Vector2(absf(x-start.x)+24.0,36.0))
		var clear := true
		for obstacle: Dictionary in raw.platforms:
			if not bool(obstacle.one_way) and sweep.intersects(_rect(obstacle.rect).grow(-0.01)):
				clear = false; break
		if clear: return direction
	return 1.0

static func _route_highest(raw: Dictionary) -> float:
	var y := float(raw.spawn[1])
	for step: Dictionary in raw.steps:
		for key: String in ["takeoff","landing"]:
			if step.has(key): y = minf(y,float(step[key][1]))
	return y

static func _all_route_highest(raw: Dictionary) -> float:
	var y := _route_highest(raw)
	for route_name: String in raw.routes:
		for step: Dictionary in raw.routes[route_name]:
			for key: String in ["takeoff","landing"]:
				if step.has(key): y = minf(y,float(step[key][1]))
	return y

static func _alias_route(m: Dictionary,id: String,from: Dictionary,to: Dictionary,route: Array) -> String:
	var steps: Array = []
	for edge_id: String in route: steps.append_array(_edge_by_id(m,edge_id).steps.duplicate(true))
	_edge(m,id,str(from.area),str(to.area),"ordinary_sequence",[from.point,to.point],steps)
	_reverse_edge(m,m.connections[-1])
	return id

static func _solid_bottom(raw: Dictionary) -> float:
	var y := 0.0
	for platform: Dictionary in raw.platforms:
		if not bool(platform.one_way): y = maxf(y,float(platform.rect[1])+float(platform.rect[3]))
	return y

static func _drop_return(m: Dictionary,id: String,from: Dictionary,to: Dictionary) -> String:
	var start := _point(from.point)
	var finish := _point(to.point)
	var steps: Array = []
	var path: Array = [_pair(start)]
	var receiver := to
	if from.has("instance"):
		# Find the first REAL lower support, considering the complete assembled
		# world. Never demand a fall through the ordinary or exploration floor.
		var instance: Dictionary = {}
		for row: Dictionary in m.geometry_instances:
			if str(row.id) == str(from.instance): instance = row; break
		var footprint := _rect(instance.local_geometry.world_bounds)
		footprint.position += _point(instance.translation)
		var leftward := start.x < footprint.get_center().x
		var chosen := _return_receiver(m,start,footprint,leftward,str(from.instance))
		if chosen.is_empty():
			# An unresolved advanced return remains a visible candidate failure;
			# it does not acquire a fabricated through-floor route.
			_edge(m,id,str(from.area),str(to.area),"unverified_return",[_pair(start),_pair(finish)])
			m.connections[-1].failure_reason = "no_body_clear_first_real_return_support"
			return id
		receiver = chosen
		finish = _point(receiver.point)
		var lip := Vector2(finish.x,start.y)
		var support := str(from.support)
		var count := maxi(1,ceili(absf(lip.x-start.x)/144.0))
		var previous := start
		for index: int in range(1,count+1):
			var point := start.lerp(lip,float(index)/float(count))
			var target := id+"__receiver_side_extension_%s" % index
			# Extend OUTWARD from the reward receiver, never toward the departure
			# across the action void. This only reaches the open return column.
			_platform(m,target,Rect2(point+Vector2(-88.0,18.0),Vector2(176.0,20.0)),true,id)
			steps.append({"kind":"walk","takeoff":_pair(previous),"landing":_pair(point),"from_support_id":support,"support_id":target})
			previous = point
			support = target
		steps.append({"kind":"drop_through","takeoff":_pair(lip),"landing":_pair(finish),"path":[_pair(lip),_pair(finish)],"from_support_id":support,"support_id":str(receiver.support)})
		path.append(_pair(lip))
	else:
		var lip := Vector2(finish.x,start.y)
		var lip_id := id+"__lip"
		_platform(m,lip_id,Rect2(lip+Vector2(-56.0,18.0),Vector2(112.0,20.0)),true,id)
		steps.append({"kind":"walk","takeoff":_pair(start),"landing":_pair(lip),"from_support_id":str(from.support),"support_id":lip_id})
		steps.append({"kind":"drop_through","takeoff":_pair(lip),"landing":_pair(finish),"path":[_pair(lip),_pair(finish)],"from_support_id":lip_id,"support_id":str(receiver.support)})
		path.append(_pair(lip))
	path.append(_pair(finish))
	_edge(m,id,str(from.area),str(receiver.area),"ordinary_sequence",path,steps)
	m.connections[-1].return_only = true
	m.connections[-1].no_return_bridge_inside_challenge = true
	m.connections[-1].first_real_receiver = str(receiver.support)
	return id

static func _return_receiver(m: Dictionary,start: Vector2,footprint: Rect2,leftward: bool,excluded: String) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var ports: Array[Dictionary] = []
	for instance: Dictionary in m.geometry_instances:
		if str(instance.id) == excluded or str(instance.difficulty) == "hard": continue
		var raw: Dictionary = instance.local_geometry
		var offset := _point(instance.translation)
		for kind: String in ["entry","exit"]:
			var point := _point(raw.spawn if kind == "entry" else raw.goal)+offset
			var support_id := str(instance.platform_id_map[raw.entry_support_id if kind == "entry" else raw.exit_support_id])
			ports.append({"area":str(instance.id)+("_in" if kind == "entry" else "_out"),"point":_pair(point),"support":support_id})
	for area: Dictionary in m.areas:
		var support_id := str(area.id)+"__wide_root"
		if not _support(m,support_id).is_empty(): ports.append({"area":str(area.id),"point":area.position,"support":support_id})
	for port: Dictionary in ports:
		var point := _point(port.point)
		var support_id := str(port.support)
		if (leftward and point.x+12.0 >= footprint.position.x) or (not leftward and point.x-12.0 <= footprint.end.x) or point.y <= start.y+64.0: continue
		if bool(_support(m,support_id).one_way): continue
		var body_column := Rect2(Vector2(point.x-12.0,start.y-18.0),Vector2(24.0,point.y-start.y+36.0))
		var horizontal := Rect2(Vector2(minf(start.x,point.x)-12.0,start.y-18.0),Vector2(absf(point.x-start.x)+24.0,36.0))
		var clear := true
		for obstacle: Dictionary in m.platforms:
			if bool(obstacle.one_way): continue
			var rect := _rect(obstacle.rect).grow(-0.01)
			if horizontal.intersects(rect) or (str(obstacle.id) != support_id and body_column.intersects(rect)):
				clear = false; break
		if clear:
			var selected := port.duplicate(true)
			selected.distance = absf(point.x-start.x)
			candidates.append(selected)
	candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.distance)<float(b.distance))
	return candidates[0] if not candidates.is_empty() else {}

static func _ordinary_route(m: Dictionary,from: String,to: String) -> Array:
	if from == to: return []
	var queue: Array = [{"at":from,"route":[]}]
	var seen: Dictionary = {from:true}
	while not queue.is_empty():
		var current: Dictionary = queue.pop_front()
		for edge: Dictionary in m.connections:
			if edge.kind != "ordinary_sequence" or str(edge.a) != str(current.at) or seen.has(str(edge.b)): continue
			var route: Array = Array(current.route)+[str(edge.id)]
			if str(edge.b) == to: return route
			seen[str(edge.b)] = true
			queue.append({"at":str(edge.b),"route":route})
	return []

static func _edge_by_id(m: Dictionary,id: String) -> Dictionary:
	for row: Dictionary in m.connections:
		if str(row.id) == id: return row
	return {}

static func _install_l_hollow(m: Dictionary,camp: Dictionary,main_route: Array) -> Dictionary:
	var raw := MODULES.build("thorn_l_root_turn")
	var bottom := float(camp.point[1])+18.0
	for instance: Dictionary in m.geometry_instances:
		if str(instance.id) in ["district_2_main_a","district_2_main_b"]:
			bottom = maxf(bottom,float(instance.translation[1])+_solid_bottom(instance.local_geometry))
	# A real gap west of the camp admits a controlled descent. The complete
	# upright root lies below the ordinary pieces, with 64wu between solids.
	var origin := Vector2(float(camp.point[0])-264.0,bottom+256.0)
	var piece := _module(m,raw,origin,"district_2_l_side")
	var l_instance: Dictionary = m.geometry_instances[-1]
	var support_map: Dictionary = l_instance.platform_id_map
	var award := _local_port(m,str(piece.instance),"elbow_reward",_point(raw.reward_position)+origin,str(support_map[raw.reward_support_id]),[piece.entry,piece.exit])
	var mouth_point := Vector2(float(piece.entry.point[0]),float(camp.point[1]))
	var mouth_support := ""
	var first_floor := INF
	for floor: Dictionary in m.platforms:
		var floor_rect := _rect(floor.rect)
		var y := floor_rect.position.y-18.0
		if bool(floor.one_way) and y>float(camp.point[1])+0.1 and y<=float(camp.point[1])+64.0 and y<first_floor and mouth_point.x-12.0>=floor_rect.position.x and mouth_point.x+12.0<=floor_rect.end.x:
			first_floor = y
			mouth_support = str(floor.id)
	if not mouth_support.is_empty():
		mouth_point.y = first_floor
		_edge(m,"l_hollow_descent",str(camp.area),str(piece.entry.area),"ordinary_sequence",[camp.point,_pair(mouth_point),piece.entry.point],[{"kind":"walk","takeoff":camp.point.duplicate(),"landing":_pair(mouth_point),"from_support_id":str(camp.support),"support_id":mouth_support},{"kind":"drop_through","takeoff":_pair(mouth_point),"landing":piece.entry.point.duplicate(),"path":[_pair(mouth_point),piece.entry.point.duplicate()],"from_support_id":mouth_support,"support_id":str(piece.entry.support)}])
	else:
		_corridor_edge(m,"l_hollow_descent",camp,piece.entry,[_point(camp.point),mouth_point,_point(piece.entry.point)])
	var down := "l_hollow_descent"
	var to_award: Array = _steps(raw.steps.slice(0,4),origin,support_map)
	to_award.append({"kind":"walk","takeoff":to_award[-1].landing.duplicate(),"landing":award.point.duplicate(),"from_support_id":str(award.support),"support_id":str(award.support)})
	_edge(m,"l_hollow_elbow_to_reward",str(piece.entry.area),str(award.area),"ordinary_sequence",[piece.entry.point,award.point],to_award)
	_edge(m,"l_hollow_reward_return",str(award.area),str(piece.entry.area),"ordinary_sequence",[award.point,piece.entry.point],_steps(raw.routes.returning,origin,support_map))
	m.connections[-1].merge({"claim_before_edge":true,"claim_area":str(award.area),"claim_id":"district_2_explore_cache"})
	# Keep the ascent out of both the entry descent and the raw recovery's
	# final held-jump arc. The lower root has a separate west mouth.
	var return_base := _open_port(m,"l_hollow_west_return",Vector2(float(camp.point[0])-400.0,float(piece.entry.point[1])),"WEST ROOT / RETURN TO THE KNOWN CAMP")
	var to_return := _connect(m,"l_hollow_west_mouth",piece.entry,return_base)
	var cap := _open_port(m,"l_hollow_west_return_cap",Vector2(float(return_base.point[0]),float(camp.point[1])),"WEST RETURN / JUMP ACROSS THE OPEN DESCENT")
	var up := _corridor_edge(m,"l_hollow_side_return_to_camp",return_base,cap,[_point(return_base.point),_point(cap.point)])
	var lip_point := Vector2(float(piece.entry.point[0])-64.0,float(camp.point[1]))
	_platform(m,"l_hollow_return_lip",Rect2(lip_point+Vector2(-32.0,18.0),Vector2(64.0,16.0)),true,"l_hollow_return")
	var lip := _local_port(m,"l_hollow","return_lip",lip_point,"l_hollow_return_lip",[])
	var to_lip := _connect(m,"l_hollow_return_to_lip",cap,lip)
	var camp_rect := _rect(_support(m,str(camp.support)).rect)
	var camp_landing := Vector2(camp_rect.position.x+32.0,float(camp.point[1]))
	_edge(m,"l_hollow_return_over_open_mouth",str(lip.area),str(camp.area),"ordinary_sequence",[lip.point,_pair(camp_landing),camp.point],[{"kind":"jump_gap","takeoff":lip.point.duplicate(),"landing":_pair(camp_landing),"from_support_id":str(lip.support),"support_id":str(camp.support),"hold_to_receiver":true},{"kind":"walk","takeoff":_pair(camp_landing),"landing":camp.point.duplicate(),"from_support_id":str(camp.support),"support_id":str(camp.support)}])
	var outward: Array = [down,"l_hollow_elbow_to_reward"]
	var returning: Array = ["l_hollow_reward_return",to_return,up,to_lip,"l_hollow_return_over_open_mouth"]
	m.routes.explore_2_out = outward
	m.routes.explore_2_return = returning+main_route
	for cache: Dictionary in m.rewards:
		if str(cache.id) == "district_2_explore_cache":
			cache.merge({"position":award.point.duplicate(),"area":str(award.area),"support_id":str(award.support),"coins":int(raw.risk_reward.coins),"resources":[{"kind":"coin","amount":int(raw.risk_reward.coins)},{"kind":"note","amount":1}],"approach_route":"explore_2_out","return_route":"explore_2_return"},true)
	var former := _edge_by_id(m,"district_2_explore_other_mouth")
	for key: String in ["claim_before_edge","claim_area","claim_id"]: former.erase(key)
	var pickups: Array = []
	for pickup: Dictionary in m.pickups:
		if not str(pickup.id).begins_with(str(piece.instance)+"_root_"): pickups.append(pickup)
	m.pickups = pickups
	var journey: Array = outward+returning+main_route
	m.macro_loops.district_2.merge({"exploration":journey.duplicate(),"choice_kind":"downward_L_hollow_reward_returns_to_camp_before_onward","decision_node":str(camp.area),"reward_area":str(award.area),"actual_reward_return":str(camp.area),"shares_main_geometry":false},true)
	m.macro_loops.lower_root = {"departure":str(camp.area),"onward":str(camp.area),"edges":outward+returning,"height":origin.y-float(camp.point[1]),"map_identity":"root_elbow_side_hollow","shape":"L","native":"unverified"}
	m.l_hollow = {"instance_id":str(piece.instance),"entry_area":str(piece.entry.area),"reward_area":str(award.area),"departure":str(camp.area),"entry_kind":"side_descent","return_kind":"actual_elbow_reverse_and_side_recovery","ordinary_main_forced":false,"native":"unverified"}
	return {"loop":outward+returning,"exploration":journey}

static func _install_crown_folds(m: Dictionary,camp: Dictionary,pod: Dictionary,main_route: Array,entry_variant: int = 0) -> Dictionary:
	var pod_bounds: Rect2
	for instance: Dictionary in m.geometry_instances:
		if str(instance.id) == str(pod.instance):
			pod_bounds = _rect(instance.local_geometry.world_bounds)
			pod_bounds.position += _point(instance.translation)
	var column := pod_bounds.end.x+40.0
	var mouth_point := Vector2(column,float(camp.point[1]))
	var mouth_support := _receiving_bough(m,"crown_fold_mouth__bough",mouth_point,160.0)
	var mouth := _local_port(m,"crown_folds","mouth",mouth_point,mouth_support,[])
	var camp_link := _connect(m,"camp_to_crown_fold_mouth",camp,mouth)
	var z_raw := MODULES.build("thorn_z_root_switchback")
	var z_origin := Vector2(column-40.0,float(camp.point[1])+256.0)
	for platform: Dictionary in m.platforms:
		var solid := _rect(platform.rect)
		if not bool(platform.one_way) and solid.position.x<z_origin.x+1408.0 and solid.end.x>z_origin.x-160.0:
			z_origin.y = maxf(z_origin.y,solid.end.y+192.0)
	var z := _module(m,z_raw,z_origin,"district_2_z_side")
	var z_instance: Dictionary = m.geometry_instances[-1]
	var z_supports: Dictionary = z_instance.platform_id_map
	var down := _corridor_edge(m,"crown_z_descent",mouth,z.entry,[mouth_point,_point(z.entry.point)])
	var up_base := _local_port(m,str(z.instance),"east_return_base",_point(z.entry.point)+Vector2(96.0,0.0),str(z.entry.support),[z.entry])
	var to_up := _connect(m,"crown_z_return_mouth",z.entry,up_base)
	var up := _corridor_edge(m,"crown_z_ascent",up_base,mouth,[_point(up_base.point),Vector2(float(up_base.point[0]),mouth_point.y),mouth_point])
	var return_to_camp: Array = [to_up,up,camp_link+"_back"]
	var z_out: Array = [camp_link,down]+Array(z.reward_out)
	var z_back: Array = Array(z.reward_return)+return_to_camp
	var z_claim := _edge_by_id(m,str(z.reward_return[0]))
	z_claim.merge({"claim_before_edge":true,"claim_area":str(z.reward.area),"claim_id":"district_2_explore_cache"},true)
	for cache: Dictionary in m.rewards:
		if str(cache.id) == "district_2_explore_cache":
			cache.merge({"position":z.reward.point.duplicate(),"area":str(z.reward.area),"support_id":str(z.reward.support),"coins":int(z_raw.risk_reward.coins),"resources":[{"kind":"coin","amount":int(z_raw.risk_reward.coins)},{"kind":"note","amount":1}],"approach_route":"explore_2_out","return_route":"explore_2_return"},true)
	var old_return := _edge_by_id(m,"district_2_explore_other_mouth")
	for key: String in ["claim_before_edge","claim_area","claim_id"]: old_return.erase(key)
	m.routes.explore_2_out = z_out
	m.routes.explore_2_return = z_back+main_route
	m.routes.crown_z_loop = z_out+z_back
	m.macro_loops.district_2.merge({"exploration":z_out+z_back+main_route,"choice_kind":"downward_Z_inner_reward_or_outer_7_fold","decision_node":str(camp.area),"reward_area":str(z.reward.area),"actual_reward_return":str(camp.area),"shares_main_geometry":false},true)
	# The 7 fold lies east and lower: its complete left recovery footprint is
	# 232wu east of the Z catch. Their solid roots never occupy the same body.
	var seven_raw := MODULES.build("thorn_7_root_fold")
	var seven_origin := z_origin+Vector2(1800.0,576.0)
	var seven := _module(m,seven_raw,seven_origin,"district_3_7_side")
	var seven_instance: Dictionary = m.geometry_instances[-1]
	var seven_supports: Dictionary = seven_instance.platform_id_map
	var outer: String
	var seven_prefix: Array
	if entry_variant == 0:
		outer = _connect(m,"z_lower_root_to_7_upper",z.exit,seven.entry)
		seven_prefix = [str(z.edge),outer]
	else:
		var middle := _local_port(m,str(z.instance),"outer_middle_window",z_origin+Vector2(1072.0,270.0),str(z_supports.middle_root),[])
		_edge(m,"z_outer_middle_approach",str(z.entry.area),str(middle.area),"ordinary_sequence",[z.entry.point,middle.point],_steps(z_raw.steps.slice(0,4),z_origin,z_supports))
		outer = _corridor_edge(m,"z_middle_window_to_7_upper",middle,seven.entry,[_point(middle.point),z_origin+Vector2(1320.0,270.0),z_origin+Vector2(1320.0,558.0),_point(seven.entry.point)])
		seven_prefix = ["z_outer_middle_approach",outer]
		# The lower root remains the other real onward connection in this seed.
		_connect(m,"z_lower_root_to_7_upper",z.exit,seven.entry)
	var seven_out: Array = [camp_link,down]+seven_prefix+Array(seven.reward_out)
	m.rewards.append({"id":"crown_7_cache","position":seven.reward.point.duplicate(),"area":str(seven.reward.area),"tier":"medium","claimed":false,"reward_mode":"resources","items":[],"coins":int(seven_raw.risk_reward.coins),"resources":[{"kind":"coin","amount":int(seven_raw.risk_reward.coins)},{"kind":"note","amount":1}],"requires":[],"support_id":str(seven.reward.support),"approach_route":"crown_7_out","return_route":"crown_7_short_return"})
	# Long return really climbs the authored 7, returns across its upper root,
	# then traverses the Z lower thorn in reverse before its known recovery.
	var lower_reverse: Array = [{"kind":"walk","landing":_pair(z_origin+Vector2(784.0,558.0)),"support_id":str(z.exit.support)}]
	lower_reverse.append({"kind":"jump_gap","takeoff":_pair(z_origin+Vector2(784.0,558.0)),"landing":_pair(z_origin+Vector2(608.0,558.0)),"from_support_id":str(z.exit.support),"support_id":str(z.exit.support),"hold_to_receiver":true})
	lower_reverse.append_array(_steps(z_raw.routes.returning.slice(2),z_origin,z_supports))
	_edge(m,"crown_z_lower_recovery",str(z.exit.area),str(z.entry.area),"ordinary_sequence",[z.exit.point,z.entry.point],lower_reverse)
	var long_return: Array = Array(seven.reward_return)+["z_lower_root_to_7_upper_back","crown_z_lower_recovery"]+return_to_camp
	_edge_by_id(m,str(seven.reward_return[0])).merge({"claim_before_edge":true,"claim_area":str(seven.reward.area),"claim_id":"crown_7_cache"},true)
	# The short return reaches the first actual 7 recovery root, then opens
	# west onto the known Z catch. It avoids repeating the Z lower thorn.
	_edge(m,"seven_cache_to_lower_mouth",str(seven.reward.area),str(seven.exit.area),"ordinary_sequence",[seven.reward.point,seven.exit.point],_steps(seven_raw.steps.slice(4),seven_origin,seven_supports))
	m.connections[-1].merge({"claim_before_edge":true,"claim_area":str(seven.reward.area),"claim_id":"crown_7_cache"})
	var first_root_step: Dictionary = {}
	for step: Dictionary in seven_raw.routes.returning:
		if str(step.kind) == "jump_rise": first_root_step = step; break
	var west := _local_port(m,str(seven.instance),"west_return_window",_point(first_root_step.landing)+seven_origin,str(seven_supports[first_root_step.support_id]),[])
	var to_window: Array = [{"kind":"walk","landing":_pair(seven_origin+Vector2(32.0,270.0)),"support_id":str(seven.exit.support)},_translated_step(first_root_step,seven_origin,seven_supports)]
	_edge(m,"seven_lower_to_west_window",str(seven.exit.area),str(west.area),"ordinary_sequence",[seven.exit.point,west.point],to_window)
	var catch_window := _local_port(m,str(z.instance),"catch_window",z_origin+Vector2(1376.0,814.0),str(z_supports["catch"]),[])
	var short_bridge := _connect(m,"seven_claimed_west_gate",west,catch_window)
	var shortcut_edge := _edge_by_id(m,short_bridge)
	shortcut_edge.condition = "opened:crown_fold_return"
	shortcut_edge.shortcut_id = "crown_fold_return"
	var reverse_gate := _edge_by_id(m,short_bridge+"_back")
	reverse_gate.condition = "opened:crown_fold_return"
	reverse_gate.shortcut_id = "crown_fold_return"
	# The entry bridge is a substantial root above this door. Preserve the
	# original entrance as a 64wu one-way recovery window at the 7 entrance, so the authored
	# long return can rise beside the upper root; west of it, a solid ceiling
	# prevents the higher recovery root from jumping over the lower door.
	_solidify_fold_return_roof(m,z_origin,seven_origin)
	m.forest_shortcuts.append({"id":"crown_fold_return","opened_key":"crown_fold_return","unlock_reward_id":"crown_7_cache","rect":[seven_origin.x-180.0,seven_origin.y+64.0,24.0,224.0],"from_area":str(west.area),"to_area":str(catch_window.area),"return_route":"crown_7_short_return","long_return_route":"crown_7_long_return"})
	_edge(m,"crown_z_catch_recovery",str(catch_window.area),str(z.entry.area),"ordinary_sequence",[catch_window.point,z.entry.point],_steps(z_raw.routes.recovery,z_origin,z_supports))
	var short_return: Array = ["seven_cache_to_lower_mouth","seven_lower_to_west_window",short_bridge,"crown_z_catch_recovery"]+return_to_camp
	m.routes.crown_7_out = seven_out
	m.routes.crown_7_short_return = short_return
	m.routes.crown_7_long_return = long_return
	m.choices.fold_entry = "z_lower_east_root" if entry_variant == 0 else "z_middle_east_window"
	m.crown_folds = {"z_instance":str(z.instance),"seven_instance":str(seven.instance),"inner_reward":str(z.reward.area),"outer_reward":str(seven.reward.area),"known_return_receiver":str(catch_window.area),"closed_gate":"crown_fold_return","door_frame":"solid_64wu_existing_upper_root","recovery_window":[seven_origin.x-64.0,seven_origin.y,64.0,16.0],"ordinary_main_forced":false,"native":"unverified"}
	return {"exploration":z_out+z_back+main_route,"short_return":short_return,"seven_reward":str(seven.reward.area)}

static func _solidify_fold_return_roof(m: Dictionary,z_origin: Vector2,seven_origin: Vector2) -> void:
	var window_left := seven_origin.x-64.0
	var windows: Array[Dictionary] = []
	for row: Dictionary in m.platforms:
		var root := _rect(row.rect)
		if not bool(row.one_way) or absf(root.position.y-seven_origin.y)>0.01 or root.end.x<=z_origin.x+1280.0 or root.position.x>=seven_origin.x: continue
		if root.position.x>=window_left: continue
		var right := minf(root.end.x,window_left)
		row.one_way = false
		row.rect = [root.position.x,root.position.y,right-root.position.x,64.0]
		row.scene_kind = "root_earth"
		row.surface_role = "root_top"
		if root.end.x>window_left:
			windows.append({"id":str(row.id)+"__recovery_window","rect":Rect2(window_left,root.position.y,root.end.x-window_left,16.0),"structure":str(row.structure_id)})
	for window: Dictionary in windows:
		_platform(m,str(window.id),window.rect,true,str(window.structure))

static func _crown_crosslink(m: Dictionary,from: Dictionary,to: Dictionary) -> Array:
	var start := _point(from.point)
	var end := _point(to.point)
	var corridor := _return_corridor(m,start,end)
	if corridor.is_empty():
		_edge(m,"crown_crosslink_unresolved",str(from.area),str(to.area),"unverified_return",[from.point,to.point])
		return ["crown_crosslink_unresolved"]
	var a := _open_port(m,"crown_crosslink_east",Vector2(float(corridor.east),float(corridor.y)),"INNER TREE / RETURN TOWARD A KNOWN WINDOW")
	var b := _open_port(m,"crown_crosslink_west",Vector2(float(corridor.west),float(corridor.y)),"INNER WINDOW / FIRST TREE BELOW")
	# Real open columns lead below the intervening roots. The previous solid
	# hubs swallowed existing windows, and a fixed-height bridge crossed catches.
	var enter := _corridor_edge(m,"crown_crosslink_climb",from,a,[start,Vector2(float(corridor.east),start.y),_point(a.point)])
	var cross := _connect(m,"crown_crosslink_bridge",a,b)
	var drop := _corridor_edge(m,"crown_crosslink_other_mouth",b,to,[_point(b.point),Vector2(float(corridor.west),end.y),end])
	m.routes.crown_crosslink_journey = [enter,cross,drop]
	return [enter,cross,drop]

static func _open_port(m: Dictionary,id: String,at: Vector2,label: String) -> Dictionary:
	var support := id+"__bough"
	_platform(m,support,Rect2(at+Vector2(-80.0,18.0),Vector2(160.0,20.0)),true,id)
	_area(m,id,at,label,"junction")
	m.scene_structure_kinds[id] = "rootland"
	return {"area":id,"point":_pair(at),"support":support}

static func _return_corridor(m: Dictionary,start: Vector2,end: Vector2) -> Dictionary:
	var minimum := maxf(start.y,end.y)+64.0
	for reward: Dictionary in m.rewards:
		if str(reward.tier) == "high": minimum = maxf(minimum,float(reward.position[1])+448.0)
	var heights: Array[float] = [minimum+16.0]
	for platform: Dictionary in m.platforms:
		if not bool(platform.one_way): heights.append(_rect(platform.rect).end.y+40.0)
	heights.sort()
	for y: float in heights:
		if y < minimum: continue
		var east := _open_column(m,start,y)
		var west := _open_column(m,end,y)
		if not is_finite(east) or not is_finite(west): continue
		var sweep := Rect2(Vector2(minf(east,west)-12.0,y-18.0),Vector2(absf(east-west)+24.0,36.0))
		if not _clear_body(m,sweep): continue
		# The future bridge's underside must also leave every resting capsule
		# clear. Looking only at the future walker's body missed hub2's head.
		var floor_body := Rect2(Vector2(minf(east,west)-80.0,y+18.0),Vector2(absf(east-west)+160.0,24.0))
		var resting_clear := true
		for area: Dictionary in m.areas:
			if str(area.id) != "arrival" and not str(area.id).begins_with("hub_"): continue
			if floor_body.intersects(Rect2(_point(area.position)-Vector2(12,18),Vector2(24,36))):
				resting_clear = false; break
		if resting_clear: return {"east":east,"west":west,"y":y}
	return {}

static func _open_column(m: Dictionary,source: Vector2,y: float) -> float:
	var columns: Array[float] = [source.x+144.0]
	for platform: Dictionary in m.platforms:
		if not bool(platform.one_way): columns.append(_rect(platform.rect).end.x+40.0)
	columns.sort()
	for x: float in columns:
		if x < source.x+40.0 or x > source.x+1800.0: continue
		var horizontal := Rect2(Vector2(source.x-12.0,source.y-18.0),Vector2(x-source.x+24.0,36.0))
		var vertical := Rect2(Vector2(x-12.0,minf(source.y,y)-18.0),Vector2(24.0,absf(source.y-y)+36.0))
		if _clear_body(m,horizontal) and _clear_body(m,vertical): return x
	return INF

static func _clear_body(m: Dictionary,body: Rect2) -> bool:
	for platform: Dictionary in m.platforms:
		if not bool(platform.one_way) and body.intersects(_rect(platform.rect).grow(-0.01)): return false
	return true

static func _corridor_edge(m: Dictionary,id: String,from: Dictionary,to: Dictionary,points: Array) -> String:
	var steps: Array = []
	var support := str(from.support)
	var previous: Vector2 = points[0]
	for segment: int in range(1,points.size()):
		var finish: Vector2 = points[segment]
		var descending: bool = finish.y > previous.y+0.1
		var count := 1 if descending else maxi(1,maxi(ceili(absf(finish.x-previous.x)/144.0),ceili(absf(finish.y-previous.y)/64.0)))
		var origin := previous
		if descending and is_equal_approx(origin.x,finish.x):
			# A real intermediate bough catches a drop even when it is one-way.
			# Give it its own accepted landing and a second Down input, instead
			# of promising one vertical leg through an actual receiving surface.
			var catches: Array[Dictionary] = []
			for row: Dictionary in m.platforms:
				var floor_rect := _rect(row.rect)
				var body_y := floor_rect.position.y-18.0
				if bool(row.one_way) and body_y>origin.y+0.1 and body_y<finish.y-0.1 and origin.x-12.0>=floor_rect.position.x and origin.x+12.0<=floor_rect.end.x:
					catches.append(row)
			catches.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.rect[1])<float(b.rect[1]))
			for row: Dictionary in catches:
				var caught := Vector2(origin.x,float(row.rect[1])-18.0)
				if caught.y<=previous.y+0.1: continue
				steps.append({"kind":"drop_through","takeoff":_pair(previous),"landing":_pair(caught),"path":[_pair(previous),_pair(caught)],"from_support_id":support,"support_id":str(row.id)})
				previous = caught
				support = str(row.id)
		for index: int in range(1,count+1):
			var point := origin.lerp(finish,float(index)/float(count))
			if segment<points.size()-1 or index<count: point = _solid_floor_point(m,point)
			var target := str(to.support)
			if segment < points.size()-1 or index < count:
				target = id+"__support_%s_%s" % [segment,index]
				target = _receiving_bough(m,target,point,160.0)
			var kind := "drop_through" if descending else "jump_rise" if point.y < previous.y-0.1 else "walk"
			var step := {"kind":kind,"takeoff":_pair(previous),"landing":_pair(point),"from_support_id":support,"support_id":target}
			if descending: step.path = [_pair(previous),_pair(point)]
			steps.append(step)
			previous = point
			support = target
	_edge(m,id,str(from.area),str(to.area),"ordinary_sequence",[from.point,to.point],steps)
	return id

static func _install_boss(m: Dictionary,from: Dictionary) -> Array:
	var point := _point(from.point)
	var prep := _hub(m,"prep",point+Vector2(320.0,0.0),"REST / READ THE BOSS APPROACH")
	var ready := {"area":"gate_ready","point":_pair(point+Vector2(520.0,0.0)),"support":str(prep.support)}
	_platform(m,"boss_approach",Rect2(point+Vector2(160.0,18.0),Vector2(480.0,48.0)),false,"boss_prep")
	ready.support = "boss_approach"
	_area(m,"gate_ready",_point(ready.point),"BOSS APPROACH","prep")
	var enter := _connect(m,"last_court_to_prep",from,prep)
	var ring := point+Vector2(500.0,-90.0)
	_anchor(m,"crown_approach_ring_0",ring,"boss_approach",point+Vector2(500.0,18.0),"main",false)
	_edge(m,"crown_approach",str(prep.area),"gate_ready","gate_hook",[prep.point,ready.point])
	m.connections[-1].anchor_id = "crown_approach_ring_0"
	m.connections[-1].support_id = "boss_approach"
	var approach := point+Vector2(640.0,0.0)
	var factory := ARENA.new()
	var contract: Dictionary = factory.queen_canopy_from_prep(approach) if int(m.map_index) == 2 else factory.from_prep(approach,1)
	m.boss_contract = contract.duplicate(true)
	m.boss_geometry = contract.duplicate(true)
	m.boss_approach_origin = _pair(approach)
	m.boss_arena = contract.get("boss_arena",[approach.x,approach.y,0.0,0.0])
	m.boss_root_supports = contract.get("root_supports",[]).duplicate(true)
	m.platforms.append_array(contract.get("platforms",[]).duplicate(true))
	m.hook_anchors.append_array(contract.get("hook_anchors",[]).duplicate(true))
	if int(m.map_index) == 2: m.boss_content = {"contract":"forest-queen-canopy-v3","scene":"res://scenes/bosses/thorn_queen_canopy.tscn","resource":"res://resources/bosses/thorn_queen_canopy.tres"}
	m.vine_gate = {"id":"crown_vine","key_anchor":"crown_approach_ring_0","rect":[approach.x-4.0,approach.y-502.0,16.0,556.0]}
	if bool(contract.get("ok",false)):
		var safe := _point(contract.safe_return)
		_area(m,"boss",safe,"FOREST BOSS","boss")
		_edge(m,"arena_entry","gate_ready","boss","walk",[ready.point,_pair(safe)])
	m.boss_approach_contract = {"entry_port":str(from.area),"progression":"four_landmarks_then_observation_and_gate","native_verified":false}
	return [enter,"crown_approach"]


static func _install_discoveries(m: Dictionary,normal: Array[Dictionary],hard: Array[Dictionary],index: int) -> void:
	var definitions: Array = ["voiceless_bell","root_cache","unsent_letter"] if index == 1 else ["old_badge","spiral_core","branch_ring_map"]
	var ports: Array = [normal[0].entry,normal[1].entry,normal[2].entry] if index == 1 else [normal[0].entry,hard[2].exit,hard[3].entry]
	var approaches: Array[String] = ["discovery_0_approach","discovery_1_approach","discovery_2_approach"]
	var returns: Array[String] = ["discovery_0_return","discovery_1_return","discovery_2_return"]
	for i: int in definitions.size():
		var district: int = i if index == 1 else [0,2,3][i]
		if index == 2 and i == 1:
			m.routes[approaches[i]] = Array(m.routes["master_2_out"])
			m.routes[returns[i]] = Array(m.routes["master_2_return"])
		elif index == 2 and i == 2:
			m.routes[approaches[i]] = ["district_3_explore_enter","district_3_master_climb"]
			m.routes[returns[i]] = ["district_3_master_climb_back","district_3_explore_enter_back"]
		else:
			m.routes[approaches[i]] = ["district_%s_explore_enter" % district]
			m.routes[returns[i]] = ["district_%s_explore_enter_back" % district]
		var port: Dictionary = ports[i]
		m.forest_discoveries.append({"id":"forest_"+definitions[i],"definition_id":definitions[i],"position":port.point.duplicate(),"area_id":str(port.area),"support_id":str(port.support),"host_support_id":str(port.support),"structure_id":str(_support(m,str(port.support)).get("structure_id","forest_roots")),"approach_route":approaches[i],"return_route":returns[i],"scene_kind":"forest_discovery","return_hint":"从奖励枝的另一端下降，重回已经见过的宽根与营地。"})

static func _reward(m: Dictionary,id: String,port: Dictionary,tier: String,coins: int,notes: int) -> void:
	m.rewards.append({"id":id,"position":port.point.duplicate(),"area":str(port.area),"tier":tier,"claimed":false,"reward_mode":"resources","items":[],"coins":coins,"resources":[{"kind":"coin","amount":coins},{"kind":"note","amount":notes}],"requires":[],"support_id":str(port.support),"approach_route":"master_%s_out" % id.get_slice("_",1) if tier == "high" else "explore_%s_out" % id.get_slice("_",1),"return_route":"master_%s_return" % id.get_slice("_",1) if tier == "high" else "explore_%s_return" % id.get_slice("_",1)})
	var district := id.get_slice("_",1)
	var edge_id := "district_%s_master_other_exit" % district if tier == "high" else "district_%s_explore_other_mouth" % district
	for edge: Dictionary in m.connections:
		if str(edge.id) == edge_id: edge.merge({"claim_before_edge":true,"claim_area":str(port.area),"claim_id":id})

static func _install_thorn_surfaces(m: Dictionary) -> void:
	m.thorn_surfaces = []
	for i: int in m.dangers.size():
		var display: Dictionary = m.danger_presentations[i]
		var host := _support(m,str(display.host_support_id))
		if host.is_empty() or bool(host.one_way): continue
		var support := _rect(host.rect)
		var danger := _rect(m.dangers[i])
		var face := str(display.facing)
		var seam := support.position.y if face == "up" else support.end.y
		m.thorn_surfaces.append({"danger_index":i,"face":face,"hazard_rect":m.dangers[i].duplicate(),"segments":[{"support_id":str(host.id),"start":[danger.position.x,seam],"end":[danger.end.x,seam]}]})

static func _anchor(m: Dictionary,id: String,point: Vector2,host: String,root: Vector2,role: String,hang: bool) -> void:
	m.hook_anchors.append({"id":id,"position":_pair(point),"scene_kind":"copper_growth_ring","structure_id":str(_support(m,host).get("structure_id","forest_roots")),"fruit_role":role,"fruit_role_basis":"branching_route_difficulty","fruit_route_bindings":[],"fruit_presentation":"rooted_fruit","fruit_host_support_id":host,"fruit_stem_root":_pair(root),"hang_enabled":hang})

static func _platform(m: Dictionary,id: String,rect: Rect2,one_way: bool,structure: String) -> void:
	m.platforms.append({"id":id,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"one_way":one_way,"scene_kind":"living_bough" if one_way else "hollow_bark" if rect.size.y>96.0 else "root_earth","structure_id":structure,"surface_role":"bough_top" if one_way else "root_top"})

static func _area(m: Dictionary,id: String,point: Vector2,label: String,role: String) -> void:
	m.areas.append({"id":id,"position":_pair(point),"label":label,"role":role})

static func _edge(m: Dictionary,id: String,a: String,b: String,kind: String,path: Array,steps: Array = []) -> void:
	m.connections.append({"id":id,"a":a,"b":b,"kind":kind,"path":path,"steps":steps,"condition":"open","admission":"candidate_pending_actual_Motor","native_verified":false})

static func _reverse_edge(m: Dictionary,edge: Dictionary) -> void:
	var steps: Array = []
	for i: int in range(edge.steps.size()-1,-1,-1):
		var row: Dictionary = edge.steps[i]
		if not row.has("takeoff"):
			continue
		var reverse := row.duplicate(true)
		reverse.landing = row.takeoff.duplicate()
		reverse.takeoff = row.landing.duplicate()
		reverse.support_id = row.get("from_support_id",row.get("support_id",""))
		reverse.from_support_id = row.get("support_id", "")
		if reverse.get("kind") == "drop_through": reverse.kind = "jump_rise"
		if reverse.has("path"): reverse.erase("path")
		steps.append(reverse)
	var path: Array = edge.path.duplicate(true)
	path.reverse()
	_edge(m,str(edge.id)+"_back",str(edge.b),str(edge.a),"ordinary_sequence",path,steps)

static func _reverse_route(route: Array) -> Array:
	var reverse: Array = []
	for i: int in range(route.size()-1,-1,-1):
		var id := str(route[i])
		# The first H is directional. Its existing ordinary roots provide the
		# return, rather than inventing an unimplemented reverse hook action.
		if id == "first_safe_side_hook": id = "district_0_main_join"
		reverse.append(id+"_back")
	return reverse

static func _support(m: Dictionary,id: String) -> Dictionary:
	for row: Dictionary in m.platforms:
		if str(row.id) == id: return row
	return {}

static func topology_signature(m: Dictionary) -> String:
	var connections: Array[String] = []
	for row: Dictionary in m.get("connections",[]): connections.append(str(row.a)+">"+str(row.b)+":"+str(row.kind))
	connections.sort()
	return str(m.get("family",""))+"/"+"|".join(connections)

static func validate(m: Dictionary) -> bool:
	if m.get("layout_version") != VERSION or m.get("requires") != ["grapple"] or m.get("production_pool") != false: return false
	if not bool(m.get("boss_contract",{}).get("ok",false)) or not LANGUAGE.validate(m): return false
	for category: String in ["platforms","hook_anchors","areas","connections","rewards","geometry_instances","forest_discoveries"]:
		var seen: Dictionary = {}
		for row: Dictionary in m.get(category,[]):
			if seen.has(str(row.id)): return false
			seen[str(row.id)] = true
	for route_name: String in m.routes:
		var at := ""
		for id: String in m.routes[route_name]:
			var found: Dictionary = {}
			for edge: Dictionary in m.connections:
				if str(edge.id) == id: found = edge; break
			if found.is_empty() or (not at.is_empty() and str(found.a) != at): return false
			at = str(found.b)
	for name: String in ["fast","growth","high_return","change_mind"]:
		var route: Array = m.routes.get(name,[])
		if route.is_empty(): return false
		var first: Dictionary = {}
		var last: Dictionary = {}
		for edge: Dictionary in m.connections:
			if edge.id == route[0]: first = edge
			if edge.id == route[-1]: last = edge
		if first.get("a") != "arrival" or last.get("b") != (m.camp_area if name in ["high_return","change_mind"] else "gate_ready"): return false
	if not ForestBibleDiscoveryCatalog.valid_rows(m.forest_discoveries): return false
	return true

static func _point(row: Array) -> Vector2:
	return Vector2(float(row[0]),float(row[1]))

static func _pair(point: Vector2) -> Array:
	return [point.x,point.y]

static func _rect(row: Array) -> Rect2:
	return Rect2(float(row[0]),float(row[1]),float(row[2]),float(row[3]))
