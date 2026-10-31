class_name WorldSwitch
extends Area2D

signal switched(enabled: bool)
@export var definition: WorldDefinition
@export var mechanism: SawHazard
var context: WorldContext
var active := true
var triggered := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if definition == null:
		definition = WorldDefinition.new()
	collision_layer = 0
	collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(48, 16)
	collision.shape = shape
	add_child(collision)
	body_entered.connect(_on_body)

func setup(world: WorldContext) -> void:
	context = world
	world.register_object(self)

func activate() -> void:
	active = true

func deactivate() -> void:
	active = false

func reset(_policy: StringName = &"life") -> void:
	triggered = false
	active = true
	queue_redraw()

func _on_body(body: Node2D) -> void:
	if active and not triggered and body is PlayerMotor:
		var controller := body.get_node("Controller") as PlayerController
		if controller.active:
			triggered = true
			if is_instance_valid(mechanism):
				mechanism.deactivate()
			switched.emit(false)
			queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-24, -8, 48, 16), Color(0.42, 0.91, 0.69) if triggered else Color(0.76, 0.61, 0.38))
