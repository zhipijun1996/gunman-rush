class_name RuntimeMapEllipseDefinition
extends ModuleMovingPlatformDefinition
## Native clockwise_ellipse/v1 from module-pack1.1.0, with the v2 materialized
## x-sign. No source_affine/mirror operation is performed by the host.
@export var center := Vector2(320,256)
@export var radii := Vector2(160,144)
@export var x_sign := 1.0

func is_valid() -> bool:
	return not platform_id.is_empty() and center.is_finite() and radii.is_finite() and radii.x > 0 and radii.y > 0 and size.is_finite() and size.x > 0 and size.y > 0 and is_finite(travel_duration) and travel_duration > 0 and dwell_duration == 0 and is_finite(initial_phase) and initial_phase >= 0 and initial_phase < 1 and x_sign in [-1.0,1.0]

func period() -> float:
	return travel_duration

func envelope() -> Rect2:
	return Rect2(center-radii-size*.5,radii*2+size)

func at_time(clock: float) -> Vector2:
	var angle: float = PI+TAU*fposmod(clock/period()+initial_phase,1.0)
	# Preserve the upstream Vector2 component precision boundary before the
	# already-materialized horizontal orientation is applied to its x offset.
	var offset := Vector2(cos(angle)*radii.x,sin(angle)*radii.y)
	offset.x *= x_sign
	return center+offset
