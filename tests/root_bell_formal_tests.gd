extends RefCounted
func audit() -> Dictionary:
	var rows: Array = []
	var failures: Array = []
	var original_rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://docs/evidence/region_production_v3/enemy_encounter_v2/legacy_manifest_strings.json")).rows
	for i: int in 20:
		for map_index: int in [1,2]:
			var root := "v3-root-bell-pilot-%s" % i
			var seed := PlainsRegionCampaign.seed_for(root,map_index)
			var difficulty := "intro" if map_index==1 else "advanced"
			var legacy := PlainsRegionGenerator.new()
			var original := legacy.generate(seed,PlayerTuning.load_default(),false,"",difficulty)
			var historical_row: Dictionary = original_rows[i*2+map_index-1]
			var old_equal: bool = historical_row.root_seed==root and historical_row.map_index==map_index and historical_row.raw_manifest==JSON.stringify(original.manifest)
			if not old_equal:failures.append("legacy_default_byte_mismatch/%s/%s"%[i,map_index])
			var v2 := PlainsRegionGenerator.new()
			v2.root_bell_mode = "v2"
			var candidate := v2.generate(seed,PlayerTuning.load_default(),false,"",difficulty)
			if not original.ok or not candidate.ok:
				failures.append("generation_failed/%s/%s"%[i,map_index])
				continue
			var result: Dictionary = candidate.manifest.root_bell_admission
			rows.append({"root_seed":root,"map_index":map_index,"actual_seed":seed,"legacy_hash":original.manifest.manifest_hash,"legacy_default_byte_equal":old_equal,"content_version":candidate.manifest.version,"candidate":result,"default_gate":PlainsRootBellEncounterV2.PRODUCTION_ADMITTED})
			if original.manifest.enemies.size()!=candidate.manifest.enemies.size(): failures.append("enemy_budget")
			if not legacy.validate(original.manifest,PlayerTuning.load_default()) or not v2.validate(candidate.manifest,PlayerTuning.load_default()):failures.append("version_replay")
	return {"rows":rows,"failures":failures,"scope":"40 actual currentcampaign manifests; eligibility only, actual traversal separate"}

func physical_negatives() -> Dictionary:
	var generated := PlainsRegionGenerator.new().generate("v3-root-bell-pilot-1/plains/map_2",PlayerTuning.load_default(),false,"","advanced")
	var manifest: Dictionary = generated.manifest
	var node_id := "plains/passage/area_3_2/area_4_2_join"
	var refused: Array = []
	var failures: Array = []
	for mutation: String in ["width400","width440","one_way","ferry_recipe","thorn_recipe","low_arch_recipe","non_bidirectional","own_low_ceiling","adjacent_gear_sweep","camp_endpoint"]:
		var m: Dictionary = manifest.duplicate(true)
		var node: Dictionary = {}
		var edge: Dictionary = {}
		for n: Dictionary in m.nodes:
			if n.id==node_id:node=n
		for e: Dictionary in m.connections:
			if node_id==str(e.id)+"_join":edge=e
		if mutation=="width400":node.geometry.platforms[0][2]=400
		elif mutation=="width440":node.geometry.platforms[0][2]=440
		elif mutation=="one_way":node.geometry.one_way=[0]
		elif mutation=="ferry_recipe":edge.recipe="ferry_dock"
		elif mutation=="thorn_recipe":edge.recipe="thorn_cells"
		elif mutation=="low_arch_recipe":edge.recipe="low_arch"
		elif mutation=="non_bidirectional":edge.bidirectional=false
		elif mutation=="own_low_ceiling":node.geometry.platforms.append([100,-70,420,32])
		elif mutation=="camp_endpoint":m.merchant_id=edge.a
		elif mutation=="adjacent_gear_sweep":
			for n: Dictionary in m.nodes:
				if n.module_id=="plains_twin_gears":n.offset=[5050,228];break
		var result := PlainsRootBellEncounterV2.inspect(m,node,PlainsRegionGenerator.definition)
		if result.reasons.is_empty():failures.append(mutation)
		else:refused.append({"mutation":mutation,"reasons":result.reasons})
	return {"refused":refused,"failures":failures,"scope":"Actual620 candidate counterfactual physical admission, no gameplay mutation"}

func wait_map(tree: SceneTree,app: DemoApp,index: int) -> bool:
	for unused: int in 180:
		await tree.physics_frame
		await tree.process_frame
		if not app._stage_pending and app.stage is PlainsRegionStage and app.stage.map_index==index:return app.stage.assembly_ok
	return false

func map2(app: DemoApp) -> void:
	app.lifetime.stage_epoch+=1
	app.lifetime.actor_epoch+=1
	app.director._enter_stage(2,&"boss")
	app._stage_entered(DemoRunResult.new())

func compatibility(tree: SceneTree) -> Dictionary:
	var old := DemoApp.new()
	old.meta_persistence_enabled=false
	tree.root.add_child(old)
	for child: Node in old.get_children():
		if child is GameAudio:child.volume=0 # Save compatibility only; no audio claim.
	var ok := old.start_plains("v3-root-bell-pilot-1")
	ok=ok and await wait_map(tree,old,1)
	map2(old)
	ok=ok and await wait_map(tree,old,2)
	(old.stage as PlainsRegionStage).capture_state()
	var snapshot := old.region_state.snapshot()
	var old_hash: String = snapshot.manifest_hash
	var old_version: String = old.stage.generated.manifest.version
	old.abandon_run()
	await tree.process_frame
	await tree.process_frame
	old.queue_free()
	await tree.process_frame
	await tree.process_frame
	var restored := PlainsRegionState.new()
	ok=ok and restored.restore(snapshot,old_hash)
	var current := DemoApp.new()
	current.meta_persistence_enabled=false
	current.root_bell_pilot_requested=true
	tree.root.add_child(current)
	for child: Node in current.get_children():
		if child is GameAudio:child.volume=0
	ok=ok and current.start_plains("v3-root-bell-pilot-1")
	ok=ok and await wait_map(tree,current,1)
	current.region_states[2]=restored
	map2(current)
	ok=ok and await wait_map(tree,current,2)
	var new_hash: String = current.stage.generated.manifest.manifest_hash
	var actual_version: String = current.stage.generated.manifest.version
	var actual_root: int = current.stage.enemy_manifest.filter(func(e: Dictionary)->bool:return e.behavior_id=="root_bell").size()
	ok=ok and old_hash==new_hash and old_version==actual_version and actual_version=="plains-region-v10" and actual_root==0
	var actual_actors: int = current.region_state.actors.size()
	ok=ok and actual_actors==snapshot.actors.size()
	current.abandon_run()
	await tree.process_frame
	await tree.process_frame
	current.queue_free()
	await tree.process_frame
	await tree.process_frame
	return {"passed":ok,"old_hash":old_hash,"actual_new_loader_hash":new_hash,"old_version":old_version,"actual_version":actual_version,"old_actor_count":snapshot.actors.size(),"actual_actor_count":actual_actors,"actual_root_count":actual_root,"scope":"Actual old DemoApp map2 capture_state → detached restore → newv2-pilot DemoApp loader deterministic legacy replay; no save/RNG schema rewrite"}
