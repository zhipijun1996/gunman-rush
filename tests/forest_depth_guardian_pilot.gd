extends RefCounted
class Observer extends Node:
	var pilot: RefCounted
	func _physics_process(_delta: float) -> void: pilot.observe()
var _last_motion_steps := 0
## Narrow actual-App input pilot. Never owns actors, Health, resources or stage activation.
var app: DemoApp
var duel: RootbellGuardianV2
var tick := 0
var frames: Array[Dictionary] = []
var events: Array[Dictionary] = []
var requests: Array[Dictionary] = []
var defeats := 0
var last_hook := -1
var last_ingress := -1
var last_warning := ""
var held_until := -1
var cast_after := 0
var next_shot := 0
var direction := 1.0
var arrived := false
var seal_seen := false
var eligible_seen := false
func run(actual_app: DemoApp, budget := 3000) -> Dictionary:
	app=actual_app
	duel=app.stage.boss.get_node("Encounter") as RootbellGuardianV2
	if duel==null: return {"error":"actual Guardian absent","frames":[],"events":[],"requests":[]}
	duel.duel_event.connect(_duel_event)
	duel.defeated.connect(_defeated)
	app.policy.batch_resolved.connect(_damage)
	app.controller.traversal.action_changed.connect(_hook)
	app.controller.shoot_ability.shot_fired.connect(_shot)
	var initial := state()
	_last_motion_steps=app.player.motion_steps
	var observer:=Observer.new();observer.pilot=self;observer.process_physics_priority=1100;app.add_child(observer)
	# Exact V6_03 actual-App earned-state inputs first. Briefly releasing fire
	# to line up the live Bell is a legal aiming decision, not an efficiency comparison.
	var earned := await earn_current_restore_state()
	app.controller.router.set_jump_held(&"restore_normal_combat",false)
	for unused: int in maxi(0,budget-tick):
		if not app.lifetime.active or app.controller.actor_resources.health.terminal or duel.health.terminal: break
		tick+=1
		drive()
		await app.get_tree().physics_frame
	await app.get_tree().process_frame
	observer.free()
	app.controller.router.set_move_axis(0)
	app.controller.router.set_jump_held(&"formal_guardian_pilot",false)
	return {"input_strategy":"V6_03 earned-state normal inputs then full surviving combat; not continuous-fire efficiency comparison","earned_counter_phase2":earned,"initial":initial,"final":state(),"frames":frames,"events":events,"requests":requests,"defeats":defeats,"actual_bell_arrival":arrived,"seal_seen":seal_seen,"eligible_seen":eligible_seen,"budget_ticks":budget,"elapsed_actual_physics_frames":Engine.get_physics_frames()-int(initial.physics_frame),"injection":false,"manual_motor_step":false}
func observe() -> void:
	# Same end-of-physics observation priority as the actual region trace.
	# SceneTree.physics_frame resumes before actor nodes, so it cannot measure
	# an actor step that has not yet happened in its very first callback.
	var sample:=state()
	sample.motor_steps=app.player.motion_steps-_last_motion_steps
	_last_motion_steps=app.player.motion_steps
	frames.append(sample)
	seal_seen=seal_seen or app.stage.boss_seal.closed
	eligible_seen=eligible_seen or not app._boss_eligible_shots.is_empty()
func state() -> Dictionary:
	var p:=app.player
	return {"tick":tick,"physics_frame":Engine.get_physics_frames(),"player":pair(p.global_position),"velocity":pair(p.velocity),"player_hp":app.controller.actor_resources.health.current,"energy":app.controller.actor_resources.stamina.current,"boss_hp":duel.health.current,"boss":pair(duel.motor.global_position),"phase":duel.stage_phase,"cycles":duel._cycles,"mode":String(duel.mode),"hook":String(app.controller.traversal.state),"boss_started":app._boss_started,"core_open":duel.core_open,"seal_closed":app.stage.boss_seal.closed,"eligible_shots":app._boss_eligible_shots.size(),"actor_epoch":app.lifetime.actor_epoch,"stage_epoch":app.lifetime.stage_epoch,"session_id":app.controller.session_id,"map_index":app.director.region_map_index,"entry_ordinal":app.director.stage_index}
func pair(p: Vector2) -> Array: return [p.x,p.y]
func request(kind: StringName, aim: Vector2) -> void:
	requests.append({"tick":tick,"kind":String(kind),"aim":pair(aim),"queued":app.controller.router.request_action(kind,aim)})
func _duel_event(row: Dictionary) -> void:
	var event:=row.duplicate(true);event.pilot_tick=tick;event.tick=tick;events.append(event)
func _defeated(_boss: BossEncounter) -> void: defeats+=1
func _hook(value: StringName) -> void:
	var target:=app.controller.traversal.hook_target
	var is_bell:=target is GuardianRootBellV2
	if is_bell and value in [&"hook_contact_kick",&"hook_kick"]: arrived=true
	events.append({"event":"actual_traversal","state":String(value),"tick":tick,"bell_target":is_bell,"target_id":target.get_instance_id() if is_instance_valid(target) else 0})
func _shot(aim: Vector2, id: int) -> void: events.append({"event":"actual_shot","tick":tick,"aim":pair(aim),"shot_id":id})
func _damage(results: Array[DamageResult]) -> void:
	for result: DamageResult in results:
		events.append({"event":"policy_result","tick":tick,"source":String(result.request.source_id),"target":String(result.request.target_id),"event_id":String(result.request.event_id),"id":String(result.request.event_id),"physics_frame":Engine.get_physics_frames(),"amount":result.request.amount,"hp":result.health.current if result.health!=null else -1,"lethal":result.lethal})
func drive() -> void:
	var c:=app.controller
	var p:=app.player
	if not app._boss_started:
		c.router.set_move_axis(1)
		return
	var arena: Array=duel.geometry.boss_arena
	var bell:=duel._bell
	if arrived and duel.mode not in [&"pursuit_warning",&"pursuit_flight"]:
		var dx:=duel.motor.global_position.x-p.global_position.x
		direction=signf(dx) if absf(dx)>165 else 0
	if p.global_position.x>float(arena[0])+float(arena[2])-110: direction=-1
	elif p.global_position.x<float(arena[0])+100: direction=1
	if not arrived and duel.mode in [&"bell_warning",&"bell_watch"] and is_instance_valid(bell):
		var branch: Dictionary=duel.geometry.side_branches[0 if bell.facing<0 else 1]
		var dx:=float(branch.rect[0])+float(branch.rect[2])*.5-p.global_position.x
		direction=signf(dx) if absf(dx)>4 else 0
	c.router.set_move_axis(direction)
	if c.traversal.state==&"free" and p.is_on_floor() and is_instance_valid(bell) and bell.state in [&"outbound",&"returning"] and last_ingress!=bell.get_instance_id() and p.global_position.distance_to(bell.global_position)<c.traversal.definition.hook_range+p.tuning.ground_speed*.2:
		last_ingress=bell.get_instance_id();held_until=tick+12;cast_after=tick
		c.router.set_move_axis(signf(bell.global_position.x-p.global_position.x))
		events.append({"event":"actual_bell_ingress_jump","tick":tick,"bell_id":last_ingress})
	var warning:="%s/%s" % [duel.mode,duel._attack_serial]
	if duel.mode==&"pursuit_warning" and warning!=last_warning:
		last_warning=warning
		direction=signf(p.global_position.x-duel.attack_goal.x)
		if direction==0: direction=-signf(duel.motor.global_position.x-p.global_position.x)
		c.router.set_move_axis(direction);held_until=tick+12
	c.router.set_jump_held(&"formal_guardian_pilot",tick<held_until)
	if tick>=cast_after and c.traversal.state==&"free" and not c.traversal.hook_used and is_instance_valid(bell) and bell.state in [&"outbound",&"returning"] and last_hook!=bell.get_instance_id():
		var start:=p.global_position+Vector2(0,-6)
		if start.distance_to(bell.global_position)<c.traversal.definition.hook_range-12 and can_intercept(bell,start):
			var ray:=PhysicsRayQueryParameters2D.create(start,bell.global_position,0xFFFFFFFF,[p.get_rid()]);ray.collide_with_areas=true
			if p.get_world_2d().direct_space_state.intersect_ray(ray).get("collider")==bell:
				last_hook=bell.get_instance_id()
				request(&"grapple",(moving_aim(bell,start)-start).normalized())
	fire()
func can_intercept(bell: GuardianRootBellV2, start: Vector2) -> bool:
	if bell.state==&"outbound": return true
	var toward:=bell.global_position.direction_to(bell.owner_motor.global_position)
	var closing:=(bell.velocity-bell.owner_motor.velocity).dot(toward)
	if closing<=0: return true
	var half:=duel.definition.collision_size*.5
	var extent:=absf(toward.x)*half.x+absf(toward.y)*half.y
	var until_owner:=maxf(0,bell.global_position.distance_to(bell.owner_motor.global_position)-extent-bell.config.bell_radius-bell.motion_safe_margin)/closing
	var travel:=start.distance_to(bell.global_position)
	var d:=app.controller.traversal.definition
	return until_owner>d.hook_windup+travel/d.hook_flight_speed+maxf(0,travel-d.hook_stop_distance)/d.hook_pull_speed+d.hook_contact_seconds
func moving_aim(bell: GuardianRootBellV2, start: Vector2) -> Vector2:
	var predicted:=bell.global_position
	var d:=app.controller.traversal.definition
	for unused: int in 3:
		var time:=d.hook_windup+start.distance_to(predicted)/d.hook_flight_speed
		predicted=bell.global_position+bell.velocity*time
		if bell.state==&"outbound": predicted+=Vector2(0,.5*bell.config.bell_gravity*time*time)
	return predicted
func fire() -> void:
	var c:=app.controller;var p:=app.player
	if not duel.core_open or tick<next_shot or c.traversal.busy() or c.traversal.state==&"hook_kick": return
	if duel.mode in [&"pursuit_warning",&"pursuit_flight"] and p.global_position.distance_to(duel.attack_goal-Vector2(0,18))<duel.definition.collision_size.x+24: return
	var half:=duel.definition.collision_size*.5-Vector2(4,4)
	var offsets: Array[Vector2]=[Vector2.ZERO,Vector2(-half.x,-half.y),Vector2(half.x,-half.y),Vector2(0,-half.y),Vector2(-half.x,half.y),Vector2(half.x,half.y)]
	for offset: Vector2 in offsets:
		var aim:=duel.motor.global_position+offset
		var ray:=PhysicsRayQueryParameters2D.create(p.global_position+Vector2(0,-6),aim,13,[p.get_rid()])
		if p.get_world_2d().direct_space_state.intersect_ray(ray).get("collider")!=duel.motor: continue
		if duel.mode==&"pursuit_flight":
			var lead:=minf(p.global_position.distance_to(aim)/p.tuning.projectile_speed,maxf(0,(duel.definition as BossDuelDefinition).pursuit_flight_seconds-duel._flight_age))
			aim+=duel.motor.velocity*lead+Vector2(0,.5*(duel.definition as BossDuelDefinition).pursuit_gravity*lead*lead)
		request(&"shoot_release",(aim-p.global_position).normalized())
		next_shot=tick+ceili(p.tuning.shot_cooldown*Engine.physics_ticks_per_second)
		return

func earn_current_restore_state() -> bool:
	var controller: PlayerController=app.controller
	var player: PlayerMotor=app.player
	var last_hook := -1
	var last_warning := ""
	var jump_until := -1
	var next_shot := 0
	var direction := 1
	for unused_frame: int in 2400:
		tick+=1
		if not app.lifetime.active or controller.actor_resources.health.terminal or duel.health.terminal: return false
		if duel.stage_phase==2 and duel._cycles>0 and duel.mode==&"bell_stagger" and duel.clock>0: return true
		if not app._boss_started:
			# Walk from actual gate-ready support into the real arena trigger.
			controller.router.set_move_axis(1)
		else:
			var arena: Array=duel.geometry.boss_arena
			if player.global_position.x>float(arena[0])+float(arena[2])-110: direction=-1
			elif player.global_position.x<float(arena[0])+100: direction=1
			var bell := duel._bell
			if duel.mode in [&"bell_warning",&"bell_watch"] and is_instance_valid(bell) and last_hook!=bell.get_instance_id():
				var branch: Dictionary=duel.geometry.side_branches[0 if bell.facing<0 else 1]
				var x:=float(branch.rect[0])+float(branch.rect[2])*.5
				direction=int(signf(x-player.global_position.x)) if absf(x-player.global_position.x)>4 else 0
			var warning := "%s/%s" % [duel.mode,duel._attack_serial]
			if duel.mode in [&"pursuit_warning",&"bell_warning"] and warning!=last_warning:
				last_warning=warning
				jump_until=tick+12
				if duel.mode==&"pursuit_warning":
					direction=int(signf(player.global_position.x-duel.attack_goal.x))
					if direction==0: direction=-int(signf(duel.motor.global_position.x-player.global_position.x))
			controller.router.set_move_axis(direction)
			controller.router.set_jump_held(&"restore_normal_combat",tick<jump_until)
			if controller.traversal.state==&"free" and not controller.traversal.hook_used and is_instance_valid(bell) and bell.state==&"outbound" and last_hook!=bell.get_instance_id():
				var start:=player.global_position+Vector2(0,-6)
				if start.distance_to(bell.global_position)<controller.traversal.definition.hook_range-12:
					var ray:=PhysicsRayQueryParameters2D.create(start,bell.global_position,0xFFFFFFFF,[player.get_rid()])
					ray.collide_with_areas=true
					if player.get_world_2d().direct_space_state.intersect_ray(ray).get("collider")==bell:
						var predicted:=bell.global_position
						for unused: int in 3:
							var time:=controller.traversal.definition.hook_windup+start.distance_to(predicted)/controller.traversal.definition.hook_flight_speed
							predicted=bell.global_position+bell.velocity*time+Vector2(0,.5*bell.config.bell_gravity*time*time)
						last_hook=bell.get_instance_id()
						request(&"grapple",(predicted-start).normalized())
			# Real normal bullets earn the low-HP phase; briefly release fire to
			# line up a physical Bell counter, then run() resumes the full fight.
			if duel.health.current>duel.health.capacity*(duel.definition as BossDuelDefinition).phase2_health_ratio and duel.core_open and tick>=next_shot and not controller.traversal.busy() and controller.traversal.state!=&"hook_kick":
				var half:=duel.definition.collision_size*.5-Vector2(4,4)
				var offsets: Array[Vector2]=[Vector2.ZERO,Vector2(-half.x,-half.y),Vector2(half.x,-half.y),Vector2(0,-half.y),Vector2(-half.x,half.y),Vector2(half.x,half.y)]
				for offset: Vector2 in offsets:
					var aim:=duel.motor.global_position+offset
					var ray:=PhysicsRayQueryParameters2D.create(player.global_position+Vector2(0,-6),aim,13,[player.get_rid()])
					if player.get_world_2d().direct_space_state.intersect_ray(ray).get("collider")!=duel.motor: continue
					request(&"shoot_release",(aim-player.global_position).normalized())
					next_shot=tick+ceili(player.tuning.shot_cooldown*Engine.physics_ticks_per_second)
					break
		await app.get_tree().physics_frame
	return false
