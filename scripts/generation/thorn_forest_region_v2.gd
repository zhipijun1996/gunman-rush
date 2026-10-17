class_name ThornForestRegionV2
extends RefCounted
## Experimental forest layouts; default registry stays v1. Data is not Motor proof.
const VERSION := "thorn-forest-region-v2"
const LAYOUT_VERSION := "hollow-clearing-upper-thorn-candidate-v2"
const FAMILIES := ["hollow_inner_first","hollow_root_first","clearing_shared_edge","clearing_shared_node"]
const HOLLOW := preload("res://scripts/generation/forest_hollow_trunk_geometry.gd")
const ARENA_FACTORY_PATH := "res://scripts/generation/forest_boss_arena_factory.gd"
static func seed_for(root_seed: String,map_index: int) -> String:return root_seed+"/thorn_forest/map_%s"%map_index
func generate(seed_value: String,tuning: PlayerTuning,map_index:=1,capability_snapshot: Dictionary={}) -> Dictionary:
	var result:=generate_spatial_candidate(seed_value,tuning,map_index,capability_snapshot)
	if result.get("ok",false) and not result.manifest.boss_contract.get("ok",false):
		result.ok=false;result.error="Forest v2 experimental spatial candidate only: "+str(result.manifest.boss_contract.get("reason","Boss not promoted"))
	return result
func generate_spatial_candidate(seed_value: String,tuning: PlayerTuning,map_index:=1,capability_snapshot: Dictionary={}) -> Dictionary:
	if seed_value.is_empty() or tuning==null or map_index not in [1,2] or not capability_snapshot.get("grapple",false):return {"ok":false,"error":"Forest v2 requires H, tuning, seed and map1/2"}
	var abilities: Variant=capability_snapshot.get("abilities",["grapple"])
	if not abilities is Array or abilities.size()!=1 or str(abilities[0])!="grapple":return {"ok":false,"error":"Forest v2 S2 requires H only"}
	for forbidden: String in ["wall_climb","double_jump","weapon_evolution_1","weapon_evolution_2"]:
		if capability_snapshot.get(forbidden,false):return {"ok":false,"error":"Forest v2 cannot require "+forbidden}
	var m:=_candidate(seed_value,map_index)
	if not _validate_structure(m,tuning):return {"ok":false,"error":"Experimental hollow/clearing data contract failed"}
	var points: Array[Vector2]=[]
	for area: Dictionary in m.areas:points.append(_point(area.position))
	return {"ok":true,"manifest":m,"stage_generator_version":VERSION,"boss_arena":_rect(m.boss_arena),"placement_points":points,"encounter_plan":{"version":VERSION,"enemies":m.enemies.duplicate(true)},"exit_points":[],"admission":"experimental_not_formal_motor_verified","production_pool":false}
func _candidate(seed_value: String,map_index: int) -> Dictionary:
	var topology:=RunRandomStream.new(seed_value,"forest_topology","map_%s"%map_index,VERSION)
	var content:=RunRandomStream.new(seed_value,"forest_ecology","map_%s"%map_index,VERSION)
	var variant:=topology.next_int(2)
	var family: String=FAMILIES[variant+(2 if map_index==2 else 0)]
	var m: Dictionary={"version":VERSION,"layout_version":LAYOUT_VERSION,"region":"thorn_forest","map_index":map_index,"seed":seed_value,"family":family,"layout_id":family,"fallback_id":"","requires":["grapple"],"production_pool":false,
		"player_tuning_hash":FileAccess.get_sha256("res://config/player_tuning.json"),"traversal_hash":FileAccess.get_sha256("res://resources/player/traversal.tres"),
		"platforms":[],"hook_anchors":[],"areas":[],"connections":[],"rewards":[],"pickups":[],"enemies":[],"enemy_drops":{},"dangers":[],"geometry_instances":[],"nodes":[{"id":"forest_v2","mirrored":false}],
		"merchant_id":"root_camp","shop":{"item":"health_blue","price":5,"stock":1},"shot_latch_plan":{"version":1,"latches":[]},"terminal_exits":[],
		"choices":{"skeleton":variant,"enemy_mix":content.next_int(2)},"streams":{"topology":"forest_topology","content":"forest_ecology","version":VERSION},
		"admission":{"geometry":"new_shared_trunk_experimental","motor":"unverified","seams":"unverified","visual":"unverified"}}
	var offset:=Vector2(600,600)
	_install_hollow(m,offset,variant==1)
	var p: Dictionary={"M":offset,"E":offset+Vector2(380,-42),"D":offset+Vector2(120,202),"R":offset+Vector2(420,282)}
	for id: String in p:_area(m,id,p[id],{"M":"TREE BELLY","E":"OUTER CROWN","D":"INNER ROOT","R":"OUTER ROOT"}[id],"junction")
	_core_edges(m,p,variant==1)
	if map_index==1:_single_tree(m,p,variant)
	else:_clearing(m,p,variant)
	_install_encounters(m,content)
	_install_boss(m,p)
	if variant==0:
		# Reward is a crossing with a real upward exit through the ONE-WAY
		# prep branch. Growth can continue to Boss without repeating upper H.
		_edge(m,"reward_to_prep","cache","prep","ordinary_sequence",[_pair(p.cache),_pair(p.prep)],[{"kind":"jump_rise","takeoff":_pair(p.cache),"landing":_pair(p.prep),"from_support_id":"outer_reward_branch","support_id":"boss_approach"}])
	for edge: Dictionary in m.connections:
		if edge.a=="cache":edge.merge({"claim_before_edge":true,"claim_area":"cache","claim_id":str(m.rewards[0].id)})
	m.routes=_routes(m)
	m.routes.change_mind=_route(m,"arrival","E");m.routes.change_mind.append_array(_route(m,"E","camp"))
	m.change_mind_contract={"decision_node":"E","planned_goal":"gate_ready","chosen_goal":"camp","actual_input":"unverified"}
	m.topology_signature=topology_signature(m)
	m.stream_positions={"topology":topology.position(),"content":content.position()}
	var bounds:=Rect2(_point(m.spawn),Vector2.ONE)
	for row: Dictionary in m.platforms:bounds=bounds.merge(_rect(row.rect))
	for anchor: Dictionary in m.hook_anchors:bounds=bounds.expand(_point(anchor.position))
	bounds=bounds.grow(200);m.world_bounds=[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y]
	m.manifest_hash=_hash(m)
	return m
func _install_hollow(m: Dictionary,offset: Vector2,split_entry: bool) -> void:
	var raw: Dictionary=HOLLOW.build("deep_zeroR")
	var source:=raw.duplicate(true)
	var modifications: Array=[]
	# Replace actual solid material, never hide spikes inside a collider or
	# narrow the previously safe 70px H opening. This derivation is UNVERIFIED.
	for platform: Dictionary in raw.platforms:
		if platform.id=="trunk_above_window":platform.rect=[210.0,-520.0,120.0,402.0]
	raw.dangers=[[210.0,-118.0,120.0,24.0]]
	modifications.append("upper trunk removed local[210,-118,120,24] becomes visible actual thorn; original window y[-94,-24] unchanged; NOT inherited hollow05 proof")

	if split_entry:
		# A real broad side-cavity route, not merely a moved chest label.
		# The right support still owns the original spawn/upper H takeoff.
		raw.platforms[0]={"id":"belly_entry","rect":[-80.0,18.0,160.0,60.0],"one_way":false}
		raw.platforms.append({"id":"belly_west","rect":[-220.0,18.0,100.0,60.0],"one_way":false})
		modifications.append("entry floor split at localx[-120,-80] for actual lower-to-upper side cavity; NOT inherited hollow05 proof")
	var instance: Dictionary={"id":"hollow","factory_path":"res://scripts/generation/forest_hollow_trunk_geometry.gd","factory_version":raw.version,"factory_sha256":FileAccess.get_sha256("res://scripts/generation/forest_hollow_trunk_geometry.gd"),"translation":_pair(offset),"facing":1,"source_geometry":source,"local_geometry":raw,"derivations":modifications,"platform_id_map":{},"anchor_id_map":{},"enemy_id_map":{},"danger_indices":[],"inserted_into_platforms":true,"protected_bounds":[260.0,50.0,1100.0,1040.0],"port_corridors":[],"native_verified":false}
	for row: Dictionary in raw.platforms:
		var rect:=_rect(row.rect);rect.position+=offset
		var id: String="hollow__"+str(row.id);instance.platform_id_map[row.id]=id
		_platform(m,id,rect,bool(row.one_way))
	for danger: Array in raw.dangers:
		var rect:=_rect(danger);rect.position+=offset
		instance.danger_indices.append(m.dangers.size())
		m.dangers.append([rect.position.x,rect.position.y,rect.size.x,rect.size.y])
	m.danger_presentations=[{"facing":"down"}]
	m.thorn_window_contract={"id":"upper_thorn_ceiling","danger_indices":instance.danger_indices.duplicate(),"safe_window_world":[810.0,506.0,120.0,70.0],"replaces_solid_world":[810.0,482.0,120.0,24.0],"purpose":"same upper H then lateral recoil through unchanged opening","error":"actual upward body/head contact with visible thorn, recover locally and retry","native_verified":false}
	for row: Dictionary in raw.hook_anchors:
		var id: String="hollow__"+str(row.id);instance.anchor_id_map[row.id]=id
		m.hook_anchors.append({"id":id,"position":_pair(_point(row.position)+offset)})
	m.geometry_instances.append(instance)
func _core_edges(m: Dictionary,p: Dictionary,split: bool) -> void:
	_phrase(m,"upper_out","M","E","hollow_upper","M","E",p)
	_phrase(m,"lower_in","E","D","hollow_lower","E","D",p)
	_phrase(m,"inner_recovery","D","M","hollow_recovery","D","M",p)
	m.connections[-1].landing_support_id="hollow__belly_west" if split else "hollow__belly_entry"
	m.connections[-1].landing=[420.0,600.0]
	if split:
		m.connections[-1].post_landing_steps=[{"kind":"jump_gap","takeoff":[468.0,600.0],"landing":[532.0,600.0],"from_support_id":"hollow__belly_west","support_id":"hollow__belly_entry"}]
	_edge(m,"belly_drop","M","D","drop",[_pair(p.M),[700.0,600.0],[700.0,802.0],_pair(p.D)])
	_edge(m,"outer_drop","E","R","drop_through",[_pair(p.E),[1020.0,558.0],_pair(p.R)])
	_edge(m,"outer_to_inner","R","D","hollow_outer_recovery",[_pair(p.R),[970.0,882.0],_pair(p.D)])
	m.connections[-1].geometry_instance="hollow";m.connections[-1].anchor_id="hollow__lower_window_ring";m.connections[-1].native_verified=false
func _single_tree(m: Dictionary,p: Dictionary,variant: int) -> void:
	if variant==0:
		p.arrival=p.M;p.camp=Vector2(360,802);p.cache=Vector2(1300,672)
		_platform(m,"outer_reward_branch",Rect2(1220,690,240,24),true)
		_reward(m,"outer_cross_cache",p.cache,"E_R_crosslink")
		_edge(m,"reward_descent","E","cache","drop_through",[_pair(p.E),[1300.0,558.0],_pair(p.cache)])
		_edge(m,"reward_other_exit","cache","R","drop",[_pair(p.cache),[1200.0,672.0],[1200.0,882.0],_pair(p.R)])
		_walk_pair(m,"camp_inner","D","camp",p)
		m.macro_loops={"inner":["upper_out","lower_in","inner_recovery"],"reward":["upper_out","reward_descent","reward_other_exit","outer_to_inner","inner_recovery"]}
		m.discovery_contract={"entry":"M","first_choices":["outer_crown_and_boss","drop_to_inner_camp"],"reward_endpoints":["E","R"],"return_camp":"camp","status":"unverified_actual_visibility"}
	else:
		p.arrival=p.R;p.camp=Vector2(1230,882);p.cache=Vector2(500,720)
		_platform(m,"inner_reward_branch",Rect2(400,738,240,20),true)
		_reward(m,"inner_cavity_cache",p.cache,"D_M_crosslink")
		_edge(m,"reward_inner_rise","D","cache","ordinary_sequence",[_pair(p.D),[610.0,802.0],_pair(p.cache)],[{"kind":"jump_rise","takeoff":[610.0,802.0],"landing":_pair(p.cache),"from_support_id":"hollow__inner_root","support_id":"inner_reward_branch"}])
		_edge(m,"reward_belly_exit","cache","M","ordinary_sequence",[_pair(p.cache),[500.0,580.0],[550.0,600.0],_pair(p.M)],[{"kind":"jump_rise_through_gap","takeoff":_pair(p.cache),"clearance_x":[480.0,520.0],"clear_feet_y":616.0,"landing":[550.0,600.0],"from_support_id":"inner_reward_branch","support_id":"hollow__belly_entry"}])
		_walk_pair(m,"camp_outer","R","camp",p)
		m.macro_loops={"main":["outer_to_inner","inner_recovery","upper_out","outer_drop"],"reward":["outer_to_inner","reward_inner_rise","reward_belly_exit","upper_out","outer_drop"]}
		m.discovery_contract={"entry":"R","first_choices":["nearby_outer_camp","inside_lower_window_then_cavity_or_recovery"],"reward_endpoints":["D","M"],"return_camp":"camp","status":"unverified_actual_visibility"}
	_finish_areas(m,p,variant)
func _clearing(m: Dictionary,p: Dictionary,variant: int) -> void:
	# One shared central tree, surrounding courts share actual bodies/ports;
	# not three copied protected Lab boxes. All NEW seams remain unverified.
	p.W=Vector2(180,600);p.N=Vector2(200,450);p.J=p.M
	_platform(m,"west_court",Rect2(40,618,260,28),true)
	_platform(m,"north_court",Rect2(60,468,220,24),true)
	m.hook_anchors.append({"id":"west_gap_ring","position":[300.0,530.0]})
	m.hook_anchors.append({"id":"north_court_ring","position":[300.0,350.0]})
	for id: String in ["W","N"]:_area(m,id,p[id],"WEST ROOT" if id=="W" else "NORTH COURT","junction")
	p.arrival=p.W
	_edge(m,"west_to_belly","W","M","ordinary_sequence",[_pair(p.W),[288.0,600.0],[392.0,600.0],_pair(p.M)],[{"kind":"jump_gap","takeoff":[288.0,600.0],"landing":[392.0,600.0],"from_support_id":"west_court","support_id":"hollow__belly_west" if variant==1 else "hollow__belly_entry"}])
	_edge(m,"belly_to_west","M","W","ordinary_sequence",[_pair(p.M),[392.0,600.0],[288.0,600.0],_pair(p.W)],[{"kind":"jump_gap","takeoff":[392.0,600.0],"landing":[288.0,600.0],"from_support_id":"hollow__belly_west" if variant==1 else "hollow__belly_entry","support_id":"west_court"}])
	if variant==1:
		var gap_step: Dictionary={"kind":"jump_gap","takeoff":[468.0,600.0],"landing":[532.0,600.0],"from_support_id":"hollow__belly_west","support_id":"hollow__belly_entry"}
		m.connections[-2].steps.append(gap_step)
		m.connections[-1].steps.push_front({"kind":"jump_gap","takeoff":[532.0,600.0],"landing":[468.0,600.0],"from_support_id":"hollow__belly_entry","support_id":"hollow__belly_west"})
	if variant==0:
		p.camp=Vector2(360,802);p.cache=Vector2(1300,672)
		_platform(m,"outer_reward_branch",Rect2(1220,690,240,24),true)
		_reward(m,"clearing_edge_cache",p.cache,"D_E_crosslink")
		_edge(m,"west_to_deep","W","D","drop_through",[_pair(p.W),[290.0,600.0],[302.0,802.0],_pair(p.D)])
		_edge(m,"deep_to_west","D","W","candidate_hook_relay",[_pair(p.D),[360.0,720.0],[300.0,530.0],_pair(p.W)])
		m.connections[-1].anchor_id="west_gap_ring"
		_edge(m,"reward_descent","E","cache","drop_through",[_pair(p.E),[1300.0,558.0],_pair(p.cache)])
		_edge(m,"reward_other_exit","cache","R","drop",[_pair(p.cache),[1200.0,672.0],[1200.0,882.0],_pair(p.R)])
		_walk_pair(m,"camp_inner","D","camp",p)
		m.macro_loops={"left":["west_to_deep","inner_recovery","belly_to_west"],"right":["upper_out","reward_descent","reward_other_exit","outer_to_inner","inner_recovery"]}
		m.loop_sharing={"kind":"shared_edge","nodes":["M","D"],"edge":"inner_recovery","warning":"reverse is own candidate, not implied by arrow"}
	else:
		p.camp=p.N;p.cache=Vector2(500,720)
		_platform(m,"inner_reward_branch",Rect2(400,738,240,20),true)
		_reward(m,"clearing_cross_loop_cache",p.cache,"N_D_crosslink")
		_edge(m,"west_north","W","N","candidate_hook_relay",[_pair(p.W),[180.0,500.0],[300.0,350.0],_pair(p.N)])
		m.connections[-1].anchor_id="north_court_ring"
		_edge(m,"north_belly","N","M","ordinary_sequence",[_pair(p.N),[268.0,450.0],[392.0,600.0],_pair(p.M)],[{"kind":"jump_gap","takeoff":[268.0,450.0],"landing":[392.0,600.0],"from_support_id":"north_court","support_id":"hollow__belly_west"}])
		m.connections[-1].steps.append({"kind":"jump_gap","takeoff":[468.0,600.0],"landing":[532.0,600.0],"from_support_id":"hollow__belly_west","support_id":"hollow__belly_entry"})
		_edge(m,"north_reward","N","cache","candidate_hook_relay",[_pair(p.N),[300.0,600.0],_pair(p.cache)])
		m.connections[-1].anchor_id="west_gap_ring"
		_edge(m,"reward_deep_exit","cache","D","drop_through",[_pair(p.cache),[650.0,720.0],_pair(p.D)])
		_walk_pair(m,"camp_north","N","camp",p)
		m.macro_loops={"left":["west_north","north_belly","belly_to_west"],"right":["upper_out","lower_in","inner_recovery"]}
		m.loop_sharing={"kind":"shared_node","nodes":["M"],"crosslink_endpoints":["N","D"]}
	m.discovery_contract={"entry":"W","first_choices":["central_window","north_camp" if variant==1 else "lower_camp"],"reward_endpoints":["N","D"] if variant==1 else ["E","R"],"loop_sharing":m.loop_sharing.kind,"status":"unverified_actual_visibility"}
	_finish_areas(m,p,variant)
func _finish_areas(m: Dictionary,p: Dictionary,variant: int) -> void:
	for id: String in ["arrival","camp","cache"]:_area(m,id,p[id],{"arrival":"FOREST ENTRY","camp":"ROOT CAMP","cache":"CROSSING CACHE"}[id],{"arrival":"tutorial","camp":"merchant","cache":"challenge_reward"}[id])
	m.spawn=_pair(p.arrival);m.camp_area="camp";m.merchant_position=_pair(p.camp)
	var node: String="M" if int(m.map_index)==1 and variant==0 else ("R" if int(m.map_index)==1 else "W")
	_edge(m,"arrival_reading","arrival",node,"walk",[_pair(p.arrival),_pair(p[node])])
	m.pickups.append({"id":"camp_heart","kind":"heart","amount":1,"position":_pair(p.camp+Vector2(-35,-5))})
func _install_encounters(m: Dictionary,content: RunRandomStream) -> void:
	# Real Definitions; placements are experiments, not old 2600px ecology proof.
	var rows: Array=[{"id":"root_patrol","behavior":"charger","x":520.0,"floor":820.0,"support":"hollow__inner_root"},
		{"id":"outer_watch","behavior":"forest_seed_sentry","x":1150.0,"floor":576.0,"support":"hollow__outer_crown"},
		{"id":"canopy_lantern","behavior":"forest_lantern","x":1050.0,"y":380.0,"support":""}]
	if int(m.map_index)==2:rows.append({"id":"west_watch","behavior":"forest_seed_sentry","x":160.0,"floor":618.0,"support":"west_court"})
	var camp:=_point(m.merchant_position)
	for row: Dictionary in rows:
		var path: String="res://resources/enemies/"+("plains_charger" if row.behavior=="charger" else str(row.behavior))+".tres"
		var definition:=load(path) as EnemyDefinition
		var at:=Vector2(float(row.x),float(row.get("y",0)) if definition.aerial else float(row.floor)-definition.collision_size.y*.5)
		if at.distance_to(camp)<350 or at.distance_to(_point(m.spawn))<150:continue
		m.enemies.append({"id":"hollow_route__"+str(row.id),"behavior_id":String(definition.behavior_id),"definition_path":path,"definition_sha256":FileAccess.get_sha256(path),"stable_id":String(definition.stable_id),"position":_pair(at),"aerial":definition.aerial,"patrol_radius":minf(definition.patrol_half_width,45.0),"support_id":row.support,"encounter_role":"experimental_shared_space_ordinary_pressure_not_new_enemy_claim"})
	var dropper:=EnemyDropService.new();dropper.configure(str(m.seed),"thorn_forest/map_%s"%m.map_index)
	for row: Dictionary in m.enemies:m.enemy_drops[row.id]=dropper.settle(StringName(row.id))
	m.encounter_plan_contract={"active_count":m.enemies.size(),"camp_exclusion_radius":350.0,"spawn_exclusion_radius":150.0,"full_route_phases":"unverified","not_legacy_woven_proof":true}
func _install_boss(m: Dictionary,p: Dictionary) -> void:
	p.prep=Vector2(1300,558);p.gate_ready=Vector2(1400,558)
	_platform(m,"boss_approach",Rect2(1176,576,284,24),true)
	for id: String in ["prep","gate_ready"]:_area(m,id,p[id],"BOSS APPROACH","prep")
	_edge(m,"crown_prep","E","prep","walk",[_pair(p.E),_pair(p.prep)])
	_edge(m,"crown_approach","prep","gate_ready","gate_hook",[_pair(p.prep),_pair(p.gate_ready)])
	m.hook_anchors.append({"id":"crown_approach_ring_0","position":[1380.0,468.0]})
	m.connections[-1].anchor_id="crown_approach_ring_0";m.connections[-1].support_id="boss_approach"
	var contract: Dictionary=load(ARENA_FACTORY_PATH).new().call("from_prep",Vector2(1460,558),int(m.map_index))
	m.boss_contract=contract.duplicate(true);m.boss_geometry=contract.duplicate(true);m.boss_approach_origin=[1460.0,558.0]
	m.boss_arena=contract.get("boss_arena",[1484.0,56.0,0.0,0.0])
	if contract.get("ok",false):
		m.platforms.append_array(contract.platforms.duplicate(true));m.hook_anchors.append_array(contract.hook_anchors.duplicate(true));m.boss_root_supports=contract.get("root_supports",[]).duplicate(true)
		var at:=_point(contract.safe_return);_area(m,"boss",at,"FOREST BOSS","boss")
		_edge(m,"arena_entry","gate_ready","boss","walk",[_pair(p.gate_ready),_pair(at)])
	else:_area(m,"boss",Vector2(1460,558),"BOSS CONTRACT BLOCKED","boss")
	m.vine_gate={"id":"crown_vine","key_anchor":"crown_approach_ring_0","rect":[1456.0,56.0,16.0,556.0]}
func _routes(m: Dictionary) -> Dictionary:
	var fast:=_route(m,"arrival","gate_ready")
	var growth:=_route(m,"arrival","camp");growth.append_array(_route(m,"camp","cache"));growth.append_array(_route(m,"cache","gate_ready"))
	var high:=_route(m,"arrival","cache");high.append_array(_route(m,"cache","camp"))
	return {"fast":fast,"growth":growth,"high_return":high}
func _phrase(m: Dictionary,id: String,a: String,b: String,kind: String,from_port: String,to_port: String,p: Dictionary) -> void:
	_edge(m,id,a,b,kind,[_pair(p[a]),_pair(p[b])])
	m.connections[-1].merge({"geometry_instance":"hollow","from_port":from_port,"to_port":to_port,"entry_role":from_port,"exit_role":to_port,"landing":_pair(p[b]),"landing_support_id":"hollow__"+str({"M":"belly_entry","E":"outer_crown","D":"inner_root","R":"outer_root"}[b]),"native_verified":false})
func _edge(m: Dictionary,id: String,a: String,b: String,kind: String,path: Array,steps: Array=[]) -> void:m.connections.append({"id":id,"a":a,"b":b,"kind":kind,"path":path,"steps":steps,"condition":"open","admission":"experimental_pending_formal","native_verified":false})
func _walk_pair(m: Dictionary,id: String,a: String,b: String,p: Dictionary) -> void:
	_edge(m,id+"_out",a,b,"walk",[_pair(p[a]),_pair(p[b])]);_edge(m,id+"_back",b,a,"walk",[_pair(p[b]),_pair(p[a])])
func _reward(m: Dictionary,id: String,at: Vector2,crosslink: String) -> void:m.rewards.append({"id":id,"area":"cache","tier":"high","position":_pair(at),"claimed":false,"reward_mode":"item_resource","items":["region_health_purple","region_damage_purple"],"coins":18,"resources":[{"kind":"coin","amount":18},{"kind":"note","amount":2}],"crosslink":crosslink,"admission":"new_reward_geometry_unverified"})
static func _route(m: Dictionary,start: String,goal: String) -> Array[String]:
	if start==goal:return []
	var queue: Array[String]=[start];var visited: Dictionary={start:true};var parents: Dictionary={};var via: Dictionary={}
	while not queue.is_empty():
		var node: String=queue.pop_front()
		for edge: Dictionary in m.connections:
			if edge.a!=node or visited.has(edge.b) or (edge.b=="cache" and goal!="cache"):continue
			visited[edge.b]=true;parents[edge.b]=node;via[edge.b]=str(edge.id)
			if edge.b==goal:
				var result: Array[String]=[];var current:=goal
				while current!=start:result.push_front(via[current]);current=parents[current]
				return result
			queue.append(edge.b)
	return []
static func _edge_by_id(m: Dictionary,id: String) -> Dictionary:
	for edge: Dictionary in m.connections:
		if edge.id==id:return edge
	return {}
func validate(m: Dictionary,tuning: PlayerTuning) -> bool:return validate_spatial_candidate(m,tuning) and bool(m.boss_contract.get("ok",false))
func validate_spatial_candidate(m: Dictionary,tuning: PlayerTuning) -> bool:return _validate_structure(m,tuning)
func _validate_structure(m: Dictionary,tuning: PlayerTuning) -> bool:
	if tuning==null or m.get("version")!=VERSION or m.get("layout_version")!=LAYOUT_VERSION or m.get("region")!="thorn_forest" or not m.get("seed") is String or m.seed.is_empty():return false
	var index: Variant=m.get("map_index")
	if typeof(index) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(index)) or float(index)!=floorf(float(index)) or int(index) not in [1,2]:return false
	if m.get("manifest_hash")!=_hash(m) or m.get("production_pool")!=false or m.get("requires")!=["grapple"]:return false
	if not RandomStageGenerator.new()._same_data(m,_candidate(m.seed,int(index))):return false
	for category: String in ["platforms","hook_anchors","areas","connections","enemies","rewards"]:
		var ids: Dictionary={}
		for row: Dictionary in m[category]:
			if ids.has(row.id):return false
			ids[row.id]=true
	for platform: Dictionary in m.platforms:
		if not _rect(platform.rect).has_area():return false
	for name: String in ["fast","growth","high_return"]:
		var at:="arrival"
		for id: String in m.routes[name]:
			var edge:=_edge_by_id(m,id)
			if edge.is_empty() or edge.a!=at:return false
			at=str(edge.b)
		if at!=("camp" if name=="high_return" else "gate_ready"):return false
	return true
static func topology_signature(m: Dictionary) -> String:
	var edges: Array[String]=[]
	for edge: Dictionary in m.connections:edges.append(str(edge.a)+">"+str(edge.b)+":"+str(edge.kind))
	edges.sort();return "|".join(edges)+";spawn="+str(m.spawn)
static func _area(m: Dictionary,id: String,at: Vector2,label: String,role: String) -> void:m.areas.append({"id":id,"position":_pair(at),"label":label,"role":role})
static func _platform(m: Dictionary,id: String,rect: Rect2,one_way: bool) -> void:m.platforms.append({"id":id,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"one_way":one_way})
static func _point(value: Array) -> Vector2:return Vector2(value[0],value[1])
static func _pair(value: Vector2) -> Array:return [value.x,value.y]
static func _rect(value: Array) -> Rect2:return Rect2(value[0],value[1],value[2],value[3])
static func _hash(m: Dictionary) -> String:
	var value:=m.duplicate(true);value.erase("manifest_hash")
	return JSON.stringify(JSON.parse_string(JSON.stringify(value,"",true)),"",true).sha256_text()
