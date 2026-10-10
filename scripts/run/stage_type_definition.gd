class_name StageTypeDefinition
extends Resource

@export var type_id: StringName
@export var definition_version := 1
@export var display_name := ""
@export var icon_id: StringName
@export var completion_rule: StringName
@export var completion_component: StageCompletionRule

func rule(ordinary_open := false) -> StageCompletionRule:
	if ordinary_open and type_id != &"boss":
		return StageCompletionRule.builtin(&"ordinary_access")
	if completion_component != null:
		return completion_component.duplicate(true) if completion_component.is_valid() else null
	return StageCompletionRule.builtin(completion_rule)

func is_valid() -> bool:
	return not type_id.is_empty() and definition_version == 1 and not display_name.is_empty() and not icon_id.is_empty() and rule() != null

static func registry() -> Dictionary:
	var result := {}
	var rows := [
		[&"combat", "Combat", &"defeat_targets"],
		[&"shop", "Shop", &"visit_exit"],
		[&"coin_reward", "Coins", &"claim_reward"],
		[&"health_reward", "Health", &"claim_reward"],
		[&"item_reward", "Items", &"choose_item"],
		[&"boss", "Boss", &"defeat_boss"],
	]
	for row: Array in rows:
		var definition := StageTypeDefinition.new()
		definition.type_id = row[0]
		definition.display_name = row[1]
		definition.icon_id = row[0]
		definition.completion_rule = row[2]
		definition.completion_component = StageCompletionRule.builtin(row[2])
		result[definition.type_id] = definition
	return result
