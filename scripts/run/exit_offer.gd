class_name ExitOffer
extends RefCounted

var exit_id: StringName
var source_stage_id: StringName
var next_stage_index := 0
var next_stage_type_id: StringName
var icon_id: StringName
var label := ""
var route_version := 1

func to_data() -> Dictionary:
	return {"exit_id": String(exit_id), "source_stage_id": String(source_stage_id), "next_stage_index": next_stage_index, "next_stage_type_id": String(next_stage_type_id), "icon_id": String(icon_id), "label": label, "route_version": route_version}

func copy() -> ExitOffer:
	var value := ExitOffer.new()
	value.exit_id = exit_id
	value.source_stage_id = source_stage_id
	value.next_stage_index = next_stage_index
	value.next_stage_type_id = next_stage_type_id
	value.icon_id = icon_id
	value.label = label
	return value
