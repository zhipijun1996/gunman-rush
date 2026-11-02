class_name ShotEnergyDefinition
extends StaminaDefinition

## Explicit historical D079 policy switch. Formal v2 uses AirFocus only.
@export var shooting_consumes_energy := true
@export var shot_energy_cost := 20.0
@export var hit_energy_recovery := 20.0
@export var ground_recovery := 30.0
@export var recovery_delay := 0.35

func is_valid() -> bool:
	return super.is_valid() and [shot_energy_cost,hit_energy_recovery,ground_recovery,recovery_delay].all(func(v: float): return is_finite(v) and v>0) and shot_energy_cost<=capacity
