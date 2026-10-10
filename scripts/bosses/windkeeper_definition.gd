class_name WindkeeperDefinition
extends BossDefinition

@export var phase_two_health := 0.67
@export var phase_three_health := 0.34
@export var stomp_speed := 180.0
@export var charge_speed := 225.0
@export var chase_speed := 110.0
@export var warning_seconds := 1.1
@export var exposed_seconds := 3.8
@export var wind_velocity := Vector2(32, -38)
@export var blade_period := 3.4

func is_valid() -> bool:
	if not super.is_valid() or not wind_velocity.is_finite() or wind_velocity.length() > 80: return false
	if not is_finite(phase_two_health) or not is_finite(phase_three_health) or not (0 < phase_three_health and phase_three_health < phase_two_health and phase_two_health < 1): return false
	for value: float in [stomp_speed,charge_speed,chase_speed,warning_seconds,exposed_seconds,blade_period]:
		if not is_finite(value) or value <= 0: return false
	return true
