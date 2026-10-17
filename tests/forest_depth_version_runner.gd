extends SceneTree
## Runtime version contracts only; not v2 route or Boss admission.
const LEGACY := preload("res://scripts/generation/thorn_forest_region_v1.gd")
# Independently selected v2 playtest-default contract; not production admission.
const EXPECTED_PUBLIC_DEFAULT := ThornForestRegionGenerator.DEPTH_VERSION
var assertions := 0
var failures := 0
var cases: Array[Dictionary] = []
var checks: Array[Dictionary] = []
var exit_weak_refs: Dictionary = {}
var exit_observations: Dictionary = {}
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
	check(ThornForestRegionGenerator.VERSION == EXPECTED_PUBLIC_DEFAULT,"public default matches the independently selected version expectation")
	for root_seed: String in ["version-contract-00","version-contract-01","version-contract-02","version-contract-03"]:
		for map_index: int in [1,2]:
			var seed_value := LEGACY.seed_for(root_seed,map_index)
			var capabilities := {"grapple":true,"abilities":["grapple"]}
			var direct: Dictionary = old.generate(seed_value,tuning,map_index,capabilities)
			var explicit_legacy_capabilities: Dictionary=capabilities.duplicate(true)
			explicit_legacy_capabilities.forest_content_version=LEGACY.VERSION
			var delegated: Dictionary = registry.generate(seed_value,tuning,map_index,explicit_legacy_capabilities)
			var pinned: Dictionary = registry.generate_version(LEGACY.VERSION,seed_value,tuning,map_index,capabilities)
			check(direct.ok and delegated.ok and pinned.ok,"v1 generation succeeds "+seed_value)
			check(equality._same_data(direct,delegated) and equality._same_data(direct,pinned),"complete generated outputs exactly equal "+seed_value)
			check(registry.validate(direct.manifest,tuning) and old.validate(delegated.manifest,tuning),"both validators accept complete legacy output "+seed_value)
			# Public no-version API is a separate contract from immutable v1 replay.
			var public_default: Dictionary=registry.generate(seed_value,tuning,map_index,capabilities)
			var expected_default: Dictionary=registry.generate_version(EXPECTED_PUBLIC_DEFAULT,seed_value,tuning,map_index,capabilities)
			check(public_default.ok and expected_default.ok and public_default.manifest.version==EXPECTED_PUBLIC_DEFAULT and equality._same_data(public_default,expected_default),"unversioned API exactly uses expected public default "+seed_value)
			check(registry.validate(public_default.manifest,tuning),"public default complete manifest validates "+seed_value)
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
	check(queen.ok and queen.manifest.version==ThornForestRegionGenerator.DEPTH_VERSION and queen.manifest.map_index==2 and queen.production_pool==false and registry.validate(queen.manifest,tuning),"v2 map2 exposes exact technically valid experimental candidate without default promotion")
	var queen_contract: Dictionary=queen.get("manifest",{}).get("boss_contract",{})
	check(queen_contract.get("version")=="forest-queen-weave-golden-v2" and queen_contract.get("boss_contract")=="queen-weave-region-experimental" and queen_contract.get("admission")=="experimental_whole_boss_pending" and queen_contract.get("entry_mapping",{}).get("new_high_bridge")==false,"v2 map2 retains exact pending whole-Boss admission and existing-floor connector")
	cases.append({"id":"v2_map2_experimental","ok":queen.ok,"returned_version":queen.get("manifest",{}).get("version",""),"production_pool":queen.get("production_pool"),"boss_contract":queen_contract.duplicate(true)})
	for map_index: int in [1,2]:
		await app_case(map_index)
	# A bounded lifecycle hypothesis: the long async run() previously quit while
	# these local RefCounteds were still on its suspended coroutine stack.
	# Observe them weakly, release only runner-owned locals, then return before quit.
	exit_weak_refs={"registry":weakref(registry),"legacy":weakref(old),"equality":weakref(equality),"tuning":weakref(tuning),"tuning_script":weakref(tuning.get_script())}
	for label: String in exit_weak_refs:
		exit_observations[label]={"before_release_alive":is_instance_valid((exit_weak_refs[label] as WeakRef).get_ref())}
	registry=null
	old=null
	equality=null
	tuning=null
	deferred_finish.call_deferred()
func deferred_finish() -> void:
	# This callback runs only after run() has returned. No sleeps or retries.
	for label: String in exit_weak_refs:
		var alive := is_instance_valid((exit_weak_refs[label] as WeakRef).get_ref())
		exit_observations[label]["after_run_return_alive"]=alive
		if label!="tuning_script": check(not alive,"owned local released after run returns: "+label)
	var output := "res://build/forest_depth/versions/native/capture.json"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"runtime version compatibility only; v2 gameplay not covered","assertions":assertions,"failures":failures,"engine":Engine.get_version_info(),"cases":cases,"checks":checks,"exit_lifecycle":exit_observations},"\t"))
	file.close()
	file=null
	print("FOREST DEPTH VERSIONS: %s assertions, %s failures" % [assertions,failures])
	quit(1 if failures else 0)
func app_case(map_index: int) -> void:
	# Dynamic actual Node consumer avoids compiling App's typed graph into this
	# generator runner. All original checks/cases are forwarded by the helper.
	var helper: Node=load("res://tests/forest_depth_version_app_case.gd").new()
	helper.reporter=weakref(self)
	helper.legacy_version=LEGACY.VERSION
	root.add_child(helper)
	await helper.run(map_index)
	helper.free()
