class_name ItemCatalogV5
extends RefCounted
## Workbook output stays immutable; authoring metadata/patches are separate data.
## Every call returns independent Resources, never mutable catalog authority.
const CONFIG_PATH := "res://config/items_v5.json"
const AUTHORING_PATH := "res://config/item_v5_authoring.json"
const STATIC_PARAMETERS := ["max_hp_add", "max_hp_multiplier", "ground_recoil_multiplier", "coyote_time_add_s", "focus_stamina_drain_multiplier", "focus_stamina_recovery_multiplier"]
const OVERRIDE_FIELDS := ["display_name", "description", "rarity", "gear_cost", "shop_price", "max_level", "definition_version", "effect_parameters", "runtime_metadata"]
const METADATA_FIELDS := ["tags", "required_tags", "required_capabilities", "exclusive_tags", "icon_key", "channel", "appearance_weight", "required_weapon_id"]
static var _cached_signature := ""
static var _cached_payload: Dictionary = {}

static func all_items() -> Array[ItemDefinition]:
	return _definitions(_read_config())

static func get_item(id: StringName) -> ItemDefinition:
	var payload := _read_config()
	if payload.is_empty(): return null
	for row: Dictionary in payload.items:
		if StringName(row.stable_id) == id: return _definition(row)
	return null

# The same validation/composition path powers the production loader and fixtures.
# Inputs are detached before edits; malformed patches never yield a partial list.
static func from_payload(base: Dictionary, authoring: Dictionary) -> Array[ItemDefinition]:
	return _definitions(compose_catalog(base, authoring))

static func _definitions(payload: Dictionary) -> Array[ItemDefinition]:
	var result: Array[ItemDefinition] = []
	if payload.is_empty(): return result
	for row: Dictionary in payload.items:
		var item := _definition(row)
		if item == null: return []
		result.append(item)
	return result

static func _read_config() -> Dictionary:
	if not FileAccess.file_exists(CONFIG_PATH) or not FileAccess.file_exists(AUTHORING_PATH): return {}
	var signature := FileAccess.get_sha256(CONFIG_PATH) + FileAccess.get_sha256(AUTHORING_PATH)
	if signature == _cached_signature: return _cached_payload
	var base: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	var authoring: Variant = JSON.parse_string(FileAccess.get_file_as_string(AUTHORING_PATH))
	var composed: Dictionary = compose_catalog(base, authoring) if base is Dictionary and authoring is Dictionary else {}
	# Atomic file replacement is supported; a concurrent change cannot mix versions.
	if signature != FileAccess.get_sha256(CONFIG_PATH) + FileAccess.get_sha256(AUTHORING_PATH): return {}
	_cached_signature = signature
	_cached_payload = composed
	return _cached_payload

static func compose_catalog(base: Dictionary, authoring: Dictionary) -> Dictionary:
	if base.get("catalog_version") != 5 or not base.get("items") is Array or base.items.is_empty() or not base.get("deleted_ids") is Array: return {}
	if authoring.size() != 5 or not _whole(authoring.get("schema_version"),1,1) or not authoring.get("metadata") is Dictionary or not authoring.get("overrides") is Dictionary or not authoring.get("additions") is Array or not authoring.get("disabled_ids") is Array: return {}
	if not _identifier_list(base.deleted_ids) or not _identifier_list(authoring.disabled_ids): return {}
	var result := base.duplicate(true)
	var ids: Dictionary = {}
	var base_ids: Array[String] = []
	for row: Variant in result.items:
		if not row is Dictionary or not _valid_id(row.get("stable_id")): return {}
		var id: String = row.stable_id
		if ids.has(id) or id in base.deleted_ids or not authoring.metadata.has(id) or not authoring.metadata[id] is Dictionary: return {}
		ids[id] = row
		base_ids.append(id)
		row.runtime_metadata = authoring.metadata[id].duplicate(true)
	if authoring.metadata.size() != base_ids.size(): return {}
	for id: Variant in authoring.metadata:
		if not id is String or id not in base_ids: return {}
	var additions: Array[String] = []
	for value: Variant in authoring.additions:
		if not value is Dictionary or not _valid_id(value.get("stable_id")): return {}
		var id: String = value.stable_id
		if ids.has(id) or id in base.deleted_ids: return {}
		var row: Dictionary = value.duplicate(true)
		ids[id] = row
		additions.append(id)
		result.items.append(row)
	for id: Variant in authoring.overrides:
		if not id is String or not ids.has(id) or not authoring.overrides[id] is Dictionary or authoring.overrides[id].is_empty(): return {}
		var patch: Dictionary = authoring.overrides[id]
		var row: Dictionary = ids[id]
		if not row.get("runtime_metadata") is Dictionary: return {}
		var implemented_roles: Dictionary = row.runtime_metadata.duplicate(true)
		for key: Variant in patch:
			if not key is String or key not in OVERRIDE_FIELDS: return {}
			if key == "effect_parameters" or key == "runtime_metadata":
				if not patch[key] is Dictionary or patch[key].is_empty() or not row.get(key) is Dictionary: return {}
				for field: Variant in patch[key]:
					if not field is String or (key == "effect_parameters" and not row[key].has(field)): return {}
					row[key][field] = _copy(patch[key][field])
			else:
				row[key] = _copy(patch[key])
		if not _same_implemented_roles(implemented_roles,row.runtime_metadata): return {}
	for id: String in authoring.disabled_ids:
		if not ids.has(id) or not ids[id].get("runtime_metadata") is Dictionary: return {}
		ids[id].runtime_metadata.appearance_weight = 0.0
	for row: Dictionary in result.items:
		if row.stable_id in additions and not _static_addition(row): return {}
		if _definition(row) == null: return {}
	return result

# Metadata binds actual component roles. Designer balance patches may adjust
# requirements/presentation, but cannot invent or remove implemented mechanisms.
static func _same_implemented_roles(bound: Dictionary, patched: Dictionary) -> bool:
	if bound.get("channel") != patched.get("channel") or not bound.get("tags") is Array or not patched.get("tags") is Array: return false
	for role: String in ["active", "companion", "mark", "projectile_active"]:
		if (role in bound.tags) != (role in patched.tags): return false
	return true

static func _copy(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value

static func _valid_id(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.is_valid_identifier() and value.to_utf8_buffer().size() == value.length()

static func _identifier_list(values: Array) -> bool:
	var seen: Array[String] = []
	for value: Variant in values:
		if not _valid_id(value) or value in seen: return false
		seen.append(value)
	return true

static func _whole(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum and float(value) == floor(float(value))

static func _metadata_valid(metadata: Dictionary) -> bool:
	for key: Variant in metadata:
		if not key is String or key not in METADATA_FIELDS: return false
	for field: String in ["tags", "required_tags", "required_capabilities", "exclusive_tags"]:
		if not metadata.get(field) is Array or not _identifier_list(metadata[field]): return false
	if "item_v5" not in metadata.tags or not _valid_id(metadata.get("icon_key")) or metadata.get("channel") not in ["PASSIVE", "ACTIVE", "WEAPON", "GRAPPLE"]: return false
	var weight: Variant = metadata.get("appearance_weight")
	if not (weight is float or weight is int) or not is_finite(float(weight)) or float(weight) < 0: return false
	if metadata.has("required_weapon_id") and not (metadata.required_weapon_id is String and (metadata.required_weapon_id.is_empty() or _valid_id(metadata.required_weapon_id))): return false
	return true

static func _static_addition(row: Dictionary) -> bool:
	var allowed := ["stable_id", "display_name", "rarity", "gear_cost", "shop_price", "max_level", "description", "effect_parameters", "parameter_contract", "definition_version", "runtime_metadata"]
	for key: Variant in row:
		if not key is String or key not in allowed: return false
	if not row.get("effect_parameters") is Dictionary or row.effect_parameters.is_empty() or not row.get("runtime_metadata") is Dictionary: return false
	for key: Variant in row.effect_parameters:
		if not key is String or String(key).trim_suffix("_by_level") not in STATIC_PARAMETERS: return false
	if row.runtime_metadata.get("channel") != "PASSIVE" or not row.runtime_metadata.get("tags") is Array: return false
	for tag: Variant in row.runtime_metadata.tags:
		if tag in ["active", "companion", "mark", "projectile_active"]: return false
	return true

static func _definition(row: Dictionary) -> ItemDefinition:
	for field: String in ["stable_id", "display_name", "rarity", "gear_cost", "shop_price", "max_level", "description", "effect_parameters", "parameter_contract", "runtime_metadata"]:
		if not row.has(field): return null
	if not _valid_id(row.stable_id) or not row.display_name is String or row.display_name.strip_edges().is_empty() or not row.description is String or not row.rarity is String or not row.effect_parameters is Dictionary or not row.parameter_contract is Dictionary or not row.runtime_metadata is Dictionary: return null
	if not _whole(row.gear_cost,1,5) or not _whole(row.shop_price,1,2147483647) or not _whole(row.max_level,1,3) or not _whole(row.get("definition_version",5),1,2147483647): return null
	if not _metadata_valid(row.runtime_metadata): return null
	var rarity_names := {"BLUE": ItemDefinition.Rarity.BLUE, "PURPLE": ItemDefinition.Rarity.PURPLE, "GOLD": ItemDefinition.Rarity.GOLD}
	if not rarity_names.has(row.rarity): return null
	var metadata: Dictionary = row.runtime_metadata
	var item := ItemDefinition.new()
	item.stable_id = StringName(row.stable_id)
	item.definition_version = int(row.get("definition_version",5))
	item.catalog_version = 5
	item.display_name = row.display_name
	item.rarity = rarity_names[row.rarity]
	item.gear_cost = int(row.gear_cost)
	item.shop_price = int(row.shop_price)
	item.max_level = int(row.max_level)
	item.effect_parameters = row.effect_parameters.duplicate(true)
	item.parameter_contract = row.parameter_contract.duplicate(true)
	item.description = row.description
	item.stack_limit = 1
	item.equip_limit = 1
	item.duplicate_policy = ItemDefinition.DuplicatePolicy.STACK if item.max_level > 1 else ItemDefinition.DuplicatePolicy.REJECT
	item.tags.assign(metadata.tags)
	item.required_tags.assign(metadata.required_tags)
	item.required_capabilities.assign(metadata.required_capabilities)
	item.exclusive_tags.assign(metadata.exclusive_tags)
	item.required_weapon_id = StringName(metadata.get("required_weapon_id",""))
	item.appearance_weight = float(metadata.appearance_weight)
	item.icon_key = StringName(metadata.icon_key)
	var component := ItemEffectComponent.new()
	component.effect_id = item.stable_id
	component.parameters = item.effect_parameters.duplicate(true)
	component.channel = {"PASSIVE":ItemEffectComponent.Channel.PASSIVE,"ACTIVE":ItemEffectComponent.Channel.ACTIVE,"WEAPON":ItemEffectComponent.Channel.WEAPON,"GRAPPLE":ItemEffectComponent.Channel.GRAPPLE}[metadata.channel]
	item.effect_components.assign([component])
	return item if item.is_valid() else null
