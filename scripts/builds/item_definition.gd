class_name ItemDefinition
extends Resource

enum Rarity { BLUE, PURPLE, GOLD }
enum DuplicatePolicy { REJECT, STACK }
@export var stable_id: StringName
@export var definition_version := 1
@export var display_name := ""
@export var rarity: Rarity = Rarity.BLUE
@export var modifiers: Array[BuildModifier] = []
@export var duplicate_policy: DuplicatePolicy = DuplicatePolicy.REJECT
@export var stack_limit := 1
@export var tags: Array[StringName] = []
@export var exclusive_tags: Array[StringName] = []
@export var appearance_weight := 1.0

func is_valid() -> bool:
	if stable_id.is_empty() or definition_version < 1 or rarity < 0 or rarity > Rarity.GOLD or stack_limit < 1 or not is_finite(appearance_weight) or appearance_weight < 0.0 or modifiers.is_empty():
		return false
	for modifier: BuildModifier in modifiers:
		if modifier == null or not modifier.is_valid():
			return false
	return true

func fingerprint() -> String:
	var effects: Array = []
	for modifier: BuildModifier in modifiers:
		effects.append([modifier.stat_id, modifier.operation, modifier.value, modifier.priority])
	return JSON.stringify([stable_id, definition_version, rarity, duplicate_policy, stack_limit, tags, exclusive_tags, appearance_weight, effects])
