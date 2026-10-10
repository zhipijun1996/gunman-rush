class_name RandomStageAssembler
extends Node2D

var modules: Array[PlatformingModule] = []
var manifest: Dictionary = {}
var bounds := Rect2()
var _seams: Array[Rect2] = []
var _seam_anchors: Array[Vector2] = []

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
	for seam: Dictionary in manifest.seams:
		var rect := Rect2(seam.rect[0], seam.rect[1], seam.rect[2], seam.rect[3])
		_seams.append(rect)
		_seam_anchors.append(Vector2(seam.anchor[0], seam.anchor[1]))
		var body := StaticBody2D.new()
		body.name = seam.id
		body.collision_layer = 1
		body.position = rect.get_center()
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		collision.shape = shape
		body.add_child(collision)
		add_child(body)
	queue_redraw()
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
	for anchor: Vector2 in _seam_anchors:
		result.append(to_global(anchor))
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

func _draw() -> void:
	for seam: Rect2 in _seams:
		draw_rect(seam, Color("315954"))
		draw_line(seam.position, Vector2(seam.end.x, seam.position.y), Color("9ef2d5"), 3)
		draw_string(ThemeDB.fallback_font, seam.position + Vector2(32, -62), "SAFE LINK / NEXT SECTION", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("9ef2d5"))
