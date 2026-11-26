class_name WorldContentRoomBridge
extends RefCounted
## Joins explicit room instances to imported design identities. No geometry is
## generated from map coordinates, and no unbound instance receives a fallback.

static func prepare(document: Dictionary, catalog: WorldContentCatalog) -> Dictionary:
	var room_id := str(document.get("room_id", ""))
	var context := catalog.room_context(room_id)
	if not context.get("ok", false): return context
	var refs: Variant = document.get("content_bindings", {})
	if not refs is Dictionary: return {"ok": false, "error": "content_bindings_invalid"}
	if refs.keys().any(func(key: Variant) -> bool: return key != "enemy_instances"):
		return {"ok": false, "error": "content_binding_kind_unsupported"}
	var bindings: Variant = refs.get("enemy_instances", {})
	if not bindings is Dictionary: return {"ok": false, "error": "content_enemy_bindings_invalid"}
	var amounts := {}
	var authored_gold := 0
	for instance_id: String in bindings:
		var link: Variant = bindings[instance_id]
		if not link is Dictionary or not link.get("drop_profile_id") is String or not link.get("species_id") is String:
			return {"ok": false, "error": "content_enemy_binding_invalid:" + instance_id}
		if link.keys().any(func(key: Variant) -> bool: return key not in ["species_id", "drop_profile_id"]):
			return {"ok": false, "error": "content_enemy_binding_field_unknown:" + instance_id}
		var entity: Dictionary = document.get("entities", {}).get(instance_id, {})
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
		if str(entity.get("definition_id", "")).begins_with("enemy.") and not amounts.has(instance_id):
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
	return {"ok": true, "enemy_gold": amounts, "room_context": context}
