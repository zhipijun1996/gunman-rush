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
	var texture: Texture2D = preload("res://assets/enemies/plains/patrol_drone_patrol.svg") if not actor.health.terminal else preload("res://assets/enemies/plains/patrol_drone_dead.svg")
	var half := _size * 0.5
	# Cosmetic rotor and armor may extend beyond the existing actor hitbox.
	# Collision and contact requests remain EnemyActor/Motor-owned.
	var size := Vector2.ONE * maxf(_size.x, _size.y) * 1.4
	draw_texture_rect(texture, Rect2(-size / 2.0, size), false)
	for index: int in ceili(actor.health.current):
		draw_circle(Vector2(-8 + index * 8, -half.y - 9), 2.0, Color(1, 0.76, 0.42))
