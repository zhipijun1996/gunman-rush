class_name BuildModifier
extends Resource

enum Operation { OVERRIDE, ADD, MULTIPLY }
@export var stat_id: StringName
@export var operation: Operation = Operation.ADD
@export var value := 0.0
@export var priority := 0
# Demo items persist for the run; timed expiry is not advertised as implemented.

func is_valid() -> bool:
	return stat_id in [&"max_jumps", &"max_air_shots", &"projectile_damage", &"shot_burst_speed", &"recoil_impulse", &"max_health"] and is_finite(value) and operation >= 0 and operation <= Operation.MULTIPLY
