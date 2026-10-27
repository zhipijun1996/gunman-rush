class_name ItemCatalogV5
extends RefCounted
## Data-only factory. Runtime effect consumers are owned by ItemRuntime.
## Returned definitions are always independent snapshots; callers cannot alter
## another offer, a held instance or the canonical catalog by editing a Resource.
const CONFIG_PATH := "res://config/items_v5.json"
const ACTIVE_IDS: Array[StringName] = [&"B33", &"P24", &"P25", &"P26", &"P27", &"G05", &"G14", &"G16", &"N02"]
const COMPANION_IDS: Array[StringName] = [&"P14", &"P15", &"G05", &"G19"]
const MARK_IDS: Array[StringName] = [&"P13"]
const PROJECTILE_ACTIVE_IDS: Array[StringName] = [&"P24", &"G14"]

static func all_items() -> Array[ItemDefinition]:
	var result: Array[ItemDefinition] = []
	var payload := _read_config()
	if payload.is_empty(): return result
	for row: Dictionary in payload.items:
		var item := _definition(row)
		if item == null: return []
		result.append(item)
	return result

static func get_item(id: StringName) -> ItemDefinition:
	var payload := _read_config()
	if payload.is_empty(): return null
	for row: Dictionary in payload.items:
		if StringName(row.stable_id) == id: return _definition(row)
	return null

static func _read_config() -> Dictionary:
	if not FileAccess.file_exists(CONFIG_PATH): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if not parsed is Dictionary or parsed.get("catalog_version") != 5 or not parsed.get("items") is Array or parsed.items.is_empty() or not parsed.get("deleted_ids") is Array: return {}
	var ids: Array[String] = []
	for row: Variant in parsed.items:
		if not row is Dictionary: return {}
		var id := String(row.get("stable_id", ""))
		if id.is_empty() or id in ids or id in parsed.deleted_ids: return {}
		ids.append(id)
	return parsed

static func _definition(row: Dictionary) -> ItemDefinition:
	for field: String in ["stable_id", "display_name", "rarity", "gear_cost", "shop_price", "max_level", "description", "effect_parameters", "parameter_contract"]:
		if not row.has(field): return null
	if not row.effect_parameters is Dictionary or not row.gear_cost is float and not row.gear_cost is int or not row.shop_price is float and not row.shop_price is int or not row.max_level is float and not row.max_level is int: return null
	if float(row.gear_cost) != floor(float(row.gear_cost)) or float(row.shop_price) != floor(float(row.shop_price)) or float(row.max_level) != floor(float(row.max_level)): return null
	var rarity_names := {"BLUE": ItemDefinition.Rarity.BLUE, "PURPLE": ItemDefinition.Rarity.PURPLE, "GOLD": ItemDefinition.Rarity.GOLD}
	if not rarity_names.has(row.rarity): return null
	var item := ItemDefinition.new()
	item.stable_id = StringName(row.stable_id)
	item.definition_version = 5
	item.catalog_version = 5
	item.display_name = row.display_name
	item.rarity = rarity_names[row.rarity]
	item.gear_cost = int(row.gear_cost)
	item.shop_price = int(row.shop_price)
	item.max_level = int(row.max_level)
	item.effect_parameters = row.effect_parameters.duplicate(true)
	if not row.parameter_contract is Dictionary: return null
	item.parameter_contract = row.parameter_contract.duplicate(true)
	item.description = row.description
	item.stack_limit = 1
	item.equip_limit = 1
	item.duplicate_policy = ItemDefinition.DuplicatePolicy.STACK if item.max_level > 1 else ItemDefinition.DuplicatePolicy.REJECT
	item.tags.assign([&"item_v5"])
	if item.stable_id in ACTIVE_IDS: item.tags.append(&"active")
	if item.stable_id in COMPANION_IDS: item.tags.append(&"companion")
	if item.stable_id in MARK_IDS: item.tags.append(&"mark")
	if item.stable_id in PROJECTILE_ACTIVE_IDS: item.tags.append(&"projectile_active")
	if item.stable_id == &"G15": item.required_tags.assign([&"projectile_active"])
	if item.stable_id == &"G08": item.required_tags.assign([&"companion", &"mark"])
	if item.stable_id in [&"B19", &"B20", &"B21", &"P13"]: item.required_capabilities.assign([&"grapple"])
	if item.stable_id == &"B30":
		item.tags.append(&"fragile_health"); item.exclusive_tags.append(&"immortal_health")
	if item.stable_id == &"G11":
		item.tags.append(&"immortal_health"); item.exclusive_tags.append(&"fragile_health")
	if item.stable_id == &"B16":
		item.tags.append(&"fragile_purse"); item.exclusive_tags.append(&"immortal_purse")
	if item.stable_id == &"G10":
		item.tags.append(&"immortal_purse"); item.exclusive_tags.append(&"fragile_purse")
	item.icon_key = _icon_key(item.stable_id)
	var component := ItemEffectComponent.new()
	component.effect_id = item.stable_id
	component.parameters = item.effect_parameters.duplicate(true)
	component.channel = ItemEffectComponent.Channel.ACTIVE if item.stable_id in ACTIVE_IDS else ItemEffectComponent.Channel.GRAPPLE if item.stable_id in [&"B19", &"B20", &"B21", &"P13"] else ItemEffectComponent.Channel.PASSIVE
	item.effect_components.assign([component])
	return item if item.is_valid() else null

static func _icon_key(id: StringName) -> StringName:
	if id in [&"B11", &"B13", &"B14", &"B15", &"B27", &"B30", &"B32", &"P18", &"P20", &"P26", &"P27", &"G02", &"G03", &"G04", &"G11", &"N02"]: return &"heart"
	if id in [&"B01", &"B16", &"B20", &"P39", &"G10", &"G12"]: return &"map"
	if id in [&"B04", &"B06", &"B09", &"B18", &"B26", &"P02", &"P06", &"G07", &"N01"]: return &"energy"
	if id in COMPANION_IDS or id in [&"G08", &"P16"]: return &"coil"
	if id in [&"B07", &"B08", &"B23", &"B28", &"P12"]: return &"boots"
	if id in [&"B19", &"B21", &"P13", &"P29"]: return &"grip"
	return &"barrel"
