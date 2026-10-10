class_name RandomStageAssembler
extends Node2D

var modules: Array[PlatformingModule] = []
var manifest: Dictionary = {}
var bounds := Rect2()

# Consumer must call once after adding this node to tree. Replay never draws RNG.
func build(recorded: Dictionary, tuning: PlayerTuning) -> Dictionary:
	if not is_inside_tree() or not modules.is_empty():
		return {"ok": false, "error": "Assembler must be in tree and empty"}
	var generator := RandomStageGenerator.new()
	var checked := generator.validate_manifest(recorded, tuning)
	if not checked.ok:
		return checked
	manifest = recorded.duplicate(true)
	bounds = Rect2(manifest.world_bounds[0], manifest.world_bounds[1], manifest.world_bounds[2], manifest.world_bounds[3])
	for node: Dictionary in manifest.nodes:
		var module := generator.scene_for(node.module_id).instantiate() as PlatformingModule
		module.name = node.id
		module.authoring_debug = false
		module.position = Vector2(node.offset[0], node.offset[1])
		module.definition = module.definition.duplicate(true) as PlatformingModuleDefinition
		for phase: Dictionary in node.initial_phases:
			for saw: ModuleSawDefinition in module.definition.saws:
				if str(saw.source_id) == phase.id:
					saw.initial_phase = phase.phase
			for ferry: ModuleMovingPlatformDefinition in module.definition.ferries:
				if str(ferry.platform_id) == phase.id:
					ferry.initial_phase = phase.phase
		modules.append(module)
		add_child(module)
	return {"ok": true, "error": ""}

func setup_damage(controller: PlayerController, policy: FrameDamagePolicy, lifetime: DemoLifetime) -> void:
	for module: PlatformingModule in modules:
		module.setup_damage(controller, policy, lifetime)

func world_entry() -> Vector2:
	return modules.front().world_entry() if not modules.is_empty() else Vector2.ZERO

func world_exit() -> Vector2:
	return modules.back().world_exit() if not modules.is_empty() else Vector2.ZERO

func world_anchors() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for module: PlatformingModule in modules:
		result.append_array(module.world_anchors())
	return result

func world_dangers() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for module: PlatformingModule in modules:
		result.append_array(module.world_dangers())
	return result

func world_static_dangers() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for module: PlatformingModule in modules:
		result.append_array(module.world_static_dangers())
	return result

func module_index_at(point: Vector2) -> int:
	for index: int in modules.size():
		var module := modules[index]
		if module.definition.world_bounds.has_point(module.to_local(point)):
			return index
	return -1
