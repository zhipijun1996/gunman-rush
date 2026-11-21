class_name ItemEffectComponent
extends Resource
## An equipped source may supply ordinary stats or typed runtime parameters.
## Runtime parameters describe data, never executable callbacks or actor state.
enum Channel { PASSIVE, ACTIVE, WEAPON, GRAPPLE }
@export var effect_id: StringName
@export var channel: Channel = Channel.PASSIVE
@export var modifiers: Array[BuildModifier] = []
@export var parameters: Dictionary = {}

func is_valid() -> bool:
	if effect_id.is_empty() or channel < Channel.PASSIVE or channel > Channel.GRAPPLE or (modifiers.is_empty() and parameters.is_empty()): return false
	if not parameters.is_empty() and not valid_parameter_value(parameters): return false
	for modifier: BuildModifier in modifiers:
		if modifier == null or not modifier.is_valid(): return false
	return true

func fingerprint() -> Array:
	var values: Array = []
	for modifier: BuildModifier in modifiers:
		values.append([modifier.stat_id, modifier.operation, modifier.value, modifier.priority])
	return [effect_id, channel, values, parameters]

static func valid_parameter_value(value: Variant) -> bool:
	if value is float: return is_finite(value)
	if value is int or value is bool: return true
	if value is String or value is StringName: return not String(value).is_empty()
	if value is Array:
		if value.is_empty(): return false
		for entry: Variant in value:
			if not valid_parameter_value(entry): return false
		return true
	if value is Dictionary:
		if value.is_empty(): return false
		for key: Variant in value:
			if not (key is String or key is StringName) or String(key).is_empty() or not valid_parameter_value(value[key]): return false
		return true
	return false
