class_name ForestBarkDamageable
extends Damageable
## Directional material response only. Accepted damage still uses Damageable's
## canonical epoch, event deduplication, HealthState and commit/resource callback.
signal shield_contact(context: Dictionary)
var blocked_count := 0
var _guarded_events: Dictionary = {}
var _guard_epoch := -1
var _guard_actor_id := -1
var _guard_health_id := -1

func receive_damage(context: Dictionary) -> bool:
	# Match Damageable's eligibility BEFORE producing feedback. Do not send a
	# shield hit to its damage sink: a block grants neither HP damage nor energy.
	var event_id: String=str(context.get("event_id",""))
	var amount: float=float(context.get("amount",0.0))
	if not active or amount<=0.0 or not is_finite(amount) or event_id.is_empty() or _events.has(event_id):return false
	if context.get("source_faction",&"")==faction or (actor_id!=0 and context.get("source_actor_id",0)==actor_id):return false
	if _health_state!=null:
		if context.get("target_actor_id",-1)!=actor_id or context.get("target_epoch",-1)!=damage_epoch:return false
	var health_id: int=_health_state.get_instance_id() if _health_state!=null else 0
	if _guard_epoch!=damage_epoch or _guard_actor_id!=actor_id or _guard_health_id!=health_id:
		_guarded_events.clear()
		_guard_epoch=damage_epoch;_guard_actor_id=actor_id;_guard_health_id=health_id
	# A valid blocked packet is consumed for this target lifetime too. Replaying
	# it with another angle must not turn a shield contact into accepted damage.
	if _guarded_events.has(event_id):return false
	var actor:=get_parent().get_node_or_null("Actor") as EnemyActor
	var direction: Variant=context.get("hit_direction")
	if actor!=null and actor.definition is ForestEnemyDefinition and direction is Vector2 and direction.is_finite() and not direction.is_zero_approx():
		var incoming: Vector2=direction.normalized()
		var front:=Vector2(actor.brain.direction,0)
		var threshold:=cos(deg_to_rad((actor.definition as ForestEnemyDefinition).bark_shield_half_angle_degrees))
		if incoming.dot(front)<-threshold:
			_guarded_events[event_id]=true
			blocked_count+=1
			shield_contact.emit(context)
			return false
	var accepted:=super.receive_damage(context)
	if accepted:_guarded_events[event_id]=true
	return accepted
