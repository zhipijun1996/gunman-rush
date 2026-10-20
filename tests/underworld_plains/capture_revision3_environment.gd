extends SceneTree
## Real formal App / KeyboardMouseAdapter / policy / selective return capture.
## Each process starts a new full-health run and makes exactly one explicit
## fixture-only initial position assignment onto an existing safe module anchor.
## Afterwards only real keyboard input drives approach; no manual hurt/heal,
## target repositioning, enemy pause, damage bypass or later actor teleport.
var app: DemoApp
var kind := "surface"
var seed := "level-design-v2-baseline/08"
var output := "res://build/underworld_r3/damage/formal_surface/trace.json"
var capture := false
var rows: Array[Dictionary] = []
var events: Array[Dictionary] = []
var health_events: Array[Dictionary] = []
var damage_events: Array[Dictionary] = []
var return_events: Array[Dictionary] = []
var failures: Array[String] = []
var fixture: Dictionary = {}
var checks := 0
var held := false
var seen_hurt := false
var seen_entry := false
var seen_exit := false
var image_dir := ""

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message);printerr("FAIL: ",message)
func json_value(value: Variant) -> Variant:
	if value is Vector2: return [value.x,value.y]
	if value is Rect2: return [value.position.x,value.position.y,value.size.x,value.size.y]
	if value is Dictionary:
		var converted: Dictionary={}
		for key: Variant in value: converted[str(key)]=json_value(value[key])
		return converted
	if value is Array:
		var converted: Array=[]
		for item: Variant in value: converted.append(json_value(item))
		return converted
	return value
func art() -> UnderworldPlayer:
	if not is_instance_valid(app.player): return null
	return app.player.get_node_or_null("PixelPlainsActor") as UnderworldPlayer
func key_right(pressed: bool) -> void:
	if held==pressed:return
	held=pressed
	var event:=InputEventKey.new();event.physical_keycode=KEY_D;event.keycode=KEY_D;event.pressed=pressed
	Input.parse_input_event(event)
	events.append({"event":"InputEventKey","key":"D","pressed":pressed,"trace_row":rows.size(),"physics_tick":Engine.get_physics_frames()})
func advance(phase: String, record := true) -> void:
	await physics_frame
	if capture: await RenderingServer.frame_post_draw
	else: await process_frame
	if not record or not is_instance_valid(app.player) or art()==null:return
	var renderer := art()
	var echoes: Array[Dictionary]=[]
	for node: Node in app.find_children("*","DamageReturnEcho",true,false):
		var echo := node as DamageReturnEcho
		echoes.append({"position":echo.global_position,"age":echo.age,"duration":echo.duration,"source_texture":echo.source.resource_path,"source_rect":echo.source_rect})
	var receipt:=renderer.animation_receipt()
	seen_hurt = seen_hurt or str(receipt.state)=="hurt"
	seen_entry = seen_entry or renderer._return_fade_remaining>0
	seen_exit = seen_exit or not echoes.is_empty()
	var row: Dictionary={"phase":phase,"row":rows.size(),"physics_tick":Engine.get_physics_frames(),"engine_drawn_frame":Engine.get_frames_drawn(),"position":app.player.global_position,"velocity":app.player.velocity,"motion_steps":app.player.motion_steps,"grounded":app.player.is_on_floor(),"health":app.controller.actor_resources.health.current,"health_epoch":app.controller.actor_resources.health.epoch,"actor_epoch":app.lifetime.actor_epoch,"stage_epoch":app.lifetime.stage_epoch,"router_axis":app.controller.router.sample_axes(),"keyboard_adapter_mode":app.player.get_node("KeyboardMouseAdapter").process_mode,"animation":receipt,"body_modulate":str(renderer.modulate),"source_exit_echoes":echoes,"input_D_held":held}
	if capture:
		var path := image_dir+"/frame_%04d.png" % rows.size()
		check(root.get_texture().get_image().save_png(path)==OK,"native postdraw PNG saves")
		row.image_file=path
	rows.append(json_value(row))
func nearest_safe_approach(module: PlatformingModule, danger: Rect2, max_range: float) -> Vector2:
	var best := Vector2.INF
	for point: Vector2 in (app.stage as PlainsRegionStage).anchors:
		var distance := danger.position.x-point.x
		if distance<30 or distance>max_range or absf(point.y+18-danger.get_center().y)>80:continue
		if not app.segment.is_safe(point):continue
		if not best.is_finite() or point.x>best.x:best=point
	return best
func candidate(stage: PlainsRegionStage) -> Dictionary:
	var candidates: Array[Dictionary]=[]
	for module: PlatformingModule in stage.assembler.modules:
		if kind=="surface":
			for thorn: PlatformThornDefinition in module.definition.surface_thorns:
				if thorn.face!=PlatformThornDefinition.Face.TOP:continue
				var local:=thorn.danger(module.definition.platforms)
				var danger:=Rect2(module.to_global(local.position),local.size)
				var initial:=nearest_safe_approach(module,danger,450)
				if not initial.is_finite():continue
				var expected_source := ""
				for node: Node in stage.get_children():
					if node is DemoContactEmitter and String(node.get_meta("hazard_module",""))==String(module.definition.module_id) and String(node.get_meta("hazard_authored_id",""))==String(thorn.surface_id) and (node as DemoContactEmitter).global_position.is_equal_approx(danger.get_center()):
						expected_source=String((node as DemoContactEmitter).source_id)
				if expected_source.is_empty():continue
				candidates.append({"initial_position":initial,"module_path":String(module.get_path()),"module_id":String(module.definition.module_id),"authored_id":String(thorn.surface_id),"role":"attached_surface","actual_danger":danger,"expected_source_id":expected_source})
		else:
			for gear: ModuleSawHazard in module.hazards:
				if gear.definition.travel.is_zero_approx():continue
				var envelope:=gear.definition.envelope()
				var danger:=Rect2(module.to_global(envelope.position),envelope.size)
				var initial:=nearest_safe_approach(module,danger,500)
				if not initial.is_finite():continue
				candidates.append({"initial_position":initial,"module_path":String(module.get_path()),"module_id":String(module.definition.module_id),"authored_id":String(gear.definition.source_id),"role":"moving_gear","actual_danger":danger,"expected_source_id":String(gear.runtime_source_id),"gear_period":gear.definition.period,"gear_travel":gear.definition.travel,"gear_clock_at_selection":module.clock})
	if candidates.is_empty():return {}
	# Prefer existing simple ground gear / first attached-thorn lesson. No enemy
	# is disabled or relocated. Other candidates remain in selection evidence.
	for item: Dictionary in candidates:
		item["preferred"]=item.module_id==("plains_gear_hop" if kind=="gear" else "plains_thorn_slalom")
	candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if a.preferred!=b.preferred:return a.preferred
		return String(a.module_path)<String(b.module_path))
	var picked: Dictionary=candidates[0].duplicate(true)
	picked.candidates=candidates
	return picked
func execute() -> void:
	check(kind in ["surface","gear"],"supported environment case kind")
	check(app.start_plains(seed),"ordinary formal App starts a fresh full-health run")
	var loaded := 0
	while (app._stage_pending or not app.stage is PlainsRegionStage or not is_instance_valid(app.policy)) and loaded<90:
		await advance("formal_loading",false);loaded+=1
	if not app.stage is PlainsRegionStage or not is_instance_valid(app.policy):check(false,"formal map did not load");return
	var stage:=app.stage as PlainsRegionStage
	# Let the real startup birth protection expire at the ordinary safe spawn.
	# No clock mutation or invulnerability bypass; this also keeps the first
	# contacted thorn from being consumed harmlessly before its pulse retry.
	while app.policy.clock<app.policy._protected_until:
		await advance("ordinary_spawn_protection_expiry",false)
	check(stage.assembly_ok and app.director.stage_index==1,"real first map assembled")
	fixture=candidate(stage)
	fixture["seed"]=seed;fixture["map_index"]=app.director.stage_index;fixture["manifest_hash"]=stage.generated.manifest.manifest_hash
	check(fixture.has("initial_position"),"actual requested hazard and safe existing approach anchor found")
	if not fixture.has("initial_position"):return
	var initial: Vector2=fixture.initial_position
	check(app.controller.actor_resources.health.current==app.controller.actor_resources.health.capacity,"run begins at original configured full HP")
	check(app.player.get_node("KeyboardMouseAdapter").process_mode!=Node.PROCESS_MODE_DISABLED,"ordinary keyboard adapter remains enabled")
	# Only initialization assignment in this process. No resource/reset API.
	app.player.global_position=initial
	if is_instance_valid(app._run_camera):app._run_camera.snap_to_target()
	fixture["initial_position_assignments"]=1
	fixture["initialization_policy"]="one explicit fixture position on existing safe platform anchor; then only real D input; no HP grant, manual damage, enemy pause or later actor position write"
	app.controller.actor_resources.health.changed.connect(func(result: ActorResourceResult) -> void:
		if result.operation==&"damage" and result.status==ActorResourceResult.Status.APPLIED and result.amount_applied<0:
			health_events.append({"event_id":String(result.event_id),"amount_applied":result.amount_applied,"health":result.snapshot.current,"terminal":result.snapshot.terminal,"physics_tick":Engine.get_physics_frames(),"engine_drawn_frame":Engine.get_frames_drawn(),"old_hit_position":app.player.global_position,"trace_row":rows.size()}))
	app.policy.batch_resolved.connect(func(batch: Array[DamageResult]) -> void:
		for result: DamageResult in batch:
			if result.request.target_id!=&"player":continue
			damage_events.append({"event_id":String(result.request.event_id),"source_id":String(result.request.source_id),"kind":result.request.kind,"amount":result.request.amount,"health":result.health.current,"hit_direction":result.request.hit_direction,"request_physics_tick":result.request.physics_tick,"commit_physics_tick":Engine.get_physics_frames(),"stage_epoch":result.request.token.stage_epoch,"actor_epoch":result.request.actor_epoch,"trace_row":rows.size()}))
	app.controller.segment_returned.connect(func() -> void:
		return_events.append({"physics_tick":Engine.get_physics_frames(),"safe_entry_position":app.player.global_position,"return_fade":art()._return_fade_remaining,"hurt_remaining":art()._hurt_remaining,"trace_row":rows.size()}))
	for i: int in 12:await advance("fixture_supported_before_input")
	check(app.player.is_on_floor() and app.player.global_position.distance_to(initial)<3,"fixture settles on actual existing floor without movement")
	check(health_events.is_empty(),"initial safe fixture has no spontaneous damage")
	fixture["active_anchor_before_input"]=String(app.segment._history[-1]) if not app.segment._history.is_empty() else ""
	fixture["original_HP"]=app.controller.actor_resources.health.current
	key_right(true)
	for i: int in 198:
		if not health_events.is_empty() or i>=90:key_right(false)
		await advance("real_keyboard_approach" if health_events.is_empty() else "accepted_environment_exit_entry_recovery")
	key_right(false)
	check(health_events.size()==1,"one actual HP commit from real environment contact")
	check(damage_events.size()==1 and damage_events[0].source_id==fixture.expected_source_id and damage_events[0].kind==DamageRequest.Kind.ENVIRONMENT,"actual accepted source is the selected real hazard")
	check(return_events.size()==1,"one actual selective environment return")
	check(seen_hurt and seen_entry and seen_exit,"postphysics/postdraw captures actual hurt, old source exit and safe entry")
	check(is_instance_valid(app.player) and app.lifetime.active and app.controller.actor_resources.health.current==float(fixture.original_HP)-1,"player remains alive with exactly one real HP loss")
	check(art()._return_fade_remaining==0 and art().animation_state!="hurt","environment recovery completes its actual animation exit")
	check(rows.size()==210,"bounded case records 3.5 seconds at 60 physics ticks")
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument=="--capture":capture=true
		elif argument.begins_with("--kind="):kind=argument.trim_prefix("--kind=")
		elif argument.begins_with("--seed="):seed=argument.trim_prefix("--seed=")
		elif argument.begins_with("--output="):output=argument.trim_prefix("--output=")
	image_dir=output.get_base_dir()+"/postdraw_frames"
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	if capture:DirAccess.make_dir_recursive_absolute(image_dir)
	root.size=Vector2i(1280,720)
	app=preload("res://scenes/demo/demo.tscn").instantiate() as DemoApp;app.meta_persistence_enabled=false;root.add_child(app)
	await execute()
	key_right(false)
	var report: Dictionary={"schema":"underworld-r3-formal-environment-capture-v1","kind":kind,"capture":capture,"seed":seed,"checks":checks,"failures":failures,"fixture":fixture,"health_commits":health_events,"damage_receipts":damage_events,"segment_returns":return_events,"actual_input_events":events,"frames":rows,"media_scope":"210 actual per-tick observations (3.5 simulation seconds); PNGs only under --capture after frame_post_draw. MovieMaker startup/teardown frames are additional. Software host rendering speed is not device FPS. Explicit fixture-only initial placement, not natural route from region entrance."}
	if not await load("res://tests/audio_teardown.gd").drain_world(app):check(false,"actual App audio teardown releases")
	report.checks=checks;report.failures=failures
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(json_value(report),"\t"));file.close()
	app.queue_free();for i: int in 5:await process_frame
	print("REVISION3 ENVIRONMENT kind=%s frames=%d checks=%d failures=%d" % [kind,rows.size(),checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
