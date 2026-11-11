class_name WorldModuleTerrain
extends Node2D
## Presentation observes committed arena geometry; physics stays with PlatformingModule.
var module: PlatformingModule
var terrain: UnderworldTerrain
var surfaces: Array[Rect2] = []

func _ready() -> void:
	module = get_parent() as PlatformingModule
	module.set_meta("underworld_formal_style", true)
	_refresh()

func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	var current: Array[Rect2] = []
	for i: int in module.definition.platforms.size():
		if i not in module.definition.one_way_platform_indices:
			current.append(module.definition.platforms[i])
	if terrain != null and current == surfaces: return
	var replacement := UnderworldTerrain.build(current)
	if replacement == null:
		push_error("Formal arena terrain could not render its committed geometry")
		return
	if terrain != null: terrain.free()
	surfaces = current
	terrain = replacement
	terrain.position.y = -4
	add_child(terrain)
	module.terrain_candidate_preview = true
	module.queue_redraw()
