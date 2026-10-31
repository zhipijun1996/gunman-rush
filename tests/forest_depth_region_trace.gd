extends Node
## V2 formal consumer only. No Motor stepping, coordinate writes or resource grants.
class Observer extends Node:
	var trace: Node
	func _physics_process(_delta: float) -> void: trace.observe()
var app: Node2D
var stage: Node2D
var player: PlayerMotor
var controller: PlayerController
var seed_value := "forest-depth-00"
var map_index := 1
var route_name := "fast"
var recorded_layout_version := ""
var manifest: Dictionary = {}
var itinerary: Array[Dictionary] = []
var frames: Array[Dictionary] = []
var events: Array[Dictionary] = []
var requests: Array[Dictionary] = []
var completed: Array[Dictionary] = []
var failures: Array[String] = []
var initial: Dictionary = {}
var finished := false
var initialized := false
var setup_done := false
var finish_pending := false
var duplicate_tick := -1
var duplicate_before: Dictionary = {}
var duplicate_after: Dictionary = {}
var tick := 0
var before_steps := 0
var leg_index := 0
var leg_started := 1
var phase := "align"
var age := 0
var stable := 0
var jump_released := false
var drop_cursor := 1
var last_drop_tick := -1000
var last_hook := ""
var canopy_lane_wait_leg := -1
var cache_claimed := false
var cache_pending := false
var modal_frames: Array[Dictionary] = []
var pointer_events: Array[Dictionary] = []
var modal_age := 0
var modal_button: Button
var modal_point := Vector2.ZERO
var claim_before: Dictionary = {}
var claim_after: Dictionary = {}
var duplicate_checked := false
var claim_local_id := "crown_cache"
var goal_changed := false
var cavity_cell := 0
var air_chain_case := preload("res://tests/forest_depth_air_chain_case.gd").new()
var grove_combat_case := preload("res://tests/forest_depth_grove_combat_case.gd").new()
var interwoven_crown_case := preload("res://tests/forest_interwoven_crown_combat_case.gd").new()
var movie_capture := OS.get_cmdline_user_args().has("--capture-movie")
func canopy_layout() -> bool:
	return manifest.get("layout_version") in ["forest-expedition-airborne-v11","forest-woven-trunk-v12","forest-interwoven-canopy-v13","forest-fruit-routes-v14"]
func interwoven_layout() -> bool:
	return manifest.get("layout_version") in ["forest-interwoven-canopy-v13","forest-fruit-routes-v14"]
func woven_layout() -> bool:
	return manifest.get("layout_version") in ["forest-woven-trunk-v12","forest-interwoven-canopy-v13","forest-fruit-routes-v14"]
func admission_evidence() -> Dictionary:
	return {}
func _ready() -> void:
	# Headless defaults to a 64px dummy window; use the project's actual UI device size.
	if DisplayServer.get_name()=="headless": get_window().size=Vector2i(int(ProjectSettings.get_setting("display/window/size/viewport_width",1280)),int(ProjectSettings.get_setting("display/window/size/viewport_height",720)))
	process_mode=Node.PROCESS_MODE_ALWAYS
	process_physics_priority=-100
	begin.call_deferred()
func begin() -> void:
	var script: Script=load("res://scripts/demo/demo_app.gd")
	if script==null or not script.can_instantiate(): fail("DemoApp_compile_failed");setup_done=true;return
	app=script.new();app.meta_persistence_enabled=false;add_child(app)
	if not app.start_debug_region(&"thorn_forest",map_index,seed_value,ThornForestRegionGenerator.DEPTH_VERSION,recorded_layout_version): fail("formal_debug_entry_rejected");setup_done=true;return
	for unused: int in 8: await get_tree().physics_frame
	stage=app.stage
	if not is_instance_valid(stage) or not stage.assembly_ok: fail("formal_v2_assembly_failed");setup_done=true;return
	player=app.player;controller=app.controller
	manifest=stage.generated.manifest.duplicate(true)
	if manifest.get("version")!=ThornForestRegionGenerator.DEPTH_VERSION or manifest.get("map_index")!=map_index or manifest.get("seed")!=ThornForestRegionGenerator.seed_for(seed_value,map_index): fail("actual_stage_identity_mismatch");setup_done=true;return
	player.get_node("KeyboardMouseAdapter").set_process_unhandled_input(false)
	var route_ids: Array=manifest.routes.get(route_name,[])
	if route_name=="upper_noH": route_ids=["arrival_reading","upper_out"]
	for id: String in route_ids:
		var edge: Dictionary={}
		for row: Dictionary in manifest.connections:
			if row.id==id: edge=row.duplicate(true)
		if edge.is_empty(): fail("missing_manifest_edge/"+id);break
		if edge.kind=="ordinary_sequence":
			for i: int in edge.steps.size():
				var step: Dictionary=edge.steps[i].duplicate(true);step.edge_id=id;step.step_index=i
				if i==0:
					for key: String in ["claim_before_edge","claim_area","claim_id"]:
						if edge.has(key): step[key]=edge[key]
				itinerary.append(step)
			itinerary.append({"kind":"walk","edge_id":id,"landing":edge.path[-1].duplicate(),"step_index":edge.steps.size()})
			if canopy_layout():itinerary[-1].b=edge.b
		else:
			edge.edge_id=id;edge.landing=edge.get("landing",edge.path[-1]).duplicate();itinerary.append(edge)
			if edge.has("post_landing_steps"):
				for i: int in edge.post_landing_steps.size():
					var step: Dictionary=edge.post_landing_steps[i].duplicate(true);step.edge_id=id;step.step_index=i;step.post_landing=true;itinerary.append(step)
			if edge.kind=="hollow_recovery": itinerary.append({"kind":"walk","edge_id":id,"landing":edge.path[-1].duplicate(),"post_recovery_align":true})
	if itinerary.is_empty(): fail("empty_manifest_itinerary")
	controller.traversal.action_changed.connect(_hook_event)
	controller.jump_ability.jumped.connect(func() -> void: event("jumped"))
	controller.shoot_ability.shot_fired.connect(func(aim: Vector2,serial: int) -> void:
		event("shot_fired",{"aim":pair(aim),"serial":serial})
		observe_actual_projectile(serial))
	controller.energy_recovered.connect(func(amount: float,airborne: bool) -> void:
		event("actual_shot_energy_credit",{"amount":amount,"fired_airborne":airborne,"owner_id":player.get_instance_id(),"session_id":controller.session_id,"hits":controller.shot_energy._hits.duplicate(true),"energy":controller.actor_resources.stamina.current}))
	app.policy.batch_resolved.connect(func(results: Array[DamageResult]) -> void:
		for result: DamageResult in results: event("committed_damage",{"target":String(result.request.target_id),"source":String(result.request.source_id),"amount":result.request.amount,"lethal":result.lethal,"event_id":String(result.request.event_id),"damage_kind":int(result.request.kind),"health_after":result.health.current if result.health!=null else -1.0}))
	initial=snapshot()
	var observer:=Observer.new();observer.trace=self;observer.process_physics_priority=1100;add_child(observer)
	initialized=true;setup_done=true
func observe_actual_projectile(serial: int) -> void:
	var matches: Array[PlayerProjectile]=[]
	for projectile: PlayerProjectile in controller.shoot_ability._projectiles:
		if is_instance_valid(projectile) and not projectile.spent and projectile.shot_id==serial: matches.append(projectile)
	if matches.size()!=1:
		fail("actual_emitted_projectile_identity_not_unique");return
	var projectile: PlayerProjectile=matches[0]
	event("actual_projectile_spawned",{"owner_id":projectile.owner_id,"session_id":projectile.session_id,"serial":projectile.shot_id,"packet":projectile.energy_receipt_id,"fired_airborne":projectile.fired_airborne,"lifetime":projectile.lifetime,"weapon_epoch":projectile.weapon_epoch,"projectile_position":pair(projectile.global_position),"direction":pair(projectile.direction)})
func pair(value: Vector2) -> Array: return [value.x,value.y]
func point(row: Array) -> Vector2: return Vector2(row[0],row[1])
func supports() -> Array[String]:
	var ids: Array[String]=[]
	if not is_instance_valid(player): return ids
	for i: int in player.get_slide_collision_count():
		var hit:=player.get_slide_collision(i)
		if hit.get_normal().dot(Vector2.UP)<0.7: continue
		var body:=hit.get_collider() as Node
		if body!=null:
			for id: Variant in body.get_meta("support_ids",[str(body.name)]):
				if str(id) not in ids: ids.append(str(id))
	return ids
func platform(id: String) -> Dictionary:
	for row: Dictionary in manifest.platforms:
		if row.id==id: return row
	return {}
func full_support(id: String) -> bool:
	var row:=platform(id)
	if row.is_empty() or not player.is_on_floor() or id not in supports(): return false
	var r:=Rect2(row.rect[0],row.rect[1],row.rect[2],row.rect[3]);var p:=player.global_position
	return p.x-12>=r.position.x-.1 and p.x+12<=r.end.x+.1 and absf(p.y+18-r.position.y)<1
func at_destination(destination: Vector2, id := "") -> bool:
	if not player.is_on_floor() or absf(player.global_position.x-destination.x)>7 or absf(player.global_position.y-destination.y)>2: return false
	if not id.is_empty(): return full_support(id)
	for support: String in supports():
		if full_support(support): return true
	return false
func event(kind: String, extra: Dictionary={}) -> void:
	var row: Dictionary={"tick":tick,"leg":leg_index,"kind":kind}
	if is_instance_valid(player): row.position=pair(player.global_position)
	movie_stamp(row)
	row.merge(extra,true);events.append(row)
func movie_stamp(row: Dictionary) -> void:
	if movie_capture:
		row.presentation_frame=Engine.get_frames_drawn()
		row.process_frame=Engine.get_process_frames()
func request(kind: StringName, aim:=Vector2.ZERO) -> void:
	# Preserve caller intent separately from the actual normalized Router packet.
	var input_aim := pair(aim)
	var queued := controller.router.request_action(kind,aim)
	var row := {"tick":tick,"leg":leg_index,"phase":phase,"kind":String(kind),"input_aim":input_aim,"aim":input_aim,"queued":queued}
	if queued:
		if controller.router._queue.is_empty(): fail("queued_action_missing_actual_router_packet");return
		var actual: Dictionary=controller.router._queue.back()
		row.aim=pair(actual.direction)
		row.router_type=String(actual.type)
		row.router_sequence=int(actual.sequence)
		row.router_epoch=int(actual.epoch)
	requests.append(row)
	movie_stamp(requests[-1])
	if leg_index<itinerary.size() and itinerary[leg_index].kind=="hollow_cavity" and itinerary[leg_index].get("motion","")=="descending_elbow":
		requests[-1].merge({"body_before":pair(player.global_position),"velocity_before":pair(player.velocity),"grounded_before":player.is_on_floor(),"hook_origin_before":pair(player.global_position+Vector2(0,-6))})
func jump(held: bool) -> void:
	controller.router.set_jump_held(&"forest_depth_route",held)
	requests.append({"tick":tick,"leg":leg_index,"kind":"jump_held","held":held})
	movie_stamp(requests[-1])
func hook(id: String) -> bool:
	last_hook=""
	var target: Node2D=stage.assembler.hook_targets.get(id)
	if not is_instance_valid(target): fail("missing_actual_anchor/"+id);return false
	request(&"grapple",(target.global_position-player.global_position-Vector2(0,-6)).normalized());return true
func _hook_event(state: StringName) -> void:
	_observe_crossbranch_hook(state)
	var target:=controller.traversal.hook_target
	last_hook=String(state)
	event(String(state),{"target":String(target.name) if is_instance_valid(target) else ""})
	# Legacy relay misses need the same actual endpoint evidence as air chains.
	events[-1].merge({"hook_tip":pair(controller.traversal.hook_tip),"hook_used_at_event":controller.traversal.hook_used,"can_air_jump_at_event":controller.jump_ability.can_air_jump(),"used_jumps_at_event":controller.jump_ability.used_jumps})
func set_phase(next: String) -> void:
	event("phase",{"from":phase,"to":next});phase=next;age=0;stable=0;jump_released=false
func fail(reason: String) -> void:
	if reason not in failures: failures.append(reason)
	finished=true
	if is_instance_valid(controller): controller.router.clear("forest_depth_failure")
func complete_leg() -> void:
	var current: Dictionary=itinerary[leg_index]
	if route_name=="change_mind" and not goal_changed and str(current.get("b",""))==str(manifest.get("change_mind_contract",{}).get("decision_node","")):
		var fast_ids: Array=manifest.routes.fast
		var at:=fast_ids.find(str(current.edge_id))
		if at<0 or at+1>=fast_ids.size() or leg_index+1>=itinerary.size(): fail("change_mind_original_plan_missing");return
		var actual_next: String=str(itinerary[leg_index+1].edge_id)
		if actual_next==str(fast_ids[at+1]): fail("change_mind_did_not_change_edge");return
		event("actual_route_goal_changed",{"decision_node":current.b,"planned_goal":"gate_ready","chosen_goal":"camp","original_next_edge":fast_ids[at+1],"actual_next_edge":actual_next,"supports":supports()})
		goal_changed=true
	completed.append({"leg":leg_index,"edge_id":itinerary[leg_index].edge_id,"start_tick":leg_started,"tick":tick,"position":pair(player.global_position),"supports":supports()})
	controller.router.set_move_axis(0);jump(false);leg_index+=1;leg_started=tick+1;drop_cursor=1;set_phase("align")
	if leg_index>=itinerary.size(): finish_pending=true
func _physics_process(_delta: float) -> void:
	if not initialized or finished or get_tree().paused: return
	if not is_instance_valid(player) or not is_instance_valid(controller) or not app.lifetime.active: fail("actual_run_ended");return
	tick+=1;age+=1;before_steps=player.motion_steps
	if tick>18000: fail("route_tick_budget");return
	if tick-leg_started>1800: fail("edge_tick_budget/"+str(leg_index)+"/"+phase);return
	if leg_index>=itinerary.size(): fail("unexpected_empty_remaining_itinerary");return
	var leg: Dictionary=itinerary[leg_index]
	if (leg.kind=="narrow_return" or bool(leg.get("claim_before_edge",false))) and not duplicate_checked:
		claim_local_id=str(leg.get("claim_id","crown_cache"));drive_cache();return
	if interwoven_crown_case.drive(self,leg):return
	if canopy_layout() and grove_combat_case.drive(self,leg):return
	match str(leg.kind):
		"walk": drive_walk(point(leg.landing))
		"drop","drop_through": drive_drop(leg)
		"jump_gap","jump_rise","jump_rise_through_gap": drive_jump(leg)
		"directional_phrase","directional_return","narrow_reward","narrow_return": drive_phrase(leg)
		"hollow_upper","hollow_lower","hollow_recovery","hollow_drop","hollow_outer_recovery":
			if route_name=="upper_noH": drive_upper_noH(leg)
			else: drive_hollow(leg)
		"hollow_cavity": drive_cavity_kind(leg)
		"airborne_chain", "hanging_chain":
			if not _wait_canopy_crossbranch_lane(leg) and not _drive_canopy_bark_high_launch(leg):air_chain_case.drive(self,leg)
		"candidate_hook_relay": drive_candidate_relay(leg)
		"gate_hook": drive_gate(leg)
		"ecology_choice","ecology_return": drive_ecology(leg)
		"crossbranch_crossing":
			if _bind_recorded_crossbranch():_crossbranch_outbound()
			else:fail("recorded_crossbranch_contract_missing")
		"crossbranch_return":
			if _bind_recorded_crossbranch():_crossbranch_return()
			else:fail("recorded_crossbranch_contract_missing")
		"drop_recovery": drive_recovery_edge(leg)
		_: fail("unsupported_manifest_connection/"+str(leg.kind))
func drive_walk(destination: Vector2) -> void:
	controller.router.set_move_axis(clampf((destination.x-player.global_position.x)/12,-1,1))
	stable=stable+1 if at_destination(destination) else 0
	if stable>=12: complete_leg()
func _wait_canopy_crossbranch_lane(leg: Dictionary) -> bool:
	# Observe the real passing body from the actual launch bank before committing
	# R-H-R. An airborne pause would spend the jump while the cast lane is blocked.
	var program: Array=leg.get("action_program",[])
	if not interwoven_layout() or str(leg.get("geometry_instance",""))!="canopy_fork" or phase!="align" or stable<12 or program.size()!=3:return false
	if str(program[0].get("action",""))!="R" or str(program[1].get("action",""))!="H" or str(program[2].get("action",""))!="R":return false
	var support_id := str(leg.get("from_support_id",""))
	if not full_support(support_id) or absf(player.velocity.x)>=1:return false
	var enemy_id := str(manifest.get("crossbranch_contract",{}).get("enemy_id",""))
	var passing: EnemyActor
	for index: int in stage.enemy_manifest.size():
		if str(stage.enemy_manifest[index].id)==enemy_id:passing=stage.enemies[index].get_node("Actor") as EnemyActor
	if not is_instance_valid(passing) or passing.health.terminal or not passing.attack_behavior is ForestCrossbranchBehavior:return false
	var behavior := passing.attack_behavior as ForestCrossbranchBehavior
	var npc: Vector2=passing.motor.global_position
	var body: Vector2=passing.definition.collision_size
	var clearance: float=controller.traversal.definition.hook_capture_radius
	var wholly_left := npc.x+body.x*.5 < player.global_position.x-clearance
	var moving_away := behavior.state==&"flight" and behavior.flight_velocity.x<0
	var on_far_shore := behavior.current_shore==1 and behavior._on_shore(1)
	var observation := {"enemy_id":enemy_id,"enemy_position":pair(npc),"enemy_body":pair(body),"enemy_health":passing.health.current,"enemy_state":String(behavior.state),"enemy_velocity":pair(behavior.flight_velocity),"current_shore":behavior.current_shore,"committed_shore":behavior.committed_shore,"whole_body_left":wholly_left,"hook_capture_radius":clearance,"supports":supports(),"snapshot":snapshot(),"phase_age":age}
	if wholly_left and (moving_away or on_far_shore):
		if canopy_lane_wait_leg==leg_index:event("canopy_crossbranch_lane_clear",observation)
		return false
	controller.router.set_move_axis(0)
	if canopy_lane_wait_leg!=leg_index:
		canopy_lane_wait_leg=leg_index
		event("canopy_crossbranch_lane_wait",observation)
	# This wait never resets the original phase age or the global edge budget.
	if age>400:fail("air_chain_bounded_phase/"+phase)
	return true
func _drive_canopy_bark_high_launch(leg: Dictionary) -> bool:
	# Candidate ecology strategy: use the real jump's height before the
	# horizontal recoil, rather than flying through the patrolling shield.
	var program: Array=leg.get("action_program",[])
	if not woven_layout() or str(leg.get("geometry_instance",""))!="canopy_fork" or phase!="air_chain_launch" or program.size()!=2:return false
	if str(program[0].get("action",""))!="R" or str(program[1].get("action",""))!="H":return false
	var keeper: EnemyActor
	for i: int in stage.enemy_manifest.size():
		if str(stage.enemy_manifest[i].id)=="upper_spiral_bark_keeper":keeper=stage.enemies[i].get_node("Actor") as EnemyActor
	if not is_instance_valid(keeper) or keeper.health.terminal:
		fail("canopy_bark_launch_actual_keeper_missing");return true
	var keeper_top:=keeper.motor.global_position.y-keeper.definition.collision_size.y*.5
	var foot:=player.global_position+Vector2(0,18)
	var required_gap:=80.0
	controller.router.set_move_axis(0)
	if foot.y<=keeper_top-required_gap and player.normal_velocity.y<0:
		event("canopy_bark_high_launch_observed",{"enemy_id":"upper_spiral_bark_keeper","enemy_position":pair(keeper.motor.global_position),"enemy_body":pair(keeper.definition.collision_size),"enemy_top":keeper_top,"foot":pair(foot),"required_gap":required_gap,"actual_gap":keeper_top-foot.y,"velocity":pair(player.velocity),"supports":supports()})
		jump(false);air_chain_case._submit(self)
	elif age>8 and player.normal_velocity.y>=0:fail("canopy_bark_launch_headroom_not_reached")
	return true

func drive_drop(leg: Dictionary) -> void:
	var path: Array=leg.path
	if path.size()<2 or drop_cursor>=path.size(): fail("malformed_drop_path");return
	var target:=point(path[drop_cursor])
	controller.router.set_move_axis(clampf((target.x-player.global_position.x)/12,-1,1))
	if path.size()>2 and drop_cursor==1:
		# First point is the horizontal mouth, not a fabricated standing ledge.
		# Complete the next vertical point before turning toward the final shore.
		if absf(player.global_position.x-target.x)<7:
			event("drop_mouth_reached",{"path_index":drop_cursor,"planned":path[drop_cursor].duplicate(),"axis_clearance_only":true})
			drop_cursor+=1;set_phase("drop_path")
		return
	if player.is_on_floor() and player.global_position.y<target.y-20 and tick-last_drop_tick>=20:
		request(&"drop_through");last_drop_tick=tick
	stable=stable+1 if at_destination(target) else 0
	if drop_cursor==path.size()-1:
		if stable>=12: complete_leg()
	elif stable>=3:
		event("drop_supported_waypoint",{"path_index":drop_cursor,"planned":path[drop_cursor].duplicate(),"supports":supports()})
		drop_cursor+=1;set_phase("drop_path")
func drive_jump(leg: Dictionary) -> void:
	var takeoff:=point(leg.takeoff);var landing:=point(leg.landing)
	if phase=="align":
		controller.router.set_move_axis(clampf((takeoff.x-player.global_position.x)/12,-1,1))
		if at_destination(takeoff,str(leg.from_support_id)) and player.recoil_burst_remaining<=0:
			jump(true);set_phase("jumping")
	else:
		if leg.kind=="jump_rise_through_gap" and phase=="jumping":
			controller.router.set_move_axis(clampf((takeoff.x-player.global_position.x)/12,-1,1))
			var clearance: Array=leg.clearance_x
			if player.global_position.y+18<=float(leg.clear_feet_y)-1 and player.global_position.x-12>=float(clearance[0]) and player.global_position.x+12<=float(clearance[1]):
				event("actual_gap_body_clearance",{"clear_feet_y":leg.clear_feet_y,"clearance_x":clearance.duplicate(),"foot":pair(player.global_position+Vector2(0,18))});set_phase("gap_cleared")
			elif age>120 or (age>8 and player.velocity.y>0): fail("bounded_gap_body_clearance_failed")
			return
		controller.router.set_move_axis(clampf((landing.x-player.global_position.x)/12,-1,1))
		if leg.kind=="jump_gap":
			release_gap_before_ceiling(str(leg.support_id))
			if not (canopy_layout() and leg.get("hold_to_receiver",false)):
				release_gap_after_vertical_clearance(str(leg.support_id))
		release_jump_after_clearance(str(leg.support_id))
		stable=stable+1 if at_destination(landing,str(leg.support_id)) else 0
		if stable>=12: complete_leg()
func release_gap_after_vertical_clearance(support_id: String) -> void:
	if jump_released or age<int(ceil(player.tuning.jump_hold_duration*Engine.physics_ticks_per_second)): return
	var target:=platform(support_id)
	if target.is_empty(): return
	var foot:=player.global_position+Vector2(0,18)
	# A gap is crossed horizontally while airborne. Waiting for the entire
	# destination footprint can hold jump until a far wall and landing.
	if foot.y>float(target.rect[1])-1 or player.velocity.y>=0: return
	event("jump_gap_vertical_clearance_release",{"support_id":support_id,"target_rect":target.rect.duplicate(),"foot":pair(foot),"velocity":pair(player.velocity),"held_ticks":age,"minimum_hold_ticks":int(ceil(player.tuning.jump_hold_duration*Engine.physics_ticks_per_second))})
	jump(false);jump_released=true
func release_gap_before_ceiling(support_id: String) -> void:
	if jump_released or player.velocity.y>=0: return
	var target:=platform(support_id)
	if target.is_empty(): return
	var foot:=player.global_position+Vector2(0,18)
	if foot.y>float(target.rect[1])-1: return
	var head:=player.global_position.y-18
	var next_up: float=absf(player.velocity.y)/float(Engine.physics_ticks_per_second)
	for ceiling: Dictionary in manifest.platforms:
		if bool(ceiling.get("one_way",false)): continue
		var rect:=Rect2(ceiling.rect[0],ceiling.rect[1],ceiling.rect[2],ceiling.rect[3])
		if player.global_position.x+12<=rect.position.x or player.global_position.x-12>=rect.end.x: continue
		var space:=head-rect.end.y
		if space>=0 and space<=next_up+1:
			event("jump_gap_release_before_ceiling",{"support_id":support_id,"target_rect":target.rect.duplicate(),"foot":pair(foot),"ceiling_id":ceiling.id,"ceiling_rect":ceiling.rect.duplicate(),"head_clearance":space,"velocity":pair(player.velocity)})
			jump(false);jump_released=true;return
func release_jump_after_clearance(support_id: String) -> void:
	var target:=platform(support_id)
	if target.is_empty(): fail("jump_target_support_missing/"+support_id);return
	var rect:=Rect2(target.rect[0],target.rect[1],target.rect[2],target.rect[3])
	var body_foot:=player.global_position+Vector2(0,18)
	var horizontal_clear:=player.global_position.x-12>=rect.position.x-.1 and player.global_position.x+12<=rect.end.x+.1
	if not jump_released and age>=int(ceil(player.tuning.jump_hold_duration*Engine.physics_ticks_per_second)) and body_foot.y<=rect.position.y-1 and horizontal_clear:
		event("jump_clearance_release",{"support_id":support_id,"foot":pair(body_foot),"target_top":rect.position.y,"target_rect":target.rect.duplicate()})
		jump(false);jump_released=true
	if age>120: fail("bounded_jump_clearance_timeout/"+support_id);return
	if age>3:
		for index: int in player.get_slide_collision_count():
			if player.get_slide_collision(index).get_normal().y>.7 and not full_support(support_id):
				fail("jump_ceiling_blocked/"+support_id);return
	if age>8 and not player.is_on_floor() and player.velocity.y>0 and body_foot.y>rect.position.y+1:
		fail("jump_descending_below_target/"+support_id)
	elif age>20 and player.is_on_floor() and support_id not in supports():
		fail("jump_landed_on_wrong_support/"+support_id)
func instance(leg: Dictionary) -> Dictionary:
	for row: Dictionary in manifest.geometry_instances:
		if row.id==leg.geometry_instance: return row
	return {}
func local_point(row: Dictionary, value: Array) -> Vector2: return point(value)+point(row.translation)
func mapped_support(row: Dictionary, id: String) -> String: return str(row.platform_id_map.get(id,""))
func mapped_hook(row: Dictionary, id: String) -> bool: return hook(str(row.anchor_id_map.get(id,"")))
func drive_phrase(leg: Dictionary) -> void:
	var row:=instance(leg)
	if row.is_empty(): fail("missing_geometry_instance");return
	var raw: Dictionary=row.local_geometry
	var origin:=local_point(row,raw.spawn)
	var goal:=local_point(row,raw.goal)
	var returning: bool=leg.kind in ["directional_return","narrow_return"]
	var narrow: bool=leg.kind in ["narrow_reward","narrow_return"]
	var pos:=player.global_position
	if phase=="align":
		var start:=goal if returning else origin
		var support:=mapped_support(row,"crown" if returning else "entry")
		controller.router.set_move_axis(clampf((start.x-pos.x)/12,-1,1))
		stable=stable+1 if at_destination(start,support) else 0
		if stable>=12:
			if returning: set_phase("bank_drop" if narrow else "return_drop")
			else: jump(true);set_phase("launch")
	elif phase=="launch":
		controller.router.set_move_axis(0)
		if pos.y<=origin.y-50 and player.velocity.y<0:
			jump(false);mapped_hook(row,"side_ring");set_phase("side_hook")
	elif phase=="side_hook":
		if controller.traversal.state==&"free" and last_hook=="free" and age>12:
			request(&"shoot_release",Vector2.LEFT);set_phase("recoil_out")
	elif phase=="recoil_out":
		if player.recoil_burst_remaining<=0 and age>3:
			if narrow: set_phase("land_goal")
			else: mapped_hook(row,"arch_exit_ring");set_phase("arch_hook")
	elif phase=="arch_hook":
		if controller.traversal.state==&"free" and last_hook=="free" and age>12:
			mapped_hook(row,"crown_ring");set_phase("crown_hook")
	elif phase=="crown_hook":
		if controller.traversal.state==&"free" and last_hook=="free" and age>12: set_phase("land_goal")
	elif phase=="land_goal":
		controller.router.set_move_axis(clampf((goal.x-pos.x)/20,-1,1))
		stable=stable+1 if at_destination(goal,mapped_support(row,"crown")) else 0
		if stable>=12: complete_leg()
	elif phase=="return_drop":
		controller.router.set_move_axis(-1 if pos.x>origin.x+float(raw["return"].drop_outside_x) else 0)
		if pos.y>origin.y+float(raw["return"].cast_below_y):
			controller.router.set_move_axis(0);mapped_hook(row,str(raw["return"].catch_anchor_id));set_phase("return_catch")
	elif phase=="return_catch":
		if controller.traversal.state==&"free" and last_hook=="free" and age>12: mapped_hook(row,str(raw["return"].anchor_id));set_phase("return_hook")
	elif phase=="return_hook":
		if controller.traversal.state==&"free" and last_hook=="free" and age>12: request(&"shoot_release",Vector2.RIGHT);set_phase("return_land")
	elif phase=="return_land":
		controller.router.set_move_axis(clampf((origin.x-pos.x)/20,-1,1))
		stable=stable+1 if at_destination(origin,mapped_support(row,"entry")) else 0
		if stable>=12: complete_leg()
	elif phase=="bank_drop":
		controller.router.set_move_axis(1 if pos.x<origin.x+float(raw["return"].drop_outside_x) else 0)
		if full_support(mapped_support(row,"recovery")): set_phase("recover_walk")
	else: drive_factory_recovery(row,origin)
func drive_factory_recovery(row: Dictionary, goal: Vector2) -> void:
	var recovery: Dictionary=row.local_geometry.recovery
	var at:=point(row.translation)+Vector2(float(recovery.walk_x),0)
	if phase=="recover_walk":
		controller.router.set_move_axis(clampf((at.x-player.global_position.x)/12,-1,1))
		if full_support(mapped_support(row,"recovery")) and absf(player.global_position.x-at.x)<4: controller.router.set_move_axis(0);jump(true);set_phase("recover_step")
	elif phase=="recover_step":
		release_jump_after_clearance(mapped_support(row,"recovery_step"))
		stable=stable+1 if full_support(mapped_support(row,"recovery_step")) else 0
		if stable>=6: jump(true);set_phase("recover_entry")
	elif phase=="recover_entry":
		controller.router.set_move_axis(clampf((goal.x-player.global_position.x)/20,-1,1))
		release_jump_after_clearance(mapped_support(row,"entry"))
		stable=stable+1 if at_destination(goal,mapped_support(row,"entry")) else 0
		if stable>=12: complete_leg()
func drive_upper_noH(leg: Dictionary) -> void:
	var row:=instance(leg)
	if row.is_empty() or leg.kind!="hollow_upper": fail("upper_noH_wrong_actual_edge");return
	var origin:=point(row.translation)
	var goal:=point(leg.landing)
	var entry:=mapped_support(row,"belly_entry")
	var crown:=mapped_support(row,"outer_crown")
	var takeoff:=origin+Vector2(68,0)
	if phase=="align":
		controller.router.set_move_axis(clampf((takeoff.x-player.global_position.x)/12,-1,1))
		stable=stable+1 if at_destination(takeoff,entry) else 0
		if stable>=12:
			event("upper_noH_actual_takeoff",{"foot":pair(player.global_position+Vector2(0,18)),"supports":supports()})
			controller.router.set_move_axis(1);jump(true);set_phase("upper_noH_jump")
	elif phase=="upper_noH_jump":
		controller.router.set_move_axis(1)
		if age==6:
			event("upper_noH_release_and_R",{"held_ticks":6,"foot":pair(player.global_position+Vector2(0,18))})
			jump(false);request(&"shoot_release",Vector2.LEFT);set_phase("upper_noH_coast")
	elif phase=="upper_noH_coast":
		controller.router.set_move_axis(clampf((goal.x-player.global_position.x)/12,-1,1))
		stable=stable+1 if at_destination(goal,crown) else 0
		if stable>=12: complete_leg()
		elif age>240: fail("bounded_upper_noH_single_attempt_missed")
func drive_hollow_cavity(leg: Dictionary) -> void:
	# Exact standing-H choreography, with the actual formal manifest translation.
	# This new kind does not change any existing leg driver/assertion.
	var row:=instance(leg)
	if row.is_empty():fail("cavity_missing_actual_instance");return
	var raw: Dictionary=row.local_geometry
	if not raw.has("cavity_contract") or not raw.nodes.has("B") or leg.get("from_port")!="S" or leg.get("to_port")!="C":fail("cavity_manifest_port_contract");return
	var start:=local_point(row,raw.nodes.S.position)
	var goal:=point(leg.landing)
	var bay:=local_point(row,raw.nodes.B.position)
	var first_support:=mapped_support(row,str(raw.nodes.S.support_id))
	var bay_support:=mapped_support(row,str(raw.nodes.B.support_id))
	var last_support:=str(leg.get("landing_support_id",mapped_support(row,str(raw.nodes.C.support_id))))
	if age>300:fail("bounded_cavity_phase/"+phase);return
	if phase=="align":
		controller.router.set_move_axis(clampf((start.x-player.global_position.x)/12,-1,1))
		stable=stable+1 if full_support(first_support) and absf(start.x-player.global_position.x)<.15 and absf(player.velocity.x)<1 else 0
		if stable>=12:
			event("hollow_port_departure",{"geometry_instance":row.id,"port":"S","support_id":first_support,"method":"standing_H_then_free_R"})
			cavity_cell=0;controller.router.set_move_axis(0)
			mapped_hook(row,"cavity_ring_a");set_phase("cavity_pull")
	elif phase=="cavity_pull":
		controller.router.set_move_axis(0)
		if controller.traversal.state==&"free" and last_hook=="free" and age>12:
			request(&"shoot_release",Vector2.LEFT);set_phase("cavity_cross")
	elif phase=="cavity_cross":
		var target:=bay if cavity_cell==0 else goal
		var support_id:=bay_support if cavity_cell==0 else last_support
		controller.router.set_move_axis(clampf((target.x-player.global_position.x)/12,-1,1))
		stable=stable+1 if at_destination(target,support_id) else 0
		if stable>=12:
			if cavity_cell==0:
				event("cavity_bay_support",{"geometry_instance":row.id,"support_id":bay_support,"standing_destination":pair(bay)})
				cavity_cell=1;controller.router.set_move_axis(0)
				mapped_hook(row,"cavity_ring_b");set_phase("cavity_pull")
			else:
				event("hollow_port_arrival",{"geometry_instance":row.id,"port":"C","support_id":last_support})
				complete_leg()

func drive_cavity_kind(leg: Dictionary) -> void:
	var row:=instance(leg)
	if not row.is_empty() and row.local_geometry.get("cavity_contract",{}).get("variant","")=="horizontal_then_airborne_descending_elbow":
		drive_hollow_cavity_elbow(leg)
	elif leg.get("motion","")=="descending_elbow":
		fail("cavity_elbow_shape_motion_mismatch")
	else:
		drive_hollow_cavity(leg)

func drive_hollow_cavity_elbow(leg: Dictionary) -> void:
	# A2: first standing H/R, then supported B observation and actual airborne side H/R.
	# Original level choreography and its guards remain a separate branch.
	var row:=instance(leg)
	if row.is_empty():fail("cavity_missing_actual_instance");return
	var raw: Dictionary=row.local_geometry
	if raw.get("cavity_contract",{}).get("variant","")!="horizontal_then_airborne_descending_elbow" or leg.get("motion","")!="descending_elbow" or leg.get("from_port")!="S" or leg.get("to_port")!="C":fail("cavity_elbow_manifest_contract");return
	var start:=local_point(row,raw.nodes.S.position)
	var goal:=point(leg.landing)
	var bay:=local_point(row,raw.nodes.B.position)
	var first_support:=mapped_support(row,str(raw.nodes.S.support_id))
	var bay_support:=mapped_support(row,str(raw.nodes.B.support_id))
	var last_support:=str(leg.get("landing_support_id",mapped_support(row,str(raw.nodes.C.support_id))))
	if age>300:fail("bounded_cavity_phase/"+phase);return
	if phase=="align":
		controller.router.set_move_axis(clampf((start.x-player.global_position.x)/12,-1,1))
		stable=stable+1 if full_support(first_support) and absf(start.x-player.global_position.x)<.15 and absf(player.velocity.x)<1 else 0
		if stable>=12:
			event("hollow_port_departure",{"geometry_instance":row.id,"port":"S","support_id":first_support,"method":"standing_H_then_free_R"})
			cavity_cell=0;controller.router.set_move_axis(0)
			mapped_hook(row,"cavity_ring_a");set_phase("cavity_pull")
	elif phase=="cavity_pull":
		controller.router.set_move_axis(0)
		if controller.traversal.state in [&"hook_miss",&"hook_retract"]:fail("cavity_elbow_actual_hook_failed/"+String(controller.traversal.state));return
		if controller.traversal.state==&"free" and last_hook=="free" and age>12:
			request(&"shoot_release",Vector2.LEFT);set_phase("cavity_cross")
	elif phase=="cavity_cross":
		var target:=bay if cavity_cell==0 else goal
		var support_id:=bay_support if cavity_cell==0 else last_support
		controller.router.set_move_axis(clampf((target.x-player.global_position.x)/12,-1,1))
		stable=stable+1 if at_destination(target,support_id) else 0
		if stable>=12:
			if cavity_cell==0:
				event("cavity_bay_support",{"geometry_instance":row.id,"support_id":bay_support,"standing_destination":pair(bay)})
				cavity_cell=1;controller.router.set_move_axis(0)
				set_phase("cavity_elbow_walkoff")
			else:
				event("hollow_port_arrival",{"geometry_instance":row.id,"port":"C","support_id":last_support})
				complete_leg()

	elif phase=="cavity_elbow_walkoff":
		var support_row:=platform(bay_support)
		if support_row.is_empty():fail("cavity_elbow_bay_missing");return
		var rect:=Rect2(support_row.rect[0],support_row.rect[1],support_row.rect[2],support_row.rect[3])
		controller.router.set_move_axis(1)
		if not player.is_on_floor() and player.global_position.x-12>=rect.end.x:
			controller.router.set_move_axis(0)
			event("cavity_airborne_departure",{"geometry_instance":row.id,"grounded":player.is_on_floor(),"velocity":pair(player.velocity),"bay_rect":support_row.rect.duplicate(),"method":"walk_off_then_side_H"})
			if mapped_hook(row,"cavity_ring_b"):set_phase("cavity_pull")

func drive_hollow(leg: Dictionary) -> void:
	# Same actual shared factory, embedded by the formal Stage assembler. Local
	# coordinates come from that instance, never a second naked golden world.
	var row:=instance(leg)
	if row.is_empty(): fail("missing_hollow_instance");return
	var raw: Dictionary=row.local_geometry
	var nodes: Dictionary=raw.get("nodes",{})
	var from_port: String=str(leg.get("from_port","R" if leg.kind=="hollow_outer_recovery" else ""))
	var to_port: String=str(leg.get("to_port","D" if leg.kind=="hollow_outer_recovery" else ""))
	if not nodes.has(from_port) or not nodes.has(to_port): fail("hollow_port_missing");return
	var start:=local_point(row,nodes[from_port].position)
	var goal:=point(leg.landing)
	var from_support:=mapped_support(row,str(nodes[from_port].support_id))
	var to_support:=str(leg.get("landing_support_id",mapped_support(row,str(nodes[to_port].support_id))))
	var local_pos:=player.global_position-point(row.translation)
	if age>360: fail("bounded_hollow_phase/"+phase);return
	if phase=="align":
		controller.router.set_move_axis(clampf((start.x-player.global_position.x)/12,-1,1))
		stable=stable+1 if at_destination(start,from_support) else 0
		if stable>=12:
			event("hollow_port_departure",{"geometry_instance":row.id,"port":from_port,"support_id":from_support})
			if leg.kind=="hollow_upper" and from_port=="M" and to_port=="E":
				controller.router.set_move_axis(0);jump(true);set_phase("hollow_launch")
			elif leg.kind=="hollow_lower" and from_port=="E" and to_port=="D": set_phase("hollow_depart")
			elif leg.kind=="hollow_recovery" and from_port=="D" and to_port=="M": set_phase("hollow_inner_walk")
			elif leg.kind=="hollow_drop" and from_port=="E" and to_port=="R": set_phase("hollow_outer_drop")
			elif leg.kind=="hollow_outer_recovery": set_phase("hollow_outer_takeoff")
			else: fail("unsupported_hollow_port_pair/"+from_port+"/"+to_port)
	elif phase=="hollow_launch":
		controller.router.set_move_axis(0)
		if player.global_position.y<=start.y-50 and player.velocity.y<0:
			jump(false);set_phase("hollow_upper_cast")
		elif age>30: fail("hollow_launch_failed")
	elif phase=="hollow_upper_cast":
		mapped_hook(row,"upper_window_ring");set_phase("hollow_upper_hook")
	elif phase=="hollow_upper_hook":
		controller.router.set_move_axis(0)
		if controller.traversal.state==&"free" and last_hook=="free" and age>12:
			request(&"shoot_release",Vector2.LEFT);set_phase("hollow_upper_land")
	elif phase=="hollow_upper_land":
		controller.router.set_move_axis(clampf((goal.x-player.global_position.x)/12,-1,1))
		if full_support(mapped_support(row,"inner_root")): fail("hollow_upper_missed_inner_root");return
		stable=stable+1 if at_destination(goal,to_support) else 0
		if stable>=12: event("hollow_port_arrival",{"geometry_instance":row.id,"port":to_port,"support_id":to_support});complete_leg()
	elif phase=="hollow_depart":
		var crown_rect: Array=platform(from_support).rect
		var departure:=Vector2(float(crown_rect[0])+13,start.y)
		controller.router.set_move_axis(clampf((departure.x-player.global_position.x)/12,-1,1))
		if absf(player.global_position.x-departure.x)<2 and full_support(from_support) and age>8:
			controller.router.set_move_axis(0);request(&"drop_through");set_phase("hollow_descent")
	elif phase=="hollow_descent":
		controller.router.set_move_axis(0)
		var lower_window: Dictionary=raw.windows.filter(func(w: Dictionary) -> bool: return w.id=="lower_window")[0]
		if local_pos.y>=float(lower_window.clear_rect[1])+18:
			mapped_hook(row,"lower_window_ring");set_phase("hollow_lower_hook")
	elif phase=="hollow_lower_hook":
		controller.router.set_move_axis(0)
		if controller.traversal.state==&"free" and last_hook=="free" and age>12: set_phase("hollow_lower_land")
	elif phase=="hollow_lower_land":
		controller.router.set_move_axis(clampf((goal.x-player.global_position.x)/12,-1,1))
		for wrong: String in ["trunk_below_window","outer_sump","outer_root","outer_recovery_step"]:
			if full_support(mapped_support(row,wrong)): fail("hollow_lower_missed_reception/"+wrong);return
		stable=stable+1 if at_destination(goal,to_support) else 0
		if stable>=12: event("hollow_port_arrival",{"geometry_instance":row.id,"port":to_port,"support_id":to_support});complete_leg()
	elif phase=="hollow_inner_walk":
		var step_rect: Array=raw.platforms.filter(func(p: Dictionary) -> bool: return p.id=="inner_recovery_step")[0].rect
		var takeoff_x:=float(step_rect[0])+float(step_rect[2])*.5
		controller.router.set_move_axis(clampf((takeoff_x-local_pos.x)/12,-1,1))
		if absf(local_pos.x-takeoff_x)<4 and full_support(from_support):
			controller.router.set_move_axis(0);jump(true);set_phase("hollow_inner_step")
	elif phase=="hollow_inner_step":
		release_jump_after_clearance(mapped_support(row,"inner_recovery_step"))
		stable=stable+1 if full_support(mapped_support(row,"inner_recovery_step")) else 0
		if stable>=6: jump(true);set_phase("hollow_belly_land")
	elif phase=="hollow_belly_land":
		# The body clears the roof/side from the factory's broad left belly bank
		# before walking to M; aiming at M mid-jump would hit the solid side.
		var bank: Dictionary=platform(to_support)
		var safe_x:=float(bank.rect[0])+40
		controller.router.set_move_axis(clampf((safe_x-player.global_position.x)/12,-1,1))
		release_jump_after_clearance(to_support)
		stable=stable+1 if full_support(to_support) else 0
		if stable>=12:
			jump(false);event("hollow_port_arrival",{"geometry_instance":row.id,"port":to_port,"support_id":to_support});complete_leg()
	elif phase=="hollow_outer_takeoff":
		var takeoff:=point(leg.path[1])
		controller.router.set_move_axis(clampf((takeoff.x-player.global_position.x)/12,-1,1))
		if at_destination(takeoff,from_support): jump(true);set_phase("hollow_outer_launch")
	elif phase=="hollow_outer_launch":
		controller.router.set_move_axis(-1)
		var lower_id:=str(row.anchor_id_map.get("lower_window_ring",""))
		var anchor: Node2D=stage.assembler.hook_targets.get(lower_id)
		if not is_instance_valid(anchor): fail("hollow_outer_missing_anchor");return
		var offset:=anchor.global_position-player.global_position-Vector2(0,-6)
		if player.global_position.x<=point(row.translation).x+340 and player.global_position.y<=point(row.translation).y+220 and offset.length()<=controller.traversal.definition.hook_range:
			jump(false);hook(lower_id);set_phase("hollow_outer_hook")
		elif age>30: fail("hollow_outer_launch_range_missed")
	elif phase=="hollow_outer_hook":
		controller.router.set_move_axis(0)
		if controller.traversal.state==&"free" and last_hook=="free" and age>12:
			request(&"shoot_release",Vector2.RIGHT);set_phase("hollow_lower_land")
	elif phase=="hollow_belly_align":
		controller.router.set_move_axis(clampf((goal.x-player.global_position.x)/12,-1,1))
		stable=stable+1 if at_destination(goal,to_support) else 0
		if stable>=12: event("hollow_port_arrival",{"geometry_instance":row.id,"port":to_port,"support_id":to_support});complete_leg()
	elif phase=="hollow_outer_drop":
		var outside_x:=float(raw.platforms.filter(func(p: Dictionary) -> bool: return p.id=="outer_crown")[0].rect[0])+float(raw.platforms.filter(func(p: Dictionary) -> bool: return p.id=="outer_crown")[0].rect[2])+20
		controller.router.set_move_axis(clampf((point(row.translation).x+outside_x-player.global_position.x)/12,-1,1))
		if full_support(to_support): set_phase("hollow_outer_align")
	elif phase=="hollow_outer_align":
		controller.router.set_move_axis(clampf((goal.x-player.global_position.x)/12,-1,1))
		stable=stable+1 if at_destination(goal,to_support) else 0
		if stable>=12: event("hollow_port_arrival",{"geometry_instance":row.id,"port":to_port,"support_id":to_support});complete_leg()
func drive_candidate_relay(leg: Dictionary) -> void:
	var goal:=point(leg.landing)
	if str(leg.edge_id)=="north_reward":
		# This edge is a candidate, not an H password. Follow its real
		# descending mouth; solid floors must be walked off normally.
		if phase=="align" and age==1: event("candidate_relay_method",{"method":"normal_descent","edge_id":leg.edge_id})
		drive_drop(leg)
		return
	if str(leg.edge_id)!="west_north": fail("unsupported_candidate_relay/"+str(leg.edge_id));return
	if age>240: fail("bounded_candidate_relay/"+phase);return
	if phase=="align":
		var start:=point(leg.path[0])
		controller.router.set_move_axis(clampf((start.x-player.global_position.x)/12,-1,1))
		stable=stable+1 if at_destination(start,"west_court") else 0
		if stable>=12: jump(true);set_phase("relay_launch")
	elif phase=="relay_launch":
		controller.router.set_move_axis(0)
		var target: Node2D=stage.assembler.hook_targets.get(str(leg.anchor_id))
		if not is_instance_valid(target): fail("candidate_relay_anchor_missing");return
		var offset:=target.global_position-player.global_position-Vector2(0,-6)
		var court:=platform("north_court")
		if court.is_empty(): fail("candidate_relay_north_support_missing");return
		var origin:=player.global_position+Vector2(0,-6)
		var radius: float=controller.traversal.definition.hook_capture_radius
		# Bodies can jump upward through this one-way surface, while the
		# real hook sweep still hits it. Clear the entire cast circle first.
		if player.global_position.y<=float(leg.path[1][1]) and origin.y+radius<=float(court.rect[1])-1 and player.velocity.y<0 and offset.length()<=controller.traversal.definition.hook_range:
			jump(false);event("candidate_relay_method",{"method":"jump_H","edge_id":leg.edge_id,"anchor_id":leg.anchor_id,"anchor_position":pair(target.global_position),"offset":pair(offset),"hook_origin":pair(origin),"hook_capture_radius":radius,"cleared_support_id":"north_court","cleared_rect":court.rect.duplicate()})
			if hook(str(leg.anchor_id)): set_phase("relay_hook")
		elif age>30: fail("candidate_relay_jump_range_missed")
	elif phase=="relay_hook":
		controller.router.set_move_axis(0)
		if controller.traversal.state==&"free" and age>12:
			var contact:=false
			for accepted: Dictionary in events:
				if int(accepted.leg)==leg_index and accepted.kind=="hook_contact_kick" and accepted.get("target","")==str(leg.anchor_id): contact=true
			if not contact: fail("candidate_relay_H_missed_actual_target");return
			set_phase("relay_land")
	elif phase=="relay_land":
		controller.router.set_move_axis(clampf((goal.x-player.global_position.x)/12,-1,1))
		stable=stable+1 if at_destination(goal,"north_court") else 0
		if stable>=12: complete_leg()
func drive_gate(leg: Dictionary) -> void:
	var goal:=point(leg.landing)
	if stage.region_state.opened.has("crown_vine") and stage.assembler.vine_shape.disabled: drive_walk(goal);return
	if phase=="align":
		var takeoff:=point(leg.path[0])
		controller.router.set_move_axis(clampf((takeoff.x-player.global_position.x)/12,-1,1))
		if at_destination(takeoff,str(leg.support_id)): jump(true);set_phase("gate_jump")
	elif phase=="gate_jump" and player.global_position.y<goal.y-40:
		jump(false);hook(str(leg.anchor_id));set_phase("gate_hook")
	elif phase=="gate_hook": controller.router.set_move_axis(clampf((goal.x-player.global_position.x)/20,-1,1))
func drive_ecology(leg: Dictionary) -> void:
	var row:=instance(leg)
	if row.is_empty(): fail("missing_woven_instance");return
	var raw: Dictionary=row.local_geometry
	var goal:=point(leg.landing)
	var side:=signf(goal.x-player.global_position.x)
	if leg.kind=="ecology_return":
		controller.router.set_move_axis(clampf((goal.x-player.global_position.x)/20,-1,1))
		if player.is_on_floor() and phase!="woven_return_jump":
			for motor: EnemyMotor in stage.enemies:
				var actor: EnemyActor=motor.get_node("Actor")
				var offset:=motor.global_position-player.global_position
				if not actor.health.terminal and offset.x*side>0 and offset.x*side<12+actor.definition.collision_size.x*.5+player.tuning.ground_speed*player.tuning.jump_hold_duration and absf(offset.y)<18+actor.definition.collision_size.y*.5:
					jump(true);set_phase("woven_return_jump");break
		if phase=="woven_return_jump" and age>=int(ceil(player.tuning.jump_hold_duration*Engine.physics_ticks_per_second)): jump(false)
		if phase=="woven_return_jump" and age>15 and player.is_on_floor(): set_phase("woven_return_walk")
		stable=stable+1 if at_destination(goal) else 0
		if stable>=12: complete_leg()
		return
	if phase=="align":
		if not player.is_on_floor(): controller.router.set_move_axis(0);return
		# Try the real live target; death/inactivity takes the fixed physical alternative.
		var target: Node2D
		var id: String=str(row.enemy_id_map.get("woven_lantern",""))
		for i: int in stage.enemy_manifest.size():
			if str(stage.enemy_manifest[i].id)==id:
				var actor: EnemyActor=stage.enemies[i].get_node("Actor")
				if not actor.health.terminal and stage.enemies[i].visible and stage.enemies[i].collision_layer!=0: target=stage.enemies[i]
		if leg.kind=="ecology_choice" and is_instance_valid(target):
			request(&"grapple",(target.global_position-player.global_position-Vector2(0,-6)).normalized());event("woven_live_target",{"id":id})
		else: mapped_hook(row,"woven_fixed_ring");event("woven_fixed_alternative")
		set_phase("woven_hook")
	elif phase=="woven_hook":
		controller.router.set_move_axis(side)
		if controller.traversal.state==&"free" and last_hook=="free" and age>12 and not player.is_on_floor(): request(&"shoot_release",Vector2(-side,0));set_phase("woven_cross")
		elif controller.traversal.state==&"free" and player.is_on_floor() and age>90: fail("woven_hook_failed_on_real_floor")
	elif phase=="woven_cross":
		controller.router.set_move_axis(clampf((goal.x-player.global_position.x)/20,-1,1))
		stable=stable+1 if at_destination(goal) else 0
		if stable>=12: complete_leg()
func drive_recovery_edge(leg: Dictionary) -> void:
	var row:=instance(leg)
	if row.is_empty(): fail("missing_recovery_instance");return
	if phase=="align": set_phase("external_drop")
	if phase=="external_drop":
		var destination:=point(leg.path[2])
		controller.router.set_move_axis(clampf((destination.x-player.global_position.x)/12,-1,1))
		if full_support(mapped_support(row,"recovery")): set_phase("recover_walk")
	else: drive_factory_recovery(row,point(leg.landing))
func drive_cache() -> void:
	controller.router.set_move_axis(0)
	if not cache_pending:
		if not player.is_on_floor(): fail("cache_interaction_not_grounded");return
		claim_before=stage.region_state.claimed.duplicate(true);cache_pending=true;request(&"interact");return
	if not app.reward_modal.opened and cache_claimed:
		if duplicate_tick<0:
			duplicate_before={"claimed":stage.region_state.claimed.duplicate(true),"items":app.build.inventory.item_ids(),"coins":app.wallet.balance}
			duplicate_tick=tick;request(&"interact");event("actual_duplicate_interact_probe")
		elif tick-duplicate_tick>=8:
			duplicate_after={"claimed":stage.region_state.claimed.duplicate(true),"items":app.build.inventory.item_ids(),"coins":app.wallet.balance}
			if app.reward_modal.opened or duplicate_before!=duplicate_after: fail("duplicate_actual_interact_changed_reward")
			else: duplicate_checked=true;set_phase("align")
func _process(_delta: float) -> void:
	if not initialized or finished or not cache_pending: return
	if not is_instance_valid(app) or not is_instance_valid(stage) or not is_instance_valid(player) or not is_instance_valid(controller) or not app.lifetime.active:
		fail("actual_run_ended");return
	if app.reward_modal.opened:
		modal_age+=1
		modal_frames.append({"index":modal_age,"tick":tick,"paused":get_tree().paused,"position":pair(player.global_position),"motion_steps":player.motion_steps,"supports":supports()})
		movie_stamp(modal_frames[-1])
		if modal_age==4:
			for button: Button in app.reward_modal.find_children("*","Button",true,false):
				if button.visible and not button.disabled:
					modal_button=button;modal_point=button.get_global_transform_with_canvas()*(button.size/2);send_pointer(true);break
		elif modal_age==5 and is_instance_valid(modal_button): send_pointer(false)
		if modal_age>90: fail("actual_cache_pointer_timeout")
	else:
		for chest: Dictionary in stage.chests:
			if chest.id=="thorn_forest/map_%s/"%map_index+claim_local_id and chest.claimed and stage.region_state.claimed.has(chest.id):
				cache_claimed=true;claim_after=stage.region_state.claimed.duplicate(true)
		if modal_age==0 and age>90: fail("cache_modal_did_not_open")
func send_pointer(pressed: bool) -> void:
	var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed;e.position=modal_point;e.global_position=modal_point
	get_viewport().push_input(e,true)
	var rect: Rect2=modal_button.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,modal_button.size)
	pointer_events.append({"kind":"mouse_button_press" if pressed else "mouse_button_release","position":pair(modal_point),"button_text":modal_button.text,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"raw_canvas_rect":[modal_button.get_global_rect().position.x,modal_button.get_global_rect().position.y,modal_button.get_global_rect().size.x,modal_button.get_global_rect().size.y],"viewport_size":pair(get_viewport().get_visible_rect().size),"window_size":pair(Vector2(get_window().size)),"screen_scale":pair(get_viewport().get_screen_transform().get_scale()),"canvas_origin":pair(modal_button.get_canvas_transform().origin),"canvas_scale":pair(modal_button.get_canvas_transform().get_scale())})
	movie_stamp(pointer_events[-1])
func observe() -> void:
	if not initialized or finished or not is_instance_valid(player) or tick<1: return
	if not frames.is_empty() and int(frames[-1].tick)==tick: return
	var enemies: Array=[]
	for i: int in stage.enemies.size():
		var motor: EnemyMotor=stage.enemies[i]
		if not is_instance_valid(motor): continue
		var actor: EnemyActor=motor.get_node("Actor")
		var behavior:=actor.attack_behavior
		var deep: Dictionary={}
		if behavior!=null and behavior.has_method("depth_snapshot"): deep=behavior.call("depth_snapshot")
		enemies.append({"id":stage.enemy_manifest[i].id,"position":pair(motor.global_position),"health":actor.health.current,"terminal":actor.health.terminal,"state":String(behavior.state) if behavior else "none","state_time":behavior.state_time if behavior else 0.0,"cooldown":behavior.cooldown if behavior else 0.0,"depth_state":deep,"stable_id":String(actor.definition.stable_id),"body_size":pair(actor.definition.collision_size),"patrol_radius":actor.definition.patrol_half_width})
	frames.append({"tick":tick,"leg":leg_index,"phase":phase,"position":pair(player.global_position),"velocity":pair(player.velocity),"grounded":player.is_on_floor(),"supports":supports(),"motor_steps":player.motion_steps-before_steps,"axis":controller.router.axis,"hook_state":String(controller.traversal.state),"hook_used":controller.traversal.hook_used,"shots":controller.action_resources.shot_charges,"energy":controller.actor_resources.stamina.current,"health":controller.actor_resources.health.current,"actor_epoch":app.lifetime.actor_epoch,"stage_epoch":app.lifetime.stage_epoch,"enemies":enemies})
	frames[-1].jump_state={"enabled":controller.jump_ability.enabled,"maximum":controller.jump_ability.maximum_jumps(),"used":controller.jump_ability.used_jumps,"can_air_jump":controller.jump_ability.can_air_jump()}
	frames[-1].focus={"shared":controller.air_focus_ability.stamina_state==controller.actor_resources.stamina,"aiming":controller.router.aim_engaged,"active":controller.air_focus_ability.active,"available":controller.active and controller.router.has_application_focus and not get_tree().paused and not controller.traversal.busy(),"time_scale":Engine.time_scale}
	frames[-1].shot_economy={"owner_id":player.get_instance_id(),"session_id":controller.session_id,"weapon_epoch":controller.shoot_ability.weapon_epoch,"hits":controller.shot_energy._hits.duplicate(true),"combat_packets":controller.combat_energy._packets.duplicate(true)}
	movie_stamp(frames[-1])
	var cavity_sample: bool=leg_index<itinerary.size() and str(itinerary[leg_index].kind)=="hollow_cavity"
	if not cavity_sample and not completed.is_empty() and int(completed[-1].tick)==tick:
		cavity_sample=str(itinerary[int(completed[-1].leg)].kind)=="hollow_cavity"
	if cavity_sample:
		frames[-1].merge({"body":[player.global_position.x-12,player.global_position.y-18,24,36],"hook_start":pair(controller.traversal.hook_start),"hook_tip":pair(controller.traversal.hook_tip),"shot_energy_delay":controller.shot_energy._delay,"burst_remaining":player.recoil_burst_remaining,"burst_velocity":pair(player.recoil_velocity)})
		frames[-1].pending_air_grants=controller.received_resource_grants.map(func(grant: Dictionary) -> Dictionary: return {"amount":int(grant.amount),"session_id":int(grant.session_id)})
	var air_chain_sample: bool=leg_index<itinerary.size() and str(itinerary[leg_index].kind) in ["airborne_chain","hanging_chain"]
	if not air_chain_sample and not completed.is_empty() and int(completed[-1].tick)==tick:
		air_chain_sample=str(itinerary[int(completed[-1].leg)].kind) in ["airborne_chain","hanging_chain"]
	if air_chain_sample:
		frames[-1].merge({"body":[player.global_position.x-12,player.global_position.y-18,24,36],"hook_start":pair(controller.traversal.hook_start),"hook_tip":pair(controller.traversal.hook_tip),"shot_energy_delay":controller.shot_energy._delay,"burst_remaining":player.recoil_burst_remaining,"burst_velocity":pair(player.recoil_velocity)})
		frames[-1].pending_air_grants=controller.received_resource_grants.map(func(grant: Dictionary) -> Dictionary: return {"amount":int(grant.amount),"session_id":int(grant.session_id)})
	if finish_pending: finished=true
func snapshot() -> Dictionary:
	if not is_instance_valid(controller): return {}
	return {"position":pair(player.global_position),"health":controller.actor_resources.health.current,"energy":controller.actor_resources.stamina.current,"shots":controller.action_resources.shot_charges,"hook_enabled":controller.traversal.hook_enabled,"double_enabled":controller.traversal.double_enabled,"wall_enabled":controller.traversal.wall_enabled,"weapon":String(controller.shoot_ability.weapon.id),"tier":controller.shoot_ability.weapon.tier,"shot_policy":{"definition_path":controller.shot_energy.definition.resource_path,"definition_sha256":FileAccess.get_sha256(controller.shot_energy.definition.resource_path),"shooting_consumes_energy":controller.shot_energy.definition.shooting_consumes_energy,"max_air_shots":player.tuning.max_air_shots},"config":{"tuning":FileAccess.get_sha256("res://config/player_tuning.json"),"traversal":FileAccess.get_sha256("res://resources/player/traversal.tres")}}


# Shared actual cross-branch movement. Candidate probes and recorded regions
# consume these same Router requests; no alternate movement implementation.
var ecology_strategy := "wait_phase"
var ecology_started := -1
var ecology_finished := -1
var ecology_entry: Dictionary = {}
var ecology_exit: Dictionary = {}
var crossbranch_candidate: Dictionary = {}
var crossbranch_actor: EnemyActor
var crossbranch_started := -1
var crossbranch_finished := -1
var crossbranch_camera: Array[Dictionary] = []
var crossbranch_state := "observe"
var crossbranch_contact := false
var crossbranch_kick := false
var crossbranch_return_state := "depart"
var crossbranch_first_free := -1
var crossbranch_R_count := 0
var crossbranch_outbound_started := -1
var crossbranch_depart_jump := false
var crossbranch_ordinary_state := "bank"
var crossbranch_air_shots := 0
var crossbranch_air_budget := 1
var crossbranch_setup_shots := 0
var crossbranch_last_shot := -10000
var crossbranch_recover_state := "catch"
var crossbranch_one_R_failed := false
var crossbranch_formal := false

func _observe_crossbranch_hook(state: StringName) -> void:
	if is_instance_valid(crossbranch_actor) and controller.traversal.hook_target==crossbranch_actor.motor:
		if ecology_strategy=="crossbranch_live_coyote_H" and state==&"hook_pull":
			event("candidate_actual_migrant_head_contact",{"hook_start":pair(controller.traversal.hook_start),"hook_tip":pair(controller.traversal.hook_tip),"latched_kick_side":controller.traversal.kick_side,"target_position":pair(crossbranch_actor.motor.global_position)})
		if state==&"hook_contact_kick":
			crossbranch_contact=true
			event("candidate_actual_migrant_body_contact",{"target_id":crossbranch_candidate.actor_id,"target_position":pair(crossbranch_actor.motor.global_position),"health":crossbranch_actor.health.current,"snapshot":snapshot()})
		if state==&"hook_kick":
			crossbranch_kick=true
			if ecology_strategy=="crossbranch_live_coyote_H":event("candidate_actual_migrant_kick",{"hook_start":pair(controller.traversal.hook_start),"hook_tip":pair(controller.traversal.hook_tip),"latched_kick_side":controller.traversal.kick_side,"snapshot":snapshot()})

func _crossbranch_support(key: String) -> String:
	if crossbranch_formal:return str(manifest.crossbranch_contract.support_ids[key])
	return str({"prize":"candidate_reward_branch","lower":"candidate_lower_return","catch":"candidate_root_catch","step0":"candidate_return_step0","step1":"candidate_return_step1"}.get(key,key))

func _bind_recorded_crossbranch() -> bool:
	if crossbranch_formal:return is_instance_valid(crossbranch_actor)
	var contract: Dictionary=manifest.get("crossbranch_contract",{})
	if contract.get("version")!=1:return false
	var count := 0
	for i: int in stage.enemy_manifest.size():
		if stage.enemy_manifest[i].id!=contract.get("enemy_id"):continue
		crossbranch_actor=stage.enemies[i].get_node("Actor") as EnemyActor;count+=1
	if count!=1 or not crossbranch_actor.attack_behavior is ForestCrossbranchBehavior:
		fail("recorded_crossbranch_actor_not_unique");return false
	crossbranch_formal=true
	crossbranch_candidate={"scope":"actual_generated_crossbranch_contract","actor_id":str(contract.enemy_id),"player_reset":false,"resource_injection":false,"enemy_phase_reset":false}
	for contact: DemoContactEmitter in app._enemy_contacts:
		if String(contact.source_id)!=str(contract.enemy_id)+"_contact":continue
		crossbranch_candidate.actual_contact={"source_id":String(contact.source_id),"half_size":pair(contact.half_size),"interval":contact.interval,"amount":contact.amount,"kind":int(contact.kind),"registered_in_App":true}
	crossbranch_candidate.actual_definition={"body":pair(crossbranch_actor.definition.collision_size),"health":crossbranch_actor.health.current,"definition_sha":FileAccess.get_sha256("res://resources/enemies/forest_crossbranch.tres"),"recovery_budget_seconds":(crossbranch_actor.definition as ForestEnemyDefinition).crossbranch_max_flight_seconds,"return_speed":crossbranch_actor.definition.return_speed}
	if not ecology_strategy.begins_with("crossbranch_"):ecology_strategy="crossbranch_live_H"
	return true

func _crossbranch_predict_aim(speed: float) -> Vector2:
	var origin:=player.global_position+Vector2(0,-6)
	var behavior:=crossbranch_actor.attack_behavior as ForestCrossbranchBehavior
	var target:=crossbranch_actor.motor.global_position
	var seconds:=origin.distance_to(target)/speed
	if behavior.state==&"flight":target+=behavior.flight_velocity*seconds+Vector2(0,.5*(crossbranch_actor.definition as ForestEnemyDefinition).crossbranch_gravity*seconds*seconds)
	return (target-origin).normalized()

func _crossbranch_head_origin_clear() -> bool:
	var origin:=player.global_position+Vector2(0,-6)
	var shape:=CircleShape2D.new();shape.radius=controller.traversal.definition.hook_capture_radius
	var query:=PhysicsShapeQueryParameters2D.new();query.shape=shape;query.transform=Transform2D(0,origin);query.collision_mask=1;query.exclude=[player.get_rid()]
	return player.get_world_2d().direct_space_state.intersect_shape(query).is_empty()

func _crossbranch_windup_intercept() -> Dictionary:
	var origin:=player.global_position+Vector2(0,-6)
	var behavior:=crossbranch_actor.attack_behavior as ForestCrossbranchBehavior
	var definition:=crossbranch_actor.definition as ForestEnemyDefinition
	var current:=crossbranch_actor.motor.global_position
	var delay: float=controller.traversal.definition.hook_windup
	var speed: float=controller.traversal.definition.hook_flight_speed
	var seconds:=delay+origin.distance_to(current)/speed
	var predicted:=current
	for iteration: int in 6:
		predicted=current+behavior.flight_velocity*seconds+Vector2(0,.5*definition.crossbranch_gravity*seconds*seconds)
		seconds=delay+origin.distance_to(predicted)/speed
	return {"origin":origin,"point":predicted,"seconds":seconds,"aim":(predicted-origin).normalized(),"NPC_half":definition.collision_size*.5}

func _crossbranch_outbound() -> void:
	if crossbranch_outbound_started<0:
		crossbranch_outbound_started=tick;ecology_started=tick;ecology_entry=snapshot();event("candidate_purpose_N_entry",{"snapshot":snapshot(),"strategy":ecology_strategy})
	if crossbranch_formal and crossbranch_actor.health.terminal and crossbranch_state=="observe":ecology_strategy="crossbranch_ordinary_safe_two_R"
	if ecology_strategy not in ["crossbranch_live_H","crossbranch_live_coyote_H"]:
		_crossbranch_ordinary();return
	var behavior:=crossbranch_actor.attack_behavior as ForestCrossbranchBehavior
	if behavior.state==&"blocked":fail("candidate_outbound_NPC_blocked");return
	if crossbranch_state=="observe":
		controller.router.set_move_axis(clampf((112-player.global_position.x)/12,-1,1))
		if ecology_strategy=="crossbranch_live_coyote_H":
			if absf(player.global_position.x-112)<7 and full_support("north_court"):crossbranch_state="coyote"
			return
		if absf(player.global_position.x-112)<7 and full_support("north_court") and behavior.state==&"flight" and behavior.committed_shore==1 and (not crossbranch_formal or crossbranch_actor.motor.global_position.x>20):
			crossbranch_state="takeoff";set_phase("candidate_depart_after_actual_commit")
		return
	if crossbranch_state=="coyote":
		controller.router.set_move_axis(-1)
		var remaining: float=controller.jump_ability._coyote_remaining
		var dt:=1.0/float(Engine.physics_ticks_per_second)
		if not player.is_on_floor() and remaining>dt+1e-8 and remaining<=2*dt+1e-8:
			event("candidate_actual_coyote_H_takeoff",{"snapshot":snapshot(),"remaining":remaining})
			jump(true);crossbranch_state="intercept"
		elif player.global_position.y>500:fail("candidate_H_coyote_window_missed")
		return
	if crossbranch_state=="takeoff":
		controller.router.set_move_axis(-1)
		if player.global_position.x<=72:
			jump(true);crossbranch_depart_jump=true;crossbranch_state="intercept";set_phase("candidate_full_jump_toward_live_migrant")
		return
	if crossbranch_state=="intercept":
		controller.router.set_move_axis(-1)
		var target:=crossbranch_actor.motor.global_position
		if ecology_strategy=="crossbranch_live_coyote_H":
			var proposal:=_crossbranch_windup_intercept()
			var origin: Vector2=proposal.origin
			var predicted: Vector2=proposal.point
			var half: Vector2=proposal.NPC_half
			var radius: float=controller.traversal.definition.hook_capture_radius
			if not player.is_on_floor() and player.normal_velocity.y>=0 and behavior.state==&"flight" and behavior.committed_shore==1 and target.x-half.x>origin.x+radius and predicted.x-half.x>origin.x+radius and predicted.y+half.y<origin.y and origin.distance_to(predicted)<controller.traversal.definition.hook_range and _crossbranch_head_origin_clear():
				event("candidate_migrant_H_request",{"aim":pair(proposal.aim),"target":pair(target),"target_id":crossbranch_candidate.actor_id,"NPC_velocity":pair(behavior.flight_velocity),"snapshot":snapshot(),"actual_head_radius":radius,"prediction_only":{"point":pair(predicted),"seconds":proposal.seconds,"fixed_origin":pair(origin),"head_contact_x_margin":predicted.x-half.x-origin.x,"predicate":"full_jump_then_first_predicted_right_upper_intercept_no_current_above_requirement"}})
				request(&"grapple",proposal.aim);crossbranch_state="pull"
			elif player.global_position.y>620:fail("candidate_coyote_H_no_valid_intercept")
			return
		if not player.is_on_floor() and behavior.state==&"flight" and behavior.committed_shore==1 and target.x<=-120 and target.distance_to(player.global_position+Vector2(0,-6))<controller.traversal.definition.hook_range and _crossbranch_head_origin_clear():
			var aim:=_crossbranch_predict_aim(controller.traversal.definition.hook_flight_speed)
			event("candidate_migrant_H_request",{"aim":pair(aim),"target":pair(target),"target_id":crossbranch_candidate.actor_id,"NPC_velocity":pair(behavior.flight_velocity),"snapshot":snapshot(),"actual_head_radius":controller.traversal.definition.hook_capture_radius})
			request(&"grapple",aim);crossbranch_state="pull";set_phase("candidate_actual_moving_body_hook")
		elif player.global_position.y>620:fail("candidate_H_missed_destination_before_contact")
		return
	if crossbranch_state=="pull":
		controller.router.set_move_axis(0)
		if controller.traversal.state==&"hook_miss":fail("candidate_actual_moving_H_miss");return
		if crossbranch_contact and crossbranch_kick and controller.traversal.state==&"free" and not player.is_on_floor():
			crossbranch_first_free=tick
			jump(false)
			var aim:=_crossbranch_optimal_ordinary_aim() if ecology_strategy=="crossbranch_live_coyote_H" else Vector2(1,1).normalized()
			event("candidate_first_actual_free_R",{"snapshot":snapshot(),"aim":pair(aim)})
			request(&"shoot_release",aim);crossbranch_R_count=1;crossbranch_state="receive";set_phase("candidate_actual_H_then_reverse_R")
		return
	if crossbranch_state=="receive":
		controller.router.set_move_axis(clampf((-400-player.global_position.x)/12,-1,1))
		stable=stable+1 if at_destination(Vector2(-400,250),_crossbranch_support("prize")) else 0
		if stable>=12:
			event("candidate_award_actual_arrival",{"snapshot":snapshot(),"supports":supports()});complete_leg()
		elif player.is_on_floor() and _crossbranch_support("catch") in supports():fail("candidate_live_R_failed_award_and_landed_recovery")

func _crossbranch_return() -> void:
	if crossbranch_return_state=="depart":
		controller.router.set_move_axis(clampf((-440-player.global_position.x)/12,-1,1))
		if absf(player.global_position.x+440)<7 and full_support(_crossbranch_support("prize")):
			jump(true);crossbranch_return_state="over_alive_body";set_phase("candidate_return_clear_live_body")
		return
	if crossbranch_return_state=="over_alive_body":
		var via: Dictionary=itinerary[leg_index].get("return_via",{})
		if not via.is_empty():
			var via_position:=point(via.position)
			controller.router.set_move_axis(clampf((via_position.x-player.global_position.x)/12,-1,1))
			if not player.is_on_floor() and player.normal_velocity.y>=0:jump(false)
			stable=stable+1 if at_destination(via_position,str(via.support_id)) and player.global_position.distance_to(via_position)<=2 else 0
			if stable>=12:
				event("candidate_return_via_arrival",{"via":via.duplicate(true),"supports":supports(),"snapshot":snapshot()})
				request(&"drop_through")
				event("candidate_return_via_drop_requested",{"support_id":str(via.support_id),"position":pair(player.global_position)})
				crossbranch_return_state="via_drop";set_phase("candidate_return_via_drop")
			return
		controller.router.set_move_axis(clampf((-150-player.global_position.x)/12,-1,1))
		if not player.is_on_floor() and player.normal_velocity.y>=0:jump(false)
		stable=stable+1 if at_destination(Vector2(-150,600),_crossbranch_support("lower")) else 0
		if stable>=12:
			jump(true);crossbranch_return_state="lower_gap";set_phase("candidate_return_lower_gap")
		elif player.is_on_floor() and _crossbranch_support("catch") in supports():fail("candidate_return_missed_lower_shore")
		return
	if crossbranch_return_state=="via_drop":
		var via: Dictionary=itinerary[leg_index].return_via
		var next:=point(via.next)
		controller.router.set_move_axis(clampf((next.x-player.global_position.x)/12,-1,1))
		stable=stable+1 if at_destination(next,_crossbranch_support("lower")) else 0
		if stable>=12:
			jump(true);crossbranch_return_state="lower_gap";set_phase("candidate_return_lower_gap")
		elif player.is_on_floor() and _crossbranch_support("catch") in supports():fail("candidate_return_missed_lower_shore")
		return
	if crossbranch_return_state=="lower_gap":
		controller.router.set_move_axis(clampf((20-player.global_position.x)/12,-1,1))
		if not player.is_on_floor() and player.normal_velocity.y>=0:jump(false)
		stable=stable+1 if at_destination(Vector2(20,600),_crossbranch_support("step1")) else 0
		if stable>=12:crossbranch_return_state="W";set_phase("candidate_same_reward_return_to_W")
		return
	if crossbranch_return_state=="W":
		controller.router.set_move_axis(clampf((180-player.global_position.x)/12,-1,1))
		stable=stable+1 if at_destination(Vector2(180,600),"west_court") else 0
		if stable>=12:
			event("candidate_actual_reward_return_W",{"snapshot":snapshot(),"wallet":app.wallet.balance,"claims":stage.region_state.claimed.keys()});crossbranch_finished=tick;ecology_finished=tick;ecology_exit=snapshot();complete_leg()

func _crossbranch_optimal_ordinary_aim() -> Vector2:
	# Read-only finite projection for the strongest air-shot angle. Actual input,
	# collisions, coyote and landing are still owned entirely by the real Motor.
	var distance: float=player.weapon_motion.base_distance(player.tuning,false)
	var goal_y:=268.0-18.0
	var dt:=1.0/float(Engine.physics_ticks_per_second)
	var best_range := -INF
	var best:=Vector2(1,1).normalized()
	for index: int in range(1,1000):
		var up:=float(index)/1000.0
		var horizontal:=sqrt(1-up*up)
		var y:=player.global_position.y-distance*up
		if y>goal_y:continue
		var age_model:=0.0
		var vy_model:=0.0
		for step: int in 120:
			vy_model=minf(player.tuning.max_normal_fall_speed,vy_model+player.tuning.gravity*(player._apex_integral(age_model+dt)-player._apex_integral(age_model)))
			y+=vy_model*dt;age_model+=dt
			if y>=goal_y:break
		var reach:=distance*horizontal+player.tuning.ground_speed*age_model
		if reach>best_range:best_range=reach;best=Vector2(horizontal,up)
	event("candidate_ordinary_angle_projection",{"actual_position":pair(player.global_position),"aim":pair(best),"distance_from_actual_motion":distance,"projected_reach_only":best_range,"model":"real_apex_integral_60Hz_readonly_no_collision_prediction"})
	return best

func _crossbranch_first_two_R_aim() -> Vector2:
	# Finite two-angle projection, not a claim of collision-free or globally
	# optimal reach. Both real shots still wait for actual Motor/cooldown state.
	var distance: float=player.weapon_motion.base_distance(player.tuning,false)
	var dt:=1.0/float(Engine.physics_ticks_per_second)
	var weapon: WeaponDefinition=controller.shoot_ability.weapon
	var cooldown:=maxf(player.tuning.shot_cooldown,weapon.interval*(weapon.rounds-1)+weapon.burst_duration)
	var gap_frames:=maxi(0,ceili(cooldown/dt)-ceili(player.tuning.shot_burst_duration/dt)+1)
	var post_y:=0.0
	var vy:=0.0
	for step: int in gap_frames:
		vy=minf(player.tuning.max_normal_fall_speed,vy+player.tuning.gravity*(player._apex_integral((step+1)*dt)-player._apex_integral(step*dt)))
		post_y+=vy*dt
	var goal_y:=268.0-18.0
	var best_range := -INF
	var best:=Vector2(1,1).normalized()
	for first_index: int in range(1,100):
		var up1:=float(first_index)/100.0
		var x1:=sqrt(1-up1*up1)
		for second_index: int in range(1,100):
			var up2:=float(second_index)/100.0
			var y:=player.global_position.y-distance*(up1+up2)+post_y
			if y>goal_y:continue
			var age:=0.0
			var fall:=0.0
			for step: int in 120:
				fall=minf(player.tuning.max_normal_fall_speed,fall+player.tuning.gravity*(player._apex_integral(age+dt)-player._apex_integral(age)))
				y+=fall*dt;age+=dt
				if y>=goal_y:break
			var reach:=distance*(x1+sqrt(1-up2*up2))+player.tuning.ground_speed*(gap_frames*dt+age)
			if reach>best_range:best_range=reach;best=Vector2(x1,up1)
	event("candidate_two_R_joint_projection",{"snapshot":snapshot(),"first_aim":pair(best),"distance_from_actual_motion":distance,"gap_frames_projection":gap_frames,"projected_range_only":best_range,"angle_grid":.01,"not_exact_collision_or_earliest_frame_proof":true})
	return best

func _crossbranch_ordinary() -> void:
	var mode:=ecology_strategy.trim_prefix("crossbranch_")
	var killed:=mode in ["shoot_then_two_R","dead_lower_two_R"]
	if crossbranch_ordinary_state=="bank":
		controller.router.set_move_axis(clampf((112-player.global_position.x)/12,-1,1))
		if absf(player.global_position.x-112)<7 and full_support("north_court"):
			if killed:crossbranch_ordinary_state="shoot_bank"
			elif mode=="ordinary_safe_two_R":
				controller.router.set_move_axis(0);jump(true);crossbranch_air_budget=2;crossbranch_ordinary_state="safe_rise"
			elif mode in ["ordinary_one_R","ordinary_two_R"]:
				crossbranch_air_budget=1 if mode=="ordinary_one_R" else 2
				crossbranch_ordinary_state="coyote"
			else:
				crossbranch_air_budget=2;jump(true);crossbranch_ordinary_state="air"
		return
	if crossbranch_ordinary_state=="safe_rise":
		controller.router.set_move_axis(0)
		var NPC_top: float=crossbranch_actor.motor.global_position.y-crossbranch_actor.definition.collision_size.y*.5
		if not player.is_on_floor() and player.global_position.y+18<NPC_top-1:
			event("candidate_actual_vertical_body_clear",{"snapshot":snapshot(),"player_bottom":player.global_position.y+18,"NPC_top":NPC_top})
			controller.router.set_move_axis(-1);crossbranch_ordinary_state="air"
		return
	if crossbranch_ordinary_state=="shoot_bank":
		controller.router.set_move_axis(clampf((112-player.global_position.x)/12,-1,1))
		if crossbranch_actor.health.terminal:
			if mode=="dead_lower_two_R" and not (absf(player.global_position.x-112)<7 and full_support("north_court")):return
			event("candidate_actual_enemy_dead_before_departure",{"shots":crossbranch_setup_shots,"snapshot":snapshot()})
			if mode=="dead_lower_two_R":
				jump(true);crossbranch_ordinary_state="lower_approach"
			else:crossbranch_ordinary_state="coyote";crossbranch_air_budget=2
			return
		if absf(player.global_position.x-112)<7 and full_support("north_court") and tick-crossbranch_last_shot>=int(ceil(controller.shoot_ability.weapon.interval*Engine.physics_ticks_per_second)) and controller.shoot_ability.cooldown_remaining<=0:
			var aim:=_crossbranch_predict_aim(player.tuning.projectile_speed)
			event("candidate_actual_bank_shot",{"snapshot":snapshot(),"aim":pair(aim),"target_position":pair(crossbranch_actor.motor.global_position)})
			request(&"shoot_release",aim);crossbranch_setup_shots+=1;crossbranch_last_shot=tick
			if crossbranch_setup_shots>8:fail("candidate_actual_projectiles_failed_kill_budget")
		return
	if crossbranch_ordinary_state=="coyote":
		controller.router.set_move_axis(-1)
		var remaining: float=controller.jump_ability._coyote_remaining
		var dt:=1.0/float(Engine.physics_ticks_per_second)
		if not player.is_on_floor() and remaining>dt+1e-8 and remaining<=2*dt+1e-8:
			event("candidate_actual_partial_coyote_takeoff",{"snapshot":snapshot(),"remaining":remaining,"body_before":pair(player.global_position),"used_jumps":controller.jump_ability.used_jumps})
			jump(true);crossbranch_ordinary_state="air"
		elif player.global_position.y>500:fail("candidate_coyote_request_window_missed")
		return
	if crossbranch_ordinary_state=="lower_approach":
		controller.router.set_move_axis(clampf((-150-player.global_position.x)/12,-1,1))
		if not player.is_on_floor() and player.normal_velocity.y>=0:jump(false)
		if at_destination(Vector2(-150,600),_crossbranch_support("lower")):
			jump(true);crossbranch_air_budget=2;crossbranch_ordinary_state="air";crossbranch_air_shots=0
		elif player.is_on_floor() and _crossbranch_support("catch") in supports():
			crossbranch_ordinary_state="recover_low";crossbranch_recover_state="catch"
		return
	if crossbranch_ordinary_state=="air":
		controller.router.set_move_axis(clampf((-400-player.global_position.x)/12,-1,1))
		if crossbranch_air_shots==0 and not player.is_on_floor() and player.normal_velocity.y>=0:
			jump(false)
			var aim:=_crossbranch_first_two_R_aim() if mode=="ordinary_safe_two_R" else _crossbranch_optimal_ordinary_aim() if crossbranch_air_budget==1 else Vector2.DOWN
			event("candidate_actual_ordinary_apex_R",{"snapshot":snapshot(),"ordinal":1,"aim":pair(aim),"budget":crossbranch_air_budget,"velocity":pair(player.normal_velocity)})
			request(&"shoot_release",aim);crossbranch_air_shots=1
		elif crossbranch_air_shots==1 and crossbranch_air_budget==2 and not player.is_on_floor() and player.recoil_burst_remaining<=0 and controller.shoot_ability.cooldown_remaining<=0 and player.normal_velocity.y>=0:
			var aim:=_crossbranch_optimal_ordinary_aim()
			event("candidate_actual_ordinary_apex_R",{"snapshot":snapshot(),"ordinal":2,"aim":pair(aim),"budget":2,"velocity":pair(player.normal_velocity)})
			request(&"shoot_release",aim);crossbranch_air_shots=2
		if player.is_on_floor() and _crossbranch_support("prize") in supports() and crossbranch_air_shots>0:
			event("candidate_first_partial_award_contact",{"snapshot":snapshot(),"position":pair(player.global_position),"full_support":full_support(_crossbranch_support("prize"))})
			# A cheap ordinary landing may immediately jump over the living body.
			# No artificial twelve-frame pause before that legitimate continuation.
			if not crossbranch_actor.health.terminal and crossbranch_actor.motor.global_position.x<player.global_position.x and absf(crossbranch_actor.motor.global_position.x-player.global_position.x)<110:
				jump(true);crossbranch_ordinary_state="award_hop"
			else:crossbranch_ordinary_state="award_walk"
		elif player.is_on_floor() and crossbranch_air_shots>0:
			if crossbranch_air_budget==1:
				crossbranch_one_R_failed=true;event("candidate_one_R_actual_failure_landed_recovery",{"snapshot":snapshot(),"supports":supports()})
			else:
				fail("candidate_actual_two_R_failed_destination");return
			crossbranch_ordinary_state="recover_low";crossbranch_recover_state="catch"
		return
	if crossbranch_ordinary_state=="recover_low":
		_crossbranch_recover_low();return
	if crossbranch_ordinary_state in ["award_hop","award_walk"]:
		controller.router.set_move_axis(clampf((-400-player.global_position.x)/12,-1,1))
		if crossbranch_ordinary_state=="award_hop" and not player.is_on_floor() and player.normal_velocity.y>=0:jump(false)
		stable=stable+1 if at_destination(Vector2(-400,250),_crossbranch_support("prize")) else 0
		if stable>=12:
			event("candidate_award_actual_arrival",{"snapshot":snapshot(),"supports":supports(),"ordinary_budget":crossbranch_air_budget,"one_R_direct_failed":crossbranch_one_R_failed});complete_leg()

func _crossbranch_recover_low() -> void:
	if _crossbranch_support("lower") in supports() and player.is_on_floor():
		controller.router.set_move_axis(clampf((-150-player.global_position.x)/12,-1,1))
		if at_destination(Vector2(-150,600),_crossbranch_support("lower")):
			crossbranch_air_budget=2;crossbranch_air_shots=0;jump(true);crossbranch_ordinary_state="air"
		return
	if crossbranch_recover_state=="catch":
		controller.router.set_move_axis(clampf((-110-player.global_position.x)/12,-1,1))
		if player.is_on_floor() and _crossbranch_support("step0") in supports():
			jump(true);crossbranch_recover_state="low";return
		if at_destination(Vector2(-110,802),_crossbranch_support("catch")):
			jump(true);crossbranch_recover_state="step0"
		return
	if crossbranch_recover_state=="step0":
		controller.router.set_move_axis(clampf((-110-player.global_position.x)/12,-1,1))
		if not player.is_on_floor() and player.normal_velocity.y>=0:jump(false)
		if at_destination(Vector2(-110,700),_crossbranch_support("step0")):
			jump(true);crossbranch_recover_state="low"
		return
	if crossbranch_recover_state=="low":
		controller.router.set_move_axis(clampf((-150-player.global_position.x)/12,-1,1))
		if not player.is_on_floor() and player.normal_velocity.y>=0:jump(false)
