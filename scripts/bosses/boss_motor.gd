class_name BossMotor
extends CharacterBody2D

var speed := 0.0

func configure(definition: BossDefinition) -> void:
	speed = definition.patrol_speed
	var rectangle := RectangleShape2D.new()
	rectangle.size = definition.collision_size
	($CollisionShape2D as CollisionShape2D).shape = rectangle

func step(direction: int, limit: float, delta: float) -> bool:
	velocity = Vector2.ZERO
	if direction not in [-1, 1] or not is_finite(limit) or limit < 0.0 or not is_finite(delta) or delta <= 0.0:
		return false
	var distance := minf(speed * delta, limit)
	velocity = Vector2(direction * distance / delta, 0.0)
	return move_and_collide(Vector2(direction * distance, 0.0)) != null if distance > 0.0 else false

func stop() -> void:
	velocity = Vector2.ZERO
