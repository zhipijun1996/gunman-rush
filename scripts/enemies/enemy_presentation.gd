class_name EnemyPresentation
extends Node2D

@export var actor: EnemyActor
var _size := Vector2.ZERO

func _ready() -> void:
	_size = actor.definition.collision_size
	actor.health.changed.connect(_health_changed)
	queue_redraw()

func _health_changed(_result: ActorResourceResult) -> void:
	queue_redraw()

func _draw() -> void:
	if actor == null:
		return
	var color := Color(0.82, 0.48, 0.27) if not actor.health.terminal else Color(0.24, 0.26, 0.29)
	var half := _size * 0.5
	draw_colored_polygon(PackedVector2Array([Vector2(-half.x, 0), Vector2(0, -half.y), Vector2(half.x, 0), Vector2(0, half.y)]), color)
	draw_circle(Vector2.ZERO, 4.0, Color(0.15, 0.17, 0.21))
	for index: int in ceili(actor.health.current):
		draw_circle(Vector2(-8 + index * 8, -half.y - 9), 2.0, Color(1, 0.76, 0.42))
