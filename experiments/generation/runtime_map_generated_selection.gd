class_name RuntimeMapGeneratedSelection
extends RefCounted
## Pure selection of complete actual output. No solver, content edits or nodes.
const SCHEMA := "gunman-rush/runtime-map-selection/v1"

static func resolve(result: Dictionary, recipe: Dictionary, body_half: Vector2, binding_id: String = "seam") -> Dictionary:
	if result.get("status")!="PASS" or not result.get("map") is Dictionary or not result.get("content_store") is Dictionary:
		return _reject("selection requires actual completed PASS map/store")
	if not recipe.get("selection_recipe") is Dictionary or not recipe.get("spawn_rule") is Dictionary:
		return _reject("missing versioned selection/spawn recipe")
	var rule: Dictionary = recipe.selection_recipe
	if rule.get("schema")!=SCHEMA or not rule.get("root") is Dictionary:
		return _reject("unsupported selection recipe schema/root")
	if not body_half.is_finite() or body_half.x<=0.0 or body_half.y<=0.0:
		return _reject("actual host body clearance is invalid")
	var map: Dictionary = result.map
	if not map.get("instances") is Array or not map.get("connections") is Array:
		return _reject("actual map has no instance/connection arrays")
	var instances: Dictionary = {}
	for row: Variant in map.instances:
		if not row is Dictionary or not row.get("id") is String and not row.get("id") is StringName:
			return _reject("malformed actual instance identity")
		var id := str(row.id)
		if id.is_empty() or instances.has(id): return _reject("duplicate/empty actual instance identity")
		instances[id] = row
	var roots: Array[Dictionary] = []
	for id: String in instances:
		if _matches(instances[id],rule.root): roots.append(instances[id])
	if roots.size()!=1: return _reject("selection root template/version/role is absent or ambiguous")
	var root: Dictionary = roots[0]
	var chosen: Array[Dictionary] = [root]
	var edges: Array[Dictionary] = []
	match str(rule.get("kind","")):
		"ellipse_junction_chain":
			if not rule.get("junction") is Dictionary: return _reject("missing junction selector")
			var first := _neighbor(map.connections,instances,root,str(rule.get("root_port","")),str(rule.get("first_entry","")),rule.junction,str(rule.get("surface","")))
			if not first.ok: return first
			var second := _neighbor(map.connections,instances,first.instance,str(rule.get("first_exit","")),str(rule.get("second_entry","")),rule.junction,str(rule.get("surface","")))
			if not second.ok: return second
			if root.id==second.instance.id or first.instance.id==second.instance.id: return _reject("selection chain repeats an instance")
			var upper := _neighbor(map.connections,instances,first.instance,str(rule.get("upper_first","")),str(rule.get("upper_second","")),rule.junction,str(rule.get("surface","")))
			if not upper.ok: return upper
			if upper.instance.id!=second.instance.id: return _reject("upper connection resolves a different junction")
			chosen.append(first.instance)
			chosen.append(second.instance)
			edges.assign([first.edge,second.edge,upper.edge])
		"unique_mechanism":
			if rule.get("require_unmirrored",false) and (not root.get("transform") is Dictionary or root.transform.get("mirror_x")!=false):
				return _reject("mechanism requires its actual unmirrored materialized output")
			if rule.get("require_no_seals",false) and (not root.get("seals") is Array or not root.seals.is_empty()):
				return _reject("mechanism requires unchanged empty source seals")
		_:
			return _reject("unknown selection recipe kind")
	var ids: Array[String] = []
	var identities: Array[Dictionary] = []
	for row: Dictionary in chosen:
		if not row.get("content_ref") is String or not result.content_store.get(row.content_ref) is Dictionary:
			return _reject("selected actual content_ref is missing")
		var content: Dictionary = result.content_store[row.content_ref]
		if content.get("stable_id")!=row.module_id: return _reject("selected content stable_id differs from template")
		if not row.get("transform") is Dictionary or row.transform.get("content_is_materialized")!=true:
			return _reject("selected content is not already materialized")
		if not LevelContentValidation.point(row.get("origin_blocks")): return _reject("selected instance origin is invalid")
		ids.append(str(row.id))
		identities.append({"instance_id":str(row.id),"module_id":row.module_id,"content_version":row.content_version,"role":row.role,"origin_blocks":row.origin_blocks.duplicate(),"transform":row.transform.duplicate(true)})
	var actual_internal: Array[Dictionary] = []
	for edge: Variant in map.connections:
		if not edge is Dictionary or not edge.get("a") is Dictionary or not edge.get("b") is Dictionary:
			return _reject("malformed actual connection")
		if str(edge.a.get("instance_id","")) in ids and str(edge.b.get("instance_id","")) in ids: actual_internal.append(edge)
	if actual_internal.size()!=int(rule.get("expected_internal_edges",-1)) or actual_internal.size()!=edges.size():
		return _reject("selected internal topology has additional/missing edges")
	for edge: Dictionary in edges:
		if edge not in actual_internal: return _reject("selected internal topology differs from resolved port chain")
	var spawn_rule: Dictionary = recipe.spawn_rule
	var raw_index: Variant = spawn_rule.get("platform_index")
	if spawn_rule.get("kind")!="original_platform_top_center" or spawn_rule.get("instance")!="root" or not LevelContentValidation.number(raw_index) or float(raw_index)!=floorf(float(raw_index)) or float(raw_index)<0.0:
		return _reject("unsupported original-platform spawn recipe/index")
	var content: Dictionary = result.content_store[root.content_ref]
	var index := int(raw_index)
	if not content.get("platforms") is Array or index<0 or index>=content.platforms.size() or not LevelContentValidation.rectangle(content.platforms[index]):
		return _reject("spawn source platform is missing/invalid")
	if not LevelContentValidation.point(root.get("origin_blocks")): return _reject("spawn instance origin is invalid")
	var platform: Array = content.platforms[index]
	var local := Vector2(float(platform[0])+float(platform[2])/2.0,float(platform[1])-body_half.y)
	var origin := Vector2(float(root.origin_blocks[0]),float(root.origin_blocks[1]))*128.0
	var spawn := origin+local
	var bindings: Dictionary = recipe.duplicate(true)
	bindings.selected_instances = ids.duplicate()
	bindings.spawns = {}
	bindings.spawns[binding_id] = [spawn.x,spawn.y]
	bindings["selection_resolution"] = {"schema":SCHEMA,"generation_input_fingerprint":result.get("request_fingerprint"),"instances":identities,"internal_connections":actual_internal.duplicate(true),"root_instance_id":str(root.id),"spawn_platform_index":index,"spawn_body_half":[body_half.x,body_half.y],"spawn_local":[local.x,local.y],"spawn_world":[spawn.x,spawn.y]}
	return {"ok":true,"error":"","ids":ids,"spawn":spawn,"bindings":bindings}

static func _matches(row: Dictionary, selector: Dictionary) -> bool:
	return row.get("module_id")==selector.get("module_id") and row.get("content_version")==selector.get("content_version") and row.get("role")==selector.get("role")

static func _neighbor(connections: Array, instances: Dictionary, source: Dictionary, port: String, peer_port: String, selector: Dictionary, surface: String) -> Dictionary:
	if port.is_empty() or peer_port.is_empty() or surface.is_empty(): return _reject("empty selection port/surface rule")
	var found: Array[Dictionary] = []
	for edge: Variant in connections:
		if not edge is Dictionary or not edge.get("a") is Dictionary or not edge.get("b") is Dictionary: return _reject("malformed selection edge")
		var peer: Dictionary = {}
		if edge.a.get("instance_id")==source.id and edge.a.get("port_id")==port: peer = edge.b
		elif edge.b.get("instance_id")==source.id and edge.b.get("port_id")==port: peer = edge.a
		if not peer.is_empty(): found.append({"edge":edge,"peer":peer})
	if found.size()!=1: return _reject("selection port neighbor is absent or ambiguous: "+port)
	var peer: Dictionary = found[0].peer
	var peer_id := str(peer.get("instance_id",""))
	if peer.get("port_id")!=peer_port or not instances.has(peer_id) or not _matches(instances[peer_id],selector) or found[0].edge.get("surface")!=surface:
		return _reject("selection peer template/version/role/port/surface differs: "+port)
	return {"ok":true,"error":"","instance":instances[peer_id],"edge":found[0].edge}

static func _reject(message: String) -> Dictionary:
	return {"ok":false,"error":message}
