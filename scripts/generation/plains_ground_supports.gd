class_name PlainsGroundSupports
extends Node2D
## Deterministic collision-bearing earth beneath eligible solid meadow slabs.
## Never fill a gap, a lower room, a hazard envelope, or a one-way platform.
const VERSION := "plains-ground-support-v1"
const EXTRA_DEPTH := 192.0
var columns: Array[Rect2] = []

# Only called after the base geometry manifest has been validated.
static func recorded_plan(manifest: Dictionary, generator: RandomStageGenerator) -> Array:
	var instances: Array[PlatformingModule] = []
	for node: Dictionary in manifest.nodes:
		var module := PlatformingModule.new()
		module.definition = generator.definition_for(node.module_id, node.mirrored, node.reverse_traversal)
		module.position = Vector2(node.offset[0], node.offset[1])
		instances.append(module)
	var values: Array = manifest.world_bounds
	var result: Array = []
	for column: Rect2 in plan(instances, Rect2(values[0], values[1], values[2], values[3])):
		result.append([column.position.x, column.position.y, column.size.x, column.size.y])
	for module: PlatformingModule in instances:
		module.free()
	return result

static func plan(modules: Array[PlatformingModule], stage_bounds: Rect2) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var bottom := stage_bounds.end.y + EXTRA_DEPTH
	for module: PlatformingModule in modules:
		var d := module.definition
		if not str(d.module_id).begins_with("plains_") and d.module_id != &"micro_board":
			continue
		for index: int in d.platforms.size():
			var slab := d.platforms[index]
			if slab.size.y <= 32.0 or index in d.one_way_platform_indices:
				continue
			var start := module.position + Vector2(slab.position.x, slab.end.y)
			if start.y >= bottom:
				continue
			var column := Rect2(start, Vector2(slab.size.x, bottom - start.y))
			result.append_array(_free_spans(column, module, modules))
	return result

static func _free_spans(column: Rect2, source: PlatformingModule, modules: Array[PlatformingModule]) -> Array[Rect2]:
	var blocked: Array[Rect2] = []
	for module: PlatformingModule in modules:
		var d := module.definition
		# Preserve the entire lower room including empty transit space. Shared
		# seam bounds can overlap 40 units; cut only that horizontal interval,
		# rather than discard the whole long ground slab.
		if module != source:
			blocked.append(Rect2(module.position + d.world_bounds.position, d.world_bounds.size))
		for platform: Rect2 in d.platforms:
			blocked.append(Rect2(module.position + platform.position, platform.size))
		for danger: Rect2 in d.danger_bounds:
			blocked.append(Rect2(module.position + danger.position, danger.size))
		for ferry: ModuleMovingPlatformDefinition in d.ferries:
			var envelope := ferry.envelope()
			blocked.append(Rect2(module.position + envelope.position, envelope.size))
		for saw: ModuleSawDefinition in d.saws:
			var envelope := saw.envelope()
			blocked.append(Rect2(module.position + envelope.position, envelope.size))
	var spans: Array[Rect2] = [column]
	for obstacle: Rect2 in blocked:
		var next: Array[Rect2] = []
		for span: Rect2 in spans:
			if not span.intersects(obstacle):
				next.append(span)
				continue
			var left := obstacle.position.x - span.position.x
			var right := span.end.x - obstacle.end.x
			if left >= 24.0:
				next.append(Rect2(span.position, Vector2(left, span.size.y)))
			if right >= 24.0:
				next.append(Rect2(obstacle.end.x, span.position.y, right, span.size.y))
		spans = next
	return spans

func install(planned: Array[Rect2]) -> void:
	columns = planned.duplicate()
	for column: Rect2 in columns:
		var body := StaticBody2D.new()
		body.position = column.get_center()
		body.collision_layer = 1
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = column.size
		shape.shape = rectangle
		body.add_child(shape)
		add_child(body)
	queue_redraw()

func _draw() -> void:
	for column: Rect2 in columns:
		# Continuation of the slab's rock; no grass cap or fake standing plane.
		PlainsTerrainSkin.draw_support(self, column)
