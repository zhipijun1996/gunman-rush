extends "res://third_party/mapgen/0.1.0/module_pack/runtime/module_runtime/module_loader-17439d47c98c.gd"
## Pre-ready materialized constructor; inherited native binding remains intact.
const TERRAIN = preload("res://scripts/mapgen/materialized_terrain.gd")
var materialized_content: Dictionary = {}

func _ready() -> void:
	process_physics_priority = 1100
	add_to_group(&"foundation_module_packages")
	content = materialized_content.duplicate(true)
	var definition = PlatformingModuleDefinition.new()
	var result: Dictionary = TERRAIN.build(self, content, definition, false, false)
	if not result.ok:
		setup_error = str(result.reason)
		return
	module = result.module
