extends RefCounted
## Actual input only. A real jump reaches cast range, the actual fixed fruit
## holds the body, then a separate Space rising edge supplies the hang jump.
## No pose, velocity, resource, collision or Motor-step authority lives here.
var active_leg := -1
var anchor_id := ""
var anchor_instance := 0
var source := Vector2.ZERO
var goal := Vector2.ZERO
var entry_support := ""
var exit_support := ""
var receiver := Rect2()
var left_gate_end := -INF
var launch_tick := -1
var cast_tick := -1
var hang_tick := -1
var hang_jump_tick := -1
var observed_cast := false
var observed_hang := false
var observed_hang_jump := false
var shoulder_cleared := false

func drive(trace: Node, leg: Dictionary) -> bool:
	if not bool(leg.get("places_fixed_hang_recovery",false)): return false
	if active_leg != int(trace.leg_index):
		if not _begin(trace,leg): return true
	var target: Node2D = trace.stage.assembler.hook_targets.get(anchor_id)
	if not is_instance_valid(target) or not target is GrappleAnchor or not (target as GrappleAnchor).hang_enabled:
		trace.fail("places_recovery_actual_fixed_hanging_fruit_missing"); return true
	if target.get_instance_id()!=anchor_instance or str(target.name)!=anchor_id:
		trace.fail("places_recovery_fixed_target_identity_changed"); return true
	if int(trace.tick)-int(trace.leg_started)>1800:
		trace.fail("places_recovery_original_1800_edge_budget"); return true
	var traversal: TraversalAbility = trace.controller.traversal
	if traversal.state in [&"hook_miss",&"hook_retract"] and cast_tick>=0:
		trace.fail("places_recovery_actual_hook_miss/"+str(trace.phase)); return true
	if str(trace.phase)=="align":
		trace.jump(false)
		trace.controller.router.set_move_axis(clampf((source.x-trace.player.global_position.x)/12.0,-1.0,1.0))
		trace.stable = int(trace.stable)+1 if trace.at_destination(source,entry_support) and absf(trace.player.velocity.x)<1.0 else 0
		if int(trace.stable)>=12:
			launch_tick = int(trace.tick)
			trace.event("places_recovery_actual_grounded_departure",{"anchor_id":anchor_id,"target_instance":anchor_instance,"entry_support":entry_support,"supports":trace.supports(),"source":trace.pair(source),"receiver_rect":[receiver.position.x,receiver.position.y,receiver.size.x,receiver.size.y]})
			trace.controller.router.set_move_axis(0.0)
			trace.jump(true)
			trace.set_phase("places_recovery_launch")
		return true
	if str(trace.phase)=="places_recovery_launch":
		trace.controller.router.set_move_axis(0.0)
		# Keep the real first jump held. An out-of-range departure does not
		# justify an early cast, a larger range, or a manual upward move.
		if trace.player.is_on_floor():
			if int(trace.age)>12: trace.fail("places_recovery_departure_jump_not_accepted")
			return true
		var origin: Vector2 = trace.player.global_position+Vector2(0.0,-6.0)
		var offset: Vector2 = target.global_position-origin
		var radius: float = traversal.definition.hook_capture_radius
		var head_clear := _clear_corridor(trace.player.global_position,origin,radius)
		if offset.length()<=traversal.definition.hook_range and head_clear:
			if not _has_event(trace,"jumped",launch_tick):
				trace.fail("places_recovery_no_actual_initial_jump_event"); return true
			cast_tick = int(trace.tick)
			trace.event("places_recovery_in_range_hook_intent",{"anchor_id":anchor_id,"target_instance":anchor_instance,"target":trace.pair(target.global_position),"hook_origin":trace.pair(origin),"distance":offset.length(),"actual_hook_range":traversal.definition.hook_range,"hook_capture_radius":radius,"body_and_cast_corridor_clear":head_clear})
			# hook() uses the existing human-mouse aim hold. The following
			# phase waits for real cast/contact events, not elapsed aim time.
			if not trace.hook(anchor_id): return true
			trace.set_phase("places_recovery_hook")
		elif int(trace.age)>12 and trace.player.normal_velocity.y>=0.0:
			trace.fail("places_recovery_initial_jump_never_reached_clear_cast_range")
		return true
	if str(trace.phase)=="places_recovery_hook":
		trace.controller.router.set_move_axis(0.0)
		observed_cast = observed_cast or _has_event(trace,"hook_cast",cast_tick)
		if traversal.state==&"hook_hang":
			if not observed_cast or traversal.hook_target!=target:
				trace.fail("places_recovery_hang_has_wrong_actual_target"); return true
			if not _has_target_event(trace,"hook_hang",cast_tick):
				trace.fail("places_recovery_missing_actual_hang_event"); return true
			observed_hang = true
			hang_tick = int(trace.tick)
			trace.event("places_recovery_actual_fixed_hang_observed",{"anchor_id":anchor_id,"target_instance":target.get_instance_id(),"actual_hook_target_instance":traversal.hook_target.get_instance_id(),"hook_tip":trace.pair(traversal.hook_tip),"body":trace.pair(trace.player.global_position),"grounded":trace.player.is_on_floor()})
			# A held launch key is not another jump edge. Send real key-up,
			# let a normal physics/input frame pass, then send a new key-down.
			trace.jump(false)
			trace.set_phase("places_recovery_jump_released")
		elif observed_cast and traversal.state==&"free":
			trace.fail("places_recovery_cast_resolved_without_fixed_hang")
		return true
	if str(trace.phase)=="places_recovery_jump_released":
		trace.controller.router.set_move_axis(0.0)
		if traversal.state!=&"hook_hang" or traversal.hook_target!=target:
			trace.fail("places_recovery_hang_lost_before_new_jump_edge"); return true
		if int(trace.tick)<=hang_tick: return true
		hang_jump_tick = int(trace.tick)
		trace.event("places_recovery_fixed_hang_jump_intent",{"anchor_id":anchor_id,"target_instance":anchor_instance,"previous_key_release_tick":hang_tick,"held_hang_frames":hang_jump_tick-hang_tick})
		trace.jump(true)
		trace.set_phase("places_recovery_receive")
		return true
	if str(trace.phase)=="places_recovery_receive":
		observed_hang_jump = observed_hang_jump or (_has_event(trace,"jumped",hang_jump_tick) and _has_target_event(trace,"hook_kick",hang_jump_tick))
		if not observed_hang_jump and int(trace.age)>12:
			trace.fail("places_recovery_fixed_hang_jump_not_actually_accepted"); return true
		var body: Vector2 = trace.player.global_position
		var full_x := body.x-12.0>=receiver.position.x-0.1 and body.x+12.0<=receiver.end.x+0.1
		var above_top := body.y+18.0<=receiver.position.y-1.0
		var shoulder := receiver.position.x+32.0
		if not shoulder_cleared and full_x and above_top and body.x>=shoulder-1.0:
			shoulder_cleared = true
			trace.event("places_recovery_actual_crown_shoulder_clear",{"anchor_id":anchor_id,"receiver_support":exit_support,"body":trace.pair(body),"receiver_left":receiver.position.x,"full_body_above_receiver":true})
		var steer_x := goal.x if shoulder_cleared else shoulder
		trace.controller.router.set_move_axis(clampf((steer_x-body.x)/12.0,-1.0,1.0))
		var full_hold_frames := int(ceil(trace.player.tuning.jump_hold_duration*Engine.physics_ticks_per_second))
		if shoulder_cleared and not bool(trace.jump_released) and int(trace.age)>=full_hold_frames:
			trace.jump(false)
			trace.jump_released = true
		trace.stable = int(trace.stable)+1 if trace.at_destination(goal,exit_support) and trace.full_support(exit_support) else 0
		if int(trace.stable)>=12:
			if not observed_cast or not observed_hang or not observed_hang_jump or not shoulder_cleared:
				trace.fail("places_recovery_arrived_without_actual_hang_jump_chain"); return true
			trace.event("places_recovery_actual_crown_arrival",{"anchor_id":anchor_id,"target_instance":anchor_instance,"receiver_support":exit_support,"supports":trace.supports(),"full_support_frames":int(trace.stable),"cast_tick":cast_tick,"hang_tick":hang_tick,"hang_jump_tick":hang_jump_tick})
			trace.complete_leg()
		elif int(trace.age)>12 and trace.player.is_on_floor() and not trace.full_support(exit_support):
			trace.fail("places_recovery_jump_landed_on_wrong_support")
		elif observed_hang_jump and trace.player.velocity.y>0.0 and body.y+18.0>receiver.position.y+1.0 and not trace.full_support(exit_support):
			trace.fail("places_recovery_descended_below_crown")
		return true
	trace.fail("places_recovery_unknown_phase/"+str(trace.phase))
	return true

func _begin(trace: Node,leg: Dictionary) -> bool:
	active_leg = int(trace.leg_index)
	anchor_id = str(leg.get("anchor_id",""))
	entry_support = str(leg.get("from_support_id",leg.get("entry_support_id","")))
	exit_support = str(leg.get("landing_support_id",leg.get("support_id","")))
	var path: Array = leg.get("path",[])
	var landing: Array = leg.get("landing",[])
	if anchor_id.is_empty() or entry_support.is_empty() or exit_support.is_empty() or path.size()<2 or landing.size()!=2:
		trace.fail("places_recovery_missing_actual_edge_binding"); return false
	source = trace.point(path[0])
	goal = trace.point(landing)
	var row: Dictionary = trace.platform(exit_support)
	if row.is_empty(): trace.fail("places_recovery_actual_receiver_missing"); return false
	receiver = Rect2(float(row.rect[0]),float(row.rect[1]),float(row.rect[2]),float(row.rect[3]))
	var target: Node2D = trace.stage.assembler.hook_targets.get(anchor_id)
	if not is_instance_valid(target) or not target is GrappleAnchor or not (target as GrappleAnchor).hang_enabled:
		trace.fail("places_recovery_actual_anchor_not_fixed_hanging"); return false
	anchor_instance = target.get_instance_id()
	left_gate_end = -INF
	for support: Dictionary in trace.manifest.platforms:
		var rect := Rect2(float(support.rect[0]),float(support.rect[1]),float(support.rect[2]),float(support.rect[3]))
		if absf(rect.position.y-receiver.position.y)>0.1 or rect.end.x>=source.x: continue
		left_gate_end = maxf(left_gate_end,rect.end.x)
	launch_tick = -1
	cast_tick = -1
	hang_tick = -1
	hang_jump_tick = -1
	observed_cast = false
	observed_hang = false
	observed_hang_jump = false
	shoulder_cleared = false
	if str(trace.phase)!="align":
		trace.fail("places_recovery_must_begin_at_real_alignment"); return false
	return true

func _clear_corridor(body: Vector2,origin: Vector2,radius: float) -> bool:
	var body_above := body.y+18.0<=receiver.position.y-1.0
	var cast_above := origin.y+radius<=receiver.position.y-1.0
	var clear_right := body.x+12.0<=receiver.position.x-1.0 and origin.x+radius<=receiver.position.x-1.0
	var clear_left := not is_finite(left_gate_end) or (body.x-12.0>=left_gate_end+1.0 and origin.x-radius>=left_gate_end+1.0)
	return (body_above and cast_above) or (clear_left and clear_right)

func _has_event(trace: Node,kind: String,since: int) -> bool:
	for row: Dictionary in trace.events:
		if int(row.get("leg",-1))==active_leg and int(row.get("tick",-1))>=since and str(row.get("kind",""))==kind: return true
	return false

func _has_target_event(trace: Node,kind: String,since: int) -> bool:
	for row: Dictionary in trace.events:
		if int(row.get("leg",-1))==active_leg and int(row.get("tick",-1))>=since and str(row.get("kind",""))==kind and str(row.get("target",""))==anchor_id: return true
	return false
