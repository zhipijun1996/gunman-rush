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

func is_valid() -> bool:
	return not stable_id.is_empty() and definition_version > 0 and not faction.is_empty() and health_definition != null and health_definition.is_valid() and is_finite(patrol_speed) and patrol_speed >= 0.0 and is_finite(patrol_half_width) and patrol_half_width >= 0.0 and initial_direction in [-1, 1] and collision_size.is_finite() and collision_size.x > 0.0 and collision_size.y > 0.0
