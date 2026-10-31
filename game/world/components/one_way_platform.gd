class_name OneWayPlatform
extends StaticBody2D

@export var width := 160.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group(&"one_way_platform")
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, 12)
	collision.shape = shape
	collision.one_way_collision = true
	collision.one_way_collision_margin = 4.0
	add_child(collision)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-width / 2.0, -6, width, 12), Color(0.31, 0.48, 0.53))
	draw_line(Vector2(-width / 2, -6), Vector2(width / 2, -6), Color(0.59, 0.85, 0.85), 2)
