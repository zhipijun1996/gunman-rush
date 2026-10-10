class_name BossDefinition
extends Resource

@export var stable_id: StringName
@export var definition_version := 1
@export var health_definition: HealthDefinition
@export var collision_size := Vector2(72, 84)
@export var patrol_speed := 42.0
@export var phase_two_threshold := 0.5
@export var attack_interval := 2.0
@export var telegraph_duration := 0.65
@export var phase_two_interval_scale := 0.7
@export var projectile_speed := 250.0
@export var projectile_radius := 7.0
@export var projectile_damage := 1.0
@export var projectile_lifetime := 5.0
@export var phase_two_spread := 0.24

func is_valid() -> bool:
	if stable_id.is_empty() or definition_version < 1 or health_definition == null or not health_definition.is_valid():
		return false
	if not collision_size.is_finite() or collision_size.x <= 0.0 or collision_size.y <= 0.0:
		return false
	for number: float in [patrol_speed, attack_interval, telegraph_duration, phase_two_interval_scale, projectile_speed, projectile_radius, projectile_damage, projectile_lifetime]:
		if not is_finite(number) or number <= 0.0:
			return false
	return is_finite(phase_two_threshold) and phase_two_threshold > 0.0 and phase_two_threshold < 1.0 and is_finite(phase_two_spread) and phase_two_spread >= 0.0 and phase_two_spread <= PI / 2.0
