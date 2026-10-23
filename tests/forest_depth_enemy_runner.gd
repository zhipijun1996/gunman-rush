extends SceneTree
## Independent local goldens, not complete formal forest route admission.
const AUDIO := preload("res://tests/audio_teardown.gd")
const ECOLOGY_GEOMETRY := preload("res://scripts/generation/forest_ecology_geometry.gd")
var assertions := 0
var failures := 0
var tick := 0
var world: Node2D
var player: PlayerMotor
var controller: PlayerController
var policy: FrameDamagePolicy
var life: DemoLifetime
var enemies: Array[EnemyActor] = []
var contacts: Array[DemoContactEmitter] = []
var events: Array[Dictionary] = []
var cases: Array[Dictionary] = []
var comparisons: Array[Dictionary] = []
var stress_controls: Array[Dictionary] = []
class ThreadAblationPolicy extends FrameDamagePolicy:
	var disable_thread := false
	var suppressed: Array[Dictionary] = []
	func submit(request: DamageRequest) -> bool:
		if disable_thread and request.source_id==&"woven_thread_spider" and String(request.event_id).contains(":thread:"):
			suppressed.append({"physics_frame":Engine.get_physics_frames(),"event_id":String(request.event_id),"source":String(request.source_id),"target":String(request.target_id),"amount":request.amount,"actor_epoch":request.actor_epoch})
			return false
		return super.submit(request)
var comparison_frames: Array[Dictionary] = []
var comparison_id := ""
var _step_time_scale := 1.0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	assertions += 1
	print("FOREST DEPTH CHECK: ","PASS " if ok else "FAIL ",label)
	if not ok: failures += 1
func frames(count: int) -> void:
	for i: int in count:
		_step_time_scale=Engine.time_scale
		await physics_frame
		await process_frame
		tick+=1
		for index: int in enemies.size():
			contacts[index].enabled = not enemies[index].health.terminal
		if not comparison_id.is_empty():
			comparison_frames.append(_comparison_frame())
func slab(rect: Rect2, one_way := false, support_id: String = "") -> void:
	var body := StaticBody2D.new()
	body.position=rect.get_center()
	body.set_meta("ecology_support_id",support_id)
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size=rect.size
	shape.shape=rectangle
	shape.one_way_collision=one_way
	if one_way: body.add_to_group(&"one_way_platform")
	body.add_child(shape)
	world.add_child(body)
func cleanup() -> void:
	if not is_instance_valid(world): return
	controller.router.clear("forest_depth_fixture_cleanup")
	controller.active=false
	life.end()
	for actor: EnemyActor in enemies: actor.attack_behavior.cancel()
	var receipt: Dictionary = AUDIO.stop_fallback_voices(world)
	world.free()
	world=null
	enemies.clear()
	contacts.clear()
	check(await AUDIO.wait_fallback_release(receipt),"owned world audio backend actually released")
func fixture(at: Vector2 = Vector2(-30,282), geometry: Dictionary = {}) -> void:
	await cleanup()
	world=Node2D.new()
	root.add_child(world)
	if geometry.is_empty(): slab(Rect2(-1200,300,2600,50))
	else:
		for row: Dictionary in geometry.platforms:
			var rect: Array=row.rect
			slab(Rect2(rect[0],rect[1],rect[2],rect[3]),bool(row.one_way),str(row.role))
	player=load("res://scenes/player/player.tscn").instantiate()
	player.position=at
	world.add_child(player)
	controller=player.get_node("Controller")
	controller.enable_shot_energy()
	controller.traversal.grant(&"grapple")
	controller.shoot_ability.shot_fired.connect(_shot)
	controller.actor_resources.stamina.changed.connect(func(result: ActorResourceResult):
		events.append({"kind":"time_energy_changed","comparison":comparison_id,"tick":tick+1,"operation":str(result.operation),"amount":result.amount_applied,"current":result.snapshot.current,"capacity":result.snapshot.capacity,"epoch":result.snapshot.epoch,"session_id":controller.session_id,"controller_tick":controller._tick,"grounded":controller._was_grounded,"aiming":controller.router.aim_engaged,"focus_active":controller.air_focus_ability.active,"focus_air_time_before":controller.air_focus_ability.air_time_used,"real_delta":controller.get_physics_process_delta_time()/_step_time_scale}))
	life=DemoLifetime.new()
	policy=ThreadAblationPolicy.new()
	policy.lifetime=life
	world.add_child(policy)
	policy.register_target(&"player",controller.actor_resources.health,true)
	policy.batch_resolved.connect(_damage)
	await frames(5)
func _shot(aim: Vector2, serial: int) -> void:
	events.append({"kind":"accepted_shot","tick":tick,"serial":serial,"aim":[aim.x,aim.y],"projectiles":controller.shoot_ability._projectiles.size()})
func _damage(results: Array[DamageResult]) -> void:
	for result: DamageResult in results:
		events.append({"kind":"policy_result","tick":tick,"event_id":String(result.request.event_id),"source":String(result.request.source_id),"target":String(result.request.target_id),"hp":result.health.current})
func enemy(id: String, at: Vector2, instance_id: String = "") -> EnemyActor:
	var scene: PackedScene=load("res://scenes/enemies/patrol_drone.tscn" if id=="plains_charger" else "res://scenes/enemies/"+id+".tscn")
	var body := scene.instantiate() as EnemyMotor
	if id=="plains_charger":
		(body.get_node("Actor") as EnemyActor).definition=load("res://resources/enemies/plains_charger.tres")
	body.position=at
	world.add_child(body)
	var actor := body.get_node("Actor") as EnemyActor
	var source := StringName(instance_id if not instance_id.is_empty() else id)
	policy.bind_damageable(source,actor.damageable,actor.health)
	actor.bind_encounter(controller,policy,life,source,[])
	var contact := DemoContactEmitter.new()
	contact.policy=policy
	contact.controller=controller
	contact.source_id=StringName(str(source)+"_body")
	contact.half_size=actor.definition.collision_size*0.5
	body.add_child(contact)
	enemies.append(actor)
	contacts.append(contact)
	return actor
func ring(at: Vector2) -> void:
	var anchor := GrappleAnchor.new()
	anchor.position=at
	world.add_child(anchor)
func wait_state(behavior: EnemyAttackBehavior, wanted: StringName, limit := 240) -> bool:
	for i: int in limit:
		if behavior.state==wanted: return true
		await frames(1)
	return false
func shoot_to_death(actor: EnemyActor) -> void:
	for i: int in 6:
		if actor.health.terminal: return
		controller.router.request_action(&"shoot_release",(actor.motor.global_position-player.global_position).normalized())
		await frames(30)
func cross_with_fixed_ring(actor: EnemyActor) -> bool:
	ring(Vector2(175,190))
	await frames(2)
	controller.router.request_action(&"grapple",(Vector2(175,190)-player.global_position).normalized())
	controller.router.set_move_axis(1)
	var caught_fixed := false
	for i: int in 85:
		await frames(1)
		if controller.traversal.hook_target is GrappleAnchor: caught_fixed=true
	controller.router.set_move_axis(0)
	await frames(25)
	return caught_fixed and player.global_position.x>200 and actor.health.current==actor.health.capacity and controller.actor_resources.health.current==controller.actor_resources.health.capacity
func _shot_policy() -> Dictionary:
	var definition:=controller.shot_energy.definition
	return {"definition_path":definition.resource_path,"definition_sha256":FileAccess.get_sha256(definition.resource_path),"shooting_consumes_energy":definition.shooting_consumes_energy,"max_air_shots":controller.motor.tuning.max_air_shots}

func _focus_snapshot() -> Dictionary:
	return {"shared":controller.air_focus_ability.stamina_state==controller.actor_resources.stamina,"aiming":controller.router.aim_engaged,"active":controller.air_focus_ability.active,"available":controller.active and controller.router.has_application_focus and not paused and not controller.traversal.busy(),"time_scale":Engine.time_scale}

func _comparison_frame() -> Dictionary:
	var actors: Array = []
	for actor: EnemyActor in enemies:
		actors.append({"id":String(actor.definition.stable_id),"instance_id":String(actor.attack_behavior.source_id),"position":[actor.motor.global_position.x,actor.motor.global_position.y],"hp":actor.health.current,"state":String(actor.attack_behavior.state),"state_time":actor.attack_behavior.state_time})
	var support_id := ""
	if player.is_on_floor():
		var ray:=PhysicsRayQueryParameters2D.create(player.global_position,player.global_position+Vector2(0,24),1,[player.get_rid()])
		var support:=player.get_world_2d().direct_space_state.intersect_ray(ray)
		if not support.is_empty(): support_id=str((support.collider as Node).get_meta("ecology_support_id","root_floor"))
	return {"shot_policy":_shot_policy(),"focus":_focus_snapshot(),"stamina_capacity":controller.actor_resources.stamina.capacity,"controller_tick":controller._tick,"resource_epoch":controller.actor_resources.stamina.epoch,"session_id":controller.session_id,"support_id":support_id,"normal_velocity":[player.normal_velocity.x,player.normal_velocity.y],"recoil_velocity":[player.recoil_velocity.x,player.recoil_velocity.y],"burst_remaining":player.recoil_burst_remaining,"shot_cost":controller.shot_energy.shot_energy_cost,"contact_remaining":controller.traversal._contact_remaining,"comparison":comparison_id,"tick":tick,"position":[player.global_position.x,player.global_position.y],"grounded":player.is_on_floor(),"hp":controller.actor_resources.health.current,"stamina":controller.actor_resources.stamina.current,"shot_charges":controller.action_resources.shot_charges,"H_state":String(controller.traversal.state),"H_target":str(controller.traversal.hook_target.name) if is_instance_valid(controller.traversal.hook_target) else "","actors":actors}

func _walk_to_entry(entry: Vector2) -> bool:
	for i: int in 180:
		var dx:=entry.x-player.global_position.x
		if absf(dx)<=player.tuning.ground_speed/float(Engine.physics_ticks_per_second) and player.is_on_floor():
			controller.router.set_move_axis(0)
			await frames(1)
			return true
		controller.router.set_move_axis(signf(dx))
		await frames(1)
	controller.router.set_move_axis(0)
	return false

func _consume_focus_and_return(entry: Vector2) -> bool:
	# Current time energy is spent only by actual airborne focus, never by misses.
	var target:=controller.actor_resources.stamina.capacity*.25
	controller.router.set_move_axis(0)
	controller.router.set_aim(controller.router.current_device,Vector2.UP,true)
	controller.router.set_jump_held(&"low_time_energy_setup",true)
	for focus_tick: int in 240:
		await frames(1)
		if controller.actor_resources.stamina.current<=target:break
	controller.router.set_aim(controller.router.current_device,Vector2.UP,false)
	controller.router.set_jump_held(&"low_time_energy_setup",false)
	if not await _walk_to_entry(entry):return false
	var capacity:=controller.actor_resources.stamina.capacity
	return controller.actor_resources.stamina.current>=capacity*.2 and controller.actor_resources.stamina.current<=capacity*.4

func _phase_ready(spider: EnemyActor, lantern: EnemyActor, phase: String) -> bool:
	if phase=="fresh": return true
	if phase=="line_hold": return spider.attack_behavior.state==&"hold"
	var motion:=lantern.attack_behavior
	if motion.state!=&"travel": return false
	var relative:=lantern.motor.global_position.x-motion.home.x
	var limit:=lantern.definition.patrol_half_width*.75
	return (phase=="travel_left" and lantern.brain.direction<0 and relative<=-limit) or (phase=="travel_right" and lantern.brain.direction>0 and relative>=limit)

func run_combination(layout: String, strategy: String, legacy := false, variant: Dictionary = {}) -> void:
	comparison_id=""
	var geometry: Dictionary=ECOLOGY_GEOMETRY.woven_crown() if layout=="woven_crown" else {}
	var entry: Vector2=Vector2(geometry.spawn[0],geometry.spawn[1]) if not geometry.is_empty() else Vector2(10,282)
	await fixture(entry,geometry)
	var primary: EnemyActor
	var secondary: EnemyActor
	if layout=="root_split":
		slab(Rect2(140,190,220,16),true,"main_branch")
		ring(Vector2(175,150))
		primary=enemy("plains_charger",Vector2(160,284))
		secondary=enemy("forest_thread_spider",Vector2(270,150))
		(secondary.attack_behavior as ForestThreadSpiderBehavior).configure_line(Vector2(120,172),Vector2(260,172))
	else:
		for row: Dictionary in geometry.hook_anchors: ring(Vector2(row.position[0],row.position[1]))
		var spider_row: Dictionary=geometry.enemies[0]
		var lantern_row: Dictionary=geometry.enemies[1]
		primary=enemy(str(spider_row.behavior_id),Vector2(spider_row.position[0],spider_row.position[1]),str(spider_row.id))
		(primary.attack_behavior as ForestThreadSpiderBehavior).configure_line(Vector2(spider_row.line_start[0],spider_row.line_start[1]),Vector2(spider_row.line_end[0],spider_row.line_end[1]))
		secondary=enemy(str(lantern_row.behavior_id),Vector2(lantern_row.position[0],lantern_row.position[1]),str(lantern_row.id))
	# All controls use identical layout/real actor definitions/resources per layout.
	# Legacy naturally retains its own HP/body/range/timing, reported as limitations.
	var setup_event_start:=events.size()
	var setup_started:=tick
	var phase_name:=str(variant.get("phase","fresh"))
	comparison_id="setup/"+str(variant.get("id",layout+"/"+strategy))
	(policy as ThreadAblationPolicy).disable_thread=bool(variant.get("line_disabled",false))
	var setup_ok:=true
	if not variant.is_empty():
		for phase_tick: int in 600:
			if _phase_ready(primary,secondary,phase_name): break
			await frames(1)
		setup_ok=_phase_ready(primary,secondary,phase_name)
		if bool(variant.get("dead_lantern",false)):
			await shoot_to_death(secondary)
			setup_ok=setup_ok and secondary.health.terminal and await _walk_to_entry(entry)
		if bool(variant.get("low_resource",false)):
			setup_ok=setup_ok and await _consume_focus_and_return(entry)
	var setup_state:=_comparison_frame()
	comparison_id=str(variant.id) if not variant.is_empty() else layout+"/"+("legacy/" if legacy else "depth/")+strategy
	var exit_x: float=float(geometry.exit.position[0]) if not geometry.is_empty() else 450.0
	var began:=tick
	var event_start:=events.size()
	var first:=_comparison_frame()
	var observed_preview:=false
	var requested_H:=false
	var caught_expected:=false
	var upper_seen:=false
	var dangerous_observed:=false
	var preview_cancelled:=false
	if strategy=="bank_shoot":
		await shoot_to_death(primary)
	elif strategy=="direct_walk":
		pass
	else:
		if bool(variant.get("react_now",false)):
			for frame: Dictionary in comparison_frames:
				if frame.tick>=setup_started and str(frame.comparison).begins_with("setup/"):
					for actor_row: Dictionary in frame.actors:
						if actor_row.id=="forest_thread_spider" and actor_row.state=="telegraph": observed_preview=true
			observed_preview=observed_preview or primary.attack_behavior.state==&"telegraph"
		else: observed_preview=await wait_state(primary.attack_behavior,&"telegraph")
		if strategy=="lower_wait" or strategy=="wait_line":
			if strategy=="lower_wait":
				controller.router.set_move_axis(-1)
				for retreat_tick: int in 40:
					if player.global_position.x < -60: break
					await frames(1)
				controller.router.set_move_axis(0)
			var dangerous_seen:=false
			for i: int in 240:
				var phase: StringName=primary.attack_behavior.state
				dangerous_seen=dangerous_seen or phase in [&"rush",&"attack",&"hold"]
				if not dangerous_seen and phase==&"recovery":
					preview_cancelled=true
					break
				if dangerous_seen and phase in [&"retract",&"recovery",&"brake"]: break
				await frames(1)
			dangerous_observed=dangerous_seen
		else:
			var target: Vector2=secondary.motor.global_position if strategy=="live_H" else (Vector2(175,150) if layout=="root_split" else Vector2(geometry.hook_anchors[0].position[0],geometry.hook_anchors[0].position[1]))
			controller.router.request_action(&"grapple",(target-player.global_position).normalized())
			requested_H=true
	controller.router.set_move_axis(1)
	var jumped:=false
	var jump_release_at: int=-1
	var live_kick_seen:=false
	var recoil_request_tick: int=-1
	var recoil_before: Dictionary={}
	var recoil_after: Dictionary={}
	for i: int in 260:
		if strategy=="live_H":
			live_kick_seen=live_kick_seen or controller.traversal.state==&"hook_kick"
			if live_kick_seen and caught_expected and recoil_request_tick<0 and controller.traversal.state==&"free" and not player.is_on_floor():
				recoil_request_tick=tick
				recoil_before=_comparison_frame()
				controller.router.request_action(&"shoot_release",Vector2.LEFT)
			elif recoil_request_tick>=0 and recoil_after.is_empty() and tick>recoil_request_tick:
				recoil_after=_comparison_frame()
		if not jumped and player.is_on_floor():
			for candidate: EnemyActor in enemies:
				if candidate.health.terminal: continue
				var offset:=candidate.motor.global_position-player.global_position
				var half_player: Vector2=(player.get_node("CollisionShape2D") as CollisionShape2D).shape.get_rect().size*0.5
				var half_enemy:=candidate.definition.collision_size*0.5
				var takeoff_distance:=half_player.x+half_enemy.x+player.tuning.ground_speed*player.tuning.jump_hold_duration
				if offset.x>0 and offset.x<takeoff_distance and absf(offset.y)<half_player.y+half_enemy.y:
					controller.router.request_action(&"jump")
					jumped=true
					jump_release_at=i+int(ceil(player.tuning.jump_hold_duration*float(Engine.physics_ticks_per_second)))
					break
		if i==jump_release_at: controller.router.request_action(&"jump_release")
		var hook_target:=controller.traversal.hook_target
		if is_instance_valid(hook_target):
			caught_expected=caught_expected or (hook_target==secondary.motor if strategy=="live_H" else hook_target is GrappleAnchor)
		upper_seen=upper_seen or str(_comparison_frame().support_id)=="main_branch"
		if player.global_position.x>exit_x and player.is_on_floor(): break
		if controller.actor_resources.health.terminal: break
		await frames(1)
	controller.router.set_move_axis(0)
	await frames(3)
	var last:=_comparison_frame()
	var result: Dictionary={"id":comparison_id,"layout":layout,"geometry_version":str(geometry.get("version","root_split_local")),"strategy":strategy,"legacy":legacy,"start":first,"end":last,"ticks":tick-began,"completed":player.global_position.x>exit_x and not controller.actor_resources.health.terminal,"observed_preview":observed_preview,"requested_H":requested_H,"caught_expected_H_target":caught_expected,"upper_support_seen":upper_seen,"committed_attack_seen":dangerous_observed,"preview_cancelled_on_retreat":preview_cancelled,"recoil_request_tick":recoil_request_tick,"recoil_before":recoil_before,"recoil_after":recoil_after,"primary_definition":{"id":String(primary.definition.stable_id),"hp":primary.health.capacity,"body":[primary.definition.collision_size.x,primary.definition.collision_size.y],"range":primary.definition.activation_range,"telegraph":primary.definition.telegraph_duration,"line_damage":(primary.definition as ForestEnemyDefinition).line_damage if primary.definition is ForestEnemyDefinition else 0.0},"event_start":event_start,"event_end":events.size(),"scope":"Local combined fixture. Success alone does not prove mechanic value; controls preserve their original Definitions."}
	if variant.is_empty(): comparisons.append(result)
	else:
		result["variant"]=variant.duplicate(true)
		result["setup_ok"]=setup_ok
		result["setup_start_tick"]=setup_started
		result["setup_event_start"]=setup_event_start
		result["setup_state"]=setup_state
		result["thread_suppressed"]=(policy as ThreadAblationPolicy).suppressed.duplicate(true)
		result["geometry_hash"]=JSON.stringify(geometry).sha256_text()
		stress_controls.append(result)
	comparison_id=""

func run() -> void:
	await fixture(Vector2(80,282))
	var spider := enemy("forest_thread_spider",Vector2(260,190))
	var thread := spider.attack_behavior as ForestThreadSpiderBehavior
	check(spider.definition.is_valid() and thread!=null,"spider real Definition and dispatcher")
	await frames(90)
	check(thread.state==&"idle" and controller.actor_resources.health.current==controller.actor_resources.health.capacity,"unconfigured line fail-closed without attacks")
	check(not thread.configure_line(Vector2.ZERO,Vector2(500,0)),"overlong line rejected")
	check(thread.configure_line(Vector2(20,282),Vector2(140,282)),"authored bounded line accepted")
	check(await wait_state(thread,&"hold"),"spider whole preview/extend precedes hold")
	var hp := controller.actor_resources.health.current
	await frames(30)
	check(controller.actor_resources.health.current==hp-1,"standing in occupied line takes one real policy damage")
	await frames(8)
	check(controller.actor_resources.health.current==hp-1,"same line cycle never repeats damage")
	cases.append({"id":"spider_stand_line","tick":tick,"hp_before":hp,"hp_after":controller.actor_resources.health.current})
	await fixture(Vector2(0,282))
	spider=enemy("forest_thread_spider",Vector2(260,190))
	thread=spider.attack_behavior as ForestThreadSpiderBehavior
	thread.configure_line(Vector2(20,282),Vector2(140,282))
	check(await wait_state(thread,&"telegraph"),"spider safe observation before line locks")
	check(await cross_with_fixed_ring(spider),"spider actual fixed-H upper bypass never requires killing")
	cases.append({"id":"spider_live_bypass","tick":tick,"enemy_hp":spider.health.current,"player_hp":controller.actor_resources.health.current})
	await fixture()
	spider=enemy("forest_thread_spider",Vector2(260,190))
	thread=spider.attack_behavior as ForestThreadSpiderBehavior
	thread.configure_line(Vector2(20,282),Vector2(140,282))
	await shoot_to_death(spider)
	check(spider.health.terminal and not thread.line_active,"spider actual bullet death removes owned dangerous line")
	cases.append({"id":"spider_bullets","tick":tick,"terminal":spider.health.terminal})
	await fixture(Vector2(80,282))
	spider=enemy("forest_thread_spider",Vector2(260,190))
	thread=spider.attack_behavior as ForestThreadSpiderBehavior
	thread.configure_line(Vector2(20,282),Vector2(140,282))
	check(await wait_state(thread,&"telegraph"),"cancel fixture reaches real preview")
	var phase := thread.state_time
	paused=true
	for i: int in 8: await process_frame
	check(thread.state_time==phase,"pause freezes line preview")
	paused=false
	life.invalidate_actor()
	await frames(1)
	check(not thread.line_active and thread.state==&"recovery","actor epoch cancels old line before activation")
	controller.active=false
	hp=controller.actor_resources.health.current
	await frames(100)
	check(not thread.line_active and controller.actor_resources.health.current==hp,"inactive target leaves no damaging old line")
	cases.append({"id":"spider_cancel_pause_epoch_inactive","tick":tick})
	for strategy: String in ["bank_shoot","lower_wait","fixed_H"]:
		await run_combination("root_split",strategy,true)
	for strategy: String in ["bank_shoot","wait_line","fixed_H","live_H"]:
		await run_combination("woven_crown",strategy)
	for phase_name: String in ["fresh","line_hold"]:
		for strategy: String in ["direct_walk","wait_line","fixed_H","live_H"]:
			for disabled: bool in [false,true]:
				await run_combination("woven_crown",strategy,false,{"id":"ablation/"+phase_name+"/"+strategy+("/off" if disabled else "/on"),"phase":phase_name,"line_disabled":disabled,"react_now":phase_name!="fresh"})
	for phase_name: String in ["travel_left","travel_right"]:
		await run_combination("woven_crown","live_H",false,{"id":"phase/"+phase_name,"phase":phase_name,"react_now":true})
	await run_combination("woven_crown","fixed_H",false,{"id":"dead_lantern/fixed_H","dead_lantern":true})
	await run_combination("woven_crown","live_H",false,{"id":"low_resource/live_H","low_resource":true,"react_now":true})
	await cleanup()
	var output := "res://build/forest_depth/ecology/native"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): output=argument.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output)
	var file := FileAccess.open(output+"/capture.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"independent local real actors/Router/projectiles/policy; no formal full route claimed","assertions":assertions,"failures":failures,"cases":cases,"events":events,"comparisons":comparisons,"stress_controls":stress_controls,"comparison_frames":comparison_frames},"  "))
	file.close()
	print("FOREST DEPTH ENEMIES: %s assertions, %s failures" % [assertions,failures])
	quit(0 if failures==0 else 1)
