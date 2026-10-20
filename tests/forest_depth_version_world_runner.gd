extends SceneTree
## Independent actual App consumer. Generator replay remains in the data process.
var assertions := 0
var failures := 0
var cases: Array[Dictionary] = []
var checks: Array[Dictionary] = []
var phase_identity: Dictionary = {}
func _initialize() -> void:
	phase_identity={"phase":"world","engine_pid":OS.get_process_id(),"run_id":"","script":get_script().resource_path,"script_sha256":FileAccess.get_sha256(get_script().resource_path)}
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--run-id="):phase_identity.run_id=argument.trim_prefix("--run-id=")
	print("FOREST VERSION PHASE: ",JSON.stringify(phase_identity))
	run.call_deferred()
func check(ok: bool, label: String) -> void:
	assertions += 1
	checks.append({"label":label,"passed":ok})
	if not ok:
		failures += 1
		printerr("FOREST VERSION FAIL: "+label)
func run() -> void:
	for map_index: int in [1,2]:
		var helper: Node=load("res://tests/forest_depth_version_app_case.gd").new()
		helper.reporter=weakref(self)
		helper.legacy_version="thorn-forest-region-v1"
		root.add_child(helper)
		await helper.run(map_index)
		helper.free()
	deferred_finish.call_deferred()
func deferred_finish() -> void:
	if "--failure-probe" in OS.get_cmdline_user_args():check(false,"explicit failure probe after all original world checks")
	var output := "res://build/forest_depth/versions/native/world.json"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"identity":phase_identity,"capture_schema":6,"scope":"actual original legacy App compatibility only; independent native consumer","assertions":assertions,"failures":failures,"engine":Engine.get_version_info(),"cases":cases,"checks":checks},"\t"))
	file.close()
	file=null
	print("FOREST DEPTH VERSION WORLD: %s assertions, %s failures" % [assertions,failures])
	quit(1 if failures else 0)
