class_name EquipmentCatalog
extends RefCounted

const DATA = preload("res://config/equipment.json")
const REWARDS = preload("res://config/equipment_rewards.json")

static func item(id: String) -> Dictionary:
	return DATA.data.items.get(id, {})

static func parameter(id: String, level: int, key: String, fallback: float = 0) -> float:
	if level < 1: return fallback
	var value: Variant = item(id).parameters.get(key, fallback)
	if value is Array: return float(value[level - 1])
	return float(value)

static func load_used(ids: Array) -> int:
	var total := 0
	for id: String in ids: total += int(item(id).load)
	return total

static func capacity(inventory: Dictionary) -> int:
	return clampi(int(DATA.data.initial_capacity) + int(inventory.get("capacity_upgrades", 0)), int(DATA.data.initial_capacity), int(DATA.data.maximum_capacity))

static func legal_loadout(owned: Dictionary, ids: Array, limit: int) -> bool:
	var groups := {}
	var seen := {}
	for id: Variant in ids:
		if not id is String or seen.has(id) or not owned.has(id) or item(id).is_empty(): return false
		seen[id] = true
		var group: String = item(id).get("exclusive_group", "")
		if not group.is_empty():
			if groups.has(group): return false
			groups[group] = true
	return load_used(ids) <= limit

static func nonnegative(value: Variant) -> bool:
	return WorldRoomValidation.number(value) and value >= 0

static func valid_effects(effects: Dictionary) -> bool:
	for key: String in ["cooldowns","marks","dots","time","target","companions","field"]:
		if effects.has(key) and not effects[key] is Dictionary: return false
	for key: String in ["hurt_count","drone_progress","gold_fraction","epoch","refund","air_hits","guard_hp","aim_seconds","stamina","protected","guard_generation","packet_serial"]:
		if effects.has(key) and not nonnegative(effects[key]): return false
	for key: String in ["rescued","enchanted","armed","in_air"]:
		if effects.has(key) and not effects[key] is bool: return false
	var shields: Variant = effects.get("shields",[])
	if not shields is Array or shields.size() > int(DATA.data.shield_limit): return false
	for source: Variant in shields:
		if source not in ["B13","G02"]: return false
	for value: Variant in effects.get("cooldowns",{}).values():
		if not nonnegative(value): return false
	for value: Variant in effects.get("dots",{}).values():
		if not value is Dictionary: return false
		for key: String in ["due","interval","ticks","damage"]:
			if not nonnegative(value.get(key)): return false
		if value.interval <= 0 or value.ticks > parameter("B24",1,"ticks"): return false
	for target: Variant in effects.get("time",{}).values():
		if not target is Dictionary: return false
		for value: Variant in target.values():
			if not value is Dictionary or not nonnegative(value.get("remaining")) or not nonnegative(value.get("scale")): return false
	for key: Variant in effects.get("marks",{}):
		var mark: Variant = effects.marks[key]
		if not key is String or not mark is Dictionary or not nonnegative(mark.get("remaining")): return false
		if key.begins_with("echo:") and not nonnegative(mark.get("packet")): return false
		if key == "memory" and not mark.get("target") is String: return false
	var target: Dictionary = effects.get("target",{})
	if not target.is_empty() and not WorldRoomValidation.vector(target.get("point")) and not target.get("target") is String: return false
	for id: Variant in effects.get("companions",{}):
		var units: Variant = effects.companions[id]
		if not units is Array or id not in ["P14","P15","G05","G19"]: return false
		for unit: Variant in units:
			if not unit is Dictionary or not nonnegative(unit.get("next")): return false
			if id == "P15" and (not nonnegative(unit.get("base")) or not nonnegative(unit.get("life"))): return false
	if not effects.get("guard_hits",[]) is Array: return false
	var field: Dictionary = effects.get("field",{})
	for key: String in ["clock","hint_wait"]:
		if not nonnegative(field.get(key,0)): return false
	for key: String in ["anchors","rings","winds"]:
		if not field.get(key,[]) is Array: return false
		for row: Variant in field.get(key,[]):
			if not row is Dictionary or not nonnegative(row.get("life")): return false
			if key != "winds" and not WorldRoomValidation.vector(row.get("point")): return false
			if key == "rings" and not row.get("hit") is Dictionary: return false
			if key == "winds":
				if not row.get("path") is Array: return false
				for point: Variant in row.path:
					if not WorldRoomValidation.vector(point): return false
	if not field.get("rounds",[]) is Array: return false
	for shot: Variant in field.get("rounds",[]):
		if not shot is Dictionary or shot.get("id") not in ["G05","P15","P14","G19"]: return false
		if not WorldRoomValidation.vector(shot.get("point")) or not WorldRoomValidation.vector(shot.get("direction")): return false
		if not nonnegative(shot.get("damage")) or not nonnegative(shot.get("remaining")): return false
	if field.has("decoy"):
		var decoy: Variant = field.decoy
		if not decoy is Dictionary or not WorldRoomValidation.vector(decoy.get("point")) or not nonnegative(decoy.get("life")): return false
	return true
