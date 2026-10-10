class_name HealthDefinition
extends Resource

@export var resource_id: StringName
@export var definition_version := 1
@export var max_health := 0.0
@export var initial_current := 0.0

func is_valid() -> bool:
	return not resource_id.is_empty() and definition_version > 0 and is_finite(max_health) and max_health > 0.0 and is_finite(initial_current) and initial_current >= 0.0 and initial_current <= max_health
