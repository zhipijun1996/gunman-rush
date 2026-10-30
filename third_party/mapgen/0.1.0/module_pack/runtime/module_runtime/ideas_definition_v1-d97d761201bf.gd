extends PlatformingModuleDefinition
## Same-port Foundation return: retain every original validity guard except
## the legacy requirement that entry and exit docking coordinates differ.
var allow_same_port_return:=false
func is_valid() -> bool:
	if not allow_same_port_return:return super.is_valid()
	if module_id.is_empty() or definition_version <= 0 or not _valid_rect(world_bounds) or platforms.is_empty() or anchors.is_empty() or entry_port == null or exit_port == null:
		return false
	if not entry_port.is_valid() or not exit_port.is_valid() or entry_port.port_id == exit_port.port_id or not world_bounds.has_point(entry_port.position) or not world_bounds.has_point(exit_port.position):
		return false
	if not _valid_ports():
		return false
	if platform_pressure < 0 or platform_pressure > 3 or timing_pressure < 0 or timing_pressure > 3 or min_jumps < 0 or min_air_shots < 0 or not is_finite(minimum_burst_distance) or minimum_burst_distance < 0.0:
		return false
	for value: float in [minimum_held_jump_height, minimum_held_jump_range, minimum_ground_speed, maximum_shot_cooldown]:
		if not is_finite(value) or value < 0.0:
			return false
	for index: int in one_way_platform_indices:
		if index < 0 or index >= platforms.size():
			return false
	for rect: Rect2 in platforms + danger_bounds:
		if not _valid_rect(rect) or not world_bounds.encloses(rect):
			return false
	var source_ids: Dictionary = {}
	for thorn: PlatformThornDefinition in surface_thorns:
		if thorn==null or not thorn.is_valid(platforms) or not world_bounds.encloses(thorn.danger(platforms)) or source_ids.has(thorn.surface_id): return false
		source_ids[thorn.surface_id]=true
	for saw: ModuleSawDefinition in saws:
		if saw == null or not saw.is_valid() or not world_bounds.encloses(saw.envelope()) or source_ids.has(saw.source_id):
			return false
		source_ids[saw.source_id] = true
	for ferry: ModuleMovingPlatformDefinition in ferries:
		if ferry == null or not ferry.is_valid() or not world_bounds.encloses(ferry.envelope()) or source_ids.has(ferry.platform_id):
			return false
		source_ids[ferry.platform_id] = true
	for path: Variant in [main_route] + branch_routes:
		if not path.is_empty() and path.size() < 2:
			return false
		for index: int in path:
			if index < 0 or index >= anchors.size():
				return false
	if not main_route.is_empty() and (anchors[main_route[0]] != entry_port.position or anchors[main_route[-1]] != exit_port.position):
		return false
	for branch: PackedInt32Array in branch_routes:
		if branch.is_empty() or branch[0] not in main_route:
			return false
	for anchor: Vector2 in anchors:
		if not _standing_point(anchor):
			return false
	for port: PlatformingModulePort in get_entry_ports() + get_exit_ports():
		if not _standing_point(port.position):
			return false
	return true
