extends "res://game/bosses/arena/armored_boss_damageable.gd"
## The drill shields the axle from frontal, horizontal fire even while retracting.
func receive_damage(context: Dictionary) -> bool:
	if not can_receive_effects(): return super.receive_damage(context)
	var actor := get_parent().get_node("Actor") as EnemyActor
	var direction: Vector2=context.get("hit_direction",Vector2.ZERO)
	if absf(direction.x)>0.65 and direction.x*actor.brain.direction<0:
		GameAudio.cue(self,&"armour")
		return false
	return super.receive_damage(context)
