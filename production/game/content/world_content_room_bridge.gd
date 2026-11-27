class_name WorldContentRoomBridge
extends RefCounted
## Joins explicit room instances to imported design identities. No geometry is
## generated from the envelope. Bound rooms use the locked local coordinate space.

static func prepare(document: Dictionary, catalog: WorldContentCatalog) -> Dictionary:
	var room_id := str(document.get("room_id", ""))
	var context := catalog.room_context(room_id)
	if not context.get("ok", false): return context
	var room_binding := catalog.binding("rooms", room_id)
	var complete: bool = room_binding.ok and room_binding.row.status == "authored"
	var doors := check_passages(document, catalog, complete)
	if not doors.ok: return doors
	var discoveries := _passage_discoveries(document, context.connections, catalog)
	if not discoveries.ok: return discoveries
	var blast:=WorldBlastPassage.prepare(document,context)
	if blast.has("error"): return {"ok":false,"error":blast.error}
	var encounter_error := WorldRoomEncounter.check_sites(document,catalog)
	if not encounter_error.is_empty(): return {"ok":false,"error":encounter_error}
	var refs: Variant = document.get("content_bindings", {})
	if not refs is Dictionary: return {"ok": false, "error": "content_bindings_invalid"}
	if refs.keys().any(func(key: Variant) -> bool: return key != "enemy_instances"):
		return {"ok": false, "error": "content_binding_kind_unsupported"}
	var bindings: Variant = refs.get("enemy_instances", {})
	if not bindings is Dictionary: return {"ok": false, "error": "content_enemy_bindings_invalid"}
	var encounter_members := {}
	for encounter: Dictionary in context.encounters:
		for id: String in document.get("sites",{}).get(encounter.id,{}).get("victory_only",[]):
			encounter_members[id] = true
	var amounts := {}
	var authored_gold := 0
	for instance_id: String in bindings:
		var link: Variant = bindings[instance_id]
		if not link is Dictionary or not link.get("drop_profile_id") is String or not link.get("species_id") is String:
			return {"ok": false, "error": "content_enemy_binding_invalid:" + instance_id}
		if link.keys().any(func(key: Variant) -> bool: return key not in ["species_id", "drop_profile_id"]):
			return {"ok": false, "error": "content_enemy_binding_field_unknown:" + instance_id}
		var entity: Dictionary = document.get("entities", {}).get(instance_id, {})
		if entity.get("definition_id")=="enemy.chime_target": return {"ok":false,"error":"practice_target_drop_not_allowed:"+instance_id}
		if not str(entity.get("definition_id", "")).begins_with("enemy."):
			return {"ok": false, "error": "content_enemy_instance_missing:" + instance_id}
		var species := catalog.bound_definition("enemy_species", link.species_id)
		if not species.get("ok", false): return species
		if species.definition_id != entity.definition_id:
			return {"ok": false, "error": "content_enemy_species_mismatch:" + instance_id}
		var drop := catalog.enemy_drop_profile(link.drop_profile_id)
		if not drop.get("ok", false): return drop
		if drop.species_id != link.species_id:
			return {"ok": false, "error": "content_enemy_drop_species_mismatch:" + instance_id}
		amounts[instance_id] = int(drop.coin_each)
		authored_gold += int(drop.coin_each)
	for instance_id: String in document.get("entities", {}):
		var entity: Dictionary = document.entities[instance_id]
		if entity.get("definition_id") == "equipment.reward":
			return {"ok": false, "error": "content_reward_binding_unsupported:" + instance_id}
		if entity.get("definition_id")=="enemy.chime_target": continue
		if str(entity.get("definition_id", "")).begins_with("enemy.") and not amounts.has(instance_id):
			if encounter_members.has(instance_id):
				# An encounter-only opponent has no ordinary species drop. Its purse
				# belongs to the locked victory transaction.
				amounts[instance_id] = 0
			else:
				return {"ok": false, "error": "content_enemy_unbound:" + instance_id}
	# Candidate groups describe a budget for review. A room author chooses the
	# actual roster, count and positions; differences never prevent the room opening.
	var planned_count := 0
	var planned_gold := 0
	for group: Dictionary in context.get("enemy_groups", []):
		for enemy: Dictionary in group.enemies:
			planned_count += int(enemy.count)
			planned_gold += int(enemy.count) * int(enemy.coin_each)
	context["enemy_budget_review"] = {
		"planning_only": true, "includes_all_candidate_groups": true,
		"planned_enemy_count": planned_count, "authored_enemy_count": amounts.size(),
		"planned_coin_total": planned_gold, "authored_coin_total": authored_gold,
		"count_delta": amounts.size() - planned_count, "coin_delta": authored_gold - planned_gold,
	}
	return {"ok": true, "enemy_gold": amounts, "room_context": context, "passage_discoveries": discoveries.sites,"blast_passages":blast.bindings}


## A grass screen can hide a mapped passage. Its local observation points earn
## the world discovery; G34 independently reveals scenery around the player.
static func _passage_discoveries(doc: Dictionary, links: Array, catalog: WorldContentCatalog) -> Dictionary:
	var sites: Variant = doc.get("sites", {})
	if not sites is Dictionary: return {"ok":false, "error":"room_sites_invalid"}
	var triggers: Array[Dictionary] = []
	for link: Dictionary in links:
		var discovery: Dictionary = link.get("discovery", {})
		if discovery.get("source_room") != doc.room_id or discovery.get("runtime_plan",{}).get("kind") != "walk_in": continue
		var id: String = discovery.event
		if not doc.get("exits", {}).has(link.id): continue
		var site: Variant = sites.get(id)
		if not site is Dictionary or not WorldRoomValidation.vector(site.get("at")) or not WorldRoomValidation.rectangle(site.get("passage_rect")):
			return {"ok":false, "error":"grass_discovery_site_required:" + id}
		var radius: Variant = site.get("approach_radius", 40.0)
		if not WorldRoomValidation.number(radius) or radius <= 0 or not site.get("other_approaches", []) is Array:
			return {"ok":false, "error":"grass_discovery_approach_invalid:" + id}
		var points := PackedVector2Array([FixedWorldProvider.point(site.at)])
		for at: Variant in site.get("other_approaches", []):
			if not WorldRoomValidation.vector(at): return {"ok":false, "error":"grass_discovery_approach_invalid:" + id}
			points.append(FixedWorldProvider.point(at))
		var event := catalog.lookup("events", id)
		if not event.ok: return event
		triggers.append({"id":id, "points":points, "radius":radius, "passage":FixedWorldProvider.rect(site.passage_rect), "event":event.row})
	return {"ok":true, "sites":triggers}

## Compare each traversable opening to the locked world independently of the
## receiving document. Two local rooms can agree with each other and both be wrong.
static func check_passages(document: Dictionary, catalog: WorldContentCatalog, complete := false) -> Dictionary:
	var exits: Variant = document.get("exits", {})
	var error := WorldRoomValidation.passage_error(exits)
	if not error.is_empty(): return {"ok":false, "error":error}
	var room_id: String = document.room_id
	var openings := {}
	var surveyed: bool = false
	var binding := catalog.binding("rooms",room_id)
	if binding.ok and binding.row.status in ["authored","placeholder"]:
		surveyed = true
		var room := catalog.lookup("rooms",room_id)
		var construction: Variant = room.get("row",{}).get("authoring",{}).get("construction")
		if not construction is Dictionary or not WorldRoomValidation.rectangle(construction.get("bounds_world")) or not construction.get("doors") is Array:
			return {"ok":false,"error":"content_room_construction_invalid:" + room_id}
		var scale: Variant = construction.get("scale")
		if not scale is Dictionary or scale.get("x") != 300 or scale.get("y") != 300 or scale.get("isotropic") != true:
			return {"ok":false,"error":"content_room_scale_mismatch:" + room_id}
		var expected_bounds := FixedWorldProvider.rect(construction.bounds_world)
		if not WorldRoomValidation.rectangle(document.get("bounds")) or not FixedWorldProvider.rect(document.bounds).is_equal_approx(expected_bounds):
			return {"ok":false,"error":"content_room_bounds_mismatch:" + room_id}
		for opening: Variant in construction.doors:
			if not opening is Dictionary: return {"ok":false,"error":"content_room_opening_invalid:" + room_id}
			if opening.get("kind") != "physical": continue
			var line: Variant = opening.get("opening_world")
			if not opening.get("id") is String or not line is Array or line.size()!=2 or not WorldRoomValidation.vector(line[0]) or not WorldRoomValidation.vector(line[1]):
				return {"ok":false,"error":"content_room_opening_invalid:" + room_id}
			openings[opening.id] = line
	if complete:
		for link: Dictionary in catalog.connections(room_id).rows:
			if link.connection_type == "interior" or link.get("one_way_from") == room_id:
				var site: Dictionary = document.get("sites",{}).get(link.id,{})
				if not WorldRoomValidation.vector(site.get("at")) or not FixedWorldProvider.rect(document.bounds).has_point(FixedWorldProvider.point(site.at)):
					return {"ok":false,"error":"content_door_handle_missing:" + room_id + "/" + str(link.id)}
			if link.connection_type == "physical" and not exits.has(link.id):
				return {"ok":false, "error":"content_door_missing:" + room_id + "/" + str(link.id)}
	var mouths: Array[Dictionary] = []
	for id: String in exits:
		var gate: Dictionary = exits[id]
		var expected := catalog.physical_passage(room_id, id)
		if not expected.ok:
			if expected.error == "content_door_not_physical" and not gate.has("span"): continue
			return expected
		if not gate.has("span") or FixedWorldProvider.point(gate.direction) != expected.direction:
			return {"ok":false, "error":"content_door_direction_mismatch:" + room_id + "/" + id}
		var point := FixedWorldProvider.point(gate.point)
		var landing := FixedWorldProvider.point(gate.spawn)
		if (landing - point).dot(expected.direction) >= 0:
			return {"ok":false, "error":"content_door_landing_outside:" + room_id + "/" + id}
		var seam: Dictionary = expected.seam
		var axis := 0 if seam.axis == "h" else 1
		var along := point[axis]
		if along < gate.span[0] or along > gate.span[1]:
			return {"ok":false, "error":"content_door_point_outside_span:" + room_id + "/" + id}
		if surveyed:
			if not openings.has(id): return {"ok":false,"error":"content_room_opening_missing:" + room_id + "/" + id}
			var start := FixedWorldProvider.point(openings[id][0])
			var end := FixedWorldProvider.point(openings[id][1])
			var normal_axis := 1 - axis
			if absf(point[normal_axis] - start[normal_axis]) > 0.01 or absf(float(gate.span[0]) - start[axis]) > 0.01 or absf(float(gate.span[1]) - end[axis]) > 0.01:
				return {"ok":false,"error":"content_door_opening_mismatch:" + room_id + "/" + id}
		for other: Dictionary in mouths:
			if other.direction != expected.direction: continue
			if (seam.end <= other.start and along >= other.along) or (seam.start >= other.end and along <= other.along):
				return {"ok":false, "error":"content_door_order_mismatch:" + room_id + "/" + id + "/" + str(other.id)}
		mouths.append({"id":id, "direction":expected.direction, "start":seam.start, "end":seam.end, "along":along})
	return {"ok":true}
