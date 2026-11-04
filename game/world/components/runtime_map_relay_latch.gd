class_name RuntimeMapRelayLatch
extends ShotLatch
## Child projectiles are authorized by a real accepted parent impact and retain
## the original player session, weapon epoch, lifetime and native projectile sweep.
var child_owner: int=-1
var direct_primary:=false
var child_requests: Dictionary={}
func authorize_child(projectile: PlayerProjectile,parent: String,token: DemoToken) -> void:
	child_requests[str(projectile.shot_id)]={"token":token,"parent":parent,"session":projectile.session_id,"expires":_clock+projectile.lifetime,"weapon_epoch":projectile.weapon_epoch}
func _receive_projectile(hit: Dictionary) -> bool:
	if hit.get("source_faction",&"")==&"player":
		if not direct_primary and Rect2(bell_position-Vector2(18,21),Vector2(36,42)).has_point(to_local(hit.get("hit_point",Vector2.ZERO))):return false
		return super._receive_projectile(hit)
	var child: Dictionary=child_requests.get(str(hit.get("shot_id",-1)),{})
	if child.is_empty() or _cancelled or is_open and not repeatable or not _pending.is_empty() or not lifetime.accepts(child.get("token")) or _clock>float(child.get("expires",-1)) or not controller.active or controller.actor_resources.health.terminal or child.get("session")!=controller.session_id or child.get("weapon_epoch")!=controller.shoot_ability.weapon_epoch or hit.get("source_faction",&"")!=&"turret_shot" or hit.get("source_actor_id",-1)!=child_owner or hit.get("session_id",-1)!=controller.session_id or hit.get("target_actor_id",-1)!=receiver.actor_id or hit.get("target_epoch",-1)!=health.epoch:return false
	var id:=str(hit.get("event_id",""))
	if id.is_empty() or _seen.has(id):return false
	_seen[id]=true;_pending={"id":id,"token":child.token,"session":controller.session_id,"health_epoch":health.epoch,"request_epoch":_request_epoch};child_requests.erase(str(hit.shot_id));return true
func cancel_pending() -> void:
	child_requests.clear();super.cancel_pending()
