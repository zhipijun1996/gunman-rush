class_name ForestExplorationPlaceEmbedding
extends RefCounted
## Copies one authored place and its real ports into a region; never fills gaps.
const API := preload("res://scripts/generation/forest_expedition_layout.gd")
const LANGUAGE := preload("res://scripts/generation/forest_scene_language.gd")
static func install(m: Dictionary,id: String,raw: Dictionary,origin: Vector2) -> Dictionary:
	var supports: Dictionary = {}
	var anchors: Dictionary = {}
	for row: Dictionary in raw.platforms:
		var mapped := id+"__"+str(row.id)
		supports[str(row.id)] = mapped
		var rect := _rect(row.rect)
		rect.position += origin
		API._platform(m,mapped,rect,bool(row.one_way),str(row.get("scene_kind","living_bough" if row.one_way else "hollow_bark")),id,str(row.id))
	for row: Dictionary in raw.hook_anchors:
		var mapped := id+"__"+str(row.id)
		anchors[str(row.id)] = mapped
		m.hook_anchors.append({"id":mapped,"position":_pair(_point(row.position)+origin),"structure_id":id,"scene_kind":"copper_growth_ring","fruit_presentation":"rooted_fruit","fruit_role":str(row.get("fruit_role","optional")),"fruit_host_support_id":str(supports[row.host_support_id]),"fruit_stem_root":_pair(_point(row.stem_root)+origin),"fruit_route_bindings":["available:"+id]})
	var dangers: Array[int] = []
	for row: Array in raw.dangers:
		var rect := _rect(row)
		rect.position += origin
		dangers.append(m.dangers.size())
		m.dangers.append([rect.position.x,rect.position.y,rect.size.x,rect.size.y])
		m.danger_presentations.append({})
	for surface: Dictionary in raw.get("danger_surfaces",[]):
		var index: int = dangers[int(surface.danger_index)]
		var host_id := str(supports[surface.host_support_id])
		var face := str(surface.face)
		assert(face in ["up","down"])
		var hazard := _rect(m.dangers[index])
		var host: Rect2 = _rect(API._platform_by_id(m,host_id).rect)
		var y := host.position.y if face == "up" else host.end.y
		m.danger_presentations[index] = {"scene_kind":"thorn_growth","facing":face,"host_structure_id":id,"host_support_id":host_id}
		m.thorn_surfaces.append({"danger_index":index,"face":face,"hazard_rect":m.dangers[index].duplicate(),"segments":[{"support_id":host_id,"start":[hazard.position.x,y],"end":[hazard.end.x,y]}]})
	var source_path := str(raw.get("source_factory",{}).get("path","res://scripts/generation/forest_exploration_places.gd"))
	var instance := {"id":id,"factory":source_path,"geometry_version":str(raw.version),"module_id":str(raw.id),"local_geometry":raw.duplicate(true),"translation":_pair(origin),"platform_id_map":supports,"anchor_id_map":anchors,"danger_indices":dangers,"native_verified":false}
	m.geometry_instances.append(instance)
	m.scene_structure_kinds[id] = "root_hollow"
	var ports: Dictionary = {}
	var actual_areas: Dictionary = {}
	for name: String in raw.ports:
		var port: Dictionary = raw.ports[name]
		var point := _point(port.position)+origin
		var location_key := JSON.stringify([str(supports[port.support_id]),_pair(point)])
		var area := str(actual_areas.get(location_key,id+"__"+name))
		if not actual_areas.has(location_key):
			API._area(m,area,point,str(raw.get("identity",raw.id))+" / "+name,"challenge_reward" if name in ["reward","cache"] else "junction")
			actual_areas[location_key] = area
		ports[name] = {"area":area,"point":_pair(point),"support":str(supports[port.support_id])}
	var routes: Dictionary = {}
	for name: String in raw.routes:
		var source: Dictionary = raw.routes[name]
		var a: Dictionary = ports[source.from_port]
		var b: Dictionary = ports[source.to_port]
		var steps: Array = []
		for row: Dictionary in source.get("steps",[]):
			var step := row.duplicate(true)
			for key: String in ["takeoff","landing"]:
				if step.has(key): step[key] = _pair(_point(step[key])+origin)
			for key: String in ["support_id","from_support_id"]:
				if step.has(key): step[key] = str(supports[str(step[key])])
			if step.has("path"):
				for index: int in step.path.size(): step.path[index] = _pair(_point(step.path[index])+origin)
			if step.kind == "jump_gap": step.hold_to_receiver = true
			steps.append(step)
		var edge := id+"__"+name
		var path: Array = []
		for point: Array in source.get("path",[]): path.append(_pair(_point(point)+origin))
		if path.size()<2: path = [a.point.duplicate(),b.point.duplicate()]
		API._edge(m,edge,str(a.area),str(b.area),str(source.kind),path,steps)
		m.connections[-1].merge({"geometry_instance":id,"from_support_id":str(a.support),"landing_support_id":str(b.support),"support_id":str(b.support),"landing":b.point.duplicate()},true)
		if source.has("action_program"):
			# Formal drivers resolve local action names through the real instance
			# anchor map, as the retained v15/v17 consumers do.
			m.connections[-1].action_program = source.action_program.duplicate(true)
		if source.has("takeoff"): m.connections[-1].action_start = _pair(_point(source.takeoff)+origin)
		routes[name] = edge
	return {"id":id,"ports":ports,"route_ids":routes,"supports":supports,"anchors":anchors,"origin":_pair(origin)}
static func _point(pair: Array) -> Vector2: return Vector2(float(pair[0]),float(pair[1]))
static func _pair(point: Vector2) -> Array: return [point.x,point.y]
static func _rect(row: Array) -> Rect2: return Rect2(float(row[0]),float(row[1]),float(row[2]),float(row[3]))
