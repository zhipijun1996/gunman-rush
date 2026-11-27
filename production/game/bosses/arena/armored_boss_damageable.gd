extends Damageable
## Shell or armour protects the body until the recovery animation exposes a weak point.
func can_receive_effects() -> bool:
	var actor := get_parent().get_node_or_null("Actor") as EnemyActor
	return active and actor != null and actor.attack_behavior != null and actor.attack_behavior.state == &"recovery"

func impact_style() -> StringName:
	return &"ordinary" if can_receive_effects() else &"armour"

func physical_impact(_point: Vector2) -> void:
	if active and not can_receive_effects(): GameAudio.cue(self,&"armour")

func receive_damage(context: Dictionary) -> bool:
	if can_receive_effects(): return super.receive_damage(context)
	if active and context.get("source_faction") == &"player":
		physical_impact(context.get("hit_point",Vector2.ZERO))
	return false
