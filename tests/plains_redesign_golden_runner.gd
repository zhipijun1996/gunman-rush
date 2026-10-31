extends SceneTree
## Development-only continuous sequences. Production physics and old drivers are immutable.
const PHASES := [0.0, .125, .25, .375, .5, .625, .75, .875]
var assertions := 0
var failures := 0
var output := ""
var broken_bank := false
var smoke := false
var cleanup_ok := true
var historical_d079 := false
var observations: Array[Dictionary] = []
var controls: Array[Dictionary] = []

class RecordedTrace extends "res://tests/plains_region_trace.gd":
	var frames: Array[Dictionary] = []
	var events: Array[Dictionary] = []
	var phrase := "initial"
	var manifest: Dictionary
	var historical_d079 := false
	func point(v: Vector2) -> Array: return [v.x, v.y]
	func support() -> Array:
		var result: Array = []
		for x: float in [-11.0, 0.0, 11.0]:
			var feet := motor.global_position + Vector2(x, 18)
			var ray := PhysicsRayQueryParameters2D.create(feet + Vector2(0,-.1), feet + Vector2(0,8), motor.collision_mask, [motor.get_rid()])
			var hit := motor.get_world_2d().direct_space_state.intersect_ray(ray)
			result.append(not hit.is_empty() and (hit.normal as Vector2).dot(Vector2.UP) > .7)
		return result
	func state() -> Dictionary:
		var collisions: Array = []
		for i: int in motor.get_slide_collision_count():
			var collision := motor.get_slide_collision(i)
			collisions.append({"point":point(collision.get_position()),"normal":point(collision.get_normal()),"collider":collision.get_collider_id()})
		var hazards: Array = []
		for module: PlatformingModule in stage.modules:
			for saw: ModuleSawHazard in module.hazards:
				hazards.append({"id":saw.get_instance_id(),"position":point(saw.global_position),"radius":saw.definition.radius})
		var latches: Array = []
		if is_instance_valid(shot_latch_encounter):
			for latch: ShotLatch in shot_latch_encounter.latches:
				latches.append({"open":latch.is_open,"open_count":latch.open_count,"sequence_step":latch.sequence_step,"pending_id":latch._pending.get("id",""),"seen":latch._seen.keys(),"gate_disabled":latch.gate_shape.disabled,"clock":latch._clock,"motion_running":latch.motion_target.motion_running if latch.motion_mode else false,"motion_clock":latch.motion_target.motion_clock if latch.motion_mode else 0.0,"platform_position":point(latch.motion_target.global_position) if latch.motion_mode else []})
		return {"tick":trace_ticks,"phrase":phrase,"position":point(motor.global_position),"normal_velocity":point(motor.normal_velocity),"recoil_velocity":point(motor.recoil_velocity),"recoil_remaining":motor.recoil_burst_remaining,"grounded":motor.is_on_floor(),"support":support(),"collisions":collisions,"energy":controller.actor_resources.stamina.current,"energy_capacity":controller.actor_resources.stamina.capacity,"shot_charges":controller.action_resources.shot_charges,"max_air_shots":motor.tuning.max_air_shots,"max_jumps":motor.tuning.max_jumps,"hook_enabled":controller.traversal.hook_enabled,"wall_enabled":controller.traversal.wall_enabled,"shot_cost":controller.shot_energy.shot_energy_cost,"shooting_consumes_energy":controller.shot_energy.definition.shooting_consumes_energy,"used_jumps":controller.jump_ability.used_jumps,"cooldown":controller.shoot_ability.cooldown_remaining,"shot_cooldown":motor.tuning.shot_cooldown,"weapon":str(controller.shoot_ability.weapon.id),"session_id":controller.session_id,"motor_id":motor.get_instance_id(),"move_axis":controller.router.axis,"hazards":hazards,"safe":safe_trace,"continuous":continuous_trace,"latches":latches}
	func record(kind: String, extra: Dictionary = {}) -> void:
		var event := {"tick":trace_ticks+1,"phrase":phrase,"kind":kind,"position":point(motor.global_position)}
		event.merge(extra)
		events.append(event)
	func tick(count: int = 1) -> void:
		for unused: int in count:
			for action: Dictionary in controller.router._queue:
				record("input_request",{"action":str(action.type),"sequence":action.sequence,"direction":point(action.direction)})
			await super.tick(1) # Retains strict original whole-body and relative hazard sweeps.
			frames.append(state())
	func install(kind: String, forward: bool, low: bool, phase: float) -> bool:
		if audio_teardown == null: audio_teardown = load("res://tests/audio_teardown.gd")
		world = Node2D.new(); tree.root.add_child(world)
		stage = PlainsRegionAssembler.new(); world.add_child(stage)
		manifest = {"layout_id":"connected_region","nodes":[],"fixture_version":"plains-redesign-golden-v1","production_pool":false}
		var ids: Array = ["plains_windchime_well","plains_low_arch"] if kind == "main" else ["plains_recoil_step","plains_remote_sequence","plains_bell_ferry_control"]
		var offsets: Array = [Vector2.ZERO,Vector2(640,0)] if kind == "main" else [Vector2(0,-860),Vector2(520,-190),Vector2(1420,-190)]
		for index: int in ids.size():
			var module := PlatformingModule.new()
			module.definition = RandomStageGenerator.new().definition_for(ids[index]).duplicate(true)
			module.position = offsets[index]
			for saw: ModuleSawDefinition in module.definition.saws: saw.initial_phase = phase
			for ferry: ModuleMovingPlatformDefinition in module.definition.ferries: ferry.initial_phase = phase
			stage.add_child(module); stage.modules.append(module)
			manifest.nodes.append({"id":"golden_"+str(index),"module_id":ids[index],"offset":point(offsets[index]),"mirrored":false,"reverse_traversal":false})
		motor = PLAYER.instantiate()
		motor.position = stage.modules[0].world_entry() if forward else stage.modules[-1].world_exit() # Sole spawn, before adding body.
		world.add_child(motor)
		if historical_d079: motor.tuning.max_air_shots = 2 # Explicit historical D079 fixture only.
		controller = motor.get_node("Controller")
		check.call(controller.enable_shot_energy(preload("res://resources/player/plains_shot_energy.tres") if historical_d079 else null),"real shot-energy consumer enabled")
		controller.set_physics_process(false)
		motor.get_node("KeyboardMouseAdapter").set_process_unhandled_input(false)
		if low:
			var stamina := controller.actor_resources.stamina
			check.call(stamina.consume_continuous(stamina.current,stamina.epoch).accepted(),"initial boundary consumes real energy to zero")
		check.call(controller.actor_resources.stamina.current == (0.0 if low else controller.actor_resources.stamina.capacity),"observed initial energy before any tick")
		previous_body = Rect2(motor.position-Vector2(12,18),Vector2(24,36))
		for module: PlatformingModule in stage.modules:
			for saw: ModuleSawHazard in module.hazards: previous_hazards[saw.get_instance_id()] = saw.global_position
		manifest.shot_latch_plan = PlainsShotLatchPlanner.recorded_plan(manifest)
		shot_latch_encounter = GeneratedShotLatchEncounter.new(); world.add_child(shot_latch_encounter)
		check.call(shot_latch_encounter.setup(manifest,stage,controller,lifetime),"unaltered production latch planner/consumer")
		controller.jump_ability.jumped.connect(func(): record("accepted_jump"))
		controller.landed.connect(func(): record("accepted_landing"))
		controller.shoot_ability.shot_fired.connect(func(direction: Vector2,id: int):
			shots += 1
			record("accepted_shot",{"shot_id":id,"direction":point(direction),"energy":controller.actor_resources.stamina.current,"charges":controller.action_resources.shot_charges,"recoil_remaining":motor.recoil_burst_remaining}))
		controller.shoot_ability.shot_rejected.connect(func(reason: StringName): record("rejected_shot",{"reason":str(reason)}))
		controller.shoot_ability.projectile_impacted.connect(func(p: Vector2,d: Vector2): record("projectile_impact",{"impact":point(p),"direction":point(d)}))
		controller.actor_resources.stamina.changed.connect(func(result: ActorResourceResult): record("energy_transaction",{"event_id":str(result.event_id),"operation":str(result.operation),"amount":result.amount_applied,"current":result.snapshot.current,"status":result.status}))
		for latch: ShotLatch in shot_latch_encounter.latches:
			latch.health.changed.connect(func(result: ActorResourceResult): record("latch_health_commit",{"event_id":str(result.event_id),"operation":str(result.operation),"amount":result.amount_applied,"current":result.snapshot.current,"status":result.status}))
			latch.opened.connect(func(): record("latch_committed",{"open_count":latch.open_count,"gate_disabled":latch.gate_shape.disabled}))
		frames.append(state())
		await tick(3)
		return true
	func driver(module: PlatformingModule) -> Variant:
		var d = load("res://tests/branch_module_driver.gd").new()
		d.module=module; d.motor=motor; d.controller=controller; d.tick_callback=tick; d.check=check
		return d
	func settle() -> bool:
		controller.router.set_move_axis(0)
		for unused: int in 180:
			await tick()
			if motor.is_on_floor() and motor.normal_velocity.length()<.1 and motor.recoil_velocity.length()<.1 and controller.shoot_ability.cooldown_remaining<=0:
				return support().all(func(v: bool): return v)
		return false
	func traverse_phrase(module: PlatformingModule, forward: bool) -> bool:
		var d = driver(module)
		if not await d.wait_for_shot_energy(2 if module.definition.module_id==&"plains_remote_sequence" else 1): return false
		if module.definition.module_id==&"plains_bell_ferry_control":
			var latch: ShotLatch=shot_latch_encounter.for_module(module)
			var bell: StaticBody2D=latch.bell_body if forward else latch.access_bodies[0]
			if not await d.move_to(bell.global_position.x): return false
			if not latch.is_open:
				if not await d.wait_for_shot_energy(): return false
				controller.router.request_action(&"shoot_release",(motor.get_node("KeyboardMouseAdapter") as KeyboardMouseAdapter).world_direction(motor.get_canvas_transform()*bell.global_position))
				await tick(32)
				if not latch.motion_target.motion_running: return false
			if not await d.wait_for_shot_energy(): return false
			controller.router.request_action(&"shoot_release",(motor.get_node("KeyboardMouseAdapter") as KeyboardMouseAdapter).world_direction(motor.get_canvas_transform()*bell.global_position))
			await tick(32)
			check.call(not latch.motion_target.motion_running,"actual bell shot parks moving ferry")
			var parked_clock:=latch.motion_target.motion_clock
			var parked_position:=latch.motion_target.global_position
			await tick(30)
			check.call(latch.motion_target.motion_clock==parked_clock and latch.motion_target.global_position.is_equal_approx(parked_position),"park preserves real clock/position rather than resetting phase")
			if not await d.wait_for_shot_energy(): return false
			controller.router.request_action(&"shoot_release",(motor.get_node("KeyboardMouseAdapter") as KeyboardMouseAdapter).world_direction(motor.get_canvas_transform()*bell.global_position))
			await tick(32)
			check.call(latch.motion_target.motion_running and latch.motion_target.motion_clock>parked_clock,"real projectile restarts from parked phase")
			return await load("res://tests/plains_exploration_motion.gd").carrier(d,module,forward)
		if module.definition.module_id==&"plains_recoil_step" and not forward:
			if not await move_to(module.position.x+300): return false
			if not await jump_point(module.position+Vector2(170,1142)): return false
			return await move_to(module.world_entry().x)
		return await forward_module(module) if forward else await reverse_module(module)

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		elif arg=="--delete-far-bank": broken_bank=true
		elif arg=="--smoke": smoke=true
		elif arg=="--historical-d079": historical_d079=true
	run.call_deferred()
func check(ok: bool,message: String) -> void:
	assertions+=1
	if not ok: failures+=1; printerr("FAIL: "+message)
func phrase_checks(trace: RecordedTrace, label: String, module: PlatformingModule, forward: bool, closed: bool) -> void:
	var ev: Array = trace.events.filter(func(e: Dictionary): return e.phrase==label)
	var jumps: Array = ev.filter(func(e: Dictionary): return e.kind=="accepted_jump")
	var lands: Array = ev.filter(func(e: Dictionary): return e.kind=="accepted_landing")
	var shots: Array = ev.filter(func(e: Dictionary): return e.kind=="accepted_shot")
	var id := str(module.definition.module_id)
	if id in ["plains_windchime_well","plains_low_arch","plains_recoil_step"]:
		check(jumps.size()==1 and not lands.is_empty(),label+" one accepted jump and actual landing")
	if id=="plains_low_arch" and jumps.size()==1:
		var releases: Array=ev.filter(func(e: Dictionary): return e.kind=="input_request" and e.action=="jump_release" and e.tick>jumps[0].tick)
		check(not releases.is_empty() and int(releases[0].tick)-int(jumps[0].tick)==7,label+" seven-tick release under real low ceiling")
		check(shots.is_empty(),label+" arch uses zero shots")
	if id=="plains_windchime_well" and forward and closed:
		check(shots.size()==1 and float(shots[0].direction[1])>.9,label+" one real downward shot")
		var opened: Array=ev.filter(func(e: Dictionary): return e.kind=="latch_committed")
		check(opened.size()==1 and opened[0].gate_disabled,label+" actual projectile commits physical gate")
		if shots.size()==1 and jumps.size()==1 and not opened.is_empty() and not lands.is_empty():
			check(jumps[0].tick<shots[0].tick and shots[0].tick<=opened[0].tick and opened[0].tick<lands[-1].tick,label+" jump→same-shot gate/recoil→landing order")
			var after: Array=trace.frames.filter(func(f: Dictionary): return f.tick>shots[0].tick and f.tick<=int(shots[0].tick)+10)
			check(after.any(func(f: Dictionary): return f.recoil_remaining>0 and f.recoil_velocity[1]<0),label+" same accepted shot creates native upward recoil")
			check(after.any(func(f: Dictionary): return float(f.position[1])<float(shots[0].position[1])-100),label+" actual upward displacement exceeds 100 after same shot")
	if id=="plains_remote_sequence" and closed:
		check(shots.size()==2,label+" exact real remote shot budget")
		check(ev.any(func(e: Dictionary): return e.kind=="latch_committed"),label+" remote high bell commits gate")
		if forward and shots.size()==2:
			check(float(shots[1].position[1])<module.position.y+220,label+" second bell shot from actual upper support")

func run_case(kind: String, forward: bool, low: bool, phase: float) -> void:
	var trace := RecordedTrace.new(); trace.tree=self; trace.check=check; trace.historical_d079=historical_d079
	check(await trace.install(kind,forward,low,phase),"fixture installs")
	var body_id := trace.motor.get_instance_id(); var session := trace.controller.session_id
	if broken_bank:
		var module: PlatformingModule=trace.stage.modules[0]
		var far_floor:=module.definition.platforms[1]; var removed:=0
		for child: Node in module.get_children():
			if child is StaticBody2D and child.position.is_equal_approx(far_floor.get_center()):
				module.remove_child(child); child.free(); removed+=1
		check(removed==1,"negative removes exactly one actual receiver collider")
	var legs: Array = []
	for leg_index: int in 2:
		var direction := forward if leg_index==0 else not forward
		var indices: Array = range(trace.stage.modules.size())
		if not direction: indices.reverse()
		var phrases: Array = []
		var reached := true
		for index: int in indices:
			var module: PlatformingModule=trace.stage.modules[index]
			trace.phrase="%s/%d/%s"%[kind,leg_index,str(module.definition.module_id)]
			var start:=trace.state()
			var approach: bool=await trace.move_to((module.world_entry() if direction else module.world_exit()).x)
			var stopped: bool=approach and await trace.settle()
			var port:=module.definition.entry_port if direction else module.definition.exit_port
			check(stopped and module.port_accepts(port,trace.motor),trace.phrase+" actual supported port before action")
			var latch: ShotLatch=trace.shot_latch_encounter.for_module(module)
			var closed:=latch!=null and not latch.is_open
			var ok: bool=stopped and await trace.traverse_phrase(module,direction)
			ok=ok and await trace.settle()
			var destination:=module.world_exit() if direction else module.world_entry()
			ok=ok and trace.motor.is_on_floor() and trace.motor.global_position.distance_to(destination)<1
			check(ok,trace.phrase+" reaches exact supported destination")
			check(trace.safe_trace and trace.continuous_trace,trace.phrase+" original whole-body/hazard sweep and continuity")
			check(trace.motor.get_instance_id()==body_id and trace.controller.session_id==session,trace.phrase+" same body and session")
			if ok:
				check(module.port_accepts(module.definition.exit_port if direction else module.definition.entry_port,trace.motor),trace.phrase+" authored exit port accepts actual Motor state")
				phrase_checks(trace,trace.phrase,module,direction,closed)
				check(trace.controller.action_resources.shot_charges==trace.motor.tuning.max_air_shots and trace.controller.jump_ability.used_jumps==0,trace.phrase+" floor alone restores jumps/charges")
			phrases.append({"label":trace.phrase,"start":start,"end":trace.state(),"reached":ok})
			if not ok: reached=false; break
		legs.append({"forward":direction,"reached":reached,"phrases":phrases})
		if not reached: break
	observations.append({"kind":kind,"forward_entry":forward,"low_initial_energy":low,"phase":phase,"manifest":trace.manifest,"initial":trace.frames[0],"final":trace.state(),"legs":legs,"frames":trace.frames,"events":trace.events,"shots":trace.shots,"enemy_scope":"No enemies instantiated; formal enemy four-state/live encounter proof remains unverified"})
	var released: bool = await trace.release_test_world()
	cleanup_ok = released and cleanup_ok
func resource_controls() -> void:
	for low: bool in [true,false]:
		var trace:=RecordedTrace.new();trace.tree=self;trace.check=check;trace.historical_d079=historical_d079
		check(await trace.install("main",true,low,0),"resource control fixture")
		trace.phrase="air_low_energy" if low else "cooldown_guard"
		if low:
			trace.controller.router.request_action(&"jump");await trace.tick(2)
			var before:=trace.controller.actor_resources.stamina.current
			trace.controller.router.request_action(&"shoot_release",Vector2.DOWN);await trace.tick()
			check(trace.shots==0 and trace.controller.actor_resources.stamina.current==before and trace.motor.recoil_burst_remaining==0,"real low-air request rejected without charge/energy grant or recoil")
			check(trace.events.any(func(e: Dictionary): return e.kind=="rejected_shot"),"real insufficient-energy rejection event")
			trace.controller.router.request_action(&"jump_release")
			await trace.tick(90)
		else:
			check(await trace.move_to(130) and await trace.settle(),"cooldown safe supported bank")
			trace.controller.router.request_action(&"shoot_release",Vector2.UP);await trace.tick()
			trace.controller.router.request_action(&"shoot_release",Vector2.UP);await trace.tick()
			check(trace.shots==1 and trace.events.any(func(e: Dictionary): return e.kind=="rejected_shot"),"real sub-cooldown request rejected without extra projectile")
			await trace.tick(40)
		check(not trace.shot_latch_encounter.latches[0].is_open,"unhit bell keeps physical gate closed")
		check(trace.safe_trace and trace.continuous_trace,"resource guard full-body trace safe")
		controls.append({"kind":trace.phrase,"initial":trace.frames[0],"final":trace.state(),"events":trace.events,"frames":trace.frames})
		var released: bool = await trace.release_test_world()
		cleanup_ok = released and cleanup_ok
func current_resource_controls() -> void:
	var trace:=RecordedTrace.new();trace.tree=self;trace.check=check
	check(await trace.install("main",true,true,0),"current resource control fixture")
	trace.phrase="current_free_air_shot"
	check(trace.motor.tuning.max_air_shots==1 and not trace.controller.shot_energy.definition.shooting_consumes_energy,"actual current one-shot/free-shot policy")
	trace.controller.router.request_action(&"jump");await trace.tick(2)
	var before:=trace.controller.actor_resources.stamina.current
	var charges:=trace.controller.action_resources.shot_charges
	trace.controller.router.request_action(&"shoot_release",Vector2.DOWN);await trace.tick()
	check(before==0 and trace.shots==1 and charges==1 and trace.controller.action_resources.shot_charges==0 and trace.controller.actor_resources.stamina.current==before and trace.motor.recoil_burst_remaining>0,"zero focus still accepts one actual airborne projectile without energy debit")
	await trace.tick(int(ceil(trace.motor.tuning.shot_cooldown*60))+1)
	trace.controller.router.request_action(&"shoot_release",Vector2.DOWN);await trace.tick()
	check(not trace.motor.is_on_floor() and trace.shots==1 and trace.events.any(func(e:Dictionary):return e.kind=="rejected_shot" and e.reason=="empty"),"current airborne second shot retains actual empty-charge rejection after cooldown")
	trace.controller.router.request_action(&"jump_release")
	await trace.tick(90)
	check(await trace.settle(),"current control returns to supported safe floor")
	var focus_before:=trace.controller.actor_resources.stamina.current
	# The route driver steps physics_tick for deterministic whole-body sweeps.
	# Invoke the real complete Controller entry here so AirFocus owns recovery.
	trace.controller._physics_process(1.0/60.0)
	var focus_after:=trace.controller.actor_resources.stamina.current
	check(trace.motor.is_on_floor() and focus_after>focus_before and trace.controller.air_focus_ability.stamina_state==trace.controller.actor_resources.stamina,"actual Controller ground tick restores shared focus energy")
	check(trace.safe_trace and trace.continuous_trace and trace.controller.action_resources.shot_charges==1,"current complete control retains whole-body sweep and landing-only charge reset")
	controls.append({"kind":"current_free_air_shot","initial":trace.frames[0],"final":trace.state(),"events":trace.events,"frames":trace.frames,"focus_before":focus_before,"focus_after":focus_after})
	var released: bool=await trace.release_test_world()
	cleanup_ok=released and cleanup_ok
	# Keep the original real cooldown negative, using the current free policy.
	trace=RecordedTrace.new();trace.tree=self;trace.check=check
	check(await trace.install("main",true,false,0),"current cooldown control fixture")
	trace.phrase="cooldown_guard"
	check(await trace.move_to(130) and await trace.settle(),"current cooldown safe supported bank")
	trace.controller.router.request_action(&"shoot_release",Vector2.UP);await trace.tick()
	trace.controller.router.request_action(&"shoot_release",Vector2.UP);await trace.tick()
	check(trace.shots==1 and trace.events.any(func(e:Dictionary):return e.kind=="rejected_shot" and e.reason=="cooldown"),"current sub-cooldown request rejects extra projectile")
	await trace.tick(40)
	check(not trace.shot_latch_encounter.latches[0].is_open and trace.safe_trace and trace.continuous_trace,"current unhit bell remains physically closed with safe trace")
	controls.append({"kind":"cooldown_guard","initial":trace.frames[0],"final":trace.state(),"events":trace.events,"frames":trace.frames})
	released=await trace.release_test_world()
	cleanup_ok=released and cleanup_ok
func run() -> void:
	for kind: String in ["main","high"]:
		for forward: bool in [true,false]:
			for low: bool in [false,true]:
				for phase: float in ([0.0] if smoke or broken_bank else PHASES):
					await run_case(kind,forward,low,phase)
					if broken_bank: finish(); return
	if not broken_bank:
		if historical_d079: await resource_controls()
		else: await current_resource_controls()
	finish()
func finish() -> void:
	if output.is_empty() or FileAccess.file_exists(output): printerr("Unique --output required"); quit(2); return
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"fixture_version":"plains-redesign-golden-v1","production_pool":false,"historical_d079":historical_d079,"observations":observations,"controls":controls,"broken_bank":broken_bank,"cleanup_ok":cleanup_ok,"smoke":smoke,"assertions":assertions,"failures":failures})+"\n");file.close()
	print("PLAINS REDESIGN GOLDEN: %d assertions, %d failures"%[assertions,failures])
	quit(0 if failures==0 else 1)
