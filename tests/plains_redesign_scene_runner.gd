extends SceneTree
## Normal formal actors, Motor and frozen policy. This adds observation only.
var assertions := 0
var failures := 0
var output := ""
var mutation := ""
var frame_dir := ""
var capture_pending := false
var screenshots: Array = []
var cases: Array = []
var app: DemoApp
var active_trace
var mutation_applied := false
var mutation_receipt: Dictionary = {}
var required_override: Array[Dictionary] = []
var current_issues: Array[String] = []
var elective_ascent := false
var elective_receipts: Array = []
var legacy_ui: Dictionary = {}
var route_comparison: Dictionary = {}
var cleanup_receipts: Array = []
const AUDIO_TEARDOWN = preload("res://tests/audio_teardown.gd")
class SceneTrace extends "res://tests/level_formal_trace.gd":
	signal presentation_sampled
	var observer: Callable
	var visual_frames: Array = []
	var observe_every_tick := false
	func tick(count: int = 1) -> void:
		for unused: int in count:
			await super.tick()
			if is_trace_cancelled(): return
			if observer.is_valid() and (observe_every_tick or trace_ticks % 6 == 0 or not observed_frames[-1].accepted_events.is_empty()):
				_sample_after_process.call_deferred()
				await presentation_sampled
				if is_trace_cancelled(): return
	func _sample_after_process() -> void:
		if is_trace_cancelled():
			presentation_sampled.emit()
			return
		visual_frames.append(observer.call(self))
		presentation_sampled.emit()
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg.begins_with("--mutation="): mutation=arg.trim_prefix("--mutation=")
		if arg.begins_with("--screens-dir="): frame_dir=arg.trim_prefix("--screens-dir=")
	root.size=Vector2i(1280,720)
	run.call_deferred()
func check(ok: bool, label: String) -> void:
	assertions+=1
	if not ok: failures+=1;printerr("SCENE FAIL: "+label)
func pair(v: Vector2) -> Array: return [v.x,v.y]
func rect_values(r: Rect2) -> Array: return [r.position.x,r.position.y,r.size.x,r.size.y]
func project_rect(r: Rect2) -> Rect2:
	var transform := app.player.get_canvas_transform()
	var a := transform*r.position
	var b := transform*r.end
	return Rect2(a.min(b),(b-a).abs())
func display_regions() -> Array[Dictionary]:
	var rows: Array[Dictionary]=[]
	for control: Control in [app._hud_frame,app._debug_button,app._pause_button,(app.stage as PlainsRegionStage).map_view]:
		if control.is_visible_in_tree(): rows.append({"path":str(control.get_path()),"kind":"info" if control==app._debug_button else "control","bounds":rect_values(control.get_global_rect())})
	if is_instance_valid(app.item_toast._root) and app.item_toast._root.is_visible_in_tree(): rows.append({"path":str(app.item_toast._root.get_path()),"bounds":rect_values(app.item_toast._root.get_global_rect())})
	return rows
func touch_conflicts(regions: Array[Dictionary]) -> Array[String]:
	var issues: Array[String]=[]
	for reserved: Rect2 in app._region_touch_regions():
		for ui: Dictionary in regions:
			var values: Array=ui.bounds
			if reserved.intersects(Rect2(values[0],values[1],values[2],values[3])):issues.append("actual touch control occluded by "+str(ui.path))
	return issues
func foreground(node: Node, rows: Array[Dictionary]) -> void:
	for child: Node in node.get_children():
		if child is Sprite2D and child.visible and child.z_index>=30 and child.modulate.a>.3 and child.texture!=null:
			var local_rect: Rect2=child.get_rect()
			var world_rect: Rect2=child.global_transform*local_rect
			rows.append({"path":str(child.get_path()),"bounds":rect_values(project_rect(world_rect))})
		foreground(child,rows)
func targets(trace) -> Array[Dictionary]:
	var rows: Array[Dictionary]=[]
	rows.append({"id":"actor","world":Rect2(app.player.global_position-Vector2(13,20),Vector2(26,40)),"mandatory":true})
	var viewport := Rect2(0,0,1280,720)
	for index: int in app.stage.enemies.size():
		var enemy: EnemyMotor=app.stage.enemies[index]
		var actor := enemy.get_node("Actor") as EnemyActor
		if actor.health.terminal or enemy.global_position.distance_to(app.player.global_position)>450: continue
		var world_rect := Rect2(enemy.global_position-actor.definition.collision_size*.5,actor.definition.collision_size)
		if viewport.intersects(project_rect(world_rect)):
			rows.append({"id":"enemy/"+str(index),"world":world_rect,"mandatory":false})
		var attack := actor.attack_behavior
		if attack!=null and attack.state in [&"telegraph",&"attack"]:
			var origin := Rect2(attack.attack_origin-Vector2(13,13),Vector2(26,26))
			if viewport.intersects(project_rect(origin)): rows.append({"id":"telegraph/"+str(index),"world":origin,"mandatory":false})
			for projectile: EnemyAttackProjectile in attack._projectiles:
				if is_instance_valid(projectile) and not projectile.spent:
					var body := Rect2(projectile.global_position-Vector2.ONE*projectile.radius,Vector2.ONE*projectile.radius*2)
					if viewport.intersects(project_rect(body)): rows.append({"id":"enemy_projectile/"+str(projectile.event_id),"world":body,"mandatory":false})
	# Before committing the real well jump, the far landing and actual target
	# must be in the view. Mandatory rows never disappear by frustum filtering.
	for module: PlatformingModule in app.stage.assembler.modules:
		if module.definition.module_id!=&"plains_windchime_well":continue
		var local: Vector2=app.player.global_position-module.global_position
		if elective_ascent:
			rows.append({"id":"elective_distant_receiver","world":Rect2(module.global_position+Vector2(385,264),Vector2(100,36)),"mandatory":false})
		if local.x>=160 and local.x<=640 and local.y>=-100 and local.y<=305:
			rows.append({"id":"well_receiver","world":Rect2(module.global_position+Vector2(385,264),Vector2(100,36)),"mandatory":true})
			var latch: ShotLatch = trace.shot_latch_encounter.for_module(module)
			if latch!=null and not latch.is_open: rows.append({"id":"well_bell","world":Rect2(module.global_position+Vector2(316,324),Vector2(28,50)),"mandatory":true})
	# The island is a real candidate landing from the dock; far from the dock
	# the entrance hint does not pretend to show a 700-world-unit-away cache.
	var discovery: Dictionary=app.stage.generated.manifest.get("creek_discovery",{})
	if not discovery.is_empty():
		for index: int in app.stage.generated.manifest.nodes.size():
			if app.stage.generated.manifest.nodes[index].id != str(discovery.get("bank","")):continue
			var module: PlatformingModule=app.stage.assembler.modules[index]
			var slab: Rect2=module.definition.platforms[0]
			var bank:=Rect2(module.global_position+slab.position,slab.size)
			if app.player.global_position.distance_to(bank.get_center())<300:
				rows.append({"id":"island_receiver","world":bank.grow(8),"mandatory":true})
	rows.append_array(required_override)
	return rows
func issues_for(rows: Array[Dictionary], regions: Array[Dictionary]) -> Array[String]:
	var issues: Array[String]=[]
	var screen := Rect2(6,6,1268,708)
	for row: Dictionary in rows:
		var projected:=project_rect(row.world)
		if row.mandatory and not screen.encloses(projected): issues.append(str(row.id)+": required target outside viewport")
		for region: Dictionary in regions:
			if row.id=="elective_distant_receiver":continue # Recorded remote bank, explicitly not an all-ascent visibility claim.
			var b: Array=region.bounds
			if projected.intersects(Rect2(b[0],b[1],b[2],b[3])): issues.append(str(row.id)+": occluded by "+str(region.path))
	return issues
func landmark_issues() -> Array[String]:
	var result: Array[String]=[]
	for child: Node in app.stage.get_children():
		if not (child is PlainsRegionScenery or child is PixelRegionScenery):continue
		for sprite: Node in child.get_children():
			if not sprite is Sprite2D or not sprite.has_meta("landmark"):continue
			var item: Dictionary=sprite.get_meta("landmark")
			var bounds:=Rect2(sprite.global_position,sprite.texture.get_size()*sprite.global_scale)
			var declared:=Rect2(item.display_bounds[0],item.display_bounds[1],item.display_bounds[2],item.display_bounds[3])
			if not bounds.is_equal_approx(declared):result.append("landmark actual sprite differs from plan")
			var foot:=Vector2(bounds.get_center().x,bounds.end.y)
			var hit:=app.player.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(foot-Vector2(0,1),foot+Vector2(0,3),1))
			if hit.is_empty() or not hit.collider is StaticBody2D:result.append("landmark has no real solid immediately under foot")
	return result
func add_blocker(world_rect: Rect2) -> Sprite2D:
	var sprite:=Sprite2D.new();sprite.name="DeliberateForegroundBlocker"
	var texture:=GradientTexture2D.new();texture.width=64;texture.height=64
	sprite.texture=texture;sprite.position=world_rect.get_center();sprite.scale=world_rect.size/Vector2(64,64);sprite.z_index=100
	app.stage.add_child(sprite)
	return sprite
func apply_mutation(trace) -> void:
	if mutation_applied or mutation.is_empty():return
	var chosen: Dictionary={}
	var rows:=targets(trace)
	if mutation=="touch_controls_overlap":
		app.overlay.set_enabled(true);app.overlay.update_layout()
		app._hud_frame.position=Vector2(12,590)
		(app.stage as PlainsRegionStage).map_view.position=Vector2(1098,674)
		app.item_toast.show_item(DemoApp.SHOT_ITEM);app.item_toast._root.position=Vector2(300,615)
		mutation_receipt={"overlay_enabled":app.overlay.enabled,"actual_touch_regions":app._region_touch_regions().map(func(r:Rect2):return rect_values(r)),"actual_ui":display_regions(),"scope":"real legacy candidate rectangles overlap real enabled overlay; no touch input claim"};mutation_applied=true;return
	if mutation in ["hud_actor","foreground_actor","heading_actor","required_outside","info_actor"]:chosen=rows[0]
	elif mutation=="foreground_landing":
		for row:Dictionary in rows:
			if row.id=="well_receiver":chosen=row;break
	elif mutation=="foreground_bell":
		for latch:ShotLatch in app.stage.shot_latches:
			var bounds:=Rect2(latch.global_position+latch.bell_position-Vector2(14,26),Vector2(28,50))
			if Rect2(30,130,1100,540).encloses(project_rect(bounds)) and bounds.get_center().distance_to(app.player.global_position)<270:
				chosen={"id":"required_bell","world":bounds,"mandatory":true};required_override=[chosen];break
	elif mutation=="foreground_ferry":
		for module:PlatformingModule in app.stage.assembler.modules:
			for ferry:ModuleMovingPlatform in module.moving_platforms:
				var bounds:=Rect2(ferry.global_position-ferry.definition.size*.5,ferry.definition.size)
				if Rect2(30,130,1100,540).encloses(project_rect(bounds)) and bounds.get_center().distance_to(app.player.global_position)<300:
					chosen={"id":"required_ferry","world":bounds,"mandatory":true};required_override=[chosen];break
	elif mutation=="floating_landmark":
		for child:Node in app.stage.get_children():
			if child is PlainsRegionScenery or child is PixelRegionScenery:
				for sprite:Node in child.get_children():
					if sprite is Sprite2D and sprite.has_meta("landmark"):
						sprite.position.y-=20;mutation_receipt={"path":str(sprite.get_path()),"actual_offset_y":-20};mutation_applied=true;return
	if chosen.is_empty():return
	if mutation=="info_actor":
		app._debug_button.global_position=project_rect(chosen.world).position
		mutation_receipt={"path":str(app._debug_button.get_path()),"actual_global_bounds":rect_values(app._debug_button.get_global_rect()),"actual_parent":str(app._debug_button.get_parent().get_path())}
	elif mutation=="hud_actor":
		app._hud_frame.position=project_rect(chosen.world).position
		mutation_receipt={"path":str(app._hud_frame.get_path()),"actual_bounds":rect_values(app._hud_frame.get_global_rect())}
	elif mutation=="heading_actor":
		var label:=Label.new();label.text="DELIBERATE ROUTE PARAGRAPH";label.position=chosen.world.position;app.stage.add_child(label)
		mutation_receipt={"path":str(label.get_path()),"actual_bounds":rect_values(project_rect(Rect2(label.global_position,label.get_combined_minimum_size())))}
		required_override=[chosen]
	elif mutation=="required_outside":
		required_override=[{"id":"required_receiver","world":Rect2(chosen.world.position+Vector2(2000,0),Vector2(100,40)),"mandatory":true}]
		mutation_receipt={"required_receiver":rect_values(required_override[0].world),"reason":"deliberately inaccessible observation window must not be filtered"}
	else:
		var blocker:=add_blocker(chosen.world)
		mutation_receipt={"path":str(blocker.get_path()),"actual_world_bounds":rect_values(chosen.world),"target":chosen.id,"z_index":blocker.z_index}
	mutation_applied=true
func observe(trace) -> Dictionary:
	apply_mutation(trace)
	var regions:=display_regions();foreground(app.stage,regions)
	if mutation=="heading_actor" and mutation_applied:regions.append({"path":mutation_receipt.path,"bounds":mutation_receipt.actual_bounds})
	var rows:=targets(trace)
	var issues:=issues_for(rows,regions)
	issues.append_array(landmark_issues())
	issues.append_array(touch_conflicts(display_regions()))
	if not issues.is_empty():current_issues.append_array(issues)
	if not frame_dir.is_empty() and trace.trace_ticks in [600,720,840,960,1440,1920,2400,3000] and not capture_pending: capture_screen.call_deferred(trace.trace_ticks)
	return {"tick":trace.trace_ticks,"edge":trace.current_edge,"position":pair(app.player.global_position),"grounded":app.player.is_on_floor(),"camera_center":pair(app._run_camera.get_screen_center_position()),"zoom":pair(app._run_camera.zoom),"touch_regions":app._region_touch_regions().map(func(r:Rect2):return rect_values(r)),"ui":regions,"targets":rows.map(func(row:Dictionary):return {"id":row.id,"world":rect_values(row.world),"screen":rect_values(project_rect(row.world)),"mandatory":row.mandatory}),"issues":issues}
func capture_screen(request_tick: int) -> void:
	capture_pending=true
	await RenderingServer.frame_post_draw
	if not is_instance_valid(app) or not is_instance_valid(app.player):capture_pending=false;return
	DirAccess.make_dir_recursive_absolute(frame_dir)
	var file := frame_dir+"/case_%02d_requested_%06d.png" % [cases.size(),request_tick]
	var image := root.get_texture().get_image()
	var error := image.save_png(file)
	screenshots.append({"path":file,"request_tick":request_tick,"actual_controller_tick":app.controller._tick,"actual_position":pair(app.player.global_position),"sha256":FileAccess.get_sha256(file),"width":image.get_width(),"height":image.get_height(),"error":error,"scope":"actual rendered viewport; deferred frame-post-draw may follow request tick, not falsely same-tick physics"})
	capture_pending=false

func run_case(map_index: int, strategy: String, custom: String="", seed_value: String="level-design-v2-baseline") -> void:
	app=DemoApp.new();app.meta_persistence_enabled=false;root.add_child(app)
	check(app.start_plains(seed_value),"formal start accepted")
	for unused:int in 120:
		await physics_frame;await process_frame
		if not app._stage_pending and app.stage is PlainsRegionStage:break
	if map_index==2:
		app.lifetime.stage_epoch+=1
		app.lifetime.actor_epoch+=1
		_sync_fixture_map_index(app, 2)
		app.director._enter_stage(2,&"boss")
		app._stage_entered(DemoRunResult.new())
		for unused:int in 120:
			await physics_frame;await process_frame
			if not app._stage_pending and app.stage is PlainsRegionStage and app.stage.map_index==2:break
	check(app.stage is PlainsRegionStage and app.stage.assembly_ok,"actual formal region ready")
	check(_fixture_identity_matches(app, map_index, seed_value), "actual stage/map/manifest seed+difficulty matches requested fixture")
	var trace:=SceneTrace.new();active_trace=trace
	check(trace.attach(app,strategy,0,"kill_from_bank_v1"),"unchanged real policy attaches")
	trace.frame_budget=15000;trace.observer=observe
	if custom=="touch_geometry":
		trace.observe_every_tick=true
		app.overlay.set_enabled(true);app.overlay.update_layout()
		# Presentation-only toast fixture. No item is granted or build changed.
		app.item_toast.show_item(DemoApp.SHOT_ITEM);app._layout_region_hud()
	var manifest_before:=JSON.stringify(app.stage.generated.manifest)
	var execution: Dictionary = {"execution_done":false}
	drive_scene_execution.call_deferred(trace,custom,execution)
	while not trace.finished and not trace.terminated:
		await process_frame
		if mutation_applied:break
	if mutation.is_empty():
		check(trace.finished and trace.outcome=="route_target_reached","formal "+str(map_index)+"/"+strategy+"/"+custom+" route target: "+trace.outcome)
		check(current_issues.is_empty(),"actual camera/UI/foreground/landmark no observed violations: "+str(current_issues.slice(0,3)))
	else:
		check(mutation_applied,"real requested mutation reached")
		observe(trace)
		check(current_issues.is_empty(),"deliberate real scene mutation rejected: "+mutation)
	check(JSON.stringify(app.stage.generated.manifest)==manifest_before,"presentation observation does not mutate actual manifest")
	var frozen_case: Dictionary = ({"map":map_index,"actual_map_index":app.stage.map_index,"actual_manifest_seed":app.stage.generated.manifest.seed,"actual_manifest_difficulty":app.stage.generated.manifest.difficulty,"strategy":strategy,"custom":custom,"outcome":trace.outcome,"finished":trace.finished,"ticks":trace.trace_ticks,"manifest":app.stage.generated.manifest.duplicate(true),"visual_frames":trace.visual_frames,"frames":trace.observed_frames,"events":trace.events,"runtime":trace.runtime_snapshot(true),"mutation":mutation_receipt,"seed":seed_value,"issues":current_issues.duplicate(),"scenery":scene_inventory(app.stage),"elective_receipts":elective_receipts.duplicate(true),"route_comparison":route_comparison.duplicate(true)}).duplicate(true)
	cases.append(frozen_case)
	var sealed_hash := JSON.stringify(frozen_case).sha256_text()
	var cleanup: Dictionary = await unwind_scene_execution(trace,execution)
	cleanup["sealed_case_sha256"] = sealed_hash
	cleanup["case_sha256_after_unwind"] = JSON.stringify(frozen_case).sha256_text()
	check(cleanup.ok and cleanup.sealed_case_sha256==cleanup.case_sha256_after_unwind,"sealed scene payload preserved and actual route execution ended without post-terminal effects")
	cleanup_receipts.append(cleanup)
	if not cleanup.ok: return
	cleanup["observers_disconnected"] = trace.disconnect_test_observers()
	trace.observer=Callable()
	while capture_pending:await process_frame
	cleanup["audio_released"] = await AUDIO_TEARDOWN.drain_world(app)
	check(cleanup.audio_released,"owned scene audio backend released")
	var reference: WeakRef = weakref(trace)
	active_trace=null
	app.free();await process_frame
	trace=null
	await process_frame
	cleanup["driver_released"] = reference.get_ref()==null
	check(cleanup.driver_released,"scene execution stack and trace actually released")
	current_issues=[]
	elective_ascent=false
	elective_receipts=[]
	route_comparison={}

func drive_scene_execution(trace: SceneTrace, custom: String, state: Dictionary) -> void:
	if custom.is_empty(): await trace.run_route()
	else: await custom_route(trace,custom)
	state.execution_done=true

func unwind_scene_execution(trace: SceneTrace, state: Dictionary) -> Dictionary:
	trace.seal_test_observation()
	var epoch_before: int = trace.controller.router.epoch if is_instance_valid(trace.controller) else -1
	app.process_mode=Node.PROCESS_MODE_DISABLED
	for descendant: Node in app.find_children("*","",true,false): descendant.process_mode=Node.PROCESS_MODE_DISABLED
	if is_instance_valid(trace.controller): trace.controller.router.clear("test_capture_sealed_unwind")
	var before := trace.cancellation_facts().duplicate(true)
	var requested := trace.request_test_unwind()
	var started := Time.get_ticks_msec()
	while not state.get("execution_done",false) and Time.get_ticks_msec()-started<1000:
		await process_frame
	var after := trace.cancellation_facts().duplicate(true)
	var completed: bool = state.get("execution_done",false)
	return {"scope":"post-capture lifecycle only; original gameplay observations already frozen","execution_done":completed,"requested":requested,"deadline_msec":1000,"elapsed_msec":Time.get_ticks_msec()-started,"router_epoch_before_clear":epoch_before,"before":before,"after":after,"ok":requested and completed and before==after}

func scene_inventory(stage: Node) -> Array:
	var rows:Array=[]
	for child:Node in stage.get_children():
		if child is PlainsRegionScenery: rows.append({"plan":child.presentation_manifest,"children":child.get_child_count(),"composition":child.get_node("PlainsRegionComposition").compositions if child.has_node("PlainsRegionComposition") else []})
		elif child is PixelRegionScenery:
			var actual_items: Array[Dictionary] = []
			var actual_compositions: Array[Dictionary] = []
			for sprite: Node in child.get_children():
				if not sprite is Sprite2D or not sprite.has_meta("landmark"):continue
				var item: Dictionary = sprite.get_meta("landmark").duplicate(true)
				item["actual_node"] = str(sprite.get_path())
				item["actual_bounds"] = rect_values(Rect2(sprite.global_position,sprite.texture.get_size()*sprite.global_scale))
				actual_items.append(item)
				if sprite.has_meta("composition"):actual_compositions.append(sprite.get_meta("composition").duplicate(true))
			# Four-role coverage comes only from instantiated sprites, never from
			# generation declarations for landmarks that might not actually exist.
			rows.append({"plan":{"items":actual_items},"declared_plan":child.presentation_manifest.duplicate(true),"children":child.get_child_count(),"composition":actual_compositions})
	return rows
func custom_route(trace, mode: String) -> void:
	var ok:bool=await trace.tutorial()
	if trace.is_trace_cancelled(): return
	if ok and mode=="extra_upward_recoil":
		ok=await extra_upward_recoil(trace)
		if trace.is_trace_cancelled(): return
	elif ok and mode=="touch_geometry":
		ok=await trace.follow_to("area_2_1")
		if trace.is_trace_cancelled(): return
	elif ok and mode=="main_then_high":
		ok=await trace.follow_to("area_2_1")
		if trace.is_trace_cancelled(): return
		if ok:
			ok=await trace.follow_to("area_0_0")
			if trace.is_trace_cancelled(): return
		if ok:
			ok=await trace.deep_trial("deep_high")
			if trace.is_trace_cancelled(): return
		if ok:
			for edge:Dictionary in trace.stage.manifest.connections:
				if edge.a=="deep_high" and edge.kind=="drop":trace.current_area=str(edge.b)
			ok=await trace.follow_to("area_2_1")
			if trace.is_trace_cancelled(): return
	elif ok and mode in ["outer_return","outer_upper_alternative"]:
		ok=await trace.follow_to("area_3_3")
		if trace.is_trace_cancelled(): return
		if ok:
			var start_tick: int=trace.trace_ticks
			var before: Dictionary=trace.runtime_snapshot(true)
			var start_position:=pair(trace.motor.global_position)
			var path: Array=["area_3_3","area_4_3","area_4_2"] if mode=="outer_return" else ["area_3_3","area_3_2","area_4_2"]
			ok=await trace.follow_to(path[1])
			if trace.is_trace_cancelled(): return
			if ok:
				ok=await trace.follow_to(path[2])
				if trace.is_trace_cancelled(): return
			var ferry_paths: Array=[]
			var outer_connection: Dictionary=trace.stage.manifest.connections.filter(func(e:Dictionary):return e.get("outer_return",false))[0]
			var carrier_modules: Array=[]
			for index: int in outer_connection.modules:
				var module: PlatformingModule=trace.stage.modules[index]
				carrier_modules.append({"node_id":trace.stage.manifest.nodes[index].id,"module_id":str(module.definition.module_id),"path":str(module.get_path())})
				for ferry: ModuleMovingPlatform in module.moving_platforms:ferry_paths.append(str(ferry.get_path()))
			var contacts: Array=[]
			for frame: Dictionary in trace.observed_frames.slice(start_tick):
				for collision: Dictionary in frame.collisions:
					if collision.collider in ferry_paths:contacts.append({"tick":frame.tick,"collider":collision.collider,"normal":collision.normal,"position":frame.position})
			route_comparison={"path":path,"start_tick":start_tick,"end_tick":trace.trace_ticks,"start_position":start_position,"end_position":pair(trace.motor.global_position),"runtime_before":before,"runtime_after":trace.runtime_snapshot(true),"ferry_contacts":contacts,"ferry_paths":ferry_paths,"carrier_modules":carrier_modules,"connection_id":outer_connection.id,"actual_edges":trace.observed_edges.filter(func(e:Dictionary):return e.start_tick>=start_tick),"reached":ok,"scope":"Same root/map/initial build/policy; shared fork and convergence. Timing/phase/resource observations, not a fun score or universally faster shortcut."}
			check(not contacts.is_empty() if mode=="outer_return" else true,"lower return actually rides the exact new horizontal connection carrier")
			if ok and mode=="outer_upper_alternative":
				var return_begin: int=trace.trace_ticks
				# Counterclockwise circuit: upper outward clears its receiving
				# bank; descend the eastern arm and leave through the new lower boat.
				# Preserve failed clockwise kill and bait strategies separately.
				var returned: bool=await trace.follow_to("area_4_3")
				if trace.is_trace_cancelled(): return
				if returned:
					returned=await trace.follow_to("area_3_3")
					if trace.is_trace_cancelled(): return
				route_comparison["cycle_return"]={"encounter_policy":"kill_from_bank_v1","path":["area_4_2","area_4_3","area_3_3"],"start_tick":return_begin,"end_tick":trace.trace_ticks,"position":pair(trace.motor.global_position),"reached":returned,"actual_edges":trace.observed_edges.filter(func(e:Dictionary):return e.start_tick>=return_begin)}
				check(returned,"same body closes upper-out lower-back circuit without repeating entry shaft")
				ok=returned
		if ok:
			ok=await trace.follow_to(str(trace.stage.manifest.prep_id))
			if trace.is_trace_cancelled(): return
	trace.finish(ok,"route_target_reached" if ok else "scene_custom_route_failed")

func extra_upward_recoil(trace) -> bool:
	var well: PlatformingModule
	for module: PlatformingModule in trace.stage.modules:
		if module.definition.module_id==&"plains_windchime_well":well=module;break
	if well==null:return false
	trace.current_edge="elective_extra_upward_recoil"
	trace.observe_every_tick=true
	app.overlay.set_enabled(true);app.overlay.update_layout()
	# Combined real toast/overlay/recoil state. No item/build grant.
	app.item_toast.show_item(DemoApp.SHOT_ITEM);app._layout_region_hud()
	var approached: bool = await trace.move_to(well.position.x+265)
	if trace.is_trace_cancelled(): return false
	if not approached:return false
	trace.critical_traversal+=1
	var latch: ShotLatch=trace.shot_latch_encounter.for_module(well)
	var first_event: int=trace.events.size()
	trace.controller.router.set_move_axis(1)
	trace.controller.router.request_action(&"jump")
	await trace.tick(14)
	if trace.is_trace_cancelled(): return false
	trace.controller.router.request_action(&"shoot_release",(trace.motor.get_node("KeyboardMouseAdapter") as KeyboardMouseAdapter).world_direction(trace.motor.get_canvas_transform()*latch.bell_body.global_position))
	trace.controller.router.set_move_axis(0)
	await trace.tick(18)
	if trace.is_trace_cancelled(): return false
	var second_tick: int=trace.trace_ticks+1
	elective_ascent=true
	# A second ordinary legal downward shot, with the real cooldown, charges,
	# energy and accepted events. No capability or resource injection.
	trace.controller.router.request_action(&"shoot_release",Vector2.DOWN)
	trace.controller.router.request_action(&"jump_release")
	var apex: float=trace.motor.global_position.y
	var settled:=false
	for unused: int in 240:
		trace.controller.router.set_move_axis(clampf((well.position.x+430-trace.motor.global_position.x)/5.5,-1,1))
		await trace.tick()
		if trace.is_trace_cancelled(): return false
		apex=minf(apex,trace.motor.global_position.y)
		if trace.motor.is_on_floor():settled=true;break
	trace.critical_traversal-=1
	var accepted: Array=[]
	for event: Dictionary in trace.events.slice(first_event):
		if event.kind=="shot_accepted":accepted.append(event)
	var scope:={"second_request_tick":second_tick,"accepted_shots":accepted,"apex_world_y":apex,"well_origin":pair(well.global_position),"settled":settled,"limitation":"Actor always mandatory. Distant old bank recorded throughout elective ascent but may leave finite view; canonical complete well arc remains separately mandatory."}
	elective_receipts.append(scope)
	check(accepted.size()==2 and accepted[1].tick>=second_tick,"elective second upward recoil uses two accepted real shots")
	check(apex<well.position.y-100,"elective actual ascent exceeds canonical well observation band")
	if not (settled and latch.is_open): return false
	var completed: bool = await trace.move_to(well.world_exit().x)
	if trace.is_trace_cancelled(): return false
	return completed

func legacy_compatibility() -> void:
	var legacy:=DemoApp.new();legacy.meta_persistence_enabled=false;root.add_child(legacy)
	check(legacy.start_demo("scene-legacy-info",false),"original nonregion consumer starts")
	for unused: int in 120:
		await physics_frame;await process_frame
		if not legacy._stage_pending and is_instance_valid(legacy.stage):break
	await process_frame
	# Fixed legacy rooms have no run-camera. Exercise the actual nonregion
	# StageCameraRig default separately, on the real legacy actor.
	var camera:=StageCameraRig.new();legacy.add_child(camera)
	camera.configure(legacy.player,Rect2(-2000,-1000,4000,2000))
	legacy_ui={"connected_region":legacy.connected_region,"info":pair(legacy._debug_button.position),"hud_width":legacy._hud_frame.size.x,"health_width":legacy._resources_hud.health_bar.size.x,"camera_zoom":pair(camera.zoom),"camera_scope":"actual nonregion StageCameraRig fixture; fixed legacy rooms themselves have no run-camera","scope":"actual legacy DemoApp consumer, not screenshot/device acceptance"}
	check(not legacy.connected_region and legacy._debug_button.position==Vector2(434,10),"nonregion actual INFO original position")
	check(legacy._hud_frame.size.x==500 and legacy._resources_hud.health_bar.size.x==220,"nonregion actual HUD and resource original widths")
	check(camera.zoom.is_equal_approx(Vector2.ONE*1.95),"nonregion original camera zoom retained")
	legacy.debug_hud=true;await process_frame
	check(legacy._debug_button.position==Vector2(434,10),"nonregion debug INFO original position")
	legacy.free();await process_frame

func run() -> void:
	if not mutation.is_empty():await run_case(1,"growth" if mutation=="foreground_ferry" else "fast")
	else:
		await legacy_compatibility()
		await run_case(1,"fast")
		await run_case(2,"growth")
		await run_case(2,"return","main_then_high")
		await run_case(2,"fast","outer_return")
		await run_case(2,"fast","outer_upper_alternative")
		await run_case(1,"fast","extra_upward_recoil")
		await run_case(1,"fast","touch_geometry")
		var selected := ""
		var corpus: Array = []
		for index: int in 10:
			var candidate := "level-design-v2-baseline" if index==0 else "level-design-v2-baseline/%02d" % index
			var generated := PlainsRegionGenerator.new().generate(PlainsRegionCampaign.seed_for(candidate,2),PlayerTuning.load_default(),false,"","advanced")
			var high: Dictionary=generated.manifest.rewards.filter(func(r:Dictionary):return r.tier=="high")[0]
			corpus.append({"seed":candidate,"variant":high.variant,"action_signature":high.action_signature,"stream_positions":generated.manifest.stream_positions})
			if int(high.variant)==0 and selected.is_empty():selected=candidate
		check(not selected.is_empty(),"canonical corpus retains rolled0 distinct challenge")
		if not selected.is_empty():await run_case(2,"return","main_then_high",selected)
		cases.append({"generation_corpus":corpus})

	if output.is_empty() or FileAccess.file_exists(output):printerr("unique output required");quit(2);return
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"scope":"normally scheduled formal consumer; privileged frozen route policy, projection proxy not human perception/device/aesthetics","assertions":assertions,"failures":failures,"mutation":mutation,"legacy_ui":legacy_ui,"screenshots":screenshots,"cases":cases,"post_capture_cleanup":cleanup_receipts})+"\n");file.close()
	print("PLAINS REDESIGN SCENE NATIVE: %d assertions, %d failures" % [assertions,failures])
	quit(0 if failures==0 else 1)


# Test-only independent-stage fixture; no natural campaign transition is claimed.
func _sync_fixture_map_index(app: DemoApp, index: int) -> void:
	for entry: Dictionary in app.director.get_property_list():
		if str(entry.get("name", "")) == "region_map_index":
			app.director.set("region_map_index", index)
			return

func _fixture_identity_matches(app: DemoApp, index: int, root_seed: String) -> bool:
	var actual := app.stage as PlainsRegionStage
	if actual == null or not actual.assembly_ok: return false
	var manifest: Dictionary = actual.generated.manifest
	return actual.map_index == index and manifest.get("region", "") == "plains" and manifest.get("seed", "") == PlainsRegionCampaign.seed_for(root_seed, index) and manifest.get("difficulty", "") == ("intro" if index == 1 else "advanced")
