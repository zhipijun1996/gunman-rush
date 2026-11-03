extends SceneTree
## Actual installed SDK -> controller request -> generated full start module.
## Only the owned module's exit bank is covered. The actual external neighbor
## is intentionally not loaded; this is not a full-map or cross-seam proof.
const SCENE := preload("res://experiments/generation/runtime_map_windchime_slice.tscn")
const BOOTSTRAP := preload("res://experiments/platform/cloud_preview.gd")
const GENERATED_PROOF := preload("res://tests/runtime_map_generated_slice_runner.gd")
const OUTPUT_DIR := "res://build/mapgen041/windchime_generated"
var checks := 0
var failures := 0
var observations: Array[Dictionary] = []

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	observations.append({"check":label,"passed":value})
	if not value:
		failures += 1
		push_error("GENERATED WINDCHIME: "+label)

func frames(count: int) -> void:
	# The existing PlayerController remains on its ordinary automatic physics
	# schedule. Never call physics_tick or write the actor's position here.
	for index: int in count: await physics_frame

func wait_ready(world: RuntimeMapWindchimeSlice) -> bool:
	var started := Time.get_ticks_msec()
	var count := 0
	while not world.ready_ok and world.error.is_empty() and count<10000 and Time.get_ticks_msec()-started<60000:
		await process_frame
		count += 1
	observations.append({"case":"generation_wait","frames":count,"wall_ms":Time.get_ticks_msec()-started,"receipt":world.generation_receipt.duplicate(true),"capability_snapshot":world.capability_snapshot.duplicate(true)})
	check(world.ready_ok,"actual controller request reaches generated/assembled/physics-admitted ready within 60s/10000 frames: "+world.error)
	return world.ready_ok

func walk_to(world: RuntimeMapWindchimeSlice, target: float, budget: int = 180) -> void:
	var start := world.session.player.global_position
	var steps := world.session.player.motion_steps
	for index: int in budget:
		world.session.controller.router.set_source_axis(&"generated_windchime_test",clampf((target-world.session.player.global_position.x)/5.0,-1.0,1.0),true)
		await frames(1)
		if absf(target-world.session.player.global_position.x)<1.5 and world.session.player.is_on_floor(): break
	world.session.controller.router.set_source_axis(&"generated_windchime_test",0.0)
	var finish := world.session.player.global_position
	observations.append({"case":"real_router_walk","start":[start.x,start.y],"finish":[finish.x,finish.y],"target_x":target,"motor_steps":world.session.player.motion_steps-steps,"grounded":world.session.player.is_on_floor()})

func count_kind(node: Node, kind: String) -> int:
	var result := 0
	if kind=="player" and node is PlayerMotor or kind=="controller" and node is PlayerController or kind=="policy" and node is FrameDamagePolicy: result = 1
	for child: Node in node.get_children(): result += count_kind(child,kind)
	return result

func physical_contract(world: RuntimeMapWindchimeSlice) -> void:
	var stage := world.stage
	var controller := world.session.controller
	var player := world.session.player
	var wallet := world.session.wallet
	var policy := world.policy
	var actor_before := world.session.lifetime.token()
	check(world.generation_profile=="controller" and world.generation.phase(world.ticket)=="committed" and world.entry_admitted,"real controller-source entrance commits only after shared Stage and physical spawn admission")
	check(world.profile_inputs.lock.version=="0.4.1" and world.generation_receipt.source_kind=="generated_memory","current 0.4.1 installed SDK is an in-memory generation source")
	check(not controller.traversal.hook_enabled and not world.generation_receipt.actual_hook_enabled and "grapple" not in world.generation_receipt.request_abilities,"controller request and live actor both lack ungranted grapple")
	check(count_kind(world,"player")==1 and count_kind(world,"controller")==1 and count_kind(world,"policy")==1,"one formal player/controller and shared damage policy")
	check(world.session.build.controller==controller and policy.lifetime==world.session.lifetime and wallet!=null and world.session.rewards!=null,"existing RunSession remains the sole services/lifetime authority")
	check(GENERATED_PROOF.write_actual_artifacts(world,OUTPUT_DIR),"persist this exact job's actual result/provenance/bindings/canonical fingerprint input")
	var identity: Dictionary = stage.plan.get_meta("runtime_map_v2_identity")
	check(identity.source_kind=="generated_memory" and identity.host_load_identity==stage.plan.map_hash,"generated content and host load identity are bound without invented map-file SHA")
	check(stage.plan.modules.size()==1 and stage.shot_latch_encounter!=null and stage.shot_latch_encounter.latches.size()==1,"one complete actual start module with its original safe_lesson")
	var placement := stage.plan.modules[0]
	var source: Dictionary = placement.definition.get_meta("runtime_map_v2_instance",{})
	var content: Dictionary = placement.definition.get_meta("runtime_map_v2_content",{})
	check(source.module_id==RuntimeMapShotLatchAdapter.MODULE_ID and source.content_version==RuntimeMapShotLatchAdapter.CONTENT_VERSION and source.role=="start","selection uses actual module/content version/start role rather than a pinned instance number")
	var unchanged_geometry: bool = placement.definition.platforms.size()==content.platforms.size()+source.seals.size()
	if unchanged_geometry:
		for index: int in content.platforms.size():
			unchanged_geometry = unchanged_geometry and placement.definition.platforms[index]==RuntimeMapShotLatchAdapter.rectangle(content.platforms[index])
		for index: int in source.seals.size():
			unchanged_geometry = unchanged_geometry and placement.definition.platforms[content.platforms.size()+index]==RuntimeMapShotLatchAdapter.rectangle(source.seals[index].rect_pixels)
	check(unchanged_geometry and placement.definition.has_meta("runtime_map_v2_authored_helpers"),"all complete materialized source platforms/seals remain and old helpers retain provenance")
	check(world.exit_port_id=="exit" and not world.exit_bank_world.is_zero_approx(),"actual used Port resolves a body-clear owned exit bank")
	await frames(12)
	var spawn := player.global_position
	check(player.is_on_floor() and player.global_position.distance_to(stage.plan.spawn)<0.2,"actual generated spawn stands still on the unchanged full module floor")
	var latch := stage.shot_latch_encounter.latches[0]
	var key := stage.shot_latch_encounter.state_keys[0]
	check(not latch.is_open and not latch.gate_shape.disabled,"actual original gate starts physically closed")
	var forward := signf(world.exit_bank_world.x-spawn.x)
	await walk_to(world,world.exit_bank_world.x)
	var gate_center := latch.to_global(latch.gate_rect.get_center())
	check(not latch.is_open and (player.global_position.x-gate_center.x)*forward<0,"closed original gate actually blocks normal Router/Motor movement to exit")
	var health_before := controller.actor_resources.health.current
	var serial_before := controller.shoot_ability._shot_serial
	controller.router.request_action(&"shoot_release",Vector2.UP)
	await frames(30)
	check(not latch.is_open,"real Router/projectile miss leaves the original gate closed")
	controller.router.request_action(&"shoot_release",(latch.bell_body.global_position-player.global_position).normalized())
	await frames(30)
	check(latch.is_open and latch.open_count==1 and latch.health.terminal and latch.gate_shape.disabled,"real accepted Router projectile hits the original bell and opens the gate permanently")
	check(world.session.region_state.opened.get(key)==true and world.session.region_state.mechanisms.has(key),"existing stable instance/latch ledger records accepted permanent opening")
	controller.router.request_action(&"shoot_release",(latch.bell_body.global_position-player.global_position).normalized())
	await frames(30)
	check(latch.is_open and latch.open_count==1,"repeated real Router hit attempt cannot settle the permanent door twice")
	check(controller.shoot_ability._shot_serial>=serial_before+2 and controller.actor_resources.health.current==health_before,"real original shot ability executes without injected hits or health/resource grants")
	await walk_to(world,world.exit_bank_world.x)
	await frames(6)
	check(player.is_on_floor() and absf(player.global_position.x-world.exit_bank_world.x)<1.5,"normal Router/Motor crosses the opened original gate to the actual owned exit shore")
	check(world.session.player==player and world.session.wallet==wallet and world.policy==policy,"route retains original player/wallet/damage authorities")
	var saved: Dictionary = stage.capture_state()
	check(PlainsRegionState.new().restore(saved,stage.plan.map_hash) and not PlainsRegionState.new().restore(saved,"different-host-load"),"existing run-local state accepts exact load identity and refuses a different one")
	var old_latch: WeakRef = weakref(latch)
	var old_stage: WeakRef = weakref(stage)
	var source_identity := stage.plan.map_hash
	var actor_epoch_before: int = world.session.lifetime.actor_epoch
	check(world.reload_slice(),"same generated Plan restores through the existing host reload boundary: "+world.error)
	await frames(5)
	check(old_stage.get_ref()==null and old_latch.get_ref()==null,"restore releases previous complete Stage and latch")
	check(world.session.player==player and world.session.controller==controller and world.session.wallet==wallet and world.policy==policy,"restore keeps existing controller/player/wallet/damage authorities")
	check(not world.accepts_result(actor_before),"restore actor invalidation refuses old actor token")
	check(world.session.lifetime.actor_epoch==actor_epoch_before+1,"first restore advances exactly the existing actor epoch")
	check(world.stage.plan.map_hash==source_identity and world.stage.shot_latch_encounter.latches.size()==1,"restore keeps exact generated load identity and one original latch")
	var restored := world.stage.shot_latch_encounter.latches[0]
	check(restored.is_open and restored.open_count==1 and restored.gate_shape.disabled,"restored original permanent-open state disables the real gate collision")
	check(player.is_on_floor() and absf(player.global_position.x-world.exit_bank_world.x)<1.5,"same-map restore retains actual reached shore without teleport or player reset")
	check(world.generation.take_plan(world.ticket,world.session.lifetime)==null and not world.generation.commit(world.ticket,world.session.lifetime) and not world.generation.tick(world.ticket,world.session.lifetime),"first restore cannot revive or recommit the stale generation ticket")
	var second_actor: DemoToken = world.session.lifetime.token()
	var second_stage: WeakRef = weakref(world.stage)
	check(world.reload_slice(),"second consecutive restore accepts the same previously committed generated Plan")
	await frames(5)
	check(second_stage.get_ref()==null and not world.accepts_result(second_actor) and world.session.lifetime.actor_epoch==actor_epoch_before+2,"second restore releases its predecessor and advances actor epoch exactly once")
	check(world.stage.plan.map_hash==source_identity and world.session.player==player and world.session.controller==controller and world.session.wallet==wallet and world.policy==policy,"repeated restore retains exact content identity and original authorities")
	var twice_restored := world.stage.shot_latch_encounter.latches[0]
	check(twice_restored.is_open and twice_restored.open_count==1 and twice_restored.gate_shape.disabled,"second restore keeps permanent-open state and settlement count")
	check(world.generation.take_plan(world.ticket,world.session.lifetime)==null and not world.generation.commit(world.ticket,world.session.lifetime) and not world.generation.tick(world.ticket,world.session.lifetime),"second restore still refuses old job result, commit and tick")
	var lifetime: DemoLifetime = world.session.lifetime
	var stable_stage: RuntimeMapSliceStage = world.stage
	var saved_stage_epoch: int = lifetime.stage_epoch
	var stable_actor_epoch: int = lifetime.actor_epoch
	lifetime.stage_epoch += 1
	check(not world.reload_slice() and world.stage==stable_stage and world.session.wallet==wallet and lifetime.actor_epoch==stable_actor_epoch,"changed stage epoch refuses restore before replacing Stage, wallet or actor")
	observations.append({"case":"expected_stage_epoch_rejection","error":world.error})
	lifetime.stage_epoch = saved_stage_epoch
	var replacement := DemoLifetime.new()
	replacement.epoch = lifetime.epoch
	replacement.stage_epoch = lifetime.stage_epoch
	replacement.actor_epoch = lifetime.actor_epoch
	replacement.active = lifetime.active
	world.session.flow.lifetime = replacement
	check(world.session.lifetime==replacement and not world.reload_slice() and world.stage==stable_stage and world.session.wallet==wallet and replacement.actor_epoch==stable_actor_epoch,"different lifetime object with equal epochs refuses restore without side effects")
	observations.append({"case":"expected_lifetime_object_rejection","error":world.error})
	world.session.flow.lifetime = lifetime
	observations.append({"case":"complete_owned_module","scope":"single complete start module only; external neighbor not loaded/certified","source":source.duplicate(true),"identity":identity.duplicate(true),"spawn":[spawn.x,spawn.y],"exit_bank":[world.exit_bank_world.x,world.exit_bank_world.y],"latches":world.stage.shot_latch_encounter.observations(),"saved_state":saved})

func bootstrap_contract() -> void:
	var host := BOOTSTRAP.new()
	host.task_id = "MAPGEN-HOST-WINDCHIME-041"
	host.review_seed = "930001"
	host.entry = "scene"
	host.entry_scene = "res://experiments/generation/runtime_map_windchime_slice.tscn"
	root.add_child(host)
	await process_frame
	await process_frame
	check(host.custom_scene is RuntimeMapWindchimeSlice and host.app==null,"existing preview bootstrap opens actual developer scene without parallel App owner")
	if not host.custom_scene is RuntimeMapWindchimeSlice:
		check(await WorldAudioLifecycle.drain_world(host),"failed bootstrap cleanup drains actual audio")
		host.free()
		return
	var world := host.custom_scene as RuntimeMapWindchimeSlice
	check(world.error.is_empty() and world.ticket!=null,"actual new scene creates its own job through existing composition: "+world.error)
	if world.error.is_empty() and world.ticket!=null and await wait_ready(world): await physical_contract(world)
	var job := world.generation
	var ticket := world.ticket
	var lifetime := world.session.lifetime
	var actor := lifetime.token()
	var stage_ref: WeakRef = weakref(world.stage) if is_instance_valid(world.stage) else null
	var world_ref: WeakRef = weakref(world)
	# Exercise the real key event and the existing signal/bootstrap return path.
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	# Audio teardown uses a real wall-clock drain; fixed-fps headless frames
	# can run much faster than real time. Wait for the actual bootstrap result.
	var returning_started := Time.get_ticks_msec()
	while Time.get_ticks_msec()-returning_started<5000:
		await process_frame
		if host.entry=="menu" and is_instance_valid(host.app): break
	escape = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = false
	Input.parse_input_event(escape)
	await frames(3)
	check(host.entry=="menu" and is_instance_valid(host.app) and host.app.menu.visible_panel==&"title" and not host.app.meta_persistence_enabled,"real ESC returns through existing bootstrap to actual title menu with persistence disabled")
	check(world_ref.get_ref()==null and (stage_ref==null or stage_ref.get_ref()==null),"menu return releases the actual generated scene and full Stage")
	check(not lifetime.active and not lifetime.accepts(actor) and job.is_closed(),"exit invalidates old actor/lifetime and closes generation owner")
	check(job.take_plan(ticket,lifetime)==null and not job.commit(ticket,lifetime) and not job.tick(ticket,lifetime),"exited generated source refuses late result/tick/duplicate commit")
	check(await WorldAudioLifecycle.drain_world(host),"final actual title audio drains with existing WorldAudioLifecycle")
	host.free()
	await process_frame

func cancel_contract(after_preload: bool) -> void:
	var world := SCENE.instantiate() as RuntimeMapWindchimeSlice
	root.add_child(world)
	var handle := world.ticket
	check(handle!=null and world.stage==null,"cancel entrance begins with independent job and no Stage")
	if handle!=null and after_preload:
		var started := Time.get_ticks_msec()
		while world.generation.phase(handle)=="preload" and Time.get_ticks_msec()-started<10000: await process_frame
		check(world.generation.phase(handle)=="generate","actual later cancel reaches generation after verified preload/cache")
	else:
		check(handle!=null and world.generation.phase(handle)=="preload","immediate cancellation covers actual preloading")
	var actor := world.session.lifetime.token()
	check(await world.close_preview(),"existing close_preview drains loading scene")
	check(not world.reload_slice() and world.stage==null,"closed entrance refuses restore and cannot create a Stage")
	check(world.closed and world.stage==null and not world.ready_ok and not world.session.lifetime.accepts(actor),"cancel keeps no assembled Stage or accepting actor token")
	check(world.generation.is_closed() and world.generation.take_plan(handle,world.session.lifetime)==null and not world.generation.commit(handle,world.session.lifetime),"cancelled source refuses late/duplicate plan delivery")
	check(not world.generation.tick(handle,world.session.lifetime) and world.stage==null,"late cancelled tick cannot create nodes")
	world.free()
	await process_frame

func run() -> void:
	root.size = Vector2i(1280,720)
	await bootstrap_contract()
	await cancel_contract(false)
	await cancel_contract(true)
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	var file := FileAccess.open(OUTPUT_DIR+"/capture.json",FileAccess.WRITE)
	if file==null: check(false,"write real generated windchime capture")
	else:
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"scope":"actual generated complete owned start module, not whole-map or external-neighbor traversal/Web/device","observations":observations},"\t",true,true))
		file.close()
	print("RUNTIME_MAP_WINDCHIME_GENERATED checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
