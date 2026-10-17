extends SceneTree
## Runtime version contracts only; not v2 route or Boss admission.
const LEGACY := preload("res://scripts/generation/thorn_forest_region_v1.gd")
const AUDIO := preload("res://tests/audio_teardown.gd")
var assertions := 0
var failures := 0
var cases: Array[Dictionary] = []
var checks: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	assertions += 1
	checks.append({"label":label,"passed":ok})
	if not ok:
		failures += 1
		printerr("FOREST VERSION FAIL: "+label)
func frames(count: int) -> void:
	for index: int in count:
		await physics_frame
		await process_frame
func run() -> void:
	var registry := ThornForestRegionGenerator.new()
	var old := LEGACY.new()
	var equality := RandomStageGenerator.new()
	var tuning := PlayerTuning.load_default()
	check(ThornForestRegionGenerator.VERSION == LEGACY.VERSION,"unpromoted default remains actual v1")
	for root_seed: String in ["version-contract-00","version-contract-01","version-contract-02","version-contract-03"]:
		for map_index: int in [1,2]:
			var seed_value := LEGACY.seed_for(root_seed,map_index)
			var capabilities := {"grapple":true,"abilities":["grapple"]}
			var direct: Dictionary = old.generate(seed_value,tuning,map_index,capabilities)
			var delegated: Dictionary = registry.generate(seed_value,tuning,map_index,capabilities)
			var pinned: Dictionary = registry.generate_version(LEGACY.VERSION,seed_value,tuning,map_index,capabilities)
			check(direct.ok and delegated.ok and pinned.ok,"v1 generation succeeds "+seed_value)
			check(equality._same_data(direct,delegated) and equality._same_data(direct,pinned),"complete generated outputs exactly equal "+seed_value)
			check(registry.validate(direct.manifest,tuning) and old.validate(delegated.manifest,tuning),"both validators accept complete legacy output "+seed_value)
			var broken: Dictionary = direct.manifest.duplicate(true)
			broken.version = "unsupported-forest-version"
			check(not registry.validate(broken,tuning) and not old.validate(broken,tuning),"both validators refuse edited legacy version "+seed_value)
			cases.append({"id":"delegate","seed":seed_value,"map":map_index,"equal_complete_output":equality._same_data(direct,delegated) and equality._same_data(direct,pinned),"manifest":direct.manifest,"stage_generator_version":delegated.stage_generator_version,"enemy_version":delegated.encounter_plan.version})
	for unsupported: String in ["unknown", "thorn-forest-region-v999", ""]:
		var refused: Dictionary = registry.generate_version(unsupported,"version-invalid",tuning,1,{"grapple":true})
		check(not refused.ok and not refused.has("manifest"),"unsupported explicit version refuses without fallback: "+unsupported)
	var malformed: Dictionary = registry.generate("version-invalid",tuning,1,{"grapple":true,"forest_content_version":{"version":LEGACY.VERSION}})
	check(not malformed.ok,"malformed capability version does not become the default")
	var queen: Dictionary = registry.generate_version(ThornForestRegionGenerator.DEPTH_VERSION,"version-queen-unimplemented",tuning,2,{"grapple":true,"abilities":["grapple"]})
	check(not queen.ok and str(queen.get("error","")).contains("Queen mechanic not promoted"),"v2 map2 explicitly refuses missing Queen geometry")
	check(not queen.has("manifest") or queen.manifest.version==ThornForestRegionGenerator.DEPTH_VERSION,"v2 map2 cannot silently return v1")
	cases.append({"id":"v2_map2_refused","ok":queen.ok,"error":queen.get("error",""),"returned_version":queen.get("manifest",{}).get("version","")})
	for map_index: int in [1,2]:
		await app_case(map_index)
	var output := "res://build/forest_depth/versions/native/capture.json"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"runtime version compatibility only; v2 gameplay not covered","assertions":assertions,"failures":failures,"engine":Engine.get_version_info(),"cases":cases,"checks":checks},"\t"))
	file.close()
	print("FOREST DEPTH VERSIONS: %s assertions, %s failures" % [assertions,failures])
	quit(1 if failures else 0)
func app_case(map_index: int) -> void:
	var app := DemoApp.new()
	app.meta_persistence_enabled=false
	root.add_child(app)
	check(not app.start_debug_region(&"thorn_forest",map_index,"version-app","unknown"),"debug rejects unsupported version before entry")
	check(app.director.state==DemoRunDirector.State.HOME,"refused debug request preserves HOME")
	var home_request := [app._debug_region,app._debug_map,app._requested_forest_version,app.forest_content_version]
	check(not app.start_debug_region(&"thorn_forest",2,"",ThornForestRegionGenerator.DEPTH_VERSION),"HOME empty seed refuses v2 map2 request")
	check([app._debug_region,app._debug_map,app._requested_forest_version,app.forest_content_version]==home_request and app.director.state==DemoRunDirector.State.HOME,"empty-seed refusal preserves all pending version/map fields and HOME")
	check(app.start_debug_region(&"thorn_forest",map_index,"version-app",LEGACY.VERSION),"explicit legacy debug entry accepted")
	await frames(8)
	check(app.stage is ThornForestRegionStage and app.stage.assembly_ok,"legacy debug assembles actual stage")
	if not app.stage is ThornForestRegionStage or not app.stage.assembly_ok:
		await dispose(app)
		return
	var active_request := [app._debug_region,app._debug_map,app._requested_forest_version,app.forest_content_version]
	var active_stage := app.stage
	check(not app.start_debug_region(&"thorn_forest",2,"refused-active-v2",ThornForestRegionGenerator.DEPTH_VERSION),"active run refuses conflicting v2 map2 debug entry")
	check([app._debug_region,app._debug_map,app._requested_forest_version,app.forest_content_version]==active_request and app.stage==active_stage,"active refusal preserves pending fields and actual active version/stage")
	var stage := app.stage as ThornForestRegionStage
	var boss_path := "res://scenes/bosses/thorn_guardian.tscn" if map_index==1 else "res://scenes/bosses/thorn_queen.tscn"
	check(stage.boss.scene_file_path==boss_path,"legacy actual instantiated Boss scene remains old")
	var enemies: Array = []
	for motor: EnemyMotor in stage.enemies:
		var actor := motor.get_node("Actor") as EnemyActor
		var expected := "res://scenes/enemies/"+str(actor.definition.behavior_id)+".tscn"
		check(actor.definition.behavior_id in [&"forest_lantern",&"forest_seed_sentry"] and motor.scene_file_path==expected,"legacy actual enemy instance remains old behavior/scene")
		enemies.append({"behavior":str(actor.definition.behavior_id),"scene":motor.scene_file_path})
	var snapshot: Dictionary = app.director.manifest.snapshot()
	var output: Dictionary = snapshot.stages[0].outputs
	check(output.generated_layout.version==LEGACY.VERSION and output.stage_generator.version==LEGACY.VERSION and output.region_map.version==LEGACY.VERSION and output.enemy_layout.version==LEGACY.VERSION,"all actual recorded version outputs pin v1")
	check(RunManifest.from_snapshot(JSON.parse_string(app.director.manifest.canonical_json()))!=null,"actual legacy manifest roundtrip accepted")
	for category: String in ["generated_layout","stage_generator","region_map","enemy_layout"]:
		var edited: Dictionary = snapshot.duplicate(true)
		edited.stages[0].outputs[category].version="thorn-forest-region-v999"
		check(RunManifest.from_snapshot(edited)==null,"recorded mismatched/unknown "+category+" version refused")
	var malformed: Dictionary = snapshot.duplicate(true)
	malformed.stages[0].outputs.generated_layout.version={"malformed":LEGACY.VERSION}
	check(RunManifest.from_snapshot(malformed)==null,"malformed recorded version safely refuses")
	var identity := {"id":"app_legacy","map":map_index,"boss_scene":stage.boss.scene_file_path,"enemies":enemies,"recorded_outputs":output.duplicate(true)}
	if map_index==1:
		var state := app.region_state
		var old_hash := state.manifest_hash
		state.claimed["version_probe_claim"]=true
		state.opened["version_probe_open"]=true
		state.mechanisms["version_probe_mechanism"]={"open":true}
		# A real nondefault instance value distinguishes replay from a fresh spawn.
		var prior_actor := stage.enemies[0].get_node("Actor") as EnemyActor
		var replay_health := prior_actor.health.current-1.0
		check(replay_health>0 and prior_actor.restore_instance_health(replay_health),"prepare actual nondefault legacy actor health for replay")
		stage.capture_state()
		var old_actors: Dictionary = state.actors.duplicate(true)
		app.forest_content_version=ThornForestRegionGenerator.DEPTH_VERSION
		await app._load_stage()
		check(app.region_state==state and state.manifest_hash==old_hash,"hash-bound version fallback retains same state object/hash")
		check(app.forest_content_version==LEGACY.VERSION and app.stage is ThornForestRegionStage and app.stage.assembly_ok,"hash-bound reload recovers recorded v1 rather than clearing state")
		check(state.claimed.has("version_probe_claim") and state.opened.has("version_probe_open") and state.mechanisms.get("version_probe_mechanism")=={"open":true},"hash fallback retains claims/open/mechanism ledgers")
		var actors_retained := old_actors.keys().size()==state.actors.keys().size()
		for actor_id: String in old_actors:
			actors_retained = actors_retained and state.actors.has(actor_id) and old_actors[actor_id].health==state.actors[actor_id].health
		check(actors_retained,"hash fallback does not erase recorded actor identities/health")
		var loaded_stage := app.stage as ThornForestRegionStage
		var loaded_actor := loaded_stage.enemies[0].get_node("Actor") as EnemyActor
		check(loaded_actor!=prior_actor and loaded_actor.health.current==replay_health,"actual reassembled legacy enemy retains nondefault health instead of resetting")
		identity.fallback={"version":app.forest_content_version,"hash_before":old_hash,"hash_after":state.manifest_hash,"same_state":app.region_state==state,"claims_retained":state.claimed.has("version_probe_claim"),"actors_retained":actors_retained,"nondefault_health":replay_health,"reloaded_health":loaded_actor.health.current}
		await frames(3)
	cases.append(identity)
	await dispose(app)
func dispose(app: DemoApp) -> void:
	app.abandon_run()
	await frames(4)
	check(app.director.state==DemoRunDirector.State.HOME,"legacy app cleanup returns HOME")
	check(await AUDIO.drain_world(app),"owned app audio actually drained")
	app.free()
	await frames(2)
