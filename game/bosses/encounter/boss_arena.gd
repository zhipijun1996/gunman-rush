class_name BossArena
extends RefCounted

var left_x := 0.0
var right_x := 0.0

func configure(left: float, right: float, actor_half_width: float) -> bool:
	if not is_finite(left) or not is_finite(right) or not is_finite(actor_half_width) or actor_half_width <= 0.0 or right - left <= actor_half_width * 2.0:
		return false
	left_x = left + actor_half_width
	right_x = right - actor_half_width
	return true

func travel_limit(position_x: float, direction: int) -> float:
	return maxf(0.0, right_x - position_x if direction > 0 else position_x - left_x)
