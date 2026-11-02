class_name CombatTarget
extends StaticBody2D

@export var max_health := 3.0
var damageable: Damageable

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(32, 64)
	collision.shape = shape
	add_child(collision)
	damageable = Damageable.new()
	damageable.name = "Damageable"
	damageable.max_health = max_health
	add_child(damageable)
	damageable.health_changed.connect(func(_health: float) -> void: queue_redraw())

func reset(_policy: StringName = &"life") -> void:
	damageable.reset()
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-16, -32, 32, 64), Color(0.78, 0.55, 0.52) if damageable == null or damageable.active else Color(0.23, 0.24, 0.3))
	if damageable != null:
		for index: int in ceili(damageable.health):
			draw_circle(Vector2(-10 + index * 10, -40), 3, Color(1, 0.76, 0.42))
