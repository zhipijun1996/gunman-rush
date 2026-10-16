class_name ThornForestDefinition
extends BossDefinition
@export var display_name := "荆棘守卫 / THORN GUARDIAN"
@export var queen := false
@export var intro_seconds := 1.6
@export var repeat_intro_seconds := 0.5
@export var observation_seconds := 0.9
@export var exposed_seconds := 2.8
@export var phase_warning_seconds := 1.2
@export var phase_three_health := 0.3
@export var seed_flight_seconds := 0.85
@export var seed_arc_height := 110.0
@export var seed_zone_seconds := 0.45
@export var seed_zone_size := Vector2(90, 34)
@export var side_direction_dot := 0.15
func is_valid() -> bool:
	if not super.is_valid(): return false
	for value: float in [intro_seconds, repeat_intro_seconds, observation_seconds, exposed_seconds, phase_warning_seconds, seed_flight_seconds, seed_arc_height, seed_zone_seconds]:
		if not is_finite(value) or value <= 0: return false
	return seed_zone_size.is_finite() and seed_zone_size.x > 0 and seed_zone_size.y > 0 and phase_three_health > 0 and phase_three_health < phase_two_threshold and side_direction_dot > 0 and side_direction_dot < 1
