class_name BossPhaseController
extends RefCounted

var phase := 1
var threshold := 0.5

func configure(definition: BossDefinition) -> void:
	phase = 1
	threshold = definition.phase_two_threshold

func update(current: float, capacity: float) -> bool:
	if phase == 1 and capacity > 0.0 and current > 0.0 and current / capacity <= threshold:
		phase = 2
		return true
	return false
