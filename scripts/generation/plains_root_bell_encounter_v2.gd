class_name PlainsRootBellEncounterV2
extends RefCounted
## Explicit physical-fairness policy; v1 graph-redundancy policy is frozen.
const VERSION := "root-bell-encounter-v2"
const CONTENT_VERSION := "plains-region-v11-root-bell-v2"
# Limited runtime pool admission: only the physically piloted 620px double_gear
# class below, at most one replacement. Independent conditional preview review
# is not commercial, whole-ecology, user, audio or device acceptance.
const PRODUCTION_ADMITTED := true

static func inspect(m: Dictionary, node: Dictionary, definition_lookup: Callable) -> Dictionary:
	var reasons: Array[String] = []
	if node.get("module_id", "") != "region_connection" or not node.has("geometry"):
		return {"reasons":["not_solid_connection"]}
	var edge: Dictionary = {}
	for value: Dictionary in m.connections:
		if str(node.id) == str(value.id) + "_join": edge = value; break
	if edge.is_empty(): return {"reasons":["missing_edge"]}
	if edge.get("condition", "") != "open" or not edge.get("bidirectional", false) or edge.get("kind", "") != "horizontal": reasons.append("not_initial_two_way")
	if edge.a in [m.merchant_id,m.prep_id] or edge.b in [m.merchant_id,m.prep_id]: reasons.append("camp_or_boss_preparation")
	for tag: String in ["ferry","thorn","low_arch","tutorial","receiver"]:
		if str(edge.get("recipe", "")).contains(tag) or str(node.id).contains(tag): reasons.append("forbidden_"+tag)
	# Keep first teaching route entirely unpressured; optional discovery routes
	# are judged by their actual banks, not by whether they have a semantic name.
	var teaching: Array = m.get("topology",{}).get("semantic_routes",{}).get("short_technique",{}).get("areas",[])
	for i: int in teaching.size()-1:
		if [str(edge.a),str(edge.b)] in [[str(teaching[i]),str(teaching[i+1])],[str(teaching[i+1]),str(teaching[i])]]: reasons.append("protected_teaching_route")
	var geometry: Dictionary = node.geometry
	if geometry.get("platforms",[]).is_empty(): return {"reasons":["missing_floor"]}
	var raw: Array = geometry.platforms[0]
	var floor := Rect2(Vector2(node.offset[0]+raw[0],node.offset[1]+raw[1]),Vector2(raw[2],raw[3]))
	if floor.size.x < 560: reasons.append("solid_width_below_560")
	# Only this physically piloted class may progress; other broad banks await proof.
	if floor.size.x != 620 or edge.get("recipe", "") != "double_gear": reasons.append("unreviewed_geometry_class")
	if geometry.get("one_way",[]).has(0): reasons.append("one_way_receiver")
	if not geometry.get("ferries",[]).is_empty() or not geometry.get("saws",[]).is_empty() or not geometry.get("spikes",[]).is_empty(): reasons.append("hazard_on_bank")
	var definition := load("res://resources/enemies/plains_root_bell.tres") as EnemyDefinition
	var home := Vector2(floor.get_center().x,floor.position.y-definition.collision_size.y*.5)
	# Each side has a full supported approach/retreat span, separated from the
	# body's contact envelope and wide enough to walk out of one fixed pulse.
	var retreat := definition.pulse_size.x*1.5
	var inner := definition.collision_size.x*.5+definition.pulse_size.x*1.5
	var left := Rect2(Vector2(floor.position.x+64,floor.position.y-180),Vector2(home.x-inner-floor.position.x-64,180))
	var right := Rect2(Vector2(home.x+inner,floor.position.y-180),Vector2(floor.end.x-64-home.x-inner,180))
	if left.size.x < retreat or right.size.x < retreat: reasons.append("insufficient_two_sided_walk_retreat")
	var protected := Rect2(floor.position+Vector2(40,-190),Vector2(floor.size.x-80,190))
	for index: int in range(1,geometry.platforms.size()):
		var extra: Array = geometry.platforms[index]
		if protected.intersects(Rect2(Vector2(node.offset[0]+extra[0],node.offset[1]+extra[1]),Vector2(extra[2],extra[3]))): reasons.append("obstructed_jump_or_observation")
	for other: Dictionary in m.nodes:
		if other.id == node.id: continue
		var d: PlatformingModuleDefinition = definition_lookup.call(other)
		var offset := Vector2(other.offset[0],other.offset[1])
		for saw: ModuleSawDefinition in d.saws:
			var sweep := saw.envelope()
			sweep.position += offset
			if protected.intersects(sweep.grow(32)): reasons.append("adjacent_saw_sweep")
		for ferry: ModuleMovingPlatformDefinition in d.ferries:
			var sweep := ferry.envelope()
			sweep.position += offset
			sweep = sweep.grow(32)
			if protected.intersects(sweep): reasons.append("adjacent_ferry_sweep")
		for danger: Rect2 in d.static_dangers():
			danger.position += offset
			if protected.intersects(danger.grow(20)): reasons.append("adjacent_static_danger")
		for index: int in d.platforms.size():
			var slab := d.platforms[index]
			slab.position += offset
			if slab.intersects(protected): reasons.append("obstructed_jump_or_observation")
	return {"reasons":reasons,"floor_xywh":[floor.position.x,floor.position.y,floor.size.x,floor.size.y],"home":[home.x,home.y],"left_observation_xywh":[left.position.x,left.position.y,left.size.x,left.size.y],"right_observation_xywh":[right.position.x,right.position.y,right.size.x,right.size.y],"edge":edge.id,"recipe":edge.get("recipe", ""),"graph_redundancy_required":false}

static func apply(m: Dictionary, definition_lookup: Callable) -> Dictionary:
	var nodes: Array = m.nodes.duplicate()
	nodes.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return str(a.id)<str(b.id))
	for node: Dictionary in nodes:
		var facts := inspect(m,node,definition_lookup)
		if not facts.reasons.is_empty(): continue
		for enemy: Dictionary in m.enemies:
			if enemy.get("area", "") != node.id or not str(enemy.id).begins_with("plains/enemy/lane/"): continue
			enemy.behavior_id = "root_bell"
			enemy.patrol_radius = 0
			enemy.aerial = false
			enemy.position = facts.home
			enemy.pattern = "ground_mark_interrupt"
			enemy.escape = "walk_out_of_fixed_mark_or_jump_over_live_body; real_hp_hit_interrupts"
			return {"version":VERSION,"status":"one_candidate","replaced":1,"id":enemy.id,"module":node.id,"physical_facts":facts}
	return {"version":VERSION,"status":"no_physically_qualified_lane","replaced":0}
