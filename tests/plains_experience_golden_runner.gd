extends SceneTree
## Development-only continuous sequences. Production physics and old drivers are immutable.
const PHASES := [0.0, .125, .25, .375, .5, .625, .75, .875]
var assertions := 0
var failures := 0
var output := ""
var broken_bank := false
var smoke := false
var observations: Array[Dictionary] = []
var controls: Array[Dictionary] = []
var tolerance: Array=[]
var exploration_first: Array=[]
var tolerance_only:=false
var space_controls: Array=[]

class RecordedTrace extends "res://tests/plains_region_trace.gd":
	var frames: Array[Dictionary] = []
	var events: Array[Dictionary] = []
	var phrase := "initial"
	var manifest: Dictionary
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
		return {"tick":trace_ticks,"phrase":phrase,"position":point(motor.global_position),"normal_velocity":point(motor.normal_velocity),"recoil_velocity":point(motor.recoil_velocity),"recoil_remaining":motor.recoil_burst_remaining,"grounded":motor.is_on_floor(),"support":support(),"collisions":collisions,"energy":controller.actor_resources.stamina.current,"energy_capacity":controller.actor_resources.stamina.capacity,"shot_charges":controller.action_resources.shot_charges,"max_air_shots":motor.tuning.max_air_shots,"max_jumps":motor.tuning.max_jumps,"hook_enabled":controller.traversal.hook_enabled,"wall_enabled":controller.traversal.wall_enabled,"shot_cost":controller.shot_energy.shot_energy_cost,"used_jumps":controller.jump_ability.used_jumps,"cooldown":controller.shoot_ability.cooldown_remaining,"shot_cooldown":motor.tuning.shot_cooldown,"weapon":str(controller.shoot_ability.weapon.id),"session_id":controller.session_id,"motor_id":motor.get_instance_id(),"move_axis":controller.router.axis,"hazards":hazards,"safe":safe_trace,"continuous":continuous_trace,"latches":latches}
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
		world = Node2D.new(); tree.root.add_child(world)
		stage = PlainsRegionAssembler.new(); world.add_child(stage)
		manifest = {"layout_id":"connected_region","nodes":[],"fixture_version":"plains-redesign-golden-v1","production_pool":false}
		var ids: Array = ["plains_windchime_well","plains_low_arch"] if kind == "main" else ["plains_remote_sequence"] if kind=="remote" else ["plains_low_arch"] if kind=="arch" else ["plains_bell_ferry_control"]
		var offsets: Array = [Vector2.ZERO,Vector2(640,0)] if kind == "main" else [Vector2.ZERO]
		for index: int in ids.size():
			var module := PlatformingModule.new()
			module.definition = RandomStageGenerator.new().definition_for(ids[index]).duplicate(true)
			module.position = offsets[index]
			for saw: ModuleSawDefinition in module.definition.saws: saw.initial_phase = phase
			for ferry: ModuleMovingPlatformDefinition in module.definition.ferries: ferry.initial_phase = phase
			stage.add_child(module); stage.modules.append(module)
			manifest.nodes.append({"id":"golden_"+str(index),"module_id":ids[index],"offset":point(offsets[index]),"mirrored":false,"reverse_traversal":false})
		if kind=="creek":
			var bank:=PlatformingModule.new();bank.definition=PlatformingModuleDefinition.new();bank.definition.module_id=&"creek_cache_bank"
			bank.definition.world_bounds=Rect2(350,100,140,160);bank.definition.platforms.assign([Rect2(350,210,140,18)]);bank.definition.one_way_platform_indices.assign([0])
			bank.definition.anchors.assign([Vector2(400,192),Vector2(440,192)]);bank.definition.entry_port=PlainsRegionGenerator.new()._port("entry",Vector2(400,192));bank.definition.exit_port=PlainsRegionGenerator.new()._port("exit",Vector2(440,192))
			stage.add_child(bank);stage.modules.append(bank)
		motor = PLAYER.instantiate()
		motor.position = stage.modules[0].world_entry() if forward else stage.modules[1 if kind=="main" else 0].world_exit() # Sole spawn, before adding body.
		world.add_child(motor)
		controller = motor.get_node("Controller")
		check.call(controller.enable_shot_energy(),"real shot-energy consumer enabled")
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
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		if arg=="--delete-island":broken_bank=true
		if arg=="--tolerance-only":tolerance_only=true
	run.call_deferred()
func check(ok: bool,message: String) -> void:
	assertions+=1
	if not ok:failures+=1;printerr("FAIL "+message)
func run() -> void:
	for kind: String in ([] if tolerance_only else ["creek"] if broken_bank else ["remote","creek"]):
		for forward: bool in ([true] if broken_bank else [true,false]):
			for low: bool in ([false] if broken_bank else [false,true]):
				for phase: float in ([0.0] if broken_bank else [0.0,.5]):
					var trace:=RecordedTrace.new();trace.tree=self;trace.check=check
					check(await trace.install(kind,forward,low,phase),"native install "+kind)
					var module: PlatformingModule=trace.stage.modules[0]
					trace.phrase=kind
					var passed:=false
					var visits: Array=[]
					if kind=="remote":
						passed=await trace.traverse_phrase(module,forward)
						var shots: Array=trace.events.filter(func(e: Dictionary):return e.kind=="accepted_shot")
						check(shots.size()==2,"remote exactly two real accepted projectiles")
						check(trace.shot_latch_encounter.latches[0].is_open,"remote physical final door open")
						if forward and shots.size()==2:check(shots[1].position[1]<220 and absf(shots[1].position[0]-shots[0].position[0])>300,"remote second shot uses changed elevated sightline")
					else:
						var bank: PlatformingModule=trace.stage.modules[1]
						module.set_meta("discovery_latch",trace.shot_latch_encounter.for_module(module))
						if broken_bank:
							var removed:=0
							for node: Node in bank.get_children():
								if node is StaticBody2D:node.free();removed+=1
							check(removed==1,"negative removes actual island collider")
						passed=await load("res://tests/plains_creek_discovery_motion.gd").traverse(trace.driver(module),module,bank,func():
							visits.append(trace.state());trace.record("grounded_island_callback")
							check(trace.motor.is_on_floor() and trace.motor.position.distance_to(Vector2(420,192))<1,"claim callback on actual stopped island support")
							await trace.tick(4),forward)
						check(visits.size()==1,"exactly one real island observation/claim window")
					check(passed,"native "+kind+" reaches receiving dock")
					check(trace.safe_trace and trace.continuous_trace,"native complete swept body and input continuity")
					observations.append({"kind":kind,"forward":forward,"low":low,"phase":phase,"passed":passed,"visits":visits,"frames":trace.frames,"events":trace.events,"enemy_scope":"no enemies; formal four-state proof is separate","claim_scope":"grounded callback only; no formal chest award claimed"})
					trace.world.free()
	if not broken_bank:
		await tolerance_cases()
		await arch_space_controls()
		if not tolerance_only:await upper_first_case()
	var data: Dictionary={"space_controls":space_controls,"tolerance":tolerance,"exploration_first":exploration_first,"version":"plains-experience-golden-v1","assertions":assertions,"failures":failures,"deleted_island":broken_bank,"observations":observations}
	if not output.is_empty():var f:=FileAccess.open(output,FileAccess.WRITE);f.store_string(JSON.stringify(data));f.close()
	print("PLAINS EXPERIENCE NATIVE: %s assertions, %s failures"%[assertions,failures]);quit(1 if failures else 0)

func tolerance_cases() -> void:
	for forward: bool in [true,false]:
		for release: int in [5,7,9]:
			for offset: int in [-8,0,8]:
				var trace:=RecordedTrace.new();trace.tree=self;trace.check=check
				await trace.install("arch",forward,false,0)
				var module: PlatformingModule=trace.stage.modules[0]
				var driver=trace.driver(module)
				var takeoff: int=(275 if forward else 365)+offset
				var approach: bool=await driver.move_to(takeoff)
				trace.phrase="arch_release_%s_offset_%s_forward_%s"%[release,offset,forward]
				trace.controller.router.request_action(&"jump")
				for frame: int in 120:
					trace.controller.router.set_move_axis(1 if forward else -1)
					if frame==release:trace.controller.router.request_action(&"jump_release")
					await trace.tick()
					if frame>release and trace.motor.is_on_floor():break
				trace.controller.router.request_action(&"jump_release")
				var passed: bool=approach and await driver.move_to((module.world_exit() if forward else module.world_entry()).x) and trace.safe_trace and trace.continuous_trace
				check(passed,"main short-hop complete input envelope release%s offset%s forward%s"%[release,offset,forward])
				tolerance.append({"forward":forward,"release_ticks":release,"takeoff_offset":offset,"passed":passed,"definition_version":module.definition.definition_version,"definition_sha256":FileAccess.get_sha256("res://resources/generation/modules/plains_low_arch.tres"),"platforms":module.definition.platforms.map(func(r:Rect2):return [r.position.x,r.position.y,r.size.x,r.size.y]),"saw_origin":[module.definition.saws[0].origin.x,module.definition.saws[0].origin.y],"saw_radius":module.definition.saws[0].radius,"frames":trace.frames,"events":trace.events,"scope":"bounded 3x3 actual input envelope both directions; no ordinary-player/device acceptance"})
				trace.world.free()
func follow(trace: RecordedTrace,path: Array) -> bool:
	for i: int in range(path.size()-1):
		var found:=false
		for edge: Dictionary in trace.stage.manifest.connections:
			if edge.condition!="open":continue
			if edge.a==path[i] and edge.b==path[i+1]:
				if not await trace.walk_edge(edge,true):return false
				found=true;break
			if edge.bidirectional and edge.b==path[i] and edge.a==path[i+1]:
				if not await trace.walk_edge(edge,false):return false
				found=true;break
		if not found:return false
	return true
func upper_first_case() -> void:
	var trace:=RecordedTrace.new();trace.tree=self;trace.check=check
	var m: Dictionary=PlainsRegionGenerator.new().generate(PlainsRegionCampaign.seed_for("level-design-v2-baseline/04",2),PlayerTuning.load_default(),false,"","advanced").manifest
	check(await trace.fixture(m,PlayerTuning.load_default()),"upper-first actual advanced manifest fixture")
	trace.controller.shoot_ability.shot_fired.connect(func(direction:Vector2,id:int):trace.record("accepted_shot",{"direction":trace.point(direction),"shot_id":id}))
	var tutorial: bool=await trace.tutorial()
	var upper: bool=tutorial and await follow(trace,m.route_intents.upper_discovery)
	var edge: Dictionary=m.connections.filter(func(e:Dictionary):return e.a=="area_0_1" and e.b=="area_1_1")[0]
	var untouched: bool=not trace.shot_latch_encounter.for_module(trace.stage.modules[int(edge.modules[0])]).is_open
	check(upper and untouched,"upper-first reaches camp while new main remote door remains genuinely closed")
	var to_receiver: bool=upper and await follow(trace,["area_2_1","area_1_1"])
	var start:=trace.trace_ticks
	var returned: bool=to_receiver and await trace.walk_edge(edge,false)
	check(returned and trace.safe_trace and trace.continuous_trace,"upper-first same body opens previously closed remote from right and returns")
	var actual_shots: Array=trace.events.filter(func(e:Dictionary):return e.kind=="accepted_shot" and e.tick>start)
	check(actual_shots.size()==2,"closed right-side return consumes two actual accepted projectiles")
	exploration_first.append({"seed":m.seed,"manifest_hash":m.manifest_hash,"upper":upper,"main_untouched":untouched,"latch_index":trace.shot_latch_encounter.latches.find(trace.shot_latch_encounter.for_module(trace.stage.modules[int(edge.modules[0])])),"start_tick":start,"end_tick":trace.trace_ticks,"returned":returned,"shots":actual_shots,"frames":trace.frames,"events":trace.events,"scope":"actual full generated geometry; no instantiated enemies, modal or formal rewards"})
	trace.world.free()

func arch_space_controls() -> void:
	for kind: String in ["walk_without_jump","held_jump_bonks_ceiling"]:
		var trace:=RecordedTrace.new();trace.tree=self;trace.check=check
		await trace.install("arch",true,false,0)
		var module: PlatformingModule=trace.stage.modules[0]
		var driver=trace.driver(module)
		check(await driver.move_to(275),"space control supported approach")
		trace.phrase=kind
		if kind=="held_jump_bonks_ceiling":trace.controller.router.request_action(&"jump")
		for unused: int in 60:
			trace.controller.router.set_move_axis(1)
			await trace.tick()
		trace.controller.router.request_action(&"jump_release")
		var exit_reached: bool=await driver.move_to(module.world_exit().x)
		var ceiling_contact: bool=trace.frames.any(func(f:Dictionary):return f.collisions.any(func(c:Dictionary):return c.normal[1]>.7))
		if kind=="walk_without_jump":check(not trace.safe_trace,"real unchanged-radius recessed wheel still rejects walking through")
		else:check(ceiling_contact,"held jump really contacts low ceiling; short release has smoother clearance")
		space_controls.append({"kind":kind,"exit_reached":exit_reached,"ceiling_contact":ceiling_contact,"safe":trace.safe_trace,"frames":trace.frames,"events":trace.events,"scope":"real hazard persistence and headroom observation, not claim all long holds fail"})
		trace.world.free()
