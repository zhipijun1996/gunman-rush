extends EnemyActor
## Bearings carry the chassis; gunfire cannot push the carriage off its rail.
func _accepted_hit(_context: Dictionary) -> void:
	if not health.terminal and not _restoring_instance: GameAudio.cue(self,&"core")

func apply_skill_impact(_unit: Vector2, _stagger_seconds: float, _stagger_cooldown: float, _knockback_speed: float, _knockback_seconds: float) -> void:
	pass
