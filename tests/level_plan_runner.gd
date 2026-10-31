extends SceneTree
## The existing providers must preserve recorded bytes; the common runtime
## must also accept content that has never had a legacy Manifest.
const AUDIO := preload("res://tests/audio_teardown.gd")
var assertions := 0
var failures := 0
var app: DemoApp

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	assertions+=1
	if not ok:
		failures+=1
		push_error("FAIL: "+label)

func frames(count: int) -> void:
	for _index: int in count: await physics_frame

func request_for(region: StringName, index: int) -> LevelRequest:
	var request := LevelRequest.new()
	request.root_seed="level-boundary-fixture"
	request.region_id=region
	request.map_index=index
	request.tuning=PlayerTuning.load_default()
	request.root_bell_mode="v3"
	request.capabilities={"grapple":true,"weapon_id":"standard","abilities":[&"grapple"],"items":[],"forest_content_version":ThornForestRegionGenerator.VERSION,"forest_layout_version":ThornForestRegionGenerator.CURRENT_DEPTH_LAYOUT,"forest_v9_north_return":true}
	return request

func providers() -> void:
	for region: StringName in [&"plains",&"thorn_forest"]:
		for index: int in [1,2]:
			var request := request_for(region,index)
			var before := JSON.stringify(request.capabilities)
			var direct: Dictionary
			var loaded: LevelBuildResult
			if region==&"plains":
				var generator := PlainsRegionGenerator.new()
				generator.root_bell_mode=request.root_bell_mode
				direct=generator.generate(PlainsRegionCampaign.seed_for(request.root_seed,index),request.tuning,false,"","intro" if index==1 else "advanced")
				loaded=PlainsLevelProvider.load_level(request)
			else:
				direct=ThornForestRegionGenerator.new().generate(request.root_seed+"/thorn_forest/map_%s" % index,request.tuning,index,request.capabilities)
				loaded=ForestLevelProvider.load_level(request)
			var label := "%s/%s" % [region,index]
			check(direct.ok and loaded.accepted(),label+": both original algorithm and provider accept")
			if not direct.ok or not loaded.accepted(): continue
			check(JSON.stringify(direct.manifest)==JSON.stringify(loaded.legacy_generated.manifest),label+": exact recorded Manifest bytes and ordering")
			check(loaded.plan.map_hash==direct.manifest.manifest_hash and loaded.plan.map_index==index,label+": resolved map identity")
			check(loaded.plan.actors.size()==direct.encounter_plan.enemies.size() and loaded.plan.pickups.size()==direct.manifest.pickups.size(),label+": actor and pickup declaration cardinality")
			check(JSON.stringify(request.capabilities)==before,label+": caller capability snapshot is unchanged")
			for actor_index: int in loaded.plan.actors.size():
				var recorded: Dictionary=direct.encounter_plan.enemies[actor_index]
				var actor: Dictionary=loaded.plan.actors[actor_index]
				check(actor.id==recorded.id and actor.behavior_id==StringName(recorded.behavior_id) and actor.position==Vector2(recorded.position[0],recorded.position[1]),label+": exact actor order, receipt identity and placement")
			request.expected_hash=loaded.plan.map_hash
			var replay := ForestLevelProvider.load_level(request) if region==&"thorn_forest" else PlainsLevelProvider.load_level(request)
			check(replay.accepted() and JSON.stringify(replay.legacy_generated.manifest)==JSON.stringify(direct.manifest),label+": supported hash replay does not rewrite content")
	# Historical fallback is source-owned. A changed current request may only
	# recover the exact admitted recorded hash, never silently replace the map.
	var old_request := request_for(&"plains",1)
	var old_generator := PlainsRegionGenerator.new()
	old_generator.root_bell_mode="legacy_v10"
	var old := old_generator.generate_before_focus_15(PlainsRegionCampaign.seed_for(old_request.root_seed,1),old_request.tuning,false,"","intro")
	check(old.ok,"historical plains fixture exists")
	if old.ok:
		old_request.expected_hash=old.manifest.manifest_hash
		var replay := PlainsLevelProvider.load_level(old_request)
		check(replay.accepted() and JSON.stringify(replay.legacy_generated.manifest)==JSON.stringify(old.manifest),"historical plains mode/focus resolves exact recorded bytes")
	var forest_request := request_for(&"thorn_forest",1)
	old=ThornForestRegionGenerator.new().generate_version(ThornForestRegionGenerator.LEGACY_VERSION,forest_request.root_seed+"/thorn_forest/map_1",forest_request.tuning,1,forest_request.capabilities)
	check(old.ok,"historical forest fixture exists")
	if old.ok:
		forest_request.expected_hash=old.manifest.manifest_hash
		var replay := ForestLevelProvider.load_level(forest_request)
		check(replay.accepted() and JSON.stringify(replay.legacy_generated.manifest)==JSON.stringify(old.manifest),"historical forest resolves exact recorded bytes")
		check(str(replay.resolved_capabilities.get("forest_content_version",""))==ThornForestRegionGenerator.LEGACY_VERSION,"historical forest reports its resolved content identity")
	for request: LevelRequest in [old_request,forest_request]:
		request.expected_hash="unknown-recorded-map"
		var rejected := ForestLevelProvider.load_level(request) if request.region_id==&"thorn_forest" else PlainsLevelProvider.load_level(request)
		check(not rejected.accepted() and rejected.plan==null,"unknown historical hash rejects without replacement")

func bare_plan() -> void:
	var plan := LevelPlan.new()
	plan.region_id=&"runtime_fixture"
	plan.source_id=&"hand_authored_test"
	plan.source_version="test-1"
	plan.map_hash="independent-plan-1"
	plan.bounds=Rect2(0,0,800,600)
	plan.spawn=Vector2(20,282)
	plan.anchors.append(plan.spawn)
	for index: int in 2:
		var placement := LevelModulePlacement.new()
		placement.instance_id="placement_%s" % index
		placement.template_id=&"micro_board"
		placement.definition=LevelModuleCatalog.definition_for("micro_board")
		placement.position=Vector2(index*260,0)
		plan.modules.append(placement)
	plan.actors.append({"id":"actor_1","behavior_id":&"patrol","position":Vector2(100,282),"overrides":{}})
	plan.pickups.append({"id":"pickup_1","kind":"coin","amount":2,"position":Vector2(60,282)})
	plan.caches.append({"id":"cache_1","tier":"blue","position":Vector2(160,282)})
	plan.caches.append({"id":"cache_2","tier":"blue","position":Vector2(420,282)})
	check(plan.validation_error().is_empty(),"independent plan needs no legacy Manifest")
	var host := Node2D.new()
	root.add_child(host)
	var state := PlainsRegionState.new()
	state.bind_map(plan.map_hash)
	state.clocks={"placement_0":1.25,"placement_1":4.5}
	state.claimed={"cache_1":true,"pickup_1":true}
	var built := LevelRuntime.assemble(host,plan,state)
	check(built.ok,"common runtime assembles a new-source plan")
	if built.ok:
		var assembler := built.assembler as PlainsRegionAssembler
		check(assembler.manifest.is_empty() and assembler.modules.size()==2,"runtime does not synthesize an old Manifest")
		check(assembler.world_entry()==plan.spawn and assembler.world_anchors()==plan.anchors,"runtime consumes explicit spawn and anchors")
		check(assembler.modules[0].clock==1.25 and assembler.modules[1].clock==4.5,"same-template instances restore independent stable-ID clocks")
		check(assembler.modules[0].definition!=assembler.modules[1].definition,"same-template placements own independent mutable definitions")
		var actor := LevelRuntime.create_actor(plan.actors[0])
		check(actor!=null and actor.position==Vector2(100,282),"resolved actor uses the existing factory")
		if actor!=null: actor.free()
		var caches := LevelRuntime.restore_caches(plan.caches,state.claimed)
		check(caches[0].claimed and not caches[1].claimed,"same-kind cache instances have separate claim identities")
		check(LevelRuntime.restore_pickups(plan.pickups,state.claimed)[0].claimed,"pickup claim survives source-independent materialization")
		check(not plan.caches[0].has("claimed"),"restoration does not mutate reusable content declarations")
	var duplicate := LevelModulePlacement.new()
	duplicate.instance_id=plan.modules[0].instance_id
	duplicate.template_id=&"micro_board"
	duplicate.definition=plan.modules[0].definition
	plan.modules.append(duplicate)
	var count := host.get_child_count()
	check(not LevelRuntime.assemble(host,plan,state).ok and host.get_child_count()==count,"duplicate placement rejects before installing world nodes")
	plan.modules.pop_back()
	plan.actors[0].behavior_id=&"missing_definition"
	check(not LevelRuntime.assemble(host,plan,state).ok and host.get_child_count()==count,"missing actor definition rejects before partial installation")
	host.free()

func real_entries() -> void:
	app=DemoApp.new()
	app.meta_persistence_enabled=false
	root.add_child(app)
	await frames(2)
	for region: StringName in [&"plains",&"thorn_forest"]:
		for index: int in [1,2]:
			check(app.start_debug_region(region,index,"level-boundary-live"),"real region departure accepted")
			for _attempt: int in 90:
				await physics_frame
				if is_instance_valid(app.stage) and not app._stage_pending and is_instance_valid(app.policy): break
			var stage := app.stage as PlainsRegionStage
			check(stage!=null and stage.assembly_ok,"real region is playable through the plan boundary")
			if stage==null or not stage.assembly_ok: continue
			check(stage.level_plan!=null and stage.level_plan== (stage.assembler as PlainsRegionAssembler).level_plan,"App provider, Stage and assembler consume the same resolved plan")
			check(stage.bound_player==app.controller and stage.global_player_position()==app.player.global_position,"Stage position queries use the explicit player binding")
			if stage is ThornForestRegionStage:
				check(app.controller.traversal.action_changed.is_connected((stage as ThornForestRegionStage)._accepted_forest_action),"forest accepted hook input uses the explicitly bound player")
			check(stage.level_plan.map_hash==app.region_state.manifest_hash and stage.level_plan.map_index==index,"real state ledger stays bound to the exact map")
			check(stage.enemies.size()==stage.level_plan.actors.size() and stage.chests.size()==stage.level_plan.caches.size(),"real actor and chest consumers use all planned instances")
			app.abandon_run()
			await frames(8)
	check(await AUDIO.drain_world(app),"actual App audio teardown drains")
	app.free()
	await frames(2)

func run() -> void:
	providers()
	bare_plan()
	await real_entries()
	print("LEVEL PLAN TESTS: %d assertions, %d failures" % [assertions,failures])
	quit(0 if failures==0 else 1)
