extends RefCounted
func audit() -> Dictionary:
	var rows: Array = []
	var failures: Array = []
	var original_rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://docs/evidence/region_production_v3/enemy_encounter_v2/legacy_manifest_strings.json")).rows
	var historical_path := "res://tests/fixtures/root_bell/pre_focus_15_player_tuning.json"
	if FileAccess.get_sha256(historical_path)!=PlainsRegionGenerator.PRE_FOCUS_15_TUNING_HASH:
		return {"rows":[],"failures":["historical_tuning_fixture_identity"],"scope":"Historical fixture rejected before replay"}
	var historical_values: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(historical_path))
	var historical_tuning := PlayerTuning.load_default()
	for key: String in historical_values:
		if key=="physics_hz":continue # Project clock, not a PlayerTuning field.
		if key=="jump_speeds":historical_tuning.jump_speeds.assign(historical_values[key])
		else:historical_tuning.set(key,historical_values[key])
	for key: String in historical_values:
		if key!="physics_hz" and not RandomStageGenerator.new()._same_data(historical_tuning.get(key),historical_values[key]):failures.append("historical_tuning_value/"+key)
	if historical_tuning.focus_time_scale!=0.2 or not historical_tuning.valid_focus_configuration():failures.append("historical_focus_profile")
	for i: int in 20:
		for map_index: int in [1,2]:
			var root := "v3-root-bell-pilot-%s" % i
			var seed := PlainsRegionCampaign.seed_for(root,map_index)
			var difficulty := "intro" if map_index==1 else "advanced"
			var legacy := PlainsRegionGenerator.new()
			var original := legacy.generate(seed,PlayerTuning.load_default(),false,"",difficulty)
			# This immutable corpus predates the authorized .2 -> .15 focus change.
			# Keep its entire original assertion against an explicit historical replay;
			# current default generation and validation remain separate below.
			var historical := legacy.generate_before_focus_15(seed,historical_tuning,false,"",difficulty)
			var historical_row: Dictionary = original_rows[i*2+map_index-1]
			var old_equal: bool = historical.ok and historical_row.root_seed==root and historical_row.map_index==map_index and historical_row.raw_manifest==JSON.stringify(historical.manifest)
			if not old_equal:failures.append("legacy_default_byte_mismatch/%s/%s"%[i,map_index])
			var v2 := PlainsRegionGenerator.new()
			v2.root_bell_mode = "v2"
			var candidate := v2.generate(seed,PlayerTuning.load_default(),false,"",difficulty)
			if not original.ok or not candidate.ok or not historical.ok:
				failures.append("generation_failed/%s/%s"%[i,map_index])
				continue
			var result: Dictionary = candidate.manifest.root_bell_admission
			var current_hash := FileAccess.get_sha256("res://config/player_tuning.json")
			var current_validated := legacy.validate(original.manifest,PlayerTuning.load_default())
			var historical_validated := legacy.validate(historical.manifest,historical_tuning)
			var current_focus := PlayerTuning.load_default().focus_time_scale
			var actual_profiles: bool = original.manifest.player_tuning_hash==current_hash and candidate.manifest.player_tuning_hash==current_hash and historical.manifest.player_tuning_hash==PlainsRegionGenerator.PRE_FOCUS_15_TUNING_HASH and current_hash!=historical.manifest.player_tuning_hash and current_focus==0.15
			if not actual_profiles or not historical_validated:failures.append("current_and_historical_tuning_identity/%s/%s"%[i,map_index])
			rows.append({"root_seed":root,"map_index":map_index,"actual_seed":seed,"legacy_hash":original.manifest.manifest_hash,"legacy_default_byte_equal":old_equal,"legacy_default_byte_equal_scope":"immutable historical v10 replay; not current default bytes","historical_hash":historical.manifest.manifest_hash,"historical_tuning_hash":historical.manifest.player_tuning_hash,"historical_validated":historical_validated,"current_tuning_hash":original.manifest.player_tuning_hash,"current_tuning_focus_scale":current_focus,"current_default_validated":current_validated,"current_and_historical_profiles_distinct":actual_profiles,"content_version":candidate.manifest.version,"candidate":result,"default_gate":PlainsRootBellEncounterV2.PRODUCTION_ADMITTED})
			if original.manifest.enemies.size()!=candidate.manifest.enemies.size(): failures.append("enemy_budget")
			if not current_validated or not v2.validate(candidate.manifest,PlayerTuning.load_default()):failures.append("version_replay")
	return {"rows":rows,"failures":failures,"historical_tuning_sha256":FileAccess.get_sha256(historical_path),"historical_tuning_values":historical_values,"historical_focus_time_scale":historical_tuning.focus_time_scale,"scope":"40 currentcampaign manifests plus exact immutable historical corpus replay with original .2 tuning; legacy_default_byte_equal describes historical replay only; eligibility, not traversal"}

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
		var actual_stage := app.stage as PlainsRegionStage
		if not app._stage_pending and actual_stage != null and actual_stage.map_index==index:return actual_stage.assembly_ok and _fixture_identity_matches(app, index, str(app.director.get("seed")))
	return false

func map2(app: DemoApp) -> void:
	app.lifetime.stage_epoch+=1
	app.lifetime.actor_epoch+=1
	_sync_fixture_map_index(app, 2)
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
	# Construct a real historical-version state through the existing loader.
	# This is an explicit version pin, not execution of a frozen old binary.
	old._root_bell_run_mode="legacy_v10"
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
	var actual_map_identity := {"map_index":current.stage.map_index,"seed":current.stage.generated.manifest.seed,"difficulty":current.stage.generated.manifest.difficulty}
	var actual_actors: int = current.region_state.actors.size()
	ok=ok and actual_actors==snapshot.actors.size()
	current.abandon_run()
	await tree.process_frame
	await tree.process_frame
	current.queue_free()
	await tree.process_frame
	await tree.process_frame
	return {"passed":ok,"actual_map_identity":actual_map_identity,"old_hash":old_hash,"actual_new_loader_hash":new_hash,"old_version":old_version,"actual_version":actual_version,"old_actor_count":snapshot.actors.size(),"actual_actor_count":actual_actors,"actual_root_count":actual_root,"scope":"Current real DemoApp explicitly pinned to historical legacy_v10 before map2 capture_state → detached restore → new loader hash-bound legacy replay; not a frozen old binary; no save/RNG schema rewrite"}

func run_manifest_replay(tree: SceneTree) -> Dictionary:
	# Replay contract fixture: real DemoApp generation/recording and the existing
	# explicit mini-Boss outcome fixture. No traversal/combat/device claim.
	var failures: Array = []
	var cases: Array = []
	var negatives: Array = []
	var snapshots: Dictionary = {}
	for mode: String in ["v2", "legacy_v10"]:
		var app := DemoApp.new()
		app.root_bell_pilot_requested = mode == "v2" # Keep this historical fixture explicitly on v11.
		app.meta_persistence_enabled = false
		tree.root.add_child(app)
		for child: Node in app.get_children():
			if child is GameAudio: child.volume = 0
		var started := app.start_plains("v3-root-bell-pilot-1")
		# _load_stage is deferred; pin the explicit legacy fixture before it runs.
		if mode == "legacy_v10": app._root_bell_run_mode = "legacy_v10"
		var ready := started and await wait_map(tree, app, 1)
		if not ready:
			failures.append(mode + "/first_map_not_ready")
		else:
			var first_native := app.director.manifest.snapshot()
			var first_json: Dictionary = JSON.parse_string(app.director.manifest.canonical_json())
			var first_native_replay := RunManifest.from_snapshot(first_native)
			var first_json_replay := RunManifest.from_snapshot(first_json)
			var first_ok := first_native_replay != null and first_json_replay != null
			if first_ok: first_ok = first_native_replay.canonical_json() == app.director.manifest.canonical_json() and first_json_replay.canonical_json() == JSON.stringify(first_json, "", true)
			cases.append({"mode": mode, "case": "first_map_native_json_exact", "passed": first_ok, "version": first_native.versions.generated_layout})
			if not first_ok: failures.append(mode + "/first_map_roundtrip")
			# Explicit lawful Definition fixture; this is not a reward acquisition proof.
			var item_added := app.build.add_item(&"run_manifest_replay_fixture", load("res://resources/items/brake_boots.tres"))
			var transitioned: bool = item_added and await load("res://tests/plains_campaign_fixture.gd").second_map(app, tree)
			if not transitioned:
				failures.append(mode + "/second_map_not_ready")
			else:
				var native := app.director.manifest.snapshot()
				var json_data: Dictionary = JSON.parse_string(app.director.manifest.canonical_json())
				var native_replay := RunManifest.from_snapshot(native)
				var json_replay := RunManifest.from_snapshot(json_data)
				var typed_items: Array = native.stages[1].outputs.capability_snapshot.items
				var has_string_name := typed_items.has(&"brake_boots") and typed_items.any(func(id: Variant) -> bool: return id is StringName)
				var roundtrip_ok := native_replay != null and json_replay != null and has_string_name
				if roundtrip_ok: roundtrip_ok = native_replay.canonical_json() == app.director.manifest.canonical_json() and json_replay.canonical_json() == JSON.stringify(json_data, "", true)
				var expected := PlainsRootBellEncounterV2.CONTENT_VERSION if mode == "v2" else PlainsRegionGenerator.VERSION
				var all_versions_match := str(native.versions.generated_layout) == expected and str(native.versions.encounters) == expected
				var regeneration_ok := true
				for entry: Dictionary in native.stages:
					var output: Dictionary = entry.outputs
					all_versions_match = all_versions_match and output.stage_generator.version == expected and output.enemy_layout.version == expected and output.generated_layout.version == expected
					var generator := PlainsRegionGenerator.new()
					generator.root_bell_mode = mode
					var regenerated := generator.generate(output.generated_layout.seed, RunManifest._region_tuning(output), false, "", output.generated_layout.difficulty)
					regeneration_ok = regeneration_ok and regenerated.ok and JSON.stringify(regenerated.manifest) == JSON.stringify(output.generated_layout)
				var root_count: int = native.stages[1].outputs.generated_layout.enemies.filter(func(e: Dictionary) -> bool: return e.behavior_id == "root_bell").size()
				var passed := roundtrip_ok and all_versions_match and regeneration_ok and root_count == (1 if mode == "v2" else 0)
				cases.append({"mode": mode, "case": "two_maps_native_json_modifier_and_exact_regeneration", "passed": passed, "native_StringName_item": has_string_name, "root_bell_count": root_count, "versions_match": all_versions_match, "regenerated_exact_manifest_strings": regeneration_ok})
				if not passed: failures.append(mode + "/two_map_replay")
				snapshots[mode] = json_data
		app.abandon_run()
		await tree.process_frame
		await tree.process_frame
		app.queue_free()
		await tree.process_frame
		await tree.process_frame
	if snapshots.has("v2"):
		for mutation: String in ["unknown_root_version", "mixed_root_versions", "mixed_stage_generator", "mixed_manifest_version", "mixed_enemy_version", "rehashed_enemy_position", "rehashed_root_bell_behavior", "unearned_resource_tuning"]:
			var data: Dictionary = snapshots.v2.duplicate(true)
			var output: Dictionary = data.stages[1].outputs
			if mutation == "unknown_root_version":
				data.versions.generated_layout = "plains-region-v999"
				data.versions.encounters = "plains-region-v999"
			elif mutation == "mixed_root_versions": data.versions.encounters = PlainsRegionGenerator.VERSION
			elif mutation == "mixed_stage_generator": output.stage_generator.version = PlainsRegionGenerator.VERSION
			elif mutation == "mixed_manifest_version":
				output.generated_layout.version = PlainsRegionGenerator.VERSION
				output.generated_layout.manifest_hash = PlainsRegionGenerator.new()._hash(output.generated_layout)
			elif mutation == "mixed_enemy_version": output.enemy_layout.version = PlainsRegionGenerator.VERSION
			elif mutation == "unearned_resource_tuning": output.stage_tuning.max_air_shots += 1
			else:
				if mutation == "rehashed_enemy_position": output.generated_layout.enemies[0].position[0] += 1
				else:
					for enemy: Dictionary in output.generated_layout.enemies:
						if enemy.behavior_id == "root_bell": enemy.behavior_id = "patrol"; break
				output.generated_layout.manifest_hash = PlainsRegionGenerator.new()._hash(output.generated_layout)
				output.enemy_layout.enemies = output.generated_layout.enemies.duplicate(true)
			var refused := RunManifest.from_snapshot(data) == null
			negatives.append({"mutation": mutation, "refused": refused})
			if not refused: failures.append("false_accept/" + mutation)
	var rejected_api := RunManifest.new("explicit-version-api", RunProfile.formal())
	var untouched := rejected_api.canonical_json()
	var unknown_refused := not rejected_api.enable_plains_region("plains-region-v999") and rejected_api.canonical_json() == untouched
	negatives.append({"mutation": "unknown_enable_version_is_atomic", "refused": unknown_refused})
	if not unknown_refused: failures.append("unknown_enable_version")
	var legacy_api := RunManifest.new("legacy-default-api", RunProfile.formal())
	var legacy_default: bool = legacy_api.enable_plains_region() and legacy_api.snapshot().versions.generated_layout == PlainsRegionGenerator.VERSION
	cases.append({"case": "default_enable_api_keeps_v10", "passed": legacy_default})
	if not legacy_default: failures.append("legacy_default_enable_version")
	return {"passed": failures.is_empty(), "failures": failures, "cases": cases, "negatives": negatives, "actual_snapshots": snapshots, "scope": "Real current DemoApp two-map versioned RunManifest snapshots/reconstruction; explicit lawful item and mini-Boss outcome fixtures, not input-only traversal/combat, save schema or device acceptance"}


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
