class_name ItemDefinition
extends Resource

enum Rarity { BLUE, PURPLE, GOLD }
enum DuplicatePolicy { REJECT, STACK }
@export var stable_id: StringName
@export var definition_version := 1
@export var catalog_version := 0
@export var max_level := 1
@export var shop_price := 0
@export var effect_parameters: Dictionary = {}
@export var parameter_contract: Dictionary = {}
@export var display_name := ""
@export var icon_key: StringName
@export_multiline var description := ""
@export var rarity: Rarity = Rarity.BLUE
@export_range(1, 5, 1) var gear_cost := 1
@export var modifiers: Array[BuildModifier] = []
@export var effect_components: Array[ItemEffectComponent] = []
# Zero follows stack_limit; a positive value further limits simultaneous copies.
@export var equip_limit := 0
@export var required_tags: Array[StringName] = []
@export var required_capabilities: Array[StringName] = []
@export var required_weapon_id: StringName
@export var duplicate_policy: DuplicatePolicy = DuplicatePolicy.REJECT
@export var stack_limit := 1
@export var tags: Array[StringName] = []
@export var exclusive_tags: Array[StringName] = []
@export var appearance_weight := 1.0

func is_valid() -> bool:
	if stable_id.is_empty() or definition_version < 1 or rarity < 0 or rarity > Rarity.GOLD or stack_limit < 1 or duplicate_policy < DuplicatePolicy.REJECT or duplicate_policy > DuplicatePolicy.STACK or not is_finite(appearance_weight) or appearance_weight < 0.0 or gear_cost < 1 or gear_cost > 5 or equip_limit < 0 or (modifiers.is_empty() and effect_components.is_empty()):
		return false
	if catalog_version < 0 or max_level < 1 or max_level > 3 or shop_price < 0: return false
	if catalog_version > 0:
		if catalog_version != 5 or max_level not in [1, 3] or shop_price <= 0 or effect_parameters.is_empty() or not ItemEffectComponent.valid_parameter_value(effect_parameters): return false
		for key: Variant in effect_parameters:
			if not _valid_v5_parameter(String(key), effect_parameters[key]): return false
			if String(key).ends_with("_by_level"):
				if not effect_parameters[key] is Array or effect_parameters[key].size() != max_level or effect_parameters.has(String(key).trim_suffix("_by_level")): return false
		if not _valid_parameter_contract(): return false
	for modifier: BuildModifier in modifiers:
		if modifier == null or not modifier.is_valid():
			return false
	var effect_ids: Array[StringName] = []
	for effect: ItemEffectComponent in effect_components:
		if effect == null or not effect.is_valid() or effect.effect_id in effect_ids or (effect.effect_id == &"stats" and not modifiers.is_empty()): return false
		effect_ids.append(effect.effect_id)
	return true

func _valid_parameter_contract() -> bool:
	for field: String in ["required_keys", "positive_keys", "integer_keys", "zero_allowed_keys"]:
		if not parameter_contract.get(field) is Array: return false
	if not parameter_contract.get("text_modes") is Dictionary or parameter_contract.get("reject_unknown_keys") != true or not parameter_contract.get("schema_source_sha256") is String or parameter_contract.schema_source_sha256.length() != 64: return false
	var required: Array = parameter_contract.required_keys
	if required.size() != effect_parameters.size(): return false
	var seen: Array[String] = []
	for key: Variant in required:
		if not key is String or key in seen or not effect_parameters.has(key): return false
		seen.append(key)
	var classified: Array[String] = []
	for group: Array in [parameter_contract.positive_keys, parameter_contract.zero_allowed_keys, parameter_contract.text_modes.keys()]:
		for key: Variant in group:
			if not key is String or key not in required or key in classified: return false
			classified.append(key)
	if classified.size() != required.size(): return false
	var integer_seen: Array[String] = []
	for key: Variant in parameter_contract.integer_keys:
		if not key is String or key not in required or key in parameter_contract.text_modes or key in integer_seen: return false
		integer_seen.append(key)
	for key: String in seen:
		var value: Variant = effect_parameters[key]
		if key in parameter_contract.text_modes:
			var modes: Variant = parameter_contract.text_modes[key]
			if not modes is Array or modes.is_empty() or not value is String or value.is_empty(): return false
			var parts: PackedStringArray = value.split("|") if key == "resource_pickup_mask" else PackedStringArray([value])
			for part: String in parts:
				if part not in modes: return false
			continue
		var values: Array = value if key.ends_with("_by_level") else [value]
		for number: Variant in values:
			if not (number is float or number is int) or not is_finite(float(number)) or float(number) < 0: return false
			if key in parameter_contract.positive_keys and float(number) <= 0: return false
			if key in integer_seen and float(number) != floor(float(number)): return false
	return true

static func _valid_v5_parameter(key: String, value: Variant) -> bool:
	if not key.is_valid_identifier(): return false
	if key in ["weapon_family", "exclude_weapon_family"]: return value is String and value == "BOMB"
	if key == "mode": return value is String and value == "THROW_ONLY"
	if key == "resource_pickup_mask":
		if not value is String or value.is_empty(): return false
		for resource: String in value.split("|"):
			if resource not in ["coin", "meta_note", "health_pickup", "energy_pickup"]: return false
		return true
	if key.ends_with("_by_level"):
		if not value is Array: return false
		for entry: Variant in value:
			if not (entry is int or entry is float) or not is_finite(float(entry)) or float(entry) < 0: return false
		return true
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0

func parameters_for_level(level: int) -> Dictionary:
	if level < 1 or level > max_level: return {}
	var result: Dictionary = {}
	for key: Variant in effect_parameters:
		var name := String(key)
		var value: Variant = effect_parameters[key]
		if name.ends_with("_by_level"):
			if not value is Array or value.size() < level: return {}
			name = name.trim_suffix("_by_level")
			value = value[level - 1]
		result[name] = value.duplicate(true) if value is Array or value is Dictionary else value
	return result

func stat_modifiers() -> Array[BuildModifier]:
	var result: Array[BuildModifier] = []
	result.append_array(modifiers)
	for effect: ItemEffectComponent in effect_components:
		result.append_array(effect.modifiers)
	return result

func maximum_equipped() -> int:
	return stack_limit if equip_limit == 0 else mini(stack_limit, equip_limit)

func fingerprint() -> String:
	var effects: Array = []
	for modifier: BuildModifier in stat_modifiers():
		effects.append([modifier.stat_id, modifier.operation, modifier.value, modifier.priority])
	var components: Array = []
	for component: ItemEffectComponent in effect_components: components.append(component.fingerprint())
	return JSON.stringify([stable_id, definition_version, rarity, gear_cost, duplicate_policy, stack_limit, equip_limit, tags, exclusive_tags, required_tags, required_capabilities, required_weapon_id, appearance_weight, components, effects, catalog_version, max_level, shop_price, effect_parameters, parameter_contract])
