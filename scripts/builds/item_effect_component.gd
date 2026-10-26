class_name ItemEffectComponent
extends Resource
## Typed source contract for future effect consumers. This iteration executes stat
## modifiers only; active skills, weapon behaviours and grapple actions are not added.
enum Channel { PASSIVE, ACTIVE, WEAPON, GRAPPLE }
@export var effect_id: StringName
@export var channel: Channel = Channel.PASSIVE
@export var modifiers: Array[BuildModifier] = []

func is_valid() -> bool:
	if effect_id.is_empty() or channel < Channel.PASSIVE or channel > Channel.GRAPPLE or modifiers.is_empty(): return false
	for modifier: BuildModifier in modifiers:
		if modifier == null or not modifier.is_valid(): return false
	return true

func fingerprint() -> Array:
	var values: Array = []
	for modifier: BuildModifier in modifiers:
		values.append([modifier.stat_id, modifier.operation, modifier.value, modifier.priority])
	return [effect_id, channel, values]
