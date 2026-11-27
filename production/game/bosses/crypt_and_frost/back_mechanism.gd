extends "res://game/bosses/arena/armored_boss_damageable.gd"
## Horizontal shots from behind travel in the direction the armored shoulder faces.
func receive_damage(context:Dictionary) -> bool:
	if not can_receive_effects(): return false
	var actor:=get_parent().get_node("Actor") as EnemyActor
	var direction:Vector2=context.get("hit_direction",Vector2.ZERO)
	return direction.x*actor.brain.direction>0.12 and super.receive_damage(context)
