class_name RecoilAbility
extends Node

@export var enabled := true:
	set(value):
		enabled = value
		if not value and motor != null:
			motor.recoil_velocity = Vector2.ZERO
var motor: PlayerMotor

func execute(direction: Vector2) -> void:
	if enabled:
		motor.apply_impulse(-direction * motor.tuning.recoil_impulse)
