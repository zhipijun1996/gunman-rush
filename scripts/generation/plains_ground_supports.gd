class_name PlainsGroundSupports
extends Node2D
## Deterministic collision-bearing earth beneath eligible solid meadow slabs.
## Never fill a gap, a lower room, a hazard envelope, or a one-way platform.
const VERSION := "plains-ground-support-v2-continuous"
const EXTRA_DEPTH := 192.0
var columns: Array[Rect2] = []
var exposed_edges:Array=[]

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
			if index in d.one_way_platform_indices:
				continue
			var start := module.position + Vector2(slab.position.x, slab.end.y)
			if start.y >= bottom:
				continue
			var column := Rect2(start, Vector2(slab.size.x, bottom - start.y))
			result.append_array(_free_spans(column, module, modules))
	return _merge_columns(result)

static func _merge_columns(rectangles: Array[Rect2]) -> Array[Rect2]:
	var sorted := rectangles.duplicate()
	sorted.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.y < b.position.y if a.position.y != b.position.y else a.position.x < b.position.x)
	var merged: Array[Rect2] = []
	for rect: Rect2 in sorted:
		if not merged.is_empty():
			var previous := merged[-1]
			if is_equal_approx(previous.position.y, rect.position.y) and is_equal_approx(previous.end.y, rect.end.y) and rect.position.x <= previous.end.x:
				merged[-1] = Rect2(previous.position, Vector2(maxf(previous.end.x, rect.end.x) - previous.position.x, previous.size.y))
				continue
		merged.append(rect)
	return merged

static func _free_spans(column: Rect2, source: PlatformingModule, modules: Array[PlatformingModule]) -> Array[Rect2]:
	var blocked: Array[Rect2] = []
	for module: PlatformingModule in modules:
		var d := module.definition
		# Preserve the entire lower room including empty transit space. Shared
		# seam bounds can overlap 40 units; cut only that horizontal interval,
		# rather than discard the whole long ground slab.
		if module != source and _has_lower_route(d, module.position, column.position.y):
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

# Preserve the complete authored lower room, including jump/recoil airspace.
# Same-height neighbors have no lower standing plane and can share solid earth.
static func _has_lower_route(d: PlatformingModuleDefinition, offset: Vector2, underside: float) -> bool:
	for platform: Rect2 in d.platforms:
		if offset.y + platform.position.y > underside - 0.01:
			return true
	for ferry: ModuleMovingPlatformDefinition in d.ferries:
		if offset.y + ferry.envelope().end.y > underside:
			return true
	return false

static func floating_indices(module: PlatformingModule, planned: Array[Rect2]) -> Array[int]:
	var result: Array[int] = []
	for index: int in module.definition.platforms.size():
		if index in module.definition.one_way_platform_indices:
			continue
		var slab: Rect2 = module.definition.platforms[index]
		var underside := module.position + Vector2(slab.position.x, slab.end.y)
		var supported := false
		for column: Rect2 in planned:
			# A broad real attachment is visually grounded; tiny corner contact is
			# insufficient. Only exact underside contacts qualify, never distant rock.
			var overlap := minf(column.end.x, underside.x + slab.size.x) - maxf(column.position.x, underside.x)
			if is_equal_approx(column.position.y, underside.y) and overlap >= slab.size.x * 0.6:
				supported = true
				break
		if not supported:
			result.append(index)
	return result

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

func configure_edges(modules:Array[PlatformingModule])->void:
	var solids:Array[Rect2]=columns.duplicate()
	for module:PlatformingModule in modules:
		for index:int in module.definition.platforms.size():
			if index not in module.definition.one_way_platform_indices:
				var slab:Rect2=module.definition.platforms[index]
				solids.append(Rect2(module.position+slab.position,slab.size))
	exposed_edges.clear()
	for column:Rect2 in columns:exposed_edges.append(PlainsTerrainSkin.exposed_faces(column,solids))
	queue_redraw()

func _draw() -> void:
	for index:int in columns.size():
		var column:Rect2=columns[index]
		# Continuation of the slab's rock; no grass cap or fake standing plane.
		PlainsTerrainSkin.draw_support(self, column)
		if index<exposed_edges.size():PlainsCohesionArt.draw_outer_edges(self,column,exposed_edges[index])

# The region owns serialized supports. Solid slabs only: all one-way drop
# surfaces and complete lower-route volumes retain their authored airspace.
static func region_plan(manifest: Dictionary) -> Array:
	var modules: Array[PlatformingModule] = []
	for node: Dictionary in manifest.nodes:
		var module := PlatformingModule.new()
		module.definition = PlainsRegionGenerator.definition(node)
		module.position = Vector2(node.offset[0],node.offset[1])
		modules.append(module)
	var result: Array[Rect2] = []
	for module: PlatformingModule in modules:
		var d := module.definition
		if str(d.module_id).begins_with("region_deep") or str(d.module_id).begins_with("region_drop"): continue
		for index: int in d.platforms.size():
			var slab := d.platforms[index]
			if index in d.one_way_platform_indices or slab.size.x < 160 or slab.size.y < 24: continue
			var start := module.position + Vector2(slab.position.x, slab.end.y)
			var depth := 164.0
			var nearest := INF
			for area: Dictionary in manifest.areas:
				var origin := Vector2(area.position[0],area.position[1])
				var distance := origin.distance_squared_to(start)
				if distance < nearest:
					nearest = distance
					depth = 238.0 if area.get("identity","") == "windmill_plateau" else 164.0 if area.get("identity","") == "creek_well" else 112.0
			var spans := _free_spans(Rect2(start,Vector2(slab.size.x,depth)),module,modules)
			# Real reward evacuation corridors may cross otherwise empty rock.
			for edge: Dictionary in manifest.connections:
				var path: Array = edge.get("return_polyline",[])
				for step: int in maxi(0,path.size()-1):
					var a := Vector2(path[step][0],path[step][1])
					var b := Vector2(path[step+1][0],path[step+1][1])
					var corridor := Rect2(a.min(b)-Vector2(45,20),(a-b).abs()+Vector2(90,40))
					var next: Array[Rect2] = []
					for span: Rect2 in spans:
						if not span.intersects(corridor): next.append(span); continue
						if corridor.position.x-span.position.x >= 32: next.append(Rect2(span.position,Vector2(corridor.position.x-span.position.x,span.size.y)))
						if span.end.x-corridor.end.x >= 32: next.append(Rect2(Vector2(corridor.end.x,span.position.y),Vector2(span.end.x-corridor.end.x,span.size.y)))
					spans = next
			result.append_array(spans)
	var values: Array = []
	for column: Rect2 in _merge_columns(result): values.append([column.position.x,column.position.y,column.size.x,column.size.y])
	for module: PlatformingModule in modules: module.free()
	return values
