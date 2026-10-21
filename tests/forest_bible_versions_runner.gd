extends SceneTree
## Additional v15 compatibility only. Original327/schema6/24 remain separate.
const STRATEGY := preload("res://tests/forest_depth_trace_strategy.gd")
const PUBLIC_EXPECTATION := preload("res://tests/forest_depth_version_runner.gd")
const BIBLE := "forest-bible-world-v15"
const OLD_LAYOUTS := ["forest-interwoven-canopy-v13","forest-fruit-routes-v14"]
const AUDIO := preload("res://tests/audio_teardown.gd")
var checks: Array[Dictionary]=[]
var cases: Array[Dictionary]=[]
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks.append({"label":label,"passed":ok})
	if not ok:failures+=1;printerr("FOREST BIBLE VERSION FAIL: "+label)
func frames(count: int) -> void:
	for unused: int in count:await physics_frame;await process_frame
func run() -> void:
	var registry := ThornForestRegionGenerator.new()
	var tuning := PlayerTuning.load_default()
	var equality := RandomStageGenerator.new()
	var caps := {"grapple":true,"abilities":["grapple"]}
	for map_index: int in [1,2]:
		var seed_value := "bible-version-map-%s" % map_index
		var explicit := registry.generate_version(ThornForestRegionGenerator.DEPTH_VERSION,seed_value,tuning,map_index,caps.merged({"forest_layout_version":BIBLE}))
		var dedicated := ThornForestRegionV2V15.new().generate(seed_value,tuning,map_index,caps)
		check(explicit.get("ok",false) and dedicated.get("ok",false),"candidate registered and dedicated map%s" % map_index)
		if not explicit.get("ok",false) or not dedicated.get("ok",false):continue
		var m: Dictionary=explicit.manifest
		check(equality._same_data(explicit,dedicated) and registry.validate(m,tuning),"whole candidate equals strict dedicated output map%s" % map_index)
		check(m.layout_version==BIBLE and not m.production_pool and m.requires==["grapple"] and m.bible_world_contract.native_verified==false,"candidate remains explicitly pending H-only map%s" % map_index)
		var negatives: Array[Dictionary]=[]
		for mutation: String in ["fruit","discovery","shortcut","drop","admission"]:
			var edited: Dictionary=m.duplicate(true)
			match mutation:
				"fruit":edited.hook_anchors[-1].position[0]+=1.0
				"discovery":edited.forest_discoveries.pop_back()
				"shortcut":edited.forest_shortcuts[0].unlock_reward_id="foreign"
				"drop":edited.enemy_drops.erase("bible_double_window_weaver")
				"admission":edited.bible_world_contract.native_verified=true
			edited.manifest_hash=ThornForestRegionGenerator._hash(edited)
			var rejected := not registry.validate(edited,tuning)
			check(rejected,"coherently rehashed candidate mutation rejected %s/map%s" % [mutation,map_index])
			negatives.append({"kind":mutation,"rejected":rejected})
		cases.append({"id":"candidate_data","map":map_index,"manifest":m,"dedicated_complete_equal":equality._same_data(explicit,dedicated),"negative_cases":negatives})
		await public_app_case(map_index)
		for layout: String in OLD_LAYOUTS:await recorded_app_case(map_index,layout)
	for layout: String in ["",OLD_LAYOUTS[0],OLD_LAYOUTS[1],BIBLE]:
		var trace: Node=STRATEGY.create(layout)
		var effective: String=layout if not layout.is_empty() else PUBLIC_EXPECTATION.EXPECTED_PUBLIC_LAYOUT
		var expected_path := "res://tests/forest_bible_region_auto_trace.gd" if effective==BIBLE else "res://tests/forest_depth_region_trace.gd"
		check(trace.get_script().resource_path==expected_path and trace.recorded_layout_version==layout,"strategy retains original explicit-or-empty App argument: "+layout)
		trace.free()
	registry=null;tuning=null;equality=null
	finish.call_deferred()
func public_app_case(map_index: int) -> void:
	var app := DemoApp.new();app.meta_persistence_enabled=false;root.add_child(app)
	check(app.start_debug_region(&"thorn_forest",map_index,"bible-version-public",ThornForestRegionGenerator.DEPTH_VERSION),"actual public App starts without layout pin map%s" % map_index)
	await frames(8)
	var stage := app.stage as ThornForestRegionStage
	check(stage!=null and stage.assembly_ok,"actual public App assembled map%s" % map_index)
	if stage==null or not stage.assembly_ok:await dispose(app);return
	var actual: Dictionary=stage.generated.manifest
	var expected := ThornForestRegionGenerator.new().generate_version(ThornForestRegionGenerator.DEPTH_VERSION,str(actual.seed),app.player.tuning,map_index,{"grapple":true,"abilities":["grapple"],"forest_layout_version":PUBLIC_EXPECTATION.EXPECTED_PUBLIC_LAYOUT})
	var equal: bool=expected.get("ok",false) and RandomStageGenerator.new()._same_data(actual,expected.manifest)
	check(actual.layout_version==PUBLIC_EXPECTATION.EXPECTED_PUBLIC_LAYOUT and equal,"independently selected full public App output map%s" % map_index)
	cases.append({"id":"public_app","map":map_index,"layout_argument":"","expected_layout":PUBLIC_EXPECTATION.EXPECTED_PUBLIC_LAYOUT,"manifest":actual.duplicate(true),"complete_manifest_equal":equal})
	await dispose(app)
func recorded_app_case(map_index: int,layout: String) -> void:
	var app := DemoApp.new();app.meta_persistence_enabled=false;root.add_child(app)
	check(app.start_debug_region(&"thorn_forest",map_index,"bible-version-recorded",ThornForestRegionGenerator.DEPTH_VERSION,layout),"actual recorded App starts %s/map%s" % [layout,map_index])
	await frames(8)
	var stage := app.stage as ThornForestRegionStage
	check(stage!=null and stage.assembly_ok,"actual recorded stage assembled %s/map%s" % [layout,map_index])
	if stage==null or not stage.assembly_ok:await dispose(app);return
	var state := app.region_state
	var original: Dictionary=stage.generated.manifest.duplicate(true)
	state.claimed["version_only_claim_fixture"]=true
	state.opened["version_only_open_fixture"]=true
	state.mechanisms["version_only_mechanism_fixture"]={"open":true}
	var actor := stage.enemies[0].get_node("Actor") as EnemyActor
	var actor_id := actor.get_instance_id()
	var nondefault_hp: float=actor.health.current-1.0
	check(nondefault_hp>0 and actor.restore_instance_health(nondefault_hp),"prepare saved actor-health fixture, not earned combat %s/map%s" % [layout,map_index])
	stage.capture_state()
	var before := {"claimed":state.claimed.duplicate(true),"opened":state.opened.duplicate(true),"mechanisms":state.mechanisms.duplicate(true),"actors":state.actors.duplicate(true)}
	# Force a different new candidate request; saved full hash must choose the
	# old registered producer instead of clearing its actual world state.
	app._forest_layout_version=BIBLE
	await app._load_stage()
	var restored := app.stage as ThornForestRegionStage
	check(restored!=null and restored.assembly_ok,"hash-bound old stage rebuild %s/map%s" % [layout,map_index])
	if restored==null or not restored.assembly_ok:await dispose(app);return
	var same_manifest: bool=RandomStageGenerator.new()._same_data(original,restored.generated.manifest)
	var ledgers := {"claimed":state.claimed.duplicate(true),"opened":state.opened.duplicate(true),"mechanisms":state.mechanisms.duplicate(true),"actors":state.actors.duplicate(true)}
	var loaded_actor := restored.enemies[0].get_node("Actor") as EnemyActor
	check(app.region_state==state and same_manifest and state.manifest_hash==str(original.manifest_hash) and app._forest_layout_version==layout,"recorded hash recovers exact old layout %s/map%s" % [layout,map_index])
	check(before==ledgers and loaded_actor.get_instance_id()!=actor_id and loaded_actor.health.current==nondefault_hp,"old claims mechanisms and nondefault actor survive rebuild %s/map%s" % [layout,map_index])
	cases.append({"id":"recorded_app","map":map_index,"layout":layout,"original_manifest":original,"restored_manifest":restored.generated.manifest.duplicate(true),"forced_request":BIBLE,"recorded_layout_after":app._forest_layout_version,"same_state":app.region_state==state,"before":before,"after":ledgers,"old_actor_id":actor_id,"new_actor_id":loaded_actor.get_instance_id(),"saved_health":nondefault_hp,"restored_health":loaded_actor.health.current})
	await dispose(app)
func dispose(app: DemoApp) -> void:
	app.abandon_run();await frames(4)
	check(await AUDIO.drain_world(app),"actual owned App audio drains")
	app.free();await frames(2)
func finish() -> void:
	var output := "res://build/region_bible_v2/versions/capture.json"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version":1,"scope":"Additional Bible compatibility; original327/schema6/24 remain separate; no route or release admission","engine":Engine.get_version_info().string,"assertions":checks.size(),"failures":failures,"checks":checks,"cases":cases}));file.close()
	print("FOREST BIBLE VERSIONS: %s assertions, %s failures" % [checks.size(),failures])
	quit(1 if failures else 0)
