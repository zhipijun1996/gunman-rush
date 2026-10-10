class_name PlatformingModuleDefinition
extends Resource

@export var module_id: StringName
@export var definition_version := 1
@export var world_bounds := Rect2(0, 0, 1280, 720)
@export var platforms: Array[Rect2] = []
@export var danger_bounds: Array[Rect2] = []
@export var anchors: Array[Vector2] = []
@export var saws: Array[ModuleSawDefinition] = []
@export var ferries: Array[ModuleMovingPlatformDefinition] = []
@export var entry_port: PlatformingModulePort
@export var exit_port: PlatformingModulePort
@export var min_jumps := 0
@export var min_air_shots := 0
@export var requires_burst := false
@export var minimum_burst_distance := 0.0

func is_valid() -> bool:
	if module_id.is_empty() or definition_version <= 0 or not _valid_rect(world_bounds) or platforms.is_empty() or anchors.is_empty() or entry_port == null or exit_port == null:
		return false
	if not entry_port.is_valid() or not exit_port.is_valid() or entry_port.port_id == exit_port.port_id or not world_bounds.has_point(entry_port.position) or not world_bounds.has_point(exit_port.position):
		return false
	if min_jumps < 0 or min_air_shots < 0 or not is_finite(minimum_burst_distance) or minimum_burst_distance < 0.0:
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
	for anchor: Vector2 in anchors:
		if not _standing_point(anchor):
			return false
	return _standing_point(entry_port.position) and _standing_point(exit_port.position)

# Capability/configuration screening only. Real Motor traces validate reachability.
func supports(tuning: PlayerTuning) -> bool:
	if tuning == null or not is_valid() or tuning.max_jumps < min_jumps or tuning.max_air_shots < min_air_shots:
		return false
	if tuning.max_jumps < maxi(entry_port.min_jumps, exit_port.min_jumps) or tuning.max_air_shots < maxi(entry_port.min_air_shots, exit_port.min_air_shots):
		return false
	if requires_burst and (tuning.recoil_mode != "shot_burst" or not is_finite(tuning.shot_burst_speed) or not is_finite(tuning.shot_burst_duration) or tuning.shot_burst_speed <= 0.0 or tuning.shot_burst_duration <= 0.0 or tuning.shot_burst_speed * tuning.shot_burst_duration < minimum_burst_distance):
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
