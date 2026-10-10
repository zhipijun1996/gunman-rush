class_name ModuleReflection
extends RefCounted

# Reflect authored geometry rather than a physics node's scale: gravity, shape
# normals and the unique PlayerMotor remain unchanged in a left-facing layout.
static func reflected_definition(source: PlatformingModuleDefinition) -> PlatformingModuleDefinition:
	if source == null:
		return null
	var result := source.duplicate(true) as PlatformingModuleDefinition
	result.resource_scene_unique_id = source.resource_scene_unique_id
	var axis_sum := source.world_bounds.position.x + source.world_bounds.end.x
	result.world_bounds = _rect(source.world_bounds, axis_sum)
	for index: int in source.platforms.size():
		result.platforms[index] = _rect(source.platforms[index], axis_sum)
	for index: int in source.danger_bounds.size():
		result.danger_bounds[index] = _rect(source.danger_bounds[index], axis_sum)
	for index: int in source.anchors.size():
		result.anchors[index] = _point(source.anchors[index], axis_sum)
	# Preserve aliases explicitly; reflecting a shared canonical port twice would
	# silently restore its original position and break multi-port docking.
	var ports: Dictionary = {}
	result.entry_port = _port(source.entry_port, axis_sum, ports)
	result.exit_port = _port(source.exit_port, axis_sum, ports)
	result.entry_ports.clear()
	for port: PlatformingModulePort in source.entry_ports:
		result.entry_ports.append(_port(port, axis_sum, ports))
	result.exit_ports.clear()
	for port: PlatformingModulePort in source.exit_ports:
		result.exit_ports.append(_port(port, axis_sum, ports))
	for index: int in result.saws.size():
		var saw := result.saws[index]
		saw.resource_scene_unique_id = source.saws[index].resource_scene_unique_id
		saw.origin = _point(saw.origin, axis_sum)
		saw.travel.x *= -1.0
	for index: int in result.ferries.size():
		var ferry := result.ferries[index]
		ferry.resource_scene_unique_id = source.ferries[index].resource_scene_unique_id
		ferry.start = _point(ferry.start, axis_sum)
		ferry.finish = _point(ferry.finish, axis_sum)
	result.mirrored_horizontal = not source.mirrored_horizontal
	return result

static func _point(value: Vector2, axis_sum: float) -> Vector2:
	return Vector2(axis_sum - value.x, value.y)

static func _rect(value: Rect2, axis_sum: float) -> Rect2:
	return Rect2(Vector2(axis_sum - value.end.x, value.position.y), value.size)

static func _port(source: PlatformingModulePort, axis_sum: float, copies: Dictionary) -> PlatformingModulePort:
	if source == null:
		return null
	var id := source.get_instance_id()
	if copies.has(id):
		return copies[id] as PlatformingModulePort
	var result := source.duplicate(true) as PlatformingModulePort
	result.resource_scene_unique_id = source.resource_scene_unique_id
	result.position = _point(source.position, axis_sum)
	result.direction.x *= -1.0
	copies[id] = result
	return result
