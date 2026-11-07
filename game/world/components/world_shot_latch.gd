class_name WorldShotLatch
extends ShotLatch
## Reuses projectile eligibility; App owns durable acceptance after damage arbitration.
signal activation_requested(id: String)
var stable_id: String
var pending_commit: Dictionary={}
func _commit_open(request: Dictionary) -> void:
	pending_commit=request
	if can_commit():activation_requested.emit(stable_id)
func can_commit() -> bool:
	var request:=pending_commit
	return not request.is_empty() and request.get("request_epoch",-1)==_request_epoch and not _cancelled and (not is_open or motion_mode) and is_inside_tree() and lifetime.accepts(request.token) and is_instance_valid(controller) and controller.active and not controller.actor_resources.health.terminal and controller.session_id==request.session and health.epoch==request.health_epoch
func proposed_state() -> Dictionary:
	var proposed:=region_snapshot()
	proposed.is_open=not motion_target.motion_running if motion_mode else true
	proposed.motion_running=proposed.is_open if motion_mode else false
	proposed.opened_at=_clock;proposed.open_count=open_count+1
	return proposed
func accept_committed() -> void:
	var request:=pending_commit;pending_commit={}
	super._commit_open(request)
func on_router_cancelled(_reason: String) -> void:
	cancel_pending()
func cancel_pending() -> void:
	pending_commit={}
	super.cancel_pending()
func _draw() -> void:
	if not is_instance_valid(controller):return
	var age:=_clock-_opened_at if _opened_at>=0 else 99.0
	var swing:=sin(age*22)*.13*maxf(0,1-age/.8)
	UnderworldTerrain.draw_mechanism_beam(self,Rect2(bell_position-Vector2(36,64),Vector2(72,8)))
	draw_line(bell_position-Vector2(0,58),bell_position-Vector2(0,18),Color("826b47"),2)
	draw_set_transform(bell_position,swing)
	UnderworldTerrain.draw_mechanism_bell(self,Vector2.ZERO,is_open,age<.16)
	draw_set_transform(Vector2.ZERO)
	if motion_mode:
		# The visible rail shows the actual carrier trajectory; brass knots identify control.
		var carrier:=motion_target as WorldMovingPlatform
		draw_line(carrier.origin-Vector2(0,12),carrier.origin+carrier.endpoint-Vector2(0,12),Color("685c48"),3)
		for at: Vector2 in [carrier.origin,carrier.origin+carrier.endpoint]:
			draw_circle(at-Vector2(0,12),5,Color("b39358"),false,2)
	elif not is_open:_draw_gate(gate_rect,1.0)
	elif age<.35:
		var raised:=gate_rect;raised.position.y-=gate_rect.size.y*age/.35
		_draw_gate(raised,1-age/.35)
	if age<.65:
		for ring: int in 2:
			var t:=maxf(0,age-ring*.1)
			draw_arc(bell_position,15+t*72,0,TAU,32,Color(.92,.78,.46,maxf(0,1-t/.55)),1)
