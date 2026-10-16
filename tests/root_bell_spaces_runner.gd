extends SceneTree
var failures: Array = []
var report: Dictionary = {}
var selected_phase := "all"
var output := "res://build/production_repair/ecology/spaces_audit.json"
func _initialize() -> void: run.call_deferred()
func require(ok: bool, reason: String) -> void:
	if not ok:failures.append(reason)
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		elif arg.begins_with("--phase="):selected_phase=arg.trim_prefix("--phase=")
	var rows: Array=[]
	var rules: Dictionary={}
	if selected_phase in ["all","inventory"]:
		for prefix: String in ["v3-root-bell-pilot-%s","plains-redesign-%s"]:
			for i: int in 10:
				for map_index: int in [1,2]:
					var seed_value := PlainsRegionCampaign.seed_for(prefix%i,map_index)
					var old:=PlainsRegionGenerator.new()
					old.root_bell_mode="v2"
					var previous:=old.generate(seed_value,PlayerTuning.load_default(),false,"","intro" if map_index==1 else "advanced")
					var current:=PlainsRegionGenerator.new()
					current.root_bell_mode="v3"
					var actual:=current.generate(seed_value,PlayerTuning.load_default(),false,"","intro" if map_index==1 else "advanced")
					require(previous.ok and actual.ok,"generation/"+seed_value)
					require(current.validate(actual.manifest,PlayerTuning.load_default()),"native_replay/"+seed_value)
					require(previous.manifest.nodes==actual.manifest.nodes and previous.manifest.connections==actual.manifest.connections and previous.manifest.rewards==actual.manifest.rewards and previous.manifest.enemy_drops==actual.manifest.enemy_drops,"non_ecology_content_drift/"+seed_value)
					require(previous.manifest.enemies.size()==actual.manifest.enemies.size(),"enemy_budget/"+seed_value)
					var eligible: Array=[]
					for node: Dictionary in actual.manifest.nodes:
						if node.module_id!="region_connection":continue
						var facts:=PlainsRootBellEncounterV3.inspect(actual.manifest,node,PlainsRegionGenerator.definition)
						for reason: String in facts.reasons:rules[reason]=rules.get(reason,0)+1
						if facts.reasons.is_empty():eligible.append({"node":node.id,"facts":facts})
					rows.append({"root_seed":prefix%i,"map_index":map_index,"legacy_v11_hash":previous.manifest.manifest_hash,"v12_hash":actual.manifest.manifest_hash,"admission":actual.manifest.root_bell_admission,"eligible":eligible,"enemy_count":actual.manifest.enemies.size()})
	var negatives: Array=physical_negatives() if selected_phase in ["all","inventory"] else []
	var compatibility: Array=[]
	if selected_phase in ["all","compatibility"]:
		for mode: String in ["legacy_v10","v2"]:compatibility.append(await saved_map_compatibility(mode))
	var replay: Array=[]
	if selected_phase in ["all","replay"]:
		for mode: String in ["legacy_v10","v2","v3"]:replay.append(await run_replay(mode))
	report={"phase":selected_phase,"scope":"40 actual maps; native physical rejection and real current DemoApp versioned state; not input traversal, pixels or player acceptance","rows":rows,"rejection_counts":rules,"physical_negatives":negatives,"saved_map_compatibility":compatibility,"run_manifest_replay":replay,"failures":failures,"production_admitted":PlainsRootBellEncounterV3.PRODUCTION_ADMITTED}
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")+"\n");file.close()
	print("ROOT BELL SPACES: maps=%s negatives=%s failures=%s"%[rows.size(),negatives.size(),failures.size()])
	finish.call_deferred()

func finish() -> void:
	quit(0 if failures.is_empty() else 1)

func physical_negatives() -> Array:
	var g:=PlainsRegionGenerator.new();g.root_bell_mode="v3"
	var original: Dictionary=g.generate("plains-redesign-8/plains/map_2",PlayerTuning.load_default(),false,"","advanced").manifest
	var refused: Array=[]
	for mutation: String in ["width559","width561","wrong_recipe","one_way","non_bidirectional","own_ceiling","adjacent_danger","camp_endpoint","hazard_on_bank","removed_guard"]:
		var m: Dictionary=original.duplicate(true)
		var node: Dictionary=m.nodes.filter(func(n: Dictionary)->bool:return n.id==m.root_bell_admission.module)[0]
		var edge: Dictionary=m.connections.filter(func(e: Dictionary)->bool:return e.id==m.root_bell_admission.physical_facts.edge)[0]
		if mutation=="width559":node.geometry.platforms[0][2]=559
		elif mutation=="width561":node.geometry.platforms[0][2]=561
		elif mutation=="wrong_recipe":edge.recipe="ferry_dock"
		elif mutation=="one_way":node.geometry.one_way=[0]
		elif mutation=="non_bidirectional":edge.bidirectional=false
		elif mutation=="own_ceiling":node.geometry.platforms.append([100,-70,420,32])
		elif mutation=="camp_endpoint":m.merchant_id=edge.a
		elif mutation=="hazard_on_bank":node.geometry.spikes=[[10,10,100,20]]
		elif mutation=="adjacent_danger":
			for n: Dictionary in m.nodes:
				if n.module_id=="plains_recovery_bridge":n.offset=[3360,518];break
		elif mutation=="removed_guard":m.enemies=m.enemies.filter(func(e: Dictionary)->bool:return e.get("area","")!=node.id)
		var facts:=PlainsRootBellEncounterV3.inspect(m,node,PlainsRegionGenerator.definition)
		var result:=PlainsRootBellEncounterV3.apply(m,PlainsRegionGenerator.definition)
		var bad: bool=not facts.reasons.is_empty() if mutation!="removed_guard" else result.replaced==0
		require(bad,"physical_false_accept/"+mutation)
		refused.append({"mutation":mutation,"refused":bad,"reasons":facts.reasons})
	return refused

func ready_map(app: DemoApp,index: int) -> bool:
	for unused: int in 180:
		await physics_frame;await process_frame
		var actual_stage := app.stage as PlainsRegionStage
		if not app._stage_pending and actual_stage != null and actual_stage.map_index==index:return actual_stage.assembly_ok
	return false
func second_map(app: DemoApp) -> void:
	app.lifetime.stage_epoch+=1;app.lifetime.actor_epoch+=1
	app.director._enter_stage(2,&"boss");app._stage_entered(DemoRunResult.new())
func cleanup(app: DemoApp) -> void:
	for child: Node in app.get_children():
		if child is GameAudio:require(await child.shutdown(),"audio_backend_not_released")
	app.abandon_run();await process_frame;await process_frame
	app.queue_free();await process_frame;await process_frame
func application(mode: String) -> DemoApp:
	var app:=DemoApp.new();app.meta_persistence_enabled=false
	root.add_child(app)
	app.start_plains("v3-root-bell-pilot-1")
	app._root_bell_run_mode=mode # Explicit loader version fixture before deferred load.
	return app
func saved_map_compatibility(mode: String) -> Dictionary:
	var old:=application(mode)
	var ok:=await ready_map(old,1)
	second_map(old);ok=await ready_map(old,2) and ok
	(old.stage as PlainsRegionStage).capture_state()
	var snapshot:=old.region_state.snapshot()
	var old_version: String=old.stage.generated.manifest.version
	await cleanup(old)
	var restored:=PlainsRegionState.new()
	ok=restored.restore(snapshot,snapshot.manifest_hash) and ok
	var current:=application("v3")
	ok=await ready_map(current,1) and ok
	current.region_states[2]=restored
	second_map(current);ok=await ready_map(current,2) and ok
	var actual_version: String=current.stage.generated.manifest.version
	ok=ok and old_version==actual_version and snapshot.manifest_hash==current.stage.generated.manifest.manifest_hash and current.region_state.actors.size()==snapshot.actors.size()
	var result: Dictionary={"mode":mode,"passed":ok,"old_version":old_version,"actual_version":actual_version,"old_hash":snapshot.manifest_hash,"actual_hash":current.stage.generated.manifest.manifest_hash,"old_actors":snapshot.actors.size(),"actual_actors":current.region_state.actors.size(),"scope":"current loader pinned historical state, not old binary or full run migration"}
	require(ok,"saved_map_compatibility/"+mode)
	await cleanup(current)
	return result
func run_replay(mode: String) -> Dictionary:
	var app:=application(mode)
	var ok:=await ready_map(app,1)
	var first:=app.director.manifest.snapshot()
	ok=ok and RunManifest.from_snapshot(first)!=null
	var transitioned: bool=await load("res://tests/plains_campaign_fixture.gd").second_map(app,self)
	ok=ok and transitioned
	var native:=app.director.manifest.snapshot()
	var encoded: Dictionary=JSON.parse_string(app.director.manifest.canonical_json())
	var roundtrip:=RunManifest.from_snapshot(encoded)
	ok=ok and roundtrip!=null
	if roundtrip!=null:ok=ok and roundtrip.canonical_json()==JSON.stringify(encoded,"",true)
	var bad: Dictionary=encoded.duplicate(true)
	bad.versions.encounters="plains-region-v999"
	var refused:=RunManifest.from_snapshot(bad)==null
	ok=ok and refused
	require(ok,"run_manifest/"+mode)
	var result: Dictionary={"mode":mode,"passed":ok,"version":native.versions.generated_layout,"wrong_version_refused":refused,"scope":"actual two-map RunManifest; explicit existing miniBoss outcome fixture, not combat proof"}
	await cleanup(app)
	return result
