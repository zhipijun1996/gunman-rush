class_name BacksideShotLatch
extends ShotLatch
## Upper-bank projectile-only shortcut. ShotLatch retains accepted-shot/session/
## target epoch/idempotency policy; this adds the existing bank-origin contract.
var upper_control := Vector2.ZERO
var shortcut_id := ""

func _receive_projectile(context: Dictionary) -> bool:
	var key := "%s:%s" % [context.get("session_id",-1),context.get("shot_id",-1)]
	var shot: Dictionary = _eligible_shots.get(key,{})
	if not shot.has("actor_position"): return false
	var origin := to_local(shot.actor_position)
	if origin.distance_to(upper_control)>90.0 or origin.y>upper_control.y+24.0:
		return false
	return super._receive_projectile(context)
