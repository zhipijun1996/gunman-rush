class_name ForestExpeditionLayout
extends RefCounted
## Region-scale connected forest: an upper aerial route shares a lower root return.
## Data only. No movement, resource grants, retries or independent random generator.
const BASE := preload("res://scripts/generation/thorn_forest_region_v2_v10.gd")
const CHAIN := preload("res://scripts/generation/forest_air_chain_geometry.gd")
const VERSION := "forest-expedition-airborne-v11"
const WESTERN := preload("res://scripts/generation/forest_western_grove.gd")

static func install(m: Dictionary) -> void:
	# V10 appended these experimental returns only AFTER computing its routes.
	# Replanning this larger region must not silently promote those relations.
	# Retire their graph recommendations here, preserving the frozen producer
	# and all real platforms/anchors/enemies and free player movement.
	var retained_connections: Array=[]
	var retired_connections: Array=[]
	for edge: Dictionary in m.connections:
		if str(edge.id) in ["crown_reverse_return","outer_lift_return","deep_to_west"]:
			retired_connections.append({"id":str(edge.id),"source_admission":str(edge.get("admission","")),"reason":"not_admitted_into_current_recommended_routes; frozen specialist producer retained"})
		else:retained_connections.append(edge)
	m.connections=retained_connections
	m.expedition_retired_connections=retired_connections
	m.erase("crown_return_contract")
	m.erase("ecology_expedition_contract")
	var stream:=RunRandomStream.new(str(m.seed),"forest_expedition","map_%s"%m.map_index,VERSION)
	var relay_layout: String="hook_hook" if stream.next_int(2)==0 else "recoil_hook"
	var grove_mix:=stream.next_int(2)
	m.choices.expedition_relay=relay_layout
	m.choices.expedition_river="hook_hook" if stream.next_int(2)==0 else "recoil_hook"
	m.choices.expedition_grove=grove_mix
	var old_spawn: Array=m.spawn.duplicate()
	for area: Dictionary in m.areas:
		if area.id=="arrival":area.id="old_arrival";area.label="OLD TREE THRESHOLD";area.role="junction"
	for edge: Dictionary in m.connections:
		if edge.a=="arrival":edge.a="old_arrival"
		if edge.b=="arrival":edge.b="old_arrival"
	m.routes.clear()
	# Fallen giant, not another isolated rectangular room: the lower root is
	# both its catch basin and the beginning of the undergrowth return loop.
	var fallen:=_install_chain(m,"fallen_chain",Vector2(-1600,700),"arch_four")
	var relay:=_install_chain(m,"crown_relay",Vector2(-550,380),relay_layout)
	var fallen_entry:=_point(fallen.local_geometry.spawn)+_point(fallen.translation)
	var fallen_goal:=_point(fallen.local_geometry.goal)+_point(fallen.translation)
	var relay_entry:=_point(relay.local_geometry.spawn)+_point(relay.translation)
	var relay_goal:=_point(relay.local_geometry.goal)+_point(relay.translation)
	_area(m,"fallen_entry",fallen_entry,"FALLEN GIANT / SIDE RING","junction")
	_area(m,"fallen_crown",fallen_goal,"BROKEN CROWN / ROOTS RETURN BELOW","junction")
	_area(m,"relay_entry",relay_entry,"HANGING BOUGH / READ THE NEXT ANCHOR","junction")
	_area(m,"relay_crown",relay_goal,"LEAF NEST / EASTERN HOLLOW AHEAD","junction")
	_platform(m,"fallen_bough_link",Rect2(-1000,430,170,24),true,"living_bough","fallen_giant","branch_joint")
	_platform(m,"relay_east_log",Rect2(-30,360,200,24),true,"fallen_log","east_broken_log","upper_log_surface")
	if not _has_platform(m,"west_court"):
		_platform(m,"west_court",Rect2(40,618,260,28),true,"canopy_perch","old_tree_west_root","broad_observation_shore")
	if not _has_area(m,"W"):_area(m,"W",Vector2(180,600),"WEST ROOT / OLD TREE","junction")
	_air_edge(m,"fallen_air_chain","fallen_entry","fallen_crown",fallen)
	var between: Array=[
		_step("jump_gap",Vector2(-1050,460),Vector2(-900,412),"fallen_chain__crown","fallen_bough_link"),
		_step("jump_gap",Vector2(-850,412),Vector2(-700,380),"fallen_bough_link","crown_relay__entry")]
	_edge(m,"fallen_to_relay","fallen_crown","relay_entry","ordinary_sequence",[pair(fallen_goal),pair(relay_entry)],between)
	_air_edge(m,"canopy_air_relay","relay_entry","relay_crown",relay)
	# Descend through the open side, not through the original tree's thorn roof.
	_edge(m,"leafnest_log_return","relay_crown","W","ordinary_sequence",[pair(relay_goal),[70.0,342.0],[230.0,600.0],[180.0,600.0]],[
		{"kind":"walk","landing":[70.0,342.0]},
		{"kind":"drop_through","path":[[70.0,342.0],[230.0,342.0],[230.0,600.0],[180.0,600.0]],"landing":[180.0,600.0]}])
	if not _has_edge(m,"west_to_belly"):
		var receiving: String="hollow__belly_west" if int(m.choices.skeleton)==1 else "hollow__belly_entry"
		var access: Array=[_step("jump_gap",Vector2(288,600),Vector2(392,600),"west_court",receiving)]
		if int(m.choices.skeleton)==1:access.append(_step("jump_gap",Vector2(468,600),Vector2(532,600),"hollow__belly_west","hollow__belly_entry"))
		_edge(m,"west_to_belly","W","M","ordinary_sequence",[[180.0,600.0],[600.0,600.0]],access)
		var reverse: Array=[]
		if int(m.choices.skeleton)==1:reverse.append(_step("jump_gap",Vector2(532,600),Vector2(468,600),"hollow__belly_entry","hollow__belly_west"))
		reverse.append(_step("jump_gap",Vector2(392,600),Vector2(288,600),receiving,"west_court"))
		_edge(m,"belly_to_west","M","W","ordinary_sequence",[[600.0,600.0],[180.0,600.0]],reverse)
	_install_roots(m)
	var western:=WESTERN.install(m)
	m.choices.expedition_cache_west=int(m.map_index)==2 and grove_mix==1
	if m.choices.expedition_cache_west:
		WESTERN.relocate_cache(m)
	var entry:=_point(western.entry) if int(m.map_index)==1 else Vector2(-1000,902)
	m.spawn=pair(entry)
	m.entry_contract={"selected":"river_entry" if int(m.map_index)==1 else "root_grotto","reason":"opposite_height_discovers_different_forest_routes","native_verified":false}
	_area(m,"arrival",entry,"RIVER ROOT FOREST ENTRY" if int(m.map_index)==1 else "ROOT GROTTO ENTRY","tutorial")
	_edge(m,"expedition_entry","arrival","river_entry" if int(m.map_index)==1 else "root_grotto","walk",[pair(entry),pair(entry)])
	# The treasure is a visible upper shortcut choice, not a new item economy.
	# Root exploration remains a legal route when a live target has died.
	var upper: Array=["expedition_entry"]
	if int(m.map_index)==2:upper.append("grotto_fallen_recovery")
	else:upper.append_array(western.prefix)
	upper.append_array(["fallen_air_chain","fallen_to_relay","canopy_air_relay","leafnest_log_return","west_to_belly"])
	var lower: Array=["expedition_entry"]
	if int(m.map_index)==1:
		lower.append_array(["river_air_relay","river_to_western_belly","western_upper","western_crown_descent","western_root_eastward","western_deep_to_undergrowth"])
	else:lower.append("grotto_eastward")
	lower.append("undergrowth_to_old_root")
	var fast: Array=upper.duplicate() if int(m.map_index)==1 else lower.duplicate()
	fast.append_array(BASE._route(m,"M" if int(m.map_index)==1 else "D","gate_ready"))
	var growth: Array=[]
	if m.choices.expedition_cache_west:
		# Discover the western cache before the eastern camp. Do not force a
		# visit to the camp, a full return west, then another journey east.
		growth.append_array(BASE._route(m,"arrival","cache"));growth.append_array(BASE._route(m,"cache","camp"));growth.append_array(BASE._route(m,"camp","gate_ready"))
	else:
		growth=lower.duplicate()
		growth.append_array(BASE._route(m,"D","camp"));growth.append_array(BASE._route(m,"camp","cache"));growth.append_array(BASE._route(m,"cache","gate_ready"))
	var high: Array=BASE._route(m,"arrival","cache") if m.choices.expedition_cache_west else upper.duplicate()
	if not m.choices.expedition_cache_west:high.append_array(BASE._route(m,"M","cache"))
	high.append_array(BASE._route(m,"cache","camp"))
	var reconsider: Array=BASE._route(m,"arrival","camp")
	var shared_index:=-1
	for i: int in mini(fast.size(),reconsider.size()):
		if fast[i]!=reconsider[i]:break
		shared_index=i
	var decision: String="arrival" if shared_index<0 else str(BASE._edge_by_id(m,str(fast[shared_index])).b)
	m.change_mind_contract={"decision_node":decision,"planned_goal":"gate_ready","chosen_goal":"camp","actual_input":"unverified"}
	var borer: Array=upper.duplicate();borer.append_array(BASE._route(m,"M","S"));borer.append("borer_crossing");borer.append_array(BASE._route(m,"C","gate_ready"))
	m.routes={"fast":fast,"growth":growth,"high_return":high,"change_mind":reconsider,"borer":borer}
	m.expedition_contract={"version":VERSION,"old_spawn":old_spawn,"new_spawn":m.spawn.duplicate(),"upper_route":"river relay / western hollow / five-action bridge / fallen air chain / living bough / aerial relay / old west root","lower_route":"fallen root catch / root grotto / undergrowth / old inner root","map1_first_discovery":"river_hollow_and_five_action_bridge","map2_first_discovery":"root_grotto_and_lower_camp","relay_program":relay_layout,"continuous_chain_required_observation":"actual airborne frames between supported departure and receiver; no count-based proof","ordinary_lower_route_retained":true,"production_pool":false,"native_verified":false}
	m.observation_windows=m.get("observation_windows",[])
	m.observation_windows.append({"rect":[-1740.0,590.0,270.0,145.0],"focus":[-1370.0,510.0]})
	m.observation_windows.append({"rect":[-2740.0,500.0,640.0,500.0],"focus":[-2110.0,760.0]})
	# Teach the first out-of-range ring before asking for an airborne commitment.
	# These signs describe ordinary inputs; they do not mark a timed solution.
	m.expedition_hints=[]
	for pair_row: Array in [["river_entry",str(m.choices.expedition_river)],["relay_entry",relay_layout]]:
		var at: Array=[]
		for area: Dictionary in m.areas:
			if area.id==pair_row[0]:at=area.position
		m.expedition_hints.append({"position":[at[0]-100.0,at[1]-155.0],"text":"Jump, fire left to travel right.\nThen hook the side ring." if pair_row[1]=="recoil_hook" else "Catch the side ring, kick away,\nthen aim for the higher ring.","radius":190.0})
	m.expedition_hints.append({"position":[-2720.0,703.0],"text":"Side rings lead across.\nRoots loop below; mind the thorns.","radius":200.0})
	_install_ecology(m,grove_mix)
	# Structure identity is authored separately from material and collision.
	# A relay has branches, not an invented hollow around its empty space.
	m.scene_structure_kinds={"hollow":"hollow_tree","western_hollow":"hollow_tree","fallen_chain":"fallen_trunk","fallen_giant":"fallen_trunk","crown_relay":"bough_relay","river_chain":"river_boughs","western_bridge":"canopy_arch","east_broken_log":"fallen_trunk","root_grotto":"root_hollow","old_tree_undergrowth":"rootland","western_underbridge":"rootland","river_root_basin":"rootland","old_tree_west_root":"rootland","forest_roots":"rootland","forest_boughs":"bough_group"}
	m.stream_positions.expedition=stream.position()
	m.streams.expedition="forest_expedition"

static func _install_chain(m: Dictionary,id: String,offset: Vector2,layout: String) -> Dictionary:
	var geometry:=CHAIN.for_region(layout)
	var instance: Dictionary={"id":id,"factory":"res://scripts/generation/forest_air_chain_geometry.gd","geometry_version":CHAIN.VERSION,"local_geometry":geometry.duplicate(true),"translation":pair(offset),"platform_id_map":{},"anchor_id_map":{},"danger_indices":[]}
	for row: Dictionary in geometry.platforms:
		var rect:=Rect2(row.rect[0],row.rect[1],row.rect[2],row.rect[3]);rect.position+=offset
		var mapped:=id+"__"+str(row.id);instance.platform_id_map[row.id]=mapped
		var kind: String=("fallen_log" if layout=="arch_four" else "hollow_bark") if str(row.id)=="root_arch" else "root_earth" if str(row.id) in ["entry","recovery"] and not bool(row.one_way) else "canopy_perch" if str(row.id)=="crown" else "living_bough"
		_platform(m,mapped,rect,bool(row.one_way),kind,id,str(row.id))
	for row: Dictionary in geometry.hook_anchors:
		var mapped:=id+"__"+str(row.id);instance.anchor_id_map[row.id]=mapped
		m.hook_anchors.append({"id":mapped,"position":pair(_point(row.position)+offset),"scene_kind":"copper_growth_ring","structure_id":id})
	for row: Array in geometry.dangers:
		instance.danger_indices.append(m.dangers.size())
		m.dangers.append([float(row[0])+offset.x,float(row[1])+offset.y,row[2],row[3]])
	m.geometry_instances.append(instance)
	return instance

static func _install_roots(m: Dictionary) -> void:
	# Three joined but differently shaped root courts. The continuous ground
	# below the first aerial crossing is its actual recovery, not decoration.
	_platform(m,"grotto_west_lip",Rect2(-760,1000,360,38),false,"fallen_log","root_grotto","broken_log_floor")
	_platform(m,"grotto_deep_root",Rect2(-440,1090,520,70),false,"root_earth","root_grotto","deep_root_terrace")
	_platform(m,"grotto_east_root",Rect2(40,1000,380,60),false,"root_earth","old_tree_undergrowth","buttress_root")
	_platform(m,"grotto_east_step",Rect2(130,900,120,22),true,"living_bough","old_tree_undergrowth","root_step")
	_platform(m,"grotto_hanging_bough",Rect2(-860,550,300,16),true,"living_bough","crown_relay","suspension_branch")
	m.hook_anchors.append({"id":"grotto_fixed_return_ring","position":[-820.0,690.0],"structure_id":"crown_relay","scene_kind":"copper_growth_ring"})
	_area(m,"root_grotto",Vector2(-1000,902),"ROOT GROTTO / CATCH AND RECONSIDER","junction")
	_area(m,"undergrowth",Vector2(160,982),"BUTTRESS ROOT / OLD CAMP ABOVE","junction")
	_edge(m,"fallen_root_descent","fallen_entry","root_grotto","drop_through",[[-1600.0,700.0],[-1850.0,700.0],[-1850.0,902.0],[-1000.0,902.0]])
	_edge(m,"grotto_fallen_recovery","root_grotto","fallen_entry","ordinary_sequence",[[-1000.0,902.0],[-1600.0,700.0]],[
		_step("jump_rise",Vector2(-1875,902),Vector2(-1875,800),"fallen_chain__recovery","fallen_chain__recovery_step"),
		_step("jump_rise",Vector2(-1875,800),Vector2(-1740,700),"fallen_chain__recovery_step","fallen_chain__entry")])
	_edge(m,"grotto_eastward","root_grotto","undergrowth","ordinary_sequence",[[-1000.0,902.0],[160.0,982.0]],[
		{"kind":"drop_through","path":[[-1000.0,902.0],[-690.0,902.0],[-690.0,982.0]],"landing":[-690.0,982.0]},
		{"kind":"drop_through","path":[[-690.0,982.0],[-300.0,982.0],[-300.0,1072.0]],"landing":[-300.0,1072.0]},
		_step("jump_rise",Vector2(-60,1072),Vector2(160,982),"grotto_deep_root","grotto_east_root")])
	_edge(m,"undergrowth_to_old_root","undergrowth","D","ordinary_sequence",[[160.0,982.0],[720.0,802.0]],[
		_step("jump_rise",Vector2(160,982),Vector2(190,882),"grotto_east_root","grotto_east_step"),
		_step("jump_rise",Vector2(190,882),Vector2(330,802),"grotto_east_step","hollow__inner_root")])
	_edge(m,"old_root_grotto_return","D","undergrowth","drop_through",[[720.0,802.0],[200.0,802.0],[160.0,982.0]])
	_edge(m,"undergrowth_grotto_return","undergrowth","root_grotto","ordinary_sequence",[[160.0,982.0],[-1000.0,902.0]],[
		{"kind":"drop_through","path":[[160.0,982.0],[-100.0,982.0],[-100.0,1072.0]],"landing":[-100.0,1072.0]},
		_step("jump_rise",Vector2(-370,1072),Vector2(-470,982),"grotto_deep_root","grotto_west_lip"),
		_step("jump_rise",Vector2(-690,982),Vector2(-800,902),"grotto_west_lip","fallen_chain__recovery")])

static func _install_ecology(m: Dictionary,mix: int) -> void:
	var placements: Array=[
		{"id":"fallen_crown_beetle","behavior":"forest_bark_beetle","position":[-945.0,466.0],"radius":20.0,"support":"fallen_chain__crown","role":"bark shield on a broad crown; flank after reading the fixed dash","direction":-1},
		{"id":"grotto_west_beetle","behavior":"forest_bark_beetle","position":[-580.0,988.0],"radius":20.0,"support":"grotto_west_lip","role":"open fallen-log shore: leave the drop receiver free, read the shield then choose an upper gun angle or flank","direction":-1},
		{"id":"grotto_deep_beetle","behavior":"forest_bark_beetle","position":[-180.0,1078.0],"radius":65.0,"support":"grotto_deep_root","role":"lower terrace angle choice; jump above its shield or lure past","direction":-1},
		{"id":"grotto_swing_pod","behavior":"forest_swing_pod","position":[-650.0,666.0],"radius":85.0,"support":"","tether_host":"grotto_hanging_bough","role":"suspended moving living anchor beneath a real bough; a worthwhile regional shortcut remains unproven; fixed root return is retained"},
		{"id":"grotto_thread","behavior":"forest_thread_spider","position":[330.0,986.0],"radius":0.0,"support":"grotto_east_root","role":"finite root thread may be waited out, shot or crossed at another height","line_start":[180.0,982.0],"line_end":[290.0,982.0]},
		{"id":"east_leaf_lantern","behavior":"forest_lantern","position":[80.0,495.0],"radius":55.0,"support":"","role":"optional living catch on the descent; fixed log stays available"}]
	if mix==1:
		placements.append({"id":"grotto_outer_watch","behavior":"forest_thread_spider","position":[-1580.0,906.0],"radius":0.0,"support":"fallen_chain__recovery","line_start":[-1650.0,902.0],"line_end":[-1520.0,902.0],"role":"finite root web changes the lower return from ranged pressure to a visible wait, shoot or alternate-height decision"})
	else:
		placements.append({"id":"grotto_outer_watch","behavior":"forest_seed_sentry","position":[-1580.0,902.0],"radius":0.0,"support":"fallen_chain__recovery","role":"watch beneath the fallen log, changes return-side approach"})
	placements.append_array(m.western_grove_contract.enemy_suggestions)
	var rejected: Array=[]
	for row: Dictionary in placements:
		var path: String="res://resources/enemies/"+str(row.behavior)+".tres"
		var definition: EnemyDefinition=load(path)
		var at:=_point(row.position)
		var half:=definition.collision_size*0.5
		var radius:=float(row.radius)
		var sweep:=Rect2(at-half-Vector2(radius,85 if row.behavior=="forest_swing_pod" else 0),definition.collision_size+Vector2(radius*2,85 if row.behavior=="forest_swing_pod" else 0))
		if sweep.grow(150).has_point(_point(m.spawn)) or sweep.grow(95).has_point(_point(m.merchant_position)):
			rejected.append({"id":row.id,"reason":"spawn_or_merchant_body_exclusion"});continue
		if not str(row.support).is_empty():
			var surface:=_platform_by_id(m,str(row.support))
			var support_rect:=Rect2(surface.rect[0],surface.rect[1],surface.rect[2],surface.rect[3])
			if sweep.position.x<support_rect.position.x or sweep.end.x>support_rect.end.x or absf(at.y+half.y-support_rect.position.y)>0.1:
				rejected.append({"id":row.id,"reason":"authored_body_sweep_not_supported"});continue
		var placed: Dictionary={"id":row.id,"behavior_id":row.behavior,"definition_path":path,"definition_sha256":FileAccess.get_sha256(path),"stable_id":String(definition.stable_id),"position":row.position.duplicate(),"aerial":definition.aerial,"patrol_radius":radius,"support_id":row.support,"authored_body_sweep":[sweep.position.x,sweep.position.y,sweep.size.x,sweep.size.y],"encounter_role":row.role,"encounter_group":"expedition_root_crown","approach":"read broad shore before committing; alternate height/return remains","alternatives":["ordinary shoot or lure","use a fixed hook route","retain lower return"],"ecology_recipe":"expedition_%s"%mix}
		if row.has("line_start"):placed.line_start=row.line_start.duplicate();placed.line_end=row.line_end.duplicate()
		if row.has("direction"):placed.initial_direction=int(row.direction)
		if row.has("tether_host"):
			placed.tether_host_support_id=row.tether_host
			placed.tether_origin=[at.x,at.y-(definition as ForestEnemyDefinition).swing_rise-30.0]
		m.enemies.append(placed)
	var dropper:=EnemyDropService.new();dropper.configure(str(m.seed),"thorn_forest/map_%s"%m.map_index)
	for row: Dictionary in m.enemies:
		if not m.enemy_drops.has(row.id):m.enemy_drops[row.id]=dropper.settle(StringName(row.id))
	m.expedition_ecology={"planned_count":placements.size(),"rejected":rejected,"total_count":m.enemies.size(),"mix":mix,"local_enemy_mechanics_verified_separately":true,"formal_encounters":"unverified"}

static func _air_edge(m: Dictionary,id: String,a: String,b: String,instance: Dictionary) -> void:
	var offset:=_point(instance.translation)
	var start:=_point(instance.local_geometry.spawn)+offset
	var goal:=_point(instance.local_geometry.goal)+offset
	_edge(m,id,a,b,"airborne_chain",[pair(start),pair(goal)])
	m.connections[-1].merge({"geometry_instance":instance.id,"landing":pair(goal),"landing_support_id":instance.platform_id_map.crown,"from_support_id":instance.platform_id_map.entry,"action_program":instance.local_geometry.action_program.duplicate(true),"continuous_airborne":true,"optional_lower_alternative":true})
static func _step(kind: String,start: Vector2,goal: Vector2,from: String,to: String) -> Dictionary:return {"kind":kind,"takeoff":pair(start),"landing":pair(goal),"from_support_id":from,"support_id":to}
static func _edge(m: Dictionary,id: String,a: String,b: String,kind: String,path: Array,steps: Array=[]) -> void:m.connections.append({"id":id,"a":a,"b":b,"kind":kind,"path":path,"steps":steps,"condition":"open","admission":"candidate_pending_formal","native_verified":false})
static func _platform(m: Dictionary,id: String,rect: Rect2,one_way: bool,kind: String,structure: String,role: String) -> void:m.platforms.append({"id":id,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"one_way":one_way,"scene_kind":kind,"structure_id":structure,"surface_role":role})
static func _area(m: Dictionary,id: String,at: Vector2,label: String,role: String) -> void:m.areas.append({"id":id,"position":pair(at),"label":label,"role":role})
static func _has_platform(m: Dictionary,id: String) -> bool:return not _platform_by_id(m,id).is_empty()
static func _platform_by_id(m: Dictionary,id: String) -> Dictionary:
	for row: Dictionary in m.platforms:
		if row.id==id:return row
	return {}
static func _has_area(m: Dictionary,id: String) -> bool:
	for row: Dictionary in m.areas:
		if row.id==id:return true
	return false
static func _has_edge(m: Dictionary,id: String) -> bool:return not BASE._edge_by_id(m,id).is_empty()
static func pair(at: Vector2) -> Array:return [at.x,at.y]
static func _point(value: Array) -> Vector2:return Vector2(value[0],value[1])
