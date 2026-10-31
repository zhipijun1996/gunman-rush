class_name RecoilAbility
extends Node

@export var enabled := true:
	set(value):
		enabled = value
		if not value and motor != null:
			motor.clear_recoil()
var motor: PlayerMotor

func execute(direction: Vector2, grounded_at_fire: bool) -> void:
	if enabled:
		# Controller samples after jump/drop intent; contact cache alone is stale
		# on a jump-and-fire tick. Never re-evaluate grounding mid-burst.
		var strength := motor.tuning.ground_recoil_multiplier if grounded_at_fire else 1.0
		if motor.tuning.recoil_mode == "shot_burst":
			motor.start_shot_burst(-direction, strength)
		else:
			motor.apply_impulse(-direction * motor.tuning.recoil_impulse * strength)
