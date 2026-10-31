class_name PrototypeEnemyDamageable
extends Damageable
## Development candidate: a guard teaches bait/rear-fire, not extra HP.
var guard:=false
func receive_damage(context:Dictionary)->bool:
	var actor:=get_parent().get_node("Actor") as EnemyActor
	if guard and actor.attack_behavior!=null and actor.attack_behavior.state!=&"recovery":
		var incoming:Vector2=context.get("hit_direction",Vector2.ZERO)
		if incoming.x*actor.brain.direction<-.2:
			GameAudio.cue(self,&"armour")
			return false
	return super.receive_damage(context)
