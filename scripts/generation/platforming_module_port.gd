class_name PlatformingModulePort
extends Resource

@export var port_id: StringName
# All positions refer to the player's body centre, not feet.
@export var position := Vector2.ZERO
@export var direction := Vector2.RIGHT
@export var max_normal_speed := 330.0
@export var max_recoil_speed := 0.0
@export var max_shot_cooldown := 0.0
@export var min_jumps := 0
@export var min_air_shots := 0
@export var minimum_held_jump_height := 0.0
@export var minimum_held_jump_range := 0.0

func is_valid() -> bool:
	return not port_id.is_empty() and position.is_finite() and direction.is_finite() and direction.is_normalized() and is_finite(max_normal_speed) and max_normal_speed >= 0.0 and is_finite(max_recoil_speed) and max_recoil_speed >= 0.0 and is_finite(max_shot_cooldown) and max_shot_cooldown >= 0.0 and min_jumps >= 0 and min_air_shots >= 0 and is_finite(minimum_held_jump_height) and minimum_held_jump_height >= 0.0 and is_finite(minimum_held_jump_range) and minimum_held_jump_range >= 0.0

func supports(tuning: PlayerTuning) -> bool:
	if tuning == null or not is_valid() or min_jumps > tuning.max_jumps or min_air_shots > tuning.max_air_shots:
		return false
	var envelope := MovementCapabilityEnvelope.snapshot(tuning)
	return not envelope.is_empty() and float(envelope.held_jump_height) + 0.001 >= minimum_held_jump_height and float(envelope.held_jump_range) + 0.001 >= minimum_held_jump_range
