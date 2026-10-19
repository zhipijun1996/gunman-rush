extends SceneTree
const MANIFEST := preload("res://scripts/run/run_manifest.gd")
var failures := 0
var checks: Array = []
var cases: Array = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks.append({"passed":ok,"label":label})
	if not ok: failures+=1;printerr("AIM SAVE FAIL: "+label)
func run() -> void:
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
	var restored:=MANIFEST.from_snapshot(recorded)
	check(restored!=null and restored.canonical_json()==historical_json,"both real archived Plains outputs replay unchanged at historical .2")
	cases.append({"kind":"original_archived_plains_prefix","source":archive,"source_sha256":FileAccess.get_sha256(archive),"recorded":recorded})
	restored=null
	var helper: Node=load("res://tests/aim_save_compat_case.gd").new()
	helper.reporter=weakref(self)
	root.add_child(helper)
	for region: String in ["plains","thorn_forest"]:
		for map_index: int in [1,2]:await helper.run(region,map_index)
	for region: String in ["plains","thorn_forest"]:
		for kind: String in ["zero","config_sha","foreign_prefix"]:await helper.invalid_state(region,kind)
	helper.free()
	finish.call_deferred()
func finish() -> void:
	var output := "res://build/forest_grapple02/aim_save_compat.json"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"cases":cases,"failures":failures,"scope":"immutable RunManifest replay and actual map-state reload; no historical full-run resume API exists"},"\t"))
	file.close()
	print("AIM SAVE COMPAT: %s assertions / %s failures" % [checks.size(),failures])
	quit(1 if failures else 0)
