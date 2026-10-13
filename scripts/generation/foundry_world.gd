class_name FoundryWorld
extends Node2D
## The authoring consumer uses existing production module bodies and art.
var modules: Array[PlatformingModule] = []
var manifest: Dictionary
var bounds := Rect2()

func build(recorded: Dictionary) -> bool:
	if not modules.is_empty() or not FoundryCatalog.valid(recorded): return false
	manifest = recorded.duplicate(true)
	for node: Dictionary in manifest.nodes:
		var module := PlatformingModule.new()
		module.definition = FoundryCatalog.definition(node.module_id, int(node.phase_index))
		module.authoring_debug = false
		module.position = Vector2(node.offset[0], node.offset[1])
		add_child(module)
		modules.append(module)
		var r := Rect2(module.position + module.definition.world_bounds.position, module.definition.world_bounds.size)
		bounds = r if modules.size() == 1 else bounds.merge(r)
	return true

func entry() -> Vector2:
	return modules[0].world_entry()

func exit_point() -> Vector2:
	return modules.back().world_exit()

func static_dangers() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for m: PlatformingModule in modules: result.append_array(m.world_static_dangers())
	return result

func danger_envelopes() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for m: PlatformingModule in modules: result.append_array(m.world_dangers())
	return result

func anchors() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for m: PlatformingModule in modules: result.append_array(m.world_anchors())
	return result
