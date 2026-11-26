class_name WorldBoolCondition
extends Node2D

@export var element_id := ""
@export var section_id := "main"
@export_enum("attempt","permanent") var state_scope := "attempt"
@export_enum("all","any") var operation := "all"
@export var invert := false
@export var sources: Array[Dictionary] = []
@export var links: Array[Dictionary] = []
var active := false

func evaluate(values: Dictionary) -> bool:
	var answer := operation == "all"
	for source: Dictionary in sources:
		var value: bool = values[source.source_id][source.output]
		if operation == "all" and not value: answer = false; break
		if operation == "any" and value: answer = true; break
	return not answer if invert else answer

func element_state() -> Dictionary:
	return {"active":active}

func element_restore(data: Dictionary) -> void:
	active = data.active

static func validate_configuration(p: Dictionary, _row: Dictionary, doc: Dictionary) -> String:
	if p.sources.is_empty(): return "sources:required"
	var seen := {}
	for binding: Variant in p.sources:
		if not binding is Dictionary or not binding.get("source_id") is String or not binding.get("output") is String: return "sources:invalid_binding"
		var source: Dictionary = doc.entities.get(binding.source_id,{})
		if source.is_empty(): return "sources:unknown_source"
		var ports: Dictionary = WorldElementCatalog.catalog().behaviors[source.component].outputs
		if ports.get(binding.output) != "bool": return "sources:boolean_output_required"
		if source.properties.get("state_scope") != p.state_scope or source.properties.get("section_id","main") != p.section_id: return "sources:recovery_boundary_mismatch"
		var key := str([binding.source_id,binding.output])
		if seen.has(key): return "sources:duplicate_binding"
		seen[key] = true
	return ""

static func control_dependencies(doc: Dictionary) -> Dictionary:
	var edges := {}
	for row: Dictionary in doc.entities.values():
		if row.definition_id == "internal.bool_condition":
			edges[row.id] = []
			for source: Dictionary in row.properties.sources: edges[row.id].append(source.source_id)
	return edges
