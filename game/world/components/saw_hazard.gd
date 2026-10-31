class_name SawHazard
extends Node2D

@export var definition: WorldDefinition
var context: WorldContext
var active := true
var origin := Vector2.ZERO
var _previous := Vector2.ZERO
var _actors: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if definition == null:
		definition = WorldDefinition.new()
	origin = position
	_previous = global_position
	process_physics_priority = 100
	queue_redraw()

func setup(world: WorldContext) -> void:
	context = world
	world.register_object(self)

func activate() -> void:
	active = true
	queue_redraw()

func deactivate() -> void:
	active = false
	queue_redraw()

func reset(_policy: StringName = &"life") -> void:
	position = origin
	_previous = global_position
	_actors.clear()
	activate()

func _physics_process(_delta: float) -> void:
	if context == null:
		return
	var phase := context.clock / maxf(0.01, definition.period) * TAU + definition.initial_phase
	position = origin + definition.travel * sin(phase)
	rotation = phase
	for actor: PlayerController in context.actor_registry:
		if not is_instance_valid(actor):
			continue
		var current := actor.motor.global_position
		var id := actor.motor.get_instance_id()
		var previous: Vector2 = _actors.get(id, current)
		if active and actor.active:
			var collision := actor.motor.get_node("CollisionShape2D") as CollisionShape2D
			var rect_shape := collision.shape as RectangleShape2D
			if rect_shape != null and swept_contact(previous - _previous, current - global_position, rect_shape.size / 2.0, definition.radius):
				actor.die()
		_actors[id] = current
	_previous = global_position

static func swept_contact(start: Vector2, finish: Vector2, half_size: Vector2, radius: float) -> bool:
	# Circle versus moving rectangle: relative segment against rounded rectangle.
	var bounds := Rect2(-half_size, half_size * 2.0)
	if bounds.has_point(start) or bounds.has_point(finish):
		return true
	var corners: Array[Vector2] = [-half_size, Vector2(half_size.x, -half_size.y), half_size, Vector2(-half_size.x, half_size.y)]
	for index: int in 4:
		var a := corners[index]
		var b := corners[(index + 1) % 4]
		if Geometry2D.segment_intersects_segment(start, finish, a, b) != null:
			return true
		var pair := Geometry2D.get_closest_points_between_segments(start, finish, a, b)
		if pair[0].distance_squared_to(pair[1]) <= radius * radius:
			return true
	return false

func _draw() -> void:
	var radius := definition.radius if definition != null else 24.0
	var tint := Color(0.96, 0.32, 0.36) if active else Color(0.24, 0.25, 0.28)
	var teeth := PackedVector2Array()
	for index: int in 32:
		teeth.append(Vector2.from_angle(index * TAU / 32.0) * radius * (1.0 if index % 2 == 0 else 0.75))
	draw_colored_polygon(teeth, tint)
	draw_circle(Vector2.ZERO, radius * 0.5, Color(0.08, 0.1, 0.15))
