class_name ForestExplorationEcology
extends RefCounted
## V16 placement only. Existing behaviours, combat, physics and drop policy own
## all outcomes. An omitted habitat is not repaired by changing world geometry.
const VERSION := "forest-exploration-ecology-v1"
const LAYOUT := "forest-branching-expedition-v16"
const MAXIMUM_ACTORS := 12
const DEFINITIONS := {
	"charger":"res://resources/enemies/plains_charger.tres",
	"forest_bark_beetle":"res://resources/enemies/forest_bark_beetle.tres",
	"forest_seed_sentry":"res://resources/enemies/forest_seed_sentry.tres",
	"forest_thread_spider":"res://resources/enemies/forest_thread_spider.tres",
	"forest_bible_weaver":"res://resources/enemies/forest_bible_weaver.tres",
	"forest_lantern":"res://resources/enemies/forest_lantern.tres",
	"forest_crossbranch":"res://resources/enemies/forest_crossbranch.tres",
	"forest_swing_pod":"res://resources/enemies/forest_swing_pod.tres"}

static func install(m: Dictionary) -> void:
	if m.get("layout_version") != LAYOUT: return
	var rng := RunRandomStream.new(str(m.seed),"forest_exploration_encounters","map_%s" % m.map_index,VERSION)
	m.enemies = []
	m.enemy_drops = {}
	var omitted: Array[Dictionary] = []
	var habitats: Dictionary = {}
	# These actors occupy different actual pieces. None is a mandatory moving
	# hook target, and the first ordinary teaching district remains unpressured.
	for behaviour: String in ["forest_bible_weaver","forest_crossbranch","forest_lantern","forest_swing_pod"]:
		var accepted := false
		var reasons: Array[String] = []
		# A designed borrowing encounter owns this one pod before the older
		# canopy habitat. Its source slot never creates an additional behaviour.
		if behaviour=="forest_swing_pod":
			for instance: Dictionary in m.get("geometry_instances",[]):
				if _district(str(instance.id))<1: continue
				for slot: Dictionary in instance.get("local_geometry",{}).get("ecology_slots",[]):
					if str(slot.get("id",""))!="borrow_pod" or str(slot.get("behavior_id",""))!=behaviour: continue
					var candidate := _authored_pod(m,instance,slot)
					var reason := _admit(m,candidate)
					if not reason.is_empty():
						omitted.append({"behaviour":behaviour,"instance":str(instance.id),"slot":"borrow_pod","reason":reason})
						continue
					m.enemies.append(candidate)
					habitats[behaviour] = str(instance.id)
					accepted = true
					break
				if accepted: break
		if accepted: continue
		for instance: Dictionary in m.get("geometry_instances",[]):
			if _district(str(instance.id)) < 1: continue
			var candidate := _special(m,instance,behaviour)
			if candidate.is_empty(): continue
			var reason := _admit(m,candidate)
			if not reason.is_empty(): reasons.append(str(instance.id)+":"+reason); continue
			m.enemies.append(candidate)
			habitats[behaviour] = str(instance.id)
			accepted = true
			break
		if not accepted: omitted.append({"behaviour":behaviour,"reason":"no_safe_non_tutorial_habitat","rejections":reasons})
	var ground_names: Array[String] = ["forest_seed_sentry","charger","forest_bark_beetle"]
	var rotation := rng.next_int(ground_names.size())
	for district: int in [1,2,3]:
		var behaviour: String = ground_names[(district-1+rotation)%ground_names.size()]
		var preferred: Array[String] = ["district_%s_main_b" % district]
		# First-map armour and ranged pressure belong to chosen branches. The
		# old short mushroom banks gave neither encounter a gentle main approach.
		if int(m.map_index)==1 and behaviour=="forest_bark_beetle": preferred=["district_3_explore","district_1_master","district_2_explore","district_3_master","district_2_master"]
		if int(m.map_index)==1 and behaviour=="forest_seed_sentry": preferred=["district_1_master","district_3_explore","district_2_explore","district_3_master","district_2_master"]
		var accepted_ground := false
		var rejections: Array[String] = []
		for id: String in preferred:
			var instance := _instance(m,id)
			var row := _ground(m,instance,behaviour)
			var reason := "no_supported_clear_counterplay_interval" if row.is_empty() else _admit(m,row)
			if not reason.is_empty(): rejections.append(id+":"+reason);continue
			m.enemies.append(row)
			accepted_ground = true
			break
		if not accepted_ground:
			if int(m.map_index)==1 and behaviour in ["forest_bark_beetle","forest_seed_sentry"]:
				omitted.append({"behaviour":behaviour,"reason":"no_supported_clear_counterplay_interval","rejections":rejections})
			else: omitted.append({"behaviour":behaviour,"instance":preferred[0],"reason":"no_supported_clear_counterplay_interval"})
	# One small timed web on a later ordinary piece; the first module/sole
	# receiver is not used as a hidden body or thread trap.
	var spider_added := false
	for district: int in [2,3,1]:
		var instance := _instance(m,"district_%s_main_a" % district)
		var row := _ground(m,instance,"forest_thread_spider")
		if row.is_empty(): continue
		var reason := _admit(m,row)
		if not reason.is_empty(): continue
		m.enemies.append(row)
		spider_added = true
		break
	if not spider_added: omitted.append({"behaviour":"forest_thread_spider","reason":"no_safe_late_supported_thread"})
	var dropper := EnemyDropService.new()
	dropper.configure(str(m.seed),"thorn_forest/map_%s" % m.map_index)
	var types: Array[String] = []
	for row: Dictionary in m.enemies:
		m.enemy_drops[str(row.id)] = dropper.settle(StringName(str(row.id)))
		if not types.has(str(row.behavior_id)): types.append(str(row.behavior_id))
	m.streams.exploration_encounters = "forest_exploration_encounters"
	m.stream_positions = m.get("stream_positions",{})
	m.stream_positions.exploration_encounters = rng.position()
	m.exploration_ecology = {"version":VERSION,"actors":m.enemies.size(),"maximum_actors":MAXIMUM_ACTORS,
		"behaviours":types,"habitats":habitats,"omissions":omitted,"ground_rotation":rotation,
		"first_ordinary_district":"no_enemies","spawn_exclusion_radius":150.0,"camp_interaction_radius":90.0,
		"real_source_definitions":true,"geometry_changed":false,"new_behaviours":false,
		"moving_targets":"optional; fixed fruit and ordinary module routes retained",
		"protection_scope":"authored body sweeps, lines and candidate ballistic paths; ranged projectile phases require actual gameplay validation",
		"native_interactions":"unverified","player_acceptance":"unverified"}

static func _special(m: Dictionary,instance: Dictionary,behaviour: String) -> Dictionary:
	var module_id := str(instance.get("module_id",""))
	if behaviour == "forest_bible_weaver" and module_id == "double_window": return _weaver(m,instance)
	if behaviour == "forest_crossbranch" and module_id == "double_fruit_s": return _crossbranch(m,instance)
	if behaviour == "forest_lantern" and module_id in ["side_fruit_crossing","double_fruit_s"]: return _lantern(m,instance)
	if behaviour == "forest_swing_pod" and module_id == "canopy_detour": return _pod(m,instance)
	return {}

static func _weaver(m: Dictionary,instance: Dictionary) -> Dictionary:
	var roof := _mapped(m,instance,"trunk_upper")
	var upper := _mapped(m,instance,"upper_window_floor")
	var lower := _mapped(m,instance,"lower_bank")
	if roof.is_empty() or upper.is_empty() or lower.is_empty(): return {}
	var cover := _rect(roof.rect)
	var a := _rect(upper.rect)
	var b := _rect(lower.rect)
	var left := maxf(a.position.x,b.position.x)+24.0
	var right := minf(a.end.x,b.end.x)-24.0
	if right-left < 48.0 or right-left > 150.0: return {}
	var definition := load(DEFINITIONS.forest_bible_weaver) as EnemyDefinition
	var at := Vector2(cover.end.x-24.0,cover.end.y+definition.collision_size.y*0.5+22.0)
	var row := _row(instance,"forest_bible_weaver",at,0.0,"")
	row.tether_host_support_id = str(roof.id)
	row.tether_origin = _pair(cover.get_center())
	row.web_strands = [{"id":"upper","start":[left,a.position.y-18.0],"end":[right,a.position.y-18.0]},
		{"id":"lower","start":[left,b.position.y-18.0],"end":[right,b.position.y-18.0]}]
	row.encounter_role = "Read alternating upper/lower threads from a broad bank; wait, shoot or use the other physical window."
	row.alternatives = ["wait outside the visible strand","shoot the rooted spider","cross the other window","return to the ordinary district route"]
	return row

static func _crossbranch(m: Dictionary,instance: Dictionary) -> Dictionary:
	var first := _mapped(m,instance,"lower_cross")
	var last := _mapped(m,instance,"exit")
	if first.is_empty() or last.is_empty(): return {}
	var definition := load(DEFINITIONS.forest_crossbranch) as ForestEnemyDefinition
	var a := _rect(first.rect)
	var b := _rect(last.rect)
	if a.size.x < 160.0 or b.size.x < 160.0: return {}
	var start := Vector2(a.end.x-48.0,a.position.y-definition.collision_size.y*0.5)
	var end := Vector2(b.position.x+100.0,b.position.y-definition.collision_size.y*0.5)
	var row := _row(instance,"forest_crossbranch",start,0.0,str(first.id))
	row.shore_rows = [{"id":str(first.id),"rect":first.rect.duplicate(),"position":_pair(start)},
		{"id":str(last.id),"rect":last.rect.duplicate(),"position":_pair(end)}]
	var ignored: Array[String] = [str(first.id),str(last.id)]
	var outward := _flight(m,start,end,definition,ignored)
	var returning := _flight(m,end,start,definition,ignored)
	if outward.is_empty() or returning.is_empty():
		row.placement_refusal = "existing_world_obstructs_authored_two_way_ballistic_body"
		return row
	var sweep: Rect2 = outward.sweep.merge(returning.sweep)
	row.authored_body_sweep = _rect_row(sweep)
	row.ballistic_path = {"outward_seconds":outward.seconds,"return_seconds":returning.seconds,
		"sample_hz":60,"both_directions_checked":true,"scope":"static world rectangles; actual live phase remains unverified"}
	row.fixed_alternative_anchor_ids = _fixed_fruits(instance)
	row.encounter_role = "Observe the departing body between two real boughs; borrow it as an optional H target or wait and use the fixed roots."
	row.alternatives = ["wait for the visible departure","shoot then use the unchanged ordinary crossing","use existing fixed fruit","decline this side branch"]
	return row

static func _lantern(m: Dictionary,instance: Dictionary) -> Dictionary:
	var translation := _point(instance.translation)
	var local := Vector2(448.0,-104.0) if str(instance.module_id)=="side_fruit_crossing" else Vector2(256.0,-144.0)
	var radius := 60.0 if str(instance.module_id)=="side_fruit_crossing" else 48.0
	var row := _row(instance,"forest_lantern",translation+local,radius,"")
	row.fixed_alternative_anchor_ids = _fixed_fruits(instance)
	if row.fixed_alternative_anchor_ids.is_empty(): return {}
	row.shore_support_ids = []
	for id: String in (["low_root_a","receiver"] if str(instance.module_id)=="side_fruit_crossing" else ["entry","observation"]):
		var support := _mapped(m,instance,id)
		if support.is_empty(): return {}
		row.shore_support_ids.append(str(support.id))
	row.encounter_role = "A visible living catch crosses the gap above two real banks; fixed fruit and ordinary stepping roots remain available after it dies."
	row.alternatives = ["borrow the moving lantern","take the fixed fruit","shoot from the broad bank","use the ordinary stepping-root route"]
	return row

static func _pod(m: Dictionary,instance: Dictionary) -> Dictionary:
	var host := _mapped(m,instance,"crown_middle")
	if host.is_empty(): return {}
	var definition := load(DEFINITIONS.forest_swing_pod) as ForestEnemyDefinition
	var rect := _rect(host.rect)
	var at := Vector2(rect.get_center().x,rect.end.y+definition.swing_rise+definition.collision_size.y*0.5+24.0)
	var radius := minf(64.0,rect.size.x*0.3)
	var row := _row(instance,"forest_swing_pod",at,radius,"")
	row.authored_body_sweep = _rect_row(Rect2(at-definition.collision_size*0.5-Vector2(radius,definition.swing_rise),definition.collision_size+Vector2(radius*2.0,definition.swing_rise)))
	row.tether_host_support_id = str(host.id)
	row.tether_origin = _pair(rect.get_center())
	row.fixed_alternative_anchor_ids = _fixed_fruits(instance)
	row.encounter_role = "A pod hangs from the actual upper bough and swings above the lower return; read its phase or choose the fixed upper branch."
	row.alternatives = ["wait for the outward swing","borrow the living body","use the fixed fruit","remain on the lower ordinary route"]
	return row

static func _authored_pod(m: Dictionary,instance: Dictionary,slot: Dictionary) -> Dictionary:
	var definition := load(DEFINITIONS.forest_swing_pod) as ForestEnemyDefinition
	var row := _row(instance,"forest_swing_pod",Vector2.ZERO,0.0,"")
	row.authored_slot_id = "borrow_pod"
	if not slot.get("position") is Array or slot.position.size()!=2 or not slot.get("tether_origin") is Array or slot.tether_origin.size()!=2:
		row.placement_refusal = "invalid_borrow_pod_coordinates"
		return row
	for value: Variant in slot.position+slot.tether_origin:
		if not (value is float or value is int) or not is_finite(float(value)):
			row.placement_refusal = "invalid_borrow_pod_coordinates"
			return row
	var radius: Variant = slot.get("patrol_radius")
	if not (radius is float or radius is int) or not is_finite(float(radius)) or float(radius)<=0.0 or float(radius)>definition.patrol_half_width:
		row.placement_refusal = "invalid_borrow_pod_radius"
		return row
	var at := _point(instance.translation)+_point(slot.position)
	row.position = _pair(at)
	row.patrol_radius = float(radius)
	row.authored_body_sweep = _rect_row(Rect2(at-definition.collision_size*.5-Vector2(float(radius),definition.swing_rise),definition.collision_size+Vector2(float(radius)*2.0,definition.swing_rise)))
	row.tether_host_support_id = str(instance.get("platform_id_map",{}).get(str(slot.get("tether_host_support_id","")),""))
	row.tether_origin = _pair(_point(instance.translation)+_point(slot.tether_origin))
	row.shore_support_ids = []
	row.fixed_alternative_anchor_ids = []
	if not slot.get("shore_support_ids") is Array or slot.shore_support_ids.size()!=2 or str(slot.shore_support_ids[0])==str(slot.shore_support_ids[1]):
		row.placement_refusal = "invalid_borrow_pod_shores"
		return row
	for local: Variant in slot.shore_support_ids:
		row.shore_support_ids.append(str(instance.get("platform_id_map",{}).get(str(local),"")))
	if not slot.get("fixed_alternative_anchor_ids") is Array or slot.fixed_alternative_anchor_ids.is_empty():
		row.placement_refusal = "missing_borrow_pod_fixed_alternative"
		return row
	for local: Variant in slot.fixed_alternative_anchor_ids:
		row.fixed_alternative_anchor_ids.append(str(instance.get("anchor_id_map",{}).get(str(local),"")))
	row.encounter_role = "Read the rooted pod's turn, borrow its living body toward the real upper receiver, or shoot and use the unchanged fixed-fruit/root route."
	row.alternatives = ["wait on the broad observation root","borrow the moving body with the existing contact kick","shoot for the ordinary settled drop, which may be none","use the independent fixed fruit","continue through the lower root hollow"]
	row.live_traversal = "unverified; enemy H damages one HP and uses the ordinary short contact kick, never fixed-anchor hang jump"
	return row

static func _ground(m: Dictionary,instance: Dictionary,behaviour: String) -> Dictionary:
	if instance.is_empty(): return {}
	var definition := load(DEFINITIONS[behaviour]) as EnemyDefinition
	var local: Dictionary = instance.local_geometry
	var candidates: Array[Dictionary] = []
	for source: Dictionary in local.get("platforms",[]):
		if str(source.id) in ["catch","tunnel_roof"] or "step" in str(source.id) or "return" in str(source.id): continue
		var platform := _mapped(m,instance,str(source.id))
		if platform.is_empty(): continue
		var rect := _rect(platform.rect)
		if rect.size.x<192.0: continue
		var at := Vector2(rect.get_center().x,rect.position.y-definition.collision_size.y*0.5)
		var entry := _point(local.spawn)+_point(instance.translation)
		var exit := _point(local.goal)+_point(instance.translation)
		if at.distance_to(entry)<140.0 or at.distance_to(exit)<140.0: continue
		var radius := 0.0 if behaviour in ["forest_seed_sentry","forest_thread_spider"] else minf(24.0,(rect.size.x-definition.collision_size.x)*0.2)
		var row := _row(instance,behaviour,at,radius,str(platform.id))
		if behaviour=="forest_bark_beetle":
			row.initial_direction = -1
			var counterspace := Rect2(at-Vector2(72.0,164.0),Vector2(144.0,164.0))
			if not _clear(m,counterspace,[str(platform.id)]): continue
			row.overhead_counterspace = _rect_row(counterspace)
		if behaviour=="forest_thread_spider":
			row.line_start = [at.x-88.0,rect.position.y-18.0]
			row.line_end = [at.x-24.0,rect.position.y-18.0]
			row.encounter_role = "A short visible root thread changes a later approach into a wait, jump, shoot or alternate-branch choice."
			row.alternatives = ["wait before the visible thread","shoot from the previous broad support","use the higher branch","return to the district fork"]
		if _admit(m,row).is_empty(): candidates.append(row)
	if candidates.is_empty(): return {}
	return candidates[0]

static func _row(instance: Dictionary,behaviour: String,at: Vector2,radius: float,support: String) -> Dictionary:
	var path: String = DEFINITIONS[behaviour]
	var definition := load(path) as EnemyDefinition
	var sweep := Rect2(at-definition.collision_size*0.5-Vector2(radius,0.0),definition.collision_size+Vector2(radius*2.0,0.0))
	return {"id":"exploration__"+str(instance.id)+"__"+behaviour,"behavior_id":behaviour,
		"definition_path":path,"definition_sha256":FileAccess.get_sha256(path),"stable_id":String(definition.stable_id),
		"position":_pair(at),"aerial":definition.aerial,"patrol_radius":radius,"support_id":support,
		"authored_body_sweep":_rect_row(sweep),"geometry_instance":str(instance.id),"ecology_version":VERSION,
		"encounter_group":str(instance.id)+"_ecology","encounter_role":"Read a later supported encounter; shoot, lure or choose the other district branch.",
		"alternatives":["shoot from a broad observation bank","lure the committed attack then pass","take the independent exploration or ordinary route"],
		"first_route_observation":"unverified"}

static func _admit(m: Dictionary,row: Dictionary) -> String:
	if not str(row.get("placement_refusal","")).is_empty(): return str(row.placement_refusal)
	if m.get("enemies",[]).size()>=MAXIMUM_ACTORS: return "actor_budget"
	var sweep := _rect(row.authored_body_sweep)
	var reason := _protected(m,sweep)
	if not reason.is_empty(): return reason
	var support_id := str(row.support_id)
	var ignore: Array[String] = []
	if not support_id.is_empty():
		var host := _support(m,support_id)
		if host.is_empty(): return "missing_support"
		var support := _rect(host.rect)
		var definition := load(str(row.definition_path)) as EnemyDefinition
		var at := _point(row.position)
		# A ballistic actor stands on each shore separately. Its flight bounds
		# span the gap and cannot be used as a patrol footprint on the first bank.
		var footprint := Rect2(at-definition.collision_size*0.5,definition.collision_size) if row.has("shore_rows") else sweep
		if footprint.position.x<support.position.x or footprint.end.x>support.end.x or absf(at.y+definition.collision_size.y*0.5-support.position.y)>.01: return "body_not_supported"
		ignore.append(support_id)
	# Crossbranch's larger sweep includes its two intended receiving supports.
	if row.has("shore_rows"):
		var definition := load(str(row.definition_path)) as ForestEnemyDefinition
		if definition==null or row.shore_rows.size()!=2: return "invalid_ballistic_shores"
		for shore: Dictionary in row.shore_rows:
			var host := _support(m,str(shore.id))
			if host.is_empty() or host.rect!=shore.rect: return "missing_ballistic_shore"
			var support := _rect(host.rect)
			var at := _point(shore.position)
			var body := Rect2(at-definition.collision_size*0.5,definition.collision_size)
			if body.position.x<support.position.x or body.end.x>support.end.x or absf(body.end.y-support.position.y)>.01: return "ballistic_shore_body_not_supported"
			ignore.append(str(shore.id))
		if str(row.shore_rows[0].id)==str(row.shore_rows[1].id) or str(row.shore_rows[0].id)!=support_id or _point(row.shore_rows[0].position)!=_point(row.position): return "invalid_ballistic_shore_identity"
		if _flight(m,_point(row.shore_rows[0].position),_point(row.shore_rows[1].position),definition,ignore).is_empty() or _flight(m,_point(row.shore_rows[1].position),_point(row.shore_rows[0].position),definition,ignore).is_empty(): return "existing_world_obstructs_authored_two_way_ballistic_body"
	if not row.has("shore_rows") and not _clear(m,sweep,ignore): return "body_sweep_obstructed"
	if row.has("tether_host_support_id"):
		var host := _support(m,str(row.tether_host_support_id))
		if host.is_empty() or not _rect(host.rect).has_point(_point(row.tether_origin)): return "tether_root_not_in_host"
	if row.get("authored_slot_id")=="borrow_pod":
		for id: String in row.shore_support_ids:
			var shore := _support(m,id)
			if shore.is_empty() or _rect(shore.rect).size.x<24.0: return "missing_borrow_pod_shore"
		for id: String in row.fixed_alternative_anchor_ids:
			var found := false
			for anchor: Dictionary in m.get("hook_anchors",[]):
				if str(anchor.id)!=id: continue
				var host := _support(m,str(anchor.get("fruit_host_support_id","")))
				var root: Variant = anchor.get("fruit_stem_root")
				if host.is_empty() or not root is Array or root.size()!=2 or not _rect(host.rect).grow(.01).has_point(_point(root)): return "unrooted_borrow_pod_fixed_alternative"
				found = true
				break
			if not found: return "missing_borrow_pod_fixed_alternative"
	for line: Dictionary in _lines(row):
		var first := _point(line.start)
		var last := _point(line.end)
		var definition := load(str(row.definition_path)) as ForestEnemyDefinition
		if definition==null or first.distance_to(last)<8.0 or first.distance_to(last)>definition.line_max_length: return "invalid_web_length"
		var line_box := Rect2(first,Vector2.ONE).expand(last).grow(definition.line_radius)
		if not _clear(m,line_box,[]): return "web_intersects_world"
		var protection_reason := _protected(m,line_box)
		if not protection_reason.is_empty(): return "web_"+protection_reason
	for placed: Dictionary in m.get("enemies",[]):
		if sweep.grow(48.0).intersects(_rect(placed.authored_body_sweep),true): return "overlapping_encounter_body_sweeps"
	return ""

static func _protected(m: Dictionary,sweep: Rect2) -> String:
	var body_space := sweep.grow_individual(12.0,18.0,12.0,18.0)
	if _distance(_point(m.spawn),body_space)<150.0: return "spawn_observation"
	if _distance(_point(m.merchant_position),body_space)<=90.0: return "camp_interaction"
	for chest: Dictionary in m.get("rewards",[]):
		if _distance(_point(chest.position),body_space)<=80.0: return "chest_interaction"
	for discovery: Dictionary in m.get("forest_discoveries",[]):
		if _distance(_point(discovery.position),body_space)<=90.0: return "Reader_interaction"
	return ""

static func _clear(m: Dictionary,body: Rect2,ignore: Array[String]) -> bool:
	for platform: Dictionary in m.get("platforms",[]):
		if ignore.has(str(platform.id)): continue
		if body.intersects(_rect(platform.rect)): return false
	for hazard: Array in m.get("dangers",[]):
		if body.intersects(_rect(hazard)): return false
	return true

static func _flight(m: Dictionary,start: Vector2,end: Vector2,definition: ForestEnemyDefinition,ignore: Array[String]) -> Dictionary:
	var vy := definition.crossbranch_rise_velocity if end.y<start.y else definition.crossbranch_fall_velocity
	var discriminant := vy*vy+2.0*definition.crossbranch_gravity*(end.y-start.y)
	if discriminant<=0.0: return {}
	var seconds := (-vy+sqrt(discriminant))/definition.crossbranch_gravity
	if seconds<=0.0 or seconds>definition.crossbranch_max_flight_seconds: return {}
	var vx := (end.x-start.x)/seconds
	var half := definition.collision_size*0.5
	var sweep := Rect2(start-half,definition.collision_size)
	var previous := start
	var steps := ceili(seconds*60.0)
	for tick: int in range(1,steps+1):
		var elapsed := minf(float(tick)/60.0,seconds)
		var at := start+Vector2(vx*elapsed,vy*elapsed+0.5*definition.crossbranch_gravity*elapsed*elapsed)
		var segment := Rect2(previous-half,definition.collision_size).merge(Rect2(at-half,definition.collision_size))
		if not _clear(m,segment,ignore): return {}
		sweep = sweep.merge(segment)
		previous = at
	return {"sweep":sweep,"seconds":seconds}

static func _lines(row: Dictionary) -> Array:
	if row.has("web_strands"): return row.web_strands
	if row.has("line_start"): return [{"start":row.line_start,"end":row.line_end}]
	return []

static func _fixed_fruits(instance: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for id: Variant in instance.get("anchor_id_map",{}): ids.append(str(instance.anchor_id_map[id]))
	return ids

static func _district(id: String) -> int:
	var bits := id.split("_")
	return int(bits[1]) if bits.size()>2 and bits[0]=="district" and bits[1].is_valid_int() else -1

static func _instance(m: Dictionary,id: String) -> Dictionary:
	for row: Dictionary in m.get("geometry_instances",[]):
		if str(row.id)==id: return row
	return {}

static func _mapped(m: Dictionary,instance: Dictionary,id: String) -> Dictionary:
	var mapped := str(instance.get("platform_id_map",{}).get(id,""))
	return _support(m,mapped)

static func _support(m: Dictionary,id: String) -> Dictionary:
	for row: Dictionary in m.get("platforms",[]):
		if str(row.id)==id: return row
	return {}

static func _distance(point: Vector2,rect: Rect2) -> float:
	return point.distance_to(Vector2(clampf(point.x,rect.position.x,rect.end.x),clampf(point.y,rect.position.y,rect.end.y)))

static func _point(row: Array) -> Vector2: return Vector2(float(row[0]),float(row[1]))
static func _pair(point: Vector2) -> Array: return [point.x,point.y]
static func _rect(row: Array) -> Rect2: return Rect2(float(row[0]),float(row[1]),float(row[2]),float(row[3]))
static func _rect_row(rect: Rect2) -> Array: return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]
