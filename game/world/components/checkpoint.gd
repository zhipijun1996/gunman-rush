class_name SafeCheckpoint
extends Area2D

signal activated
@export var definition: WorldDefinition
var context: WorldContext
var active := true
var selected := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_physics_priority = 50
	if definition == null:
		definition = WorldDefinition.new()
	collision_layer = 0
	collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = definition.safe_size
	collision.shape = shape
	add_child(collision)

func setup(world: WorldContext) -> void:
	context = world
	world.register_object(self)

func activate() -> void:
	active = true

func deactivate() -> void:
	active = false

func reset(_policy: StringName = &"life") -> void:
	# Session checkpoint survives death; restart updates the context explicitly.
	queue_redraw()

func _physics_process(_delta: float) -> void:
	for body: Node2D in get_overlapping_bodies():
		if body is PlayerMotor:
			try_activate(body.get_node("Controller") as PlayerController)

func try_activate(controller: PlayerController) -> bool:
	if not active or selected or context == null or not controller.active or not controller.motor.is_on_floor():
		return false
	if not Rect2(global_position - definition.safe_size / 2.0, definition.safe_size).has_point(controller.motor.global_position):
		return false
	# Validate the spawn itself, not only the actor standing elsewhere in the Area.
	var actor_shape := controller.motor.get_node("CollisionShape2D") as CollisionShape2D
	var rectangle := actor_shape.shape as RectangleShape2D
	if rectangle == null:
		return false
	var shape_query := PhysicsShapeQueryParameters2D.new()
	shape_query.shape = rectangle
	shape_query.transform = Transform2D(0.0, global_position + Vector2(0, -0.05))
	shape_query.collision_mask = controller.motor.collision_mask
	shape_query.exclude = [controller.motor.get_rid()]
	shape_query.margin = 0.0
	if not get_world_2d().direct_space_state.intersect_shape(shape_query).is_empty():
		return false
	var feet := global_position + Vector2(0, rectangle.size.y / 2.0)
	for x_offset: float in [-rectangle.size.x / 2.0 + 1.0, 0.0, rectangle.size.x / 2.0 - 1.0]:
		var ray := PhysicsRayQueryParameters2D.create(feet + Vector2(x_offset, -0.1), feet + Vector2(x_offset, 3.0), controller.motor.collision_mask, [controller.motor.get_rid()])
		var floor_hit := get_world_2d().direct_space_state.intersect_ray(ray)
		if floor_hit.is_empty() or (floor_hit.normal as Vector2).dot(Vector2.UP) < 0.7:
			return false
	# Reject hazards whose entire configured travel can invade the safe zone.
	for object: Node in context.objects:
		if object is SawHazard and object.active:
			if object.global_position.distance_to(global_position) < object.definition.radius + definition.safe_size.length() / 2.0 + object.definition.travel.length():
				return false
	context.set_checkpoint(global_position)
	selected = true
	activated.emit()
	queue_redraw()
	return true

func _draw() -> void:
	var tint := Color(0.95, 0.8, 0.47) if selected else Color(0.56, 0.59, 0.74)
	draw_line(Vector2(0, 18), Vector2(0, -38), tint, 3)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -38), Vector2(30, -27), Vector2(0, -16)]), tint)
	draw_arc(Vector2(0, 18), 24, PI, TAU, 20, tint, 2)
