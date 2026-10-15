extends SceneTree
## Real physics fixtures and an actual DemoApp failure/retry. Fixture results
## never stand in for the separately captured formal-route consumer.
const PLAYER := preload("res://scenes/player/player.tscn")
const ENEMY := preload("res://scenes/enemies/patrol_drone.tscn")
var assertions := 0
var failures := 0
var output := "res://build/plains_redesign/encounter/native.json"
var cases: Array = []
var frames: Array = []
var events: Array = []
var world: Node2D
var motor: PlayerMotor
var controller: PlayerController
var enemy: EnemyMotor
var actor: EnemyActor
var policy: FrameDamagePolicy
var life: DemoLifetime
var ticks := 0
var recovery_only := false
var reward_resource := ""
var reward_entry_only := false
var entry_policy := "kill_from_bank_v1"
var entry_phase := 0
var entry_map := 1
var entry_tier := "high"
var entry_low := false
var restore_unsafe_entry := false
var restore_unsafe_return := false
var entry_seed := "level-design-v2-baseline"

# This observer adds per-frame live enemy bodies, never changes movement policy.
class RewardTrace extends "res://tests/level_formal_trace.gd":
	var guard_id := ""
	func tick(count: int = 1) -> void:
		for unused: int in count:
			await super.tick()
			if not observed_frames.is_empty():
				observed_frames[-1]["reward_guard"] = runtime_snapshot(true).enemies.filter(func(e: Dictionary): return e.id==guard_id)

func _initialize() -> void: run.call_deferred()
func verify(ok: bool, label: String) -> void:
	assertions+=1
	if not ok: failures+=1;print("ENCOUNTER POLICY FAILURE: ",label)
func floor_body(rect: Rect2) -> void:
	var body:=StaticBody2D.new();body.position=rect.get_center()
	var shape:=CollisionShape2D.new();var box:=RectangleShape2D.new();box.size=rect.size;shape.shape=box;body.add_child(shape);world.add_child(body)
func fixture(behavior: String,blocked: bool=false,near: bool=false) -> void:
	if is_instance_valid(world):world.free()
	world=Node2D.new();root.add_child(world)
	frames=[];events=[];ticks=0
	floor_body(Rect2(-1800,300,4000,40))
	if blocked:floor_body(Rect2(320,0,30,300))
	motor=PLAYER.instantiate();motor.position=Vector2(180,282);world.add_child(motor)
	controller=motor.get_node("Controller");verify(controller.enable_shot_energy(),"real formal shot energy enabled")
	life=DemoLifetime.new();policy=FrameDamagePolicy.new();policy.lifetime=life;world.add_child(policy);policy.register_target(&"player",controller.actor_resources.health,true)
	enemy=ENEMY.instantiate();enemy.position=Vector2(320 if near else 600,182 if behavior=="diver" else 282)
	actor=enemy.get_node("Actor");actor.definition=(preload("res://resources/enemies/patrol_drone.tres") if behavior=="patrol" else PlainsEncounterPlanner.definition_for_behavior(behavior)).duplicate(true)
	world.add_child(enemy);policy.bind_damageable(&"fixture_enemy",actor.damageable,actor.health);actor.bind_encounter(controller,policy,life,&"fixture_enemy",[])
	var contact:=DemoContactEmitter.new();contact.controller=controller;contact.policy=policy;contact.source_id=&"fixture_contact";contact.half_size=actor.definition.collision_size*.5+Vector2.ONE;enemy.add_child(contact)
	policy.player_fatal.connect(func():controller.die())
	controller.shoot_ability.shot_fired.connect(func(direction:Vector2,id:int):events.append({"tick":ticks+1,"kind":"shot","shot_id":id,"event_id":"%s:%s:%s"%[motor.get_instance_id(),controller.session_id,id],"direction":[direction.x,direction.y]}))
	controller.shoot_ability.shot_rejected.connect(func(reason:StringName):events.append({"tick":ticks+1,"kind":"rejected","reason":str(reason)}))
	policy.batch_resolved.connect(func(results:Array[DamageResult]):
		for result:DamageResult in results:events.append({"tick":ticks+1,"kind":"committed","event_id":str(result.request.event_id),"target":str(result.request.target_id),"health_after":result.health.current,"lethal":result.lethal}))
	controller.energy_recovered.connect(func(amount:float,airborne:bool):events.append({"tick":ticks+1,"kind":"refund","amount_applied":amount,"airborne":airborne}))
	if actor.attack_behavior != null:actor.attack_behavior.state_changed.connect(func(state:StringName):events.append({"tick":ticks+1,"kind":"enemy_state","state":str(state),"position":[enemy.global_position.x,enemy.global_position.y]}))
	await advance(3)
func advance(count:int=1) -> void:
	for unused:int in count:
		var requests:Array=[]
		for action:Dictionary in controller.router._queue:requests.append({"type":str(action.type),"direction":[action.direction.x,action.direction.y]})
		await physics_frame;await process_frame;ticks+=1
		frames.append({"tick":ticks,"position":[motor.global_position.x,motor.global_position.y],"grounded":motor.is_on_floor(),"energy":controller.actor_resources.stamina.current,"health":controller.actor_resources.health.current,"axis":controller.router.axis,"requests":requests,"enemy_position":[enemy.global_position.x,enemy.global_position.y],"enemy_health":actor.health.current,"enemy_state":str(actor.attack_behavior.state) if actor.attack_behavior!=null else "patrol","actor_processing":actor.is_physics_processing(),"projectile_count":actor.attack_behavior._projectiles.filter(func(p):return is_instance_valid(p) and not p.spent).size() if actor.attack_behavior!=null else 0})
func count_kind(kind:String) -> int:return events.filter(func(e:Dictionary):return e.kind==kind).size()
func wait_ready() -> void:
	for unused:int in 90:
		if controller.shoot_ability.cooldown_remaining<=0 and motor.is_on_floor():return
		await advance()
func fire(direction:Vector2) -> void:
	controller.router.request_action(&"shoot_release",direction);await advance()
func snapshot_case(id:String,extra:Dictionary={}) -> void:
	var receipts:Array=[]
	for id_value:StringName in controller.actor_resources.stamina._receipts:
		var value:Dictionary=controller.actor_resources.stamina._receipts[id_value];var result:ActorResourceResult=value.result
		receipts.append({"event_id":str(id_value),"status":int(result.status),"operation":str(result.operation),"amount_applied":result.amount_applied,"requested_amount":value.amount,"current":result.snapshot.current})
	var row:Dictionary={"id":id,"scope":"normally_scheduled_real_physics_fixture_not_formal_region","frames":frames.duplicate(true),"events":events.duplicate(true),"receipts":receipts,"enemy_terminal":actor.health.terminal,"enemy_health":actor.health.current,"player_health":controller.actor_resources.health.current,"motor_id":motor.get_instance_id(),"session":controller.session_id};row.merge(extra);cases.append(row)
func guards() -> void:
	await fixture("charger",true)
	await fire(Vector2.RIGHT);await advance(40)
	verify(actor.health.current==actor.health.capacity,"real solid occludes real enemy damage")
	verify(count_kind("shot")==1 and events.filter(func(e:Dictionary):return e.kind=="committed" and e.target=="fixture_enemy").is_empty(),"blocked accepted shot is not a hit")
	snapshot_case("solid_occlusion")
	await fixture("charger")
	await fire(Vector2.UP);await fire(Vector2.UP)
	verify(count_kind("shot")==1 and events.any(func(e:Dictionary):return e.kind=="rejected" and e.reason=="cooldown"),"real cooldown rejects extra accepted shot")
	snapshot_case("cooldown_rejected")
	await fixture("charger")
	for unused:int in 5:
		await wait_ready();await fire(Vector2.UP)
	verify(is_zero_approx(controller.actor_resources.stamina.current),"five legal shots actually consume initial energy")
	await wait_ready();controller.router.request_action(&"jump");await advance(2)
	var before:=count_kind("shot");await fire(Vector2.UP)
	verify(not motor.is_on_floor() and count_kind("shot")==before and events.any(func(e:Dictionary):return e.kind=="rejected" and e.reason=="energy"),"real airborne low energy rejects without injection")
	snapshot_case("air_energy_rejected")
func kills_and_states() -> void:
	for behavior:String in ["patrol","charger","diver","hopper","sentry","fan_sentry"]:
		await fixture(behavior)
		var ineligible:bool=motor.global_position.distance_to(actor.attack_behavior.home if actor.attack_behavior!=null else actor._spawn)>actor.definition.activation_range
		verify(ineligible and actor.is_physics_processing() and not actor.health.terminal,"living engagement-ineligible actor still processing "+behavior)
		for unused:int in 6:
			if actor.health.terminal:break
			await wait_ready();await fire((enemy.global_position+enemy.velocity*(motor.global_position.distance_to(enemy.global_position)/motor.tuning.projectile_speed)-motor.global_position).normalized());await advance(40)
		await advance(30)
		verify(actor.health.terminal and actor.health.current==0,"three real projectiles actually kill "+behavior)
		var hits:=events.filter(func(e:Dictionary):return e.kind=="committed" and e.target=="fixture_enemy")
		verify(hits.size()==3 and hits[-1].lethal,"actual terminal damage receipts "+behavior)
		var refund_count:=count_kind("refund")
		await wait_ready();await fire((enemy.global_position+enemy.velocity*(motor.global_position.distance_to(enemy.global_position)/motor.tuning.projectile_speed)-motor.global_position).normalized());await advance(55)
		verify(count_kind("refund")==refund_count,"actual dead enemy supplies no new refund "+behavior)
		snapshot_case("kill_and_dead_"+behavior,{"initial_engagement_ineligible":ineligible,"activation_range":actor.definition.activation_range})
	for behavior:String in ["charger","diver","hopper","sentry","fan_sentry"]:
		await fixture(behavior,false,true)
		var telegraphed:=false;var recovered:=false;var origin:=enemy.global_position
		for unused:int in 300:
			if actor.attack_behavior.state==&"telegraph":telegraphed=true
			controller.router.set_move_axis(-1 if actor.attack_behavior.state==&"attack" and motor.global_position.x>65 else 0)
			await advance()
			if telegraphed and actor.attack_behavior.state==&"recovery":recovered=true;break
		verify(telegraphed and recovered and events.any(func(e:Dictionary):return e.kind=="enemy_state" and e.state=="attack") and not actor.health.terminal,"real bait observes telegraph attack recovery "+behavior)
		var moved:=enemy.global_position.distance_to(origin)>2
		if behavior in ["charger","diver","hopper"]:verify(moved,"actual moving-away body "+behavior)
		snapshot_case("bait_state_"+behavior,{"observed_telegraph":telegraphed,"observed_recovery":recovered,"body_moved":moved})
func formal_recovery() -> void:
	if is_instance_valid(world):world.free()
	var app:=DemoApp.new();app.meta_persistence_enabled=false;root.add_child(app)
	var proof_seed := "level-design-v2-baseline/05" if reward_resource=="heart" else "level-design-v2-baseline"
	# Existing audited cohort /05 orders healing before coin, inside the real two-choice offer.
	verify(app.start_plains(proof_seed),"actual normal formal start")
	for unused:int in 120:
		await physics_frame;await process_frame
		if not app._stage_pending and app.stage is PlainsRegionStage:break
	var driver=load("res://tests/level_formal_trace.gd").new()
	verify(driver.attach(app,"return",0,"kill_from_bank_v1"),"formal observer attached normally")
	driver.frame_budget=12000;driver.allow_expected_recovery=true;driver.probe_reward_errors=true
	driver.preferred_reward_resource=reward_resource
	var tutorial_ok:bool=await driver.tutorial();verify(tutorial_ok,"actual tutorial before failure probe")
	var module:PlatformingModule=null
	for candidate:PlatformingModule in driver.stage.modules:
		if candidate.definition.module_id==&"plains_windchime_well" and candidate.position.y>-400:module=candidate;break
	verify(module!=null,"actual first well selected by actual definition")
	if module==null:app.queue_free();return
	if reward_resource=="heart":
		# A real first pit mistake makes the real healing offer eligible. No HP
		# write, injected damage or special fixture reward replaces normal input.
		driver.critical_traversal+=1
		verify(await driver.move_to(module.position.x+250,500),"actual pre-heal bank reached normally")
		var initial_returns:int=driver._recovery_serial
		for unused:int in 180:
			app.controller.router.set_move_axis(clampf((module.position.x+330-app.player.global_position.x)/5.5,-1,1));await driver.tick()
			if driver._recovery_serial>initial_returns:break
		app.controller.router.set_move_axis(0);await driver.tick(2);driver.critical_traversal-=1
		verify(driver._recovery_serial==initial_returns+1 and app.controller.actor_resources.health.current<app.controller.actor_resources.health.capacity,"real pit makes healing choice eligible")
	var world_id:=app.stage.get_instance_id();var enemy_ids:Array=app.stage.enemies.map(func(e):return e.get_instance_id())
	if reward_resource=="heart":
		# Traverse the actual edge's original module helpers, then interact on
		# the near bank before walking through its automatic supply pickup.
		var approach_ok:=true
		for edge:Dictionary in app.stage.generated.manifest.connections:
			if edge.a!="area_0_1" or edge.b!="area_1_1":continue
			for index:Variant in edge.modules:
				var part:PlatformingModule=driver.stage.modules[int(index)]
				if not await driver.move_to(part.world_entry().x,500) or not await driver.forward_module(part):approach_ok=false;break
		verify(approach_ok,"actual main modules reach near reward bank before supply")
	else:
		verify(await driver.follow_to("area_1_1"),"normal main phrase before reward/recovery probe")
	var chest:Dictionary=app.stage.chests.filter(func(c:Dictionary):return str(c.id).ends_with("medium_0"))[0]
	# Stay inside the native80 interaction radius but outside the nearby
	# automatic supply pickup, so the real heal option remains eligible.
	var claim_x:float=chest.position.x-(70.0 if reward_resource=="heart" else 0.0)
	verify(await driver.move_to(claim_x,500) and await driver.claim_required_chest(str(chest.id)),"actual first medium claimed before failure")
	if reward_resource=="heart":
		var area_position:Vector2=PlainsRegionGenerator.new()._point(PlainsRegionGenerator.new()._area(driver.stage.manifest,"area_1_1").position)
		verify(await driver.move_to(area_position.x,500),"actual center reached after supported healing transaction")
		driver.current_area="area_1_1"
	var reward_id:String=str(chest.id)
	var before_wallet:int=app.wallet.balance
	verify(await driver.follow_to("area_0_1"),"same body legitimately returns to well start")
	var bank_x:float=module.position.x+250
	verify(await driver.move_to(bank_x,500),"normal input reaches actual bank")
	var latch:ShotLatch=driver.shot_latch_encounter.for_module(module)
	verify(latch.is_open,"real completed well phrase already opened gate before actual failure")
	app.controller.router.request_action(&"shoot_release",Vector2.UP);await driver.tick()
	var before_runtime:Dictionary=driver.runtime_snapshot(true)
	var before_resources:Dictionary=load("res://tools/level_capability_snapshot.gd").capture(app.controller,app.build,"before_expected_pit_failure")
	var failure_start_tick:int=driver.trace_ticks
	var before_health:=app.controller.actor_resources.health.current;var before_session:=app.controller.session_id;var before_epoch:=app.lifetime.actor_epoch;var before_open:=latch.open_count
	verify(before_health>1,"nonfatal failure precondition not injected")
	var before_recovery:int=driver._recovery_serial
	driver.critical_traversal+=1
	for unused:int in 180:
		app.controller.router.set_move_axis(clampf((module.position.x+330-app.player.global_position.x)/5.5,-1,1));await driver.tick()
		if driver._recovery_serial>before_recovery:break
	app.controller.router.set_move_axis(0);await driver.tick(2);driver.critical_traversal-=1
	var returned_runtime:Dictionary=driver.runtime_snapshot(true)
	var returned_resources:Dictionary=load("res://tools/level_capability_snapshot.gd").capture(app.controller,app.build,"after_actual_segment_return")
	var return_tick:int=driver.trace_ticks
	var natural_energy:=true
	var previous_energy:float=float(before_resources.shot_energy.current)
	for frame:Dictionary in driver.observed_frames.slice(failure_start_tick):
		if float(frame.shot_energy)-previous_energy>app.controller.shot_energy.ground_energy_recovery/Engine.physics_ticks_per_second+.0001:natural_energy=false
		previous_energy=float(frame.shot_energy)
	verify(natural_energy,"failure return does not inject shooting energy")
	verify(driver._recovery_serial==before_recovery+1,"real pit contact triggers exactly one normal segment return")
	verify(app.controller.actor_resources.health.current==before_health-1 and app.controller.session_id==before_session+1 and app.lifetime.actor_epoch==before_epoch+1,"real damage session epoch selective return")
	verify(chest.claimed and app.region_state.claimed.has(reward_id) and app.wallet.balance==before_wallet,"real claimed reward and wallet persist across failure")
	verify(app.stage.get_instance_id()==world_id and app.stage.enemies.map(func(e):return e.get_instance_id())==enemy_ids and latch.is_open and latch.open_count==before_open,"same scene/enemy/latch instances retain committed opening")
	verify(await driver.move_to(module.world_entry().x,500) and await driver.forward_module(module),"real retry uses legal input after normal return")
	cases.append({"id":"formal_pit_return_retry","root_seed":proof_seed,"capture_contract_version":3,"map_index":app.director.stage_index,"manifest":app.stage.generated.manifest,"formal_run_manifest_final":app.director.manifest.snapshot(),"scope":"actual_live_DemoApp_normal_start","frames":driver.observed_frames,"events":driver.events,"resource_receipts":driver.resource_receipts,"policy_observations":driver.policy_observations,"failure_start_tick":failure_start_tick,"return_tick":return_tick,"before_actor_epoch":before_epoch,"after_actor_epoch":app.lifetime.actor_epoch,"before_runtime":before_runtime,"returned_runtime":returned_runtime,"before_resources":before_resources,"returned_resources":returned_resources,"before_health":before_health,"after_health":app.controller.actor_resources.health.current,"before_session":before_session,"after_session":app.controller.session_id,"recovery_count":driver._recovery_serial,"reward_id":reward_id,"claimed_after":chest.claimed,"wallet_before":before_wallet,"wallet_after":app.wallet.balance,"latch_open":latch.is_open,"same_scene":app.stage.get_instance_id()==world_id,"retry_position":[app.player.global_position.x,app.player.global_position.y],"expected_exit":[module.world_exit().x,module.world_exit().y]})
	app.queue_free();await process_frame
func drive_reward_entry(driver: RewardTrace, state: Dictionary) -> void:
	await driver.tick(entry_phase)
	state.tutorial=await driver.tutorial()
	if not state.tutorial:state.done=true;return
	var goal:="deep_"+entry_tier
	var edge:Dictionary=driver.stage.manifest.connections.filter(func(e:Dictionary):return e.kind=="challenge" and e.b==goal)[0]
	state.approach=await driver.follow_to(edge.a)
	if not state.approach:state.done=true;return
	state.entry_tick=driver.trace_ticks
	state.entry_position=[driver.motor.global_position.x,driver.motor.global_position.y]
	state.entry_energy=driver.controller.actor_resources.stamina.current
	state.entry_guard=driver.runtime_snapshot(true).enemies.filter(func(e:Dictionary):return e.id==driver.guard_id)
	if entry_low:
		# Spend through accepted real Router shots, never write stamina. Ground
		# regeneration/cooldown remain active and every receipt is observed.
		driver.critical_traversal+=1
		for unused:int in 8:
			if driver.controller.actor_resources.stamina.current<20:break
			while driver.controller.shoot_ability.cooldown_remaining>0:await driver.tick()
			driver.controller.router.request_action(&"shoot_release",Vector2.RIGHT)
			await driver.tick()
			if not await driver.move_to(float(state.entry_position[0]),120):break
		state.low_tick=driver.trace_ticks
		state.low_energy=driver.controller.actor_resources.stamina.current
		driver.critical_traversal-=1
	state.trial_start_tick=driver.trace_ticks
	state.trial=await driver.deep_trial(goal)
	state.trial_end_tick=driver.trace_ticks
	for e:Dictionary in driver.stage.manifest.connections:
		if e.a==goal and e.kind=="drop":driver.current_area=e.b;state.return_area=e.b
	if state.trial:state.camp=await driver.follow_to(str(driver.stage.manifest.merchant_id))
	state.done=true

func formal_reward_entry() -> void:
	var app:=DemoApp.new();app.meta_persistence_enabled=false;root.add_child(app)
	verify(app.start_plains(entry_seed),"reward entry actual normal spawn")
	for unused:int in 120:
		await physics_frame;await process_frame
		if app.stage is PlainsRegionStage and not app._stage_pending:break
	if entry_map==2:
		app.lifetime.stage_epoch+=1;app.lifetime.actor_epoch+=1
		app.director._enter_stage(2,&"boss");app._stage_entered(DemoRunResult.new())
		for unused:int in 120:
			await physics_frame;await process_frame
			if app.stage is PlainsRegionStage and app.stage.map_index==2 and not app._stage_pending:break
	var driver:=RewardTrace.new()
	verify(driver.attach(app,"return",0,entry_policy),"unchanged formal policy attached")
	driver.frame_budget=12000
	var goal:="deep_"+entry_tier
	var edge:Dictionary=driver.stage.manifest.connections.filter(func(e:Dictionary):return e.kind=="challenge" and e.b==goal)[0]
	driver.guard_id="plains/enemy/"+str(edge.a)
	if restore_unsafe_entry:
		# Explicit physical counterexample, before any input: restore the original
		# recorded conflicting guard placement, not fake a damage event or JSON.
		for i:int in driver.formal_stage.enemies.size():
			if driver.formal_stage.enemy_manifest[i].id!=driver.guard_id:continue
			var guard:EnemyMotor=driver.formal_stage.enemies[i]
			var actor:=guard.get_node("Actor") as EnemyActor
			var base:Array=PlainsRegionGenerator.new()._area(driver.stage.manifest,edge.a).position
			guard.position=Vector2(base[0]+70,base[1]-110)
			actor.attack_behavior.home=guard.position;actor._spawn=guard.position
	if restore_unsafe_return:
		var drop:Dictionary=driver.stage.manifest.connections.filter(func(e:Dictionary):return e.a==goal and e.kind=="drop")[0]
		var anchor:Array=drop.return_polyline[1]
		var bank:Dictionary=driver.stage.manifest.areas.filter(func(a:Dictionary):return Vector2(a.position[0],a.position[1]).distance_to(Vector2(anchor[0],anchor[1]))<1)[0]
		for i:int in driver.formal_stage.enemies.size():
			if driver.formal_stage.enemy_manifest[i].id!="plains/enemy/"+str(bank.id):continue
			var guard:EnemyMotor=driver.formal_stage.enemies[i]
			var actor:=guard.get_node("Actor") as EnemyActor
			guard.position=Vector2(anchor[0],anchor[1])+(Vector2(70,-110) if actor.definition.aerial else Vector2(130,0))
			actor.attack_behavior.home=guard.position;actor._spawn=guard.position
	var state:Dictionary={"done":false,"tutorial":false,"approach":false,"trial":false,"camp":false}
	drive_reward_entry.call_deferred(driver,state)
	while not state.done and not driver.terminated:await process_frame
	verify(state.done and state.tutorial and state.approach and state.trial and state.camp,"actual spawn to complete high chain, claim, different return and camp")
	var chest:Dictionary=driver.formal_stage.chests.filter(func(c:Dictionary):return c.tier==entry_tier)[0]
	verify(chest.claimed and app.region_state.claimed.has(chest.id),"actual modal callback and world claim")
	if entry_low:verify(state.get("low_energy",100)<20,"naturally spent low shot energy before recovery")
	if entry_policy=="bait_then_bypass_v1":
		var survivors:Array=driver.runtime_snapshot(true).enemies.filter(func(e:Dictionary):return e.id==driver.guard_id)
		verify(survivors.size()==1 and survivors[0].health>0 and not survivors[0].terminal,"high entrance guard remains alive through actual bypass")
	var modules:Array=[]
	for id:String in [goal+"_entry",goal+"_ferry",goal+"_recoil",goal+"_landing"]:
		var module:PlatformingModule=driver.named(id)
		modules.append({"id":id,"module_id":str(module.definition.module_id),"entry":[module.world_entry().x,module.world_entry().y],"exit":[module.world_exit().x,module.world_exit().y]})
	cases.append({"id":"formal_reward_entry","scope":"actual_live_DemoApp_normal_start_reward_entry_observer","map_index":entry_map,"tier":entry_tier,"phase":entry_phase,"policy":entry_policy,"natural_low":entry_low,"restored_unsafe":restore_unsafe_entry,"restored_unsafe_return":restore_unsafe_return,"root_seed":entry_seed,"state":state,"guard_id":driver.guard_id,"modules":modules,"manifest":driver.stage.manifest,"frames":driver.observed_frames,"events":driver.events,"resource_receipts":driver.resource_receipts,"policy_observations":driver.policy_observations,"outcome":driver.outcome,"diagnostics":driver.diagnostics,"formal_run_manifest_final":app.director.manifest.snapshot(),"initial_capability":driver.initial_capability,"final_capability":driver.final_capability,"final_runtime":driver.runtime_snapshot(true),"chest_id":chest.id,"claimed":chest.claimed,"driver_sha256":FileAccess.get_sha256("res://tests/level_formal_trace.gd"),"observer_sha256":FileAccess.get_sha256("res://tests/plains_encounter_policy_runner.gd")})
	app.queue_free();await process_frame

func run() -> void:
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		elif arg=="--recovery-only":recovery_only=true
		elif arg=="--reward-entry":reward_entry_only=true
		elif arg.begins_with("--entry-policy="):entry_policy=arg.trim_prefix("--entry-policy=")
		elif arg.begins_with("--entry-phase="):entry_phase=arg.trim_prefix("--entry-phase=").to_int()
		elif arg.begins_with("--entry-map="):entry_map=arg.trim_prefix("--entry-map=").to_int()
		elif arg.begins_with("--entry-tier="):entry_tier=arg.trim_prefix("--entry-tier=")
		elif arg=="--entry-low":entry_low=true
		elif arg=="--restore-unsafe-entry":restore_unsafe_entry=true
		elif arg=="--restore-unsafe-return":restore_unsafe_return=true
		elif arg.begins_with("--entry-seed="):entry_seed=arg.trim_prefix("--entry-seed=")
		elif arg.begins_with("--reward-resource="):reward_resource=arg.trim_prefix("--reward-resource=")
	verify(reward_resource in ["","coin","heart","note"],"bounded legal reward proof mode")
	if reward_entry_only:await formal_reward_entry()
	elif recovery_only:await formal_recovery()
	else:await guards();await kills_and_states()
	if is_instance_valid(world):world.free()
	var report:Dictionary={"schema_version":1,"artifact_kind":"actual_encounter_policy_proof","assertions":assertions,"failures":failures,"cases":cases,"engine":Engine.get_version_info().string,"scope":"physics fixtures and explicitly identified live DemoApp scenario, not all-player or device/fun acceptance"}
	DirAccess.make_dir_recursive_absolute(output.get_base_dir());var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report));file.close()
	print("PLAINS ENCOUNTER POLICY: %s assertions, %s failures, %s cases"%[assertions,failures,cases.size()]);quit(0 if failures==0 else 1)
