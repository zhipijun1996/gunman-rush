class_name ForestEnemyDefinition
extends EnemyDefinition
## Spider timing/line values are consumed by its behavior, not the Player.
@export var rest_cooldown := 0.8
@export var line_max_length := 150.0
@export var line_radius := 8.0
@export var line_extend_seconds := 0.15
@export var line_hold_seconds := 0.65
@export var line_retract_seconds := 0.25
@export var line_damage := 1.0

func is_valid() -> bool:
	# Base validates only its own behavior registry. Keep its contract untouched.
	if behavior_id != &"forest_thread_spider": return false
	if stable_id.is_empty() or definition_version < 1 or faction.is_empty() or health_definition == null or not health_definition.is_valid(): return false
	if not collision_size.is_finite() or collision_size.x <= 0 or collision_size.y <= 0 or initial_direction not in [-1,1]: return false
	for number: float in [patrol_speed, patrol_half_width, telegraph_duration, attack_duration, recovery_duration, attack_speed, activation_range, protected_radius, rest_cooldown, line_max_length, line_radius, line_extend_seconds, line_hold_seconds, line_retract_seconds, line_damage]:
		if not is_finite(number) or number < 0: return false
	return telegraph_duration >= 0.3 and recovery_duration >= 0.3 and attack_speed > 0 and activation_range > 0 and line_max_length > 0 and line_radius > 0 and line_extend_seconds > 0 and line_hold_seconds > 0 and line_retract_seconds > 0 and line_damage > 0
