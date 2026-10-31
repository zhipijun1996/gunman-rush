class_name SegmentRespawn
extends RefCounted

signal returned(anchor_id: StringName)
var controller: PlayerController
var lifetime: DemoLifetime
var danger_bounds: Array[Rect2] = []
var _anchors: Dictionary = {}
var _history: Array[StringName] = []

func configure(player: PlayerController, life: DemoLifetime) -> void:
	controller = player
	lifetime = life

func add_anchor(id: StringName, location: Vector2) -> bool:
	if id.is_empty() or not location.is_finite() or _anchors.has(id):
		return false
	_anchors[id] = location
	return true

func activate_anchor(id: StringName) -> bool:
	if not _anchors.has(id) or not is_safe(_anchors[id]):
		return false
	_history.erase(id)
	_history.append(id)
	return true

func return_to_anchor() -> bool:
	if lifetime == null or not lifetime.active or not is_instance_valid(controller) or not controller.active or controller.actor_resources.health.terminal:
		return false
	for index: int in range(_history.size() - 1, -1, -1):
		var id := _history[index]
		var location: Vector2 = _anchors[id]
		if is_safe(location) and controller.return_to_segment(location):
			lifetime.invalidate_actor()
			returned.emit(id)
			return true
	# A malformed map stops safely; it never teleports blindly into a hazard.
	controller.router.clear("unsafe_segment_anchor")
	controller.motor.reset_motion()
	controller.active = false
	push_error("No safe segment anchor: content validation failed")
	return false

func is_safe(location: Vector2) -> bool:
	if not is_instance_valid(controller) or not controller.is_inside_tree() or not location.is_finite():
		return false
	var body := controller.motor
	var collision := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or not collision.shape is RectangleShape2D:
		return false
	var rectangle := collision.shape as RectangleShape2D
	var bounds := Rect2(location - rectangle.size / 2.0, rectangle.size)
	for danger: Rect2 in danger_bounds:
		if danger.intersects(bounds, true):
			return false
	var space := body.get_world_2d().direct_space_state
	var shape_query := PhysicsShapeQueryParameters2D.new()
	shape_query.shape = rectangle
	shape_query.transform = Transform2D(0.0, location + collision.position + Vector2(0, -0.05))
	shape_query.collision_mask = body.collision_mask
	shape_query.exclude = [body.get_rid()]
	shape_query.margin = 0.0
	if not space.intersect_shape(shape_query).is_empty():
		return false
	var feet := location + collision.position + Vector2(0, rectangle.size.y / 2.0)
	for offset: float in [-rectangle.size.x / 2.0 + 1.0, 0.0, rectangle.size.x / 2.0 - 1.0]:
		var ray := PhysicsRayQueryParameters2D.create(feet + Vector2(offset, -0.1), feet + Vector2(offset, 8.0), body.collision_mask, [body.get_rid()])
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or (hit.normal as Vector2).dot(Vector2.UP) < 0.7:
			return false
	return true
