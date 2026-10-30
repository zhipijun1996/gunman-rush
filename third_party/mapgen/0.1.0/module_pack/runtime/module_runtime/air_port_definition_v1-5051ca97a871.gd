extends PlatformingModuleDefinition
## Preserve all original validation; explicit AIR docks need no standing floor.
var air_points: Array[Vector2]=[]

func _standing_point(at: Vector2) -> bool:
	for point: Vector2 in air_points:
		if at.is_equal_approx(point):return true
	return super._standing_point(at)
