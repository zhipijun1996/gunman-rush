extends "res://third_party/mapgen/0.1.0/module_pack/runtime/module_runtime/module_loader_revision058_v3-604c78fe2c16.gd"
## Pre-ready materialized constructor; inherited native binding remains intact.
const TERRAIN = preload("res://scripts/mapgen/materialized_terrain.gd")
var materialized_content: Dictionary = {}

func _ready() -> void:
	process_physics_priority = 1100
	add_to_group(&"foundation_module_packages")
	content = materialized_content.duplicate(true)
	var definition = preload("res://third_party/mapgen/0.1.0/module_pack/runtime/module_runtime/ideas_definition_v1-d97d761201bf.gd").new()
	var result: Dictionary = TERRAIN.build(self, content, definition, true, false)
	if not result.ok:
		setup_error = str(result.reason)
		return
	module = result.module
