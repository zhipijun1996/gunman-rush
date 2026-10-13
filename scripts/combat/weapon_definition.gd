class_name WeaponDefinition
extends Resource
## Immutable configuration. The one equipped ShootAbility owns packet state.
@export var id: StringName = &"pulse_gun"
@export var tier := 1
@export var branch: StringName = &""
@export var rounds := 1
@export var interval := 0.11
@export var burst_duration := 0.065
@export var recoil_scale := 0.72
func is_valid() -> bool:
	return id in [&"pulse_gun", &"triple_machine_gun"] and tier in [1,2] and rounds in [1,3] and interval > 0 and burst_duration > 0 and recoil_scale > 0 and recoil_scale <= 1
