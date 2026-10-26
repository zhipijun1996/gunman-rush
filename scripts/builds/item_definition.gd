class_name ItemDefinition
extends Resource

enum Rarity { BLUE, PURPLE, GOLD }
enum DuplicatePolicy { REJECT, STACK }
@export var stable_id: StringName
@export var definition_version := 1
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
	for modifier: BuildModifier in modifiers:
		if modifier == null or not modifier.is_valid():
			return false
	var effect_ids: Array[StringName] = []
	for effect: ItemEffectComponent in effect_components:
		if effect == null or not effect.is_valid() or effect.effect_id in effect_ids or (effect.effect_id == &"stats" and not modifiers.is_empty()): return false
		effect_ids.append(effect.effect_id)
	return true

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
	return JSON.stringify([stable_id, definition_version, rarity, gear_cost, duplicate_policy, stack_limit, equip_limit, tags, exclusive_tags, required_tags, required_capabilities, required_weapon_id, appearance_weight, components, effects])
