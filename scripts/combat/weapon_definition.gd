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
	if not is_finite(interval) or not is_finite(burst_duration) or not is_finite(recoil_scale): return false
	if interval <= 0 or burst_duration <= 0 or recoil_scale <= 0 or recoil_scale > 1: return false
	return (id == &"pulse_gun" and tier == 1 and rounds == 1 and branch.is_empty()) or (id == &"triple_machine_gun" and tier == 2 and rounds == 3 and branch == &"machine_gun")
