extends SceneTree
var assertions:=0
var failures:=0
func _initialize()->void:run.call_deferred()
func check(ok:bool,message:String)->void:
	assertions+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func run()->void:
	for id:String in ["plains_thorn_slalom","plains_remote_sequence","plains_gear_brook"]:
		var d:=RandomStageGenerator.new().definition_for(id)
		check(d!=null and d.is_valid() and d.supports(PlayerTuning.load_default()),"authored actual solid and resource valid "+id)
		var metadata:=PlainsRegionGenerator.new()._connection_actions({"nodes":[{"module_id":id,"mirrored":false,"reverse_traversal":false,"initial_phases":[]}]},{"kind":"horizontal","modules":[0]})
		if id=="plains_bell_ferry_control":check(metadata.shoot_mechanism,"controlled ferry port declares required ground shot")
		if id=="plains_remote_bell":check(metadata.get("optional_remote_shot",false) and not metadata.shoot_mechanism,"remote port declares optional shot with actual no-shot detour")
		if not d.surface_thorns.is_empty():
			var t:PlatformThornDefinition=d.surface_thorns[0]
			check(d.static_dangers().has(t.danger(d.platforms)),"collision hazard derived from actual host")
			var reflected:=ModuleReflection.reflected_definition(d)
			check(reflected.is_valid() and reflected.static_dangers()[0]==ModuleReflection._rect(d.static_dangers()[0],d.world_bounds.end.x),"thorn face and range reflect with actual solid")
		for phase:float in [0.0,.25,.5,.75]:
			for forward:bool in [true,false]:
				var trace=load("res://tests/plains_region_trace.gd").new();trace.tree=self;trace.check=check
				trace.world=Node2D.new();root.add_child(trace.world);trace.stage=PlainsRegionAssembler.new();trace.world.add_child(trace.stage)
				var module:=PlatformingModule.new();module.definition=d.duplicate(true)
				for f:ModuleMovingPlatformDefinition in module.definition.ferries:f.initial_phase=phase
				for saw:ModuleSawDefinition in module.definition.saws:saw.initial_phase=phase
				trace.stage.add_child(module);trace.stage.modules.append(module)
				trace.motor=preload("res://scenes/player/player.tscn").instantiate();trace.motor.position=module.world_entry() if forward else module.world_exit();trace.world.add_child(trace.motor)
				trace.controller=trace.motor.get_node("Controller");trace.controller.enable_shot_energy();trace.controller.set_physics_process(false);trace.motor.get_node("KeyboardMouseAdapter").set_process_unhandled_input(false)
				trace.previous_body=Rect2(trace.motor.position-Vector2(12,18),Vector2(24,36))
				var manifest:Dictionary={"layout_id":"connected_region","nodes":[{"id":"probe","module_id":id,"offset":[0,0],"mirrored":false,"reverse_traversal":false}]};manifest.shot_latch_plan=PlainsShotLatchPlanner.recorded_plan(manifest)
				trace.shot_latch_encounter=GeneratedShotLatchEncounter.new();trace.world.add_child(trace.shot_latch_encounter)
				check(trace.shot_latch_encounter.setup(manifest,trace.stage,trace.controller,trace.lifetime),"actual planned mechanism consumer")
				for saw:ModuleSawHazard in module.hazards:trace.previous_hazards[saw.get_instance_id()]=saw.global_position
				await trace.tick(3)
				var passed:bool=await trace.forward_module(module) if forward else await trace.reverse_module(module)
				check(passed and trace.safe_trace and trace.continuous_trace,"actual bidirectional body sweep "+id+" phase="+str(phase)+" forward="+str(forward))
				if id=="plains_bell_ferry_control" and passed:
					var latch:ShotLatch=trace.shot_latch_encounter.for_module(module)
					var f:ModuleMovingPlatform=module.moving_platforms[0]
					var driver=load("res://tests/branch_module_driver.gd").new();driver.module=module;driver.motor=trace.motor;driver.controller=trace.controller;driver.tick_callback=trace.tick;driver.check=check
					var body:StaticBody2D=latch.access_bodies[0] if forward else latch.bell_body
					await driver.move_to(body.global_position.x)
					trace.controller.router.request_action(&"shoot_release",(body.global_position-trace.motor.position).normalized())
					await trace.tick(40);var held:float=f.motion_clock;var pos:Vector2=f.position
					await trace.tick(80)
					check(not f.motion_running and f.motion_clock==held and f.position==pos,"accepted bell shot parks independent carrier phase")
					trace.controller.router.request_action(&"shoot_release",(body.global_position-trace.motor.position).normalized())
					await trace.tick(40)
					check(f.motion_running and f.motion_clock>held,"another actual shot resumes without resetting phase")
					check(trace.safe_trace and trace.motor.is_on_floor(),"both actuator shots retain safe real bank support")
				if not await preload("res://tests/audio_teardown.gd").drain_world(trace.world):
					failures+=1;push_error("actual cohesion world audio failed to drain");quit(1);return
				trace.world.free()
	print("PLAINS COHESION: %s assertions, %s failures"%[assertions,failures]);quit(1 if failures else 0)
