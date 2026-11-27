extends Damageable
## Plated chassis stops projectiles. Only a stopped machine exposes its mechanism.
func can_receive_effects() -> bool:
	var actor := get_parent().get_node_or_null("Actor") as EnemyActor
	return active and actor != null and actor.attack_behavior != null and actor.attack_behavior.state == &"recovery"

func impact_style() -> StringName:
	return &"ordinary" if can_receive_effects() else &"armour"

func physical_impact(_point: Vector2) -> void:
	if active and not can_receive_effects(): GameAudio.cue(self,&"armour")

func receive_damage(context: Dictionary) -> bool:
	return can_receive_effects() and super.receive_damage(context)
