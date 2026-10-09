class_name ChallengeGoal
extends Area2D

signal reached(controller: PlayerController)
var completed := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	collision_layer = 0
	collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(64, 100)
	collision.shape = shape
	add_child(collision)
	body_entered.connect(func(body: Node2D) -> void:
		if not completed and body is PlayerMotor:
			var controller := body.get_node("Controller") as PlayerController
			if controller.active:
				completed = true
				reached.emit(controller)
				queue_redraw()
	)

func reset(_policy: StringName = &"life") -> void:
	completed = false
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-28, -50, 56, 100), Color(0.4, 0.84, 0.66, 0.3))
	draw_arc(Vector2.ZERO, 23, 0, TAU, 32, Color(0.62, 0.97, 0.76) if completed else Color(0.92, 0.78, 0.5), 3)
