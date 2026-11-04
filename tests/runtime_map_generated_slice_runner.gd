extends SceneTree
## Real generated entrance and its existing services; no result/solver fixture.
const SCENE := preload("res://experiments/generation/runtime_map_generated_slice.tscn")
const BUILDER := preload("res://game/world/generation/mapgen/runtime_map_generation_request.gd")
const DATA := preload("res://addons/mapgen/data_json.gd")
var checks := 0
var failures := 0
var observations: Array[Dictionary] = []

static func write_actual_artifacts(world: RuntimeMapGeneratedSlice, directory: String) -> bool:
	var actual: Dictionary = world.generation.actual_result(world.ticket,world.session.lifetime)
	var provenance: Dictionary = world.generation.provenance(world.ticket,world.session.lifetime)
	var bindings: Dictionary = world.generation.resolved_bindings(world.ticket,world.session.lifetime)
	if actual.get("status")!="PASS" or provenance.is_empty() or bindings.is_empty(): return false
	if DirAccess.make_dir_recursive_absolute(directory)!=OK: return false
	var payload: String = DATA.canonical({"request":provenance.request,"config":provenance.config,"library_sha256":provenance.module_archive.sha256,"implementation":provenance.implementation})
	var files := {"result.json":JSON.stringify(actual,"",true,true),"provenance.json":JSON.stringify(provenance,"",true,true),"host_bindings.json":JSON.stringify(bindings,"",true,true),"protocol_payload.json":payload}
	for name: String in files:
		var output := FileAccess.open(directory+"/"+name,FileAccess.WRITE)
		if output==null: return false
		output.store_string(files[name]) # Original canonical payload has no newline.
		output.close()
	return true

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	observations.append({"check":label,"passed":value})
	if not value:
		failures += 1
		push_error("GENERATED SLICE: "+label)

func enter() -> RuntimeMapGeneratedSlice:
	var world := SCENE.instantiate() as RuntimeMapGeneratedSlice
	root.add_child(world)
	return world

func frames(count: int) -> void:
	for index: int in count:
		await physics_frame

func count_kind(node: Node, kind: String) -> int:
	var count := 0
	if (kind == "player" and node is PlayerMotor) or (kind == "controller" and node is PlayerController) or (kind == "policy" and node is FrameDamagePolicy):
		count += 1
	for child: Node in node.get_children():
		count += count_kind(child,kind)
	return count

func builder_contract(world: RuntimeMapGeneratedSlice) -> void:
	var controller := world.session.controller
	var motor := world.session.player
	var inputs := RuntimeMapGenerationProfile.read_profile(world.DEFAULT_INPUT_PROFILE)
	check(inputs.ok,"locked request is decoded by original typed DataJSON")
	if not inputs.ok: return
	var template: Dictionary = inputs.request
	var original: String = DATA.canonical(template)
	var built: Dictionary = BUILDER.from_controller(controller,motor,930001,template)
	check(built.ok,"builder consumes actual configured controller: "+str(built.error))
	if not built.ok: return
	check(not controller.traversal.hook_enabled and "grapple" not in built.request.player.abilities and "grapple" in template.player.abilities,"conformance grapple tag never grants live or ordinary-request grapple")
	check(built.snapshot.abilities.maximum_jumps==controller.jump_ability.maximum_jumps(),"builder uses public effective jump capacity")
	check(not built.request.has("snapshot") and not built.request.has("host_token"),"diagnostics do not enter strict public algorithm request")
	var unchanged: Dictionary = built.request.duplicate(true)
	unchanged.seed = template.seed
	unchanged.player = template.player.duplicate(true)
	check(DATA.canonical(unchanged)==original and DATA.canonical(template)==original,"template terminals/filter/air-loop and original bytes-as-values preserved")
	var shape := motor.get_node("CollisionShape2D") as CollisionShape2D
	var rectangle := shape.shape as RectangleShape2D
	check(built.request.player.clearance_half_extents_pixels==[rectangle.size.x/2.0,rectangle.size.y/2.0],"actual default rectangle determines clearance")
	var old_scale := shape.scale
	shape.scale = Vector2(1.5,2.0)
	var scaled: Dictionary = BUILDER.from_controller(controller,motor,1,template)
	check(scaled.ok and scaled.request.player.clearance_half_extents_pixels==[rectangle.size.x*.75,rectangle.size.y],"actual shape scale affects clearance without changing the Resource")
	shape.scale = old_scale
	var old_disabled := shape.disabled
	shape.disabled = true
	check(not BUILDER.from_controller(controller,motor,1,template).ok,"missing active shape refuses request")
	shape.disabled = old_disabled
	var tuning := motor.tuning
	var old_max := tuning.max_jumps
	var old_floor := controller.jump_ability.capacity_floor
	var old_jumps := controller.jump_ability.used_jumps
	var old_shots := controller.action_resources.shot_charges
	# Test only the live aggregate field to which BuildState applies extra jumps;
	# do not invent an item or grant a core traversal ability.
	tuning.max_jumps = maxi(3,old_max)
	controller.jump_ability.capacity_floor = 0
	controller.jump_ability.used_jumps = tuning.max_jumps
	controller.action_resources.shot_charges = 0
	var spent: Dictionary = BUILDER.from_controller(controller,motor,1,template)
	check(spent.ok and spent.snapshot.abilities.maximum_jumps==tuning.max_jumps and "double_jump" in spent.request.player.abilities,"effective extra-jump tuning survives exhausted flight charges in nominal request")
	check(spent.ok and ("shot_recoil" in spent.request.player.abilities)==("shot_recoil" in built.request.player.abilities) and spent.snapshot.resources.shot_charges==0,"spent shot charge is observed without erasing nominal weapon capability or replenishing it")
	check(controller.action_resources.shot_charges==0 and controller.jump_ability.used_jumps==tuning.max_jumps and not controller.traversal.hook_enabled,"builder neither replenishes actions nor grants traversal")
	tuning.max_jumps = old_max
	controller.jump_ability.capacity_floor = old_floor
	controller.jump_ability.used_jumps = old_jumps
	controller.action_resources.shot_charges = old_shots
	var old_enabled := controller.shoot_ability.enabled
	# Avoid an enabled setter's reset side effects: zero capacity is a separate
	# nominal negative and is restored synchronously before any frame advances.
	var old_capacity := tuning.max_air_shots
	tuning.max_air_shots = 0
	var no_shots: Dictionary = BUILDER.from_controller(controller,motor,1,template)
	check(no_shots.ok and "shot_recoil" not in no_shots.request.player.abilities and controller.shoot_ability.enabled==old_enabled,"zero nominal shot capacity removes recoil without toggling ShootAbility")
	tuning.max_air_shots = old_capacity
	for seed: int in [-9007199254740991,9007199254740991]:
		var exact: Dictionary = BUILDER.from_controller(controller,motor,seed,template)
		check(exact.ok and exact.request.seed is int and exact.request.seed==seed,"integer seed boundary remains exact: "+str(seed))
	for seed: int in [-9007199254740992,9007199254740992]:
		check(not BUILDER.from_controller(controller,motor,seed,template).ok,"out-of-range seed is rejected: "+str(seed))
	check(not BUILDER.from_controller(null,motor,1,template).ok,"missing controller rejected")
	check(not BUILDER.from_controller(controller,motor,1,{}).ok,"invalid template rejected")
	check(DATA.canonical(template)==original,"all builder calls leave original template unchanged")

func ferry_contract(world: RuntimeMapGeneratedSlice) -> void:
	# Derive this inventory from THIS completed job, never the frozen map fixture.
	var actual: Dictionary = world.generation.actual_result(world.ticket,world.session.lifetime)
	check(actual.get("status")=="PASS" and actual.get("content_store") is Dictionary and actual.get("map") is Dictionary,"ferry contract reads the completed actual generation result")
	if actual.get("status")!="PASS" or not actual.get("content_store") is Dictionary or not actual.get("map") is Dictionary: return
	var selected: Dictionary = {}
	for placement: LevelModulePlacement in world.stage.plan.modules:
		selected[placement.instance_id] = true
	var expected: Dictionary = {}
	var found_instances: Dictionary = {}
	for instance: Dictionary in actual.map.instances:
		if not selected.has(instance.id): continue
		found_instances[instance.id] = true
		var content: Dictionary = actual.content_store[instance.content_ref]
		for source: Dictionary in content.moving_platforms:
			var key: String = str(instance.id)+"/"+str(source.platform_id)
			check(not expected.has(key),"actual selected source platform identity unique: "+key)
			expected[key] = source.duplicate(true)
	check(found_instances.size()==selected.size(),"every selected module resolves through actual instance content_ref")
	var observed: Dictionary = {}
	for index: int in world.stage.plan.modules.size():
		var placement: LevelModulePlacement = world.stage.plan.modules[index]
		var module: PlatformingModule = world.stage.assembler.modules[index]
		for ferry: ModuleMovingPlatform in module.moving_platforms:
			var key: String = placement.instance_id+"/"+str(ferry.definition.platform_id)
			check(not observed.has(key) and expected.has(key),"native ferry exists exactly once in selected source: "+key)
			observed[key] = true
			if not expected.has(key): continue
			var source: Dictionary = expected[key]
			var ellipse := ferry.definition as RuntimeMapEllipseDefinition
			check(ellipse!=null and source.trajectory_kind=="clockwise_ellipse/v1","native ferry retains original ellipse mechanism: "+key)
			if ellipse == null: continue
			check(ellipse.center==Vector2(source.ellipse_center[0],source.ellipse_center[1]) and ellipse.radii==Vector2(source.ellipse_radii[0],source.ellipse_radii[1]) and ellipse.x_sign==float(source.ellipse_x_sign) and ellipse.period()==float(source.ellipse_period) and ellipse.initial_phase==float(source.initial_phase),"native ellipse preserves materialized center/radii/sign/period/phase: "+key)
			check(ellipse.size==Vector2(source.size[0],source.size[1]) and ellipse.start==Vector2(source.start[0],source.start[1]) and ellipse.finish==Vector2(source.finish[0],source.finish[1]) and ellipse.dwell_duration==float(source.dwell_duration),"native ferry size/endpoints/dwell match actual source: "+key)
	check(observed.size()==expected.size() and not expected.is_empty(),"native ferry count matches nonempty actual selected source inventory")
	for key: String in expected:
		check(observed.has(key),"actual selected ferry is not omitted: "+key)
	observations.append({"case":"actual_ferry_inventory","expected_platforms":expected,"observed_platform_ids":observed.keys(),"expected_count":expected.size(),"actual_count":observed.size(),"previous_fixture_error":"slice02 hardcoded two ferries; real selected M16 contains P and M18/M21 contain none"})

func cancel_contract(after_preload: bool) -> void:
	var world := enter()
	var handle: RefCounted = world.ticket
	check(handle!=null and world.stage==null,"new entrance starts with a job and no Stage")
	if after_preload and handle!=null:
		var start := Time.get_ticks_msec()
		while world.generation.phase(handle)=="preload" and Time.get_ticks_msec()-start<10000:
			await process_frame
		check(world.generation.phase(handle)=="generate","cancel test reaches actual generation after real preload")
	else:
		check(world.generation.phase(handle)=="preload","immediate cancellation covers preloading")
	check(await world.close_preview(),"close_preview drains loading entrance")
	check(world.closed and world.stage==null and not world.ready_ok and world.generation.is_closed(),"cancelled entrance has no Stage or ready result")
	check(world.generation.take_plan(handle,world.session.lifetime)==null and not world.generation.commit(handle,world.session.lifetime),"closed source cannot take or commit a late plan")
	check(not world.generation.tick(handle,world.session.lifetime) and world.stage==null,"late tick cannot install anything")
	world.free()
	await process_frame

func run() -> void:
	root.size = Vector2i(1280,720)
	var world := enter()
	var initial_positions: Array[Vector2] = []
	if is_instance_valid(world.session.controller):
		var actual_player := world.session.player
		world.session.controller.segment_returned.connect(func() -> void: initial_positions.append(actual_player.global_position))
	check(world.error.is_empty() and world.ticket!=null,"actual generated scene composes player and source: "+world.error)
	if world.ticket!=null and world.error.is_empty():
		builder_contract(world)
		var started := Time.get_ticks_msec()
		var waited := 0
		while not world.ready_ok and world.error.is_empty() and waited<10000 and Time.get_ticks_msec()-started<60000:
			await process_frame
			waited += 1
		check(world.ready_ok,"real seed930001 reaches committed ready within 60s/10000 frames: "+world.error)
		observations.append({"generation_frames":waited,"elapsed_ms":Time.get_ticks_msec()-started,"receipt":world.generation_receipt.duplicate(true),"snapshot":world.capability_snapshot.duplicate(true)})
	if world.ready_ok:
		var stage := world.stage
		check(initial_positions.size()==1 and initial_positions[0].is_equal_approx(stage.plan.spawn),"exactly one accepted initial positioning event places the real actor at the host-bound spawn")
		observations.append({"accepted_initial_positions":initial_positions.map(func(value: Vector2) -> Array: return [value.x,value.y]),"requested_spawn":[stage.plan.spawn.x,stage.plan.spawn.y]})
		check(world.generation.phase(world.ticket)=="committed" and stage.assembly_ok and world.entry_admitted,"real generated plan commits only after Stage assembly and body/foot physics admission")
		check(world.session.flow.seed==world.request.root_seed and world.request.root_seed==str(world.profile_inputs.request.seed),"actual RunSession seed and LevelRequest seed match the one captured typed profile")
		check(write_actual_artifacts(world,"res://build/mapgen_godot_04/default"),"write same-run actual result/provenance/original canonical payload/resolved bindings for coverage")
		check(stage.plan.modules.size()==3 and stage.plan.connections.size()==3,"selected actual output installs three modules and three connections")
		ferry_contract(world)
		check(count_kind(world,"player")==1 and count_kind(world,"controller")==1 and count_kind(world,"policy")==1,"one real PlayerMotor/Controller and one FrameDamagePolicy")
		check(world.session.build.controller==world.session.controller and world.policy.lifetime==world.session.lifetime and world.session.wallet!=null and world.session.rewards!=null and world.session.shop!=null,"ordinary RunSession services share controller/lifetime")
		check(not world.session.controller.traversal.hook_enabled and not world.generation_receipt.actual_hook_enabled and "grapple" in world.generation_receipt.request_abilities,"four-tag conformance request is distinct from actual no-grapple player")
		var identity: Dictionary = stage.plan.get_meta("runtime_map_v2_identity")
		var provenance: Dictionary = world.generation.provenance(world.ticket,world.session.lifetime)
		check(identity.source_kind=="generated_memory" and identity.generation_input_fingerprint==provenance.expected_request_fingerprint and identity.host_load_identity==stage.plan.map_hash,"actual receipt fingerprints agree without frozen-file identity substitution")
		check(world.generation.take_plan(world.ticket,world.session.lifetime)==null and not world.generation.commit(world.ticket,world.session.lifetime),"already committed plan cannot be taken or committed twice")
		await frames(5)
		var player := world.session.player
		var before := player.global_position
		var steps := player.motion_steps
		var wallet := world.session.wallet
		var damage := world.policy
		world.session.controller.router.set_source_axis(&"generated_slice_test",1.0,true)
		await frames(20)
		world.session.controller.router.set_source_axis(&"generated_slice_test",0.0)
		check(player.motion_steps>steps and player.global_position.x>before.x+1.0,"real Router movement advances actual Motor without position injection")
		check(world.session.wallet==wallet and world.policy==damage,"movement keeps existing services rather than constructing replacements")
		observations.append({"movement_start":[before.x,before.y],"movement_end":[player.global_position.x,player.global_position.y],"motor_steps":player.motion_steps-steps})
	var stage_ref: WeakRef = weakref(world.stage) if is_instance_valid(world.stage) else null
	check(await world.close_preview(),"completed or failed entrance drains with original close_preview")
	check(not world.session.lifetime.active and world.stage==null and not world.ready_ok,"exit invalidates lifetime and detaches Stage")
	await process_frame
	check(stage_ref==null or stage_ref.get_ref()==null,"detached generated Stage is released")
	world.free()
	await process_frame
	await cancel_contract(false)
	await cancel_contract(true)
	DirAccess.make_dir_recursive_absolute("res://build/mapgen_godot_03")
	var output := FileAccess.open("res://build/mapgen_godot_03/generated_slice.json",FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify({"checks":checks,"failures":failures,"scope":"actual generated loading slice and builder only; not whole-map playability/Web/device","observations":observations}))
		output.close()
	else:
		check(false,"write actual generated slice receipt")
	print("RUNTIME_MAP_GENERATED_SLICE checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
