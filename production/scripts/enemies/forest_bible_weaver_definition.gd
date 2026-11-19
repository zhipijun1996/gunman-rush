class_name ForestBibleWeaverDefinition
extends ForestEnemyDefinition
## Separate opt-in identity: old ForestEnemyDefinition's finite registry remains.
func is_valid() -> bool:
	if EnemyBehaviorRegistry.validation_family(behavior_id) != &"weaver": return false
	if not has_valid_identity() or not EnemyBehaviorRegistry.definition_error(behavior_id,stable_id).is_empty(): return false
	for number: float in [patrol_speed,patrol_half_width,telegraph_duration,attack_duration,recovery_duration,attack_speed,return_speed,activation_range,protected_radius,rest_cooldown,line_max_length,line_radius,line_extend_seconds,line_hold_seconds,line_retract_seconds,line_damage]:
		if not is_finite(number) or number < 0: return false
	return patrol_speed == 0 and patrol_half_width == 0 and telegraph_duration >= 0.3 and recovery_duration >= 0.3 and attack_speed > 0 and return_speed > 0 and activation_range > 0 and line_max_length >= 8 and line_max_length <= 150 and line_radius > 0 and line_extend_seconds > 0 and line_hold_seconds > 0 and line_retract_seconds > 0 and line_damage > 0
