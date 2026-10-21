class_name ForestBibleV2Layout
extends RefCounted
## One world-coordinate source for new traversal, discoveries and presentation.
## Old five route programs and all inherited bodies remain untouched.
const VERSION := "forest-bible-world-v15"
const SPIRAL_RETURN_VERSION := "forest-bible-spiral-east-mouth-v1"
const API := preload("res://scripts/generation/forest_expedition_layout.gd")
const RECIPE := preload("res://scripts/generation/thorn_forest_region_v2_v10.gd")
const BACK := preload("res://scripts/generation/forest_bible_backbranch_geometry.gd")
const LANGUAGE := preload("res://scripts/generation/forest_scene_language.gd")
const THORN_SURFACES := preload("res://scripts/generation/forest_bible_thorn_surfaces.gd")

static func install(m: Dictionary) -> void:
	var rng := RunRandomStream.new(str(m.seed),"forest_bible_world","map_%s" % m.map_index,VERSION)
	var outside := rng.next_int(2) == 0
	m.choices.bible_root_connection = "outer_root_east_mouth" if outside else "inner_root_lower_mouth"
	m.streams.bible_world = "forest_bible_world"
	m.stream_positions.bible_world = rng.position()
	m.forest_discoveries = []
	m.forest_shortcuts = []
	_install_root_connection(m,outside)
	_install_backbranch(m)
	_install_weaver(m)
	_install_discoveries(m)
	_install_journeys(m)
	_install_practice_bell(m)
	# Rebuild the presentation membership from the same actual bodies, including
	# the new passage's explicit void. No separate art coordinate layout.
	m.scene_structure_kinds.merge({"bible_root_tunnel":"root_hollow","bible_backbranch":"fallen_trunk","bible_weaver_hollow":"hollow_tree"})
	LANGUAGE.annotate(m)
	if not THORN_SURFACES.install(m): return
	for structure: Dictionary in m.scene_structures:
		if structure.id == "bible_weaver_hollow": structure.open_voids = [[1330.0,1020.0,230.0,180.0]]
	m.bible_world_contract = {"version":VERSION,"connection_variant":m.choices.bible_root_connection,
		"actual_connection_edge":"bible_root_mouth_exit","actual_receiver":"R" if outside else "D",
		"physical_difference":"exclusive_east_outer_steps_or_lower_window_side_steps; original_trunk_preserved",
		"preserved_route_names":["fast","growth","high_return","change_mind","borer"],
		"F05":{"edge":"bible_backbranch_flight","departure":"drop_outside_before_side_H","return":"bible_backbranch_other_exit","reward":"bible_backbranch_cache"},
		"F08":{"inherited_edge":"interwoven_deep_ascent","unique_discovery":"forest_spiral_core","return":"bible_spiral_other_exit","return_version":SPIRAL_RETURN_VERSION},
		"F06":{"enemy":"bible_double_window_weaver","paths":["bible_web_upper_cross","bible_web_lower_cross"]},
		"native_verified":false,"production_pool":false}
	var bounds := Rect2(API._point(m.spawn),Vector2.ONE)
	for row: Dictionary in m.platforms: bounds = bounds.merge(RECIPE._rect(row.rect))
	for row: Dictionary in m.hook_anchors: bounds = bounds.expand(API._point(row.position))
	bounds = bounds.grow(200.0)
	m.world_bounds = [bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y]
	m.topology_signature = RECIPE.topology_signature(m)+"/"+str(m.choices.bible_root_connection)

static func _install_root_connection(m: Dictionary, outside: bool) -> void:
	# All new stairs lie below or east of the old shared trunk; none cuts into
	# the 580px HRHHR shaft or supplies a mid-phrase landing.
	_p(m,"bible_lower_root",Rect2(360,1400,790,28),true,"bible_root_tunnel","lower_root_crossing")
	_p(m,"bible_root_step0",Rect2(1060,1300,150,24),true,"bible_root_tunnel","lower_observation_step")
	_p(m,"bible_root_step1",Rect2(1160,1200,160,24),true,"bible_root_tunnel","fork_observation_step")
	API._area(m,"bible_root_fork",Vector2(1240,1182),"ROOT TUNNEL / TWO FACES OF THE SAME TREE","junction")
	API._edge(m,"bible_basin_root_tunnel","interwoven_deep_basin","bible_root_fork","ordinary_sequence",[[200.0,1382.0],[440.0,1382.0],[1100.0,1282.0],[1240.0,1182.0]],[
		API._step("jump_gap",Vector2(275,1382),Vector2(400,1382),"interwoven_deep_basin","bible_lower_root"),
		API._step("jump_rise",Vector2(1100,1382),Vector2(1130,1282),"bible_lower_root","bible_root_step0"),
		API._step("jump_rise",Vector2(1150,1282),Vector2(1240,1182),"bible_root_step0","bible_root_step1")])
	if outside:
		_p(m,"bible_outer_step2",Rect2(1260,1100,110,24),true,"bible_root_tunnel","eastward_camp_mouth")
		_p(m,"bible_outer_step3",Rect2(1350,1000,130,24),true,"bible_root_tunnel","outer_root_receiver")
		API._edge(m,"bible_root_mouth_exit","bible_root_fork","R","ordinary_sequence",[[1240.0,1182.0],[1320.0,1082.0],[1400.0,982.0],[1200.0,882.0],[1020.0,882.0]],[
			API._step("jump_rise",Vector2(1295,1182),Vector2(1320,1082),"bible_root_step1","bible_outer_step2"),
			API._step("jump_rise",Vector2(1340,1082),Vector2(1400,982),"bible_outer_step2","bible_outer_step3"),
			API._step("jump_rise",Vector2(1365,982),Vector2(1250,882),"bible_outer_step3","hollow__outer_root")])
	else:
		# The old solid outer sump occupies x930..1300/y1060..1090.
		# Approach its WEST end below the old floor before rising; a step only
		# ten pixels beneath that sump is not a body-clear passage.
		_p(m,"bible_inner_root_bridge",Rect2(650,1200,550,24),true,"bible_root_tunnel","westward_camp_tunnel")
		_p(m,"bible_inner_step2",Rect2(650,1100,160,24),true,"bible_root_tunnel","west_of_solid_sump")
		_p(m,"bible_inner_step3",Rect2(700,1000,100,20),true,"bible_root_tunnel","below_inner_root_east_edge")
		_p(m,"bible_inner_mouth",Rect2(835,900,85,20),true,"bible_root_tunnel","inner_window_receiver")
		API._edge(m,"bible_root_mouth_exit","bible_root_fork","D","ordinary_sequence",[[1240.0,1182.0],[730.0,1182.0],[730.0,1082.0],[750.0,982.0],[875.0,882.0],[720.0,802.0]],[
			{"kind":"walk","landing":[730.0,1182.0],"support_id":"bible_inner_root_bridge"},
			API._step("jump_rise",Vector2(730,1182),Vector2(730,1082),"bible_inner_root_bridge","bible_inner_step2"),
			API._step("jump_rise",Vector2(730,1082),Vector2(750,982),"bible_inner_step2","bible_inner_step3"),
			API._step("jump_rise",Vector2(770,982),Vector2(875,882),"bible_inner_step3","bible_inner_mouth"),
			{"kind":"jump_gap","takeoff":[850.0,882.0],"landing":[750.0,802.0],"from_support_id":"bible_inner_mouth","support_id":"hollow__inner_root","hold_until_ceiling_or_receiver":true}])
	API._edge(m,"bible_root_mouth_return","R" if outside else "D","bible_root_fork","drop_through",[[1200.0,882.0],[1365.0,982.0],[1390.0,1082.0],[1240.0,1182.0]] if outside else [[720.0,802.0],[875.0,882.0],[750.0,982.0],[730.0,1182.0],[1240.0,1182.0]])
	# The old root floor is solid. Leave its EAST lip, receive on an actual
	# y900 bough, then cross to R above the old solid trunk/sump. The previous
	# unsupported y922/y1162 drop waypoints are preserved as a counterexample
	# in build/region_bible_v2/f08-invalid-return-counterexample/.
	var spiral_mouth := "bible_inner_mouth"
	if outside:
		spiral_mouth = "bible_spiral_mouth"
		_p(m,spiral_mouth,Rect2(835,900,85,20),true,"bible_root_tunnel","spiral_east_mouth_receiver")
	API._edge(m,"bible_spiral_other_exit","interwoven_root_landing","R","ordinary_sequence",[[400.0,802.0],[430.0,802.0],[875.0,882.0],[980.0,882.0],[1020.0,882.0]],[
		{"kind":"walk","landing":[430.0,802.0],"support_id":"hollow__inner_root","bible_spiral_reader":true},
		{"kind":"drop_through","path":[[430.0,802.0],[810.0,802.0],[875.0,882.0]],"landing":[875.0,882.0],"support_id":spiral_mouth},
		{"kind":"jump_gap","takeoff":[905.0,882.0],"landing":[980.0,882.0],"from_support_id":spiral_mouth,"support_id":"hollow__outer_root","hold_until_ceiling_or_receiver":true}])
	m.routes.bible_root_connection = ["interwoven_deep_descent","bible_basin_root_tunnel","bible_root_mouth_exit"]
	m.routes.bible_spiral_approach = ["interwoven_deep_descent","interwoven_deep_ascent"]
	m.routes.bible_spiral_return = ["bible_spiral_other_exit"] + RECIPE._route(m,"R","camp")

static func _install_backbranch(m: Dictionary) -> void:
	var raw := BACK.build()
	var instance := {"id":"bible_backbranch","factory":"res://scripts/generation/forest_bible_backbranch_geometry.gd","geometry_version":BACK.VERSION,"local_geometry":raw,"translation":[0.0,0.0],"platform_id_map":{},"anchor_id_map":{},"danger_indices":[]}
	for row: Dictionary in raw.platforms:
		var id := "bible_backbranch__"+str(row.id)
		instance.platform_id_map[row.id] = id
		API._platform(m,id,RECIPE._rect(row.rect),bool(row.one_way),"hollow_bark" if str(row.id).begins_with("broken") or str(row.id).begins_with("west_") else "canopy_perch" if row.id == "crown" else "living_bough" if row.one_way else "root_earth","bible_backbranch",str(row.id))
	_anchor(m,"bible_backbranch__side_fruit",Vector2(1886,1060),"bible_backbranch","bible_backbranch__entry",Vector2(1886,1024))
	instance.anchor_id_map.side_fruit = "bible_backbranch__side_fruit"
	m.geometry_instances.append(instance)
	API._area(m,"bible_backbranch_entry",Vector2(2020,982),"BROKEN BRANCH / DESCEND TO LOOK BACK","junction")
	API._area(m,"bible_backbranch_reward",Vector2(1740,1022),"BACK OF THE BROKEN BOUGH","challenge_reward")
	API._air_edge(m,"bible_backbranch_flight","bible_backbranch_entry","bible_backbranch_reward",instance)
	m.connections[-1].departure = raw.departure.duplicate(true)
	m.connections[-1].first_hook_requires_descent_below = 1080.0
	API._edge(m,"bible_backbranch_other_exit","bible_backbranch_reward","bible_web_lower","ordinary_sequence",[[1740.0,1022.0],[1850.0,1062.0],[1900.0,1302.0],[1630.0,1182.0]],[
		{"kind":"drop_through","path":[[1740.0,1022.0],[1850.0,1022.0],[1850.0,1062.0]],"landing":[1850.0,1062.0],"support_id":"bible_backbranch__broken_lower"},
		{"kind":"drop_through","path":[[1850.0,1062.0],[1900.0,1062.0],[1900.0,1302.0]],"landing":[1900.0,1302.0],"support_id":"bible_backbranch__recovery"},
		API._step("jump_rise",Vector2(1660,1302),Vector2(1630,1182),"bible_backbranch__recovery","bible_weaver_lower")])
	m.rewards.append({"id":"bible_backbranch_cache","position":[1740.0,1022.0],"area":"bible_backbranch_reward","tier":"medium","claimed":false,"reward_mode":"resources","items":[],"coins":4,"resources":[{"kind":"coin","amount":4},{"kind":"note","amount":1}],"crosslink":"F05_backside_other_exit","requires":[],"approach_route":"bible_backbranch_approach","return_route":"bible_backbranch_return"})
	m.routes.bible_backbranch_approach = ["bible_root_mouth_return","bible_web_lower_out","bible_web_to_backbranch","bible_backbranch_flight"]
	m.routes.bible_backbranch_return = ["bible_backbranch_other_exit","bible_web_lower_cross","bible_root_mouth_exit"] + RECIPE._route(m,"R" if m.choices.bible_root_connection == "outer_root_east_mouth" else "D","camp")
	_p(m,"bible_backbranch_short_bridge",Rect2(1350,1040,180,24),true,"bible_backbranch","award_opened_direct_return")
	API._edge(m,"bible_backbranch_shortcut","bible_backbranch_reward","R","ordinary_sequence",[[1740.0,1022.0],[1630.0,1062.0],[1440.0,1022.0],[1260.0,882.0],[1020.0,882.0]],[
		{"kind":"drop_through","path":[[1740.0,1022.0],[1630.0,1022.0],[1630.0,1062.0]],"landing":[1630.0,1062.0],"support_id":"bible_weaver_upper"},
		API._step("jump_rise",Vector2(1585,1062),Vector2(1440,1022),"bible_weaver_upper","bible_backbranch_short_bridge"),
		API._step("jump_rise",Vector2(1370,1022),Vector2(1260,882),"bible_backbranch_short_bridge","hollow__outer_root")])
	m.connections[-1].condition = "opened:bible_backbranch_return"
	m.connections[-1].shortcut_id = "bible_backbranch_return"
	m.forest_shortcuts.append({"id":"bible_backbranch_return","opened_key":"bible_backbranch_return","unlock_reward_id":"bible_backbranch_cache","rect":[1660.0,1000.0,40.0,80.0],"from_area":"bible_backbranch_reward","to_area":"R","return_route":"bible_backbranch_short_return","long_return_route":"bible_backbranch_return"})
	m.routes.bible_backbranch_short_return = ["bible_backbranch_shortcut"] + RECIPE._route(m,"R","camp")

static func _install_weaver(m: Dictionary) -> void:
	_p(m,"bible_weaver_upper",Rect2(1570,1080,90,24),true,"bible_weaver_hollow","upper_observation_bank")
	_p(m,"bible_weaver_lower",Rect2(1550,1200,180,24),true,"bible_weaver_hollow","lower_observation_bank")
	_p(m,"bible_weaver_upper_receiver",Rect2(1310,1080,65,24),true,"bible_weaver_hollow","upper_window_receiver")
	_p(m,"bible_weaver_upper_mid",Rect2(1380,1080,100,24),true,"bible_weaver_hollow","web_controlled_upper_transit")
	_p(m,"bible_weaver_lower_mid",Rect2(1380,1200,100,24),true,"bible_weaver_hollow","web_controlled_lower_transit")
	_p(m,"bible_weaver_roof",Rect2(1490,990,100,24),true,"bible_weaver_hollow","silk_host_bough")
	API._area(m,"bible_web_upper",Vector2(1630,1062),"WEAVER HOLLOW / UPPER WINDOW","junction")
	API._area(m,"bible_web_lower",Vector2(1630,1182),"WEAVER HOLLOW / LOWER WINDOW","junction")
	API._edge(m,"bible_web_upper_cross","bible_web_upper","bible_root_fork","ordinary_sequence",[[1630.0,1062.0],[1340.0,1062.0],[1240.0,1182.0]],[API._step("jump_gap",Vector2(1585,1062),Vector2(1455,1062),"bible_weaver_upper","bible_weaver_upper_mid"),API._step("jump_gap",Vector2(1395,1062),Vector2(1340,1062),"bible_weaver_upper_mid","bible_weaver_upper_receiver"),{"kind":"drop_through","path":[[1340.0,1062.0],[1340.0,1062.0],[1240.0,1182.0]],"landing":[1240.0,1182.0],"support_id":"bible_root_step1"}])
	API._edge(m,"bible_web_lower_cross","bible_web_lower","bible_root_fork","ordinary_sequence",[[1630.0,1182.0],[1240.0,1182.0]],[API._step("jump_gap",Vector2(1565,1182),Vector2(1455,1182),"bible_weaver_lower","bible_weaver_lower_mid"),API._step("jump_gap",Vector2(1395,1182),Vector2(1300,1182),"bible_weaver_lower_mid","bible_root_step1")])
	API._edge(m,"bible_web_lower_out","bible_root_fork","bible_web_lower","ordinary_sequence",[[1240.0,1182.0],[1630.0,1182.0]],[API._step("jump_gap",Vector2(1305,1182),Vector2(1400,1182),"bible_root_step1","bible_weaver_lower_mid"),API._step("jump_gap",Vector2(1465,1182),Vector2(1570,1182),"bible_weaver_lower_mid","bible_weaver_lower")])
	API._edge(m,"bible_web_to_backbranch","bible_web_lower","bible_backbranch_entry","ordinary_sequence",[[1630.0,1182.0],[1980.0,1302.0],[2180.0,1202.0],[2180.0,1092.0],[2020.0,982.0]],[
		{"kind":"drop_through","path":[[1630.0,1182.0],[1750.0,1182.0],[1980.0,1302.0]],"landing":[1980.0,1302.0],"support_id":"bible_backbranch__recovery"},
		API._step("jump_rise",Vector2(2180,1302),Vector2(2180,1202),"bible_backbranch__recovery","bible_backbranch__recovery_step"),
		API._step("jump_rise",Vector2(2180,1202),Vector2(2180,1092),"bible_backbranch__recovery_step","bible_backbranch__retry_step"),
		API._step("jump_rise",Vector2(2155,1092),Vector2(2020,982),"bible_backbranch__retry_step","bible_backbranch__entry")])
	var path := "res://resources/enemies/forest_bible_weaver.tres"
	m.enemies.append({"id":"bible_double_window_weaver","behavior_id":"forest_bible_weaver","definition_path":path,"definition_sha256":FileAccess.get_sha256(path),"stable_id":"forest_bible_weaver","position":[1550.0,1106.0],"aerial":false,"patrol_radius":0.0,"support_id":"","tether_host":"bible_weaver_roof","authored_body_sweep":[1537.0,1092.0,26.0,28.0],"encounter_group":"bible_double_window_choice","encounter_role":"alternate_upper_lower_web; wait, cross_other_height_or_shoot","web_strands":[{"id":"upper","start":[1360.0,1060.0],"end":[1480.0,1060.0]},{"id":"lower","start":[1360.0,1180.0],"end":[1480.0,1180.0]}]})

	var dropper := EnemyDropService.new()
	dropper.configure(str(m.seed),"thorn_forest/map_%s" % m.map_index)
	m.enemy_drops["bible_double_window_weaver"] = dropper.settle(&"bible_double_window_weaver")

static func _install_discoveries(m: Dictionary) -> void:
	if int(m.map_index) == 1:
		_site(m,"forest_voiceless_bell","voiceless_bell",Vector2(1180,558),"E","hollow__outer_crown","bible_bell_approach","bible_bell_return")
		API._edge(m,"bible_live_bell_crossing","R","E","hollow_live_return",[[1020.0,882.0],[980.0,558.0]])
		m.connections[-1].merge({"geometry_instance":"hollow","enemy_id":"hollow_route__outer_lift_lantern","landing":[980.0,558.0],"landing_support_id":"hollow__outer_crown","optional":true,"strategies":["living_anchor_then_downward_recoil","ordinary_jump_and_at_most_two_downward_shots","retain_lower_window_return"],"native_verified":false})
		m.routes.bible_bell_approach = ["bible_live_bell_crossing"]
		m.routes.bible_bell_return = ["outer_drop","outer_to_inner"] + RECIPE._route(m,"D","camp")
		_site(m,"forest_root_cache","root_cache",Vector2(560,802),"D","hollow__inner_root","bible_cache_approach","bible_cache_return")
		m.routes.bible_cache_approach = ["outer_to_inner"]
		m.routes.bible_cache_return = ["inner_recovery"] + RECIPE._route(m,"M","camp")
		_site(m,"forest_unsent_letter","unsent_letter",Vector2(325,802),"interwoven_root_landing","hollow__inner_root","bible_letter_approach","bible_letter_return")
		m.routes.bible_letter_approach = ["interwoven_deep_descent","interwoven_deep_ascent"]
		m.routes.bible_letter_return = ["interwoven_root_to_D"] + RECIPE._route(m,"D","camp")
	else:
		_site(m,"forest_old_badge","old_badge",Vector2(-525,250) if m.choices.get("west_reward",false) else Vector2(200,450),"cache" if m.choices.get("west_reward",false) else "N","far_reward_branch" if m.choices.get("west_reward",false) else "north_court","bible_badge_approach","bible_badge_return")
		API._edge(m,"bible_north_approach","W","N","candidate_hook_relay",[[180.0,600.0],[180.0,500.0],[300.0,440.0],[200.0,450.0]])
		m.connections[-1].anchor_id = "north_court_ring"
		API._edge(m,"bible_north_return","N","W","drop_through",[[200.0,450.0],[200.0,600.0],[180.0,600.0]])
		m.routes.bible_badge_approach = ["north_far_bough","far_cache"] if m.choices.get("west_reward",false) else ["bible_north_approach"]
		m.routes.bible_badge_return = ["far_reward_return"] + RECIPE._route(m,"W","camp") if m.choices.get("west_reward",false) else ["bible_north_return"] + RECIPE._route(m,"W","camp")
		_site(m,"forest_spiral_core","spiral_core",Vector2(460,802),"interwoven_root_landing","hollow__inner_root","bible_spiral_approach","bible_spiral_return")
		var crown := _area_point(m,"C")
		_site(m,"forest_branch_ring_map","branch_ring_map",Vector2(1120,crown.y),"C","hollow__cavity_exit","bible_map_approach","bible_map_return")
		m.routes.bible_map_approach = ["belly_borer_access","borer_crossing"]
		m.routes.bible_map_return = ["borer_crown_descent","outer_drop","outer_to_inner"] + RECIPE._route(m,"D","camp")

static func _install_journeys(m: Dictionary) -> void:
	var prefix: Array = []
	for edge_id: String in m.routes.growth:
		prefix.append(edge_id)
		if edge_id == "broken_arch_flight": break
	m.routes.bible_connection_journey = prefix + ["interwoven_deep_descent","bible_basin_root_tunnel","bible_root_mouth_exit"] + RECIPE._route(m,"R" if m.choices.bible_root_connection == "outer_root_east_mouth" else "D","camp")
	m.routes.bible_backbranch_journey = prefix + ["interwoven_deep_descent","bible_basin_root_tunnel","bible_web_lower_out","bible_web_to_backbranch","bible_backbranch_flight"] + m.routes.bible_backbranch_short_return
	if int(m.map_index) == 2:
		m.routes.bible_spiral_journey = prefix + m.routes.bible_spiral_approach + m.routes.bible_spiral_return
	var shortcut := RECIPE._edge_by_id(m,"bible_backbranch_shortcut")
	shortcut.merge({"claim_before_edge":true,"claim_area":"bible_backbranch_reward","claim_id":"bible_backbranch_cache"})


static func _install_practice_bell(m: Dictionary) -> void:
	m.training_bells = []
	if int(m.map_index) != 1: return
	m.training_bells.append({"id":"bible_guardian_practice_bell","position":[1290.0,408.0],"motion":{"kind":"pendulum","center":[1290.0,408.0],"radius":[30.0,12.0],"period":3.2},"host_support_id":"boss_approach","structure_id":"hollow","tether_root":[1290.0,360.0],"observation_position":[1300.0,558.0],"return_position":[1300.0,558.0],"route_id":"crown_prep","damage":false,"reward":false,"enemy_clear_required_for_unpressured_practice":true})
	m.fruit_boughs.append({"id":"bible_practice_bell_frame","host_support_id":"boss_approach","root":[1220.0,576.0],"points":[[1220.0,576.0],[1220.0,500.0],[1240.0,390.0],[1290.0,360.0]],"attachments":{},"standing_edge":false,"base_width":10.0})
	m.practice_bell_contract = {"bell_radius":12.0,"complete_motion_sweep":[1248.0,384.0,84.0,48.0],"gate_cast_segment":[[1300.0,558.0],[1380.0,468.0]],"gate_cast_vertical_clearance_lower_bound":36.0,"standing_player_top":540.0,"standing_body_vertical_clearance_lower_bound":108.0,"observation_to_extreme_center_distance_upper_bound":167.0,"hook_range_source":"resources/player/traversal.tres","existing_enemies_preserved":true,"bell_is_non_damaging_not_an_enemy_free_guarantee":true,"native_verified":false}


static func _site(m: Dictionary, id: String, definition: String, at: Vector2, area: String, support: String, approach: String, returning: String) -> void:
	m.forest_discoveries.append({"id":id,"definition_id":definition,"position":API.pair(at),"area_id":area,"support_id":support,"approach_route":approach,"return_route":returning,"scene_kind":"forest_discovery","structure_id":str(API._platform_by_id(m,support).get("structure_id","hollow")),"host_support_id":support,"return_hint":"沿另一处树洞回到已见的根枝，再返回营地。"})

static func _p(m: Dictionary, id: String, rect: Rect2, one_way: bool, structure: String, role: String) -> void:
	API._platform(m,id,rect,one_way,"living_bough" if one_way else "root_earth",structure,role)

static func _anchor(m: Dictionary, id: String, at: Vector2, structure: String, support: String, stem: Vector2) -> void:
	m.hook_anchors.append({"id":id,"position":API.pair(at),"scene_kind":"copper_growth_ring","structure_id":structure,"fruit_role":"optional","fruit_role_basis":"Bible_backbranch_optional_skill","fruit_route_bindings":["available:bible_backbranch_flight:H"],"fruit_presentation":"rooted_fruit","fruit_host_support_id":support,"fruit_stem_root":API.pair(stem)})

static func validate(m: Dictionary) -> bool:
	if not THORN_SURFACES.validate(m): return false
	if not LANGUAGE.validate(m) or m.get("bible_world_contract",{}).get("version") != VERSION: return false
	if m.get("forest_discoveries",[]).size() != 3 or m.get("forest_shortcuts",[]).size() != 1: return false
	var ids: Dictionary = {}
	for category: String in ["platforms","hook_anchors","areas","connections","enemies","rewards","geometry_instances","forest_discoveries"]:
		ids.clear()
		for row: Dictionary in m[category]:
			if ids.has(row.id): return false
			ids[row.id] = true
	if not m.get("enemy_drops") is Dictionary: return false
	for enemy: Dictionary in m.enemies:
		var settled: Variant = m.enemy_drops.get(str(enemy.id))
		if not settled is Dictionary or settled.is_empty(): return false
		# Immutable historical no-drop enemies intentionally use this exact
		# minimal consumer row; never rewrite their canonical old bytes.
		if RandomStageGenerator.new()._same_data(settled,{"kind":"none","amount":0}) and str(enemy.id) != "bible_double_window_weaver": continue
		if settled.get("enemy_id") != str(enemy.id) or settled.get("stream_namespace") != "enemy_drops" or settled.get("content_version") != EnemyDropService.CONTENT_VERSION: return false
	for site: Dictionary in m.forest_discoveries:
		if API._platform_by_id(m,str(site.support_id)).is_empty() or not m.routes.has(site.approach_route) or not m.routes.has(site.return_route) or site.approach_route == site.return_route: return false
	for route_name: String in m.routes:
		var at := ""
		for edge_id: String in m.routes[route_name]:
			var edge := RECIPE._edge_by_id(m,edge_id)
			if edge.is_empty() or (not at.is_empty() and str(edge.a) != at): return false
			at = str(edge.b)
	return true

static func _area_point(m: Dictionary, id: String) -> Vector2:
	for row: Dictionary in m.areas:
		if str(row.id) == id: return API._point(row.position)
	return Vector2.ZERO
