extends RefCounted
## Tests use the same versioned equipment command as the paused production UI.
## Granting ownership alone deliberately never changes the actor.

static func equip_sources(build: BuildState, sources: Array[StringName]) -> bool:
	var ids: Array[StringName] = []
	for source: StringName in sources:
		var instance: RunItemInstance = build.inventory.instance_for_source(source)
		if instance == null:
			return false
		ids.append(instance.instance_id)
	return equip_ids(build, ids)

static func equip_ids(build: BuildState, ids: Array[StringName]) -> bool:
	var equipment := build.equipment
	var tree := build.controller.get_tree()
	var was_paused := tree.paused
	tree.paused = true
	var token := equipment.lifetime.token()
	var session := equipment.open_session(token)
	var accepted := bool(equipment.submit(ids, token, session, int(equipment.snapshot().revision)).accepted)
	equipment.close_session()
	tree.paused = was_paused
	return accepted

static func add_and_equip(build: BuildState, source: StringName, item: ItemDefinition) -> bool:
	if not build.add_item(source, item):
		return false
	var instance: RunItemInstance = build.inventory.instance_for_source(source)
	var ids: Array[StringName] = []
	ids.assign(build.equipment.snapshot().equipped_ids)
	if not instance.instance_id in ids:
		ids.append(instance.instance_id)
	return equip_ids(build, ids)

static func unequip_source(build: BuildState, source: StringName) -> bool:
	var instance: RunItemInstance = build.inventory.instance_for_source(source)
	if instance == null:
		return false
	var ids: Array[StringName] = []
	ids.assign(build.equipment.snapshot().equipped_ids)
	if not instance.instance_id in ids:
		return false
	ids.erase(instance.instance_id)
	return equip_ids(build, ids)

static func owned_ids(build: BuildState) -> Array[StringName]:
	var result: Array[StringName] = []
	for instance: RunItemInstance in build.inventory.instances():
		result.append(instance.definition_id)
	return result

static func equip_all(build: BuildState) -> bool:
	var ids: Array[StringName] = []
	for instance: RunItemInstance in build.inventory.instances():
		ids.append(instance.instance_id)
	return equip_ids(build, ids)
