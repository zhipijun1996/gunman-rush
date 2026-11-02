class_name LevelModulePlacement
extends RefCounted
## Template identity and one stable placement are deliberately separate.
var instance_id := ""
var template_id: StringName
var definition: PlatformingModuleDefinition
var position := Vector2.ZERO
# Existing explicit terrain ownership transfer, empty for ordinary modules.
var terrain_ownership: Dictionary = {}
