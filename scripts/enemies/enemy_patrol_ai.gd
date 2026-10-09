class_name EnemyPatrolAI
extends Node

@export var enabled := true
var direction := 1
var _origin_x := 0.0
var _radius := 0.0

func configure(definition: EnemyDefinition, origin_x: float) -> void:
	_origin_x = origin_x
	_radius = definition.patrol_half_width
	direction = definition.initial_direction

func sample_intent(location: Vector2) -> EnemyIntent:
	var result := EnemyIntent.new()
	if not enabled or _radius <= 0.0 or not location.is_finite():
		return result
	if direction > 0 and location.x >= _origin_x + _radius - 1.0e-6:
		direction = -1
	elif direction < 0 and location.x <= _origin_x - _radius + 1.0e-6:
		direction = 1
	result.move_axis = direction
	result.travel_limit = maxf(0.0, _origin_x + _radius - location.x) if direction > 0 else maxf(0.0, location.x - (_origin_x - _radius))
	return result

func on_blocked() -> void:
	direction = -direction
