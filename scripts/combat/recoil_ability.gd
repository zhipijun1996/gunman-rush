class_name RecoilAbility
extends Node

@export var enabled := true:
	set(value):
		enabled = value
		if not value and motor != null:
			motor.clear_recoil()
var motor: PlayerMotor

func execute(direction: Vector2) -> void:
	if enabled:
		if motor.tuning.recoil_mode == "shot_burst":
			motor.start_shot_burst(-direction)
		else:
			motor.apply_impulse(-direction * motor.tuning.recoil_impulse)
