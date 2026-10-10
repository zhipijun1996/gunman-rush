class_name ModuleMovingPlatformDefinition
extends Resource

@export var platform_id: StringName = &"ferry"
@export var start := Vector2(400, 572)
@export var finish := Vector2(960, 572)
@export var size := Vector2(160, 24)
@export var travel_duration := 3.0
@export var dwell_duration := 1.0
@export var initial_phase := 0.0

func is_valid() -> bool:
	return not platform_id.is_empty() and start.is_finite() and finish.is_finite() and start != finish and size.is_finite() and size.x > 0.0 and size.y > 0.0 and is_finite(travel_duration) and travel_duration > 0.0 and is_finite(dwell_duration) and dwell_duration > 0.0 and is_finite(initial_phase) and initial_phase >= 0.0 and initial_phase < 1.0

func period() -> float:
	return (travel_duration + dwell_duration) * 2.0

func envelope() -> Rect2:
	var low := start.min(finish) - size / 2.0
	var high := start.max(finish) + size / 2.0
	return Rect2(low, high - low)

func at_time(clock: float) -> Vector2:
	var elapsed := fposmod(clock + initial_phase * period(), period())
	if elapsed < dwell_duration:
		return start
	elapsed -= dwell_duration
	if elapsed < travel_duration:
		return start.lerp(finish, elapsed / travel_duration)
	elapsed -= travel_duration
	if elapsed < dwell_duration:
		return finish
	return finish.lerp(start, (elapsed - dwell_duration) / travel_duration)
