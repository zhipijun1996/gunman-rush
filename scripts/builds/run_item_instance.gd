class_name RunItemInstance
extends RefCounted
## A run-owned item snapshot. Only RunInventory creates authoritative instances.
var instance_id: StringName
var definition_id: StringName
var definition_version := 1
var source_id: StringName
var origin: StringName
var item: ItemDefinition

func copy() -> RunItemInstance:
	var result := RunItemInstance.new()
	result.instance_id = instance_id
	result.definition_id = definition_id
	result.definition_version = definition_version
	result.source_id = source_id
	result.origin = origin
	result.item = item.duplicate(true)
	return result
