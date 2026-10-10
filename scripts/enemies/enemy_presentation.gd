class_name EnemyPresentation
extends Node2D
## Original generated acorn beetle skin; AI and collision remain independent.
@export var actor: EnemyActor
var _size := Vector2.ZERO
var _clock := 0.0
var _hurt_time := 0.0
func _ready() -> void:
	_size = actor.definition.collision_size
	actor.health.changed.connect(_health_changed)
	queue_redraw()
func _process(delta: float) -> void:
	_clock += delta
	_hurt_time = maxf(0, _hurt_time - delta)
	queue_redraw()
func _health_changed(result: ActorResourceResult) -> void:
	if result.status == ActorResourceResult.Status.APPLIED and result.amount_applied < 0:
		_hurt_time = 0.14
	queue_redraw()
func _draw() -> void:
	if actor == null:
		return
	var texture := PlainsRefreshAssets.object_texture(&"enemy_left" if actor.brain.direction < 0 else &"enemy_right")
	var size := Vector2(_size.x * 1.45, _size.y * 1.45)
	var bob := sin(_clock * 7) * 1.2 if not actor.health.terminal else 0.0
	var tint := Color(1.0, 0.50, 0.43) if _hurt_time > 0 else Color.WHITE
	if actor.health.terminal:
		tint = Color(0.58, 0.57, 0.49, 0.52)
		size.y *= 0.45
	draw_texture_rect(texture, Rect2(Vector2(-size.x / 2, -size.y / 2 + bob), size), false, tint)
	for index: int in ceili(actor.health.current):
		draw_circle(Vector2(-8 + index * 8, -_size.y / 2 - 9), 2.0, Color(1, 0.76, 0.42))
