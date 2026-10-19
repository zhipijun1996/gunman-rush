extends SceneTree
## Actual original projectile rejection/traversal tests plus Underworld consumers.
class UnderworldShotCases extends "res://tests/shot_latch_tests.gd":
	func create_fixture() -> void:
		await super.create_fixture()
		world.set_meta("underworld_formal_style",true)
		world.set_meta("pixel_formal_style",true)
		for latch: ShotLatch in latches:
			latch.formal_presentation=true
			latch.set_region_presentation(true)
			latch.refresh_pixel_presentation()

var assertions := 0
var failures := 0
var rows: Array[Dictionary] = []
var capture := "--capture" in OS.get_cmdline_user_args()
var feedback_only := "--feedback-only" in OS.get_cmdline_user_args()
var _capture_active := false
var _capture_frames: Array[Dictionary] = []
var _capture_ferry: ModuleMovingPlatform
var _capture_latch: ShotLatch
var _capture_motor: PlayerMotor

class MechanismCatalog extends Node2D:
	func _ready() -> void:
		texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_string(font,Vector2(70,65),"UNDERWORLD / CARRIERS AND SHOT BELLS",HORIZONTAL_ALIGNMENT_LEFT,-1,28,Color("dfd2a2"))
		draw_string(font,Vector2(70,105),"Image-derived material: independent length / thickness / matching primary and access bells",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("899b80"))
		var y:=170.0
		for size: Vector2 in [Vector2(32,12),Vector2(64,24),Vector2(120,24),Vector2(192,24),Vector2(120,48)]:
			UnderworldTerrain.draw_moving(self,Rect2(Vector2(100,y),size))
			draw_string(font,Vector2(330,y+18),"%d x %d" % [size.x,size.y],HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("b8a67b"))
			y+=75
		UnderworldTerrain.draw_mechanism_beam(self,Rect2(700,180,160,8))
		UnderworldTerrain.draw_mechanism_beam(self,Rect2(920,180,24,200))
		for index: int in 3:
			var point:=Vector2(715+index*64,245)
			UnderworldTerrain.draw_mechanism_bell(self,point,index>0)
			draw_string(font,point+Vector2(-20,48),["MAIN","SECOND","ACCESS"][index],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("b8a67b"))
		draw_string(font,Vector2(70,655),"Material catalog only. Actual accepted-shot footage and original rejection tests recorded separately.",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("899b80"))

func record_rendered_frame() -> void:
	if not _capture_active or not is_instance_valid(_capture_ferry): return
	var index:=_capture_frames.size()
	root.get_texture().get_image().save_png("res://build/underworld_plains/mechanisms/%s/%06d.png" % ["feedback_frames" if feedback_only else "frames",index])
	_capture_frames.append({"frame":index,"physics_tick":Engine.get_physics_frames(),"ferry_position":[_capture_ferry.position.x,_capture_ferry.position.y],"ferry_clock":_capture_ferry.motion_clock,"running":_capture_ferry.motion_running,"accepted_shots":_capture_latch.open_count,"shot_serial":_capture_latch.controller.shoot_ability._shot_serial,"bell_swing":_capture_latch._underworld_bell_swing(),"actor_position":[_capture_motor.position.x,_capture_motor.position.y],"platform_velocity":[_capture_motor.get_platform_velocity().x,_capture_motor.get_platform_velocity().y]})

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		printerr("FAIL: "+label)

func frames(count: int) -> void:
	for unused: int in count: await physics_frame

func patch_matrix() -> void:
	var texture := load(str(UnderworldTerrain.mechanism_specification().carrier.texture)) as Texture2D
	check(texture!=null,"actual generated carrier texture loads")
	for width: float in [1,8,16,31,32,120,192,320]:
		for height: float in [1,4,8,12,24,48]:
			var rect := Rect2(-width*.5,-height*.5,width,height)
			var plan := UnderworldTerrain.moving_patch_plan(rect)
			var area := 0.0
			for patch: Dictionary in plan:
				check(rect.encloses(patch.target),"material follows exact actual rectangle")
				check(Rect2(Vector2.ZERO,texture.get_size()).encloses(patch.source),"no source neighbor contamination")
				area += (patch.target as Rect2).get_area()
			check(is_equal_approx(area,rect.get_area()),"complete independent length/thickness coverage")
	var bell := UnderworldTerrain.mechanism_bell_size()
	check(bell.x<=28 and bell.y<=34,"bell source fits original receiver without widening hit target")
	check(is_equal_approx(bell.aspect(),UnderworldTerrain.mechanism_bell_texture().get_size().aspect()),"same bell aspect at primary/sequence/access")

func actual_ferry(phase: float, forward: bool) -> void:
	var trace = load("res://tests/plains_region_trace.gd").new()
	trace.tree=self
	trace.check=check
	trace.world=Node2D.new()
	trace.world.set_meta("underworld_formal_style",true)
	trace.world.set_meta("pixel_formal_style",true)
	trace.world.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(trace.world)
	trace.stage=PlainsRegionAssembler.new()
	trace.world.add_child(trace.stage)
	var module := PlatformingModule.new()
	module.authoring_debug=false
	module.terrain_candidate_preview=true
	module.definition=RandomStageGenerator.new().definition_for("plains_bell_ferry_control").duplicate(true)
	for definition: ModuleMovingPlatformDefinition in module.definition.ferries: definition.initial_phase=phase
	trace.stage.add_child(module)
	trace.stage.modules.append(module)
	var ferry: ModuleMovingPlatform=module.moving_platforms[0]
	ferry.set_painted_enabled(true)
	check(ferry.painted_art is ModuleMovingPlatform.UnderworldCarrierPaint,"real ferry selects current material renderer")
	var collider_before: Vector2=(ferry.get_child(0).shape as RectangleShape2D).size
	var old_paint:=Node2D.new()
	ferry.remove_child(ferry.painted_art)
	ferry.painted_art.free()
	ferry.painted_art=old_paint
	ferry.add_child(old_paint)
	ferry.set_painted_enabled(true)
	check(ferry.painted_art is ModuleMovingPlatform.UnderworldCarrierPaint and old_paint.get_parent()==null,"stale painted overlay replaced in current consumer")
	trace.motor=preload("res://scenes/player/player.tscn").instantiate()
	trace.motor.position=module.world_exit() if feedback_only else module.world_entry() if forward else module.world_exit()
	trace.world.add_child(trace.motor)
	trace.controller=trace.motor.get_node("Controller")
	if capture:
		trace.motor.get_node("CourierVisual").hide()
		trace.motor.get_node("PlayerVisualAdapter").process_mode=Node.PROCESS_MODE_DISABLED
		trace.motor.get_node("PlayerFeedback").hide()
		var art:=UnderworldPlayer.new()
		art.motor=trace.motor;art.controller=trace.controller
		trace.motor.add_child(art)
		var terrain:=UnderworldTerrain.build(module.definition.platforms)
		terrain.z_index=-1
		trace.world.add_child(terrain)
		var camera:=Camera2D.new()
		camera.position=Vector2(400,270);camera.zoom=Vector2.ONE*1.4
		trace.world.add_child(camera)
	trace.controller.enable_shot_energy()
	trace.controller.set_physics_process(false)
	trace.motor.get_node("KeyboardMouseAdapter").set_process_unhandled_input(false)
	trace.previous_body=Rect2(trace.motor.position-Vector2(12,18),Vector2(24,36))
	var manifest: Dictionary={"layout_id":"connected_region","nodes":[{"id":"probe","module_id":"plains_bell_ferry_control","offset":[0,0],"mirrored":false,"reverse_traversal":false}]}
	manifest.shot_latch_plan=PlainsShotLatchPlanner.recorded_plan(manifest)
	trace.shot_latch_encounter=GeneratedShotLatchEncounter.new()
	trace.world.add_child(trace.shot_latch_encounter)
	check(trace.shot_latch_encounter.setup(manifest,trace.stage,trace.controller,trace.lifetime),"actual planner creates real bell-controlled ferry")
	var latch: ShotLatch=trace.shot_latch_encounter.for_module(module)
	latch.set_region_presentation(true)
	latch.refresh_pixel_presentation()
	check(latch._underworld_feedback_origins().has(latch.access_positions[0]),"actual access receiver gets local accepted feedback origin")
	if capture:
		_capture_ferry=ferry;_capture_latch=latch;_capture_motor=trace.motor
		_capture_active=true
	await trace.tick(3)
	if feedback_only:
		var driver=load("res://tests/branch_module_driver.gd").new()
		driver.module=module;driver.motor=trace.motor;driver.controller=trace.controller;driver.tick_callback=trace.tick;driver.check=check
		var access: StaticBody2D=latch.access_bodies[0]
		check(await driver.move_to(access.global_position.x),"feedback fixture uses real return-bank walking")
		for pulse: int in 3:
			var before:=latch.open_count
			trace.controller.router.request_action(&"shoot_release",(access.global_position-trace.motor.position).normalized())
			await trace.tick(30)
			check(latch.open_count==before+1 and ferry.motion_running==(pulse%2==0),"actual access projectile produces expected start/park state")
		rows.append({"kind":"actual_return_bell_feedback_probe","accepted_count":latch.open_count,"receiver_origin":[latch.access_positions[0].x,latch.access_positions[0].y],"feedback_origins":str(latch._underworld_feedback_origins()),"scope":"Real return-bank input/projectile/Damageable accepted toggles; initial grounded fixture, not route traversal"})
		_capture_active=false
		if not await load("res://tests/audio_teardown.gd").drain_world(trace.world): check(false,"feedback audio teardown")
		trace.world.free()
		await process_frame
		return
	var passed: bool=await trace.forward_module(module) if forward else await trace.reverse_module(module)
	check(passed and trace.safe_trace and trace.continuous_trace,"real input-only ferry traversal phase=%s forward=%s" % [phase,forward])
	if passed:
		var driver=load("res://tests/branch_module_driver.gd").new()
		driver.module=module;driver.motor=trace.motor;driver.controller=trace.controller;driver.tick_callback=trace.tick;driver.check=check
		var bell: StaticBody2D=latch.access_bodies[0] if forward else latch.bell_body
		await driver.move_to(bell.global_position.x)
		var accepted_before:=latch.open_count
		trace.controller.router.request_action(&"shoot_release",(bell.global_position-trace.motor.position).normalized())
		await trace.tick(40)
		check(latch.open_count==accepted_before+1 and not ferry.motion_running,"actual projectile/Damageable/commit parks ferry")
		var held:=ferry.motion_clock
		var position_before:=ferry.position
		await trace.tick(60)
		check(ferry.motion_clock==held and ferry.position==position_before,"parked source art and phase stay on physical body")
		trace.controller.router.request_action(&"shoot_release",(bell.global_position-trace.motor.position).normalized())
		await trace.tick(40)
		check(latch.open_count==accepted_before+2 and ferry.motion_running and ferry.motion_clock>held,"actual second shot resumes original phase")
		var clock_before:=ferry.motion_clock
		var bell_clock:=latch._clock
		paused=true
		await process_frame
		await process_frame
		check(ferry.motion_clock==clock_before and latch._clock==bell_clock,"pause freezes moving and accepted-feedback clocks")
		paused=false
		ferry.restore_motion(held,false)
		check(ferry.position==ferry.definition.at_time(held) and not ferry.motion_running,"real saved phase restore synchronizes collision and art")
		check((ferry.get_child(0).shape as RectangleShape2D).size==collider_before,"style replacement never mutates collision shape")
		check(ferry.painted_art.position==Vector2.ZERO,"body owns all material movement without offset drift")
	rows.append({"kind":"real_authored_ferry_route","phase":phase,"forward":forward,"passed":passed,"safe_trace":trace.safe_trace,"continuous":trace.continuous_trace,"accepted_count":latch.open_count,"source":ferry.painted_art.get_meta("material_source"),"scope":"Unmodified route driver and actual Router/projectile/Damageable accepted toggles; not formal whole-map completion"})
	_capture_active=false
	if not await load("res://tests/audio_teardown.gd").drain_world(trace.world): check(false,"ferry audio teardown")
	trace.world.free()
	await process_frame

func formal_inventory() -> void:
	var app:=DemoApp.new()
	app.meta_persistence_enabled=false
	root.add_child(app)
	check(app.start_plains("underworld-mechanism-unification"),"actual normal DemoApp starts")
	await frames(10)
	check(app.stage is PlainsRegionStage and app.stage.assembly_ok,"formal map assembles")
	var stage:=app.stage as PlainsRegionStage
	var ferries:=0
	for module: PlatformingModule in stage.assembler.modules:
		for ferry: ModuleMovingPlatform in module.moving_platforms:
			ferries+=1
			check(ferry.painted_art is ModuleMovingPlatform.UnderworldCarrierPaint,"formal actual ferry uses same material")
	var manifest_hash: String=stage.generated.manifest.manifest_hash
	check(ferries>0,"formal map contains actual moving consumers")
	app.stage.capture_state()
	app._load_stage()
	await frames(10)
	check(app.stage.generated.manifest.manifest_hash==manifest_hash,"real unload/reload preserves Manifest")
	for module: PlatformingModule in app.stage.assembler.modules:
		for ferry: ModuleMovingPlatform in module.moving_platforms: check(ferry.painted_art is ModuleMovingPlatform.UnderworldCarrierPaint,"reloaded actual ferry retains current material")
	rows.append({"kind":"actual_DemoApp_reload","seed":"underworld-mechanism-unification","manifest_hash":manifest_hash,"ferries":ferries,"scope":"Actual normal-entry consumer material inventory and reload, not traversal"})
	if not await load("res://tests/audio_teardown.gd").drain_world(app): check(false,"formal audio teardown")
	app.free()
	await process_frame

func actual_sequence(id: String) -> void:
	var trace=load("res://tests/plains_region_trace.gd").new()
	trace.tree=self;trace.check=check
	trace.world=Node2D.new()
	trace.world.set_meta("underworld_formal_style",true)
	trace.world.set_meta("pixel_formal_style",true)
	root.add_child(trace.world)
	trace.stage=PlainsRegionAssembler.new()
	trace.world.add_child(trace.stage)
	var module:=PlatformingModule.new()
	module.definition=RandomStageGenerator.new().definition_for(id).duplicate(true)
	module.authoring_debug=false
	trace.stage.add_child(module);trace.stage.modules.append(module)
	trace.motor=preload("res://scenes/player/player.tscn").instantiate()
	trace.motor.position=module.world_entry()
	trace.world.add_child(trace.motor)
	trace.controller=trace.motor.get_node("Controller")
	trace.controller.enable_shot_energy();trace.controller.set_physics_process(false)
	trace.motor.get_node("KeyboardMouseAdapter").set_process_unhandled_input(false)
	trace.previous_body=Rect2(trace.motor.position-Vector2(12,18),Vector2(24,36))
	var manifest: Dictionary={"layout_id":"connected_region","nodes":[{"id":"sequence_probe","module_id":id,"offset":[0,0],"mirrored":false,"reverse_traversal":false}]}
	manifest.shot_latch_plan=PlainsShotLatchPlanner.recorded_plan(manifest)
	trace.shot_latch_encounter=GeneratedShotLatchEncounter.new();trace.world.add_child(trace.shot_latch_encounter)
	check(trace.shot_latch_encounter.setup(manifest,trace.stage,trace.controller,trace.lifetime),"actual sequence/timed planner builds same bell family")
	var latch: ShotLatch=trace.shot_latch_encounter.for_module(module)
	latch.set_region_presentation(true);latch.refresh_pixel_presentation()
	await trace.tick(3)
	var passed: bool=await trace.forward_module(module)
	check(passed and trace.safe_trace and trace.continuous_trace,"actual accepted ordered/timed bell route "+id)
	if id=="plains_windchime_sequence":
		check(latch.sequence_step==1 and latch.is_open and latch.open_count==1,"second real receiver completes sequence once")
		check(latch._underworld_feedback_origins().has(latch._second_body.position),"actual second receiver gets same local accepted feedback")
	if id=="plains_windchime_timed":
		await trace.tick(ceili(latch.open_seconds*60)+10)
		check(not latch.is_open and not latch.gate_shape.disabled and latch.gate_body.collision_layer==1,"same styled timed gate actually closes after actor clears")
	for child: Node in latch.get_children():
		if child is Sprite2D:
			check(child.texture==UnderworldTerrain.mechanism_bell_texture(),"actual sequence/access receiver has matching original image")
	rows.append({"kind":"actual_sequence_or_timed_route","module":id,"passed":passed,"sequence_step":latch.sequence_step,"accepted_open_count":latch.open_count,"shots":trace.controller.shoot_ability._shot_serial,"scope":"Actual Router projectile Damageable ordered receivers/timed reclose; controlled authored module, not full map"})
	if not await load("res://tests/audio_teardown.gd").drain_world(trace.world): check(false,"ordered bell audio teardown")
	trace.world.free()
	await process_frame

func run() -> void:
	patch_matrix()
	# Original tests retain wrong epoch, duplicate, missed and stale-shot rejection.
	if capture:
		root.size=Vector2i(1280,720)
		DirAccess.make_dir_recursive_absolute("res://build/underworld_plains/mechanisms/"+("feedback_frames" if feedback_only else "frames"))
		RenderingServer.frame_post_draw.connect(record_rendered_frame)
		await actual_ferry(0,true)
		FileAccess.open("res://build/underworld_plains/mechanisms/"+("feedback_frames.json" if feedback_only else "capture_frames.json"),FileAccess.WRITE).store_string(JSON.stringify({"fps":60,"audio":"Dummy; no listening claim","frames":_capture_frames},"\t")+"\n")
		var catalog:=MechanismCatalog.new()
		root.add_child(catalog)
		await process_frame
		await RenderingServer.frame_post_draw
		var image:=root.get_texture().get_image()
		image.save_png("res://build/underworld_plains/mechanisms/material_catalog.png")
		for sample: Rect2i in [Rect2i(100,170,32,12),Rect2i(100,245,64,24),Rect2i(100,320,120,24),Rect2i(100,395,192,24),Rect2i(100,470,120,48),Rect2i(700,180,160,8),Rect2i(920,180,24,200)]:
			var colors: Dictionary={}
			var white:=0
			for y: int in range(sample.position.y,sample.end.y):
				for x: int in range(sample.position.x,sample.end.x):
					var color:=image.get_pixel(x,y)
					colors[color.to_rgba32()]=true
					if color.r>.95 and color.g>.95 and color.b>.95: white+=1
			check(white==0 and colors.size()>8,"GPU source material visible, no temporary-RID white rectangle")
			rows.append({"kind":"actual_GPU_material_sample","bounds":[sample.position.x,sample.position.y,sample.size.x,sample.size.y],"white_pixels":white,"distinct_colors":colors.size()})
		catalog.free()
	else:
		await load("res://tests/shot_latch_tests.gd").new().run(self,check)
		await UnderworldShotCases.new().run(self,check)
		for phase: float in [0,.25,.5,.75]:
			for forward: bool in [true,false]: await actual_ferry(phase,forward)
		for id: String in ["plains_windchime_sequence","plains_windchime_timed"]: await actual_sequence(id)
		await formal_inventory()
	var report: Dictionary={"task_id":"UNDERWORLD-PLAINS-01-USER-REWORK","assertions":assertions,"failures":failures,"observations":rows,"scope":"Source-derived length/thickness patches, original accepted/rejected projectile contracts, authored module routes and actual formal reload; GPU and user judgment separate"}
	DirAccess.make_dir_recursive_absolute("res://build/underworld_plains/mechanisms")
	FileAccess.open("res://build/underworld_plains/mechanisms/"+("feedback_gpu_runtime.json" if feedback_only else "gpu_runtime.json" if capture else "runtime.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("UNDERWORLD MECHANISMS: %d assertions, %d failures" % [assertions,failures])
	quit(1 if failures else 0)
