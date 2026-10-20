extends SceneTree
var failures := 0
var checks: Array = []
var cases: Array = []
var owner_observations: Array = []
var helper_reference: WeakRef
var phase_identity: Dictionary
func _initialize() -> void:
	phase_identity={"phase":"world","engine_pid":OS.get_process_id(),"run_id":"","script":get_script().resource_path,"script_sha256":FileAccess.get_sha256(get_script().resource_path)}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--run-id="):phase_identity.run_id=arg.trim_prefix("--run-id=")
	print("AIM SAVE PHASE: ",JSON.stringify(phase_identity))
	run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks.append({"passed":ok,"label":label})
	if not ok: failures+=1;printerr("AIM SAVE FAIL: "+label)
func run() -> void:

	var helper: Node=load("res://tests/aim_save_compat_case.gd").new()
	helper.reporter=weakref(self)
	helper_reference=weakref(helper)
	root.add_child(helper)
	for region: String in ["plains","thorn_forest"]:
		for map_index: int in [1,2]:await helper.run(region,map_index)
	for region: String in ["plains","thorn_forest"]:
		for kind: String in ["zero","config_sha","foreign_prefix"]:await helper.invalid_state(region,kind)
	helper.free()
	helper=null
	finish.call_deferred()
func finish() -> void:
	var helper_released := helper_reference.get_ref()==null
	owner_observations.append({"kind":"scene_helper","released":helper_released})
	if not helper_released:check(false,"actual scene helper released after its async run returned")
	if "--failure-probe" in OS.get_cmdline_user_args():check(false,"explicit failure probe after all real checks")
	var output := "res://build/forest_grapple02/aim_save_compat_world.json"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"identity":phase_identity,"checks":checks,"cases":cases,"failures":failures,"owner_observations":owner_observations,"scope":"immutable RunManifest replay and actual map-state reload; no historical full-run resume API exists"},"\t"))
	file.close()
	print("AIM SAVE COMPAT: %s assertions / %s failures" % [checks.size(),failures])
	quit(1 if failures else 0)
