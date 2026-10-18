class_name ForestWesternGrove
extends RefCounted
## Additional connected forest instances, using the existing expedition installer.
## No new movement/RNG/economy authority. Exact factories remain experimental.
const HOLLOW := preload("res://scripts/generation/forest_hollow_trunk_geometry.gd")
const LAYOUT_PATH := "res://scripts/generation/forest_expedition_layout.gd"

static func install(m: Dictionary) -> Dictionary:
	# Runtime lookup avoids a preload cycle when the expedition calls this helper.
	var api: Script=load(LAYOUT_PATH)
	var relay: String=str(m.choices.expedition_river)
	var river: Dictionary=api._install_chain(m,"river_chain",Vector2(-3800,900),relay)
	var bridge: Dictionary=api._install_chain(m,"western_bridge",Vector2(-2620,858),"bridge_five")
	var tree:=_install_hollow(m,api)
	var positions: Dictionary={"river_entry":Vector2(-3800,900),"river_crown":Vector2(-3445,858),"western_M":Vector2(-3000,900),"western_E":Vector2(-2620,858),"western_D":Vector2(-2880,1102),"western_R":Vector2(-2580,1182),"western_deep_join":Vector2(-300,1072),"western_river_catch":Vector2(-3710,1302)}
	for id: String in positions:
		api._area(m,id,positions[id],str({"river_entry":"RIVER ROOT / READ THE SIDE RINGS","river_crown":"RIVER CROWN / HOLLOW TRUNK AHEAD","western_M":"WESTERN HOLLOW / TWO WINDOWS","western_E":"WESTERN CROWN / THE SPLIT CANOPY","western_D":"WESTERN INNER ROOT / RETRY OR RETURN","western_R":"WESTERN ROOT / UNDERBRIDGE LOOP","western_deep_join":"DEEP ROOT / OLD GROTTO ABOVE","western_river_catch":"RIVER BASIN / WIDE RETRY ROOT"}[id]),"junction")
	api._air_edge(m,"river_air_relay","river_entry","river_crown",river)
	# The one-way crown overlaps the hollow's lower belly lip in x, but not y.
	# Leave its east side before dropping 42px onto the actual solid belly.
	api._edge(m,"river_to_western_belly","river_crown","western_M","ordinary_sequence",[api.pair(positions.river_crown),api.pair(positions.western_M)],[{"kind":"drop_through","path":[[-3445.0,858.0],[-3180.0,858.0],[-3180.0,900.0],[-3000.0,900.0]],"landing":[-3000.0,900.0]}])
	api._edge(m,"western_belly_to_river","western_M","river_crown","ordinary_sequence",[api.pair(positions.western_M),api.pair(positions.river_crown)],[api._step("jump_rise",Vector2(-3208,900),Vector2(-3290,858),"western_hollow__belly_entry","river_chain__crown")])
	_phrase(m,api,tree,"western_upper","western_M","western_E","hollow_upper","M","E",positions)
	# Descend in the broad left lane of the bridge hazard, not factory drop_x620.
	api._edge(m,"western_crown_descent","western_E","western_R","ordinary_sequence",[[-2620.0,858.0],[-2580.0,1182.0]],[{"kind":"drop_through","path":[[-2620.0,858.0],[-2620.0,858.0],[-2620.0,1182.0],[-2580.0,1182.0]],"landing":[-2580.0,1182.0]}])
	_phrase(m,api,tree,"western_lower_in","western_E","western_D","hollow_lower","E","D",positions)
	_phrase(m,api,tree,"western_window_return","western_R","western_D","hollow_outer_recovery","R","D",positions)
	m.connections[-1].path=[api.pair(positions.western_R),[-2630.0,1182.0],api.pair(positions.western_D)]
	# The neighboring river crown is above the belly approach. Use it as an
	# explicit return landing, then reuse the visible east-side descent. The
	# isolated hollow's D->M jump would catch this real neighboring support.
	api._edge(m,"western_inner_recovery","western_D","river_crown","ordinary_sequence",[api.pair(positions.western_D),api.pair(positions.river_crown)],[
		api._step("jump_rise",Vector2(-3270,1102),Vector2(-3270,1000),"western_hollow__inner_root","western_hollow__inner_recovery_step"),
		api._step("jump_rise",Vector2(-3270,1000),Vector2(-3270,858),"western_hollow__inner_recovery_step","river_chain__crown").merged({"hold_to_receiver":true})])
	api._air_edge(m,"western_air_bridge","western_E","fallen_entry",bridge)
	_install_lower_loop(m,api)
	_install_river_recovery(m,api)
	var enemies: Array=_enemy_suggestions()
	var prefix: Array=["river_air_relay","river_to_western_belly","western_upper","western_air_bridge"]
	m.western_grove_contract={"version":"western-river-hollow-root-loop-v1","prefix":prefix.duplicate(),"lower_loop":["western_crown_descent","western_root_eastward","western_deep_to_grotto","grotto_fallen_recovery"],"existing_factories_only":true,"reward_added":false,"native_verified":false,"enemy_suggestions":enemies.duplicate(true),"field_recovery_not_standalone_recovery":true}
	return {"prefix":prefix,"entry":api.pair(positions.river_entry),"nodes":positions,"river_instance":river.id,"hollow_instance":tree.id,"bridge_instance":bridge.id,"lower_edges":["western_crown_descent","western_root_eastward","western_deep_to_grotto"],"return_edges":["grotto_to_western_deep","western_root_westward","western_window_return","western_inner_recovery"],"enemy_rows":enemies,"reward_relocation_proposed":false,"native_verified":false}

static func _install_hollow(m: Dictionary,api: Script) -> Dictionary:
	var raw: Dictionary=HOLLOW.build("deep_zeroR")
	var offset:=Vector2(-3000,900)
	var row: Dictionary={"id":"western_hollow","factory_path":"res://scripts/generation/forest_hollow_trunk_geometry.gd","factory_entry":"build","factory_argument":"deep_zeroR","factory_version":raw.version,"factory_sha256":FileAccess.get_sha256("res://scripts/generation/forest_hollow_trunk_geometry.gd"),"translation":api.pair(offset),"facing":1,"source_geometry":raw.duplicate(true),"local_geometry":raw.duplicate(true),"derivations":[],"platform_id_map":{},"anchor_id_map":{},"enemy_id_map":{},"danger_indices":[],"inserted_into_platforms":true,"protected_bounds":[-3340.0,350.0,1100.0,1040.0],"port_corridors":[],"native_verified":false}
	for support: Dictionary in raw.platforms:
		var at:=Rect2(support.rect[0],support.rect[1],support.rect[2],support.rect[3]);at.position+=offset
		var id: String="western_hollow__"+str(support.id)
		row.platform_id_map[support.id]=id
		var kind: String="canopy_perch" if str(support.id)=="outer_crown" else "root_earth" if str(support.id) in ["inner_root","outer_root","outer_sump"] else "living_bough" if bool(support.one_way) else "hollow_bark"
		api._platform(m,id,at,bool(support.one_way),kind,"western_hollow",str(support.id))
	for anchor: Dictionary in raw.hook_anchors:
		var id: String="western_hollow__"+str(anchor.id)
		row.anchor_id_map[anchor.id]=id
		m.hook_anchors.append({"id":id,"position":api.pair(Vector2(anchor.position[0],anchor.position[1])+offset),"structure_id":"western_hollow","scene_kind":"copper_growth_ring"})
	for danger: Array in raw.dangers:
		row.danger_indices.append(m.dangers.size())
		m.dangers.append([float(danger[0])+offset.x,float(danger[1])+offset.y,danger[2],danger[3]])
	m.geometry_instances.append(row)
	return row

static func _phrase(m: Dictionary,api: Script,instance: Dictionary,id: String,a: String,b: String,kind: String,from_port: String,to_port: String,points: Dictionary) -> void:
	api._edge(m,id,a,b,kind,[api.pair(points[a]),api.pair(points[b])])
	var support: String=str(instance.platform_id_map[instance.local_geometry.nodes[to_port].support_id])
	m.connections[-1].merge({"geometry_instance":instance.id,"from_port":from_port,"to_port":to_port,"entry_role":from_port,"exit_role":to_port,"landing":api.pair(points[b]),"landing_support_id":support,"native_verified":false})

static func _install_lower_loop(m: Dictionary,api: Script) -> void:
	# Stay below both the five-chain thorn strip (y958) and solid fallen roots
	# (y920..960). Ascend only beyond the solid catch's east edge x=-720.
	api._platform(m,"western_root_knuckle",Rect2(-2310,1200,460,44),false,"root_earth","western_underbridge","wide_root_knuckle")
	api._platform(m,"western_fallen_log",Rect2(-1760,1200,500,36),false,"fallen_log","western_underbridge","fallen_trunk_top")
	api._platform(m,"western_root_exit",Rect2(-1150,1200,630,54),false,"root_earth","western_underbridge","east_root_observation")
	# Enter the under-log corridor from its open west mouth, not by jumping
	# into the solid log underside. This floor joins the existing deep root.
	api._platform(m,"western_underlog_root",Rect2(-900,1090,500,40),false,"root_earth","root_grotto","underlog_tunnel_floor")
	api._edge(m,"western_root_eastward","western_R","western_deep_join","ordinary_sequence",[[-2580.0,1182.0],[-300.0,1072.0]],[
		api._step("jump_gap",Vector2(-1875,1182),Vector2(-1735,1182),"western_root_knuckle","western_fallen_log").merged({"hold_to_receiver":true}),
		api._step("jump_gap",Vector2(-1285,1182),Vector2(-1125,1182),"western_fallen_log","western_root_exit").merged({"hold_to_receiver":true}),
		api._step("jump_rise",Vector2(-950,1182),Vector2(-840,1072),"western_root_exit","western_underlog_root")])
	api._edge(m,"western_deep_to_undergrowth","western_deep_join","undergrowth","ordinary_sequence",[[-300.0,1072.0],[160.0,982.0]],[api._step("jump_rise",Vector2(-60,1072),Vector2(160,982),"grotto_deep_root","grotto_east_root")])
	api._edge(m,"western_deep_to_grotto","western_deep_join","root_grotto","ordinary_sequence",[[-300.0,1072.0],[-1000.0,902.0]],[
		api._step("jump_rise",Vector2(-370,1072),Vector2(-470,982),"grotto_deep_root","grotto_west_lip"),
		api._step("jump_rise",Vector2(-690,982),Vector2(-800,902),"grotto_west_lip","fallen_chain__recovery")])
	api._edge(m,"grotto_to_western_deep","root_grotto","western_deep_join","ordinary_sequence",[[-1000.0,902.0],[-300.0,1072.0]],[
		{"kind":"drop_through","path":[[-1000.0,902.0],[-690.0,902.0],[-690.0,982.0]],"landing":[-690.0,982.0]},
		{"kind":"drop_through","path":[[-690.0,982.0],[-300.0,982.0],[-300.0,1072.0]],"landing":[-300.0,1072.0]}])
	api._edge(m,"western_root_westward","western_deep_join","western_R","ordinary_sequence",[[-300.0,1072.0],[-2580.0,1182.0]],[
		{"kind":"drop_through","path":[[-300.0,1072.0],[-950.0,1072.0],[-950.0,1182.0]],"landing":[-950.0,1182.0]},
		api._step("jump_gap",Vector2(-1125,1182),Vector2(-1285,1182),"western_root_exit","western_fallen_log").merged({"hold_to_receiver":true}),
		api._step("jump_gap",Vector2(-1735,1182),Vector2(-1875,1182),"western_fallen_log","western_root_knuckle").merged({"hold_to_receiver":true})])

static func _install_river_recovery(m: Dictionary,api: Script) -> void:
	api._platform(m,"western_river_basin",Rect2(-4170,1320,890,50),false,"root_earth","river_root_basin","wide_failure_catch")
	api._platform(m,"western_river_step0",Rect2(-4135,1210,100,20),true,"living_bough","river_root_basin","west_retry_step")
	api._platform(m,"western_river_step1",Rect2(-4135,1100,100,20),true,"living_bough","river_root_basin","west_retry_step")
	api._platform(m,"western_river_step2",Rect2(-4135,990,100,20),true,"living_bough","river_root_basin","west_retry_step")
	api._platform(m,"western_river_inner_step",Rect2(-3425,1230,110,20),true,"living_bough","river_root_basin","inner_root_return_step")
	api._edge(m,"western_basin_retry","western_river_catch","river_entry","ordinary_sequence",[[-3710.0,1302.0],[-3800.0,900.0]],[
		api._step("jump_rise",Vector2(-4085,1302),Vector2(-4085,1192),"western_river_basin","western_river_step0"),
		api._step("jump_rise",Vector2(-4085,1192),Vector2(-4085,1082),"western_river_step0","western_river_step1"),
		api._step("jump_rise",Vector2(-4085,1082),Vector2(-4085,972),"western_river_step1","western_river_step2"),
		api._step("jump_rise",Vector2(-4085,972),Vector2(-3900,900),"western_river_step2","river_chain__entry")])
	api._edge(m,"western_inner_to_basin","western_D","western_river_catch","ordinary_sequence",[[-2880.0,1102.0],[-3710.0,1302.0]],[
		{"kind":"drop_through","path":[[-2880.0,1102.0],[-3370.0,1102.0],[-3370.0,1212.0]],"landing":[-3370.0,1212.0]},
		{"kind":"drop_through","path":[[-3370.0,1212.0],[-3460.0,1212.0],[-3710.0,1302.0]],"landing":[-3710.0,1302.0]}])
	api._edge(m,"western_basin_to_inner","western_river_catch","western_D","ordinary_sequence",[[-3710.0,1302.0],[-2880.0,1102.0]],[
		api._step("jump_rise",Vector2(-3370,1302),Vector2(-3370,1212),"western_river_basin","western_river_inner_step"),
		api._step("jump_rise",Vector2(-3370,1212),Vector2(-3240,1102),"western_river_inner_step","western_hollow__inner_root")])

static func _enemy_suggestions() -> Array:
	# Suggestions only: existing expedition placement/body-exclusion/drop service
	# owns admission. No enemy or reward is injected by this helper.
	return [
		{"id":"western_root_beetle","behavior":"forest_bark_beetle","position":[-2130.0,1188.0],"radius":55.0,"support":"western_root_knuckle","direction":-1,"role":"wide root shield before the log gap; flank on the broad shore or bait dash toward the gap"},
		{"id":"western_log_watch","behavior":"forest_seed_sentry","position":[-1510.0,1182.0],"radius":0.0,"support":"western_fallen_log","role":"telegraphed root-lane seeds; wait on opposite broad shore, jump the gap during preview or use gunfire"},
		{"id":"western_exit_beetle","behavior":"forest_bark_beetle","position":[-850.0,1188.0],"radius":60.0,"support":"western_root_exit","direction":1,"role":"shield on return direction; the far root shelf offers a height change and recovery"},
		{"id":"western_basin_watch","behavior":"forest_seed_sentry","position":[-3520.0,1302.0],"radius":0.0,"support":"western_river_basin","role":"basin sentry away from the retry ladder; decide whether to return through the window or climb the west root"}]

static func relocate_cache(m: Dictionary) -> bool:
	# Caller selects this topology on its own versioned random stream. This moves
	# one existing cache; it never grants a second reward or changes its ledger.
	var rewards: Variant=m.get("rewards")
	if not rewards is Array or rewards.size()!=1 or not rewards[0] is Dictionary: return false
	var reward: Dictionary=rewards[0]
	if not reward.get("id") is String or str(reward.id).is_empty() or reward.get("area")!="cache": return false
	var cache: Dictionary={}
	for area: Dictionary in m.get("areas",[]):
		if area.id=="cache":
			if not cache.is_empty(): return false
			cache=area
	if cache.is_empty(): return false
	for row: Dictionary in m.get("platforms",[]):
		if row.id=="western_cache_bough": return false
	var api: Script=load(LAYOUT_PATH)
	# Left of the solid roof x[-3220,-2790], y[380,790]. The cache itself
	# occupies x[-3312,-3288], y[764,800]: 68px from its right body to roof.
	api._platform(m,"western_cache_bough",Rect2(-3390,800,200,24),true,"fallen_log","western_hollow","optional_cache_bough")
	cache.position=[-3300.0,782.0]
	cache.label="WESTERN BOUGH CACHE / RIVER RETURN"
	reward.position=[-3300.0,782.0]
	var retained: Array=[]
	for edge: Dictionary in m.connections:
		if edge.a!="cache" and edge.b!="cache": retained.append(edge)
	m.connections=retained
	# Approach from the exposed river crown: jumping directly out of the
	# belly leaves only a few pixels before the real roof catches the head.
	api._edge(m,"western_cache_rise","river_crown","cache","ordinary_sequence",[[-3445.0,858.0],[-3300.0,782.0]],[api._step("jump_rise",Vector2(-3340,858),Vector2(-3300,782),"river_chain__crown","western_cache_bough")])
	# Never descend along the roof's right end: body would enter solid bark.
	# Walk beyond the bough's west lip, then land on the visible river receiver.
	api._edge(m,"western_cache_river_exit","cache","river_crown","drop_through",[[-3300.0,782.0],[-3445.0,782.0],[-3445.0,858.0]])
	m.connections[-1].merge({"claim_before_edge":true,"claim_area":"cache","claim_id":str(reward.id)})
	# Metadata describes the new reachable reward, never removed historical edges.
	var edge_ids: Dictionary={}
	for edge: Dictionary in m.connections:edge_ids[str(edge.id)]=true
	for loop_id: String in m.macro_loops.keys():
		var retained_loop: bool=true
		for edge_id: String in m.macro_loops[loop_id]:
			if not edge_ids.has(edge_id):retained_loop=false
		if not retained_loop:m.macro_loops.erase(loop_id)
	m.macro_loops.western_reward=["western_cache_rise","western_cache_river_exit"]
	if m.has("crossbranch_contract"):
		m.crossbranch_contract.erase("claim_edge")
		m.crossbranch_contract.return_edge=m.crossbranch_contract.decline_edge
		m.crossbranch_contract.reward_available=false
	m.discovery_contract.reward_endpoints=["river_crown"]
	m.discovery_contract.reward_relationship="western hollow side bough reached from the exposed river crown; same original cache economy; return to the crown and choose high bridge or underbridge route"
	m.discovery_contract.erase("upper_reward_exit")
	m.loop_sharing.crosslink_endpoints=["western_M","river_crown"]
	reward.crosslink="western_hollow_river_bough"
	m.western_cache_contract={"selected":true,"reward_id":str(reward.id),"reward_count":rewards.size(),"position":[-3300.0,782.0],"support_id":"western_cache_bough","entry_edge":"western_cache_rise","exit_edge":"western_cache_river_exit","return_node":"river_crown","reward_added":false,"economy_changed":false,"native_verified":false,"ceiling_constraint":"approach from river crown left of roof; avoid direct belly-to-cache jump"}
	return true
