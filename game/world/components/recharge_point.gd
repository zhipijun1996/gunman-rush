class_name RechargePoint
extends Area2D

@export var definition: WorldDefinition
var context: WorldContext
var active := true
var _pending: Dictionary = {}
var _consumed_sessions: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_physics_priority = 50
	if definition == null:
		definition = WorldDefinition.new()
	collision_layer = 0
	collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = definition.radius
	collision.shape = shape
	add_child(collision)
	body_entered.connect(_on_body)

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
	_pending.clear()
	_consumed_sessions.clear()
	activate()

func _physics_process(_delta: float) -> void:
	# A full-resource player can remain overlapping until a shot opens a slot.
	for body: Node2D in get_overlapping_bodies():
		_on_body(body)

func _on_body(body: Node2D) -> void:
	if body is PlayerMotor:
		try_touch(body.get_node("Controller") as PlayerController)

func try_touch(controller: PlayerController) -> bool:
	var key := "%d:%d" % [controller.motor.get_instance_id(), controller.session_id]
	if not active or not controller.active or controller.motor.is_on_floor() or _pending.has(key) or _consumed_sessions.has(key):
		return false
	if not controller.action_resources.can_grant_shot():
		return false
	_pending[key] = true
	var expected := controller.session_id
	var weak_point: WeakRef = weakref(self)
	var weak_controller: WeakRef = weakref(controller)
	controller.queue_grant(definition.grant_amount, expected, func(actual: int) -> void:
		var point := weak_point.get_ref() as RechargePoint
		var actor := weak_controller.get_ref() as PlayerController
		if point == null or actor == null:
			return
		point._pending.erase(key)
		if actual > 0 and actor.session_id == expected and point.active:
			point._consumed_sessions[key] = true
			point.deactivate()
	, func() -> bool:
		var point := weak_point.get_ref() as RechargePoint
		return point != null and point.is_inside_tree() and point.active
	)
	return true

func _draw() -> void:
	var radius := definition.radius if definition != null else 24.0
	var tint := Color(0.4, 0.94, 0.84) if active else Color(0.18, 0.28, 0.3)
	draw_circle(Vector2.ZERO, radius, Color(tint, 0.15))
	draw_arc(Vector2.ZERO, radius * 0.8, 0, TAU, 32, tint, 3)
	draw_line(Vector2(-8, 0), Vector2(8, 0), tint, 3)
	draw_line(Vector2(0, -8), Vector2(0, 8), tint, 3)
