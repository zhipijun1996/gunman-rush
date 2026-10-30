extends "res://third_party/mapgen/0.1.0/module_pack/runtime/module_runtime/revision061_ellipse_definition_v1-fff23a5cee8f.gd"
## The native v1 installer predates the materialized mirror sign field.
@export var ellipse_x_sign := 1.0
@export var materialized_center := Vector2(320, 256):
	set(value):
		materialized_center = value
		center = value
@export var materialized_radii := Vector2(160, 144):
	set(value):
		materialized_radii = value
		radii = value

func at_time(clock: float) -> Vector2:
	var angle: float = PI + TAU * fposmod(clock / period() + initial_phase, 1.0)
	return center + Vector2(cos(angle) * radii.x * ellipse_x_sign, sin(angle) * radii.y)

func is_valid() -> bool:
	return ellipse_x_sign in [-1.0, 1.0] and super.is_valid()
