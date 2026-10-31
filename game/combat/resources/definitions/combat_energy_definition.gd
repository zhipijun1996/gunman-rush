class_name CombatEnergyDefinition
extends Resource
@export var capacity := 100.0
@export var target_gain := 7.0
@export var packet_gain_limit := 12.0

func is_valid() -> bool:
	return is_finite(capacity) and capacity>0 and is_finite(target_gain) and target_gain>0 and is_finite(packet_gain_limit) and packet_gain_limit>=target_gain
