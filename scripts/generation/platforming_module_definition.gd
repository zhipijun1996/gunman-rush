class_name PlatformingModuleDefinition
extends Resource

@export var module_id: StringName
@export var definition_version := 1
@export var world_bounds := Rect2(0, 0, 1280, 720)
@export var platforms: Array[Rect2] = []
@export var one_way_platform_indices: Array[int] = []
@export var danger_bounds: Array[Rect2] = []
@export var anchors: Array[Vector2] = []
# Explicit traversable paths. Branches can rejoin the main route or end in a loot pocket.
@export var main_route: Array[int] = []
@export var branch_routes: Array[PackedInt32Array] = []
@export var saws: Array[ModuleSawDefinition] = []
@export var ferries: Array[ModuleMovingPlatformDefinition] = []
@export var entry_port: PlatformingModulePort
@export var exit_port: PlatformingModulePort
@export var entry_ports: Array[PlatformingModulePort] = []
@export var exit_ports: Array[PlatformingModulePort] = []
@export var mirrored_horizontal := false
@export_range(0, 3) var platform_pressure := 0
@export_range(0, 3) var timing_pressure := 0
@export var min_jumps := 0
@export var min_air_shots := 0
@export var requires_burst := false
@export var minimum_burst_distance := 0.0
# Authored screening requirements, not a geometric or physical path proof.
@export var minimum_held_jump_height := 0.0
@export var minimum_held_jump_range := 0.0
@export var minimum_ground_speed := 0.0
@export var maximum_shot_cooldown := 0.0

func is_valid() -> bool:
	if module_id.is_empty() or definition_version <= 0 or not _valid_rect(world_bounds) or platforms.is_empty() or anchors.is_empty() or entry_port == null or exit_port == null:
		return false
	if not entry_port.is_valid() or not exit_port.is_valid() or entry_port.port_id == exit_port.port_id or entry_port.position == exit_port.position or not world_bounds.has_point(entry_port.position) or not world_bounds.has_point(exit_port.position):
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

# Arrays describe authored alternatives; canonical ports retain the currently
# selected traversal and preserve the legacy single-port module contract.
func get_entry_ports() -> Array[PlatformingModulePort]:
	if not entry_ports.is_empty():
		return entry_ports
	var result: Array[PlatformingModulePort] = []
	if entry_port != null:
		result.append(entry_port)
	return result

func get_exit_ports() -> Array[PlatformingModulePort]:
	if not exit_ports.is_empty():
		return exit_ports
	var result: Array[PlatformingModulePort] = []
	if exit_port != null:
		result.append(exit_port)
	return result

func _valid_ports() -> bool:
	var ids: Dictionary = {}
	for port: PlatformingModulePort in get_entry_ports() + get_exit_ports():
		if port == null or not port.is_valid() or not world_bounds.has_point(port.position) or ids.has(port.port_id):
			return false
		ids[port.port_id] = true
	return _contains_port(get_entry_ports(), entry_port) and _contains_port(get_exit_ports(), exit_port)

func _contains_port(ports: Array[PlatformingModulePort], active: PlatformingModulePort) -> bool:
	for port: PlatformingModulePort in ports:
		if port.port_id == active.port_id:
			return port.position == active.position and port.direction == active.direction and port.max_normal_speed == active.max_normal_speed and port.max_recoil_speed == active.max_recoil_speed and port.max_shot_cooldown == active.max_shot_cooldown and port.min_jumps == active.min_jumps and port.min_air_shots == active.min_air_shots and port.minimum_held_jump_height == active.minimum_held_jump_height and port.minimum_held_jump_range == active.minimum_held_jump_range
	return false

# Capability/configuration screening only. Real Motor traces validate reachability.
func supports(tuning: PlayerTuning) -> bool:
	if tuning == null or not is_valid() or tuning.max_jumps < min_jumps or tuning.max_air_shots < min_air_shots:
		return false
	if not entry_port.supports(tuning) or not exit_port.supports(tuning):
		return false
	if requires_burst and (tuning.recoil_mode != "shot_burst" or not is_finite(tuning.shot_burst_speed) or not is_finite(tuning.shot_burst_duration) or tuning.shot_burst_speed <= 0.0 or tuning.shot_burst_duration <= 0.0 or tuning.shot_burst_speed * tuning.shot_burst_duration < minimum_burst_distance):
		return false
	var envelope := MovementCapabilityEnvelope.snapshot(tuning)
	if envelope.is_empty() or float(envelope.held_jump_height) + 0.001 < minimum_held_jump_height or float(envelope.held_jump_range) + 0.001 < minimum_held_jump_range or tuning.ground_speed < minimum_ground_speed:
		return false
	if maximum_shot_cooldown > 0.0 and tuning.shot_cooldown > maximum_shot_cooldown:
		return false
	return true

func _standing_point(point: Vector2) -> bool:
	if not point.is_finite() or not world_bounds.has_point(point):
		return false
	var player_rect := Rect2(point - Vector2(12, 18), Vector2(24, 36))
	for danger: Rect2 in danger_bounds:
		if danger.intersects(player_rect.grow(8)):
			return false
	for saw: ModuleSawDefinition in saws:
		if saw.envelope().intersects(player_rect.grow(8)):
			return false
	for ferry: ModuleMovingPlatformDefinition in ferries:
		if ferry.envelope().intersects(player_rect.grow(8)):
			return false
	var supported := false
	for platform: Rect2 in platforms:
		if platform.intersects(player_rect):
			return false
		if absf(point.y + 18.0 - platform.position.y) <= 0.1 and point.x - 12.0 >= platform.position.x and point.x + 12.0 <= platform.end.x:
			supported = true
	return supported

func _valid_rect(rect: Rect2) -> bool:
	return rect.position.is_finite() and rect.size.is_finite() and rect.size.x > 0.0 and rect.size.y > 0.0
