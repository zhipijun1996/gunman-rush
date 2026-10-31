extends SceneTree
var assertions:=0
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	assertions+=1
	if not ok: failures+=1;printerr("FAIL: "+message)
func run() -> void:
	var g:=PlainsRegionGenerator.new()
	for id: String in ["plains_low_arch","plains_twin_gears","plains_ferry_channel","plains_windchime_rush","plains_windchime_well"]:
		for phase: float in [0.0,.125,.25,.375,.5,.625,.75,.875]:
			for forward: bool in [true,false]:
				var trace=load("res://tests/plains_region_trace.gd").new();trace.tree=self;trace.check=check
				trace.world=Node2D.new();root.add_child(trace.world)
				trace.stage=PlainsRegionAssembler.new();trace.world.add_child(trace.stage)
				var module:=PlatformingModule.new();module.definition=RandomStageGenerator.new().definition_for(id).duplicate(true)
				for saw: ModuleSawDefinition in module.definition.saws: saw.initial_phase=phase
				for ferry: ModuleMovingPlatformDefinition in module.definition.ferries: ferry.initial_phase=phase
				trace.stage.add_child(module);trace.stage.modules.append(module)
				trace.motor=preload("res://game/player/player.tscn").instantiate();trace.motor.position=module.world_entry() if forward else module.world_exit();trace.world.add_child(trace.motor)
				trace.controller=trace.motor.get_node("Controller");trace.controller.set_physics_process(false);trace.controller.enable_shot_energy();trace.motor.get_node("KeyboardMouseAdapter").set_process_unhandled_input(false)
				trace.previous_body=Rect2(trace.motor.position-Vector2(12,18),Vector2(24,36))
				for saw: ModuleSawHazard in module.hazards: trace.previous_hazards[saw.get_instance_id()]=saw.global_position
				var m: Dictionary={"layout_id":"connected_region","nodes":[{"id":"probe","module_id":id,"offset":[0,0],"mirrored":false,"reverse_traversal":false}]}
				m.shot_latch_plan=PlainsShotLatchPlanner.recorded_plan(m)
				trace.shot_latch_encounter=GeneratedShotLatchEncounter.new();trace.world.add_child(trace.shot_latch_encounter)
				check(trace.shot_latch_encounter.setup(m,trace.stage,trace.controller,trace.lifetime),"probe uses real bell consumer")
				await trace.tick(3)
				var ok: bool=await trace.forward_module(module) if forward else await trace.reverse_module(module)
				check(ok and trace.safe_trace and trace.continuous_trace,"actual swept-safe operation "+id+" phase="+str(phase)+" forward="+str(forward))
				if not await load("res://tests/audio_teardown.gd").drain_world(trace.world):
					failures += 1;push_error("TEST AUDIO TEARDOWN: playback did not release within 1000ms");quit(1);return
				trace.world.free()
	await return_bell_guard()
	print("PLAINS EXPLORATION MODULES: %s assertions, %s failures" % [assertions,failures])
	quit(1 if failures else 0)

func return_bell_guard() -> void:
	var trace=load("res://tests/plains_region_trace.gd").new();trace.tree=self;trace.check=check
	trace.world=Node2D.new();root.add_child(trace.world);trace.stage=PlainsRegionAssembler.new();trace.world.add_child(trace.stage)
	var module:=PlatformingModule.new();module.definition=RandomStageGenerator.new().definition_for("plains_windchime_well");trace.stage.add_child(module);trace.stage.modules.append(module)
	trace.motor=preload("res://game/player/player.tscn").instantiate();trace.motor.position=Vector2(450,-190);trace.world.add_child(trace.motor)
	trace.controller=trace.motor.get_node("Controller");trace.controller.set_physics_process(false);trace.controller.enable_shot_energy()
	# Explicit firing-origin fixture; real projectile, wall query and latch consumer.
	var m: Dictionary={"layout_id":"connected_region","nodes":[{"id":"probe","module_id":"plains_windchime_well","offset":[0,0],"mirrored":false,"reverse_traversal":false}]};m.shot_latch_plan=PlainsShotLatchPlanner.recorded_plan(m)
	trace.shot_latch_encounter=GeneratedShotLatchEncounter.new();trace.world.add_child(trace.shot_latch_encounter);trace.shot_latch_encounter.setup(m,trace.stage,trace.controller,trace.lifetime)
	for unused: int in 2: await physics_frame
	var latch: ShotLatch=trace.shot_latch_encounter.for_module(module);var target: Vector2=latch.access_bodies[0].global_position
	var query:=PhysicsRayQueryParameters2D.create(trace.motor.position,target,1,[trace.motor.get_rid()])
	check(trace.motor.get_world_2d().direct_space_state.intersect_ray(query).is_empty(),"return-bell origin fixture has a genuine clear wall ray")
	check(trace.controller.shoot_ability.try_fire((target-trace.motor.position).normalized(),false),"left-side real projectile fires at visible return bell")
	for unused: int in 40: await physics_frame
	check(not latch.is_open and latch.open_count==0,"return bell rejects entry-side shot using stored fire origin")
	if not await load("res://tests/audio_teardown.gd").drain_world(trace.world):
		failures += 1;push_error("TEST AUDIO TEARDOWN: playback did not release within 1000ms");quit(1);return
	trace.world.free()
