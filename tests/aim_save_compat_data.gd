extends SceneTree
# Immutable replay consumer, with no actual-world scene ownership.
func data_script(path: String) -> Script:
	return load(path) as Script
var checks: Array = []
var cases: Array = []
var phase_identity: Dictionary
func _initialize() -> void:
	phase_identity={"phase":"data","engine_pid":OS.get_process_id(),"run_id":"","script":get_script().resource_path,"script_sha256":FileAccess.get_sha256(get_script().resource_path)}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--run-id="):phase_identity.run_id=arg.trim_prefix("--run-id=")
	print("AIM SAVE PHASE: ",JSON.stringify(phase_identity))
	execute.call_deferred()
func execute() -> void:
	var result := run()
	var failures := 0
	for row: Dictionary in result.checks:
		if not row.passed:
			failures+=1
			printerr("AIM SAVE FAIL: "+str(row.label))
	var output := "res://build/forest_grapple02/aim_save_compat_data.json"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"identity":phase_identity,"checks":result.checks,"cases":result.cases,"failures":failures,"scope":"immutable historical prefix replay only; no full-run resume API exists"},"\t"))
	file.close()
	print("AIM SAVE DATA: %s assertions / %s failures" % [result.checks.size(),failures])
	quit(1 if failures else 0)
func check(ok: bool,label: String) -> void:
	checks.append({"passed":ok,"label":label})
func run() -> Dictionary:
	var archive := "res://docs/evidence/forest_depth_v2/reviews/campaign-output-helper/cross_region_manifest.json"
	check(FileAccess.get_sha256(archive)=="82d6ef43b5f8bbd0f14cdff9468cdc7dae17c5c986d78a447935982c46475efa","original historical campaign bytes retained")
	# The source's forest-v6 suffix is not in today's whitelist. Its two actual
	# Plains outputs still reproduce the exact schema-1 prefix before transition.
	var recorded: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(archive))
	recorded.schema_version=1
	recorded.versions=recorded.legacy_versions.duplicate(true)
	recorded.erase("legacy_versions")
	recorded.stages=recorded.stages.slice(0,2)
	var historical_json:=JSON.stringify(recorded,"",true)
	var restored: RefCounted =data_script("res://scripts/run/run_manifest.gd").from_snapshot(recorded)
	check(restored!=null and restored.canonical_json()==historical_json,"both real archived Plains outputs replay unchanged at historical .2")
	cases.append({"kind":"original_archived_plains_prefix","source":archive,"source_sha256":FileAccess.get_sha256(archive),"recorded":recorded})
	for index: int in [0,1]:
		for field: String in ["id","version","health"]:
			var invalid := recorded.duplicate(true)
			invalid.stages[index].outputs.boss_layout[field] = "foreign_boss" if field=="id" else 999
			check(data_script("res://scripts/run/run_manifest.gd").from_snapshot(invalid)==null,"archived map %s rejects foreign Boss %s" % [index+1,field])
		var mismatched := recorded.duplicate(true)
		mismatched.stages[index].outputs.generated_layout.player_tuning_hash = FileAccess.get_sha256("res://config/player_tuning.json")
		mismatched.stages[index].outputs.generated_layout.manifest_hash = data_script("res://scripts/generation/random_stage_generator.gd").new()._manifest_hash(mismatched.stages[index].outputs.generated_layout)
		check(data_script("res://scripts/run/run_manifest.gd").from_snapshot(mismatched)==null,"archived map %s rejects historical Boss under foreign configuration" % [index+1])
		var swapped := recorded.duplicate(true)
		swapped.stages[index].outputs.boss_layout = recorded.stages[1-index].outputs.boss_layout.duplicate(true)
		check(data_script("res://scripts/run/run_manifest.gd").from_snapshot(swapped)==null,"archived map %s rejects other map historical Boss tuple" % [index+1])
	check_historical_plains_prefixes()
	restored=null
	return {"checks":checks,"cases":cases}
func check_historical_plains_prefixes() -> void:
	var path := "res://tests/fixtures/main_dbc6ba08_actual_plains_prefixes.json"
	check(FileAccess.get_sha256(path)=="7ae2d91b83974849edfc3777f1c940a1e924c412b18b6c2fcbd30b99166fea87","actual old-source three-version prefix bytes retained")
	var prefixes: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(prefixes.size()==3,"all three original supported Plains versions covered")
	for row: Dictionary in prefixes:
		var recorded: Dictionary = row.recorded
		var label := "main dbc6ba08 / " + str(row.mode)
		var canonical := JSON.stringify(recorded,"",true)
		var restored: RefCounted = data_script("res://scripts/run/run_manifest.gd").from_snapshot(recorded)
		check(restored!=null and restored.canonical_json()==canonical,label+" actual .15 old-Boss snapshot replays unchanged")
		var current := recorded.duplicate(true)
		for index: int in [0,1]:
			var definition: Resource = load("res://resources/bosses/bellstrider.tres" if index==0 else "res://resources/bosses/windkeeper_storm.tres")
			assert(is_instance_of(definition,data_script("res://scripts/bosses/boss_definition.gd")))
			current.stages[index].outputs.boss_layout = {"id":str(definition.stable_id),"version":definition.definition_version,"health":definition.health_definition.max_health}
		var current_restored: RefCounted = data_script("res://scripts/run/run_manifest.gd").from_snapshot(current)
		check(current_restored!=null and current_restored.canonical_json()==JSON.stringify(current,"",true),label+" current-Boss tuple remains canonical")
		for index: int in [0,1]:
			for field: String in ["id","version","health","configuration","focus","map_identity"]:
				var bad := recorded.duplicate(true)
				var output: Dictionary = bad.stages[index].outputs
				match field:
					"id":output.boss_layout.id="foreign_boss"
					"version":output.boss_layout.version=999
					"health":output.boss_layout.health+=1
					"configuration":
						output.generated_layout.player_tuning_hash="f".repeat(64)
						output.generated_layout.manifest_hash=data_script("res://scripts/generation/random_stage_generator.gd").new()._manifest_hash(output.generated_layout)
					"focus":output.stage_tuning.focus_time_scale=0.19
					"map_identity":output.region_map.map_index=2 if index==0 else 1
				check(data_script("res://scripts/run/run_manifest.gd").from_snapshot(bad)==null,label+" map%s rejects foreign %s" % [index+1,field])
		cases.append({"kind":"actual_old_source_plains_prefix","source_commit":row.source_commit,"mode":row.mode,"source":path,"source_sha256":FileAccess.get_sha256(path),"recorded":recorded})
