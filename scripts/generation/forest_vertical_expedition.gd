class_name ForestVerticalExpedition
extends RefCounted
## Woven trunk: safe receiving boughs separate genuinely airborne phrases.
## Lower catches return to the same mouth; they never lead east to the Boss.
const VERSION := "forest-woven-trunk-v12"
const UPPER_EXIT_RING := [140.0,-640.0]
const THORN_CATCH_RECT := [-310.0,720.0,1190.0,40.0]
const THORN_CATCH_BOUNDS := [-320.0,-550.0,1220.0,1390.0]
const CANOPY_RETURN_LEFT := 85.0
const CANOPY_RETURN_GOAL_X := 105.0
const RETURN_VIA := {"position":[-150.0,396.0],"support_id":"upper_spiral__crown","kind":"drop_through","next":[-150.0,600.0]}
const RETURN_APERTURE := {"top":560.0,"bottom":640.0,"support":"right_bark","lower_support":"right_bark_return_lower"}
const THORN_RETRY_RINGS := [{"id":"thorn_retry_low_ring","local_position":[-105.0,400.0],"local_tether":[-105.0,78.0],"host":"thorn_mouth__entry"},{"id":"thorn_retry_high_ring","local_position":[-85.0,225.0],"local_tether":[-85.0,78.0],"host":"thorn_mouth__entry"},{"id":"thorn_retry_exit_ring","local_position":[-35.0,98.0],"local_tether":[-35.0,78.0],"host":"thorn_mouth__entry"}]
const BASE := preload("res://scripts/generation/thorn_forest_region_v2_v10.gd")
const API := preload("res://scripts/generation/forest_expedition_layout.gd")
const MOUTH := preload("res://scripts/generation/forest_thorn_mouth_geometry.gd")
const VERTICAL := preload("res://scripts/generation/forest_vertical_chain_geometry.gd")

static func install(m: Dictionary) -> void:
	var kept: Array=[]
	for e: Dictionary in m.connections:
		if str(e.id) not in ["crown_reverse_return","outer_lift_return","deep_to_west"]:kept.append(e)
	m.connections=kept
	m.erase("crown_return_contract");m.erase("ecology_expedition_contract")
	# The optional reward's old wide catch crosses the new crown shaft.
	# Retain its eastern recovery shore and steps, leaving the shaft open
	# to the real hook ray as well as the ascending Player body.
	for platform: Dictionary in m.platforms:
		if str(platform.id)=="far_root_catch":platform.rect=[-220.0,820.0,300.0,30.0]
	# Approach the old north court below the new canopy receiving bough.
	for anchor: Dictionary in m.hook_anchors:
		if str(anchor.id)=="north_court_ring":anchor.position=[300.0,440.0]
	for edge: Dictionary in m.connections:
		if str(edge.id)=="west_north":edge.path[2]=[300.0,440.0]
		if bool(m.choices.get("west_reward",false)) and str(edge.id) in ["far_reward_return","far_bough_decline"]:
			edge.return_via=RETURN_VIA.duplicate(true)
			edge.path.insert(2,RETURN_VIA.position.duplicate())
	for area: Dictionary in m.areas:
		if area.id=="arrival":area.id="old_arrival"
	for e: Dictionary in m.connections:
		if e.a=="arrival":e.a="old_arrival"
		if e.b=="arrival":e.b="old_arrival"
	var rng:=RunRandomStream.new(str(m.seed),"forest_vertical","map_%s"%m.map_index,VERSION)
	var crossing: String="hook_hook" if rng.next_int(2)==0 else "recoil_hook"
	if crossing=="recoil_hook" and bool(m.choices.get("west_reward",false)):crossing="recoil_hook_recoil"
	var placements: Array=[
		["root_spiral",Vector2(-2200,1882),"hollow_spiral","HOLLOW ROOT / THE WINDING SAP SHAFT"],
		["lower_fork",Vector2(-2050,1322),"recoil_hook","LIVING FORK / SIDEWAYS BETWEEN TRUNKS"],
		["thorn_mouth",Vector2(-1695,1280),"thorn_mouth","THORN HOLLOW / SIDE CATCH THEN RECOIL THROUGH"],
		["middle_fork",Vector2(-1340,1238),"recoil_hook","TRUNK FORK / RECOIL BELOW THE BROKEN BARK"],
		["broken_arch",Vector2(-985,1196),"arch_four","BROKEN TRUNK / UNDER THE BARK ARCH"],
		["upper_spiral",Vector2(-435,956),"hollow_spiral","CROWN SHAFT / RECOIL INTO DAYLIGHT"],
		["canopy_fork",Vector2(-285,396),crossing,"LEAF FORK / OLD TREE BELOW"]]
	m.observation_windows=m.get("observation_windows",[]).duplicate(true)
	var prefix: Array=[]
	var previous: String="arrival"
	var previous_instance: Dictionary={}
	for index: int in placements.size():
		var row: Array=placements[index]
		var id:=str(row[0]);var offset: Vector2=row[1];var layout:=str(row[2])
		var instance: Dictionary=_vertical(m,id,offset,layout) if layout in ["hollow_spiral","thorn_mouth"] else API._install_chain(m,id,offset,layout)
		if layout=="arch_four" or id=="upper_spiral":_shared_catch(m,instance)
		if id=="upper_spiral":_upper_exit_clearance(m,instance)
		if id=="upper_spiral" and bool(m.choices.get("west_reward",false)):_upper_return_aperture(m,instance)
		if id=="thorn_mouth":_deepen_thorn_catch(m,instance)
		if id=="canopy_fork" and bool(m.choices.get("west_reward",false)):_canopy_return_clearance(m,instance)
		if not previous_instance.is_empty():_clip_entry(m,instance,previous_instance)
		var entry:=API._point(instance.local_geometry.spawn)+offset
		var goal:=API._point(instance.local_geometry.goal)+offset
		m.observation_windows.append({"id":id+"_read","rect":[entry.x-155.0,entry.y-48.0,310.0,88.0],"focus":API.pair(entry+Vector2(40,-320) if layout=="hollow_spiral" else entry+Vector2(250,-100))})
		var mouth:=id+"_mouth";var crown:=id+"_crown"
		API._area(m,mouth,entry,str(row[3]),"junction")
		API._area(m,crown,goal,"SAFE BOUGH / LOOK BEFORE THE NEXT FLIGHT","junction")
		API._edge(m,id+"_approach",previous,mouth,"walk",[API.pair(entry),API.pair(entry)])
		prefix.append(id+"_approach")
		API._air_edge(m,id+"_flight",mouth,crown,instance)
		m.connections[-1].optional_lower_alternative=false
		prefix.append(id+"_flight")
		previous=crown;previous_instance=instance
	API._platform(m,"east_descent_log",Rect2(-30,372,200,24),true,"fallen_log","east_broken_log","safe_descent_lip")
	if bool(m.choices.get("west_reward",false)):
		var log_surface:=API._platform_by_id(m,"east_descent_log")
		log_surface.rect=[CANOPY_RETURN_LEFT,372.0,170.0-CANOPY_RETURN_LEFT,24.0]
	if not API._has_platform(m,"west_court"):API._platform(m,"west_court",Rect2(40,618,260,28),true,"canopy_perch","old_tree_west_root","old_tree_arrival")
	if not API._has_area(m,"W"):API._area(m,"W",Vector2(180,600),"WEST ROOT / OLD TREE","junction")
	var descent_start: Array=[CANOPY_RETURN_GOAL_X,354.0] if bool(m.choices.get("west_reward",false)) else [70.0,354.0]
	API._edge(m,"woven_descent",previous,"W","ordinary_sequence",[descent_start,[100.0,354.0],[180.0,600.0]],[{"kind":"walk","landing":[100.0,354.0]},{"kind":"drop_through","path":[[100.0,354.0],[230.0,354.0],[230.0,600.0],[180.0,600.0]],"landing":[180.0,600.0]}])
	prefix.append("woven_descent")
	if not API._has_edge(m,"west_to_belly"):
		var receiving: String="hollow__belly_west" if int(m.choices.skeleton)==1 else "hollow__belly_entry"
		var steps: Array=[API._step("jump_gap",Vector2(288,600),Vector2(392,600),"west_court",receiving)]
		if int(m.choices.skeleton)==1:steps.append(API._step("jump_gap",Vector2(468,600),Vector2(532,600),"hollow__belly_west","hollow__belly_entry"))
		API._edge(m,"west_to_belly","W","M","ordinary_sequence",[[180.0,600.0],[600.0,600.0]],steps)
	prefix.append("west_to_belly")
	m.spawn=[-2200.0,1882.0]
	API._area(m,"arrival",Vector2(-2200,1882),"ROOT SHAFT / BEGIN THE CANOPY ASCENT","tutorial")
	m.routes.clear()
	var rest_prefix: Array=prefix.duplicate()
	var rest_edge:=BASE._edge_by_id(m,"root_spiral_flight").duplicate(true)
	rest_edge.id="root_spiral_rest_flight";rest_edge.kind="hanging_chain"
	rest_edge.action_program=VERTICAL.build().rest_program.duplicate(true)
	rest_edge.rest_anchor_id="root_spiral__rest_ring";rest_edge.hang_observation_frames=18
	m.connections.append(rest_edge);rest_prefix[1]="root_spiral_rest_flight"
	var fast: Array=prefix.duplicate();fast.append_array(BASE._route(m,"M","gate_ready"))
	var growth: Array=rest_prefix.duplicate();growth.append_array(BASE._route(m,"M","camp"));growth.append_array(BASE._route(m,"camp","cache"));growth.append_array(BASE._route(m,"cache","gate_ready"))
	var high: Array=rest_prefix.duplicate();high.append_array(BASE._route(m,"M","cache"));high.append_array(BASE._route(m,"cache","camp"))
	var reconsider: Array=prefix.duplicate();reconsider.append_array(BASE._route(m,"M","camp"))
	var shared_index:=-1
	for i: int in mini(fast.size(),reconsider.size()):
		if fast[i]!=reconsider[i]:break
		shared_index=i
	var decision: String="arrival" if shared_index<0 else str(BASE._edge_by_id(m,str(fast[shared_index])).b)
	var borer: Array=prefix.duplicate();borer.append_array(BASE._route(m,"M","S"));borer.append("borer_crossing");borer.append_array(BASE._route(m,"C","gate_ready"))
	m.routes={"fast":fast,"growth":growth,"high_return":high,"change_mind":reconsider,"borer":borer}
	m.change_mind_contract={"decision_node":decision,"planned_goal":"gate_ready","chosen_goal":"camp","actual_input":"unverified"}
	m.entry_contract={"selected":"root_spiral","reason":"vertical_compound_trunk_is_the_primary_route","native_verified":false}
	m.vertical_contract={"version":VERSION,"primary_rise":1528.0,"ordinary_forward_bypass":false,"continuous_phrases":7,"recovery":"deep thorn catch returns through three fixed hanging roots to the same mouth; ordinary ground cannot reach forward crowns","golden":"hollow_spiral H H R H / thorn_mouth H R","early_choice":"right brass continuous flight or left teal hanging observation, rejoin broad root crown","native_verified":false,"production_pool":false}
	_ecology(m)
	m.expedition_hints=[{"position":[-2250.0,1790.0],"text":"Climb through the hollow: hook, hook,\nfire down, then catch the crown ring.","radius":210.0},{"position":[-2430.0,1732.0],"text":"Teal double ring: hang and observe.\nJump kicks off; hook again or fire.\nBrass rings kick off automatically.","radius":200.0},{"position":[-1940.0,1880.0],"text":"Deep roots return to the SAME hollow.\nJump high to the green hanging roots.\nRest, reaim, then fire down below the bough.","radius":230.0},{"position":[-1710.0,1120.0],"text":"Each broad bough is a place to read.\nThe next flight changes direction.","radius":180.0}]
	m.scene_structure_kinds={"hollow":"hollow_tree","root_spiral":"hollow_tree","thorn_mouth":"hollow_tree","upper_spiral":"hollow_tree","lower_fork":"bough_relay","broken_arch":"fallen_trunk","canopy_fork":"bough_relay","middle_fork":"bough_relay","east_broken_log":"fallen_trunk","old_tree_west_root":"rootland","forest_roots":"rootland","forest_boughs":"bough_group"}
	m.choices.vertical_crossing=crossing;m.streams.vertical="forest_vertical";m.stream_positions.vertical=rng.position()

static func _vertical(m: Dictionary,id: String,offset: Vector2,layout: String) -> Dictionary:
	var geometry:=VERTICAL.build() if layout=="hollow_spiral" else MOUTH.build()
	var instance: Dictionary={"id":id,"factory":"res://scripts/generation/forest_vertical_chain_geometry.gd" if layout=="hollow_spiral" else "res://scripts/generation/forest_thorn_mouth_geometry.gd","geometry_version":str(geometry.version),"local_geometry":geometry.duplicate(true),"translation":API.pair(offset),"platform_id_map":{},"anchor_id_map":{},"danger_indices":[]}
	for row: Dictionary in geometry.platforms:
		var rect:=BASE._rect(row.rect);rect.position+=offset
		var mapped:=id+"__"+str(row.id);instance.platform_id_map[row.id]=mapped
		API._platform(m,mapped,rect,bool(row.one_way),"hollow_bark" if str(row.id) in ["left_bark","right_bark","root_arch"] else "root_earth" if str(row.id) in ["entry","recovery"] else "canopy_perch" if str(row.id)=="crown" else "living_bough",id,str(row.id))
	for danger: Array in geometry.dangers:
		instance.danger_indices.append(m.dangers.size())
		m.dangers.append([float(danger[0])+offset.x,float(danger[1])+offset.y,danger[2],danger[3]])
	for row: Dictionary in geometry.hook_anchors:
		var mapped:=id+"__"+str(row.id);instance.anchor_id_map[row.id]=mapped
		m.hook_anchors.append({"id":mapped,"position":API.pair(BASE._point(row.position)+offset),"scene_kind":"copper_growth_ring","structure_id":id})
	m.hook_anchors.append({"id":id+"__rest_ring","position":API.pair(offset+(Vector2(-120,-170) if layout=="hollow_spiral" else Vector2(-120,-70))),"scene_kind":"hanging_growth_ring","structure_id":id,"hang_enabled":true})
	m.geometry_instances.append(instance)
	return instance

static func _shared_catch(m: Dictionary,instance: Dictionary) -> void:
	# A later arch's isolated catch would cap the previous hollow's real
	# ascent. This explicit regional derivation uses that hollow's catch.
	var omitted: Array=[]
	for local: String in ["recovery","recovery_step"]:
		omitted.append(str(instance.platform_id_map[local]))
		instance.platform_id_map.erase(local)
	var platforms: Array=[]
	for row: Dictionary in m.platforms:
		if str(row.id) not in omitted:platforms.append(row)
	m.platforms=platforms
	instance.local_geometry.platforms=instance.local_geometry.platforms.filter(func(row: Dictionary) -> bool:return str(row.id) not in ["recovery","recovery_step"])
	instance.local_geometry.regional_recovery="previous-woven-hollow-catch-v1"
	instance.regional_derivation="omit_isolated_catch_above_previous_ascent"

static func _clip_entry(m: Dictionary,current: Dictionary,previous: Dictionary) -> void:
	# Shared ports inherit their real overlap. A standalone 300px approach
	# must not grow backwards across the preceding upward hook's line.
	var source: Dictionary=API._platform_by_id(m,str(current.platform_id_map.entry))
	var receiver: Dictionary=API._platform_by_id(m,str(previous.platform_id_map.crown))
	var a:=BASE._rect(source.rect);var b:=BASE._rect(receiver.rect)
	assert(absf(a.position.y-b.position.y)<0.01)
	var left:=maxf(a.position.x,b.position.x);var right:=minf(a.end.x,b.end.x)
	assert(right-left>=48)
	source.rect=[left,a.position.y,right-left,a.size.y]
	source.one_way=bool(receiver.one_way)
	if source.one_way:source.scene_kind="living_bough"
	for row: Dictionary in current.local_geometry.platforms:
		if row.id=="entry":
			row.rect=[left-float(current.translation[0]),a.position.y-float(current.translation[1]),right-left,a.size.y]
			row.one_way=bool(receiver.one_way)
	current.entry_derivation={"rule":"intersection_with_previous_crown","previous_instance":str(previous.id)}

static func _ecology(m: Dictionary) -> void:
	# Receiving centers and first hook rays remain clear. These creatures
	# contest the outer boughs and waiting positions, not invisible midair gates.
	var rows: Array=[]
	API._platform(m,"thorn_outer_fighting_bough",Rect2(-1095,1256,300,24),true,"fallen_log","thorn_mouth","separated_low_fighting_bough")
	for id: String in ["root_spiral","thorn_mouth","upper_spiral"]:
		var surface:=API._platform_by_id(m,"thorn_outer_fighting_bough" if id=="thorn_mouth" else id+"__crown");var r:=BASE._rect(surface.rect)
		rows.append({"id":id+"_bark_keeper","behavior":"forest_bark_beetle","support":surface.id,"position":[r.position.x+(150.0 if id=="thorn_mouth" else 245.0),r.position.y-12.0],"radius":10.0 if id=="thorn_mouth" else 20.0,"direction":-1,"role":"outer crown shield: bait the readable dash or shoot above it; central receiving bank stays clear"})
	var host_id:="upper_spiral_pod_bough"
	API._platform(m,host_id,Rect2(-695,480,180,16),true,"living_bough","upper_spiral","living_pod_host_branch")
	rows.append({"id":"crown_pendulum","behavior":"forest_swing_pod","support":"","position":[-595.0,596.0],"radius":40.0,"tether_host":host_id,"tether_origin":[-595.0,496.0],"role":"visible suspended living body beside the optional rest-ring lane; fixed core targets remain independent"})
	for spec: Array in [["root_gleam",-1870.0,1390.0],["middle_gleam",-1190.0,1130.0]]:
		rows.append({"id":spec[0],"behavior":"forest_lantern","support":"","position":[spec[1],spec[2]],"radius":28.0,"role":"side flight anchors near a broad hollow exit; may be used, shot or left alone"})
	var fork:=API._platform_by_id(m,"lower_fork__crown");var floor:=BASE._rect(fork.rect)
	rows.append({"id":"lower_fork_thread","behavior":"forest_thread_spider","support":fork.id,"position":[floor.end.x-35.0,floor.position.y-14.0],"radius":0.0,"line_start":[floor.end.x-110.0,floor.position.y-18.0],"line_end":[floor.end.x-45.0,floor.position.y-18.0],"role":"outer fork thread marks a wait-or-cross choice beyond the safe landing center"})
	for spec: Array in [["root_catch_watch","root_spiral__recovery"],["middle_catch_watch","thorn_mouth__recovery"]]:
		var surface:=API._platform_by_id(m,str(spec[1]));var r:=BASE._rect(surface.rect)
		rows.append({"id":spec[0],"behavior":"forest_seed_sentry","support":surface.id,"position":[r.end.x-80.0,r.position.y-18.0],"radius":0.0,"role":"recovery root seed warning; retained wide retry bank lets the player shoot, wait or change height"})
	var catch_surface:=API._platform_by_id(m,"root_spiral__recovery");var catch_rect:=BASE._rect(catch_surface.rect)
	rows.append({"id":"root_catch_charger","behavior":"charger","support":catch_surface.id,"position":[catch_rect.position.x+110.0,catch_rect.position.y-16.0],"radius":35.0,"role":"root-floor lunge encourages a height change during recovery, away from the first departure"})
	for row: Dictionary in rows:
		var path: String="res://resources/enemies/plains_charger.tres" if row.behavior=="charger" else "res://resources/enemies/"+str(row.behavior)+".tres"
		var definition: EnemyDefinition=load(path)
		var at:=BASE._point(row.position);var half:=definition.collision_size*.5
		if not str(row.support).is_empty():
			var support:=BASE._rect(API._platform_by_id(m,str(row.support)).rect)
			assert(absf(at.y+half.y-support.position.y)<.1)
			assert(at.x-half.x-float(row.radius)>=support.position.x and at.x+half.x+float(row.radius)<=support.end.x)
		var placed: Dictionary={"id":row.id,"behavior_id":row.behavior,"definition_path":path,"definition_sha256":FileAccess.get_sha256(path),"stable_id":String(definition.stable_id),"position":row.position,"aerial":definition.aerial,"patrol_radius":float(row.radius),"support_id":row.support,"encounter_role":row.role,"encounter_group":"woven_hollow_bough_ecology","approach":"read the central receiving bank before contesting outer branches","alternatives":["remain on central receiving bank","change height or hook direction","shoot or bait a visible commitment"]}
		if row.has("line_start"):placed.line_start=row.line_start;placed.line_end=row.line_end
		if row.has("direction"):placed.initial_direction=int(row.direction)
		if row.has("tether_host"):placed.tether_host_support_id=row.tether_host;placed.tether_origin=row.tether_origin
		m.enemies.append(placed)
	var dropper:=EnemyDropService.new();dropper.configure(str(m.seed),"thorn_forest/map_%s"%m.map_index)
	for row: Dictionary in m.enemies:
		if not m.enemy_drops.has(row.id):m.enemy_drops[row.id]=dropper.settle(StringName(row.id))
	m.vertical_ecology={"added":rows.size(),"total":m.enemies.size(),"formal_encounters":"unverified"}

static func _upper_return_aperture(m: Dictionary,instance: Dictionary) -> void:
	# An 80px tree hollow carries the old root return through the real bark.
	# Both remaining solid pieces retain the original wall's outer bounds.
	var offset:=BASE._point(instance.translation)
	var surface:=API._platform_by_id(m,str(instance.platform_id_map[RETURN_APERTURE.support]))
	var original:=BASE._rect(surface.rect)
	var upper_height:=float(RETURN_APERTURE.top)-original.position.y
	var lower_height:=original.end.y-float(RETURN_APERTURE.bottom)
	surface.rect=[original.position.x,original.position.y,original.size.x,upper_height]
	surface.surface_role="tree_return_upper_bark"
	var lower_local:={"id":str(RETURN_APERTURE.lower_support),"rect":[original.position.x-offset.x,float(RETURN_APERTURE.bottom)-offset.y,original.size.x,lower_height],"one_way":false}
	for row: Dictionary in instance.local_geometry.platforms:
		if str(row.id)==str(RETURN_APERTURE.support):row.rect=[original.position.x-offset.x,original.position.y-offset.y,original.size.x,upper_height]
	instance.local_geometry.platforms.append(lower_local)
	var mapped:=str(instance.id)+"__"+str(RETURN_APERTURE.lower_support)
	instance.platform_id_map[RETURN_APERTURE.lower_support]=mapped
	API._platform(m,mapped,Rect2(original.position.x,float(RETURN_APERTURE.bottom),original.size.x,lower_height),false,"hollow_bark",str(instance.id),"tree_return_lower_bark")
	instance.aperture_derivation={"rule":"tree_return_hollow","aperture":RETURN_APERTURE.duplicate(true),"scene_kind":"hollow_tree_return_opening"}

static func _canopy_return_clearance(m: Dictionary,instance: Dictionary) -> void:
	# Leave the migrant's actual return arc open below the receiving bough.
	# The remaining wide shore keeps its original right edge and one-way body.
	var offset:=BASE._point(instance.translation)
	var surface:=API._platform_by_id(m,str(instance.platform_id_map.crown))
	var original:=BASE._rect(surface.rect)
	surface.rect=[CANOPY_RETURN_LEFT,original.position.y,original.end.x-CANOPY_RETURN_LEFT,original.size.y]
	for row: Dictionary in instance.local_geometry.platforms:
		if row.id=="crown":row.rect=[CANOPY_RETURN_LEFT-offset.x,original.position.y-offset.y,original.end.x-CANOPY_RETURN_LEFT,original.size.y]
	instance.local_geometry.goal=[CANOPY_RETURN_GOAL_X-offset.x,float(instance.local_geometry.goal[1])]
	instance.receiver_derivation={"rule":"canopy_leave_migrant_return_gap","world_left":CANOPY_RETURN_LEFT,"world_goal_x":CANOPY_RETURN_GOAL_X}

static func _upper_exit_clearance(m: Dictionary,instance: Dictionary) -> void:
	# Optional legacy far-reward boughs occupy y268..292. The final catch
	# remains below their underside for every seed, instead of inside wood.
	for row: Dictionary in instance.local_geometry.hook_anchors:
		if row.id=="spiral_crown":row.position=UPPER_EXIT_RING.duplicate()
	for row: Dictionary in m.hook_anchors:
		if row.id==instance.anchor_id_map.spiral_crown:row.position=API.pair(BASE._point(instance.translation)+BASE._point(UPPER_EXIT_RING))
	instance.anchor_derivation={"rule":"upper_exit_below_legacy_far_bough","anchor":"spiral_crown","position":UPPER_EXIT_RING.duplicate()}

static func _deepen_thorn_catch(m: Dictionary,instance: Dictionary) -> void:
	# Actual baseline01 proved the former shallow catch skipped three flights.
	# A deep basin has staged fixed-H recovery, never a free upward staircase.
	var offset:=BASE._point(instance.translation)
	var rect:=BASE._rect(THORN_CATCH_RECT);rect.position+=offset
	var surface:=API._platform_by_id(m,str(instance.platform_id_map.recovery))
	surface.rect=[rect.position.x,rect.position.y,rect.size.x,rect.size.y]
	for row: Dictionary in instance.local_geometry.platforms:
		if row.id=="recovery":row.rect=THORN_CATCH_RECT.duplicate()
	instance.local_geometry.world_bounds=THORN_CATCH_BOUNDS.duplicate()
	instance.recovery_derivation={"rule":"deep_catch_with_hanging_return","rect":THORN_CATCH_RECT.duplicate(),"bounds":THORN_CATCH_BOUNDS.duplicate(),"return_area":"thorn_mouth_mouth"}
	for ring: Dictionary in THORN_RETRY_RINGS:
		m.hook_anchors.append({"id":ring.id,"position":API.pair(offset+BASE._point(ring.local_position)),"hang_enabled":true,"scene_kind":"hanging_root_ring","structure_id":"thorn_mouth","tether_origin":API.pair(offset+BASE._point(ring.local_tether)),"tether_host_support_id":ring.host,"recovery_role":"deep_catch_return_to_thorn_mouth"})
	m.expedition_recovery={"support":surface.id,"mouth":"thorn_mouth_mouth","program":["full held jump","thorn_retry_low_ring hang","thorn_retry_high_ring hang","thorn_retry_exit_ring hang below the one-way bough","fire down to recoil upward through the bough","land on the thorn-mouth bank"],"native_verified":false}
