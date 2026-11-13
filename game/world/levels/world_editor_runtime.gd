class_name WorldEditorRuntime
extends RefCounted
## Compile editor data into the existing runtime contract. Component behavior,
## physical geometry, conditions and receipts remain the game's own systems.
static func compile(base: Dictionary, project: Dictionary, selected: String, verified_behavior_hash := "") -> Dictionary:
	if project.get("schema") != 3 or not project.get("rooms") is Dictionary or not project.get("connections") is Dictionary: return {"error":"editor_project_invalid"}
	if project.get("source", {}).get("content_version") != base.get("content_version") and (verified_behavior_hash.is_empty() or project.source.get("behavior_hash") != verified_behavior_hash): return {"error":"editor_runtime_version_mismatch"}
	if not project.rooms.has(selected): return {"error":"editor_selected_room_missing"}
	var next := base.duplicate(true)
	for key: String in ["player", "demo_services", "ui_texts", "npcs", "runtime_rules", "collection_rules", "gear_milestones", "traveler_story", "start"]:
		if project.get("runtime_defaults", {}).has(key): next[key] = project.runtime_defaults[key].duplicate(true) if project.runtime_defaults[key] is Array or project.runtime_defaults[key] is Dictionary else project.runtime_defaults[key]
	next.content_version = str(project.source.content_version)
	var documents: Dictionary = {}
	var rows: Dictionary = {}
	var template: Dictionary = base.rooms.values()[0]
	for rid: String in project.rooms:
		var authored: Dictionary = project.rooms[rid]
		if not authored.get("entities") is Dictionary or not authored.get("root") is Dictionary: return {"error":"editor_room_invalid:"+rid}
		if authored.entities.is_empty() and not bool(authored.get("authored", false)):
			if rid == selected: return {"error":"editor_room_has_no_authored_content"}
			continue
		var document := {"schema":3, "room_id":rid, "root":authored.root, "entities":authored.entities}
		var checked := WorldRoomDocument.instantiate(document)
		if checked.has("error"): return {"error":rid+":"+str(checked.error)}
		checked.room.free()
		documents[rid] = document
		var row: Dictionary = base.rooms.get(rid, template).duplicate(true)
		row.room_id = rid
		row.name = str(authored.get("name", rid))
		row.region = str(authored.get("region", "P"))
		row.purpose = str(authored.get("purpose", ""))
		row["document_ref"] = ""
		row.doors = []
		row.entry_spawns = []
		row.sections = authored.get("sections", {}).values()
		row.internal_routes = []
		for route: Dictionary in authored.get("routes", {}).values():
			var adapted := route.duplicate(true)
			adapted["from_section"] = route.get("from", "main")
			adapted["to_section"] = route.get("to", "main")
			row.internal_routes.append(adapted)
		if not base.rooms.has(rid):
			for key: String in ["npcs", "interactions", "reward_refs", "clock_action_refs", "shortcut_operators", "remembered_gates", "auxiliary_spawns", "shop_stock_refs"]: row[key] = []
			row.rest = {"enabled":false}
			row.rift = {"enabled":false}
		if authored.get("camera") is Dictionary: row.camera = authored.camera.duplicate(true)
		else: row.camera = {"profile":"bounded_follow", "transition":"occluded", "zones":[], "links":[]}
		rows[rid] = row
	for rid: String in rows:
		var authored: Dictionary = project.rooms[rid]
		var row: Dictionary = rows[rid]
		for port: Dictionary in authored.get("ports", {}).values():
			var connection: Dictionary = project.connections.get(str(port.get("connection", "")), {})
			if connection.is_empty(): return {"error":"editor_port_connection_missing:"+str(port.id)}
			var is_a: bool = str(connection.a.room) == rid and str(connection.a.port) == str(port.id)
			var destination: Dictionary = connection.b if is_a else connection.a
			if not project.rooms.has(str(destination.room)): return {"error":"editor_target_room_missing"}
			var other: Dictionary = project.rooms[str(destination.room)].get("ports", {}).get(str(destination.port), {})
			if other.is_empty(): return {"error":"editor_target_port_missing"}
			var door: Dictionary = {}
			for old: Dictionary in base.rooms.get(rid, {}).get("doors", []):
				if old.id == port.id: door = old.duplicate(true)
			if door.is_empty(): door = template.doors[0].duplicate(true)
			door.id = str(port.id)
			door.room_id = rid
			door.edge_id = str(connection.id)
			door.section = str(port.get("section", "main"))
			door.target_room = str(destination.room)
			door.target_door_id = str(destination.port)
			door.target_section = str(other.get("section", "main"))
			door.target_spawn = "spawn:"+str(destination.port)
			door.target_implemented = rows.has(str(destination.room))
			door.direction = str(port.get("direction", "right"))
			door.target_direction = str(other.get("direction", "left"))
			door["front_door"] = bool(connection.get("front_door", false))
			door.requires = connection.get("requires", [[]]).duplicate(true)
			var direction := str(connection.get("direction", "both"))
			door.outbound_allowed = (direction != "b_to_a") if is_a else (direction != "a_to_b")
			door.position_candidate.local_world_units = port.position.duplicate()
			if port.get("landing") is Dictionary: door.landing_contract = port.landing.duplicate(true)
			else:
				var landing := FixedWorldProvider.point(port.position)
				match door.direction:
					"left": landing += Vector2(64, -18)
					"right": landing += Vector2(-64, -18)
					"up": landing += Vector2(0, 128)
					"down": landing += Vector2(-96, -64)
				door.landing_contract = {"section":door.section, "safe_standing_position_world_units":[landing.x, landing.y], "entry_position_world_units":[landing.x, landing.y], "platform_candidate_rect_world_units":[clampf(landing.x-64,0,maxf(0,float(authored.bounds[2])-128)),landing.y+18,128,32], "incoming_mode":"walk_into_grounded_landing", "platform_is_real_collision":false, "needs_support_validation":true}
			row.doors.append(door)
			row.entry_spawns.append({"id":"spawn:"+str(port.id), "entry_door":str(port.id), "section_id":door.section, "position_candidate_world_units":door.landing_contract.entry_position_world_units, "eventual_standing_position_world_units":door.landing_contract.safe_standing_position_world_units})
		var geometry := WorldEditorGeometry.apply(row, {"bounds":authored.bounds, "space_rects":authored.spaces})
		if geometry.has("error"): return {"error":rid+":"+str(geometry.error)}
		rows[rid] = geometry.room
	next.rooms = rows
	next.map_rooms = []
	for rid: String in rows:
		var authored: Dictionary = project.rooms[rid]
		var origin := FixedWorldProvider.point(authored.origin)
		var polygon: Array = []
		for point: Array in rows[rid].world_geometry.outline_candidate_local: polygon.append([origin.x+float(point[0]), origin.y+float(point[1])])
		next.map_rooms.append({"id":rid, "name":rows[rid].name, "region":rows[rid].region, "origin":authored.origin, "polygon":polygon, "map_centre":[origin.x+float(authored.bounds[2])*.5, origin.y+float(authored.bounds[3])*.5], "map_component":str(authored.get("layer", "world"))})
	var action_map: Dictionary = {}
	next.npcs = project.get("npcs", {}).values().duplicate(true)
	for action: Dictionary in base.actions: action_map[str(action.id)] = action.duplicate(true)
	for action: Dictionary in project.get("catalog", {}).get("actions", []):
		action_map[str(action.id)] = action.duplicate(true)
	for reward: Dictionary in project.get("rewards", {}).values():
		var action_id := str(reward.get("action_id", ""))
		if not action_map.has(action_id):
			if reward.get("action") is Dictionary: action_map[action_id] = reward.action.duplicate(true)
			elif reward.get("physical", false): return {"error":"editor_reward_definition_missing:"+str(reward.id)}
			else: continue
		var action: Dictionary = action_map[action_id]
		action.room_id = str(reward.room)
		action.section_id = str(reward.get("section", "main"))
		action.requires = reward.get("requires", action.get("requires", [[]])).duplicate(true)
		var kind := str(reward.get("type", action.get("type", "")))
		if kind != str(action.get("type", "")):
			if reward.get("goal", false) or str(action.get("type", "")) in ["ability", "equipment"] or kind in ["ability", "equipment"]:
				return {"error":"editor_unique_reward_type_immutable"}
			var prototype: Dictionary = {}
			for candidate: Dictionary in action_map.values():
				if candidate.get("type") == kind and not candidate.get("inventory_grants", {}).is_empty(): prototype = candidate; break
			if prototype.is_empty(): return {"error":"editor_reward_type_not_registered:"+kind}
			action.type = kind
			action.inventory_grants = prototype.inventory_grants.duplicate(true)
		var quantity := int(reward.get("quantity", 1))
		if quantity < 1: return {"error":"editor_reward_quantity_invalid"}
		if not reward.get("goal", false) and action.get("inventory_grants", {}).size() == 1:
			for item: String in action.inventory_grants: action.inventory_grants[item] = quantity
		elif quantity != 1: return {"error":"editor_reward_not_stackable"}
	for action: Dictionary in action_map.values():
		var npc_id := str(action.get("service_npc", ""))
		if project.get("npcs", {}).has(npc_id):
			action.room_id = str(project.npcs[npc_id].room_id)
			action.section_id = str(project.npcs[npc_id].get("section_id", "main"))
	next.actions = []
	for action: Dictionary in action_map.values():
		if rows.has(str(action.room_id)): next.actions.append(action)
	next["editor_preview"] = true
	return {"runtime":next, "documents":documents}
