class_name ThornForestRegionV2V9
extends RefCounted
## Recorded-layout replay extracted from dd214ddec4394758d3d3efb71d604b86b7fdb7a3.
## One bounded itinerary switch also preserves the actually recorded pre-N movie14 layout.
## Forest depth playtest candidate. Default selection is owned by the registry; data is not Motor proof.
# Historical generation basis, not the current runtime movement/aim contract.
# Baseline 6c61faadd511c48a267b975550da897e701fd09f config bytes.
const GENERATION_TUNING_HASH := "e5161bb8ef1855b9eda515ab0613a4a738b47abc43b0f2dc118d2e45f71b2058"
const VERSION := "thorn-forest-region-v2"
const LAYOUT_VERSION := "shared-tree-living-detour-v9"
const FAMILIES := ["hollow_inner_first","hollow_root_first","clearing_shared_edge","clearing_shared_node"]
const HOLLOW := preload("res://scripts/generation/forest_hollow_trunk_geometry.gd")
const ARENA_FACTORY_PATH := "res://scripts/generation/forest_boss_arena_factory.gd"
var known_north_return := true
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
		"player_tuning_hash":GENERATION_TUNING_HASH,"traversal_hash":FileAccess.get_sha256("res://resources/player/traversal.tres"),
		"platforms":[],"hook_anchors":[],"areas":[],"connections":[],"rewards":[],"pickups":[],"enemies":[],"enemy_drops":{},"dangers":[],"geometry_instances":[],"nodes":[{"id":"forest_v2","mirrored":false}],
		"merchant_id":"root_camp","shop":{"item":"health_blue","price":5,"stock":1},"shot_latch_plan":{"version":1,"latches":[]},"terminal_exits":[],
		"choices":{"skeleton":variant,"cache_route":topology.next_int(2),"enemy_mix":content.next_int(2),"cavity_direction":(topology.next_int(2) if map_index==2 else 0)},"streams":{"topology":"forest_topology","content":"forest_ecology","version":VERSION},
		"admission":{"geometry":"new_shared_trunk_experimental","motor":"unverified","seams":"unverified","visual":"unverified"}}
	var offset:=Vector2(600,600)
	# Draw after the existing skeleton/cache/cavity decisions. This changes
	# actual discovery from a different shore, not the driver's visit order.
	# Only this relationship already has both a lower-window route and an
	# independent R -> E -> C route; other combinations retain their entry.
	var entry_draw: int=topology.next_int(2) if map_index==2 else 0
	var root_entry_eligible: bool=map_index==2 and variant==0 and int(m.choices.cache_route)==0 and int(m.choices.cavity_direction)==0
	m.choices.entry_draw=entry_draw
	m.choices.root_entry=root_entry_eligible and entry_draw==1
	m.choices.west_reward_draw=topology.next_int(2) if map_index==2 else 0
	m.choices.west_reward=map_index==2 and variant==1 and int(m.choices.west_reward_draw)==1
	m.entry_contract={"requested":entry_draw,"eligible":root_entry_eligible,"selected":"R" if m.choices.root_entry else ("W" if map_index==2 else ("M" if variant==0 else "R")),"reason":"lower_window_or_living_crown_then_return_to_known_root" if m.choices.root_entry else "retain_existing_entry","native_verified":false}
	_install_hollow(m,offset,variant==1)
	var p: Dictionary={"M":offset,"E":offset+Vector2(380,-42),"D":offset+Vector2(120,202),"R":offset+Vector2(420,282)}
	for id: String in p:_area(m,id,p[id],{"M":"TREE BELLY","E":"OUTER CROWN","D":"INNER ROOT","R":"OUTER ROOT"}[id],"junction")
	_core_edges(m,p,variant==1)
	_install_cavity_edges(m,p,variant==1)
	# Separated encounter supports, preserving all existing ports and gaps.
	if map_index==1:_platform(m,"borer_entry_perch",Rect2(270,568,80,18),true)
	if map_index==1:_single_tree(m,p,variant)
	else:_clearing(m,p,variant)
	if int(m.choices.cache_route)==1:_borer_reward(m,p)
	if bool(m.choices.west_reward):_install_west_reward(m,p)
	_install_encounters(m,content)
	_install_boss(m,p)
	if variant==0 and int(m.choices.cache_route)==0:
		# The upper right exit shares an existing broad prep shore before the
		# cache drop. The player can read the lower reward there, not blind-fall.
		_edge(m,"borer_outer_cache","C","cache","drop_through",[_pair(p.C),[1300.0,p.C.y],[1300.0,558.0],_pair(p.cache)])
		m.discovery_contract.upper_reward_exit="C -> existing prep shore -> outer cache; crown descent remains an alternative"
		# Reward is a crossing with a real upward exit through the ONE-WAY
		# prep branch. Growth can continue to Boss without repeating upper H.
		if map_index==1:
			_edge(m,"reward_to_prep","cache","prep","ordinary_sequence",[_pair(p.cache),_pair(p.prep)],[{"kind":"jump_rise","takeoff":_pair(p.cache),"landing":_pair(p.prep),"from_support_id":"outer_reward_branch","support_id":"boss_approach"}])
		else:
			# The old broad shore remains a readable reward exit, not a false
			# 390px jump to the new upper Boss entrance.
			_edge(m,"reward_to_crown","cache","E","ordinary_sequence",[_pair(p.cache),[1300.0,558.0],_pair(p.E)],[{"kind":"jump_rise","takeoff":_pair(p.cache),"landing":[1300.0,558.0],"from_support_id":"outer_reward_branch","support_id":"crown_reward_rest"}])
	for edge: Dictionary in m.connections:
		if edge.a=="cache":edge.merge({"claim_before_edge":true,"claim_area":"cache","claim_id":str(m.rewards[0].id)})
	m.routes=_routes(m)
	m.routes.borer=_route(m,"arrival","S");m.routes.borer.append("borer_crossing")
	if map_index==2:
		m.routes.borer.append_array(_route(m,"C","gate_ready"))
	elif variant==0 and int(m.choices.cache_route)==0:
		m.routes.borer.append("borer_outer_cache");m.routes.borer.append_array(_route(m,"cache","gate_ready"))
	else:
		m.routes.borer.append("borer_crown_descent");m.routes.borer.append_array(_route(m,"E","gate_ready"))
	var reconsider_port: String="C" if map_index==2 else "E"
	m.routes.change_mind=_route(m,"arrival",reconsider_port);m.routes.change_mind.append_array(_route(m,reconsider_port,"camp"))
	m.change_mind_contract={"decision_node":reconsider_port,"planned_goal":"gate_ready","chosen_goal":"camp","actual_input":"unverified"}
	_install_optional_live_return(m,p)
	m.topology_signature=topology_signature(m)
	m.stream_positions={"topology":topology.position(),"content":content.position()}
	var bounds:=Rect2(_point(m.spawn),Vector2.ONE)
	for row: Dictionary in m.platforms:bounds=bounds.merge(_rect(row.rect))
	for anchor: Dictionary in m.hook_anchors:bounds=bounds.expand(_point(anchor.position))
	bounds=bounds.grow(200);m.world_bounds=[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y]
	m.manifest_hash=_hash(m)
	return m
func _install_optional_live_return(m: Dictionary,p: Dictionary) -> void:
	# This physical shortcut already exists between the wide root and crown.
	# Keep the ordinary <=2R solution when the living anchor has been killed.
	# Append AFTER existing routes: admitting this optional relationship must
	# not silently replace their original learning/reward/return itineraries.
	var crown_return_enabled: bool=int(m.map_index)==2 and int(m.choices.skeleton)==0 and int(m.choices.cache_route)==0 and int(m.choices.cavity_direction)==0
	if crown_return_enabled:
		# Actual full-jump plus one recoil reaches this existing crown shore.
		# Retain the useful return connection, not the slower rejected side ring.
		_edge(m,"crown_reverse_return","E","C","ecology_return",[_pair(p.E),_pair(p.C)])
		m.connections[-1].merge({"role":"crown_reverse_return","landing":_pair(p.C),"from_support_id":"hollow__outer_crown","landing_support_id":"hollow__cavity_exit","optional":true,"strategies":["ordinary_full_jump_and_one_downward_recoil","retain_R_D_M_S_C_return"],"admission":"pending_actual_complete_reward_return","native_verified":false})
		m.crown_return_contract={"goal":"E_to_C_and_Queen_not_E_to_D_detour","fixed_lower_return_retained":true,"platforms_changed":false,"side_anchor_retired":true,"native_verified":false}
	var gate_tail:=_route(m,"E","gate_ready")
	_edge(m,"outer_lift_return","R","E","hollow_live_return",[_pair(p.R),_pair(p.E)])
	m.connections[-1].merge({"geometry_instance":"hollow","enemy_id":"hollow_route__outer_lift_lantern","landing":_pair(p.E),"landing_support_id":"hollow__outer_crown","optional":true,"strategies":["living_anchor_then_downward_recoil","ordinary_jump_and_at_most_two_downward_shots"],"admission":"pending_formal_expedition","native_verified":false})
	if int(m.map_index)==1 and int(m.choices.skeleton)==1:
		var expedition: Array=m.routes.high_return.duplicate()
		expedition.append_array(["camp_outer_back","outer_lift_return"])
		expedition.append_array(gate_tail)
		m.routes.ecology_expedition=expedition
		m.ecology_expedition_contract={"prefix":"high_return","decision_after":"actual_reward_and_camp_return","choice":"borrow_live_lantern_or_spend_up_to_two_R_or_return_through_D_M","destination":"gate_ready","admission":"pending_actual_formal_run"}
	elif crown_return_enabled:
		# Follow the existing reward's other exit to R, then choose a return.
		# No mandatory camp detour and no replacement of the original routes.
		var reward_return: Array=[]
		for edge_id: String in m.routes.high_return:
			reward_return.append(edge_id)
			if edge_id=="reward_other_exit":break
		if not reward_return.is_empty() and reward_return[-1]=="reward_other_exit":
			reward_return.append("outer_lift_return")
			reward_return.append_array(gate_tail)
			m.routes.ecology_expedition=reward_return
			m.ecology_expedition_contract={"prefix":"actual_reward_other_exit_to_R","decision_after":"actual_reward_not_camp","choice":"borrow_live_lantern_or_spend_up_to_two_R_or_return_through_D_M","destination":"gate_ready","admission":"pending_actual_map2_complete_reward_return"}
	if bool(m.choices.root_entry):
		# The fixed lower-window route remains fast/growth's default. This
		# alternate uses the same physical shore in the other direction; it is
		# not a scripted tour added ahead of an unchanged western spawn.
		m.routes.crown_entry=["arrival_reading","outer_lift_return"]
		m.routes.crown_entry.append_array(gate_tail)
		m.entry_contract.alternate_route="crown_entry"
		m.entry_contract.fixed_route="fast"

func _install_hollow(m: Dictionary,offset: Vector2,split_entry: bool) -> void:
	var descending: bool=int(m.choices.cavity_direction)==1
	var raw: Dictionary=HOLLOW.build_cavity_elbow() if descending else HOLLOW.build_cavity()
	var source:=raw.duplicate(true)
	var modifications: Array=[]
	# Existing factory owns the complete tested cavity. All new regional seams
	# remain experimental until the actual DemoApp route consumer admits them.
	modifications.append("descending airborne elbow from exact A2 geometry; original M/E/D/R retained; new regional seams unverified" if descending else "shared roof cavity from exact geometry factory; original M/E/D/R retained; new S/C regional seams unverified")

	if split_entry:
		# A real broad side-cavity route, not merely a moved chest label.
		# The right support still owns the original spawn/upper H takeoff.
		raw.platforms[0]={"id":"belly_entry","rect":[-80.0,18.0,160.0,60.0],"one_way":false}
		raw.platforms.append({"id":"belly_west","rect":[-220.0,18.0,100.0,60.0],"one_way":false})
		modifications.append("entry floor split at localx[-120,-80] for actual lower-to-upper side cavity; NOT inherited hollow05 proof")
	var instance: Dictionary={"id":"hollow","factory_path":"res://scripts/generation/forest_hollow_trunk_geometry.gd","factory_entry":"build_cavity_elbow" if descending else "build_cavity","factory_version":raw.version,"factory_sha256":FileAccess.get_sha256("res://scripts/generation/forest_hollow_trunk_geometry.gd"),"translation":_pair(offset),"facing":1,"source_geometry":source,"local_geometry":raw,"derivations":modifications,"platform_id_map":{},"anchor_id_map":{},"enemy_id_map":{},"danger_indices":[],"inserted_into_platforms":true,"protected_bounds":[float(raw.world_bounds[0])+offset.x,float(raw.world_bounds[1])+offset.y,float(raw.world_bounds[2]),float(raw.world_bounds[3])],"port_corridors":[],"native_verified":false}
	for row: Dictionary in raw.platforms:
		var rect:=_rect(row.rect);rect.position+=offset
		var id: String="hollow__"+str(row.id);instance.platform_id_map[row.id]=id
		_platform(m,id,rect,bool(row.one_way))
	for danger: Array in raw.dangers:
		var rect:=_rect(danger);rect.position+=offset
		instance.danger_indices.append(m.dangers.size())
		m.dangers.append([rect.position.x,rect.position.y,rect.size.x,rect.size.y])
	m.danger_presentations=raw.get("danger_presentations",[{"facing":"down"},{"facing":"up"},{"facing":"up"}]).duplicate(true)
	m.cavity_contract={"geometry_instance":"hollow","from_port":"S","to_port":"C","admission":"experimental_regional_seams_pending","motion":"descending_elbow" if descending else "level","not_inherited_upper_window_value":true}

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
func _install_cavity_edges(m: Dictionary,p: Dictionary,split: bool) -> void:
	# The upper passage is an optional shared loop, not a new isolated room.
	# Existing tested lower routes remain available with unchanged port bodies.
	var geometry: Dictionary=m.geometry_instances[0].local_geometry
	var translation:=_point(m.geometry_instances[0].translation)
	p.S=_point(geometry.nodes.S.position)+translation;p.C=_point(geometry.nodes.C.position)+translation
	_area(m,"S",p.S,"BORER MOUTH","junction")
	_area(m,"C",p.C,"EAST HOLLOW","junction")
	_platform(m,"borer_access_low",Rect2(250,500,130,20),true)
	# Leave the west-to-north hook sweep clear; the existing 338 landing stays inside this ledge.
	_platform(m,"borer_access_middle",Rect2(300,400,130,20),true)
	var steps: Array=[]
	if split:steps.append({"kind":"jump_gap","takeoff":[532.0,600.0],"landing":[468.0,600.0],"from_support_id":"hollow__belly_entry","support_id":"hollow__belly_west"})
	steps.append_array([
		{"kind":"jump_rise","takeoff":[392.0,600.0],"landing":[338.0,482.0],"from_support_id":"hollow__belly_west" if split else "hollow__belly_entry","support_id":"borer_access_low"},
		{"kind":"jump_rise","takeoff":[338.0,482.0],"landing":[338.0,382.0],"from_support_id":"borer_access_low","support_id":"borer_access_middle"},
		{"kind":"jump_rise","takeoff":[338.0,382.0],"landing":_pair(p.S),"from_support_id":"borer_access_middle","support_id":"hollow__cavity_observe"}
	])
	_edge(m,"belly_borer_access","M","S","ordinary_sequence",[_pair(p.M),_pair(p.S)],steps)
	_edge(m,"borer_crossing","S","C","hollow_cavity",[_pair(p.S),_pair(p.C)])
	m.connections[-1].merge({"geometry_instance":"hollow","from_port":"S","to_port":"C","landing":_pair(p.C),"landing_support_id":"hollow__cavity_exit","entry_role":"S","exit_role":"C","motion":m.cavity_contract.motion,"native_verified":false})
	_edge(m,"borer_crown_descent","C","E","drop_through",[_pair(p.C),_pair(p.C),_pair(p.E)])
	var west_landing: Array=[420.0,600.0] if split else _pair(p.M)
	_edge(m,"borer_belly_return","S","M","drop_through",[_pair(p.S),[338.0,282.0],[338.0,382.0],[338.0,482.0],west_landing])
	if split:
		m.connections[-1].post_landing_steps=[{"kind":"jump_gap","takeoff":[468.0,600.0],"landing":[532.0,600.0],"from_support_id":"hollow__belly_west","support_id":"hollow__belly_entry"},{"kind":"walk","landing":_pair(p.M)}]
	m.borer_loop={"ports":["M","S","C","E"],"edges":["belly_borer_access","borer_crossing","borer_crown_descent","lower_in","inner_recovery"],"risk_reward":"two H+two R receive the wide centre; descending H0R receives the edge and conserves a shot; three ordinary R cross faster; zero-shot roof bypass remains legal" if int(m.choices.cavity_direction)==1 else "two H+two R retain energy at C; four R cross faster; ordinary roof bypass remains legal","seams":"unverified_actual_DemoApp"}

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
	p.arrival=p.R if bool(m.choices.root_entry) else p.W
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
		# From the northern camp the middle stair is already on the way to S.
		# Do not descend to M only to climb the same ledges again. The older
		# north_belly edge remains a genuine choice for the lower tree/cache.
		_edge(m,"north_borer_access","N","S","ordinary_sequence",[_pair(p.N),[338.0,382.0],_pair(p.S)],[
			{"kind":"jump_rise","takeoff":[268.0,450.0],"landing":[338.0,382.0],"from_support_id":"north_court","support_id":"borer_access_middle"},
			{"kind":"jump_rise","takeoff":[338.0,382.0],"landing":_pair(p.S),"from_support_id":"borer_access_middle","support_id":"hollow__cavity_observe"}
		])
		# The shared cavity stair is a real receiving ledge on this crossing.
		# Read it as a landing, then descend through the two one-way steps.
		_edge(m,"north_belly","N","M","ordinary_sequence",[_pair(p.N),[338.0,382.0],[420.0,600.0],_pair(p.M)],[
			{"kind":"jump_rise","takeoff":[268.0,450.0],"landing":[338.0,382.0],"from_support_id":"north_court","support_id":"borer_access_middle"},
			{"kind":"drop_through","path":[[338.0,382.0],[338.0,382.0],[338.0,482.0],[420.0,600.0]],"landing":[420.0,600.0]}
		])
		m.connections[-1].steps.append({"kind":"jump_gap","takeoff":[468.0,600.0],"landing":[532.0,600.0],"from_support_id":"hollow__belly_west","support_id":"hollow__belly_entry"})
		_edge(m,"north_reward","N","cache","candidate_hook_relay",[_pair(p.N),[300.0,600.0],_pair(p.cache)])
		m.connections[-1].anchor_id="west_gap_ring"
		_edge(m,"reward_deep_exit","cache","D","drop_through",[_pair(p.cache),[650.0,720.0],_pair(p.D)])
		_walk_pair(m,"camp_north","N","camp",p)
		m.macro_loops={"left":["west_north","north_belly","belly_to_west"],"right":["upper_out","lower_in","inner_recovery"]}
		m.loop_sharing={"kind":"shared_node","nodes":["M"],"crosslink_endpoints":["N","D"]}
	m.discovery_contract={"entry":"R" if bool(m.choices.root_entry) else "W","first_choices":["lower_window_to_inner_camp","living_or_recoil_crown_then_upper_exit"] if bool(m.choices.root_entry) else ["central_window","north_camp" if variant==1 else "lower_camp"],"reward_endpoints":["N","D"] if variant==1 else ["E","R"],"loop_sharing":m.loop_sharing.kind,"status":"unverified_actual_visibility"}
	_finish_areas(m,p,variant)
func _finish_areas(m: Dictionary,p: Dictionary,variant: int) -> void:
	for id: String in ["arrival","camp","cache"]:_area(m,id,p[id],{"arrival":"FOREST ENTRY","camp":"ROOT CAMP","cache":"CROSSING CACHE"}[id],{"arrival":"tutorial","camp":"merchant","cache":"challenge_reward"}[id])
	m.spawn=_pair(p.arrival);m.camp_area="camp";m.merchant_position=_pair(p.camp)
	if p.camp==Vector2(360,802):
		# This camp already shares the left root and its recovery stair. Do
		# not force a visit to D's centre and back across the same sentry.
		var receiving_support: String="hollow__belly_west" if variant==1 else "hollow__belly_entry"
		var recovery_steps: Array=[
			{"kind":"jump_rise","takeoff":[328.0,802.0],"landing":[328.0,700.0],"from_support_id":"hollow__inner_root","support_id":"hollow__inner_recovery_step"},
			{"kind":"jump_rise","takeoff":[328.0,700.0],"landing":[420.0,600.0],"from_support_id":"hollow__inner_recovery_step","support_id":receiving_support}
		]
		if variant==1:recovery_steps.append({"kind":"jump_gap","takeoff":[468.0,600.0],"landing":[532.0,600.0],"from_support_id":"hollow__belly_west","support_id":"hollow__belly_entry"})
		_edge(m,"camp_recovery","camp","M","ordinary_sequence",[_pair(p.camp),[328.0,700.0],[420.0,600.0],_pair(p.M)],recovery_steps)
		if int(m.map_index)==2:
			_edge(m,"west_camp_descent","W","camp","drop_through",[_pair(p.W),[290.0,600.0],[302.0,802.0],_pair(p.camp)])
	var node: String="M" if int(m.map_index)==1 and variant==0 else ("R" if int(m.map_index)==1 or bool(m.choices.root_entry) else "W")
	_edge(m,"arrival_reading","arrival",node,"walk",[_pair(p.arrival),_pair(p[node])])
	m.pickups.append({"id":"camp_heart","kind":"heart","amount":1,"position":_pair(p.camp+Vector2(-35,-5))})
func _borer_reward(m: Dictionary,p: Dictionary) -> void:
	# An independent topology choice moves the SAME reward into a shared loop.
	# It changes the goal and return route, not just the silhouette or coin count.
	p.cache=Vector2(1100,p.C.y)
	for area: Dictionary in m.areas:
		if area.id=="cache":area.position=_pair(p.cache);area.label="BORER CACHE"
	m.rewards[0].position=_pair(p.cache)
	m.rewards[0].crosslink="S_C_E_shared_loop"
	var retained: Array=[]
	for edge: Dictionary in m.connections:
		if edge.a!="cache" and edge.b!="cache":retained.append(edge)
	m.connections=retained
	_edge(m,"borer_cache","C","cache","walk",[_pair(p.C),_pair(p.cache)])
	_edge(m,"cache_borer_back","cache","C","walk",[_pair(p.cache),_pair(p.C)])
	_edge(m,"cache_crown_exit","cache","E","drop_through",[_pair(p.cache),_pair(p.C),_pair(p.E)])
	m.discovery_contract.reward_endpoints=["C","E"]
	m.discovery_contract.reward_relationship="observe upper cavity, choose H/R resource trade or outside roof bypass; descend to original crown after claim"
	m.macro_loops.borer_reward=["belly_borer_access","borer_crossing","borer_cache","cache_crown_exit","lower_in","inner_recovery"]
	if m.has("loop_sharing") and m.loop_sharing.has("crosslink_endpoints"):m.loop_sharing.crosslink_endpoints=["S","E"]

func _install_west_reward(m: Dictionary,p: Dictionary) -> void:
	# One existing cache moves to an optional opposite shore. The return
	# enters the known west court instead of repeating the outward crossing.
	# This is a data consumer of the tested ballistic body, not a phase reset.
	var supports: Array[Dictionary]=[
		{"id":"far_reward_branch","rect":[-610.0,268.0,290.0,24.0],"one_way":true},
		{"id":"far_lower_return","rect":[-220.0,618.0,140.0,24.0],"one_way":true},
		{"id":"far_root_catch","rect":[-1050.0,820.0,1130.0,30.0],"one_way":true},
		{"id":"far_return_step0","rect":[-160.0,718.0,100.0,20.0],"one_way":true},
		{"id":"far_return_step1","rect":[-60.0,618.0,100.0,20.0],"one_way":true}]
	for row: Dictionary in supports:_platform(m,row.id,_rect(row.rect),bool(row.one_way))
	p.cache=Vector2(-525,250)
	for area: Dictionary in m.areas:
		if area.id=="cache":area.position=_pair(p.cache);area.label="FAR BOUGH CACHE"
	m.rewards[0].position=_pair(p.cache)
	m.rewards[0].crosslink="north_far_bough_west_return"
	var retained: Array=[]
	for edge: Dictionary in m.connections:
		if edge.a!="cache" and edge.b!="cache":retained.append(edge)
	m.connections=retained
	_area(m,"far_bough",Vector2(-400,250),"FAR BOUGH","junction")
	_edge(m,"north_far_bough","N","far_bough","crossbranch_crossing",[_pair(p.N),[-400.0,250.0]])
	m.connections[-1].merge({"role":"outbound","enemy_id":"hollow_route__crossbranch","landing_support_id":"far_reward_branch","landing":[-400.0,250.0],"optional":true,"strategies":["borrow_actual_departing_body_then_reverse_recoil","ordinary_full_jump_and_two_recoil_shots","retain_main_cavity_route"]})
	_edge(m,"far_cache","far_bough","cache","walk",[[-400.0,250.0],_pair(p.cache)])
	var returning: Array=[[-440.0,250.0],[-150.0,600.0],[20.0,600.0],_pair(p.W)]
	_edge(m,"far_reward_return","cache","W","crossbranch_return",[_pair(p.cache)]+returning)
	m.connections[-1].merge({"role":"return","landing":_pair(p.W),"optional":true})
	_edge(m,"far_bough_decline","far_bough","W","crossbranch_return",[[-400.0,250.0]]+returning)
	m.connections[-1].merge({"role":"return","landing":_pair(p.W),"optional":true})
	m.crossbranch_contract={"version":1,"enemy_id":"hollow_route__crossbranch","shore_rows":[{"id":"north_court","rect":[60.0,468.0,220.0,24.0],"position":[76.0,452.0]},{"id":"far_reward_branch","rect":[-610.0,268.0,290.0,24.0],"position":[-350.0,252.0]}],"support_ids":{"prize":"far_reward_branch","lower":"far_lower_return","catch":"far_root_catch","step0":"far_return_step0","step1":"far_return_step1","north":"north_court","west":"west_court"},"outbound_edge":"north_far_bough","claim_edge":"far_cache","return_edge":"far_reward_return","decline_edge":"far_bough_decline","admission":"optional_expression_pending_formal_lifecycle_and_pixels","native_verified":false}
	m.observation_windows=[{"id":"far_bough_departure","rect":[96.0,420.0,64.0,60.0],"focus":[-450.0,252.0]}]
	m.discovery_contract.reward_endpoints=["N","W"]
	m.discovery_contract.reward_relationship="optional visible far bough, bodily grapple or ordinary recoil, lower return to known west court; north camp heart may become useful after cache capacity increase"
	m.macro_loops.erase("borer_reward")
	m.macro_loops.far_bough=["west_north","north_far_bough","far_cache","far_reward_return"]
	if m.has("loop_sharing"):m.loop_sharing.crosslink_endpoints=["N","W"]

func _install_encounters(m: Dictionary,content: RunRandomStream) -> void:
	# Consume the already-recorded ecology choice; never jitter positions or
	# add another RNG stream. These are two authored route-pressure recipes.
	var mix := int(m.choices.enemy_mix)
	var line_recipe := mix == 1
	var rows: Array = []
	if line_recipe:
		rows.append({"id":"root_seed_watch","behavior":"forest_seed_sentry","x":620.0,"floor":820.0,"support":"hollow__inner_root","group":"inner_root_support_choice","role":"old supported branch is seeded; move during preview or use the cache branch as real projectile cover","approach":"D toward inner recovery or inner cache","alternatives":["wait on D observation support","shoot from a supported bank","retreat toward cache cover"]})
		rows.append({"id":"crown_thread","behavior":"forest_thread_spider","x":1130.0,"floor":576.0,"support":"hollow__outer_crown","group":"crown_line_return_choice","line_start":[1045.0,558.0],"line_end":[1105.0,558.0],"role":"conditional crown line timing: ordinary jump, wait or supported gunfire; no admitted upper live-anchor bypass","approach":"E toward prep or outer reward descent","alternatives":["wait on E","shoot the spider","retreat through R and choose an independently verified return","return via R"]})
	else:
		rows.append({"id":"root_patrol","behavior":"charger","x":620.0,"floor":820.0,"radius":25.0,"support":"hollow__inner_root","group":"inner_root_support_choice","role":"old charger horizontal commitment on the root; player may change layers, enemy cannot","approach":"D toward inner recovery or inner cache","alternatives":["wait on D observation support","shoot from a supported bank","take the cache or recovery branch"]})
		rows.append({"id":"outer_watch","behavior":"forest_seed_sentry","x":1150.0,"floor":576.0,"support":"hollow__outer_crown","group":"crown_seed_return_choice","role":"seed the old crown stand after safe E observation; ordinary jump, move off the lock or shoot from support, without an upper live-anchor bypass","approach":"E toward prep or outer reward descent","alternatives":["leave the old support","shoot the sentry","retreat through R and choose an independently verified return","return via R"]})
	rows.append({"id":"outer_lift_lantern","behavior":"forest_lantern","x":1050.0,"y":680.0,"support":"","group":"outer_root_return_choice","role":"R-to-E moving lift: actual grapple then downward shot recoil; seven local controls preserve ordinary two-shot and fixed returns. Current seed integrations require their own evidence","approach":"R toward E return; compare normal full jump and at most two downward shots","alternatives":["normal full jump plus at most two downward shots","existing lower-window D-M-E return","kill then use unchanged fixed return"]})
	# The other skeleton has its camp elsewhere. This is a separated return
	# encounter, not a second line covering the same landing or a tail-cache tax.
	if int(m.choices.skeleton) == 1:
		if bool(m.choices.west_reward):
			var exit_y: float=_point(m.areas.filter(func(a: Dictionary) -> bool:return a.id=="C")[0].position).y
			rows.append({"id":"inner_thread","behavior":"forest_thread_spider","x":1130.0,"floor":exit_y+18.0,"support":"hollow__cavity_exit","group":"cavity_exit_line","line_start":[1085.0,exit_y],"line_end":[1115.0,exit_y],"role":"existing spider guards the onward branch after the cavity; the C receiving position and broad left bank remain outside its body and thread","approach":"C safe receiving bank toward prep","alternatives":["wait on the left bank for actual retraction","shoot from support","jump past the body and line","decline the crown approach and return to the root"]})
		else:
			rows.append({"id":"inner_thread","behavior":"forest_thread_spider","x":400.0,"floor":820.0,"support":"hollow__inner_root","group":"inner_recovery_line","line_start":[370.0,802.0],"line_end":[420.0,802.0],"role":"left-root line before recovery; a separate supported waiting interval remains before the root watch","approach":"inner root toward inner recovery step","alternatives":["wait on the root","shoot from the right bank","decline the return until line retracts"]})
	if int(m.map_index)==1:
		rows.append({"id":"borer_entry_thread","behavior":"forest_thread_spider","x":310.0,"floor":568.0,"radius":0.0,"support":"borer_entry_perch","group":"rising_access_thread","line_start":[320.0,540.0],"line_end":[368.0,540.0],"role":"read a short rising-path line before committing from M to the low access branch; keep all three original reception shores clear","approach":"M toward S access; new side perch is also a real recovery surface","alternatives":["shoot from supported M approach","wait for actual retraction before jumping","retreat onto the original belly support"]})
	if bool(m.choices.west_reward):
		rows.append({"id":"crossbranch","behavior":"forest_crossbranch","x":76.0,"floor":468.0,"radius":0.0,"support":"north_court","group":"far_bough_exploration","role":"autonomous ballistic body is an obstacle, a living grapple anchor, or a killable target; borrowing it changes the recoil direction toward the same optional cache","approach":"observe from north court before choosing the far bough","alternatives":["full jump and two ordinary recoil shots","wait for the next visible departure","kill the body then use unchanged ordinary route","decline the optional cache and continue through the cavity"],"shore_rows":m.crossbranch_contract.shore_rows.duplicate(true),"no_drop":true})


	var camp := _point(m.merchant_position)
	var cache := _point(m.rewards[0].position)
	var camp_rect := Rect2(camp-Vector2(102,108),Vector2(204,216)) # actual shop90 + Player half12/18
	var spawn := _point(m.spawn)
	var rejected: Array = []
	for row: Dictionary in rows:
		var path: String = "res://resources/enemies/"+("plains_charger" if row.behavior=="charger" else str(row.behavior))+".tres"
		var definition := load(path) as EnemyDefinition
		var at := Vector2(float(row.x),float(row.get("y",0)) if definition.aerial else float(row.floor)-definition.collision_size.y*.5)
		var radius := float(row.get("radius",minf(definition.patrol_half_width,45.0)))
		var half := definition.collision_size*.5
		var sweep := Rect2(at-half-Vector2(radius,0),definition.collision_size+Vector2(radius*2,0))
		var closest := Vector2(clampf(spawn.x,sweep.position.x,sweep.end.x),clampf(spawn.y,sweep.position.y,sweep.end.y))
		var reason := "camp_body" if sweep.intersects(camp_rect,true) else "spawn_body" if closest.distance_to(spawn)<150 else ""
		var expanded := Rect2(sweep.position-Vector2(12,18),sweep.size+Vector2(24,36))
		var cache_closest := Vector2(clampf(cache.x,expanded.position.x,expanded.end.x),clampf(cache.y,expanded.position.y,expanded.end.y))
		if reason.is_empty() and cache_closest.distance_to(cache)<=80: reason="cache_interaction_body"
		if row.has("line_start"):
			var first := _point(row.line_start)
			var last := _point(row.line_end)
			var line_radius := (definition as ForestEnemyDefinition).line_radius
			if Geometry2D.get_closest_point_to_segment(cache,first,last).distance_to(cache)<=80.0+18.0+line_radius: reason="cache_interaction_line"
			elif Geometry2D.get_closest_point_to_segment(camp,first,last).distance_to(camp)<=90.0+18.0+line_radius: reason="camp_interaction_line"
		if not reason.is_empty():
			rejected.append({"id":row.id,"reason":reason,"body_sweep":[sweep.position.x,sweep.position.y,sweep.size.x,sweep.size.y]})
			continue
		var placed: Dictionary = {"id":"hollow_route__"+str(row.id),"behavior_id":String(definition.behavior_id),"definition_path":path,"definition_sha256":FileAccess.get_sha256(path),"stable_id":String(definition.stable_id),"position":_pair(at),"aerial":definition.aerial,"patrol_radius":radius,"support_id":row.support,"authored_body_sweep":[sweep.position.x,sweep.position.y,sweep.size.x,sweep.size.y],"encounter_role":row.role,"encounter_group":row.group,"approach":row.approach,"alternatives":row.alternatives.duplicate(),"ecology_recipe":mix}
		if row.has("line_start"):
			placed.line_start=row.line_start.duplicate()
			placed.line_end=row.line_end.duplicate()
		if row.has("shore_rows"):placed.shore_rows=row.shore_rows.duplicate(true)
		if bool(row.get("no_drop",false)):placed.no_drop=true
		m.enemies.append(placed)
	var dropper := EnemyDropService.new()
	dropper.configure(str(m.seed),"thorn_forest/map_%s"%m.map_index)
	for row: Dictionary in m.enemies:
		m.enemy_drops[row.id]=dropper.settle(StringName(row.id))
		if bool(row.get("no_drop",false)):m.enemy_drops[row.id]={"kind":"none","amount":0}
	m.encounter_plan_contract={"version":"compact-authored-ecology-v5","selected_mix":mix,"mix_consumed":true,"recipe":"root_seed_crown_weave" if line_recipe else "root_charge_crown_seed","active_count":m.enemies.size(),"planned_count":rows.size(),"rejected_placements":rejected,"camp_interaction_radius":90.0,"camp_body_protected_rect":[camp_rect.position.x,camp_rect.position.y,camp_rect.size.x,camp_rect.size.y],"cache_interaction_radius":80.0,"spawn_exclusion_radius":150.0,"protection_scope":"complete initial/authored patrol body and authored thread; ranged flight still requires actual route observations","full_route_phases":"unverified","not_legacy_woven_proof":true,"density_not_final":true}
func _install_boss(m: Dictionary,p: Dictionary) -> void:
	# First map introduces combat at the crown. The final map promotes the
	# horizontal cavity to the approach: the lower crown is now a return shore.
	var upper_exit: bool=int(m.map_index)==2
	var floor_center_y: float=p.C.y if upper_exit else 558.0
	p.prep=Vector2(1300,floor_center_y);p.gate_ready=Vector2(1400,floor_center_y)
	_platform(m,"boss_approach",Rect2(1176,floor_center_y+18,284,24),true)
	if upper_exit:_platform(m,"crown_reward_rest",Rect2(1176,576,284,24),true)
	for id: String in ["prep","gate_ready"]:_area(m,id,p[id],"BOSS APPROACH","prep")
	_edge(m,"cavity_prep" if upper_exit else "crown_prep","C" if upper_exit else "E","prep","walk",[_pair(p.C if upper_exit else p.E),_pair(p.prep)])
	_edge(m,"crown_approach","prep","gate_ready","gate_hook",[_pair(p.prep),_pair(p.gate_ready)])
	m.hook_anchors.append({"id":"crown_approach_ring_0","position":[1380.0,floor_center_y-90]})
	m.connections[-1].anchor_id="crown_approach_ring_0";m.connections[-1].support_id="boss_approach"
	var approach:=Vector2(1460,floor_center_y)
	var contract: Dictionary=load(ARENA_FACTORY_PATH).new().call("from_prep",approach,int(m.map_index))
	m.boss_contract=contract.duplicate(true);m.boss_geometry=contract.duplicate(true);m.boss_approach_origin=_pair(approach)
	m.boss_arena=contract.get("boss_arena",[1484.0,floor_center_y-502,0.0,0.0])
	if contract.get("ok",false):
		m.platforms.append_array(contract.platforms.duplicate(true));m.hook_anchors.append_array(contract.hook_anchors.duplicate(true));m.boss_root_supports=contract.get("root_supports",[]).duplicate(true)
		var at:=_point(contract.safe_return);_area(m,"boss",at,"FOREST BOSS","boss")
		_edge(m,"arena_entry","gate_ready","boss","walk",[_pair(p.gate_ready),_pair(at)])
	else:_area(m,"boss",approach,"BOSS CONTRACT BLOCKED","boss")
	m.vine_gate={"id":"crown_vine","key_anchor":"crown_approach_ring_0","rect":[1456.0,floor_center_y-502,16.0,556.0]}
	m.boss_approach_contract={"entry_port":"C" if upper_exit else "E","progression":("descending_cavity_final_approach" if int(m.choices.cavity_direction)==1 else "horizontal_cavity_final_approach") if upper_exit else "crown_combat_introduction","ordinary_roof_bypass_retained":true,"native_verified":false}
func _routes(m: Dictionary) -> Dictionary:
	var fast:=_route(m,"arrival","gate_ready")
	var growth:=_route(m,"arrival","camp");growth.append_array(_route(m,"camp","cache"))
	if bool(m.choices.west_reward) and known_north_return:
		# Equal edge counts conceal very different movement costs: W -> M
		# repeats the lower climb, while the known N shore already meets S.
		# Returning here also lets a new health-capacity reward use the heart
		# left at the previously full-health camp. The other route stays open.
		growth.append_array(_route(m,"cache","N"));growth.append_array(_route(m,"N","gate_ready"))
	else:growth.append_array(_route(m,"cache","gate_ready"))
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
	for name: String in m.routes:
		var at:="arrival"
		for id: String in m.routes[name]:
			var edge:=_edge_by_id(m,id)
			if edge.is_empty() or edge.a!=at:return false
			at=str(edge.b)
		if at!=("camp" if name in ["high_return","change_mind"] else "gate_ready"):return false
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
