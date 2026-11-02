extends SceneTree
# Explicit historical aperture/rune contract, replaced in formal R3 continuous fights.
var assertions:=0
var failures:=0
func _initialize()->void:run.call_deferred()
func check(ok:bool,message:String)->void:
	assertions+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func run()->void:
	for id:String in ["plains_thorn_cells","plains_thorn_wall","plains_remote_bell","plains_bell_ferry_control"]:
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
				trace.stage.add_child(module);trace.stage.modules.append(module)
				trace.motor=preload("res://game/player/player.tscn").instantiate();trace.motor.position=module.world_entry() if forward else module.world_exit();trace.world.add_child(trace.motor)
				trace.controller=trace.motor.get_node("Controller");trace.controller.enable_shot_energy();trace.controller.set_physics_process(false);trace.motor.get_node("KeyboardMouseAdapter").set_process_unhandled_input(false)
				trace.previous_body=Rect2(trace.motor.position-Vector2(12,18),Vector2(24,36))
				var manifest:Dictionary={"layout_id":"connected_region","nodes":[{"id":"probe","module_id":id,"offset":[0,0],"mirrored":false,"reverse_traversal":false}]};manifest.shot_latch_plan=PlainsShotLatchPlanner.recorded_plan(manifest)
				trace.shot_latch_encounter=GeneratedShotLatchEncounter.new();trace.world.add_child(trace.shot_latch_encounter)
				check(trace.shot_latch_encounter.setup(manifest,trace.stage,trace.controller,trace.lifetime),"actual planned mechanism consumer")
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
				if not await load("res://tests/audio_teardown.gd").drain_world(trace.world):
					failures += 1;push_error("TEST AUDIO TEARDOWN: playback did not release within 1000ms");quit(1);return
				trace.world.free()
	await remote_detour()
	await boss_rules()
	print("PLAINS INTERACTIVE PLATFORMS: %s assertions, %s failures"%[assertions,failures]);quit(1 if failures else 0)
func boss_rules()->void:
	var world:=Node2D.new();root.add_child(world)
	var player:=preload("res://game/player/player.tscn").instantiate();world.add_child(player)
	var boss:=preload("res://scenes/bosses/windkeeper.tscn").instantiate();var e:WindkeeperEncounter=boss.get_node("Encounter");e.definition=preload("res://resources/bosses/legacy/windkeeper_storm_window_v4.tres");world.add_child(boss);e.configure_arena(255,1000,player);e.set_physics_process(false);e.activate()
	e.stage_phase=1
	check(e.accepts_core_direction({"hit_direction":Vector2.UP,"fired_airborne":false}),"stage I permits ground-fired attack")
	e.stage_phase=2
	check(not e.accepts_core_direction({"hit_direction":Vector2.UP,"fired_airborne":false}) and e.accepts_core_direction({"hit_direction":Vector2.DOWN,"fired_airborne":false}),"stage II upward opening rejects ground-side incoming ray")
	e.health.apply_damage(ActorResourceRequest.new(&"phase_fixture",e.health.epoch,24,e.health.get_instance_id()))
	e.stage_phase=3
	e._enter(&"pier_open",12);e.rune_platform=0;e.register_rune_shot(1,42)
	check(not e.accepts_core_direction({"hit_direction":Vector2.DOWN,"fired_airborne":false}),"stage III actual airborne firing required")
	check(not e.accepts_core_direction({"hit_direction":Vector2(1,.3),"fired_airborne":true,"session_id":1,"shot_id":42}) and e.accepts_core_direction({"hit_direction":Vector2.DOWN,"fired_airborne":true,"session_id":1,"shot_id":42}),"stage III narrow downward cone")
	e._enter(&"observe",.1)
	var seen:Array=[]
	var reversed:=false
	for i:int in 2400:
		e.physics_tick(1.0/60)
		reversed=reversed or e._pier_direction<0
		if e.mode==&"pier_open" and not seen.has(e.chase_segment):seen.append(e.chase_segment)
		if e.mode==&"final_hold":check(false,"new profile never stalls at final pier");break
	check(seen.size()==3 and reversed,"stage III traverses three shelf centers then returns")
	var snap:Dictionary=e.combat_snapshot();e._pier_direction=1;e.restore_combat_state(snap)
	check(e._pier_direction==int(snap.pier_direction),"return direction survives snapshot")
	var settle_started := Time.get_ticks_msec()
	while not e._core.is_inside_tree() or not boss.get_children().any(func(child: Node) -> bool: return child is BossArrivalPresentation):
		if Time.get_ticks_msec()-settle_started >= 1000:
			failures += 1;push_error("TEST DEFERRED TEARDOWN: actual core/arrival did not enter tree");quit(1);return
		await process_frame
	print("TEST DEFERRED TEARDOWN: core/arrival entered tree in ",Time.get_ticks_msec()-settle_started,"ms")
	if not await load("res://tests/audio_teardown.gd").drain_world(world):
		failures += 1;push_error("TEST AUDIO TEARDOWN: playback did not release within 1000ms");quit(1);return
	world.free()

func remote_detour()->void:
	for forward:bool in [true,false]:
		var trace=load("res://tests/plains_region_trace.gd").new();trace.tree=self;trace.check=check
		trace.world=Node2D.new();root.add_child(trace.world);trace.stage=PlainsRegionAssembler.new();trace.world.add_child(trace.stage)
		var module:=PlatformingModule.new();module.definition=RandomStageGenerator.new().definition_for("plains_remote_bell");trace.stage.add_child(module);trace.stage.modules.append(module)
		trace.motor=preload("res://game/player/player.tscn").instantiate();trace.motor.position=module.world_entry() if forward else module.world_exit();trace.world.add_child(trace.motor);trace.controller=trace.motor.get_node("Controller");trace.controller.enable_shot_energy();trace.controller.set_physics_process(false);trace.motor.get_node("KeyboardMouseAdapter").set_process_unhandled_input(false);trace.previous_body=Rect2(trace.motor.position-Vector2(12,18),Vector2(24,36))
		var m:Dictionary={"layout_id":"connected_region","nodes":[{"id":"route_choice","module_id":"plains_remote_bell","offset":[0,0],"mirrored":false,"reverse_traversal":false}]};m.shot_latch_plan=PlainsShotLatchPlanner.recorded_plan(m)
		trace.shot_latch_encounter=GeneratedShotLatchEncounter.new();trace.world.add_child(trace.shot_latch_encounter);trace.shot_latch_encounter.setup(m,trace.stage,trace.controller,trace.lifetime);await trace.tick(3)
		var driver=load("res://tests/branch_module_driver.gd").new();driver.module=module;driver.motor=trace.motor;driver.controller=trace.controller;driver.tick_callback=trace.tick;driver.check=check
		var points:Array=[Vector2(500,192),Vector2(675,152),Vector2(850,192)] if forward else [Vector2(850,192),Vector2(675,152),Vector2(500,192),Vector2(400,282)]
		var safe:bool=await driver.move_to(400 if forward else 850)
		for point:Vector2 in points:safe=await driver.jump_to(point) and safe
		if forward:
			trace.controller.router.request_action(&"drop_through");await trace.tick()
			safe=await driver.land() and safe
			check(absf(trace.motor.position.y-282)<2,"upper detour uses real drop-through onto safe floor")
		safe=await driver.move_to((module.world_exit() if forward else module.world_entry()).x) and safe
		var latch:ShotLatch=trace.shot_latch_encounter.for_module(module)
		check(safe and trace.safe_trace and trace.continuous_trace,"closed door has real upper alternate route in both directions "+str(forward))
		check(latch.open_count==0 and not latch.is_open and trace.controller.shoot_ability._shot_serial==0,"upper detour spends no shots and never opens door")
		if not await load("res://tests/audio_teardown.gd").drain_world(trace.world):
			failures += 1;push_error("TEST AUDIO TEARDOWN: playback did not release within 1000ms");quit(1);return
		trace.world.free()
