extends SceneTree
## Current default registry and actual App only; frozen historical replay is separate.
const EXPECTED_VERSION := "thorn-forest-region-v2"
const EXPECTED_LAYOUT := "forest-bible-world-v15"
const AUDIO := preload("res://tests/audio_teardown.gd")
var checks: Array[Dictionary] = []
var cases: Array[Dictionary] = []
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"label":label,"passed":ok})
	if not ok:
		failures += 1
		printerr("FOREST CURRENT REGISTRY FAIL: "+label)

func frames(count: int) -> void:
	for unused: int in count:
		await physics_frame
		await process_frame

func data_cases() -> void:
	# Synchronous locals leave scope before the async App consumer can quit.
	var registry := ThornForestRegionGenerator.new()
	var equality := RandomStageGenerator.new()
	var tuning := PlayerTuning.load_default()
	var caps := {"grapple":true,"abilities":["grapple"]}
	check(ThornForestRegionGenerator.VERSION==EXPECTED_VERSION and ThornForestRegionGenerator.CURRENT_DEPTH_LAYOUT==EXPECTED_LAYOUT,"independent current public version and layout")
	for root_seed: String in ["version-contract-00","version-contract-01","version-contract-02","version-contract-03"]:
		for index: int in [1,2]:
			var seed_value := root_seed+"/thorn_forest/map_"+str(index)
			var current := registry.generate(seed_value,tuning,index,caps)
			var explicit := registry.generate_version(EXPECTED_VERSION,seed_value,tuning,index,caps.merged({"forest_layout_version":EXPECTED_LAYOUT}))
			var ok: bool=current.get("ok",false) and explicit.get("ok",false)
			check(ok,"current and explicit generation "+seed_value)
			var m: Dictionary=current.get("manifest",{})
			var equal := ok and equality._same_data(current,explicit)
			check(equal,"complete unversioned output equals explicit selected layout "+seed_value)
			check(ok and m.get("version")==EXPECTED_VERSION and m.get("layout_version")==EXPECTED_LAYOUT and int(m.get("map_index",0))==index,"exact current identity "+seed_value)
			check(ok and registry.validate(m,tuning),"current whole manifest strictly validates "+seed_value)
			var altered := m.duplicate(true)
			altered.version="unsupported-forest-version"
			altered.manifest_hash=ThornForestRegionGenerator._hash(altered)
			var rejected := not registry.validate(altered,tuning)
			check(rejected,"coherently rehashed unsupported current version rejects "+seed_value)
			cases.append({"id":"current_data","seed":seed_value,"map":index,"version":m.get("version"),"layout":m.get("layout_version"),"complete_output_equal":equal,"strict_validation":ok and registry.validate(m,tuning),"unsupported_rehashed_rejected":rejected,"manifest":m})
	var negatives: Array[Dictionary] = []
	for version: String in ["unknown","thorn-forest-region-v999",""]:
		var result := registry.generate_version(version,"version-invalid",tuning,1,caps)
		var refused: bool=not result.get("ok",false) and not result.has("manifest")
		check(refused,"explicit unknown/empty version refuses without fallback: "+version)
		negatives.append({"kind":"version/"+version,"refused":refused})
	var malformed := registry.generate("version-invalid",tuning,1,caps.merged({"forest_content_version":{"version":EXPECTED_VERSION}}))
	var malformed_refused: bool=not malformed.get("ok",false) and not malformed.has("manifest")
	check(malformed_refused,"malformed capability version refuses without default fallback")
	negatives.append({"kind":"malformed_version","refused":malformed_refused})
	for layout: Variant in ["forest-future-v999","",{"layout":EXPECTED_LAYOUT}]:
		var result := registry.generate_version(EXPECTED_VERSION,"layout-invalid",tuning,1,caps.merged({"forest_layout_version":layout}))
		var refused: bool=not result.get("ok",false) and not result.has("manifest")
		check(refused,"unknown/empty/malformed layout refuses: "+str(layout))
		negatives.append({"kind":"layout/"+str(layout),"refused":refused})
	cases.append({"id":"registry_refusals","negative_cases":negatives})

func request_fields(app: DemoApp) -> Array:
	return [app._debug_region,app._debug_map,app._requested_forest_version,app._requested_forest_layout,app.forest_content_version,app._forest_layout_version]

func app_case(index: int) -> void:
	var app := DemoApp.new()
	app.meta_persistence_enabled=false
	root.add_child(app)
	var home_fields := request_fields(app)
	check(not app.start_debug_region(&"thorn_forest",index,"current-version-app","unknown"),"HOME unsupported version refuses map"+str(index))
	var home_unknown_unchanged := request_fields(app)==home_fields and app.director.state==DemoRunDirector.State.HOME
	check(home_unknown_unchanged,"HOME unsupported request preserves state and pending fields map"+str(index))
	check(not app.start_debug_region(&"thorn_forest",index,"",EXPECTED_VERSION),"HOME empty seed refuses map"+str(index))
	var home_empty_unchanged := request_fields(app)==home_fields and app.director.state==DemoRunDirector.State.HOME
	check(home_empty_unchanged,"HOME empty seed preserves state and pending fields map"+str(index))
	check(app.start_debug_region(&"thorn_forest",index,"current-version-app"),"actual unpinned current App starts map"+str(index))
	await frames(8)
	var stage := app.stage as ThornForestRegionStage
	var assembled := stage!=null and stage.assembly_ok
	check(assembled,"actual current App assembles map"+str(index))
	if not assembled:
		await dispose(app)
		return
	var actual: Dictionary=stage.generated.manifest.duplicate(true)
	var expected := ThornForestRegionGenerator.new().generate_version(EXPECTED_VERSION,str(actual.seed),app.player.tuning,index,{"grapple":true,"abilities":["grapple"],"forest_layout_version":EXPECTED_LAYOUT})
	var complete_equal: bool=actual.get("version")==EXPECTED_VERSION and actual.get("layout_version")==EXPECTED_LAYOUT and expected.get("ok",false) and RandomStageGenerator.new()._same_data(actual,expected.manifest)
	check(complete_equal,"actual current App full output equals independent layout expectation map"+str(index))
	var active_fields := request_fields(app)
	check(not app.start_debug_region(&"thorn_forest",3-index,"conflicting-current",EXPECTED_VERSION),"active current run refuses replacement map"+str(index))
	var active_unchanged := request_fields(app)==active_fields and app.stage==stage
	check(active_unchanged,"active refusal retains pending fields and actual Stage map"+str(index))
	var snapshot := app.director.manifest.snapshot()
	check(RunManifest.from_snapshot(JSON.parse_string(app.director.manifest.canonical_json()))!=null,"actual current manifest JSON roundtrip map"+str(index))
	var corrupted: Dictionary=snapshot.duplicate(true)
	corrupted.stages[0].outputs.generated_layout.version="thorn-forest-region-v999"
	var unknown_snapshot_refused := RunManifest.from_snapshot(corrupted)==null
	check(unknown_snapshot_refused,"current snapshot unknown version rejects map"+str(index))
	corrupted=snapshot.duplicate(true)
	corrupted.stages[0].outputs.generated_layout.version={"malformed":EXPECTED_VERSION}
	var malformed_snapshot_refused := RunManifest.from_snapshot(corrupted)==null
	check(malformed_snapshot_refused,"current snapshot malformed version rejects map"+str(index))
	var state := app.region_state
	state.claimed["current_version_claim_fixture"]=true
	state.opened["current_version_open_fixture"]=true
	state.mechanisms["current_version_mechanism_fixture"]={"open":true}
	check(not stage.enemies.is_empty(),"actual current world has a restorable enemy map"+str(index))
	if stage.enemies.is_empty():
		await dispose(app)
		return
	var actor := stage.enemies[0].get_node("Actor") as EnemyActor
	var actor_id := actor.get_instance_id()
	var saved_hp: float=actor.health.current-1.0
	check(saved_hp>0 and actor.restore_instance_health(saved_hp),"prepare nondefault actual current actor health map"+str(index))
	stage.capture_state()
	var before := {"claimed":state.claimed.duplicate(true),"opened":state.opened.duplicate(true),"mechanisms":state.mechanisms.duplicate(true),"actors":state.actors.duplicate(true)}
	await app._load_stage()
	var restored := app.stage as ThornForestRegionStage
	var restore_assembled := restored!=null and restored.assembly_ok
	check(restore_assembled,"actual current world reload assembles map"+str(index))
	if not restore_assembled:
		await dispose(app)
		return
	var same_manifest := RandomStageGenerator.new()._same_data(actual,restored.generated.manifest)
	var same_state := app.region_state==state and state.manifest_hash==str(actual.manifest_hash)
	check(same_manifest and same_state,"current reload retains exact current manifest hash and state map"+str(index))
	var after := {"claimed":state.claimed.duplicate(true),"opened":state.opened.duplicate(true),"mechanisms":state.mechanisms.duplicate(true),"actors":state.actors.duplicate(true)}
	var loaded_actor := restored.enemies[0].get_node("Actor") as EnemyActor
	var ledgers_health: bool = before==after and loaded_actor.get_instance_id()!=actor_id and loaded_actor.health.current==saved_hp
	check(ledgers_health,"current reload preserves claims mechanisms actor ledger and nondefault HP map"+str(index))
	cases.append({"id":"current_app","map":index,"version":actual.get("version"),"layout":actual.get("layout_version"),"complete_output_equal":complete_equal,"home_unknown_unchanged":home_unknown_unchanged,"home_empty_unchanged":home_empty_unchanged,"active_unchanged":active_unchanged,"unknown_snapshot_refused":unknown_snapshot_refused,"malformed_snapshot_refused":malformed_snapshot_refused,"reload_same_manifest":same_manifest,"reload_same_state":same_state,"reload_ledgers_health":ledgers_health,"saved_health":saved_hp,"restored_health":loaded_actor.health.current})
	await dispose(app)

func dispose(app: DemoApp) -> void:
	var ref: WeakRef = weakref(app)
	app.abandon_run()
	await frames(4)
	check(app.director.state==DemoRunDirector.State.HOME,"current App cleanup returns HOME")
	check(await AUDIO.drain_world(app),"current App owned audio drains")
	app.free()
	await frames(2)
	check(ref.get_ref()==null,"current App owner releases")

func run() -> void:
	data_cases()
	for index: int in [1,2]:
		await app_case(index)
	finish.call_deferred()

func finish() -> void:
	var output := "res://build/forest_current_registry/native/capture.json"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version":1,"scope":"Current V15 registry, current App refusal and current-state reload; no frozen historical replay","engine":Engine.get_version_info().string,"assertions":checks.size(),"failures":failures,"checks":checks,"cases":cases},"\t"))
	file.close()
	print("FOREST CURRENT REGISTRY: %s assertions, %s failures" % [checks.size(),failures])
	quit(1 if failures else 0)
