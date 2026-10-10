class_name ModuleSawDefinition
extends Resource

@export var source_id: StringName = &"module_saw"
@export var origin := Vector2(630, 450)
@export var travel := Vector2(0, 130)
@export var radius := 24.0
@export var period := 4.0
@export var initial_phase := 0.0
@export var damage := 1.0
@export var contact_interval := 0.7

func is_valid() -> bool:
	return not source_id.is_empty() and origin.is_finite() and travel.is_finite() and is_finite(radius) and radius > 0.0 and is_finite(period) and period > 0.0 and is_finite(initial_phase) and initial_phase >= 0.0 and initial_phase < 1.0 and is_finite(damage) and damage > 0.0 and is_finite(contact_interval) and contact_interval > 0.0

func envelope() -> Rect2:
	var extent := travel.abs() + Vector2.ONE * radius
	return Rect2(origin - extent, extent * 2.0)

func at_time(clock: float) -> Vector2:
	return origin + travel * sin(TAU * (clock / period + initial_phase))
