class_name EnemyDefinition
extends Resource

@export var stable_id: StringName
@export var definition_version := 1
@export var health_definition: HealthDefinition
@export var faction: StringName = &"enemy"
@export var patrol_speed := 0.0
@export var patrol_half_width := 0.0
@export var initial_direction := 1
@export var collision_size := Vector2.ZERO
@export var aerial := false
@export var behavior_id: StringName = &"patrol"
@export var telegraph_duration := 0.45
@export var attack_duration := 0.2
@export var recovery_duration := 0.7
@export var attack_speed := 300.0
@export var return_speed := 100.0
@export var activation_range := 180.0
@export var dive_depth := 50.0
@export var protected_radius := 45.0
@export var projectile_speed := 240.0
@export var projectile_lifetime := 0.9
## Actor-local forward pivot and distance along the already locked aim.
## Zero defaults preserve existing center-origin projectile consumers.
@export var projectile_muzzle_pivot := Vector2.ZERO
@export var projectile_muzzle_reach := 0.0
@export var forest_dwell_seconds := 1.15
@export var forest_arc_height := 70.0
@export var forest_zone_seconds := 0.4
@export var pulse_size := Vector2(52, 36)

# Shared identity/health/body validation only. Specialized definitions retain
# their exact original timing/line/flight constraints instead of inheriting
# irrelevant projectile or base-registry restrictions.
func has_valid_identity() -> bool:
	return not stable_id.is_empty() and definition_version > 0 and not faction.is_empty() and health_definition != null and health_definition.is_valid() and collision_size.is_finite() and collision_size.x > 0.0 and collision_size.y > 0.0 and initial_direction in [-1,1]

func is_valid() -> bool:
	for value: float in [telegraph_duration, attack_duration, recovery_duration, attack_speed, return_speed, activation_range, dive_depth, protected_radius, projectile_speed, projectile_lifetime, projectile_muzzle_reach, forest_dwell_seconds, forest_arc_height, forest_zone_seconds]:
		if not is_finite(value): return false
	if not projectile_muzzle_pivot.is_finite() or projectile_muzzle_reach < 0.0: return false
	if not pulse_size.is_finite() or pulse_size.x <= 0 or pulse_size.y <= 0: return false
	return EnemyBehaviorRegistry.validation_family(behavior_id) == &"base" and EnemyBehaviorRegistry.definition_error(behavior_id,stable_id).is_empty() and forest_dwell_seconds > 0 and forest_arc_height > 0 and forest_zone_seconds > 0 and telegraph_duration >= 0.3 and attack_duration > 0 and recovery_duration >= 0.3 and attack_speed > 0 and activation_range > 0 and dive_depth >= 0 and protected_radius >= 0 and projectile_speed > 0 and projectile_lifetime > 0 and has_valid_identity() and is_finite(patrol_speed) and patrol_speed >= 0.0 and is_finite(patrol_half_width) and patrol_half_width >= 0.0
