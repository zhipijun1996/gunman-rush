class_name WorldHazardGeometry
extends RefCounted

## The body AABB is computed from the actual rectangle and collision transform.
static func body_rect(shape: CollisionShape2D) -> Rect2:
	return shape.global_transform * shape.shape.get_rect()

## Times within a linear step when the moving AABB overlaps the moving bounds.
## Both intervals are normalized. A reversed interval denotes no contact.
static func sweep(from: Rect2, to: Rect2, start: Rect2, finish: Rect2) -> Vector2:
	var entry := 0.0
	var exit_time := 1.0
	for axis: int in 2:
		var distances := Vector2(from.end[axis]-start.position[axis], start.end[axis]-from.position[axis])
		var last := Vector2(to.end[axis]-finish.position[axis], finish.end[axis]-to.position[axis])
		for face: int in 2:
			if distances[face] < 0 and last[face] < 0: return Vector2(1,0)
			if distances[face] < 0:
				entry = maxf(entry, distances[face]/(distances[face]-last[face]))
			elif last[face] < 0:
				exit_time = minf(exit_time, distances[face]/(distances[face]-last[face]))
	return Vector2(entry,exit_time)

static func interpolate(a: Rect2, b: Rect2, t: float) -> Rect2:
	return Rect2(a.position.lerp(b.position,t),a.size.lerp(b.size,t))

static func supported(motor: PlayerMotor, body: Node) -> bool:
	if not motor.is_on_floor(): return false
	for i: int in motor.get_slide_collision_count():
		var hit := motor.get_slide_collision(i)
		if hit.get_collider() == body and hit.get_normal().dot(Vector2.UP) > 0.9: return true
	return false

static func rectangle_shape(size: Vector2, one_way := false) -> CollisionShape2D:
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	collision.one_way_collision = one_way
	return collision
