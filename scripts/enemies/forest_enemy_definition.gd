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

@export var bark_shield_half_angle_degrees := 55.0
@export var bark_rest_seconds := 1.8
@export var swing_period_seconds := 4.8
@export var swing_rise := 70.0

# Cross-branch candidate values have one actual Resource consumer.
@export var crossbranch_rest_seconds := 1.8
@export var crossbranch_settle_seconds := 0.35
@export var crossbranch_gravity := 620.0
@export var crossbranch_rise_velocity := -540.0
@export var crossbranch_fall_velocity := -220.0
@export var crossbranch_max_flight_seconds := 2.5

func is_valid() -> bool:
	# Base validates only its own behavior registry. Keep its contract untouched.
	if behavior_id not in [&"forest_thread_spider",&"forest_crossbranch",&"forest_bark_beetle",&"forest_swing_pod"]: return false
	if stable_id.is_empty() or definition_version < 1 or faction.is_empty() or health_definition == null or not health_definition.is_valid(): return false
	if not collision_size.is_finite() or collision_size.x <= 0 or collision_size.y <= 0 or initial_direction not in [-1,1]: return false
	if behavior_id in [&"forest_bark_beetle",&"forest_swing_pod"]:
		for value: float in [patrol_speed,patrol_half_width,telegraph_duration,attack_duration,recovery_duration,attack_speed,activation_range,protected_radius,bark_rest_seconds,swing_period_seconds,swing_rise,bark_shield_half_angle_degrees]:
			if not is_finite(value) or value<0:return false
		return telegraph_duration>=0.3 and recovery_duration>=0.3 and attack_duration>0 and attack_speed>0 and patrol_half_width>0 and swing_period_seconds>0 and swing_rise>0 and bark_rest_seconds>0 and bark_shield_half_angle_degrees>0 and bark_shield_half_angle_degrees<90
	if behavior_id==&"forest_crossbranch":
		for value: float in [crossbranch_rest_seconds,crossbranch_settle_seconds,crossbranch_gravity,crossbranch_max_flight_seconds,telegraph_duration,return_speed]:
			if not is_finite(value) or value<=0:return false
		return is_finite(crossbranch_rise_velocity) and crossbranch_rise_velocity<0 and is_finite(crossbranch_fall_velocity) and crossbranch_fall_velocity<0 and telegraph_duration>=0.3
	for number: float in [patrol_speed, patrol_half_width, telegraph_duration, attack_duration, recovery_duration, attack_speed, activation_range, protected_radius, rest_cooldown, line_max_length, line_radius, line_extend_seconds, line_hold_seconds, line_retract_seconds, line_damage]:
		if not is_finite(number) or number < 0: return false
	return telegraph_duration >= 0.3 and recovery_duration >= 0.3 and attack_speed > 0 and activation_range > 0 and line_max_length > 0 and line_radius > 0 and line_extend_seconds > 0 and line_hold_seconds > 0 and line_retract_seconds > 0 and line_damage > 0
